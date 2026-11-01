-- 99_ejemplos_ejecucion.sql
-- Ejemplos de como se ejecutan los SP
USE WideWorldImporters;
GO

-- Catalogos
EXEC dbo.usp_Catalogo_CategoriasCliente;
EXEC dbo.usp_Catalogo_MetodosEntrega;
EXEC dbo.usp_Catalogo_GruposCompra;
EXEC dbo.usp_Catalogo_BuscarCiudades @Texto = 'Lisc';
EXEC dbo.usp_Catalogo_BuscarPersonas @Texto = 'Waldemar';
EXEC dbo.usp_Catalogo_BuscarClientes @Texto = 'Head Office';
EXEC dbo.usp_Catalogo_BuscarProveedores @Texto = 'pub';
EXEC dbo.usp_Catalogo_BuscarProductos @Texto = 'rc';

-- Clientes
EXEC dbo.usp_Clientes_Listar;
EXEC dbo.usp_Clientes_Listar @Nombre = 'toys';
EXEC dbo.usp_Clientes_Listar @CategoriaID = 4;
EXEC dbo.usp_Clientes_Listar @Nombre = 'toys', @CategoriaID = 3, @MetodoEntregaID = 3;
EXEC dbo.usp_Clientes_Listar @Nombre = 'toys', @Pagina = 3;

EXEC dbo.usp_Clientes_Detalle @ClienteID = 1;
GO

-- CRUD de clientes: se crea un cliente, se edita y se elimina
-- (sin @ClienteFacturarID el cliente se factura a si mismo)
DECLARE @nuevo TABLE (ClienteID INT);
DECLARE @id INT;

INSERT @nuevo EXEC dbo.usp_Clientes_Insertar
    @Nombre = 'Cliente Ejemplo', @CategoriaID = 3,
    @ContactoPrimarioID = 1001, @MetodoEntregaID = 3, @CiudadEntregaID = 19586, @CiudadPostalID = 19586,
    @DiasPago = 7, @Telefono = '(308) 555-0199', @Fax = '(308) 555-0198', @SitioWeb = 'http://www.ejemplo.com',
    @DireccionEntrega1 = 'Shop 1', @CodigoPostalEntrega = '90410', @DireccionPostal1 = 'PO Box 1',
    @CodigoPostalPostal = '90410', @Latitud = 41.5, @Longitud = -102.6;
SELECT @id = ClienteID FROM @nuevo;

EXEC dbo.usp_Clientes_Actualizar
    @ClienteID = @id, @Nombre = 'Cliente Ejemplo Editado', @ClienteFacturarID = @id, @CategoriaID = 4,
    @ContactoPrimarioID = 1001, @MetodoEntregaID = 3, @CiudadEntregaID = 19586, @CiudadPostalID = 19586,
    @DiasPago = 14, @Telefono = '(308) 555-0199', @Fax = '(308) 555-0198', @SitioWeb = 'http://www.ejemplo.com',
    @DireccionEntrega1 = 'Shop 1', @CodigoPostalEntrega = '90410', @DireccionPostal1 = 'PO Box 1',
    @CodigoPostalPostal = '90410', @Latitud = 41.5, @Longitud = -102.6;

EXEC dbo.usp_Clientes_Detalle @ClienteID = @id;
EXEC dbo.usp_Clientes_Eliminar @ClienteID = @id;
GO

-- Proveedores
EXEC dbo.usp_Catalogo_CategoriasProveedor;
EXEC dbo.usp_Proveedores_Listar;
EXEC dbo.usp_Proveedores_Listar @Nombre = 'pub';
EXEC dbo.usp_Proveedores_Listar @CategoriaID = 2;
EXEC dbo.usp_Proveedores_Listar @Pagina = 2;
EXEC dbo.usp_Proveedores_Detalle @ProveedorID = 2;
GO

-- CRUD de proveedores: se crea un proveedor, se edita y se elimina
DECLARE @nuevoProveedor TABLE (ProveedorID INT);
DECLARE @idProveedor INT;

