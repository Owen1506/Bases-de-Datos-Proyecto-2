-- 02_sp_catalogos.sql
-- SP para llenar los selects de los filtros
USE WideWorldImporters;
GO

-- Opciones que SQL Server exige para tablas con columnas calculadas o indices filtrados
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_CategoriasCliente
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CustomerCategoryID AS CategoriaID, CustomerCategoryName AS Categoria
    FROM syn.CustomerCategories
    ORDER BY CustomerCategoryName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_MetodosEntrega
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DeliveryMethodID AS MetodoEntregaID, DeliveryMethodName AS MetodoEntrega
    FROM syn.DeliveryMethods
    ORDER BY DeliveryMethodName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_GruposCompra
AS
BEGIN
    SET NOCOUNT ON;

    SELECT BuyingGroupID AS GrupoCompraID, BuyingGroupName AS GrupoCompra
    FROM syn.BuyingGroups
    ORDER BY BuyingGroupName;
END;
GO

-- Los siguientes son buscadores para el formulario de clientes.
-- Como hay muchas ciudades y personas, se devuelven solo las primeras 20 que coinciden.

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_BuscarCiudades
    @Texto NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 20 ci.CityID AS CiudadID,
           ci.CityName + ', ' + sp.StateProvinceName AS Ciudad
    FROM syn.Cities ci
    JOIN syn.StateProvinces sp ON sp.StateProvinceID = ci.StateProvinceID
    WHERE ci.CityName LIKE @Texto + '%'
    ORDER BY ci.CityName, sp.StateProvinceName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_BuscarPersonas
    @Texto NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 20 PersonID AS PersonaID, FullName AS Persona
    FROM syn.People
    WHERE FullName LIKE '%' + @Texto + '%'
    ORDER BY FullName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_BuscarClientes
    @Texto NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 20 CustomerID AS ClienteID, CustomerName AS Cliente
    FROM syn.Customers
    WHERE CustomerName LIKE '%' + @Texto + '%'
    ORDER BY CustomerName;
END;
GO

-- Buscadores para las sugerencias del filtro de nombre de proveedores e inventario

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_BuscarProveedores
    @Texto NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 20 SupplierID AS ProveedorID, SupplierName AS Proveedor
    FROM syn.Suppliers
    WHERE SupplierName LIKE '%' + @Texto + '%'
    ORDER BY SupplierName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_BuscarProductos
    @Texto NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 20 StockItemID AS ProductoID, StockItemName AS Producto
    FROM syn.StockItems
    WHERE StockItemName LIKE '%' + @Texto + '%'
    ORDER BY StockItemName;
END;
GO

-- Catalogos de proveedores

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_CategoriasProveedor
AS
BEGIN
    SET NOCOUNT ON;

    SELECT SupplierCategoryID AS CategoriaID, SupplierCategoryName AS Categoria
    FROM syn.SupplierCategories
    ORDER BY SupplierCategoryName;
END;
GO

-- Catalogos de inventario y ventas

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_GruposInventario
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        StockGroupID AS GrupoID,
        StockGroupName AS Grupo
    FROM syn.StockGroups
    ORDER BY StockGroupName ASC;
END;
GO


CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Colores
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ColorID,
        ColorName AS Color
    FROM syn.Colors
    ORDER BY ColorName ASC;
END;
GO


CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_TiposEmpaque
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PackageTypeID AS TipoEmpaqueID,
        PackageTypeName AS TipoEmpaque
    FROM syn.PackageTypes
    ORDER BY PackageTypeName ASC;
END;
GO


CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Proveedores
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SupplierID AS ProveedorID,
        SupplierName AS Proveedor
    FROM syn.Suppliers
    ORDER BY SupplierName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Clientes
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CustomerID AS ClienteID,
        CustomerName AS Cliente
    FROM syn.Customers
    ORDER BY CustomerName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Vendedores
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PersonID AS VendedorID,
        FullName AS Vendedor
    FROM syn.People
    WHERE IsSalesperson = 1
    ORDER BY FullName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_ContactosCliente
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.PersonID AS ContactoID,
        p.FullName AS Contacto,
        'Primario' AS Tipo
    FROM syn.Customers c
    JOIN syn.People p
        ON p.PersonID = c.PrimaryContactPersonID
    WHERE c.CustomerID = @ClienteID

    UNION ALL

    SELECT
        p.PersonID,
        p.FullName,
        'Alternativo'
    FROM syn.Customers c
    JOIN syn.People p
        ON p.PersonID = c.AlternateContactPersonID
    WHERE c.CustomerID = @ClienteID
      AND c.AlternateContactPersonID IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Productos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        StockItemID AS ProductoID,
        StockItemName AS Producto,
        UnitPrice AS PrecioUnitario,
        TaxRate AS Impuesto
    FROM syn.StockItems
    ORDER BY StockItemName ASC;
END;
GO
