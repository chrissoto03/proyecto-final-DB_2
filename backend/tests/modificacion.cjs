'use strict';
// Isolated SQL/API integration: creates its own business and removes only its rows.
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const config = require('../src/config');
const { getPool, pool, sql } = require('../src/db');
const app = require('../src/app');
(async () => {
  const db = await getPool(); let fixture, server;
  try {
    const tag = randomUUID();
    fixture = (await db.request().input('email',`entrega-${tag}@prueba.test`).input('cliente',`cliente-${tag}@prueba.test`).query(`
      SET XACT_ABORT ON; BEGIN TRANSACTION;
      DECLARE @n INT,@u INT,@c INT,@cat INT,@e1 INT,@e2 INT,@r INT;
      EXEC renta.usp_Negocio_Crear @nombre='Temporal prueba entrega',@email_contacto=@email,@negocio_id=@n OUTPUT;
      EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador temporal entrega',@email=@email,@password=N'TemporalEntrega2026!',@rol_nombre='Operador',@negocio_id=@n,@usuario_id=@u OUTPUT;
      EXEC renta.usp_Usuario_Registrar @nombre_completo='Cliente temporal entrega',@email=@cliente,@password=N'TemporalEntrega2026!',@usuario_id=@c OUTPUT;
      EXEC renta.usp_CategoriaEquipo_Crear @negocio_id=@n,@nombre='Temporal entrega',@tarifa_hora=10,@tarifa_dia=40,@monto_deposito=5,@categoria_id=@cat OUTPUT;
      EXEC renta.usp_Equipo_Crear @negocio_id=@n,@categoria_id=@cat,@codigo_interno='ENT-001',@equipo_id=@e1 OUTPUT;
      EXEC renta.usp_Equipo_Crear @negocio_id=@n,@categoria_id=@cat,@codigo_interno='ENT-002',@equipo_id=@e2 OUTPUT;
      INSERT renta.Reserva(negocio_id,cliente_id,operador_id,tipo_reserva,fecha_inicio,fecha_fin,estado,monto_final)
      VALUES(@n,@c,@u,'Anticipada',DATEADD(minute,-1,GETDATE()),DATEADD(hour,1,GETDATE()),'Pendiente',20);
      SET @r=SCOPE_IDENTITY();
      INSERT renta.DetalleReserva(reserva_id,equipo_id,tarifa_aplicada) VALUES(@r,@e1,10),(@r,@e2,10);
      INSERT renta.Deposito(reserva_id,monto_cobrado) VALUES(@r,5);
      COMMIT;
      SELECT @n n,@u u,@c c,@cat cat,@e1 e1,@e2 e2,@r r;`)).recordset[0];
    const q = text => { const req=db.request(); for(const [k,v] of Object.entries(fixture)) req.input(k,v); return req.query(text); };
    server=await new Promise(resolve=>{const s=app.listen(Number(process.env.TEST_API_PORT || 0),'127.0.0.1',()=>resolve(s));});
    const token=(n=fixture.n,rol='Operador')=>jwt.sign({negocio_id:n,rol},config.jwtSecret,{subject:String(fixture.u),issuer:config.jwtIssuer,audience:config.jwtAudience,expiresIn:'5m'});
    async function post(path,body={},n=fixture.n,rol='Operador') {
      const response=await fetch(`http://127.0.0.1:${server.address().port}/api/${path}`,{method:'POST',headers:{'Content-Type':'application/json',Authorization:`Bearer ${token(n,rol)}`},body:JSON.stringify(body)});
      return {status:response.status,data:await response.json()};
    }
    await q("UPDATE renta.Reserva SET fecha_inicio=DATEADD(day,1,GETDATE()),fecha_fin=DATEADD(hour,25,GETDATE()) WHERE reserva_id=@r;");
    const original=async()=> (await q('SELECT CONVERT(varchar(23),fecha_inicio,126) inicio,CONVERT(varchar(23),fecha_fin,126) fin FROM renta.Reserva WHERE reserva_id=@r')).recordset[0];
    const snapshot=async()=> (await q(`SELECT * FROM renta.Reserva WHERE reserva_id=@r;
      SELECT * FROM renta.DetalleReserva WHERE reserva_id=@r ORDER BY detalle_id;
      SELECT * FROM renta.Equipo WHERE equipo_id IN (@e1,@e2) ORDER BY equipo_id;
      SELECT * FROM renta.Pago WHERE reserva_id=@r ORDER BY pago_id;
      SELECT * FROM renta.Deposito WHERE reserva_id=@r;
      SELECT * FROM renta.AuditoriaEquipo WHERE equipo_id IN (@e1,@e2) ORDER BY auditoria_id;`)).recordsets;
    const initial=await original();
    const make=(hours,ids=[fixture.e1,fixture.e2])=>({fecha_inicio:initial.inicio,fecha_fin:new Date(new Date(initial.inicio+'Z').getTime()+hours*3600000).toISOString().slice(0,-1),equipo_ids:ids});
    const review=p=>post(`reservas/${fixture.r}/modificacion/revisar`,p);
    const commit=quote=>post(`reservas/${fixture.r}/modificacion/confirmar`,{confirmacion:quote.data.confirmacion});
    async function okReview(p) {const before=await snapshot();const result=await review(p);assert.equal(result.status,200,JSON.stringify(result));assert.deepEqual(await snapshot(),before,'Preview is read-only');return result;}
    async function denied(label,action){const before=await snapshot();const result=await action();assert.ok([400,403,404,409].includes(result.status),`${label}: ${JSON.stringify(result)}`);assert.deepEqual(await snapshot(),before,label);console.log('PASS '+label);return result;}
    const method=(await db.request().query('SELECT TOP(1) metodo_pago_id id FROM renta.MetodoPago ORDER BY metodo_pago_id')).recordset[0].id;
    await q('UPDATE renta.CategoriaEquipo SET tarifa_hora=99,tarifa_dia=200 WHERE categoria_id=@cat;');
    let quote=await okReview({fecha_inicio:initial.inicio,fecha_fin:initial.fin,equipo_ids:[fixture.e2,fixture.e1]});
    assert.equal(quote.data.resumen.total_nuevo,20);assert.equal(quote.data.resumen.cambios,false);
    const nochange=await snapshot();assert.equal((await commit(quote)).status,200);assert.deepEqual(await snapshot(),nochange);
    console.log('PASS unchanged dates/equipment preserve agreed price despite tariff change');
    await q('UPDATE renta.CategoriaEquipo SET tarifa_hora=10,tarifa_dia=40 WHERE categoria_id=@cat;');
    assert.equal((await post(`reservas/${fixture.r}/pagos`,{metodo_pago_id:method,monto:5})).status,201);
    quote=await okReview(make(2));assert.equal(quote.data.resumen.total_nuevo,40);assert.equal(quote.data.resumen.saldo,35);
    assert.equal((await post(`reservas/${fixture.r}/pagos`,{metodo_pago_id:method,monto:5})).status,201);
    let changed=await denied('payment after review requires confirmation again',()=>commit(quote));
    assert.equal(changed.status,409);assert.equal(changed.data.resumen.saldo,30);assert.ok(changed.data.confirmacion);
    assert.equal((await commit(changed)).status,200);
    assert.equal((await q('SELECT estado FROM renta.Reserva WHERE reserva_id=@r')).recordset[0].estado,'Pendiente');
    await denied('replaying old confirmation cannot overwrite saved changes',()=>commit(quote));
    quote=await okReview(make(3));
    await q('UPDATE renta.CategoriaEquipo SET tarifa_hora=12 WHERE categoria_id=@cat;');
    changed=await denied('tariff after review requires confirmation again',()=>commit(quote));assert.equal(changed.status,409);assert.equal(changed.data.resumen.total_nuevo,72);
    await denied('tampered confirmation',()=>post(`reservas/${fixture.r}/modificacion/confirmar`,{confirmacion:changed.data.confirmacion+'x'}));
    await denied('other business review',()=>post(`reservas/${fixture.r}/modificacion/revisar`,make(2),2147483647));
    await denied('other business confirmation',()=>post(`reservas/${fixture.r}/modificacion/confirmar`,{confirmacion:changed.data.confirmacion},2147483647));
    await denied('customer role',()=>post(`reservas/${fixture.r}/modificacion/revisar`,make(2),fixture.n,'Cliente'));
    await denied('equipment outside business',()=>review(make(2,[2147483647])));
    await denied('duplicate equipment',()=>review(make(2,[fixture.e1,fixture.e1])));
    await denied('new start not future',()=>review({fecha_inicio:'2020-01-01T08:00:00',fecha_fin:'2020-01-01T09:00:00',equipo_ids:[fixture.e1]}));
    quote=await okReview(make(2,[fixture.e1]));
    await q(`INSERT renta.Reserva(negocio_id,cliente_id,tipo_reserva,fecha_inicio,fecha_fin,estado,monto_final)
      SELECT @n,@c,'Anticipada',fecha_inicio,DATEADD(hour,4,fecha_inicio),'Pendiente',0 FROM renta.Reserva WHERE reserva_id=@r;
      INSERT renta.DetalleReserva(reserva_id,equipo_id,tarifa_aplicada) VALUES(SCOPE_IDENTITY(),@e1,0);`);
    await denied('new competing reservation invalidates confirmation',()=>commit(quote));
    await q('DELETE d FROM renta.DetalleReserva d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id WHERE r.negocio_id=@n AND r.reserva_id<>@r; DELETE renta.Reserva WHERE negocio_id=@n AND reserva_id<>@r;');
    for(const state of ['Cancelada','Completada','En curso']){await q(`UPDATE renta.Reserva SET estado='${state}' WHERE reserva_id=@r;`);await denied('state '+state,()=>review(make(2)));}
    await q("UPDATE renta.Reserva SET estado='Pendiente' WHERE reserva_id=@r; UPDATE renta.DetalleReserva SET fecha_hora_entrega=GETDATE() WHERE reserva_id=@r AND equipo_id=@e1;");
    await denied('delivered detail',()=>review(make(2)));
    await q('UPDATE renta.DetalleReserva SET fecha_hora_entrega=NULL WHERE reserva_id=@r;');
    await q("UPDATE renta.Equipo SET estado='Mantenimiento' WHERE equipo_id=@e2;");await denied('one unusable equipment prevents all changes',()=>review(make(3)));
    await q("UPDATE renta.Equipo SET estado='Disponible' WHERE equipo_id=@e2; UPDATE renta.CategoriaEquipo SET tarifa_hora=10 WHERE categoria_id=@cat;");
    // Two tabs reviewed different proposals against the same original data.
    const first=await okReview(make(2,[fixture.e1])),second=await okReview(make(3,[fixture.e2]));
    const outcomes=await Promise.all([commit(first),commit(second)]);assert.deepEqual(outcomes.map(x=>x.status).sort(),[200,409]);
    console.log('PASS own reservation excluded, concurrent proposals cannot overwrite silently');
    // This test-only trigger lives inside a transaction; the forced rollback removes it.
    const rollbackQuote=await okReview(make(3));
    const rollbackBefore=await snapshot();
    const triggerName='trg_Test_Modificacion_'+fixture.n;
    let forced=false;
    try {
      await db.request().input('r',fixture.r).input('n',fixture.n).input('u',fixture.u)
        .input('inicio',sql.DateTime,new Date(rollbackQuote.data.propuesta.fecha_inicio+'Z'))
        .input('fin',sql.DateTime,new Date(rollbackQuote.data.propuesta.fecha_fin+'Z'))
        .input('equipos',sql.NVarChar(sql.MAX),JSON.stringify(rollbackQuote.data.propuesta.equipo_ids))
        .input('version',sql.VarChar(64),rollbackQuote.data.resumen.version)
        .query(`BEGIN TRANSACTION;
          EXEC(N'CREATE TRIGGER renta.${triggerName} ON renta.DetalleReserva AFTER INSERT, UPDATE, DELETE AS
          BEGIN IF EXISTS(SELECT 1 FROM inserted WHERE reserva_id=${fixture.r}) OR EXISTS(SELECT 1 FROM deleted WHERE reserva_id=${fixture.r})
          THROW 51090, ''Fallo de prueba despues de escribir detalle'', 1; END');
          BEGIN TRY
            EXEC renta.usp_Reserva_Modificar @r,@n,@u,@inicio,@fin,@equipos,1,@version;
            ROLLBACK TRANSACTION;
          END TRY BEGIN CATCH IF XACT_STATE()<>0 ROLLBACK TRANSACTION; THROW; END CATCH;`);
    } catch(error) {assert.equal(error.number || error.originalError?.info?.number,51090);forced=true;}
    assert.ok(forced);assert.deepEqual(await snapshot(),rollbackBefore);
    assert.equal((await db.request().input('name','renta.'+triggerName).query('SELECT OBJECT_ID(@name) id')).recordset[0].id,null);
    console.log('PASS forced failure after detail write rolls back dates, equipment, payments and audit');
    // A total equal to the paid amount confirms; a lower total is rejected.
    quote=await okReview(make(1,[fixture.e1]));assert.equal(quote.data.resumen.total_nuevo,10);assert.equal((await commit(quote)).status,200);
    assert.equal((await q('SELECT estado FROM renta.Reserva WHERE reserva_id=@r')).recordset[0].estado,'Confirmada');
    await q('UPDATE renta.CategoriaEquipo SET tarifa_hora=1 WHERE categoria_id=@cat;');
    await denied('total below paid blocked',()=>review(make(2,[fixture.e1])));
    await q('UPDATE renta.CategoriaEquipo SET tarifa_hora=10 WHERE categoria_id=@cat;');
    const payments=(await q('SELECT SUM(monto) total FROM renta.Pago WHERE reserva_id=@r')).recordset[0].total;assert.equal(payments,10);
    assert.equal((await q('SELECT monto_cobrado,fecha_devolucion FROM renta.Deposito WHERE reserva_id=@r')).recordset[0].monto_cobrado,5);
    // Original start is checked after lock waits as well.
    await q('UPDATE renta.Reserva SET fecha_inicio=DATEADD(second,2,GETDATE()) WHERE reserva_id=@r;');
    quote=await okReview(make(2,[fixture.e1]));
    const held=new sql.Transaction(db);await held.begin();
    try {await new sql.Request(held).input('r',fixture.r).query('SELECT reserva_id FROM renta.Reserva WITH(UPDLOCK,HOLDLOCK) WHERE reserva_id=@r;');const waiting=commit(quote);await new Promise(r=>setTimeout(r,3000));await held.commit();assert.equal((await waiting).status,403);}catch(e){try{await held.rollback();}catch{}throw e;}
    console.log('PASS original start expires during lock wait; abonos and deposit preserved');
    if(process.env.CLIENT_URL){
      await q('UPDATE renta.Reserva SET fecha_inicio=DATEADD(day,2,GETDATE()),fecha_fin=DATEADD(hour,49,GETDATE()) WHERE reserva_id=@r;');
      const cookies=new Map();
      async function page(path,data){const r=await fetch(process.env.CLIENT_URL+path,{method:data?'POST':'GET',redirect:'manual',headers:{Cookie:[...cookies].map(([k,v])=>`${k}=${v}`).join('; '),...(data?{'Content-Type':'application/x-www-form-urlencoded'}:{})},body:data?new URLSearchParams(data):undefined});for(const c of r.headers.getSetCookie()){const p=c.split(';')[0],i=p.indexOf('=');cookies.set(p.slice(0,i),p.slice(i+1));}return {status:r.status,location:r.headers.get('location'),html:await r.text()};}
      const csrf=h=>h.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/)[1];
      let ui=await page('/');ui=await page('/?handler=Login',{'Input.Email':`entrega-${tag}@prueba.test`,'Input.Password':'TemporalEntrega2026!',__RequestVerificationToken:csrf(ui.html)});
      ui=await page(`/reservas/${fixture.r}/modificar`);assert.equal(ui.status,200);
      const dates=await original();const fields={Inicio:dates.inicio,Fin:new Date(new Date(dates.fin+'Z').getTime()+3600000).toISOString().slice(0,-1),Equipos:String(fixture.e1)};
      ui=await page(`/reservas/${fixture.r}/modificar?handler=Revisar`,{...fields,__RequestVerificationToken:csrf(ui.html)});assert.ok(ui.html.includes('Total anterior'));assert.ok(ui.html.includes('Confirmar modificación'));
      const confirmation=ui.html.match(/name="Confirmacion"[^>]*value="([^"]+)"/)?.[1] || ui.html.match(/value="([^"]+)"[^>]*name="Confirmacion"/)?.[1];assert.ok(confirmation);
      ui=await page(`/reservas/${fixture.r}/modificar?handler=Confirmar`,{...fields,Confirmacion:confirmation,__RequestVerificationToken:csrf(ui.html)});assert.equal(ui.status,302);assert.ok(ui.location.includes(`/reservas/${fixture.r}`));
      console.log('PASS Razor modification preview, confirmation with antiforgery and redirect to same reservation');
    }
  } finally {
    if(server) await new Promise(resolve=>server.close(resolve));
    if(fixture) await db.request().input('n',fixture.n).input('c',fixture.c).query(`SET XACT_ABORT ON; BEGIN TRANSACTION;
      DELETE p FROM renta.Pago p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id WHERE r.negocio_id=@n;
      DELETE p FROM renta.Deposito p JOIN renta.Reserva r ON r.reserva_id=p.reserva_id WHERE r.negocio_id=@n;
      DELETE d FROM renta.DetalleReserva d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id WHERE r.negocio_id=@n;
      DELETE renta.Reserva WHERE negocio_id=@n;
      DELETE a FROM renta.AuditoriaEquipo a JOIN renta.Equipo e ON e.equipo_id=a.equipo_id JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@n;
      DELETE m FROM renta.Mantenimiento m JOIN renta.Equipo e ON e.equipo_id=m.equipo_id JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@n;
      DELETE e FROM renta.Equipo e JOIN renta.CategoriaEquipo c ON c.categoria_id=e.categoria_id WHERE c.negocio_id=@n;
      DELETE renta.CategoriaEquipo WHERE negocio_id=@n; DELETE renta.Usuario WHERE negocio_id=@n OR usuario_id=@c;
      DELETE renta.Negocio WHERE negocio_id=@n; COMMIT;`);
    await pool.close();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
