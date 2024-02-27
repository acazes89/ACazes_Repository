
--******************************************************************************
-- CreditServe SQL Reference Mapper
--******************************************************************************

--Author: Adam Cazes
--Created: 5/22/23
--Description: Identifies all references to known database objects within a given stored procedure or piece of code
--Instructions:
	--As it's currently written, this needs to be connected to the same database as the sproc in order to work properly!!! Select the DB in the AvailableDatabases dropdown at the top left in SSMS.
	--I make no promises as to the performance of this on a piece of code that uses dynamic sql loops
	--Also, the field IsPrimaryOutput is really only designed to work for more straightforward code like model training and report sprocs. It may misidentify them for more complex logic like the CSIDW sprocs.
	--Last step is to double check the 'primary output' designation of fields. 
		--add this later? May make the overall presentation more confusing
-------------------------------------------------------------------------------------
--Change Log:


-------------------------------------------------------------------------------------


	DECLARE	@ProcName varchar(100)
	DECLARE	@ProcDB varchar(100)
	DECLARE	@Description varchar(max)
	DECLARE	@Author varchar(50)
	DECLARE	@IsReport bit
	DECLARE	@IsModelTraining bit
	DECLARE @Directory varchar(250)
	DECLARE @SQL varchar(max)


--use [schema].[name] to run codesearch on a stored procedure already written to a database. If copy-pasting your code, give it a title:
	SET @ProcName = 'dbo.usp_ac_ProfitScore_V3_test'	--''--	
	--SET @ProcName = 'usp_ac_FraudAnomalyModel_v1'

--specify the database. Select this same database in the [Available Databases] dropdown at the top left in SSMS.
	SET @ProcDB = 'Sandbox'

--describe your piece of code. What is its purpose?
	SET @Description = 'this started as a copy of [usp_ac_ProfitScore_V3], but I modified it to provide examples of various potential issues you can have when searching text strings'

--your name
	SET @Author = 'Adam Cazes'

--Is this a report? Type the number one if so, zero if not. We should probably restrict it to production level reports, not casual research.
	SET @IsReport = 0

--Is this the training sproc for a (production) model? One if so, zero if not.
	SET @IsModelTraining = 0

--Where did you save the code to? This may be helpful if someone actually wants to see the code with formatting intact. 
	SET @Directory = 'F:\Public\Personal Folders\AdamC\Projects\Reference Mapper\ProfitScore Test Sproc'

--If this is an ad-hoc query, insert your logic here. You'll need to find and replace your single quotes with double quotes:
	SET @SQL = ''


	--Now, execute this entire page. Your results, as well as some sample queries for researching the code library, are listed below. 
	--If anything is incorrect, notify the owner of this sproc, and (update the temp tables before they are written to prod overnight??).


--EXEC usp_ac_ReferenceSearch_v1_test
EXEC usp_ac_ReferenceSearch_v1
	@ProcName, @ProcDB, @Description, @Author, @IsReport, @IsModelTraining, @Directory, @SQL


--YOUR RESULT
	DECLARE @CurrentCodeSearch int = (select max(CodeSearchID) from Sandbox2.dbo.CodeSearch_Searches_v1_test)

	SELECT r.CodeSearchID, r.Server, r.[ObjectName], r.TableSnippetID, a.SearchDB as 'MappedDB', a.SearchString as 'MappedTable', r.AliasID, a.Alias, a.NonAlias, r.ReferenceID, r.Reference as 'MappedField', r.RefIndex, r.RefSnippet, r.IsCriteriaOnly, r.CodeSection, r.IsPrimaryOutput
	FROM Sandbox2.dbo.CodeSearch_References_v1_test r
	join Sandbox2.dbo.CodeSearch_Aliases_v1_test a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1_test t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	WHERE r.CodesearchID = @CurrentCodeSearch
	order by r.CodeSearchID, r.CodeSection, r.RefIndex


--By default, the "primary" outputs are those located in the final select statment. If you need to alter which code section to use, or individual fields, do so here:

	--UPDATE Sandbox2.dbo.CodeSearch_References_v1 
	--	SET IsPrimaryOutput = CASE 
	--							when r.CodeSection = 10 then 1 
	--							--when r.ReferenceID in (100,101,102)	then 1 
	--							else 0 END
	--FROM Sandbox2.dbo.CodeSearch_References_v1 r

