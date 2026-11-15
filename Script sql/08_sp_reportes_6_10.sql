USE WideWorldImporters;
GO
-- Reportes 6-10 para la base original del Proyecto 1.
-- Grupo de producto = categoria; producto = subcategoria equivalente en WWI.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Reporte_MatrizVentasCategoria @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina < 1 THROW 51503, 'Pagina invalida.', 1;
    DECLARE @Columnas NVARCHAR(MAX), @Valores NVARCHAR(MAX), @Total NVARCHAR(MAX), @Consulta NVARCHAR(MAX);
    SELECT @Columnas = STRING_AGG(CONVERT(NVARCHAR(MAX),QUOTENAME(Anio)),N',') WITHIN GROUP (ORDER BY Anio),
           @Valores = STRING_AGG(CONVERT(NVARCHAR(MAX),N'COALESCE('+QUOTENAME(Anio)+N',0) AS '+QUOTENAME(Anio)),N',') WITHIN GROUP (ORDER BY Anio),
           @Total = STRING_AGG(CONVERT(NVARCHAR(MAX),N'COALESCE('+QUOTENAME(Anio)+N',0)'),N'+') WITHIN GROUP (ORDER BY Anio)
    FROM (SELECT DISTINCT YEAR(InvoiceDate) AS Anio FROM syn.Invoices) AS A;
    IF @Columnas IS NULL
    BEGIN
        SELECT CAST(NULL AS NVARCHAR(100)) AS Categoria WHERE 1=0;
        RETURN;
    END;
    SET @Consulta=N'
      ;WITH Ventas AS (
        SELECT g.StockGroupID AS GrupoID,g.StockGroupName AS Categoria,YEAR(i.InvoiceDate) AS Anio,
               SUM(il.ExtendedPrice) AS Monto
        FROM syn.Invoices i JOIN syn.InvoiceLines il ON il.InvoiceID=i.InvoiceID
        JOIN syn.StockItemStockGroups pg ON pg.StockItemID=il.StockItemID
        JOIN syn.StockGroups g ON g.StockGroupID=pg.StockGroupID
        GROUP BY g.StockGroupID,g.StockGroupName,YEAR(i.InvoiceDate)
      )
      SELECT GrupoID,Categoria,'+@Valores+N','+@Total+N' AS TotalGeneral,
             COUNT(*) OVER() AS TotalRegistros
      FROM Ventas PIVOT (SUM(Monto) FOR Anio IN ('+@Columnas+N')) AS p
      ORDER BY Categoria,GrupoID OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;';
    EXEC sys.sp_executesql @Consulta,N'@Pagina INT',@Pagina;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Reporte_SeguimientoClientes
    @Anio INT=NULL,@Mes INT=NULL,@GrupoID INT=NULL,@ProductoID INT=NULL,@Pagina INT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Mes IS NOT NULL AND @Mes NOT BETWEEN 1 AND 12 THROW 51504,'Mes invalido.',1;
    IF @Pagina<1 THROW 51503,'Pagina invalida.',1;
    IF @Anio IS NOT NULL AND NOT EXISTS(SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate)=@Anio)
        THROW 51505,'El anio no tiene ventas.',1;
    ;WITH Base AS (
        SELECT i.CustomerID,YEAR(i.InvoiceDate) AS Anio,MONTH(i.InvoiceDate) AS Mes,
               i.InvoiceDate,i.InvoiceID,il.Quantity,il.ExtendedPrice
        FROM syn.Invoices i JOIN syn.InvoiceLines il ON il.InvoiceID=i.InvoiceID
        WHERE (@Anio IS NULL OR YEAR(i.InvoiceDate)=@Anio)
          AND (@Mes IS NULL OR MONTH(i.InvoiceDate)=@Mes)
          AND (@ProductoID IS NULL OR il.StockItemID=@ProductoID)
          AND (@GrupoID IS NULL OR EXISTS(SELECT 1 FROM syn.StockItemStockGroups pg
              WHERE pg.StockItemID=il.StockItemID AND pg.StockGroupID=@GrupoID))
    )
    SELECT b.Anio,b.Mes,b.CustomerID AS ClienteID,c.CustomerName AS Cliente,
           COUNT(DISTINCT b.InvoiceID) AS CantidadFacturas,
           MIN(b.InvoiceDate) AS PrimeraFactura,MAX(b.InvoiceDate) AS UltimaFactura,
           SUM(b.ExtendedPrice) AS MontoTotal,SUM(b.Quantity) AS CantidadTotal,
           MIN(b.Quantity) AS CantidadMinima,MAX(b.Quantity) AS CantidadMaxima,
           COUNT(*) OVER() AS TotalRegistros
    FROM Base b JOIN syn.Customers c ON c.CustomerID=b.CustomerID
    GROUP BY b.Anio,b.Mes,b.CustomerID,c.CustomerName
    ORDER BY b.Anio DESC,b.Mes DESC,c.CustomerName
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Reporte_SeguimientoProveedores
    @Anio INT=NULL,@Mes INT=NULL,@GrupoID INT=NULL,@ProductoID INT=NULL,@Pagina INT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Mes IS NOT NULL AND @Mes NOT BETWEEN 1 AND 12 THROW 51504,'Mes invalido.',1;
    IF @Pagina<1 THROW 51503,'Pagina invalida.',1;
    IF @Anio IS NOT NULL AND NOT EXISTS(SELECT 1 FROM syn.PurchaseOrders WHERE YEAR(OrderDate)=@Anio)
        THROW 51506,'El anio no tiene ordenes de compra.',1;
    ;WITH Base AS (
        SELECT po.SupplierID,YEAR(po.OrderDate) AS Anio,MONTH(po.OrderDate) AS Mes,
               po.OrderDate,po.PurchaseOrderID,pol.OrderedOuters,
               ISNULL(pol.OrderedOuters*pol.ExpectedUnitPricePerOuter,0) AS Monto
        FROM syn.PurchaseOrders po JOIN syn.PurchaseOrderLines pol ON pol.PurchaseOrderID=po.PurchaseOrderID
        WHERE (@Anio IS NULL OR YEAR(po.OrderDate)=@Anio)
          AND (@Mes IS NULL OR MONTH(po.OrderDate)=@Mes)
          AND (@ProductoID IS NULL OR pol.StockItemID=@ProductoID)
          AND (@GrupoID IS NULL OR EXISTS(SELECT 1 FROM syn.StockItemStockGroups pg
              WHERE pg.StockItemID=pol.StockItemID AND pg.StockGroupID=@GrupoID))
    )
    SELECT b.Anio,b.Mes,b.SupplierID AS ProveedorID,s.SupplierName AS Proveedor,
           COUNT(DISTINCT b.PurchaseOrderID) AS CantidadOrdenes,
           MIN(b.OrderDate) AS PrimeraOrden,MAX(b.OrderDate) AS UltimaOrden,
           SUM(b.Monto) AS MontoTotal,SUM(b.OrderedOuters) AS CantidadTotal,
           MIN(b.OrderedOuters) AS CantidadMinima,MAX(b.OrderedOuters) AS CantidadMaxima,
           COUNT(*) OVER() AS TotalRegistros
    FROM Base b JOIN syn.Suppliers s ON s.SupplierID=b.SupplierID
    GROUP BY b.Anio,b.Mes,b.SupplierID,s.SupplierName
    ORDER BY b.Anio DESC,b.Mes DESC,s.SupplierName
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

