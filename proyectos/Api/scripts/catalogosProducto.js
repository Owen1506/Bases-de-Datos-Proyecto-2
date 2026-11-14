// Uso: node scripts/catalogosProducto.js exportar|cargar|verificar
const fs = require('node:fs');
const path = require('node:path');
const sql = require('mssql');
require('dotenv').config({ path: path.resolve(__dirname, '../../../.env'), quiet: true });

const archivo = path.resolve(__dirname, '../../../backups/fragmentacion/catalogos_referencia.json');
const nodos = [
  { nombre: 'Corporativo', puerto: 1436, base: 'WideWorldImporters_Corporativo', clave: 'MSSQL_CORPORATIVO_PASSWORD' },
  { nombre: 'SanJose', puerto: 1434, base: 'WideWorldImporters_SanJose', clave: 'MSSQL_SANJOSE_PASSWORD' },
  { nombre: 'Limon', puerto: 1435, base: 'WideWorldImporters_Limon', clave: 'MSSQL_LIMON_PASSWORD' }
];

const catalogos = [
  {
    clave: 'proveedores', tabla: 'Purchasing.Suppliers', id: 'SupplierID', jsonId: 'ProveedorID', nombre: 'SupplierName',
    origen: 'Purchasing.Suppliers', columnaId: 'SupplierID', columnaNombre: 'SupplierName'
  },
  {
    clave: 'grupos', tabla: 'Warehouse.StockGroups', id: 'StockGroupID', jsonId: 'GrupoID', nombre: 'StockGroupName',
    origen: 'Warehouse.StockGroups', columnaId: 'StockGroupID', columnaNombre: 'StockGroupName'
  },
  {
    clave: 'colores', tabla: 'Warehouse.Colors', id: 'ColorID', jsonId: 'ColorID', nombre: 'ColorName',
    origen: 'Warehouse.Colors', columnaId: 'ColorID', columnaNombre: 'ColorName'
  },
  {
    clave: 'empaques', tabla: 'Warehouse.PackageTypes', id: 'PackageTypeID', jsonId: 'TipoEmpaqueID', nombre: 'PackageTypeName',
    origen: 'Warehouse.PackageTypes', columnaId: 'PackageTypeID', columnaNombre: 'PackageTypeName'
  }
];

function config(nodo) {
  const password = process.env[nodo.clave];
  if (!password) throw new Error(`Falta ${nodo.clave} en .env`);
  return {
    user: 'sa', password, server: 'localhost', port: nodo.puerto, database: nodo.base,
    options: { encrypt: true, trustServerCertificate: true }
  };
}

function validar(datos) {
  if (datos.version !== 1) throw new Error('Versión de archivo de catálogos no reconocida.');
  for (const c of catalogos) {
    const filas = datos[c.clave];
    if (!Array.isArray(filas) || filas.length === 0) throw new Error(`Falta el catálogo ${c.clave}.`);
    const ids = new Set();
    for (const fila of filas) {
      if (!Number.isInteger(fila[c.jsonId]) || ids.has(fila[c.jsonId]) ||
          typeof fila.Nombre !== 'string' || !fila.Nombre.trim()) {
        throw new Error(`El catálogo ${c.clave} tiene IDs o nombres inválidos.`);
      }
      ids.add(fila[c.jsonId]);
    }
  }
  return datos;
}

function leerArchivo() { return validar(JSON.parse(fs.readFileSync(archivo, 'utf8'))); }

async function exportar() {
  if (fs.existsSync(archivo)) throw new Error(`Ya existe ${archivo}; no se reemplazó.`);
  const password = process.env.MSSQL_SA_PASSWORD;
  if (!password) throw new Error('Falta MSSQL_SA_PASSWORD en .env');
  const pool = await new sql.ConnectionPool({
    user: 'sa', password, server: 'localhost', port: 1433,
    database: 'WideWorldImporters', options: { encrypt: true, trustServerCertificate: true }
  }).connect();
  try {
    const tx = new sql.Transaction(pool);
    await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
    const datos = { version: 1 };
    try {
      for (const c of catalogos) {
        const consulta = `SELECT ${c.columnaId} AS ${c.jsonId}, ${c.columnaNombre} AS Nombre
          FROM ${c.origen} ORDER BY ${c.columnaId}`;
        datos[c.clave] = (await new sql.Request(tx).query(consulta)).recordset;
      }
      await tx.commit();
    } catch (error) {
      await tx.rollback();
      throw error;
    }
    validar(datos);
    fs.mkdirSync(path.dirname(archivo), { recursive: true });
    fs.writeFileSync(archivo, JSON.stringify(datos, null, 2), { flag: 'wx', mode: 0o600 });
    console.log(`Catálogos exportados a ${archivo}. Solo contienen IDs y nombres.`);
  } finally { await pool.close(); }
}

