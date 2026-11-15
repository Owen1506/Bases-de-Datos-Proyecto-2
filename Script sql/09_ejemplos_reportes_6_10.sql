-- Ejemplos de los reportes 6-10 sobre la base original del Proyecto 1.
USE WideWorldImporters;
GO

EXEC dbo.usp_Reporte_MatrizVentasCategoria @Pagina = 1;
EXEC dbo.usp_Reporte_SeguimientoClientes
    @Anio = 2015, @Mes = 5, @GrupoID = NULL, @ProductoID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_SeguimientoProveedores
    @Anio = 2015, @Mes = 5, @GrupoID = NULL, @ProductoID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_RotacionInventario
    @Anio = 2015, @GrupoID = NULL, @ProveedorID = NULL, @Pagina = 1;
EXEC dbo.usp_Reporte_MetodosEnvioDestino
    @Anio = 2015, @Mes = 5, @CategoriaClienteID = NULL,
    @GrupoID = NULL, @ProductoID = NULL, @Pagina = 1;
GO
