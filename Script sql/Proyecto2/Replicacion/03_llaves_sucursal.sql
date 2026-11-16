-- Paso 3 (San José y Limón, conectado a la base del nodo): llaves foráneas con NOT FOR REPLICATION.
-- Los cambios que llegan desde Corporativo no se validan contra estas llaves.
ALTER TABLE Warehouse.StockItemStockGroups DROP CONSTRAINT FK_Warehouse_StockItemStockGroups_Item;
ALTER TABLE Warehouse.StockItemStockGroups ADD CONSTRAINT FK_Warehouse_StockItemStockGroups_Item
    FOREIGN KEY (StockItemID) REFERENCES Warehouse.StockItems (StockItemID)
    ON DELETE CASCADE NOT FOR REPLICATION;

ALTER TABLE Warehouse.StockItemHoldings DROP CONSTRAINT FK_Warehouse_StockItemHoldings_Item;
ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT FK_Warehouse_StockItemHoldings_Item
    FOREIGN KEY (StockItemID) REFERENCES Warehouse.StockItems (StockItemID)
    NOT FOR REPLICATION;
GO

-- Verificar: las dos llaves deben decir NotForReplication = 1
SELECT name AS Llave, is_not_for_replication AS NotForReplication
FROM sys.foreign_keys
WHERE name IN (N'FK_Warehouse_StockItemStockGroups_Item', N'FK_Warehouse_StockItemHoldings_Item');
GO
