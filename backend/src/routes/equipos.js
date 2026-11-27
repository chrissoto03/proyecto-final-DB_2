'use strict';

const { Router } = require('express');
const { getPool, sql } = require('../db');
const { authenticate, requireRoles } = require('../middleware/auth');

const router = Router();
const allowedStates = new Set([
  'Disponible', 'Reservado', 'Alquilado', 'Mantenimiento', 'Averiado', 'Fuera de servicio'
]);

router.get('/disponibilidad', authenticate, requireRoles('Administrador', 'Operador'), async (req, res, next) => {
  const negocioId = req.auth.negocio_id;
  if (!Number.isInteger(negocioId) || negocioId <= 0) return res.status(403).json({ error: 'El usuario no pertenece a un negocio.' });
  const parseDate = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(:\d{2}(\.\d{1,3})?)?$/.test(value) ? new Date(value) : null;
  const inicio = parseDate(req.query.fecha_inicio), fin = parseDate(req.query.fecha_fin);
  if (!inicio || !fin || !Number.isFinite(inicio.getTime()) || !Number.isFinite(fin.getTime()) || fin <= inicio) {
    return res.status(400).json({ error: 'Indica inicio y fin válidos; el fin debe ser posterior al inicio.' });
  }
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('negocio_id', sql.Int, negocioId)
      .input('categoria_id', sql.Int, null)
      .input('fecha_inicio', sql.DateTime, inicio)
      .input('fecha_fin', sql.DateTime, fin)
      .execute('renta.usp_Equipo_ConsultarDisponibilidad');
    return res.json({ datos: result.recordset || [] });
  } catch (error) { return next(error); }
});
router.get('/', authenticate, requireRoles('Administrador', 'Operador'), async (req, res, next) => {
  const estado = req.query.estado || 'Disponible';
  if (typeof estado !== 'string' || !allowedStates.has(estado)) {
    return res.status(400).json({ error: 'El estado solicitado no es valido.' });
  }
  if (!Number.isInteger(req.auth.negocio_id)) {
    return res.status(403).json({ error: 'El usuario no pertenece a un negocio.' });
  }
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('negocio_id', sql.Int, req.auth.negocio_id)
      .input('estado', sql.VarChar(20), estado)
      .execute('renta.usp_Equipo_ListarPorEstado');
    return res.json({ datos: result.recordset || [] });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
