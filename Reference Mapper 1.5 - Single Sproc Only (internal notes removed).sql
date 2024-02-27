


USE Sandbox
GO

CREATE PROCEDURE usp_ac_ReferenceSearch_v1
		@ProcName varchar(100),
		@ProcDB varchar(100),
		@Description varchar(max),
		@Author varchar(50),
		@IsReport bit,
		@IsModelTraining bit,
		@Directory varchar(250),
		@SQL varchar(max)

AS


BEGIN
	----------------------> deactivating the transaction stuff for now since it makes it tough to troubleshoot
	SET NOCOUNT ON	

	BEGIN TRY
	BEGIN TRANSACTION
	----------------------


--******************************************************************************
-- CreditServe SQL Reference Mapper
--******************************************************************************

--Author: Adam Cazes
--Created: 5/22/23
--Description: Identifies all references to known database objects within a given stored procedure or piece of code
--Instructions:
	--As it's currently written, this needs to be connected to the same database the sproc is on in order to work properly

-------------------------------------------------------------------------------------
--Change Log:
--5/23/23 AC- swapped out % for $ in new line delineator
--			- added FullString and Directory to CodeSearch table
--			- added Logger search to Sections table --never mind. Let's have people review the PrimaryOutputs manually. It's pretty tricky to programmatically identify this, you would pretty much have to track, from section to section, any time a field is renamed. 
--			- modify primary output - take the found references, remove the alias, then search for them in the last section. If they exist there with the same name, make them primary.

-------------------------------------------------------------------------------------
	/*

	Structure:
		--Section 1 segments the code into sections
		--Section 2 identifies all mentions of known tables and views
		--Section 3 extracts the table alias used (if one was used)
		--Section 4 identifies all references (all found cominations of alias+field for that table, in that section of code)

	

	DEMO Notes:
		-reference Kevins Score monitoring reports as an example of best practices (what NOT to do). We need PBI report code to be searchable and easily interpretable for whomever might need to work on it. 
	-Examples Use Cases:
		-If you want to see all reports where primary output = x
		-if you want to see all models that use x as primary input
		-if you want to see everything that depends on a given broken field
		-if you want to see everywhere that something portfolio specific is hard-coded
		-if you want to see all ad-hoc reports on subject x that used field y
		-automated ad-hoc report/query builder that you can construct on top of the code+reference library

	
	*/


--FOR MANUAL RUNS/TESTING:
	--SET NOCOUNT OFF
	--DECLARE @ProcName varchar(100)	--now parameters
	--DECLARE @ProcDB varchar(100)		--now parameters
	--DECLARE @Description varchar(max)	--now parameters
	--DECLARE @IsReport bit = 0
	--DECLARE @IsModelTraining bit = 1
	--DECLARE @Directory varchar(250) = 'F:\Public\Personal Folders\AdamC\Projects\Reference Mapper\FraudModel Test Sproc'
	--DECLARE @SQL varchar(max) = 'IF OBJECT_ID(N''tempdb.dbo.#LE'') IS NOT NULL
	--								DROP TABLE #LE;

	--							SELECT [DataSourceID]
	--									,[LeadID]
	--									,StoreGroupName_LE = [StoreGroupName]
	--									,SSN_PrevIncomeAvg_LE = [SSN_PrevIncomeAvg]
	--							into #LE
	--							FROM [LeadEnvy].[dbo].[vw_CSIDataRobotProfitScoreV3Outcomes] (nolock)'
	--DECLARE @Author varchar(100) = 'Adam C'
	--SET @ProcName = ''--'[dbo].[usp_ac_ProfitScore_V3_test]'--'dbo.usp_ac_FraudAnomalyModel_v1'--
	--SET @ProcDB = 'Sandbox'


