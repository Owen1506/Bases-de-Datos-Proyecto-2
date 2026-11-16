-- Procedimientos de compatibilidad de la API. No recrea bases ni tablas.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Clientes_Privado @ClienteID INT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT p.PhoneNumber AS Telefono, p.FaxNumber AS Fax, p.WebsiteURL AS SitioWeb,
 p.DeliveryAddressLine1 AS DireccionEntrega1, p.DeliveryAddressLine2 AS DireccionEntrega2,
 p.DeliveryPostalCode AS CodigoPostalEntrega, p.PostalAddressLine1 AS DireccionPostal1,
 p.PostalAddressLine2 AS DireccionPostal2, p.PostalPostalCode AS CodigoPostalPostal,
 p.DeliveryLocation.Lat AS Latitud, p.DeliveryLocation.Long AS Longitud,
 pc.FullName AS ContactoPrimario, pc.PhoneNumber AS ContactoPrimarioTelefono,
 pc.EmailAddress AS ContactoPrimarioCorreo, ac.FullName AS ContactoAlternativo,
 ac.PhoneNumber AS ContactoAlternativoTelefono, ac.EmailAddress AS ContactoAlternativoCorreo
 FROM Sales.Customers c
 JOIN Sensitive.Customers p ON p.CustomerID=c.CustomerID
 LEFT JOIN Sensitive.People pc ON pc.PersonID=c.PrimaryContactPersonID
 LEFT JOIN Sensitive.People ac ON ac.PersonID=c.AlternateContactPersonID
 WHERE c.CustomerID=@ClienteID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Proveedores_Privado @ProveedorID INT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT p.PhoneNumber AS Telefono, p.FaxNumber AS Fax, p.WebsiteURL AS SitioWeb,
 p.DeliveryAddressLine1 AS DireccionEntrega1, p.DeliveryAddressLine2 AS DireccionEntrega2,
 p.DeliveryPostalCode AS CodigoPostalEntrega, p.PostalAddressLine1 AS DireccionPostal1,
 p.PostalAddressLine2 AS DireccionPostal2, p.PostalPostalCode AS CodigoPostalPostal,
 p.DeliveryLocation.Lat AS Latitud, p.DeliveryLocation.Long AS Longitud,
 pc.FullName AS ContactoPrimario, pc.PhoneNumber AS ContactoPrimarioTelefono,
 pc.EmailAddress AS ContactoPrimarioCorreo, ac.FullName AS ContactoAlternativo,
 ac.PhoneNumber AS ContactoAlternativoTelefono, ac.EmailAddress AS ContactoAlternativoCorreo, p.BankAccountBranch AS NombreBanco, p.BankAccountNumber AS NumeroCuenta
 FROM Purchasing.Suppliers s
 JOIN Sensitive.Suppliers p ON p.SupplierID=s.SupplierID
 LEFT JOIN Sensitive.People pc ON pc.PersonID=s.PrimaryContactPersonID
 LEFT JOIN Sensitive.People ac ON ac.PersonID=s.AlternateContactPersonID
 WHERE s.SupplierID=@ProveedorID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Catalogo_BuscarPersonas
    @Texto NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 20 PersonID AS PersonaID, FullName AS Persona
    FROM Sensitive.People
    WHERE FullName LIKE '%' + @Texto + '%'
    ORDER BY FullName;
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
    JOIN Sensitive.People p
        ON p.PersonID = c.PrimaryContactPersonID
    WHERE c.CustomerID = @ClienteID

    UNION ALL

    SELECT
        p.PersonID,
        p.FullName,
        'Alternativo'
    FROM syn.Customers c
    JOIN Sensitive.People p
        ON p.PersonID = c.AlternateContactPersonID
    WHERE c.CustomerID = @ClienteID
      AND c.AlternateContactPersonID IS NOT NULL;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Clientes_Guardar
 @Nombre NVARCHAR(100), @CategoriaID INT, @MetodoEntregaID INT = NULL,
 @CiudadEntregaID INT, @CiudadPostalID INT, @DiasPago INT,
 @ContactoPrimarioID INT = NULL, @ContactoAlternativoID INT = NULL,
 @Telefono NVARCHAR(20), @Fax NVARCHAR(20), @SitioWeb NVARCHAR(256),
 @DireccionEntrega1 NVARCHAR(60), @DireccionEntrega2 NVARCHAR(60) = NULL,
 @CodigoPostalEntrega NVARCHAR(10), @DireccionPostal1 NVARCHAR(60),
 @DireccionPostal2 NVARCHAR(60) = NULL, @CodigoPostalPostal NVARCHAR(10),
 @Latitud FLOAT = NULL, @Longitud FLOAT = NULL,
 @GrupoCompraID INT = NULL, @ClienteFacturarID INT = NULL,
 @ClienteID INT = NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Nuevo BIT=CASE WHEN @ClienteID IS NULL THEN 1 ELSE 0 END;
  IF @Nuevo=0 AND NOT EXISTS(SELECT 1 FROM Sales.Customers WITH(UPDLOCK,HOLDLOCK) WHERE CustomerID=@ClienteID)
   THROW 51510, 'El registro no existe.', 1;
  IF @DiasPago<0 THROW 51511, 'Los días de pago no son válidos.', 1;
  IF @Nuevo=0 AND @ContactoPrimarioID IS NULL
   SELECT @ContactoPrimarioID=PrimaryContactPersonID FROM Sales.Customers WHERE CustomerID=@ClienteID;
  IF @ContactoPrimarioID IS NULL
  BEGIN
   SELECT @ContactoPrimarioID=ISNULL(MAX(PersonID),0)+1 FROM Application.People WITH(UPDLOCK,HOLDLOCK);
   INSERT Application.People(PersonID,IsSalesperson,FullName,SucursalID) VALUES(@ContactoPrimarioID,0,NULL,NULL);
   INSERT Sensitive.People(PersonID,FullName,PhoneNumber,FaxNumber) VALUES(@ContactoPrimarioID,LEFT(@Nombre,50),@Telefono,@Fax);
  END;
  IF NOT EXISTS(SELECT 1 FROM Sensitive.People WHERE PersonID=@ContactoPrimarioID)
   OR (@ContactoAlternativoID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Sensitive.People WHERE PersonID=@ContactoAlternativoID))
   THROW 51512, 'El contacto seleccionado no existe en Corporativo.', 1;
  IF @ClienteFacturarID IS NOT NULL AND @ClienteFacturarID<>ISNULL(@ClienteID,-1)
     AND NOT EXISTS(SELECT 1 FROM Sales.Customers WHERE CustomerID=@ClienteFacturarID
         AND BuyingGroupID=@GrupoCompraID)
   THROW 51513, 'El cliente por facturar debe pertenecer al mismo grupo de compra.', 1;
  IF @Nuevo=1
  BEGIN
   SELECT @ClienteID=ISNULL(MAX(CustomerID),0)+1 FROM Sales.Customers WITH(UPDLOCK,HOLDLOCK);
   INSERT Sales.Customers(CustomerID,CustomerName,BillToCustomerID,CustomerCategoryID,BuyingGroupID,
    PrimaryContactPersonID,AlternateContactPersonID,DeliveryMethodID,DeliveryCityID,PostalCityID,
    CreditLimit,AccountOpenedDate,StandardDiscountPercentage,IsOnCreditHold,PaymentDays)
   VALUES(@ClienteID,@Nombre,COALESCE(@ClienteFacturarID,@ClienteID),@CategoriaID,@GrupoCompraID,
    @ContactoPrimarioID,@ContactoAlternativoID,@MetodoEntregaID,@CiudadEntregaID,@CiudadPostalID,
    NULL,CONVERT(DATE,GETDATE()),0,0,@DiasPago);
   INSERT Sensitive.Customers(CustomerID,PhoneNumber,FaxNumber,WebsiteURL,DeliveryAddressLine1,
    DeliveryAddressLine2,DeliveryPostalCode,DeliveryLocation,PostalAddressLine1,PostalAddressLine2,PostalPostalCode)
   VALUES(@ClienteID,@Telefono,@Fax,@SitioWeb,@DireccionEntrega1,@DireccionEntrega2,@CodigoPostalEntrega,
    CASE WHEN @Latitud IS NULL THEN NULL ELSE geography::Point(@Latitud,@Longitud,4326) END,
    @DireccionPostal1,@DireccionPostal2,@CodigoPostalPostal);
  END
  ELSE
  BEGIN
   UPDATE Sales.Customers SET CustomerName=@Nombre,
    CustomerCategoryID=@CategoriaID,
    PrimaryContactPersonID=@ContactoPrimarioID,AlternateContactPersonID=@ContactoAlternativoID,
    DeliveryMethodID=@MetodoEntregaID,DeliveryCityID=@CiudadEntregaID,PostalCityID=@CiudadPostalID,
    PaymentDays=@DiasPago,
    BuyingGroupID=@GrupoCompraID,BillToCustomerID=COALESCE(@ClienteFacturarID,@ClienteID)
   WHERE CustomerID=@ClienteID;
   UPDATE Sensitive.Customers SET PhoneNumber=@Telefono,FaxNumber=@Fax,WebsiteURL=@SitioWeb,
    DeliveryAddressLine1=@DireccionEntrega1,DeliveryAddressLine2=@DireccionEntrega2,DeliveryPostalCode=@CodigoPostalEntrega,
    DeliveryLocation=CASE WHEN @Latitud IS NULL THEN NULL ELSE geography::Point(@Latitud,@Longitud,4326) END,
    PostalAddressLine1=@DireccionPostal1,PostalAddressLine2=@DireccionPostal2,PostalPostalCode=@CodigoPostalPostal
   WHERE CustomerID=@ClienteID;
  END;
  COMMIT;
  SELECT @ClienteID AS ClienteID;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Proveedores_Guardar
 @Nombre NVARCHAR(100), @CategoriaID INT, @MetodoEntregaID INT = NULL,
 @CiudadEntregaID INT, @CiudadPostalID INT, @DiasPago INT,
 @ContactoPrimarioID INT = NULL, @ContactoAlternativoID INT = NULL,
 @Telefono NVARCHAR(20), @Fax NVARCHAR(20), @SitioWeb NVARCHAR(256),
 @DireccionEntrega1 NVARCHAR(60), @DireccionEntrega2 NVARCHAR(60) = NULL,
 @CodigoPostalEntrega NVARCHAR(10), @DireccionPostal1 NVARCHAR(60),
 @DireccionPostal2 NVARCHAR(60) = NULL, @CodigoPostalPostal NVARCHAR(10),
 @Latitud FLOAT = NULL, @Longitud FLOAT = NULL,
 @ReferenciaProveedor NVARCHAR(20) = NULL, @NombreBanco NVARCHAR(50) = NULL, @NumeroCuenta NVARCHAR(20) = NULL,
 @ProveedorID INT = NULL
