-- Ejemplos de los reportes 6-10 del sistema distribuido.
-- Ejecutar en Corporativo; SucursalID NULL = consolidado, 1 = San Jose, 2 = Limon.
USE WideWorldImporters_Corporativo;
GO

EXEC dbo.usp_Reporte_MatrizVentasCategoria @SucursalID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_SeguimientoClientes
    @SucursalID = 1, @Anio = 2015, @Mes = 5, @GrupoID = NULL, @ProductoID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_SeguimientoProveedores
    @SucursalID = 2, @Anio = 2015, @Mes = 5, @GrupoID = NULL, @ProductoID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_RotacionInventario
    @SucursalID = NULL, @Anio = 2015, @GrupoID = NULL, @ProveedorID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_MetodosEnvioDestino
    @SucursalID = NULL, @Anio = 2015, @Mes = 5,
    @CategoriaClienteID = NULL, @GrupoID = NULL, @ProductoID = NULL, @Pagina = 1;
GO
