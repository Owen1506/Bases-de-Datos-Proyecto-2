// Carga inicial del catálogo y del inventario. No configura replicación.
// Uso: node scripts/fragmentacion.js exportar|cargar|verificar
const fs = require('node:fs');
const path = require('node:path');
const sql = require('mssql');
require('dotenv').config({ path: path.resolve(__dirname, '../../../.env'), quiet: true });

const carpeta = path.resolve(__dirname, '../../../backups/fragmentacion');
const archivo = path.join(carpeta, 'carga_inicial.json');
const nodos = [
  { nombre: 'Corporativo', puerto: 1436, base: 'WideWorldImporters_Corporativo', clave: 'MSSQL_CORPORATIVO_PASSWORD' },
  { nombre: 'SanJose', puerto: 1434, base: 'WideWorldImporters_SanJose', clave: 'MSSQL_SANJOSE_PASSWORD' },
  { nombre: 'Limon', puerto: 1435, base: 'WideWorldImporters_Limon', clave: 'MSSQL_LIMON_PASSWORD' }
];

const columnasProducto = [
  ['ProductoID', sql.Int], ['Nombre', sql.NVarChar(100)], ['ProveedorID', sql.Int],
  ['ColorID', sql.Int], ['UnidadEmpaqueID', sql.Int], ['EmpaqueExteriorID', sql.Int],
  ['Marca', sql.NVarChar(50)], ['Tamano', sql.NVarChar(20)], ['DiasEntrega', sql.Int],
  ['CantidadPorEmpaque', sql.Int], ['EsRefrigerado', sql.Bit], ['CodigoBarras', sql.NVarChar(50)],
  ['Impuesto', sql.Decimal(18, 3)], ['PrecioUnitario', sql.Decimal(18, 2)],
  ['PrecioVenta', sql.Decimal(18, 2)], ['Peso', sql.Decimal(18, 3)],
  ['ComentariosMarketing', sql.NVarChar(sql.MAX)]
];

const consultaProductos = `SELECT
  StockItemID AS ProductoID, StockItemName AS Nombre, SupplierID AS ProveedorID,
  ColorID, UnitPackageID AS UnidadEmpaqueID, OuterPackageID AS EmpaqueExteriorID,
  Brand AS Marca, Size AS Tamano, LeadTimeDays AS DiasEntrega,
  QuantityPerOuter AS CantidadPorEmpaque, IsChillerStock AS EsRefrigerado,
  Barcode AS CodigoBarras, TaxRate AS Impuesto, UnitPrice AS PrecioUnitario,
  RecommendedRetailPrice AS PrecioVenta, TypicalWeightPerUnit AS Peso,
  MarketingComments AS ComentariosMarketing
FROM Warehouse.StockItems ORDER BY StockItemID`;

const consultaDestino = `SELECT ProductoID, Nombre, ProveedorID, ColorID, UnidadEmpaqueID,
  EmpaqueExteriorID, Marca, Tamano, DiasEntrega, CantidadPorEmpaque, EsRefrigerado,
  CodigoBarras, Impuesto, PrecioUnitario, PrecioVenta, Peso, ComentariosMarketing
FROM catalogo.Productos ORDER BY ProductoID`;

function configuracion(nodo) {
  const password = process.env[nodo.clave];
  if (!password) throw new Error(`Falta ${nodo.clave} en .env`);
  return {
    user: 'sa', password, server: 'localhost', port: nodo.puerto, database: nodo.base,
    options: { encrypt: true, trustServerCertificate: true }
  };
}

function cantidadPara(nodo, cantidad) {
  return nodo.nombre === 'SanJose' ? Math.ceil(cantidad / 2) : Math.floor(cantidad / 2);
}

function datosGuardados() {
  const datos = JSON.parse(fs.readFileSync(archivo, 'utf8'));
  if (datos.version !== 1 || !Array.isArray(datos.productos) ||
      !Array.isArray(datos.grupos) || !Array.isArray(datos.existencias)) {
    throw new Error('El archivo de carga no tiene el formato esperado.');
  }
  if (!datos.productos.length || !datos.existencias.length) {
    throw new Error('El origen no contiene productos o existencias.');
  }
  const ids = new Set(datos.productos.map(p => p.ProductoID));
  if (ids.size !== datos.productos.length ||
      datos.grupos.some(g => !ids.has(g.ProductoID)) ||
      datos.existencias.some(e => !ids.has(e.ProductoID) || !Number.isInteger(e.CantidadOriginal) || e.CantidadOriginal < 0) ||
      new Set(datos.existencias.map(e => e.ProductoID)).size !== datos.existencias.length ||
      datos.existencias.length !== datos.productos.length) {
    throw new Error('El archivo tiene IDs duplicados, productos sin existencias o cantidades inválidas.');
  }
  return datos;
}

