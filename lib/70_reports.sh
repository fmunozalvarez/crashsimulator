append_report_command() {
  local report_file="$1"
  local title="$2"
  shift 2
  local status timeout_seconds
  timeout_seconds="${CRASHSIM_REPORT_COMMAND_TIMEOUT:-30}"
  [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || timeout_seconds=30

  append_report_section "$report_file" "$title"
  {
    printf "Command:"
    printf " %q" "$@"
    printf "\n\n"
    printf '```text\n'
  } >>"$report_file"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@" >>"$report_file" 2>&1
  else
    "$@" >>"$report_file" 2>&1
  fi
  status=$?
  if [[ "$status" -ne 0 ]]; then
    printf "\n[command exited with status %s]\n" "$status" >>"$report_file"
  fi
  printf '```\n' >>"$report_file"
}

append_report_file() {
  local report_file="$1"
  local title="$2"
  local path="$3"

  append_report_section "$report_file" "$title"
  if [[ -f "$path" ]]; then
    {
      printf 'File: `%s`\n\n' "$path"
      printf '```text\n'
      sed 's/\r$//' "$path"
      printf '```\n'
    } >>"$report_file"
  else
    printf 'File not found: `%s`\n' "$path" >>"$report_file"
  fi
}

append_report_environment() {
  local report_file="$1"

  append_report_section "$report_file" "Operating System And Oracle Environment"
  {
    printf "Command: env | sort with secret redaction\n\n"
    printf '```text\n'
    env | sort | awk -F= '
      BEGIN {
        secret_pattern = "(PASS|PASSWORD|TOKEN|SECRET|CREDENTIAL|AUTH|PRIVATE.*KEY|ACCESS.*KEY|KEY_FILE)"
      }
      {
        key = $1
        upper_key = toupper(key)
        if (upper_key ~ secret_pattern) {
          print key "=<redacted>"
        } else {
          print
        }
      }
    '
    printf '```\n'
  } >>"$report_file"
}

append_network_config_files() {
  local report_file="$1"
  local net_dirs=()
  local dir file lsnrctl_bin lsnrctl_home found

  if [[ -n "${TNS_ADMIN:-}" ]]; then
    net_dirs+=("$TNS_ADMIN")
  fi
  if [[ -n "${ORACLE_HOME:-}" ]]; then
    net_dirs+=("${ORACLE_HOME}/network/admin")
  fi
  lsnrctl_bin="$(command -v lsnrctl 2>/dev/null || true)"
  if [[ -n "$lsnrctl_bin" ]]; then
    lsnrctl_home="$(cd "$(dirname "$lsnrctl_bin")/.." >/dev/null 2>&1 && pwd || true)"
    [[ -n "$lsnrctl_home" ]] && net_dirs+=("${lsnrctl_home}/network/admin")
  fi

  local unique_dirs=()
  for dir in "${net_dirs[@]}"; do
    [[ -n "$dir" ]] || continue
    found=0
    local existing
    for existing in "${unique_dirs[@]}"; do
      [[ "$existing" == "$dir" ]] && found=1 && break
    done
    [[ "$found" -eq 1 ]] || unique_dirs+=("$dir")
  done

  for dir in "${unique_dirs[@]}"; do
    for file in listener.ora tnsnames.ora sqlnet.ora; do
      append_report_file "$report_file" "Network config: ${dir}/${file}" "${dir}/${file}"
    done
  done
}

write_backup_report_evidence_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write backup report evidence SQL file: $sql_file"
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
SQL
}

write_backup_report_detail_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write backup report detail SQL file: $sql_file"
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
SQL
}

parse_backup_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  BACKUP_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_BKP" && -n "$key" ]] || continue
    BACKUP_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

