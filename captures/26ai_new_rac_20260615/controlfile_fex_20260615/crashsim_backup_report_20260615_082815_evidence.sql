whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off

select 'CSIM_BKP|db_name|' || name from v$database;
select 'CSIM_BKP|db_unique_name|' || db_unique_name from v$database;
select 'CSIM_BKP|dbid|' || dbid from v$database;
select 'CSIM_BKP|database_role|' || database_role from v$database;
select 'CSIM_BKP|open_mode|' || open_mode from v$database;
select 'CSIM_BKP|cdb|' || cdb from v$database;
select 'CSIM_BKP|log_mode|' || log_mode from v$database;
select 'CSIM_BKP|force_logging|' || force_logging from v$database;
select 'CSIM_BKP|flashback_on|' || flashback_on from v$database;
select 'CSIM_BKP|platform_name|' || platform_name from v$database;

select 'CSIM_BKP|control_file_record_keep_time|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'control_file_record_keep_time';
select 'CSIM_BKP|archive_lag_target|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'archive_lag_target';
select 'CSIM_BKP|db_recovery_file_dest|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'db_recovery_file_dest';

select 'CSIM_BKP|rman_retention_policy|' ||
       nvl(max(case when name = 'RETENTION POLICY' then value end), 'DEFAULT')
from v$rman_configuration;
select 'CSIM_BKP|rman_controlfile_autobackup|' ||
       nvl(max(case when name = 'CONTROLFILE AUTOBACKUP' then value end), 'DEFAULT/OFF')
from v$rman_configuration;
select 'CSIM_BKP|rman_backup_optimization|' ||
       nvl(max(case when name = 'BACKUP OPTIMIZATION' then value end), 'DEFAULT/OFF')
from v$rman_configuration;
select 'CSIM_BKP|rman_encryption|' ||
       nvl(max(case when name = 'ENCRYPTION FOR DATABASE' then value end), 'DEFAULT')
from v$rman_configuration;
select 'CSIM_BKP|rman_compression|' ||
       nvl(max(case when name = 'COMPRESSION ALGORITHM' then value end), 'DEFAULT')
from v$rman_configuration;
select 'CSIM_BKP|rman_channel_config_count|' ||
       count(*)
from v$rman_configuration
where name like 'CHANNEL%';

select 'CSIM_BKP|datafile_count|' || count(*) from v$datafile;
select 'CSIM_BKP|tempfile_count|' || count(*) from v$tempfile;
select 'CSIM_BKP|database_size_gb|' || round(sum(bytes)/1024/1024/1024, 2)
from v$datafile;
select 'CSIM_BKP|datafile_copy_count|' || count(*) from v$datafile_copy;

