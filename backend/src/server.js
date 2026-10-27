'use strict';

const app = require('./app');
const config = require('./config');
const { getPool, pool } = require('./db');

async function start() {
  await getPool();
  const server = app.listen(config.port, () => {
    console.log('RentaTica API escuchando en http://localhost:' + config.port);
  });

  const shutdown = async () => {
    server.close(async () => {
      await pool.close();
      process.exit(0);
    });
  };
  process.once('SIGINT', shutdown);
  process.once('SIGTERM', shutdown);
}

start().catch((error) => {
  console.error('No se pudo iniciar la API. Revise .env, SQL Server y los procedimientos instalados.');
  console.error(error.code || error.name || 'Error de inicio');
  process.exit(1);
});