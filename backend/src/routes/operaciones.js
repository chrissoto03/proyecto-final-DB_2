'use strict';

const { Router } = require('express');
const { readBusinessDate } = require('../lib/business-date');
const { getPool, sql } = require('../db');
const { authenticate, requireRoles } = require('../middleware/auth');

const router = Router();
const staff = [authenticate, requireRoles('Administrador', 'Operador')];
const allowedReservationTypes = new Set(['Anticipada', 'Walk-in']);
const allowedReturnStates = new Set(['Bueno', 'Averiado', 'Perdido']);

function readPositiveId(value) {
  const id = Number(value);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function readBusinessId(req, res) {
  const id = readPositiveId(req.auth?.negocio_id);
  if (!id) {
    res.status(403).json({ error: 'El usuario autenticado no pertenece a un negocio.' });
    return null;
  }
  return id;
}



function readAmount(value, allowZero = false) {
  const amount = Number(value);
  if (!Number.isFinite(amount) || amount > 99999999.99 || amount < (allowZero ? 0 : 0.01)) return null;
  if (Math.abs(amount * 100 - Math.round(amount * 100)) > 0.000001) return null;
  return amount;
}

async function getReservation(pool, reservaId, negocioId) {
  const result = await pool.request()
    .input('reserva_id', sql.Int, reservaId)
    .input('negocio_id', sql.Int, negocioId)
    .execute('renta.usp_Reserva_ObtenerPorId');
  const sets = result.recordsets || [];
  return {
    reserva: sets[0]?.[0] || null,
    detalles: sets[1] || [],
    pagos: sets[2] || [],
    depositos: sets[3] || []
  };
}

router.get('/clientes', ...staff, async (req, res, next) => {
  try {
    const pool = await getPool();
    const roles = await pool.request().execute('renta.usp_Rol_Listar');
    const clientRole = (roles.recordset || []).find(role => role.nombre === 'Cliente');
    if (!clientRole) return res.status(503).json({ error: 'No está configurado el rol Cliente.' });
    const result = await pool.request()
      .input('rol_id', sql.Int, clientRole.rol_id)
      .execute('renta.usp_Usuario_Listar');
    return res.json({ datos: result.recordset || [] });
  } catch (error) {
    return next(error);
  }
});

router.get('/metodos-pago', ...staff, async (_req, res, next) => {
  try {
    const pool = await getPool();
    const result = await pool.request().execute('renta.usp_MetodoPago_Listar');
    return res.json({ datos: result.recordset || [] });
  } catch (error) {
    return next(error);
  }
});

router.get('/reservas', ...staff, async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const estado = typeof req.query.estado === 'string' && req.query.estado.trim()
    ? req.query.estado.trim()
    : null;
  if (estado && !['Pendiente', 'Confirmada', 'En curso', 'Completada', 'Cancelada'].includes(estado)) {
    return res.status(400).json({ error: 'estado no es un estado de reserva válido.' });
  }
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('negocio_id', sql.Int, negocioId)
      .input('estado', sql.VarChar(20), estado)
      .input('cliente_id', sql.Int, null)
      .input('desde', sql.DateTime, null)
      .input('hasta', sql.DateTime, null)
      .execute('renta.usp_Reserva_Listar');
    return res.json({ datos: result.recordset || [] });
  } catch (error) {
    return next(error);
  }
});
router.get('/reservas/proximas', ...staff, async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const dias = req.query.dias === undefined ? 30 : Number(req.query.dias);
  if (!Number.isInteger(dias) || dias < 0 || dias > 365) {
    return res.status(400).json({ error: 'dias debe ser un entero entre 0 y 365.' });
  }
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('negocio_id', sql.Int, negocioId)
      .input('dias', sql.Int, dias)
      .execute('renta.usp_Reserva_Proximas');
    return res.json({ datos: result.recordset || [] });
  } catch (error) {
    return next(error);
  }
});

router.get('/reservas/:reserva_id', ...staff, async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const reservaId = readPositiveId(req.params.reserva_id);
  if (!reservaId) return res.status(400).json({ error: 'reserva_id debe ser un entero positivo.' });
  try {
    const pool = await getPool();
    const data = await getReservation(pool, reservaId, negocioId);
    return res.json(data);
  } catch (error) {
    return next(error);
  }
});

