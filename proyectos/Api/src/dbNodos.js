const sql = require('mssql');
const { conectarCorporativo } = require('./dbCorporativo');

function configSucursal(puerto, clave, baseDatos) {
  return {
    user: 'sa',
    password: clave,
    server: 'localhost',
    port: puerto,
    database: baseDatos,
    connectionTimeout: 5000,
    requestTimeout: 15000,
    options: {
      encrypt: true,
      trustServerCertificate: true
    }
  };
}

// La llave es la SucursalID del usuario
const sucursales = {
  1: {
    nombre: 'San José',
    pool: new sql.ConnectionPool(configSucursal(1434, process.env.MSSQL_SANJOSE_PASSWORD, 'WideWorldImporters_SanJose'))
  },
  2: {
    nombre: 'Limón',
    pool: new sql.ConnectionPool(configSucursal(1435, process.env.MSSQL_LIMON_PASSWORD, 'WideWorldImporters_Limon'))
  }
};

// Error con el estado HTTP que debe responder la API
function errorConEstado(estado, mensaje) {
  const error = new Error(mensaje);
  error.estado = estado;
  return error;
}

// Ejecuta el SP; si el nodo no responde lanza un error 503 con su nombre
async function ejecutarEnNodo(conectar, nombreNodo, nombre, parametros) {
  try {
    const pool = await conectar();
    const request = pool.request();

    for (const clave in parametros) {
      request.input(clave, parametros[clave]);
    }

    const resultado = await request.execute(nombre);
    return resultado.recordset;
  } catch (error) {
    if (error instanceof sql.ConnectionError || ['ESOCKET', 'ECONNCLOSED', 'ETIMEOUT'].includes(error.code)) {
      throw errorConEstado(503, 'El nodo ' + nombreNodo + ' no está disponible en este momento. Intente más tarde.');
    }
    throw error;
  }
}

async function ejecutarSPCorporativo(nombre, parametros = {}) {
  return ejecutarEnNodo(conectarCorporativo, 'Corporativo', nombre, parametros);
}

async function ejecutarSPSucursal(sucursalId, nombre, parametros = {}) {
  const sucursal = sucursales[sucursalId];

  if (!sucursal) {
    throw errorConEstado(400, 'Debe indicar una sucursal válida.');
  }

  return ejecutarEnNodo(() => sucursal.pool.connect(), sucursal.nombre, nombre, parametros);
}

module.exports = { ejecutarSPCorporativo, ejecutarSPSucursal };
