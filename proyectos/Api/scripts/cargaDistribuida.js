const fs = require('node:fs');
const path = require('node:path');
const sql = require('mssql');

require('dotenv').config({
  path: path.join(__dirname, '../../../.env'),
  quiet: true
});

const RAIZ = path.join(__dirname, '../../..');
const ARCHIVO_CARGA = path.join(RAIZ, 'backups/fragmentacion/carga_distribuida.json');
const MAXIMO_PARAMETROS_POR_LOTE = 1800;

const NODOS = {
  origen: configurarNodo(1433, process.env.MSSQL_SA_PASSWORD, 'WideWorldImporters'),
  corporativo: configurarNodo(1436, process.env.MSSQL_CORPORATIVO_PASSWORD, 'WideWorldImporters_Corporativo'),
  sanJose: configurarNodo(1434, process.env.MSSQL_SANJOSE_PASSWORD, 'WideWorldImporters_SanJose'),
  limon: configurarNodo(1435, process.env.MSSQL_LIMON_PASSWORD, 'WideWorldImporters_Limon')
};

function configurarNodo(port, password, database) {
  return {
    user: 'sa',
    password,
    server: 'localhost',
    port,
    database,
    connectionTimeout: 10000,
    requestTimeout: 300000,
    pool: { max: 5, min: 0, idleTimeoutMillis: 30000 },
    options: { encrypt: true, trustServerCertificate: true }
  };
}

function exigirConfiguracion() {
  const faltantes = [];
  if (!NODOS.origen.password) faltantes.push('MSSQL_SA_PASSWORD');
  if (!NODOS.corporativo.password) faltantes.push('MSSQL_CORPORATIVO_PASSWORD');
  if (!NODOS.sanJose.password) faltantes.push('MSSQL_SANJOSE_PASSWORD');
  if (!NODOS.limon.password) faltantes.push('MSSQL_LIMON_PASSWORD');
  if (faltantes.length) {
    throw new Error(`Faltan variables en .env: ${faltantes.join(', ')}`);
  }
}

function fecha(valor) {
  return valor == null ? null : new Date(valor);
}

function numero(valor) {
  return valor == null ? null : Number(valor);
}

function dividirEnLotes(filas, tamano) {
  const lotes = [];
  for (let inicio = 0; inicio < filas.length; inicio += tamano) {
    lotes.push(filas.slice(inicio, inicio + tamano));
  }
  return lotes;
}

async function consultar(transaccion, consulta) {
  const resultado = await new sql.Request(transaccion).query(consulta);
  return resultado.recordset;
}