backup_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${BACKUP_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

backup_is_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

backup_display_number() {
  local value="$1"
  if [[ "$value" == .* ]]; then
    printf "0%s" "$value"
  else
    printf "%s" "$value"
  fi
}

backup_display_value() {
  local value="$1"
  if backup_is_number "$value"; then
    backup_display_number "$value"
  else
    printf "%s" "$value"
  fi
}

backup_num_gt() {
  backup_is_number "$1" && backup_is_number "$2" &&
    awk -v a="$1" -v b="$2" 'BEGIN { exit (a > b) ? 0 : 1 }'
}

backup_num_le() {
  backup_is_number "$1" && backup_is_number "$2" &&
    awk -v a="$1" -v b="$2" 'BEGIN { exit (a <= b) ? 0 : 1 }'
}

backup_cadence_label() {
  local hours="$1"
  if ! backup_is_number "$hours"; then
    printf "not enough history"
  elif backup_num_le "$hours" "2"; then
    printf "roughly hourly or better"
  elif backup_num_le "$hours" "8"; then
    printf "several times per day"
  elif backup_num_le "$hours" "30"; then
    printf "roughly daily"
  elif backup_num_le "$hours" "190"; then
    printf "roughly weekly"
  else
    printf "less frequent than weekly"
  fi
}

backup_detect_strategy() {
  local level0 level1 arch copies
  level0="$(backup_value level0_count_30d 0)"
  level1="$(backup_value level1_count_30d 0)"
  arch="$(backup_value archivelog_backup_sets_30d 0)"
  copies="$(backup_value datafile_copy_count 0)"

  if [[ "$level0" =~ ^[0-9]+$ && "$level1" =~ ^[0-9]+$ && "$level0" -gt 0 && "$level1" -gt 0 ]]; then
    printf "Level 0 plus Level 1 incremental strategy observed"
  elif [[ "$level0" =~ ^[0-9]+$ && "$level0" -gt 0 ]]; then
    printf "Level 0/full datafile backup strategy observed"
  elif [[ "$copies" =~ ^[0-9]+$ && "$copies" -gt 0 ]]; then
    printf "Datafile image copy metadata observed"
  else
    printf "No complete datafile backup strategy is visible in RMAN metadata"
  fi

  if [[ "$arch" =~ ^[0-9]+$ && "$arch" -gt 0 ]]; then
    printf " with archived redo backups"
  else
    printf " without visible archived redo backup history"
  fi
}

backup_estimated_rpo() {
  local log_mode arch_age unbacked_age arch_sets dg_count
  local arch_age_display unbacked_age_display
  log_mode="$(backup_value log_mode UNKNOWN)"
  arch_age="$(backup_value last_archivelog_backup_age_hours UNKNOWN)"
  unbacked_age="$(backup_value oldest_unbacked_archivelog_age_hours UNKNOWN)"
  arch_sets="$(backup_value archivelog_backup_sets_30d 0)"
  dg_count="$(backup_value valid_remote_standby_dest_count 0)"

  if [[ "$log_mode" != "ARCHIVELOG" ]]; then
    printf "Backup-only RPO is at risk: NOARCHIVELOG mode generally limits recovery to the last whole backup."
  elif [[ "$arch_sets" =~ ^[0-9]+$ && "$arch_sets" -eq 0 ]]; then
    printf "Backup-only RPO is not proven: no archived redo backup sets were observed in the last 30 days. Local archived logs may reduce data loss only if the local FRA/storage survives."
  elif backup_is_number "$arch_age"; then
    arch_age_display="$(backup_display_number "$arch_age")"
    printf "Backup-only RPO is approximately the age of the latest archived redo backup, currently about %s hours; actual data loss can be lower if required archived logs and online redo survive locally." "$arch_age_display"
  else
    printf "Backup-only RPO could not be estimated from visible archived redo backup metadata."
  fi

  if backup_is_number "$unbacked_age"; then
    unbacked_age_display="$(backup_display_number "$unbacked_age")"
    printf " Oldest currently unbacked archived redo is about %s hours old." "$unbacked_age_display"
  fi
  if [[ "$dg_count" =~ ^[0-9]+$ && "$dg_count" -gt 0 ]]; then
    printf " Valid Data Guard destinations are visible and may provide a lower HA/DR RPO than backup-only recovery; validate transport/apply lag separately."
  fi
}

backup_estimated_rto() {
  local missing level0_age level1_age db_gb avg_job max_job copies
  missing="$(backup_value datafiles_without_backup_metadata 0)"
  level0_age="$(backup_value last_level0_backup_age_hours UNKNOWN)"
  level1_age="$(backup_value last_level1_backup_age_hours UNKNOWN)"
  db_gb="$(backup_value database_size_gb UNKNOWN)"
  avg_job="$(backup_value avg_successful_job_elapsed_minutes_30d UNKNOWN)"
  max_job="$(backup_value max_successful_job_elapsed_minutes_30d UNKNOWN)"
  copies="$(backup_value datafile_copy_count 0)"

  if [[ "$missing" =~ ^[0-9]+$ && "$missing" -gt 0 ]]; then
    printf "RTO is not safely estimable because %s datafile(s) have no visible backup metadata." "$missing"
    return
  fi

  if [[ "$level0_age" == "UNKNOWN" ]]; then
    printf "RTO is not safely estimable because no Level 0/full datafile backup is visible."
    return
  fi

  if [[ "$copies" =~ ^[0-9]+$ && "$copies" -gt 0 ]]; then
    printf "Potential RTO may be lower if image copies are current and switch-to-copy/roll-forward is practiced."
  else
    printf "Potential RTO is likely hours for full database restore/recovery unless timed drills prove otherwise."
  fi
  printf " Visible database size is %s GB." "$db_gb"
  printf " Latest Level 0/full backup age is %s hours." "$(backup_display_number "$level0_age")"
  if backup_is_number "$level1_age"; then
    printf " Latest Level 1 incremental backup age is %s hours, so recovery must restore/roll forward backups and apply redo after that point." "$(backup_display_number "$level1_age")"
  fi
  if backup_is_number "$avg_job" || backup_is_number "$max_job"; then
    printf " Recent successful backup job duration averages %s minutes and maxes at %s minutes; restore time can differ and must be measured." "$(backup_display_number "$avg_job")" "$(backup_display_number "$max_job")"
  fi
}

backup_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

write_backup_report_rman_repository_file() {
  local cmd_file="$1"

  {
    [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "connect catalog %s\n" "$RMAN_CATALOG_CONNECT"
    printf "show all;\n"
    printf "list backup summary;\n"
    printf "list backup of database summary;\n"
    printf "list backup of archivelog all summary;\n"
    printf "list expired backup summary;\n"
    printf "list expired archivelog all;\n"
    printf "report schema;\n"
    printf "report need backup;\n"
    printf "report obsolete;\n"
    printf "restore database preview summary;\n"
    printf "exit;\n"
  } >"$cmd_file" || die "Unable to write RMAN repository report file: $cmd_file"
  chmod 600 "$cmd_file" 2>/dev/null || true
}

write_backup_report_rman_validate_file() {
  local cmd_file="$1"

  {
    [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "connect catalog %s\n" "$RMAN_CATALOG_CONNECT"
    printf "restore database validate;\n"
    printf "restore archivelog all validate;\n"
    printf "validate database check logical;\n"
    printf "exit;\n"
  } >"$cmd_file" || die "Unable to write RMAN validation report file: $cmd_file"
  chmod 600 "$cmd_file" 2>/dev/null || true
}

append_report_rman_cmdfile() {
  local report_file="$1"
  local title="$2"
  local cmd_file="$3"
  local log_file="$4"
  local status

  append_report_section "$report_file" "$title"
  {
    printf 'Repository source requested: `%s`\n\n' "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "recovery catalog plus target control file" || printf "target control file")"
    printf 'Command: `%s target / cmdfile=%s log=%s`\n\n' "$(basename "$RMAN_BIN")" "$cmd_file" "$log_file"
    printf '```text\n'
  } >>"$report_file"

  "$RMAN_BIN" target / cmdfile="$cmd_file" log="$log_file" >/dev/null 2>&1
  status=$?
  if [[ -f "$log_file" ]]; then
    print_redacted_rman_log "$log_file" >>"$report_file"
  else
    printf "RMAN log file was not created: %s\n" "$log_file" >>"$report_file"
  fi
  if [[ "$status" -ne 0 ]]; then
    printf "\n[command exited with status %s]\n" "$status" >>"$report_file"
  fi
  printf '```\n' >>"$report_file"
  return "$status"
}

run_backup_report() {
  discover_environment
  ensure_sqlplus
  ensure_rman

  local report_file evidence_sql evidence_file detail_sql generated_at rman_cmd_dir
  local rman_repo_file rman_repo_log rman_validate_file rman_validate_log
  local repo_status=0 validate_status=0
  local strategy rpo_hint rto_hint level0_gap level1_gap arch_gap
  local missing failed7 failed30 expired unavailable deleted recover_files corruptions fra_used
  local controlfile_auto retention catalog_redacted

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_backup_report_${RUN_ID}.md"
  evidence_sql="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_evidence.sql"
  evidence_file="${LOG_DIR}/crashsim_backup_report_${RUN_ID}.evidence"
  detail_sql="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_detail.sql"
  rman_cmd_dir="$LOG_DIR"
  [[ -n "$RMAN_CATALOG_CONNECT" ]] && rman_cmd_dir="$WORK_DIR"
  rman_repo_file="${rman_cmd_dir}/crashsim_backup_report_${RUN_ID}_repository.rman"
  rman_repo_log="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_repository.log"
  rman_validate_file="${rman_cmd_dir}/crashsim_backup_report_${RUN_ID}_validate.rman"
  rman_validate_log="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_validate.log"

  write_backup_report_evidence_sql_file "$evidence_sql"
  write_backup_report_detail_sql_file "$detail_sql"

  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$evidence_sql" >"$evidence_file" </dev/null ||
    die "Backup evidence SQL failed: $evidence_sql (evidence: $evidence_file)"
  parse_backup_evidence_file "$evidence_file"

  strategy="$(backup_detect_strategy)"
  rpo_hint="$(backup_estimated_rpo)"
  rto_hint="$(backup_estimated_rto)"
  level0_gap="$(backup_cadence_label "$(backup_value level0_avg_gap_hours UNKNOWN)")"
  level1_gap="$(backup_cadence_label "$(backup_value level1_avg_gap_hours UNKNOWN)")"
  arch_gap="$(backup_cadence_label "$(backup_value archivelog_backup_avg_gap_hours UNKNOWN)")"
  catalog_redacted="$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"

  {
    printf "# CrashSimulator Backup Strategy And Recoverability Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(backup_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(backup_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- DBID: `%s`\n' "$(backup_value dbid UNKNOWN)"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(backup_value database_role "$DB_ROLE")" "$(backup_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(backup_value cdb "$DB_CDB")"
    printf -- '- Storage: `%s`\n' "$STORAGE_TYPE"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Deep RMAN validation: `%s`\n' "$([[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && printf enabled || printf disabled)"
    printf -- '- RMAN repository source requested: `%s`\n' "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "recovery catalog plus target control file" || printf "target control file")"
    [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf -- '- RMAN catalog connect: `%s`\n' "$catalog_redacted"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This report estimates recoverability from current database/RMAN metadata and optional RMAN validation output. RTO/RPO values are planning estimates, not guarantees; prove them with timed restore, recovery, and application validation drills.\n"
  } >"$report_file" || die "Unable to write backup report file: $report_file"

  append_report_section "$report_file" "Executive Summary"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    printf '| Strategy detected | %s |\n' "$(md_escape "$strategy")"
    printf '| Level 0/full cadence | %s; last backup `%s`, age `%s` hours |\n' \
      "$(md_escape "$level0_gap")" "$(md_escape "$(backup_value last_level0_backup_time NONE)")" "$(md_escape "$(backup_display_value "$(backup_value last_level0_backup_age_hours UNKNOWN)")")"
    printf '| Level 1 incremental cadence | %s; last backup `%s`, age `%s` hours |\n' \
      "$(md_escape "$level1_gap")" "$(md_escape "$(backup_value last_level1_backup_time NONE)")" "$(md_escape "$(backup_display_value "$(backup_value last_level1_backup_age_hours UNKNOWN)")")"
    printf '| Archived redo backup cadence | %s; last backup `%s`, age `%s` hours |\n' \
      "$(md_escape "$arch_gap")" "$(md_escape "$(backup_value last_archivelog_backup_time NONE)")" "$(md_escape "$(backup_display_value "$(backup_value last_archivelog_backup_age_hours UNKNOWN)")")"
    printf '| Visible database size | `%s` GB across `%s` datafiles |\n' "$(md_escape "$(backup_value database_size_gb UNKNOWN)")" "$(md_escape "$(backup_value datafile_count UNKNOWN)")"
    printf '| Backup device types | `%s` |\n' "$(md_escape "$(backup_value backup_device_types NONE)")"
    printf '| Backup piece device types | `%s` |\n' "$(md_escape "$(backup_value backup_piece_device_types NONE)")"
    printf '| Backup-only RPO estimate | %s |\n' "$(md_escape "$rpo_hint")"
    printf '| Backup/recovery RTO estimate | %s |\n' "$(md_escape "$rto_hint")"
  } >>"$report_file"

  append_report_section "$report_file" "Backup Health Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  missing="$(backup_value datafiles_without_backup_metadata 0)"
  if [[ "$missing" =~ ^[0-9]+$ && "$missing" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Coverage" "Every datafile has backup metadata" "missing_datafiles=${missing}" "Keep validating restore paths and catalog/control-file metadata retention."
  else
    backup_append_check "$report_file" "GAP" "Coverage" "Datafile backup coverage" "missing_datafiles=${missing}" "Run a database backup or investigate files not represented in RMAN metadata before destructive drills."
  fi

  if backup_is_number "$(backup_value last_level0_backup_age_hours UNKNOWN)" && backup_num_le "$(backup_value last_level0_backup_age_hours UNKNOWN)" "168"; then
    backup_append_check "$report_file" "OK" "Baseline" "Recent Level 0/full backup" "age_hours=$(backup_display_value "$(backup_value last_level0_backup_age_hours)")" "Keep Level 0/full backups aligned with restore-time objectives."
  else
    backup_append_check "$report_file" "WARN" "Baseline" "Recent Level 0/full backup" "age_hours=$(backup_display_value "$(backup_value last_level0_backup_age_hours UNKNOWN)")" "Review Level 0/full backup cadence; weekly or better is common for many RMAN strategies, but tune to SLA and restore throughput."
  fi

  if [[ "$(backup_value log_mode UNKNOWN)" == "ARCHIVELOG" ]]; then
    backup_append_check "$report_file" "OK" "Recoverability" "ARCHIVELOG mode" "log_mode=ARCHIVELOG" "Continue backing archived redo frequently enough to meet RPO."
  else
    backup_append_check "$report_file" "GAP" "Recoverability" "ARCHIVELOG mode" "log_mode=$(backup_value log_mode UNKNOWN)" "Enable ARCHIVELOG if point-in-time/media recovery is required."
  fi

  if backup_is_number "$(backup_value last_archivelog_backup_age_hours UNKNOWN)" && backup_num_le "$(backup_value last_archivelog_backup_age_hours UNKNOWN)" "24"; then
    backup_append_check "$report_file" "OK" "RPO" "Recent archived redo backup" "age_hours=$(backup_display_value "$(backup_value last_archivelog_backup_age_hours)")" "Back up archived redo more frequently than the required backup-only RPO."
  else
    backup_append_check "$report_file" "WARN" "RPO" "Recent archived redo backup" "age_hours=$(backup_display_value "$(backup_value last_archivelog_backup_age_hours UNKNOWN)")" "Increase archived-log backup frequency if backup-only RPO must be less than a day."
  fi

  failed7="$(backup_value failed_jobs_7d 0)"
  failed30="$(backup_value failed_jobs_30d 0)"
  if [[ "$failed7" =~ ^[0-9]+$ && "$failed7" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Reliability" "No failed RMAN jobs in last 7 days" "failed_7d=${failed7}, failed_30d=${failed30}" "Keep alerting on failed backup jobs."
  else
    backup_append_check "$report_file" "WARN" "Reliability" "Failed RMAN jobs" "failed_7d=${failed7}, failed_30d=${failed30}" "Investigate failed backup jobs and confirm they did not break required backup windows."
  fi

  expired="$(backup_value backup_piece_expired_count 0)"
  unavailable="$(backup_value backup_piece_unavailable_count 0)"
  deleted="$(backup_value backup_piece_deleted_count 0)"
  if [[ "$expired" =~ ^[0-9]+$ && "$unavailable" =~ ^[0-9]+$ && "$expired" -eq 0 && "$unavailable" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Repository" "Backup piece status" "available=$(backup_value backup_piece_available_count 0), expired=${expired}, unavailable=${unavailable}, deleted=${deleted}" "Schedule periodic CROSSCHECK and cleanup obsolete/expired records."
  else
    backup_append_check "$report_file" "WARN" "Repository" "Backup piece status" "available=$(backup_value backup_piece_available_count 0), expired=${expired}, unavailable=${unavailable}, deleted=${deleted}" "Run RMAN CROSSCHECK and resolve expired/unavailable pieces before relying on them."
  fi

  controlfile_auto="$(backup_value rman_controlfile_autobackup DEFAULT/OFF)"
  if [[ "$controlfile_auto" == *"ON"* ]]; then
    backup_append_check "$report_file" "OK" "Control file" "Control file autobackup" "$controlfile_auto" "Keep autobackup enabled and test restore controlfile from autobackup."
  else
    backup_append_check "$report_file" "WARN" "Control file" "Control file autobackup" "$controlfile_auto" "Enable CONFIGURE CONTROLFILE AUTOBACKUP ON unless an equivalent control-file/SPFILE backup process exists."
  fi

  recover_files="$(backup_value recover_file_count 0)"
  corruptions="$(( $(backup_value block_corruption_count 0) + $(backup_value copy_corruption_count 0) + $(backup_value backup_corruption_count 0) ))"
  if [[ "$recover_files" =~ ^[0-9]+$ && "$recover_files" -eq 0 && "$corruptions" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Validation" "Recovery/corruption views" "recover_files=${recover_files}, corruption_rows=${corruptions}" "Continue scheduled validation and corruption monitoring."
  else
    backup_append_check "$report_file" "GAP" "Validation" "Recovery/corruption views" "recover_files=${recover_files}, corruption_rows=${corruptions}" "Resolve files needing media recovery or corruption rows before further destructive testing."
  fi

  fra_used="$(backup_value fra_used_pct UNKNOWN)"
  if backup_is_number "$fra_used" && backup_num_gt "$fra_used" "85"; then
    backup_append_check "$report_file" "WARN" "FRA" "FRA utilization" "fra_used_pct=${fra_used}" "Increase FRA size or adjust retention/backup deletion to avoid archived-log pressure."
  else
    backup_append_check "$report_file" "OK" "FRA" "FRA utilization" "fra_used_pct=${fra_used}" "Keep FRA capacity monitored against archive generation and retention."
  fi

  retention="$(backup_value rman_retention_policy DEFAULT)"
  append_report_section "$report_file" "Strategy Interpretation And Recommendations"
  {
    printf -- '- Observed strategy: %s.\n' "$strategy"
    printf -- '- RMAN retention policy: `%s`.\n' "$retention"
    printf -- '- Control file record keep time: `%s` days. If no catalog is used, keep this long enough to preserve restore history for your retention window.\n' "$(backup_value control_file_record_keep_time UNKNOWN)"
    printf -- '- Backup repository source: `%s`.\n' "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "Recovery catalog requested; RMAN output below confirms whether it connected successfully." || printf "Target control file only for this report run.")"
    printf -- '- RTO guidance: %s\n' "$rto_hint"
    printf -- '- RPO guidance: %s\n' "$rpo_hint"
    printf -- '- Best-practice direction: run periodic RMAN restore validation, validate selected backups when pieces are suspected missing, keep repository metadata accurate with crosschecks, protect control file/SPFILE backups, and run timed CrashSimulator restore drills to prove actual RTO/RPO.\n'
  } >>"$report_file"

  append_report_section "$report_file" "SQL Backup Repository Details"
  append_report_command "$report_file" "Control-File SQL Backup Evidence" "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$detail_sql"

  write_backup_report_rman_repository_file "$rman_repo_file"
  append_report_rman_cmdfile "$report_file" "RMAN Repository, Restore Preview, Need-Backup, And Obsolete Report" "$rman_repo_file" "$rman_repo_log" || repo_status=$?

  if [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]]; then
    write_backup_report_rman_validate_file "$rman_validate_file"
    append_report_rman_cmdfile "$report_file" "RMAN Deep Validation - Restore Database, Archivelogs, And Logical Database Check" "$rman_validate_file" "$rman_validate_log" || validate_status=$?
  else
    append_report_section "$report_file" "RMAN Deep Validation"
    append_report_text "$report_file" 'Skipped by default. Re-run with `--deep-validate` or set `CRASHSIM_REPORT_DEEP_VALIDATE=1` to run `RESTORE DATABASE VALIDATE`, `RESTORE ARCHIVELOG ALL VALIDATE`, and `VALIDATE DATABASE CHECK LOGICAL`. Those checks are read-only but can be I/O intensive, especially for SBT/Object Storage.'
  fi

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle Database 19c backup and recovery administration: https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/performing-backup-and-recovery.html\n'
    printf -- '- Oracle Maximum Availability Architecture overview: https://www.oracle.com/database/technologies/maximum-availability-architecture/\n'
    printf -- '- CrashSimulator RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw Backup Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_BKP|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  echo "Backup strategy and recoverability report generated: ${report_file}"
  echo "Strategy detected: ${strategy}"
  echo "RPO estimate: ${rpo_hint}"
  echo "RTO estimate: ${rto_hint}"
  maybe_render_html "$report_file"
  if [[ "$repo_status" -ne 0 || "$validate_status" -ne 0 ]]; then
    warn "One or more RMAN report/validation sections exited with a non-zero status. Review: ${report_file}"
  fi
}

write_config_report_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write configuration report SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 500 lines 260 trimspool on tab off verify off feedback on
set numwidth 20
column name format a34
column value format a120
column display_value format a120
column file_name format a150
column member format a150
column destination format a120
column error format a120
column handle format a120
column path format a150
column pdb_name format a30
column tablespace_name format a30
column parameter_name format a42
column start_time format a20
column end_time format a20
column completion_time format a20

prompt # SQL Evidence
prompt
prompt ## Database Identity
select name, db_unique_name, dbid, platform_name, database_role, open_mode,
       cdb, log_mode, force_logging, flashback_on, protection_mode,
       switchover_status
from v$database;

prompt ## Instance Identity
select instance_name, host_name, version, status, database_status, active_state,
       parallel, thread#, archiver, to_char(startup_time, 'YYYY-MM-DD HH24:MI:SS') startup_time
from v$instance;

prompt ## Database Version
select banner_full from v$version where banner_full like 'Oracle Database%';

prompt ## Key Paths And Parameters
select name, display_value
from v$parameter
where name in (
  'spfile',
  'control_files',
  'db_name',
  'db_unique_name',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'db_create_file_dest',
  'db_create_online_log_dest_1',
  'db_create_online_log_dest_2',
  'diagnostic_dest',
  'audit_file_dest',
  'adg_redirect_dml',
  'compatible',
  'cluster_database',
  'remote_login_passwordfile',
  'enable_pluggable_database',
  'local_undo_enabled',
  'wallet_root',
  'tde_configuration'
)
order by name;

prompt ## Non-Default Database Parameters
select name parameter_name, type, isdefault, ismodified, issys_modifiable, ispdb_modifiable, display_value
from v$parameter
where isdefault = 'FALSE'
order by name;

prompt ## Diagnostic And Trace Locations
select name, value from v$diag_info order by name;

prompt ## Control Files
select name from v$controlfile order by name;

prompt ## Redo Log Groups
select l.group#, l.thread#, l.sequence#, round(l.bytes/1024/1024,2) size_mb,
       l.blocksize, l.members, l.archived, l.status
from v$log l
order by l.thread#, l.group#;

prompt ## Redo Log Members
select lf.group#, l.thread#, l.status, lf.type, lf.is_recovery_dest_file, lf.member
from v$logfile lf
join v$log l on l.group# = lf.group#
order by lf.group#, lf.member;

prompt ## Database Size Summary
select 'DATAFILES' component, count(*) file_count, round(sum(bytes)/1024/1024/1024,2) size_gb
from v$datafile
union all
select 'TEMPFILES' component, count(*) file_count, round(nvl(sum(bytes),0)/1024/1024/1024,2) size_gb
from v$tempfile
union all
select 'ONLINE REDO' component, count(*) file_count, round(nvl(sum(bytes),0)/1024/1024/1024,2) size_gb
from v$log;

prompt ## SYSTEM And UNDO Datafiles
select df.file#, ts.name tablespace_name,
       case when ts.name = 'SYSTEM' then 'SYSTEM'
            when ts.name like 'UNDO%' then 'UNDO'
            else 'OTHER'
       end tablespace_class,
       round(df.bytes/1024/1024,2) size_mb,
       df.status, df.enabled, df.name file_name
from v$datafile df
join v$tablespace ts on ts.ts# = df.ts# and ts.con_id = df.con_id
where ts.name = 'SYSTEM'
   or ts.name like 'UNDO%'
order by df.con_id, df.file#;

prompt ## Temporary Files
select tf.file#, ts.name tablespace_name, round(tf.bytes/1024/1024,2) size_mb,
       tf.status, tf.enabled, tf.name file_name
from v$tempfile tf
join v$tablespace ts on ts.ts# = tf.ts# and ts.con_id = tf.con_id
order by tf.con_id, tf.file#;

prompt ## FRA Destination And Usage
select name, round(space_limit/1024/1024/1024,2) space_limit_gb,
       round(space_used/1024/1024/1024,2) space_used_gb,
       round(space_reclaimable/1024/1024/1024,2) space_reclaimable_gb,
       number_of_files
from v$recovery_file_dest;

prompt ## FRA Usage By File Type
select file_type, percent_space_used, percent_space_reclaimable, number_of_files
from v$flash_recovery_area_usage
order by file_type;

prompt ## RMAN Configuration
select name, value from v$rman_configuration order by name;

prompt ## Recent RMAN Backup Jobs
select *
from (
  select session_key, input_type, status,
         to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') start_time,
         to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') end_time,
         elapsed_seconds, output_device_type, input_bytes_display, output_bytes_display
  from v$rman_backup_job_details
  order by start_time desc
)
where rownum <= 40;

prompt ## Backup Set Summary
select *
from (
  select recid backup_set_recid, set_stamp, set_count, backup_type,
         incremental_level, controlfile_included, pieces piece_count,
         to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') start_time,
         to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time
  from v$backup_set
  order by completion_time desc
)
where rownum <= 60;

prompt ## Observed Backup Methodology From RMAN History
select nvl(input_type, 'UNKNOWN') input_type, status, count(*) job_count,
       to_char(min(start_time), 'YYYY-MM-DD HH24:MI:SS') first_observed,
       to_char(max(start_time), 'YYYY-MM-DD HH24:MI:SS') last_observed
from v$rman_backup_job_details
where start_time >= sysdate - 60
group by input_type, status
order by input_type, status;

prompt ## Datafile Backup Coverage
select df.file#, df.name file_name,
       to_char(max(bdf.completion_time), 'YYYY-MM-DD HH24:MI:SS') last_backup_time,
       case when max(bdf.completion_time) is null then 'NO BACKUP IN CONTROL FILE METADATA'
            else 'BACKUP METADATA FOUND'
       end backup_status
from v$datafile df
left join v$backup_datafile bdf on bdf.file# = df.file#
group by df.file#, df.name
order by df.file#;

prompt ## Backup Piece Status
select status, device_type, count(*) piece_count,
       to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS') latest_completion
from v$backup_piece
group by status, device_type
order by status, device_type;

prompt ## Recoverability Indicators
select file#, checkpoint_change#, to_char(checkpoint_time, 'YYYY-MM-DD HH24:MI:SS') checkpoint_time,
       unrecoverable_change#, to_char(unrecoverable_time, 'YYYY-MM-DD HH24:MI:SS') unrecoverable_time,
       name
from v$datafile
order by file#;

prompt ## Files Requiring Media Recovery
select * from v$recover_file order by file#;

prompt ## Database Block Corruption
select * from v$database_block_corruption order by file#, block#;

prompt ## Copy Corruption
select * from v$copy_corruption order by file#, block#;

prompt ## Backup Corruption
select * from v$backup_corruption order by file#, block#;

prompt ## Restore Points
select name, scn, time, database_incarnation#, guarantee_flashback_database, storage_size
from v$restore_point
order by time desc;

prompt ## Data Guard Role And FSFO Columns
select database_role, protection_mode, protection_level, switchover_status,
       fs_failover_status, fs_failover_current_target,
       fs_failover_threshold, fs_failover_observer_present
from v$database;

prompt ## Data Guard Destinations
select dest_id, status, target, destination, db_unique_name, valid_now, error
from v$archive_dest
where destination is not null
order by dest_id;

prompt ## Archive Gaps
select * from v$archive_gap;

prompt ## Data Guard Stats
select name, value, unit, time_computed, datum_time
from v$dataguard_stats
order by name;

prompt ## TDE Wallet Status
select * from v$encryption_wallet;

prompt ## Encrypted Tablespaces
select tablespace_name, encrypted
from dba_tablespaces
where encrypted = 'YES'
order by tablespace_name;

prompt ## Encrypted Columns
select owner, table_name, count(*) encrypted_column_count
from dba_encrypted_columns
group by owner, table_name
order by owner, table_name;
SQL

  if [[ "$DB_CDB" == "YES" ]]; then
    cat >>"$sql_file" <<'SQL' || die "Unable to write CDB report SQL file: $sql_file"

prompt ## PDB State And Size
select p.name pdb_name, p.con_id, p.open_mode, p.restricted,
       round(p.total_size/1024/1024/1024,2) total_size_gb,
       to_char(p.open_time, 'YYYY-MM-DD HH24:MI:SS') open_time
from v$pdbs p
order by p.con_id;

prompt ## Datafile Count And Size By Container
select c.name pdb_name, c.con_id, count(df.file#) datafile_count,
       round(nvl(sum(df.bytes),0)/1024/1024/1024,2) datafile_gb,
       round(nvl(tf.temp_bytes,0)/1024/1024/1024,2) tempfile_gb
from v$containers c
left join v$datafile df on df.con_id = c.con_id
left join (
  select con_id, sum(bytes) temp_bytes
  from v$tempfile
  group by con_id
) tf on tf.con_id = c.con_id
group by c.name, c.con_id, tf.temp_bytes
order by c.con_id;

prompt ## Tablespaces By Container
select p.name pdb_name, t.tablespace_name, t.contents, t.status, t.bigfile,
       t.logging, t.extent_management, t.allocation_type, t.segment_space_management,
       round(nvl(df.bytes,0)/1024/1024,2) data_mb,
       round(nvl(tf.bytes,0)/1024/1024,2) temp_mb
from cdb_tablespaces t
join v$containers p on p.con_id = t.con_id
left join (
  select con_id, tablespace_name, sum(bytes) bytes
  from cdb_data_files
  group by con_id, tablespace_name
) df on df.con_id = t.con_id and df.tablespace_name = t.tablespace_name
left join (
  select con_id, tablespace_name, sum(bytes) bytes
  from cdb_temp_files
  group by con_id, tablespace_name
) tf on tf.con_id = t.con_id and tf.tablespace_name = t.tablespace_name
order by p.con_id, t.tablespace_name;

prompt ## Datafiles By Container
select p.name pdb_name, df.file_id, df.tablespace_name,
       round(df.bytes/1024/1024,2) size_mb, df.status, df.online_status,
       df.autoextensible, df.file_name
from cdb_data_files df
join v$containers p on p.con_id = df.con_id
order by p.con_id, df.file_id;

prompt ## Tempfiles By Container
select p.name pdb_name, tf.file_id, tf.tablespace_name,
       round(tf.bytes/1024/1024,2) size_mb, tf.status, tf.autoextensible, tf.file_name
from cdb_temp_files tf
join v$containers p on p.con_id = tf.con_id
order by p.con_id, tf.file_id;

prompt ## Encrypted Tablespaces By Container
select p.name pdb_name, t.tablespace_name, t.encrypted
from cdb_tablespaces t
join v$containers p on p.con_id = t.con_id
where t.encrypted = 'YES'
order by p.con_id, t.tablespace_name;
SQL
  else
    cat >>"$sql_file" <<'SQL' || die "Unable to write non-CDB report SQL file: $sql_file"

prompt ## Tablespaces
select t.tablespace_name, t.contents, t.status, t.bigfile, t.logging,
       t.extent_management, t.allocation_type, t.segment_space_management,
       round(nvl(df.bytes,0)/1024/1024,2) data_mb,
       round(nvl(tf.bytes,0)/1024/1024,2) temp_mb
from dba_tablespaces t
left join (
  select tablespace_name, sum(bytes) bytes
  from dba_data_files
  group by tablespace_name
) df on df.tablespace_name = t.tablespace_name
left join (
  select tablespace_name, sum(bytes) bytes
  from dba_temp_files
  group by tablespace_name
) tf on tf.tablespace_name = t.tablespace_name
order by t.tablespace_name;

prompt ## Datafiles
select file_id, tablespace_name, round(bytes/1024/1024,2) size_mb,
       status, online_status, autoextensible, file_name
from dba_data_files
order by file_id;

prompt ## Tempfiles
select file_id, tablespace_name, round(bytes/1024/1024,2) size_mb,
       status, autoextensible, file_name
from dba_temp_files
order by file_id;
SQL
  fi

  cat >>"$sql_file" <<'SQL' || die "Unable to finish report SQL file: $sql_file"

exit
SQL
}

run_configuration_report() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file generated_at grid_home crsctl_bin asm_sid dgmgrl_bin
  local rman_show_file rman_preview_file rman_restore_validate_file rman_db_validate_file
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}.sql"
  rman_show_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_show_all.rman"
  rman_preview_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_restore_preview.rman"
  rman_restore_validate_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_restore_validate.rman"
  rman_db_validate_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_database_validate.rman"
  write_config_report_sql_file "$sql_file"

  {
    printf "# CrashSimulator Target Database Configuration Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "${DB_NAME:-unknown}"
    printf -- '- DB unique name: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Instance/SID: `%s`\n' "${INSTANCE_NAME:-${ORACLE_SID:-unknown}}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- CDB: `%s`\n' "${DB_CDB:-unknown}"
    printf -- '- Storage: `%s`\n' "${STORAGE_TYPE:-unknown}"
    printf -- '- Cluster type: `%s`\n' "${CLUSTER_TYPE:-unknown}"
    printf -- '- Oracle home: `%s`\n' "${ORACLE_HOME:-unknown}"
    printf -- '- Deep RMAN validation: `%s`\n' "$([[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && printf enabled || printf disabled)"
    printf -- '- SQL evidence file: `%s`\n' "$sql_file"
    printf "\n"
    printf "Backup and recoverability notes: this report includes RMAN metadata, backup coverage by datafile, corruption views, and an RMAN restore preview. External schedulers or OCI backup policies may need separate inspection when they are not visible in target database RMAN history.\n"
  } >"$report_file" || die "Unable to write report file: $report_file"

  append_report_command "$report_file" "SQL Database, PDB, Storage, Backup, TDE, Data Guard, And Corruption Evidence" \
    "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file"

  append_report_section "$report_file" "RMAN Catalog And Restore Preview"
  {
    printf 'The report invokes RMAN with `target /` only. If the output says it is using the target control file, no recovery catalog was used by this report session. This does not prove that an external scheduler never uses a catalog; it reports what is detectable from the target host/session.\n\n'
  } >>"$report_file"
  ensure_rman
  {
    printf "show all;\n"
    printf "exit\n"
  } >"$rman_show_file" || die "Unable to write RMAN report file: $rman_show_file"
  {
    printf "restore database preview summary;\n"
    printf "exit\n"
  } >"$rman_preview_file" || die "Unable to write RMAN report file: $rman_preview_file"
  append_report_command "$report_file" "RMAN SHOW ALL" "$RMAN_BIN" target / cmdfile="$rman_show_file"
  append_report_command "$report_file" "RMAN RESTORE DATABASE PREVIEW SUMMARY" "$RMAN_BIN" target / cmdfile="$rman_preview_file"
  if [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]]; then
    {
      printf "restore database validate;\n"
      printf "exit\n"
    } >"$rman_restore_validate_file" || die "Unable to write RMAN report file: $rman_restore_validate_file"
    {
      printf "validate database check logical;\n"
      printf "exit\n"
    } >"$rman_db_validate_file" || die "Unable to write RMAN report file: $rman_db_validate_file"
    append_report_command "$report_file" "RMAN RESTORE DATABASE VALIDATE" "$RMAN_BIN" target / cmdfile="$rman_restore_validate_file"
    append_report_command "$report_file" "RMAN VALIDATE DATABASE CHECK LOGICAL" "$RMAN_BIN" target / cmdfile="$rman_db_validate_file"
  else
    append_report_section "$report_file" "Deep RMAN Validation"
    append_report_text "$report_file" 'Skipped by default. Re-run with `--deep-validate` or set `CRASHSIM_REPORT_DEEP_VALIDATE=1` to run RMAN restore/database validation. Those checks are read-only but can be I/O intensive.'
  fi

  append_report_environment "$report_file"
  append_report_command "$report_file" "Host Kernel And Identity" uname -a
  append_report_command "$report_file" "ORACLE_HOME Directory" bash -lc "ls -ld '${ORACLE_HOME:-}' 2>&1; du -sh '${ORACLE_HOME:-}' 2>&1"
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/OPatch/opatch" ]]; then
    append_report_command "$report_file" "OPatch LSPatches" "${ORACLE_HOME}/OPatch/opatch" lspatches
  fi

  if command -v lsnrctl >/dev/null 2>&1; then
    append_report_command "$report_file" "Listener Status" lsnrctl status
    append_report_command "$report_file" "Listener Services" lsnrctl services
  else
    append_report_section "$report_file" "Listener Status"
    append_report_text "$report_file" "lsnrctl was not found in PATH."
  fi
  append_network_config_files "$report_file"

  if command -v srvctl >/dev/null 2>&1; then
    if [[ -n "$DB_UNIQUE_NAME" ]]; then
      append_report_command "$report_file" "srvctl config database" srvctl config database -d "$DB_UNIQUE_NAME"
      append_report_command "$report_file" "srvctl status database" srvctl status database -d "$DB_UNIQUE_NAME"
      append_report_command "$report_file" "srvctl config services" srvctl config service -d "$DB_UNIQUE_NAME"
      append_report_command "$report_file" "srvctl status services" srvctl status service -d "$DB_UNIQUE_NAME"
    fi
    append_report_command "$report_file" "srvctl config asm" srvctl config asm
    append_report_command "$report_file" "srvctl status asm" srvctl status asm
  fi

  if command -v crsctl >/dev/null 2>&1; then
    append_report_command "$report_file" "Grid Infrastructure CRS Check" crsctl check crs
    append_report_command "$report_file" "Grid Infrastructure Resource Status" crsctl stat res -t
    append_report_command "$report_file" "Voting Disk Status" crsctl query css votedisk
  fi
  if command -v ocrcheck >/dev/null 2>&1; then
    append_report_command "$report_file" "OCR Check" ocrcheck
  fi
  if command -v ocrconfig >/dev/null 2>&1; then
    append_report_command "$report_file" "OCR Backups" ocrconfig -showbackup
  fi

  crsctl_bin="$(command -v crsctl 2>/dev/null || true)"
  if [[ -n "$crsctl_bin" ]]; then
    grid_home="$(cd "$(dirname "$crsctl_bin")/.." >/dev/null 2>&1 && pwd || true)"
    if [[ -n "$grid_home" && -x "${grid_home}/bin/asmcmd" ]]; then
      asm_sid="${CRASHSIM_ASM_SID:-}"
      [[ -n "$asm_sid" ]] || asm_sid="$(detect_asm_sid_from_process || true)"
      [[ -n "$asm_sid" ]] || asm_sid="+ASM"
      append_report_command "$report_file" "ASM Disk Groups" env ORACLE_HOME="$grid_home" ORACLE_SID="$asm_sid" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/asmcmd" lsdg
      append_report_command "$report_file" "ASM SPFILE" env ORACLE_HOME="$grid_home" ORACLE_SID="$asm_sid" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/asmcmd" spget
    fi
  elif command -v asmcmd >/dev/null 2>&1; then
    append_report_command "$report_file" "ASM Disk Groups" run_asmcmd_with_grid_env lsdg
    append_report_command "$report_file" "ASM SPFILE" run_asmcmd_with_grid_env spget
  fi

  dgmgrl_bin="$(find_dgmgrl_bin)"
  if [[ -n "$dgmgrl_bin" && -x "$dgmgrl_bin" ]]; then
    append_report_command "$report_file" "Data Guard Broker Configuration" bash -lc "printf 'show configuration verbose;\nshow fast_start failover;\nexit\n' | \"${dgmgrl_bin}\" -silent /"
  else
    append_report_section "$report_file" "Data Guard Broker Configuration"
    append_report_text "$report_file" "dgmgrl was not found in ORACLE_HOME/bin or PATH. SQL Data Guard/FSFO evidence is still included above."
  fi

  echo "Configuration report generated: ${report_file}"
  maybe_render_html "$report_file"
}

print_recovery_runbook() {
  local id="$1"

  echo "Recovery runbook hints:"
  cat <<'RUNBOOK'
  - Capture evidence first: alert log, trace files, Data Guard/RAC status, RMAN output, and exact error stack.
  - Confirm scope: CDB root vs PDB, file number/name, tablespace, redo group/thread, database role, and storage backend.
  - Prefer restoring from known-good backups or copies; do not reuse files corrupted by the scenario.
  - Record RTO/RPO timestamps: fault injection, detection, restore start, recovery complete, application validation.
RUNBOOK

  case "$id" in
    1|2|23)
      cat <<'RUNBOOK'
  - Control file loss/corruption:
    1. If one multiplexed control file remains, shut down, copy it to the missing location, then start the database.
    2. If all control files are lost, start NOMOUNT and restore a control file from autobackup or a known copy:
       rman target /
       startup nomount;
       restore controlfile from autobackup;
       alter database mount;
       catalog start with '<fra_or_backup_location>' noprompt;
       recover database;
    3. If a backup control file was used, expect OPEN RESETLOGS after recovery.
    4. Recreate multiplexing and verify CONTROL_FILES, V$CONTROLFILE, and alert log health.
RUNBOOK
      ;;
    3|4|18|19|20|21|24)
      cat <<'RUNBOOK'
  - Redo log loss/corruption:
    1. Identify thread/group/member status in V$LOG and V$LOGFILE before choosing a recovery action.
    2. For lost inactive groups, practice ALTER DATABASE CLEAR LOGFILE GROUP <group#> when appropriate.
    3. For active/current redo loss, expect crash/incomplete-recovery decisions; validate whether backups plus archived redo meet RPO.
    4. In RAC, include THREAD# and instance ownership. In Data Guard, consider failover/switchover if primary current redo is unrecoverable.
    5. Recreate multiplexed members and force several log switches after recovery.
RUNBOOK
      ;;
    5|8|9|10|12|15|22|59|62)
      cat <<'RUNBOOK'
  - Non-SYSTEM datafile/tablespace or archived-log recovery:
    1. Identify FILE#, TABLESPACE_NAME, CHECKPOINT_CHANGE#, and ONLINE_STATUS from V$DATAFILE, DBA_DATA_FILES, and V$RECOVER_FILE.
    2. If the database can stay open, offline the affected datafile or tablespace.
    3. Restore and recover the datafile/tablespace:
       rman target /
       sql "alter database datafile <file#> offline";
       restore datafile <file#>;
       recover datafile <file#>;
       sql "alter database datafile <file#> online";
    4. For missing archived redo, restore the archived log first or decide whether incomplete recovery is acceptable.
    5. Validate with RMAN VALIDATE, V$DATABASE_BLOCK_CORRUPTION, application checks, and a fresh backup.
RUNBOOK
      ;;
    6|13|31|38)
      cat <<'RUNBOOK'
  - Temporary file/tablespace loss:
    1. Tempfiles usually do not require media recovery.
    2. Drop the missing tempfile metadata if needed, then add a new tempfile to the temporary tablespace.
    3. Confirm DBA_TEMP_FILES, V$TEMPFILE, temp tablespace defaults, and representative sort/temp workloads.
RUNBOOK
      ;;
    7|14|17)
      cat <<'RUNBOOK'
  - SYSTEM/all-datafile database recovery:
    1. Expect MOUNT-mode recovery for SYSTEM or whole-database datafile loss.
    2. Restore and recover with RMAN:
       rman target /
       startup mount;
       restore database;
       recover database;
       alter database open;
    3. If incomplete recovery is required, document the chosen UNTIL SCN/TIME and use OPEN RESETLOGS.
    4. Validate dictionary health, components, invalid objects, listener/services, and take a new baseline backup.
RUNBOOK
      ;;
    11|36)
      cat <<'RUNBOOK'
  - Non-unique index loss:
    1. Identify dropped indexes from DDL repository, recycle bin/flashback metadata, schema export, or application deployment scripts.
    2. Rebuild with CREATE INDEX or application DDL. For unusable indexes, use ALTER INDEX ... REBUILD.
    3. Gather statistics if needed and validate execution plans for affected queries.
RUNBOOK
      ;;
    16)
      cat <<'RUNBOOK'
  - Password file loss:
    1. Recreate with orapwd for standalone filesystem deployments, matching password format/version requirements.
    2. For srvctl-managed databases, update Clusterware metadata if the password-file path changes.
    3. In Data Guard/RAC, synchronize password files across required nodes/standbys.
    4. Test local and remote SYSDBA authentication, redo transport, and broker connectivity.
RUNBOOK
      ;;
    25|29|60|61)
      cat <<'RUNBOOK'
  - Backup/FRA/catalog loss:
    1. Run CROSSCHECK and LIST BACKUP/ARCHIVELOG to separate missing local files from object-storage/catalog metadata.
    2. Restore missing local autobackups or backup pieces from secondary/object storage if available.
    3. If FRA was moved/lost, recreate the directory, permissions, and DB_RECOVERY_FILE_DEST capacity.
    4. For FRA pressure/full drills, restore DB_RECOVERY_FILE_DEST_SIZE, free reclaimable space safely, and confirm archiving resumes.
    5. For catalog outage, practice NOCATALOG recovery using control-file metadata, then resync when the catalog returns.
    6. Finish by running RESTORE VALIDATE DATABASE and taking a fresh backup.
