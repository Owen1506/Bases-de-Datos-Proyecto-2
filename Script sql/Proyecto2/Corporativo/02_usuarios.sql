USE WideWorldImporters_Corporativo;
GO

IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Usuarios (
        iduser INT IDENTITY(1,1) PRIMARY KEY,
        username VARCHAR(50) NOT NULL UNIQUE,
        [password] VARBINARY(MAX) NOT NULL,
        fullname VARCHAR(150) NOT NULL,
        active BIT NOT NULL DEFAULT 1,
        rol VARCHAR(20) NOT NULL,
        email VARCHAR(150) NOT NULL,
        hiredate DATE NOT NULL DEFAULT GETDATE(),
        SucursalID INT NULL,

        CONSTRAINT CK_Usuarios_Rol
            CHECK (rol IN ('Administrador', 'Corporativo')),

        CONSTRAINT CK_Usuarios_Sucursal
            CHECK (
                (rol = 'Administrador' AND SucursalID IN (1, 2))
                OR
                (rol = 'Corporativo' AND SucursalID IS NULL)
            )
    );
END;
GO
