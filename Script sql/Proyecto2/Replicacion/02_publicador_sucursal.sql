-- Paso 2 (San José y Limón): usar Corporativo como distribuidor.
-- @password: la del distribuidor (paso 1).
USE master;
GO

EXEC sp_adddistributor
    @distributor = N'wwi_corporativo',
    @password = N'$(CLAVE_CORPORATIVO)';
GO

-- Verificar: distribution server = WWI_CORPORATIVO
EXEC sp_get_distributor;
GO
