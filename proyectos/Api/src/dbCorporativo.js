
const sql = require('mssql');

require('dotenv').config({
  path: __dirname + '/../../../.env'
});

const configCorporativo = {
  user: 'sa',
  password: process.env.MSSQL_CORPORATIVO_PASSWORD,
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

const poolCorporativo = new sql.ConnectionPool(configCorporativo);

async function conectarCorporativo() {
  return await poolCorporativo.connect();
}

module.exports = { conectarCorporativo };
