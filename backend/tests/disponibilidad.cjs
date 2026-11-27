'use strict';
// Read-only integration test. Uses an existing future reservation; never resets scenario 13.
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const config = require('../src/config');
const { getPool, pool } = require('../src/db');
const app = require('../src/app');
(async () => {
  let server;
  try {
    const db = await getPool();
    const fixture = (await db.request().query(`SELECT TOP(1) r.reserva_id,r.negocio_id,d.equipo_id,
      CONVERT(varchar(19),r.fecha_inicio,126) inicio,CONVERT(varchar(19),r.fecha_fin,126) fin,
      CONVERT(varchar(19),DATEADD(day,1,r.fecha_fin),126) despues,
      CONVERT(varchar(19),DATEADD(day,2,r.fecha_fin),126) despues_fin
      FROM renta.Reserva r JOIN renta.DetalleReserva d ON d.reserva_id=r.reserva_id
      WHERE r.tipo_reserva='Anticipada' AND r.estado IN ('Pendiente','Confirmada') AND r.fecha_inicio>GETDATE()
      ORDER BY r.reserva_id DESC;`)).recordset[0];
    assert.ok(fixture,'Requires an existing future reservation');
    server = await new Promise(resolve => { const s = app.listen(0,'127.0.0.1',()=>resolve(s)); });
    const token = (business, role='Operador') => jwt.sign({negocio_id:business,rol:role},config.jwtSecret,{issuer:config.jwtIssuer,audience:config.jwtAudience,subject:'1',expiresIn:'1m'});
    async function get(start,end,business=fixture.negocio_id,role='Operador') {
      const q = new URLSearchParams({fecha_inicio:start,fecha_fin:end});
      const response=await fetch(`http://127.0.0.1:${server.address().port}/api/equipos/disponibilidad?${q}`,{headers:{Authorization:`Bearer ${token(business,role)}`}});
      return {status:response.status,body:await response.json()};
    }
    const overlap=await get(fixture.inicio,fixture.fin); assert.equal(overlap.status,200);
    assert.ok(!overlap.body.datos.some(e=>e.equipo_id===fixture.equipo_id),'overlap excluded');
    const later=await get(fixture.despues,fixture.despues_fin); assert.equal(later.status,200);
    assert.ok(later.body.datos.some(e=>e.equipo_id===fixture.equipo_id),'reserved unit reusable on non-overlapping dates');
    assert.ok(later.body.datos.every(e=>Number.isFinite(e.monto_estimado)));
    const foreign=await get(fixture.despues,fixture.despues_fin,2147483647); assert.equal(foreign.status,404);
    assert.equal((await get(fixture.fin,fixture.inicio)).status,400);
    assert.equal((await get('invalid',fixture.fin)).status,400);
    assert.equal((await get(fixture.inicio,fixture.fin,fixture.negocio_id,'Cliente')).status,403);
    console.log('PASS: overlap excluded, non-overlap available with estimate, invalid ranges rejected, role and business isolation. No data mutated.');
  } finally { if(server) await new Promise(resolve=>server.close(resolve)); await pool.close(); }
})().catch(error=>{ console.error(error);process.exitCode=1; });