RUNBOOK
      ;;
    26)
      cat <<'RUNBOOK'
  - SPFILE loss:
    1. If the instance is still up, create a pfile from memory or from the surviving spfile location.
    2. If down, rebuild a pfile from alert-log parameter history and known configuration.
    3. Start with pfile, create spfile from pfile, then restart normally.
    4. For RAC/ASM, ensure srvctl and ASM metadata point to the restored SPFILE.
RUNBOOK
      ;;
    27|57)
      cat <<'RUNBOOK'
  - SQL*Net/listener config loss:
    1. Restore listener.ora, tnsnames.ora, sqlnet.ora, and wallet/network includes from config backup or automation.
    2. Reload or restart listener: lsnrctl reload/start.
    3. Validate local bequeath, service registration, client TNS aliases, SCAN/VIP names if clustered, and Data Guard transport aliases.
RUNBOOK
      ;;
    28)
      cat <<'RUNBOOK'
  - ORACLE_HOME loss:
    1. Restore or reinstall the same Oracle Home version/RU and one-off patch level.
    2. Reattach inventory if needed, validate OPatch inventory, relink binaries if required.
    3. Restore network/admin, dbs password/SPFILE links, wallet/client config, and custom scripts.
    4. Start database/listener and run datapatch sanity checks if the home was rebuilt.