async function exportar() {
  exigirConfiguracion();
  if (fs.existsSync(ARCHIVO_CARGA)) {
    throw new Error(`Ya existe ${ARCHIVO_CARGA}. Muévalo o bórrelo conscientemente antes de exportar otra vez.`);
  }

  fs.mkdirSync(path.dirname(ARCHIVO_CARGA), { recursive: true });
  const pool = await new sql.ConnectionPool(NODOS.origen).connect();
  const transaccion = new sql.Transaction(pool);

  try {
    await transaccion.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);

    const paises = await consultar(transaccion, `
      SELECT CountryID, CountryName
      FROM Application.Countries ORDER BY CountryID;`);
    const provincias = await consultar(transaccion, `
      SELECT StateProvinceID, StateProvinceCode, StateProvinceName, CountryID
      FROM Application.StateProvinces ORDER BY StateProvinceID;`);
    const ciudades = await consultar(transaccion, `
      SELECT CityID, CityName, StateProvinceID
      FROM Application.Cities ORDER BY CityID;`);
    const metodosEntrega = await consultar(transaccion, `
      SELECT DeliveryMethodID, DeliveryMethodName
      FROM Application.DeliveryMethods ORDER BY DeliveryMethodID;`);
    const categoriasCliente = await consultar(transaccion, `
      SELECT CustomerCategoryID, CustomerCategoryName
      FROM Sales.CustomerCategories ORDER BY CustomerCategoryID;`);
    const gruposCompra = await consultar(transaccion, `
      SELECT BuyingGroupID, BuyingGroupName
      FROM Sales.BuyingGroups ORDER BY BuyingGroupID;`);
    const categoriasProveedor = await consultar(transaccion, `
      SELECT SupplierCategoryID, SupplierCategoryName
      FROM Purchasing.SupplierCategories ORDER BY SupplierCategoryID;`);
    const personasOrigen = await consultar(transaccion, `
      SELECT PersonID, FullName, IsSalesperson, PhoneNumber, FaxNumber, EmailAddress
      FROM Application.People ORDER BY PersonID;`);
    const clientesOrigen = await consultar(transaccion, `
      SELECT CustomerID, CustomerName, BillToCustomerID, CustomerCategoryID,
             BuyingGroupID, PrimaryContactPersonID, AlternateContactPersonID,
             DeliveryMethodID, DeliveryCityID, PostalCityID, CreditLimit,
             AccountOpenedDate, StandardDiscountPercentage, IsStatementSent,
             IsOnCreditHold, PaymentDays, PhoneNumber, FaxNumber, WebsiteURL,
             DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
             CASE WHEN DeliveryLocation IS NULL THEN NULL ELSE DeliveryLocation.STAsText() END AS DeliveryLocationWkt,
             CASE WHEN DeliveryLocation IS NULL THEN NULL ELSE DeliveryLocation.STSrid END AS DeliveryLocationSrid,
             PostalAddressLine1, PostalAddressLine2, PostalPostalCode
      FROM Sales.Customers ORDER BY CustomerID;`);
    const proveedoresOrigen = await consultar(transaccion, `
      SELECT SupplierID, SupplierName, SupplierCategoryID,
             PrimaryContactPersonID, AlternateContactPersonID, DeliveryMethodID,
             PaymentDays, SupplierReference, PhoneNumber, FaxNumber, WebsiteURL,
             DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
             CASE WHEN DeliveryLocation IS NULL THEN NULL ELSE DeliveryLocation.STAsText() END AS DeliveryLocationWkt,
             CASE WHEN DeliveryLocation IS NULL THEN NULL ELSE DeliveryLocation.STSrid END AS DeliveryLocationSrid,
             PostalAddressLine1, PostalAddressLine2, PostalPostalCode,
             BankAccountName, BankAccountBranch, BankAccountCode,
             BankAccountNumber, BankInternationalCode, InternalComments
      FROM Purchasing.Suppliers ORDER BY SupplierID;`);
    const facturasOrigen = await consultar(transaccion, `
      SELECT InvoiceID, CustomerID, BillToCustomerID, OrderID, DeliveryMethodID,
             ContactPersonID, AccountsPersonID, SalespersonPersonID,
             PackedByPersonID, InvoiceDate, CustomerPurchaseOrderNumber,
             IsCreditNote, CreditNoteReason, Comments, DeliveryInstructions,
             InternalComments, TotalDryItems, TotalChillerItems, DeliveryRun,
             RunPosition, ReturnedDeliveryData
      FROM Sales.Invoices ORDER BY InvoiceID;`);
    const lineasFacturaOrigen = await consultar(transaccion, `
      SELECT InvoiceLineID, InvoiceID, StockItemID, Description, PackageTypeID,
             Quantity, UnitPrice, TaxRate, TaxAmount, LineProfit, ExtendedPrice
      FROM Sales.InvoiceLines ORDER BY InvoiceLineID;`);
    const ordenesOrigen = await consultar(transaccion, `
      SELECT PurchaseOrderID, SupplierID, OrderDate, DeliveryMethodID,
             ContactPersonID, ExpectedDeliveryDate, SupplierReference,
             IsOrderFinalized, Comments, InternalComments
      FROM Purchasing.PurchaseOrders ORDER BY PurchaseOrderID;`);
    const lineasOrdenOrigen = await consultar(transaccion, `
      SELECT PurchaseOrderLineID, PurchaseOrderID, StockItemID, OrderedOuters,
             Description, ReceivedOuters, PackageTypeID,
             ExpectedUnitPricePerOuter, LastReceiptDate, IsOrderLineFinalized
      FROM Purchasing.PurchaseOrderLines ORDER BY PurchaseOrderLineID;`);
    const inventarioOrigen = await consultar(transaccion, `
      SELECT StockItemID, QuantityOnHand, BinLocation, LastStocktakeQuantity,
             LastCostPrice, ReorderLevel, TargetStockLevel
      FROM Warehouse.StockItemHoldings ORDER BY StockItemID;`);

    await transaccion.commit();

    const asignacion = asignarVendedores(personasOrigen, facturasOrigen);
    const sucursalPorVendedor = new Map([
      ...asignacion.sanJose.map(id => [id, 1]),
      ...asignacion.limon.map(id => [id, 2])
    ]);

    const personasPublicas = personasOrigen.map(persona => ({
      PersonID: persona.PersonID,
      IsSalesperson: Boolean(persona.IsSalesperson),
      FullName: persona.IsSalesperson ? persona.FullName : null,
      SucursalID: persona.IsSalesperson ? sucursalPorVendedor.get(persona.PersonID) : null
    }));
    const personasSensibles = personasOrigen.map(persona => ({
      PersonID: persona.PersonID,
      FullName: persona.FullName,
      PhoneNumber: persona.PhoneNumber,
      FaxNumber: persona.FaxNumber,
      EmailAddress: persona.EmailAddress
    }));
    const clientesPublicos = clientesOrigen.map(({ PhoneNumber, FaxNumber, WebsiteURL,
      DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
      DeliveryLocationWkt, DeliveryLocationSrid, PostalAddressLine1,
      PostalAddressLine2, PostalPostalCode, ...publico }) => publico);
    const clientesSensibles = clientesOrigen.map(cliente => ({
      CustomerID: cliente.CustomerID,
      PhoneNumber: cliente.PhoneNumber,
      FaxNumber: cliente.FaxNumber,
      WebsiteURL: cliente.WebsiteURL,
      DeliveryAddressLine1: cliente.DeliveryAddressLine1,
      DeliveryAddressLine2: cliente.DeliveryAddressLine2,
      DeliveryPostalCode: cliente.DeliveryPostalCode,
      DeliveryLocationWkt: cliente.DeliveryLocationWkt,
      DeliveryLocationSrid: cliente.DeliveryLocationSrid,
      PostalAddressLine1: cliente.PostalAddressLine1,
      PostalAddressLine2: cliente.PostalAddressLine2,
      PostalPostalCode: cliente.PostalPostalCode
    }));
    const proveedoresPublicos = proveedoresOrigen.map(({ PhoneNumber, FaxNumber, WebsiteURL,
      DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
      DeliveryLocationWkt, DeliveryLocationSrid, PostalAddressLine1,
      PostalAddressLine2, PostalPostalCode, BankAccountName, BankAccountBranch,
      BankAccountCode, BankAccountNumber, BankInternationalCode,
      InternalComments, ...publico }) => publico);
    const proveedoresSensibles = proveedoresOrigen.map(proveedor => ({
      SupplierID: proveedor.SupplierID,
      PhoneNumber: proveedor.PhoneNumber,
      FaxNumber: proveedor.FaxNumber,
      WebsiteURL: proveedor.WebsiteURL,
      DeliveryAddressLine1: proveedor.DeliveryAddressLine1,
      DeliveryAddressLine2: proveedor.DeliveryAddressLine2,
      DeliveryPostalCode: proveedor.DeliveryPostalCode,
      DeliveryLocationWkt: proveedor.DeliveryLocationWkt,
      DeliveryLocationSrid: proveedor.DeliveryLocationSrid,
      PostalAddressLine1: proveedor.PostalAddressLine1,
      PostalAddressLine2: proveedor.PostalAddressLine2,
      PostalPostalCode: proveedor.PostalPostalCode,
      BankAccountName: proveedor.BankAccountName,
      BankAccountBranch: proveedor.BankAccountBranch,
      BankAccountCode: proveedor.BankAccountCode,
      BankAccountNumber: proveedor.BankAccountNumber,
      BankInternationalCode: proveedor.BankInternationalCode,
      InternalComments: proveedor.InternalComments
    }));

    const facturas = { sanJose: [], limon: [] };
    for (const factura of facturasOrigen) {
      const sucursal = sucursalPorVendedor.get(factura.SalespersonPersonID);
      if (!sucursal) throw new Error(`La factura ${factura.InvoiceID} no tiene vendedor asignado.`);
      facturas[sucursal === 1 ? 'sanJose' : 'limon'].push({ SucursalID: sucursal, ...factura });
    }
    const sucursalPorFactura = new Map([
      ...facturas.sanJose.map(f => [f.InvoiceID, 1]),
      ...facturas.limon.map(f => [f.InvoiceID, 2])
    ]);
    const lineasFactura = { sanJose: [], limon: [] };
    for (const linea of lineasFacturaOrigen) {
      const sucursal = sucursalPorFactura.get(linea.InvoiceID);
      if (!sucursal) throw new Error(`La línea ${linea.InvoiceLineID} no tiene factura asignada.`);
      lineasFactura[sucursal === 1 ? 'sanJose' : 'limon'].push({ SucursalID: sucursal, ...linea });
    }

    const ordenes = { sanJose: [], limon: [] };
    for (const orden of ordenesOrigen) {
      const sucursal = orden.PurchaseOrderID % 2 === 1 ? 1 : 2;
      ordenes[sucursal === 1 ? 'sanJose' : 'limon'].push({ SucursalID: sucursal, ...orden });
    }
    const sucursalPorOrden = new Map([
      ...ordenes.sanJose.map(o => [o.PurchaseOrderID, 1]),
      ...ordenes.limon.map(o => [o.PurchaseOrderID, 2])
    ]);
    const lineasOrden = { sanJose: [], limon: [] };
    for (const linea of lineasOrdenOrigen) {
      const sucursal = sucursalPorOrden.get(linea.PurchaseOrderID);
      if (!sucursal) throw new Error(`La línea ${linea.PurchaseOrderLineID} no tiene orden asignada.`);
      lineasOrden[sucursal === 1 ? 'sanJose' : 'limon'].push({ SucursalID: sucursal, ...linea });
    }

    const inventario = {
      sanJose: inventarioOrigen.map(fila => ({
        SucursalID: 1,
        ...fila,
        QuantityOnHand: Math.ceil(fila.QuantityOnHand / 2),
        BinLocation: null
      })),
      limon: inventarioOrigen.map(fila => ({
        SucursalID: 2,
        ...fila,
        QuantityOnHand: Math.floor(fila.QuantityOnHand / 2),
        BinLocation: null
      }))
    };

    const carga = {
      formato: 2,
      generadoEn: new Date().toISOString(),
      criterioOrdenes: 'PurchaseOrderID impar = San José; par = Limón',
      asignacionVendedores: asignacion,
      referencias: { paises, provincias, ciudades, metodosEntrega, categoriasCliente, gruposCompra, categoriasProveedor },
      personasPublicas,
      personasSensibles,
      clientesPublicos,
      clientesSensibles,
      proveedoresPublicos,
      proveedoresSensibles,
      facturas,
      lineasFactura,
      ordenes,
      lineasOrden,
      inventario
    };

    validarCarga(carga);
    fs.writeFileSync(ARCHIVO_CARGA, JSON.stringify(carga));
    console.log(`Exportación creada en ${ARCHIVO_CARGA}`);
    mostrarResumen(carga);
  } catch (error) {
    if (transaccion._aborted !== true && transaccion._rollbackRequested !== true) {
      try { await transaccion.rollback(); } catch (_) { /* La transacción puede haber terminado. */ }
    }
    throw error;
  } finally {
    await pool.close();
  }
}