select 'CSIM_BKP|datafiles_without_backup_metadata|' || count(*)
from (
  select df.file#
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
  having max(bdf.completion_time) is null
);
select 'CSIM_BKP|oldest_datafile_backup_time|' ||
       nvl(to_char(min(last_backup_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from (
  select df.file#, max(bdf.completion_time) last_backup_time
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
);
select 'CSIM_BKP|last_datafile_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_datafile;
select 'CSIM_BKP|last_datafile_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile;
select 'CSIM_BKP|last_level0_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_datafile
where incremental_level = 0
   or incremental_level is null;
select 'CSIM_BKP|last_level0_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile
where incremental_level = 0
   or incremental_level is null;
select 'CSIM_BKP|last_level1_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_datafile
where incremental_level = 1;
select 'CSIM_BKP|last_level1_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile
where incremental_level = 1;

select 'CSIM_BKP|level0_count_30d|' || count(*)
from (
  select distinct set_stamp, set_count
  from v$backup_datafile
  where (incremental_level = 0 or incremental_level is null)
    and completion_time >= sysdate - 30
);
select 'CSIM_BKP|level1_count_30d|' || count(*)
from (
  select distinct set_stamp, set_count
  from v$backup_datafile
  where incremental_level = 1
    and completion_time >= sysdate - 30
);
select 'CSIM_BKP|level0_avg_gap_hours|' ||
       nvl(to_char(round(avg((completion_time - prev_time) * 24), 1)), 'UNKNOWN')
from (
  select completion_time,
         lag(completion_time) over (order by completion_time) prev_time
  from (
    select distinct completion_time
    from v$backup_datafile
    where (incremental_level = 0 or incremental_level is null)
      and completion_time >= sysdate - 90
  )
)
where prev_time is not null;
select 'CSIM_BKP|level1_avg_gap_hours|' ||
       nvl(to_char(round(avg((completion_time - prev_time) * 24), 1)), 'UNKNOWN')
from (
  select completion_time,
         lag(completion_time) over (order by completion_time) prev_time
  from (
    select distinct completion_time
    from v$backup_datafile
    where incremental_level = 1
      and completion_time >= sysdate - 90
  )
)
where prev_time is not null;

select 'CSIM_BKP|successful_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status like 'COMPLETED%';
select 'CSIM_BKP|failed_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status not like 'COMPLETED%';
select 'CSIM_BKP|successful_jobs_30d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status like 'COMPLETED%';
select 'CSIM_BKP|failed_jobs_30d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status not like 'COMPLETED%';
select 'CSIM_BKP|last_successful_job_time|' ||
       nvl(to_char(max(end_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_BKP|last_successful_job_age_hours|' ||
       nvl(to_char(round((sysdate - max(end_time)) * 24, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_BKP|backup_device_types|' ||
       nvl((
         select listagg(output_device_type, ',') within group (order by output_device_type)
         from (
           select distinct nvl(output_device_type, 'UNKNOWN') output_device_type
           from v$rman_backup_job_details
           where start_time >= sysdate - 30
         )
       ), 'NONE')
from dual;
select 'CSIM_BKP|avg_successful_job_elapsed_minutes_30d|' ||
       nvl(to_char(round(avg(elapsed_seconds) / 60, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status like 'COMPLETED%';
select 'CSIM_BKP|max_successful_job_elapsed_minutes_30d|' ||
       nvl(to_char(round(max(elapsed_seconds) / 60, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status like 'COMPLETED%';

select 'CSIM_BKP|archivelog_backup_sets_30d|' || count(*)
from v$backup_set
where backup_type = 'L'
  and completion_time >= sysdate - 30;
select 'CSIM_BKP|last_archivelog_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_set
where backup_type = 'L';
select 'CSIM_BKP|last_archivelog_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_set
where backup_type = 'L';
select 'CSIM_BKP|archivelog_backup_avg_gap_hours|' ||
       nvl(to_char(round(avg((completion_time - prev_time) * 24), 1)), 'UNKNOWN')
from (
  select completion_time,
         lag(completion_time) over (order by completion_time) prev_time
  from (
    select distinct completion_time
    from v$backup_set
    where backup_type = 'L'
      and completion_time >= sysdate - 90
  )
)
where prev_time is not null;
select 'CSIM_BKP|archivelogs_known_7d|' || count(*)
from v$archived_log
where completion_time >= sysdate - 7
  and name is not null
  and nvl(deleted, 'NO') = 'NO';
select 'CSIM_BKP|archivelogs_not_backed_7d|' || count(*)
from v$archived_log
where completion_time >= sysdate - 7
  and name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0;
select 'CSIM_BKP|oldest_unbacked_archivelog_time|' ||
       nvl(to_char(min(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0;
select 'CSIM_BKP|oldest_unbacked_archivelog_age_hours|' ||
       nvl(to_char(round((sysdate - min(completion_time)) * 24, 1)), 'UNKNOWN')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0;
select 'CSIM_BKP|latest_archivelog_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';

select 'CSIM_BKP|controlfile_backup_count_30d|' || count(*)
from v$backup_set
where controlfile_included = 'YES'
  and completion_time >= sysdate - 30;
select 'CSIM_BKP|last_controlfile_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_set
where controlfile_included = 'YES';
select 'CSIM_BKP|last_controlfile_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_set
where controlfile_included = 'YES';

select 'CSIM_BKP|backup_piece_available_count|' || count(*)
from v$backup_piece
where status = 'A';
select 'CSIM_BKP|backup_piece_expired_count|' || count(*)
from v$backup_piece
where status = 'X';
select 'CSIM_BKP|backup_piece_deleted_count|' || count(*)
from v$backup_piece
where status = 'D';
select 'CSIM_BKP|backup_piece_unavailable_count|' || count(*)
from v$backup_piece
where status not in ('A', 'D', 'X');
select 'CSIM_BKP|latest_backup_piece_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_piece;
select 'CSIM_BKP|backup_piece_device_types|' ||
       nvl((
         select listagg(device_type, ',') within group (order by device_type)
         from (
           select distinct nvl(device_type, 'UNKNOWN') device_type
           from v$backup_piece
           where completion_time >= sysdate - 30
         )
       ), 'NONE')
from dual;

select 'CSIM_BKP|recover_file_count|' || count(*) from v$recover_file;
select 'CSIM_BKP|block_corruption_count|' || count(*) from v$database_block_corruption;
select 'CSIM_BKP|copy_corruption_count|' || count(*) from v$copy_corruption;
select 'CSIM_BKP|backup_corruption_count|' || count(*) from v$backup_corruption;

select 'CSIM_BKP|fra_configured|' ||
       case when count(*) > 0 and max(space_limit) > 0 then 'YES' else 'NO' end
from v$recovery_file_dest;
select 'CSIM_BKP|fra_used_pct|' ||
       nvl(to_char(round(max(space_used) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;
select 'CSIM_BKP|fra_reclaimable_pct|' ||
       nvl(to_char(round(max(space_reclaimable) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;

select 'CSIM_BKP|remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status <> 'INACTIVE';
select 'CSIM_BKP|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_BKP|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_BKP|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_BKP|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_BKP|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

exit