router.post('/reservas', authenticate, requireRoles('Operador'), async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const clienteId = readPositiveId(req.body?.cliente_id);
  const equipoIds = req.body?.equipo_ids;
  const tipoReserva = req.body?.tipo_reserva;
  const fechaInicioSolicitada = readBusinessDate(req.body?.fecha_inicio);
  const fechaFin = readBusinessDate(req.body?.fecha_fin);
  const operadorId = readPositiveId(req.auth?.sub);
  if (!clienteId) return res.status(400).json({ error: 'cliente_id debe ser un entero positivo.' });
  if (!Array.isArray(equipoIds) || equipoIds.length < 1 || equipoIds.length > 20 ||
      equipoIds.some(id => !readPositiveId(id)) || new Set(equipoIds.map(Number)).size !== equipoIds.length) {
    return res.status(400).json({ error: 'equipo_ids debe contener entre 1 y 20 identificadores positivos sin repetir.' });
  }
  if (!allowedReservationTypes.has(tipoReserva)) {
    return res.status(400).json({ error: 'tipo_reserva debe ser Anticipada o Walk-in.' });
  }
  if (!fechaInicioSolicitada || !fechaFin) {
    return res.status(400).json({ error: 'Indique fechas válidas.' });
  }
  const fechaInicio = tipoReserva === 'Walk-in'
    ? new Date(Date.now() - 60_000)
    : fechaInicioSolicitada;
  if (tipoReserva === 'Anticipada' && fechaFin <= fechaInicio) {
    return res.status(400).json({ error: 'La fecha final debe ser posterior al inicio de la reserva.' });
  }
  if (tipoReserva === 'Walk-in' && !operadorId) {
    return res.status(403).json({ error: 'Walk-in requiere una sesión de Operador válida.' });
  }
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('negocio_id', sql.Int, negocioId)
      .input('cliente_id', sql.Int, clienteId)
      .input('operador_id', sql.Int, operadorId)
      .input('tipo_reserva', sql.VarChar(20), tipoReserva)
      .input('fecha_inicio', sql.DateTime, fechaInicio)
      .input('fecha_fin', sql.DateTime, fechaFin)
      .input('equipos_json', sql.NVarChar(sql.MAX), JSON.stringify(equipoIds.map(Number)))
      .output('reserva_id', sql.Int)
      .execute('renta.usp_Reserva_Crear');
    const reservaId = result.output.reserva_id;
    const data = await getReservation(pool, reservaId, negocioId);
    return res.status(201).json({ reserva_id: reservaId, ...data });
  } catch (error) {
    return next(error);
  }
});

router.post('/reservas/:reserva_id/pagos', ...staff, async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const reservaId = readPositiveId(req.params.reserva_id);
  const metodoPagoId = readPositiveId(req.body?.metodo_pago_id);
  const monto = readAmount(req.body?.monto);
  if (!reservaId) return res.status(400).json({ error: 'reserva_id debe ser un entero positivo.' });
  if (!metodoPagoId) return res.status(400).json({ error: 'metodo_pago_id debe ser un entero positivo.' });
  if (monto === null) return res.status(400).json({ error: 'monto debe ser mayor que cero y tener máximo dos decimales.' });
  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('reserva_id', sql.Int, reservaId)
      .input('negocio_id', sql.Int, negocioId)
      .input('metodo_pago_id', sql.Int, metodoPagoId)
      .input('monto', sql.Decimal(10, 2), monto)
      .output('pago_id', sql.Int)
      .execute('renta.usp_Pago_Registrar');
    const data = await getReservation(pool, reservaId, negocioId);
    return res.status(201).json({ pago_id: result.output.pago_id, ...data });
  } catch (error) {
    return next(error);
  }
});

router.post('/reservas/:reserva_id/entrega', ...staff, async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const reservaId = readPositiveId(req.params.reserva_id);
  const usuarioId = readPositiveId(req.auth?.sub);
  if (!reservaId) return res.status(400).json({ error: 'reserva_id debe ser un entero positivo.' });
  if (!usuarioId) return res.status(403).json({ error: 'La sesion no identifica un empleado valido.' });
  try {
    const pool = await getPool();
    await pool.request()
      .input('reserva_id', sql.Int, reservaId)
      .input('negocio_id', sql.Int, negocioId)
      .input('usuario_id', sql.Int, usuarioId)
      .execute('renta.usp_Reserva_Entregar');
    return res.json({ mensaje: 'Equipos entregados.', ...await getReservation(pool, reservaId, negocioId) });
  } catch (error) { return next(error); }
});
router.post('/devoluciones/:detalle_id', ...staff, async (req, res, next) => {
  const negocioId = readBusinessId(req, res);
  if (!negocioId) return;
  const detalleId = readPositiveId(req.params.detalle_id);
  const usuarioId = readPositiveId(req.auth?.sub);
  const estado = req.body?.estado_devolucion;
  if (!detalleId) return res.status(400).json({ error: 'detalle_id debe ser un entero positivo.' });
  if (!allowedReturnStates.has(estado)) {
    return res.status(400).json({ error: 'estado_devolucion debe ser Bueno, Averiado o Perdido.' });
  }
  const montoDevuelto = req.body?.monto_devuelto === undefined ? null : readAmount(req.body.monto_devuelto, true);
  const montoRetencion = req.body?.monto_retencion === undefined ? null : readAmount(req.body.monto_retencion, true);
  if (req.body?.monto_devuelto !== undefined && montoDevuelto === null) return res.status(400).json({ error: 'monto_devuelto no es válido.' });
  if (req.body?.monto_retencion !== undefined && montoRetencion === null) return res.status(400).json({ error: 'monto_retencion no es válido.' });
  try {
    const pool = await getPool();
    await pool.request()
      .input('detalle_id', sql.Int, detalleId)
      .input('negocio_id', sql.Int, negocioId)
      .input('estado_devolucion', sql.VarChar(20), estado)
      .input('monto_devuelto', sql.Decimal(10, 2), montoDevuelto)
      .input('monto_retencion', sql.Decimal(10, 2), montoRetencion)
      .input('usuario_id', sql.Int, usuarioId)
      .execute('renta.usp_Equipo_Devolver');
    return res.json({ mensaje: 'Devolución registrada.', detalle_id: detalleId, estado_devolucion: estado });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;