--TABLE BUILD STATEMENTS:
	----DROP TABLE Sandbox2.dbo.CodeSearch_Searches_v1
	--CREATE TABLE Sandbox2.dbo.CodeSearch_Searches_v1
	--(CodeSearchID int identity(1,1),
	-- [ObjectID] int,
	-- [Server] varchar(100), 
	-- [ObjectName] varchar(100), 
	-- [ObjectDB] varchar(100), 
	-- [ObjectType] varchar(100), 
	-- [Author] varchar(100),
	-- [ObjectDescription] varchar(max),
	-- [IsReport] int,
	-- [IsModelTraining] int,
	-- [InsertDate] datetime,
	-- [LastSearched] datetime,
	-- [FieldsMapped] int,
	-- [FullString] nvarchar(max),
	-- [Directory] nvarchar(250))

	-- --DROP TABLE Sandbox2.dbo.CodeSearch_Sections_v1
	-- CREATE TABLE Sandbox2.dbo.CodeSearch_Sections_v1
	--(SectionID int identity(1,1),
	-- [CodeSearchID] int,
	-- [Server] varchar(100), 
	-- [ObjectName] varchar(100), 
	-- --[ObjectType] varchar(100), 
	-- [SectionStart] int, 
	-- [SectionEnd] int,
	-- [SectionIdentifier] varchar(100),
	-- [SectionNum] int, 
	-- [Snippet] varchar(max), 
	-- [SearchDB] varchar(100),
	-- [InsertDate] datetime)

	-- --DROP TABLE Sandbox2.dbo.CodeSearch_Tables_v1
	-- CREATE TABLE Sandbox2.dbo.CodeSearch_Tables_v1
	--	(SnippetID int identity(1,1),
	--	 [CodeSearchID] int,
	--	 [Server] varchar(100), 
	--	 [ObjectName] varchar(100), 
	--	-- [Database] varchar(100), 
	--	 --[ObjectType] varchar(100), 
	--	 --[ObjectDescription] varchar(max),
	--	 [Snippet] varchar(max), 
	--	 [SnippetIndex] int,
	--	 [SnippetNum] int, 
	--	 [SearchString] varchar(100), 
	--	 [SearchDB] varchar(100),
	--	 [InsertDate] datetime)

	-- --DROP TABLE Sandbox2.dbo.CodeSearch_Aliases_v1
	-- CREATE TABLE Sandbox2.dbo.CodeSearch_Aliases_v1
	--	(AliasID int identity(1,1)
	--	 ,SnippetID int
	--	 ,CodeSearchID int
	--	 ,SnippetNum int
	--	 ,[Server] varchar(10)
	--	 ,[ObjectName] varchar(100)
	--	 ,SearchDB varchar(100)
	--	 ,SearchString varchar(100)
	--	 ,StartIndex int
	--	 ,FirstSpace int
	--	 ,SecondSpace int
	--	 ,NewLine int
	--	 ,StopIndex int
	--	 ,Alias varchar(50)
	--	 ,NonAlias varchar(50)
	--	 ,AliasSearchType varchar(100)
	--	 ,[InsertDate] datetime
	--	 ,Checked datetime)

	----DROP TABLE Sandbox2.dbo.CodeSearch_References_v1	
	--  CREATE TABLE Sandbox2.dbo.CodeSearch_References_v1
	--	(ReferenceID  int identity(1,1),
	--	 AliasID int,
	--	 TableSnippetID int,
	--	 CodeSearchID int,
	--	 [Server] varchar(100), 
	--	 [ObjectName] varchar(100), 
	--	 [Database] varchar(100), 
	--	 [Table] varchar(100), 
	--	 [Field] varchar(100),  
	--	 [Alias] varchar(100),
	--	 [Reference] varchar(100),
	--	 [RefIndex] int,
	--	 [RefSnippet] varchar(max),
	--	 [SnippetNum] int,
	--	 [IsCriteriaOnly] bit,
	--	[CodeSection] int,
	--	[IsPrimaryOutput] bit,
	--	[InsertDate] datetime )
	

DECLARE @CurrentCodeSearch int 
DECLARE @Objects TABLE (ProcName varchar(100), ObjectID int)
DECLARE @Strings TABLE (SearchString varchar(250), SearchDB varchar(250), SearchSchema varchar(250), SearchTable varchar(250))

	Insert Into @Strings (SearchString, SearchDB, SearchSchema, SearchTable)
	Select SearchString, DatabaseName, SchemaName, TableName
	From   (select 'SearchString' = r.DatabaseName+'.'+r.SchemaName+'.'+r.TableName, r.DatabaseName, r.SchemaName, r.TableName 
			From Sandbox2.dbo.RPT01DataStructure r
			Where r.DatabaseName not in ('tempdb') --, 'Sandbox') you COULD omit SB tables if you want, but you would lose mappings to the "DataRobot_" modeling inputs, so leaving in for now. 
			GROUP BY r.DatabaseName+'.'+r.SchemaName+'.'+r.TableName, r.DatabaseName, r.SchemaName, r.TableName) t




SET @ProcName = IIF(isnull(@ProcName,'')='', @Author+' | Ad-Hoc query | '+convert(varchar(200),convert(date,getdate())), @ProcName)
DECLARE @NewLineSub VARCHAR(MAX) = (select REPLACE(isnull(OBJECT_DEFINITION(OBJECT_ID(@ProcName)), @SQL), CHAR(13) + CHAR(10), '$'))	--change new lines for $ in either sproc def or ad-hoc string
DECLARE @LogicString VARCHAR(MAX) = (select REPLACE(REPLACE(@NewLineSub, '[', ''), ']', ''))											--remove all brackets 

--DECLARE @Timestamp1 datetime = getdate()
--**************************************
-- INSERT TO SEARCH TABLE
--**************************************
	--IF OBJECT_ID(@ProcName) IS NOT NULL  --For pasted SQL only!!!
	--BEGIN
--SPECIFIED SPROC
	 Insert Into Sandbox2.dbo.CodeSearch_Searches_v1
	 (ObjectID, Server, ObjectName, ObjectDB, ObjectType, Author, ObjectDescription, IsReport, IsModelTraining, InsertDate, FullString, Directory)
 
	 SELECT DISTINCT
		OBJECT_ID(@ProcName)
		,[Server] = 'RPT01'
		,[ObjectName] = @ProcName
		,[ObjectDB] = @ProcDB
		,[ObjectType] = case 
			when [sysobjects].xtype = 'P' then 'Stored Proc'
			when [sysobjects].xtype = 'TF' then 'Function'
			when [sysobjects].xtype = 'FN' then 'Function'
			when [sysobjects].xtype = 'TR' then 'Trigger'
			when [sysobjects].xtype = 'V' then 'View' end
		,@Author
		,@Description
		,@IsReport
		,@IsModelTraining
		,'InsertDate' = getdate()
		,@LogicString
		,@Directory
	FROM [sysobjects],[syscomments]
	WHERE [sysobjects].id = [syscomments].id
	--AND [sysobjects].type in ('P','TF','TR','V','FN')
	AND [sysobjects].category = 0
	AND [sysobjects].id = OBJECT_ID(@ProcName)