function asignarVendedores(personas, facturas) {
  const vendedores = personas.filter(p => p.IsSalesperson).map(p => p.PersonID).sort((a, b) => a - b);
  if (vendedores.length !== 10) {
    throw new Error(`Se esperaban 10 vendedores en WWI y se encontraron ${vendedores.length}.`);
  }
  const conteo = new Map(vendedores.map(id => [id, 0]));
  for (const factura of facturas) {
    if (!conteo.has(factura.SalespersonPersonID)) {
      throw new Error(`La factura ${factura.InvoiceID} referencia un vendedor no reconocido.`);
    }
    conteo.set(factura.SalespersonPersonID, conteo.get(factura.SalespersonPersonID) + 1);
  }
  const total = facturas.length;
  let mejor = null;
  for (let a = 0; a < vendedores.length - 4; a++)
    for (let b = a + 1; b < vendedores.length - 3; b++)
      for (let c = b + 1; c < vendedores.length - 2; c++)
        for (let d = c + 1; d < vendedores.length - 1; d++)
          for (let e = d + 1; e < vendedores.length; e++) {
            const grupo = [vendedores[a], vendedores[b], vendedores[c], vendedores[d], vendedores[e]];
            const cantidad = grupo.reduce((suma, id) => suma + conteo.get(id), 0);
            const diferencia = Math.abs(total - cantidad * 2);
            if (!mejor || diferencia < mejor.diferencia) mejor = { grupo, cantidad, diferencia };
          }
  const sanJose = mejor.grupo;
  const conjuntoSJ = new Set(sanJose);
  const limon = vendedores.filter(id => !conjuntoSJ.has(id));
  return {
    sanJose,
    limon,
    facturasSanJose: mejor.cantidad,
    facturasLimon: total - mejor.cantidad,
    facturasPorVendedor: Object.fromEntries([...conteo.entries()])
  };
}

function validarCarga(carga) {
  if (carga.formato !== 2) {
    throw new Error('El archivo de carga usa un formato anterior. Genere una exportación nueva.');
  }
  if (carga.asignacionVendedores.sanJose.length !== 5 || carga.asignacionVendedores.limon.length !== 5) {
    throw new Error('Cada sucursal debe tener exactamente cinco vendedores.');
  }
  const facturas = carga.facturas.sanJose.length + carga.facturas.limon.length;
  const lineas = carga.lineasFactura.sanJose.length + carga.lineasFactura.limon.length;
  if (!facturas || !lineas) throw new Error('La exportación no contiene facturas o líneas.');
  const ordenes = carga.ordenes.sanJose.length + carga.ordenes.limon.length;
  const lineasOrden = carga.lineasOrden.sanJose.length + carga.lineasOrden.limon.length;
  if (!ordenes || !lineasOrden) throw new Error('La exportación no contiene órdenes o líneas.');
  if (carga.inventario.sanJose.length !== carga.inventario.limon.length) {
    throw new Error('Las sucursales no tienen la misma cantidad de productos en inventario.');
  }
}

