const sql = require('mssql');

const config = {
  user: 'sa',
  password: process.env.MSSQL_SA_PASSWORD,
  server: 'localhost',
  port: 1433,
  database: 'WideWorldImporters',
  options: {
    encrypt: true,
    trustServerCertificate: true
  }
};

// Ejecuta un stored procedure y devuelve las filas tal como vienen de la base.
// parametros es un objeto, por ejemplo { Nombre: 'toys', CategoriaID: 3 }
async function ejecutarSP(nombre, parametros = {}) {
  const pool = await sql.connect(config);
  const request = pool.request();

  for (const clave in parametros) {
    request.input(clave, parametros[clave]);
  }

  const resultado = await request.execute(nombre);
  return resultado.recordset;
}

module.exports = { ejecutarSP };
