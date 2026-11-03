USE WideWorldImporters_Corporativo;
GO

SELECT
    iduser,
    username,
    fullname,
    active,
    rol,
    SucursalID,
    DATALENGTH([password]) AS BytesCifrados
FROM dbo.Usuarios
ORDER BY iduser;
GO

SELECT name AS Certificado
FROM sys.certificates
WHERE name = 'CertificadoUsuarios';

SELECT name AS Clave
FROM sys.symmetric_keys
WHERE name IN ('##MS_DatabaseMasterKey##', 'ClaveUsuarios');
GO

OPEN SYMMETRIC KEY ClaveUsuarios
DECRYPTION BY CERTIFICATE CertificadoUsuarios;

SELECT
    username,
    CASE
        WHEN LEFT(CONVERT(NVARCHAR(300), DecryptByKey([password])), 7) = N'scrypt$'
             AND LEN(CONVERT(NVARCHAR(300), DecryptByKey([password]))) = 168
        THEN 'CORRECTO'
        ELSE 'REVISAR'
    END AS EstadoHash
FROM dbo.Usuarios;

CLOSE SYMMETRIC KEY ClaveUsuarios;
GO