RUNBOOK
      ;;
    30|32|33|34|35|37|39|40|41|42)
      cat <<'RUNBOOK'
  - PDB datafile/tablespace recovery:
    1. Identify target PDB, FILE#, tablespace, and whether local undo is enabled.
    2. Close the affected PDB if needed:
       alter pluggable database <pdb_name> close immediate;
    3. Restore/recover at PDB or datafile granularity:
       rman target /
       restore pluggable database <pdb_name>;
       recover pluggable database <pdb_name>;
       sql "alter pluggable database <pdb_name> open";
    4. For single datafiles, restore/recover DATAFILE <file#> where possible.
    5. Validate PDB open mode, application services, invalid objects, and PDB-local backup posture.
RUNBOOK
      ;;
    43)
      cat <<'RUNBOOK'
  - PDB table loss:
    1. Try FLASHBACK TABLE if recycle bin/flashback requirements are met.
    2. Otherwise recover via Data Pump import, table-level RMAN recovery, PDB PITR clone, or application DDL/data reload.
    3. Validate dependent indexes, constraints, grants, triggers, statistics, and application row counts.
RUNBOOK
      ;;
    44)
      cat <<'RUNBOOK'
  - PDB schema loss:
    1. Prefer Data Pump schema import if exports are part of the DR design.
    2. Otherwise practice PDB point-in-time recovery to an auxiliary location and extract/import the schema.
    3. Recreate grants, synonyms, jobs, scheduler objects, statistics, and application credentials.
