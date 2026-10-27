'use strict';

const { Router } = require('express');
const { getPool, sql } = require('../db');
const { authenticate, requireRoles } = require('../middleware/auth');

const router = Router();

router.get('/inventario', authenticate, requireRoles('Administrador', 'Operador'), async (req, res, next) => {
  if (!Number.isInteger(req.auth.negocio_id)) {
    return res.status(403).json({ error: 'El usuario no pertenece a un negocio.' });
  }
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('negocio_id', sql.Int, req.auth.negocio_id)
      .execute('renta.usp_Reporte_InventarioPorCategoria');
    return res.json({ datos: result.recordset || [] });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;