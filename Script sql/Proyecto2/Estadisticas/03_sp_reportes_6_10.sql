-- Reportes 6 a 10 sobre la copia consolidada de Corporativo.
-- Categoria de producto = StockGroup; subcategoria = StockItem (WWI no tiene subcategorias).
IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51500, 'Estos reportes se crean en Corporativo.', 1;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- Catalogos usados por los filtros. El usuario Corporativo no consulta tablas desde la API.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_Filtros @Tipo VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    IF @Tipo = 'grupos'
        SELECT StockGroupID AS Id, StockGroupName AS Nombre FROM syn.GruposProducto ORDER BY Nombre;
    ELSE IF @Tipo = 'productos'
        SELECT StockItemID AS Id, StockItemName AS Nombre FROM syn.Productos ORDER BY Nombre;
    ELSE IF @Tipo = 'proveedores'
        SELECT SupplierID AS Id, SupplierName AS Nombre FROM syn.Suppliers ORDER BY Nombre;
    ELSE IF @Tipo = 'categoriasCliente'
        SELECT CustomerCategoryID AS Id, CustomerCategoryName AS Nombre FROM syn.CustomerCategories ORDER BY Nombre;
    ELSE IF @Tipo = 'aniosVentas'
        SELECT DISTINCT YEAR(InvoiceDate) AS Id, CONVERT(VARCHAR(4), YEAR(InvoiceDate)) AS Nombre
        FROM syn.Invoices ORDER BY Id;
    ELSE IF @Tipo = 'aniosCompras'
        SELECT DISTINCT YEAR(OrderDate) AS Id, CONVERT(VARCHAR(4), YEAR(OrderDate)) AS Nombre
        FROM syn.PurchaseOrders ORDER BY Id;
    ELSE
        THROW 51501, 'Catalogo de filtros invalido.', 1;
END;
GO

-- 6: una columna por anio disponible. El PIVOT se hace por completo en SQL Server.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_MatrizVentasCategoria
    @SucursalID INT = NULL, @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @SucursalID IS NOT NULL AND @SucursalID NOT IN (1, 2)
        THROW 51502, 'Sucursal invalida.', 1;
    IF @Pagina < 1 THROW 51503, 'Pagina invalida.', 1;

    DECLARE @Columnas NVARCHAR(MAX), @Valores NVARCHAR(MAX), @Total NVARCHAR(MAX), @Consulta NVARCHAR(MAX);
    SELECT @Columnas = STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(Anio)), N',') WITHIN GROUP (ORDER BY Anio),
           @Valores = STRING_AGG(CONVERT(NVARCHAR(MAX), N'COALESCE(' + QUOTENAME(Anio) + N',0) AS ' + QUOTENAME(Anio)), N',') WITHIN GROUP (ORDER BY Anio),
           @Total = STRING_AGG(CONVERT(NVARCHAR(MAX), N'COALESCE(' + QUOTENAME(Anio) + N',0)'), N'+') WITHIN GROUP (ORDER BY Anio)
    FROM (SELECT DISTINCT YEAR(InvoiceDate) AS Anio FROM syn.Invoices
          WHERE @SucursalID IS NULL OR SucursalID = @SucursalID) AS A;

    IF @Columnas IS NULL
    BEGIN
        SELECT CAST(NULL AS INT) AS GrupoID, CAST(NULL AS NVARCHAR(100)) AS Categoria,
               CAST(NULL AS DECIMAL(18,2)) AS TotalGeneral, CAST(NULL AS INT) AS TotalRegistros
        WHERE 1 = 0;
        RETURN;
    END;

    SET @Consulta = N'
        ;WITH Ventas AS (
            SELECT g.StockGroupID AS GrupoID, g.StockGroupName AS Categoria,
                   YEAR(i.InvoiceDate) AS Anio, SUM(il.ExtendedPrice) AS Monto
            FROM syn.Invoices i
            JOIN syn.InvoiceLines il ON il.SucursalID=i.SucursalID AND il.InvoiceID=i.InvoiceID
            JOIN syn.ProductoGrupos pg ON pg.StockItemID=il.StockItemID
            JOIN syn.GruposProducto g ON g.StockGroupID=pg.StockGroupID
            WHERE @SucursalID IS NULL OR i.SucursalID=@SucursalID
            GROUP BY g.StockGroupID, g.StockGroupName, YEAR(i.InvoiceDate)
        )
        SELECT GrupoID, Categoria, ' + @Valores + N', ' + @Total + N' AS TotalGeneral,
               COUNT(*) OVER() AS TotalRegistros
        FROM Ventas PIVOT (SUM(Monto) FOR Anio IN (' + @Columnas + N')) AS p
        ORDER BY Categoria, GrupoID
        OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;';
    EXEC sys.sp_executesql @Consulta, N'@SucursalID INT, @Pagina INT', @SucursalID, @Pagina;
