-- Ejecutar en Corporativo: reportes del Proyecto 1 sobre las vistas materializadas.
-- @SucursalID: NULL = consolidado, 1 = San José, 2 = Limón.
-- WITH (NOEXPAND): lee los datos guardados de la vista en lugar de recalcularlos desde las tablas.
IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51031, 'Los SP de estadísticas se crean en Corporativo.', 1;
GO

-- Las vistas indexadas exigen estas opciones; cada SP las guarda al crearse
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

-- REPORTE 1: Montos mínimos, máximos y promedio de compras por proveedor y categoría usando ROLLUP
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_ComprasProveedores
    @SucursalID INT = NULL,
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
            s.SupplierName AS Proveedor,
            sc.SupplierCategoryName AS Categoria,
            o.Monto AS MontoOrden
        FROM dbo.vm_MontoOrden o WITH (NOEXPAND)
        JOIN syn.Suppliers s
            ON s.SupplierID = o.SupplierID
        JOIN syn.SupplierCategories sc
            ON sc.SupplierCategoryID = s.SupplierCategoryID
        WHERE
            (@SucursalID IS NULL OR o.SucursalID = @SucursalID)
            AND (@Categoria IS NULL OR sc.SupplierCategoryName LIKE '%' + @Categoria + '%')
            AND (@NombreProveedor IS NULL OR s.SupplierName LIKE '%' + @NombreProveedor + '%')
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
    @SucursalID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Anio
    FROM dbo.vm_MontoFactura WITH (NOEXPAND)
    WHERE @SucursalID IS NULL OR SucursalID = @SucursalID
    ORDER BY Anio;
END;
GO

-- REPORTE 2: montos por factura, cliente y categoría de cliente.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_VentasClientes
    @SucursalID INT = NULL,
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
            c.CustomerID AS ClienteID,
            c.CustomerName AS Cliente,
            cc.CustomerCategoryName AS Categoria,
            f.Monto AS MontoFactura
        FROM dbo.vm_MontoFactura f WITH (NOEXPAND)
        JOIN syn.Customers c ON c.CustomerID = f.CustomerID
        JOIN syn.CustomerCategories cc ON cc.CustomerCategoryID = c.CustomerCategoryID
        WHERE (@SucursalID IS NULL OR f.SucursalID = @SucursalID)
          AND (@NombreCliente IS NULL OR c.CustomerName LIKE '%' + @NombreCliente + '%')
          AND (@Categoria IS NULL OR cc.CustomerCategoryName LIKE '%' + @Categoria + '%')
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
    @SucursalID INT = NULL,
    @Anio INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Anio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM dbo.vm_GananciaProducto WITH (NOEXPAND)
        WHERE Anio = @Anio AND (@SucursalID IS NULL OR SucursalID = @SucursalID)
    )
        THROW 50020, 'El año indicado no tiene facturas registradas.', 1;

    -- En el consolidado se suman las ganancias de las dos sucursales
    ;WITH Ganancias AS (
        SELECT
            g.Anio,
            p.StockItemID AS ProductoID,
            p.StockItemName AS Producto,
            SUM(g.Ganancia) AS GananciaTotal
        FROM dbo.vm_GananciaProducto g WITH (NOEXPAND)
        JOIN syn.Productos p ON p.StockItemID = g.StockItemID
        WHERE (@SucursalID IS NULL OR g.SucursalID = @SucursalID)
          AND (@Anio IS NULL OR g.Anio = @Anio)
        GROUP BY g.Anio, p.StockItemID, p.StockItemName
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
    @SucursalID INT = NULL,
    @AnioInicio INT = NULL,
    @AnioFin INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @AnioInicio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM dbo.vm_MontoFactura WITH (NOEXPAND)
        WHERE Anio = @AnioInicio AND (@SucursalID IS NULL OR SucursalID = @SucursalID)
    )
        THROW 50021, 'El año inicial no tiene facturas registradas.', 1;

    IF @AnioFin IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM dbo.vm_MontoFactura WITH (NOEXPAND)
        WHERE Anio = @AnioFin AND (@SucursalID IS NULL OR SucursalID = @SucursalID)
    )
        THROW 50022, 'El año final no tiene facturas registradas.', 1;

    IF @AnioInicio IS NOT NULL AND @AnioFin IS NOT NULL AND @AnioInicio > @AnioFin
        THROW 50023, 'El año inicial debe ser menor o igual que el año final.', 1;

    -- Cada fila de la vista es una factura con su monto
    ;WITH Totales AS (
        SELECT
            f.Anio,
            c.CustomerID AS ClienteID,
            c.CustomerName AS Cliente,
            COUNT(*) AS CantidadFacturas,
            SUM(f.Monto) AS MontoTotalFacturado
        FROM dbo.vm_MontoFactura f WITH (NOEXPAND)
        JOIN syn.Customers c ON c.CustomerID = f.CustomerID
        WHERE (@SucursalID IS NULL OR f.SucursalID = @SucursalID)
          AND (@AnioInicio IS NULL OR f.Anio >= @AnioInicio)
          AND (@AnioFin IS NULL OR f.Anio <= @AnioFin)
        GROUP BY f.Anio, c.CustomerID, c.CustomerName
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

-- Años con órdenes de compra disponibles para los filtros de reportes.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_AniosOrdenesCompra
    @SucursalID INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Anio
    FROM dbo.vm_MontoOrden WITH (NOEXPAND)
    WHERE @SucursalID IS NULL OR SucursalID = @SucursalID
    ORDER BY Anio;
END;
GO

-- REPORTE 5: proveedores con más órdenes de compra por año.
CREATE OR ALTER PROCEDURE dbo.usp_Reporte_TopProveedoresOrdenes
    @SucursalID INT = NULL,
    @AnioInicio INT = NULL,
    @AnioFin INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @AnioInicio IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM dbo.vm_MontoOrden WITH (NOEXPAND)
        WHERE Anio = @AnioInicio AND (@SucursalID IS NULL OR SucursalID = @SucursalID)
    )
        THROW 50024, 'El año inicial no tiene órdenes de compra registradas.', 1;

    IF @AnioFin IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM dbo.vm_MontoOrden WITH (NOEXPAND)
        WHERE Anio = @AnioFin AND (@SucursalID IS NULL OR SucursalID = @SucursalID)
    )
        THROW 50025, 'El año final no tiene órdenes de compra registradas.', 1;

    IF @AnioInicio IS NOT NULL AND @AnioFin IS NOT NULL AND @AnioInicio > @AnioFin
        THROW 50026, 'El año inicial debe ser menor o igual que el año final.', 1;

    -- Cada fila de la vista es una orden con su monto
    ;WITH Totales AS (
        SELECT
            o.Anio,
            s.SupplierID AS ProveedorID,
            s.SupplierName AS Proveedor,
            COUNT(*) AS CantidadOrdenes,
            SUM(o.Monto) AS MontoTotal
        FROM dbo.vm_MontoOrden o WITH (NOEXPAND)
        JOIN syn.Suppliers s ON s.SupplierID = o.SupplierID
        WHERE (@SucursalID IS NULL OR o.SucursalID = @SucursalID)
          AND (@AnioInicio IS NULL OR o.Anio >= @AnioInicio)
          AND (@AnioFin IS NULL OR o.Anio <= @AnioFin)
        GROUP BY o.Anio, s.SupplierID, s.SupplierName
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
