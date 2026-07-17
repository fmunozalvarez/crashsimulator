# srvctl ships inside EVERY database home, so a runnable srvctl proves nothing
# about Grid Infrastructure / Oracle Restart being installed (misreading it
# classified plain single-instance labs as GI_SINGLE and the seed planner then
# attempted srvctl service creation that can never work there). Only the OLR
# registration laid down by root.sh, or a live HAS stack, count as evidence.
topology_grid_stack_present() {
  [[ -f /etc/oracle/olr.loc || -f /var/opt/oracle/olr.loc ]] && return "$SUCCESS"
  if grid_tool_available crsctl; then
    run_grid_tool crsctl check has 2>/dev/null | grep -qi "online" && return "$SUCCESS"
  fi
  return "$FAIL"
}

collect_datafile_plan() {
  reset_plan_targets

  local idx kind target metadata pdb_name con_id file_no tablespace path target_no
  target_no=1
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    case "$kind" in
      fs_rename|fs_corrupt_header|asm_rm|asm_corrupt_header|external)
        ;;
      *)
        continue
        ;;
    esac

    metadata="$(datafile_metadata_for_path "$target" || true)"
    if [[ -z "$metadata" ]]; then
      warn "Skipping non-datafile target for RMAN protection: $target"
      continue
    fi

    IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$metadata"
    PLAN_TARGET_PATHS+=("$path")
    PLAN_TARGET_PDBS+=("$pdb_name")
    PLAN_TARGET_CON_IDS+=("$con_id")
    PLAN_TARGET_FILE_NOS+=("$file_no")
    PLAN_TARGET_TABLESPACES+=("$tablespace")

    manifest_append "target_${target_no}_path" "$path"
    manifest_append "target_${target_no}_pdb_name" "$pdb_name"
    manifest_append "target_${target_no}_con_id" "$con_id"
    manifest_append "target_${target_no}_file_no" "$file_no"
    manifest_append "target_${target_no}_tablespace" "$tablespace"
    target_no=$((target_no + 1))
  done

  manifest_append "target_count" "${#PLAN_TARGET_FILE_NOS[@]}"
  [[ "${#PLAN_TARGET_FILE_NOS[@]}" -gt 0 ]] || die "No datafile targets were found for RMAN protection/recovery."
}

join_csv() {
  local IFS=,
  printf "%s" "$*"
}

rman_tag() {
  local id="$1"
  printf "CSIM%s_%s" "$id" "$RUN_ID"
}

run_sql_script_file() {
  local script_file="$1"
  local log_file="$2"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "SQL*Plus script: $script_file"
    sed 's/^/  /' "$script_file"
    return "$SUCCESS"
  fi

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$script_file" >"$log_file" </dev/null ||
    die "SQL*Plus script failed: $script_file (log: $log_file)"
}

run_rman_cmdfile() {
  local cmd_file="$1"
  local log_file="$2"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "RMAN command file: $cmd_file"
    sed 's/^/  /' "$cmd_file"
    return "$SUCCESS"
  fi

  ensure_rman
  "$RMAN_BIN" target / cmdfile="$cmd_file" log="$log_file" ||
    die "RMAN command file failed: $cmd_file (log: $log_file)"
}

safe_remove_after_validation() {
  local path="$1"
  [[ -n "$path" ]] || return "$SUCCESS"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would remove validated scenario backup $path"
    return "$SUCCESS"
  fi
  [[ -e "$path" ]] || return "$SUCCESS"
  echo "rm -f -- $path"
  rm -f -- "$path" || die "Unable to remove validated scenario backup: $path"
}

write_open_pdbs_sql_file() {
  local sql_file="$1"
  cat >"$sql_file" <<'SQL' || die "Unable to write PDB open SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
declare
  l_cdb v$database.cdb%type;
begin
  select cdb into l_cdb from v$database;

  if l_cdb = 'YES' then
    for r in (
      select name, open_mode
      from v$pdbs
      where name <> 'PDB$SEED'
      order by con_id
    ) loop
      if r.open_mode not in ('READ WRITE', 'READ ONLY', 'READ ONLY WITH APPLY') then
        execute immediate 'alter pluggable database ' || dbms_assert.simple_sql_name(r.name) || ' open';
      else
        dbms_output.put_line('PDB ' || r.name || ' already open: ' || r.open_mode);
      end if;
    end loop;
  end if;
end;
/
exit
SQL
}

run_sql_text() {
  local title="$1"
  local sql_text="$2"
  local output_file="$3"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN SQL: $title"
    printf "%s\n" "$sql_text" | sed 's/^/  /'
    return "$SUCCESS"
  fi

  sql_query "$output_file" "$sql_text" ||
    die "SQL failed: $title (log: $output_file)"
}

query_instance_status() {
  local output_file="$1"
  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" >"$output_file" <<SQL
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off termout off
set linesize 32767 trimspool on trimout on tab off
select status from v\$instance;
exit
SQL
}

ensure_database_open() {
  local status_file="$WORK_DIR/instance_status.out"
  local open_file="$WORK_DIR/open_database.sql"
  local open_log="$LOG_DIR/crashsim_recover_open_database_${RUN_ID}.log"
  local status

  if [[ "$EXECUTE" -eq 0 ]]; then
    cat >"$open_file" <<'SQL' || die "Unable to write database-open SQL file: $open_file"
whenever sqlerror exit sql.sqlcode
-- Recovery will query V$INSTANCE and then STARTUP, ALTER DATABASE MOUNT,
-- or ALTER DATABASE OPEN only when the current state requires it.
exit
SQL
    echo "SQL*Plus script: $open_file"
    sed 's/^/  /' "$open_file"
    return "$SUCCESS"
  fi

  if ! query_instance_status "$status_file"; then
    cat >"$open_file" <<'SQL' || die "Unable to write database startup SQL file: $open_file"
whenever sqlerror exit sql.sqlcode
startup
exit
SQL
    run_sql_script_file "$open_file" "$open_log"
  else
    status="$(trim_blank_lines <"$status_file" | head -n 1 | tr -d ' ')"
    case "$status" in
      OPEN)
        ;;
      MOUNTED)
        run_sql_text "open mounted database" "alter database open;" "$open_log"
        ;;
      STARTED)
        run_sql_text "mount and open started database" "
alter database mount;
alter database open;
" "$open_log"
        ;;
      *)
        die "Unsupported instance status during recovery: ${status:-unknown}"
        ;;
    esac
  fi

  local pdb_sql="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.sql"
  local pdb_log="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.log"
  write_open_pdbs_sql_file "$pdb_sql"
  run_sql_script_file "$pdb_sql" "$pdb_log"
}

force_database_open() {
  local open_file="$WORK_DIR/startup_force_database.sql"
  local open_log="$LOG_DIR/crashsim_recover_startup_force_${RUN_ID}.log"

  cat >"$open_file" <<'SQL' || die "Unable to write startup-force SQL file: $open_file"
whenever sqlerror exit sql.sqlcode
startup force
exit
SQL
  run_sql_script_file "$open_file" "$open_log"

  local pdb_sql="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.sql"
  local pdb_log="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.log"
  write_open_pdbs_sql_file "$pdb_sql"
  run_sql_script_file "$pdb_sql" "$pdb_log"
}