-- Estimacion de dias de existencias con el saldo actual y ventas anuales.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_RotacionInventario
    @Anio INT=NULL,@GrupoID INT=NULL,@ProveedorID INT=NULL,@Pagina INT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina<1 THROW 51503,'Pagina invalida.',1;
    IF @Anio IS NOT NULL AND NOT EXISTS(SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate)=@Anio)
        THROW 51505,'El anio no tiene ventas.',1;
    ;WITH Ventas AS (
        SELECT YEAR(i.InvoiceDate) AS Anio,il.StockItemID,SUM(il.Quantity) AS CantidadVendida
        FROM syn.Invoices i JOIN syn.InvoiceLines il ON il.InvoiceID=i.InvoiceID
        WHERE @Anio IS NULL OR YEAR(i.InvoiceDate)=@Anio
        GROUP BY YEAR(i.InvoiceDate),il.StockItemID
    )
    SELECT v.Anio,p.StockItemID AS ProductoID,p.StockItemName AS Producto,
           s.SupplierName AS Proveedor,v.CantidadVendida,h.QuantityOnHand AS ExistenciaActual,
           CAST(365.0*h.QuantityOnHand/NULLIF(v.CantidadVendida,0) AS DECIMAL(18,2)) AS DiasRotacion,
           COUNT(*) OVER() AS TotalRegistros
    FROM Ventas v JOIN syn.StockItems p ON p.StockItemID=v.StockItemID
    JOIN syn.Suppliers s ON s.SupplierID=p.SupplierID
    JOIN syn.StockItemHoldings h ON h.StockItemID=p.StockItemID
    WHERE (@ProveedorID IS NULL OR p.SupplierID=@ProveedorID)
      AND (@GrupoID IS NULL OR EXISTS(SELECT 1 FROM syn.StockItemStockGroups pg
          WHERE pg.StockItemID=p.StockItemID AND pg.StockGroupID=@GrupoID))
    ORDER BY v.Anio DESC,DiasRotacion DESC,p.StockItemName
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Reporte_MetodosEnvioDestino
    @Anio INT=NULL,@Mes INT=NULL,@CategoriaClienteID INT=NULL,
    @GrupoID INT=NULL,@ProductoID INT=NULL,@Pagina INT=1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Mes IS NOT NULL AND @Mes NOT BETWEEN 1 AND 12 THROW 51504,'Mes invalido.',1;
    IF @Pagina<1 THROW 51503,'Pagina invalida.',1;
    IF @Anio IS NOT NULL AND NOT EXISTS(SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate)=@Anio)
        THROW 51505,'El anio no tiene ventas.',1;
    ;WITH Totales AS (
        SELECT ci.CityID AS CiudadID,ci.CityName AS Ciudad,
               dm.DeliveryMethodID AS MetodoID,dm.DeliveryMethodName AS Metodo,
               COUNT_BIG(*) AS CantidadVentas
        FROM syn.Invoices i JOIN syn.Customers c ON c.CustomerID=i.CustomerID
        JOIN syn.Cities ci ON ci.CityID=c.DeliveryCityID
        JOIN syn.DeliveryMethods dm ON dm.DeliveryMethodID=i.DeliveryMethodID
        WHERE (@Anio IS NULL OR YEAR(i.InvoiceDate)=@Anio)
          AND (@Mes IS NULL OR MONTH(i.InvoiceDate)=@Mes)
          AND (@CategoriaClienteID IS NULL OR c.CustomerCategoryID=@CategoriaClienteID)
          AND EXISTS(SELECT 1 FROM syn.InvoiceLines il WHERE il.InvoiceID=i.InvoiceID
              AND (@ProductoID IS NULL OR il.StockItemID=@ProductoID)
              AND (@GrupoID IS NULL OR EXISTS(SELECT 1 FROM syn.StockItemStockGroups pg
                  WHERE pg.StockItemID=il.StockItemID AND pg.StockGroupID=@GrupoID)))
        GROUP BY ci.CityID,ci.CityName,dm.DeliveryMethodID,dm.DeliveryMethodName
    ), Clasificados AS (
        SELECT *,DENSE_RANK() OVER(PARTITION BY CiudadID ORDER BY CantidadVentas DESC) AS Posicion
        FROM Totales
    )
    SELECT CiudadID,Ciudad,Posicion,MetodoID,Metodo,CantidadVentas,
           COUNT(*) OVER() AS TotalRegistros
    FROM Clasificados
    ORDER BY CantidadVentas DESC,Ciudad,Posicion,Metodo
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO
