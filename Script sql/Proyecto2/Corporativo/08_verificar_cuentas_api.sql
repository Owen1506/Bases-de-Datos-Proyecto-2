USE WideWorldImporters_Corporativo;
GO

EXECUTE AS USER = 'api_login';
IF ISNULL(HAS_PERMS_BY_NAME('dbo.usp_Api_Login', 'OBJECT', 'EXECUTE'), 0) <> 1
    THROW 51310, 'api_login no puede ejecutar el login.', 1;
IF HAS_PERMS_BY_NAME('dbo.Usuarios', 'OBJECT', 'SELECT') = 1
    THROW 51311, 'api_login puede leer Usuarios directamente.', 1;
IF HAS_PERMS_BY_NAME('dbo.usp_Reporte_VentasClientes', 'OBJECT', 'EXECUTE') = 1
    THROW 51312, 'api_login puede ejecutar reportes.', 1;
REVERT;

EXECUTE AS USER = 'api_administrador';
IF ISNULL(HAS_PERMS_BY_NAME('dbo.usp_Api_Clientes_Guardar', 'OBJECT', 'EXECUTE'), 0) <> 1
    THROW 51313, 'api_administrador no puede guardar clientes.', 1;
IF HAS_PERMS_BY_NAME('dbo.usp_Reporte_VentasClientes', 'OBJECT', 'EXECUTE') = 1
    THROW 51314, 'api_administrador puede ejecutar reportes.', 1;
REVERT;

EXECUTE AS USER = 'api_corporativo';
IF ISNULL(HAS_PERMS_BY_NAME('dbo.usp_Reporte_VentasClientes', 'OBJECT', 'EXECUTE'), 0) <> 1
    THROW 51315, 'api_corporativo no puede ejecutar reportes.', 1;
IF HAS_PERMS_BY_NAME('dbo.usp_Api_Clientes_Guardar', 'OBJECT', 'EXECUTE') = 1
    THROW 51316, 'api_corporativo puede guardar clientes.', 1;
IF HAS_PERMS_BY_NAME('Sensitive.Customers', 'OBJECT', 'SELECT') = 1
    THROW 51317, 'api_corporativo puede leer datos sensibles.', 1;
REVERT;
GO
