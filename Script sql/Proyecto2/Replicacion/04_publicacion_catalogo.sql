-- Paso 4 (Corporativo): publicar PruebaCatalogo hacia San José y Limón.
-- Sin instantánea inicial: las sucursales ya tienen la tabla vacía.
USE WideWorldImporters_Corporativo;
GO

EXEC sp_replicationdboption
    @dbname = N'WideWorldImporters_Corporativo',
    @optname = N'publish',
    @value = N'true';
GO

-- Log Reader Agent: lee el log y pasa los cambios a distribution
EXEC sp_addlogreader_agent
    @publisher_security_mode = 0,
    @publisher_login = N'sa',
    @publisher_password = N'$(CLAVE_CORPORATIVO)';
GO

EXEC sp_addpublication
    @publication = N'Pub_Catalogo',
    @status = N'active',
    @replicate_ddl = 0;
GO

EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'PruebaCatalogo',
    @source_owner = N'dbo', @source_object = N'PruebaCatalogo',
    @destination_owner = N'dbo';
GO

EXEC sp_addsubscription
    @publication = N'Pub_Catalogo',
    @subscriber = N'wwi_sanjose',
    @destination_db = N'WideWorldImporters_SanJose',
    @sync_type = N'replication support only';

EXEC sp_addsubscription
    @publication = N'Pub_Catalogo',
    @subscriber = N'wwi_limon',
    @destination_db = N'WideWorldImporters_Limon',
    @sync_type = N'replication support only';
GO

-- Distribution Agents: aplican los cambios en cada sucursal
EXEC sp_addpushsubscription_agent
    @publication = N'Pub_Catalogo',
    @subscriber = N'wwi_sanjose',
    @subscriber_db = N'WideWorldImporters_SanJose',
    @subscriber_security_mode = 0,
    @subscriber_login = N'sa',
    @subscriber_password = N'$(CLAVE_SANJOSE)';

EXEC sp_addpushsubscription_agent
    @publication = N'Pub_Catalogo',
    @subscriber = N'wwi_limon',
    @subscriber_db = N'WideWorldImporters_Limon',
    @subscriber_security_mode = 0,
    @subscriber_login = N'sa',
    @subscriber_password = N'$(CLAVE_LIMON)';
GO
