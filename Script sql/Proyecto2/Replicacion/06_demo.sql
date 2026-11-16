-- Demo de replicación
-- Ejecutar cada bloque en la conexión indicada. Esperar unos 15 s antes de verificar.

-- 1. Catálogo: Corporativo -> San José y Limón

-- Corporativo: insertar un producto con su grupo
USE WideWorldImporters_Corporativo;
INSERT INTO Warehouse.StockItems (StockItemID, StockItemName, SupplierID, UnitPackageID, OuterPackageID,
    LeadTimeDays, QuantityPerOuter, IsChillerStock, TaxRate, UnitPrice, TypicalWeightPerUnit)
VALUES (1000, N'Producto de prueba', 1, 7, 7, 7, 1, 0, 15, 10.00, 0.5);
INSERT INTO Warehouse.StockItemStockGroups (StockItemID, StockGroupID) VALUES (1000, 1);
GO

-- San José: verificar (debe aparecer con su grupo)
USE WideWorldImporters_SanJose;
SELECT p.StockItemID, p.StockItemName, p.UnitPrice, g.StockGroupID
FROM Warehouse.StockItems p LEFT JOIN Warehouse.StockItemStockGroups g ON g.StockItemID = p.StockItemID
WHERE p.StockItemID = 1000;
GO

-- Limón: verificar (debe aparecer con su grupo)
USE WideWorldImporters_Limon;
SELECT p.StockItemID, p.StockItemName, p.UnitPrice, g.StockGroupID
FROM Warehouse.StockItems p LEFT JOIN Warehouse.StockItemStockGroups g ON g.StockItemID = p.StockItemID
WHERE p.StockItemID = 1000;
GO

-- Corporativo: actualizar
USE WideWorldImporters_Corporativo;
UPDATE Warehouse.StockItems SET UnitPrice = 12.50 WHERE StockItemID = 1000;
GO

-- San José: verificar (precio 12.50)
USE WideWorldImporters_SanJose;
SELECT StockItemID, StockItemName, UnitPrice FROM Warehouse.StockItems WHERE StockItemID = 1000;
GO

-- Limón: verificar (precio 12.50)
USE WideWorldImporters_Limon;
SELECT StockItemID, StockItemName, UnitPrice FROM Warehouse.StockItems WHERE StockItemID = 1000;
GO

-- Corporativo: borrar (el grupo se borra en cascada)
USE WideWorldImporters_Corporativo;
DELETE FROM Warehouse.StockItems WHERE StockItemID = 1000;
GO

-- San José: verificar (sin filas)
USE WideWorldImporters_SanJose;
SELECT StockItemID, StockItemName, UnitPrice FROM Warehouse.StockItems WHERE StockItemID = 1000;
GO

-- Limón: verificar (sin filas)
USE WideWorldImporters_Limon;
SELECT StockItemID, StockItemName, UnitPrice FROM Warehouse.StockItems WHERE StockItemID = 1000;
GO


-- 2. Inventario: San José -> Corporativo

-- San José: ver la cantidad actual del producto 1 y cambiarla
USE WideWorldImporters_SanJose;
SELECT StockItemID, QuantityOnHand, BinLocation FROM Warehouse.StockItemHoldings WHERE StockItemID = 1;
EXEC dbo.usp_Existencias_Actualizar @ProductoID = 1, @CantidadDisponible = 500, @Ubicacion = N'SJ-1';
GO

-- Corporativo: verificar (la fila de San José dice 500 y SJ-1, la de Limón no cambia)
USE WideWorldImporters_Corporativo;
SELECT SucursalID, StockItemID, QuantityOnHand, BinLocation FROM Warehouse.StockItemHoldings WHERE StockItemID = 1;
GO

-- Limón: verificar (su cantidad no cambia)
USE WideWorldImporters_Limon;
SELECT StockItemID, QuantityOnHand, BinLocation FROM Warehouse.StockItemHoldings WHERE StockItemID = 1;
GO

-- San José: restaurar (87805 es la cantidad de la carga inicial)
USE WideWorldImporters_SanJose;
EXEC dbo.usp_Existencias_Actualizar @ProductoID = 1, @CantidadDisponible = 87805, @Ubicacion = NULL;
GO


-- 3. Total de la empresa: Corporativo suma las dos sucursales

USE WideWorldImporters_Corporativo;
SELECT StockItemID, SUM(QuantityOnHand) AS TotalEmpresa
FROM Warehouse.StockItemHoldings
WHERE StockItemID = 1
GROUP BY StockItemID;
GO
