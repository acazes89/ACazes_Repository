

	CREATE PROCEDURE AutomatedQA_TableComp_JoinSpecific
		@DBName_A varchar(50),
		@SchemaName_A varchar(50),
		@TableName_A varchar(100),
		@DBName_B varchar(50) = 'tempdb',		 --default val
		@SchemaName_B varchar(50) = 'dbo',		 --default val
		@TableName_B varchar(100) = '#placeholder', --default val
		@JoinField1 varchar(100) = 'placeholder', --default val
		@JoinField2 varchar(100) = 'unspecified', --default val
		@JoinField3 varchar(100) = 'unspecified', --default val
		@Join1_Operator varchar(3) = '=',
		@Join2_Operator varchar(3) = '=',
		@Join3_Operator varchar(3) = '=',
		@JoinType varchar(25) = 'inner',
		@CalcNumExactMatchesYorN varchar(1) = 'N',
		@FraudSpiderVarsOnly varchar(1) = 'N',
		@IncludeFieldsList NVARCHAR(MAX) = 'unspecified', --default val
		@OmitFieldsList NVARCHAR(MAX) = 'unspecified'
		--@RandomSample numeric(4,3) = 1.0  --add later

	AS

	BEGIN

/*
	--PROJECT: Automated QA - Table Comparison and Summarization Tool
	--AUTHOR: Adam Cazes
	--OVERVIEW:
		--Based on the table name given by the user, this extracts the fields and summarizes the data within them, and then (if desired) compares those values to the values of the same name in the second given table. 
	--INSTRUCTIONS:
		--execute this sproc, with the parameters you care about specified. A minimum of one table (DB, schema, name) must be specified, all others are optional. 
		--refresh the excel report.
		--See sharepoint page for a more detailed walkthrough.
	--TABLE STRUCTURE:
		--temp_AutomatedQA_Tables: records tables being compared and high level metrics. CopmarisionID from this runs everything else
		--temp_AutomatedQA_Fields: Extracts all fields and datatypes from TableA and TableB recorded in "Tables".
		--temp_AutomatedQA_CategoricalSummary: All categorical fields (all text string fields that mostly fail a conversion) AND one row per distinct value for those fields. Rows that represent less than 0.1% of the population are removed to keep the table from accidentally blowing up. 
		--temp_AutomatedQA_CategoricalComparison: Distribution comparison between the two tables for each field
		--temp_AutomatedQA_NumericalSummary: Numeric fields summarized
		--temp_AutomatedQA_NumericalSummary: Numeric fields compared. 
		
		I'll probably add a seventh table for an optional numeric distribution at some point.

		


	--CHANGE LOG:
		--added the @SQL_tblcopy section. Basically, to avoid having to change too much, The table specified in the parameters is added to "ParentTable", and the fixed temp table names are always inserted and used throughout the rest of the sproc
		--added "IsMasked" check in fields. These are then omitted in the exact match section. 
		--added Is FraudSpider paramter and check in fields. 
		--started off with the ExactMatches existing on the comparison tables, so you could see it in the excel charts. Issue was that you needed info from the fields table, plus there were dupe rows in categorical comp due to each value having a row, so I moved the column to the fields table
		--added comparisonID to the join between temp_AutomatedQA_Fields within the @ColumnsEM query. Think this was the culprit for returning multiple results whe it was only based on name. It would be safer to do some kind of distinct CommonFieldID. 
		--Changed @ColumnsEM to go in order for qa purposes. 
		--Adding check to see if there are numerics formatted as text. This involved:
			--adding columns to catsummary table to count rows that can be casted to date or float
			--this required changing that query to be dependent on datatype. Try_cast throws an error when you run it on tinyint, so I couldn't make DatasourceID work within the existing query. 
			--I ignored all flavors of null for these flags. I then added a section that changed the datatype if the percentage of successful castings was over 50%
		--Added an Omit list and changed specific fields list to "IncludeFieldsList"
		--changed numeric precision in NumComp from 12 to 25 and added a where max must be less than a thousand trillion clause. Float can only have 15 prec so it was causing overflow. 
*/

		DECLARE @FieldsTable table (FieldName NVARCHAR(100)) 
		INSERT INTO @FieldsTable (FieldName)
		SELECT value FROM STRING_SPLIT(@IncludeFieldsList, ',');

		DECLARE @OmitFieldsTable table (FieldName NVARCHAR(100)) 
		INSERT INTO @OmitFieldsTable (FieldName)
		SELECT value FROM STRING_SPLIT(@OmitFieldsList, ',');

		IF @TableName_B = '#placeholder'
		BEGIN
			SELECT 'placeholder' as 'placeholder'
			into #placeholder
		END


	--for qa (of this)
		--DECLARE @DBName_A varchar(50)
		--DECLARE @SchemaName_A varchar(50)
		--DECLARE @TableName_A varchar(100)
		--DECLARE @DBName_B varchar(50)
		--DECLARE @SchemaName_B varchar(50)
		--DECLARE @TableName_B varchar(100)
		--DECLARE @JoinField1 varchar(100)
		--DECLARE @JoinField2 varchar(100) = 'unspecified' --default val
		--DECLARE @JoinField3 varchar(100) = 'unspecified' --default val
		--DECLARE @Join1_Operator varchar(3) = '='
		--DECLARE @Join2_Operator varchar(3) = '='
		--DECLARE @Join3_Operator varchar(3) = '='
		--DECLARE @JoinType varchar(25) = 'inner'
		--DECLARE @CalcNumExactMatchesYorN varchar(1) = 'N'


		--SET @DBName_A = 'Sandbox'
		--SET @SchemaName_A = 'dbo'
		--SET @TableName_A = 'PrescreenScore2_v2_ModelUpdateData_full'
		--SET @DBName_B = 'LeadEnvy'
		--SET @SchemaName_B = 'dbo'
		--SET @TableName_B = 'CsiDataRobotPrescreen2v2Outcomes' 
		--SET @JoinField1 = 'LeadID'
		--SET @Join1_Operator = '='
		--SET @JoinField2 = 'DataSourceID'
		--SET @Join2_Operator = '='
		--SET @JoinType = 'inner'
		--SET @CalcNumExactMatchesYorN = 'Y';

  --Table Build:
	--DROP TABLE Sandbox2.adc.temp_AutomatedQA_Tables
	--CREATE TABLE Sandbox2.adc.temp_AutomatedQA_Tables
	--(RunDate datetime,
	-- ComparisonID int identity(1,1), 
	-- TableA_DB varchar(50),
	-- TableA_Schema varchar(25),
	-- TableA varchar(100),
	-- TableA_Rows int,
	-- TableA_NullRows int,
	-- TableA_NullColumns int,
	-- TableB_DB varchar(50),
	-- TableB_Schema varchar(25),
	-- TableB varchar(100),
	-- TableB_Rows int,
	-- TableB_NullRows int,
	-- TableB_NullColumns int,
	-- InA_MissingFromB int,
	-- InB_MissingFromA int,
	-- ParentTableA varchar(250),
	-- ParentTableB varchar(250))

  --For Troubleshooting:
	--insert into Sandbox2.adc.temp_AutomatedQA_Tables
	-- (Rundate, TableA_DB, TableA_Schema, TableA, TableB_DB, TableB_Schema, TableB)
	-- values
	-- (getdate(), 'Sandbox2', 'adc', 'temp_PS1comp_Training_120123', 'Sandbox2', 'adc', 'temp_PS1comp_LE_120123'
	-- )