--	END		--For pasted SQL only!!!
--	ELSE 
--	BEGIN
----PASTED SQL CODE
--	Insert Into Sandbox2.dbo.CodeSearch_Searches_v1
--	 (Server, ObjectName, ObjectDB, ObjectType, Author, ObjectDescription, IsReport, IsModelTraining, InsertDate, FullString, Directory)
 
--	 SELECT DISTINCT
--		[Server] = 'RPT01'
--		,[ObjectName] = @ProcName
--		,[ObjectDB] = @ProcDB
--		,[ObjectType] = 'Ad-Hoc'
--		,@Author
--		,@Description
--		,@IsReport
--		,@IsModelTraining
--		,'InsertDate' = getdate()
--		,@LogicString
--		,@Directory
--	 END		--For pasted SQL only!!!

	--NOTES: 
		--EACH table reference found is inserted, even if found multiple times. We have to do it this way, because you can have multiple tables with different aliases, with some being inputs, and others being primary report/modeling outputs - so we need to search for all possible fields belonging to each mapped table for each table+alias combo. If you don't specify the alias, you run into the issue of incorrect matches due to common field names. 
		--the mapper is designed to be run on a loop, when desired, but when running an individual sproc, only 1 CodeSearchID is involved. 

	SET @CurrentCodeSearch = (select top 1 CodeSearchID from Sandbox2.dbo.CodeSearch_Searches_v1 where LastSearched is null and ObjectName = @ProcName order by InsertDate desc) 

	
	DECLARE @SelectTable TABLE ([CodeSearchID] int,
								 [Server] varchar(100), 
								 [ObjectName] varchar(100), 
								 [ObjectType] varchar(100), 
								 [SectionStart] varchar(100), --this IS snipindex
								 [SectionIdentifier] varchar(100),
								 [SectionNum] int, 
								 [Snippet] varchar(max), 
								 [SearchDB] varchar(100),
								 [InsertDate] datetime)

	

