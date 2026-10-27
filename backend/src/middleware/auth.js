'use strict';

const jwt = require('jsonwebtoken');
const config = require('../config');

function authenticate(req, res, next) {
  const header = req.get('authorization') || '';
  const [scheme, token] = header.split(' ');
  if (scheme !== 'Bearer' || !token) {
    return res.status(401).json({ error: 'Se requiere un token Bearer.' });
  }
  try {
    req.auth = jwt.verify(token, config.jwtSecret, {
      algorithms: ['HS256'],
      issuer: config.jwtIssuer,
      audience: config.jwtAudience
    });
    return next();
  } catch {
    return res.status(401).json({ error: 'El token es invalido o ha expirado.' });
  }
}

function requireRoles(...roles) {
  return (req, res, next) => {
    if (!req.auth || !roles.includes(req.auth.rol)) {
      return res.status(403).json({ error: 'El rol no tiene permiso para esta operacion.' });
    }
    return next();
  };
}

module.exports = { authenticate, requireRoles };