-- Demo de falla de un nodo
-- Ejecutar cada bloque en la conexión indicada y los comandos de Terminal en una terminal.
-- Mientras un nodo está apagado, la replicación guarda sus cambios en cola (hasta 72 h) y se los entrega al volver.
-- Para ver qué nodos responden, con la API encendida: curl http://localhost:3000/api/estado

-- 1. Cae una sucursal: Limón

-- Terminal: apagar Limón (en la página, admin_limon recibe "El nodo Limón no está disponible")
--   docker stop wwi_limon

-- Corporativo: cambiar el precio del producto 1
USE WideWorldImporters_Corporativo;
UPDATE Warehouse.StockItems SET UnitPrice = 30.00 WHERE StockItemID = 1;
GO

-- San José: verificar (precio 30.00, la otra sucursal sigue funcionando)
USE WideWorldImporters_SanJose;
SELECT StockItemID, UnitPrice FROM Warehouse.StockItems WHERE StockItemID = 1;
GO

-- Corporativo: el cambio para Limón queda en cola (pendingcmdcount mayor a 0)
USE distribution;
EXEC sp_replmonitorsubscriptionpendingcmds @publisher = N'wwi_corporativo',
    @publisher_db = N'WideWorldImporters_Corporativo', @publication = N'Pub_Catalogo',
    @subscriber = N'wwi_limon', @subscriber_db = N'WideWorldImporters_Limon', @subscription_type = 0;
GO

-- Terminal: encender Limón y esperar 1 minuto (el agente de replicación reintenta cada minuto)
--   docker start wwi_limon

-- Limón: verificar (precio 30.00, recibido al volver; si aún dice 25.00, esperar y repetir)
USE WideWorldImporters_Limon;
SELECT StockItemID, UnitPrice FROM Warehouse.StockItems WHERE StockItemID = 1;
GO

-- Corporativo: restaurar (25.00 es el precio de la carga inicial)
USE WideWorldImporters_Corporativo;
UPDATE Warehouse.StockItems SET UnitPrice = 25.00 WHERE StockItemID = 1;
GO


-- 2. Cae Corporativo

-- Terminal: apagar Corporativo (en la página, las sucursales siguen; estadísticas y login nuevo no)
--   docker stop wwi_corporativo

-- San José: la sucursal sigue trabajando sin Corporativo
USE WideWorldImporters_SanJose;
SELECT StockItemID, QuantityOnHand, BinLocation FROM Warehouse.StockItemHoldings WHERE StockItemID = 1;
EXEC dbo.usp_Existencias_Actualizar @ProductoID = 1, @CantidadDisponible = 500, @Ubicacion = N'SJ-1';
GO

-- Terminal: encender Corporativo y esperar 1 minuto
--   docker start wwi_corporativo

-- Corporativo: verificar (la fila de San José dice 500 y SJ-1, recibida al volver; si no, esperar y repetir)
USE WideWorldImporters_Corporativo;
SELECT SucursalID, StockItemID, QuantityOnHand, BinLocation FROM Warehouse.StockItemHoldings WHERE StockItemID = 1;
GO

-- San José: restaurar (87805 es la cantidad de la carga inicial)
USE WideWorldImporters_SanJose;
EXEC dbo.usp_Existencias_Actualizar @ProductoID = 1, @CantidadDisponible = 87805, @Ubicacion = NULL;
GO