--**************************************
--	Split the code into sections
--**************************************

	DECLARE @StartPosition INT = 1;
	DECLARE @NextPosition INT;
	DECLARE @MatchSnippet NVARCHAR(MAX);
	DECLARE @SnippetNum INT = 1

	DECLARE @SectionWords TABLE (SectionWord varchar(100))
	DECLARE @CurrentSectionWord varchar(100)

	INSERT INTO @SectionWords VALUES ('Select'), ('Update')


	WHILE EXISTS (Select * from @SectionWords)
	BEGIN
	
		SET @CurrentSectionWord = (select top 1 SectionWord from @SectionWords)
		WHILE @StartPosition > 0  --starts at 1
		

		BEGIN
			SET @NextPosition = CHARINDEX(@CurrentSectionWord, @LogicString, @StartPosition);  --search for match
			

    
			IF @NextPosition > 0  --if search term found
				BEGIN
					--PRINT 'CurrentSectionWord = '+convert(varchar(50), @CurrentSectionWord)
					--PRINT 'MatchPosition = '+convert(varchar(50), @NextPosition)

					SET @MatchSnippet = SUBSTRING(@LogicString, @NextPosition, LEN(@CurrentSectionWord) + 20);
															--take snippet

					--new way
			
					IF CHARINDEX(@CurrentSectionWord, @LogicString) > 0
					BEGIN
						INSERT INTO @SelectTable (
							[Server],
							[CodeSearchID],
							[ObjectName],
							[SectionStart],
							[SectionIdentifier],
							[SectionNum],
							[Snippet],
							[InsertDate]
						)
						VALUES (
							'RPT01',
							@CurrentCodeSearch,
							@ProcName,
							@NextPosition,
							@CurrentSectionWord,
							@SnippetNum,
							@MatchSnippet,
							GETDATE()
						)
					END

					;	--insert snippet
        
					SET @StartPosition = @NextPosition + 1;	--reset start position
					SET @SnippetNum = @SnippetNum + 1		--increment snippet num
				END
			ELSE
			BEGIN
				SET @StartPosition = 0;
			END
		END
		DELETE FROM @SectionWords where SectionWord = @CurrentSectionWord
	END


		INSERT INTO [RPT01].Sandbox2.dbo.CodeSearch_Sections_v1
		([Server], [CodeSearchID], [ObjectName], [SectionStart], [SectionIdentifier], [SectionNum], [Snippet], [InsertDate], [SectionEnd])
	
		Select [Server], [CodeSearchID], [ObjectName], [SectionStart], [SectionIdentifier], [SectionNum], [Snippet], [InsertDate]
				,'SectionEnd' = isnull(LEAD(SectionStart) OVER (partition by CodeSearchID, ObjectName order by SectionNum) - 1, LEN(@LogicString))
				--,'ContainsLogger' = IIF( CHARINDEX('into logger', @
		from @SelectTable

--DECLARE @Timestamp2 datetime = getdate()
--DECLARE @Runtime1 varchar(100) = convert(varchar(25), datediff(ss, @Timestamp1, @Timestamp2))
--PRINT 'Sections Runtime (seconds) - '+@Runtime1
--*********************************************
--	Find all mentions of known tables or views
--*********************************************

		DECLARE @LogTable TABLE ([CodeSearchID] int,
							 [Server] varchar(100), 
							 [ObjectName] varchar(100), 
							-- [Database] varchar(100), 
							-- [ObjectType] varchar(100), 
							-- [ObjectDescription] varchar(max),
							 [Snippet] varchar(max), 
							 [SnippetIndex] int,
							 [SnippetNum] int, 
							 [SearchString] varchar(100), 
							 [SearchDB] varchar(100),
							 [LeftOfSearch] varchar(100),
							 [RightOfSearch] varchar(100),
							 [InsertDate] datetime,
							 [Flex] int, [Flex2] varchar(10))


WHILE EXISTS (select * from @Strings)
BEGIN

	DECLARE @CurrentSearchString varchar(255) = (select top 1 SearchString from @Strings)
	DECLARE @SearchDB varchar(255) = (select top 1 SearchDB from @Strings where SearchString = @CurrentSearchString)
	DECLARE @SearchTable Varchar(255) = (select top 1 SearchTable from @Strings where SearchString = @CurrentSearchString)
	DECLARE @SearchSchema Varchar(25) = (select top 1 SearchSchema from @Strings where SearchString = @CurrentSearchString)
	DECLARE @MainSearch Varchar(255) = @SearchSchema+'.'+@SearchTable

	PRINT 'CurrentCodeSearch = '+convert(varchar(50), @CurrentCodeSearch)
	PRINT 'CurrentTableSearchString = '+convert(varchar(250), @CurrentSearchString)

	SET @StartPosition = 1
	WHILE @StartPosition > 0  --starts at 1
	BEGIN
		SET @NextPosition = CHARINDEX(@MainSearch, @LogicString, @StartPosition);  --search for match
    
		IF @NextPosition > 0  --if search term found
			BEGIN
				SET @MatchSnippet = SUBSTRING(@LogicString, @NextPosition, LEN(@MainSearch) + 20);
														--take snippet
				DECLARE @LeftOfSearch varchar(200) = substring(@LogicString, @NextPosition - LEN(@SearchDB) - 8, LEN(@SearchDB) + 8)
				DECLARE @RightOfSearch varchar(200) = substring(@LogicString, @NextPosition + LEN(@MainSearch), 1) 

				INSERT INTO @LogTable ([Server]
										,[CodeSearchID]
										,[ObjectName]
										,[Snippet]
										,[SnippetIndex]
										,[SnippetNum]
										,[SearchString]
										,[SearchDB]
										,[LeftOfSearch]
										,[RightOfSearch]
										,[InsertDate]
										,[Flex], [Flex2])
				SELECT 'RPT01'
						,@CurrentCodeSearch
						,[sysobjects].name  --,@ProcName changed this 5/26 but was this really the issue?
						,@MatchSnippet
						,@NextPosition
						,@SnippetNum
						,@MainSearch
						,@SearchDB --this is not necessarily contained within the string, in case "USE _____" was stated and no database is specified in the select/update
						,@LeftOfSearch --substring(@LogicString, @NextPosition - LEN(@SearchDB) - 8, 8)
						,@RightOfSearch --substring(@LogicString, @NextPosition + LEN(@MainSearch), 1) 
						,getdate()
						,'ContainsDBaseRef_WrongDB' = IIF(substring(@LogicString, @NextPosition-1,1) = '.' AND CHARINDEX(@SearchDB, @LeftOfSearch) = 0, 1, 0)
						,substring(@LogicString, @NextPosition-1,1)
				FROM [sysobjects]
				WHERE 1=1
				AND [sysobjects].category = 0
				AND @NextPosition > 0
				AND [sysobjects].id = OBJECT_ID(@ProcName)
				AND substring(@LogicString, @NextPosition - LEN(@SearchDB) - 8, 8) not like '%INTO%' --omit into so it doesn't interpret as non-aliased select
				AND substring(@LogicString, @NextPosition + LEN(@MainSearch), 1) in (' ','$') --omit non-matches via table w/i table (e.g. dbo.Data vs dbo.DataRobot --this was formerly done in the 'aliases' table step but it needs to be in here too)
				AND IIF(substring(@LogicString, @NextPosition-1,1) = '.' AND CHARINDEX(@SearchDB, @LeftOfSearch) = 0, 1, 0) = 0 --omit instances where the database IS specified, but a different database is found left of the match
				;										--insert snippet
        
				SET @StartPosition = @NextPosition + 1;	--reset start position
				SET @SnippetNum = @SnippetNum + 1		--increment snippet num
			END
		ELSE
		BEGIN
			SET @StartPosition = 0;
		END
	END
	DELETE From @Strings where SearchString = @CurrentSearchString
END



	--select * from @LogTable

		INSERT INTO [RPT01].Sandbox2.dbo.CodeSearch_Tables_v1
		([Server], [CodeSearchID], [ObjectName], [Snippet], [SnippetIndex], [SnippetNum], [SearchString], [SearchDB], [InsertDate])
	
		Select [Server], [CodeSearchID], [ObjectName], [Snippet], [SnippetIndex], [SnippetNum], [SearchString], [SearchDB], [InsertDate] from @LogTable

--DECLARE @Timestamp3 datetime = getdate()
--DECLARE @Runtime2 varchar(100) = convert(varchar(25), datediff(ss, @Timestamp2, @Timestamp3))
--PRINT 'TableSearch Runtime (seconds) - '+@Runtime2
--**************************************
--	Extract Table Aliases
--**************************************

		--DECLARE @CurrentCodeSearch int = (select top 1 CodeSearchID from Sandbox2.dbo.CodeSearch_Searches_v1) -- placeholder

		INSERT INTO Sandbox2.dbo.CodeSearch_Aliases_v1
		(SnippetID
		 ,CodeSearchID
		  ,[Server]
		 ,[ObjectName]
		 ,SearchDB
		 ,SearchString
		 ,StartIndex
		 ,FirstSpace
		 ,SecondSpace
		 ,NewLine
		 ,StopIndex
		 ,Alias
		 ,NonAlias
		 ,AliasSearchType
		 ,InsertDate)

		select	v.SnippetID
				,@CurrentCodeSearch
				,v.[Server]
				,v.[ObjectName]
				,v.SearchDB
				,v.[SearchString]
				,indices.StartIndex
				,indices.FirstSpace
				,indices.SecondSpace
				,indices.NewLine
				,indices.StopIndex
				,'ALIAS' = IIF(trim(SUBSTRING(v.Snippet, indices.StartIndex, indices.StopIndex-indices.StartIndex)) = '', null, trim(SUBSTRING(v.Snippet, indices.StartIndex, indices.StopIndex-indices.StartIndex)))
				,'NonAlias' = null
				,'AliasSearchType' = CASE					--this is broken
						WHEN indices.SecondSpace > 0 and indices.NewLine = 0 THEN 'space'
						WHEN indices.SecondSpace > 0 and indices.NewLine > 0 and indices.NewLine < indices.SecondSpace THEN 'new line'
						ELSE 'neither space nor new line'
					END 
				,'InsertDate' = getdate()
		from Sandbox2.dbo.CodeSearch_Tables_v1 v
		left join (select SnippetID, 
					 'StartIndex' = CHARINDEX(SearchString, Snippet) + LEN(SearchString), --ends at immediate end of search term
					 'FirstSpace' = CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))),
					 'SecondSpace' = CHARINDEX(' ', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) ),
					 'NewLine' =	 CHARINDEX('$', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) ),
			--this can have anomalies and needs more work. I think multiple spaces before an alias might throw it off?
					 'StopIndex' = CASE when  CHARINDEX(' ', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) ) 
											< CHARINDEX('$', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) ) 
										   OR CHARINDEX('$', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) ) = 0
												then CHARINDEX(' ', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) )

										when  CHARINDEX('$', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) ) 
											< CHARINDEX(' ', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) )
												then CHARINDEX('$', Snippet, 1 + CHARINDEX(' ', Snippet, (CHARINDEX(SearchString, Snippet) + LEN(SearchString))) )
										else null END
						from Sandbox2.dbo.CodeSearch_Tables_v1) indices on v.SnippetID = indices.SnippetID
		left join Sandbox2.dbo.CodeSearch_Aliases_v1 a (nolock) 
			on v.SnippetID = a.SnippetID
			and v.CodeSearchID = a.CodeSearchID
		WHERE 1=1
			AND a.SnippetID is null
			AND v.CodeSearchID = @CurrentCodeSearch
			AND indices.StartIndex >= indices.FirstSpace --added 5/21. Needed to avoid counting the same table within another table (e.g. factLeads within factLeadsAndLoans)

		--Takes recently inserted aliases and checks to see if they are not actually an alias
		--5/18 I added " = ' '" to capture if someone typed {tablename}_newline_. That was being recorded as a space alias.
			UPDATE Sandbox2.dbo.CodeSearch_Aliases_v1
				SET Checked = getdate(),
					Alias = CASE when Alias = ' ' OR Alias like '%)%' OR Alias like '%;%' OR Alias like '%[$]%' OR Alias like '%with%' OR Alias like '%lock%' OR Alias like '%where%' OR Alias like '%inner%' OR Alias like '%left%' OR Alias like '%join%' OR Alias like '%outer%' OR Alias like '%cross%' OR Alias like '%group%' OR Alias like '%select%' then null else Alias END,
					NonAlias = CASE when Alias = ' ' OR Alias like '%)%' OR Alias like '%;%' OR Alias like '%[$]%' OR Alias like '%with%' OR Alias like '%lock%' OR Alias like '%where%' OR Alias like '%inner%' OR Alias like '%left%' OR Alias like '%join%' OR Alias like '%outer%' OR Alias like '%cross%' OR Alias like '%group%' OR Alias like '%select%' then Alias else null END
			from Sandbox2.dbo.CodeSearch_Aliases_v1
			Where Checked is null


