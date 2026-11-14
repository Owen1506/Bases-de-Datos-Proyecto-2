-- Columnas publicas de clientes/proveedores y sus referencias.
-- Ejecutar en Corporativo, San Jose y Limon. No carga filas nuevas.
-- Los nombres de tabla y columna de WWI se conservan en la parte publica.
-- SSMS continua tras un THROW si hay GO: cada lote vuelve a comprobar la base.
SET XACT_ABORT ON;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51070, 'Conecte a una de las tres bases del Proyecto 2.', 1;
IF OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL
    THROW 51071, 'Ejecute primero 04_catalogos_referencia.sql.', 1;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF SCHEMA_ID(N'Application') IS NULL EXEC(N'CREATE SCHEMA Application');
IF SCHEMA_ID(N'Sales') IS NULL EXEC(N'CREATE SCHEMA Sales');
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Application.Countries', N'U') IS NULL
    CREATE TABLE Application.Countries (
        CountryID INT NOT NULL CONSTRAINT PK_Application_Countries PRIMARY KEY,
        CountryName NVARCHAR(60) NOT NULL
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Application.StateProvinces', N'U') IS NULL
    CREATE TABLE Application.StateProvinces (
        StateProvinceID INT NOT NULL CONSTRAINT PK_Application_StateProvinces PRIMARY KEY,
        StateProvinceCode NVARCHAR(5) NOT NULL,
        StateProvinceName NVARCHAR(50) NOT NULL,
        CountryID INT NOT NULL,
        CONSTRAINT FK_Application_StateProvinces_Country FOREIGN KEY (CountryID)
            REFERENCES Application.Countries(CountryID)
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Application.Cities', N'U') IS NULL
    CREATE TABLE Application.Cities (
        CityID INT NOT NULL CONSTRAINT PK_Application_Cities PRIMARY KEY,
        CityName NVARCHAR(50) NOT NULL,
        StateProvinceID INT NOT NULL,
        CONSTRAINT FK_Application_Cities_StateProvince FOREIGN KEY (StateProvinceID)
            REFERENCES Application.StateProvinces(StateProvinceID)
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Application.DeliveryMethods', N'U') IS NULL
    CREATE TABLE Application.DeliveryMethods (
        DeliveryMethodID INT NOT NULL CONSTRAINT PK_Application_DeliveryMethods PRIMARY KEY,
        DeliveryMethodName NVARCHAR(50) NOT NULL
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Sales.CustomerCategories', N'U') IS NULL
    CREATE TABLE Sales.CustomerCategories (
        CustomerCategoryID INT NOT NULL CONSTRAINT PK_Sales_CustomerCategories PRIMARY KEY,
        CustomerCategoryName NVARCHAR(50) NOT NULL
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Sales.BuyingGroups', N'U') IS NULL
    CREATE TABLE Sales.BuyingGroups (
        BuyingGroupID INT NOT NULL CONSTRAINT PK_Sales_BuyingGroups PRIMARY KEY,
        BuyingGroupName NVARCHAR(50) NOT NULL
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Purchasing.SupplierCategories', N'U') IS NULL
    CREATE TABLE Purchasing.SupplierCategories (
        SupplierCategoryID INT NOT NULL CONSTRAINT PK_Purchasing_SupplierCategories PRIMARY KEY,
        SupplierCategoryName NVARCHAR(50) NOT NULL
    );
GO

-- Este archivo crea inicialmente solo PersonID. Los nombres de contactos se
-- guardaran en Sensitive.People de Corporativo; vendedores se completan luego.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Application.People', N'U') IS NULL
    CREATE TABLE Application.People (
        PersonID INT NOT NULL CONSTRAINT PK_Application_People PRIMARY KEY
    );
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF OBJECT_ID(N'Sales.Customers', N'U') IS NULL
    CREATE TABLE Sales.Customers (
        CustomerID INT NOT NULL CONSTRAINT PK_Sales_Customers PRIMARY KEY,
        CustomerName NVARCHAR(100) NOT NULL,
        BillToCustomerID INT NOT NULL,
        CustomerCategoryID INT NOT NULL,
        BuyingGroupID INT NULL,
        PrimaryContactPersonID INT NOT NULL,
        AlternateContactPersonID INT NULL,
        DeliveryMethodID INT NOT NULL,
        DeliveryCityID INT NOT NULL,
        PostalCityID INT NOT NULL,
        CreditLimit DECIMAL(18,2) NULL,
        AccountOpenedDate DATE NOT NULL,
        StandardDiscountPercentage DECIMAL(18,3) NOT NULL,
        IsOnCreditHold BIT NOT NULL,
        PaymentDays INT NOT NULL,
        CONSTRAINT FK_Sales_Customers_BillTo FOREIGN KEY (BillToCustomerID)
            REFERENCES Sales.Customers(CustomerID),
        CONSTRAINT FK_Sales_Customers_Category FOREIGN KEY (CustomerCategoryID)
            REFERENCES Sales.CustomerCategories(CustomerCategoryID),
        CONSTRAINT FK_Sales_Customers_BuyingGroup FOREIGN KEY (BuyingGroupID)
            REFERENCES Sales.BuyingGroups(BuyingGroupID),
        CONSTRAINT FK_Sales_Customers_PrimaryContact FOREIGN KEY (PrimaryContactPersonID)
            REFERENCES Application.People(PersonID),
        CONSTRAINT FK_Sales_Customers_AlternateContact FOREIGN KEY (AlternateContactPersonID)
            REFERENCES Application.People(PersonID),
        CONSTRAINT FK_Sales_Customers_DeliveryMethod FOREIGN KEY (DeliveryMethodID)
            REFERENCES Application.DeliveryMethods(DeliveryMethodID),
        CONSTRAINT FK_Sales_Customers_DeliveryCity FOREIGN KEY (DeliveryCityID)
            REFERENCES Application.Cities(CityID),
        CONSTRAINT FK_Sales_Customers_PostalCity FOREIGN KEY (PostalCityID)
            REFERENCES Application.Cities(CityID),
        CONSTRAINT CK_Sales_Customers_PaymentDays CHECK (PaymentDays >= 0)
    );
GO

-- Suppliers ya tiene 15 filas y esta publicado. Se agregan columnas anulables
-- para conservarlas; la carga posterior completara los valores y fijara NOT NULL donde aplique.
-- Pub_Catalogo usa replicate_ddl = 0: ampliar el articulo es trabajo posterior.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF COL_LENGTH(N'Purchasing.Suppliers', N'SupplierCategoryID') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD SupplierCategoryID INT NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'SupplierReference') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD SupplierReference NVARCHAR(20) NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'DeliveryMethodID') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD DeliveryMethodID INT NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'DeliveryCityID') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD DeliveryCityID INT NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'PostalCityID') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD PostalCityID INT NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'PaymentDays') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD PaymentDays INT NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'PrimaryContactPersonID') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD PrimaryContactPersonID INT NULL;
IF COL_LENGTH(N'Purchasing.Suppliers', N'AlternateContactPersonID') IS NULL
    ALTER TABLE Purchasing.Suppliers ADD AlternateContactPersonID INT NULL;