RUNBOOK
      ;;
    45)
      cat <<'RUNBOOK'
  - Dropped PDB recovery:
    1. If unplug metadata exists, evaluate plug-in recovery paths; otherwise use RMAN/PITR or restore the CDB to recover the PDB.
    2. Practice RESTORE PLUGGABLE DATABASE and RECOVER PLUGGABLE DATABASE where backups support it.
    3. Recreate services, open modes, save state, local users, wallets, and application connectivity.
RUNBOOK
      ;;
    46|49|72)
      cat <<'RUNBOOK'
  - ASM disk, disk group, or SPFILE recovery:
    1. Use asmcmd/SQL to inspect disk group mount state, redundancy, failgroups, missing/offline disks, and rebalance operations.
    2. For single-disk failure, confirm redundancy is still intact, monitor ASM rebalance, and restore/replace/drop/add the disk according to lab design.
    3. Restore ASM metadata/SPFILE from backup or OCR/srvctl metadata where applicable.
    4. Mount disk groups, then validate database files and Clusterware resources.
    5. For FEX/ACFS-style @... managed storage, use provider-approved storage controls, validate GI/database services, and collect provider redundancy/rebuild evidence before allowing destructive execution.
RUNBOOK
      ;;
    47|48)
      cat <<'RUNBOOK'
  - OCR/voting disk recovery:
    1. Capture crsctl query css votedisk and ocrcheck output before repair.
    2. Practice OCR restore from automatic backup and voting disk replacement per Grid Infrastructure version.
    3. Validate CRS stack, node membership, database resources, services, and post-recovery backups.
