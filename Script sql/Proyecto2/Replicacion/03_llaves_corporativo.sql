-- Paso 3 (Corporativo): el inventario consolidado se borra junto con el producto.
-- NOT FOR REPLICATION: las filas que llegan de las sucursales no se validan contra esta llave.
USE WideWorldImporters_Corporativo;
GO

ALTER TABLE Warehouse.StockItemHoldings DROP CONSTRAINT FK_Warehouse_StockItemHoldings_Item;
ALTER TABLE Warehouse.StockItemHoldings ADD CONSTRAINT FK_Warehouse_StockItemHoldings_Item
    FOREIGN KEY (StockItemID) REFERENCES Warehouse.StockItems (StockItemID)
    ON DELETE CASCADE NOT FOR REPLICATION;
GO

-- Verificar: debe decir CASCADE y NotForReplication = 1
SELECT name AS Llave, delete_referential_action_desc AS AlBorrar, is_not_for_replication AS NotForReplication
FROM sys.foreign_keys
WHERE name = N'FK_Warehouse_StockItemHoldings_Item';
GO
