-- 06_sp_ventas.sql
-- SP del modulo de ventas
USE WideWorldImporters;
GO

-- Opciones que SQL Server exige para tablas con columnas calculadas o indices filtrados
-- (Invoices tiene una columna calculada; sin esto insertar o eliminar facturas falla)
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Listar
    @FechaInicio DATE = NULL,
    @FechaFin DATE = NULL,
    @NombreCliente NVARCHAR(100) = NULL,
    @MontoMin DECIMAL(18,2) = NULL,
    @MontoMax DECIMAL(18,2) = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @NombreCliente = ''
        SET @NombreCliente = NULL;

    IF @Pagina < 1
        SET @Pagina = 1;

    -- los rangos deben tener sentido
    IF @FechaInicio IS NOT NULL AND @FechaFin IS NOT NULL AND @FechaInicio > @FechaFin
    BEGIN
        THROW 50011, 'La fecha inicial no puede ser mayor que la fecha final.', 1;
    END;

    IF @MontoMin IS NOT NULL AND @MontoMax IS NOT NULL AND @MontoMin > @MontoMax
    BEGIN
        THROW 50012, 'El monto mínimo no puede ser mayor que el monto máximo.', 1;
    END;

    DECLARE @TamanoPagina INT = 10;

    SELECT
        i.InvoiceID AS FacturaID,
        i.InvoiceDate AS Fecha,
        c.CustomerID AS ClienteID,
        c.CustomerName AS Cliente,
        dm.DeliveryMethodName AS MetodoEntrega,
        SUM(il.ExtendedPrice) AS Monto,
        COUNT(*) OVER() AS TotalRegistros

    FROM syn.Invoices i

    JOIN syn.Customers c
        ON c.CustomerID = i.CustomerID

    JOIN syn.DeliveryMethods dm
        ON dm.DeliveryMethodID = i.DeliveryMethodID

    JOIN syn.InvoiceLines il
        ON il.InvoiceID = i.InvoiceID

    WHERE
        (@FechaInicio IS NULL OR i.InvoiceDate >= @FechaInicio)
        AND (@FechaFin IS NULL OR i.InvoiceDate <= @FechaFin)
        AND (
            @NombreCliente IS NULL
            OR c.CustomerName LIKE '%' + @NombreCliente + '%'
        )

    GROUP BY
        i.InvoiceID,
        i.InvoiceDate,
        c.CustomerID,
        c.CustomerName,
        dm.DeliveryMethodName

    HAVING
        (@MontoMin IS NULL OR SUM(il.ExtendedPrice) >= @MontoMin)
        AND (@MontoMax IS NULL OR SUM(il.ExtendedPrice) <= @MontoMax)

    ORDER BY
        c.CustomerName ASC,
        i.InvoiceID ASC

    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Detalle
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        i.InvoiceID AS FacturaID,

        i.CustomerID AS ClienteID,
        c.CustomerName AS Cliente,

        dm.DeliveryMethodName AS MetodoEntrega,
        i.DeliveryMethodID AS MetodoEntregaID, -- para llenar el formulario de edicion

        i.CustomerPurchaseOrderNumber AS NumeroOrdenCliente,

        cp.PersonID AS ContactoID,
        cp.FullName AS Contacto,

        sp.PersonID AS VendedorID,
        sp.FullName AS Vendedor,

        i.InvoiceDate AS Fecha,

        i.DeliveryInstructions AS InstruccionesEntrega,

        (
            SELECT SUM(il.ExtendedPrice)
            FROM syn.InvoiceLines il
            WHERE il.InvoiceID = i.InvoiceID
        ) AS MontoTotal

    FROM syn.Invoices i

    JOIN syn.Customers c
        ON c.CustomerID = i.CustomerID

    JOIN syn.DeliveryMethods dm
        ON dm.DeliveryMethodID = i.DeliveryMethodID

    JOIN syn.People cp
        ON cp.PersonID = i.ContactPersonID

    JOIN syn.People sp
        ON sp.PersonID = i.SalespersonPersonID

    WHERE i.InvoiceID = @FacturaID;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_DetalleLineas
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        il.InvoiceLineID AS LineaID,

        il.StockItemID AS ProductoID,
        si.StockItemName AS Producto,

        il.Quantity AS Cantidad,
        il.UnitPrice AS PrecioUnitario,
        il.TaxRate AS Impuesto,
        il.TaxAmount AS MontoImpuesto,
        il.ExtendedPrice AS TotalLinea

    FROM syn.InvoiceLines il

    JOIN syn.StockItems si
        ON si.StockItemID = il.StockItemID

    WHERE il.InvoiceID = @FacturaID

    ORDER BY il.InvoiceLineID ASC;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Insertar
    @ClienteID INT,
    @MetodoEntregaID INT,
    @ContactoID INT,
    @VendedorID INT,

    @Fecha DATE,

    @NumeroOrdenCliente NVARCHAR(20) = NULL,
    @InstruccionesEntrega NVARCHAR(MAX) = NULL,

    @Detalles NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NuevaFactura TABLE (
        FacturaID INT
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar cliente
        IF NOT EXISTS (
            SELECT 1
            FROM syn.Customers
            WHERE CustomerID = @ClienteID
        )
        BEGIN
            THROW 50001, 'El cliente indicado no existe.', 1;
        END;

        -- Validar método de entrega
        IF NOT EXISTS (
            SELECT 1
            FROM syn.DeliveryMethods
            WHERE DeliveryMethodID = @MetodoEntregaID
        )
        BEGIN
            THROW 50002, 'El método de entrega indicado no existe.', 1;
        END;

        -- Validar contacto: debe ser el contacto primario o alternativo del cliente
        IF NOT EXISTS (
            SELECT 1
            FROM syn.Customers
            WHERE CustomerID = @ClienteID
              AND @ContactoID IN (PrimaryContactPersonID, AlternateContactPersonID)
        )
        BEGIN
            THROW 50003, 'La persona de contacto debe ser el contacto primario o alternativo del cliente.', 1;
        END;

        -- Validar vendedor
        IF NOT EXISTS (
            SELECT 1
            FROM syn.People
            WHERE PersonID = @VendedorID
              AND IsSalesperson = 1
        )
        BEGIN
            THROW 50004, 'El vendedor indicado no existe.', 1;
        END;

        -- Validar fecha
        IF @Fecha IS NULL
        BEGIN
            THROW 50005, 'La fecha de la factura es obligatoria.', 1;
        END;

        -- Validar JSON
        IF ISJSON(@Detalles) = 0
        BEGIN
            THROW 50006, 'El detalle de la venta no tiene un formato válido.', 1;
        END;

        DECLARE @Detalle TABLE (
            ProductoID INT,
            Cantidad INT,
            PrecioUnitario DECIMAL(18,2)
        );

        INSERT INTO @Detalle (
            ProductoID,
            Cantidad,
            PrecioUnitario
        )
        SELECT
            ProductoID,
            Cantidad,
            PrecioUnitario
        FROM OPENJSON(@Detalles)
        WITH (
            ProductoID INT '$.ProductoID',
            Cantidad INT '$.Cantidad',
            PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario'
        );

        -- Debe existir al menos una línea
        IF NOT EXISTS (
            SELECT 1
            FROM @Detalle
        )
        BEGIN
            THROW 50007, 'La factura debe contener al menos un producto.', 1;
        END;

        -- Validar cantidad y precio
        IF EXISTS (
            SELECT 1
            FROM @Detalle
            WHERE ProductoID IS NULL
               OR Cantidad IS NULL
               OR PrecioUnitario IS NULL
               OR Cantidad <= 0
               OR PrecioUnitario < 0
        )
        BEGIN
            THROW 50008, 'La cantidad o el precio de uno de los productos no es válido.', 1;
        END;

        -- Validar productos
        IF EXISTS (
            SELECT 1
            FROM @Detalle d

            LEFT JOIN syn.StockItems si
                ON si.StockItemID = d.ProductoID

            WHERE si.StockItemID IS NULL
        )
        BEGIN
            THROW 50009, 'Uno de los productos indicados no existe.', 1;
        END;

        DECLARE @ClienteFacturarID INT;

        SELECT
            @ClienteFacturarID = BillToCustomerID
        FROM syn.Customers
        WHERE CustomerID = @ClienteID;


        -- Insertar encabezado
        INSERT INTO syn.Invoices (
            CustomerID,
            BillToCustomerID,
            DeliveryMethodID,
            ContactPersonID,
            AccountsPersonID,
            SalespersonPersonID,
            PackedByPersonID,
            InvoiceDate,
            CustomerPurchaseOrderNumber,
            IsCreditNote,
            DeliveryInstructions,
            TotalDryItems,
            TotalChillerItems,
            LastEditedBy
        )

        OUTPUT INSERTED.InvoiceID
        INTO @NuevaFactura

        VALUES (
            @ClienteID,
            @ClienteFacturarID,
            @MetodoEntregaID,
            @ContactoID,
            @ContactoID,
            @VendedorID,
            @VendedorID,
            @Fecha,
            @NumeroOrdenCliente,
            0,
            @InstruccionesEntrega,
            0,
            0,
            1
        );


        DECLARE @FacturaID INT;

        SELECT
            @FacturaID = FacturaID
        FROM @NuevaFactura;


        -- Insertar líneas de factura
        INSERT INTO syn.InvoiceLines (
            InvoiceID,
            StockItemID,
            Description,
            PackageTypeID,
            Quantity,
            UnitPrice,
            TaxRate,
            TaxAmount,
            LineProfit,
            ExtendedPrice,
            LastEditedBy
        )

        SELECT
            @FacturaID,

            d.ProductoID,

            si.StockItemName,

            si.UnitPackageID,

            d.Cantidad,

            d.PrecioUnitario,

            si.TaxRate,

            ROUND(
                d.Cantidad
                * d.PrecioUnitario
                * si.TaxRate / 100,
                2
            ),

            ROUND(
                d.Cantidad
                * (d.PrecioUnitario - h.LastCostPrice),
                2
            ),

            ROUND(
                (d.Cantidad * d.PrecioUnitario)
                +
                (
                    d.Cantidad
                    * d.PrecioUnitario
                    * si.TaxRate / 100
                ),
                2
            ),

            1

        FROM @Detalle d

        JOIN syn.StockItems si
            ON si.StockItemID = d.ProductoID

        JOIN syn.StockItemHoldings h
            ON h.StockItemID = d.ProductoID;


        -- Calcular productos secos y refrigerados
        UPDATE syn.Invoices
        SET
            TotalDryItems = (
                SELECT COALESCE(SUM(d.Cantidad), 0)

                FROM @Detalle d

                JOIN syn.StockItems si
                    ON si.StockItemID = d.ProductoID

                WHERE si.IsChillerStock = 0
            ),

            TotalChillerItems = (
                SELECT COALESCE(SUM(d.Cantidad), 0)

                FROM @Detalle d

                JOIN syn.StockItems si
                    ON si.StockItemID = d.ProductoID

                WHERE si.IsChillerStock = 1
            )

        WHERE InvoiceID = @FacturaID;


        COMMIT TRANSACTION;

        SELECT FacturaID
        FROM @NuevaFactura;

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Actualizar
    @FacturaID INT,

    @ClienteID INT,
    @MetodoEntregaID INT,
    @ContactoID INT,
    @VendedorID INT,

    @Fecha DATE,

    @NumeroOrdenCliente NVARCHAR(20) = NULL,
    @InstruccionesEntrega NVARCHAR(MAX) = NULL,

    @Detalles NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Validar factura
        IF NOT EXISTS (
            SELECT 1
            FROM syn.Invoices
            WHERE InvoiceID = @FacturaID
        )
        BEGIN
            THROW 50001, 'La factura indicada no existe.', 1;
        END;

        -- Validar cliente
        IF NOT EXISTS (
            SELECT 1
            FROM syn.Customers
            WHERE CustomerID = @ClienteID
        )
        BEGIN
            THROW 50002, 'El cliente indicado no existe.', 1;
        END;

        -- Validar método de entrega
        IF NOT EXISTS (
            SELECT 1
            FROM syn.DeliveryMethods
            WHERE DeliveryMethodID = @MetodoEntregaID
        )
        BEGIN
            THROW 50003, 'El método de entrega indicado no existe.', 1;
        END;

        -- Validar contacto: debe ser el contacto primario o alternativo del cliente
        IF NOT EXISTS (
            SELECT 1
            FROM syn.Customers
            WHERE CustomerID = @ClienteID
              AND @ContactoID IN (PrimaryContactPersonID, AlternateContactPersonID)
        )
        BEGIN
            THROW 50004, 'La persona de contacto debe ser el contacto primario o alternativo del cliente.', 1;
        END;

        -- Validar vendedor
        IF NOT EXISTS (
            SELECT 1
            FROM syn.People
            WHERE PersonID = @VendedorID
              AND IsSalesperson = 1
        )
        BEGIN
            THROW 50005, 'El vendedor indicado no existe.', 1;
        END;

        IF @Fecha IS NULL
        BEGIN
            THROW 50006, 'La fecha de la factura es obligatoria.', 1;
        END;

        -- Validar JSON
        IF ISJSON(@Detalles) = 0
        BEGIN
            THROW 50007, 'El detalle de la venta no tiene un formato válido.', 1;
        END;


        DECLARE @Detalle TABLE (
            ProductoID INT,
            Cantidad INT,
            PrecioUnitario DECIMAL(18,2)
        );

        INSERT INTO @Detalle (
            ProductoID,
            Cantidad,
            PrecioUnitario
        )
        SELECT
            ProductoID,
            Cantidad,
            PrecioUnitario
        FROM OPENJSON(@Detalles)
        WITH (
            ProductoID INT '$.ProductoID',
            Cantidad INT '$.Cantidad',
            PrecioUnitario DECIMAL(18,2) '$.PrecioUnitario'
        );


        IF NOT EXISTS (
            SELECT 1
            FROM @Detalle
        )
        BEGIN
            THROW 50008, 'La factura debe contener al menos un producto.', 1;
        END;


        IF EXISTS (
            SELECT 1
            FROM @Detalle
            WHERE ProductoID IS NULL
               OR Cantidad IS NULL
               OR PrecioUnitario IS NULL
               OR Cantidad <= 0
               OR PrecioUnitario < 0
        )
        BEGIN
            THROW 50009, 'La cantidad o el precio de uno de los productos no es válido.', 1;
        END;


        IF EXISTS (
            SELECT 1
            FROM @Detalle d

            LEFT JOIN syn.StockItems si
                ON si.StockItemID = d.ProductoID

            WHERE si.StockItemID IS NULL
        )
        BEGIN
            THROW 50010, 'Uno de los productos indicados no existe.', 1;
        END;


        DECLARE @ClienteFacturarID INT;

        SELECT
            @ClienteFacturarID = BillToCustomerID
        FROM syn.Customers
        WHERE CustomerID = @ClienteID;


        -- Actualizar encabezado
        UPDATE syn.Invoices
        SET
            CustomerID = @ClienteID,
            BillToCustomerID = @ClienteFacturarID,
            DeliveryMethodID = @MetodoEntregaID,
            ContactPersonID = @ContactoID,
            AccountsPersonID = @ContactoID,
            SalespersonPersonID = @VendedorID,
            PackedByPersonID = @VendedorID,
            InvoiceDate = @Fecha,
            CustomerPurchaseOrderNumber = @NumeroOrdenCliente,
            DeliveryInstructions = @InstruccionesEntrega,
            LastEditedBy = 1

        WHERE InvoiceID = @FacturaID;


        -- Reemplazar las líneas anteriores
        DELETE FROM syn.InvoiceLines
        WHERE InvoiceID = @FacturaID;


        INSERT INTO syn.InvoiceLines (
            InvoiceID,
            StockItemID,
            Description,
            PackageTypeID,
            Quantity,
            UnitPrice,
            TaxRate,
            TaxAmount,
            LineProfit,
            ExtendedPrice,
            LastEditedBy
        )

        SELECT
            @FacturaID,

            d.ProductoID,

            si.StockItemName,

            si.UnitPackageID,

            d.Cantidad,

            d.PrecioUnitario,

            si.TaxRate,

            ROUND(
                d.Cantidad
                * d.PrecioUnitario
                * si.TaxRate / 100,
                2
            ),

            ROUND(
                d.Cantidad
                * (d.PrecioUnitario - h.LastCostPrice),
                2
            ),

            ROUND(
                (d.Cantidad * d.PrecioUnitario)
                +
                (
                    d.Cantidad
                    * d.PrecioUnitario
                    * si.TaxRate / 100
                ),
                2
            ),

            1

        FROM @Detalle d

        JOIN syn.StockItems si
            ON si.StockItemID = d.ProductoID

        JOIN syn.StockItemHoldings h
            ON h.StockItemID = d.ProductoID;


        UPDATE syn.Invoices
        SET
            TotalDryItems = (
                SELECT COALESCE(SUM(d.Cantidad), 0)

                FROM @Detalle d

                JOIN syn.StockItems si
                    ON si.StockItemID = d.ProductoID

                WHERE si.IsChillerStock = 0
            ),

            TotalChillerItems = (
                SELECT COALESCE(SUM(d.Cantidad), 0)

                FROM @Detalle d

                JOIN syn.StockItems si
                    ON si.StockItemID = d.ProductoID

                WHERE si.IsChillerStock = 1
            )

        WHERE InvoiceID = @FacturaID;


        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Ventas_Eliminar
    @FacturaID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM syn.Invoices
            WHERE InvoiceID = @FacturaID
        )
        BEGIN
            THROW 50001, 'La factura indicada no existe.', 1;
        END;


        DELETE FROM syn.InvoiceLines
        WHERE InvoiceID = @FacturaID;


        DELETE FROM syn.Invoices
        WHERE InvoiceID = @FacturaID;


        COMMIT TRANSACTION;

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
        BEGIN
            THROW 50002,
                'No se puede eliminar la factura porque tiene registros asociados.',
                1;
        END;

        THROW;
    END CATCH;
END;
GO