-- 00_verificar_nodo.sql
-- Revisa que un nodo esté listo para la replicación. Se ejecuta en cualquiera de los tres nodos.
-- Servidor y NombreHost deben ser iguales (la replicación se conecta por nombre de servidor)
-- y el Agent debe estar activo (ejecuta los agentes de la replicación).
SELECT
    @@SERVERNAME AS Servidor,
    CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) AS NombreHost,
    CASE
        WHEN @@SERVERNAME = CAST(SERVERPROPERTY('MachineName') AS NVARCHAR(128)) THEN 'Correcto'
        ELSE 'Revisar'
    END AS NombreServidor,
    CASE
        WHEN EXISTS (SELECT 1 FROM sys.dm_exec_sessions WHERE program_name LIKE N'SQLAgent%') THEN 'Activo'
        ELSE 'Detenido'
    END AS Agent;
GO
