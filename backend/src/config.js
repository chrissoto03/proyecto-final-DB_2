'use strict';

const path = require('node:path');
require('dotenv').config({ path: path.resolve(__dirname, '..', '.env') });

function required(name, fallback) {
  const value = process.env[name] || fallback;
  if (!value) throw new Error('Falta configurar ' + name + '. Copie .env.example a .env.');
  return value;
}

const jwtSecret = required('JWT_SECRET');
if (Buffer.byteLength(jwtSecret, 'utf8') < 32 || jwtSecret.startsWith('REEMPLAZAR_')) {
  throw new Error('JWT_SECRET debe ser aleatorio y tener al menos 32 bytes.');
}

module.exports = Object.freeze({
  port: Number(process.env.PORT || 3000),
  dbServer: required('DB_SERVER'),
  dbName: required('DB_NAME', 'RentaTicaDB'),
  trustServerCertificate: process.env.DB_TRUST_CERTIFICATE === 'true',
  jwtSecret,
  jwtIssuer: 'rentatica-api',
  jwtAudience: 'rentatica-client'
});
