-- 04_sp_proveedores.sql
-- SP del modulo de proveedores
USE WideWorldImporters;
GO

-- Opciones que SQL Server exige para tablas con columnas calculadas o indices filtrados
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Listar
    @Nombre NVARCHAR(100) = NULL,
    @CategoriaID INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Nombre = ''
        SET @Nombre = NULL;

    IF @Pagina < 1
        SET @Pagina = 1;

    DECLARE @TamanoPagina INT = 10;

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

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Detalle
    @ProveedorID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        s.SupplierID AS ProveedorID,
        s.SupplierReference AS CodigoProveedor,
        s.SupplierName AS Nombre,
        sc.SupplierCategoryName AS Categoria,

        pc.FullName AS ContactoPrimario,
        pc.PhoneNumber AS ContactoPrimarioTelefono,
        pc.EmailAddress AS ContactoPrimarioCorreo,

        ac.FullName AS ContactoAlternativo,
        ac.PhoneNumber AS ContactoAlternativoTelefono,
        ac.EmailAddress AS ContactoAlternativoCorreo,

        dm.DeliveryMethodName AS MetodoEntrega,

        dc.CityName AS CiudadEntrega,
        s.DeliveryPostalCode AS CodigoPostalEntrega,

        s.PhoneNumber AS Telefono,
        s.FaxNumber AS Fax,
        s.WebsiteURL AS SitioWeb,

        s.DeliveryAddressLine1 AS DireccionEntrega1,
        s.DeliveryAddressLine2 AS DireccionEntrega2,

        s.PostalAddressLine1 AS DireccionPostal1,
        s.PostalAddressLine2 AS DireccionPostal2,
        pci.CityName AS CiudadPostal,
        s.PostalPostalCode AS CodigoPostalPostal,

        s.DeliveryLocation.Lat AS Latitud,
        s.DeliveryLocation.Long AS Longitud,

        s.BankAccountBranch AS NombreBanco, -- BankAccountName es el titular, el banco esta en BankAccountBranch
        s.BankAccountNumber AS NumeroCuenta,

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

    JOIN syn.People pc
        ON pc.PersonID = s.PrimaryContactPersonID

    JOIN syn.People ac
        ON ac.PersonID = s.AlternateContactPersonID

    LEFT JOIN syn.DeliveryMethods dm
        ON dm.DeliveryMethodID = s.DeliveryMethodID

    JOIN syn.Cities dc
        ON dc.CityID = s.DeliveryCityID

    JOIN syn.Cities pci
        ON pci.CityID = s.PostalCityID

    JOIN syn.StateProvinces dsp
        ON dsp.StateProvinceID = dc.StateProvinceID

    JOIN syn.StateProvinces psp
        ON psp.StateProvinceID = pci.StateProvinceID

    WHERE s.SupplierID = @ProveedorID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Insertar
    @Nombre NVARCHAR(100),
    @CategoriaID INT,
    @ContactoPrimarioID INT,
    @ContactoAlternativoID INT,
    @MetodoEntregaID INT,
    @CiudadEntregaID INT,
    @CiudadPostalID INT,

    @ReferenciaProveedor NVARCHAR(20) = NULL,

    @NombreBanco NVARCHAR(50) = NULL,
    @NumeroCuenta NVARCHAR(20) = NULL,

    @DiasPago INT,

    @Telefono NVARCHAR(20),
    @Fax NVARCHAR(20),
    @SitioWeb NVARCHAR(256),

    @DireccionEntrega1 NVARCHAR(60),
    @DireccionEntrega2 NVARCHAR(60) = NULL,
    @CodigoPostalEntrega NVARCHAR(10),

    @DireccionPostal1 NVARCHAR(60),
    @DireccionPostal2 NVARCHAR(60) = NULL,
    @CodigoPostalPostal NVARCHAR(10),

    @Latitud FLOAT = NULL,
    @Longitud FLOAT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NuevoProveedor TABLE (
        ProveedorID INT
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Formato del sitio web y de los codigos postales (5 digitos, como todos los de la base)
        IF (@SitioWeb NOT LIKE 'http://_%._%' AND @SitioWeb NOT LIKE 'https://_%._%') OR @SitioWeb LIKE '% %'
        BEGIN
            THROW 50005, 'El sitio web debe empezar con http:// o https://, por ejemplo http://www.ejemplo.com', 1;
        END;

        IF @CodigoPostalEntrega NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
           OR @CodigoPostalPostal NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
        BEGIN
            THROW 50006, 'El código postal debe tener 5 dígitos.', 1;
        END;

        INSERT INTO syn.Suppliers (
            SupplierName,
            SupplierCategoryID,
            PrimaryContactPersonID,
            AlternateContactPersonID,
            DeliveryMethodID,
            DeliveryCityID,
            PostalCityID,
            SupplierReference,
            BankAccountBranch, -- nombre del banco (BankAccountName es el titular)
            BankAccountNumber,
            PaymentDays,
            PhoneNumber,
            FaxNumber,
            WebsiteURL,
            DeliveryAddressLine1,
            DeliveryAddressLine2,
            DeliveryPostalCode,
            DeliveryLocation,
            PostalAddressLine1,
            PostalAddressLine2,
            PostalPostalCode,
            LastEditedBy
        )
        OUTPUT INSERTED.SupplierID INTO @NuevoProveedor
        VALUES (
            @Nombre,
            @CategoriaID,
            @ContactoPrimarioID,
            @ContactoAlternativoID,
            @MetodoEntregaID,
            @CiudadEntregaID,
            @CiudadPostalID,
            @ReferenciaProveedor,
            @NombreBanco,
            @NumeroCuenta,
            @DiasPago,
            @Telefono,
            @Fax,
            @SitioWeb,
            @DireccionEntrega1,
            @DireccionEntrega2,
            @CodigoPostalEntrega,

            CASE
                WHEN @Latitud IS NOT NULL AND @Longitud IS NOT NULL
                THEN geography::Point(@Latitud, @Longitud, 4326)
                ELSE NULL
            END,

            @DireccionPostal1,
            @DireccionPostal2,
            @CodigoPostalPostal,
            1
        );

        COMMIT TRANSACTION;

        SELECT ProveedorID
        FROM @NuevoProveedor;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del proveedor ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            THROW 50003, 'Ya existe un proveedor con ese nombre.', 1;
        END;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Actualizar
    @ProveedorID INT,

    @Nombre NVARCHAR(100),
    @CategoriaID INT,
    @ContactoPrimarioID INT,
    @ContactoAlternativoID INT,
    @MetodoEntregaID INT,
    @CiudadEntregaID INT,
    @CiudadPostalID INT,

    @ReferenciaProveedor NVARCHAR(20) = NULL,

    @NombreBanco NVARCHAR(50) = NULL,
    @NumeroCuenta NVARCHAR(20) = NULL,

    @DiasPago INT,

    @Telefono NVARCHAR(20),
    @Fax NVARCHAR(20),
    @SitioWeb NVARCHAR(256),

    @DireccionEntrega1 NVARCHAR(60),
    @DireccionEntrega2 NVARCHAR(60) = NULL,
    @CodigoPostalEntrega NVARCHAR(10),

    @DireccionPostal1 NVARCHAR(60),
    @DireccionPostal2 NVARCHAR(60) = NULL,
    @CodigoPostalPostal NVARCHAR(10),

    @Latitud FLOAT = NULL,
    @Longitud FLOAT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM syn.Suppliers
            WHERE SupplierID = @ProveedorID
        )
        BEGIN
            THROW 50001, 'El proveedor indicado no existe.', 1;
        END;

        -- Formato del sitio web y de los codigos postales (5 digitos, como todos los de la base)
        IF (@SitioWeb NOT LIKE 'http://_%._%' AND @SitioWeb NOT LIKE 'https://_%._%') OR @SitioWeb LIKE '% %'
        BEGIN
            THROW 50005, 'El sitio web debe empezar con http:// o https://, por ejemplo http://www.ejemplo.com', 1;
        END;

        IF @CodigoPostalEntrega NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
           OR @CodigoPostalPostal NOT LIKE '[0-9][0-9][0-9][0-9][0-9]'
        BEGIN
            THROW 50006, 'El código postal debe tener 5 dígitos.', 1;
        END;

        UPDATE syn.Suppliers
        SET
            SupplierName = @Nombre,
            SupplierCategoryID = @CategoriaID,
            PrimaryContactPersonID = @ContactoPrimarioID,
            AlternateContactPersonID = @ContactoAlternativoID,
            DeliveryMethodID = @MetodoEntregaID,
            DeliveryCityID = @CiudadEntregaID,
            PostalCityID = @CiudadPostalID,

            SupplierReference = @ReferenciaProveedor,

            BankAccountBranch = @NombreBanco,
            BankAccountNumber = @NumeroCuenta,

            PaymentDays = @DiasPago,

            PhoneNumber = @Telefono,
            FaxNumber = @Fax,
            WebsiteURL = @SitioWeb,

            DeliveryAddressLine1 = @DireccionEntrega1,
            DeliveryAddressLine2 = @DireccionEntrega2,
            DeliveryPostalCode = @CodigoPostalEntrega,

            DeliveryLocation =
                CASE
                    WHEN @Latitud IS NOT NULL AND @Longitud IS NOT NULL
                    THEN geography::Point(@Latitud, @Longitud, 4326)
                    ELSE NULL
                END,

            PostalAddressLine1 = @DireccionPostal1,
            PostalAddressLine2 = @DireccionPostal2,
            PostalPostalCode = @CodigoPostalPostal,

            LastEditedBy = 1

        WHERE SupplierID = @ProveedorID;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del proveedor ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            THROW 50003, 'Ya existe un proveedor con ese nombre.', 1;
        END;

        THROW;
    END CATCH;
END;
GO


CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Eliminar
    @ProveedorID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM syn.Suppliers
            WHERE SupplierID = @ProveedorID
        )
        BEGIN
            THROW 50001, 'El proveedor indicado no existe.', 1;
        END;

        DELETE FROM syn.Suppliers
        WHERE SupplierID = @ProveedorID;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
        BEGIN
            THROW 50002, 'No se puede eliminar el proveedor porque tiene registros asociados.', 1;
        END;

        THROW;
    END CATCH;
END;
GO