-- Sinonimos locales de facturas, ordenes e inventario en cada nodo.
-- Ejecutar despues de 12-16 en la base que corresponda.
-- Las publicaciones y los linked servers se configuraran por separado.
SET XACT_ABORT ON;

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51130, 'Conecte a una de las tres bases del Proyecto 2.', 1;
IF OBJECT_ID(N'Sales.Invoices', N'U') IS NULL OR
   OBJECT_ID(N'Sales.InvoiceLines', N'U') IS NULL OR
   OBJECT_ID(N'Purchasing.PurchaseOrders', N'U') IS NULL OR
   OBJECT_ID(N'Purchasing.PurchaseOrderLines', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.StockItemHoldings', N'U') IS NULL
    THROW 51131, 'Faltan tablas de facturas, ordenes o inventario.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF SCHEMA_ID(N'syn') IS NULL EXEC(N'CREATE SCHEMA syn');

    DROP SYNONYM IF EXISTS syn.Invoices;
    CREATE SYNONYM syn.Invoices FOR Sales.Invoices;
    DROP SYNONYM IF EXISTS syn.InvoiceLines;
    CREATE SYNONYM syn.InvoiceLines FOR Sales.InvoiceLines;
    DROP SYNONYM IF EXISTS syn.PurchaseOrders;
    CREATE SYNONYM syn.PurchaseOrders FOR Purchasing.PurchaseOrders;
    DROP SYNONYM IF EXISTS syn.PurchaseOrderLines;
    CREATE SYNONYM syn.PurchaseOrderLines FOR Purchasing.PurchaseOrderLines;
    DROP SYNONYM IF EXISTS syn.Existencias;
    CREATE SYNONYM syn.Existencias FOR Warehouse.StockItemHoldings;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
