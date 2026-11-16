-- Verificar estructuras publicas en los tres nodos y privacidad por nodo.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51074, 'Conecte a una de las tres bases del Proyecto 2.', 1;

IF OBJECT_ID(N'Application.Countries', N'U') IS NULL OR
   OBJECT_ID(N'Application.StateProvinces', N'U') IS NULL OR
   OBJECT_ID(N'Application.Cities', N'U') IS NULL OR
   OBJECT_ID(N'Application.DeliveryMethods', N'U') IS NULL OR
   OBJECT_ID(N'Application.People', N'U') IS NULL OR
   OBJECT_ID(N'Sales.CustomerCategories', N'U') IS NULL OR
   OBJECT_ID(N'Sales.BuyingGroups', N'U') IS NULL OR
   OBJECT_ID(N'Sales.Customers', N'U') IS NULL OR
   OBJECT_ID(N'Purchasing.SupplierCategories', N'U') IS NULL OR
   OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL
    THROW 51075, 'Faltan tablas publicas de clientes, proveedores o referencias.', 1;

IF EXISTS (
    SELECT 1
    FROM (VALUES
        (N'Application.Countries', N'CountryID'),
        (N'Application.Countries', N'CountryName'),
        (N'Application.StateProvinces', N'StateProvinceID'),
        (N'Application.StateProvinces', N'StateProvinceCode'),
        (N'Application.StateProvinces', N'StateProvinceName'),
        (N'Application.StateProvinces', N'CountryID'),
        (N'Application.Cities', N'CityID'),
        (N'Application.Cities', N'CityName'),
        (N'Application.Cities', N'StateProvinceID'),
        (N'Application.DeliveryMethods', N'DeliveryMethodID'),
        (N'Application.DeliveryMethods', N'DeliveryMethodName'),
        (N'Application.People', N'PersonID'),
        (N'Sales.CustomerCategories', N'CustomerCategoryID'),
        (N'Sales.CustomerCategories', N'CustomerCategoryName'),
        (N'Sales.BuyingGroups', N'BuyingGroupID'),
        (N'Sales.BuyingGroups', N'BuyingGroupName'),
        (N'Sales.Customers', N'CustomerID'),
        (N'Sales.Customers', N'CustomerName'),
        (N'Sales.Customers', N'BillToCustomerID'),
        (N'Sales.Customers', N'CustomerCategoryID'),
        (N'Sales.Customers', N'BuyingGroupID'),
        (N'Sales.Customers', N'PrimaryContactPersonID'),
        (N'Sales.Customers', N'AlternateContactPersonID'),
        (N'Sales.Customers', N'DeliveryMethodID'),
        (N'Sales.Customers', N'DeliveryCityID'),
        (N'Sales.Customers', N'PostalCityID'),
        (N'Sales.Customers', N'CreditLimit'),
        (N'Sales.Customers', N'AccountOpenedDate'),
        (N'Sales.Customers', N'StandardDiscountPercentage'),
        (N'Sales.Customers', N'IsOnCreditHold'),
        (N'Sales.Customers', N'PaymentDays'),
        (N'Purchasing.SupplierCategories', N'SupplierCategoryID'),
        (N'Purchasing.SupplierCategories', N'SupplierCategoryName'),
        (N'Purchasing.Suppliers', N'SupplierID'),
        (N'Purchasing.Suppliers', N'SupplierName'),
        (N'Purchasing.Suppliers', N'SupplierCategoryID'),
        (N'Purchasing.Suppliers', N'SupplierReference'),
        (N'Purchasing.Suppliers', N'DeliveryMethodID'),
        (N'Purchasing.Suppliers', N'DeliveryCityID'),
        (N'Purchasing.Suppliers', N'PostalCityID'),
        (N'Purchasing.Suppliers', N'PaymentDays'),
        (N'Purchasing.Suppliers', N'PrimaryContactPersonID'),
        (N'Purchasing.Suppliers', N'AlternateContactPersonID')
    ) AS Esperadas(Tabla, Columna)
    WHERE COL_LENGTH(Esperadas.Tabla, Esperadas.Columna) IS NULL
)
    THROW 51076, 'Faltan columnas publicas de WWI.', 1;

