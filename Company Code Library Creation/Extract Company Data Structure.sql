USE master
GO

/*
DESCRIPTION: 
	This loops through each DB on a given server, and extracts all table names, objects, and data types. It also attempts to infer who owns what, but that will need work down the road. 
AUTHOR:
	Adam Cazes
*/

DECLARE @DatabaseName VARCHAR(100)
DECLARE @SQL NVARCHAR(MAX)

IF OBJECT_ID('Sandbox2.dbo.RPT01DataStructure') IS NOT NULL
    DROP TABLE Sandbox2.dbo.RPT01DataStructure

CREATE TABLE Sandbox2.dbo.RPT01DataStructure (
    DatabaseName VARCHAR(100),
    SchemaName VARCHAR(100),
    TableName VARCHAR(100),
    FieldName VARCHAR(100),
    FieldType VARCHAR(50),
    ObjectType VARCHAR(20), -- table or view
    Owner VARCHAR(50),
    MaintainedBy VARCHAR(50)
)

DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases WHERE name NOT IN ('master', 'tempdb', 'model', 'msdb', 'ReportServer', 'ReportServerTempDB', 'HIQ', 'DLProd', 'SSISDB', 'DBAConsole', 'Flinks')
and create_date > '1/1/2004'

OPEN db_cursor

FETCH NEXT FROM db_cursor INTO @DatabaseName

WHILE @@FETCH_STATUS = 0
BEGIN
	--V1
    --SET @SQL = 'USE ' + QUOTENAME(@DatabaseName) + '; '
    --SET @SQL = @SQL + 'INSERT INTO Sandbox2.dbo.RPT01DataStructure (DatabaseName, SchemaName, TableName, FieldName, FieldType) '
    --SET @SQL = @SQL + 'SELECT '''+ @DatabaseName +''' AS DatabaseName, '
    --SET @SQL = @SQL + 's.name AS SchemaName, '
    --SET @SQL = @SQL + 't.name AS TableName, '
    --SET @SQL = @SQL + 'c.name AS FieldName, '
    --SET @SQL = @SQL + 'TYPE_NAME(c.user_type_id) AS FieldType '
    --SET @SQL = @SQL + 'FROM sys.tables t '
    --SET @SQL = @SQL + 'INNER JOIN sys.columns c ON t.object_id = c.object_id '
    --SET @SQL = @SQL + 'INNER JOIN sys.schemas s ON t.schema_id = s.schema_id '
    --SET @SQL = @SQL + 'ORDER BY s.name, t.name, c.column_id'

	--For QA:
	--DECLARE @DatabaseName VARCHAR(100) = 'LeadEnvy'
	--DECLARE @SQL NVARCHAR(MAX)

	SET @SQL = 'USE ' + QUOTENAME(@DatabaseName) + '; '
	SET @SQL = @SQL + 'INSERT INTO Sandbox2.dbo.RPT01DataStructure (DatabaseName, SchemaName, TableName, FieldName, FieldType, ObjectType) '
	SET @SQL = @SQL + 'SELECT ''' + @DatabaseName + ''' AS DatabaseName, '
	SET @SQL = @SQL + 's.name AS SchemaName, '
	SET @SQL = @SQL + 't.name AS TableName, '
	SET @SQL = @SQL + 'c.name AS FieldName, '
	SET @SQL = @SQL + 'TYPE_NAME(c.user_type_id) AS FieldType, '
	SET @SQL = @SQL + '''Table'' AS ObjectType ' -- Set ObjectType as 'Table' for tables

	-- Query tables
	SET @SQL = @SQL + 'FROM sys.tables t '
	SET @SQL = @SQL + 'INNER JOIN sys.columns c ON t.object_id = c.object_id '
	SET @SQL = @SQL + 'INNER JOIN sys.schemas s ON t.schema_id = s.schema_id '

	SET @SQL = @SQL + 'UNION ALL '

	-- Query views
	SET @SQL = @SQL + 'SELECT ''' + @DatabaseName + ''' AS DatabaseName, '
	SET @SQL = @SQL + 's.name AS SchemaName, '
	SET @SQL = @SQL + 'v.name AS TableName, '
	SET @SQL = @SQL + 'c.name AS FieldName, ' -- No field name for views
	SET @SQL = @SQL + 'TYPE_NAME(c.user_type_id) AS FieldType, '
	SET @SQL = @SQL + '''View'' AS ObjectType ' -- Set ObjectType as 'View' for views
	SET @SQL = @SQL + 'FROM sys.views v '
	SET @SQL = @SQL + 'INNER JOIN sys.columns c ON v.object_id = c.object_id '
	SET @SQL = @SQL + 'INNER JOIN sys.schemas s ON v.schema_id = s.schema_id '

	SET @SQL = @SQL + 'ORDER BY SchemaName, TableName'

	--print @SQL 
    EXEC sp_executesql @SQL

    FETCH NEXT FROM db_cursor INTO @DatabaseName
