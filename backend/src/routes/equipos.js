'use strict';

const { Router } = require('express');
const { getPool, sql } = require('../db');
const { authenticate, requireRoles } = require('../middleware/auth');

const router = Router();
const allowedStates = new Set([
  'Disponible', 'Reservado', 'Alquilado', 'Mantenimiento', 'Averiado', 'Fuera de servicio'
]);

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