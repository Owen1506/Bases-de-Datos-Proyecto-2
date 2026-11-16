const sql = require('mssql');
const { conectarCorporativo } = require('./dbCorporativo');

function configSucursal(puerto, clave, baseDatos) {
  return {
    user: 'api_sucursal',
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
    pool: new sql.ConnectionPool(configSucursal(1434, process.env.API_SUCURSAL_PASSWORD, 'WideWorldImporters_SanJose'))
  },
  2: {
    nombre: 'Limón',
    pool: new sql.ConnectionPool(configSucursal(1435, process.env.API_SUCURSAL_PASSWORD, 'WideWorldImporters_Limon'))
  }
};

// Error con el estado HTTP que debe responder la API
function errorConEstado(estado, mensaje) {
  const error = new Error(mensaje);
  error.estado = estado;
  return error;
}

// Ejecuta el SP; si el nodo no responde lanza un error 503 con su nombre
async function ejecutarEnNodo(conectar, nombreNodo, nombre, parametros, contexto = {}, completo = false) {
  try {
    const pool = await conectar();
    const request = pool.request();

    for (const clave in parametros) {
      request.input(clave, parametros[clave]);
    }

    if (!/^dbo\.[A-Za-z_][A-Za-z0-9_]*$/.test(nombre) ||
        Object.keys(parametros).some(clave => !/^[A-Za-z][A-Za-z0-9_]*$/.test(clave))) {
      throw new Error('Nombre de procedimiento o parámetro inválido.');
    }
    request.input('__sucursal', sql.Int, contexto.SucursalID ?? null);
    request.input('__usuario', sql.Int, contexto.iduser ?? null);
    // Una sola petición mantiene el contexto y el EXEC en la misma conexión del pool.
    // Se sobrescriben ambos valores en cada llamada para no heredar otra sesión.
    const argumentos = Object.keys(parametros).map(clave => `@${clave}=@${clave}`).join(', ');
    const resultado = await request.query(`
      SET ANSI_NULLS ON; SET ANSI_PADDING ON; SET ANSI_WARNINGS ON;
      SET ARITHABORT ON; SET CONCAT_NULL_YIELDS_NULL ON;
      SET QUOTED_IDENTIFIER ON; SET NUMERIC_ROUNDABORT OFF;
      EXEC sys.sp_set_session_context @key=N'SucursalID', @value=@__sucursal;
      EXEC sys.sp_set_session_context @key=N'iduser', @value=@__usuario;
      EXEC ${nombre} ${argumentos};
    `);
    return completo ? resultado : (resultado.recordset || []);
  } catch (error) {
    if (error instanceof sql.ConnectionError || ['ESOCKET', 'ECONNCLOSED', 'ETIMEOUT'].includes(error.code)) {
      throw errorConEstado(503, 'El nodo ' + nombreNodo + ' no está disponible en este momento. Intente más tarde.');
    }
    throw error;
  }
}

async function ejecutarSPCorporativo(nombre, parametros = {}, contexto = {}) {
  return ejecutarEnNodo(conectarCorporativo, 'Corporativo', nombre, parametros, contexto);
}

async function ejecutarSPReporte(nombre, parametros = {}) {
  if (!nombre.startsWith('dbo.usp_Reporte_')) throw new Error('Procedimiento de reporte inválido.');
  return ejecutarEnNodo(() => conectarCorporativo('corporativo'), 'Corporativo', nombre, parametros);
}

async function ejecutarSPSucursal(sucursalId, nombre, parametros = {}, contexto = {}, completo = false) {
  const sucursal = sucursales[sucursalId];

  if (!sucursal) {
    throw errorConEstado(400, 'Debe indicar una sucursal válida.');
  }

  return ejecutarEnNodo(() => sucursal.pool.connect(), sucursal.nombre, nombre, parametros,
    { ...contexto, SucursalID: Number(sucursalId) }, completo);
}

// Revisa qué nodos responden: true si el nodo contesta un SELECT 1
async function estadoNodos() {
  const conexiones = {
    'Corporativo': conectarCorporativo,
    'San José': () => sucursales[1].pool.connect(),
    'Limón': () => sucursales[2].pool.connect()
  };
  const estado = {};

  for (const nodo in conexiones) {
    try {
      const pool = await conexiones[nodo]();
      await pool.request().query('SELECT 1');
      estado[nodo] = true;
    } catch (error) {
      estado[nodo] = false;
    }
  }
  return estado;
}

async function cerrarConexiones() {
  await Promise.all(Object.values(sucursales).map(sucursal => sucursal.pool.close()));
  await require('./dbCorporativo').cerrarCorporativo();
}
module.exports = { ejecutarSPCorporativo, ejecutarSPReporte, ejecutarSPSucursal, estadoNodos, cerrarConexiones };
