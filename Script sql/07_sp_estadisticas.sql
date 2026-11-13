USE WideWorldImporters;
GO

-- REPORTE 1: Montos mínimos, máximos y promedio de compras por proveedor y categoría usando ROLLUP
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_ComprasProveedores
    @Categoria NVARCHAR(100) = NULL,
    @NombreProveedor NVARCHAR(100) = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Categoria = ''
        SET @Categoria = NULL;

    IF @NombreProveedor = ''
        SET @NombreProveedor = NULL;


    ;WITH Ordenes AS (
        SELECT
            po.PurchaseOrderID,
            s.SupplierID,
            s.SupplierName AS Proveedor,
            sc.SupplierCategoryName AS Categoria,

            SUM(
                pol.OrderedOuters *
                pol.ExpectedUnitPricePerOuter
            ) AS MontoOrden

        FROM syn.PurchaseOrders po

        JOIN syn.Suppliers s
            ON s.SupplierID = po.SupplierID

        JOIN syn.SupplierCategories sc
            ON sc.SupplierCategoryID = s.SupplierCategoryID

        JOIN syn.PurchaseOrderLines pol
            ON pol.PurchaseOrderID = po.PurchaseOrderID

        WHERE
            (
                @Categoria IS NULL
                OR sc.SupplierCategoryName LIKE '%' + @Categoria + '%'
            )

            AND (
                @NombreProveedor IS NULL
                OR s.SupplierName LIKE '%' + @NombreProveedor + '%'
            )

        GROUP BY
            po.PurchaseOrderID,
            s.SupplierID,
            s.SupplierName,
            sc.SupplierCategoryName
    )

    SELECT
        CASE
            WHEN GROUPING(Categoria) = 1
                THEN 'TOTAL GENERAL'
            ELSE Categoria
        END AS Categoria,

        CASE
            WHEN GROUPING(Categoria) = 1
                THEN NULL

            WHEN GROUPING(Proveedor) = 1
                THEN 'TOTAL CATEGORIA'

            ELSE Proveedor
        END AS Proveedor,

        MIN(MontoOrden) AS MontoMinimo,
        MAX(MontoOrden) AS MontoMaximo,
        AVG(MontoOrden) AS MontoPromedio,
        COUNT(*) OVER() AS TotalRegistros

    FROM Ordenes

    GROUP BY ROLLUP (
        Categoria,
        Proveedor
    )

    ORDER BY
        GROUPING(Categoria),
        Categoria,
        GROUPING(Proveedor),
        Proveedor
    OFFSET (@Pagina - 1) * 10 ROWS
    FETCH NEXT 10 ROWS ONLY;
END;
GO

-- Años con facturas disponibles para los filtros de reportes.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_AniosFacturas
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT YEAR(InvoiceDate) AS Anio
    FROM syn.Invoices
    ORDER BY Anio;
END;
GO