END

CLOSE db_cursor
DEALLOCATE db_cursor

--Alter table Sandbox2.dbo.RPT01DataStructure add SchemaName varchar(50)

select * from Sandbox2.dbo.RPT01DataStructure
where ObjectType = 'View'

select distinct DatabaseName, owner, maintainedby from Sandbox2.dbo.RPT01DataStructure
order by databasename, tablename--, fieldname

UPDATE Sandbox2.dbo.RPT01DataStructure
	SET Owner = CASE when DatabaseName = 'CSIDW' then 'Jose Salinas'
					 when DatabaseName = 'Analytics' then 'Kris Martens (copied from APP01)'
					 when DatabaseName = 'DataRobot' then 'Adam Cazes'
					 when DatabaseName in ('DataStudy','FraudSpider') then 'Jeremy Jones'
					 when DatabaseName = 'Epic' then 'Jose Salinas'
					 when DatabaseName IN ('LeadEnvy','LeadEnvy_Archives') then 'Jose Salinas'
					 when DatabaseName = 'Models' then 'Charles Sharp'
					 when DatabaseName = 'ReportDataMarts' then 'Justin Green'
					 When SchemaName <> 'dbo' then 'user - '+SchemaName
					 else 'TBD' END
	From Sandbox2.dbo.RPT01DataStructure

UPDATE Sandbox2.dbo.RPT01DataStructure
	SET MaintainedBy = CASE when DatabaseName not in ('Sandbox', 'Sandbox2') then 'Justin Green'
					 when DatabaseName = 'Analytics' then 'Justin Green'
					 when DatabaseName = 'DataRobot' then 'Justin Green'
					 when DatabaseName = 'Epic' then 'Justin Green'
					 When SchemaName <> 'dbo' then 'user - '+SchemaName
					 else 'TBD' END
	From Sandbox2.dbo.RPT01DataStructure



-------------------------------------------------------
--Analysis/QA:
-------------------------------------------------------
--Renam and Migrate:
	--select * into #temp from Sandbox2.dbo.RPT01DataStructure

	--drop table Sandbox2.dbo.RPT01DataStructure

	--select 'RPT01' as Server, t.* into Sandbox2.dbo.RPT01DataStructure from #temp t

	--select * from Sandbox2.dbo.RPT01DataStructure


SELECT 
    o.name AS table_name, 
    u.name AS creator_name, 
    o.create_date AS create_date 
FROM sys.objects o 
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
INNER JOIN sys.database_principals u ON s.principal_id = u.principal_id 

WHERE o.type = 'U' -- U = user-defined table
AND o.name = 'your_table_name' -- replace with your table name

select * FROM sys.objects o
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
INNER JOIN sys.database_principals u ON s.principal_id = u.principal_id 



USE [LeadEnvy]; 

INSERT INTO Sandbox2.dbo.RPT01DataStructure (DatabaseName, SchemaName, TableName, FieldName, FieldType, ObjectType) 
SELECT 'LeadEnvy' AS DatabaseName, s.name AS SchemaName, t.name AS TableName, c.name AS FieldName, TYPE_NAME(c.user_type_id) AS FieldType, 'Table' AS ObjectType 
FROM sys.tables t 
INNER JOIN sys.columns c ON t.object_id = c.object_id 
INNER JOIN sys.schemas s ON t.schema_id = s.schema_id 

UNION ALL 

SELECT 'LeadEnvy' AS DatabaseName, s.name AS SchemaName, v.name AS TableName, c.name AS FieldName, TYPE_NAME(c.user_type_id) AS FieldType, 'View' AS ObjectType
FROM sys.views v 
INNER JOIN sys.columns c ON v.object_id = c.object_id 
INNER JOIN sys.schemas s ON v.schema_id = s.schema_id 

ORDER BY SchemaName, TableName
