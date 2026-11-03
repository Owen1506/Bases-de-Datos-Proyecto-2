USE master;
GO

IF DB_ID('WideWorldImporters_Limon') IS NULL
    EXEC('CREATE DATABASE WideWorldImporters_Limon');
GO
