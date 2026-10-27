'use strict';

const fs = require('node:fs');
const path = require('node:path');
const express = require('express');
const helmet = require('helmet');
const swaggerUi = require('swagger-ui-express');
const YAML = require('yaml');
const { pool } = require('./db');
const authRoutes = require('./routes/auth');
const equipoRoutes = require('./routes/equipos');
const reportRoutes = require('./routes/reportes');

const app = express();
app.disable('x-powered-by');
app.use(helmet({ contentSecurityPolicy: { directives: { scriptSrc: ["'self'", "'unsafe-inline'"], styleSrc: ["'self'", "'unsafe-inline'"] } } }));
app.use(express.json({ limit: '32kb' }));

const openapi = YAML.parse(fs.readFileSync(path.resolve(__dirname, '..', 'openapi.yaml'), 'utf8'));
app.use('/docs', swaggerUi.serve, swaggerUi.setup(openapi));
app.get('/openapi.yaml', (_req, res) => {
  res.type('text/yaml').sendFile(path.resolve(__dirname, '..', 'openapi.yaml'));
});

app.get('/health', (_req, res) => {
  if (!pool.connected) return res.status(503).json({ estado: 'degradado', sql_server: 'desconectado' });
  return res.json({ estado: 'disponible', sql_server: 'conectado' });
});
app.use('/api/auth', authRoutes);
app.use('/api/equipos', equipoRoutes);
app.use('/api/reportes', reportRoutes);
app.use((_req, res) => res.status(404).json({ error: 'Ruta no encontrada.' }));

app.use((error, _req, res, _next) => {
  const number = error.number || error.originalError?.info?.number;
  const sqlStatus = new Map([[50001, 404], [50002, 409], [50003, 400], [50004, 403], [50005, 401]]);
  const status = sqlStatus.get(number) || ((error.status >= 400 && error.status < 500) ? error.status : 500);
  if (number && sqlStatus.has(number)) {
    return res.status(status).json({ error: error.message, codigo_sql: number });
  }
  if (status === 500) console.error('Fallo de API/SQL:', error.code || error.name || 'error interno');
  return res.status(status).json({ error: status === 500 ? 'Error interno del servidor.' : error.message });
});

module.exports = app;