RUNBOOK
      ;;
    50|67)
      cat <<'RUNBOOK'
  - Standby apply cancelled or apply-lag simulation:
    1. Restart managed recovery:
       alter database recover managed standby database disconnect from session;
    2. If using broker, set apply state through DGMGRL and validate configuration.
    3. Monitor V$DATAGUARD_STATS, V$ARCHIVE_DEST_STATUS, alert log, and apply lag until caught up.
    4. Compare actual lag duration against RPO/SLA and confirm alerting detected the breach.
RUNBOOK
      ;;
    51|52|54|68)
      cat <<'RUNBOOK'
  - Data Guard transport/broker/snapshot drill:
    1. Restore transport state, then force a log switch on the primary.
    2. Validate broker configuration with DGMGRL SHOW CONFIGURATION and SHOW DATABASE VERBOSE.
    3. Monitor transport/apply lag, archive gaps, protection mode, and FSFO observer state if enabled.
RUNBOOK
      ;;
    66)
      cat <<'RUNBOOK'
  - FSFO observer unavailable:
    1. Confirm FSFO status, observer location, failover target, threshold, and protection mode with DGMGRL and V$DATABASE.
    2. Stop or isolate only the observer in an approved lab; do not break primary-standby redo transport unless that is a separate scenario.
    3. Validate broker warnings, failover expectations, monitoring alerts, and observer restart procedure.
    4. Restart the observer and confirm FSFO returns to the expected synchronized/ready state.
