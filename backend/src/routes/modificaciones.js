'use strict';
const { Router } = require('express');
const { readBusinessDate } = require('../lib/business-date');
const jwt = require('jsonwebtoken');
const config = require('../config');
const { getPool, sql } = require('../db');
const { authenticate, requireRoles } = require('../middleware/auth');
const router = Router();
router.use(authenticate, requireRoles('Administrador', 'Operador'));
const positive = x => Number.isInteger(Number(x)) && Number(x)>0 && Number(x)<=2147483647;
const audience = 'rentatica-modificacion';
function scope(req,res) {
  if (!positive(req.auth.negocio_id)||!positive(req.auth.sub)) {res.status(403).json({error:'La sesion no pertenece a un negocio.'});return false;}
  if (!positive(req.params.id)) {res.status(400).json({error:'Reserva invalida.'});return false;}
  return true;
}
function proposal(body) {
  const ids=body?.equipo_ids;
  if (!readBusinessDate(body?.fecha_inicio)||!readBusinessDate(body?.fecha_fin)||readBusinessDate(body.fecha_fin)<=readBusinessDate(body.fecha_inicio)||!Array.isArray(ids)||ids.length<1||ids.length>20||ids.some(x=>!positive(x))||new Set(ids.map(Number)).size!==ids.length) return null;
  return {fecha_inicio:body.fecha_inicio,fecha_fin:body.fecha_fin,equipo_ids:ids.map(Number).sort((a,b)=>a-b)};
}
async function calculate(req,p,confirm=false,version=null) {
  const pool=await getPool();
  const result=await pool.request().input('reserva_id',sql.Int,Number(req.params.id))
    .input('negocio_id',sql.Int,Number(req.auth.negocio_id)).input('usuario_id',sql.Int,Number(req.auth.sub))
    .input('fecha_inicio',sql.DateTime,readBusinessDate(p.fecha_inicio)).input('fecha_fin',sql.DateTime,readBusinessDate(p.fecha_fin))
    .input('equipos_json',sql.NVarChar(sql.MAX),JSON.stringify(p.equipo_ids))
    .input('confirmar',sql.Bit,confirm).input('version_esperada',sql.VarChar(64),version)
    .execute('renta.usp_Reserva_Modificar');
  return {resumen:result.recordsets[0][0],equipos:result.recordsets[1],propuesta:p};
}
function signed(req,result) {
  return {...result,confirmacion:jwt.sign({reserva_id:Number(req.params.id),negocio_id:Number(req.auth.negocio_id),propuesta:result.propuesta,version:result.resumen.version},config.jwtSecret,{algorithm:'HS256',issuer:config.jwtIssuer,audience,subject:String(req.auth.sub),expiresIn:'15m'})};
}
router.get('/reservas/:id/modificacion/equipos',async(req,res,next)=>{
  if(!scope(req,res))return;
  try {
    const pool=await getPool();
    await pool.request().input('reserva_id',sql.Int,Number(req.params.id)).input('negocio_id',sql.Int,Number(req.auth.negocio_id)).execute('renta.usp_Reserva_ObtenerPorId');
    const result=await pool.request().input('negocio_id',sql.Int,Number(req.auth.negocio_id)).execute('renta.usp_Equipo_Listar');
    const maintenance=await pool.request().input('negocio_id',sql.Int,Number(req.auth.negocio_id)).execute('renta.usp_Equipo_ListarConMantenimientoAbierto');
    const unavailable=new Set((maintenance.recordset||[]).map(e=>e.equipo_id));
    res.json({datos:(result.recordset||[]).map(e=>({...e,
      motivo_no_reservable: ['Averiado','Mantenimiento','Fuera de servicio'].includes(e.estado)
        ? `No se puede reservar: ${e.estado.toLowerCase()}.`
        : unavailable.has(e.equipo_id) ? 'No se puede reservar: tiene mantenimiento abierto.' : null
    }))});
  }catch(e){next(e);}
});
router.post('/reservas/:id/modificacion/revisar',async(req,res,next)=>{
  if(!scope(req,res))return;
  const p=proposal(req.body);if(!p)return res.status(400).json({error:'Indique fechas y entre 1 y 20 equipos validos.'});
  try {res.json(signed(req,await calculate(req,p)));}catch(e){next(e);}
});
router.post('/reservas/:id/modificacion/confirmar',async(req,res,next)=>{
  if(!scope(req,res))return;
  let quote;
  try {
    quote=jwt.verify(req.body?.confirmacion,config.jwtSecret,{algorithms:['HS256'],issuer:config.jwtIssuer,audience,subject:String(req.auth.sub)});
    if(quote.reserva_id!==Number(req.params.id)||quote.negocio_id!==Number(req.auth.negocio_id))throw Error('scope');
  }catch {return res.status(409).json({error:'La revision vencio o no corresponde a esta reserva. Revise los cambios otra vez.'});}
  try {res.json(await calculate(req,quote.propuesta,true,quote.version));}
  catch(e){
    if((e.number||e.originalError?.info?.number)===50002){
      try{return res.status(409).json({error:'La reserva, el precio o el saldo cambiaron. Revise el nuevo resumen y confirme otra vez.',...signed(req,await calculate(req,quote.propuesta))});}catch(updated){return next(updated);}
    }
    next(e);
  }
});
module.exports=router;
