// Requires scenario 13 with FLUJO-001 and FLUJO-002 available, API :3000 and Razor :5181.
// Leaves the two reservations in the temporary scenario for manual inspection.
const assert = require('node:assert/strict');
const { getPool, pool } = require('../src/db');
const base = process.env.CLIENT_URL || 'http://localhost:5181';
const cookies = new Map();
async function page(path, data) {
  const response = await fetch(base + path, { method: data ? 'POST' : 'GET', redirect: 'manual',
    headers: { Cookie: [...cookies].map(([k,v]) => `${k}=${v}`).join('; '), ...(data ? {'Content-Type':'application/x-www-form-urlencoded'} : {}) },
    body: data ? new URLSearchParams(data) : undefined });
  for (const cookie of response.headers.getSetCookie()) { const part = cookie.split(';')[0]; const at = part.indexOf('='); cookies.set(part.slice(0,at),part.slice(at+1)); }
  return { status: response.status, location: response.headers.get('location'), html: await response.text() };
}
function csrf(html) { const match = html.match(/name="__RequestVerificationToken"[^>]*value="([^"]+)"/); assert.ok(match, 'antiforgery token'); return match[1]; }
async function api(path, token, body) {
  const r = await fetch('http://localhost:3000/api/' + path, {method:body ? 'POST':'GET',headers:{'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:body?JSON.stringify(body):undefined});
  const data = await r.json();
  if (data.reserva) delete data.reserva.hora_servidor;
  return { status:r.status, data };
}
(async () => {
  let other;
  const db = await getPool();
  try {
    const auth = await api('auth/login', null, {email:'operador.flujo@prueba.test',password:'RentaTicaFlujo2026!'});
    assert.equal(auth.status,200); const token=auth.data.token;
    const customers=await api('clientes',token), equipment=await api('equipos?estado=Disponible',token);
    const customer=customers.data.datos.find(x=>x.email==='cliente.flujo@prueba.test');
    const ids=['FLUJO-001','FLUJO-002'].map(code=>equipment.data.datos.find(x=>x.codigo_interno===code)?.equipo_id);
    assert.ok(ids.every(Boolean),'Both temporary equipment units must be available; do not reset existing data automatically.');
    const reservations=[];
    for(const id of ids) {
      const result=await api('reservas',token,{cliente_id:customer.usuario_id,equipo_ids:[id],tipo_reserva:'Walk-in',fecha_inicio:new Date().toISOString(),fecha_fin:new Date(Date.now()+7200000).toISOString()});
      assert.equal(result.status,201,JSON.stringify(result.data)); reservations.push(result.data);
    }
    const [a,b]=reservations, aid=a.reserva.reserva_id,bid=b.reserva.reserva_id;
    let ui=await page('/');
    ui=await page('/?handler=Login',{'Input.Email':'operador.flujo@prueba.test','Input.Password':'RentaTicaFlujo2026!',__RequestVerificationToken:csrf(ui.html)});
    assert.ok(ui.html.includes(`/reservas/${aid}`),'List has detail link');
    const tabA=await page(`/reservas/${aid}`); const tabB=await page(`/reservas/${bid}`);
    assert.ok(tabA.html.includes('FLUJO-001')); assert.ok(tabB.html.includes('FLUJO-002'));
    let result=await page(`/reservas/${aid}?handler=Pagar`,{Monto:'1.00',Metodo:'1',__RequestVerificationToken:csrf(tabA.html)});
    assert.equal(result.status,302,result.html.match(/<div class="notice error"[^>]*>(.*?)<\/div>/s)?.[1]); assert.ok(result.location.includes(`/reservas/${aid}`));
    let updated=await api(`reservas/${aid}`,token); assert.equal(updated.data.reserva.saldo,a.reserva.saldo-1);
    ui=await page(`/reservas/${aid}`);
    // A forged detail from the second tab must not be returned from the first reservation.
    result=await page(`/reservas/${aid}?handler=Devolver`,{detalleId:b.detalles[0].detalle_id,estado:'Bueno',__RequestVerificationToken:csrf(ui.html)});
    assert.equal(result.status,200); assert.ok(result.html.includes('no corresponde'));
    result=await page(`/reservas/${aid}?handler=Pagar`,{Monto:String(updated.data.reserva.saldo),Metodo:'1',__RequestVerificationToken:csrf(ui.html)});
    assert.equal(result.status,302,result.html.match(/<div class="notice error"[^>]*>(.*?)<\/div>/s)?.[1]);
    ui=await page(`/reservas/${aid}`); assert.ok(!ui.html.includes('Registrar abono'));
    result=await page(`/reservas/${aid}?handler=Devolver`,{detalleId:a.detalles[0].detalle_id,estado:'Bueno',__RequestVerificationToken:csrf(ui.html)});
    assert.equal(result.status,302,result.html.match(/<div class="notice error"[^>]*>(.*?)<\/div>/s)?.[1]);
    updated=await api(`reservas/${aid}`,token); assert.equal(updated.data.reserva.saldo,0); assert.equal(updated.data.reserva.estado,'Completada');
    const unchanged=await api(`reservas/${bid}`,token); assert.deepEqual(unchanged.data,b.reserva_id ? {reserva:b.reserva,detalles:b.detalles,pagos:b.pagos,depositos:b.depositos}:b);
    const available=await api('equipos?estado=Disponible',token); assert.ok(available.data.datos.some(x=>x.equipo_id===ids[0]));
    const setup=await db.request().query(`DECLARE @n INT,@u INT;
      EXEC renta.usp_Negocio_Crear @nombre='Prueba aislamiento ficha',@email_contacto='ficha-aislamiento@prueba.test',@negocio_id=@n OUTPUT;
      EXEC renta.usp_Usuario_CrearEmpleado @nombre_completo='Operador aislamiento',@email='ficha-aislamiento@prueba.test',@password=N'FichaTemporal2026!',@rol_nombre='Operador',@negocio_id=@n,@usuario_id=@u OUTPUT;
      SELECT @n negocio_id;`);
    other=setup.recordset[0].negocio_id;
    const otherAuth=await api('auth/login',null,{email:'ficha-aislamiento@prueba.test',password:'FichaTemporal2026!'}); assert.equal(otherAuth.status,200);
    for(const [path,body] of [[`reservas/${bid}`,null],[`reservas/${bid}/pagos`,{metodo_pago_id:1,monto:1}],[`devoluciones/${b.detalles[0].detalle_id}`,{estado_devolucion:'Bueno'}]]) {
      const denied=await api(path,otherAuth.data.token,body); assert.ok([403,404].includes(denied.status),`${path}: ${denied.status}`);
    }
    assert.deepEqual((await api(`reservas/${bid}`,token)).data,unchanged.data);
    console.log(`PASS: list, same-session tabs, partial/full payment, foreign-detail rejection, return, stock, unchanged second reservation, cross-business GET/payment/return. Reservations ${aid}, ${bid}.`);
  } finally {
    if(other) await db.request().input('id',other).query('DELETE FROM renta.Usuario WHERE negocio_id=@id; DELETE FROM renta.Negocio WHERE negocio_id=@id;');
    await pool.close();
  }
})().catch(error=>{console.error(error);process.exitCode=1;});
