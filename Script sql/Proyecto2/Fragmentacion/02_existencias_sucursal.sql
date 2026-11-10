-- Ejecutar solamente en WideWorldImporters_SanJose y WideWorldImporters_Limon,
-- despues de 01_catalogo_productos.sql.
SET XACT_ABORT ON;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51001, 'Las existencias solo se crean en una base de sucursal.', 1;
GO

IF OBJECT_ID(N'catalogo.Productos', N'U') IS NULL
    THROW 51002, 'Ejecute primero 01_catalogo_productos.sql.', 1;
GO

IF SCHEMA_ID(N'inventario') IS NULL
    EXEC(N'CREATE SCHEMA inventario');
GO

IF OBJECT_ID(N'inventario.Existencias', N'U') IS NULL
BEGIN
    CREATE TABLE inventario.Existencias (
        ProductoID INT NOT NULL CONSTRAINT PK_InventarioExistencias PRIMARY KEY,
        CantidadDisponible INT NOT NULL CONSTRAINT DF_InventarioExistencias_Cantidad DEFAULT (0),
        Ubicacion NVARCHAR(20) NULL,
        CantidadUltimoConteo INT NULL,
        UltimoCosto DECIMAL(18,2) NULL,
        NivelReorden INT NULL,
        NivelObjetivo INT NULL,
        CONSTRAINT FK_InventarioExistencias_Producto FOREIGN KEY (ProductoID)
            REFERENCES catalogo.Productos (ProductoID),
        CONSTRAINT CK_InventarioExistencias_Cantidades CHECK (
            CantidadDisponible >= 0
            AND (CantidadUltimoConteo IS NULL OR CantidadUltimoConteo >= 0)
            AND (NivelReorden IS NULL OR NivelReorden >= 0)
            AND (NivelObjetivo IS NULL OR NivelObjetivo >= 0)
        )
    );
END;
GO