--DECLARE @Timestamp4 datetime = getdate()
--DECLARE @Runtime3 varchar(100) = convert(varchar(25), datediff(ss, @Timestamp3, @Timestamp4))
--PRINT 'Aliases Runtime (seconds) - '+@Runtime3
--**************************************
--	Identify specific field references
--**************************************
--This first searches for references found BEFORE the table. These are select/update references. Everything found AFTER the table, but prior to the next select/update statement, is a "criteria only" ref.

------------------------------------
--FOR MANUAL RUNS:
--DECLARE @ProcName varchar(100) = '[dbo].[usp_ac_ProfitScore_V3_test]'
	--DECLARE @LogicString VARCHAR(MAX) = (select REPLACE(OBJECT_DEFINITION(OBJECT_ID(@ProcName)), CHAR(13) + CHAR(10), '%'))
	--DECLARE @SearchString VARCHAR(MAX) = 'CSIDW.dbo.factLeadsAndLoans';
	--DECLARE @SearchDB Varchar(255) = (SELECT LEFT(@SEARCHSTRING, CHARINDEX('.', @SEARCHSTRING) - 1))
	--DECLARE @SearchTable Varchar(255) = (SELECT RIGHT(@SEARCHSTRING, LEN(@SEARCHSTRING) - CHARINDEX('.', @SEARCHSTRING, CHARINDEX('.', @SEARCHSTRING) + 1)) AS RightString)
	--DECLARE @SearchSchema Varchar(255)  = (SELECT SUBSTRING(@SEARCHSTRING, CHARINDEX('.', @SEARCHSTRING) + 1, CHARINDEX('.', @SEARCHSTRING, CHARINDEX('.', @SEARCHSTRING) + 1) - CHARINDEX('.', @SEARCHSTRING) - 1) AS MiddleString)
	--DECLARE @MainSearch Varchar(255) = @SearchSchema+'.'+@SearchTable
	--DECLARE @BracketSearch Varchar(255) = '['+@SearchSchema+'].['+@SearchTable+']'
	--DECLARE @CurrentCodeSearch int = (select max(CodeSearchID) from Sandbox2.dbo.CodeSearch_Searches_v1)
