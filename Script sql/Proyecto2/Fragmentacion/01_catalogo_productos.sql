-- Ejecutar en WideWorldImporters_Corporativo, WideWorldImporters_SanJose
-- y WideWorldImporters_Limon. El catálogo tiene la misma estructura en los tres nodos.
SET XACT_ABORT ON;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51000, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF SCHEMA_ID(N'Warehouse') IS NULL
    EXEC(N'CREATE SCHEMA Warehouse');
GO

IF OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL
BEGIN
    CREATE TABLE Warehouse.StockItems (
        StockItemID INT NOT NULL CONSTRAINT PK_Warehouse_StockItems PRIMARY KEY,
        StockItemName NVARCHAR(100) NOT NULL,
        SupplierID INT NOT NULL,
        ColorID INT NULL,
        UnitPackageID INT NOT NULL,
        OuterPackageID INT NOT NULL,
        Brand NVARCHAR(50) NULL,
        Size NVARCHAR(20) NULL,
        LeadTimeDays INT NOT NULL,
        QuantityPerOuter INT NOT NULL,
        IsChillerStock BIT NOT NULL,
        Barcode NVARCHAR(50) NULL,
        TaxRate DECIMAL(18,3) NOT NULL,
        UnitPrice DECIMAL(18,2) NOT NULL,
        RecommendedRetailPrice DECIMAL(18,2) NULL,
        TypicalWeightPerUnit DECIMAL(18,3) NOT NULL,
        MarketingComments NVARCHAR(MAX) NULL,
        CONSTRAINT UQ_Warehouse_StockItems_Name UNIQUE (StockItemName),
        CONSTRAINT CK_Warehouse_StockItems_Prices CHECK (UnitPrice >= 0 AND (RecommendedRetailPrice IS NULL OR RecommendedRetailPrice >= 0)),
        CONSTRAINT CK_Warehouse_StockItems_Quantities CHECK (QuantityPerOuter > 0 AND LeadTimeDays >= 0 AND TypicalWeightPerUnit > 0),
        CONSTRAINT CK_Warehouse_StockItems_Tax CHECK (TaxRate BETWEEN 0 AND 100)
    );
END;
GO

IF OBJECT_ID(N'Warehouse.StockItemStockGroups', N'U') IS NULL
BEGIN
    CREATE TABLE Warehouse.StockItemStockGroups (
        StockItemID INT NOT NULL,
        StockGroupID INT NOT NULL,
        CONSTRAINT PK_Warehouse_StockItemStockGroups PRIMARY KEY (StockItemID, StockGroupID),
        CONSTRAINT FK_Warehouse_StockItemStockGroups_Item FOREIGN KEY (StockItemID)
            REFERENCES Warehouse.StockItems (StockItemID) ON DELETE CASCADE
    );
END;
GO