async function exportar() {
  const clave = process.env.MSSQL_SA_PASSWORD;
  if (!clave) throw new Error('Falta MSSQL_SA_PASSWORD en .env');
  const pool = await new sql.ConnectionPool({
    user: 'sa', password: clave, server: 'localhost', port: 1433,
    database: 'WideWorldImporters', options: { encrypt: true, trustServerCertificate: true }
  }).connect();
  try {
    const tx = new sql.Transaction(pool);
    await tx.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
    let productos, grupos, existencias;
    try {
      productos = (await new sql.Request(tx).query(consultaProductos)).recordset;
      grupos = (await new sql.Request(tx).query(`SELECT StockItemID AS ProductoID, StockGroupID AS GrupoID
        FROM Warehouse.StockItemStockGroups ORDER BY StockItemID, StockGroupID`)).recordset;
      existencias = (await new sql.Request(tx).query(`SELECT StockItemID AS ProductoID,
        QuantityOnHand AS CantidadOriginal FROM Warehouse.StockItemHoldings ORDER BY StockItemID`)).recordset;
      await tx.commit();
    } catch (error) {
      await tx.rollback();
      throw error;
    }
    fs.mkdirSync(carpeta, { recursive: true });
    if (fs.existsSync(archivo)) throw new Error(`Ya existe ${archivo}. Revíselo antes de generar otra carga.`);
    fs.writeFileSync(archivo, JSON.stringify({ version: 1, productos, grupos, existencias }, null, 2), { flag: 'wx', mode: 0o600 });
    datosGuardados();
    console.log(`Exportados ${productos.length} productos, ${grupos.length} grupos y ${existencias.length} existencias a ${archivo}`);
  } finally {
    await pool.close();
  }
}

async function revisarEstructura(pool, nodo) {
  const r = await pool.request().query(`SELECT
    OBJECT_ID(N'catalogo.Productos', N'U') AS Productos,
    OBJECT_ID(N'catalogo.ProductoGrupos', N'U') AS Grupos,
    OBJECT_ID(N'inventario.Existencias', N'U') AS Existencias`);
  const tablas = r.recordset[0];
  if (!tablas.Productos || !tablas.Grupos || (nodo.nombre !== 'Corporativo' && !tablas.Existencias)) {
    throw new Error(`Faltan tablas de fragmentación en ${nodo.nombre}. Ejecute primero los scripts SQL 01 y 02.`);
  }
  if (nodo.nombre === 'Corporativo' && tablas.Existencias) {
    throw new Error('Corporativo no debe contener inventario.Existencias.');
  }
}

async function insertarProducto(tx, producto) {
  const r = new sql.Request(tx);
  for (const [columna, tipo] of columnasProducto) r.input(columna, tipo, producto[columna]);
  await r.query(`INSERT INTO catalogo.Productos (${columnasProducto.map(([c]) => c).join(', ')})
    VALUES (${columnasProducto.map(([c]) => '@' + c).join(', ')})`);
}

