-- Ejecutar en San José y Limón: al borrar un producto (también por replicación) se borra su inventario.
IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51010, 'El trigger de existencias solo se crea en una base de sucursal.', 1;
GO

CREATE OR ALTER TRIGGER catalogo.trg_Productos_BorrarExistencias
ON catalogo.Productos
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DELETE e
    FROM inventario.Existencias e
    JOIN deleted d ON d.ProductoID = e.ProductoID;
END;
GO
