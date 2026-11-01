-- 05_sp_inventario.sql
-- SP del modulo de inventario
USE WideWorldImporters;
GO

-- Opciones que SQL Server exige para tablas con columnas calculadas o indices filtrados
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Inventario_Listar
    @Nombre NVARCHAR(100) = NULL,
    @GrupoID INT = NULL,
    @CantidadMin INT = NULL,
    @CantidadMax INT = NULL,
    @Pagina INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    IF @Nombre = ''
        SET @Nombre = NULL;

    IF @Pagina < 1
        SET @Pagina = 1;

    -- el rango de cantidad debe tener sentido
    IF @CantidadMin IS NOT NULL AND @CantidadMax IS NOT NULL AND @CantidadMin > @CantidadMax
    BEGIN
        THROW 50011, 'La cantidad mínima no puede ser mayor que la cantidad máxima.', 1;
    END;

    DECLARE @TamanoPagina INT = 10;

    SELECT
        si.StockItemID AS ProductoID,
        si.StockItemName AS Nombre,
        STRING_AGG(sg.StockGroupName, ', ') WITHIN GROUP (ORDER BY sg.StockGroupName) AS Grupo,
        h.QuantityOnHand AS CantidadDisponible,
        COUNT(*) OVER() AS TotalRegistros
    FROM syn.StockItems si
    JOIN syn.StockItemHoldings h
        ON h.StockItemID = si.StockItemID
    LEFT JOIN syn.StockItemStockGroups sisg
        ON sisg.StockItemID = si.StockItemID
    LEFT JOIN syn.StockGroups sg
        ON sg.StockGroupID = sisg.StockGroupID
    WHERE
        (@Nombre IS NULL OR si.StockItemName LIKE '%' + @Nombre + '%')
        AND (@CantidadMin IS NULL OR h.QuantityOnHand >= @CantidadMin)
        AND (@CantidadMax IS NULL OR h.QuantityOnHand <= @CantidadMax)
        AND (
            @GrupoID IS NULL
            OR EXISTS (
                SELECT 1
                FROM syn.StockItemStockGroups x
                WHERE x.StockItemID = si.StockItemID
                  AND x.StockGroupID = @GrupoID
            )
        )
    GROUP BY
        si.StockItemID,
        si.StockItemName,
        h.QuantityOnHand
    ORDER BY si.StockItemName ASC
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Inventario_Detalle
    @ProductoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        si.StockItemID AS ProductoID,
        si.StockItemName AS Nombre,

        si.SupplierID AS ProveedorID,
        s.SupplierName AS Proveedor,

        STRING_AGG(sg.StockGroupName, ', ') WITHIN GROUP (ORDER BY sg.StockGroupName) AS Grupo,

        c.ColorName AS Color,

        up.PackageTypeName AS UnidadEmpaquetamiento,
        op.PackageTypeName AS Empaquetamiento,

        si.QuantityPerOuter AS CantidadEmpaquetamiento,

        si.Brand AS Marca,
        si.Size AS Tamano,

        si.TaxRate AS Impuesto,
        si.UnitPrice AS PrecioUnitario,
        si.RecommendedRetailPrice AS PrecioVenta,

        si.TypicalWeightPerUnit AS Peso,
        si.SearchDetails AS PalabrasClave,

        h.QuantityOnHand AS CantidadDisponible,
        h.BinLocation AS Ubicacion,

        -- datos para llenar el formulario de edicion
        si.ColorID,
        si.UnitPackageID AS UnidadEmpaqueID,
        si.OuterPackageID AS EmpaqueExteriorID,
        STRING_AGG(CAST(sg.StockGroupID AS VARCHAR(10)), ',') AS GruposIDs,
        si.LeadTimeDays AS DiasEntrega,
        si.IsChillerStock AS EsRefrigerado,
        si.Barcode AS CodigoBarras,
        si.MarketingComments AS ComentariosMarketing

    FROM syn.StockItems si
    JOIN syn.Suppliers s
        ON s.SupplierID = si.SupplierID
    LEFT JOIN syn.Colors c
        ON c.ColorID = si.ColorID
    JOIN syn.PackageTypes up
        ON up.PackageTypeID = si.UnitPackageID
    JOIN syn.PackageTypes op
        ON op.PackageTypeID = si.OuterPackageID
    JOIN syn.StockItemHoldings h
        ON h.StockItemID = si.StockItemID
    LEFT JOIN syn.StockItemStockGroups sisg
        ON sisg.StockItemID = si.StockItemID
    LEFT JOIN syn.StockGroups sg
        ON sg.StockGroupID = sisg.StockGroupID
    WHERE si.StockItemID = @ProductoID
    GROUP BY
        si.StockItemID,
        si.StockItemName,
        si.SupplierID,
        s.SupplierName,
        c.ColorName,
        up.PackageTypeName,
        op.PackageTypeName,
        si.QuantityPerOuter,
        si.Brand,
        si.Size,
        si.TaxRate,
        si.UnitPrice,
        si.RecommendedRetailPrice,
        si.TypicalWeightPerUnit,
        si.SearchDetails,
        h.QuantityOnHand,
        h.BinLocation,
        si.ColorID,
        si.UnitPackageID,
        si.OuterPackageID,
        si.LeadTimeDays,
        si.IsChillerStock,
        si.Barcode,
        si.MarketingComments;
