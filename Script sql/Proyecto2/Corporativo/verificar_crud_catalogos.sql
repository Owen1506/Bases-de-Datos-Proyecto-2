-- Prueba no destructiva de los CRUD corporativos de clientes y proveedores.
-- Todo cambio se revierte al finalizar.
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME()<>N'WideWorldImporters_Corporativo'
    THROW 51520,'Conecte a Corporativo.',1;

DECLARE @CategoriaClienteID INT=(SELECT TOP(1) CustomerCategoryID FROM Sales.CustomerCategories ORDER BY CustomerCategoryID);
DECLARE @GrupoCompraID INT=(SELECT TOP(1) BuyingGroupID FROM Sales.BuyingGroups ORDER BY BuyingGroupID);
DECLARE @CategoriaProveedorID INT=(SELECT TOP(1) SupplierCategoryID FROM Purchasing.SupplierCategories ORDER BY SupplierCategoryID);
DECLARE @MetodoEntregaID INT=(SELECT TOP(1) DeliveryMethodID FROM Application.DeliveryMethods ORDER BY DeliveryMethodID);
DECLARE @CiudadID INT=(SELECT TOP(1) CityID FROM Application.Cities ORDER BY CityID);
IF @CategoriaClienteID IS NULL OR @CategoriaProveedorID IS NULL OR @MetodoEntregaID IS NULL OR @CiudadID IS NULL
    THROW 51521,'Faltan catálogos para realizar la prueba.',1;

BEGIN TRANSACTION;
BEGIN TRY
    EXEC dbo.usp_Clientes_Insertar
        @Nombre=N'Cliente temporal de verificación',@CategoriaClienteID=@CategoriaClienteID,
        @GrupoCompraID=@GrupoCompraID,@MetodoEntregaID=@MetodoEntregaID,
        @CiudadEntregaID=@CiudadID,@CiudadPostalID=@CiudadID,@FechaApertura='20261114',
        @DescuentoEstandar=0,@DiasPago=7,@ContactoPrincipal=N'Contacto temporal',
        @Telefono=N'0000-0000',@Fax=N'0000-0000',@SitioWeb=N'https://example.invalid',
        @DireccionEntrega1=N'Dirección temporal',@CodigoPostalEntrega=N'00000',
        @DireccionPostal1=N'Dirección temporal',@CodigoPostal=N'00000';
    DECLARE @ClienteID INT=(SELECT TOP(1) CustomerID FROM Sales.Customers
                            WHERE CustomerName=N'Cliente temporal de verificación'
                            ORDER BY CustomerID DESC);
    IF @ClienteID IS NULL THROW 51522,'No se creó el cliente temporal.',1;
    EXEC dbo.usp_Clientes_Actualizar @ClienteID=@ClienteID,
        @Nombre=N'Cliente temporal actualizado',@CategoriaClienteID=@CategoriaClienteID,
        @GrupoCompraID=@GrupoCompraID,@MetodoEntregaID=@MetodoEntregaID,
        @CiudadEntregaID=@CiudadID,@CiudadPostalID=@CiudadID,@FechaApertura='20261114',
        @DescuentoEstandar=1,@DiasPago=10,@ContactoPrincipal=N'Contacto actualizado',
        @Telefono=N'0000-0001',@Fax=N'0000-0001',@SitioWeb=N'https://example.invalid',
        @DireccionEntrega1=N'Dirección temporal',@CodigoPostalEntrega=N'00000',
        @DireccionPostal1=N'Dirección temporal',@CodigoPostal=N'00000';
    EXEC dbo.usp_Clientes_Eliminar @ClienteID=@ClienteID;

    EXEC dbo.usp_Proveedores_Insertar
        @Nombre=N'Proveedor temporal de verificación',@CategoriaProveedorID=@CategoriaProveedorID,
        @MetodoEntregaID=@MetodoEntregaID,@DiasPago=7,@ContactoPrincipal=N'Contacto temporal',
        @Telefono=N'0000-0000',@Fax=N'0000-0000',@SitioWeb=N'https://example.invalid',
        @DireccionEntrega1=N'Dirección temporal',@CodigoPostalEntrega=N'00000',
        @DireccionPostal1=N'Dirección temporal',@CodigoPostal=N'00000';
    DECLARE @ProveedorID INT=(SELECT TOP(1) SupplierID FROM Purchasing.Suppliers
                              WHERE SupplierName=N'Proveedor temporal de verificación'
                              ORDER BY SupplierID DESC);
    IF @ProveedorID IS NULL THROW 51523,'No se creó el proveedor temporal.',1;
    EXEC dbo.usp_Proveedores_Actualizar @ProveedorID=@ProveedorID,
        @Nombre=N'Proveedor temporal actualizado',@CategoriaProveedorID=@CategoriaProveedorID,
        @MetodoEntregaID=@MetodoEntregaID,@DiasPago=10,@ContactoPrincipal=N'Contacto actualizado',
        @Telefono=N'0000-0001',@Fax=N'0000-0001',@SitioWeb=N'https://example.invalid',
        @DireccionEntrega1=N'Dirección temporal',@CodigoPostalEntrega=N'00000',
        @DireccionPostal1=N'Dirección temporal',@CodigoPostal=N'00000';
    EXEC dbo.usp_Proveedores_Eliminar @ProveedorID=@ProveedorID;

    ROLLBACK;
    SELECT N'CORRECTO' AS EstadoCrudCorporativo;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
