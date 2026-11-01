-- 03_sp_clientes.sql
-- SP del modulo de clientes
USE WideWorldImporters;
GO

-- Opciones que SQL Server exige para tablas con columnas calculadas o indices filtrados
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Lista de clientes, los filtros son opcionales
-- Devuelve solo una pagina de resultados y en TotalRegistros el total que cumple los filtros
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

-- Detalle de un cliente
CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Detalle
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CustomerID AS ClienteID,
           c.CustomerName AS Nombre,
           cc.CustomerCategoryName AS Categoria,
           bg.BuyingGroupName AS GrupoCompra,
           pc.FullName AS ContactoPrimario,
           pc.PhoneNumber AS ContactoPrimarioTelefono,
           pc.EmailAddress AS ContactoPrimarioCorreo,
           ac.FullName AS ContactoAlternativo,
           ac.PhoneNumber AS ContactoAlternativoTelefono,
           ac.EmailAddress AS ContactoAlternativoCorreo,
           c.BillToCustomerID AS ClienteFacturarID,
           bt.CustomerName AS ClienteFacturar,
           dm.DeliveryMethodName AS MetodoEntrega,
           dc.CityName AS CiudadEntrega,
           dsp.StateProvinceName AS ProvinciaEntrega,
           c.DeliveryPostalCode AS CodigoPostalEntrega,
           c.PhoneNumber AS Telefono,
           c.FaxNumber AS Fax,
           c.PaymentDays AS DiasPago,
           c.WebsiteURL AS SitioWeb,
           c.DeliveryAddressLine1 AS DireccionEntrega1,
           c.DeliveryAddressLine2 AS DireccionEntrega2,
           c.PostalAddressLine1 AS DireccionPostal1,
           c.PostalAddressLine2 AS DireccionPostal2,
           pci.CityName AS CiudadPostal,
           c.PostalPostalCode AS CodigoPostalPostal,
           c.DeliveryLocation.Lat AS Latitud,
           c.DeliveryLocation.Long AS Longitud,
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
    JOIN syn.People pc ON pc.PersonID = c.PrimaryContactPersonID
    JOIN syn.Customers bt ON bt.CustomerID = c.BillToCustomerID
    JOIN syn.Cities dc ON dc.CityID = c.DeliveryCityID
    JOIN syn.StateProvinces dsp ON dsp.StateProvinceID = dc.StateProvinceID
    JOIN syn.Cities pci ON pci.CityID = c.PostalCityID
    JOIN syn.StateProvinces psp ON psp.StateProvinceID = pci.StateProvinceID
    LEFT JOIN syn.BuyingGroups bg ON bg.BuyingGroupID = c.BuyingGroupID
    LEFT JOIN syn.People ac ON ac.PersonID = c.AlternateContactPersonID
    WHERE c.CustomerID = @ClienteID;
END;
GO

-- SP Eliminar
CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Eliminar
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM syn.Customers
            WHERE CustomerID = @ClienteID
        )
        BEGIN
            THROW 50001, 'El cliente indicado no existe.', 1;
        END;

        DELETE FROM syn.Customers
        WHERE CustomerID = @ClienteID;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
        BEGIN
            THROW 50002, 'No se puede eliminar el cliente porque tiene registros asociados.', 1;
        END;

        THROW;
    END CATCH;
END;
GO
-- SP Modificar/Actualizar
CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Actualizar
    @ClienteID INT,
    @Nombre NVARCHAR(100),
    @ClienteFacturarID INT = NULL,
    @CategoriaID INT,
    @GrupoCompraID INT = NULL,
    @ContactoPrimarioID INT = NULL,
    @ContactoAlternativoID INT = NULL,
    @MetodoEntregaID INT,
    @CiudadEntregaID INT,
    @CiudadPostalID INT,
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
            FROM syn.Customers
            WHERE CustomerID = @ClienteID
        )
        BEGIN
            THROW 50001, 'El cliente indicado no existe.', 1;
        END;

        -- si no se indica contacto primario, se conserva el que ya tenia
        IF @ContactoPrimarioID IS NULL
            SELECT @ContactoPrimarioID = PrimaryContactPersonID FROM syn.Customers WHERE CustomerID = @ClienteID;

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

        -- si no se indica a quien facturar, el cliente se factura a si mismo
        IF @ClienteFacturarID IS NULL SET @ClienteFacturarID = @ClienteID;

        -- si factura a otro cliente, ese cliente debe ser del mismo grupo de compra
        IF @ClienteFacturarID <> @ClienteID
           AND NOT EXISTS (
               SELECT 1
               FROM syn.Customers
               WHERE CustomerID = @ClienteFacturarID
                 AND BuyingGroupID = @GrupoCompraID
           )
        BEGIN
            THROW 50004, 'El cliente por facturar debe pertenecer al mismo grupo de compra. Si el cliente no tiene grupo, deje el campo vacío.', 1;
        END;

        UPDATE syn.Customers
        SET
            CustomerName = @Nombre,
            BillToCustomerID = @ClienteFacturarID,
            CustomerCategoryID = @CategoriaID,
            BuyingGroupID = @GrupoCompraID,
            PrimaryContactPersonID = @ContactoPrimarioID,
            AlternateContactPersonID = @ContactoAlternativoID,
            DeliveryMethodID = @MetodoEntregaID,
            DeliveryCityID = @CiudadEntregaID,
            PostalCityID = @CiudadPostalID,
            PaymentDays = @DiasPago,
            PhoneNumber = @Telefono,
            FaxNumber = @Fax,
            WebsiteURL = @SitioWeb,
            DeliveryAddressLine1 = @DireccionEntrega1,
            DeliveryAddressLine2 = @DireccionEntrega2,
            DeliveryPostalCode = @CodigoPostalEntrega,
            DeliveryLocation = CASE
                WHEN @Latitud IS NOT NULL AND @Longitud IS NOT NULL
                THEN geography::Point(@Latitud, @Longitud, 4326)
                ELSE NULL
            END,
            PostalAddressLine1 = @DireccionPostal1,
            PostalAddressLine2 = @DireccionPostal2,
            PostalPostalCode = @CodigoPostalPostal,
            LastEditedBy = 1
        WHERE CustomerID = @ClienteID;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del cliente ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            THROW 50003, 'Ya existe un cliente con ese nombre.', 1;
        END;

        THROW;
    END CATCH;