IF COL_LENGTH(N'Sales.Customers', N'PhoneNumber') IS NOT NULL OR
   COL_LENGTH(N'Sales.Customers', N'DeliveryAddressLine1') IS NOT NULL OR
   COL_LENGTH(N'Purchasing.Suppliers', N'BankAccountNumber') IS NOT NULL OR
   COL_LENGTH(N'Purchasing.Suppliers', N'PhoneNumber') IS NOT NULL OR
   COL_LENGTH(N'Application.People', N'EmailAddress') IS NOT NULL
    THROW 51077, 'Hay columnas sensibles en una tabla publica.', 1;

-- Tras 10_vendedores_publicos.sql, FullName solo se permite para vendedores.
-- SQL dinamico mantiene este verificador util tambien antes de ejecutar 10.
IF COL_LENGTH(N'Application.People', N'FullName') IS NOT NULL
BEGIN
    IF COL_LENGTH(N'Application.People', N'IsSalesperson') IS NULL OR
       COL_LENGTH(N'Application.People', N'SucursalID') IS NULL
        THROW 51086, 'FullName publico requiere IsSalesperson y SucursalID.', 1;
    EXEC(N'IF EXISTS (
        SELECT 1 FROM Application.People
        WHERE (IsSalesperson = 1 AND (FullName IS NULL OR SucursalID IS NULL OR SucursalID NOT IN (1, 2)))
           OR (IsSalesperson = 0 AND (FullName IS NOT NULL OR SucursalID IS NOT NULL))
    ) THROW 51087, ''Un contacto tiene nombre publico o un vendedor no tiene sucursal.'', 1;');
END;

IF EXISTS (
    SELECT 1 FROM sys.foreign_keys
    WHERE name IN (
        N'FK_Application_StateProvinces_Country', N'FK_Application_Cities_StateProvince',
        N'FK_Sales_Customers_BillTo', N'FK_Sales_Customers_Category',
        N'FK_Sales_Customers_BuyingGroup', N'FK_Sales_Customers_PrimaryContact',
        N'FK_Sales_Customers_AlternateContact', N'FK_Sales_Customers_DeliveryMethod',
        N'FK_Sales_Customers_DeliveryCity', N'FK_Sales_Customers_PostalCity',
        N'FK_Purchasing_Suppliers_Category', N'FK_Purchasing_Suppliers_DeliveryMethod',
        N'FK_Purchasing_Suppliers_DeliveryCity', N'FK_Purchasing_Suppliers_PostalCity',
        N'FK_Purchasing_Suppliers_PrimaryContact', N'FK_Purchasing_Suppliers_AlternateContact'
    ) AND (is_disabled = 1 OR is_not_trusted = 1)
)
    THROW 51078, 'Una llave foranea publica esta deshabilitada o no es confiable.', 1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE name IN (
        N'FK_Application_StateProvinces_Country', N'FK_Application_Cities_StateProvince',
        N'FK_Sales_Customers_BillTo', N'FK_Sales_Customers_Category',
        N'FK_Sales_Customers_BuyingGroup', N'FK_Sales_Customers_PrimaryContact',
        N'FK_Sales_Customers_AlternateContact', N'FK_Sales_Customers_DeliveryMethod',
        N'FK_Sales_Customers_DeliveryCity', N'FK_Sales_Customers_PostalCity',
        N'FK_Purchasing_Suppliers_Category', N'FK_Purchasing_Suppliers_DeliveryMethod',
        N'FK_Purchasing_Suppliers_DeliveryCity', N'FK_Purchasing_Suppliers_PostalCity',
        N'FK_Purchasing_Suppliers_PrimaryContact', N'FK_Purchasing_Suppliers_AlternateContact'
    )) <> 16
    THROW 51079, 'Faltan llaves foraneas publicas.', 1;