write_tempfile_recovery_sql_file() {
  local container_name="$1"
  local original_path="$2"
  local sql_file="$3"
  local container_sql=""
  local original_literal

  original_literal="$(sql_quote "$original_path")"
  if [[ -n "$container_name" && "$container_name" != "CDB\$ROOT" && "$container_name" != "ROOT" && "$container_name" != "NONCDB" ]]; then
    container_sql="alter session set container = $(sql_identifier "$container_name");"
  fi

  cat >"$sql_file" <<SQL || die "Unable to write tempfile recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
${container_sql}
declare
  l_tempfile_count number := 0;
  l_temp_tbs database_properties.property_value%type;
begin
  select property_value
    into l_temp_tbs
    from database_properties
   where property_name = 'DEFAULT_TEMP_TABLESPACE';

  select count(*)
    into l_tempfile_count
    from v\$tempfile
   where con_id = to_number(sys_context('USERENV', 'CON_ID'));

  dbms_output.put_line('Default temporary tablespace: ' || l_temp_tbs);
  dbms_output.put_line('Current tempfile count before metadata repair: ' || l_tempfile_count);

  begin
    dbms_output.put_line('Dropping missing tempfile metadata for ${original_path}');
    execute immediate 'alter database tempfile ' || chr(39) || ${original_literal} || chr(39) || ' drop including datafiles';
  exception
    when others then
      if sqlcode = -1516 then
        dbms_output.put_line('Original tempfile is not in metadata; an OMF replacement may already exist.');
      else
        raise;
      end if;
  end;

  select count(*)
    into l_tempfile_count
    from v\$tempfile
   where con_id = to_number(sys_context('USERENV', 'CON_ID'));

  dbms_output.put_line('Current tempfile count after metadata repair: ' || l_tempfile_count);

  if l_tempfile_count <= 0 then
    dbms_output.put_line('Adding replacement tempfile to ' || l_temp_tbs);
    execute immediate 'alter tablespace ' || dbms_assert.simple_sql_name(l_temp_tbs) ||
      ' add tempfile size ${TEMPFILE_SIZE} autoextend on next 10m maxsize unlimited';
  end if;

  select count(*)
    into l_tempfile_count
    from v\$tempfile
   where con_id = to_number(sys_context('USERENV', 'CON_ID'));

  if l_tempfile_count <= 0 then
    raise_application_error(-20001, 'Temporary tablespace ' || l_temp_tbs || ' has no tempfiles after recovery.');
  end if;
end;
/
select file#, status, enabled, name
from v\$tempfile
where con_id = to_number(sys_context('USERENV', 'CON_ID'))
order by file#;
exit
SQL
}

load_manifest_tempfile_targets() {
  RECOVER_TEMPFILE_PATHS=()
  RECOVER_TEMPFILE_TABLESPACE=""
  RECOVER_TEMPFILE_PDB=""

  local count idx kind path tablespace pdb_name
  count="$(manifest_get "planned_action_count" || true)"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0

  idx=1
  while [[ "$idx" -le "$count" ]]; do
    kind="$(manifest_get "action_${idx}_kind" || true)"
    case "$kind" in
      fs_rename|asm_tempfile_rm)
        path="$(manifest_first_value "action_${idx}_tempfile" "action_${idx}_target" || true)"
        if [[ -n "$path" ]]; then
          RECOVER_TEMPFILE_PATHS+=("$path")
          tablespace="$(manifest_get "action_${idx}_tablespace" || true)"
          pdb_name="$(manifest_get "action_${idx}_pdb_name" || true)"
          [[ -n "$RECOVER_TEMPFILE_TABLESPACE" || -z "$tablespace" ]] ||
            RECOVER_TEMPFILE_TABLESPACE="$tablespace"
          [[ -n "$RECOVER_TEMPFILE_PDB" || -z "$pdb_name" ]] ||
            RECOVER_TEMPFILE_PDB="$pdb_name"
        fi
        ;;
    esac
    idx=$((idx + 1))
  done

  if [[ "${#RECOVER_TEMPFILE_PATHS[@]}" -eq 0 ]]; then
    local paths original backup
    if paths="$(manifest_rename_paths 2>/dev/null)"; then
      IFS='|' read -r original backup <<<"$paths"
      [[ -n "$original" ]] && RECOVER_TEMPFILE_PATHS+=("$original")
    fi
  fi

  [[ "${#RECOVER_TEMPFILE_PATHS[@]}" -gt 0 ]]
}

write_tempfile_list_recovery_sql_file() {
  local container_name="$1"
  local tablespace_name="$2"
  local sql_file="$3"
  shift 3

  local container_sql="" tablespace_literal path path_literal
  if [[ -n "$container_name" && "$container_name" != "CDB\$ROOT" && "$container_name" != "ROOT" && "$container_name" != "NONCDB" ]]; then
    container_sql="alter session set container = $(sql_identifier "$container_name");"
  fi
  tablespace_literal="$(sql_quote "$tablespace_name")"

  {
    cat <<SQL
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
${container_sql}
declare
  l_tempfile_count number := 0;
  l_temp_tbs varchar2(128) := ${tablespace_literal};
begin
  if l_temp_tbs is null then
    select property_value
      into l_temp_tbs
      from database_properties
     where property_name = 'DEFAULT_TEMP_TABLESPACE';
  end if;

  dbms_output.put_line('Temporary tablespace selected for repair: ' || l_temp_tbs);
SQL

    for path in "$@"; do
      path_literal="$(sql_quote "$path")"
      cat <<SQL
  begin
    dbms_output.put_line('Dropping missing tempfile metadata for ${path}');
    execute immediate 'alter database tempfile ' || chr(39) || ${path_literal} || chr(39) || ' drop including datafiles';
  exception
    when others then
      if sqlcode in (-1516, -1116, -1110) then
        dbms_output.put_line('Tempfile metadata was already absent or not usable: ${path}');
      else
        raise;
      end if;
  end;
SQL
    done

    cat <<'SQL'

  select count(*)
    into l_tempfile_count
    from v$tempfile tf
    join v$tablespace ts
      on ts.con_id = tf.con_id
     and ts.ts# = tf.ts#
   where tf.con_id = to_number(sys_context('USERENV', 'CON_ID'))
     and ts.name = l_temp_tbs;

  dbms_output.put_line('Current tempfile count after metadata repair: ' || l_tempfile_count);

  if l_tempfile_count <= 0 then
    dbms_output.put_line('Adding replacement tempfile to ' || l_temp_tbs);
SQL
    printf "    execute immediate 'alter tablespace ' || dbms_assert.simple_sql_name(l_temp_tbs) ||\n"
    printf "      ' add tempfile size %s autoextend on next 10m maxsize unlimited';\n" "$TEMPFILE_SIZE"
    cat <<'SQL'
  end if;

  select count(*)
    into l_tempfile_count
    from v$tempfile tf
    join v$tablespace ts
      on ts.con_id = tf.con_id
     and ts.ts# = tf.ts#
   where tf.con_id = to_number(sys_context('USERENV', 'CON_ID'))
     and ts.name = l_temp_tbs;

  if l_tempfile_count <= 0 then
    raise_application_error(-20001, 'Temporary tablespace ' || l_temp_tbs || ' has no tempfiles after recovery.');
  end if;
end;
/
select tf.file#, tf.status, tf.enabled, ts.name tablespace_name, tf.name
from v$tempfile tf
join v$tablespace ts
  on ts.con_id = tf.con_id
 and ts.ts# = tf.ts#
where tf.con_id = to_number(sys_context('USERENV', 'CON_ID'))
order by ts.name, tf.file#;
exit
SQL
  } >"$sql_file" || die "Unable to write tempfile-list recovery SQL file: $sql_file"
}

