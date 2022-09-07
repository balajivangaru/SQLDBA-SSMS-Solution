use DBA_Admin
go

declare @top_filter int = 30;

declare @start_time_snap1	datetime2 = '2022-09-05 15:30';
declare @start_time_snap2	datetime2 = '2022-09-07 15:30';
declare @end_time_snap1		datetime2 = '2022-09-05 16:00';
declare @end_time_snap2		datetime2 = '2022-09-07 16:00';

if object_id('tempdb..#current') is not null drop table #current;
;with cte as (
	select --top 100 
			[query] = 'total-stats',
			[date] = convert(date,event_time), 
			[row_rank] = row_number()over(partition by convert(date,event_time) order by sum(logical_reads) desc),
			--database_name, username, client_app_name, client_hostname, client_app_name,
			username,
			logical_reads_gb = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024), 
			logical_reads_mb = convert(numeric(20,2),sum(logical_reads)*8.0/1024), 
			cpu_time_minutes = (sum(cpu_time)/1e+6)/60,
			cpu_time = convert(varchar,floor((sum(cpu_time)/1e+6)/60/60/24)) + ' Day '+ convert(varchar,dateadd(second,(sum(cpu_time)/1e+6),'1900-01-01 00:00:00'),108)
			,[executions > 5 sec] = count(1)
	from dbo.resource_consumption rc
	where rc.event_time between @start_time_snap2 and @end_time_snap2
	group by convert(date,event_time), 
			--database_name, username, client_app_name, client_hostname, client_app_name
			username
)
select * into #current from cte where row_rank <= @top_filter
order by [date],[row_rank];

if object_id('tempdb..#previous') is not null drop table #previous;
;with cte as (
	select --top 100 
			[query] = 'total-stats',
			[date] = convert(date,event_time),
			[row_rank] = row_number()over(partition by convert(date,event_time) order by sum(logical_reads) desc),
			--database_name, username, client_app_name, client_hostname, client_app_name,
			username,
			logical_reads_gb = convert(numeric(20,2),sum(logical_reads)*8.0/1024/1024), 
			logical_reads_mb = convert(numeric(20,2),sum(logical_reads)*8.0/1024), 
			cpu_time_minutes = (sum(cpu_time)/1e+6)/60,
			cpu_time = convert(varchar,floor((sum(cpu_time)/1e+6)/60/60/24)) + ' Day '+ convert(varchar,dateadd(second,(sum(cpu_time)/1e+6),'1900-01-01 00:00:00'),108)
			,[executions > 5 sec] = count(1)
	from dbo.resource_consumption rc
	where rc.event_time between @start_time_snap1 and @end_time_snap1
	group by convert(date,event_time), 
			--database_name, username, client_app_name, client_hostname, client_app_name
			username
)
select * into #previous from cte where row_rank <= @top_filter
order by [date],[row_rank];

select	[query] = coalesce(c.query,p.query), 		
		[date-snap1] = coalesce(p.date, prev_date),
		[date-snap2] = coalesce(c.date, cur_date), 
		username = coalesce(c.username,p.username),
		[logical_reads_gb-snap1] = p.logical_reads_gb,
		[logical_reads_gb-snap2] = c.logical_reads_gb,		
		[logical_reads_gb (??)] = case when isnull(c.logical_reads_gb,0.0) > isnull(p.logical_reads_gb,0.0) 
										then convert(varchar,isnull(c.logical_reads_gb,0.0) - isnull(p.logical_reads_gb,0.0))+N' ?'
										when isnull(c.logical_reads_gb,0.0) = isnull(p.logical_reads_gb,0.0) then '='
										else convert(varchar,isnull(p.logical_reads_gb,0.0)-isnull(c.logical_reads_gb,0.0))+N' ?' end,
		[cpu_time-snap1] = p.cpu_time,
		[cpu_time-snap2] = c.cpu_time,		
		[executions > 5 sec - snap1] = p.[executions > 5 sec],
		[executions > 5 sec - snap2] = c.[executions > 5 sec],
		[executions (??)] = case when isnull(c.[executions > 5 sec],0) > isnull(p.[executions > 5 sec],0) 
										then convert(varchar,isnull(c.[executions > 5 sec],0) - isnull(p.[executions > 5 sec],0))+N' ?'
										when isnull(c.[executions > 5 sec],0) = isnull(p.[executions > 5 sec],0) then '='
										else convert(varchar,isnull(p.[executions > 5 sec],0)-isnull(c.[executions > 5 sec],0))+N' ?' end
		,[logical_reads_gb_TOTAL (??)] = case when (sum(c.logical_reads_gb)over()) - (sum(p.logical_reads_gb)over()) >= 0.0 
												then convert(varchar,(sum(c.logical_reads_gb)over()) - (sum(p.logical_reads_gb)over()))+N' ?'
											  else convert(varchar,(sum(p.logical_reads_gb)over())-(sum(c.logical_reads_gb)over()))+N' ?'
											  end
from #current c full outer join #previous p on c.username = p.username
outer apply (select top 1 i.date as cur_date from #current i) cur
outer apply (select top 1 i.date as prev_date from #previous i) prev
where abs(isnull(c.logical_reads_gb,0.0) - isnull(p.logical_reads_gb,0.0)) >= 10
--order by abs(isnull(c.logical_reads_gb,0.0) - isnull(p.logical_reads_gb,0.0)) desc
order by abs(isnull(c.cpu_time_minutes,0.0) - isnull(p.cpu_time_minutes,0.0)) desc
go