-- Verificación no destructiva de consultas y CRUD de ventas.
-- Ejecutar una vez en San José y otra en Limón. Todo cambio termina en ROLLBACK.
SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @SucursalID INT = CASE DB_NAME()
    WHEN N'WideWorldImporters_SanJose' THEN 1
    WHEN N'WideWorldImporters_Limon' THEN 2
END;
IF @SucursalID IS NULL THROW 51500,'Conecte a San José o Limón.',1;
EXEC sys.sp_set_session_context @key=N'SucursalID',@value=@SucursalID;
EXEC sys.sp_set_session_context @key=N'iduser',@value=1;

IF (SELECT COUNT(*) FROM Application.People WHERE IsSalesperson=1 AND SucursalID=@SucursalID)<>5
    THROW 51501,'La sucursal no tiene exactamente cinco vendedores.',1;
IF NOT EXISTS(SELECT 1 FROM Sales.Customers)
    THROW 51502,'No hay clientes cargados.',1;
IF NOT EXISTS(SELECT 1 FROM Purchasing.Suppliers)
    THROW 51503,'No hay proveedores cargados.',1;

EXEC dbo.usp_Catalogo_Vendedores;
EXEC dbo.usp_Clientes_Listar @Pagina=1,@TamanoPagina=5;
EXEC dbo.usp_Proveedores_Listar @Pagina=1,@TamanoPagina=5;

DECLARE @ClienteID INT=(SELECT TOP(1) CustomerID FROM Sales.Customers ORDER BY CustomerID);
DECLARE @ProveedorID INT=(SELECT TOP(1) SupplierID FROM Purchasing.Suppliers ORDER BY SupplierID);
DECLARE @MaxFacturaOriginal INT=ISNULL((SELECT MAX(InvoiceID) FROM Sales.Invoices),0);
DECLARE @MaxLineaOriginal INT=ISNULL((SELECT MAX(InvoiceLineID) FROM Sales.InvoiceLines),0);
EXEC dbo.usp_Clientes_Detalle @ClienteID=@ClienteID;
EXEC dbo.usp_Proveedores_Detalle @ProveedorID=@ProveedorID;

BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @VendedorID INT=(SELECT TOP(1) PersonID FROM Application.People
                             WHERE IsSalesperson=1 AND SucursalID=@SucursalID ORDER BY PersonID);
    DECLARE @ProductoID INT=(SELECT TOP(1) StockItemID FROM Warehouse.StockItemHoldings
                             WHERE SucursalID=@SucursalID AND QuantityOnHand>=3 ORDER BY StockItemID);
    DECLARE @CantidadInicial INT=(SELECT QuantityOnHand FROM Warehouse.StockItemHoldings
                                  WHERE SucursalID=@SucursalID AND StockItemID=@ProductoID);
    DECLARE @Lineas NVARCHAR(MAX)=N'[{"ProductoID":'+CONVERT(NVARCHAR(20),@ProductoID)+N',"Cantidad":2}]';
    EXEC dbo.usp_Ventas_Insertar @ClienteID=@ClienteID,@VendedorID=@VendedorID,
        @LineasJson=@Lineas,@OrdenCompraCliente=N'B3-VERIFY';
    DECLARE @FacturaID INT=(SELECT TOP(1) InvoiceID FROM Sales.Invoices
                            WHERE SucursalID=@SucursalID
                              AND CustomerPurchaseOrderNumber=N'B3-VERIFY'
                            ORDER BY InvoiceID DESC);
    IF @FacturaID IS NULL THROW 51504,'No se creó la factura de prueba.',1;
    IF (SELECT QuantityOnHand FROM Warehouse.StockItemHoldings
        WHERE SucursalID=@SucursalID AND StockItemID=@ProductoID)<>@CantidadInicial-2
        THROW 51505,'La inserción no descontó correctamente el inventario.',1;

    SET @Lineas=N'[{"ProductoID":'+CONVERT(NVARCHAR(20),@ProductoID)+N',"Cantidad":1}]';
    EXEC dbo.usp_Ventas_Actualizar @FacturaID=@FacturaID,@ClienteID=@ClienteID,
        @VendedorID=@VendedorID,@LineasJson=@Lineas;
    IF (SELECT QuantityOnHand FROM Warehouse.StockItemHoldings
        WHERE SucursalID=@SucursalID AND StockItemID=@ProductoID)<>@CantidadInicial-1
        THROW 51506,'La actualización no ajustó correctamente el inventario.',1;

    EXEC dbo.usp_Ventas_Eliminar @FacturaID=@FacturaID;
    IF (SELECT QuantityOnHand FROM Warehouse.StockItemHoldings
        WHERE SucursalID=@SucursalID AND StockItemID=@ProductoID)<>@CantidadInicial
        THROW 51507,'La eliminación no restauró correctamente el inventario.',1;

    ROLLBACK;

    DECLARE @VendedorOtraSucursal INT=(SELECT TOP(1) PersonID FROM Application.People
                                       WHERE IsSalesperson=1 AND SucursalID<>@SucursalID ORDER BY PersonID);
    DECLARE @RechazoVendedor BIT=0;
    BEGIN TRY
        EXEC dbo.usp_Ventas_Insertar @ClienteID=@ClienteID,
            @VendedorID=@VendedorOtraSucursal,@LineasJson=@Lineas;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()=51414 SET @RechazoVendedor=1;
        ELSE THROW;
    END CATCH;
    IF @RechazoVendedor=0 THROW 51508,'Se aceptó un vendedor de otra sucursal.',1;

    SET @Lineas=N'[{"ProductoID":'+CONVERT(NVARCHAR(20),@ProductoID)+N',"Cantidad":2147483647}]';
    DECLARE @RechazoInventario BIT=0;
    BEGIN TRY
        EXEC dbo.usp_Ventas_Insertar @ClienteID=@ClienteID,
            @VendedorID=@VendedorID,@LineasJson=@Lineas;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()=51415 SET @RechazoInventario=1;
        ELSE THROW;
    END CATCH;
    IF @RechazoInventario=0 THROW 51509,'Se aceptó una venta sin inventario suficiente.',1;

    DECLARE @ReiniciarIdentidades NVARCHAR(MAX)=
        N'DBCC CHECKIDENT (''Sales.Invoices'', RESEED, '+CONVERT(NVARCHAR(20),@MaxFacturaOriginal)+N') WITH NO_INFOMSGS;'+
        N'DBCC CHECKIDENT (''Sales.InvoiceLines'', RESEED, '+CONVERT(NVARCHAR(20),@MaxLineaOriginal)+N') WITH NO_INFOMSGS;';
    EXEC sys.sp_executesql @ReiniciarIdentidades;

    SELECT DB_NAME() AS Nodo,N'CORRECTO' AS EstadoOperacion,
           @RechazoVendedor AS RechazoVendedorExterno,
           @RechazoInventario AS RechazoInventarioInsuficiente;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK;
    THROW;
END CATCH;
