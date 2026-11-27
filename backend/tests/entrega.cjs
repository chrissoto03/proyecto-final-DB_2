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
    const delivery=()=>post(`reservas/${fixture.r}/entrega`);
    const snapshot=async()=> (await q(`SELECT * FROM renta.Reserva WHERE reserva_id=@r;
      SELECT * FROM renta.DetalleReserva WHERE reserva_id=@r ORDER BY detalle_id;
      SELECT * FROM renta.Equipo WHERE equipo_id IN (@e1,@e2) ORDER BY equipo_id;
      SELECT * FROM renta.Pago WHERE reserva_id=@r ORDER BY pago_id;
      SELECT * FROM renta.Deposito WHERE reserva_id=@r;
      SELECT * FROM renta.AuditoriaEquipo WHERE equipo_id IN (@e1,@e2) ORDER BY auditoria_id;`)).recordsets;
    async function denied(label,action=delivery) {const before=await snapshot();const result=await action();assert.ok([400,403,404].includes(result.status),`${label}: ${JSON.stringify(result)}`);assert.deepEqual(await snapshot(),before,`${label}: no partial changes`);console.log(`PASS ${label}`);}
    const method=(await db.request().query('SELECT TOP(1) metodo_pago_id id FROM renta.MetodoPago ORDER BY metodo_pago_id')).recordset[0].id;
    assert.equal((await post(`reservas/${fixture.r}/pagos`,{metodo_pago_id:method,monto:10})).status,201);
    await denied('partial payment leaves Pending');
    await q("UPDATE renta.Reserva SET estado='Confirmada' WHERE reserva_id=@r;");
    await denied('Confirmed but balance outstanding (deposit not counted)');
    await q("UPDATE renta.Reserva SET estado='Pendiente' WHERE reserva_id=@r;");
    assert.equal((await post(`reservas/${fixture.r}/pagos`,{metodo_pago_id:method,monto:10})).status,201);
    await denied('other business',()=>post(`reservas/${fixture.r}/entrega`,{},2147483647));
    await denied('customer role',()=>post(`reservas/${fixture.r}/entrega`,{},fixture.n,'Cliente'));
    await q("UPDATE renta.Reserva SET fecha_inicio=DATEADD(minute,10,GETDATE()) WHERE reserva_id=@r;");
    await denied('before start');
    await q("UPDATE renta.Reserva SET fecha_inicio=DATEADD(hour,-1,GETDATE()),fecha_fin=GETDATE() WHERE reserva_id=@r;");
    await denied('at or after end');
    await q("UPDATE renta.Reserva SET fecha_inicio=DATEADD(minute,-1,GETDATE()),fecha_fin=DATEADD(hour,1,GETDATE()) WHERE reserva_id=@r;");
    for(const state of ['Cancelada','Completada','Pendiente']) {
      await q(`UPDATE renta.Reserva SET estado='${state}' WHERE reserva_id=@r;`);await denied(`state ${state}`);
    }
    await q("UPDATE renta.Reserva SET estado='Confirmada' WHERE reserva_id=@r;");
    for(const state of ['Averiado','Mantenimiento','Fuera de servicio','Alquilado']) {
      await q(`UPDATE renta.Equipo SET estado='${state}' WHERE equipo_id=@e2;`);await denied(`one of two equipment ${state}`);
    }
    await q("UPDATE renta.Equipo SET estado='Reservado' WHERE equipo_id=@e2; INSERT renta.Mantenimiento(equipo_id,tipo,fecha_inicio) VALUES(@e2,'Preventivo',GETDATE());");
    await denied('open maintenance despite Reserved status');
    await q('DELETE renta.Mantenimiento WHERE equipo_id=@e2;');
    await q(`INSERT renta.Reserva(negocio_id,cliente_id,tipo_reserva,fecha_inicio,fecha_fin,estado,monto_final)
      VALUES(@n,@c,'Walk-in',DATEADD(day,-2,GETDATE()),DATEADD(day,-1,GETDATE()),'Completada',0);
      INSERT renta.DetalleReserva(reserva_id,equipo_id,tarifa_aplicada,fecha_hora_entrega) VALUES(SCOPE_IDENTITY(),@e2,0,DATEADD(day,-2,GETDATE()));`);
    await denied('unreturned equipment in another rental even outside date range');
    await q('DELETE d FROM renta.DetalleReserva d JOIN renta.Reserva r ON r.reserva_id=d.reserva_id WHERE r.negocio_id=@n AND r.reserva_id<>@r; DELETE renta.Reserva WHERE negocio_id=@n AND reserva_id<>@r;');
    // Force an assignment inconsistency without touching any pre-existing data.
    await q('UPDATE renta.DetalleReserva SET equipo_id=@e1 WHERE reserva_id=@r AND equipo_id=@e2;');
    await denied('duplicate assigned equipment');
    await q('UPDATE renta.DetalleReserva SET equipo_id=@e2 WHERE detalle_id=(SELECT MAX(detalle_id) FROM renta.DetalleReserva WHERE reserva_id=@r);');
    const held = new sql.Transaction(db);
    await held.begin();
    try {
      await new sql.Request(held).input('r',fixture.r).query('UPDATE renta.Reserva SET fecha_fin=DATEADD(second,2,GETDATE()) WHERE reserva_id=@r;');
      const waiting = delivery();
      await new Promise(resolve=>setTimeout(resolve,3000));
      await held.commit();
      assert.equal((await waiting).status,403,'Clock is checked after waiting for the lock');
    } catch(error) { try { await held.rollback(); } catch {} throw error; }
    console.log('PASS delivery window expires while waiting for lock');
    await q('UPDATE renta.Reserva SET fecha_inicio=GETDATE(),fecha_fin=DATEADD(hour,1,GETDATE()) WHERE reserva_id=@r;');
    const outcomes=await Promise.all([delivery(),delivery()]);
    assert.deepEqual(outcomes.map(x=>x.status).sort(),[200,403]);
    const delivered=outcomes.find(x=>x.status===200).data;
    assert.equal(delivered.reserva.estado,'En curso');
    assert.equal(delivered.reserva.saldo,0);
    assert.ok(delivered.detalles.every(d=>d.fecha_hora_entrega && !d.fecha_hora_devolucion));
    assert.equal(new Set(delivered.detalles.map(d=>d.fecha_hora_entrega)).size,1);
    assert.equal(delivered.depositos[0].monto_cobrado,5);assert.equal(delivered.depositos[0].fecha_devolucion,null);
    const audits=(await q("SELECT * FROM renta.AuditoriaEquipo WHERE equipo_id IN (@e1,@e2) AND estado_nuevo='Alquilado' AND usuario_id=@u;")).recordset;
    assert.equal(audits.length,2);
    console.log('PASS start reached, atomic two-equipment delivery, same timestamp, deposit unchanged, audit, concurrent duplicate rejected');
    assert.equal((await post(`devoluciones/${delivered.detalles[0].detalle_id}`,{estado_devolucion:'Bueno'})).status,200);
    assert.equal((await post(`devoluciones/${delivered.detalles[1].detalle_id}`,{estado_devolucion:'Bueno',monto_devuelto:5,monto_retencion:0})).status,200);
    assert.equal((await q('SELECT estado FROM renta.Reserva WHERE reserva_id=@r')).recordset[0].estado,'Completada');
    const walk=await post('reservas',{cliente_id:fixture.c,equipo_ids:[fixture.e1],tipo_reserva:'Walk-in',fecha_inicio:new Date().toISOString(),fecha_fin:new Date(Date.now()+86400000).toISOString()});
    assert.equal(walk.status,201);assert.equal(walk.data.reserva.estado,'En curso');assert.ok(walk.data.detalles[0].fecha_hora_entrega);
    console.log('PASS return cycle and unchanged Walk-in creation');
    if (process.env.CLIENT_URL) {
      // Restore only this test reservation to exercise its Razor form, with no physical conflict.
      await q(`UPDATE renta.DetalleReserva SET fecha_hora_devolucion=GETDATE(),estado_equipo_devolucion='Bueno' WHERE reserva_id<>@r AND reserva_id IN (SELECT reserva_id FROM renta.Reserva WHERE negocio_id=@n);
        UPDATE renta.Reserva SET estado='Confirmada',fecha_inicio=DATEADD(minute,-1,GETDATE()),fecha_fin=DATEADD(hour,1,GETDATE()) WHERE reserva_id=@r;
        UPDATE renta.DetalleReserva SET fecha_hora_entrega=NULL,fecha_hora_devolucion=NULL,estado_equipo_devolucion=NULL WHERE reserva_id=@r;
        UPDATE renta.Equipo SET estado='Reservado' WHERE equipo_id IN (@e1,@e2);`);
      const cookies=new Map();
      async function page(path,data) {
        const response=await fetch(process.env.CLIENT_URL+path,{method:data?'POST':'GET',redirect:'manual',headers:{Cookie:[...cookies].map(([k,v])=>`${k}=${v}`).join('; '),...(data?{'Content-Type':'application/x-www-form-urlencoded'}:{})},body:data?new URLSearchParams(data):undefined});
        for(const cookie of response.headers.getSetCookie()) {const pair=cookie.split(';')[0],i=pair.indexOf('=');cookies.set(pair.slice(0,i),pair.slice(i+1));}
        return {status:response.status,location:response.headers.get('location'),html:await response.text()};
      }
      const csrf=html=>html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/)[1];
      let ui=await page('/');
      ui=await page('/?handler=Login',{'Input.Email':`entrega-${tag}@prueba.test`,'Input.Password':'TemporalEntrega2026!',__RequestVerificationToken:csrf(ui.html)});
      ui=await page(`/reservas/${fixture.r}`);assert.ok(ui.html.includes('>Entregar equipos</button>'));
      ui=await page(`/reservas/${fixture.r}?handler=Entregar`,{__RequestVerificationToken:csrf(ui.html)});
      assert.equal(ui.status,302);assert.ok(ui.location.includes(`/reservas/${fixture.r}`));
      ui=await page(ui.location);assert.ok(ui.html.includes('En curso'));assert.ok(!ui.html.includes('>Entregar equipos</button>'));assert.ok(ui.html.includes('Devolver ENT-001'));
      console.log('PASS real Razor login, delivery form with antiforgery, redirect to same reservation and return actions');
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