END;
GO

-- 7: compras de clientes; primera/ultima factura = fechas extremas del mes.
-- Cantidad minima/maxima se refiere a una linea de factura del grupo filtrado.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_SeguimientoClientes
    @SucursalID INT = NULL, @Anio INT = NULL, @Mes INT = NULL,
    @GrupoID INT = NULL, @ProductoID INT = NULL, @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Mes IS NOT NULL AND @Mes NOT BETWEEN 1 AND 12 THROW 51504, 'Mes invalido.', 1;
    IF @Pagina < 1 THROW 51503, 'Pagina invalida.', 1;
    IF @Anio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate)=@Anio)
        THROW 51505, 'El anio no tiene ventas.', 1;

    ;WITH Base AS (
        SELECT i.SucursalID, i.CustomerID, YEAR(i.InvoiceDate) AS Anio,
               MONTH(i.InvoiceDate) AS Mes, i.InvoiceDate, i.InvoiceID,
               il.Quantity, il.ExtendedPrice
        FROM syn.Invoices i
        JOIN syn.InvoiceLines il ON il.SucursalID=i.SucursalID AND il.InvoiceID=i.InvoiceID
        WHERE (@SucursalID IS NULL OR i.SucursalID=@SucursalID)
          AND (@Anio IS NULL OR YEAR(i.InvoiceDate)=@Anio)
          AND (@Mes IS NULL OR MONTH(i.InvoiceDate)=@Mes)
          AND (@ProductoID IS NULL OR il.StockItemID=@ProductoID)
          AND (@GrupoID IS NULL OR EXISTS
              (SELECT 1 FROM syn.ProductoGrupos pg WHERE pg.StockItemID=il.StockItemID AND pg.StockGroupID=@GrupoID))
    )
    SELECT b.SucursalID, b.Anio, b.Mes, b.CustomerID AS ClienteID,
           c.CustomerName AS Cliente, COUNT(DISTINCT b.InvoiceID) AS CantidadFacturas,
           MIN(b.InvoiceDate) AS PrimeraFactura, MAX(b.InvoiceDate) AS UltimaFactura,
           SUM(b.ExtendedPrice) AS MontoTotal, SUM(b.Quantity) AS CantidadTotal,
           MIN(b.Quantity) AS CantidadMinima, MAX(b.Quantity) AS CantidadMaxima,
           COUNT(*) OVER() AS TotalRegistros
    FROM Base b JOIN syn.Customers c ON c.CustomerID=b.CustomerID
    GROUP BY b.SucursalID, b.Anio, b.Mes, b.CustomerID, c.CustomerName
    ORDER BY b.Anio DESC, b.Mes DESC, c.CustomerName, b.SucursalID
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