function leerCarga() {
  if (!fs.existsSync(ARCHIVO_CARGA)) {
    throw new Error(`No existe ${ARCHIVO_CARGA}. Ejecute primero el comando exportar.`);
  }
  const carga = JSON.parse(fs.readFileSync(ARCHIVO_CARGA, 'utf8'));
  validarCarga(carga);
  return carga;
}

const DEFINICIONES = {
  paises: { tabla: 'Application.Countries', columnas: [['CountryID', sql.Int], ['CountryName', sql.NVarChar(60)]] },
  provincias: { tabla: 'Application.StateProvinces', columnas: [
    ['StateProvinceID', sql.Int], ['StateProvinceCode', sql.NVarChar(5)],
    ['StateProvinceName', sql.NVarChar(50)], ['CountryID', sql.Int]
  ] },
  ciudades: { tabla: 'Application.Cities', columnas: [['CityID', sql.Int], ['CityName', sql.NVarChar(50)], ['StateProvinceID', sql.Int]] },
  metodosEntrega: { tabla: 'Application.DeliveryMethods', columnas: [['DeliveryMethodID', sql.Int], ['DeliveryMethodName', sql.NVarChar(50)]] },
  categoriasCliente: { tabla: 'Sales.CustomerCategories', columnas: [['CustomerCategoryID', sql.Int], ['CustomerCategoryName', sql.NVarChar(50)]] },
  gruposCompra: { tabla: 'Sales.BuyingGroups', columnas: [['BuyingGroupID', sql.Int], ['BuyingGroupName', sql.NVarChar(50)]] },
  categoriasProveedor: { tabla: 'Purchasing.SupplierCategories', columnas: [['SupplierCategoryID', sql.Int], ['SupplierCategoryName', sql.NVarChar(50)]] },
  personasPublicas: { tabla: 'Application.People', columnas: [['PersonID', sql.Int], ['IsSalesperson', sql.Bit], ['FullName', sql.NVarChar(50)], ['SucursalID', sql.Int]] },
  clientesPublicos: { tabla: 'Sales.Customers', columnas: [
    ['CustomerID', sql.Int], ['CustomerName', sql.NVarChar(100)], ['BillToCustomerID', sql.Int],
    ['CustomerCategoryID', sql.Int], ['BuyingGroupID', sql.Int], ['PrimaryContactPersonID', sql.Int],
    ['AlternateContactPersonID', sql.Int], ['DeliveryMethodID', sql.Int], ['DeliveryCityID', sql.Int],
    ['PostalCityID', sql.Int], ['CreditLimit', sql.Decimal(18, 2)], ['AccountOpenedDate', sql.Date],
    ['StandardDiscountPercentage', sql.Decimal(18, 3)], ['IsStatementSent', sql.Bit],
    ['IsOnCreditHold', sql.Bit], ['PaymentDays', sql.Int]
  ] },
  facturas: { tabla: 'Sales.Invoices', identidad: true, columnas: [
    ['SucursalID', sql.Int], ['InvoiceID', sql.Int], ['CustomerID', sql.Int], ['BillToCustomerID', sql.Int],
    ['OrderID', sql.Int], ['DeliveryMethodID', sql.Int], ['ContactPersonID', sql.Int],
    ['AccountsPersonID', sql.Int], ['SalespersonPersonID', sql.Int], ['PackedByPersonID', sql.Int],
    ['InvoiceDate', sql.Date], ['CustomerPurchaseOrderNumber', sql.NVarChar(20)], ['IsCreditNote', sql.Bit],
    ['CreditNoteReason', sql.NVarChar(sql.MAX)], ['Comments', sql.NVarChar(sql.MAX)],
    ['DeliveryInstructions', sql.NVarChar(sql.MAX)], ['InternalComments', sql.NVarChar(sql.MAX)],
    ['TotalDryItems', sql.Int], ['TotalChillerItems', sql.Int], ['DeliveryRun', sql.NVarChar(5)],
    ['RunPosition', sql.NVarChar(5)], ['ReturnedDeliveryData', sql.NVarChar(sql.MAX)]
  ] },
  lineasFactura: { tabla: 'Sales.InvoiceLines', identidad: true, columnas: [
    ['SucursalID', sql.Int], ['InvoiceLineID', sql.Int], ['InvoiceID', sql.Int], ['StockItemID', sql.Int],
    ['Description', sql.NVarChar(100)], ['PackageTypeID', sql.Int], ['Quantity', sql.Int],
    ['UnitPrice', sql.Decimal(18, 2)], ['TaxRate', sql.Decimal(18, 3)], ['TaxAmount', sql.Decimal(18, 2)],
    ['LineProfit', sql.Decimal(18, 2)], ['ExtendedPrice', sql.Decimal(18, 2)]
  ] },
  ordenes: { tabla: 'Purchasing.PurchaseOrders', identidad: true, columnas: [
    ['SucursalID', sql.Int], ['PurchaseOrderID', sql.Int], ['SupplierID', sql.Int], ['OrderDate', sql.Date],
    ['DeliveryMethodID', sql.Int], ['ContactPersonID', sql.Int], ['ExpectedDeliveryDate', sql.Date],
    ['SupplierReference', sql.NVarChar(20)], ['IsOrderFinalized', sql.Bit],
    ['Comments', sql.NVarChar(sql.MAX)], ['InternalComments', sql.NVarChar(sql.MAX)]
  ] },
  lineasOrden: { tabla: 'Purchasing.PurchaseOrderLines', identidad: true, columnas: [
    ['SucursalID', sql.Int], ['PurchaseOrderLineID', sql.Int], ['PurchaseOrderID', sql.Int],
    ['StockItemID', sql.Int], ['OrderedOuters', sql.Int], ['Description', sql.NVarChar(100)],
    ['ReceivedOuters', sql.Int], ['PackageTypeID', sql.Int],
    ['ExpectedUnitPricePerOuter', sql.Decimal(18, 2)], ['LastReceiptDate', sql.Date],
    ['IsOrderLineFinalized', sql.Bit]
  ] },
  inventario: { tabla: 'Warehouse.StockItemHoldings', columnas: [
    ['SucursalID', sql.Int], ['StockItemID', sql.Int], ['QuantityOnHand', sql.Int],
    ['BinLocation', sql.NVarChar(20)], ['LastStocktakeQuantity', sql.Int],
    ['LastCostPrice', sql.Decimal(18, 2)], ['ReorderLevel', sql.Int], ['TargetStockLevel', sql.Int]
  ] }
};

