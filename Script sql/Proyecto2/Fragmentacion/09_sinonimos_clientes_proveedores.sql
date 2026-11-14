-- Sinonimos para los fragmentos publicos y los datos sensibles.
-- Ejecutar en cada nodo despues de 06 y 07. Las referencias remotas de las
-- sucursales se resolveran cuando se configure el linked server wwi_corporativo.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51083, 'Conecte a una de las tres bases del Proyecto 2.', 1;
GO

IF SCHEMA_ID(N'syn') IS NULL EXEC(N'CREATE SCHEMA syn');
GO

DROP SYNONYM IF EXISTS syn.Customers;
CREATE SYNONYM syn.Customers FOR Sales.Customers;
DROP SYNONYM IF EXISTS syn.Suppliers;
CREATE SYNONYM syn.Suppliers FOR Purchasing.Suppliers;
DROP SYNONYM IF EXISTS syn.People;
CREATE SYNONYM syn.People FOR Application.People;
DROP SYNONYM IF EXISTS syn.CustomerCategories;
CREATE SYNONYM syn.CustomerCategories FOR Sales.CustomerCategories;
DROP SYNONYM IF EXISTS syn.BuyingGroups;
CREATE SYNONYM syn.BuyingGroups FOR Sales.BuyingGroups;
DROP SYNONYM IF EXISTS syn.SupplierCategories;
CREATE SYNONYM syn.SupplierCategories FOR Purchasing.SupplierCategories;
DROP SYNONYM IF EXISTS syn.DeliveryMethods;
CREATE SYNONYM syn.DeliveryMethods FOR Application.DeliveryMethods;
DROP SYNONYM IF EXISTS syn.Cities;
CREATE SYNONYM syn.Cities FOR Application.Cities;
DROP SYNONYM IF EXISTS syn.StateProvinces;
CREATE SYNONYM syn.StateProvinces FOR Application.StateProvinces;
DROP SYNONYM IF EXISTS syn.Countries;
CREATE SYNONYM syn.Countries FOR Application.Countries;
GO

DROP SYNONYM IF EXISTS syn.CustomersSensitive;
DROP SYNONYM IF EXISTS syn.SuppliersSensitive;
DROP SYNONYM IF EXISTS syn.PeopleSensitive;
IF DB_NAME() = N'WideWorldImporters_Corporativo'
BEGIN
    EXEC(N'CREATE SYNONYM syn.CustomersSensitive FOR Sensitive.Customers');
    EXEC(N'CREATE SYNONYM syn.SuppliersSensitive FOR Sensitive.Suppliers');
    EXEC(N'CREATE SYNONYM syn.PeopleSensitive FOR Sensitive.People');
END
ELSE
BEGIN
    EXEC(N'CREATE SYNONYM syn.CustomersSensitive FOR
        [wwi_corporativo].[WideWorldImporters_Corporativo].[Sensitive].[CustomersRemote]');
    EXEC(N'CREATE SYNONYM syn.SuppliersSensitive FOR
        [wwi_corporativo].[WideWorldImporters_Corporativo].[Sensitive].[SuppliersRemote]');
    EXEC(N'CREATE SYNONYM syn.PeopleSensitive FOR
        [wwi_corporativo].[WideWorldImporters_Corporativo].[Sensitive].[People]');
END;
GO

SELECT name AS Sinonimo, base_object_name AS Objeto
FROM sys.synonyms
WHERE name IN (N'Customers', N'Suppliers', N'People',
               N'CustomersSensitive', N'SuppliersSensitive', N'PeopleSensitive')
ORDER BY name;
GO