IF DB_NAME() = N'WideWorldImporters_Corporativo'
BEGIN
    IF OBJECT_ID(N'Sensitive.Customers', N'U') IS NULL OR
       OBJECT_ID(N'Sensitive.Suppliers', N'U') IS NULL OR
       OBJECT_ID(N'Sensitive.People', N'U') IS NULL
        THROW 51080, 'Faltan tablas sensibles en Corporativo.', 1;
    IF EXISTS (
        SELECT 1
        FROM (VALUES
            (N'Sensitive.Customers', N'CustomerID'),
            (N'Sensitive.Customers', N'PhoneNumber'),
            (N'Sensitive.Customers', N'FaxNumber'),
            (N'Sensitive.Customers', N'WebsiteURL'),
            (N'Sensitive.Customers', N'DeliveryAddressLine1'),
            (N'Sensitive.Customers', N'DeliveryAddressLine2'),
            (N'Sensitive.Customers', N'DeliveryPostalCode'),
            (N'Sensitive.Customers', N'DeliveryLocation'),
            (N'Sensitive.Customers', N'PostalAddressLine1'),
            (N'Sensitive.Customers', N'PostalAddressLine2'),
            (N'Sensitive.Customers', N'PostalPostalCode'),
            (N'Sensitive.Suppliers', N'SupplierID'),
            (N'Sensitive.Suppliers', N'PhoneNumber'),
            (N'Sensitive.Suppliers', N'FaxNumber'),
            (N'Sensitive.Suppliers', N'WebsiteURL'),
            (N'Sensitive.Suppliers', N'DeliveryAddressLine1'),
            (N'Sensitive.Suppliers', N'DeliveryAddressLine2'),
            (N'Sensitive.Suppliers', N'DeliveryPostalCode'),
            (N'Sensitive.Suppliers', N'DeliveryLocation'),
            (N'Sensitive.Suppliers', N'PostalAddressLine1'),
            (N'Sensitive.Suppliers', N'PostalAddressLine2'),
            (N'Sensitive.Suppliers', N'PostalPostalCode'),
            (N'Sensitive.Suppliers', N'BankAccountName'),
            (N'Sensitive.Suppliers', N'BankAccountBranch'),
            (N'Sensitive.Suppliers', N'BankAccountCode'),
            (N'Sensitive.Suppliers', N'BankAccountNumber'),
            (N'Sensitive.Suppliers', N'BankInternationalCode'),
            (N'Sensitive.Suppliers', N'InternalComments'),
            (N'Sensitive.People', N'PersonID'),
            (N'Sensitive.People', N'FullName'),
            (N'Sensitive.People', N'PhoneNumber'),
            (N'Sensitive.People', N'FaxNumber'),
            (N'Sensitive.People', N'EmailAddress')
        ) AS Esperadas(Tabla, Columna)
        WHERE COL_LENGTH(Esperadas.Tabla, Esperadas.Columna) IS NULL
    )
        THROW 51084, 'Faltan columnas sensibles de WWI en Corporativo.', 1;
    IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE name IN (
        N'FK_Sensitive_Customers_Public', N'FK_Sensitive_Suppliers_Public',
        N'FK_Sensitive_People_Public')) <> 3
        THROW 51081, 'Faltan llaves de la parte sensible.', 1;
    IF EXISTS (
        SELECT 1 FROM sys.foreign_keys
        WHERE name IN (N'FK_Sensitive_Customers_Public', N'FK_Sensitive_Suppliers_Public',
                       N'FK_Sensitive_People_Public')
          AND (is_disabled = 1 OR is_not_trusted = 1)
    )
        THROW 51085, 'Una llave foranea sensible esta deshabilitada o no es confiable.', 1;
END
ELSE IF EXISTS (SELECT 1 FROM sys.tables WHERE schema_id = SCHEMA_ID(N'Sensitive'))
    THROW 51082, 'Una sucursal contiene tablas sensibles.', 1;

SELECT DB_NAME() AS Nodo,
       (SELECT COUNT(*) FROM Sales.Customers) AS Customers,
       (SELECT COUNT(*) FROM Purchasing.Suppliers) AS Suppliers,
       (SELECT COUNT(*) FROM Application.People) AS People,
       N'CORRECTO' AS EstadoFragmentacion;
