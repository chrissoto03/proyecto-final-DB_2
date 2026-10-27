'use strict';

const sql = require('mssql/msnodesqlv8');
const config = require('./config');

const pool = new sql.ConnectionPool({
  server: config.dbServer,
  database: config.dbName,
  options: {
    trustedConnection: true,
    trustServerCertificate: config.trustServerCertificate
  },
  pool: { min: 0, max: 10, idleTimeoutMillis: 30000 },
  connectionTimeout: 15000,
  requestTimeout: 30000
});

let connecting;
async function getPool() {
  if (pool.connected) return pool;
  if (!connecting) connecting = pool.connect().finally(() => { connecting = undefined; });
  await connecting;
  return pool;
}

module.exports = { sql, getPool, pool };