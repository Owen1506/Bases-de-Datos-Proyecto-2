-- Purchasing.PurchaseOrders y PurchaseOrderLines de cada sucursal.
-- Ejecutar en San Jose (1434) y Limon (1435), despues de los catalogos.
-- Solo crea estructura; el criterio para repartir ordenes se aplicara al cargar datos.
SET XACT_ABORT ON;

IF DB_NAME() NOT IN (N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51110, 'Conecte a la base de San Jose o Limon.', 1;
IF OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL OR
   OBJECT_ID(N'Application.People', N'U') IS NULL OR
   OBJECT_ID(N'Application.DeliveryMethods', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.PackageTypes', N'U') IS NULL
    THROW 51111, 'Faltan catalogos. Ejecute primero los archivos 01, 04 y 06.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'Purchasing.PurchaseOrders', N'U') IS NULL
        CREATE TABLE Purchasing.PurchaseOrders (
            SucursalID INT NOT NULL,
            PurchaseOrderID INT IDENTITY(1,1) NOT NULL,
            SupplierID INT NOT NULL,
            OrderDate DATE NOT NULL,
            DeliveryMethodID INT NOT NULL,
            ContactPersonID INT NOT NULL,
            ExpectedDeliveryDate DATE NULL,
            SupplierReference NVARCHAR(20) NULL,
            IsOrderFinalized BIT NOT NULL,
            Comments NVARCHAR(MAX) NULL,
            InternalComments NVARCHAR(MAX) NULL,
            CONSTRAINT PK_Purchasing_PurchaseOrders PRIMARY KEY (SucursalID, PurchaseOrderID),
            CONSTRAINT FK_Purchasing_PurchaseOrders_Supplier FOREIGN KEY (SupplierID)
                REFERENCES Purchasing.Suppliers(SupplierID),
            CONSTRAINT FK_Purchasing_PurchaseOrders_DeliveryMethod FOREIGN KEY (DeliveryMethodID)
                REFERENCES Application.DeliveryMethods(DeliveryMethodID),
            CONSTRAINT FK_Purchasing_PurchaseOrders_Contact FOREIGN KEY (ContactPersonID)
                REFERENCES Application.People(PersonID)
        );

    IF OBJECT_ID(N'Purchasing.PurchaseOrderLines', N'U') IS NULL
        CREATE TABLE Purchasing.PurchaseOrderLines (
            SucursalID INT NOT NULL,
            PurchaseOrderLineID INT IDENTITY(1,1) NOT NULL,
            PurchaseOrderID INT NOT NULL,
            StockItemID INT NOT NULL,
            OrderedOuters INT NOT NULL,
            Description NVARCHAR(100) NOT NULL,
            ReceivedOuters INT NOT NULL,
            PackageTypeID INT NOT NULL,
            ExpectedUnitPricePerOuter DECIMAL(18,2) NULL,
            LastReceiptDate DATE NULL,
            IsOrderLineFinalized BIT NOT NULL,
            CONSTRAINT PK_Purchasing_PurchaseOrderLines PRIMARY KEY (SucursalID, PurchaseOrderLineID),
            CONSTRAINT FK_Purchasing_PurchaseOrderLines_Order FOREIGN KEY (SucursalID, PurchaseOrderID)
                REFERENCES Purchasing.PurchaseOrders(SucursalID, PurchaseOrderID),
            CONSTRAINT FK_Purchasing_PurchaseOrderLines_StockItem FOREIGN KEY (StockItemID)
                REFERENCES Warehouse.StockItems(StockItemID),
            CONSTRAINT FK_Purchasing_PurchaseOrderLines_PackageType FOREIGN KEY (PackageTypeID)
                REFERENCES Warehouse.PackageTypes(PackageTypeID)
        );

    IF DB_NAME() = N'WideWorldImporters_SanJose'
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Purchasing_PurchaseOrders_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrders WITH CHECK ADD CONSTRAINT CK_Purchasing_PurchaseOrders_SucursalID
                CHECK (SucursalID = 1);
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Purchasing_PurchaseOrderLines_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrderLines WITH CHECK ADD CONSTRAINT CK_Purchasing_PurchaseOrderLines_SucursalID
                CHECK (SucursalID = 1);
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Purchasing_PurchaseOrders_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrders ADD CONSTRAINT DF_Purchasing_PurchaseOrders_SucursalID DEFAULT (1) FOR SucursalID;
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Purchasing_PurchaseOrderLines_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrderLines ADD CONSTRAINT DF_Purchasing_PurchaseOrderLines_SucursalID DEFAULT (1) FOR SucursalID;
    END
    ELSE
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Purchasing_PurchaseOrders_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrders WITH CHECK ADD CONSTRAINT CK_Purchasing_PurchaseOrders_SucursalID
                CHECK (SucursalID = 2);
        IF NOT EXISTS (SELECT 1 FROM sys.check_constraints WHERE name = N'CK_Purchasing_PurchaseOrderLines_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrderLines WITH CHECK ADD CONSTRAINT CK_Purchasing_PurchaseOrderLines_SucursalID
                CHECK (SucursalID = 2);
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Purchasing_PurchaseOrders_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrders ADD CONSTRAINT DF_Purchasing_PurchaseOrders_SucursalID DEFAULT (2) FOR SucursalID;
        IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Purchasing_PurchaseOrderLines_SucursalID')
            ALTER TABLE Purchasing.PurchaseOrderLines ADD CONSTRAINT DF_Purchasing_PurchaseOrderLines_SucursalID DEFAULT (2) FOR SucursalID;
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
