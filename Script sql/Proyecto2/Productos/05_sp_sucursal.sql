-- Ejecutar en San José y Limón: lectura del catálogo replicado y escritura del inventario propio.
IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51013, 'Los SP de productos de sucursal se crean en San José o Limón.', 1;
GO

-- Lista de productos con la cantidad de esta sucursal; los filtros son opcionales
CREATE OR ALTER PROCEDURE dbo.usp_Productos_Listar
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

    IF @CantidadMin IS NOT NULL AND @CantidadMax IS NOT NULL AND @CantidadMin > @CantidadMax
        THROW 50011, 'La cantidad mínima no puede ser mayor que la cantidad máxima.', 1;

    DECLARE @TamanoPagina INT = 10;

    SELECT
        p.StockItemID AS ProductoID,
        p.StockItemName AS Nombre,
        STRING_AGG(g.StockGroupName, ', ') WITHIN GROUP (ORDER BY g.StockGroupName) AS Grupo,
        COALESCE(e.QuantityOnHand, 0) AS CantidadDisponible,
        COUNT(*) OVER() AS TotalRegistros
    FROM syn.Productos p
    LEFT JOIN syn.Existencias e
        ON e.StockItemID = p.StockItemID
    LEFT JOIN syn.ProductoGrupos pg
        ON pg.StockItemID = p.StockItemID
    LEFT JOIN syn.GruposProducto g
        ON g.StockGroupID = pg.StockGroupID
    WHERE
        (@Nombre IS NULL OR p.StockItemName LIKE '%' + @Nombre + '%')
        AND (@CantidadMin IS NULL OR COALESCE(e.QuantityOnHand, 0) >= @CantidadMin)
        AND (@CantidadMax IS NULL OR COALESCE(e.QuantityOnHand, 0) <= @CantidadMax)
        AND (
            @GrupoID IS NULL
            OR EXISTS (
                SELECT 1
                FROM syn.ProductoGrupos x
                WHERE x.StockItemID = p.StockItemID
                  AND x.StockGroupID = @GrupoID
            )
        )
    GROUP BY
        p.StockItemID,
        p.StockItemName,
        e.QuantityOnHand
    ORDER BY p.StockItemName ASC
    OFFSET (@Pagina - 1) * @TamanoPagina ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

-- Detalle de un producto con el inventario de esta sucursal
CREATE OR ALTER PROCEDURE dbo.usp_Productos_Detalle
    @ProductoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.StockItemID AS ProductoID,
        p.StockItemName AS Nombre,
        p.SupplierID AS ProveedorID,
        pr.SupplierName AS Proveedor,
        (SELECT STRING_AGG(g.StockGroupName, ', ') WITHIN GROUP (ORDER BY g.StockGroupName)
         FROM syn.ProductoGrupos pg
         JOIN syn.GruposProducto g ON g.StockGroupID = pg.StockGroupID
         WHERE pg.StockItemID = p.StockItemID) AS Grupo,
        c.ColorName AS Color,
        up.PackageTypeName AS UnidadEmpaquetamiento,
        op.PackageTypeName AS Empaquetamiento,
        p.QuantityPerOuter AS CantidadEmpaquetamiento,
        p.Brand AS Marca,
        p.Size AS Tamano,
        p.TaxRate AS Impuesto,
        p.UnitPrice AS PrecioUnitario,
        p.RecommendedRetailPrice AS PrecioVenta,
        p.TypicalWeightPerUnit AS Peso,
        CONCAT(p.StockItemName, N' ', p.MarketingComments) AS PalabrasClave,
        COALESCE(e.QuantityOnHand, 0) AS CantidadDisponible,
        e.BinLocation AS Ubicacion
    FROM syn.Productos p
    JOIN syn.ProveedoresBasicos pr
        ON pr.SupplierID = p.SupplierID
    LEFT JOIN syn.Colores c
        ON c.ColorID = p.ColorID
    JOIN syn.TiposEmpaque up
        ON up.PackageTypeID = p.UnitPackageID
    JOIN syn.TiposEmpaque op
        ON op.PackageTypeID = p.OuterPackageID
    LEFT JOIN syn.Existencias e
        ON e.StockItemID = p.StockItemID
    WHERE p.StockItemID = @ProductoID;
END;
GO

-- Cantidad y ubicación del producto en esta sucursal; crea la fila si todavía no existe
CREATE OR ALTER PROCEDURE dbo.usp_Existencias_Actualizar
    @ProductoID INT,
    @CantidadDisponible INT,
    @Ubicacion NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM syn.Productos WHERE StockItemID = @ProductoID)
            THROW 50001, 'El producto indicado no existe.', 1;

        IF @CantidadDisponible < 0
            THROW 50006, 'La cantidad disponible no puede ser negativa.', 1;

        -- UPDLOCK y HOLDLOCK: dos cambios a la vez no crean la misma fila dos veces
        IF EXISTS (SELECT 1 FROM syn.Existencias WITH (UPDLOCK, HOLDLOCK) WHERE StockItemID = @ProductoID)
            UPDATE syn.Existencias
            SET QuantityOnHand = @CantidadDisponible,
                BinLocation = @Ubicacion
            WHERE StockItemID = @ProductoID;
        ELSE
            INSERT INTO syn.Existencias (StockItemID, QuantityOnHand, BinLocation)
            VALUES (@ProductoID, @CantidadDisponible, @Ubicacion);

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO
