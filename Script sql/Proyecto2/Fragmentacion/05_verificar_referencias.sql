-- Ejecutar en cada nodo despues de cargar productos y catalogos de referencia.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51005, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF OBJECT_ID(N'catalogo.Productos', N'U') IS NULL
   OR OBJECT_ID(N'catalogo.ProductoGrupos', N'U') IS NULL
   OR OBJECT_ID(N'catalogo.ProveedoresBasicos', N'U') IS NULL
   OR OBJECT_ID(N'catalogo.GruposProducto', N'U') IS NULL
   OR OBJECT_ID(N'catalogo.Colores', N'U') IS NULL
   OR OBJECT_ID(N'catalogo.TiposEmpaque', N'U') IS NULL
    THROW 51006, 'Faltan tablas de productos o catalogos de referencia.', 1;
GO

SELECT DB_NAME() AS Nodo,
    (SELECT COUNT(*) FROM catalogo.Productos) AS Productos,
    (SELECT COUNT(*) FROM catalogo.ProveedoresBasicos) AS Proveedores,
    (SELECT COUNT(*) FROM catalogo.GruposProducto) AS Grupos,
    (SELECT COUNT(*) FROM catalogo.Colores) AS Colores,
    (SELECT COUNT(*) FROM catalogo.TiposEmpaque) AS TiposEmpaque;
GO

IF EXISTS (
    SELECT 1 FROM catalogo.Productos p
    LEFT JOIN catalogo.ProveedoresBasicos s ON s.ProveedorID = p.ProveedorID
    LEFT JOIN catalogo.Colores c ON c.ColorID = p.ColorID
    LEFT JOIN catalogo.TiposEmpaque u ON u.TipoEmpaqueID = p.UnidadEmpaqueID
    LEFT JOIN catalogo.TiposEmpaque e ON e.TipoEmpaqueID = p.EmpaqueExteriorID
    WHERE s.ProveedorID IS NULL
       OR (p.ColorID IS NOT NULL AND c.ColorID IS NULL)
       OR u.TipoEmpaqueID IS NULL OR e.TipoEmpaqueID IS NULL
)
   OR EXISTS (
    SELECT 1 FROM catalogo.ProductoGrupos pg
    LEFT JOIN catalogo.GruposProducto g ON g.GrupoID = pg.GrupoID
    WHERE g.GrupoID IS NULL
)
    THROW 51007, 'Hay productos con referencias que no existen en este nodo.', 1;
GO

SELECT DB_NAME() AS Nodo, N'CORRECTO' AS EstadoReferencias;
GO
