-- Ejecutar en los tres nodos: sinónimos del catálogo. Los SP usan estos nombres, como en el Proyecto 1.
IF SCHEMA_ID(N'syn') IS NULL
    EXEC(N'CREATE SCHEMA syn');
GO

DROP SYNONYM IF EXISTS syn.Productos;
CREATE SYNONYM syn.Productos FOR catalogo.Productos;

DROP SYNONYM IF EXISTS syn.ProductoGrupos;
CREATE SYNONYM syn.ProductoGrupos FOR catalogo.ProductoGrupos;

DROP SYNONYM IF EXISTS syn.ProveedoresBasicos;
CREATE SYNONYM syn.ProveedoresBasicos FOR catalogo.ProveedoresBasicos;

DROP SYNONYM IF EXISTS syn.GruposProducto;
CREATE SYNONYM syn.GruposProducto FOR catalogo.GruposProducto;

DROP SYNONYM IF EXISTS syn.Colores;
CREATE SYNONYM syn.Colores FOR catalogo.Colores;

DROP SYNONYM IF EXISTS syn.TiposEmpaque;
CREATE SYNONYM syn.TiposEmpaque FOR catalogo.TiposEmpaque;
GO

-- Solo en sucursales: inventario propio
DROP SYNONYM IF EXISTS syn.Existencias;
IF OBJECT_ID(N'inventario.Existencias', N'U') IS NOT NULL
    CREATE SYNONYM syn.Existencias FOR inventario.Existencias;
GO

-- Verificar
SELECT name AS Sinonimo, base_object_name AS Tabla FROM sys.synonyms ORDER BY name;
GO