function valorParaSql(nombre, valor) {
  if (valor == null) return null;
  if (nombre.endsWith('Date')) return fecha(valor);
  return valor;
}

async function cantidadTabla(transaccion, tabla) {
  const resultado = await new sql.Request(transaccion).query(`SELECT COUNT_BIG(*) AS Cantidad FROM ${tabla};`);
  return Number(resultado.recordset[0].Cantidad);
}

async function insertarEnBloques(transaccion, definicion, filas, opciones = {}) {
  if (!filas.length) return;
  const existentes = await cantidadTabla(transaccion, definicion.tabla);
  if (existentes !== 0) {
    if (opciones.permitirExistentes && existentes === filas.length) return;
    throw new Error(`${definicion.tabla} contiene ${existentes} filas; se esperaban 0 antes de cargar.`);
  }
  const metadatos = await obtenerMetadatosTabla(transaccion, definicion.tabla);
  const nombresDestino = new Set(metadatos.map(columna => columna.name));
  const columnas = definicion.columnas.filter(([nombre]) => nombresDestino.has(nombre));
  const nombresIncluidos = new Set(columnas.map(([nombre]) => nombre));
  const obligatoriasFaltantes = metadatos.filter(columna =>
    !columna.is_nullable &&
    !columna.is_identity &&
    !columna.is_computed &&
    !columna.tiene_default &&
    columna.tipo !== 'timestamp' &&
    columna.tipo !== 'rowversion' &&
    !nombresIncluidos.has(columna.name)
  );
  if (obligatoriasFaltantes.length) {
    throw new Error(`${definicion.tabla}: faltan valores para las columnas obligatorias ${obligatoriasFaltantes.map(c => c.name).join(', ')}.`);
  }
  if (!columnas.length) throw new Error(`${definicion.tabla}: no hay columnas compatibles para insertar.`);

  const columnaIdentidad = metadatos.find(columna => columna.is_identity)?.name ?? null;
  const filasPorLote = Math.max(1, Math.floor(MAXIMO_PARAMETROS_POR_LOTE / columnas.length));

  for (const lote of dividirEnLotes(filas, filasPorLote)) {
      const request = new sql.Request(transaccion);
      const valores = [];

      for (let indiceFila = 0; indiceFila < lote.length; indiceFila++) {
        const parametrosFila = [];
        for (let indiceColumna = 0; indiceColumna < columnas.length; indiceColumna++) {
          const [nombre, tipo] = columnas[indiceColumna];
          const parametro = `p_${indiceFila}_${indiceColumna}`;
          request.input(parametro, tipo, valorParaSql(nombre, lote[indiceFila][nombre]));
          parametrosFila.push(`@${parametro}`);
        }
        valores.push(`(${parametrosFila.join(',')})`);
      }

      const nombresColumnas = columnas.map(([nombre]) => `[${nombre}]`).join(',');
      try {
        if (columnaIdentidad) {
          await request.query(`
            SET IDENTITY_INSERT ${definicion.tabla} ON;
            BEGIN TRY
              INSERT INTO ${definicion.tabla} (${nombresColumnas}) VALUES ${valores.join(',')};
              SET IDENTITY_INSERT ${definicion.tabla} OFF;
            END TRY
            BEGIN CATCH
              SET IDENTITY_INSERT ${definicion.tabla} OFF;
              THROW;
            END CATCH;`);
        } else {
          await request.query(`INSERT INTO ${definicion.tabla} (${nombresColumnas}) VALUES ${valores.join(',')};`);
        }
      } catch (error) {
        throw new Error(`${definicion.tabla}: ${error.message}`);
      }
  }
}

async function obtenerMetadatosTabla(transaccion, tabla) {
  const request = new sql.Request(transaccion);
  request.input('Tabla', sql.NVarChar(256), tabla);
  const resultado = await request.query(`
    SELECT c.name, c.is_nullable, c.is_identity, c.is_computed,
           CONVERT(bit, CASE WHEN c.default_object_id <> 0 THEN 1 ELSE 0 END) AS tiene_default,
           t.name AS tipo
    FROM sys.columns AS c
    JOIN sys.types AS t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID(@Tabla, N'U')
    ORDER BY c.column_id;`);
  if (!resultado.recordset.length) throw new Error(`No existe la tabla ${tabla}.`);
  return resultado.recordset;
}

async function actualizarProveedores(transaccion, filas) {
  const cantidad = await cantidadTabla(transaccion, 'Purchasing.Suppliers');
  if (cantidad !== filas.length) {
    throw new Error(`Purchasing.Suppliers contiene ${cantidad} filas y el origen contiene ${filas.length}.`);
  }
  for (const proveedor of filas) {
    const request = new sql.Request(transaccion);
    request.input('SupplierID', sql.Int, proveedor.SupplierID);
    request.input('SupplierName', sql.NVarChar(100), proveedor.SupplierName);
    request.input('SupplierCategoryID', sql.Int, proveedor.SupplierCategoryID);
    request.input('PrimaryContactPersonID', sql.Int, proveedor.PrimaryContactPersonID);
    request.input('AlternateContactPersonID', sql.Int, proveedor.AlternateContactPersonID);
    request.input('DeliveryMethodID', sql.Int, proveedor.DeliveryMethodID);
    request.input('PaymentDays', sql.Int, proveedor.PaymentDays);
    request.input('SupplierReference', sql.NVarChar(20), proveedor.SupplierReference);
    const resultado = await request.query(`
      UPDATE Purchasing.Suppliers
      SET SupplierName=@SupplierName, SupplierCategoryID=@SupplierCategoryID,
          PrimaryContactPersonID=@PrimaryContactPersonID,
          AlternateContactPersonID=@AlternateContactPersonID,
          DeliveryMethodID=@DeliveryMethodID, PaymentDays=@PaymentDays,
          SupplierReference=@SupplierReference
      WHERE SupplierID=@SupplierID;`);
    if (resultado.rowsAffected[0] !== 1) throw new Error(`No existe SupplierID ${proveedor.SupplierID}.`);
  }
}

