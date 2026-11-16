USE WideWorldImporters_Corporativo;
GO

-- Generado como .local.sql por configurarSeguridad.js; las claves nunca van a Git.
DECLARE @Login NVARCHAR(128), @Clave NVARCHAR(128), @Sql NVARCHAR(MAX);
DECLARE cuentas CURSOR LOCAL FAST_FORWARD FOR
SELECT nombre, clave FROM (VALUES
    (N'api_login', N'CLAVE_API_LOGIN'),
    (N'api_administrador', N'CLAVE_API_ADMIN'),
    (N'api_corporativo', N'CLAVE_API_CORPORATIVO')
) AS datos(nombre, clave);
OPEN cuentas;
FETCH NEXT FROM cuentas INTO @Login, @Clave;
WHILE @@FETCH_STATUS = 0
BEGIN
    IF LEN(@Clave) < 12 THROW 51300, 'La clave SQL de la API debe tener al menos 12 caracteres.', 1;
    SET @Sql = CASE WHEN SUSER_ID(@Login) IS NULL THEN N'CREATE' ELSE N'ALTER' END
        + N' LOGIN ' + QUOTENAME(@Login) + N' WITH PASSWORD = ' + QUOTENAME(@Clave, '''')
        + N', CHECK_POLICY = ON';
    EXEC(@Sql);
    IF DATABASE_PRINCIPAL_ID(@Login) IS NULL
    BEGIN
        SET @Sql = N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login);
        EXEC(@Sql);
    END;
    FETCH NEXT FROM cuentas INTO @Login, @Clave;
END;
CLOSE cuentas;
DEALLOCATE cuentas;
GO

GRANT EXECUTE ON OBJECT::dbo.usp_Api_Login TO api_login;

-- Administradores: procedimientos usados por Clientes, Proveedores, Inventario
-- y Catalogos. No reciben permisos de servidor ni db_owner.
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Clientes_Privado TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Proveedores_Privado TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Contacto TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_BuscarPersonas TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_ContactosCliente TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Clientes_Guardar TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Proveedores_Guardar TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Clientes_Eliminar TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Proveedores_Eliminar TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Productos_Detalle TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Productos_Insertar TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Productos_Actualizar TO api_administrador;
GRANT EXECUTE ON OBJECT::dbo.usp_Productos_Eliminar TO api_administrador;

-- Los procedimientos usan sinonimos; SQL Server exige permisos sobre las tablas
-- base al resolverlos. Se conceden solo lectura y DML en las tablas que editan.
GRANT SELECT ON SCHEMA::syn TO api_administrador;
GRANT SELECT ON SCHEMA::Sales TO api_administrador;
GRANT SELECT ON SCHEMA::Purchasing TO api_administrador;
GRANT SELECT ON SCHEMA::Warehouse TO api_administrador;
GRANT SELECT ON SCHEMA::Application TO api_administrador;
GRANT SELECT ON SCHEMA::Sensitive TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Sales.Customers TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Purchasing.Suppliers TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Sensitive.Customers TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Sensitive.Suppliers TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Sensitive.People TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Application.People TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Warehouse.StockItems TO api_administrador;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Warehouse.StockItemStockGroups TO api_administrador;

-- Corporativo solo puede ejecutar reportes y leer sus fuentes publicas.
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_ComprasProveedores TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_AniosFacturas TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_AniosOrdenesCompra TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_VentasClientes TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_TopProductosGanancia TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_TopClientesFacturas TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_TopProveedoresOrdenes TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_Filtros TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_MatrizVentasCategoria TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_SeguimientoClientes TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_SeguimientoProveedores TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_RotacionInventario TO api_corporativo;
GRANT EXECUTE ON OBJECT::dbo.usp_Reporte_MetodosEnvioDestino TO api_corporativo;
GRANT SELECT ON SCHEMA::syn TO api_corporativo;
GRANT SELECT ON SCHEMA::Sales TO api_corporativo;
GRANT SELECT ON SCHEMA::Purchasing TO api_corporativo;
GRANT SELECT ON SCHEMA::Warehouse TO api_corporativo;
GRANT SELECT ON SCHEMA::Application TO api_corporativo;
GRANT SELECT ON OBJECT::dbo.vm_MontoOrden TO api_corporativo;
GRANT SELECT ON OBJECT::dbo.vm_MontoFactura TO api_corporativo;
GRANT SELECT ON OBJECT::dbo.vm_GananciaProducto TO api_corporativo;
GO
