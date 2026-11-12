-- Ejecutar solo en Corporativo, después de la replicación: versión del producto para detectar ediciones simultáneas.
-- No llega a las sucursales: la publicación tiene replicate_ddl = 0.
IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51011, 'La versión de productos solo se agrega en Corporativo.', 1;
GO

IF COL_LENGTH(N'catalogo.Productos', N'Version') IS NULL
    ALTER TABLE catalogo.Productos ADD Version ROWVERSION;
GO
