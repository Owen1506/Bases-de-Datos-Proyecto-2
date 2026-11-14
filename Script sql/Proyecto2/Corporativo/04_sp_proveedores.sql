-- Escrituras de proveedores en Corporativo.
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Insertar
    @Nombre NVARCHAR(100), @CategoriaProveedorID INT, @MetodoEntregaID INT,
    @CiudadEntregaID INT = NULL, @CiudadPostalID INT = NULL,
    @DiasPago INT, @Referencia NVARCHAR(20) = NULL,
    @ContactoPrincipal NVARCHAR(50), @TelefonoContacto NVARCHAR(20) = NULL,
    @FaxContacto NVARCHAR(20) = NULL, @CorreoContacto NVARCHAR(256) = NULL,
    @Telefono NVARCHAR(20), @Fax NVARCHAR(20), @SitioWeb NVARCHAR(256),
    @DireccionEntrega1 NVARCHAR(60), @DireccionEntrega2 NVARCHAR(60) = NULL,
    @CodigoPostalEntrega NVARCHAR(10), @UbicacionWkt NVARCHAR(MAX) = NULL,
    @UbicacionSrid INT = 4326, @DireccionPostal1 NVARCHAR(60),
    @DireccionPostal2 NVARCHAR(60) = NULL, @CodigoPostal NVARCHAR(10),
    @CuentaNombre NVARCHAR(50) = NULL, @CuentaSucursal NVARCHAR(50) = NULL,
    @CuentaCodigo NVARCHAR(20) = NULL, @CuentaNumero NVARCHAR(20) = NULL,
    @CodigoInternacional NVARCHAR(20) = NULL, @ComentariosInternos NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ProveedorID INT,@ContactoID INT;
        SELECT @ProveedorID=ISNULL(MAX(SupplierID),0)+1 FROM Purchasing.Suppliers WITH(UPDLOCK,HOLDLOCK);
        SELECT @ContactoID=ISNULL(MAX(PersonID),0)+1 FROM Application.People WITH(UPDLOCK,HOLDLOCK);
        INSERT Application.People(PersonID,IsSalesperson,FullName,SucursalID)
        VALUES(@ContactoID,0,NULL,NULL);
        INSERT Sensitive.People(PersonID,FullName,PhoneNumber,FaxNumber,EmailAddress)
        VALUES(@ContactoID,@ContactoPrincipal,@TelefonoContacto,@FaxContacto,@CorreoContacto);
        INSERT Purchasing.Suppliers(
            SupplierID,SupplierName,SupplierCategoryID,PrimaryContactPersonID,
            AlternateContactPersonID,DeliveryMethodID,DeliveryCityID,PostalCityID,
            PaymentDays,SupplierReference)
        VALUES(@ProveedorID,@Nombre,@CategoriaProveedorID,@ContactoID,NULL,
               @MetodoEntregaID,@CiudadEntregaID,@CiudadPostalID,@DiasPago,@Referencia);
        INSERT Sensitive.Suppliers(
            SupplierID,PhoneNumber,FaxNumber,WebsiteURL,DeliveryAddressLine1,
            DeliveryAddressLine2,DeliveryPostalCode,DeliveryLocation,
            PostalAddressLine1,PostalAddressLine2,PostalPostalCode,
            BankAccountName,BankAccountBranch,BankAccountCode,BankAccountNumber,
            BankInternationalCode,InternalComments)
        VALUES(@ProveedorID,@Telefono,@Fax,@SitioWeb,@DireccionEntrega1,
               @DireccionEntrega2,@CodigoPostalEntrega,
               CASE WHEN @UbicacionWkt IS NULL THEN NULL ELSE geography::STGeomFromText(@UbicacionWkt,@UbicacionSrid) END,
               @DireccionPostal1,@DireccionPostal2,@CodigoPostal,
               @CuentaNombre,@CuentaSucursal,@CuentaCodigo,@CuentaNumero,
               @CodigoInternacional,@ComentariosInternos);
        COMMIT;
        SELECT @ProveedorID AS ProveedorID,@ContactoID AS ContactoPrincipalID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Proveedores_Actualizar
    @ProveedorID INT, @Nombre NVARCHAR(100), @CategoriaProveedorID INT,
    @MetodoEntregaID INT, @CiudadEntregaID INT = NULL, @CiudadPostalID INT = NULL,
    @DiasPago INT, @Referencia NVARCHAR(20) = NULL,
    @ContactoPrincipal NVARCHAR(50), @TelefonoContacto NVARCHAR(20) = NULL,
    @FaxContacto NVARCHAR(20) = NULL, @CorreoContacto NVARCHAR(256) = NULL,
    @Telefono NVARCHAR(20), @Fax NVARCHAR(20), @SitioWeb NVARCHAR(256),
    @DireccionEntrega1 NVARCHAR(60), @DireccionEntrega2 NVARCHAR(60) = NULL,
    @CodigoPostalEntrega NVARCHAR(10), @UbicacionWkt NVARCHAR(MAX) = NULL,
    @UbicacionSrid INT = 4326, @DireccionPostal1 NVARCHAR(60),
    @DireccionPostal2 NVARCHAR(60) = NULL, @CodigoPostal NVARCHAR(10),
    @CuentaNombre NVARCHAR(50) = NULL, @CuentaSucursal NVARCHAR(50) = NULL,
    @CuentaCodigo NVARCHAR(20) = NULL, @CuentaNumero NVARCHAR(20) = NULL,
    @CodigoInternacional NVARCHAR(20) = NULL, @ComentariosInternos NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ContactoID INT;
        SELECT @ContactoID=PrimaryContactPersonID FROM Purchasing.Suppliers WITH(UPDLOCK,HOLDLOCK)
        WHERE SupplierID=@ProveedorID;
        IF @ContactoID IS NULL THROW 51310, 'El proveedor no existe.', 1;
        UPDATE Purchasing.Suppliers SET SupplierName=@Nombre,
            SupplierCategoryID=@CategoriaProveedorID,DeliveryMethodID=@MetodoEntregaID,
            DeliveryCityID=@CiudadEntregaID,PostalCityID=@CiudadPostalID,
            PaymentDays=@DiasPago,SupplierReference=@Referencia
        WHERE SupplierID=@ProveedorID;
        UPDATE Sensitive.Suppliers SET PhoneNumber=@Telefono,FaxNumber=@Fax,
            WebsiteURL=@SitioWeb,DeliveryAddressLine1=@DireccionEntrega1,
            DeliveryAddressLine2=@DireccionEntrega2,DeliveryPostalCode=@CodigoPostalEntrega,
            DeliveryLocation=CASE WHEN @UbicacionWkt IS NULL THEN NULL ELSE geography::STGeomFromText(@UbicacionWkt,@UbicacionSrid) END,
            PostalAddressLine1=@DireccionPostal1,PostalAddressLine2=@DireccionPostal2,
            PostalPostalCode=@CodigoPostal,BankAccountName=@CuentaNombre,
            BankAccountBranch=@CuentaSucursal,BankAccountCode=@CuentaCodigo,
            BankAccountNumber=@CuentaNumero,BankInternationalCode=@CodigoInternacional,
            InternalComments=@ComentariosInternos WHERE SupplierID=@ProveedorID;
        UPDATE Sensitive.People SET FullName=@ContactoPrincipal,
            PhoneNumber=@TelefonoContacto,FaxNumber=@FaxContacto,
            EmailAddress=@CorreoContacto WHERE PersonID=@ContactoID;
        COMMIT;
        SELECT @ProveedorID AS ProveedorID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
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
        DECLARE @ContactoPrincipalID INT,@ContactoAlternoID INT;
        SELECT @ContactoPrincipalID=PrimaryContactPersonID,
               @ContactoAlternoID=AlternateContactPersonID
        FROM Purchasing.Suppliers WITH(UPDLOCK,HOLDLOCK) WHERE SupplierID=@ProveedorID;
        IF NOT EXISTS(SELECT 1 FROM Purchasing.Suppliers WITH(UPDLOCK,HOLDLOCK) WHERE SupplierID=@ProveedorID)
            THROW 51311, 'El proveedor no existe.', 1;
        IF EXISTS(SELECT 1 FROM Purchasing.PurchaseOrders WHERE SupplierID=@ProveedorID)
            THROW 51312, 'No se puede eliminar un proveedor que tiene órdenes de compra.', 1;
        IF EXISTS(SELECT 1 FROM Warehouse.StockItems WHERE SupplierID=@ProveedorID)
            THROW 51313, 'No se puede eliminar un proveedor asociado con productos.', 1;
        DELETE Sensitive.Suppliers WHERE SupplierID=@ProveedorID;
        DELETE Purchasing.Suppliers WHERE SupplierID=@ProveedorID;
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
        SELECT @ProveedorID AS ProveedorID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
