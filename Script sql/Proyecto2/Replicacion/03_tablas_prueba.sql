-- Paso 3 (los tres nodos, conectado a la base del nodo): tabla de prueba de facturas.
-- PruebaFacturas: sucursales -> Corporativo. Se cambia por las facturas reales.
IF OBJECT_ID(N'dbo.PruebaFacturas', N'U') IS NULL
    CREATE TABLE dbo.PruebaFacturas (
        SucursalID INT NOT NULL,
        FacturaID INT NOT NULL,
        Cliente NVARCHAR(100) NOT NULL,
        Monto DECIMAL(18,2) NOT NULL,
        CONSTRAINT PK_PruebaFacturas PRIMARY KEY (SucursalID, FacturaID)
    );
GO

-- Verificar: debe aparecer la tabla
SELECT DB_NAME() AS Base, name AS Tabla
FROM sys.tables
WHERE name LIKE N'Prueba%';
GO
