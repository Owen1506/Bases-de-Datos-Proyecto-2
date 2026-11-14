-- Ejecutar en Corporativo, San José y Limón antes de cargar los catálogos.
-- Solo se copia el ID y nombre del proveedor; los datos de contacto y bancarios
-- permanecen fuera de las sucursales.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51004, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF SCHEMA_ID(N'Warehouse') IS NULL EXEC(N'CREATE SCHEMA Warehouse');
IF SCHEMA_ID(N'Purchasing') IS NULL EXEC(N'CREATE SCHEMA Purchasing');
GO

IF OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE Purchasing.Suppliers (
        SupplierID INT NOT NULL CONSTRAINT PK_Purchasing_Suppliers PRIMARY KEY,
        SupplierName NVARCHAR(100) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'Warehouse.StockGroups', N'U') IS NULL
BEGIN
    CREATE TABLE Warehouse.StockGroups (
        StockGroupID INT NOT NULL CONSTRAINT PK_Warehouse_StockGroups PRIMARY KEY,
        StockGroupName NVARCHAR(50) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'Warehouse.Colors', N'U') IS NULL
BEGIN
    CREATE TABLE Warehouse.Colors (
        ColorID INT NOT NULL CONSTRAINT PK_Warehouse_Colors PRIMARY KEY,
        ColorName NVARCHAR(20) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'Warehouse.PackageTypes', N'U') IS NULL
BEGIN
    CREATE TABLE Warehouse.PackageTypes (
        PackageTypeID INT NOT NULL CONSTRAINT PK_Warehouse_PackageTypes PRIMARY KEY,
        PackageTypeName NVARCHAR(50) NOT NULL
    );
END;
GO
