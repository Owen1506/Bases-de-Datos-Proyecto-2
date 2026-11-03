-- Demo de replicación
-- Ejecutar cada bloque en la conexión indicada. Esperar unos 15 s antes de verificar.

-- 1. Catálogo: Corporativo -> San José y Limón

-- Corporativo: insertar
USE WideWorldImporters_Corporativo;
INSERT INTO dbo.PruebaCatalogo (ProductoID, Nombre, Precio) VALUES (1, N'Producto de prueba', 10.00);
GO

-- San José: verificar (debe aparecer)
USE WideWorldImporters_SanJose;
SELECT ProductoID, Nombre, Precio FROM dbo.PruebaCatalogo;
GO

-- Limón: verificar (debe aparecer)
USE WideWorldImporters_Limon;
SELECT ProductoID, Nombre, Precio FROM dbo.PruebaCatalogo;
GO

-- Corporativo: actualizar
USE WideWorldImporters_Corporativo;
UPDATE dbo.PruebaCatalogo SET Precio = 12.50 WHERE ProductoID = 1;
GO

-- San José: verificar (precio 12.50)
USE WideWorldImporters_SanJose;
SELECT ProductoID, Nombre, Precio FROM dbo.PruebaCatalogo;
GO

-- Limón: verificar (precio 12.50)
USE WideWorldImporters_Limon;
SELECT ProductoID, Nombre, Precio FROM dbo.PruebaCatalogo;
GO

-- Corporativo: borrar
USE WideWorldImporters_Corporativo;
DELETE FROM dbo.PruebaCatalogo WHERE ProductoID = 1;
GO

-- San José: verificar (sin filas)
USE WideWorldImporters_SanJose;
SELECT ProductoID, Nombre, Precio FROM dbo.PruebaCatalogo;
GO

-- Limón: verificar (sin filas)
USE WideWorldImporters_Limon;
SELECT ProductoID, Nombre, Precio FROM dbo.PruebaCatalogo;
GO


-- 2. Facturas: San José -> Corporativo

-- San José: insertar
USE WideWorldImporters_SanJose;
INSERT INTO dbo.PruebaFacturas (SucursalID, FacturaID, Cliente, Monto) VALUES (1, 1, N'Cliente de prueba', 100.00);
GO

-- Corporativo: verificar (debe aparecer)
USE WideWorldImporters_Corporativo;
SELECT SucursalID, FacturaID, Cliente, Monto FROM dbo.PruebaFacturas;
GO

-- Limón: verificar (no debe aparecer)
USE WideWorldImporters_Limon;
SELECT SucursalID, FacturaID, Cliente, Monto FROM dbo.PruebaFacturas;
GO

-- San José: actualizar
USE WideWorldImporters_SanJose;
UPDATE dbo.PruebaFacturas SET Monto = 150.00 WHERE SucursalID = 1 AND FacturaID = 1;
GO

-- Corporativo: verificar (monto 150.00)
USE WideWorldImporters_Corporativo;
SELECT SucursalID, FacturaID, Cliente, Monto FROM dbo.PruebaFacturas;
GO

-- San José: borrar
USE WideWorldImporters_SanJose;
DELETE FROM dbo.PruebaFacturas WHERE SucursalID = 1 AND FacturaID = 1;
GO

-- Corporativo: verificar (sin filas)
USE WideWorldImporters_Corporativo;
SELECT SucursalID, FacturaID, Cliente, Monto FROM dbo.PruebaFacturas;
GO


-- 3. Misma factura número 1 en las dos sucursales

-- San José: insertar
USE WideWorldImporters_SanJose;
INSERT INTO dbo.PruebaFacturas (SucursalID, FacturaID, Cliente, Monto) VALUES (1, 1, N'Cliente de San José', 100.00);
GO

-- Limón: insertar
USE WideWorldImporters_Limon;
INSERT INTO dbo.PruebaFacturas (SucursalID, FacturaID, Cliente, Monto) VALUES (2, 1, N'Cliente de Limón', 200.00);
GO

-- Corporativo: verificar (deben aparecer las dos, la clave es sucursal + número)
USE WideWorldImporters_Corporativo;
SELECT SucursalID, FacturaID, Cliente, Monto FROM dbo.PruebaFacturas;
GO

-- San José: limpiar
USE WideWorldImporters_SanJose;
DELETE FROM dbo.PruebaFacturas;
GO

-- Limón: limpiar
USE WideWorldImporters_Limon;
DELETE FROM dbo.PruebaFacturas;
GO
