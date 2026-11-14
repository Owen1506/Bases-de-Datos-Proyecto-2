-- Catálogos locales utilizados por clientes, proveedores y ventas.
-- Ejecutar en San José y Limón.
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_CategoriasCliente
AS
BEGIN
    SET NOCOUNT ON;
    SELECT CustomerCategoryID AS CategoriaClienteID,
           CustomerCategoryName AS Nombre
    FROM Sales.CustomerCategories
    ORDER BY CustomerCategoryName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_GruposCompra
AS
BEGIN
    SET NOCOUNT ON;
    SELECT BuyingGroupID AS GrupoCompraID, BuyingGroupName AS Nombre
    FROM Sales.BuyingGroups
    ORDER BY BuyingGroupName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_CategoriasProveedor
AS
BEGIN
    SET NOCOUNT ON;
    SELECT SupplierCategoryID AS CategoriaProveedorID,
           SupplierCategoryName AS Nombre
    FROM Purchasing.SupplierCategories
    ORDER BY SupplierCategoryName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_MetodosEntrega
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DeliveryMethodID AS MetodoEntregaID,
           DeliveryMethodName AS Nombre
    FROM Application.DeliveryMethods
    ORDER BY DeliveryMethodName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Ciudades
    @Busqueda NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT c.CityID AS CiudadID,
           c.CityName AS Ciudad,
           sp.StateProvinceName AS Provincia,
           co.CountryName AS Pais
    FROM Application.Cities AS c
    JOIN Application.StateProvinces AS sp ON sp.StateProvinceID = c.StateProvinceID
    JOIN Application.Countries AS co ON co.CountryID = sp.CountryID
    WHERE @Busqueda IS NULL OR c.CityName LIKE N'%' + @Busqueda + N'%'
    ORDER BY c.CityName, sp.StateProvinceName;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_Vendedores
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SucursalID INT = TRY_CONVERT(INT, SESSION_CONTEXT(N'SucursalID'));
    IF @SucursalID NOT IN (1, 2)
        THROW 51200, 'No existe una sucursal válida en la sesión.', 1;

    SELECT PersonID AS VendedorID, FullName AS Nombre
    FROM Application.People
    WHERE IsSalesperson = 1 AND SucursalID = @SucursalID
    ORDER BY FullName;
END;
GO
