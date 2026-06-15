whenever sqlerror exit sql.sqlcode
set pages 500 lines 260 trimspool on tab off verify off feedback on
set numwidth 20
column name format a38
column value format a120
column input_type format a24
column status format a24
column start_time format a20
column end_time format a20
column completion_time format a20
column file_name format a150
column handle format a150
column device_type format a18
column backup_status format a34
column backup_class format a22
column start_day format a10

prompt # Backup SQL Evidence
prompt
prompt ## Database Backup Context
select name, db_unique_name, database_role, open_mode, cdb, log_mode,
       force_logging, flashback_on
from v$database;

prompt ## RMAN Configuration
select name, value from v$rman_configuration order by name;

prompt ## RMAN Job History - Last 60 Jobs
select *
from (
  select session_key, input_type, status,
         to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') start_time,
         to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') end_time,
         round(elapsed_seconds / 60, 1) elapsed_minutes,
         output_device_type, input_bytes_display, output_bytes_display
  from v$rman_backup_job_details
  order by start_time desc
)
where rownum <= 60;

prompt ## Observed Job Cadence By Type, Day, And Hour
select nvl(input_type, 'UNKNOWN') input_type,
       to_char(start_time, 'DY', 'NLS_DATE_LANGUAGE=English') start_day,
       to_char(start_time, 'HH24') start_hour,
       count(*) job_count,
       to_char(min(start_time), 'YYYY-MM-DD HH24:MI:SS') first_observed,
       to_char(max(start_time), 'YYYY-MM-DD HH24:MI:SS') last_observed
from v$rman_backup_job_details
where start_time >= sysdate - 60
group by nvl(input_type, 'UNKNOWN'),
         to_char(start_time, 'DY', 'NLS_DATE_LANGUAGE=English'),
         to_char(start_time, 'HH24')
order by input_type, job_count desc, start_day, start_hour;

prompt ## Datafile Backup Coverage
select df.file#, df.name file_name,
       to_char(max(bdf.completion_time), 'YYYY-MM-DD HH24:MI:SS') last_backup_time,
       min(bdf.incremental_level) keep (dense_rank last order by bdf.completion_time nulls first) last_incremental_level,
       case when max(bdf.completion_time) is null then 'NO BACKUP IN CONTROL FILE METADATA'
            else 'BACKUP METADATA FOUND'
       end backup_status
from v$datafile df
left join v$backup_datafile bdf on bdf.file# = df.file#
group by df.file#, df.name
order by df.file#;

prompt ## Datafile Backup Levels - Last 90 Days
select case when incremental_level is null then 'FULL/NON-INCREMENTAL'
            else 'LEVEL ' || to_char(incremental_level)
       end backup_class,
       count(*) backed_file_entries,
       to_char(min(completion_time), 'YYYY-MM-DD HH24:MI:SS') first_observed,
       to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS') last_observed
from v$backup_datafile
where completion_time >= sysdate - 90
group by incremental_level
order by backup_class;

prompt ## Backup Piece Status
select status, device_type, count(*) piece_count,
       to_char(min(completion_time), 'YYYY-MM-DD HH24:MI:SS') oldest_completion,
       to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS') latest_completion
from v$backup_piece
group by status, device_type
order by status, device_type;

prompt ## Recent Backup Pieces
select *
from (
  select recid, stamp, status, device_type,
         to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time,
         round(bytes/1024/1024/1024, 2) size_gb,
         compressed, handle
  from v$backup_piece
  order by completion_time desc nulls last
)
where rownum <= 80;

prompt ## Archived Redo Backup Coverage - Last 7 Days
select thread#, sequence#,
       to_char(first_time, 'YYYY-MM-DD HH24:MI:SS') first_time,
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time,
       deleted, backup_count, name
from v$archived_log
where completion_time >= sysdate - 7
  and name is not null
order by thread#, sequence#;

prompt ## Unbacked Archived Redo Logs
select thread#, sequence#,
       to_char(first_time, 'YYYY-MM-DD HH24:MI:SS') first_time,
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time,
       deleted, backup_count, name
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0
order by completion_time;

prompt ## Backup Corruption Views
select 'V$DATABASE_BLOCK_CORRUPTION' source_name, count(*) row_count from v$database_block_corruption
union all
select 'V$COPY_CORRUPTION' source_name, count(*) row_count from v$copy_corruption
union all
select 'V$BACKUP_CORRUPTION' source_name, count(*) row_count from v$backup_corruption;

prompt ## Files Requiring Media Recovery
select * from v$recover_file order by file#;

prompt ## FRA Usage
select name, round(space_limit/1024/1024/1024,2) space_limit_gb,
       round(space_used/1024/1024/1024,2) space_used_gb,
       round(space_reclaimable/1024/1024/1024,2) space_reclaimable_gb,
       number_of_files
from v$recovery_file_dest;

prompt ## FRA Usage By File Type
select file_type, percent_space_used, percent_space_reclaimable, number_of_files
from v$flash_recovery_area_usage
order by file_type;

prompt ## Data Guard / RPO Adjacent Evidence
select dest_id, status, target, destination, db_unique_name, valid_now, error
from v$archive_dest
where destination is not null
order by dest_id;

select name, value, unit, time_computed, datum_time
from v$dataguard_stats
order by name;

exit