async function insertarSensibles(transaccion, tabla, clave, filas, columnas) {
  const existentes = await cantidadTabla(transaccion, tabla);
  if (existentes !== 0) throw new Error(`${tabla} contiene ${existentes} filas; se esperaban 0.`);
  for (const fila of filas) {
    const request = new sql.Request(transaccion);
    request.input(clave, sql.Int, fila[clave]);
    for (const [nombre, tipo] of columnas) request.input(nombre, tipo, fila[nombre]);
    request.input('DeliveryLocationWkt', sql.NVarChar(sql.MAX), fila.DeliveryLocationWkt);
    request.input('DeliveryLocationSrid', sql.Int, fila.DeliveryLocationSrid);
    const nombres = [clave, ...columnas.map(([nombre]) => nombre), 'DeliveryLocation'];
    const valores = [`@${clave}`, ...columnas.map(([nombre]) => `@${nombre}`),
      'CASE WHEN @DeliveryLocationWkt IS NULL THEN NULL ELSE geography::STGeomFromText(@DeliveryLocationWkt,@DeliveryLocationSrid) END'];
    await request.query(`INSERT INTO ${tabla} (${nombres.join(',')}) VALUES (${valores.join(',')});`);
  }
}

async function insertarPersonasSensibles(transaccion, filas) {
  const definicion = {
    tabla: 'Sensitive.People',
    columnas: [['PersonID', sql.Int], ['FullName', sql.NVarChar(50)], ['PhoneNumber', sql.NVarChar(20)],
      ['FaxNumber', sql.NVarChar(20)], ['EmailAddress', sql.NVarChar(256)]]
  };
  await insertarEnBloques(transaccion, definicion, filas);
}

async function verificarInventarioExistente(transaccion, nombre, esperado) {
  const resultado = await new sql.Request(transaccion).query(`
    SELECT SucursalID, StockItemID, QuantityOnHand, BinLocation
    FROM Warehouse.StockItemHoldings
    ORDER BY StockItemID;`);
  if (resultado.recordset.length !== esperado.length) {
    throw new Error(`${nombre}: inventario existente ${resultado.recordset.length}; esperado ${esperado.length}.`);
  }
  for (let indice = 0; indice < esperado.length; indice++) {
    const real = resultado.recordset[indice];
    const fila = esperado[indice];
    if (real.SucursalID !== fila.SucursalID ||
        real.StockItemID !== fila.StockItemID ||
        Number(real.QuantityOnHand) !== Number(fila.QuantityOnHand) ||
        (real.BinLocation ?? null) !== (fila.BinLocation ?? null)) {
      throw new Error(`${nombre}: el inventario del producto ${fila.StockItemID} no coincide con la carga esperada.`);
    }
  }
}

async function cargarCatalogosPublicos(transaccion, carga) {
  await insertarEnBloques(transaccion, DEFINICIONES.paises, carga.referencias.paises);
  await insertarEnBloques(transaccion, DEFINICIONES.provincias, carga.referencias.provincias);
  await insertarEnBloques(transaccion, DEFINICIONES.ciudades, carga.referencias.ciudades);
  await insertarEnBloques(transaccion, DEFINICIONES.metodosEntrega, carga.referencias.metodosEntrega);
  await insertarEnBloques(transaccion, DEFINICIONES.categoriasCliente, carga.referencias.categoriasCliente);
  await insertarEnBloques(transaccion, DEFINICIONES.gruposCompra, carga.referencias.gruposCompra);
  await insertarEnBloques(transaccion, DEFINICIONES.categoriasProveedor, carga.referencias.categoriasProveedor);
  await insertarEnBloques(transaccion, DEFINICIONES.personasPublicas, carga.personasPublicas);
  await actualizarProveedores(transaccion, carga.proveedoresPublicos);
  await insertarEnBloques(transaccion, DEFINICIONES.clientesPublicos, carga.clientesPublicos);
}

async function cargarSensibles(transaccion, carga) {
  await insertarPersonasSensibles(transaccion, carga.personasSensibles);
  await insertarSensibles(transaccion, 'Sensitive.Customers', 'CustomerID', carga.clientesSensibles, [
    ['PhoneNumber', sql.NVarChar(20)], ['FaxNumber', sql.NVarChar(20)], ['WebsiteURL', sql.NVarChar(256)],
    ['DeliveryAddressLine1', sql.NVarChar(60)], ['DeliveryAddressLine2', sql.NVarChar(60)],
    ['DeliveryPostalCode', sql.NVarChar(10)], ['PostalAddressLine1', sql.NVarChar(60)],
    ['PostalAddressLine2', sql.NVarChar(60)], ['PostalPostalCode', sql.NVarChar(10)]
  ]);
  await insertarSensibles(transaccion, 'Sensitive.Suppliers', 'SupplierID', carga.proveedoresSensibles, [
    ['PhoneNumber', sql.NVarChar(20)], ['FaxNumber', sql.NVarChar(20)], ['WebsiteURL', sql.NVarChar(256)],
    ['DeliveryAddressLine1', sql.NVarChar(60)], ['DeliveryAddressLine2', sql.NVarChar(60)],
    ['DeliveryPostalCode', sql.NVarChar(10)], ['PostalAddressLine1', sql.NVarChar(60)],
    ['PostalAddressLine2', sql.NVarChar(60)], ['PostalPostalCode', sql.NVarChar(10)],
    ['BankAccountName', sql.NVarChar(50)], ['BankAccountBranch', sql.NVarChar(50)],
    ['BankAccountCode', sql.NVarChar(20)], ['BankAccountNumber', sql.NVarChar(20)],
    ['BankInternationalCode', sql.NVarChar(20)], ['InternalComments', sql.NVarChar(sql.MAX)]
  ]);
}

