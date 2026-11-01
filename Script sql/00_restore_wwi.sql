-- =============================================
-- 00_restore_wwi.sql
-- Restaura WideWorldImporters-Full en SQL Server (Linux / Docker)
-- Requiere el .bak en ./backups (montado en /var/opt/mssql/backup)
-- =============================================
USE master;
GO

RESTORE DATABASE WideWorldImporters
FROM DISK = '/var/opt/mssql/backup/WideWorldImporters-Full.bak'
WITH
    MOVE 'WWI_Primary'         TO '/var/opt/mssql/data/WideWorldImporters.mdf',
    MOVE 'WWI_UserData'        TO '/var/opt/mssql/data/WideWorldImporters_UserData.ndf',
    MOVE 'WWI_Log'             TO '/var/opt/mssql/data/WideWorldImporters.ldf',
    MOVE 'WWI_InMemory_Data_1' TO '/var/opt/mssql/data/WideWorldImporters_InMemory_Data_1',
    STATS = 10;
GO
