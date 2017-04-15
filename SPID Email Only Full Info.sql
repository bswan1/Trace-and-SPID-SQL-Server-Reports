/*
    This script will check for long running SPIDS and mail the SPID number, duration,
    username and the SQL being executed. It can be run ad-hoc or run as a scheduled job 
    and reports on the longest running SPIDs with an execution time greater than 2 minutes
    It will email an HTML formatted table.
    
    The script uses a table called master.dbo.LongRunningQueries, but you can use a
    temp table or put this table wherever you want - table create script below    :
    
    *******************************************
    
    USE [master]
    GO

    CREATE TABLE [dbo].[LongRunningQueries](
    [spid] [int] NULL,
    [batch_duration] [time](3) NULL,
    [program_name] [nvarchar](500) NULL,
    [hostname] [nvarchar](100) NULL,
    [loginame] [nvarchar](100) NULL
    ) ON [PRIMARY]

    GO
    
    ********************************************/

-- variable declaratuions
DECLARE @exectime TIME(3)
DECLARE @tableHTML NVARCHAR(MAX)
DECLARE @Handle VARBINARY (85)
DECLARE @SPID INT
DECLARE @sqltext NVARCHAR(MAX)

-- clear results of last run from table
TRUNCATE TABLE LongRunningQueries

-- populate the table with execution info, you don't have to use top 1
INSERT INTO master.dbo.LongRunningQueries
SELECT top 1 P.spid
            , RIGHT(CONVERT(VARCHAR,DATEADD(ms, DATEDIFF(ms, P.last_batch, GETDATE()), '1900-01-01'), 121), 12)
            , P.program_name
            , P.hostname
            , P.loginame
FROM master.dbo.sysprocesses P WITH (NOLOCK)
WHERE     P.spid > 50 
        AND P.status NOT IN ('background', 'sleeping')
        AND P.cmd NOT IN ('AWAITING COMMAND','MIRROR HANDLER','LAZY WRITER','CHECKPOINT SLEEP','RA MANAGER')

-- put the excution time of the longest runnifn SPID in a variable        
SET @exectime = (SELECT top 1 batch_duration from master.dbo.LongRunningQueries)

-- put the SPID in a variable
SET @SPID = (SELECT top 1 spid from master.dbo.LongRunningQueries)

-- get the SQL the SPID is executing
SELECT @Handle = sql_handle FROM master.dbo.sysprocesses WHERE spid = @SPID
set @sqltext = (SELECT text FROM ::fn_get_sql (@Handle))

-- if the SPID is executing for longer than 2 mins populate a table with it's info and mail it
IF @exectime > (CAST('00:02:00.000' AS TIME(3))) BEGIN
SET @tableHTML = N'<H1>Long Running WFM Querys</H1>' +
 N'<table border="1">' +
 N'<tr><th>SPID</th>' +
 N'<th>Duration</th>' +
 N'<th>Application</th>' +
 N'<th>HostName</th>' +
 N'<th>Login</th>' +
 N'<th>SQL Executing</th></tr>' +
 CAST ( ( SELECT td = T.spid, '',
 td = T.batch_duration, '',
 td = T.[program_name], '',
 td = T.hostname, '',
 td = T.loginame, '',
 td = @sqltext, ''
 FROM 
 master.dbo.LongRunningQueries T 
 FOR XML PATH('tr'), TYPE
 ) AS NVARCHAR(MAX) ) +
 N'</table>'
 
 EXEC msdb.dbo.sp_send_dbmail
 @profile_name = 'Default',
 @recipients= 'me@mycompany.com;you@yourcompany.com',
 @subject = 'Long Running WFM Query found',
 @body = @tableHTML,
 @body_format = 'HTML';
END