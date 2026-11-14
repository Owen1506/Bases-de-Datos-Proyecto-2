-- Datos privados de clientes, proveedores y personas de contacto.
-- Ejecutar SOLO en Corporativo tras 06_clientes_proveedores_publicos.sql.
-- Estos objetos nunca se publican a San Jose ni a Limon.
SET XACT_ABORT ON;
GO

IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51072, 'Los datos sensibles solo se crean en Corporativo.', 1;
IF OBJECT_ID(N'Sales.Customers', N'U') IS NULL OR
   OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL OR
   OBJECT_ID(N'Application.People', N'U') IS NULL
    THROW 51073, 'Ejecute primero 06_clientes_proveedores_publicos.sql.', 1;
GO

IF SCHEMA_ID(N'Sensitive') IS NULL EXEC(N'CREATE SCHEMA Sensitive');
GO

IF OBJECT_ID(N'Sensitive.Customers', N'U') IS NULL
    CREATE TABLE Sensitive.Customers (
        CustomerID INT NOT NULL CONSTRAINT PK_Sensitive_Customers PRIMARY KEY,
        PhoneNumber NVARCHAR(20) NOT NULL,
        FaxNumber NVARCHAR(20) NOT NULL,
        WebsiteURL NVARCHAR(256) NOT NULL,
        DeliveryAddressLine1 NVARCHAR(60) NOT NULL,
        DeliveryAddressLine2 NVARCHAR(60) NULL,
        DeliveryPostalCode NVARCHAR(10) NOT NULL,
        DeliveryLocation GEOGRAPHY NULL,
        PostalAddressLine1 NVARCHAR(60) NOT NULL,
        PostalAddressLine2 NVARCHAR(60) NULL,
        PostalPostalCode NVARCHAR(10) NOT NULL,
        CONSTRAINT FK_Sensitive_Customers_Public FOREIGN KEY (CustomerID)
            REFERENCES Sales.Customers(CustomerID)
    );
GO

IF OBJECT_ID(N'Sensitive.Suppliers', N'U') IS NULL
    CREATE TABLE Sensitive.Suppliers (
        SupplierID INT NOT NULL CONSTRAINT PK_Sensitive_Suppliers PRIMARY KEY,
        PhoneNumber NVARCHAR(20) NOT NULL,
        FaxNumber NVARCHAR(20) NOT NULL,
        WebsiteURL NVARCHAR(256) NOT NULL,
        DeliveryAddressLine1 NVARCHAR(60) NOT NULL,
        DeliveryAddressLine2 NVARCHAR(60) NULL,
        DeliveryPostalCode NVARCHAR(10) NOT NULL,
        DeliveryLocation GEOGRAPHY NULL,
        PostalAddressLine1 NVARCHAR(60) NOT NULL,
        PostalAddressLine2 NVARCHAR(60) NULL,
        PostalPostalCode NVARCHAR(10) NOT NULL,
        BankAccountName NVARCHAR(50) NULL,
        BankAccountBranch NVARCHAR(50) NULL,
        BankAccountCode NVARCHAR(20) NULL,
        BankAccountNumber NVARCHAR(20) NULL,
        BankInternationalCode NVARCHAR(20) NULL,
        InternalComments NVARCHAR(MAX) NULL,
        CONSTRAINT FK_Sensitive_Suppliers_Public FOREIGN KEY (SupplierID)
            REFERENCES Purchasing.Suppliers(SupplierID)
    );
GO

IF OBJECT_ID(N'Sensitive.People', N'U') IS NULL
    CREATE TABLE Sensitive.People (
        PersonID INT NOT NULL CONSTRAINT PK_Sensitive_People PRIMARY KEY,
        FullName NVARCHAR(50) NOT NULL,
        PhoneNumber NVARCHAR(20) NULL,
        FaxNumber NVARCHAR(20) NULL,
        EmailAddress NVARCHAR(256) NULL,
        CONSTRAINT FK_Sensitive_People_Public FOREIGN KEY (PersonID)
            REFERENCES Application.People(PersonID)
    );
GO

-- Las consultas de cuatro partes no aceptan objetos remotos que expongan
-- geography. Estas vistas mantienen los datos en las tablas originales y
-- exponen las columnas escalares que necesitan las sucursales.
CREATE OR ALTER VIEW Sensitive.CustomersRemote AS
SELECT CustomerID, PhoneNumber, FaxNumber, WebsiteURL,
       DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
       PostalAddressLine1, PostalAddressLine2, PostalPostalCode
FROM Sensitive.Customers;
GO

CREATE OR ALTER VIEW Sensitive.SuppliersRemote AS
SELECT SupplierID, PhoneNumber, FaxNumber, WebsiteURL,
       DeliveryAddressLine1, DeliveryAddressLine2, DeliveryPostalCode,
       PostalAddressLine1, PostalAddressLine2, PostalPostalCode,
       BankAccountName, BankAccountBranch, BankAccountCode,
       BankAccountNumber, BankInternationalCode, InternalComments
FROM Sensitive.Suppliers;
GO