-------------------------------------

	DECLARE @Aliases TABLE (SnippetID int, SnippetIndex int, SearchDB varchar(100), SearchString varchar(100), AliasID int, Alias varchar(100), SectionStart int, SectionEnd int, SectionNum int)
	DECLARE @References TABLE (SearchDB varchar(100), SearchSchema varchar(100), SearchTable varchar(100), FieldName varchar(100), Alias varchar(100), AliasID int, Reference varchar(100))
	DECLARE @MaxCodeSection int = (select max(SectionNum) from Sandbox2.dbo.CodeSearch_Sections_v1 where CodeSearchID = @CurrentCodeSearch)


	

--insert aliases that don't yet exist in the reference table
	--is this the best way of doing this? Seems like I should just pull it by CodeSearchID
	INSERT INTO @Aliases (SnippetID, SnippetIndex, SearchDB, SearchString, AliasID, Alias, SectionStart, SectionEnd, SectionNum)
		SELECT a.SnippetID, t.SnippetIndex, a.SearchDB, a.SearchString, a.AliasID, a.Alias, s.SectionStart, s.SectionEnd, s.SectionNum
		FROM Sandbox2.dbo.CodeSearch_Aliases_v1 a
		join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
		join Sandbox2.dbo.CodeSearch_Sections_v1 s on t.CodeSearchID = s.CodeSearchID and t.SnippetIndex between s.SectionStart and s.SectionEnd
		left join Sandbox2.dbo.CodeSearch_References_v1 r on a.CodeSearchID = r.CodeSearchID and a.SnippetID = r.TableSnippetID and a.AliasID = r.AliasID
		WHERE r.AliasID is null
 

	WHILE EXISTS (select * from @Aliases)
		BEGIN

		DECLARE @CurrentAliasID int = (select top 1 AliasID from @Aliases)
		DECLARE @CurrentAlias varchar(100) = (select top 1 Alias from @Aliases where AliasID = @CurrentAliasID)
		DECLARE @CurrentSnippetIndex int = (select top 1 SnippetIndex from @Aliases where AliasID = @CurrentAliasID)

		DECLARE @RefDB varchar(100) = (select top 1 SearchDB from @Aliases where AliasID = @CurrentAliasID)
		DECLARE @RefSchema varchar(100) = (select top 1 left(SearchString, CHARINDEX('.', SearchString)-1) from @Aliases where AliasID = @CurrentAliasID)
		DECLARE @RefTable varchar(100) = (select top 1 right(SearchString, LEN(SearchString) - CHARINDEX('.', SearchString)) from @Aliases where AliasID = @CurrentAliasID)

	

		INSERT INTO @References (SearchDB, SearchSchema, SearchTable, FieldName, Alias, AliasID, Reference)
			select [DatabaseName], r.SchemaName, r.TableName, r.FieldName, @CurrentAlias, @CurrentAliasID, SearchTerm = IIF(@CurrentAlias is null, FieldName, @CurrentAlias+'.'+FieldName)
			from Sandbox2.dbo.RPT01DataStructure r
			where 1=1
			and r.DatabaseName = @RefDB
			and r.SchemaName = @RefSchema
			and r.TableName = @RefTable


	--	print @CurrentAlias

		WHILE EXISTS (select * from @References)
		BEGIN


			DECLARE @CurrentRef varchar(100) = (select top 1 Reference from @References)
			--print @CurrentRef
	
			DECLARE @RevSearchString varchar(max) = REVERSE(@CurrentRef)
			DECLARE @RevLogicString  varchar(max) = reverse(@LogicString)
			DECLARE @RevSearchIndex int = CHARINDEX(reverse(@CurrentRef), reverse(@LogicString), len(@LogicString) - @CurrentSnippetIndex+1)
			DECLARE @HasMatch		int = IIF(CHARINDEX(reverse(@CurrentRef), reverse(@LogicString), len(@LogicString) - @CurrentSnippetIndex+1) > 0 , 1, 0)
		--Find the most recent either select or update statement (relative to the table ref). Strings are reversed, so the smaller index. 
			DECLARE @RevSelectIndex int = CHARINDEX(reverse('Select'), reverse(@LogicString), CHARINDEX(reverse(@CurrentRef), reverse(@LogicString), len(@LogicString) - @CurrentSnippetIndex+1))
			DECLARE @RevUpdateIndex int = CHARINDEX(reverse('Update'), reverse(@LogicString), CHARINDEX(reverse(@CurrentRef), reverse(@LogicString), len(@LogicString) - @CurrentSnippetIndex+1))
			DECLARE @RevBoundaryIndex int = IIF(@RevUpdateIndex < @RevSelectIndex, @RevUpdateIndex, @RevSelectIndex)
		--if the found reference happened in an earlier section, ignore. Otherwise, extract reference
			DECLARE @RestrictedString varchar(max) = IIF((@RevBoundaryIndex - @RevSearchIndex) <= 0, null, 
															Substring(@RevLogicString, @RevSearchIndex, LEN(@CurrentRef)))
			DECLARE @BigRestrictedString varchar(max) = IIF((@RevBoundaryIndex - @RevSearchIndex) <= 0, null,
															REVERSE(Substring(@RevLogicString, @RevSearchIndex - 5, LEN(@CurrentRef) + 10)) )
			DECLARE @BelongsToPriorAlias int = CASE WHEN @RevSearchIndex < @RevBoundaryIndex then 0 
													WHEN @RevSearchIndex >= @RevBoundaryIndex then 1
												ELSE 5 END --check for nulls, nonmatches, etc

			
		--CriteriaOnly vars:
			DECLARE @CurrentCodeSection int			= (select SectionNum from @Aliases where AliasID = @CurrentAliasID)
			DECLARE @CurrentSectionStart int		= (select SectionStart from @Aliases where AliasID = @CurrentAliasID)
			DECLARE @CurrentSectionEnd int			= (select SectionEnd from @Aliases where AliasID = @CurrentAliasID)
			DECLARE @PostTableString varchar(max)	= IIF(@CurrentSectionEnd - @CurrentSnippetIndex <= 0, null,
															substring(@LogicString, @CurrentSnippetIndex, (@CurrentSectionEnd - @CurrentSnippetIndex)) )
			DECLARE @HasPostTableMatch int			= IIF(CHARINDEX(@CurrentRef, @PostTableString) > 0 , 1, 0)
			DECLARE @PostTableIndex int				= IIF(@HasPostTableMatch = 0, null, CHARINDEX(@CurrentRef, @PostTableString) + @CurrentSnippetIndex)
			DECLARE @PostTableSnippet varchar(100)	= IIF(@HasPostTableMatch = 0, null, substring(@PostTableString, CHARINDEX(@CurrentRef, @PostTableString) - 5, len(@CurrentRef) + 10))

			INSERT INTO [RPT01].Sandbox2.dbo.CodeSearch_References_v1
			(TableSnippetID,
			 AliasID,
			 CodeSearchID,
			 [Server], 
			 [ObjectName], 
			-- [ObjectType],
			 [Database], 
			 [Table], 
			 [Field],  
			 Alias,
			 [Reference],
			 [RefIndex],
			 [RefSnippet],
			-- [SnippetNum],
			 [InsertDate],
			 --LeftOfRef,
			 --LeftOfRef_Rev
			 [IsCriteriaOnly],
			 [CodeSection],
			 [IsPrimaryOutput]
			 )

	
		SELECT 
				DISTINCT 
				TableSnippetID = (select top 1 SnippetID from @Aliases where AliasID = @CurrentAliasID)
				,AliasID = @CurrentAliasID
				,@CurrentCodeSearch
				,'RPT01' as [Server]
				,[sysobjects].name AS [ObjectName] 
				--,'ObjectType' = case 
				--	when [sysobjects].xtype = 'P' then 'Stored Proc'
				--	when [sysobjects].xtype = 'TF' then 'Function'
				--	when [sysobjects].xtype = 'FN' then 'Function'
				--	when [sysobjects].xtype = 'TR' then 'Trigger'
				--	when [sysobjects].xtype = 'V' then 'View'
				--	end 
				,'Database' = @RefDB
				,'Table' = @RefTable
				,'Field' = (select top 1 FieldName from @References where Reference = @CurrentRef)
				,'Alias' = @CurrentAlias
				,'Reference' = @CurrentRef
				,'RefIndex' = LEN(@LogicString) - @RevSearchIndex
				,'RefSnippet' = @BigRestrictedString
				,getdate()
				,'IsCriteriaOnly' = 0
				,'CodeSection' = @CurrentCodeSection
				,'IsPrimaryOutput' = IIF(@CurrentCodeSection = @MaxCodeSection, 1, 0)  --'select' fields only
			FROM [sysobjects]--,[syscomments]
			WHERE 1=1
			AND [sysobjects].category = 0
			AND @HasMatch = 1
			AND @BelongsToPriorAlias = 0
			AND [sysobjects].id = OBJECT_ID(@ProcName)
		--final check for reference within another reference (e.g. fl.DatasourceID within prevfl.DataSourceID)
			AND SUBSTRING(@BigRestrictedString, CHARINDEX(@CurrentRef, @BigRestrictedString) - 1, 1) in (' ','	',',','$')

		UNION
		
		--References used in joins, filters, etc (AFTER the select/update):
			SELECT 
				DISTINCT 
				TableSnippetID = (select top 1 SnippetID from @Aliases where AliasID = @CurrentAliasID)
				,AliasID = @CurrentAliasID
				,@CurrentCodeSearch
				,'RPT01' as [Server]
				,[sysobjects].name AS [ObjectName] 
				--,'ObjectType' = case 
				--	when [sysobjects].xtype = 'P' then 'Stored Proc'
				--	when [sysobjects].xtype = 'TF' then 'Function'
				--	when [sysobjects].xtype = 'FN' then 'Function'
				--	when [sysobjects].xtype = 'TR' then 'Trigger'
				--	when [sysobjects].xtype = 'V' then 'View'
				--	end 
				,'Database' = @RefDB
				,'Table' = @RefTable
				,'Field' = (select top 1 FieldName from @References where Reference = @CurrentRef)
				,'Alias' = @CurrentAlias
				,'Reference' = @CurrentRef
				,'RefIndex' = @PostTableIndex
				,'RefSnippet' = @PostTableSnippet
				,getdate()
				,'IsCriteriaOnly' = 1
				,'CodeSection' = @CurrentCodeSection
				,'IsPrimaryOutput' = 0
			FROM [sysobjects]--,[syscomments]
			WHERE 1=1
			AND [sysobjects].category = 0
			AND @HasPostTableMatch = 1
			AND [sysobjects].id = OBJECT_ID(@ProcName)
		--final check for reference within another reference (e.g. fl.DatasourceID within prevfl.DataSourceID)
			AND SUBSTRING(@PostTableSnippet, CHARINDEX(@CurrentRef, @PostTableSnippet) - 1, 1) in (' ','	',',','$', '=') --also '=' for where clause/join fields


			DELETE from @References where Reference = @CurrentRef
		END


		DELETE from @Aliases where AliasID = @CurrentAliasID
	END

