USE master;
GO

IF DB_ID('WideWorldImporters_Corporativo') IS NULL
    EXEC('CREATE DATABASE WideWorldImporters_Corporativo');
GO
