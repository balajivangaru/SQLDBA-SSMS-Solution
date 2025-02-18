select 
 j.name as 'JobName',
 s.step_id as 'Step',
 s.step_name as 'StepName',
 msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
 ((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) 
         as 'RunDurationMinutes'
From msdb.dbo.sysjobs j 
INNER JOIN msdb.dbo.sysjobsteps s 
 ON j.job_id = s.job_id
INNER JOIN msdb.dbo.sysjobhistory h 
 ON s.job_id = h.job_id 
 AND s.step_id = h.step_id 
 AND h.step_id <> 0
where j.enabled = 1   --Only Enabled Jobs
--and j.name IN ('ResLink Autofill','ResLink Control') --Uncomment to search for a single job
/*
and msdb.dbo.agent_datetime(run_date, run_time) 
BETWEEN '12/08/2012' and '12/10/2012'  --Uncomment for date range queries
*/
order by RunDateTime desc,JobName
go


select	j.name as 'JobName',
		msdb.dbo.agent_datetime(run_date, run_time) as 'RunDateTime',
		((run_duration/10000*3600 + (run_duration/100)%100*60 + run_duration%100 + 31 ) / 60) as 'RunDurationMinutes',
		h.step_id
From msdb.dbo.sysjobs j 
INNER JOIN msdb.dbo.sysjobhistory h 
 ON j.job_id = h.job_id 
where j.enabled = 1  --Only Enabled Jobs
and msdb.dbo.agent_datetime(run_date, run_time) >= DATEADD(hour,-3,getdate())
and j.name = '(dba) Collect-PerfmonData'
and h.step_id = 0
order by JobName, RunDateTime desc