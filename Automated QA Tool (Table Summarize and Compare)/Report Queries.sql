


	EXEC AutomatedQA_TableComp_JoinSpecific 
	--What tables do you want to compare?
		@DBName_A = 'Table A Database'
		,@SchemaName_A = 'Table A Schema'
		,@TableName_A = 'Table A Name'
		,@DBName_B = 'Table B Database'
		,@SchemaName_B = 'Table B Schema'
		,@TableName_B = 'Table B Name' 
	--How do you want to join them?
		,@JoinField1 = 'LeadID'
		,@Join1_Operator = '='
		,@JoinField2 = 'DataSourceID'		--omit if not needed
		,@Join2_Operator = '='				--omit if not needed
		,@JoinType = 'inner' 
	--Do you want the sproc to calculate how many rows match exactly for each column? Increases runtime a bit.
		,@CalcNumExactMatchesYorN = 'Y'
	--Are you only interested in comparing specific fields? 
		,@IncludeFieldsList = ('FieldA,FieldB,FieldC')	--COMMA SEPERATED, NO SPACES (only compare these)
		,@OmitFieldsList = ('FieldA,FieldB,FieldC') --COMMA SEPERATED, NO SPACES (compare everything BUT these)

--REVIEW RESULTS

	DECLARE @CurrentComp int = (select max(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)

	
	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_Tables					WHERE ComparisonID = @CurrentComp
	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_Fields					WHERE ComparisonID = @CurrentComp
	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_CategoricalSummary		WHERE ComparisonID = @CurrentComp 
	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_CategoricalComparison		WHERE ComparisonID = @CurrentComp
	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_NumericalSummary			WHERE ComparisonID = @CurrentComp
	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_NumericalComparison		WHERE ComparisonID = @CurrentComp


--REPORT QUERIES: Change these table references to your new table names before implementing!!!
	--Numeric Comparison:
	DECLARE @CurrentComp int = (Select MAX(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_NumericalComparison)
	DECLARE @TableA varchar(100) = 
			(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @CurrentComp)

	SELECT nc.*, f.ExactMatches, 'TableA_NonNulls' = t.TableA_Rows - nc.TableA_Nulls, 'MatchPercent' = f.ExactMatches / (1.0*(t.TableA_Rows - nc.TableA_Nulls)), 'TableB_NonNulls' = t.TableB_Rows - nc.TableB_Nulls
	FROM Sandbox2.adc.temp_AutomatedQA_NumericalComparison nc
	left join Sandbox2.adc.temp_AutomatedQA_Fields f on f.IsCategorical = 0 and nc.ComparisonID = f.ComparisonID and nc.ColumnID = f.ColumnID and f.TableName = @TableA
	left join Sandbox2.adc.temp_AutomatedQA_Tables t on nc.ComparisonID = t.ComparisonID 
	Where nc.ComparisonID = @CurrentComp


	--Categorical Comparison:
	DECLARE @MaxID int = (Select MAX(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_CategoricalComparison) --lets actually leave this here. If it refreshes, and there's nothing in there, I'm worried the table might lose its formatting.

	SELECT * FROM Sandbox2.adc.temp_AutomatedQA_CategoricalComparison
	Where ComparisonID = @MaxID


	--Table Summary:
	DECLARE @MaxID int = (Select MAX(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	DECLARE @TableA varchar(100) = 
			(select TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @MaxID)
	DECLARE @MatchPercentage numeric(5,4) = 
		(SELECT AVG(MatchPercent) FROM
			(select  nc.ColumnID
					,t.TableA_Rows - t.InA_MissingFromB as 'MatchRows'
					,nc.ExactMatches
					,nc.ExactMatches / (1.0*(t.TableA_Rows - t.InA_MissingFromB)) as 'MatchPercent'
			from Sandbox2.adc.temp_AutomatedQA_Fields nc --switched from old way (num and cat separately)
			join Sandbox2.adc.temp_AutomatedQA_Tables t on nc.ComparisonID = t.ComparisonID
			where t.ComparisonID = @MaxID
			and nc.TableName = @TableA) t)

	SELECT   ComparisonID
			,RunDate
			,'Table' = ParentTableA 
			,'Rows' = TableA_Rows
			,'NullRows' = TableA_NullRows
			,'NullColumns' = TableA_NullColumns
			,'MissingFromOther' = InA_MissingFromB
			,'AvgValueMatchPercentage' = @MatchPercentage
			,'TempTable' = TableA_DB+'.'+TableA_Schema+'.'+TableA
	FROM Sandbox2.adc.temp_AutomatedQA_Tables
	Where ComparisonID = @MaxID
		UNION
	SELECT   ComparisonID
			,RunDate
			,'Table' = ParentTableB
			,'Rows' = TableB_Rows
			,'NullRows' = TableB_NullRows
			,'NullColumns' = TableB_NullColumns
			,'MissingFromOther' = InB_MissingFromA
			,'AvgValueMatchPercentage' = @MatchPercentage --the same
			,'TempTable' = TableB_DB+'.'+TableB_Schema+'.'+TableB 
	FROM Sandbox2.adc.temp_AutomatedQA_Tables
	Where ComparisonID = @MaxID





--A Missing From B script: You would have to update your join fields with these as well. 

--NOTE: these will error out if you're doing a single table analysis. I couldn't find a way around that, but just ignore it
	DECLARE @MaxID int = (Select MAX(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	DECLARE @TableA varchar(250) = (select top 1 TableA_DB+'.'+TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @MaxID)
	DECLARE @TableB varchar(250) = (select top 1 TableB_DB+'.'+TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @MaxID)
	
	DECLARE @JoinField1 varchar(100) = 'LeadID'
	DECLARE @JoinField2 varchar(100) = 'DataSourceID'
	DECLARE @JoinField3 varchar(100) = 'unspecified'
	DECLARE @SQL nvarchar(max)
	--Select @TableA

	SET @SQL = 
		'Select TOP 10000 a.*
		from '+@TableA+' a
		left join '+@TableB+' b on a.'+@JoinField1+' = b.'+@JoinField1+
		(CASE when @JoinField2 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField2+' = b.'+@JoinField2 END) +
		(CASE when @JoinField3 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField3+' = b.'+@JoinField3 END) +'
		where b.'+@JoinField1+' is null'

	--PRINT @SQL
	EXEC sp_executesql @SQL

--B Missing From A script:
	DECLARE @MaxID int = (Select MAX(ComparisonID) from Sandbox2.adc.temp_AutomatedQA_Tables)
	DECLARE @TableA varchar(250) = (select top 1 TableA_DB+'.'+TableA_Schema+'.'+TableA from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @MaxID)
	DECLARE @TableB varchar(250) = (select top 1 TableB_DB+'.'+TableB_Schema+'.'+TableB from Sandbox2.adc.temp_AutomatedQA_Tables where ComparisonID = @MaxID)

	DECLARE @JoinField1 varchar(100) = 'LeadID'
	DECLARE @JoinField2 varchar(100) = 'DataSourceID'
	DECLARE @JoinField3 varchar(100) = 'unspecified'
	DECLARE @SQL nvarchar(max)
	--Select @TableA

	SET @SQL = 
		'Select TOP 10000 a.*
		from '+@TableB+' a
		left join '+@TableA+' b on a.'+@JoinField1+' = b.'+@JoinField1+
		(CASE when @JoinField2 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField2+' = b.'+@JoinField2 END) +
		(CASE when @JoinField3 = 'unspecified' then '' ELSE
			' AND a.'+@JoinField3+' = b.'+@JoinField3 END) +'
		where b.'+@JoinField1+' is null'

	--PRINT @SQL
	EXEC sp_executesql @SQL


	