-- 8: compras a proveedores; la unidad es OrderedOuters y la fecha es OrderDate.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_SeguimientoProveedores
    @SucursalID INT = NULL, @Anio INT = NULL, @Mes INT = NULL,
    @GrupoID INT = NULL, @ProductoID INT = NULL, @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Mes IS NOT NULL AND @Mes NOT BETWEEN 1 AND 12 THROW 51504, 'Mes invalido.', 1;
    IF @Pagina < 1 THROW 51503, 'Pagina invalida.', 1;
    IF @Anio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM syn.PurchaseOrders WHERE YEAR(OrderDate)=@Anio)
        THROW 51506, 'El anio no tiene ordenes de compra.', 1;

    ;WITH Base AS (
        SELECT po.SucursalID, po.SupplierID, YEAR(po.OrderDate) AS Anio,
               MONTH(po.OrderDate) AS Mes, po.OrderDate, po.PurchaseOrderID,
               pol.OrderedOuters, ISNULL(pol.OrderedOuters*pol.ExpectedUnitPricePerOuter,0) AS Monto
        FROM syn.PurchaseOrders po
        JOIN syn.PurchaseOrderLines pol ON pol.SucursalID=po.SucursalID AND pol.PurchaseOrderID=po.PurchaseOrderID
        WHERE (@SucursalID IS NULL OR po.SucursalID=@SucursalID)
          AND (@Anio IS NULL OR YEAR(po.OrderDate)=@Anio)
          AND (@Mes IS NULL OR MONTH(po.OrderDate)=@Mes)
          AND (@ProductoID IS NULL OR pol.StockItemID=@ProductoID)
          AND (@GrupoID IS NULL OR EXISTS
              (SELECT 1 FROM syn.ProductoGrupos pg WHERE pg.StockItemID=pol.StockItemID AND pg.StockGroupID=@GrupoID))
    )
    SELECT b.SucursalID, b.Anio, b.Mes, b.SupplierID AS ProveedorID,
           s.SupplierName AS Proveedor, COUNT(DISTINCT b.PurchaseOrderID) AS CantidadOrdenes,
           MIN(b.OrderDate) AS PrimeraOrden, MAX(b.OrderDate) AS UltimaOrden,
           SUM(b.Monto) AS MontoTotal, SUM(b.OrderedOuters) AS CantidadTotal,
           MIN(b.OrderedOuters) AS CantidadMinima, MAX(b.OrderedOuters) AS CantidadMaxima,
           COUNT(*) OVER() AS TotalRegistros
    FROM Base b JOIN syn.Suppliers s ON s.SupplierID=b.SupplierID
    GROUP BY b.SucursalID, b.Anio, b.Mes, b.SupplierID, s.SupplierName
    ORDER BY b.Anio DESC, b.Mes DESC, s.SupplierName, b.SucursalID
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

-- 9: dias de existencias = existencias actuales / ventas diarias del anio.
-- Es una estimacion: no existe historial de saldos iniciales en esta fragmentacion.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_RotacionInventario
    @SucursalID INT = NULL, @Anio INT = NULL, @GrupoID INT = NULL,
    @ProveedorID INT = NULL, @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Pagina < 1 THROW 51503, 'Pagina invalida.', 1;
    IF @Anio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate)=@Anio)
        THROW 51505, 'El anio no tiene ventas.', 1;

    ;WITH Ventas AS (
        SELECT i.SucursalID, YEAR(i.InvoiceDate) AS Anio, il.StockItemID,
               SUM(il.Quantity) AS CantidadVendida
        FROM syn.Invoices i
        JOIN syn.InvoiceLines il ON il.SucursalID=i.SucursalID AND il.InvoiceID=i.InvoiceID
        WHERE (@SucursalID IS NULL OR i.SucursalID=@SucursalID)
          AND (@Anio IS NULL OR YEAR(i.InvoiceDate)=@Anio)
        GROUP BY i.SucursalID, YEAR(i.InvoiceDate), il.StockItemID
    ), Totales AS (
        SELECT v.Anio, v.StockItemID, SUM(v.CantidadVendida) AS CantidadVendida,
               SUM(ISNULL(h.QuantityOnHand,0)) AS ExistenciaActual
        FROM Ventas v
        LEFT JOIN syn.Existencias h ON h.SucursalID=v.SucursalID AND h.StockItemID=v.StockItemID
        GROUP BY v.Anio, v.StockItemID
    )
    SELECT t.Anio, t.StockItemID AS ProductoID, p.StockItemName AS Producto,
           s.SupplierName AS Proveedor, t.CantidadVendida, t.ExistenciaActual,
           CAST(365.0*t.ExistenciaActual/NULLIF(t.CantidadVendida,0) AS DECIMAL(18,2)) AS DiasRotacion,
           COUNT(*) OVER() AS TotalRegistros
    FROM Totales t
    JOIN syn.Productos p ON p.StockItemID=t.StockItemID
    JOIN syn.Suppliers s ON s.SupplierID=p.SupplierID
    WHERE (@ProveedorID IS NULL OR p.SupplierID=@ProveedorID)
      AND (@GrupoID IS NULL OR EXISTS
          (SELECT 1 FROM syn.ProductoGrupos pg WHERE pg.StockItemID=p.StockItemID AND pg.StockGroupID=@GrupoID))
    ORDER BY t.Anio DESC, DiasRotacion DESC, p.StockItemName
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

