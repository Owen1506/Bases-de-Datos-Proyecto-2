-- Paso 5 (San José): publicar facturas, órdenes e inventario hacia Corporativo.
-- Sin instantánea inicial: la carga de datos deja las copias de Corporativo iguales a la sucursal.
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

EXEC sp_addarticle @publication = N'Pub_SanJose', @article = N'Invoices',
    @source_owner = N'Sales', @source_object = N'Invoices', @destination_owner = N'Sales';
EXEC sp_addarticle @publication = N'Pub_SanJose', @article = N'InvoiceLines',
    @source_owner = N'Sales', @source_object = N'InvoiceLines', @destination_owner = N'Sales';
EXEC sp_addarticle @publication = N'Pub_SanJose', @article = N'PurchaseOrders',
    @source_owner = N'Purchasing', @source_object = N'PurchaseOrders', @destination_owner = N'Purchasing';
EXEC sp_addarticle @publication = N'Pub_SanJose', @article = N'PurchaseOrderLines',
    @source_owner = N'Purchasing', @source_object = N'PurchaseOrderLines', @destination_owner = N'Purchasing';

-- Inventario: los borrados no se envían, en Corporativo ya se borran en cascada con el producto
EXEC sp_addarticle @publication = N'Pub_SanJose', @article = N'StockItemHoldings',
    @source_owner = N'Warehouse', @source_object = N'StockItemHoldings', @destination_owner = N'Warehouse',
    @del_cmd = N'NONE';
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
