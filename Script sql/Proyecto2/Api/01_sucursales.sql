-- Compatibilidad de la API con las bases de sucursal. No modifica datos.
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
    FROM Warehouse.StockItems
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
    FROM Warehouse.StockGroups
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
    FROM Warehouse.Colors
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
    FROM Warehouse.PackageTypes
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
    WHERE IsSalesperson = 1 AND SucursalID = TRY_CONVERT(INT, SESSION_CONTEXT(N'SucursalID'))
    ORDER BY FullName ASC;
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
    FROM Warehouse.StockItems
    ORDER BY StockItemName ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Listar
    @Nombre NVARCHAR(100) = NULL,
    @CategoriaID INT = NULL,
    @MetodoEntregaID INT = NULL,
    @Pagina INT = 1,
    @TamanoPagina INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    -- si viene vacio es como no filtrar
    IF @Nombre = '' SET @Nombre = NULL;

    IF @Pagina < 1 SET @Pagina = 1;
    IF @TamanoPagina < 1 SET @TamanoPagina = 10;

    SELECT c.CustomerID AS ClienteID,
           c.CustomerName AS Nombre,
           cc.CustomerCategoryName AS Categoria,
           dm.DeliveryMethodName AS MetodoEntrega,
           COUNT(*) OVER () AS TotalRegistros
    FROM syn.Customers c
    JOIN syn.CustomerCategories cc ON cc.CustomerCategoryID = c.CustomerCategoryID
    JOIN syn.DeliveryMethods dm ON dm.DeliveryMethodID = c.DeliveryMethodID
    WHERE (@Nombre IS NULL OR c.CustomerName LIKE '%' + @Nombre + '%')
      AND (@CategoriaID IS NULL OR c.CustomerCategoryID = @CategoriaID)
      AND (@MetodoEntregaID IS NULL OR c.DeliveryMethodID = @MetodoEntregaID)
    ORDER BY c.CustomerName
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Listar
    @Nombre NVARCHAR(100) = NULL,
    @CategoriaID INT = NULL,
    @Pagina INT = 1,
    @TamanoPagina INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @Nombre = ''
        SET @Nombre = NULL;

    IF @Pagina < 1
        SET @Pagina = 1;

    IF @TamanoPagina < 1 SET @TamanoPagina = 10;

    SELECT
        s.SupplierID AS ProveedorID,
        s.SupplierName AS Nombre,
        sc.SupplierCategoryName AS Categoria,
        dm.DeliveryMethodName AS MetodoEntrega,
        COUNT(*) OVER() AS TotalRegistros
    FROM syn.Suppliers s
    JOIN syn.SupplierCategories sc
        ON sc.SupplierCategoryID = s.SupplierCategoryID
    LEFT JOIN syn.DeliveryMethods dm
        ON dm.DeliveryMethodID = s.DeliveryMethodID
    WHERE
        (@Nombre IS NULL OR s.SupplierName LIKE '%' + @Nombre + '%')
        AND (@CategoriaID IS NULL OR s.SupplierCategoryID = @CategoriaID)
    ORDER BY s.SupplierName ASC
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Listar
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NombreCliente NVARCHAR(100) = NULL,
    @MontoMin DECIMAL(18,2) = NULL,
    @MontoMax DECIMAL(18,2) = NULL,
    @Pagina INT = 1,
    @TamanoPagina INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    IF @NombreCliente = ''
        SET @NombreCliente = NULL;

    IF @Pagina < 1
        SET @Pagina = 1;

    -- los rangos deben tener sentido
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaInicio > @FechaFin
    BEGIN
        THROW 50011, 'La fecha inicial no puede ser mayor que la fecha final.', 1;
    END;

    IF @MontoMin IS NOT NULL AND @MontoMax IS NOT NULL AND @MontoMin > @MontoMax
    BEGIN
        THROW 50012, 'El monto mínimo no puede ser mayor que el monto máximo.', 1;
    END;

    IF @TamanoPagina < 1 SET @TamanoPagina = 10;

    SELECT
        i.InvoiceID AS FacturaID,
        i.InvoiceDate AS Fecha,
        c.CustomerID AS ClienteID,
        c.CustomerName AS Cliente,
        dm.DeliveryMethodName AS MetodoEntrega,
        SUM(il.ExtendedPrice) AS Monto,
        COUNT(*) OVER() AS TotalRegistros

    FROM syn.Invoices i

    JOIN syn.Customers c
        ON c.CustomerID = i.CustomerID

    JOIN syn.DeliveryMethods dm
        ON dm.DeliveryMethodID = i.DeliveryMethodID

    JOIN syn.InvoiceLines il
        ON il.InvoiceID = i.InvoiceID AND il.SucursalID = i.SucursalID

    WHERE
        (@FechaInicio IS NULL OR i.InvoiceDate >= @FechaInicio)
        AND i.SucursalID = TRY_CONVERT(INT, SESSION_CONTEXT(N'SucursalID'))
        AND (@FechaFin IS NULL OR i.InvoiceDate <= @FechaFin)
        AND (
            @NombreCliente IS NULL
            OR c.CustomerName LIKE '%' + @NombreCliente + '%'
        )

    GROUP BY
        i.InvoiceID,
        i.InvoiceDate,
        c.CustomerID,
        c.CustomerName,
        dm.DeliveryMethodName

    HAVING
        (@MontoMin IS NULL OR SUM(il.ExtendedPrice) >= @MontoMin)
        AND (@MontoMax IS NULL OR SUM(il.ExtendedPrice) <= @MontoMax)

    ORDER BY
        c.CustomerName ASC,
        i.InvoiceID ASC

    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Clientes_Publico
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CustomerID AS ClienteID,
           c.CustomerName AS Nombre,
           cc.CustomerCategoryName AS Categoria,
           bg.BuyingGroupName AS GrupoCompra,
           c.BillToCustomerID AS ClienteFacturarID,
           bt.CustomerName AS ClienteFacturar,
           dm.DeliveryMethodName AS MetodoEntrega,
           dc.CityName AS CiudadEntrega,
           dsp.StateProvinceName AS ProvinciaEntrega,
           c.PaymentDays AS DiasPago,
           pci.CityName AS CiudadPostal,
           -- IDs para llenar el formulario de edicion
           c.CustomerCategoryID AS CategoriaID,
           c.BuyingGroupID AS GrupoCompraID,
           c.PrimaryContactPersonID AS ContactoPrimarioID,
           c.AlternateContactPersonID AS ContactoAlternativoID,
           c.DeliveryMethodID AS MetodoEntregaID,
           c.DeliveryCityID AS CiudadEntregaID,
           c.PostalCityID AS CiudadPostalID,
           psp.StateProvinceName AS ProvinciaPostal
    FROM syn.Customers c
    JOIN syn.CustomerCategories cc ON cc.CustomerCategoryID = c.CustomerCategoryID
    JOIN syn.DeliveryMethods dm ON dm.DeliveryMethodID = c.DeliveryMethodID
    JOIN syn.Customers bt ON bt.CustomerID = c.BillToCustomerID
    JOIN syn.Cities dc ON dc.CityID = c.DeliveryCityID
    JOIN syn.StateProvinces dsp ON dsp.StateProvinceID = dc.StateProvinceID
    JOIN syn.Cities pci ON pci.CityID = c.PostalCityID
    JOIN syn.StateProvinces psp ON psp.StateProvinceID = pci.StateProvinceID
    LEFT JOIN syn.BuyingGroups bg ON bg.BuyingGroupID = c.BuyingGroupID
    WHERE c.CustomerID = @ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Proveedores_Publico
    @ProveedorID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SupplierID AS ProveedorID,
        s.SupplierReference AS CodigoProveedor,
        s.SupplierName AS Nombre,
        sc.SupplierCategoryName AS Categoria,



        dm.DeliveryMethodName AS MetodoEntrega,

        dc.CityName AS CiudadEntrega,



        pci.CityName AS CiudadPostal,



        s.PaymentDays AS DiasPago,

        -- IDs y provincias para llenar el formulario de edicion
        s.SupplierCategoryID AS CategoriaID,
        s.PrimaryContactPersonID AS ContactoPrimarioID,
        s.AlternateContactPersonID AS ContactoAlternativoID,
        s.DeliveryMethodID AS MetodoEntregaID,
        s.DeliveryCityID AS CiudadEntregaID,
        s.PostalCityID AS CiudadPostalID,
        dsp.StateProvinceName AS ProvinciaEntrega,
        psp.StateProvinceName AS ProvinciaPostal

    FROM syn.Suppliers s

    JOIN syn.SupplierCategories sc
        ON sc.SupplierCategoryID = s.SupplierCategoryID

    LEFT JOIN syn.DeliveryMethods dm
        ON dm.DeliveryMethodID = s.DeliveryMethodID

    LEFT JOIN syn.Cities dc
        ON dc.CityID = s.DeliveryCityID

    LEFT JOIN syn.Cities pci
        ON pci.CityID = s.PostalCityID

    LEFT JOIN syn.StateProvinces dsp
        ON dsp.StateProvinceID = dc.StateProvinceID

    LEFT JOIN syn.StateProvinces psp
        ON psp.StateProvinceID = pci.StateProvinceID

    WHERE s.SupplierID = @ProveedorID;
END;
GO
