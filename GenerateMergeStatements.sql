USE Master
GO

/****** Object:  StoredProcedure [dbo].[dba_GenerateMergeStatement]    Script Date: 4/8/2017 7:06:49 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[dba_GenerateMergeStatement]
    (@table NVARCHAR(128) )
AS
set nocount on; 
declare @return int;


PRINT '-- ' + @table + ' -------------------------------------------------------------'
--PRINT 'SET NOCOUNT ON;
--'
-- Set the identity insert on for tables with identities
select @return = objectproperty(object_id(@table), 'TableHasIdentity')
if @return = 1 
    PRINT 'SET IDENTITY_INSERT [dbo].[' + @table + '] ON;
    '


declare @sql varchar(max) = ''
declare @list varchar(max) = '';

SELECT @list = @list + [name] +', '
from sys.columns
where object_id = object_id(@table)


SELECT @list = @list + [name] +', '
from sys.columns
where object_id = object_id(@table)


SELECT @list = @list + 's.' + [name] +', '
from sys.columns
where object_id = object_id(@table)

-- --------------------------------------------------------------------------------
PRINT 'MERGE [dbo].[' + @table + '] AS t'
PRINT 'USING (SELECT * FROM [source_database].[dbo].[' + @table + ']) as s'

-- Get the join columns ----------------------------------------------------------
SET @list = ''
select     @list = @list + 't.[' + c.COLUMN_NAME + '] = s.[' +  c.COLUMN_NAME + '] AND '
from     INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
    INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
where     pk.TABLE_NAME = @table
and    CONSTRAINT_TYPE = 'PRIMARY KEY'
and    c.TABLE_NAME = pk.TABLE_NAME
and    c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

SELECT @list =  LEFT(@list, LEN(@list) -3)
PRINT 'ON ( ' + @list + ')'


-- WHEN MATCHED ------------------------------------------------------------------
PRINT 'WHEN MATCHED THEN UPDATE SET'

SELECT @list = '';
SELECT @list = @list + '    [' + [name] +  '] = s.[' + [name] +'],
'
FROM sys.columns
WHERE object_id = OBJECT_ID(@table)
-- don't update primary keys
AND [name] NOT IN (SELECT  [column_name]
                    FROM     INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk ,
                            INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
                    WHERE     pk.TABLE_NAME = @table
                    AND    CONSTRAINT_TYPE = 'PRIMARY KEY'
                    AND    c.TABLE_NAME = pk.TABLE_NAME
                    AND    c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME)
-- and don't update identity columns
AND COLUMNPROPERTY(OBJECT_ID(@table), [name], 'IsIdentity ') = 0                    
--print @list                    
PRINT LEFT(@list, LEN(@list) -3 )

-- WHEN NOT MATCHED BY TARGET ------------------------------------------------
PRINT ' WHEN NOT MATCHED BY TARGET THEN';

-- Get the insert list
SET @list = ''

SELECT @list = @list + '[' + [name] +'], '
FROM sys.columns
WHERE object_id = OBJECT_ID(@table)

SELECT @list = LEFT(@list, LEN(@list) - 1)

PRINT '    INSERT(' + @list + ')'

-- get the values list
SET @list = ''

SELECT @list = @list + 's.[' +[name] +'], '
FROM sys.columns
WHERE object_id = OBJECT_ID(@table)

SELECT @list = LEFT(@list, LEN(@list) - 1)

PRINT '    VALUES(' + @list + ')'

-- WHEN NOT MATCHED BY SOURCE
PRINT 'WHEN NOT MATCHED BY SOURCE THEN DELETE; '

PRINT ''

PRINT 'PRINT ''' + @table + ': '' + CAST(@@ROWCOUNT AS VARCHAR(100));';
PRINT ''

-- Set the identity insert OFF for tables with identities
SELECT @return = OBJECTPROPERTY(OBJECT_ID(@table), 'TableHasIdentity')
IF @return = 1 
    PRINT 'SET IDENTITY_INSERT [dbo].[' + @table + '] OFF;
    '
PRINT ''
PRINT 'GO'
PRINT '';


GO


