-- Ejecutar en cada nodo despues de cargar productos y catalogos de referencia.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51005, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL
   OR OBJECT_ID(N'Warehouse.StockItemStockGroups', N'U') IS NULL
   OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL
   OR OBJECT_ID(N'Warehouse.StockGroups', N'U') IS NULL
   OR OBJECT_ID(N'Warehouse.Colors', N'U') IS NULL
   OR OBJECT_ID(N'Warehouse.PackageTypes', N'U') IS NULL
    THROW 51006, 'Faltan tablas de productos o catalogos de referencia.', 1;
GO

SELECT DB_NAME() AS Nodo,
    (SELECT COUNT(*) FROM Warehouse.StockItems) AS Productos,
    (SELECT COUNT(*) FROM Purchasing.Suppliers) AS Proveedores,
    (SELECT COUNT(*) FROM Warehouse.StockGroups) AS Grupos,
    (SELECT COUNT(*) FROM Warehouse.Colors) AS Colores,
    (SELECT COUNT(*) FROM Warehouse.PackageTypes) AS TiposEmpaque;
GO

IF EXISTS (
    SELECT 1 FROM Warehouse.StockItems p
    LEFT JOIN Purchasing.Suppliers s ON s.SupplierID = p.SupplierID
    LEFT JOIN Warehouse.Colors c ON c.ColorID = p.ColorID
    LEFT JOIN Warehouse.PackageTypes u ON u.PackageTypeID = p.UnitPackageID
    LEFT JOIN Warehouse.PackageTypes e ON e.PackageTypeID = p.OuterPackageID
    WHERE s.SupplierID IS NULL
       OR (p.ColorID IS NOT NULL AND c.ColorID IS NULL)
       OR u.PackageTypeID IS NULL OR e.PackageTypeID IS NULL
)
   OR EXISTS (
    SELECT 1 FROM Warehouse.StockItemStockGroups pg
    LEFT JOIN Warehouse.StockGroups g ON g.StockGroupID = pg.StockGroupID
    WHERE g.StockGroupID IS NULL
)
    THROW 51007, 'Hay productos con referencias que no existen en este nodo.', 1;
GO

SELECT DB_NAME() AS Nodo, N'CORRECTO' AS EstadoReferencias;
GO