--WRITE TO SUBSET TABLE
	--this is in the more advanced version only. We need to do this in order to make some transformations to the data. 

IF OBJECT_ID('Sandbox2.dbo.temp_AutomatedQA_TableA') IS NOT NULL
    DROP TABLE Sandbox2.dbo.temp_AutomatedQA_TableA
IF OBJECT_ID('Sandbox2.dbo.temp_AutomatedQA_TableB') IS NOT NULL
    DROP TABLE Sandbox2.dbo.temp_AutomatedQA_TableB

--TABLE A INSERT
	DECLARE @SQL_tblcopy nvarchar(max)
	SET @SQL_tblcopy = CASE when @TableName_B = '#placeholder' THEN 
		'Select a.*
		into Sandbox2.dbo.temp_AutomatedQA_TableA
		From '+@DBName_A+'.'+@SchemaName_A+'.'+@TableName_A+' a'
	ELSE
	'Select a.*
	into Sandbox2.dbo.temp_AutomatedQA_TableA
	From '+@DBName_A+'.'+@SchemaName_A+'.'+@TableName_A+' a
	'+@JoinType+' join '+@DBName_B+'.'+@SchemaName_B+'.'+@TableName_B+' b on
	a.'+@JoinField1 + @Join1_Operator + 'b.' + @JoinField1 + 
		(CASE when @JoinField2 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField2 + @Join2_Operator + 'b.'+@JoinField2 END) +
		(CASE when @JoinField3 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField3 + @Join3_Operator + 'b.'+@JoinField3 END) +''
	END
	PRINT @SQL_tblcopy
	EXEC sp_executesql @Sql_tblcopy
