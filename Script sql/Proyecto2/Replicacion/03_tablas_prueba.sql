-- Paso 3 (los tres nodos, conectado a la base del nodo): tablas de prueba.
-- PruebaCatalogo: Corporativo -> sucursales. PruebaFacturas: sucursales -> Corporativo.
IF OBJECT_ID(N'dbo.PruebaCatalogo', N'U') IS NULL
    CREATE TABLE dbo.PruebaCatalogo (
        ProductoID INT NOT NULL PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL,
        Precio DECIMAL(18,2) NOT NULL
    );

IF OBJECT_ID(N'dbo.PruebaFacturas', N'U') IS NULL
    CREATE TABLE dbo.PruebaFacturas (
        SucursalID INT NOT NULL,
        FacturaID INT NOT NULL,
        Cliente NVARCHAR(100) NOT NULL,
        Monto DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_PruebaFacturas PRIMARY KEY (SucursalID, FacturaID)
    );
GO

-- Verificar: deben aparecer las dos tablas
SELECT DB_NAME() AS Base, name AS Tabla
FROM sys.tables
WHERE name LIKE N'Prueba%';
GO
