-- Paso 3 (San José y Limón, conectado a la base del nodo): llaves foráneas con NOT FOR REPLICATION.
-- Los cambios que llegan desde Corporativo no se validan contra estas llaves.
ALTER TABLE catalogo.ProductoGrupos DROP CONSTRAINT FK_CatalogoProductoGrupos_Producto;
ALTER TABLE catalogo.ProductoGrupos ADD CONSTRAINT FK_CatalogoProductoGrupos_Producto
    FOREIGN KEY (ProductoID) REFERENCES catalogo.Productos (ProductoID)
    ON DELETE CASCADE NOT FOR REPLICATION;

ALTER TABLE inventario.Existencias DROP CONSTRAINT FK_InventarioExistencias_Producto;
ALTER TABLE inventario.Existencias ADD CONSTRAINT FK_InventarioExistencias_Producto
    FOREIGN KEY (ProductoID) REFERENCES catalogo.Productos (ProductoID)
    NOT FOR REPLICATION;
GO

-- Verificar: las dos llaves deben decir NotForReplication = 1
SELECT name AS Llave, is_not_for_replication AS NotForReplication
FROM sys.foreign_keys
WHERE name IN (N'FK_CatalogoProductoGrupos_Producto', N'FK_InventarioExistencias_Producto');
GO
