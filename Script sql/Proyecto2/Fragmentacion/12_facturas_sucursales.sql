-- Sales.Invoices y Sales.InvoiceLines propias de cada sucursal.
-- Ejecutar en San Jose (1434) y Limon (1435), despues de 10_vendedores_publicos.sql.
-- Solo crea estructura. Las facturas se cargaran segun el vendedor asignado.
SET XACT_ABORT ON;

IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51100, 'Conecte a la base de San Jose o Limon.', 1;
IF OBJECT_ID(N'Sales.Customers', N'U') IS NULL OR
   OBJECT_ID(N'Application.People', N'U') IS NULL OR
   COL_LENGTH(N'Application.People', N'SucursalID') IS NULL OR
   OBJECT_ID(N'Application.DeliveryMethods', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.PackageTypes', N'U') IS NULL OR
   NOT EXISTS (SELECT 1 FROM sys.key_constraints
               WHERE parent_object_id = OBJECT_ID(N'Application.People', N'U')
                 AND name = N'UQ_Application_People_Sucursal_Person')
    THROW 51101, 'Faltan catalogos o vendedores. Ejecute primero los archivos 01, 04, 06 y 10.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'Sales.Invoices', N'U') IS NULL
        CREATE TABLE Sales.Invoices (
            SucursalID INT NOT NULL,
            InvoiceID INT IDENTITY(1,1) NOT NULL,
            CustomerID INT NOT NULL,
            BillToCustomerID INT NOT NULL,
            OrderID INT NULL,
            DeliveryMethodID INT NOT NULL,
            ContactPersonID INT NOT NULL,
            AccountsPersonID INT NOT NULL,
            SalespersonPersonID INT NOT NULL,
            PackedByPersonID INT NOT NULL,
            InvoiceDate DATE NOT NULL,
            CustomerPurchaseOrderNumber NVARCHAR(20) NULL,
            IsCreditNote BIT NOT NULL,
            CreditNoteReason NVARCHAR(MAX) NULL,
            Comments NVARCHAR(MAX) NULL,
            DeliveryInstructions NVARCHAR(MAX) NULL,
            InternalComments NVARCHAR(MAX) NULL,
            TotalDryItems INT NOT NULL,
            TotalChillerItems INT NOT NULL,
            DeliveryRun NVARCHAR(5) NULL,
            RunPosition NVARCHAR(5) NULL,
            ReturnedDeliveryData NVARCHAR(MAX) NULL,
            CONSTRAINT PK_Sales_Invoices PRIMARY KEY (SucursalID, InvoiceID),
            CONSTRAINT FK_Sales_Invoices_Customer FOREIGN KEY (CustomerID)
                REFERENCES Sales.Customers(CustomerID),
            CONSTRAINT FK_Sales_Invoices_BillToCustomer FOREIGN KEY (BillToCustomerID)
                REFERENCES Sales.Customers(CustomerID),
            CONSTRAINT FK_Sales_Invoices_DeliveryMethod FOREIGN KEY (DeliveryMethodID)
                REFERENCES Application.DeliveryMethods(DeliveryMethodID),
            CONSTRAINT FK_Sales_Invoices_Contact FOREIGN KEY (ContactPersonID)
                REFERENCES Application.People(PersonID),
            CONSTRAINT FK_Sales_Invoices_Accounts FOREIGN KEY (AccountsPersonID)
                REFERENCES Application.People(PersonID),
            CONSTRAINT FK_Sales_Invoices_Salesperson FOREIGN KEY (SucursalID, SalespersonPersonID)
                REFERENCES Application.People(SucursalID, PersonID),
            CONSTRAINT FK_Sales_Invoices_PackedBy FOREIGN KEY (PackedByPersonID)
                REFERENCES Application.People(PersonID),
            CONSTRAINT CK_Sales_Invoices_ReturnedDeliveryData CHECK
                (ReturnedDeliveryData IS NULL OR ISJSON(ReturnedDeliveryData) = 1)
        );

    IF OBJECT_ID(N'Sales.InvoiceLines', N'U') IS NULL
        CREATE TABLE Sales.InvoiceLines (
            SucursalID INT NOT NULL,
            InvoiceLineID INT IDENTITY(1,1) NOT NULL,
            InvoiceID INT NOT NULL,
            StockItemID INT NOT NULL,
            Description NVARCHAR(100) NOT NULL,
            PackageTypeID INT NOT NULL,
            Quantity INT NOT NULL,
            UnitPrice DECIMAL(18,2) NULL,
            TaxRate DECIMAL(18,3) NOT NULL,
            TaxAmount DECIMAL(18,2) NOT NULL,
            LineProfit DECIMAL(18,2) NOT NULL,
            ExtendedPrice DECIMAL(18,2) NOT NULL,
            CONSTRAINT PK_Sales_InvoiceLines PRIMARY KEY (SucursalID, InvoiceLineID),
            CONSTRAINT FK_Sales_InvoiceLines_Invoice FOREIGN KEY (SucursalID, InvoiceID)
                REFERENCES Sales.Invoices(SucursalID, InvoiceID),
            CONSTRAINT FK_Sales_InvoiceLines_StockItem FOREIGN KEY (StockItemID)
                REFERENCES Warehouse.StockItems(StockItemID),
            CONSTRAINT FK_Sales_InvoiceLines_PackageType FOREIGN KEY (PackageTypeID)
                REFERENCES Warehouse.PackageTypes(PackageTypeID)
        );

    -- Los IDs 1 y 2 se decidieron para San Jose y Limon. Los predicados
    -- separados dejan clara la propiedad horizontal de cada tabla.
    IF DB_NAME() = N'WideWorldImporters_SanJose'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Sales_Invoices_SucursalID')
            ALTER TABLE Sales.Invoices WITH CHECK ADD CONSTRAINT CK_Sales_Invoices_SucursalID
                CHECK (SucursalID = 1);
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Sales_InvoiceLines_SucursalID')
            ALTER TABLE Sales.InvoiceLines WITH CHECK ADD CONSTRAINT CK_Sales_InvoiceLines_SucursalID
                CHECK (SucursalID = 1);
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Sales_Invoices_SucursalID')
            ALTER TABLE Sales.Invoices ADD CONSTRAINT DF_Sales_Invoices_SucursalID DEFAULT (1) FOR SucursalID;
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Sales_InvoiceLines_SucursalID')
            ALTER TABLE Sales.InvoiceLines ADD CONSTRAINT DF_Sales_InvoiceLines_SucursalID DEFAULT (1) FOR SucursalID;
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Sales_Invoices_SucursalID')
            ALTER TABLE Sales.Invoices WITH CHECK ADD CONSTRAINT CK_Sales_Invoices_SucursalID
                CHECK (SucursalID = 2);
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Sales_InvoiceLines_SucursalID')
            ALTER TABLE Sales.InvoiceLines WITH CHECK ADD CONSTRAINT CK_Sales_InvoiceLines_SucursalID
                CHECK (SucursalID = 2);
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Sales_Invoices_SucursalID')
            ALTER TABLE Sales.Invoices ADD CONSTRAINT DF_Sales_Invoices_SucursalID DEFAULT (2) FOR SucursalID;
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Sales_InvoiceLines_SucursalID')
            ALTER TABLE Sales.InvoiceLines ADD CONSTRAINT DF_Sales_InvoiceLines_SucursalID DEFAULT (2) FOR SucursalID;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
