-- Verificar el esquema y la privacidad de vendedores en cada nodo.
-- Ejecutar despues de 10_vendedores_publicos.sql, sin cargar datos.
IF DB_NAME() NOT IN (N'WideWorldImporters_Corporativo', N'WideWorldImporters_SanJose', N'WideWorldImporters_Limon')
    THROW 51092, 'Conecte a una de las tres bases del Proyecto 2.', 1;
IF OBJECT_ID(N'Application.People', N'U') IS NULL
    THROW 51093, 'Falta Application.People.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'IsSalesperson' AND system_type_id = 104 AND is_nullable = 0
) OR NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'FullName' AND system_type_id = 231 AND max_length = 100 AND is_nullable = 1
) OR NOT EXISTS (
    SELECT 1 FROM sys.columns
    WHERE object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'SucursalID' AND system_type_id = 56 AND is_nullable = 1
)
    THROW 51094, 'Faltan columnas de vendedores o sus tipos no coinciden.', 1;

IF NOT EXISTS (
    SELECT 1 FROM sys.check_constraints
    WHERE parent_object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'CK_Application_People_PublicName'
      AND is_disabled = 0 AND is_not_trusted = 0
)
    THROW 51095, 'Falta la restriccion confiable de nombres publicos.', 1;
IF NOT EXISTS (
    SELECT 1 FROM sys.key_constraints
    WHERE parent_object_id = OBJECT_ID(N'Application.People', N'U')
      AND name = N'UQ_Application_People_Sucursal_Person' AND type = N'UQ'
)
    THROW 51096, 'Falta la clave compuesta para vendedor y sucursal.', 1;

IF EXISTS (
    SELECT 1 FROM Application.People
    WHERE (IsSalesperson = 1 AND (FullName IS NULL OR SucursalID IS NULL OR SucursalID NOT IN (1, 2)))
       OR (IsSalesperson = 0 AND (FullName IS NOT NULL OR SucursalID IS NOT NULL))
)
    THROW 51097, 'Un contacto tiene nombre publico o un vendedor no tiene nombre y sucursal.', 1;

SELECT DB_NAME() AS Nodo,
       COUNT(*) AS Personas,
       COALESCE(SUM(CASE WHEN IsSalesperson = 1 THEN 1 ELSE 0 END), 0) AS Vendedores,
       COALESCE(SUM(CASE WHEN IsSalesperson = 0 THEN 1 ELSE 0 END), 0) AS ContactosSinNombrePublico,
       N'CORRECTO' AS EstadoVendedores
FROM Application.People;