discover_service_name() {
  if [[ -n "$SERVICE_NAME" ]]; then
    printf "%s\n" "$SERVICE_NAME"
    return "$SUCCESS"
  fi

  local file="$WORK_DIR/service_name.out"
  sql_query "$file" "
select regexp_substr(value, '[^,]+', 1, 1)
from v\$parameter
where name = 'service_names';
" || return "$FAIL"
  SERVICE_NAME="$(trim_blank_lines <"$file" | head -n 1 | tr -d ' ')"
  [[ -n "$SERVICE_NAME" ]] || return "$FAIL"
  printf "%s\n" "$SERVICE_NAME"
}

sqlplus_password_literal() {
  local value="$1"
  value="${value//\"/\\\"}"
  printf "%s" "$value"
}

remote_sysdba_test() {
  local service output_file status password_escaped
  [[ -n "$SYS_PASSWORD" ]] || die "Password-file recovery requires --sys-password or CRASHSIM_SYS_PASSWORD for remote SYSDBA validation."
  password_escaped="$(sqlplus_password_literal "$SYS_PASSWORD")"
  output_file="$WORK_DIR/remote_sysdba_test.out"

  if [[ "$EXECUTE" -eq 0 ]]; then
    service="${SERVICE_NAME:-<service_name>}"
    cat <<DRYRUN
DRY-RUN: would validate remote SYSDBA using:
  connect sys/"********"@//localhost:1521/${service} as sysdba
  require output prefix: REMOTE_SYSDBA_OK|
DRYRUN
    return "$SUCCESS"
  fi

  service="$(discover_service_name)" || die "Could not discover listener service name. Use --service-name or CRASHSIM_SERVICE_NAME."
  ensure_sqlplus
  "$SQLPLUS_BIN" -L -s /nolog >"$output_file" <<SQL
connect sys/"${password_escaped}"@//localhost:1521/${service} as sysdba
set heading off feedback off pages 0 verify off echo off
select 'REMOTE_SYSDBA_OK|' || name || '|' || open_mode from v\$database;
exit
SQL
  status=$?
  cat "$output_file"
  [[ "$status" -eq 0 ]] || die "Remote SYSDBA SQL*Plus exited with status $status."
  grep -q '^REMOTE_SYSDBA_OK|' "$output_file" ||
    die "Remote SYSDBA validation did not return REMOTE_SYSDBA_OK."
}

restore_sysbackup_user_if_present() {
  [[ -n "$SYSBACKUP_USER" ]] || return "$SUCCESS"

  local user_literal
  user_literal="$(sql_quote "$SYSBACKUP_USER")"
  run_sql_text "restore SYSBACKUP grant for ${SYSBACKUP_USER} if account exists" "
declare
  l_count number;
begin
  select count(*)
    into l_count
    from cdb_users
   where username = ${user_literal}
     and common = 'YES';

  if l_count > 0 then
    execute immediate 'grant sysbackup to ${SYSBACKUP_USER} container=all';
  end if;
end;
/
" "$LOG_DIR/crashsim_recover_sysbackup_${RUN_ID}.log"
}

archivelog_sequence_for_path() {
  local path="$1"
  local path_literal file seq
  path_literal="$(sql_quote "$path")"
  file="$WORK_DIR/archivelog_sequence.out"
  sql_query "$file" "
select sequence#
from v\$archived_log
where name = ${path_literal}
  and rownum = 1;
" || return "$FAIL"
  seq="$(trim_blank_lines <"$file" | head -n 1 | tr -d ' ')"
  [[ "$seq" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$seq"
}

backupset_key_for_piece() {
  local path="$1"
  local path_literal file key
  path_literal="$(sql_quote "$path")"
  file="$WORK_DIR/backupset_key.out"
  sql_query "$file" "
select bs.recid
from v\$backup_piece bp
join v\$backup_set bs
  on bs.set_stamp = bp.set_stamp
 and bs.set_count = bp.set_count
where bp.handle = ${path_literal}
  and rownum = 1;
" || return "$FAIL"
  key="$(trim_blank_lines <"$file" | head -n 1 | tr -d ' ')"
  [[ "$key" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$key"
}

discover_environment() {
  if [[ "$DISCOVERED" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  ensure_os_user
  ensure_sqlplus

  local db_file="$WORK_DIR/db.env"
  local instance_file="$WORK_DIR/instance.env"
  local params_file="$WORK_DIR/params.env"
  local pdb_file="$WORK_DIR/pdbs.env"

  # Fail closed if v$database is unreadable: with the instance down, sqlplus
  # prints the failing statement + ORA-01034 and this parser used to swallow
  # that as topology (DB_ROLE became a stray quote from the echoed SQL), so
  # readiness gates blamed the database ROLE instead of the dead instance.
  if ! sql_query "$db_file" "
select name || '|' ||
       db_unique_name || '|' ||
       database_role || '|' ||
       open_mode || '|' ||
       cdb || '|' ||
       protection_mode || '|' ||
       switchover_status
from v\$database;
"; then
    local ora_hint
    ora_hint="$(grep -m 1 -oE 'ORA-[0-9]+.*' "$db_file" 2>/dev/null)"
    die "Topology discovery cannot read v\$database (${ora_hint:-SQL*Plus connection failed}).
The Oracle instance is not available. Start it (sqlplus / as sysdba; startup) - or, if a
destructive scenario was injected earlier and never recovered, run --recover for that
scenario first - then retry."
  fi
  local db_line
  db_line="$(trim_blank_lines <"$db_file" | head -n 1)"
  case "$db_line" in
    *"|"*"|"*"|"*"|"*"|"*"|"*) ;;
    *) die "Topology discovery returned unexpected output instead of v\$database data: ${db_line:-<empty>}" ;;
  esac
  IFS='|' read -r DB_NAME DB_UNIQUE_NAME DB_ROLE DB_OPEN_MODE DB_CDB DB_PROTECTION_MODE DB_SWITCHOVER_STATUS <<<"$db_line"

  sql_query "$instance_file" "
select instance_name || '|' ||
       host_name || '|' ||
       status || '|' ||
       parallel || '|' ||
       thread#
from v\$instance;
"
  local instance_line
  instance_line="$(trim_blank_lines <"$instance_file" | head -n 1)"
  IFS='|' read -r INSTANCE_NAME HOST_NAME INSTANCE_STATUS INSTANCE_PARALLEL INSTANCE_THREAD <<<"$instance_line"

  sql_query "$params_file" "
select name || '=' || nvl(value, '')
from v\$parameter
where name in ('spfile','db_recovery_file_dest','oracle_base')
order by name;
"
  while IFS='=' read -r param_name param_value; do
    case "$param_name" in
      db_recovery_file_dest) FRA_PATH="$param_value" ;;
      oracle_base) ORACLE_BASE_DETECTED="$param_value" ;;
      spfile) SPFILE_PATH="$param_value" ;;
    esac
  done < <(trim_blank_lines <"$params_file")

  if grid_tool_available srvctl; then
    local srvctl_config srvctl_type srvctl_rc=0
    # srvctl prints failures to STDOUT (e.g. "Start Oracle Clusterware stack
    # and try again." on hosts with no Oracle Restart at all), so non-empty
    # output alone is NOT config data - the exit status must be checked too.
    srvctl_config="$(run_grid_tool srvctl config database -d "$DB_UNIQUE_NAME" 2>/dev/null)" || srvctl_rc=$?
    if [[ "$srvctl_rc" -ne 0 ]]; then
      srvctl_config=""
    fi
    if [[ -n "$srvctl_config" ]]; then
      GI_MANAGED=1
      PASSWORD_FILE_PATH="$(printf "%s\n" "$srvctl_config" |
        awk -F': ' '/^Password file:/ {print $2; exit}')"
      srvctl_type="$(printf "%s\n" "$srvctl_config" |
        awk -F': ' '/^Type:/ {print $2; exit}' |
        tr '[:lower:]' '[:upper:]' |
        tr -cd '[:alnum:]_')"
    else
      srvctl_type=""
    fi

    case "$srvctl_type" in
      RAC|RACONE|RACONENODE|RAC_ONE_NODE)
        CLUSTER_TYPE="$srvctl_type"
        ;;
      SINGLE)
        if grid_tool_available crsctl; then
          CLUSTER_TYPE="GI_SINGLE"
        else
          CLUSTER_TYPE="SINGLE"
        fi
        ;;
      "")
        if [[ "$INSTANCE_PARALLEL" == "YES" ]]; then
          CLUSTER_TYPE="RAC"
        elif [[ "$GI_MANAGED" -eq 1 ]] || topology_grid_stack_present; then
          CLUSTER_TYPE="GI_SINGLE"
        else
          CLUSTER_TYPE="SINGLE"
        fi
        ;;
      *)
        CLUSTER_TYPE="$srvctl_type"
        ;;
    esac
  elif [[ "$INSTANCE_PARALLEL" == "YES" ]]; then
    CLUSTER_TYPE="RAC"
  elif grid_tool_available crsctl; then
    CLUSTER_TYPE="GI_SINGLE"
  else
    CLUSTER_TYPE="SINGLE"
  fi

  detect_password_file

  if [[ "$DB_CDB" == "YES" ]]; then
    sql_query "$pdb_file" "
