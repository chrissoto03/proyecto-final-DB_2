'use strict';

const { Router } = require('express');
const rateLimit = require('express-rate-limit');
const jwt = require('jsonwebtoken');
const config = require('../config');
const { getPool, sql } = require('../db');

const router = Router();
const loginLimit = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-8',
  legacyHeaders: false
});

router.post('/login', loginLimit, async (req, res, next) => {
  const { email, password } = req.body || {};
  if (typeof email !== 'string' || !email.trim() || email.length > 100 ||
      typeof password !== 'string' || !password || password.length > 100) {
    return res.status(400).json({ error: 'Correo y contrasena son obligatorios.' });
  }

  try {
    const pool = await getPool();
    const result = await pool.request()
      .input('email', sql.VarChar(100), email.trim())
      .input('password', sql.NVarChar(100), password)
      .execute('renta.usp_Auth_ValidarCredenciales');
    const user = result.recordset && result.recordset[0];
    if (!user) return res.status(401).json({ error: 'Credenciales invalidas.' });

    const token = jwt.sign({
      rol: user.rol,
      negocio_id: user.negocio_id,
      email: user.email
    }, config.jwtSecret, {
      algorithm: 'HS256',
      expiresIn: '8h',
      issuer: config.jwtIssuer,
      audience: config.jwtAudience,
      subject: String(user.usuario_id)
    });
    return res.json({ token, token_type: 'Bearer', expires_in: 28800, usuario: user });
  } catch (error) {
    return next(error);
  }
});

module.exports = router;