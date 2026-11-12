-- Ejecutar en Corporativo, San José y Limón antes de cargar los catálogos.
-- Solo se copia el ID y nombre del proveedor; los datos de contacto y bancarios
-- permanecen fuera de las sucursales.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51004, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF SCHEMA_ID(N'catalogo') IS NULL
    EXEC(N'CREATE SCHEMA catalogo');
GO

IF OBJECT_ID(N'catalogo.ProveedoresBasicos', N'U') IS NULL
BEGIN
    CREATE TABLE catalogo.ProveedoresBasicos (
        ProveedorID INT NOT NULL CONSTRAINT PK_CatalogoProveedoresBasicos PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'catalogo.GruposProducto', N'U') IS NULL
BEGIN
    CREATE TABLE catalogo.GruposProducto (
        GrupoID INT NOT NULL CONSTRAINT PK_CatalogoGruposProducto PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'catalogo.Colores', N'U') IS NULL
BEGIN
    CREATE TABLE catalogo.Colores (
        ColorID INT NOT NULL CONSTRAINT PK_CatalogoColores PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL
    );
END;
GO

IF OBJECT_ID(N'catalogo.TiposEmpaque', N'U') IS NULL
BEGIN
    CREATE TABLE catalogo.TiposEmpaque (
        TipoEmpaqueID INT NOT NULL CONSTRAINT PK_CatalogoTiposEmpaque PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL
    );
END;
GO