GO

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon') OR OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL RETURN;
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Purchasing_Suppliers_Category')
    ALTER TABLE Purchasing.Suppliers ADD CONSTRAINT FK_Purchasing_Suppliers_Category
        FOREIGN KEY (SupplierCategoryID) REFERENCES Purchasing.SupplierCategories(SupplierCategoryID);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Purchasing_Suppliers_DeliveryMethod')
    ALTER TABLE Purchasing.Suppliers ADD CONSTRAINT FK_Purchasing_Suppliers_DeliveryMethod
        FOREIGN KEY (DeliveryMethodID) REFERENCES Application.DeliveryMethods(DeliveryMethodID);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Purchasing_Suppliers_DeliveryCity')
    ALTER TABLE Purchasing.Suppliers ADD CONSTRAINT FK_Purchasing_Suppliers_DeliveryCity
        FOREIGN KEY (DeliveryCityID) REFERENCES Application.Cities(CityID);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Purchasing_Suppliers_PostalCity')
    ALTER TABLE Purchasing.Suppliers ADD CONSTRAINT FK_Purchasing_Suppliers_PostalCity
        FOREIGN KEY (PostalCityID) REFERENCES Application.Cities(CityID);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Purchasing_Suppliers_PrimaryContact')
    ALTER TABLE Purchasing.Suppliers ADD CONSTRAINT FK_Purchasing_Suppliers_PrimaryContact
        FOREIGN KEY (PrimaryContactPersonID) REFERENCES Application.People(PersonID);
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = N'FK_Purchasing_Suppliers_AlternateContact')
    ALTER TABLE Purchasing.Suppliers ADD CONSTRAINT FK_Purchasing_Suppliers_AlternateContact
        FOREIGN KEY (AlternateContactPersonID) REFERENCES Application.People(PersonID);
GO
