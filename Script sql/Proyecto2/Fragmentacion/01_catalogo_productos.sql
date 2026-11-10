-- Ejecutar en WideWorldImporters_Corporativo, WideWorldImporters_SanJose
-- y WideWorldImporters_Limon. El catálogo tiene la misma estructura en los tres nodos.
SET XACT_ABORT ON;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51000, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF SCHEMA_ID(N'catalogo') IS NULL
    EXEC(N'CREATE SCHEMA catalogo');
GO

IF OBJECT_ID(N'catalogo.Productos', N'U') IS NULL
BEGIN
    CREATE TABLE catalogo.Productos (
        ProductoID INT NOT NULL CONSTRAINT PK_CatalogoProductos PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL,
        ProveedorID INT NOT NULL,
        ColorID INT NULL,
        UnidadEmpaqueID INT NOT NULL,
        EmpaqueExteriorID INT NOT NULL,
        Marca NVARCHAR(50) NULL,
        Tamano NVARCHAR(20) NULL,
        DiasEntrega INT NOT NULL,
        CantidadPorEmpaque INT NOT NULL,
        EsRefrigerado BIT NOT NULL,
        CodigoBarras NVARCHAR(50) NULL,
        Impuesto DECIMAL(18,3) NOT NULL,
        PrecioUnitario DECIMAL(18,2) NOT NULL,
        PrecioVenta DECIMAL(18,2) NULL,
        Peso DECIMAL(18,3) NOT NULL,
        ComentariosMarketing NVARCHAR(MAX) NULL,
        CONSTRAINT UQ_CatalogoProductos_Nombre UNIQUE (Nombre),
        CONSTRAINT CK_CatalogoProductos_Precios CHECK (PrecioUnitario >= 0 AND (PrecioVenta IS NULL OR PrecioVenta >= 0)),
        CONSTRAINT CK_CatalogoProductos_Cantidades CHECK (CantidadPorEmpaque > 0 AND DiasEntrega >= 0 AND Peso > 0),
        CONSTRAINT CK_CatalogoProductos_Impuesto CHECK (Impuesto BETWEEN 0 AND 100)
    );
END;
GO

IF OBJECT_ID(N'catalogo.ProductoGrupos', N'U') IS NULL
BEGIN
    CREATE TABLE catalogo.ProductoGrupos (
        ProductoID INT NOT NULL,
        GrupoID INT NOT NULL,
        CONSTRAINT PK_CatalogoProductoGrupos PRIMARY KEY (ProductoID, GrupoID),
        CONSTRAINT FK_CatalogoProductoGrupos_Producto FOREIGN KEY (ProductoID)
            REFERENCES catalogo.Productos (ProductoID) ON DELETE CASCADE
    );
END;
GO