async function cargarNodo(nodo, datos) {
  const pool = await new sql.ConnectionPool(configuracion(nodo)).connect();
  try {
    await revisarEstructura(pool, nodo);
    const tx = new sql.Transaction(pool);
    await tx.begin();
    try {
      const r = await new sql.Request(tx).query(`SELECT
        (SELECT COUNT(*) FROM catalogo.Productos) AS Productos,
        (SELECT COUNT(*) FROM catalogo.ProductoGrupos) AS Grupos` +
        (nodo.nombre === 'Corporativo' ? '' : `,
        (SELECT COUNT(*) FROM inventario.Existencias) AS Existencias`));
      if (Object.values(r.recordset[0]).some(n => n !== 0)) {
        throw new Error(`${nodo.nombre} ya tiene datos en las tablas de fragmentación; se detuvo para no duplicarlos.`);
      }
      for (const p of datos.productos) await insertarProducto(tx, p);
      for (const g of datos.grupos) {
        await new sql.Request(tx).input('ProductoID', sql.Int, g.ProductoID)
          .input('GrupoID', sql.Int, g.GrupoID)
          .query(`INSERT INTO catalogo.ProductoGrupos (ProductoID, GrupoID) VALUES (@ProductoID, @GrupoID)`);
      }
      if (nodo.nombre !== 'Corporativo') {
        for (const e of datos.existencias) {
          await new sql.Request(tx).input('ProductoID', sql.Int, e.ProductoID)
            .input('Cantidad', sql.Int, cantidadPara(nodo, e.CantidadOriginal))
            .query(`INSERT INTO inventario.Existencias (ProductoID, CantidadDisponible)
              VALUES (@ProductoID, @Cantidad)`);
        }
      }
      await tx.commit();
      console.log(`${nodo.nombre}: carga completada.`);
    } catch (error) {
      await tx.rollback();
      throw error;
    }
  } finally {
    await pool.close();
  }
}

function iguales(a, b) { return JSON.stringify(a) === JSON.stringify(b); }

async function verificarNodo(nodo, datos) {
  const pool = await new sql.ConnectionPool(configuracion(nodo)).connect();
  try {
    await revisarEstructura(pool, nodo);
    const productos = (await pool.request().query(consultaDestino)).recordset;
    const grupos = (await pool.request().query(`SELECT ProductoID, GrupoID FROM catalogo.ProductoGrupos
      ORDER BY ProductoID, GrupoID`)).recordset;
    if (!iguales(productos, datos.productos) || !iguales(grupos, datos.grupos)) {
      throw new Error(`El catálogo de ${nodo.nombre} no coincide con el JSON de origen.`);
    }
    if (nodo.nombre !== 'Corporativo') {
      const existencias = (await pool.request().query(`SELECT ProductoID, CantidadDisponible
        FROM inventario.Existencias ORDER BY ProductoID`)).recordset;
      const esperadas = datos.existencias.map(e => ({
        ProductoID: e.ProductoID, CantidadDisponible: cantidadPara(nodo, e.CantidadOriginal)
      }));
      if (!iguales(existencias, esperadas)) {
        throw new Error(`Las existencias de ${nodo.nombre} no corresponden al reparto inicial.`);
      }
    }
    console.log(`${nodo.nombre}: ${productos.length} productos y ${grupos.length} relaciones correctas.`);
  } finally {
    await pool.close();
  }
}

async function main() {
  const accion = process.argv[2];
  if (accion === 'exportar') return exportar();
  if (!['cargar', 'verificar'].includes(accion)) {
    throw new Error('Uso: node scripts/fragmentacion.js exportar|cargar|verificar');
  }
  const datos = datosGuardados();
  if (accion === 'cargar') {
    // Comprobar todos los nodos antes de escribir en alguno. Una carga completa
    // se puede omitir; una carga distinta o parcial detiene todo el proceso.
    const pendientes = [];
    for (const nodo of nodos) {
      const pool = await new sql.ConnectionPool(configuracion(nodo)).connect();
      try {
        await revisarEstructura(pool, nodo);
        const r = await pool.request().query(`SELECT
          (SELECT COUNT(*) FROM catalogo.Productos) AS Productos,
          (SELECT COUNT(*) FROM catalogo.ProductoGrupos) AS Grupos` +
          (nodo.nombre === 'Corporativo' ? '' : `,
          (SELECT COUNT(*) FROM inventario.Existencias) AS Existencias`));
        if (Object.values(r.recordset[0]).every(n => n === 0)) pendientes.push(nodo);
        else await verificarNodo(nodo, datos);
      } finally { await pool.close(); }
    }
    for (const nodo of pendientes) await cargarNodo(nodo, datos);
  }
  for (const nodo of nodos) await verificarNodo(nodo, datos);
  const total = datos.existencias.reduce((suma, e) => suma + e.CantidadOriginal, 0);
  console.log(`Reparto verificado: ${total} unidades originales = San José + Limón.`);
}

main().catch(error => { console.error(error.message); process.exitCode = 1; });
