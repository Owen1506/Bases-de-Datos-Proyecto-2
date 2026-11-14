-- Consultas de clientes desde una sucursal.
-- La parte pública es local y el contacto sensible se consulta en Corporativo.
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Listar
    @Busqueda NVARCHAR(100) = NULL,
    @CategoriaClienteID INT = NULL,
    @Pagina INT = 1,
    @TamanoPagina INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina < 1 OR @TamanoPagina NOT BETWEEN 1 AND 200
        THROW 51210, 'La página o su tamaño no son válidos.', 1;

    SELECT c.CustomerID AS ClienteID,
           c.CustomerName AS Nombre,
           cc.CustomerCategoryName AS Categoria,
           bg.BuyingGroupName AS GrupoCompra,
           city.CityName AS CiudadEntrega,
           c.CreditLimit AS LimiteCredito,
           c.AccountOpenedDate AS FechaApertura,
           COUNT_BIG(*) OVER() AS TotalRegistros
    FROM Sales.Customers AS c
    JOIN Sales.CustomerCategories AS cc ON cc.CustomerCategoryID = c.CustomerCategoryID
    LEFT JOIN Sales.BuyingGroups AS bg ON bg.BuyingGroupID = c.BuyingGroupID
    JOIN Application.Cities AS city ON city.CityID = c.DeliveryCityID
    WHERE (@Busqueda IS NULL OR c.CustomerName LIKE N'%' + @Busqueda + N'%')
      AND (@CategoriaClienteID IS NULL OR c.CustomerCategoryID = @CategoriaClienteID)
    ORDER BY c.CustomerName, c.CustomerID
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Detalle
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM Sales.Customers WHERE CustomerID = @ClienteID)
        THROW 51211, 'El cliente no existe.', 1;

    CREATE TABLE #PrivadoCliente (
        CustomerID INT PRIMARY KEY,
        PhoneNumber NVARCHAR(20) NULL,
        FaxNumber NVARCHAR(20) NULL,
        WebsiteURL NVARCHAR(256) NULL,
        DeliveryAddressLine1 NVARCHAR(60) NULL,
        DeliveryAddressLine2 NVARCHAR(60) NULL,
        DeliveryPostalCode NVARCHAR(10) NULL,
        PostalAddressLine1 NVARCHAR(60) NULL,
        PostalAddressLine2 NVARCHAR(60) NULL,
        PostalPostalCode NVARCHAR(10) NULL
    );
    CREATE TABLE #PrivadoPersona (
        PersonID INT PRIMARY KEY,
        FullName NVARCHAR(50) NULL,
        PhoneNumber NVARCHAR(20) NULL,
        FaxNumber NVARCHAR(20) NULL,
        EmailAddress NVARCHAR(256) NULL
    );

    DECLARE @ContactoDisponible BIT = 1;
    BEGIN TRY
        EXEC sys.sp_executesql N'
            INSERT INTO #PrivadoCliente
            SELECT CustomerID, PhoneNumber, FaxNumber, WebsiteURL,
                   DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
                   PostalAddressLine1, PostalAddressLine2, PostalPostalCode
            FROM syn.CustomersSensitive WHERE CustomerID = @ID;

            INSERT INTO #PrivadoPersona
            SELECT p.PersonID, p.FullName, p.PhoneNumber, p.FaxNumber, p.EmailAddress
            FROM syn.PeopleSensitive AS p
            WHERE p.PersonID IN (
                SELECT PrimaryContactPersonID FROM Sales.Customers WHERE CustomerID=@ID
                UNION
                SELECT AlternateContactPersonID FROM Sales.Customers WHERE CustomerID=@ID
            );', N'@ID INT', @ID=@ClienteID;
    END TRY
    BEGIN CATCH
        SET @ContactoDisponible = 0;
    END CATCH;

    SELECT c.CustomerID AS ClienteID, c.CustomerName AS Nombre,
           c.BillToCustomerID AS ClienteFacturacionID,
           c.CustomerCategoryID AS CategoriaClienteID,
           cc.CustomerCategoryName AS Categoria,
           c.BuyingGroupID AS GrupoCompraID, bg.BuyingGroupName AS GrupoCompra,
           c.PrimaryContactPersonID AS ContactoPrincipalID,
           pp.FullName AS ContactoPrincipal,
           pp.PhoneNumber AS TelefonoContacto,
           pp.EmailAddress AS CorreoContacto,
           c.AlternateContactPersonID AS ContactoAlternoID,
           pa.FullName AS ContactoAlterno,
           c.DeliveryMethodID AS MetodoEntregaID,
           c.DeliveryCityID AS CiudadEntregaID,
           c.PostalCityID AS CiudadPostalID,
           c.CreditLimit AS LimiteCredito,
           c.AccountOpenedDate AS FechaApertura,
           c.StandardDiscountPercentage AS DescuentoEstandar,
           c.PaymentDays AS DiasPago,
           pc.PhoneNumber AS Telefono,
           pc.FaxNumber AS Fax,
           pc.WebsiteURL AS SitioWeb,
           pc.DeliveryAddressLine1 AS DireccionEntrega1,
           pc.DeliveryAddressLine2 AS DireccionEntrega2,
           pc.DeliveryPostalCode AS CodigoPostalEntrega,
           pc.PostalAddressLine1 AS DireccionPostal1,
           pc.PostalAddressLine2 AS DireccionPostal2,
           pc.PostalPostalCode AS CodigoPostal,
           @ContactoDisponible AS ContactoDisponible
    FROM Sales.Customers AS c
    JOIN Sales.CustomerCategories AS cc ON cc.CustomerCategoryID=c.CustomerCategoryID
    LEFT JOIN Sales.BuyingGroups AS bg ON bg.BuyingGroupID=c.BuyingGroupID
    LEFT JOIN #PrivadoCliente AS pc ON pc.CustomerID=c.CustomerID
    LEFT JOIN #PrivadoPersona AS pp ON pp.PersonID=c.PrimaryContactPersonID
    LEFT JOIN #PrivadoPersona AS pa ON pa.PersonID=c.AlternateContactPersonID
    WHERE c.CustomerID=@ClienteID;
END;
GO
