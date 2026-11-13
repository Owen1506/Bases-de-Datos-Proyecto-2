-- Ejecutar en Corporativo: SP de escritura de productos.
-- El catálogo solo se escribe aquí; la replicación lo lleva a las sucursales.
IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51012, 'Los SP de escritura de productos se crean en Corporativo.', 1;
GO

-- Detalle para el formulario de edición, con la versión del producto
CREATE OR ALTER PROCEDURE dbo.usp_Productos_Detalle
    @ProductoID INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        p.ProductoID,
        p.Nombre,
        p.ProveedorID,
        p.ColorID,
        p.UnidadEmpaqueID,
        p.EmpaqueExteriorID,
        p.CantidadPorEmpaque AS CantidadEmpaquetamiento,
        p.Marca,
        p.Tamano,
        p.Impuesto,
        p.PrecioUnitario,
        p.PrecioVenta,
        p.Peso,
        p.DiasEntrega,
        p.EsRefrigerado,
        p.CodigoBarras,
        p.ComentariosMarketing,
        (SELECT STRING_AGG(CAST(g.GrupoID AS VARCHAR(10)), ',')
         FROM syn.ProductoGrupos g
         WHERE g.ProductoID = p.ProductoID) AS GruposIDs,
        CAST(p.Version AS BIGINT) AS Version
    FROM syn.Productos p
    WHERE p.ProductoID = @ProductoID;
END;
GO

-- @Grupos es la lista de grupos separada por comas, por ejemplo '2,4,6'
CREATE OR ALTER PROCEDURE dbo.usp_Productos_Insertar
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
    @DiasEntrega INT,
    @EsRefrigerado BIT,
    @CodigoBarras NVARCHAR(50) = NULL,
    @ComentariosMarketing NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ProductoID INT;
    DECLARE @ListaGrupos TABLE (GrupoID INT);

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO @ListaGrupos (GrupoID)
        SELECT DISTINCT TRY_CAST(value AS INT)
        FROM STRING_SPLIT(@Grupos, ',');

        -- Debe venir al menos un grupo y todos deben existir
        IF NOT EXISTS (SELECT 1 FROM @ListaGrupos)
           OR EXISTS (
               SELECT 1
               FROM @ListaGrupos l
               LEFT JOIN syn.GruposProducto g ON g.GrupoID = l.GrupoID
               WHERE g.GrupoID IS NULL
           )
            THROW 50004, 'Debe elegir al menos un grupo válido.', 1;

        IF NOT EXISTS (SELECT 1 FROM syn.ProveedoresBasicos WHERE ProveedorID = @ProveedorID)
           OR NOT EXISTS (SELECT 1 FROM syn.TiposEmpaque WHERE TipoEmpaqueID = @UnidadEmpaqueID)
           OR NOT EXISTS (SELECT 1 FROM syn.TiposEmpaque WHERE TipoEmpaqueID = @EmpaqueExteriorID)
           OR (@ColorID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM syn.Colores WHERE ColorID = @ColorID))
            THROW 50005, 'El proveedor, el color o el empaque indicado no existe.', 1;

        -- Nuevo ID; UPDLOCK y HOLDLOCK evitan que dos inserciones a la vez obtengan el mismo
        SELECT @ProductoID = COALESCE(MAX(ProductoID), 0) + 1
        FROM syn.Productos WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO syn.Productos (
            ProductoID, Nombre, ProveedorID, ColorID, UnidadEmpaqueID, EmpaqueExteriorID,
            Marca, Tamano, DiasEntrega, CantidadPorEmpaque, EsRefrigerado, CodigoBarras,
            Impuesto, PrecioUnitario, PrecioVenta, Peso, ComentariosMarketing
        )
        VALUES (
            @ProductoID, @Nombre, @ProveedorID, @ColorID, @UnidadEmpaqueID, @EmpaqueExteriorID,
            @Marca, @Tamano, @DiasEntrega, @CantidadEmpaquetamiento, @EsRefrigerado, @CodigoBarras,
            @Impuesto, @PrecioUnitario, @PrecioVenta, @Peso, @ComentariosMarketing
        );

        INSERT INTO syn.ProductoGrupos (ProductoID, GrupoID)
        SELECT @ProductoID, GrupoID
        FROM @ListaGrupos;

        COMMIT TRANSACTION;

        SELECT @ProductoID AS ProductoID;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del producto ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
            THROW 50003, 'Ya existe un producto con ese nombre.', 1;

        THROW;
    END CATCH;