INSERT @nuevoProveedor EXEC dbo.usp_Proveedores_Insertar
    @Nombre = 'Proveedor Ejemplo', @CategoriaID = 2, @ContactoPrimarioID = 1001, @ContactoAlternativoID = 1002,
    @MetodoEntregaID = 7, @CiudadEntregaID = 19586, @CiudadPostalID = 19586, @NombreBanco = 'Woodgrove Bank Lisco',
    @NumeroCuenta = '1234567890', @DiasPago = 30, @Telefono = '(308) 555-0111', @Fax = '(308) 555-0112',
    @SitioWeb = 'http://www.proveedor.com', @DireccionEntrega1 = 'Suite 1', @CodigoPostalEntrega = '90410',
    @DireccionPostal1 = 'PO Box 1', @CodigoPostalPostal = '90410';
SELECT @idProveedor = ProveedorID FROM @nuevoProveedor;

EXEC dbo.usp_Proveedores_Actualizar
    @ProveedorID = @idProveedor, @Nombre = 'Proveedor Ejemplo Editado', @CategoriaID = 2, @ContactoPrimarioID = 1001,
    @ContactoAlternativoID = 1002, @MetodoEntregaID = 7, @CiudadEntregaID = 19586, @CiudadPostalID = 19586,
    @NombreBanco = 'Woodgrove Bank Lisco', @NumeroCuenta = '1234567890', @DiasPago = 45, @Telefono = '(308) 555-0111',
    @Fax = '(308) 555-0112', @SitioWeb = 'http://www.proveedor.com', @DireccionEntrega1 = 'Suite 1',
    @CodigoPostalEntrega = '90410', @DireccionPostal1 = 'PO Box 1', @CodigoPostalPostal = '90410';

EXEC dbo.usp_Proveedores_Detalle @ProveedorID = @idProveedor;
EXEC dbo.usp_Proveedores_Eliminar @ProveedorID = @idProveedor;
GO

-- Inventario
EXEC dbo.usp_Catalogo_GruposInventario;
-- catalogos del formulario de productos
EXEC dbo.usp_Catalogo_Proveedores;
EXEC dbo.usp_Catalogo_Colores;
EXEC dbo.usp_Catalogo_TiposEmpaque;
EXEC dbo.usp_Inventario_Listar;
EXEC dbo.usp_Inventario_Listar @Nombre = 'usb';
EXEC dbo.usp_Inventario_Listar @GrupoID = 4;
EXEC dbo.usp_Inventario_Listar @Nombre = 'shirt', @GrupoID = 4, @Pagina = 2;
EXEC dbo.usp_Inventario_Listar @CantidadMax = 999;
EXEC dbo.usp_Inventario_Listar @Nombre = 'shirt', @GrupoID = 4, @CantidadMin = 1000, @CantidadMax = 100000;
EXEC dbo.usp_Inventario_Detalle @ProductoID = 1;
GO

-- CRUD de inventario: se crea un producto en dos grupos, se edita (queda en tres) y se elimina
DECLARE @nuevoProducto TABLE (ProductoID INT);
DECLARE @idProducto INT;

INSERT @nuevoProducto EXEC dbo.usp_Inventario_Insertar
    @Nombre = 'Producto Ejemplo', @ProveedorID = 1, @Grupos = '2,4', @UnidadEmpaqueID = 7, @EmpaqueExteriorID = 7,
    @CantidadEmpaquetamiento = 1, @Impuesto = 15, @PrecioUnitario = 10, @Peso = 0.5, @CantidadDisponible = 100,
    @Ubicacion = 'L-1', @DiasEntrega = 7, @EsRefrigerado = 0, @ComentariosMarketing = 'Producto de ejemplo';
SELECT @idProducto = ProductoID FROM @nuevoProducto;

EXEC dbo.usp_Inventario_Actualizar
    @ProductoID = @idProducto, @Nombre = 'Producto Ejemplo', @ProveedorID = 1, @Grupos = '1,2,4', @UnidadEmpaqueID = 7,
    @EmpaqueExteriorID = 7, @CantidadEmpaquetamiento = 1, @Impuesto = 15, @PrecioUnitario = 12, @Peso = 0.5,
    @CantidadDisponible = 80, @Ubicacion = 'L-2', @DiasEntrega = 14, @EsRefrigerado = 0, @ComentariosMarketing = 'Producto de ejemplo';

