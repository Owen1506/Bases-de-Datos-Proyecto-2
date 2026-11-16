EXECUTE AS USER = 'api_sucursal';
IF ISNULL(HAS_PERMS_BY_NAME('dbo.usp_Ventas_Insertar', 'OBJECT', 'EXECUTE'), 0) <> 1
    THROW 51320, 'api_sucursal no puede insertar ventas.', 1;
IF ISNULL(HAS_PERMS_BY_NAME('dbo.usp_Existencias_Actualizar', 'OBJECT', 'EXECUTE'), 0) <> 1
    THROW 51321, 'api_sucursal no puede actualizar existencias.', 1;
IF HAS_PERMS_BY_NAME('Sales.Customers', 'OBJECT', 'UPDATE') = 1
    THROW 51322, 'api_sucursal puede modificar clientes.', 1;
REVERT;
GO
