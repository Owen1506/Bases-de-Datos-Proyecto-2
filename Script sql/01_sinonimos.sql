-- 01_sinonimos.sql
-- Sinonimos de las tablas, los SP usan estos nombres en vez de las tablas
USE WideWorldImporters;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'syn')
    EXEC('CREATE SCHEMA syn');
GO

-- Clientes
DROP SYNONYM IF EXISTS syn.Customers;
CREATE SYNONYM syn.Customers FOR Sales.Customers;

DROP SYNONYM IF EXISTS syn.CustomerCategories;
CREATE SYNONYM syn.CustomerCategories FOR Sales.CustomerCategories;

DROP SYNONYM IF EXISTS syn.BuyingGroups;
CREATE SYNONYM syn.BuyingGroups FOR Sales.BuyingGroups;

DROP SYNONYM IF EXISTS syn.DeliveryMethods;
CREATE SYNONYM syn.DeliveryMethods FOR Application.DeliveryMethods;

DROP SYNONYM IF EXISTS syn.People;
CREATE SYNONYM syn.People FOR Application.People;

DROP SYNONYM IF EXISTS syn.Cities;
CREATE SYNONYM syn.Cities FOR Application.Cities;

DROP SYNONYM IF EXISTS syn.StateProvinces;
CREATE SYNONYM syn.StateProvinces FOR Application.StateProvinces;
GO

-- Proveedores
DROP SYNONYM IF EXISTS syn.Suppliers;
CREATE SYNONYM syn.Suppliers FOR Purchasing.Suppliers;

DROP SYNONYM IF EXISTS syn.SupplierCategories;
CREATE SYNONYM syn.SupplierCategories FOR Purchasing.SupplierCategories;
GO

-- Inventario
DROP SYNONYM IF EXISTS syn.StockItems;
CREATE SYNONYM syn.StockItems FOR Warehouse.StockItems;

DROP SYNONYM IF EXISTS syn.StockItemHoldings;
CREATE SYNONYM syn.StockItemHoldings FOR Warehouse.StockItemHoldings;

DROP SYNONYM IF EXISTS syn.StockGroups;
CREATE SYNONYM syn.StockGroups FOR Warehouse.StockGroups;

DROP SYNONYM IF EXISTS syn.StockItemStockGroups;
CREATE SYNONYM syn.StockItemStockGroups FOR Warehouse.StockItemStockGroups;

DROP SYNONYM IF EXISTS syn.Colors;
CREATE SYNONYM syn.Colors FOR Warehouse.Colors;

DROP SYNONYM IF EXISTS syn.PackageTypes;
CREATE SYNONYM syn.PackageTypes FOR Warehouse.PackageTypes;
GO

-- Ventas
DROP SYNONYM IF EXISTS syn.Invoices;
CREATE SYNONYM syn.Invoices FOR Sales.Invoices;

DROP SYNONYM IF EXISTS syn.InvoiceLines;
CREATE SYNONYM syn.InvoiceLines FOR Sales.InvoiceLines;
GO

-- Estadisticas
DROP SYNONYM IF EXISTS syn.PurchaseOrders;
CREATE SYNONYM syn.PurchaseOrders FOR Purchasing.PurchaseOrders;

DROP SYNONYM IF EXISTS syn.PurchaseOrderLines;
CREATE SYNONYM syn.PurchaseOrderLines FOR Purchasing.PurchaseOrderLines;
GO