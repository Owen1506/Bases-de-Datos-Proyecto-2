-- Paso 1 (Corporativo): configurar el distribuidor y registrar los tres nodos como publicadores.
-- Los agentes se conectan con sa (@security_mode = 0).
USE master;
GO

EXEC sp_adddistributor
    @distributor = N'wwi_corporativo',
    @password = N'$(CLAVE_CORPORATIVO)';
GO

-- Base distribution: guarda los cambios pendientes de enviar
EXEC sp_adddistributiondb
    @database = N'distribution',
    @security_mode = 0,
    @login = N'sa',
    @password = N'$(CLAVE_CORPORATIVO)';
GO

-- Publicadores
EXEC sp_adddistpublisher
    @publisher = N'wwi_corporativo',
    @distribution_db = N'distribution',
    @security_mode = 0,
    @login = N'sa',
    @password = N'$(CLAVE_CORPORATIVO)',
    @working_directory = N'/var/opt/mssql/data';

EXEC sp_adddistpublisher
    @publisher = N'wwi_sanjose',
    @distribution_db = N'distribution',
    @security_mode = 0,
    @login = N'sa',
    @password = N'$(CLAVE_SANJOSE)',
    @working_directory = N'/var/opt/mssql/data';

EXEC sp_adddistpublisher
    @publisher = N'wwi_limon',
    @distribution_db = N'distribution',
    @security_mode = 0,
    @login = N'sa',
    @password = N'$(CLAVE_LIMON)',
    @working_directory = N'/var/opt/mssql/data';
GO

-- Verificar: deben aparecer los tres publicadores
EXEC sp_helpdistpublisher;
GO
