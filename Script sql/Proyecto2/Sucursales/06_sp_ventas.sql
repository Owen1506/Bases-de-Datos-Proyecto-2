-- Facturación local de cada sucursal.
-- Las líneas se reciben como JSON para conservar una sola transacción por factura.
SET XACT_ABORT ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Listar
    @Busqueda NVARCHAR(100) = NULL, @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL, @Pagina INT = 1, @TamanoPagina INT = 25
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SucursalID INT=TRY_CONVERT(INT,SESSION_CONTEXT(N'SucursalID'));
    IF @SucursalID NOT IN(1,2) THROW 51400,'No existe una sucursal válida en la sesión.',1;
    IF @Pagina<1 OR @TamanoPagina NOT BETWEEN 1 AND 200
        THROW 51401,'La página o su tamaño no son válidos.',1;

    SELECT i.InvoiceID AS FacturaID,i.InvoiceDate AS Fecha,
           i.CustomerID AS ClienteID,c.CustomerName AS Cliente,
           i.SalespersonPersonID AS VendedorID,p.FullName AS Vendedor,
           SUM(il.ExtendedPrice) AS Total,
           COUNT_BIG(*) OVER() AS TotalRegistros
    FROM Sales.Invoices AS i
    JOIN Sales.Customers AS c ON c.CustomerID=i.CustomerID
    JOIN Application.People AS p ON p.PersonID=i.SalespersonPersonID
    JOIN Sales.InvoiceLines AS il ON il.SucursalID=i.SucursalID AND il.InvoiceID=i.InvoiceID
    WHERE i.SucursalID=@SucursalID
      AND (@Busqueda IS NULL OR c.CustomerName LIKE N'%'+@Busqueda+N'%'
           OR CONVERT(NVARCHAR(20),i.InvoiceID)=@Busqueda)
      AND (@FechaInicio IS NULL OR i.InvoiceDate>=@FechaInicio)
      AND (@FechaFin IS NULL OR i.InvoiceDate<=@FechaFin)
    GROUP BY i.InvoiceID,i.InvoiceDate,i.CustomerID,c.CustomerName,
             i.SalespersonPersonID,p.FullName
    ORDER BY i.InvoiceDate DESC,i.InvoiceID DESC
    OFFSET (@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Detalle
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SucursalID INT=TRY_CONVERT(INT,SESSION_CONTEXT(N'SucursalID'));
    IF @SucursalID NOT IN(1,2) THROW 51402,'No existe una sucursal válida en la sesión.',1;
    IF NOT EXISTS(SELECT 1 FROM Sales.Invoices WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID)
        THROW 51403,'La factura no existe en esta sucursal.',1;

    SELECT i.InvoiceID AS FacturaID,i.InvoiceDate AS Fecha,i.CustomerID AS ClienteID,
           c.CustomerName AS Cliente,i.BillToCustomerID AS ClienteFacturacionID,
           i.DeliveryMethodID AS MetodoEntregaID,i.ContactPersonID AS ContactoID,
           i.AccountsPersonID AS ContactoCuentasID,
           i.SalespersonPersonID AS VendedorID,p.FullName AS Vendedor,
           i.PackedByPersonID AS EmpacadoPorID,
           i.CustomerPurchaseOrderNumber AS OrdenCompraCliente,
           i.IsCreditNote AS EsNotaCredito,i.CreditNoteReason AS RazonNotaCredito,
           i.Comments AS Comentarios,i.DeliveryInstructions AS InstruccionesEntrega,
           i.TotalDryItems AS TotalSecos,i.TotalChillerItems AS TotalRefrigerados
    FROM Sales.Invoices AS i
    JOIN Sales.Customers AS c ON c.CustomerID=i.CustomerID
    JOIN Application.People AS p ON p.PersonID=i.SalespersonPersonID
    WHERE i.SucursalID=@SucursalID AND i.InvoiceID=@FacturaID;

    SELECT il.InvoiceLineID AS LineaFacturaID,il.StockItemID AS ProductoID,
           il.Description AS Descripcion,il.PackageTypeID AS TipoEmpaqueID,
           il.Quantity AS Cantidad,il.UnitPrice AS PrecioUnitario,
           il.TaxRate AS TasaImpuesto,il.TaxAmount AS Impuesto,
           il.LineProfit AS Ganancia,il.ExtendedPrice AS Total
    FROM Sales.InvoiceLines AS il
    WHERE il.SucursalID=@SucursalID AND il.InvoiceID=@FacturaID
    ORDER BY il.InvoiceLineID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Insertar
    @ClienteID INT,@VendedorID INT,@LineasJson NVARCHAR(MAX),
    @Fecha DATE=NULL,@ClienteFacturacionID INT=NULL,@MetodoEntregaID INT=NULL,
    @ContactoID INT=NULL,@ContactoCuentasID INT=NULL,@EmpacadoPorID INT=NULL,
    @OrdenCompraCliente NVARCHAR(20)=NULL,@EsNotaCredito BIT=0,
    @RazonNotaCredito NVARCHAR(MAX)=NULL,@Comentarios NVARCHAR(MAX)=NULL,
    @InstruccionesEntrega NVARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SucursalID INT=TRY_CONVERT(INT,SESSION_CONTEXT(N'SucursalID'));
    IF @SucursalID NOT IN(1,2) THROW 51410,'No existe una sucursal válida en la sesión.',1;
    IF ISJSON(@LineasJson)<>1 THROW 51411,'Las líneas de la factura no son JSON válido.',1;

    DECLARE @Lineas TABLE(ProductoID INT PRIMARY KEY,Cantidad INT NOT NULL,
        Descripcion NVARCHAR(100) NULL,TipoEmpaqueID INT NULL,
        PrecioUnitario DECIMAL(18,2) NULL,TasaImpuesto DECIMAL(18,3) NULL);
    INSERT @Lineas(ProductoID,Cantidad,Descripcion,TipoEmpaqueID,PrecioUnitario,TasaImpuesto)
    SELECT ProductoID,SUM(Cantidad),MAX(Descripcion),MAX(TipoEmpaqueID),
           MAX(PrecioUnitario),MAX(TasaImpuesto)
    FROM OPENJSON(@LineasJson) WITH(
        ProductoID INT '$.ProductoID',Cantidad INT '$.Cantidad',
        Descripcion NVARCHAR(100) '$.Descripcion',TipoEmpaqueID INT '$.TipoEmpaqueID',
        PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario',TasaImpuesto DECIMAL(18,3) '$.TasaImpuesto')
    GROUP BY ProductoID;
    IF NOT EXISTS(SELECT 1 FROM @Lineas) OR EXISTS(SELECT 1 FROM @Lineas WHERE ProductoID IS NULL OR Cantidad<=0)
        THROW 51412,'La factura debe contener líneas válidas con cantidad positiva.',1;

    BEGIN TRY
        BEGIN TRANSACTION;
        DECLARE @ContactoPrincipal INT,@MetodoCliente INT,@ClienteCobro INT;
        SELECT @ContactoPrincipal=PrimaryContactPersonID,@MetodoCliente=DeliveryMethodID,
               @ClienteCobro=BillToCustomerID
        FROM Sales.Customers WITH(HOLDLOCK) WHERE CustomerID=@ClienteID;
        IF @ContactoPrincipal IS NULL THROW 51413,'El cliente no existe.',1;
        IF NOT EXISTS(SELECT 1 FROM Application.People
                      WHERE PersonID=@VendedorID AND IsSalesperson=1 AND SucursalID=@SucursalID)
            THROW 51414,'El vendedor no pertenece a esta sucursal.',1;

        DECLARE @BloqueoInventario INT;
        SELECT @BloqueoInventario=SUM(h.StockItemID)
        FROM Warehouse.StockItemHoldings AS h WITH(UPDLOCK,HOLDLOCK)
        JOIN @Lineas AS l ON l.ProductoID=h.StockItemID
        WHERE h.SucursalID=@SucursalID;
        IF EXISTS(SELECT 1 FROM @Lineas AS l LEFT JOIN Warehouse.StockItemHoldings AS h
                  ON h.SucursalID=@SucursalID AND h.StockItemID=l.ProductoID
                  WHERE h.StockItemID IS NULL OR h.QuantityOnHand<l.Cantidad)
            THROW 51415,'No existe inventario suficiente para uno o más productos.',1;

        DECLARE @Preparadas TABLE(ProductoID INT PRIMARY KEY,Cantidad INT,
            Descripcion NVARCHAR(100),TipoEmpaqueID INT,PrecioUnitario DECIMAL(18,2),
            TasaImpuesto DECIMAL(18,3),Impuesto DECIMAL(18,2),
            Ganancia DECIMAL(18,2),Total DECIMAL(18,2),EsRefrigerado BIT);
        INSERT @Preparadas
        SELECT l.ProductoID,l.Cantidad,COALESCE(l.Descripcion,si.StockItemName),
               COALESCE(l.TipoEmpaqueID,si.UnitPackageID),
               COALESCE(l.PrecioUnitario,si.UnitPrice),COALESCE(l.TasaImpuesto,si.TaxRate),
               ROUND(l.Cantidad*COALESCE(l.PrecioUnitario,si.UnitPrice)*COALESCE(l.TasaImpuesto,si.TaxRate)/100,2),
               ROUND(l.Cantidad*(COALESCE(l.PrecioUnitario,si.UnitPrice)-ISNULL(h.LastCostPrice,0)),2),
               ROUND(l.Cantidad*COALESCE(l.PrecioUnitario,si.UnitPrice)*(1+COALESCE(l.TasaImpuesto,si.TaxRate)/100),2),
               si.IsChillerStock
        FROM @Lineas AS l JOIN Warehouse.StockItems AS si ON si.StockItemID=l.ProductoID
        JOIN Warehouse.StockItemHoldings AS h ON h.SucursalID=@SucursalID AND h.StockItemID=l.ProductoID;

        UPDATE h SET QuantityOnHand=h.QuantityOnHand-p.Cantidad
        FROM Warehouse.StockItemHoldings AS h JOIN @Preparadas AS p ON p.ProductoID=h.StockItemID
        WHERE h.SucursalID=@SucursalID;

        SET @Fecha=COALESCE(@Fecha,CONVERT(DATE,SYSDATETIME()));
        SET @ClienteFacturacionID=COALESCE(@ClienteFacturacionID,@ClienteCobro);
        SET @MetodoEntregaID=COALESCE(@MetodoEntregaID,@MetodoCliente);
        SET @ContactoID=COALESCE(@ContactoID,@ContactoPrincipal);
        SET @ContactoCuentasID=COALESCE(@ContactoCuentasID,@ContactoPrincipal);
        SET @EmpacadoPorID=COALESCE(@EmpacadoPorID,@VendedorID);
        INSERT Sales.Invoices(SucursalID,CustomerID,BillToCustomerID,OrderID,
            DeliveryMethodID,ContactPersonID,AccountsPersonID,SalespersonPersonID,
            PackedByPersonID,InvoiceDate,CustomerPurchaseOrderNumber,IsCreditNote,
            CreditNoteReason,Comments,DeliveryInstructions,InternalComments,
            TotalDryItems,TotalChillerItems,DeliveryRun,RunPosition,ReturnedDeliveryData)
        SELECT @SucursalID,@ClienteID,@ClienteFacturacionID,NULL,@MetodoEntregaID,
               @ContactoID,@ContactoCuentasID,@VendedorID,@EmpacadoPorID,@Fecha,
               @OrdenCompraCliente,@EsNotaCredito,@RazonNotaCredito,@Comentarios,
               @InstruccionesEntrega,NULL,
               ISNULL(SUM(CASE WHEN EsRefrigerado=0 THEN Cantidad ELSE 0 END),0),
               ISNULL(SUM(CASE WHEN EsRefrigerado=1 THEN Cantidad ELSE 0 END),0),
               NULL,NULL,NULL FROM @Preparadas;
        DECLARE @FacturaID INT=CONVERT(INT,SCOPE_IDENTITY());
        INSERT Sales.InvoiceLines(SucursalID,InvoiceID,StockItemID,Description,
            PackageTypeID,Quantity,UnitPrice,TaxRate,TaxAmount,LineProfit,ExtendedPrice)
        SELECT @SucursalID,@FacturaID,ProductoID,Descripcion,TipoEmpaqueID,Cantidad,
               PrecioUnitario,TasaImpuesto,Impuesto,Ganancia,Total FROM @Preparadas;
        COMMIT;
        SELECT @FacturaID AS FacturaID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Actualizar
    @FacturaID INT,@ClienteID INT,@VendedorID INT,@LineasJson NVARCHAR(MAX),
    @Fecha DATE=NULL,@Comentarios NVARCHAR(MAX)=NULL,@InstruccionesEntrega NVARCHAR(MAX)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SucursalID INT=TRY_CONVERT(INT,SESSION_CONTEXT(N'SucursalID'));
    IF @SucursalID NOT IN(1,2) THROW 51420,'No existe una sucursal válida en la sesión.',1;
    IF ISJSON(@LineasJson)<>1 THROW 51421,'Las líneas de la factura no son JSON válido.',1;
    DECLARE @Nuevas TABLE(ProductoID INT PRIMARY KEY,Cantidad INT,Descripcion NVARCHAR(100),
        TipoEmpaqueID INT,PrecioUnitario DECIMAL(18,2),TasaImpuesto DECIMAL(18,3));
    INSERT @Nuevas SELECT ProductoID,SUM(Cantidad),MAX(Descripcion),MAX(TipoEmpaqueID),
        MAX(PrecioUnitario),MAX(TasaImpuesto)
    FROM OPENJSON(@LineasJson) WITH(ProductoID INT '$.ProductoID',Cantidad INT '$.Cantidad',
        Descripcion NVARCHAR(100) '$.Descripcion',TipoEmpaqueID INT '$.TipoEmpaqueID',
        PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario',TasaImpuesto DECIMAL(18,3) '$.TasaImpuesto')
    GROUP BY ProductoID;
    IF NOT EXISTS(SELECT 1 FROM @Nuevas) OR EXISTS(SELECT 1 FROM @Nuevas WHERE Cantidad<=0)
        THROW 51422,'Las líneas no son válidas.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM Sales.Invoices WITH(UPDLOCK,HOLDLOCK)
                      WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID)
            THROW 51423,'La factura no existe en esta sucursal.',1;
        IF NOT EXISTS(SELECT 1 FROM Sales.Customers WHERE CustomerID=@ClienteID)
            THROW 51424,'El cliente no existe.',1;
        IF NOT EXISTS(SELECT 1 FROM Application.People WHERE PersonID=@VendedorID
                      AND IsSalesperson=1 AND SucursalID=@SucursalID)
            THROW 51425,'El vendedor no pertenece a esta sucursal.',1;

        UPDATE h SET QuantityOnHand=h.QuantityOnHand+x.Cantidad
        FROM Warehouse.StockItemHoldings AS h
        JOIN(SELECT StockItemID,SUM(Quantity) Cantidad FROM Sales.InvoiceLines
             WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID GROUP BY StockItemID) AS x
          ON x.StockItemID=h.StockItemID
        WHERE h.SucursalID=@SucursalID;
        DECLARE @BloqueoInventario INT;
        SELECT @BloqueoInventario=SUM(h.StockItemID) FROM Warehouse.StockItemHoldings AS h WITH(UPDLOCK,HOLDLOCK)
        JOIN @Nuevas AS n ON n.ProductoID=h.StockItemID WHERE h.SucursalID=@SucursalID;
        IF EXISTS(SELECT 1 FROM @Nuevas AS n LEFT JOIN Warehouse.StockItemHoldings AS h
                  ON h.SucursalID=@SucursalID AND h.StockItemID=n.ProductoID
                  WHERE h.StockItemID IS NULL OR h.QuantityOnHand<n.Cantidad)
            THROW 51426,'No existe inventario suficiente para uno o más productos.',1;

        DELETE Sales.InvoiceLines WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID;
        UPDATE h SET QuantityOnHand=h.QuantityOnHand-n.Cantidad
        FROM Warehouse.StockItemHoldings AS h JOIN @Nuevas AS n ON n.ProductoID=h.StockItemID
        WHERE h.SucursalID=@SucursalID;
        UPDATE i SET CustomerID=@ClienteID,BillToCustomerID=c.BillToCustomerID,
            DeliveryMethodID=c.DeliveryMethodID,ContactPersonID=c.PrimaryContactPersonID,
            AccountsPersonID=c.PrimaryContactPersonID,SalespersonPersonID=@VendedorID,
            PackedByPersonID=@VendedorID,InvoiceDate=COALESCE(@Fecha,InvoiceDate),
            Comments=@Comentarios,DeliveryInstructions=@InstruccionesEntrega
        FROM Sales.Invoices AS i JOIN Sales.Customers AS c ON c.CustomerID=@ClienteID
        WHERE i.SucursalID=@SucursalID AND i.InvoiceID=@FacturaID;
        INSERT Sales.InvoiceLines(SucursalID,InvoiceID,StockItemID,Description,PackageTypeID,
            Quantity,UnitPrice,TaxRate,TaxAmount,LineProfit,ExtendedPrice)
        SELECT @SucursalID,@FacturaID,n.ProductoID,COALESCE(n.Descripcion,si.StockItemName),
            COALESCE(n.TipoEmpaqueID,si.UnitPackageID),n.Cantidad,
            COALESCE(n.PrecioUnitario,si.UnitPrice),COALESCE(n.TasaImpuesto,si.TaxRate),
            ROUND(n.Cantidad*COALESCE(n.PrecioUnitario,si.UnitPrice)*COALESCE(n.TasaImpuesto,si.TaxRate)/100,2),
            ROUND(n.Cantidad*(COALESCE(n.PrecioUnitario,si.UnitPrice)-ISNULL(h.LastCostPrice,0)),2),
            ROUND(n.Cantidad*COALESCE(n.PrecioUnitario,si.UnitPrice)*(1+COALESCE(n.TasaImpuesto,si.TaxRate)/100),2)
        FROM @Nuevas AS n JOIN Warehouse.StockItems AS si ON si.StockItemID=n.ProductoID
        JOIN Warehouse.StockItemHoldings AS h ON h.SucursalID=@SucursalID AND h.StockItemID=n.ProductoID;
        UPDATE i SET TotalDryItems=x.Secos,TotalChillerItems=x.Frios
        FROM Sales.Invoices AS i CROSS APPLY(
            SELECT ISNULL(SUM(CASE WHEN si.IsChillerStock=0 THEN il.Quantity ELSE 0 END),0) Secos,
                   ISNULL(SUM(CASE WHEN si.IsChillerStock=1 THEN il.Quantity ELSE 0 END),0) Frios
            FROM Sales.InvoiceLines il JOIN Warehouse.StockItems si ON si.StockItemID=il.StockItemID
            WHERE il.SucursalID=@SucursalID AND il.InvoiceID=@FacturaID) x
        WHERE i.SucursalID=@SucursalID AND i.InvoiceID=@FacturaID;
        COMMIT;
        SELECT @FacturaID AS FacturaID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Eliminar
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @SucursalID INT=TRY_CONVERT(INT,SESSION_CONTEXT(N'SucursalID'));
    IF @SucursalID NOT IN(1,2) THROW 51430,'No existe una sucursal válida en la sesión.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM Sales.Invoices WITH(UPDLOCK,HOLDLOCK)
                      WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID)
            THROW 51431,'La factura no existe en esta sucursal.',1;
        DECLARE @BloqueoInventario INT;
        SELECT @BloqueoInventario=SUM(h.StockItemID) FROM Warehouse.StockItemHoldings h WITH(UPDLOCK,HOLDLOCK)
        JOIN Sales.InvoiceLines il ON il.SucursalID=@SucursalID AND il.InvoiceID=@FacturaID
          AND il.StockItemID=h.StockItemID WHERE h.SucursalID=@SucursalID;
        UPDATE h SET QuantityOnHand=h.QuantityOnHand+x.Cantidad
        FROM Warehouse.StockItemHoldings h
        JOIN(SELECT StockItemID,SUM(Quantity) Cantidad FROM Sales.InvoiceLines
             WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID GROUP BY StockItemID)x
          ON x.StockItemID=h.StockItemID WHERE h.SucursalID=@SucursalID;
        DELETE Sales.InvoiceLines WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID;
        DELETE Sales.Invoices WHERE SucursalID=@SucursalID AND InvoiceID=@FacturaID;
        COMMIT;
        SELECT @FacturaID AS FacturaID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK;
        THROW;
    END CATCH;
END;
GO
