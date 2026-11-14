-- Paso 4 (Corporativo): publicar el catálogo con nombres WWI hacia San José y Limón.
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
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'StockItems',
    @source_owner = N'Warehouse', @source_object = N'StockItems', @destination_owner = N'Warehouse';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'StockItemStockGroups',
    @source_owner = N'Warehouse', @source_object = N'StockItemStockGroups', @destination_owner = N'Warehouse';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'Suppliers',
    @source_owner = N'Purchasing', @source_object = N'Suppliers', @destination_owner = N'Purchasing';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'StockGroups',
    @source_owner = N'Warehouse', @source_object = N'StockGroups', @destination_owner = N'Warehouse';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'Colors',
    @source_owner = N'Warehouse', @source_object = N'Colors', @destination_owner = N'Warehouse';
EXEC sp_addarticle @publication = N'Pub_Catalogo', @article = N'PackageTypes',
    @source_owner = N'Warehouse', @source_object = N'PackageTypes', @destination_owner = N'Warehouse';
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
