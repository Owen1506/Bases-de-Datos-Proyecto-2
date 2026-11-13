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
        p.ProductoID,
        p.Nombre,
        STRING_AGG(g.Nombre, ', ') WITHIN GROUP (ORDER BY g.Nombre) AS Grupo,
        COALESCE(e.CantidadDisponible, 0) AS CantidadDisponible,
        COUNT(*) OVER() AS TotalRegistros
    FROM syn.Productos p
    LEFT JOIN syn.Existencias e
        ON e.ProductoID = p.ProductoID
    LEFT JOIN syn.ProductoGrupos pg
        ON pg.ProductoID = p.ProductoID
    LEFT JOIN syn.GruposProducto g
        ON g.GrupoID = pg.GrupoID
    WHERE
        (@Nombre IS NULL OR p.Nombre LIKE '%' + @Nombre + '%')
        AND (@CantidadMin IS NULL OR COALESCE(e.CantidadDisponible, 0) >= @CantidadMin)
        AND (@CantidadMax IS NULL OR COALESCE(e.CantidadDisponible, 0) <= @CantidadMax)
        AND (
            @GrupoID IS NULL
            OR EXISTS (
                SELECT 1
                FROM syn.ProductoGrupos x
                WHERE x.ProductoID = p.ProductoID
                  AND x.GrupoID = @GrupoID
            )
        )
    GROUP BY
        p.ProductoID,
        p.Nombre,
        e.CantidadDisponible
    ORDER BY p.Nombre ASC
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
        p.ProductoID,
        p.Nombre,
        p.ProveedorID,
        pr.Nombre AS Proveedor,
        (SELECT STRING_AGG(g.Nombre, ', ') WITHIN GROUP (ORDER BY g.Nombre)
         FROM syn.ProductoGrupos pg
         JOIN syn.GruposProducto g ON g.GrupoID = pg.GrupoID
         WHERE pg.ProductoID = p.ProductoID) AS Grupo,
        c.Nombre AS Color,
        up.Nombre AS UnidadEmpaquetamiento,
        op.Nombre AS Empaquetamiento,
        p.CantidadPorEmpaque AS CantidadEmpaquetamiento,
        p.Marca,
        p.Tamano,
        p.Impuesto,
        p.PrecioUnitario,
        p.PrecioVenta,
        p.Peso,
        CONCAT(p.Nombre, N' ', p.ComentariosMarketing) AS PalabrasClave,
        COALESCE(e.CantidadDisponible, 0) AS CantidadDisponible,
        e.Ubicacion
    FROM syn.Productos p
    JOIN syn.ProveedoresBasicos pr
        ON pr.ProveedorID = p.ProveedorID
    LEFT JOIN syn.Colores c
        ON c.ColorID = p.ColorID
    JOIN syn.TiposEmpaque up
        ON up.TipoEmpaqueID = p.UnidadEmpaqueID
    JOIN syn.TiposEmpaque op
        ON op.TipoEmpaqueID = p.EmpaqueExteriorID
    LEFT JOIN syn.Existencias e
        ON e.ProductoID = p.ProductoID
    WHERE p.ProductoID = @ProductoID;
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

        IF NOT EXISTS (SELECT 1 FROM syn.Productos WHERE ProductoID = @ProductoID)
            THROW 50001, 'El producto indicado no existe.', 1;

        IF @CantidadDisponible < 0
            THROW 50006, 'La cantidad disponible no puede ser negativa.', 1;

        -- UPDLOCK y HOLDLOCK: dos cambios a la vez no crean la misma fila dos veces
        IF EXISTS (SELECT 1 FROM syn.Existencias WITH (UPDLOCK, HOLDLOCK) WHERE ProductoID = @ProductoID)
            UPDATE syn.Existencias
            SET CantidadDisponible = @CantidadDisponible,
                Ubicacion = @Ubicacion
            WHERE ProductoID = @ProductoID;
        ELSE
            INSERT INTO syn.Existencias (ProductoID, CantidadDisponible, Ubicacion)
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
