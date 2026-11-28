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
    await q("UPDATE renta.Reserva SET estado='Cancelada' WHERE reserva_id=@r; UPDATE renta.Equipo SET estado='Averiado' WHERE equipo_id=@e1;");
    async function get(path,n=fixture.n){const r=await fetch(`http://127.0.0.1:${server.address().port}/api/${path}`,{headers:{Authorization:`Bearer ${token(n)}`}});return {status:r.status,data:await r.json()};}
    const start=body=>post(`equipos/${fixture.e1}/mantenimientos`,body||{tipo:'Correctivo',descripcion:'Reparación temporal',costo:0});
    const ficha=()=>get(`equipos/${fixture.e1}/ficha`);
    assert.equal((await ficha()).data.equipo.estado,'Averiado');
    assert.equal((await get(`equipos/${fixture.e1}/ficha`,2147483647)).status,404);
    for(const costo of [-1,1.234,100000000])assert.equal((await start({tipo:'Correctivo',descripcion:'Prueba',costo})).status,400);
    assert.equal((await start({tipo:'Correctivo',descripcion:'',costo:0})).status,400);
    assert.equal((await post(`equipos/${fixture.e1}/mantenimientos`,{tipo:'Correctivo',descripcion:'Prueba',costo:0},2147483647)).status,404);
    assert.equal((await post(`equipos/${fixture.e1}/mantenimientos`,{tipo:'Correctivo',descripcion:'Prueba',costo:0},fixture.n,'Cliente')).status,403);
    const starts=await Promise.all([start(),start()]);assert.deepEqual(starts.map(x=>x.status).sort(),[201,403]);
    const mid=starts.find(x=>x.status===201).data.mantenimiento_id;
    assert.equal((await ficha()).data.equipo.estado,'Mantenimiento');assert.equal((await ficha()).data.mantenimientos.length,1);
    const finish=estado=>post(`mantenimientos/${mid}/finalizar`,{costo:25.50,estado_equipo:estado});
    assert.equal((await finish('Reservado')).status,400);
    assert.equal((await post(`mantenimientos/${mid}/finalizar`,{costo:0,estado_equipo:'Disponible'},2147483647)).status,403);
    await q("UPDATE renta.Reserva SET estado='Confirmada',fecha_inicio=DATEADD(day,1,GETDATE()),fecha_fin=DATEADD(day,2,GETDATE()) WHERE reserva_id=@r;");
    assert.equal((await ficha()).data.reservas.length,1);
    assert.equal((await finish('Disponible')).status,200);
    let data=(await ficha()).data;assert.equal(data.equipo.estado,'Reservado');assert.equal(data.mantenimientos[0].costo,25.50);assert.ok(data.mantenimientos[0].fecha_fin);
    assert.equal((await finish('Disponible')).status,403);
    console.log('PASS damaged→maintenance→reserved, audit-safe concurrent start, duplicate finish, invalid inputs, role/business scope, associated reservations');
    await q("UPDATE renta.Reserva SET estado='Cancelada' WHERE reserva_id=@r; UPDATE renta.Equipo SET estado='Averiado' WHERE equipo_id=@e1;");
    for(const estado of ['Averiado','Disponible','Fuera de servicio']){
      const opened=await start();assert.equal(opened.status,201);
      assert.equal((await post(`mantenimientos/${opened.data.mantenimiento_id}/finalizar`,{costo:0,estado_equipo:estado})).status,200);
      assert.equal((await ficha()).data.equipo.estado,estado);
    }
    await q("UPDATE renta.Equipo SET estado='Averiado' WHERE equipo_id=@e1; UPDATE renta.DetalleReserva SET fecha_hora_entrega=GETDATE() WHERE reserva_id=@r AND equipo_id=@e1;");
    assert.equal((await start()).status,403);await q('UPDATE renta.DetalleReserva SET fecha_hora_entrega=NULL WHERE reserva_id=@r;');
    console.log('PASS unsuccessful repair stays damaged, successful repair available, outstanding rental blocks maintenance');
    if(process.env.CLIENT_URL){
      const cookies=new Map();
      async function page(path,data){const r=await fetch(process.env.CLIENT_URL+path,{method:data?'POST':'GET',redirect:'manual',headers:{Cookie:[...cookies].map(([k,v])=>`${k}=${v}`).join('; '),...(data?{'Content-Type':'application/x-www-form-urlencoded'}:{})},body:data?new URLSearchParams(data):undefined});for(const c of r.headers.getSetCookie()){const p=c.split(';')[0],i=p.indexOf('=');cookies.set(p.slice(0,i),p.slice(i+1));}return {status:r.status,location:r.headers.get('location'),html:await r.text()};}
      const csrf=h=>h.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/)[1];
      let ui=await page('/');ui=await page('/?handler=Login',{'Input.Email':`entrega-${tag}@prueba.test`,'Input.Password':'TemporalEntrega2026!',__RequestVerificationToken:csrf(ui.html)});
      ui=await page(`/equipos/${fixture.e1}`);assert.ok(ui.html.includes('ENT-001'));
      ui=await page(`/equipos/${fixture.e1}?handler=Iniciar`,{Tipo:'Correctivo',Descripcion:'Reparación desde ficha',Costo:'5.50',__RequestVerificationToken:csrf(ui.html)});assert.equal(ui.status,302);
      ui=await page(ui.location);assert.ok(ui.html.includes('En reparaci'));
      const open=(await ficha()).data.mantenimientos.find(m=>!m.fecha_fin);
      ui=await page(`/equipos/${fixture.e2}?handler=Finalizar`,{mantenimientoId:open.mantenimiento_id,estadoEquipo:'Disponible',Costo:'5.50',__RequestVerificationToken:csrf(ui.html)});assert.equal(ui.status,200);assert.ok(ui.html.includes('no est'));
      ui=await page(`/equipos/${fixture.e1}`);
      ui=await page(`/equipos/${fixture.e1}?handler=Finalizar`,{mantenimientoId:open.mantenimiento_id,estadoEquipo:'Disponible',Costo:'5.50',__RequestVerificationToken:csrf(ui.html)});assert.equal(ui.status,302);assert.ok(ui.location.includes(`/equipos/${fixture.e1}`));
      assert.equal((await ficha()).data.equipo.estado,'Disponible');
      console.log('PASS Razor create/finalize repair, forged maintenance from other equipment rejected, decimal cost preserved');
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
