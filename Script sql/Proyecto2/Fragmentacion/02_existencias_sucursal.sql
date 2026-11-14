-- Ejecutar solamente en WideWorldImporters_SanJose y WideWorldImporters_Limon,
-- despues de 01_catalogo_productos.sql.
SET XACT_ABORT ON;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51001, 'Las existencias solo se crean en una base de sucursal.', 1;
GO

IF OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL
    THROW 51002, 'Ejecute primero 01_catalogo_productos.sql.', 1;
GO

IF OBJECT_ID(N'Warehouse.StockItemHoldings', N'U') IS NULL
BEGIN
    CREATE TABLE Warehouse.StockItemHoldings (
        StockItemID INT NOT NULL CONSTRAINT PK_Warehouse_StockItemHoldings PRIMARY KEY,
        QuantityOnHand INT NOT NULL CONSTRAINT DF_Warehouse_StockItemHoldings_Quantity DEFAULT (0),
        BinLocation NVARCHAR(20) NULL,
        LastStocktakeQuantity INT NULL,
        LastCostPrice DECIMAL(18,2) NULL,
        ReorderLevel INT NULL,
        TargetStockLevel INT NULL,
        CONSTRAINT FK_Warehouse_StockItemHoldings_Item FOREIGN KEY (StockItemID)
            REFERENCES Warehouse.StockItems (StockItemID),
        CONSTRAINT CK_Warehouse_StockItemHoldings_Quantities CHECK (
            QuantityOnHand >= 0
            AND (LastStocktakeQuantity IS NULL OR LastStocktakeQuantity >= 0)
            AND (ReorderLevel IS NULL OR ReorderLevel >= 0)
            AND (TargetStockLevel IS NULL OR TargetStockLevel >= 0)
        )
    );
END;
GO