AS
BEGIN
 SET NOCOUNT ON;
 SET XACT_ABORT ON;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @Nuevo BIT=CASE WHEN @ProveedorID IS NULL THEN 1 ELSE 0 END;
  IF @Nuevo=0 AND NOT EXISTS(SELECT 1 FROM Purchasing.Suppliers WITH(UPDLOCK,HOLDLOCK) WHERE SupplierID=@ProveedorID)
   THROW 51510, 'El registro no existe.', 1;
  IF @DiasPago<0 THROW 51511, 'Los días de pago no son válidos.', 1;
  IF @ContactoPrimarioID IS NULL
  BEGIN
   SELECT @ContactoPrimarioID=ISNULL(MAX(PersonID),0)+1 FROM Application.People WITH(UPDLOCK,HOLDLOCK);
   INSERT Application.People(PersonID,IsSalesperson,FullName,SucursalID) VALUES(@ContactoPrimarioID,0,NULL,NULL);
   INSERT Sensitive.People(PersonID,FullName,PhoneNumber,FaxNumber) VALUES(@ContactoPrimarioID,LEFT(@Nombre,50),@Telefono,@Fax);
  END;
  IF NOT EXISTS(SELECT 1 FROM Sensitive.People WHERE PersonID=@ContactoPrimarioID)
   OR (@ContactoAlternativoID IS NOT NULL AND NOT EXISTS(SELECT 1 FROM Sensitive.People WHERE PersonID=@ContactoAlternativoID))
   THROW 51512, 'El contacto seleccionado no existe en Corporativo.', 1;
  IF @Nuevo=1
  BEGIN
   SELECT @ProveedorID=ISNULL(MAX(SupplierID),0)+1 FROM Purchasing.Suppliers WITH(UPDLOCK,HOLDLOCK);
   INSERT Purchasing.Suppliers(SupplierID,SupplierName,SupplierCategoryID,PrimaryContactPersonID,
    AlternateContactPersonID,DeliveryMethodID,DeliveryCityID,PostalCityID,PaymentDays,SupplierReference)
   VALUES(@ProveedorID,@Nombre,@CategoriaID,@ContactoPrimarioID,@ContactoAlternativoID,@MetodoEntregaID,
    @CiudadEntregaID,@CiudadPostalID,@DiasPago,@ReferenciaProveedor);
   INSERT Sensitive.Suppliers(SupplierID,PhoneNumber,FaxNumber,WebsiteURL,DeliveryAddressLine1,
    DeliveryAddressLine2,DeliveryPostalCode,DeliveryLocation,PostalAddressLine1,PostalAddressLine2,PostalPostalCode)
   VALUES(@ProveedorID,@Telefono,@Fax,@SitioWeb,@DireccionEntrega1,@DireccionEntrega2,@CodigoPostalEntrega,
    CASE WHEN @Latitud IS NULL THEN NULL ELSE geography::Point(@Latitud,@Longitud,4326) END,
    @DireccionPostal1,@DireccionPostal2,@CodigoPostalPostal);
  END
  ELSE
  BEGIN
   UPDATE Purchasing.Suppliers SET SupplierName=@Nombre,
    SupplierCategoryID=@CategoriaID,
    PrimaryContactPersonID=@ContactoPrimarioID,AlternateContactPersonID=@ContactoAlternativoID,
    DeliveryMethodID=@MetodoEntregaID,DeliveryCityID=@CiudadEntregaID,PostalCityID=@CiudadPostalID,
    PaymentDays=@DiasPago,
    SupplierReference=@ReferenciaProveedor
   WHERE SupplierID=@ProveedorID;
   UPDATE Sensitive.Suppliers SET PhoneNumber=@Telefono,FaxNumber=@Fax,WebsiteURL=@SitioWeb,
    DeliveryAddressLine1=@DireccionEntrega1,DeliveryAddressLine2=@DireccionEntrega2,DeliveryPostalCode=@CodigoPostalEntrega,
    DeliveryLocation=CASE WHEN @Latitud IS NULL THEN NULL ELSE geography::Point(@Latitud,@Longitud,4326) END,
    PostalAddressLine1=@DireccionPostal1,PostalAddressLine2=@DireccionPostal2,PostalPostalCode=@CodigoPostalPostal
   WHERE SupplierID=@ProveedorID;
  END;
  UPDATE Sensitive.Suppliers SET BankAccountBranch=@NombreBanco,BankAccountNumber=@NumeroCuenta WHERE SupplierID=@ProveedorID;
  COMMIT;
  SELECT @ProveedorID AS ProveedorID;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Api_Contacto @PersonaID INT
AS
BEGIN
 SET NOCOUNT ON;
 SELECT FullName AS Contacto FROM Sensitive.People WHERE PersonID=@PersonaID;
END;
GO
