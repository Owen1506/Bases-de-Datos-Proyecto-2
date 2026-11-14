-- Ejecutar en cada base del Proyecto 2 tras los scripts de estructura.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51003, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

SELECT
    DB_NAME() AS Nodo,
    CASE WHEN OBJECT_ID(N'Warehouse.StockItems', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TieneStockItems,
    CASE WHEN OBJECT_ID(N'Warehouse.StockItemStockGroups', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TieneStockItemStockGroups,
    CASE WHEN OBJECT_ID(N'Warehouse.StockItemHoldings', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TieneStockItemHoldings;
GO
