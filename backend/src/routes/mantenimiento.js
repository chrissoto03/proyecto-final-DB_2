'use strict';
const {Router}=require('express');
const {getPool,sql}=require('../db');
const {authenticate,requireRoles}=require('../middleware/auth');
const router=Router();
router.use(authenticate,requireRoles('Administrador','Operador'));
const id=x=>Number.isInteger(Number(x)) && Number(x)>0 && Number(x)<=2147483647;
const money=x=>typeof x==='number' && Number.isFinite(x) && x>=0 && x<=99999999.99 && Math.abs(x*100-Math.round(x*100))<0.000001;
function scope(req,res){if(!id(req.auth.negocio_id)||!id(req.auth.sub)){res.status(403).json({error:'Se requiere una sesión de empleado del negocio.'});return false;}if(!id(req.params.id)){res.status(400).json({error:'Identificador inválido.'});return false;}return true;}
router.get('/equipos/:id/ficha',async(req,res,next)=>{
 if(!scope(req,res))return;
 try {const pool=await getPool();
 const equipment=await pool.request().input('equipo_id',sql.Int,Number(req.params.id)).input('negocio_id',sql.Int,Number(req.auth.negocio_id)).execute('renta.usp_Equipo_ObtenerPorId');
 const history=await pool.request().input('equipo_id',sql.Int,Number(req.params.id)).input('negocio_id',sql.Int,Number(req.auth.negocio_id)).execute('renta.usp_Mantenimiento_ListarPorEquipo');
 res.json({equipo:equipment.recordsets[0][0],reservas:equipment.recordsets[1]||[],mantenimientos:history.recordset||[]});
 }catch(e){next(e);}
});
router.post('/equipos/:id/mantenimientos',async(req,res,next)=>{
 if(!scope(req,res))return;
 const {descripcion,costo,tipo}=req.body||{};
 if(typeof descripcion!=='string'||!descripcion.trim()||descripcion.trim().length>300||!money(costo)||!['Preventivo','Correctivo'].includes(tipo))return res.status(400).json({error:'Indica tipo, descripción de hasta 300 caracteres y costo no negativo con máximo dos decimales.'});
 try{const pool=await getPool();const result=await pool.request().input('negocio_id',sql.Int,Number(req.auth.negocio_id)).input('equipo_id',sql.Int,Number(req.params.id)).input('operador_id',sql.Int,Number(req.auth.sub)).input('tipo',sql.VarChar(20),tipo).input('descripcion',sql.VarChar(300),descripcion.trim()).input('costo',sql.Decimal(10,2),costo).output('mantenimiento_id',sql.Int).execute('renta.usp_Mantenimiento_Crear');res.status(201).json({mantenimiento_id:result.output.mantenimiento_id});}catch(e){next(e);}
});
router.post('/mantenimientos/:id/finalizar',async(req,res,next)=>{
 if(!scope(req,res))return;
 const {costo,estado_equipo}=req.body||{};
 if(!money(costo)||!['Disponible','Averiado','Fuera de servicio'].includes(estado_equipo))return res.status(400).json({error:'Indica un costo no negativo con máximo dos decimales y un resultado válido.'});
 try{const pool=await getPool();await pool.request().input('mantenimiento_id',sql.Int,Number(req.params.id)).input('negocio_id',sql.Int,Number(req.auth.negocio_id)).input('usuario_id',sql.Int,Number(req.auth.sub)).input('costo',sql.Decimal(10,2),costo).input('estado_equipo',sql.VarChar(20),estado_equipo).execute('renta.usp_Mantenimiento_Finalizar');res.json({mensaje:'Mantenimiento finalizado.'});}catch(e){next(e);}
});
module.exports=router;
