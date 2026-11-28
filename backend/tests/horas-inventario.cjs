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
    const {readBusinessDate}=require('../src/lib/business-date');
    for(const value of ['2027-01-10T12:00','2027-01-10T12:00:00','2027-01-10T12:00:00Z']) assert.equal(readBusinessDate(value).toISOString(),'2027-01-10T12:00:00.000Z');
    for(const value of ['2027-02-30T12:00:00','2027-01-10T25:00:00','1700-01-10T12:00:00','2027-01-10T12:00:00-06:00','']) assert.equal(readBusinessDate(value),null);
    async function get(path){const r=await fetch(`http://127.0.0.1:${server.address().port}/api/${path}`,{headers:{Authorization:`Bearer ${token()}`}});return {status:r.status,data:await r.json()};}
    const dates=(await q("SELECT CONVERT(varchar(19),DATEADD(hour,12,CONVERT(datetime,CONVERT(date,DATEADD(day,2,GETDATE())))),126) inicio, CONVERT(varchar(19),DATEADD(hour,14,CONVERT(datetime,CONVERT(date,DATEADD(day,2,GETDATE())))),126) fin;")).recordset[0];
    const query=new URLSearchParams({fecha_inicio:dates.inicio,fecha_fin:dates.fin});
    const available=await get('equipos/disponibilidad?'+query);assert.equal(available.status,200);assert.equal(available.data.datos.find(e=>e.equipo_id===fixture.e1).monto_estimado,20);
    const created=await post('reservas',{cliente_id:fixture.c,equipo_ids:[fixture.e1],tipo_reserva:'Anticipada',fecha_inicio:dates.inicio,fecha_fin:dates.fin});
    assert.equal(created.status,201,JSON.stringify(created));const rid=created.data.reserva.reserva_id;
    assert.equal(created.data.reserva.fecha_inicio.slice(0,19),dates.inicio);assert.equal(created.data.reserva.fecha_fin.slice(0,19),dates.fin);assert.equal(created.data.reserva.monto_final,20);
    const raw=(await db.request().input('id',rid).query('SELECT CONVERT(varchar(19),fecha_inicio,126) inicio,CONVERT(varchar(19),fecha_fin,126) fin FROM renta.Reserva WHERE reserva_id=@id')).recordset[0];assert.deepEqual(raw,dates);
    assert.ok(!(await get('equipos/disponibilidad?'+query)).data.datos.some(e=>e.equipo_id===fixture.e1));
    const adjacent=new URLSearchParams({fecha_inicio:dates.fin,fecha_fin:dates.fin.slice(0,11)+'16:00:00'});
    assert.ok((await get('equipos/disponibilidad?'+adjacent)).data.datos.some(e=>e.equipo_id===fixture.e1));
    const review=await post(`reservas/${rid}/modificacion/revisar`,{fecha_inicio:dates.inicio,fecha_fin:dates.fin,equipo_ids:[fixture.e1]});assert.equal(review.status,200);assert.equal(review.data.resumen.cambios,false);assert.equal(review.data.resumen.total_nuevo,20);
    await q("UPDATE renta.Reserva SET estado='Cancelada' WHERE reserva_id=@r; UPDATE renta.Equipo SET estado='Averiado' WHERE equipo_id=@e2;");
    assert.ok(!(await get('equipos/disponibilidad?'+adjacent)).data.datos.some(e=>e.equipo_id===fixture.e2));
    const now=(await q('SELECT CONVERT(varchar(19),GETDATE(),126) inicio,CONVERT(varchar(19),DATEADD(hour,2,GETDATE()),126) fin')).recordset[0];
    const walk=await post('reservas',{cliente_id:fixture.c,equipo_ids:[fixture.e1],tipo_reserva:'Walk-in',fecha_inicio:now.inicio,fecha_fin:now.fin});assert.equal(walk.status,201,JSON.stringify(walk));assert.equal(walk.data.reserva.monto_final,20);assert.equal(walk.data.reserva.fecha_fin.slice(0,19),now.fin);
    const badWalk=await post('reservas',{cliente_id:fixture.c,equipo_ids:[fixture.e1],tipo_reserva:'Walk-in',fecha_inicio:now.inicio,fecha_fin:'2020-01-01T10:00:00'});assert.equal(badWalk.status,400);
    console.log('PASS local dates round-trip unchanged, 2 hours = 20, overlap/adjacency, no-op modification, damaged equipment excluded, Walk-in uses SQL time and rejects past end');
    if(process.env.CLIENT_URL){
      const cookies=new Map();
      async function page(path,data){const r=await fetch(process.env.CLIENT_URL+path,{method:data?'POST':'GET',headers:{Cookie:[...cookies].map(([k,v])=>`${k}=${v}`).join('; '),...(data?{'Content-Type':'application/x-www-form-urlencoded'}:{})},body:data?new URLSearchParams(data):undefined});for(const c of r.headers.getSetCookie()){const p=c.split(';')[0],i=p.indexOf('=');cookies.set(p.slice(0,i),p.slice(i+1));}assert.equal(r.status,200);return r.text();}
      const csrf=h=>h.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/)[1];
      let html=await page('/');html=await page('/?handler=Login',{'Input.Email':`entrega-${tag}@prueba.test`,'Input.Password':'TemporalEntrega2026!',__RequestVerificationToken:csrf(html)});
      html=await page('/?handler=Equipos',{Estado:'Averiado',__RequestVerificationToken:csrf(html)});assert.ok(html.includes('<table'));assert.ok(html.includes('ENT-002'));assert.ok(!html.includes('<pre>'));
      html=await page('/?handler=Equipos',{Estado:'Mantenimiento',__RequestVerificationToken:csrf(html)});assert.ok(html.includes('No hay resultados para esta consulta.'));
      html=await page('/?handler=ReporteInventario',{__RequestVerificationToken:csrf(html)});assert.ok(html.includes('<table'));assert.ok(html.includes('Fuera de operación'));assert.ok(!html.includes('<pre>'));
      console.log('PASS Razor inventory table, empty-state message, category report without JSON');
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
