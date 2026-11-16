
const sql = require('mssql');

require('dotenv').config({
  path: __dirname + '/../../../.env'
});

const configCorporativo = {
  server: 'localhost',
  port: 1436,
  database: 'WideWorldImporters_Corporativo',
  connectionTimeout: 5000,
  requestTimeout: 15000,
  options: {
    encrypt: true,
    trustServerCertificate: true
  }
};

const pools = {
  administrador: new sql.ConnectionPool({ ...configCorporativo, user: 'api_administrador', password: process.env.API_ADMIN_PASSWORD }),
  corporativo: new sql.ConnectionPool({ ...configCorporativo, user: 'api_corporativo', password: process.env.API_CORPORATIVO_PASSWORD }),
  login: new sql.ConnectionPool({ ...configCorporativo, user: 'api_login', password: process.env.API_LOGIN_PASSWORD })
};

async function conectarCorporativo(tipo = 'administrador') {
  if (!Object.hasOwn(pools, tipo)) throw new Error('Tipo de conexión corporativa inválido.');
  return pools[tipo].connect();
}

module.exports = { conectarCorporativo, cerrarCorporativo: () => Promise.all(Object.values(pools).map(pool => pool.close())) };