select name || '|' || con_id || '|' || open_mode
from v\$pdbs
where name <> 'PDB\$SEED'
order by con_id;
"
    mapfile -t PDB_ROWS < <(trim_blank_lines <"$pdb_file")
  fi

  detect_storage_type
  DISCOVERED=1
}

detect_storage_type() {
  local file="$WORK_DIR/storage.env"
  local srvctl_storage_file="$WORK_DIR/storage_srvctl.env"
  local crs_storage_file="$WORK_DIR/storage_crs.env"
  local has_asm=0 has_fex=0 has_acfs=0 has_fs=0 line class
  sql_query "$file" "
select name from v\$datafile where rownum <= 50
union all
select name from v\$tempfile where rownum <= 50
union all
select name from v\$controlfile where rownum <= 10
union all
select value
from v\$parameter
where name in ('spfile','db_recovery_file_dest')
  and value is not null
"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    line="$(trim_value "$line")"
    class="$(storage_path_class "$line")"
    case "$class" in
      asm) has_asm=1 ;;
      fex) has_fex=1 ;;
      acfs) has_acfs=1 ;;
      filesystem) has_fs=1 ;;
    esac
  done < <(trim_blank_lines <"$file")

  if [[ -n "$DB_UNIQUE_NAME" ]] && grid_tool_available srvctl; then
    if run_grid_tool srvctl config database -d "$DB_UNIQUE_NAME" >"$srvctl_storage_file" 2>/dev/null; then
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
          "Mount point paths:"*|"Spfile:"*|"Password file:"*)
            line="${line#*:}"
            ;;
          *)
            continue
            ;;
        esac
        line="$(trim_value "$line")"
        [[ -n "$line" ]] || continue
        IFS=',' read -r -a storage_values <<<"$line"
        local storage_value
        for storage_value in "${storage_values[@]}"; do
          storage_value="$(trim_value "$storage_value")"
          [[ -n "$storage_value" ]] || continue
          class="$(storage_path_class "$storage_value")"
          case "$class" in
            asm) has_asm=1 ;;
            fex) has_fex=1 ;;
            acfs) has_acfs=1 ;;
            filesystem) has_fs=1 ;;
          esac
        done
      done <"$srvctl_storage_file"
    fi
  fi

  if grid_tool_available crsctl; then
    if run_grid_tool crsctl stat res -p >"$crs_storage_file" 2>/dev/null; then
      while IFS= read -r line; do
        [[ "$line" == MOUNTPOINT_PATH=* || "$line" == INTERNAL_MOUNTPOINT_PATH=* || "$line" == VOLUME_DEVICE=* ]] || continue
        line="${line#*=}"
        line="$(trim_value "$line")"
        [[ -n "$line" ]] || continue
        class="$(storage_path_class "$line")"
        case "$class" in
          asm) has_asm=1 ;;
          fex) has_fex=1 ;;
          acfs) has_acfs=1 ;;
          filesystem) has_fs=1 ;;
        esac
      done <"$crs_storage_file"
    fi
  fi

  for line in "$SPFILE_PATH" "$FRA_PATH" "$PASSWORD_FILE_PATH"; do
    [[ -n "$line" ]] || continue
    line="$(trim_value "$line")"
    class="$(storage_path_class "$line")"
    case "$class" in
      asm) has_asm=1 ;;
      fex) has_fex=1 ;;
      acfs) has_acfs=1 ;;
      filesystem) has_fs=1 ;;
    esac
  done

  if [[ "$has_asm" -eq 1 && ( "$has_fex" -eq 1 || "$has_acfs" -eq 1 || "$has_fs" -eq 1 ) ]]; then
    STORAGE_TYPE="MIXED"
  elif [[ "$has_asm" -eq 1 ]]; then
    STORAGE_TYPE="ASM"
  elif [[ "$has_fex" -eq 1 && "$has_acfs" -eq 1 ]]; then
    STORAGE_TYPE="FEX_ACFS"
  elif [[ "$has_fex" -eq 1 ]]; then
    STORAGE_TYPE="FEX"
  elif [[ "$has_acfs" -eq 1 ]]; then
    STORAGE_TYPE="ACFS"
  elif [[ "$has_fs" -eq 1 ]]; then
    STORAGE_TYPE="FILESYSTEM"
  else
    STORAGE_TYPE="UNKNOWN"
  fi
}