async function cargarNodo(nombre, configuracion, carga, sucursal) {
  if (await nodoCoincideConCarga(configuracion, carga, sucursal)) {
    console.log(`${nombre}: ya coincide con la carga; se omite.`);
    return;
  }
  const pool = await new sql.ConnectionPool(configuracion).connect();
  const transaccion = new sql.Transaction(pool);
  try {
    await transaccion.begin(sql.ISOLATION_LEVEL.SERIALIZABLE);
    await cargarCatalogosPublicos(transaccion, carga);
    if (nombre === 'Corporativo') await cargarSensibles(transaccion, carga);

    const facturas = sucursal ? carga.facturas[sucursal] : [...carga.facturas.sanJose, ...carga.facturas.limon];
    const lineasFactura = sucursal ? carga.lineasFactura[sucursal] : [...carga.lineasFactura.sanJose, ...carga.lineasFactura.limon];
    const ordenes = sucursal ? carga.ordenes[sucursal] : [...carga.ordenes.sanJose, ...carga.ordenes.limon];
    const lineasOrden = sucursal ? carga.lineasOrden[sucursal] : [...carga.lineasOrden.sanJose, ...carga.lineasOrden.limon];
    const inventario = sucursal ? carga.inventario[sucursal] : [...carga.inventario.sanJose, ...carga.inventario.limon];

    await insertarEnBloques(transaccion, DEFINICIONES.facturas, facturas);
    await insertarEnBloques(transaccion, DEFINICIONES.lineasFactura, lineasFactura);
    await insertarEnBloques(transaccion, DEFINICIONES.ordenes, ordenes);
    await insertarEnBloques(transaccion, DEFINICIONES.lineasOrden, lineasOrden);

    if (sucursal) {
      await verificarInventarioExistente(transaccion, nombre, inventario);
    } else {
      await insertarEnBloques(transaccion, DEFINICIONES.inventario, inventario);
    }

    await transaccion.commit();
    console.log(`${nombre}: carga completada.`);
  } catch (error) {
    try { await transaccion.rollback(); } catch (_) { /* La transacción puede haber terminado. */ }
    throw new Error(`${nombre}: ${error.message}`);
  } finally {
    await pool.close();
  }
}

function sumar(filas, campo) {
  return filas.reduce((total, fila) => total + Number(fila[campo] ?? 0), 0);
}

async function nodoCoincideConCarga(configuracion, carga, sucursal) {
  const resumen = await resumenNodo(configuracion);
  const facturas = sucursal ? carga.facturas[sucursal] : [...carga.facturas.sanJose, ...carga.facturas.limon];
  const lineasFactura = sucursal ? carga.lineasFactura[sucursal] : [...carga.lineasFactura.sanJose, ...carga.lineasFactura.limon];
  const ordenes = sucursal ? carga.ordenes[sucursal] : [...carga.ordenes.sanJose, ...carga.ordenes.limon];
  const lineasOrden = sucursal ? carga.lineasOrden[sucursal] : [...carga.lineasOrden.sanJose, ...carga.lineasOrden.limon];
  const inventario = sucursal ? carga.inventario[sucursal] : [...carga.inventario.sanJose, ...carga.inventario.limon];
  const esperado = {
    Clientes: carga.clientesPublicos.length,
    Proveedores: carga.proveedoresPublicos.length,
    Personas: carga.personasPublicas.length,
    Facturas: facturas.length,
    LineasFactura: lineasFactura.length,
    MontoFacturas: sumar(lineasFactura, 'ExtendedPrice'),
    Ordenes: ordenes.length,
    LineasOrden: lineasOrden.length,
    FilasInventario: inventario.length,
    Inventario: sumar(inventario, 'QuantityOnHand')
  };
  const coincide = Object.entries(esperado).every(([campo, valor]) =>
    Math.abs(Number(resumen[campo]) - Number(valor)) <= 0.005
  );
  if (!coincide || sucursal) return coincide;

  const pool = await new sql.ConnectionPool(configuracion).connect();
  try {
    const sensibles = await pool.request().query(`
      SELECT
        (SELECT COUNT_BIG(*) FROM Sensitive.Customers) AS Clientes,
        (SELECT COUNT_BIG(*) FROM Sensitive.Suppliers) AS Proveedores,
        (SELECT COUNT_BIG(*) FROM Sensitive.People) AS Personas;`);
    return Number(sensibles.recordset[0].Clientes) === carga.clientesSensibles.length &&
      Number(sensibles.recordset[0].Proveedores) === carga.proveedoresSensibles.length &&
      Number(sensibles.recordset[0].Personas) === carga.personasSensibles.length;
  } finally {
    await pool.close();
  }
}

async function cargar() {
  exigirConfiguracion();
  const carga = leerCarga();
  await cargarNodo('Corporativo', NODOS.corporativo, carga, null);
  await cargarNodo('San José', NODOS.sanJose, carga, 'sanJose');
  await cargarNodo('Limón', NODOS.limon, carga, 'limon');
  console.log('Carga distribuida completada. Ejecute ahora el comando verificar.');
}

async function resumenNodo(configuracion) {
  const pool = await new sql.ConnectionPool(configuracion).connect();
  try {
    const resultado = await pool.request().query(`
      SELECT
        (SELECT COUNT_BIG(*) FROM Sales.Customers) AS Clientes,
        (SELECT COUNT_BIG(*) FROM Purchasing.Suppliers) AS Proveedores,
        (SELECT COUNT_BIG(*) FROM Application.People) AS Personas,
        (SELECT COUNT_BIG(*) FROM Sales.Invoices) AS Facturas,
        (SELECT COUNT_BIG(*) FROM Sales.InvoiceLines) AS LineasFactura,
        (SELECT COALESCE(SUM(ExtendedPrice),0) FROM Sales.InvoiceLines) AS MontoFacturas,
        (SELECT COUNT_BIG(*) FROM Purchasing.PurchaseOrders) AS Ordenes,
        (SELECT COUNT_BIG(*) FROM Purchasing.PurchaseOrderLines) AS LineasOrden,
        (SELECT COUNT_BIG(*) FROM Warehouse.StockItemHoldings) AS FilasInventario,
        (SELECT COALESCE(SUM(CONVERT(BIGINT,QuantityOnHand)),0) FROM Warehouse.StockItemHoldings) AS Inventario;
    `);
    return Object.fromEntries(Object.entries(resultado.recordset[0]).map(([clave, valor]) => [clave, numero(valor)]));
  } finally {
    await pool.close();
  }
}

function esperarIgual(nombre, real, esperado) {
  if (Math.abs(Number(real) - Number(esperado)) > 0.005) {
    throw new Error(`${nombre}: se obtuvo ${real} y se esperaba ${esperado}.`);
  }
}

