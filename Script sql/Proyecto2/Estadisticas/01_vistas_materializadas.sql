-- Ejecutar en Corporativo: vistas materializadas (vistas indexadas) para las estadísticas.
-- SQL Server guarda el resultado de cada vista y lo actualiza solo con cada cambio en las tablas,
-- también con las facturas y órdenes que llegan por replicación desde las sucursales.
IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51030, 'Las vistas materializadas se crean en Corporativo.', 1;
GO

-- SQL Server exige estas opciones para crear vistas indexadas
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Monto de cada factura (reportes de ventas por cliente y top clientes).
-- SCHEMABINDING amarra la vista a las tablas; COUNT_BIG(*) es obligatorio con GROUP BY.
CREATE OR ALTER VIEW dbo.vm_MontoFactura
WITH SCHEMABINDING
AS
SELECT
    i.SucursalID,
    i.InvoiceID,
    i.CustomerID,
    YEAR(i.InvoiceDate) AS Anio,
    SUM(il.ExtendedPrice) AS Monto,
    COUNT_BIG(*) AS Lineas
FROM Sales.Invoices i
JOIN Sales.InvoiceLines il
    ON il.SucursalID = i.SucursalID
   AND il.InvoiceID = i.InvoiceID
GROUP BY i.SucursalID, i.InvoiceID, i.CustomerID, YEAR(i.InvoiceDate);
GO

-- El índice único es el que guarda los datos de la vista
CREATE UNIQUE CLUSTERED INDEX IX_vm_MontoFactura
ON dbo.vm_MontoFactura (SucursalID, InvoiceID);
GO

-- Monto de cada orden de compra (reportes de compras por proveedor y top proveedores).
-- ISNULL: no se permite SUM sobre una columna que acepta NULL.
CREATE OR ALTER VIEW dbo.vm_MontoOrden
WITH SCHEMABINDING
AS
SELECT
    po.SucursalID,
    po.PurchaseOrderID,
    po.SupplierID,
    YEAR(po.OrderDate) AS Anio,
    SUM(ISNULL(pol.OrderedOuters * pol.ExpectedUnitPricePerOuter, 0)) AS Monto,
    COUNT_BIG(*) AS Lineas
FROM Purchasing.PurchaseOrders po
JOIN Purchasing.PurchaseOrderLines pol
    ON pol.SucursalID = po.SucursalID
   AND pol.PurchaseOrderID = po.PurchaseOrderID
GROUP BY po.SucursalID, po.PurchaseOrderID, po.SupplierID, YEAR(po.OrderDate);
GO

CREATE UNIQUE CLUSTERED INDEX IX_vm_MontoOrden
ON dbo.vm_MontoOrden (SucursalID, PurchaseOrderID);
GO

-- Ganancia de cada producto por sucursal y año (reporte de top productos)
CREATE OR ALTER VIEW dbo.vm_GananciaProducto
WITH SCHEMABINDING
AS
SELECT
    i.SucursalID,
    YEAR(i.InvoiceDate) AS Anio,
    il.StockItemID,
    SUM(il.LineProfit) AS Ganancia,
    COUNT_BIG(*) AS Lineas
FROM Sales.Invoices i
JOIN Sales.InvoiceLines il
    ON il.SucursalID = i.SucursalID
   AND il.InvoiceID = i.InvoiceID
GROUP BY i.SucursalID, YEAR(i.InvoiceDate), il.StockItemID;
GO

CREATE UNIQUE CLUSTERED INDEX IX_vm_GananciaProducto
ON dbo.vm_GananciaProducto (SucursalID, Anio, StockItemID);
GO

-- Verificar: deben aparecer las tres vistas con su índice
SELECT v.name AS Vista, i.name AS Indice
FROM sys.views v
JOIN sys.indexes i ON i.object_id = v.object_id
WHERE v.name LIKE N'vm[_]%';
GO
