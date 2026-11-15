USE WideWorldImporters_Corporativo;
GO

-- El usuario SQL del login solo ejecuta este procedimiento. La clave simetrica
-- se abre bajo dbo y el hash se compara en la API, nunca se devuelve al navegador.
CREATE OR ALTER PROCEDURE dbo.usp_Api_Login
    @username VARCHAR(50)
WITH EXECUTE AS OWNER
AS
BEGIN
    SET NOCOUNT ON;
    OPEN SYMMETRIC KEY ClaveUsuarios DECRYPTION BY CERTIFICATE CertificadoUsuarios;
    SELECT iduser, username, fullname, active, rol, SucursalID,
           CONVERT(NVARCHAR(300), DecryptByKey([password])) AS hashGuardado
    FROM dbo.Usuarios
    WHERE username = @username;
    CLOSE SYMMETRIC KEY ClaveUsuarios;
END;
GO
