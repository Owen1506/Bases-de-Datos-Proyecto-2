USE WideWorldImporters_Corporativo;
GO

-- Sustituir estos valores por hashes scrypt generados con Node.js en una
-- copia .local.sql. No almacenar contraseñas ni hashes reales en Git.
DECLARE @HashSJ NVARCHAR(300) = N'HASH_ADMIN_SJ';
DECLARE @HashLimon NVARCHAR(300) = N'HASH_ADMIN_LIMON';
DECLARE @HashGerente NVARCHAR(300) = N'HASH_GERENTE';

IF LEFT(@HashSJ, 7) <> N'scrypt$'
   OR LEN(@HashSJ) <> 168
   OR LEFT(@HashLimon, 7) <> N'scrypt$'
   OR LEN(@HashLimon) <> 168
   OR LEFT(@HashGerente, 7) <> N'scrypt$'
   OR LEN(@HashGerente) <> 168
BEGIN
    THROW 50001, 'Los hashes no tienen el formato esperado.', 1;
END;

OPEN SYMMETRIC KEY ClaveUsuarios
DECRYPTION BY CERTIFICATE CertificadoUsuarios;

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE username = 'admin_sj')
BEGIN
    INSERT INTO dbo.Usuarios (username, [password], fullname, rol, email, SucursalID)
    VALUES (
        'admin_sj',
        EncryptByKey(Key_GUID('ClaveUsuarios'), @HashSJ),
        'Administrador San José',
        'Administrador',
        'admin_sj@ejemplo.com',
        1
    );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE username = 'admin_limon')
BEGIN
    INSERT INTO dbo.Usuarios (username, [password], fullname, rol, email, SucursalID)
    VALUES (
        'admin_limon',
        EncryptByKey(Key_GUID('ClaveUsuarios'), @HashLimon),
        'Administrador Limón',
        'Administrador',
        'admin_limon@ejemplo.com',
        2
    );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE username = 'gerente')
BEGIN
    INSERT INTO dbo.Usuarios (username, [password], fullname, rol, email, SucursalID)
    VALUES (
        'gerente',
        EncryptByKey(Key_GUID('ClaveUsuarios'), @HashGerente),
        'Gerente Corporativo',
        'Corporativo',
        'gerente@ejemplo.com',
        NULL
    );
END;

CLOSE SYMMETRIC KEY ClaveUsuarios;
GO