RUNBOOK
      ;;
    69)
      cat <<'RUNBOOK'
  - Standby redo log misconfiguration:
    1. Compare online redo groups and sizes per thread against standby redo logs.
    2. Add SRLs so each thread has at least online redo group count plus one, with SRLs at least as large as online redo.
    3. In RAC, validate every redo thread and every standby site.
    4. Force log switches, confirm real-time apply, and validate Data Guard broker status after changes.
RUNBOOK
      ;;
    53)
      cat <<'RUNBOOK'
  - Active Data Guard read-only pressure:
    1. Confirm the standby remains read-only with apply, and distinguish query pressure from apply lag.
    2. Validate services, resource manager limits, session cleanup, and lag metrics.
RUNBOOK
      ;;
    55|56|70|71)
      cat <<'RUNBOOK'
  - RAC instance/service recovery:
    1. Check crsctl stat res -t, srvctl status database, srvctl status service, and alert logs on all nodes.
    2. Restart the failed instance, relocate VIP/services, or start services with srvctl as appropriate.
    3. Validate FAN/ONS, TAF/Application Continuity/TAC behavior, connection pool response, and service placement after recovery.
    4. For VIP drills, validate SCAN/VIP listener behavior and client retry timing from outside the cluster.
RUNBOOK
      ;;
    58)
      cat <<'RUNBOOK'
  - TDE wallet/keystore loss:
    1. Restore wallet/keystore files from secure backup, preserving permissions and wallet_root layout.
    2. Open the keystore and validate encrypted tablespaces/backups.
    3. In RAC/Data Guard, synchronize wallet material to every required node/site and test redo apply.
RUNBOOK
      ;;
    63)
      cat <<'RUNBOOK'
  - TEMP exhaustion:
    1. Confirm which SQL, module, user, or PDB consumed TEMP from V$TEMPSEG_USAGE and ASH/AWR evidence where licensed.
    2. Relieve pressure by stopping the runaway workload, adding TEMP capacity, or adjusting workload/resource manager limits.
    3. Validate temporary tablespace defaults, tempfile autoextend/maxsize posture, and alerts for ORA-01652.
    4. Clean up disposable lab objects and confirm representative reporting/ETL workloads can complete.
RUNBOOK
      ;;
    64|65)
      cat <<'RUNBOOK'
  - RTO/RPO validation drill:
    1. Supply realistic objectives with --maa-local-rto/--maa-local-rpo, --maa-dr-rto/--maa-dr-rpo, or guided MAA/SLA context.
    2. For RTO, run a scenario recovery first so CrashSimulator has measured recovery start/complete timestamps.
    3. For RPO, review archived redo, backed-up archived redo, Data Guard lag, and archive-gap evidence.
    4. Treat PASS/FAIL as an operational drill result, then update backup cadence, Data Guard transport/apply, monitoring, and runbooks.
RUNBOOK
      ;;
    83|84|87)
      cat <<'RUNBOOK'
  - Service continuity, AC/TAC, FAN/ONS, and role-service validation:
    1. Inventory service attributes from SQL and srvctl before changing anything.
    2. Confirm application drivers/pools support FAN, Transaction Guard, AC/TAC, and service drain behavior.
    3. Run replay/notification tests with a replay-safe client workload and capture application-visible behavior.
    4. For Data Guard role services, validate service placement before and after an approved role transition.
RUNBOOK
      ;;
    85|86)
      cat <<'RUNBOOK'
  - Data Guard switchover/failback:
    1. Validate Broker configuration, lag, SRLs, flashback, protection mode, and service role placement before transition.
    2. Communicate the planned window, drain services, run DGMGRL validation, and capture pre-transition evidence.
    3. Execute switchover/failback only in an approved lab or change window.
    4. Validate new roles, apply, services, applications, monitoring, backups, and the path back to the original topology.
RUNBOOK
      ;;
    88)
      cat <<'RUNBOOK'
  - PDB point-in-time recovery:
    1. Choose an exact recovery timestamp/SCN and confirm backups plus archived redo cover it.
    2. Allocate an auxiliary destination with enough free space and run RMAN preview before recovery.
    3. Recover only the intended PDB, validate open state, services, application data, and invalid objects.
    4. Take a fresh backup after successful PITR and document RTO/RPO.
RUNBOOK
      ;;
    89|90)
      cat <<'RUNBOOK'
  - Restore point and patch rollback readiness:
    1. Confirm Flashback Database, FRA headroom, recent backups, restore points, and Data Guard/app service posture.
    2. Create a guaranteed restore point only for an approved change window and monitor FRA growth.
    3. Validate rollback in a lab, including OPEN RESETLOGS consequences where applicable.
    4. Drop restore points only after fallback closure and a new backup baseline.
RUNBOOK
      ;;
    EXA01|EXA02|EXA03|EXA04)
      cat <<'RUNBOOK'
  - Exadata platform drill:
    1. Collect cell, ASM, database, service, and workload evidence before any platform fault.
    2. Use an Exadata-approved lab and tooling path; do not simulate storage/cell faults from generic OS commands.
    3. Validate rebalance/repair, database service continuity, Smart Scan/Flash Cache behavior, and application impact.
RUNBOOK
      ;;
    OCI01|OCI02|OCI03|OCI04|OCI05)
      cat <<'RUNBOOK'
  - OCI Base Database Service drill:
    1. Capture OCI control-plane, DBaaS tooling, RMAN, network, service, and wallet evidence.
    2. Keep cloud fault injection inside an approved compartment/VCN/lab boundary with rollback commands prepared.
    3. Validate backups, cross-region restore, DB system recovery, DNS/VCN/NSG behavior, and application reconnect.
RUNBOOK
      ;;
    GG01|GG02|GG03|GG04)
      cat <<'RUNBOOK'
  - GoldenGate drill:
    1. Inventory deployment, Extract, Replicat, trail, checkpoint, heartbeat, and lag evidence.
    2. Confirm source/target consistency checks and resync path before stopping processes or manipulating trails.
    3. Validate lag alerts, restart/catch-up behavior, trail recovery, and application/data consistency after the drill.
RUNBOOK
      ;;
    73|79)
      cat <<'RUNBOOK'
  - ORDS service or ORDS node outage:
    1. Confirm user impact with the ORDS/APEX smoke URL, load balancer URL if present, and application-specific APEX page checks.
    2. Restart the affected ORDS service with systemctl, then validate service status, logs, and HTTP response.
    3. In RAC or multi-node ORDS, confirm the load balancer removed/added the node as expected and sessions behaved acceptably.
    4. Capture timing for detection, restart, application availability, and any required user retry/relogin.
