-- Ejecutar en cada base del Proyecto 2 tras los scripts de estructura.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51003, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

SELECT
    DB_NAME() AS Nodo,
    CASE WHEN OBJECT_ID(N'catalogo.Productos', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TieneProductos,
    CASE WHEN OBJECT_ID(N'catalogo.ProductoGrupos', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TieneProductoGrupos,
    CASE WHEN OBJECT_ID(N'inventario.Existencias', N'U') IS NOT NULL THEN 1 ELSE 0 END AS TieneExistencias;
GO
