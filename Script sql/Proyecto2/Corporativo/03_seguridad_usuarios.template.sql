USE WideWorldImporters_Corporativo;
GO

-- Ejecutar solo en una instalacion nueva y desde una copia .local.sql.
-- Sustituir la contraseña de ejemplo y conservarla fuera de Git.
CREATE MASTER KEY
ENCRYPTION BY PASSWORD = 'REEMPLAZAR_CON_CLAVE_SEGURA';
GO

CREATE CERTIFICATE CertificadoUsuarios
WITH SUBJECT = 'Proteccion de credenciales de usuarios';
GO

CREATE SYMMETRIC KEY ClaveUsuarios
WITH ALGORITHM = AES_256
ENCRYPTION BY CERTIFICATE CertificadoUsuarios;
GO