-- 10: destino = ciudad de entrega actual del cliente; una factura cuenta una vez
-- por metodo aunque tenga varias lineas de producto que cumplan el filtro.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_MetodosEnvioDestino
    @SucursalID INT = NULL, @Anio INT = NULL, @Mes INT = NULL,
    @CategoriaClienteID INT = NULL, @GrupoID INT = NULL,
    @ProductoID INT = NULL, @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;
    IF @Mes IS NOT NULL AND @Mes NOT BETWEEN 1 AND 12 THROW 51504, 'Mes invalido.', 1;
    IF @Pagina < 1 THROW 51503, 'Pagina invalida.', 1;
    IF @Anio IS NOT NULL AND NOT EXISTS (SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate)=@Anio)
        THROW 51505, 'El anio no tiene ventas.', 1;

    ;WITH Totales AS (
        SELECT i.SucursalID, ci.CityID AS CiudadID, ci.CityName AS Ciudad,
               dm.DeliveryMethodID AS MetodoID, dm.DeliveryMethodName AS Metodo,
               COUNT_BIG(*) AS CantidadVentas
        FROM syn.Invoices i
        JOIN syn.Customers c ON c.CustomerID=i.CustomerID
        JOIN syn.Cities ci ON ci.CityID=c.DeliveryCityID
        JOIN syn.DeliveryMethods dm ON dm.DeliveryMethodID=i.DeliveryMethodID
        WHERE (@SucursalID IS NULL OR i.SucursalID=@SucursalID)
          AND (@Anio IS NULL OR YEAR(i.InvoiceDate)=@Anio)
          AND (@Mes IS NULL OR MONTH(i.InvoiceDate)=@Mes)
          AND (@CategoriaClienteID IS NULL OR c.CustomerCategoryID=@CategoriaClienteID)
          AND EXISTS (
              SELECT 1 FROM syn.InvoiceLines il
              WHERE il.SucursalID=i.SucursalID AND il.InvoiceID=i.InvoiceID
                AND (@ProductoID IS NULL OR il.StockItemID=@ProductoID)
                AND (@GrupoID IS NULL OR EXISTS
                    (SELECT 1 FROM syn.ProductoGrupos pg WHERE pg.StockItemID=il.StockItemID AND pg.StockGroupID=@GrupoID))
          )
        GROUP BY i.SucursalID, ci.CityID, ci.CityName, dm.DeliveryMethodID, dm.DeliveryMethodName
    ), Clasificados AS (
        SELECT *, DENSE_RANK() OVER (PARTITION BY SucursalID, CiudadID ORDER BY CantidadVentas DESC) AS Posicion
        FROM Totales
    )
    SELECT SucursalID, CiudadID, Ciudad, Posicion, MetodoID, Metodo, CantidadVentas,
           COUNT(*) OVER() AS TotalRegistros
    FROM Clasificados
    ORDER BY CantidadVentas DESC, Ciudad, SucursalID, Posicion, Metodo
    OFFSET (@Pagina-1)*10 ROWS FETCH NEXT 10 ROWS ONLY;
END;
GO

-- En una actualizacion incremental la cuenta ya existe. En una instalacion nueva,
-- 07_cuentas_api.local.sql otorga estos permisos despues de crear las cuentas.
IF DATABASE_PRINCIPAL_ID(N'api_corporativo') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_Filtros TO api_corporativo;
    GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_MatrizVentasCategoria TO api_corporativo;
    GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_SeguimientoClientes TO api_corporativo;
    GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_SeguimientoProveedores TO api_corporativo;
    GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_RotacionInventario TO api_corporativo;
    GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_MetodosEnvioDestino TO api_corporativo;
END;
GO
