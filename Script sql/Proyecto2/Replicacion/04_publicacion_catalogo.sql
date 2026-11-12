-- Paso 4 (Corporativo): publicar el catálogo (tablas catalogo.*) hacia San José y Limón.
-- Sin instantánea inicial: la carga de Fragmentacion deja los tres nodos con los mismos datos.
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

-- Artículos: productos y sus tablas de referencia
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'Productos',
    @source_owner = N'catalogo', @source_object = N'Productos', @destination_owner = N'catalogo';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'ProductoGrupos',
    @source_owner = N'catalogo', @source_object = N'ProductoGrupos', @destination_owner = N'catalogo';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'ProveedoresBasicos',
    @source_owner = N'catalogo', @source_object = N'ProveedoresBasicos', @destination_owner = N'catalogo';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'GruposProducto',
    @source_owner = N'catalogo', @source_object = N'GruposProducto', @destination_owner = N'catalogo';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'Colores',
    @source_owner = N'catalogo', @source_object = N'Colores', @destination_owner = N'catalogo';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'TiposEmpaque',
    @source_owner = N'catalogo', @source_object = N'TiposEmpaque', @destination_owner = N'catalogo';
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