async function verificar() {
  exigirConfiguracion();
  const carga = leerCarga();
  const [corporativo, sanJose, limon] = await Promise.all([
    resumenNodo(NODOS.corporativo), resumenNodo(NODOS.sanJose), resumenNodo(NODOS.limon)
  ]);

  const esperadoComun = {
    Clientes: carga.clientesPublicos.length,
    Proveedores: carga.proveedoresPublicos.length,
    Personas: carga.personasPublicas.length
  };
  for (const [nombre, resumen] of [['Corporativo', corporativo], ['San José', sanJose], ['Limón', limon]]) {
    for (const [campo, esperado] of Object.entries(esperadoComun)) esperarIgual(`${nombre}.${campo}`, resumen[campo], esperado);
  }

  esperarIgual('SanJosé.Facturas', sanJose.Facturas, carga.facturas.sanJose.length);
  esperarIgual('Limón.Facturas', limon.Facturas, carga.facturas.limon.length);
  esperarIgual('Corporativo.Facturas', corporativo.Facturas, sanJose.Facturas + limon.Facturas);
  esperarIgual('SanJosé.LineasFactura', sanJose.LineasFactura, carga.lineasFactura.sanJose.length);
  esperarIgual('Limón.LineasFactura', limon.LineasFactura, carga.lineasFactura.limon.length);
  esperarIgual('Corporativo.LineasFactura', corporativo.LineasFactura, sanJose.LineasFactura + limon.LineasFactura);
  esperarIgual('Monto consolidado', corporativo.MontoFacturas, sanJose.MontoFacturas + limon.MontoFacturas);
  esperarIgual('SanJosé.Ordenes', sanJose.Ordenes, carga.ordenes.sanJose.length);
  esperarIgual('Limón.Ordenes', limon.Ordenes, carga.ordenes.limon.length);
  esperarIgual('Corporativo.Ordenes', corporativo.Ordenes, sanJose.Ordenes + limon.Ordenes);
  esperarIgual('SanJosé.LineasOrden', sanJose.LineasOrden, carga.lineasOrden.sanJose.length);
  esperarIgual('Limón.LineasOrden', limon.LineasOrden, carga.lineasOrden.limon.length);
  esperarIgual('Corporativo.LineasOrden', corporativo.LineasOrden, sanJose.LineasOrden + limon.LineasOrden);
  esperarIgual('Inventario consolidado', corporativo.Inventario, sanJose.Inventario + limon.Inventario);
  esperarIgual('Filas inventario Corporativo', corporativo.FilasInventario, sanJose.FilasInventario + limon.FilasInventario);

  await verificarSensibles(carga);
  await verificarVendedores(carga);
  console.table({ Corporativo: corporativo, SanJose: sanJose, Limon: limon });
  console.log('VERIFICACION_DISTRIBUIDA_CORRECTA');
}

async function verificarSensibles(carga) {
  const pool = await new sql.ConnectionPool(NODOS.corporativo).connect();
  try {
    const resultado = await pool.request().query(`
      SELECT
        (SELECT COUNT_BIG(*) FROM Sensitive.Customers) AS Clientes,
        (SELECT COUNT_BIG(*) FROM Sensitive.Suppliers) AS Proveedores,
        (SELECT COUNT_BIG(*) FROM Sensitive.People) AS Personas;`);
    esperarIgual('Sensitive.Customers', resultado.recordset[0].Clientes, carga.clientesSensibles.length);
    esperarIgual('Sensitive.Suppliers', resultado.recordset[0].Proveedores, carga.proveedoresSensibles.length);
    esperarIgual('Sensitive.People', resultado.recordset[0].Personas, carga.personasSensibles.length);
  } finally {
    await pool.close();
  }
}

async function verificarVendedores(carga) {
  for (const [nombre, configuracion, sucursal, esperados] of [
    ['San José', NODOS.sanJose, 1, carga.asignacionVendedores.sanJose],
    ['Limón', NODOS.limon, 2, carga.asignacionVendedores.limon]
  ]) {
    const pool = await new sql.ConnectionPool(configuracion).connect();
    try {
      const resultado = await pool.request().input('SucursalID', sql.Int, sucursal).query(`
        SELECT PersonID FROM Application.People
        WHERE IsSalesperson=1 AND SucursalID=@SucursalID ORDER BY PersonID;
        SELECT COUNT_BIG(*) AS Incorrectas
        FROM Sales.Invoices AS i
        JOIN Application.People AS p ON p.PersonID=i.SalespersonPersonID
        WHERE i.SucursalID<>@SucursalID OR p.SucursalID<>@SucursalID;`);
      const reales = resultado.recordsets[0].map(fila => fila.PersonID);
      if (JSON.stringify(reales) !== JSON.stringify(esperados)) {
        throw new Error(`${nombre}: la asignación de vendedores no coincide con la exportación.`);
      }
      esperarIgual(`${nombre}.FacturasIncorrectas`, resultado.recordsets[1][0].Incorrectas, 0);
    } finally {
      await pool.close();
    }
  }
}

function mostrarResumen(carga) {
  console.table({
    SanJose: {
      Vendedores: carga.asignacionVendedores.sanJose.length,
      Facturas: carga.facturas.sanJose.length,
      LineasFactura: carga.lineasFactura.sanJose.length,
      Ordenes: carga.ordenes.sanJose.length,
      LineasOrden: carga.lineasOrden.sanJose.length,
      Inventario: carga.inventario.sanJose.reduce((suma, fila) => suma + fila.QuantityOnHand, 0)
    },
    Limon: {
      Vendedores: carga.asignacionVendedores.limon.length,
      Facturas: carga.facturas.limon.length,
      LineasFactura: carga.lineasFactura.limon.length,
      Ordenes: carga.ordenes.limon.length,
      LineasOrden: carga.lineasOrden.limon.length,
      Inventario: carga.inventario.limon.reduce((suma, fila) => suma + fila.QuantityOnHand, 0)
    }
  });
}

async function main() {
  const comando = process.argv[2];
  if (!['exportar', 'cargar', 'verificar'].includes(comando)) {
    throw new Error('Uso: node scripts/cargaDistribuida.js <exportar|cargar|verificar>');
  }
  if (comando === 'exportar') await exportar();
  if (comando === 'cargar') await cargar();
  if (comando === 'verificar') await verificar();
}

main().catch(error => {
  console.error(error.message);
  process.exitCode = 1;
});
