-- Completar Application.People con los vendedores publicos de WWI.
-- Ejecutar en Corporativo, San Jose y Limon, conectado a la base correcta.
-- No inserta personas ni asigna vendedores; los datos se cargaran despues.
-- Una persona no vendedora conserva su FullName solo en Sensitive.People.
SET XACT_ABORT ON;

IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51090, 'Conecte a una de las tres bases del Proyecto 2.', 1;
IF OBJECT_ID(N'Application.People', N'U') IS NULL
    THROW 51091, 'Ejecute primero 06_clientes_proveedores_publicos.sql.', 1;

BEGIN TRY
    BEGIN TRANSACTION;

-- Los nombres FullName e IsSalesperson provienen de WWI. SucursalID es la
-- columna adicional del proyecto: 1 = San Jose, 2 = Limon, NULL = contacto.
-- El valor 0 conserva las personas ya existentes como contactos sin nombre publico.
IF COL_LENGTH(N'Application.People', N'IsSalesperson') IS NULL
    EXEC(N'ALTER TABLE Application.People ADD IsSalesperson BIT NOT NULL
        CONSTRAINT DF_Application_People_IsSalesperson DEFAULT (0) WITH VALUES;');
IF COL_LENGTH(N'Application.People', N'FullName') IS NULL
    EXEC(N'ALTER TABLE Application.People ADD FullName NVARCHAR(50) NULL;');
IF COL_LENGTH(N'Application.People', N'SucursalID') IS NULL
    EXEC(N'ALTER TABLE Application.People ADD SucursalID INT NULL;');

-- Una persona puede aparecer como vendedor solo si tiene nombre y sucursal.
-- Los demas contactos conservan nombre y datos privados en Corporativo.
IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'CK_Application_People_PublicName'
)
    EXEC(N'ALTER TABLE Application.People WITH CHECK ADD
        CONSTRAINT CK_Application_People_PublicName CHECK (
            (IsSalesperson = 1 AND FullName IS NOT NULL
                AND SucursalID IS NOT NULL AND SucursalID IN (1, 2))
            OR (IsSalesperson = 0 AND FullName IS NULL AND SucursalID IS NULL)
        );');

-- Esta clave permite a Sales.Invoices validar despues vendedor y sucursal
-- juntos mediante una llave foranea compuesta.
IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'UQ_Application_People_Sucursal_Person'
)
    EXEC(N'ALTER TABLE Application.People ADD
        CONSTRAINT UQ_Application_People_Sucursal_Person UNIQUE (SucursalID, PersonID);');

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
