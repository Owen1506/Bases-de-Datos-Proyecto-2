-- Copia consolidada de ordenes de compra y lineas en Corporativo.
-- Ejecutar solo en Corporativo despues de crear los catalogos.
-- Solo estructura, sin insertar ordenes.
SET XACT_ABORT ON;

IF DB_NAME() <> N'WideWorldImporters_Corporativo'
    THROW 51112, 'Conecte a WideWorldImporters_Corporativo.', 1;
IF OBJECT_ID(N'Purchasing.Suppliers', N'U') IS NULL OR
   OBJECT_ID(N'Application.People', N'U') IS NULL OR
   OBJECT_ID(N'Application.DeliveryMethods', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.StockItems', N'U') IS NULL OR
   OBJECT_ID(N'Warehouse.PackageTypes', N'U') IS NULL
    THROW 51113, 'Faltan catalogos. Ejecute primero los archivos 01, 04 y 06.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

    IF OBJECT_ID(N'Purchasing.PurchaseOrders', N'U') IS NULL
        CREATE TABLE Purchasing.PurchaseOrders (
            SucursalID INT NOT NULL,
            PurchaseOrderID INT NOT NULL,
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
            CONSTRAINT CK_Purchasing_PurchaseOrders_SucursalID CHECK (SucursalID IN (1, 2)),
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
            PurchaseOrderLineID INT NOT NULL,
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
            CONSTRAINT CK_Purchasing_PurchaseOrderLines_SucursalID CHECK (SucursalID IN (1, 2)),
            CONSTRAINT FK_Purchasing_PurchaseOrderLines_Order FOREIGN KEY (SucursalID, PurchaseOrderID)
                REFERENCES Purchasing.PurchaseOrders(SucursalID, PurchaseOrderID),
            CONSTRAINT FK_Purchasing_PurchaseOrderLines_StockItem FOREIGN KEY (StockItemID)
                REFERENCES Warehouse.StockItems(StockItemID),
            CONSTRAINT FK_Purchasing_PurchaseOrderLines_PackageType FOREIGN KEY (PackageTypeID)
                REFERENCES Warehouse.PackageTypes(PackageTypeID)
        );

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
