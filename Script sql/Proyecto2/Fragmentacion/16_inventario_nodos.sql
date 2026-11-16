-- Inventario horizontal de sucursales y tabla consolidada de Corporativo.
-- Ejecutar en las tres bases. En sucursales conserva las filas y cantidades;
-- solo agrega SucursalID (1 San Jose, 2 Limon) y la clave compuesta.
-- En Corporativo crea una tabla vacia; sus filas se cargaran o replicaran despues.
SET XACT_ABORT ON;

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51120, 'Conecte a una de las tres bases del Proyecto 2.', 1;
IF OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL
    THROW 51121, 'Ejecute primero 01_catalogo_productos.sql.', 1;
IF DB_NAME() <> N'WideWorldImporters_Corporativo' AND OBJECT_ID(N'Warehouse.StockItemHoldings', N'U') IS NULL
    THROW 51122, 'Ejecute primero 02_existencias_sucursal.sql.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF DB_NAME() = N'WideWorldImporters_Corporativo'
    BEGIN
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
                CONSTRAINT CK_Warehouse_StockItemHoldings_SucursalID CHECK (SucursalID IN (1, 2)),
                CONSTRAINT FK_Warehouse_StockItemHoldings_Item FOREIGN KEY (StockItemID)
                    REFERENCES Warehouse.StockItems(StockItemID),
                CONSTRAINT CK_Warehouse_StockItemHoldings_Quantities CHECK (
                    QuantityOnHand >= 0
                    AND (LastStocktakeQuantity IS NULL OR LastStocktakeQuantity >= 0)
                    AND (ReorderLevel IS NULL OR ReorderLevel >= 0)
                    AND (TargetStockLevel IS NULL OR TargetStockLevel >= 0)
                )
            );
    END
    ELSE
    BEGIN
        -- La tabla anterior tenia StockItemID como unica clave. El DEFAULT
        -- completa SucursalID en las filas existentes sin tocar cantidades.
        IF COL_LENGTH(N'Warehouse.StockItemHoldings', N'SucursalID') IS NULL
        BEGIN
            IF DB_NAME() = N'WideWorldImporters_SanJose'
                ALTER TABLE Warehouse.StockItemHoldings ADD SucursalID INT NOT NULL
                    CONSTRAINT DF_Warehouse_StockItemHoldings_SucursalID DEFAULT (1) WITH VALUES;
            ELSE
                ALTER TABLE Warehouse.StockItemHoldings ADD SucursalID INT NOT NULL
                    CONSTRAINT DF_Warehouse_StockItemHoldings_SucursalID DEFAULT (2) WITH VALUES;
        END;

        -- Acepta tanto la tabla antigua como una migracion reintentada.
        IF EXISTS (
            SELECT 1
            FROM sys.key_constraints AS pk
            JOIN sys.index_columns AS ic
              ON ic.object_id = pk.parent_object_id AND ic.index_id = pk.unique_index_id
            JOIN sys.columns AS c
              ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE pk.parent_object_id = OBJECT_ID(N'Warehouse.StockItemHoldings', N'U')
              AND pk.name = N'PK_Warehouse_StockItemHoldings'
              AND ic.key_ordinal = 1 AND c.name = N'StockItemID'
        )
        BEGIN
            ALTER TABLE Warehouse.StockItemHoldings DROP CONSTRAINT PK_Warehouse_StockItemHoldings;
            ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT PK_Warehouse_StockItemHoldings
                PRIMARY KEY (SucursalID, StockItemID);
        END;

        IF (
            SELECT COUNT(*)
            FROM sys.key_constraints AS pk
            JOIN sys.index_columns AS ic
              ON ic.object_id = pk.parent_object_id AND ic.index_id = pk.unique_index_id
            JOIN sys.columns AS c
              ON c.object_id = ic.object_id AND c.column_id = ic.column_id
            WHERE pk.parent_object_id = OBJECT_ID(N'Warehouse.StockItemHoldings', N'U')
              AND pk.name = N'PK_Warehouse_StockItemHoldings'
              AND ((ic.key_ordinal = 1 AND c.name = N'SucursalID')
                   OR (ic.key_ordinal = 2 AND c.name = N'StockItemID'))
        ) <> 2
            THROW 51123, 'La clave de existencias no es (SucursalID, StockItemID).', 1;

        IF DB_NAME() = N'WideWorldImporters_SanJose'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Warehouse_StockItemHoldings_SucursalID')
                EXEC(N'ALTER TABLE Warehouse.StockItemHoldings WITH CHECK ADD CONSTRAINT CK_Warehouse_StockItemHoldings_SucursalID
                    CHECK (SucursalID = 1);');
            IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Warehouse_StockItemHoldings_SucursalID')
                EXEC(N'ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT DF_Warehouse_StockItemHoldings_SucursalID
                    DEFAULT (1) FOR SucursalID;');
        END
        ELSE
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Warehouse_StockItemHoldings_SucursalID')
                EXEC(N'ALTER TABLE Warehouse.StockItemHoldings WITH CHECK ADD CONSTRAINT CK_Warehouse_StockItemHoldings_SucursalID
                    CHECK (SucursalID = 2);');
            IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Warehouse_StockItemHoldings_SucursalID')
                EXEC(N'ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT DF_Warehouse_StockItemHoldings_SucursalID
                    DEFAULT (2) FOR SucursalID;');
        END;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
