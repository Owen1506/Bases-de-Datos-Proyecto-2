-- Consultas de proveedores desde una sucursal.
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Listar
    @Busqueda NVARCHAR(100) = NULL,
    @CategoriaProveedorID INT = NULL,
    @Pagina INT = 1,
    @TamanoPagina INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina < 1 OR @TamanoPagina NOT BETWEEN 1 AND 200
        THROW 51220, 'La página o su tamaño no son válidos.', 1;

    SELECT s.SupplierID AS ProveedorID,
           s.SupplierName AS Nombre,
           sc.SupplierCategoryName AS Categoria,
           s.SupplierReference AS Referencia,
           s.PaymentDays AS DiasPago,
           COUNT_BIG(*) OVER() AS TotalRegistros
    FROM Purchasing.Suppliers AS s
    JOIN Purchasing.SupplierCategories AS sc ON sc.SupplierCategoryID=s.SupplierCategoryID
    WHERE (@Busqueda IS NULL OR s.SupplierName LIKE N'%' + @Busqueda + N'%')
      AND (@CategoriaProveedorID IS NULL OR s.SupplierCategoryID=@CategoriaProveedorID)
    ORDER BY s.SupplierName, s.SupplierID
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Detalle
    @ProveedorID INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM Purchasing.Suppliers WHERE SupplierID=@ProveedorID)
        THROW 51221, 'El proveedor no existe.', 1;

    CREATE TABLE #PrivadoProveedor (
        SupplierID INT PRIMARY KEY, PhoneNumber NVARCHAR(20), FaxNumber NVARCHAR(20),
        WebsiteURL NVARCHAR(256), DeliveryAddressLine1 NVARCHAR(60),
        DeliveryAddressLine2 NVARCHAR(60), DeliveryPostalCode NVARCHAR(10),
        PostalAddressLine1 NVARCHAR(60), PostalAddressLine2 NVARCHAR(60),
        PostalPostalCode NVARCHAR(10), BankAccountName NVARCHAR(50),
        BankAccountBranch NVARCHAR(50), BankAccountCode NVARCHAR(20),
        BankAccountNumber NVARCHAR(20), BankInternationalCode NVARCHAR(20),
        InternalComments NVARCHAR(MAX)
    );
    CREATE TABLE #PrivadoPersona (
        PersonID INT PRIMARY KEY, FullName NVARCHAR(50), PhoneNumber NVARCHAR(20),
        FaxNumber NVARCHAR(20), EmailAddress NVARCHAR(256)
    );
    DECLARE @ContactoDisponible BIT=1;
    BEGIN TRY
        EXEC sys.sp_executesql N'
            INSERT INTO #PrivadoProveedor
            SELECT SupplierID, PhoneNumber, FaxNumber, WebsiteURL,
                   DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
                   PostalAddressLine1, PostalAddressLine2, PostalPostalCode,
                   BankAccountName, BankAccountBranch, BankAccountCode,
                   BankAccountNumber, BankInternationalCode, InternalComments
            FROM syn.SuppliersSensitive WHERE SupplierID=@ID;
            INSERT INTO #PrivadoPersona
            SELECT p.PersonID,p.FullName,p.PhoneNumber,p.FaxNumber,p.EmailAddress
            FROM syn.PeopleSensitive AS p
            WHERE p.PersonID IN (
                SELECT PrimaryContactPersonID FROM Purchasing.Suppliers WHERE SupplierID=@ID
                UNION
                SELECT AlternateContactPersonID FROM Purchasing.Suppliers WHERE SupplierID=@ID
            );', N'@ID INT', @ID=@ProveedorID;
    END TRY
    BEGIN CATCH
        SET @ContactoDisponible=0;
    END CATCH;

    SELECT s.SupplierID AS ProveedorID, s.SupplierName AS Nombre,
           s.SupplierCategoryID AS CategoriaProveedorID,
           sc.SupplierCategoryName AS Categoria,
           s.PrimaryContactPersonID AS ContactoPrincipalID,
           pp.FullName AS ContactoPrincipal, pp.PhoneNumber AS TelefonoContacto,
           pp.EmailAddress AS CorreoContacto,
           s.AlternateContactPersonID AS ContactoAlternoID,
           pa.FullName AS ContactoAlterno,
           s.DeliveryMethodID AS MetodoEntregaID,
           s.PaymentDays AS DiasPago, s.SupplierReference AS Referencia,
           ps.PhoneNumber AS Telefono, ps.FaxNumber AS Fax,
           ps.WebsiteURL AS SitioWeb,
           ps.DeliveryAddressLine1 AS DireccionEntrega1,
           ps.DeliveryAddressLine2 AS DireccionEntrega2,
           ps.DeliveryPostalCode AS CodigoPostalEntrega,
           ps.PostalAddressLine1 AS DireccionPostal1,
           ps.PostalAddressLine2 AS DireccionPostal2,
           ps.PostalPostalCode AS CodigoPostal,
           ps.BankAccountName AS CuentaNombre,
           ps.BankAccountBranch AS CuentaSucursal,
           ps.BankAccountCode AS CuentaCodigo,
           ps.BankAccountNumber AS CuentaNumero,
           ps.BankInternationalCode AS CodigoInternacional,
           ps.InternalComments AS ComentariosInternos,
           @ContactoDisponible AS ContactoDisponible
    FROM Purchasing.Suppliers AS s
    JOIN Purchasing.SupplierCategories AS sc ON sc.SupplierCategoryID=s.SupplierCategoryID
    LEFT JOIN #PrivadoProveedor AS ps ON ps.SupplierID=s.SupplierID
    LEFT JOIN #PrivadoPersona AS pp ON pp.PersonID=s.PrimaryContactPersonID
    LEFT JOIN #PrivadoPersona AS pa ON pa.PersonID=s.AlternateContactPersonID
    WHERE s.SupplierID=@ProveedorID;
END;
GO