END;
GO

-- @Version es la que devolvió usp_Productos_Detalle. Si no coincide, otro usuario lo modificó.
-- @Grupos reemplaza todos los grupos anteriores.
CREATE OR ALTER PROCEDURE dbo.usp_Productos_Actualizar
    @ProductoID INT,
    @Version BIGINT,
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
    @DiasEntrega INT,
    @EsRefrigerado BIT,
    @CodigoBarras NVARCHAR(50) = NULL,
    @ComentariosMarketing NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ListaGrupos TABLE (GrupoID INT);

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM syn.Productos WHERE ProductoID = @ProductoID)
            THROW 50001, 'El producto indicado no existe.', 1;

        INSERT INTO @ListaGrupos (GrupoID)
        SELECT DISTINCT TRY_CAST(value AS INT)
        FROM STRING_SPLIT(@Grupos, ',');

        IF NOT EXISTS (SELECT 1 FROM @ListaGrupos)
           OR EXISTS (
               SELECT 1
               FROM @ListaGrupos l
               LEFT JOIN syn.GruposProducto g ON g.GrupoID = l.GrupoID
               WHERE g.GrupoID IS NULL
           )
            THROW 50004, 'Debe elegir al menos un grupo válido.', 1;

        IF NOT EXISTS (SELECT 1 FROM syn.ProveedoresBasicos WHERE ProveedorID = @ProveedorID)
           OR NOT EXISTS (SELECT 1 FROM syn.TiposEmpaque WHERE TipoEmpaqueID = @UnidadEmpaqueID)
           OR NOT EXISTS (SELECT 1 FROM syn.TiposEmpaque WHERE TipoEmpaqueID = @EmpaqueExteriorID)
           OR (@ColorID IS NOT NULL AND NOT EXISTS (SELECT 1 FROM syn.Colores WHERE ColorID = @ColorID))
            THROW 50005, 'El proveedor, el color o el empaque indicado no existe.', 1;

        -- Solo se actualiza si nadie lo modificó desde que se leyó
        UPDATE syn.Productos
        SET
            Nombre = @Nombre,
            ProveedorID = @ProveedorID,
            ColorID = @ColorID,
            UnidadEmpaqueID = @UnidadEmpaqueID,
            EmpaqueExteriorID = @EmpaqueExteriorID,
            Marca = @Marca,
            Tamano = @Tamano,
            DiasEntrega = @DiasEntrega,
            CantidadPorEmpaque = @CantidadEmpaquetamiento,
            EsRefrigerado = @EsRefrigerado,
            CodigoBarras = @CodigoBarras,
            Impuesto = @Impuesto,
            PrecioUnitario = @PrecioUnitario,
            PrecioVenta = @PrecioVenta,
            Peso = @Peso,
            ComentariosMarketing = @ComentariosMarketing
        WHERE ProductoID = @ProductoID
          AND CAST(Version AS BIGINT) = @Version;

        IF @@ROWCOUNT = 0
            THROW 50013, 'Otro usuario modificó este producto. Vuelva a cargarlo.', 1;

        -- Se reemplazan los grupos por la lista completa que llegó
        DELETE FROM syn.ProductoGrupos
        WHERE ProductoID = @ProductoID;

        INSERT INTO syn.ProductoGrupos (ProductoID, GrupoID)
        SELECT @ProductoID, GrupoID
        FROM @ListaGrupos;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2627 / 2601: el nombre del producto ya existe (restriccion UNIQUE)
        IF ERROR_NUMBER() IN (2627, 2601)
            THROW 50003, 'Ya existe un producto con ese nombre.', 1;

        THROW;
    END CATCH;
END;
GO

-- Los grupos se borran en cascada; en las sucursales el trigger borra el inventario
CREATE OR ALTER PROCEDURE dbo.usp_Productos_Eliminar
    @ProductoID INT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF NOT EXISTS (SELECT 1 FROM syn.Productos WHERE ProductoID = @ProductoID)
            THROW 50001, 'El producto indicado no existe.', 1;

        DELETE FROM syn.Productos
        WHERE ProductoID = @ProductoID;

        COMMIT TRANSACTION;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        IF ERROR_NUMBER() = 547
            THROW 50002, 'No se puede eliminar el producto porque tiene registros asociados.', 1;

        THROW;
    END CATCH;
END;
GO