storage_path_class() {
  local path="$1"
  local first_char
  path="$(printf "%s" "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  first_char="${path:0:1}"
  case "$first_char" in
    +) printf "asm" ;;
    @) printf "fex" ;;
    /)
      if [[ "$path" == *"/dbaas_acfs/"* ||
            "$path" == *"/acfs/"* ||
            "$path" == /acfs/* ||
            "$path" == /acfs ||
            "$path" == /var/opt/oracle/dbaas_acfs ||
            "$path" == /var/opt/oracle/dbaas_acfs/* ]]; then
        printf "acfs"
      else
        printf "filesystem"
      fi
      ;;
    *) printf "unknown" ;;
  esac
}

storage_path_is_local_filesystem() {
  local class
  class="$(storage_path_class "$1")"
  [[ "$class" == "filesystem" || "$class" == "acfs" ]]
}

storage_path_is_provider_managed() {
  local class
  class="$(storage_path_class "$1")"
  [[ "$class" == "asm" || "$class" == "fex" ]]
}

storage_path_provider_reason() {
  local path="$1"
  local operation="${2:-crash injection}"
  case "$(storage_path_class "$path")" in
    asm)
      printf "ASM path requires ASM-aware %s; filesystem rename/dd is not valid" "$operation"
      ;;
    fex)
      printf "FEX/ACFS managed storage handle requires provider-aware %s; this @... handle is not a local filesystem path" "$operation"
      ;;
    acfs)
      printf "ACFS-backed local path can use filesystem actions when visible and writable to the current OS user"
      ;;
    filesystem)
      printf "filesystem path"
      ;;
    *)
      printf "unknown storage path format requires manual validation before %s" "$operation"
      ;;
  esac
}

storage_supports_gi_storage_planning() {
  case "$STORAGE_TYPE" in
    ASM|FEX|FEX_ACFS|ACFS|MIXED) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

detect_password_file() {
  if [[ -n "$PASSWORD_FILE_PATH" ]]; then
    return "$SUCCESS"
  fi
  if [[ -z "${ORACLE_HOME:-}" ]]; then
    return "$SUCCESS"
  fi

  local candidate
  local db_lower
  local db_unique_lower
  db_lower="$(printf "%s" "$DB_NAME" | tr '[:upper:]' '[:lower:]')"
  db_unique_lower="$(printf "%s" "$DB_UNIQUE_NAME" | tr '[:upper:]' '[:lower:]')"

  for candidate in \
    "${ORACLE_HOME}/dbs/orapw${ORACLE_SID:-}" \
    "${ORACLE_HOME}/dbs/orapw${INSTANCE_NAME:-}" \
    "${ORACLE_HOME}/dbs/orapw${db_lower}" \
    "${ORACLE_HOME}/dbs/orapw${DB_NAME}" \
    "${ORACLE_HOME}/dbs/orapw${db_unique_lower}" \
    "${ORACLE_HOME}/dbs/orapw${DB_UNIQUE_NAME}"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      PASSWORD_FILE_PATH="$candidate"
      return "$SUCCESS"
    fi
  done
}

write_discovery_text() {
  local output_file="$1"
  local row name con_id open_mode

  {
    cat <<DISCOVERY
CrashSimulator V2 discovery
  Version:           ${VERSION}
  Generated UTC:     $(date -u +%Y-%m-%dT%H:%M:%SZ)
  Host:              ${HOST_NAME}
  OS user:           $(id -un)
  Oracle home:       ${ORACLE_HOME:-unknown}
  SQL*Plus:          ${SQLPLUS_BIN}
  Database name:     ${DB_NAME}
  DB unique name:    ${DB_UNIQUE_NAME}
  Version family:    12c or later required by v2
  CDB:               ${DB_CDB}
  Open mode:         ${DB_OPEN_MODE}
  Database role:     ${DB_ROLE}
  Protection mode:   ${DB_PROTECTION_MODE}
  Switchover status: ${DB_SWITCHOVER_STATUS}
  Instance:          ${INSTANCE_NAME}
  Thread:            ${INSTANCE_THREAD}
  RAC parallel:      ${INSTANCE_PARALLEL}
  Cluster type:      ${CLUSTER_TYPE}
  GI managed:        ${GI_MANAGED}
  Storage type:      ${STORAGE_TYPE}
  SPFILE:            ${SPFILE_PATH:-not detected}
  Password file:     ${PASSWORD_FILE_PATH:-not detected}
  FRA:               ${FRA_PATH:-not configured}
DISCOVERY

    if [[ "$DB_CDB" == "YES" ]]; then
      printf "  PDBs:\n"
      if [[ "${#PDB_ROWS[@]}" -eq 0 ]]; then
        printf "    none found\n"
      else
        for row in "${PDB_ROWS[@]}"; do
          IFS='|' read -r name con_id open_mode <<<"$row"
          printf "    %s (CON_ID=%s, OPEN_MODE=%s)\n" "$name" "$con_id" "$open_mode"
        done
      fi
    fi
  } >"$output_file" || die "Unable to write discovery text: $output_file"
}

print_discovery() {
  local topology_file latest_file
  discover_environment

  topology_file="${LOG_DIR}/crashsim_topology_${RUN_ID}.txt"
  latest_file="${LOG_DIR}/crashsim_topology_latest.txt"
  write_discovery_text "$topology_file"
  cp -p -- "$topology_file" "$latest_file" 2>/dev/null || true
  cat "$topology_file"
  echo
  echo "Topology snapshot: ${topology_file}"
  echo "Latest topology snapshot: ${latest_file}"
  maybe_render_html "$topology_file"
}

file_mtime_epoch() {
  local file="$1"
  stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || return "$FAIL"
}

topology_cache_value() {
  local file="$1" label="$2"
  awk -F: -v label="$label" '
    index($1, label) {
      value=$0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      print value
      exit
    }
  ' "$file"
}

load_topology_cache() {
  local cache_file="${LOG_DIR}/crashsim_topology_latest.txt"
  local now mtime age row name con_id open_mode

  [[ "$TOPOLOGY_CACHE_DISABLED" -eq 0 ]] || return "$FAIL"
  [[ "$TOPOLOGY_CACHE_REFRESH" -eq 0 ]] || return "$FAIL"
  [[ "$TOPOLOGY_CACHE_TTL_SECONDS" -gt 0 ]] || return "$FAIL"
  [[ -f "$cache_file" ]] || return "$FAIL"

  now="$(date +%s)"
  mtime="$(file_mtime_epoch "$cache_file")" || return "$FAIL"
  age=$((now - mtime))
  [[ "$age" -le "$TOPOLOGY_CACHE_TTL_SECONDS" ]] || return "$FAIL"

  HOST_NAME="$(topology_cache_value "$cache_file" "Host")"
  DB_NAME="$(topology_cache_value "$cache_file" "Database name")"
  DB_UNIQUE_NAME="$(topology_cache_value "$cache_file" "DB unique name")"
  DB_CDB="$(topology_cache_value "$cache_file" "CDB")"
  DB_OPEN_MODE="$(topology_cache_value "$cache_file" "Open mode")"
  DB_ROLE="$(topology_cache_value "$cache_file" "Database role")"
  DB_PROTECTION_MODE="$(topology_cache_value "$cache_file" "Protection mode")"
  DB_SWITCHOVER_STATUS="$(topology_cache_value "$cache_file" "Switchover status")"
  INSTANCE_NAME="$(topology_cache_value "$cache_file" "Instance")"
  INSTANCE_THREAD="$(topology_cache_value "$cache_file" "Thread")"
  INSTANCE_PARALLEL="$(topology_cache_value "$cache_file" "RAC parallel")"
  CLUSTER_TYPE="$(topology_cache_value "$cache_file" "Cluster type")"
  GI_MANAGED="$(topology_cache_value "$cache_file" "GI managed")"
  STORAGE_TYPE="$(topology_cache_value "$cache_file" "Storage type")"
  SPFILE_PATH="$(topology_cache_value "$cache_file" "SPFILE")"
  PASSWORD_FILE_PATH="$(topology_cache_value "$cache_file" "Password file")"
  FRA_PATH="$(topology_cache_value "$cache_file" "FRA")"

  PDB_ROWS=()
  while IFS= read -r row; do
    if [[ "$row" =~ ^[[:space:]]+([^[:space:]]+)[[:space:]]+\(CON_ID=([^,]+),[[:space:]]*OPEN_MODE=(.*)\)$ ]]; then
      name="${BASH_REMATCH[1]}"
      con_id="${BASH_REMATCH[2]}"
      open_mode="${BASH_REMATCH[3]}"
      PDB_ROWS+=("${name}|${con_id}|${open_mode}")
    fi
  done <"$cache_file"

  echo "Using cached topology snapshot (${age}s old): ${cache_file}"
  return "$SUCCESS"
}

doctor_tool_path() {
  local tool="$1"
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/${tool}" ]]; then
    printf "%s" "${ORACLE_HOME}/bin/${tool}"
    return "$SUCCESS"
  fi
  if [[ -n "${CRASHSIM_GRID_HOME:-}" && -x "${CRASHSIM_GRID_HOME}/bin/${tool}" ]]; then
    printf "%s" "${CRASHSIM_GRID_HOME}/bin/${tool}"
    return "$SUCCESS"
  fi
  command -v "$tool" 2>/dev/null || true
}

DOCTOR_REPORT_FILE=""
DOCTOR_ERRORS=0
DOCTOR_WARNINGS=0

doctor_add_check() {
  local status="$1" area="$2" check="$3" evidence="$4" action="$5"
  case "$status" in
    GAP|ERROR) DOCTOR_ERRORS=$((DOCTOR_ERRORS + 1)) ;;
    WARN) DOCTOR_WARNINGS=$((DOCTOR_WARNINGS + 1)) ;;
  esac
  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$status" \
    "$(md_escape "$area")" \
    "$(md_escape "$check")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$action")" >>"$DOCTOR_REPORT_FILE"
}

doctor_check_command() {
  local tool="$1" area="$2" required="$3" reason="$4"
  local path
  path="$(doctor_tool_path "$tool")"
  if [[ -n "$path" ]]; then
    doctor_add_check "OK" "$area" "${tool} available" "$path" "No action needed."
  elif [[ "$required" == "required" ]]; then
    doctor_add_check "GAP" "$area" "${tool} available" "not found" "$reason"
  else
    doctor_add_check "WARN" "$area" "${tool} available" "not found" "$reason"
  fi
}

run_doctor() {
  local report_file latest_file bash_major bash_status log_probe node_path script_root
  local config_status destructive_status cache_status

  report_file="${LOG_DIR}/crashsim_doctor_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_doctor_latest.md"
  DOCTOR_REPORT_FILE="$report_file"
  DOCTOR_ERRORS=0
  DOCTOR_WARNINGS=0
  script_root="$(script_dir)"

  {
    printf "# CrashSimulator Doctor / Public Readiness Preflight\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un)"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf '%s\n\n' 'This preflight is read-only. It checks local tooling, configuration hygiene, public-release safety posture, and optional HA/DR helpers. Use `--health-check`, `--scenario-readiness-report`, and `--prepare-environment --dry-run` for database-specific evidence.'
    printf "## Evidence Policy\n\n"
    printf "| Evidence state | Meaning |\n"
    printf "| --- | --- |\n"
    printf "| Confirmed | Direct dated evidence from this environment exists. |\n"
    printf "| Observed | Tool output or configuration was observed, but not tested end to end. |\n"
    printf "| Candidate | Component appears installed/configured; service-level claims still need drills. |\n"
    printf "| Inferred | Conclusion follows from topology pattern; verify before relying on it. |\n"
    printf "| Gap | Evidence is absent, stale, or contradictory. |\n"
    printf "\n## Checks\n\n"
    printf "| Status | Area | Check | Evidence | Recommended action |\n"
    printf "| --- | --- | --- | --- | --- |\n"
  } >"$report_file" || die "Unable to write doctor report: $report_file"

  bash_major="${BASH_VERSINFO[0]:-0}"
  if [[ "$bash_major" -ge 4 ]]; then
    doctor_add_check "OK" "Runtime" "Bash version" "${BASH_VERSION}" "No action needed."
  else
    doctor_add_check "GAP" "Runtime" "Bash version" "${BASH_VERSION:-unknown}" "Run with Bash 4 or later."
  fi

  if [[ -w "$LOG_DIR" ]]; then
    log_probe="${LOG_DIR}/.crashsim_doctor_write_test_${RUN_ID}"
    if : >"$log_probe" 2>/dev/null; then
      rm -f "$log_probe" 2>/dev/null || true
      doctor_add_check "OK" "Logging" "Log directory writable" "$LOG_DIR" "No action needed."
    else
      doctor_add_check "GAP" "Logging" "Log directory writable" "$LOG_DIR" "Fix permissions or choose --log-dir."
    fi
  else
    doctor_add_check "GAP" "Logging" "Log directory writable" "$LOG_DIR" "Fix permissions or choose --log-dir."
  fi

  if [[ -n "$CONFIG_SOURCE" ]]; then
    config_status="loaded: ${CONFIG_SOURCE}"
  else
    config_status="not loaded"
  fi
  doctor_add_check "INFO" "Configuration" "Startup config" "$config_status" "Run --write-config-template to create a reusable non-secret config."

  if [[ "${DESTRUCTIVE_LAB_ACK^^}" == "YES" ]]; then
    destructive_status="set for this run"
    doctor_add_check "WARN" "Safety" "Destructive lab acknowledgement" "$destructive_status" "Keep this enabled only in approved non-production labs."
  else
    destructive_status="not set"
    doctor_add_check "OK" "Safety" "Destructive lab acknowledgement" "$destructive_status" "Destructive --execute --yes actions remain blocked until explicitly acknowledged."
  fi

  if [[ "$TOPOLOGY_CACHE_DISABLED" -eq 1 ]]; then
    cache_status="disabled"
  else
    cache_status="ttl=${TOPOLOGY_CACHE_TTL_SECONDS}s"
  fi
  doctor_add_check "INFO" "Efficiency" "Topology cache" "$cache_status" "Use --refresh-topology when you need live topology discovery."

  [[ -n "${ORACLE_HOME:-}" && -d "${ORACLE_HOME:-}" ]] &&
    doctor_add_check "OK" "Oracle environment" "ORACLE_HOME" "$ORACLE_HOME" "No action needed." ||
    doctor_add_check "WARN" "Oracle environment" "ORACLE_HOME" "${ORACLE_HOME:-not set}" "Set ORACLE_HOME or use SQLPLUS/RMAN overrides before database-host scenarios."
  [[ -n "${ORACLE_SID:-}" ]] &&
    doctor_add_check "OK" "Oracle environment" "ORACLE_SID" "$ORACLE_SID" "No action needed." ||
    doctor_add_check "WARN" "Oracle environment" "ORACLE_SID" "not set" "Set ORACLE_SID for bequeath SYSDBA workflows."

  doctor_check_command "sqlplus" "Oracle client" "required" "Install Oracle client/database software or set SQLPLUS."
  doctor_check_command "rman" "Oracle client" "required" "Install Oracle client/database software or set RMAN."
  doctor_check_command "lsnrctl" "Oracle network" "optional" "Install Oracle networking tools for listener checks."
  doctor_check_command "srvctl" "RAC/GI" "optional" "Required only for RAC/GI service and instance drills."
  doctor_check_command "crsctl" "RAC/GI" "optional" "Required only for Grid Infrastructure readiness checks."
  doctor_check_command "asmcmd" "ASM/GI" "optional" "Required only for ASM/FEX/ACFS storage evidence."
  doctor_check_command "dgmgrl" "Data Guard" "optional" "Required only for Broker/FSFO checks."
  doctor_check_command "ords" "APEX/ORDS" "optional" "Required only for ORDS/APEX service-path scenarios."
  doctor_check_command "oci" "OCI/ADB" "optional" "Required only for OCI control-plane and ADB readiness checks."
  doctor_check_command "java" "APEX/ORDS" "optional" "Required for ORDS installation/runtime validation."
  doctor_check_command "curl" "HTTP smoke" "optional" "Useful for ORDS/APEX/ADB smoke URLs."
  doctor_check_command "node" "APEX session driver" "optional" "Required only for the optional Playwright APEX session driver."
  doctor_check_command "git" "Release" "optional" "Useful for release checks and source synchronization."
  doctor_check_command "zip" "Release" "optional" "Useful for runtime package creation."
  doctor_check_command "unzip" "Release" "optional" "Useful for runtime package validation."

  node_path="$(doctor_tool_path node)"
  if [[ -n "$node_path" && -f "${script_root}/tools/crashsim_apex_session_driver.cjs" ]]; then
    if "$node_path" -e "require('playwright')" >/dev/null 2>&1; then
      doctor_add_check "OK" "APEX session driver" "Playwright Node module" "available" "No action needed."
    else
      doctor_add_check "WARN" "APEX session driver" "Playwright Node module" "not found in current Node path" "Install Playwright only if scenario 80 browser-session evidence is required."
    fi
  fi

  if [[ -n "${CRASHSIM_REMOTE_NODES:-}" ]]; then
    doctor_add_check "INFO" "Multi-node" "Remote node sync list" "${CRASHSIM_REMOTE_NODES}" "Run tools/crashsim_node_sync_check.sh before RAC/ORDS multi-node drills."
  else
    doctor_add_check "INFO" "Multi-node" "Remote node sync list" "not set" "Set CRASHSIM_REMOTE_NODES for RAC/ORDS multi-node version/config sync checks."
  fi

  {
    printf "\n## Summary\n\n"
    printf -- '- Errors/Gaps: `%s`\n' "$DOCTOR_ERRORS"
    printf -- '- Warnings: `%s`\n' "$DOCTOR_WARNINGS"
    printf -- '- Latest report: `%s`\n' "$latest_file"
    printf "\n## Suggested First Public-Readiness Sequence\n\n"
    printf '```bash\n'
    printf "./%s --doctor --html\n" "$PROGRAM"
    printf "./%s --secret-scan --scan-path .\n" "$PROGRAM"
    printf "./%s --scenario-lifecycle-check --html\n" "$PROGRAM"
    printf "./%s --prepare-environment --dry-run --html\n" "$PROGRAM"
    printf "./%s --scenario-readiness-report --html\n" "$PROGRAM"
    printf "./%s --release-check\n" "$PROGRAM"
    printf '```\n'
  } >>"$report_file"

  cp "$report_file" "$latest_file" 2>/dev/null || true
  echo "Doctor report generated: ${report_file}"
  echo "Latest doctor report: ${latest_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
  [[ "$DOCTOR_ERRORS" -eq 0 ]]
}

run_first_run_guide() {
  local report_file latest_file
  report_file="${LOG_DIR}/crashsim_first_run_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_first_run_latest.md"
  {
    printf "# CrashSimulator First-Run Guide\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf "\nThis guide is intentionally read-only. It gives new users a safe order of operations before they try destructive drills.\n\n"
    printf "## Recommended Flow\n\n"
    printf '1. Configure the Oracle environment or create `crashsimulator.conf`, then run `./%s --show-config` and `./%s --validate-config`.\n' "$PROGRAM" "$PROGRAM"
    printf '2. Run `./%s --public-limitations --html` so the team understands plan-only, provider-specific, ADB, licensing-sensitive, and destructive-drill expectations.\n' "$PROGRAM"
    printf '3. Run `./%s --doctor --html` to check local tooling, config, and public-safety posture.\n' "$PROGRAM"
    printf '4. Run `./%s --discover` or open the Guided Workflow menu to collect topology evidence.\n' "$PROGRAM"
    printf '5. Run `./%s --prepare-environment --dry-run --html` to detect missing lab seeds for this topology without changing the database.\n' "$PROGRAM"
    printf '6. Run `./%s --scenario-readiness-report --html` to see which scenarios are runnable, plan-only, or blocked.\n' "$PROGRAM"
    printf '7. Run `./%s --scenario-lifecycle-report --html` to review validation/protection/execution/recovery/runbook/evidence coverage.\n' "$PROGRAM"
    printf "8. Start with read-only reports, then low-risk logical/tempfile drills, then destructive drills only after backup, runbook, and recovery validation review.\n"
    printf '%s\n' '9. Before any non-interactive destructive execution, set `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` only in an approved non-production lab.'
    printf "\n## Safe Starter Commands\n\n"
    printf '```bash\n'
    printf "./%s --show-config\n" "$PROGRAM"
    printf "./%s --validate-config\n" "$PROGRAM"
    printf "./%s --public-limitations --html\n" "$PROGRAM"
    printf "./%s --doctor --html\n" "$PROGRAM"
    printf "./%s --discover\n" "$PROGRAM"
    printf "./%s --prepare-environment --dry-run --html\n" "$PROGRAM"
    printf "./%s --scenario-lifecycle-check --html\n" "$PROGRAM"
    printf "./%s --scenario-readiness-report --html\n" "$PROGRAM"
    printf "./%s --backup-report\n" "$PROGRAM"
    printf "./%s --maa-report --html\n" "$PROGRAM"
    printf "./%s --resilience-scorecard --html\n" "$PROGRAM"
    printf '```\n'
    printf "\n## Evidence Interpretation\n\n"
    printf "Treat installed or configured components as candidates until a drill has measured them. Do not claim near-zero downtime without client/service/FAN/AC/TAC evidence, and do not claim zero data loss without synchronous protection and tested transition evidence.\n"
    printf "\n## Safe Starter Scenario Ideas\n\n"
    printf -- '- Read-only first: health check, configuration report, backup/recoverability report, MAA report, service review, resilience scorecard, APEX/ORDS readiness, and ADB readiness where applicable.\n'
    printf -- '- Low-risk drills after readiness passes: scenarios `6` and `31` for tempfile loss, `11` and `36` for disposable index rebuild practice, `43` for disposable table loss, and `63` for controlled TEMP pressure.\n'
    printf -- '- Defer plan-only/provider-specific drills such as ASM/GI/OCR/voting, OCI control-plane, Exadata, GoldenGate, switchover/failback, PDB PITR, GRP rollback, and AC/TAC replay until the external runbook and approvals are complete.\n'
  } >"$report_file" || die "Unable to write first-run guide: $report_file"
  cp "$report_file" "$latest_file" 2>/dev/null || true
  echo "First-run guide generated: ${report_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
}

run_public_limitations_page() {
  local report_file latest_file docs_file
  report_file="${LOG_DIR}/crashsim_public_limitations_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_public_limitations_latest.md"
  docs_file="$(script_dir)/docs/CRASHSIMULATOR_PUBLIC_LIMITATIONS.md"

  {
    printf "# CrashSimulator Public Beta Limitations And Expectations\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf "\nCrashSimulator is an open-source resilience validation platform for Oracle Database labs. It helps teams practice, validate, and document recoverability, but it is not a production chaos tool, an Oracle certification program, a licensing verifier, or a substitute for tested backups and change control.\n"

    printf "\n## Safety Expectations\n\n"
    printf -- '- Dry-run is the default. Destructive activity requires `--execute`, typed confirmation, and for non-interactive runs `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` or `--accept-destructive-lab`.\n'
    printf -- '- Use destructive scenarios only in approved non-production or dedicated resilience-test environments.\n'
    printf -- '- Run `--doctor`, `--discover`, `--prepare-environment --dry-run`, `--scenario-readiness-report`, `--runbook <id>`, and a backup/recoverability review before destructive drills.\n'
    printf -- '- Keep manifests, runbooks, health checks, RMAN/SQL evidence, audit logs, and HTML reports until recovery validation is complete.\n'

    printf "\n## Plan-Only And Provider-Specific Scenarios\n\n"
    printf "Some scenarios intentionally produce runbook/evidence instead of directly changing infrastructure. This is by design when the safe action depends on storage provider, Grid/root privileges, OCI control-plane boundaries, load balancers, GoldenGate deployment names, application client behavior, or a formal change window.\n\n"
    printf "| Scenario family | Examples | Public expectation |\n"
    printf "| --- | --- | --- |\n"
    printf '%s\n' '| ASM/GI/FEX/ACFS storage | `46`, `47`, `48`, `49`, `72` | Plan-only or provider-aware until redundant lab disks, failgroups, OCR/voting recovery, and rollback are explicitly approved. |'
    printf '%s\n' '| Data Guard role transition | `52`, `54`, `66`, `85`, `86` | Broker/FSFO/switchover/failback evidence and runbooks first; role transitions remain operator-approved. |'
    printf '%s\n' '| RAC network/service infrastructure | `70`, selected `83`, `84`, `87` | Validate services/FAN/AC/TAC metadata; client replay and VIP/notification disruption need application evidence and approval. |'
    printf '%s\n' '| PDB PITR and lifecycle rollback | `88`, `89`, `90` | Generate evidence and templates; actual PDB PITR, GRP flashback, patch rollback, and resetlogs remain change-window actions. |'
    printf '%s\n' '| Exadata | `EXA01`-`EXA04` | Requires Exadata tooling, cell/storage evidence, and supportable lab procedures; generic hosts remain readiness-only. |'
    printf '%s\n' '| OCI Base Database | `OCI01`-`OCI05` | Requires OCI CLI/profile/OCIDs and approved cloud-control-plane scope; network/security-list changes are not guessed. |'
    printf '%s\n' '| GoldenGate | `GG01`-`GG04` | Requires deployment-specific Extract/Replicat/trail targets, lag thresholds, and resync runbooks. |'

    printf "\n## Autonomous Database Differences\n\n"
    printf "Autonomous Database does not expose host-level files, ASM disks, control files, redo members, password files, SPFILEs, or ORACLE_HOME for destructive manipulation. ADB scenarios use a separate coverage model focused on logical/user-error recovery, PITR/clone readiness, wallet/connectivity, private endpoints, IAM, Object Storage, Autonomous Data Guard, resource pressure, Database Actions, APEX, and application access-path checks. OCI metadata checks require a configured OCI CLI/profile and the relevant OCIDs.\n"

    printf "\n## Licensing And Support Sensitivity\n\n"
    printf "CrashSimulator can detect and report signals for features such as RAC, Active Data Guard, Application Continuity/TAC, Diagnostics/Tuning-related evidence, TDE, Exadata, GoldenGate, and OCI services, but it does not validate license entitlement or support contracts. Confirm licensing and supportability with Oracle documentation, contracts, and authorized advisors before relying on a feature in production.\n"

    printf "\n## Evidence And MAA Claims\n\n"
    printf -- '- Treat installed/configured components as candidate capabilities until measured drills prove the service level.\n'
    printf -- '- Do not claim zero data loss without protection mode, synchronous transport/commit behavior, standby receive/apply state, and tested transition evidence.\n'
    printf -- '- Do not claim near-zero downtime without service placement, FAN/ONS, AC/TAC or client retry evidence, draining/replay behavior, and measured outage timing.\n'
    printf -- '- Use `--resilience-scorecard`, MAA reports, and scenario lifecycle/readiness reports as evidence summaries, not as formal certification.\n'

    printf "\n## Recommended New-User Order\n\n"
    printf '```bash\n'
    printf "./%s --show-config\n" "$PROGRAM"
    printf "./%s --validate-config\n" "$PROGRAM"
    printf "./%s --doctor --html\n" "$PROGRAM"
    printf "./%s --discover\n" "$PROGRAM"
    printf "./%s --prepare-environment --dry-run --html\n" "$PROGRAM"
    printf "./%s --scenario-readiness-report --html\n" "$PROGRAM"
    printf "./%s --scenario-lifecycle-report --html\n" "$PROGRAM"
    printf "./%s --backup-report --html\n" "$PROGRAM"
    printf "./%s --runbook 6 --html\n" "$PROGRAM"
    printf "./%s --scenario 6 --dry-run\n" "$PROGRAM"
    printf '```\n'

    printf "\n## Safe Starter Scenario Ideas\n\n"
    printf -- '- Read-only/reporting: `--health-check`, `--config-report`, `--backup-report`, `--service-review`, `--maa-report`, `--resilience-scorecard`, `--apex-ords-report`, `--adb-readiness-report`.\n'
    printf -- '- Low-risk database drills after readiness passes: `6`/`31` tempfile loss, `11`/`36` disposable index rebuild, `43` disposable table loss, `63` controlled TEMP pressure.\n'
    printf -- '- RAC/Data Guard/application drills should start with readiness/reporting scenarios before service relocation, apply/transport lag, switchover/failback, or client replay tests.\n'
  } >"$report_file" || die "Unable to write public limitations page: $report_file"

  cp "$report_file" "$latest_file" 2>/dev/null || true
  if [[ -d "$(dirname "$docs_file")" ]]; then
    cp "$report_file" "$docs_file" 2>/dev/null || true
  fi
  echo "Public limitations page generated: ${report_file}"
  echo "Latest public limitations page: ${latest_file}"
  [[ -f "$docs_file" ]] && echo "Documentation copy: ${docs_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
}

