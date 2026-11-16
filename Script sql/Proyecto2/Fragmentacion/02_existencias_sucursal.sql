-- Ejecutar solamente en WideWorldImporters_SanJose y WideWorldImporters_Limon,
-- despues de 01_catalogo_productos.sql. En una base nueva crea la tabla de inventario.
-- Si la tabla anterior ya existe, 16_inventario_nodos.sql migra sus filas sin borrarlas.
SET XACT_ABORT ON;

IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51001, 'Las existencias solo se crean en una base de sucursal.', 1;
IF OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL
    THROW 51002, 'Ejecute primero 01_catalogo_productos.sql.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'Warehouse.StockItemHoldings', N'U') IS NULL
        CREATE TABLE Warehouse.StockItemHoldings (
            SucursalID INT NOT NULL,
            StockItemID INT NOT NULL,
            QuantityOnHand INT NOT NULL CONSTRAINT DF_Warehouse_StockItemHoldings_Quantity DEFAULT (0),
            BinLocation NVARCHAR(20) NULL,
            LastStocktakeQuantity INT NULL,
            LastCostPrice DECIMAL(18,2) NULL,
            ReorderLevel INT NULL,
            TargetStockLevel INT NULL,
            CONSTRAINT PK_Warehouse_StockItemHoldings PRIMARY KEY (SucursalID, StockItemID),
            CONSTRAINT FK_Warehouse_StockItemHoldings_Item FOREIGN KEY (StockItemID)
                REFERENCES Warehouse.StockItems(StockItemID),
            CONSTRAINT CK_Warehouse_StockItemHoldings_Quantities CHECK (
                QuantityOnHand >= 0
                AND (LastStocktakeQuantity IS NULL OR LastStocktakeQuantity >= 0)
                AND (ReorderLevel IS NULL OR ReorderLevel >= 0)
                AND (TargetStockLevel IS NULL OR TargetStockLevel >= 0)
            )
        );

    -- En las instalaciones anteriores falta SucursalID: lo agrega el archivo 16.
    IF COL_LENGTH(N'Warehouse.StockItemHoldings', N'SucursalID') IS NOT NULL
    BEGIN
        IF DB_NAME() = N'WideWorldImporters_SanJose'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Warehouse_StockItemHoldings_SucursalID')
                ALTER TABLE Warehouse.StockItemHoldings WITH CHECK ADD CONSTRAINT CK_Warehouse_StockItemHoldings_SucursalID
                    CHECK (SucursalID = 1);
            IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Warehouse_StockItemHoldings_SucursalID')
                ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT DF_Warehouse_StockItemHoldings_SucursalID
                    DEFAULT (1) FOR SucursalID;
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Warehouse_StockItemHoldings_SucursalID')
                ALTER TABLE Warehouse.StockItemHoldings WITH CHECK ADD CONSTRAINT CK_Warehouse_StockItemHoldings_SucursalID
                    CHECK (SucursalID = 2);
            IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Warehouse_StockItemHoldings_SucursalID')
                ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT DF_Warehouse_StockItemHoldings_SucursalID
                    DEFAULT (2) FOR SucursalID;
        END;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