async function revisarTablas(pool, nodo) {
  const nombres = ['Warehouse.StockItems', 'Warehouse.StockItemStockGroups', ...catalogos.map(c => c.tabla)];
  const campos = nombres.map((n, i) => `OBJECT_ID(N'${n}', N'U') AS Tabla${i}`).join(', ');
  const r = await pool.request().query(`SELECT ${campos}`);
  if (Object.values(r.recordset[0]).some(id => !id)) {
    throw new Error(`Faltan tablas de productos o referencias en ${nodo.nombre}. Ejecute 01 y 04.`);
  }
}

async function verificarReferencias(pool, nodo) {
  const r = await pool.request().query(`SELECT
    (SELECT COUNT(*) FROM Warehouse.StockItems) AS Productos,
    (SELECT COUNT(*) FROM Warehouse.StockItems p
      LEFT JOIN Purchasing.Suppliers s ON s.SupplierID = p.SupplierID
      LEFT JOIN Warehouse.Colors c ON c.ColorID = p.ColorID
      LEFT JOIN Warehouse.PackageTypes u ON u.PackageTypeID = p.UnitPackageID
      LEFT JOIN Warehouse.PackageTypes e ON e.PackageTypeID = p.OuterPackageID
      WHERE s.SupplierID IS NULL
         OR (p.ColorID IS NOT NULL AND c.ColorID IS NULL)
         OR u.PackageTypeID IS NULL OR e.PackageTypeID IS NULL) AS ProductosInvalidos,
    (SELECT COUNT(*) FROM Warehouse.StockItemStockGroups pg
      LEFT JOIN Warehouse.StockGroups g ON g.StockGroupID = pg.StockGroupID
      WHERE g.StockGroupID IS NULL) AS GruposInvalidos`);
  const { Productos, ProductosInvalidos, GruposInvalidos } = r.recordset[0];
  if (!Productos || ProductosInvalidos || GruposInvalidos) {
    throw new Error(`${nodo.nombre}: ${ProductosInvalidos} productos y ${GruposInvalidos} grupos con referencias inválidas, o faltan productos.`);
  }
}

async function estadoNodo(nodo, datos) {
  const pool = await new sql.ConnectionPool(config(nodo)).connect();
  try {
    await revisarTablas(pool, nodo);
    const cantidades = await Promise.all(catalogos.map(async c => {
      const r = await pool.request().query(`SELECT COUNT(*) AS Total FROM ${c.tabla}`);
      return r.recordset[0].Total;
    }));
    if (cantidades.every(n => n === 0)) return 'vacio';
    await verificarNodoConPool(pool, nodo, datos);
    return 'cargado';
  } finally { await pool.close(); }
}

async function cargarNodo(nodo, datos) {
  const pool = await new sql.ConnectionPool(config(nodo)).connect();
  try {
    const tx = new sql.Transaction(pool);
    await tx.begin();
    try {
      for (const c of catalogos) {
        const r = await new sql.Request(tx).query(`SELECT COUNT(*) AS Total FROM ${c.tabla}`);
        if (r.recordset[0].Total !== 0) throw new Error(`${nodo.nombre} ya tiene datos en ${c.tabla}.`);
        for (const fila of datos[c.clave]) {
          await new sql.Request(tx)
            .input('Id', sql.Int, fila[c.jsonId])
            .input('Nombre', sql.NVarChar(100), fila.Nombre)
            .query(`INSERT INTO ${c.tabla} (${c.id}, ${c.nombre}) VALUES (@Id, @Nombre)`);
        }
      }
      await tx.commit();
      console.log(`${nodo.nombre}: catálogos cargados.`);
    } catch (error) {
      await tx.rollback();
      throw error;
    }
  } finally { await pool.close(); }
}

async function verificarNodoConPool(pool, nodo, datos) {
  for (const c of catalogos) {
    const filas = (await pool.request().query(`SELECT ${c.id} AS ${c.jsonId}, ${c.nombre} AS Nombre FROM ${c.tabla}
      ORDER BY ${c.id}`)).recordset;
    if (JSON.stringify(filas) !== JSON.stringify(datos[c.clave])) {
      throw new Error(`${nodo.nombre}: ${c.tabla} no coincide con el JSON de origen.`);
    }
  }
  await verificarReferencias(pool, nodo);
}

async function verificarNodo(nodo, datos) {
  const pool = await new sql.ConnectionPool(config(nodo)).connect();
  try {
    await revisarTablas(pool, nodo);
    await verificarNodoConPool(pool, nodo, datos);
    console.log(`${nodo.nombre}: catálogos y referencias correctos.`);
  } finally { await pool.close(); }
}

async function main() {
  const accion = process.argv[2];
  if (accion === 'exportar') return exportar();
  if (!['cargar', 'verificar'].includes(accion)) {
    throw new Error('Uso: node scripts/catalogosProducto.js exportar|cargar|verificar');
  }
  const datos = leerArchivo();
  if (accion === 'cargar') {
    // Todos los destinos se revisan antes de escribir. Los ya completos se omiten.
    const pendientes = [];
    for (const nodo of nodos) if (await estadoNodo(nodo, datos) === 'vacio') pendientes.push(nodo);
    for (const nodo of pendientes) await cargarNodo(nodo, datos);
  }
  for (const nodo of nodos) await verificarNodo(nodo, datos);
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