--TABLE B INSERT
	SET @SQL_tblcopy = CASE when @TableName_B = '#placeholder' THEN 
		'Select b.*
		into Sandbox2.dbo.temp_AutomatedQA_TableB
		From '+@DBName_B+'.'+@SchemaName_B+'.'+@TableName_B+' b' 
	ELSE 
	'Select b.*
	into Sandbox2.dbo.temp_AutomatedQA_TableB
	From '+@DBName_B+'.'+@SchemaName_B+'.'+@TableName_B+' b
	'+@JoinType+' join '+@DBName_A+'.'+@SchemaName_A+'.'+@TableName_A+' a on
	a.'+@JoinField1 + @Join1_Operator + 'b.' + @JoinField1 + 
		(CASE when @JoinField2 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField2 + @Join2_Operator + 'b.'+@JoinField2 END) +
		(CASE when @JoinField3 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField3 + @Join3_Operator + 'b.'+@JoinField3 END) +''
	END

	EXEC sp_executesql @Sql_tblcopy







	--FOR THIS VERSION, USE TEMP SB TABLES
		--alter tablename fields at the end

	--normal
	 --insert into Sandbox2.adc.temp_AutomatedQA_Tables
	 --(Rundate, TableA_DB, TableA_Schema, TableA, TableB_DB, TableB_Schema, TableB)
	 --values
	 --(getdate(), @DBName_A, @SchemaName_A, @TableName_A, @DBName_B, @SchemaName_B, @TableName_B)

	--TEMP SB
	 insert into Sandbox2.adc.temp_AutomatedQA_Tables
	 (Rundate, TableA_DB, TableA_Schema, TableA, TableB_DB, TableB_Schema, TableB, ParentTableA, ParentTableB)
	 values
	 (getdate(), 'Sandbox2', 'dbo', 'temp_AutomatedQA_TableA', 'Sandbox2', 'dbo', 'temp_AutomatedQA_TableB', @DBName_A+'.'+@SchemaName_A+'.'+@TableName_A, @DBName_B+'.'+@SchemaName_B+'.'+@TableName_B)

	

	--USE Sandbox2
	--GO

	DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	DECLARE @TableA varchar(100) = 
			(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableA_db varchar(100) = 
			(select TableA_DB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableA_s varchar(100) = 
			(select TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableB varchar(100) = 
	(select TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableB_db varchar(100) = 
			(select TableB_DB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableB_s varchar(100) = 
			(select TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableA_full varchar(250) = (select top 1 TableA_DB+'.'+TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	DECLARE @TableB_full varchar(250) = (select top 1 TableB_DB+'.'+TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)

--UPDATE TABLE ROWS:
	DECLARE @SQL nvarchar(max) = 
	'UPDATE Sandbox2.adc.temp_AutomatedQA_Tables
		SET TableA_Rows = (Select count(*) from '+@TableA_s+'),
			TableB_Rows = (Select count(*) from '+@TableB_s+')
	FROM Sandbox2.adc.temp_AutomatedQA_Tables
	WHERE ComparisonID = '+CONVERT(varchar(10), @CurrentComp)

	--print @sql
	EXEC sp_executesql @SQL


  --Table Build:
	--DROP TABLE Sandbox2.adc.temp_AutomatedQA_Fields
	--CREATE TABLE Sandbox2.adc.temp_AutomatedQA_Fields
	--(DateChecked datetime
	--,ComparisonID int
	--,ColumnID int identity(1,1)
	--,DBName varchar(50)
	--,SchemaName varchar(50)
	--,TableName varchar(100)
	--,ColumnName varchar(100)
	--,IsCategorical int
	--,OtherIgnore int
	--,IgnoreReason varchar(250)
	--,DataType varchar(50)
	--,IsDate int
	--,ExactMatches int
	--,IsMasked int
	--,CastedFromType varchar(25))

	INSERT INTO Sandbox2.adc.temp_AutomatedQA_Fields
	(DateChecked
	,ComparisonID
	,DBName
	,SchemaName
	,TableName
	,ColumnName
	,IsCategorical
	,OtherIgnore
	,IgnoreReason
	,DataType
	,IsDate
	,IsMasked)

	SELECT 
		--o.name AS table_name,
		--o.object_id,
		'DateChecked' = getdate()
		,@CurrentComp as 'ComparisonID'
		,'DBName' = IIF(o.name = qa.TableA, qa.TableA_DB, qa.TableB_DB)
		,'SchemaName' = s.name
		,'TableName' = o.name
		,'ColumnName' = c.name
		--,c.column_id
		--,'ColumnID' = ROW_Number() OVER (partition by @CurrentComp order by c.column_id) --THIS IS A HACK, change to insert and make unique ID once structure final
		--,'IsMetric' = 0
		,'IsCategorical' = CASE when t.name like '%char%' then 1
								when c.name = 'DataSourceID' then 1
								else 0 END
		,'OtherIgnore' = 0
		,'IgnoreReason' = convert(varchar(250), null)
		,t.name AS DataType
		,'IsDate' = IIF(t.name like '%date%',1,0)
		,c.is_masked

	--INTO Sandbox2.adc.temp_AutomatedQA_Fields

	FROM sys.objects o 
	INNER JOIN sys.schemas s ON o.schema_id = s.schema_id 
	INNER JOIN sys.database_principals u ON s.principal_id = u.principal_id 
	INNER JOIN sys.tables tbl ON o.object_id = tbl.object_id
	INNER JOIN sys.columns c ON tbl.object_id = c.object_id 
	INNER JOIN sys.types t ON c.system_type_id = t.system_type_id AND t.user_type_id = c.user_type_id
	JOIN Sandbox2.adc.temp_AutomatedQA_Tables qa on qa.ComparisonID = @CurrentComp 
	LEFT JOIN Sandbox2.adc.FraudSpiderQA_fields fs on c.name = fs.FieldName
	LEFT JOIN @FieldsTable ft on c.name = ft.FieldName
	LEFT JOIN @OmitFieldsTable oft on c.name = oft.FieldName

	WHERE o.type = 'U' -- U = user-defined table
	--AND o.name = 'temp_PS1comp_Training_120123' 
	AND o.name in (qa.TableA, qa.TableB) --this would need to be combined with schema if non-unique name
	AND (CASE when @FraudSpiderVarsOnly = 'Y'			 --if it IS declared AND it's missing, omit
			AND fs.FieldName is null then 0
		 else 1 END) = 1
	AND (CASE when @IncludeFieldsList <> 'unspecified'  --if it IS declared AND it's missing, omit
			AND ft.FieldName is null then 0				
		 else 1 END) = 1
	AND (CASE when @OmitFieldsList <> 'unspecified'  --if it IS declared, and it's NOT missing, omit
			AND oft.FieldName is NOT null then 0				
		 else 1 END) = 1


--CATEGORICAL SUMMARY:

  --Table Build:
	--DROP TABLE Sandbox2.adc.temp_AutomatedQA_CategoricalSummary
	--CREATE TABLE Sandbox2.adc.temp_AutomatedQA_CategoricalSummary
	--(PKID int identity(1,1),
	-- RunDate datetime,
	-- ComparisonID int, 
	-- TableName varchar(100),
	-- ColumnID int,
	-- ColumnName varchar(100),
	-- ColumnValue varchar(250),
	-- ValueRows int,
	-- ValuePercent numeric(5,4),
	-- DateCastRows int,  --for check if non-categorical fields formatted as text
	-- FloatCastRows int) --for check if non-categorical fields formatted as text

  --For Troubleshooting:
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableA varchar(100) = 
	--		(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableA_db varchar(100) = 
	--		(select TableA_DB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableA_s varchar(100) = 
	--		(select TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB varchar(100) = 
	--(select TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_db varchar(100) = 
	--		(select TableB_DB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_s varchar(100) = 
	--		(select TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)


	DECLARE @Columns table (ComparisonID int, ColumnID int, DBName varchar(100), [SchemaName] varchar(25), TableName varchar(100), ColumnName varchar(100), DataType varchar(25)) 
	
	INSERT INTO @Columns (ComparisonID, ColumnID, DBName, SchemaName, TableName, ColumnName, DataType)
	SELECT ComparisonID, ColumnID, DBName, SchemaName, TableName, ColumnName, DataType
	FROM Sandbox2.adc.temp_AutomatedQA_Fields
	WHERE 1=1
	AND IsMasked = 0
	AND IsCategorical = 1 
	AND ComparisonID = @CurrentComp

	WHILE EXISTS (select * from @Columns)
	BEGIN

		DECLARE @CurrentColumnID int = (select top 1 ColumnID from @Columns)
		DECLARE @CurrentColumnName varchar(100) = (select top 1 ColumnName from @Columns where ColumnID = @CurrentColumnID)
		DECLARE @CurrentDB varchar(100) = (select DBName from @Columns where ColumnID = @CurrentColumnID)
		DECLARE @CurrentSchema varchar(100) = (select SchemaName from @Columns where ColumnID = @CurrentColumnID)
		DECLARE @CurrentTable varchar(100) = (select TableName from @Columns where ColumnID = @CurrentColumnID)
		DECLARE @CurrentDataType varchar(100) = (select DataType from @Columns where ColumnID = @CurrentColumnID)
		

		DECLARE @SQL2 nvarchar(max) =
		'INSERT INTO Sandbox2.adc.temp_AutomatedQA_CategoricalSummary
		(RunDate,
		 ComparisonID, 
		 ColumnID,
		 --TableDB, 
		 --TableSchema,
		 TableName,
		 ColumnName,
		 ColumnValue,
		 ValueRows,
		 ValuePercent,
		 DateCastRows,
		 FloatCastRows)
		 Select  
				getdate()
				,'+CONVERT(varchar(10), @CurrentComp)+'
				,'+CONVERT(varchar(10), @CurrentColumnID)+'
				,'''+@CurrentTable+'''
				,'''+@CurrentColumnName+''' as ColumnName
				,['+@CurrentColumnName+'] as ''ColumnValue''
				,''ValueRows'' = sum(1) 
				,''ValuePercent'' = sum(1.0) / (Select CASE when '''+@CurrentTable+''' = TableA then TableA_Rows
									ELSE TableB_Rows END
							 from Sandbox2.adc.temp_AutomatedQA_Tables
							 where ComparisonID = '+CONVERT(varchar(10), @CurrentComp)+')'

	--only run the try_casts on varchar fields. SQL server won't run this against an int field. We also want to ignore all flavors of null for both the numerator and denominator for successful cast percent. 
		IF @CurrentDataType like '%char%' 
		BEGIN
			SET @SQL2 = @SQL2 + '
				,''DateCastRows'' = SUM(CASE when TRY_CAST(['+@CurrentColumnName+'] as date) is not null 
												AND TRY_CAST(['+@CurrentColumnName+'] as date) between 
																		''1/1/2018'' and ''1/1/2030'' then 1
											else 0 END)
				,''FloatCastRows'' = SUM(CASE when TRY_CAST(['+@CurrentColumnName+'] as float) is NOT null 
											AND ['+@CurrentColumnName+'] not in ('''', ''null'') then 1
											  else 0 END)
				From '+@CurrentSchema+'.'+@CurrentTable+'
				group by ['+@CurrentColumnName+']'
		END
	--if not char, set to zero:
		ELSE 
		BEGIN
			SET @SQL2 = @SQL2 + '
				,''DateCastRows'' = SUM(0)
				,''FloatCastRows'' = SUM(0)
				From '+@CurrentSchema+'.'+@CurrentTable+'
				group by ['+@CurrentColumnName+']'
		END


		print 'cat summary:' + @SQL2
		EXEC sp_executesql @SQL2

		DELETE from @Columns where ColumnID = @CurrentColumnID

	END  --outer loop


--NOW CHECK TOTALS, THEN CHANGE TYPES IF >50% of values were numeric, and delete them from catsummary table
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)

	--DROP TABLE #CastResults
	Select ComparisonID, ColumnID, ColumnName
			,sum(ValueRows) as TotalRows
			,sum(IIF(ColumnValue is null OR ColumnValue in ('', 'null'),ValueRows,0)) as NullRows
			,sum(DateCastRows) as DateRows
			,'DateRowPerc' = sum(DateCastRows) / 
				(sum(ValueRows*1.0) - sum(IIF(ColumnValue is null,ValueRows*1.0,0)))
			,sum(FloatCastRows) as NumericRows
			,'NumericRowPerc' = sum(FloatCastRows) / 
				(sum(ValueRows*1.0) - sum(IIF(ColumnValue is null,ValueRows*1.0,0)))
	into #CastResults
	From Sandbox2.adc.temp_AutomatedQA_CategoricalSummary
	where ComparisonID = @CurrentComp
	group by ComparisonID, ColumnID, ColumnName

--UPDATE DATA TYPES

	UPDATE Sandbox2.adc.temp_AutomatedQA_Fields
		SET IsCategorical = 0,
			CastedFromType = f.DataType,
			[IsDate] = IIF(cr.DateRowPerc > 0.5,1,0),
			DataType = CASE when cr.DateRowPerc > 0.5 then 'datetime'
							when cr.NumericRowPerc > 0.5 then 'float'
						else 'you done f''d up a-a-ron' END
	FROM Sandbox2.adc.temp_AutomatedQA_Fields f
	join #CastResults cr on f.ComparisonID = cr.ComparisonID and f.ColumnID = cr.ColumnID
	WHERE f.IsCategorical = 1
	and f.ComparisonID = @CurrentComp
	and (cr.DateRowPerc > 0.5 OR cr.NumericRowPerc > 0.5)

--DELETE CASTED CATEGORICALS
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)

	DELETE FROM cs
	FROM Sandbox2.adc.temp_AutomatedQA_CategoricalSummary cs
	join Sandbox2.adc.temp_AutomatedQA_Fields f on cs.ComparisonID = f.ComparisonID and cs.ColumnID = f.ColumnID
	WHERE cs.ComparisonID = @CurrentComp
	AND f.CastedFromType IS NOT NULL
	AND f.DataType in ('float','datetime')

--DELETE Categoricals where the number o
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)

	DELETE FROM cs
	FROM Sandbox2.adc.temp_AutomatedQA_CategoricalSummary cs
	join Sandbox2.adc.temp_AutomatedQA_Fields f on cs.ComparisonID = f.ComparisonID and cs.ColumnID = f.ColumnID
	WHERE cs.ComparisonID = @CurrentComp
	and cs.ValuePercent < 0.001

--DELETE PLACEHOLDER (for single table)
	DELETE FROM cs
	FROM Sandbox2.adc.temp_AutomatedQA_CategoricalSummary cs
	join Sandbox2.adc.temp_AutomatedQA_Fields f on cs.ComparisonID = f.ComparisonID and cs.ColumnID = f.ColumnID
	WHERE cs.ComparisonID = @CurrentComp
	and cs.ColumnName = 'placeholder'
	

--CAST SOURCE TABLES IF NEEDED

--TABLE SUMMARY:
--UPDATE NULL ROWS A:

	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableA varchar(100) = 
	--	(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableA_full varchar(250) = (select top 1 TableA_DB+'.'+TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp);

	DECLARE @SQL_NullRows_A NVARCHAR(MAX)
	

    SET @SQL_NullRows_A = N'
    Select count(*) AS TotalNullRows
    From ' + @TableA_full + '
    Where 1 = 1';
	
	SELECT @SQL_NullRows_A = @SQL_NullRows_A + N'
    AND ' + QUOTENAME(name) + ' IS NULL'
    FROM sys.columns
    WHERE [object_id] = OBJECT_ID(@TableA_full);
	
	SET @SQL_NullRows_A = 
		'UPDATE Sandbox2.adc.temp_AutomatedQA_Tables
		SET TableA_NullRows = ('+@SQL_NullRows_A+')
		FROM Sandbox2.adc.temp_AutomatedQA_Tables
		Where ComparisonID = '+convert(varchar(100), @CurrentComp)+''

	PRINT 'NullRows'+@SQL_NullRows_A
	EXEC sp_executesql @SQL_NullRows_A


--UPDATE NULL ROWS B:
  --For Troubleshooting:
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableB varchar(100) = 
	--	(select TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_full varchar(250) = (select top 1 TableB_DB+'.'+TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp);

	DECLARE @SQL_NullRows_B NVARCHAR(MAX)
	

    SET @SQL_NullRows_B = N'
    Select count(*) AS TotalNullRows
    From ' + @TableB_full + '
    Where 1 = 1';
	
	SELECT @SQL_NullRows_B = @SQL_NullRows_B + N'
    AND ' + QUOTENAME(name) + ' IS NULL'
    FROM sys.columns
    WHERE [object_id] = OBJECT_ID(@TableB_full);
	
	SET @SQL_NullRows_B = 
		'UPDATE Sandbox2.adc.temp_AutomatedQA_Tables
		SET TableB_NullRows = ('+@SQL_NullRows_B+')
		FROM Sandbox2.adc.temp_AutomatedQA_Tables
		Where ComparisonID = '+convert(varchar(100), @CurrentComp)+''

	--PRINT @SQL_NullRows_B
	EXEC sp_executesql @SQL_NullRows_B


--UPDATE COUNT OF A missing from B
  --For Troubleshooting:
	--DECLARE @CurrentComp int = (Select MAX(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableA_full varchar(250) = (select top 1 TableA_DB+'.'+TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_full varchar(250) = (select top 1 TableB_DB+'.'+TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @JoinField1 varchar(100) = 'LeadID'
	--DECLARE @JoinField2 varchar(100) = 'DataSourceID'
	--DECLARE @JoinField3 varchar(100) = 'unspecified'

	--Select @TableA

	DECLARE @SQL_A_NotIn_B nvarchar(max) = 
		'Select count(*)
		from '+@TableA_full+' a
		left join '+@TableB_full+' b on a.'+@JoinField1+' = b.'+@JoinField1+
		(CASE when @JoinField2 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField2+' = b.'+@JoinField2 END) +
		(CASE when @JoinField3 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField3+' = b.'+@JoinField3 END) +'
		where b.'+@JoinField1+' is null'

	SET @SQL_A_NotIn_B = 
		'UPDATE Sandbox2.adc.temp_AutomatedQA_Tables
			SET InA_MissingFromB = 
				('+@SQL_A_NotIn_B+')
		FROM Sandbox2.adc.temp_AutomatedQA_Tables
		Where ComparisonID = '+convert(varchar(10), @CurrentComp)+''

	IF @TableName_B <> '#placeholder'
	BEGIN
		PRINT 'A Not in B:' + @SQL_A_NotIn_B
		EXEC sp_executesql @SQL_A_NotIn_B
	END

	DECLARE @SQL_B_NotIn_A nvarchar(max) = 
		'Select count(*)
		from '+@TableB_full+' a
		left join '+@TableA_full+' b on a.'+@JoinField1+' = b.'+@JoinField1+
		(CASE when @JoinField2 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField2+' = b.'+@JoinField2 END) +
		(CASE when @JoinField3 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField3+' = b.'+@JoinField3 END) +'
		where b.'+@JoinField1+' is null'

	SET @SQL_B_NotIn_A = 
		'UPDATE Sandbox2.adc.temp_AutomatedQA_Tables
			SET InB_MissingFromA = 
				('+@SQL_B_NotIn_A+')
		FROM Sandbox2.adc.temp_AutomatedQA_Tables
		Where ComparisonID = '+convert(varchar(10), @CurrentComp)+''

	IF @TableName_B <> '#placeholder'
	BEGIN
		EXEC sp_executesql @SQL_B_NotIn_A
	END

--UPDATE DATA TYPES
	DECLARE @SQL_UpdateDtype nvarchar(max) 
	
	

	--select * from Sandbox2.adc.temp_AutomatedQA_CategoricalSummary

--Categorical Comparison:
  --Table Build:
	--DROP TABLE Sandbox2.adc.temp_AutomatedQA_CategoricalComparison
	--CREATE TABLE Sandbox2.adc.temp_AutomatedQA_CategoricalComparison
	--(PKID int identity(1,1),
	-- RunDate datetime,
	-- ComparisonID int, 
	-- ColumnID int,
	-- ColumnName varchar(100),
	-- ColumnValue varchar(250),
	-- TableA_Count int,
	-- TableB_Count int,
	-- CountDiff int,
	-- TableA_Percent numeric(5,4),
	-- TableB_Percent numeric(5,4),
	-- PercentDiff numeric(5,4))

  --For Troubleshooting:
	 --DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	 --DECLARE @TableA varchar(100) = 
		--	(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)



	 INSERT INTO Sandbox2.adc.temp_AutomatedQA_CategoricalComparison
	 (RunDate
	 ,ComparisonID
	 ,ColumnID
	 ,ColumnName
	 ,ColumnValue
	 ,TableA_Count
	 ,TableB_Count
	 ,CountDiff
	 ,TableA_Percent
	 ,TableB_Percent
	 ,PercentDiff)

	 Select 
			a.RunDate
			,a.ComparisonID
			,a.ColumnID
			,a.ColumnName
			,a.ColumnValue
			,a.ValueRows
			,b.ValueRows
			,b.ValueRows - a.ValueRows
			,a.ValuePercent
			,b.ValuePercent
			,b.ValuePercent - a.ValuePercent
	 From Sandbox2.adc.temp_AutomatedQA_CategoricalSummary a
	 left join Sandbox2.adc.temp_AutomatedQA_CategoricalSummary b on a.ComparisonID = b.ComparisonID and a.ColumnName = b.ColumnName and a.ColumnValue = b.ColumnValue and a.PKID <> b.PKID
	 Where a.ComparisonID = @CurrentComp
	 and a.TableName = @TableA
	 --and (a.ValuePercent + b.ValuePercent) / 2 > 0.001 --omit if the value makes up less than 0.1% to keep the table from blowing up (changed to deleting these from the summary table)

	 

--NUMERICAL SUMMARY:
  --Table Build:
	--DROP TABLE Sandbox2.adc.temp_AutomatedQA_NumericalSummary
	--CREATE TABLE Sandbox2.adc.temp_AutomatedQA_NumericalSummary
	--(PKID int identity(1,1),
	-- RunDate datetime,
	-- ComparisonID int, 
	-- ColumnID int,
	-- TableName varchar(100),
	-- ColumnName varchar(100),
	-- [IsDate] int,
	-- DistinctValues int,
	-- Nulls int,
	-- NonNulls int,
	-- ColMin float,
	-- ColMax float,
	-- ColMean float)

  --For Troubleshooting:
	-- DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableA varchar(100) = 
	--		(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableA_db varchar(100) = 
	--		(select TableA_DB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableA_s varchar(100) = 
	--		(select TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB varchar(100) = 
	--(select TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_db varchar(100) = 
	--		(select TableB_DB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_s varchar(100) = 
	--		(select TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)


	DECLARE @Columns_num table (ComparisonID int, ColumnID int, DBName varchar(100), [SchemaName] varchar(25), TableName varchar(100), ColumnName varchar(100), [IsDate] int, DataType varchar(25), CastedFromType varchar(25)) 
	
	INSERT INTO @Columns_num (ComparisonID, ColumnID, DBName, SchemaName, TableName, ColumnName, [IsDate], DataType, CastedFromType)
	SELECT ComparisonID, ColumnID, DBName, SchemaName, TableName, ColumnName, [IsDate], DataType, CastedFromType
	FROM Sandbox2.adc.temp_AutomatedQA_Fields
	WHERE 1=1
	AND IsMasked = 0
	AND IsCategorical = 0  
	AND ComparisonID = @CurrentComp

	WHILE EXISTS (select * from @Columns_num)
	BEGIN

		DECLARE @CurrentColumnID_num int = (select top 1 ColumnID from @Columns_num)
		DECLARE @CurrentColumnName_num varchar(100) = (select top 1 ColumnName from @Columns_num where ColumnID = @CurrentColumnID_num)
		DECLARE @CurrentTable_num varchar(100) = (select TableName from @Columns_num where ColumnID = @CurrentColumnID_num)
		DECLARE @CurrentDB_num varchar(100) = (select DBName from @Columns_num where ColumnID = @CurrentColumnID_num)
		DECLARE @CurrentSchema_num varchar(100) = (select SchemaName from @Columns_num where ColumnID = @CurrentColumnID_num)
		DECLARE @CurrentDataType_num varchar(25) = (select DataType from @Columns_num where ColumnID = @CurrentColumnID_num)
		DECLARE @CurrentCastedFromType varchar(25) = (select CastedFromType from @Columns_num where ColumnID = @CurrentColumnID_num)

	--make @CurrentColumnName_num the name only, and separately, @CurrentColumnLogic

	--ALTER LOGIC FOR DATE FIELDS, CONVERT TO EXCEL FLOAT
		DECLARE @CurrentColumnIsDate int = (select top 1 IsDate from @Columns_num where ColumnID = @CurrentColumnID_num)
		DECLARE @CurrentColumnLogic nvarchar(max) = 
			CASE when @CurrentCastedFromType like '%char%' and @CurrentDataType_num = 'float' then 'TRY_CAST('+QUOTENAME(@CurrentColumnName_num)+' as float)'
				when @CurrentColumnIsDate = 0 then QUOTENAME(@CurrentColumnName_num)
				ELSE 'CAST(DATEDIFF(DAY, ''19000101'', '+QUOTENAME(@CurrentColumnName_num)+') AS FLOAT)' END
			--CAST(DATEDIFF(DAY, '19000101', YourDateTimeColumn) AS FLOAT)

	--	Select @CurrentColumnLogic
	--	DELETE from @Columns_num where ColumnID = @CurrentColumnID_num

	--END



		DECLARE @SQL3 nvarchar(max) = 

		'Insert Into Sandbox2.adc.temp_AutomatedQA_NumericalSummary
		(RunDate,
		 ComparisonID, 
		 ColumnID,
		 TableName,
		 ColumnName,
		 IsDate,
		 DistinctValues,
		 Nulls,
		 NonNulls,
		 ColMin,
		 ColMax,
		 ColMean)
		 	 
		 Select  
				getdate()
				,'+CONVERT(varchar(10), @CurrentComp)+'
				,'+CONVERT(varchar(10), @CurrentColumnID_num)+'
				,'''+@CurrentTable_num+'''
				,'''+@CurrentColumnName_num+'''
				,'+CONVERT(varchar(10), @CurrentColumnIsDate)+'
				,count(distinct '+@CurrentColumnLogic+')
				,sum(iif('+@CurrentColumnLogic+' is null,1,0))
				,sum(iif('+@CurrentColumnLogic+' is null,0,1))
				,min('+@CurrentColumnLogic+')
				,max('+@CurrentColumnLogic+')
				,AVG(CAST('+@CurrentColumnLogic+' AS DECIMAL))
		From '+@CurrentSchema_num+'.'+@CurrentTable_num+''

		print 'num summary:'+@SQL3
		EXEC sp_executesql @SQL3

		DELETE from @Columns_num where ColumnID = @CurrentColumnID_num

	END


	--select * from Sandbox2.adc.temp_AutomatedQA_NumericalSummary



--NUMERICAL Comparison:
  --Table Build:
	----DROP TABLE Sandbox2.adc.temp_AutomatedQA_NumericalComparison
	--CREATE TABLE Sandbox2.adc.temp_AutomatedQA_NumericalComparison
	--(PKID int identity(1,1),
	-- RunDate datetime,
	-- ComparisonID int, 
	-- ColumnID int,
	-- ColumnName varchar(100),
	-- IsDate int,
	-- TableA_DistVal int,
	-- TableB_DistVal int,
	-- DistVal_PercDiff float,
	-- TableA_Nulls int,
	-- TableB_Nulls int,
	-- Nulls_PercDiff float,
	-- TableA_Min int,
	-- TableB_Min int,
	-- Min_PercDiff float,
	-- TableA_Max int,
	-- TableB_Max int,
	-- Max_PercDiff float,
	-- TableA_Mean float,
	-- TableB_Mean float,
	-- Mean_PercDiff float
	-- )

  --For Troubleshooting:
	 --DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	 --DECLARE @TableA varchar(100) = 
		--	(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)

	--print 'INSERT INTO Sandbox2.adc.temp_AutomatedQA_NumericalComparison'
	 INSERT INTO Sandbox2.adc.temp_AutomatedQA_NumericalComparison
	 (RunDate
	 ,ComparisonID
	 ,ColumnID
	 ,ColumnName
	 ,[IsDate]
	 ,TableA_DistVal
	 ,TableB_DistVal
	 ,DistVal_PercDiff
	 ,TableA_Nulls
	 ,TableB_Nulls
	 ,Nulls_PercDiff
	 ,TableA_Min
	 ,TableB_Min
	 ,Min_PercDiff
	 ,TableA_Max
	 ,TableB_Max
	 ,Max_PercDiff
	 ,TableA_Mean
	 ,TableB_Mean
	 ,Mean_PercDiff)

	 Select 
			a.RunDate
			,a.ComparisonID
			,a.ColumnID
			,a.ColumnName
			,a.[IsDate]
			--,a.PKID
			--,b.PKID as BPKID
			,'TableA_DistVal' = a.DistinctValues
			,'TableB_DistVal' = b.DistinctValues
			,'DistVal_PercDiff' = CONVERT(DECIMAL(25, 4), iif(a.DistinctValues = 0 and b.DistinctValues <> 0, 1, iif(a.DistinctValues = 0, iif(b.DistinctValues = 0, 0, null), (b.DistinctValues - a.DistinctValues) / (1.0*a.DistinctValues))))
			,'TableA_Nulls' = a.Nulls
			,'TableB_Nulls' = b.Nulls
			,'Nulls_PercDiff' = CONVERT(DECIMAL(25, 4), iif(a.Nulls = 0 and b.Nulls <> 0, 1, iif(a.Nulls = 0, iif(b.Nulls = 0, 0, null), (b.Nulls - a.Nulls) / (1.0*a.Nulls))))
			,'TableA_Min' = a.ColMin
			,'TableB_Min' = b.ColMin
			,'Min_PercDiff' = CONVERT(DECIMAL(25, 4), iif(a.ColMin = 0 and b.ColMin <> 0, 1, iif(a.ColMin = 0, iif(b.ColMin = 0, 0, null), (b.ColMin - a.ColMin) / (1.0*a.ColMin))))
			,'TableA_Max' = a.ColMax
			,'TableB_Max' = b.ColMax
			,'Max_PercDiff' = CONVERT(DECIMAL(25, 4), iif(a.ColMax = 0 and b.ColMax <> 0, 1, iif(a.ColMax = 0, iif(b.ColMax = 0, 0, null), (b.ColMax - a.ColMax) / (1.0*a.ColMax))))
			,'TableA_Mean' = a.ColMean
			,'TableB_Mean' = b.ColMean
			,'Mean_PercDiff' = CONVERT(DECIMAL(25, 4), iif(a.ColMean = 0 and b.ColMean <> 0, 1, iif(a.ColMean = 0, iif(b.ColMean = 0, 0, null), (b.ColMean - a.ColMean) / (1.0*a.ColMean))))
			--,'MeanNumerator' = (b.ColMean - a.ColMean)
			--,'MeanDenominator' = (1.0*a.ColMean)
	--into #temp
	 From Sandbox2.adc.temp_AutomatedQA_NumericalSummary a
	 left join Sandbox2.adc.temp_AutomatedQA_NumericalSummary b on a.ComparisonID = b.ComparisonID and a.ColumnName = b.ColumnName and a.PKID <> b.PKID
	 Where a.ComparisonID = @CurrentComp
	 and a.TableName = @TableA
	 and a.ColMax < 100000000000000 --needs to be less than 15 digits for float conversion


	
--UPDATE NULL COLUMNS
  --For Troubleshooting:
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableB varchar(100) = 
	--	(select TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--print 'UPDATE Sandbox2.adc.temp_AutomatedQA_Tables'
	UPDATE Sandbox2.adc.temp_AutomatedQA_Tables
		SET TableA_NullColumns = o.A_NullColumns,
			TableB_NullColumns = o.B_NullColumns

	FROM Sandbox2.adc.temp_AutomatedQA_Tables a
	join
	(Select ComparisonID
			,sum(IIF(TableA_Rows = TableA_Nulls, 1, 0)) as A_NullColumns
			,sum(IIF(TableB_Rows = TableB_Nulls, 1, 0)) as B_NullColumns
	 From
		(Select t.ComparisonID, nc.ColumnID, t.TableA_Rows, nc.TableA_Nulls, t.TableB_Rows, nc.TableB_Nulls
		from Sandbox2.adc.temp_AutomatedQA_NumericalComparison nc
		join Sandbox2.adc.temp_AutomatedQA_Tables t on nc.ComparisonID = t.ComparisonID
		where t.ComparisonID = @CurrentComp) t
	 Group by ComparisonID) o on a.ComparisonID = o.ComparisonID
	 

--RECORD NUMBER OF EXACT MATCHES (if requested)
	--DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	--DECLARE @TableA varchar(100) = 
	--		(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB varchar(100) = 
	--(select TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableA_full varchar(250) = (select top 1 TableA_DB+'.'+TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @TableB_full varchar(250) = (select top 1 TableB_DB+'.'+TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)
	--DECLARE @JoinField1 varchar(100) = 'LeadID'
	--DECLARE @JoinField2 varchar(100) = 'DataSourceID'
	--DECLARE @JoinField3 varchar(100) = 'unspecified'
	--DECLARE @CalcNumExactMatchesYorN varchar(1) = 'Y'

	IF @CalcNumExactMatchesYorN = 'Y'
	BEGIN
		 DECLARE @SQL_ExactMatches nvarchar(max)
		 DECLARE @SQL_ExactMatches_cat nvarchar(max)

		 DECLARE @Columns_EM table (ComparisonID int, ColumnID int, DBName varchar(100), [SchemaName] varchar(25), TableName varchar(100), ColumnName varchar(100), [IsDate] int, IsCategorical int) 

	--changed to only calc exact matches for columns that exist in both tables: 
		INSERT INTO @Columns_EM (ComparisonID, ColumnID, DBName, SchemaName, TableName, ColumnName, [IsDate], IsCategorical)
		SELECT a.ComparisonID, a.ColumnID, a.DBName, a.SchemaName, a.TableName, a.ColumnName, a.[IsDate], a.IsCategorical
		FROM Sandbox2.adc.temp_AutomatedQA_Fields a
		INNER JOIN Sandbox2.adc.temp_AutomatedQA_Fields b on a.ColumnName = b.ColumnName and a.ComparisonID = b.ComparisonID
		WHERE 1=1
		--AND IsCategorical = 0  --PULL ALL FIELDS (one table only)
		AND a.IsMasked = 0
		AND a.ComparisonID = @CurrentComp
		AND a.TableName = @TableA
		AND b.TableName = @TableB
		AND IIF(a.DataType like '%char%',1,0) = IIF(b.DataType like '%char%',1,0)

		--select 'Columns_EM', ComparisonID, ColumnID, ColumnName, count(*) from @Columns_EM
		--group by ComparisonID, ColumnID, ColumnName
		--order by count(*) desc

		WHILE EXISTS (select * from @Columns_EM)
		BEGIN

			DECLARE @CurrentColumnID_EM int = (select top 1 ColumnID from @Columns_EM order by ColumnID)
			DECLARE @CurrentColumnName_EM varchar(100) = (select top 1 ColumnName from @Columns_EM where ColumnID = @CurrentColumnID_EM)
			DECLARE @CurrentTable_EM varchar(100) = (select TableName from @Columns_EM where ColumnID = @CurrentColumnID_EM)
			DECLARE @CurrentDB_EM varchar(100) = (select DBName from @Columns_EM where ColumnID = @CurrentColumnID_EM)
			DECLARE @CurrentSchema_EM varchar(100) = (select SchemaName from @Columns_EM where ColumnID = @CurrentColumnID_EM)
			DECLARE @IsCategorical int = (Select IsCategorical from @Columns_EM where ColumnID = @CurrentColumnID_EM)


		--QUERY
			SET @SQL_ExactMatches = N'
			Select count(*) AS ExactMatches
			From ' + @TableA_full + ' a
			INNER JOIN ' + @TableB_full + ' b 
				on a.'+@JoinField1+' = b.'+@JoinField1+
				(CASE when @JoinField2 = 'unspecified' then '' ELSE
					' AND a.'+@JoinField2+' = b.'+@JoinField2 END) +
				(CASE when @JoinField3 = 'unspecified' then '' ELSE
					' AND a.'+@JoinField3+' = b.'+@JoinField3 END) +'
				AND a.['+@CurrentColumnName_EM+'] = b.['+@CurrentColumnName_EM+']'

		--DECLARE @CurrentUpdateTable varchar(250) = IIF(@IsCategorical = 1, 'Sandbox2.adc.temp_AutomatedQA_CategoricalComparison', 
		--  'Sandbox2.adc.temp_AutomatedQA_NumericalComparison')
		DECLARE @CurrentUpdateTable varchar(250) = 'Sandbox2.adc.temp_AutomatedQA_Fields'
		  
		--TABLE UPDATE
			SET @SQL_ExactMatches = N'

				UPDATE '+@CurrentUpdateTable+'
					SET ExactMatches = ('+@SQL_ExactMatches+')

				FROM '+@CurrentUpdateTable+'
				WHERE ComparisonID = '+convert(varchar(10),@CurrentComp)+'
				AND ColumnID = '+convert(varchar(10),@CurrentColumnID_EM)+''

			PRINT @SQL_ExactMatches
			EXEC sp_executesql @SQL_ExactMatches


			DELETE from @Columns_EM where ColumnID = @CurrentColumnID_EM
		END
	
	END --end exact match




 END --sproc end