--DECLARE @Timestamp5 datetime = getdate()
--DECLARE @Runtime4 varchar(100) = convert(varchar(25), datediff(ss, @Timestamp4, @Timestamp5))
--PRINT 'References Runtime (seconds) - '+@Runtime4

--Search for any found references in final section in case the last is some variant of "select...from earlier #temp"
--I thought about ONLY doing this where you have a select from temp in the last section, but that might miss some. Rather have extra than be missing primaries.
----------------------------------------------------------------------------
--FOR MANUAL RUNS:
	--DECLARE @ProcName varchar(100) = 'dbo.usp_ac_FraudAnomalyModel_v1'
	--DECLARE @CurrentCodeSearch int = (select top 1 CodeSearchID from Sandbox2.dbo.CodeSearch_Searches_v1 where LastSearched is null and ObjectName = @ProcName order by InsertDate desc)
	--DECLARE @MaxCodeSection int = (select max(SectionNum) from Sandbox2.dbo.CodeSearch_Sections_v1 where CodeSearchID = @CurrentCodeSearch)
	--DECLARE @NewLineSub VARCHAR(MAX) = (select REPLACE(OBJECT_DEFINITION(OBJECT_ID(@ProcName)), CHAR(13) + CHAR(10), '$'))	--change new lines for $
	--DECLARE @LogicString VARCHAR(MAX) = (select LOWER(REPLACE(REPLACE(@NewLineSub, '[', ''), ']', '')))