-- REPORTE 2: montos por factura, cliente y categoría de cliente.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_VentasClientes
    @NombreCliente NVARCHAR(100) = NULL,
    @Categoria NVARCHAR(100) = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    SET @NombreCliente = NULLIF(LTRIM(RTRIM(@NombreCliente)), '');
    SET @Categoria = NULLIF(LTRIM(RTRIM(@Categoria)), '');

    ;WITH Facturas AS (
        SELECT
            i.InvoiceID,
            c.CustomerID AS ClienteID,
            c.CustomerName AS Cliente,
            cc.CustomerCategoryName AS Categoria,
            SUM(il.ExtendedPrice) AS MontoFactura
        FROM syn.Invoices i
        JOIN syn.Customers c ON c.CustomerID = i.CustomerID
        JOIN syn.CustomerCategories cc ON cc.CustomerCategoryID = c.CustomerCategoryID
        JOIN syn.InvoiceLines il ON il.InvoiceID = i.InvoiceID
        WHERE (@NombreCliente IS NULL OR c.CustomerName LIKE '%' + @NombreCliente + '%')
          AND (@Categoria IS NULL OR cc.CustomerCategoryName LIKE '%' + @Categoria + '%')
        GROUP BY i.InvoiceID, c.CustomerID, c.CustomerName, cc.CustomerCategoryName
    )
    SELECT
        CASE WHEN GROUPING(Categoria) = 1 THEN 'TOTAL GENERAL' ELSE Categoria END AS Categoria,
        CASE
            WHEN GROUPING(Categoria) = 1 THEN NULL
            WHEN GROUPING(ClienteID) = 1 THEN 'TOTAL CATEGORIA'
            ELSE Cliente
        END AS Cliente,
        MIN(MontoFactura) AS MontoMinimo,
        MAX(MontoFactura) AS MontoMaximo,
        AVG(MontoFactura) AS MontoPromedio,
        CASE
            WHEN GROUPING(Categoria) = 1 THEN 'general'
            WHEN GROUPING(ClienteID) = 1 THEN 'categoria'
            ELSE 'cliente'
        END AS TipoFila,
        COUNT(*) OVER() AS TotalRegistros
    FROM Facturas
    GROUP BY ROLLUP (Categoria, ClienteID, Cliente)
    -- Se descarta el nivel intermedio (categoría, ID) del ROLLUP.
    HAVING GROUPING(ClienteID) = GROUPING(Cliente)
    ORDER BY GROUPING(Categoria), Categoria,
             GROUPING(ClienteID), Cliente, ClienteID
    OFFSET (@Pagina - 1) * 10 ROWS
    FETCH NEXT 10 ROWS ONLY;
END;
GO

-- REPORTE 3: productos con mayor ganancia por año.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_TopProductosGanancia
    @Anio INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Anio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate) = @Anio
    )
        THROW 50020, 'El año indicado no tiene facturas registradas.', 1;

    ;WITH Ganancias AS (
        SELECT
            YEAR(i.InvoiceDate) AS Anio,
            si.StockItemID AS ProductoID,
            si.StockItemName AS Producto,
            SUM(il.LineProfit) AS GananciaTotal
        FROM syn.Invoices i
        JOIN syn.InvoiceLines il ON il.InvoiceID = i.InvoiceID
        JOIN syn.StockItems si ON si.StockItemID = il.StockItemID
        WHERE @Anio IS NULL OR YEAR(i.InvoiceDate) = @Anio
        GROUP BY YEAR(i.InvoiceDate), si.StockItemID, si.StockItemName
    ), Clasificados AS (
        SELECT *, DENSE_RANK() OVER (
            PARTITION BY Anio ORDER BY GananciaTotal DESC
        ) AS Posicion
        FROM Ganancias
    )
    SELECT Anio, Posicion, ProductoID, Producto, GananciaTotal,
           COUNT(*) OVER() AS TotalRegistros
    FROM Clasificados
    WHERE Posicion <= 5
    ORDER BY Anio DESC, Posicion, ProductoID
    OFFSET (@Pagina - 1) * 10 ROWS
    FETCH NEXT 10 ROWS ONLY;
END;
GO

-- REPORTE 4: clientes con más facturas por año y monto facturado.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_TopClientesFacturas
    @AnioInicio INT = NULL,
    @AnioFin INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @AnioInicio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate) = @AnioInicio
    )
        THROW 50021, 'El año inicial no tiene facturas registradas.', 1;

    IF @AnioFin IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM syn.Invoices WHERE YEAR(InvoiceDate) = @AnioFin
    )
        THROW 50022, 'El año final no tiene facturas registradas.', 1;

    IF @AnioInicio IS NOT NULL AND @AnioFin IS NOT NULL AND @AnioInicio > @AnioFin
        THROW 50023, 'El año inicial debe ser menor o igual que el año final.', 1;

    ;WITH MontosFactura AS (
        SELECT
            i.InvoiceID,
            YEAR(i.InvoiceDate) AS Anio,
            i.CustomerID AS ClienteID,
            SUM(COALESCE(il.ExtendedPrice, 0)) AS MontoFactura
        FROM syn.Invoices i
        LEFT JOIN syn.InvoiceLines il ON il.InvoiceID = i.InvoiceID
        WHERE (@AnioInicio IS NULL OR YEAR(i.InvoiceDate) >= @AnioInicio)
          AND (@AnioFin IS NULL OR YEAR(i.InvoiceDate) <= @AnioFin)
        GROUP BY i.InvoiceID, YEAR(i.InvoiceDate), i.CustomerID
    ), Totales AS (
        SELECT
            mf.Anio,
            c.CustomerID AS ClienteID,
            c.CustomerName AS Cliente,
            COUNT(*) AS CantidadFacturas,
            SUM(mf.MontoFactura) AS MontoTotalFacturado
        FROM MontosFactura mf
        JOIN syn.Customers c ON c.CustomerID = mf.ClienteID
        GROUP BY mf.Anio, c.CustomerID, c.CustomerName
    ), Clasificados AS (
        SELECT *, DENSE_RANK() OVER (
            PARTITION BY Anio ORDER BY CantidadFacturas DESC
        ) AS Posicion
        FROM Totales
    )
    SELECT Anio, Posicion, ClienteID, Cliente, CantidadFacturas, MontoTotalFacturado,
           COUNT(*) OVER() AS TotalRegistros
    FROM Clasificados
    WHERE Posicion <= 5
    ORDER BY Anio DESC, Posicion, MontoTotalFacturado DESC, ClienteID
    OFFSET (@Pagina - 1) * 10 ROWS
    FETCH NEXT 10 ROWS ONLY;