EXEC dbo.usp_Inventario_Detalle @ProductoID = @idProducto;
EXEC dbo.usp_Inventario_Eliminar @ProductoID = @idProducto;
GO

-- Ventas
EXEC dbo.usp_Ventas_Listar;
EXEC dbo.usp_Ventas_Listar @NombreCliente = 'dinh';
EXEC dbo.usp_Ventas_Listar @FechaInicio = '2015-01-01', @FechaFin = '2015-12-31';
EXEC dbo.usp_Ventas_Listar @MontoMin = 1000, @MontoMax = 5000;
EXEC dbo.usp_Ventas_Listar @NombreCliente = 'dinh', @FechaInicio = '2015-01-01', @FechaFin = '2015-12-31',
    @MontoMin = 1000, @Pagina = 2;
EXEC dbo.usp_Ventas_Detalle @FacturaID = 1;
EXEC dbo.usp_Ventas_DetalleLineas @FacturaID = 1;
GO

-- CRUD de ventas: se crea una factura con dos productos, se edita y se elimina.
-- Las lineas van en JSON; el impuesto y los totales los calcula el SP.
EXEC dbo.usp_Catalogo_Vendedores;
EXEC dbo.usp_Catalogo_ContactosCliente @ClienteID = 1;
EXEC dbo.usp_Catalogo_Productos;

DECLARE @nuevaFactura TABLE (FacturaID INT);
DECLARE @idFactura INT;

INSERT @nuevaFactura EXEC dbo.usp_Ventas_Insertar
    @ClienteID = 1, @MetodoEntregaID = 3, @ContactoID = 1001, @VendedorID = 2, @Fecha = '2016-06-01',
    @NumeroOrdenCliente = '99999', @InstruccionesEntrega = 'Dejar en recepcion',
    @Detalles = '[{"ProductoID":1,"Cantidad":2,"PrecioUnitario":25},{"ProductoID":2,"Cantidad":1,"PrecioUnitario":25}]';
SELECT @idFactura = FacturaID FROM @nuevaFactura;

EXEC dbo.usp_Ventas_Actualizar
    @FacturaID = @idFactura, @ClienteID = 1, @MetodoEntregaID = 3, @ContactoID = 1002, @VendedorID = 3,
    @Fecha = '2016-06-02', @Detalles = '[{"ProductoID":3,"Cantidad":5,"PrecioUnitario":10}]';

EXEC dbo.usp_Ventas_Detalle @FacturaID = @idFactura;
EXEC dbo.usp_Ventas_DetalleLineas @FacturaID = @idFactura;
EXEC dbo.usp_Ventas_Eliminar @FacturaID = @idFactura;
GO

-- Reportes y estadisticas
-- años validos para los filtros de los reportes
EXEC dbo.usp_Reporte_AniosFacturas;
EXEC dbo.usp_Reporte_AniosOrdenesCompra;

-- 1. Montos de compras a proveedores por proveedor y categoria (ROLLUP)
EXEC dbo.usp_Reporte_ComprasProveedores;
EXEC dbo.usp_Reporte_ComprasProveedores @Categoria = 'Novelty', @NombreProveedor = 'Contoso';

-- 2. Montos de ventas a clientes por cliente y categoria (ROLLUP)
EXEC dbo.usp_Reporte_VentasClientes;
EXEC dbo.usp_Reporte_VentasClientes @NombreCliente = 'Tailspin', @Categoria = 'Novelty';

-- 3. Top 5 de productos con mas ganancia por año (DENSE_RANK)
EXEC dbo.usp_Reporte_TopProductosGanancia;
EXEC dbo.usp_Reporte_TopProductosGanancia @Anio = 2015;

-- 4. Top 5 de clientes con mas facturas por año (DENSE_RANK)
EXEC dbo.usp_Reporte_TopClientesFacturas;
EXEC dbo.usp_Reporte_TopClientesFacturas @AnioInicio = 2014, @AnioFin = 2015;

-- 5. Top 5 de proveedores con mas ordenes de compra por año (DENSE_RANK)
EXEC dbo.usp_Reporte_TopProveedoresOrdenes;
EXEC dbo.usp_Reporte_TopProveedoresOrdenes @AnioInicio = 2014, @AnioFin = 2015;
GO
