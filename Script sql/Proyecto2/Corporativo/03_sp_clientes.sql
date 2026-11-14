-- Escrituras de clientes. La parte pública y sensible se administran juntas en Corporativo.
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Insertar
    @Nombre NVARCHAR(100), @CategoriaClienteID INT, @GrupoCompraID INT = NULL,
    @MetodoEntregaID INT, @CiudadEntregaID INT, @CiudadPostalID INT,
    @LimiteCredito DECIMAL(18,2) = NULL, @FechaApertura DATE,
    @DescuentoEstandar DECIMAL(18,3) = 0, @EnEsperaCredito BIT = 0, @DiasPago INT,
    @ContactoPrincipal NVARCHAR(50), @TelefonoContacto NVARCHAR(20) = NULL,
    @FaxContacto NVARCHAR(20) = NULL, @CorreoContacto NVARCHAR(256) = NULL,
    @ContactoAlterno NVARCHAR(50) = NULL, @TelefonoAlterno NVARCHAR(20) = NULL,
    @FaxAlterno NVARCHAR(20) = NULL, @CorreoAlterno NVARCHAR(256) = NULL,
    @Telefono NVARCHAR(20), @Fax NVARCHAR(20), @SitioWeb NVARCHAR(256),
    @DireccionEntrega1 NVARCHAR(60), @DireccionEntrega2 NVARCHAR(60) = NULL,
    @CodigoPostalEntrega NVARCHAR(10), @UbicacionWkt NVARCHAR(MAX) = NULL,
    @UbicacionSrid INT = 4326, @DireccionPostal1 NVARCHAR(60),
    @DireccionPostal2 NVARCHAR(60) = NULL, @CodigoPostal NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    IF NULLIF(LTRIM(RTRIM(@Nombre)),N'') IS NULL OR
       NULLIF(LTRIM(RTRIM(@ContactoPrincipal)),N'') IS NULL
        THROW 51300, 'Nombre y contacto principal son obligatorios.', 1;
    IF @DiasPago < 0 OR @DescuentoEstandar < 0 OR @DescuentoEstandar > 100
        THROW 51301, 'Los días de pago o el descuento no son válidos.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ClienteID INT, @ContactoPrincipalID INT, @ContactoAlternoID INT=NULL;
        SELECT @ClienteID=ISNULL(MAX(CustomerID),0)+1 FROM Sales.Customers WITH (UPDLOCK,HOLDLOCK);
        SELECT @ContactoPrincipalID=ISNULL(MAX(PersonID),0)+1 FROM Application.People WITH (UPDLOCK,HOLDLOCK);

        INSERT Application.People(PersonID,IsSalesperson,FullName,SucursalID)
        VALUES(@ContactoPrincipalID,0,NULL,NULL);
        INSERT Sensitive.People(PersonID,FullName,PhoneNumber,FaxNumber,EmailAddress)
        VALUES(@ContactoPrincipalID,@ContactoPrincipal,@TelefonoContacto,@FaxContacto,@CorreoContacto);

        IF NULLIF(LTRIM(RTRIM(@ContactoAlterno)),N'') IS NOT NULL
        BEGIN
            SET @ContactoAlternoID=@ContactoPrincipalID+1;
            INSERT Application.People(PersonID,IsSalesperson,FullName,SucursalID)
            VALUES(@ContactoAlternoID,0,NULL,NULL);
            INSERT Sensitive.People(PersonID,FullName,PhoneNumber,FaxNumber,EmailAddress)
            VALUES(@ContactoAlternoID,@ContactoAlterno,@TelefonoAlterno,@FaxAlterno,@CorreoAlterno);
        END;

        INSERT Sales.Customers(
            CustomerID,CustomerName,BillToCustomerID,CustomerCategoryID,BuyingGroupID,
            PrimaryContactPersonID,AlternateContactPersonID,DeliveryMethodID,
            DeliveryCityID,PostalCityID,CreditLimit,AccountOpenedDate,
            StandardDiscountPercentage,IsOnCreditHold,PaymentDays)
        VALUES(@ClienteID,@Nombre,@ClienteID,@CategoriaClienteID,@GrupoCompraID,
               @ContactoPrincipalID,@ContactoAlternoID,@MetodoEntregaID,
               @CiudadEntregaID,@CiudadPostalID,@LimiteCredito,@FechaApertura,
               @DescuentoEstandar,@EnEsperaCredito,@DiasPago);

        INSERT Sensitive.Customers(
            CustomerID,PhoneNumber,FaxNumber,WebsiteURL,DeliveryAddressLine1,
            DeliveryAddressLine2,DeliveryPostalCode,DeliveryLocation,
            PostalAddressLine1,PostalAddressLine2,PostalPostalCode)
        VALUES(@ClienteID,@Telefono,@Fax,@SitioWeb,@DireccionEntrega1,
               @DireccionEntrega2,@CodigoPostalEntrega,
               CASE WHEN @UbicacionWkt IS NULL THEN NULL ELSE geography::STGeomFromText(@UbicacionWkt,@UbicacionSrid) END,
               @DireccionPostal1,@DireccionPostal2,@CodigoPostal);
        COMMIT;
        SELECT @ClienteID AS ClienteID, @ContactoPrincipalID AS ContactoPrincipalID,
               @ContactoAlternoID AS ContactoAlternoID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Actualizar
    @ClienteID INT, @Nombre NVARCHAR(100), @CategoriaClienteID INT,
    @GrupoCompraID INT = NULL, @MetodoEntregaID INT,
    @CiudadEntregaID INT, @CiudadPostalID INT,
    @LimiteCredito DECIMAL(18,2) = NULL, @FechaApertura DATE,
    @DescuentoEstandar DECIMAL(18,3), @EnEsperaCredito BIT = 0, @DiasPago INT,
    @ContactoPrincipal NVARCHAR(50), @TelefonoContacto NVARCHAR(20) = NULL,
    @FaxContacto NVARCHAR(20) = NULL, @CorreoContacto NVARCHAR(256) = NULL,
    @Telefono NVARCHAR(20), @Fax NVARCHAR(20), @SitioWeb NVARCHAR(256),
    @DireccionEntrega1 NVARCHAR(60), @DireccionEntrega2 NVARCHAR(60) = NULL,
    @CodigoPostalEntrega NVARCHAR(10), @UbicacionWkt NVARCHAR(MAX) = NULL,
    @UbicacionSrid INT = 4326, @DireccionPostal1 NVARCHAR(60),
    @DireccionPostal2 NVARCHAR(60) = NULL, @CodigoPostal NVARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ContactoPrincipalID INT;
        SELECT @ContactoPrincipalID=PrimaryContactPersonID
        FROM Sales.Customers WITH (UPDLOCK,HOLDLOCK) WHERE CustomerID=@ClienteID;
        IF @ContactoPrincipalID IS NULL THROW 51302, 'El cliente no existe.', 1;

        UPDATE Sales.Customers SET CustomerName=@Nombre,
            CustomerCategoryID=@CategoriaClienteID,BuyingGroupID=@GrupoCompraID,
            DeliveryMethodID=@MetodoEntregaID,DeliveryCityID=@CiudadEntregaID,
            PostalCityID=@CiudadPostalID,CreditLimit=@LimiteCredito,
            AccountOpenedDate=@FechaApertura,
            StandardDiscountPercentage=@DescuentoEstandar,
            IsOnCreditHold=@EnEsperaCredito,PaymentDays=@DiasPago
        WHERE CustomerID=@ClienteID;
        UPDATE Sensitive.Customers SET PhoneNumber=@Telefono,FaxNumber=@Fax,
            WebsiteURL=@SitioWeb,DeliveryAddressLine1=@DireccionEntrega1,
            DeliveryAddressLine2=@DireccionEntrega2,DeliveryPostalCode=@CodigoPostalEntrega,
            DeliveryLocation=CASE WHEN @UbicacionWkt IS NULL THEN NULL ELSE geography::STGeomFromText(@UbicacionWkt,@UbicacionSrid) END,
            PostalAddressLine1=@DireccionPostal1,PostalAddressLine2=@DireccionPostal2,
            PostalPostalCode=@CodigoPostal WHERE CustomerID=@ClienteID;
        UPDATE Sensitive.People SET FullName=@ContactoPrincipal,
            PhoneNumber=@TelefonoContacto,FaxNumber=@FaxContacto,
            EmailAddress=@CorreoContacto WHERE PersonID=@ContactoPrincipalID;
        COMMIT;
        SELECT @ClienteID AS ClienteID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Clientes_Eliminar
    @ClienteID INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ContactoPrincipalID INT,@ContactoAlternoID INT;
        SELECT @ContactoPrincipalID=PrimaryContactPersonID,
               @ContactoAlternoID=AlternateContactPersonID
        FROM Sales.Customers WITH(UPDLOCK,HOLDLOCK) WHERE CustomerID=@ClienteID;
        IF NOT EXISTS(SELECT 1 FROM Sales.Customers WITH(UPDLOCK,HOLDLOCK) WHERE CustomerID=@ClienteID)
            THROW 51303, 'El cliente no existe.', 1;
        IF EXISTS(SELECT 1 FROM Sales.Invoices WHERE CustomerID=@ClienteID OR BillToCustomerID=@ClienteID)
            THROW 51304, 'No se puede eliminar un cliente que tiene facturas.', 1;
        IF EXISTS(SELECT 1 FROM Sales.Customers WHERE BillToCustomerID=@ClienteID AND CustomerID<>@ClienteID)
            THROW 51305, 'No se puede eliminar porque otros clientes lo usan para facturación.', 1;
        DELETE Sensitive.Customers WHERE CustomerID=@ClienteID;
        DELETE Sales.Customers WHERE CustomerID=@ClienteID;
        DELETE sp FROM Sensitive.People AS sp
        WHERE sp.PersonID IN(@ContactoPrincipalID,@ContactoAlternoID)
          AND NOT EXISTS(SELECT 1 FROM Sales.Customers c WHERE c.PrimaryContactPersonID=sp.PersonID OR c.AlternateContactPersonID=sp.PersonID)
          AND NOT EXISTS(SELECT 1 FROM Purchasing.Suppliers s WHERE s.PrimaryContactPersonID=sp.PersonID OR s.AlternateContactPersonID=sp.PersonID)
          AND NOT EXISTS(SELECT 1 FROM Sales.Invoices i WHERE i.ContactPersonID=sp.PersonID OR i.AccountsPersonID=sp.PersonID OR i.SalespersonPersonID=sp.PersonID OR i.PackedByPersonID=sp.PersonID)
          AND NOT EXISTS(SELECT 1 FROM Purchasing.PurchaseOrders po WHERE po.ContactPersonID=sp.PersonID);
        DELETE p FROM Application.People AS p
        WHERE p.PersonID IN(@ContactoPrincipalID,@ContactoAlternoID)
          AND NOT EXISTS(SELECT 1 FROM Sensitive.People sp WHERE sp.PersonID=p.PersonID)
          AND p.IsSalesperson=0;
        COMMIT;
        SELECT @ClienteID AS ClienteID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