END;
GO


CREATE OR ALTER PROCEDURE dbo.usp_Reporte_AniosOrdenesCompra
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT YEAR(OrderDate) AS Anio
    FROM syn.PurchaseOrders
    ORDER BY Anio;
END;
GO

-- REPORTE 5: proveedores con más órdenes de compra por año.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_TopProveedoresOrdenes
    @AnioInicio INT = NULL,
    @AnioFin INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @AnioInicio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM syn.PurchaseOrders WHERE YEAR(OrderDate) = @AnioInicio
    )
        THROW 50024, 'El año inicial no tiene órdenes de compra registradas.', 1;

    IF @AnioFin IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM syn.PurchaseOrders WHERE YEAR(OrderDate) = @AnioFin
    )
        THROW 50025, 'El año final no tiene órdenes de compra registradas.', 1;

    IF @AnioInicio IS NOT NULL AND @AnioFin IS NOT NULL AND @AnioInicio > @AnioFin
        THROW 50026, 'El año inicial debe ser menor o igual que el año final.', 1;

    ;WITH MontosOrden AS (
        SELECT
            po.PurchaseOrderID,
            YEAR(po.OrderDate) AS Anio,
            po.SupplierID AS ProveedorID,
            SUM(COALESCE(pol.OrderedOuters * pol.ExpectedUnitPricePerOuter, 0)) AS MontoOrden
        FROM syn.PurchaseOrders po
        LEFT JOIN syn.PurchaseOrderLines pol ON pol.PurchaseOrderID = po.PurchaseOrderID
        WHERE (@AnioInicio IS NULL OR YEAR(po.OrderDate) >= @AnioInicio)
          AND (@AnioFin IS NULL OR YEAR(po.OrderDate) <= @AnioFin)
        GROUP BY po.PurchaseOrderID, YEAR(po.OrderDate), po.SupplierID
    ), Totales AS (
        SELECT
            mo.Anio,
            s.SupplierID AS ProveedorID,
            s.SupplierName AS Proveedor,
            COUNT(*) AS CantidadOrdenes,
            SUM(mo.MontoOrden) AS MontoTotal
        FROM MontosOrden mo
        JOIN syn.Suppliers s ON s.SupplierID = mo.ProveedorID
        GROUP BY mo.Anio, s.SupplierID, s.SupplierName
    ), Clasificados AS (
        SELECT *, DENSE_RANK() OVER (
            PARTITION BY Anio ORDER BY CantidadOrdenes DESC
        ) AS Posicion
        FROM Totales
    )
    SELECT Anio, Posicion, ProveedorID, Proveedor, CantidadOrdenes, MontoTotal,
           COUNT(*) OVER() AS TotalRegistros
    FROM Clasificados
    WHERE Posicion <= 5
    ORDER BY Anio DESC, Posicion, MontoTotal DESC, ProveedorID
    OFFSET (@Pagina - 1) * 10 ROWS
    FETCH NEXT 10 ROWS ONLY;
END;
GO