-----------------------------------------
-- Sample Queries
-----------------------------------------
																										/*
 Examples of things you can query:																																									
	A) If you want to see all reports where primary output = x
	B) If you want to see all models that use x as primary input
	C) If you want to see everything that depends on a given broken field
	D) If you want to see everywhere that something portfolio specific is hard-coded
	E) If you want to see all ad-hoc reports on subject x that used field y	
	G) Find past reporting code related to title keywords to avoid double work*/


-- A) All reports that have field ______ as a primary OUTput: Example ACHOptInRate

	SELECT DISTINCT r.Server, s.ObjectName, s.ObjectType, s.ObjectDescription, s.InsertDate, s.LastSearched
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND r.IsPrimaryOutput = 1
	AND s.IsReport = 1
	and r.Field like 'ACH'
	

-- B) All MODELS that have field ______ as a primary INput: Example ACHOptIn (did they or did they not)

	SELECT DISTINCT r.Server, s.ObjectName, s.ObjectType, s.ObjectDescription, s.InsertDate, s.LastSearched
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND r.IsPrimaryOutput = 1
	AND s.IsModelTraining = 1
	and r.Field like 'ACH'
	and r.Field like 'Opt'


-- C) Search for the correct logic for _______: 
	--Example OriginalStoreGroup

	SELECT DISTINCT s.Server, s.ObjectName, s.ObjectType, s.ObjectDescription, s.InsertDate, s.LastSearched, s.Directory
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND CHARINDEX('%StoreGroup%', s.FullString) > 0
	AND CHARINDEX('%NoVerification%', s.FullString) > 0

-- D) All sprocs that pull from table________: Example LoanDocsTrackingV2 

	SELECT DISTINCT r.Server, s.ObjectName, s.ObjectType, s.ObjectDescription, s.InsertDate, s.LastSearched
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND s.ObjectType = 'Stored Proc'
	AND (r.[Database] = 'LeadEnvy' and r.[Table] = 'LoanDocsTrackingV2')

-- E) Search the actual code snippet from the sprocs above

	SELECT DISTINCT s.ObjectID, s.FullString
	into #strings
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND s.ObjectType = 'Stored Proc'
	AND (r.[Database] = 'LeadEnvy' and r.[Table] = 'LoanDocsTrackingV2')

	select s.ObjectID, s.FullString, 
			'Snippet' = substring(s.FullString, CHARINDEX('LoanDocsTrackingV2', s.FullString) - 200, 500)
	from #strings s
	Where 1=1
	AND CHARINDEX('join LeadEnvy.dbo.LoanDocsTrackingV2', s.FullString) > 0

-- F) All portfolio-specific logic

	SELECT DISTINCT r.Server, s.ObjectName, s.ObjectType, s.ObjectDescription
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a 
		on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t 
		on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s 
		on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND CHARINDEX('DatasourceID = 1', s.FullString) > 0

-- G) Find past reporting code related to title keywords to avoid double work

	SELECT DISTINCT r.Server, s.ObjectName, s.ObjectType, s.ObjectDescription, s.InsertDate, s.LastSearched
	FROM Sandbox2.dbo.CodeSearch_References_v1 r
	join Sandbox2.dbo.CodeSearch_Aliases_v1 a on r.CodeSearchID = a.CodeSearchID and r.AliasID = a.AliasID
	join Sandbox2.dbo.CodeSearch_Tables_v1 t on a.CodeSearchID = t.CodeSearchID and a.SnippetID = t.SnippetID
	join Sandbox2.dbo.CodeSearch_Searches_v1 s on r.CodeSearchID = s.CodeSearchID
	WHERE 1=1
	AND s.ObjectType = 'Ad-Hoc'
	AND (CASE when CHARINDEX('Page', s.ObjectDescription) > 0 then 1
			  when CHARINDEX('Traffic', s.ObjectDescription) > 0 then 1
			  else 0 END) = 1
	OR (r.[Database] = 'LeadEnvy' AND r.[Table] IN ('TestFlowPages', 'TestFlows', 'TestGroups'))
	