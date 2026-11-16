-- Mismo login en ambas instancias; la API escoge el nodo segun la sucursal.
DECLARE @Clave NVARCHAR(128) = N'CLAVE_API_SUCURSAL';
IF LEN(@Clave) < 12 THROW 51301, 'La clave SQL de sucursal debe tener al menos 12 caracteres.', 1;
DECLARE @Sql NVARCHAR(MAX) = CASE WHEN SUSER_ID(N'api_sucursal') IS NULL
    THEN N'CREATE' ELSE N'ALTER' END
    + N' LOGIN [api_sucursal] WITH PASSWORD = ' + QUOTENAME(@Clave, '''')
    + N', CHECK_POLICY = ON';
EXEC(@Sql);
IF DATABASE_PRINCIPAL_ID(N'api_sucursal') IS NULL
    CREATE USER api_sucursal FOR LOGIN api_sucursal;
GO

GRANT EXECUTE ON OBJECT::dbo.usp_Clientes_Listar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Clientes_Publico TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Proveedores_Listar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Api_Proveedores_Publico TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Productos_Listar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Productos_Detalle TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Existencias_Actualizar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Ventas_Listar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Ventas_Detalle TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Ventas_Insertar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Ventas_Actualizar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Ventas_Eliminar TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_CategoriasCliente TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_MetodosEntrega TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_GruposCompra TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_CategoriasProveedor TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_GruposInventario TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_Colores TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_TiposEmpaque TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_Proveedores TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_Vendedores TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_Productos TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_BuscarCiudades TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_BuscarClientes TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_BuscarProveedores TO api_sucursal;
GRANT EXECUTE ON OBJECT::dbo.usp_Catalogo_BuscarProductos TO api_sucursal;

GRANT SELECT ON SCHEMA::syn TO api_sucursal;
GRANT SELECT ON SCHEMA::Sales TO api_sucursal;
GRANT SELECT ON SCHEMA::Purchasing TO api_sucursal;
GRANT SELECT ON SCHEMA::Warehouse TO api_sucursal;
GRANT SELECT ON SCHEMA::Application TO api_sucursal;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Sales.Invoices TO api_sucursal;
GRANT INSERT, UPDATE, DELETE ON OBJECT::Sales.InvoiceLines TO api_sucursal;
GRANT INSERT, UPDATE ON OBJECT::Warehouse.StockItemHoldings TO api_sucursal;
GO
