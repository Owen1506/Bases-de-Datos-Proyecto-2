-- Paso 5 (San José): publicar PruebaFacturas hacia Corporativo.
USE WideWorldImporters_SanJose;
GO

EXEC sp_replicationdboption
    @dbname = N'WideWorldImporters_SanJose',
    @optname = N'publish',
    @value = N'true';
GO

-- Log Reader Agent: lee el log y pasa los cambios a distribution
EXEC sp_addlogreader_agent
    @publisher_security_mode = 0,
    @publisher_login = N'sa',
    @publisher_password = N'$(CLAVE_SANJOSE)';
GO

EXEC sp_addpublication
    @publication = N'Pub_SanJose',
    @status = N'active',
    @replicate_ddl = 0;
GO

EXEC sp_addarticle @publication = N'Pub_SanJose', @article = N'PruebaFacturas',
    @source_owner = N'dbo', @source_object = N'PruebaFacturas',
    @destination_owner = N'dbo';
GO

EXEC sp_addsubscription
    @publication = N'Pub_SanJose',
    @subscriber = N'wwi_corporativo',
    @destination_db = N'WideWorldImporters_Corporativo',
    @sync_type = N'replication support only';
GO

-- Distribution Agent: aplica los cambios en Corporativo
EXEC sp_addpushsubscription_agent
    @publication = N'Pub_SanJose',
    @subscriber = N'wwi_corporativo',
    @subscriber_db = N'WideWorldImporters_Corporativo',
    @subscriber_security_mode = 0,
    @subscriber_login = N'sa',
    @subscriber_password = N'$(CLAVE_CORPORATIVO)';
GO