RUNBOOK
      ;;
    74|75)
      cat <<'RUNBOOK'
  - ORDS configuration loss or pool misconfiguration:
    1. Restore the ORDS configuration directory, wallets, pool settings, and static-file mappings from a known-good backup.
    2. Validate database service name, credentials, wallet/TLS settings, connection pool sizing, and PL/SQL gateway mode.
    3. Restart ORDS and test the ORDS landing page, APEX application URL, SQL Developer Web if enabled, and logs.
    4. Keep ORDS config backups synchronized across ORDS nodes and document credential rotation steps.
RUNBOOK
      ;;
    76)
      cat <<'RUNBOOK'
  - APEX/ORDS runtime account locked:
    1. Identify whether APEX_PUBLIC_USER, ORDS_PUBLIC_USER, or ORDS_METADATA is locked/expired in the target PDB.
    2. Unlock the account or rotate credentials according to policy, then update ORDS config if passwords changed.
    3. Restart ORDS if credential changes require it and validate APEX/ORDS URL access.
    4. Capture audit evidence for who changed the account and why.
RUNBOOK
      ;;
    77)
      cat <<'RUNBOOK'
  - APEX static resources unavailable:
    1. Restore the APEX images/static directory or ORDS static mapping from backup.
    2. Confirm ownership, permissions, context path such as /i/, and ORDS config static resource settings.
    3. Validate APEX pages for CSS, JavaScript, images, login, and application runtime behavior.
RUNBOOK
      ;;
    78|80)
      cat <<'RUNBOOK'
  - APEX application/session availability:
    1. Validate the ORDS landing page and a real APEX application URL after database/PDB/ORDS recovery.
    2. For session continuity, keep an active test session open during ORDS, RAC service, Data Guard, or database recovery drills.
    3. When possible, use the seeded browser-session driver with a disposable APEX app and a stable success selector such as #CRASHSIM_SESSION_OK.
    4. Record whether users see retry, relogin, lost state, failed transaction, or seamless continuation.
    5. Feed findings into service AC/TAC, FAN/ONS, pool retry, and APEX session timeout design.
RUNBOOK
      ;;
    81)
      cat <<'RUNBOOK'
  - APEX mail queue/configuration validation:
    1. Review SMTP host/port/wallet parameters, network ACLs, and TLS certificate dependencies.
    2. Validate notification delivery after PDB recovery, wallet restore, ORDS restart, and network changes.
    3. Capture failed mail queue evidence and document the operational restart/resubmit procedure.
RUNBOOK
      ;;
    82)
      cat <<'RUNBOOK'
  - APEX upgrade or patch rollback readiness:
    1. Capture APEX version, component status, invalid objects, runtime users, ORDS version/config, and static-file version before changes.
    2. Take database and ORDS config/static-file backups before patching.
    3. After patch or rollback, validate APEX registry, invalid objects, workspaces/apps, ORDS URL, and representative applications.
    4. Document cutover, rollback decision points, and evidence required by change control.
RUNBOOK
      ;;
    *)
      cat <<'RUNBOOK'
  - Generic recovery:
    1. Identify failed component and choose restore/recreate/failover based on RTO/RPO.
    2. Validate database consistency and application behavior.
    3. Capture lessons learned and update backups, monitoring, and runbooks.
RUNBOOK
      ;;
  esac
}

add_action() {
  local kind="$1"
  local target="$2"
  local detail="${3:-}"
  ACTION_KINDS+=("$kind")
  ACTION_TARGETS+=("$target")
  ACTION_DETAILS+=("$detail")
}

reset_actions() {
  ACTION_KINDS=()
  ACTION_TARGETS=()
  ACTION_DETAILS=()
}

print_actions() {
  local kind target detail
  local i=1
  local idx
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    detail="${ACTION_DETAILS[$idx]}"
    printf "%2d. %-14s %s" "$i" "$kind" "$target"
    if [[ -n "$detail" ]]; then
      printf " (%s)" "$detail"
    fi
    printf "\n"
    i=$((i + 1))
  done
}

execute_actions() {
  if [[ "${#ACTION_KINDS[@]}" -eq 0 ]]; then
    die "No targets were found for this scenario."
  fi

  echo "Planned actions:"
  print_actions
  echo
  if [[ "$PLANNING_ONLY" -eq 1 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$PLANNING_ONLY" -eq 0 ]]; then
    record_action_targets
  fi

  local has_external=0
  local external_idx
  for external_idx in "${!ACTION_KINDS[@]}"; do
    if [[ "${ACTION_KINDS[$external_idx]}" == "external" ]]; then
      has_external=1
      break
    fi
  done

  if [[ "$EXECUTE" -eq 0 ]]; then
    if [[ "$has_external" -eq 1 ]]; then
      info "DRY-RUN complete. One or more targets require a provider-specific handler before execution."
      return "$SUCCESS"
    fi
    info "DRY-RUN complete. Re-run with --execute to perform these actions."
    return "$SUCCESS"
  fi
  [[ "$has_external" -eq 0 ]] ||
    die "One or more planned targets require a provider-specific handler and cannot be executed safely yet."

  local kind target detail idx
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    detail="${ACTION_DETAILS[$idx]}"
    case "$kind" in
      fs_rename)
        perform_fs_rename "$target"
        ;;
      fs_corrupt_header)
        perform_fs_corrupt "$target" 1 1
        ;;
      fs_corrupt_body)
        perform_fs_corrupt "$target" 1 30
        ;;
      asm_rm|asm_tempfile_rm)
        perform_asm_rm "$target"
        ;;
      asm_corrupt_header)
        perform_asm_rm "$target"
        ;;
      sql)
        run_sql_action "$detail" "$target"
        ;;
      sqlfile)
        run_sql_script_file "$target" "$detail"
        ;;
      report)
        echo "Report action: ${target} ${detail}"
        ;;
      srvctl_abort_instance)
        perform_srvctl_abort_instance "$target"
        ;;
      srvctl_abort_database)
        perform_srvctl_abort_database
        ;;
      srvctl_relocate_service)
        perform_srvctl_relocate_service "$target" "$detail"
        ;;
      srvctl_stop_start_service_instance)
        perform_srvctl_stop_start_service_instance "$target" "$detail"
        ;;
      systemctl_stop_service)
        perform_systemctl_service_action stop "$target"
        ;;
      systemctl_start_service)
        perform_systemctl_service_action start "$target"
        ;;
      ords_priv_config_rename)
        perform_ords_priv_config_rename "$target"
        ;;
      ords_pool_bad_service)
        perform_ords_pool_bad_service
        ;;
      external)
        die "External target requires a provider-specific handler and was not executed: $target"
        ;;
      *)
        die "Unknown action kind: $kind"
        ;;
    esac
  done
}

perform_asm_rm() {
  local path="$1"
  [[ "$(storage_path_class "$path")" == "asm" ]] || die "ASM remove action received a non-ASM path: $path"
  echo "asmcmd rm $path (Grid owner: ${GRID_USER})"
  run_asmcmd_with_grid_env rm "$path" ||
    die "Unable to remove ASM file with asmcmd: $path"
}

perform_systemctl_service_action() {
  local action="$1"
  local service="$2"
  local method

  [[ -n "$service" ]] || die "No systemd service name was supplied."

  case "$action" in
    start|stop|restart|status) ;;
    *) die "Unsupported systemctl action: $action" ;;
  esac

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run systemctl ${action} ${service}"
    return "$SUCCESS"
  fi

  method="$(ords_control_method || true)"
  if [[ "$method" == "systemctl" ]]; then
    command -v systemctl >/dev/null 2>&1 || die "systemctl was not found."
    echo "systemctl ${action} ${service}"
    systemctl "$action" "$service" ||
      die "systemctl ${action} ${service} failed."
  elif [[ "$method" == "ords_priv_helper" ]]; then
    run_ords_priv_helper service "$action" "$service" ||
      die "approved ORDS helper service ${action} ${service} failed."
  elif [[ "$method" == "sudo_systemctl" ]]; then
    echo "sudo -n systemctl ${action} ${service}"
    sudo -n systemctl "$action" "$service" ||
      die "sudo systemctl ${action} ${service} failed."
  else
    die "systemctl ${action} ${service} requires root or passwordless sudo for the current OS user."
  fi
}

ords_config_get_value() {
  local key="$1"
  local output
  command -v ords >/dev/null 2>&1 || return "$FAIL"
  output="$(ords --config "$ORDS_CONFIG_DIR" config get "$key" 2>/dev/null | trim_blank_lines || true)"
  printf "%s" "$output" | tail -n 1
}

ords_config_set_value() {
  local key="$1"
  local value="$2"
  command -v ords >/dev/null 2>&1 || return "$FAIL"
  echo "ords --config ${ORDS_CONFIG_DIR} config set ${key} ${value}"
  ords --config "$ORDS_CONFIG_DIR" config set "$key" "$value" >/dev/null
}

