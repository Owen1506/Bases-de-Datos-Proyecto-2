-- Ejecutar en los tres nodos: sinónimos del catálogo. Los SP usan estos nombres, como en el Proyecto 1.
IF SCHEMA_ID(N'syn') IS NULL
    EXEC(N'CREATE SCHEMA syn');
GO

DROP SYNONYM IF EXISTS syn.Productos;
CREATE SYNONYM syn.Productos FOR Warehouse.StockItems;

DROP SYNONYM IF EXISTS syn.ProductoGrupos;
CREATE SYNONYM syn.ProductoGrupos FOR Warehouse.StockItemStockGroups;

DROP SYNONYM IF EXISTS syn.ProveedoresBasicos;
CREATE SYNONYM syn.ProveedoresBasicos FOR Purchasing.Suppliers;

DROP SYNONYM IF EXISTS syn.GruposProducto;
CREATE SYNONYM syn.GruposProducto FOR Warehouse.StockGroups;

DROP SYNONYM IF EXISTS syn.Colores;
CREATE SYNONYM syn.Colores FOR Warehouse.Colors;

DROP SYNONYM IF EXISTS syn.TiposEmpaque;
CREATE SYNONYM syn.TiposEmpaque FOR Warehouse.PackageTypes;
GO

-- Solo en sucursales: inventario propio
DROP SYNONYM IF EXISTS syn.Existencias;
IF OBJECT_ID(N'Warehouse.StockItemHoldings', N'U') IS NOT NULL
    CREATE SYNONYM syn.Existencias FOR Warehouse.StockItemHoldings;
GO

-- Verificar
SELECT name AS Sinonimo, base_object_name AS Tabla FROM sys.synonyms ORDER BY name;
GO