----------------------------------------------------------------------------

	DECLARE @PrimaryStart int = (select SectionStart from Sandbox2.dbo.CodeSearch_Sections_v1 where CodesearchID = @CurrentCodeSearch and SectionNum = @MaxCodeSection)
	DECLARE @PrimaryEnd int = (select SectionEnd from Sandbox2.dbo.CodeSearch_Sections_v1 where CodesearchID = @CurrentCodeSearch and SectionNum = @MaxCodeSection)

--Update Primaries if also found in final select/update
	UPDATE Sandbox2.dbo.CodeSearch_References_v1
		SET IsPrimaryOutput = 1
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	WHERE IsPrimaryOutput = 0
	AND CHARINDEX(Field, SUBSTRING(@LogicString, @PrimaryStart, LEN(@LogicString) - @PrimaryStart))>0

	UPDATE Sandbox2.dbo.CodeSearch_Searches_v1 
		SET LastSearched = getdate(),
			FieldsMapped = sub.numfound
	FROM Sandbox2.dbo.CodeSearch_Searches_v1 s
	join (select s.CodeSearchID, 'numfound' = count(distinct r.ReferenceID)
			from Sandbox2.dbo.CodeSearch_Searches_v1 s
			left join Sandbox2.dbo.CodeSearch_References_v1 r on s.CodeSearchID = r.CodeSearchID
			group by s.CodeSearchID) sub on s.CodeSearchID = sub.CodeSearchID
	WHERE s.CodeSearchID = @CurrentCodeSearch


--Output Results at end of sproc exec (optional)
	--select * from Sandbox2.dbo.CodeSearch_Searches_v1	where CodesearchID = @CurrentCodeSearch
	--select * from Sandbox2.dbo.CodeSearch_Sections_v1	where CodesearchID = @CurrentCodeSearch
	--select * from Sandbox2.dbo.CodeSearch_Tables_v1		where CodesearchID = @CurrentCodeSearch
	--select * from Sandbox2.dbo.CodeSearch_Aliases_v1	where CodesearchID = @CurrentCodeSearch
	--select * from Sandbox2.dbo.CodeSearch_References_v1 where CodesearchID = @CurrentCodeSearch
	--order by CodeSearchID, CodeSection, RefIndex


---------------------- deactivating the transaction stuff for now since it makes it tough to troubleshoot
	COMMIT;
END TRY

BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK;  
END CATCH;
----------------------

END