END;
GO
-- SP Insertar
CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Insertar
    @Nombre NVARCHAR(100),
    @ClienteFacturarID INT = NULL,
    @CategoriaID INT,
    @GrupoCompraID INT = NULL,
    @ContactoPrimarioID INT = NULL,
    @ContactoAlternativoID INT = NULL,
    @MetodoEntregaID INT,
    @CiudadEntregaID INT,
    @CiudadPostalID INT,
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

    DECLARE @NuevoCliente TABLE (
        ClienteID INT
    );
    DECLARE @NuevaPersona TABLE (
        PersonaID INT
    );
    DECLARE @FacturarA INT;

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

        -- si factura a otro cliente, ese cliente debe ser del mismo grupo de compra
        IF @ClienteFacturarID IS NOT NULL
           AND NOT EXISTS (
               SELECT 1
               FROM syn.Customers
               WHERE CustomerID = @ClienteFacturarID
                 AND BuyingGroupID = @GrupoCompraID
           )
        BEGIN
            THROW 50004, 'El cliente por facturar debe pertenecer al mismo grupo de compra. Si el cliente no tiene grupo, deje el campo vacío.', 1;
        END;

        -- Si no se indica a quien facturar, el cliente se factura a si mismo.
        -- Como su ID todavia no existe, se guarda con un cliente cualquiera
        -- y despues del INSERT se corrige (todo dentro de la misma transaccion).
        SET @FacturarA = @ClienteFacturarID;
        IF @FacturarA IS NULL
            SELECT TOP 1 @FacturarA = CustomerID FROM syn.Customers ORDER BY CustomerID;

        -- Si no se indica contacto primario, el propio cliente es su contacto:
        -- se crea una persona con su nombre, telefono y fax (como los clientes independientes de la base).
        -- FullName admite 50 caracteres, por eso se toma el inicio del nombre.
        IF @ContactoPrimarioID IS NULL
        BEGIN
            INSERT INTO syn.People (
                FullName,
                PreferredName,
                IsPermittedToLogon,
                IsExternalLogonProvider,
                IsSystemUser,
                IsEmployee,
                IsSalesperson,
                PhoneNumber,
                FaxNumber,
                LastEditedBy
            )
            OUTPUT INSERTED.PersonID INTO @NuevaPersona
            VALUES (LEFT(@Nombre, 50), LEFT(@Nombre, 50), 0, 0, 0, 0, 0, @Telefono, @Fax, 1);

            SELECT @ContactoPrimarioID = PersonaID FROM @NuevaPersona;
        END;

        INSERT INTO syn.Customers (
            CustomerName,
            BillToCustomerID,
            CustomerCategoryID,
            BuyingGroupID,
            PrimaryContactPersonID,
            AlternateContactPersonID,
            DeliveryMethodID,
            DeliveryCityID,
            PostalCityID,
            AccountOpenedDate,
            StandardDiscountPercentage,
            IsStatementSent,
            IsOnCreditHold,
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
        OUTPUT INSERTED.CustomerID INTO @NuevoCliente
        VALUES (
            @Nombre,
            @FacturarA,
            @CategoriaID,
            @GrupoCompraID,
            @ContactoPrimarioID,
            @ContactoAlternativoID,
            @MetodoEntregaID,
            @CiudadEntregaID,
            @CiudadPostalID,
            CAST(GETDATE() AS DATE),
            0,
            0,
            0,
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

        IF @ClienteFacturarID IS NULL
        BEGIN
            UPDATE syn.Customers
            SET BillToCustomerID = CustomerID
            WHERE CustomerID = (SELECT ClienteID FROM @NuevoCliente);
        END;

        COMMIT TRANSACTION;

        SELECT ClienteID
        FROM @NuevoCliente;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del cliente ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            THROW 50003, 'Ya existe un cliente con ese nombre.', 1;
        END;

        THROW;
    END CATCH;
END;
GO