USE master;
GO

IF DB_ID('WideWorldImporters_SanJose') IS NULL
    EXEC('CREATE DATABASE WideWorldImporters_SanJose');
GO