END;
GO

-- @Grupos es la lista de grupos del producto separada por comas, por ejemplo '2,4,6'
CREATE OR ALTER PROCEDURE dbo.usp_Inventario_Insertar
    @Nombre NVARCHAR(100),
    @ProveedorID INT,
    @Grupos NVARCHAR(200),
    @ColorID INT = NULL,
    @UnidadEmpaqueID INT,
    @EmpaqueExteriorID INT,
    @CantidadEmpaquetamiento INT,
    @Marca NVARCHAR(50) = NULL,
    @Tamano NVARCHAR(20) = NULL,
    @Impuesto DECIMAL(18,3),
    @PrecioUnitario DECIMAL(18,2),
    @PrecioVenta DECIMAL(18,2) = NULL,
    @Peso DECIMAL(18,3),
    @CantidadDisponible INT,
    @Ubicacion NVARCHAR(20),
    @DiasEntrega INT,
    @EsRefrigerado BIT,
    @CodigoBarras NVARCHAR(50) = NULL,
    @ComentariosMarketing NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @NuevoProducto TABLE (
        ProductoID INT
    );
    DECLARE @ProductoID INT;

    -- los grupos separados en filas
    DECLARE @ListaGrupos TABLE (
        GrupoID INT
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO @ListaGrupos (GrupoID)
        SELECT DISTINCT TRY_CAST(value AS INT)
        FROM STRING_SPLIT(@Grupos, ',');

        -- debe venir al menos un grupo y todos deben existir
        IF NOT EXISTS (SELECT 1 FROM @ListaGrupos)
           OR EXISTS (
               SELECT 1
               FROM @ListaGrupos l
               LEFT JOIN syn.StockGroups sg ON sg.StockGroupID = l.GrupoID
               WHERE sg.StockGroupID IS NULL
           )
        BEGIN
            THROW 50004, 'Debe elegir al menos un grupo válido.', 1;
        END;

        INSERT INTO syn.StockItems (
            StockItemName,
            SupplierID,
            ColorID,
            UnitPackageID,
            OuterPackageID,
            Brand,
            Size,
            LeadTimeDays,
            QuantityPerOuter,
            IsChillerStock,
            Barcode,
            TaxRate,
            UnitPrice,
            RecommendedRetailPrice,
            TypicalWeightPerUnit,
            MarketingComments,
            LastEditedBy
        )
        OUTPUT INSERTED.StockItemID INTO @NuevoProducto
        VALUES (
            @Nombre,
            @ProveedorID,
            @ColorID,
            @UnidadEmpaqueID,
            @EmpaqueExteriorID,
            @Marca,
            @Tamano,
            @DiasEntrega,
            @CantidadEmpaquetamiento,
            @EsRefrigerado,
            @CodigoBarras,
            @Impuesto,
            @PrecioUnitario,
            @PrecioVenta,
            @Peso,
            @ComentariosMarketing,
            1
        );

        SELECT @ProductoID = ProductoID
        FROM @NuevoProducto;

        INSERT INTO syn.StockItemHoldings (
            StockItemID,
            QuantityOnHand,
            BinLocation,
            LastStocktakeQuantity,
            LastCostPrice,
            ReorderLevel,
            TargetStockLevel,
            LastEditedBy
        )
        VALUES (
            @ProductoID,
            @CantidadDisponible,
            @Ubicacion,
            @CantidadDisponible,
            @PrecioUnitario,
            0,
            @CantidadDisponible,
            1
        );

        INSERT INTO syn.StockItemStockGroups (
            StockItemID,
            StockGroupID,
            LastEditedBy
        )
        SELECT @ProductoID, GrupoID, 1
        FROM @ListaGrupos;

        COMMIT TRANSACTION;

        SELECT ProductoID
        FROM @NuevoProducto;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del producto ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            THROW 50003, 'Ya existe un producto con ese nombre.', 1;
        END;

        THROW;
    END CATCH;
END;
GO

-- @Grupos es la lista completa de grupos del producto separada por comas, por ejemplo '2,4,6'.
-- Se reemplazan todos los grupos anteriores por los de la lista.
CREATE OR ALTER PROCEDURE dbo.usp_Inventario_Actualizar
    @ProductoID INT,
    @Nombre NVARCHAR(100),
    @ProveedorID INT,
    @Grupos NVARCHAR(200),
    @ColorID INT = NULL,
    @UnidadEmpaqueID INT,
    @EmpaqueExteriorID INT,
    @CantidadEmpaquetamiento INT,
    @Marca NVARCHAR(50) = NULL,
    @Tamano NVARCHAR(20) = NULL,
    @Impuesto DECIMAL(18,3),
    @PrecioUnitario DECIMAL(18,2),
    @PrecioVenta DECIMAL(18,2) = NULL,
    @Peso DECIMAL(18,3),
    @CantidadDisponible INT,
    @Ubicacion NVARCHAR(20),
    @DiasEntrega INT,
    @EsRefrigerado BIT,
    @CodigoBarras NVARCHAR(50) = NULL,
    @ComentariosMarketing NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ListaGrupos TABLE (
        GrupoID INT
    );

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM syn.StockItems
            WHERE StockItemID = @ProductoID
        )
        BEGIN
            THROW 50001, 'El producto indicado no existe.', 1;
        END;

        INSERT INTO @ListaGrupos (GrupoID)
        SELECT DISTINCT TRY_CAST(value AS INT)
        FROM STRING_SPLIT(@Grupos, ',');

        -- debe venir al menos un grupo y todos deben existir
        IF NOT EXISTS (SELECT 1 FROM @ListaGrupos)
           OR EXISTS (
               SELECT 1
               FROM @ListaGrupos l
               LEFT JOIN syn.StockGroups sg ON sg.StockGroupID = l.GrupoID
               WHERE sg.StockGroupID IS NULL
           )
        BEGIN
            THROW 50004, 'Debe elegir al menos un grupo válido.', 1;
        END;

        UPDATE syn.StockItems
        SET
            StockItemName = @Nombre,
            SupplierID = @ProveedorID,
            ColorID = @ColorID,
            UnitPackageID = @UnidadEmpaqueID,
            OuterPackageID = @EmpaqueExteriorID,
            Brand = @Marca,
            Size = @Tamano,
            LeadTimeDays = @DiasEntrega,
            QuantityPerOuter = @CantidadEmpaquetamiento,
            IsChillerStock = @EsRefrigerado,
            Barcode = @CodigoBarras,
            TaxRate = @Impuesto,
            UnitPrice = @PrecioUnitario,
            RecommendedRetailPrice = @PrecioVenta,
            TypicalWeightPerUnit = @Peso,
            MarketingComments = @ComentariosMarketing,
            LastEditedBy = 1
        WHERE StockItemID = @ProductoID;

        UPDATE syn.StockItemHoldings
        SET
            QuantityOnHand = @CantidadDisponible,
            BinLocation = @Ubicacion,
            LastEditedBy = 1
        WHERE StockItemID = @ProductoID;

        -- se reemplazan los grupos por la lista completa que llego
        DELETE FROM syn.StockItemStockGroups
        WHERE StockItemID = @ProductoID;

        INSERT INTO syn.StockItemStockGroups (
            StockItemID,
            StockGroupID,
            LastEditedBy
        )
        SELECT @ProductoID, GrupoID, 1
        FROM @ListaGrupos;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del producto ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
        BEGIN
            THROW 50003, 'Ya existe un producto con ese nombre.', 1;
        END;

        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_Inventario_Eliminar
    @ProductoID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (
            SELECT 1
            FROM syn.StockItems
            WHERE StockItemID = @ProductoID
        )
        BEGIN
            THROW 50001, 'El producto indicado no existe.', 1;
        END;

        DELETE FROM syn.StockItemStockGroups
        WHERE StockItemID = @ProductoID;

        DELETE FROM syn.StockItemHoldings
        WHERE StockItemID = @ProductoID;

        DELETE FROM syn.StockItems
        WHERE StockItemID = @ProductoID;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
        BEGIN
            THROW 50002, 'No se puede eliminar el producto porque tiene registros asociados.', 1;
        END;

        THROW;
    END CATCH;
END;
GO
