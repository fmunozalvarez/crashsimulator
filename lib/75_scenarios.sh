perform_ords_pool_bad_service() {
  local original_service bad_service state

  [[ -d "$ORDS_CONFIG_DIR" ]] || die "ORDS config directory not found: $ORDS_CONFIG_DIR"
  can_control_ords_service || die "ORDS pool drill requires approved ORDS service restart privileges."
  command -v curl >/dev/null 2>&1 || die "curl was not found; cannot validate ORDS pool outage evidence."

  original_service="$(ords_config_get_value db.servicename)"
  [[ -n "$original_service" ]] || die "Could not read ORDS db.servicename from ${ORDS_CONFIG_DIR}."
  bad_service="CRASHSIM_BAD_SERVICE_${RUN_ID}"

  manifest_append "ords_config_dir" "$ORDS_CONFIG_DIR"
  manifest_append "ords_db_pool" "$ORDS_DB_POOL"
  manifest_append "ords_pool_original_servicename" "$original_service"
  manifest_append "ords_pool_bad_servicename" "$bad_service"
  manifest_append "ords_service_name" "$ORDS_SERVICE_NAME"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would set ORDS db.servicename from ${original_service} to ${bad_service}"
    echo "DRY-RUN: would restart ORDS service ${ORDS_SERVICE_NAME}"
    echo "DRY-RUN: would validate ${ORDS_URL} is affected, then recover with --recover 75"
    return "$SUCCESS"
  fi

  ords_config_set_value db.servicename "$bad_service" ||
    die "Unable to set ORDS db.servicename to lab-bad value."
  perform_systemctl_service_action restart "$ORDS_SERVICE_NAME"

  if curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1; then
    state="reachable"
    warn "ORDS smoke URL remained reachable after pool misconfiguration; review whether the URL exercises the changed pool."
  else
    state="outage-confirmed"
  fi
  manifest_append "ords_pool_fault_state" "$state"
  echo "ORDS pool misconfiguration state: ${state}"
}

perform_ords_priv_config_rename() {
  local path="$1"
  local backup="${path}.${RUN_ID}.crashsim.bak"

  [[ "$path" == "$ORDS_CONFIG_DIR" ]] ||
    die "Approved ORDS config rename only supports the configured ORDS config directory: ${ORDS_CONFIG_DIR}"
  ords_priv_helper_config_available ||
    die "Approved ORDS config helper is not available for ${path}."

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run approved helper config-rename $path $backup"
    return "$SUCCESS"
  fi

  run_ords_priv_helper config-rename "$path" "$backup" ||
    die "Unable to rename ORDS config with approved helper: $path"
  RENAME_COUNT=$((RENAME_COUNT + 1))
  manifest_append "rename_${RENAME_COUNT}_original" "$path"
  manifest_append "rename_${RENAME_COUNT}_backup" "$backup"
  manifest_append "rename_${RENAME_COUNT}_method" "ords_priv_config_rename"
}

perform_fs_rename() {
  local path="$1"
  if storage_path_is_provider_managed "$path"; then
    die "$(storage_path_provider_reason "$path" "crash injection")."
  fi
  [[ -e "$path" ]] || die "Target does not exist: $path"
  local backup="${path}.${RUN_ID}.crashsim.bak"
  echo "mv -- $path $backup"
  mv -- "$path" "$backup"
  RENAME_COUNT=$((RENAME_COUNT + 1))
  manifest_append "rename_${RENAME_COUNT}_original" "$path"
  manifest_append "rename_${RENAME_COUNT}_backup" "$backup"
  manifest_append "rename_${RENAME_COUNT}_method" "rename"
}

backup_before_corrupt() {
  local path="$1"
  local backup="${path}.${RUN_ID}.crashsim.bak"
  [[ -e "$path" ]] || die "Target does not exist: $path"
  echo "cp -p -- $path $backup"
  cp -p -- "$path" "$backup" || die "Unable to create scenario backup before corruption: $backup"
  RENAME_COUNT=$((RENAME_COUNT + 1))
  manifest_append "rename_${RENAME_COUNT}_original" "$path"
  manifest_append "rename_${RENAME_COUNT}_backup" "$backup"
  manifest_append "rename_${RENAME_COUNT}_method" "copy_before_corrupt"
}

perform_fs_corrupt() {
  local path="$1"
  local seek_blocks="$2"
  local count_blocks="$3"
  if storage_path_is_provider_managed "$path"; then
    die "$(storage_path_provider_reason "$path" "corruption handling")."
  fi
  [[ -e "$path" ]] || die "Target does not exist: $path"
  backup_before_corrupt "$path"
  echo "dd if=/dev/zero of=$path bs=8192 seek=$seek_blocks count=$count_blocks conv=notrunc"
  dd if=/dev/zero of="$path" bs=8192 seek="$seek_blocks" count="$count_blocks" conv=notrunc
}

perform_srvctl_abort_instance() {
  local instance="$1"
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl stop instance -d $DB_UNIQUE_NAME -i $instance -o abort"
  srvctl stop instance -d "$DB_UNIQUE_NAME" -i "$instance" -o abort
}

perform_srvctl_abort_database() {
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl stop database -d $DB_UNIQUE_NAME -o abort"
  srvctl stop database -d "$DB_UNIQUE_NAME" -o abort
}

perform_srvctl_relocate_service() {
  local service="$1"
  local detail="$2"
  local old_inst new_inst
  IFS='|' read -r old_inst new_inst <<<"$detail"
  [[ -n "$service" && -n "$old_inst" && -n "$new_inst" ]] ||
    die "Service relocation action is missing service/source/target metadata."
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl relocate service -d $DB_UNIQUE_NAME -s $service -oldinst $old_inst -newinst $new_inst"
  srvctl relocate service -d "$DB_UNIQUE_NAME" -s "$service" -oldinst "$old_inst" -newinst "$new_inst"
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service"
}

perform_srvctl_stop_start_service_instance() {
  local service="$1"
  local instance="$2"
  [[ -n "$service" && -n "$instance" ]] ||
    die "Service stop/start action is missing service or instance metadata."
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl stop service -d $DB_UNIQUE_NAME -s $service -i $instance"
  srvctl stop service -d "$DB_UNIQUE_NAME" -s "$service" -i "$instance"
  echo "srvctl start service -d $DB_UNIQUE_NAME -s $service -i $instance"
  srvctl start service -d "$DB_UNIQUE_NAME" -s "$service" -i "$instance"
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service"
}

discover_pmon_spid() {
  local output_file="$WORK_DIR/pmon_spid.out"
  sql_query "$output_file" "
select p.spid
from v\$bgprocess b
join v\$process p on p.addr = b.paddr
where b.name = 'PMON'
  and p.spid is not null;
" || return "$FAIL"
  trim_blank_lines <"$output_file" | head -n 1 | tr -d ' '
}

abort_target_instance() {
  if [[ "$PLANNING_ONLY" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  if [[ "$EXECUTE" -eq 0 ]]; then
    info "DRY-RUN: would abort target instance ${INSTANCE_NAME}"
    return "$SUCCESS"
  fi

  if [[ "$CLUSTER_TYPE" == "RAC" || "$INSTANCE_PARALLEL" == "YES" ]]; then
    perform_srvctl_abort_instance "$INSTANCE_NAME"
    return "$SUCCESS"
  fi

  local pmon_pattern="ora_pmon_${ORACLE_SID:-$INSTANCE_NAME}"
  local pid
  pid="$(discover_pmon_spid || true)"
  if [[ -z "$pid" ]]; then
    pid="$(pgrep -f "$pmon_pattern" | head -n 1 || true)"
  fi
  [[ -n "$pid" ]] || die "Could not find PMON for ${ORACLE_SID:-$INSTANCE_NAME}"
  echo "kill -9 $pid (PMON ${ORACLE_SID:-$INSTANCE_NAME})"
  kill -9 "$pid"
}

query_targets() {
  local file="$1"
  local sql_text="$2"
  sql_query "$file" "$sql_text"
  load_rows "$file"
}

add_fs_rename_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" || "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "crash injection")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "crash injection")"
    fi
  done
}

add_datafile_loss_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" ]]; then
      add_action "asm_rm" "$row" "ASM datafile loss via asmcmd rm"
    elif [[ "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "datafile loss injection")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "datafile loss injection")"
    fi
  done
}

add_tempfile_loss_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" ]]; then
      add_action "asm_tempfile_rm" "$row" "ASM tempfile loss via asmcmd rm"
    elif [[ "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "tempfile loss injection")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "tempfile loss injection")"
    fi
  done
}

add_fs_corrupt_targets() {
  local kind="$1"
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" || "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "corruption handling")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "$kind" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "corruption handling")"
    fi
  done
}

add_datafile_header_corrupt_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" ]]; then
      add_action "asm_corrupt_header" "$row" "ASM header-corruption surrogate: remove ASM datafile and recover FILE#"
    elif [[ "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "header-corruption handling")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_corrupt_header" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "header-corruption handling")"
    fi
  done
}

query_nonpdb_datafiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  query_targets "$file" "
select file_name
from (
  select df.file_name
  from dba_data_files df
  join dba_tablespaces ts on ts.tablespace_name = df.tablespace_name
  where ${where_clause}
  order by df.file_id
)
${limit_clause};
"
}

query_nonpdb_tempfiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  query_targets "$file" "
select file_name
from (
  select tf.file_name
  from dba_temp_files tf
  join dba_tablespaces ts on ts.tablespace_name = tf.tablespace_name
  where ${where_clause}
  order by tf.file_id
)
${limit_clause};
"
}

query_pdb_datafiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_targets "$file" "
select file_name
from (
  select df.file_name
  from cdb_data_files df
  join cdb_tablespaces ts
    on ts.con_id = df.con_id
   and ts.tablespace_name = df.tablespace_name
  join v\$pdbs p on p.con_id = df.con_id
  where p.name = ${pdb_literal}
    and ${where_clause}
  order by df.file_id
)
${limit_clause};
"
}

query_pdb_tempfiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_targets "$file" "
select file_name
from (
  select tf.file_name
  from cdb_temp_files tf
  join cdb_tablespaces ts
    on ts.con_id = tf.con_id
   and ts.tablespace_name = tf.tablespace_name
  join v\$pdbs p on p.con_id = tf.con_id
  where p.name = ${pdb_literal}
    and ${where_clause}
  order by tf.file_id
)
${limit_clause};
"
}

query_all_datafiles() {
  local file="$1"
  if [[ "$DB_CDB" == "YES" ]]; then
    query_targets "$file" "
select name
from v\$datafile
order by con_id, file#;
"
  else
    query_targets "$file" "
select name
from v\$datafile
order by file#;
"
  fi
}

one_row() {
  echo "where rownum = 1"
}

scenario_control_one() {
  reset_actions
  query_targets "$WORK_DIR/control_one.lst" "
select name
from (select name from v\$controlfile order by name)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_control_all() {
  reset_actions
  query_targets "$WORK_DIR/control_all.lst" "
select name from v\$controlfile order by name;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_redo_member_one() {
  reset_actions
  local id="${1:-$CURRENT_SCENARIO_ID}"
  local status_filter="and 1 = 1"
  local status_rank="case l.status when 'INACTIVE' then 1 when 'ACTIVE' then 2 when 'CURRENT' then 3 else 4 end"

  if [[ "$id" == "3" ]]; then
    status_filter="and l.status = 'CURRENT'"
    status_rank="1"
  fi

  query_targets "$WORK_DIR/redo_member_one.lst" "
select member
from (
  select lf.member
  from v\$log l
  join v\$logfile lf on lf.group# = l.group#
  where l.group# in (
    select group#
    from v\$logfile
    group by group#
    having count(*) > 1
  )
  ${status_filter}
  order by ${status_rank}, lf.group#, lf.member
)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_current_redo_all() {
  reset_actions
  query_targets "$WORK_DIR/current_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'CURRENT'
order by lf.group#, lf.member;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_inactive_redo_all() {
  reset_actions
  query_targets "$WORK_DIR/inactive_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'INACTIVE'
order by lf.group#, lf.member;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_active_redo_all() {
  reset_actions
  run_sql_action "switch logfile before active redo selection" "alter system switch logfile;"
  if [[ "$EXECUTE" -eq 0 ]]; then
    query_targets "$WORK_DIR/active_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'CURRENT'
order by lf.group#, lf.member;
"
  else
    query_targets "$WORK_DIR/active_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'ACTIVE'
order by lf.group#, lf.member;
"
  fi
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_non_system_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/non_system_one.lst" \
    "ts.contents = 'PERMANENT' and df.tablespace_name not in ('SYSTEM','SYSAUX')" \
    "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_temp_one() {
  reset_actions
  query_nonpdb_tempfiles "$WORK_DIR/temp_one.lst" "1 = 1" "$(one_row)"
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_system_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/system_one.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_undo_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/undo_one.lst" "ts.contents = 'UNDO'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_readonly_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/readonly_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where status = 'READ ONLY'
      and contents = 'PERMANENT'
      and tablespace_name not in ('SYSTEM','SYSAUX')
    order by case
               when tablespace_name = 'CRASHSIM_ROOT_RO_TBS' then 0
               when tablespace_name like 'CRASHSIM%' then 1
               else 2
             end,
             tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_indexonly_tbs() {
  reset_actions
  query_targets "$WORK_DIR/indexonly_tbs.lst" "
with index_ts as (
  select tablespace_name
  from dba_indexes
  where tablespace_name is not null
  group by tablespace_name
),
table_ts as (
  select tablespace_name
  from dba_tables
  where tablespace_name is not null
  group by tablespace_name
),
target_ts as (
  select tablespace_name
  from (
    select i.tablespace_name
    from index_ts i
    left join table_ts t on t.tablespace_name = i.tablespace_name
    where t.tablespace_name is null
      and i.tablespace_name not in ('SYSTEM','SYSAUX')
    order by case
               when i.tablespace_name = 'CRASHSIM_ROOT_INDEX_TBS' then 0
               when i.tablespace_name like 'CRASHSIM%' then 1
               else 2
             end,
             i.tablespace_name
  )
  where rownum = 1
)
select df.file_name
from dba_data_files df
join target_ts t on t.tablespace_name = df.tablespace_name
order by df.file_id;
"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_drop_indexes() {
  reset_actions
  local owner_filter="and (i.owner like 'CRASHSIM%' or i.owner like 'C##CRASHSIM%')"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and i.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
  query_targets "$WORK_DIR/drop_indexes.lst" "
select owner || '.' || index_name
from (
  select i.owner, i.index_name
  from dba_indexes i
  join dba_users u on u.username = i.owner
  where i.uniqueness = 'NONUNIQUE'
    and i.owner not in ('SYS','SYSTEM')
    and u.oracle_maintained = 'N'
    ${owner_filter}
  order by i.owner, i.index_name
)
where rownum <= 20;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No non-unique user index candidate was found. Re-run seed_crashsim_lab.sql or use --schema for a lab schema."
  local sql_text="
begin
  for rec in (
    select i.owner, i.index_name
    from dba_indexes i
    join dba_users u on u.username = i.owner
    where i.uniqueness = 'NONUNIQUE'
      and i.owner not in ('SYS','SYSTEM')
      and u.oracle_maintained = 'N'
      ${owner_filter}
      and rownum <= 20
  ) loop
    execute immediate 'drop index \"' || rec.owner || '\".\"' || rec.index_name || '\"';
  end loop;
end;
/
"
  add_action "sql" "$sql_text" "drop non-unique indexes (${#TARGET_ROWS[@]} candidates)"
  execute_actions
}

scenario_non_system_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/non_system_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where contents = 'PERMANENT'
      and tablespace_name not in ('SYSTEM','SYSAUX')
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_temp_tbs() {
  reset_actions
  query_nonpdb_tempfiles "$WORK_DIR/temp_tbs.lst" "
tf.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where contents = 'TEMPORARY'
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_system_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/system_tbs.lst" "df.tablespace_name = 'SYSTEM'" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_undo_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/undo_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where contents = 'UNDO'
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_password_file() {
  reset_actions
  local path="$PASSWORD_FILE_PATH"
  if [[ -z "$path" && -n "${ORACLE_HOME:-}" && -n "${ORACLE_SID:-}" ]]; then
    if [[ -f "${ORACLE_HOME}/dbs/orapw${ORACLE_SID}" ]]; then
      path="${ORACLE_HOME}/dbs/orapw${ORACLE_SID}"
    elif [[ -f "${ORACLE_HOME}/dbs/orapw${DB_NAME}" ]]; then
      path="${ORACLE_HOME}/dbs/orapw${DB_NAME}"
    fi
  fi
  [[ -n "$path" ]] || die "Password file path was not discovered."
  TARGET_ROWS=("$path")
  add_fs_rename_targets
  execute_actions
}

scenario_all_datafiles() {
  reset_actions
  query_all_datafiles "$WORK_DIR/all_datafiles.lst"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_file_header_corrupt() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/file_header_corrupt.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_header_corrupt_targets
  execute_actions
  abort_target_instance
}

scenario_control_corrupt() {
  reset_actions
  query_targets "$WORK_DIR/control_corrupt.lst" "
select name from v\$controlfile order by name;
"
  add_fs_corrupt_targets "fs_corrupt_body"
  execute_actions
  abort_target_instance
}

scenario_redo_corrupt() {
  reset_actions
  run_sql_action "switch logfile before redo corruption selection" "alter system switch logfile;"
  if [[ "$EXECUTE" -eq 0 ]]; then
    query_targets "$WORK_DIR/redo_corrupt.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'CURRENT'
order by lf.group#, lf.member;
"
  else
    query_targets "$WORK_DIR/redo_corrupt.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'ACTIVE'
order by lf.group#, lf.member;
"
  fi
  add_fs_corrupt_targets "fs_corrupt_body"
  execute_actions
  abort_target_instance
}

scenario_rman_backups() {
  reset_actions
  local where_clause="status = 'A' and handle is not null"
  local limit_clause=""
  local piece_literal

  if [[ -n "$PIECE_HANDLE" ]]; then
    piece_literal="$(sql_quote "$PIECE_HANDLE")"
    where_clause="${where_clause} and handle = ${piece_literal}"
  fi
  if [[ "$LOCAL_ONLY" -eq 1 ]]; then
    where_clause="${where_clause} and handle like '/%'"
  fi
  if [[ -n "$MAX_TARGETS" ]]; then
    limit_clause="where rownum <= ${MAX_TARGETS}"
  fi

  if [[ "$EXECUTE" -eq 1 ]]; then
    if [[ -z "$PIECE_HANDLE" ]]; then
      [[ "$LOCAL_ONLY" -eq 1 ]] ||
        die "Scenario 25 execution requires --local-only or --piece-handle."
      [[ -n "$MAX_TARGETS" ]] ||
        die "Scenario 25 execution with --local-only also requires --max-targets <n>."
    fi
  fi

  manifest_append "scenario_25_local_only" "$LOCAL_ONLY"
  manifest_append "scenario_25_max_targets" "$MAX_TARGETS"
  manifest_append "scenario_25_piece_handle" "$PIECE_HANDLE"

  query_targets "$WORK_DIR/rman_backup_pieces.lst" "
select handle
from (
  select handle
  from v\$backup_piece
  where ${where_clause}
  order by completion_time nulls last, recid
)
${limit_clause};
"
  local row
  for row in "${TARGET_ROWS[@]}"; do
    if [[ "$row" == /* ]]; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "non-filesystem RMAN backup piece"
    fi
  done
  if [[ "$EXECUTE" -eq 1 ]]; then
    local idx
    for idx in "${!ACTION_KINDS[@]}"; do
      [[ "${ACTION_KINDS[$idx]}" == "fs_rename" ]] ||
        die "Scenario 25 execution can only operate on local filesystem backup pieces. Non-local handle: ${ACTION_TARGETS[$idx]}"
    done
  fi
  execute_actions
}

scenario_spfile() {
  reset_actions
  [[ -n "$SPFILE_PATH" ]] || die "SPFILE path was not discovered."
  TARGET_ROWS=("$SPFILE_PATH")
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_sqlnet() {
  reset_actions
  local net_dir="${TNS_ADMIN:-${ORACLE_HOME:-}/network/admin}"
  [[ -d "$net_dir" ]] || die "Network admin directory was not found: $net_dir"
  TARGET_ROWS=()
  local file
  for file in listener.ora tnsnames.ora sqlnet.ora; do
    if [[ -f "${net_dir}/${file}" ]]; then
      TARGET_ROWS+=("${net_dir}/${file}")
    fi
  done
  add_fs_rename_targets
  execute_actions
}

scenario_oracle_home() {
  reset_actions
  [[ -n "${ORACLE_HOME:-}" && -d "$ORACLE_HOME" ]] || die "ORACLE_HOME was not found."
  TARGET_ROWS=("$ORACLE_HOME")
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_fra() {
  reset_actions
  [[ -n "$FRA_PATH" ]] || die "FRA is not configured."
  TARGET_ROWS=("$FRA_PATH")
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_non_system_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_non_system_one.lst" \
    "ts.contents = 'PERMANENT' and df.tablespace_name not in ('SYSTEM','SYSAUX')" \
    "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_temp_one() {
  reset_actions
  query_pdb_tempfiles "$WORK_DIR/pdb_temp_one.lst" "1 = 1" "$(one_row)"
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_system_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_system_one.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_undo_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_undo_one.lst" "ts.contents = 'UNDO'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_readonly_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_pdb_datafiles "$WORK_DIR/pdb_readonly_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select ts.tablespace_name
    from cdb_tablespaces ts
    join v\$pdbs p on p.con_id = ts.con_id
    where p.name = ${pdb_literal}
      and ts.status = 'READ ONLY'
    order by ts.tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_indexonly_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_targets "$WORK_DIR/pdb_indexonly_tbs.lst" "
with target_pdb as (
  select con_id from v\$pdbs where name = ${pdb_literal}
),
index_ts as (
  select tablespace_name
  from cdb_indexes
  where con_id = (select con_id from target_pdb)
    and tablespace_name is not null
  group by tablespace_name
),
table_ts as (
  select tablespace_name
  from cdb_tables
  where con_id = (select con_id from target_pdb)
    and tablespace_name is not null
  group by tablespace_name
),
target_ts as (
  select i.tablespace_name
  from index_ts i
  left join table_ts t on t.tablespace_name = i.tablespace_name
  where t.tablespace_name is null
    and i.tablespace_name not in ('SYSTEM','SYSAUX')
    and rownum = 1
)
select df.file_name
from cdb_data_files df
join target_pdb p on p.con_id = df.con_id
join target_ts t on t.tablespace_name = df.tablespace_name
order by df.file_id;
"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_drop_indexes() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and i.owner like 'CRASHSIM%'"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and i.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
  local target_file="$WORK_DIR/pdb_drop_indexes.lst"
  sql_query "$target_file" "
alter session set container = ${pdb};
select owner || '.' || index_name
from (
  select i.owner, i.index_name
  from dba_indexes i
  join dba_users u on u.username = i.owner
  where i.uniqueness = 'NONUNIQUE'
    and i.owner not in ('SYS','SYSTEM')
    and u.oracle_maintained = 'N'
    ${owner_filter}
  order by i.owner, i.index_name
)
where rownum <= 20;
alter session set container = CDB\$ROOT;
"
  load_rows "$target_file"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No PDB non-unique user index candidate was found. Re-run seed_crashsim_lab.sql or use --schema for a lab schema."
  local sql_text="
alter session set container = ${pdb};
begin
  for rec in (
    select i.owner, i.index_name
    from dba_indexes i
    join dba_users u on u.username = i.owner
    where i.uniqueness = 'NONUNIQUE'
      and i.owner not in ('SYS','SYSTEM')
      and u.oracle_maintained = 'N'
      ${owner_filter}
      and rownum <= 20
  ) loop
    execute immediate 'drop index \"' || rec.owner || '\".\"' || rec.index_name || '\"';
  end loop;
end;
/
alter session set container = CDB\$ROOT;
"
  add_action "sql" "$sql_text" "drop PDB non-unique indexes (${#TARGET_ROWS[@]} candidates)"
  execute_actions
}

scenario_pdb_non_system_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_pdb_datafiles "$WORK_DIR/pdb_non_system_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select ts.tablespace_name
    from cdb_tablespaces ts
    join v\$pdbs p on p.con_id = ts.con_id
    where p.name = ${pdb_literal}
      and ts.contents = 'PERMANENT'
      and ts.tablespace_name not in ('SYSTEM','SYSAUX')
    order by ts.tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_temp_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_pdb_tempfiles "$WORK_DIR/pdb_temp_tbs.lst" "
tf.tablespace_name = (
  select tablespace_name
  from (
    select ts.tablespace_name
    from cdb_tablespaces ts
    join v\$pdbs p on p.con_id = ts.con_id
    where p.name = ${pdb_literal}
      and ts.contents = 'TEMPORARY'
    order by ts.tablespace_name
  )
  where rownum = 1
)" ""
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_system_tbs() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_system_tbs.lst" "df.tablespace_name = 'SYSTEM'" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_undo_tbs() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_undo_tbs.lst" "ts.contents = 'UNDO'" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_all_datafiles() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_all_datafiles.lst" "1 = 1" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_file_header_corrupt() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_file_header_corrupt.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_header_corrupt_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_drop_table() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and t.owner like 'CRASHSIM%'"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and t.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
  local target_file="$WORK_DIR/pdb_drop_table.lst"
  sql_query "$target_file" "
alter session set container = ${pdb};
select owner || '|' || table_name
from (
  select t.owner, t.table_name
  from dba_tables t
  join dba_users u on u.username = t.owner
  where t.owner not in ('SYS','SYSTEM')
    and u.oracle_maintained = 'N'
    and t.nested = 'NO'
    and t.temporary = 'N'
    and t.secondary = 'N'
    ${owner_filter}
  order by t.owner, t.table_name
)
where rownum = 1;
alter session set container = CDB\$ROOT;
"
  load_rows "$target_file"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No PDB user table candidate was found."
  local owner table_name
  IFS='|' read -r owner table_name <<<"${TARGET_ROWS[0]}"
  local owner_sql table_sql
  owner_sql="$(sql_identifier "$owner")"
  table_sql="$(sql_identifier "$table_name")"
  local sql_text="
alter session set container = ${pdb};
drop table ${owner_sql}.${table_sql} purge;
alter session set container = CDB\$ROOT;
"
  add_action "sql" "$sql_text" "drop PDB table ${owner}.${table_name}"
  execute_actions
}

scenario_pdb_drop_schema() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and username like 'CRASHSIM%'"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and username = $(sql_quote "$TARGET_SCHEMA")"
  fi
  local target_file="$WORK_DIR/pdb_drop_schema.lst"
  sql_query "$target_file" "
alter session set container = ${pdb};
select username
from (
  select username
  from dba_users
  where oracle_maintained = 'N'
    and username not in ('SYS','SYSTEM')
    and account_status not like 'LOCKED%'
    ${owner_filter}
  order by username
)
where rownum = 1;
alter session set container = CDB\$ROOT;
"
  load_rows "$target_file"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No PDB user schema candidate was found."
  local username username_sql
  username="${TARGET_ROWS[0]}"
  username_sql="$(sql_identifier "$username")"
  local sql_text="
alter session set container = ${pdb};
drop user ${username_sql} cascade;
alter session set container = CDB\$ROOT;
"
  add_action "sql" "$sql_text" "drop PDB schema ${username}"
  execute_actions
}

scenario_drop_pdb() {
  reset_actions
  local pdb="$TARGET_PDB"
  [[ "$pdb" != "CDB\$ROOT" && "$pdb" != "PDB\$SEED" ]] || die "Refusing to drop protected container: $pdb"
  [[ "$pdb" == CRASHSIM_* ]] ||
    die "Refusing to drop non-disposable PDB '${pdb}'. Scenario 45 requires a PDB name starting with CRASHSIM_."
  local sql_text="
alter pluggable database ${pdb} close immediate instances=all;
drop pluggable database ${pdb} including datafiles;
"
  add_action "sql" "$sql_text" "drop selected PDB including datafiles"
  execute_actions
}

redact_rman_catalog_connect() {
  local value="$1"
  if [[ -z "$value" ]]; then
    printf "not configured"
    return "$SUCCESS"
  fi
  printf "%s" "$value" | sed -E 's#([^/@[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#'
}

write_recovery_catalog_check_rman() {
  local cmd_file="$1"
  cat >"$cmd_file" <<RMAN || die "Unable to write recovery catalog RMAN file: $cmd_file"
connect catalog ${RMAN_CATALOG_CONNECT}
resync catalog;
list incarnation;
report schema;
exit
RMAN
  chmod 600 "$cmd_file" 2>/dev/null || true
}

write_recovery_catalog_fallback_rman() {
  local cmd_file="$1"
  cat >"$cmd_file" <<'RMAN' || die "Unable to write NOCATALOG fallback RMAN file: $cmd_file"
list incarnation;
report schema;
list backup summary;
restore database preview summary;
exit
RMAN
  chmod 600 "$cmd_file" 2>/dev/null || true
}

print_redacted_rman_log() {
  local log_file="$1"
  sed -E 's#(connect catalog [^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#Ig' "$log_file"
}

scenario_recovery_catalog_unavailable() {
  reset_actions
  local redacted catalog_cmd catalog_log fallback_cmd fallback_log
  redacted="$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"
  catalog_cmd="${LOG_DIR}/crashsim_s60_${RUN_ID}_catalog_check.rman"
  catalog_log="${LOG_DIR}/crashsim_s60_${RUN_ID}_catalog_check.log"
  fallback_cmd="${LOG_DIR}/crashsim_s60_${RUN_ID}_nocatalog_fallback.rman"
  fallback_log="${LOG_DIR}/crashsim_s60_${RUN_ID}_nocatalog_fallback.log"

  echo "Recovery catalog drill"
  echo "Catalog connect string: ${redacted}"
  echo "Purpose: validate catalog resync/reporting, then validate target-control-file NOCATALOG fallback."
  echo

  manifest_append "rman_catalog_configured" "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)"
  manifest_append "rman_catalog_connect_redacted" "$redacted"
  manifest_append "rman_catalog_check_cmdfile" "$catalog_cmd"
  manifest_append "rman_catalog_check_log" "$catalog_log"
  manifest_append "rman_nocatalog_fallback_cmdfile" "$fallback_cmd"
  manifest_append "rman_nocatalog_fallback_log" "$fallback_log"

  if [[ -z "$RMAN_CATALOG_CONNECT" ]]; then
    echo "No recovery catalog connect string was supplied."
    echo "Set --rman-catalog or CRASHSIM_RMAN_CATALOG to validate the catalog phase."
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would still validate NOCATALOG fallback against the target control file."
      return "$SUCCESS"
    fi
    ensure_rman
    write_recovery_catalog_fallback_rman "$fallback_cmd"
    "$RMAN_BIN" target / cmdfile="$fallback_cmd" log="$fallback_log" ||
      die "RMAN NOCATALOG fallback validation failed: $fallback_log"
    cat "$fallback_log"
    return "$SUCCESS"
  fi

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run RMAN target / with catalog connect string ${redacted}"
    echo "DRY-RUN: would run resync catalog, list incarnation, and report schema."
    echo "DRY-RUN: would run RMAN target / without catalog for fallback list/report/restore preview."
    return "$SUCCESS"
  fi

  ensure_rman
  write_recovery_catalog_check_rman "$catalog_cmd"
  write_recovery_catalog_fallback_rman "$fallback_cmd"

  "$RMAN_BIN" target / cmdfile="$catalog_cmd" log="$catalog_log" ||
    die "RMAN recovery catalog validation failed: $catalog_log"
  print_redacted_rman_log "$catalog_log"

  "$RMAN_BIN" target / cmdfile="$fallback_cmd" log="$fallback_log" ||
    die "RMAN NOCATALOG fallback validation failed: $fallback_log"
  cat "$fallback_log"
}

iso_to_epoch() {
  local value="$1"
  local epoch=""
  [[ -n "$value" ]] || return "$FAIL"
  epoch="$(date -u -d "$value" +%s 2>/dev/null || true)"
  if [[ -z "$epoch" ]]; then
    epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$value" +%s 2>/dev/null || true)"
  fi
  [[ "$epoch" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$epoch"
}

duration_to_seconds() {
  local raw="$1"
  local text number unit
  text="$(printf "%s" "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$text" in
    ""|not\ supplied) return "$FAIL" ;;
    zero|near\ zero|near-zero) printf "0\n"; return "$SUCCESS" ;;
  esac
  number="$(printf "%s" "$text" | sed -nE 's/^[^0-9]*([0-9]+([.][0-9]+)?).*/\1/p' | head -n 1)"
  [[ -n "$number" ]] || return "$FAIL"
  if printf "%s" "$text" | grep -Eq 'day|d\b'; then
    unit=86400
  elif printf "%s" "$text" | grep -Eq 'hour|hr|h\b'; then
    unit=3600
  elif printf "%s" "$text" | grep -Eq 'minute|min|m\b'; then
    unit=60
  else
    unit=1
  fi
  awk -v n="$number" -v u="$unit" 'BEGIN {printf "%d\n", int(n*u + 0.999)}'
}

format_seconds() {
  local seconds="$1"
  [[ "$seconds" =~ ^[0-9]+$ ]] || { printf "%s" "$seconds"; return "$SUCCESS"; }
  local days hours mins secs remainder
  days=$((seconds / 86400))
  remainder=$((seconds % 86400))
  hours=$((remainder / 3600))
  remainder=$((remainder % 3600))
  mins=$((remainder / 60))
  secs=$((remainder % 60))
  if [[ "$days" -gt 0 ]]; then
    printf "%sd %sh %sm %ss" "$days" "$hours" "$mins" "$secs"
  elif [[ "$hours" -gt 0 ]]; then
    printf "%sh %sm %ss" "$hours" "$mins" "$secs"
  elif [[ "$mins" -gt 0 ]]; then
    printf "%sm %ss" "$mins" "$secs"
  else
    printf "%ss" "$secs"
  fi
}

latest_completed_recovery_manifest() {
  local manifest
  while IFS= read -r manifest; do
    if grep -q '^recovery_completed_at_utc=' "$manifest" 2>/dev/null; then
      printf "%s\n" "$manifest"
      return "$SUCCESS"
    fi
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_recover_s*.manifest' 2>/dev/null | sort -r)
  return "$FAIL"
}

write_rto_validation_report() {
  local report_file="$1"
  local latest_manifest scenario_id scenario_title started completed start_epoch complete_epoch actual_seconds
  local objective label target_seconds status

  latest_manifest="$(latest_completed_recovery_manifest || true)"

  {
    printf "# CrashSimulator RTO Validation Drill\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- Latest completed recovery manifest: `%s`\n\n' "${latest_manifest:-none found}"
    printf '%s\n\n' 'This read-only drill measures actual recovery time from CrashSimulator recovery manifests. It does not infer RTO from backup size alone; it needs a completed `--recover <id> --execute` run to produce a measured result.'
  } >"$report_file" || die "Unable to write RTO validation report: $report_file"

  append_report_section "$report_file" "Measured Recovery"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    if [[ -n "$latest_manifest" ]]; then
      scenario_id="$(awk -F= '$1=="scenario_id"{print $2; exit}' "$latest_manifest")"
      scenario_title="$(awk -F= '$1=="scenario_title"{print $2; exit}' "$latest_manifest")"
      started="$(awk -F= '$1=="recovery_started_at_utc"{print $2; exit}' "$latest_manifest")"
      completed="$(awk -F= '$1=="recovery_completed_at_utc"{print $2; exit}' "$latest_manifest")"
      if start_epoch="$(iso_to_epoch "$started")" && complete_epoch="$(iso_to_epoch "$completed")" && [[ "$complete_epoch" -ge "$start_epoch" ]]; then
        actual_seconds=$((complete_epoch - start_epoch))
      else
        actual_seconds=""
      fi
      printf '| Scenario | `%s - %s` |\n' "$(md_escape "${scenario_id:-unknown}")" "$(md_escape "${scenario_title:-unknown}")"
      printf '| Recovery started | `%s` |\n' "$(md_escape "${started:-unknown}")"
      printf '| Recovery completed | `%s` |\n' "$(md_escape "${completed:-unknown}")"
      if [[ -n "$actual_seconds" ]]; then
        printf '| Actual RTO | `%s` (`%s` seconds) |\n' "$(format_seconds "$actual_seconds")" "$actual_seconds"
      else
        printf '| Actual RTO | `UNKNOWN` |\n'
      fi
    else
      printf '| Actual RTO | `NOT MEASURED` |\n'
      printf '| Reason | No completed CrashSimulator recovery manifest was found. |\n'
    fi
  } >>"$report_file"

  append_report_section "$report_file" "Objective Comparison"
  {
    printf '| Objective | Supplied target | Parsed target | Result |\n'
    printf '| --- | --- | --- | --- |\n'
    for label in \
      "Local unplanned RTO|${MAA_LOCAL_RTO:-}" \
      "Disaster/site RTO|${MAA_DR_RTO:-}" \
      "Planned maintenance RTO|${MAA_PLANNED_RTO:-}"; do
      objective="${label#*|}"
      label="${label%%|*}"
      if target_seconds="$(duration_to_seconds "$objective")"; then
        if [[ -n "${actual_seconds:-}" ]]; then
          if [[ "$actual_seconds" -le "$target_seconds" ]]; then
            status="PASS"
          else
            status="FAIL"
          fi
        else
          status="NOT MEASURED"
        fi
        printf '| %s | `%s` | `%s` (`%s` seconds) | `%s` |\n' \
          "$(md_escape "$label")" "$(md_escape "$objective")" "$(format_seconds "$target_seconds")" "$target_seconds" "$status"
      else
        printf '| %s | `%s` | `not supplied or not parseable` | `INFO` |\n' \
          "$(md_escape "$label")" "$(md_escape "${objective:-not supplied}")"
      fi
    done
  } >>"$report_file"

  append_report_section "$report_file" "Next Steps"
  {
    printf -- '- To create a measured RTO, execute a controlled scenario recovery and then re-run scenario `64`.\n'
    printf -- '- Record application validation separately; database-open time is necessary but not always sufficient for business RTO.\n'
    printf -- '- Use the same scenario repeatedly to trend operational improvement over time.\n'
  } >>"$report_file"
}

write_rpo_validation_sql_file() {
  local sql_file="$1"
  cat >"$sql_file" <<'SQL' || die "Unable to write RPO validation SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off

select 'CSIM_RPO|database_role|' || database_role from v$database;
select 'CSIM_RPO|open_mode|' || open_mode from v$database;
select 'CSIM_RPO|current_scn|' || current_scn from v$database;
select 'CSIM_RPO|log_mode|' || log_mode from v$database;
select 'CSIM_RPO|force_logging|' || force_logging from v$database;
select 'CSIM_RPO|flashback_on|' || flashback_on from v$database;
select 'CSIM_RPO|current_time|' || to_char(systimestamp at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS TZH:TZM') from dual;

select 'CSIM_RPO|latest_archived_log_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';
select 'CSIM_RPO|latest_archived_log_age_seconds|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 86400)), 'UNKNOWN')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';
select 'CSIM_RPO|latest_archived_log_thread_sequence|' ||
       nvl(max(to_char(thread#) || ':' || to_char(sequence#)) keep (dense_rank last order by completion_time), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';

select 'CSIM_RPO|latest_backed_archivelog_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) > 0;
select 'CSIM_RPO|latest_backed_archivelog_age_seconds|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 86400)), 'UNKNOWN')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) > 0;
select 'CSIM_RPO|latest_backed_archivelog_thread_sequence|' ||
       nvl(max(to_char(thread#) || ':' || to_char(sequence#)) keep (dense_rank last order by completion_time), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) > 0;

select 'CSIM_RPO|unbacked_archivelog_count|' || count(*)
from v$archived_log al
where al.name is not null
  and nvl(al.deleted, 'NO') = 'NO'
  and nvl(al.backup_count, 0) = 0;

select 'CSIM_RPO|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_RPO|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_RPO|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_RPO|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_RPO|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

exit
SQL
}

parse_rpo_evidence_file() {
  local evidence_file="$1"
  local prefix key value
  RPO_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_RPO" && -n "$key" ]] || continue
    RPO_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

rpo_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${RPO_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

write_rpo_validation_report() {
  local report_file="$1"
  local evidence_file="$2"
  local backup_age archive_age actual_seconds actual_basis objective label target_seconds status

  backup_age="$(rpo_value latest_backed_archivelog_age_seconds UNKNOWN)"
  archive_age="$(rpo_value latest_archived_log_age_seconds UNKNOWN)"
  if [[ "$backup_age" =~ ^[0-9]+$ ]]; then
    actual_seconds="$backup_age"
    actual_basis="Backup-only RPO based on latest backed-up archived redo."
  elif [[ "$archive_age" =~ ^[0-9]+$ ]]; then
    actual_seconds="$archive_age"
    actual_basis="Control-file archived redo visibility; backup-only RPO was not measurable."
  else
    actual_seconds=""
    actual_basis="No archived redo age was measurable from target control-file evidence."
  fi

  {
    printf "# CrashSimulator RPO Validation Drill\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(rpo_value database_role "$DB_ROLE")" "$(rpo_value open_mode "$DB_OPEN_MODE")"
    printf -- '- Evidence file: `%s`\n\n' "$evidence_file"
    printf "This read-only drill estimates the currently recoverable data window from archived redo, archived-redo backup metadata, and Data Guard lag evidence. It is an operational RPO indicator, not a substitute for a timed restore/recovery drill.\n\n"
  } >"$report_file" || die "Unable to write RPO validation report: $report_file"

  append_report_section "$report_file" "Recoverable Data Window"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| Actual RPO estimate | `%s` |\n' "$([[ -n "$actual_seconds" ]] && format_seconds "$actual_seconds" || printf UNKNOWN)"
    printf '| Actual RPO seconds | `%s` |\n' "${actual_seconds:-UNKNOWN}"
    printf '| Basis | %s |\n' "$(md_escape "$actual_basis")"
    printf '| Latest archived redo | `%s` sequence `%s`, age `%s` |\n' \
      "$(md_escape "$(rpo_value latest_archived_log_time NONE)")" \
      "$(md_escape "$(rpo_value latest_archived_log_thread_sequence NONE)")" \
      "$(md_escape "$(rpo_value latest_archived_log_age_seconds UNKNOWN)")"
    printf '| Latest backed-up archived redo | `%s` sequence `%s`, age `%s` |\n' \
      "$(md_escape "$(rpo_value latest_backed_archivelog_time NONE)")" \
      "$(md_escape "$(rpo_value latest_backed_archivelog_thread_sequence NONE)")" \
      "$(md_escape "$(rpo_value latest_backed_archivelog_age_seconds UNKNOWN)")"
    printf '| Unbacked archived logs | `%s` |\n' "$(md_escape "$(rpo_value unbacked_archivelog_count UNKNOWN)")"
    printf '| Data Guard destinations | valid `%s`, errors `%s`, archive gaps `%s` |\n' \
      "$(md_escape "$(rpo_value valid_remote_standby_dest_count UNKNOWN)")" \
      "$(md_escape "$(rpo_value standby_dest_error_count UNKNOWN)")" \
      "$(md_escape "$(rpo_value archive_gap_count UNKNOWN)")"
    printf '| Data Guard lag | transport `%s`, apply `%s` |\n' \
      "$(md_escape "$(rpo_value dataguard_transport_lag UNKNOWN)")" \
      "$(md_escape "$(rpo_value dataguard_apply_lag UNKNOWN)")"
  } >>"$report_file"

  append_report_section "$report_file" "Objective Comparison"
  {
    printf '| Objective | Supplied target | Parsed target | Result |\n'
    printf '| --- | --- | --- | --- |\n'
    for label in \
      "Local unplanned RPO|${MAA_LOCAL_RPO:-}" \
      "Disaster/site RPO|${MAA_DR_RPO:-}" \
      "Planned maintenance RPO|${MAA_PLANNED_RPO:-}"; do
      objective="${label#*|}"
      label="${label%%|*}"
      if target_seconds="$(duration_to_seconds "$objective")"; then
        if [[ -n "$actual_seconds" ]]; then
          if [[ "$actual_seconds" -le "$target_seconds" ]]; then
            status="PASS"
          else
            status="FAIL"
          fi
        else
          status="NOT MEASURED"
        fi
        printf '| %s | `%s` | `%s` (`%s` seconds) | `%s` |\n' \
          "$(md_escape "$label")" "$(md_escape "$objective")" "$(format_seconds "$target_seconds")" "$target_seconds" "$status"
      else
        printf '| %s | `%s` | `not supplied or not parseable` | `INFO` |\n' \
          "$(md_escape "$label")" "$(md_escape "${objective:-not supplied}")"
      fi
    done
  } >>"$report_file"

  append_report_section "$report_file" "Raw RPO Evidence"
  {
    printf '```text\n'
    sed -n '/^CSIM_RPO|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"
}

write_fra_pressure_sql_file() {
  local sql_file="$1"
  local original_size="$2"
  local target_size="$3"
  cat >"$sql_file" <<SQL || die "Unable to write FRA pressure SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
prompt FRA usage before pressure change
select name, space_limit, space_used, space_reclaimable, number_of_files
from v\$recovery_file_dest;
alter system set db_recovery_file_dest_size=${target_size} scope=both;
prompt FRA usage after shrinking DB_RECOVERY_FILE_DEST_SIZE
select name, space_limit, space_used,
       round(space_used / nullif(space_limit, 0) * 100, 2) used_pct,
       space_reclaimable, number_of_files
from v\$recovery_file_dest;
declare
begin
  execute immediate 'alter system archive log current';
  dbms_output.put_line('ARCHIVE LOG CURRENT completed. FRA pressure may not be high enough; lower headroom or generate more redo in a lab.');
exception
  when others then
    if sqlcode in (-19809, -19815, -16038, -257) then
      dbms_output.put_line('Expected FRA pressure symptom captured: ' || sqlerrm);
    else
      raise;
    end if;
end;
/
prompt Restore command for recovery helper
prompt alter system set db_recovery_file_dest_size=${original_size} scope=both;
exit
SQL
}

write_fra_restore_sql_file() {
  local sql_file="$1"
  local original_size="$2"
  cat >"$sql_file" <<SQL || die "Unable to write FRA restore SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
alter system set db_recovery_file_dest_size=${original_size} scope=both;
select name, space_limit, space_used,
       round(space_used / nullif(space_limit, 0) * 100, 2) used_pct,
       space_reclaimable, number_of_files
from v\$recovery_file_dest;
alter system archive log current;
exit
SQL
}

write_temp_exhaustion_sql_file() {
  local sql_file="$1"
  local container_clause="$2"
  local target_mb="$3"
  local rows
  rows=$(( (target_mb * 1024 * 1024 / 3000) + 1 ))
  cat >"$sql_file" <<SQL || die "Unable to write TEMP exhaustion SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on size unlimited feedback on timing on pages 100 lines 220
${container_clause}
prompt TEMP usage before controlled pressure
select tablespace, round(sum(blocks * 8192)/1024/1024, 2) used_mb
from v\$tempseg_usage
group by tablespace
order by tablespace;
declare
  l_rows number := ${rows};
  l_mb number := ${target_mb};
begin
  begin
    execute immediate 'drop table crashsim_temp_pressure purge';
  exception
    when others then
      if sqlcode != -942 then
        raise;
      end if;
  end;

  execute immediate 'create global temporary table crashsim_temp_pressure (id number, payload varchar2(4000)) on commit preserve rows';
  dbms_output.put_line('Attempting controlled TEMP pressure: approximately ' || l_mb || ' MB using ' || l_rows || ' rows.');

  begin
    insert into crashsim_temp_pressure
    select level, rpad('X', 3000, 'X')
    from dual
    connect by level <= l_rows
    order by dbms_random.value;
    dbms_output.put_line('TEMP pressure workload completed without ORA-01652. Increase --temp-exhaust-mb for a stronger lab drill.');
  exception
    when others then
      if sqlcode = -1652 then
        dbms_output.put_line('Expected TEMP exhaustion symptom captured: ' || sqlerrm);
      else
        raise;
      end if;
  end;

  rollback;
  execute immediate 'drop table crashsim_temp_pressure purge';
end;
/
prompt TEMP usage after controlled pressure cleanup
select tablespace, round(sum(blocks * 8192)/1024/1024, 2) used_mb
from v\$tempseg_usage
group by tablespace
order by tablespace;
exit
SQL
}

print_optional_tool_output() {
  local title="$1"
  shift
  echo
  echo "${title}:"
  if "$@" 2>&1 | sed 's/^/  /'; then
    return "$SUCCESS"
  fi
  warn "Unable to collect ${title}."
}

detect_asm_sid_from_process() {
  pgrep -af 'asm_pmon_' 2>/dev/null |
    awk -F'asm_pmon_' 'NF > 1 {print $2; exit}'
}

discover_grid_home_for_tool() {
  local tool="$1"
  local tool_path candidate

  if [[ -n "${CRASHSIM_GRID_HOME:-}" && -x "${CRASHSIM_GRID_HOME}/bin/${tool}" ]]; then
    printf "%s" "$CRASHSIM_GRID_HOME"
    return "$SUCCESS"
  fi

  tool_path="$(command -v "$tool" 2>/dev/null || true)"
  if [[ -n "$tool_path" ]]; then
    candidate="$(cd "$(dirname "$tool_path")/.." >/dev/null 2>&1 && pwd || true)"
    if [[ -n "$candidate" && -x "${candidate}/bin/${tool}" ]]; then
      printf "%s" "$candidate"
      return "$SUCCESS"
    fi
  fi

  for tool_path in \
    "/u01/app/23.0.0.0/gridhome_1/bin/${tool}" \
    "/u01/app/23.0.0.0/grid/bin/${tool}" \
    "/u01/app/grid/product/23.0.0/grid/bin/${tool}" \
    "/u01/app/19.0.0.0/gridhome_1/bin/${tool}" \
    "/u01/app/19.0.0.0/grid/bin/${tool}" \
    "/u01/app/grid/product/19.0.0/grid/bin/${tool}"; do
    if [[ -x "$tool_path" ]]; then
      candidate="$(cd "$(dirname "$tool_path")/.." >/dev/null 2>&1 && pwd || true)"
      if [[ -n "$candidate" ]]; then
        printf "%s" "$candidate"
        return "$SUCCESS"
      fi
    fi
  done

  return "$FAIL"
}

grid_tool_available() {
  local tool="$1"
  discover_grid_home_for_tool "$tool" >/dev/null 2>&1
}

run_grid_tool() {
  local tool="$1"
  shift
  local grid_home status
  grid_home="$(discover_grid_home_for_tool "$tool" || true)"
  [[ -n "$grid_home" && -x "${grid_home}/bin/${tool}" ]] || return "$FAIL"

  if [[ "$(id -un 2>/dev/null || true)" == "$GRID_USER" ]]; then
    env ORACLE_HOME="$grid_home" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/${tool}" "$@"
    return "$?"
  fi

  env ORACLE_HOME="$grid_home" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/${tool}" "$@"
  status=$?
  [[ "$status" -eq 0 ]] && return "$SUCCESS"

  if command -v sudo >/dev/null 2>&1 && sudo -n -u "$GRID_USER" true >/dev/null 2>&1; then
    sudo -n -u "$GRID_USER" env ORACLE_HOME="$grid_home" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/${tool}" "$@"
    return "$?"
  fi

  return "$status"
}

run_asmcmd_with_grid_env() {
  local asmcmd_bin asm_home asm_sid
  asm_home="$(discover_grid_home_for_tool asmcmd || true)"
  [[ -n "$asm_home" ]] || return "$FAIL"
  asmcmd_bin="${asm_home}/bin/asmcmd"
  [[ -x "$asmcmd_bin" ]] || return "$FAIL"
  asm_sid="${CRASHSIM_ASM_SID:-}"
  [[ -n "$asm_sid" ]] || asm_sid="$(detect_asm_sid_from_process || true)"
  [[ -n "$asm_sid" ]] || asm_sid="+ASM"
  if [[ "$(id -un 2>/dev/null || true)" == "$GRID_USER" ]]; then
    env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -n -u "$GRID_USER" env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
  else
    env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
  fi
}

collect_managed_storage_targets() {
  local output_file="$1"
  sql_query "$output_file" "
select name || '=' || nvl(value, '')
from v\$parameter
where name in (
  'control_files',
  'db_create_file_dest',
  'db_create_online_log_dest_1',
  'db_create_online_log_dest_2',
  'db_recovery_file_dest',
  'spfile'
)
  and value is not null
order by name;
"
}

first_managed_storage_target() {
  local evidence_file="$1"
  local value
  value="$(awk -F= '
    $2 ~ /^[@+]/ {print $2; exit}
    $2 ~ /^\\/.*(dbaas_acfs|\\/acfs\\/|^\\/acfs\\/)/ {print $2; exit}
  ' "$evidence_file" 2>/dev/null || true)"
  [[ -n "$value" ]] || value="${FRA_PATH:-${SPFILE_PATH:-FEX_ACFS_STORAGE}}"
  printf "%s" "$value"
}

print_managed_storage_evidence() {
  local evidence_file="$1"
  if [[ -s "$evidence_file" ]]; then
    echo
    echo "Managed storage destinations visible to the database:"
    sed 's/^/  /' "$evidence_file"
  fi
}

scenario_asm_diskgroup_unavailable() {
  reset_actions
  local dg_file managed_file row dg_name dg_state dg_type dg_total dg_free target_dg=""
  echo "ASM/FEX managed data storage planning helper"
  dg_file="$WORK_DIR/asm_diskgroups.lst"
  managed_file="$WORK_DIR/managed_storage_targets.lst"
  sql_query "$dg_file" "
select name || '|' || state || '|' || type || '|' || total_mb || '|' || free_mb
from v\$asm_diskgroup
order by name;
"
  collect_managed_storage_targets "$managed_file" || true
  mapfile -t TARGET_ROWS < <(trim_blank_lines <"$dg_file")
  if [[ "${#TARGET_ROWS[@]}" -eq 0 ]]; then
    print_managed_storage_evidence "$managed_file"
    if [[ "$STORAGE_TYPE" == "FEX" || "$STORAGE_TYPE" == "FEX_ACFS" || "$STORAGE_TYPE" == "ACFS" ]]; then
      target_dg="$(first_managed_storage_target "$managed_file")"
      add_action "external" "$target_dg" "FEX/ACFS managed storage outage requires provider-aware fault injection, service impact validation, and RMAN/GI recovery checks"
      execute_actions
      return "$SUCCESS"
    fi
    warn "No ASM disk groups were visible from V\$ASM_DISKGROUP."
    target_dg="+ASM_DISKGROUP"
  else
    echo
    echo "ASM disk groups visible to the database:"
    for row in "${TARGET_ROWS[@]}"; do
      IFS='|' read -r dg_name dg_state dg_type dg_total dg_free <<<"$row"
      printf "  %-12s state=%-12s type=%-8s total_mb=%-10s free_mb=%s\n" \
        "$dg_name" "$dg_state" "$dg_type" "$dg_total" "$dg_free"
      if [[ "$dg_name" == "DATA" ]]; then
        target_dg="+${dg_name}"
      fi
    done
    if [[ -z "$target_dg" ]]; then
      IFS='|' read -r dg_name dg_state dg_type dg_total dg_free <<<"${TARGET_ROWS[0]}"
      target_dg="+${dg_name}"
    fi
  fi
  add_action "external" "$target_dg" "ASM disk group outage requires explicit ASM-aware fault injection and restore/rebalance steps"
  execute_actions
}

scenario_ocr_restore_drill() {
  reset_actions
  echo "OCR restore planning helper"
  if grid_tool_available ocrcheck; then
    print_optional_tool_output "ocrcheck" run_grid_tool ocrcheck
  else
    warn "ocrcheck not found in Grid Infrastructure home or PATH."
  fi
  if grid_tool_available ocrconfig; then
    print_optional_tool_output "ocrconfig -showbackup" run_grid_tool ocrconfig -showbackup
  else
    warn "ocrconfig not found in Grid Infrastructure home or PATH."
  fi
  add_action "external" "OCR" "OCR restore practice must use a root/Grid procedure, verified OCR backups, and CRS validation"
  execute_actions
}

scenario_voting_disk_drill() {
  reset_actions
  echo "Voting disk planning helper"
  if grid_tool_available crsctl; then
    print_optional_tool_output "crsctl query css votedisk" run_grid_tool crsctl query css votedisk
  else
    warn "crsctl not found in Grid Infrastructure home or PATH."
  fi
  add_action "external" "VOTING_DISK" "Voting disk replacement practice must use a root/Grid procedure and cluster membership validation"
  execute_actions
}

scenario_asm_spfile_loss() {
  reset_actions
  local asm_spfile="" asm_config_file db_config_file
  echo "ASM/FEX managed SPFILE planning helper"
  if grid_tool_available srvctl; then
    if [[ -n "$DB_UNIQUE_NAME" ]]; then
      db_config_file="$WORK_DIR/srvctl_config_database.out"
      if run_grid_tool srvctl config database -d "$DB_UNIQUE_NAME" >"$db_config_file" 2>&1; then
        echo
        echo "srvctl config database -d ${DB_UNIQUE_NAME}:"
        sed 's/^/  /' "$db_config_file"
      else
        warn "Unable to collect srvctl database configuration for ${DB_UNIQUE_NAME}."
      fi
    fi
    asm_config_file="$WORK_DIR/srvctl_config_asm.out"
    if run_grid_tool srvctl config asm >"$asm_config_file" 2>&1; then
      echo
      echo "srvctl config asm:"
      sed 's/^/  /' "$asm_config_file"
    else
      warn "Unable to collect srvctl config asm."
    fi
  else
    warn "srvctl not found in Grid Infrastructure home or PATH."
  fi
  if grid_tool_available asmcmd; then
    asm_spfile="$(run_asmcmd_with_grid_env spget 2>/dev/null | trim_blank_lines | head -n 1 || true)"
    if [[ -n "$asm_spfile" ]]; then
      print_optional_tool_output "asmcmd spget" run_asmcmd_with_grid_env spget
    else
      warn "asmcmd spget was not available from the current OS user; use the Grid owner if ASM SPFILE path discovery is required."
    fi
  else
    warn "asmcmd not found in Grid Infrastructure home or PATH."
  fi
  if [[ -z "$asm_spfile" && "$(storage_path_class "$SPFILE_PATH")" == "fex" ]]; then
    asm_spfile="$SPFILE_PATH"
  elif [[ -z "$asm_spfile" && "$(storage_path_class "$SPFILE_PATH")" == "acfs" ]]; then
    asm_spfile="$SPFILE_PATH"
  fi
  [[ -n "$asm_spfile" ]] || asm_spfile="+ASM_SPFILE"
  if [[ "$(storage_path_class "$asm_spfile")" == "fex" ]]; then
    add_action "external" "$asm_spfile" "FEX/ACFS managed SPFILE loss requires provider-aware metadata restore, srvctl database validation, and instance restart/recovery checks"
  elif [[ "$(storage_path_class "$asm_spfile")" == "acfs" ]]; then
    add_action "external" "$asm_spfile" "ACFS-backed SPFILE loss should be practiced with an approved backup/restore wrapper, srvctl database validation, and instance restart/recovery checks"
  else
    add_action "external" "$asm_spfile" "ASM SPFILE loss requires ASM-aware backup/restore flow and Clusterware resource validation"
  fi
  execute_actions
}

collect_dgmgrl_fsfo_evidence() {
  local output_file="$1"
  local dgmgrl_bin

  dgmgrl_bin="$(find_dgmgrl_bin)"
  if [[ -z "$dgmgrl_bin" || ! -x "$dgmgrl_bin" ]]; then
    printf "dgmgrl not found in ORACLE_HOME/bin or PATH.\n" >"$output_file" || true
    return "$FAIL"
  fi
  printf 'show configuration verbose;\nshow fast_start failover;\nexit\n' |
    "$dgmgrl_bin" -silent / >"$output_file" 2>&1 || return "$FAIL"
}

write_adg_pressure_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write ADG pressure SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off termout on
set linesize 32767 trimspool on trimout on tab off

select 'CSIM_ADG|database|' ||
       'db_unique_name=' || db_unique_name ||
       '|role=' || database_role ||
       '|open_mode=' || open_mode ||
       '|flashback=' || flashback_on ||
       '|protection=' || protection_mode
from v$database;

select 'CSIM_ADG|managed_standby|' || process || '|' || status || '|' ||
       nvl(client_process, 'UNKNOWN') || '|' || nvl(sequence#, 0)
from v$managed_standby
where process in ('MRP0','MRP','RFS','LNS')
   or process like 'MRP%'
order by process;

select 'CSIM_ADG|lag|' || name || '|' || nvl(value, 'UNKNOWN') || '|' || nvl(unit, '')
from v$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;

select 'CSIM_ADG|user_session_count|' || count(*)
from v$session
where type = 'USER';

select 'CSIM_ADG|session_by_user|' || nvl(username, 'UNKNOWN') || '|' || count(*)
from v$session
where type = 'USER'
group by nvl(username, 'UNKNOWN')
order by count(*) desc, nvl(username, 'UNKNOWN');

exit
SQL
}

write_adg_pressure_report() {
  local report_file="$1"
  local evidence_file="$2"

  {
    printf "# CrashSimulator Active Data Guard Read-Only Pressure Readiness\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- Evidence file: `%s`\n\n' "$evidence_file"
    printf "This read-only scenario validates that the target is an Active Data Guard standby and captures baseline evidence before any approved reporting/query-pressure workload is introduced. It does not generate load by itself; use the evidence to size a controlled workload and monitor apply lag, user sessions, services, and Resource Manager behavior.\n\n"
  } >"$report_file" || die "Unable to write ADG pressure report: $report_file"

  append_report_section "$report_file" "Evidence"
  {
    printf '```text\n'
    sed -n '/^CSIM_ADG|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  append_report_section "$report_file" "Guardrails"
  {
    printf -- '- Run only on a standby opened `READ ONLY WITH APPLY`.\n'
    printf -- '- Keep workload read-only and disposable; do not use production reporting spikes as an unbounded stress test.\n'
    printf -- '- Monitor `V$DATAGUARD_STATS`, standby alert logs, service placement, query response time, and application retry behavior.\n'
    printf -- '- If apply lag breaches the SLA, stop the pressure workload first, then validate apply catch-up before continuing.\n'
  } >>"$report_file"
}

scenario_dg_broker_config_unavailable() {
  reset_actions
  local broker_file="$WORK_DIR/dg_broker_config_sql.lst"
  local dgmgrl_file="$WORK_DIR/dg_broker_config_dgmgrl.out"
  local broker_start

  sql_query "$broker_file" "
select 'DATABASE|' || db_unique_name || '|' || database_role || '|' || open_mode || '|' || protection_mode
from v\$database;
select 'DG_BROKER_START=' || value
from v\$parameter
where name = 'dg_broker_start';
select 'DEST|' || dest_id || '|' || nvl(status, 'UNKNOWN') || '|' || nvl(destination, 'UNKNOWN') || '|' || nvl(db_unique_name, 'UNKNOWN')
from v\$archive_dest
where target = 'STANDBY'
order by dest_id;
"
  broker_start="$(awk -F= '/^DG_BROKER_START=/ {print toupper($2); exit}' "$broker_file")"
  [[ "$broker_start" == "TRUE" ]] ||
    die "Data Guard broker is not enabled (DG_BROKER_START=${broker_start:-unknown}). Enable broker and validate DGMGRL before scenario 52."

  echo "Data Guard broker SQL evidence:"
  sed 's/^/  /' "$broker_file"
  manifest_append "dg_broker_sql_evidence" "$broker_file"

  if collect_dgmgrl_fsfo_evidence "$dgmgrl_file"; then
    echo
    echo "DGMGRL broker evidence:"
    sed 's/^/  /' "$dgmgrl_file"
    manifest_append "dg_broker_dgmgrl_evidence" "$dgmgrl_file"
  else
    warn "DGMGRL evidence was not available or broker connection failed. Scenario 52 remains plan-only until DGMGRL evidence is clean."
    manifest_append "dg_broker_dgmgrl_evidence" "$dgmgrl_file"
  fi

  add_action "external" "DG_BROKER_CONFIG" "Approved lab action only: make broker configuration unavailable or stop broker management, then validate DGMGRL/SQL warnings and restore broker configuration. CrashSimulator keeps this plan-only."
  execute_actions
}

scenario_adg_readonly_session_pressure() {
  reset_actions
  local role_file="$WORK_DIR/adg_open_mode.lst"
  local role_line open_mode sql_file evidence_file report_file

  sql_query "$role_file" "
select database_role || '|' || open_mode || '|' || nvl(guard_status, 'UNKNOWN')
from v\$database;
"
  role_line="$(trim_blank_lines <"$role_file" | head -n 1)"
  IFS='|' read -r DB_ROLE open_mode _guard_status <<<"$role_line"
  [[ "$DB_ROLE" == *"STANDBY"* ]] ||
    die "Scenario 53 requires a standby role. Current role: ${DB_ROLE:-unknown}"
  [[ "$open_mode" == "READ ONLY WITH APPLY" ]] ||
    die "Scenario 53 requires Active Data Guard open mode READ ONLY WITH APPLY. Current open mode: ${open_mode:-unknown}"

  sql_file="${LOG_DIR}/crashsim_s53_${RUN_ID}_adg_pressure.sql"
  evidence_file="${LOG_DIR}/crashsim_s53_${RUN_ID}_adg_pressure.evidence"
  report_file="${LOG_DIR}/crashsim_s53_${RUN_ID}_adg_pressure.md"
  write_adg_pressure_sql_file "$sql_file"
  manifest_append "adg_pressure_sqlfile" "$sql_file"
  manifest_append "adg_pressure_evidence" "$evidence_file"
  manifest_append "adg_pressure_report" "$report_file"

  add_action "report" "Active Data Guard read-only pressure readiness" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "ADG pressure readiness SQL failed: $sql_file (evidence: $evidence_file)"
  grep -q '^CSIM_ADG|' "$evidence_file" ||
    die "ADG pressure readiness SQL produced no evidence rows: $evidence_file"
  write_adg_pressure_report "$report_file" "$evidence_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_snapshot_standby_conversion_practice() {
  reset_actions
  local snapshot_file="$WORK_DIR/snapshot_standby_readiness.lst"
  local dgmgrl_file="$WORK_DIR/snapshot_standby_dgmgrl.out"
  local role open_mode flashback force_logging
  local line

  sql_query "$snapshot_file" "
select db_unique_name || '|' || database_role || '|' || open_mode || '|' || flashback_on || '|' || force_logging
from v\$database;
select 'RESTORE_POINT_COUNT=' || count(*)
from v\$restore_point;
select 'DG_STAT|' || name || '|' || nvl(value, 'UNKNOWN') || '|' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
"
  line="$(trim_blank_lines <"$snapshot_file" | head -n 1)"
  IFS='|' read -r _db_unique role open_mode flashback force_logging <<<"$line"
  [[ "$role" == *"STANDBY"* ]] ||
    die "Scenario 54 requires a standby role. Current role: ${role:-unknown}"
  [[ "$flashback" == "YES" ]] ||
    die "Snapshot standby conversion requires Flashback Database enabled on the standby. Current FLASHBACK_ON=${flashback:-unknown}."

  echo "Snapshot standby readiness SQL evidence:"
  sed 's/^/  /' "$snapshot_file"
  manifest_append "snapshot_standby_sql_evidence" "$snapshot_file"
  manifest_append "snapshot_standby_role" "$role"
  manifest_append "snapshot_standby_open_mode" "$open_mode"
  manifest_append "snapshot_standby_flashback_on" "$flashback"
  manifest_append "snapshot_standby_force_logging" "$force_logging"

  if collect_dgmgrl_fsfo_evidence "$dgmgrl_file"; then
    echo
    echo "DGMGRL snapshot-standby context evidence:"
    sed 's/^/  /' "$dgmgrl_file"
    manifest_append "snapshot_standby_dgmgrl_evidence" "$dgmgrl_file"
  else
    warn "DGMGRL evidence was not available; collect broker evidence manually before conversion."
    manifest_append "snapshot_standby_dgmgrl_evidence" "$dgmgrl_file"
  fi

  add_action "external" "SNAPSHOT_STANDBY_CONVERSION" "Approved standby-only action: convert to snapshot standby, run disposable write tests, convert back to physical standby, restart apply, and validate lag. CrashSimulator keeps conversion execution plan-only."
  execute_actions
}

plan_dg_transport_defer() {
  local detail="$1"
  local dest_file="$WORK_DIR/remote_standby_dest.lst"
  local row dest_id status destination db_unique_name

  query_targets "$dest_file" "
select dest_id || '|' ||
       nvl(status, 'UNKNOWN') || '|' ||
       nvl(destination, 'UNKNOWN') || '|' ||
       nvl(db_unique_name, 'UNKNOWN')
from (
  select dest_id, status, destination, db_unique_name
  from v\$archive_dest
  where target = 'STANDBY'
    and destination is not null
    and status <> 'INACTIVE'
  order by case status when 'VALID' then 1 else 2 end, dest_id
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No remote standby archive destination was found."
  row="${TARGET_ROWS[0]}"
  IFS='|' read -r dest_id status destination db_unique_name <<<"$row"
  [[ "$dest_id" =~ ^[0-9]+$ ]] || die "Unable to parse Data Guard destination metadata: ${row}"

  manifest_append "dg_dest_id" "$dest_id"
  manifest_append "dg_dest_status_before" "$status"
  manifest_append "dg_dest_destination" "$destination"
  manifest_append "dg_dest_db_unique_name" "$db_unique_name"

  add_action "sql" "alter system set log_archive_dest_state_${dest_id}=defer scope=both;" "$detail for LOG_ARCHIVE_DEST_${dest_id}"
  execute_actions
}

write_standby_redo_log_review_sql_file() {
  local sql_file="$1"
  cat >"$sql_file" <<'SQL' || die "Unable to write standby redo log review SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 200 lines 260 trimspool on tab off feedback off heading off

select 'CSIM_SRL|database_role|' || database_role from v$database;
select 'CSIM_SRL|protection_mode|' || protection_mode from v$database;
select 'CSIM_SRL|open_mode|' || open_mode from v$database;

select 'CSIM_SRL|online_thread|' || thread# ||
       '|online_groups|' || count(*) ||
       '|online_max_mb|' || round(max(bytes)/1024/1024, 2)
from v$log
group by thread#
order by thread#;

select 'CSIM_SRL|standby_thread|' || thread# ||
       '|srl_groups|' || count(*) ||
       '|srl_max_mb|' || round(max(bytes)/1024/1024, 2)
from v$standby_log
group by thread#
order by thread#;

with online_redo as (
  select thread#, count(*) online_groups, max(bytes) max_online_bytes
  from v$log
  group by thread#
),
standby_redo as (
  select thread#, count(*) srl_groups, max(bytes) max_srl_bytes
  from v$standby_log
  group by thread#
),
threads as (
  select thread# from online_redo
  union
  select thread# from standby_redo
)
select 'CSIM_SRL|thread|' || t.thread# ||
       '|online_groups|' || nvl(o.online_groups, 0) ||
       '|required_srl_groups|' || (nvl(o.online_groups, 0) + 1) ||
       '|actual_srl_groups|' || nvl(s.srl_groups, 0) ||
       '|online_max_mb|' || round(nvl(o.max_online_bytes, 0)/1024/1024, 2) ||
       '|srl_max_mb|' || round(nvl(s.max_srl_bytes, 0)/1024/1024, 2) ||
       '|status|' ||
       case
         when nvl(s.srl_groups, 0) = 0 then 'MISSING_SRLS'
         when nvl(s.srl_groups, 0) < nvl(o.online_groups, 0) + 1 then 'TOO_FEW_SRLS'
         when nvl(s.max_srl_bytes, 0) < nvl(o.max_online_bytes, 0) then 'SRL_TOO_SMALL'
         else 'OK'
       end
from threads t
left join online_redo o on o.thread# = t.thread#
left join standby_redo s on s.thread# = t.thread#
order by t.thread#;

exit
SQL
}

write_standby_redo_log_review_report() {
  local report_file="$1"
  local evidence_file="$2"
  {
    printf "# CrashSimulator Standby Redo Log Review\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- Evidence file: `%s`\n\n' "$evidence_file"
    printf "This read-only scenario checks whether standby redo logs appear to meet a common Data Guard baseline: each redo thread should have at least one more SRL group than online redo groups, and SRL size should be at least the largest online redo size for that thread.\n\n"
  } >"$report_file" || die "Unable to write standby redo log report: $report_file"

  append_report_section "$report_file" "Thread Results"
  {
    printf '```text\n'
    sed -n '/^CSIM_SRL|thread|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  append_report_section "$report_file" "Recommendations"
  {
    printf -- '- If a thread reports `MISSING_SRLS`, add standby redo logs before relying on real-time apply or low RPO.\n'
    printf -- '- If a thread reports `TOO_FEW_SRLS`, add at least enough SRL groups to reach online redo group count plus one.\n'
    printf -- '- If a thread reports `SRL_TOO_SMALL`, recreate SRLs so each thread has SRLs at least as large as the largest online redo log.\n'
    printf -- '- In RAC, validate every redo thread, not only the currently active instance.\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw Evidence"
  {
    printf '```text\n'
    sed -n '/^CSIM_SRL|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"
}

scenario_fsfo_observer_unavailable() {
  reset_actions
  local fsfo_file="$WORK_DIR/fsfo_observer_sql.lst"
  local dgmgrl_file="$WORK_DIR/fsfo_observer_dgmgrl.out"
  local line fsfo_status fsfo_target fsfo_threshold observer_present observer_seen=0

  sql_query "$fsfo_file" "
select nvl(fs_failover_status, 'UNKNOWN') || '|' ||
       nvl(fs_failover_current_target, 'UNKNOWN') || '|' ||
       nvl(to_char(fs_failover_threshold), 'UNKNOWN') || '|' ||
       nvl(fs_failover_observer_present, 'UNKNOWN')
from v\$database;
"
  line="$(trim_blank_lines <"$fsfo_file" | head -n 1)"
  IFS='|' read -r fsfo_status fsfo_target fsfo_threshold observer_present <<<"$line"
  [[ -n "$fsfo_status" ]] || die "Unable to collect FSFO status from V\$DATABASE."

  echo "FSFO SQL evidence: status=${fsfo_status}, target=${fsfo_target}, threshold=${fsfo_threshold}, observer=${observer_present}"
  if [[ "$observer_present" == "YES" ]]; then
    observer_seen=1
  fi

  if collect_dgmgrl_fsfo_evidence "$dgmgrl_file"; then
    echo
    echo "DGMGRL FSFO evidence:"
    sed 's/^/  /' "$dgmgrl_file"
    if grep -Eiq 'observer[[:space:]]*:[[:space:]]*[^[:space:](]+' "$dgmgrl_file" ||
       grep -Eiq 'observer[[:space:]_]*(host|name|present)[^:]*:[[:space:]]*[^[:space:](]+' "$dgmgrl_file"; then
      observer_seen=1
    fi
  else
    warn "DGMGRL FSFO evidence was not available; relying on SQL FSFO columns."
  fi

  [[ "$observer_seen" -eq 1 ]] ||
    die "FSFO observer was not detected. Enable FSFO and start an observer before scenario 66."

  manifest_append "fsfo_status" "$fsfo_status"
  manifest_append "fsfo_target" "$fsfo_target"
  manifest_append "fsfo_threshold" "$fsfo_threshold"
  manifest_append "fsfo_observer_present" "$observer_present"
  manifest_append "fsfo_dgmgrl_evidence" "$dgmgrl_file"

  add_action "external" "FSFO_OBSERVER" "Stop or isolate the observer host/process, then validate broker status, failover expectations, and observer restart. CrashSimulator keeps this plan-only."
  execute_actions
}

scenario_dg_apply_lag() {
  reset_actions
  local apply_file="$WORK_DIR/dg_apply_lag_process.lst"
  local lag_file="$WORK_DIR/dg_apply_lag_stats.lst"
  local row process_name process_status

  query_targets "$apply_file" "
select process || '|' || status
from (
  select process, status
  from v\$managed_standby
  where process like 'MRP%'
  order by process
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No managed standby recovery process was detected. Start apply before running scenario 67."
  row="${TARGET_ROWS[0]}"
  IFS='|' read -r process_name process_status <<<"$row"

  sql_query "$lag_file" "
select name || '=' || nvl(value, 'UNKNOWN') || ' ' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
"
  echo "Current Data Guard lag evidence:"
  sed 's/^/  /' "$lag_file"

  manifest_append "dg_apply_process" "$process_name"
  manifest_append "dg_apply_process_status" "$process_status"
  manifest_append "dg_apply_lag_evidence" "$lag_file"

  add_action "sql" "alter database recover managed standby database cancel;" "pause standby apply to create measurable apply lag"
  execute_actions
}

scenario_dg_transport_partition() {
  reset_actions
  plan_dg_transport_defer "simulate Data Guard transport network partition"
}

scenario_standby_redo_log_misconfig() {
  reset_actions
  local sql_file evidence_file report_file
  sql_file="${LOG_DIR}/crashsim_s69_${RUN_ID}_standby_redo_review.sql"
  evidence_file="${LOG_DIR}/crashsim_s69_${RUN_ID}_standby_redo_review.evidence"
  report_file="${LOG_DIR}/crashsim_s69_${RUN_ID}_standby_redo_review.md"

  write_standby_redo_log_review_sql_file "$sql_file"
  manifest_append "standby_redo_review_sqlfile" "$sql_file"
  manifest_append "standby_redo_review_evidence" "$evidence_file"
  manifest_append "standby_redo_review_report" "$report_file"

  add_action "report" "Standby redo log review" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Standby redo log review SQL failed: $sql_file (evidence: $evidence_file)"
  write_standby_redo_log_review_report "$report_file" "$evidence_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_rac_vip_relocation() {
  reset_actions
  command -v crsctl >/dev/null 2>&1 || die "crsctl not found"
  local vip_file="$WORK_DIR/rac_vip_resources.out"
  local vip_detail_file="$WORK_DIR/rac_vip_resources_detail.out"
  local vip_resource

  crsctl stat res -t >"$vip_file" 2>&1 ||
    die "Unable to collect Clusterware resource status with crsctl."
  crsctl stat res -w "TYPE = ora.cluster_vip_net1.type" -p >"$vip_detail_file" 2>&1 || true

  vip_resource="$(awk '/^ora\..*\.vip([[:space:]]|$)/ {print $1; exit}' "$vip_file")"
  if [[ -z "$vip_resource" ]]; then
    vip_resource="$(awk -F= '/^NAME=ora\..*\.vip$/ {print $2; exit}' "$vip_detail_file")"
  fi
  [[ -n "$vip_resource" ]] || die "No RAC VIP resources were visible to crsctl."

  echo "RAC VIP evidence:"
  sed 's/^/  /' "$vip_file"
  manifest_append "rac_vip_resource" "$vip_resource"
  manifest_append "rac_vip_status_evidence" "$vip_file"
  manifest_append "rac_vip_detail_evidence" "$vip_detail_file"

  add_action "external" "$vip_resource" "Relocate VIP with srvctl/crsctl under Grid owner approval, then validate client connect strings, FAN/ONS, and service failover. CrashSimulator keeps VIP movement plan-only."
  execute_actions
}

scenario_rac_service_placement_failure() {
  reset_actions
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"

  local service services_file status_file config_file status_line running source_inst
  services_file="$WORK_DIR/srvctl_services_placement.lst"
  srvctl config service -d "$DB_UNIQUE_NAME" >"$services_file" 2>&1 ||
    die "Unable to collect srvctl service configuration for ${DB_UNIQUE_NAME}."

  if [[ -n "$SERVICE_NAME" ]]; then
    service="$SERVICE_NAME"
  else
    service="$(awk -F': ' '/^Service name:/ {print $2; exit}' "$services_file")"
  fi
  [[ -n "$service" ]] || die "No srvctl-managed database service was found. Create a service before scenario 71."

  config_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_placement_config.out"
  status_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_placement_status.out"
  srvctl config service -d "$DB_UNIQUE_NAME" -s "$service" >"$config_file" 2>&1 ||
    die "Service ${service} was not found in srvctl config for ${DB_UNIQUE_NAME}."
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" >"$status_file" 2>&1 ||
    die "Unable to collect srvctl service status for ${service}."

  echo "srvctl config service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$config_file"
  echo
  echo "srvctl status service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$status_file"

  status_line="$(grep -E '^Service .* is running on instance' "$status_file" | head -n 1 || true)"
  running="$(printf "%s" "$status_line" | sed -E 's/^.*instance\(s\)[[:space:]]*//; s/[[:space:]]//g')"
  [[ -n "$running" ]] || die "Service ${service} is not running. Start it before service placement failure practice."
  source_inst="$(first_csv_value "$running" || true)"
  [[ -n "$source_inst" ]] || die "Unable to determine a running source instance for service ${service}."

  manifest_append "scenario_71_service" "$service"
  manifest_append "scenario_71_running_instances_before" "$running"
  manifest_append "scenario_71_source_instance" "$source_inst"
  manifest_append "scenario_71_config_evidence" "$config_file"
  manifest_append "scenario_71_status_evidence" "$status_file"

  add_action "srvctl_stop_start_service_instance" "$service" "$source_inst"
  execute_actions
}

scenario_asm_single_disk_failure() {
  reset_actions
  local disk_file="$WORK_DIR/asm_single_disk_candidates.lst"
  local all_disk_file="$WORK_DIR/asm_single_disk_all.lst"
  local managed_file="$WORK_DIR/managed_storage_targets.lst"
  local row dg_name dg_type disk_name failgroup disk_path mount_status header_status mode_status state target

  echo "ASM/FEX storage component failure planning helper"

  query_targets "$disk_file" "
select dg.name || '|' ||
       dg.type || '|' ||
       d.name || '|' ||
       nvl(d.failgroup, 'UNKNOWN') || '|' ||
       nvl(d.path, 'UNKNOWN') || '|' ||
       nvl(d.mount_status, 'UNKNOWN') || '|' ||
       nvl(d.header_status, 'UNKNOWN') || '|' ||
       nvl(d.mode_status, 'UNKNOWN') || '|' ||
       nvl(d.state, 'UNKNOWN')
from v\$asm_disk d
join v\$asm_diskgroup dg on dg.group_number = d.group_number
where dg.type not in ('EXTERN', 'EXTERNAL')
  and d.name is not null
  and d.mount_status = 'CACHED'
  and d.mode_status = 'ONLINE'
order by case dg.type when 'HIGH' then 1 when 'NORMAL' then 2 else 3 end,
         dg.name, d.failgroup, d.name;
"
  if [[ "${#TARGET_ROWS[@]}" -eq 0 ]]; then
    sql_query "$all_disk_file" "
select dg.name || '|' || dg.type || '|' || count(*) || ' disks'
from v\$asm_disk d
join v\$asm_diskgroup dg on dg.group_number = d.group_number
group by dg.name, dg.type
order by dg.name;
"
    if [[ -s "$all_disk_file" ]]; then
      echo "ASM disk group evidence:"
      sed 's/^/  /' "$all_disk_file"
    fi
    if [[ "$STORAGE_TYPE" == "FEX" || "$STORAGE_TYPE" == "FEX_ACFS" || "$STORAGE_TYPE" == "ACFS" ]]; then
      collect_managed_storage_targets "$managed_file" || true
      print_managed_storage_evidence "$managed_file"
      target="$(first_managed_storage_target "$managed_file")"
      add_action "external" "$target" "FEX/ACFS storage-component failure should be injected through provider-approved storage controls; validate database service continuity, GI resources, RMAN recoverability, and provider redundancy/rebuild evidence"
      execute_actions
      return "$SUCCESS"
    fi
    die "No redundant ASM disk candidate was found. Scenario 72 requires NORMAL, HIGH, FLEX, or EXTENDED redundancy with online disks."
  fi

  row="${TARGET_ROWS[0]}"
  IFS='|' read -r dg_name dg_type disk_name failgroup disk_path mount_status header_status mode_status state <<<"$row"
  [[ -n "$dg_name" && -n "$disk_name" ]] || die "Unable to parse ASM disk candidate metadata: ${row}"

  manifest_append "asm_diskgroup_name" "$dg_name"
  manifest_append "asm_diskgroup_type" "$dg_type"
  manifest_append "asm_disk_name" "$disk_name"
  manifest_append "asm_disk_failgroup" "$failgroup"
  manifest_append "asm_disk_path" "$disk_path"
  manifest_append "asm_disk_mount_status" "$mount_status"
  manifest_append "asm_disk_header_status" "$header_status"
  manifest_append "asm_disk_mode_status" "$mode_status"
  manifest_append "asm_disk_state" "$state"

  add_action "external" "${dg_name}:${disk_name}" "Single ASM disk failure should be injected only in a redundant lab. Example plan: alter diskgroup ${dg_name} offline disk ${disk_name}; monitor rebalance; restore with online/drop/add disk as appropriate."
  execute_actions
}

collect_service_continuity_evidence() {
  local evidence_file="$1"
  sql_query "$evidence_file" "
select 'DATABASE|' || name || '|' || db_unique_name || '|' || database_role || '|' || open_mode
from v\$database;
select 'SERVICE_COLUMN|' || column_name
from dba_tab_columns
where owner = 'SYS'
  and table_name = 'DBA_SERVICES'
  and column_name in (
    'NAME','NETWORK_NAME','PDB','FAILOVER_TYPE','FAILOVER_METHOD',
    'COMMIT_OUTCOME','REPLAY_INITIATION_TIMEOUT','RETENTION_TIMEOUT',
    'SESSION_STATE_CONSISTENCY','FAILOVER_RESTORE','AQ_HA_NOTIFICATIONS',
    'DRAIN_TIMEOUT','STOP_OPTION','CLB_GOAL','GOAL'
  )
order by column_name;
select 'SERVICE|' || name || '|' || nvl(network_name, 'UNKNOWN') || '|' || nvl(pdb, 'UNKNOWN')
from dba_services
where name not like 'SYS\$%'
order by name;
select 'GV_SERVICE|' || inst_id || '|' || name || '|' || nvl(network_name, 'UNKNOWN') || '|' || nvl(pdb, 'UNKNOWN')
from gv\$services
where name not like 'SYS\$%'
order by inst_id, name;
"
}

collect_scenario_srvctl_service_evidence() {
  local prefix="$1"
  local config_file="${prefix}_srvctl_config_service.out"
  local status_file="${prefix}_srvctl_status_service.out"
  local ons_file="${prefix}_srvctl_config_ons.out"
  local crs_file="${prefix}_crs_service_resources.out"

  if [[ -n "$DB_UNIQUE_NAME" ]] && grid_tool_available srvctl; then
    run_grid_tool srvctl config service -d "$DB_UNIQUE_NAME" >"$config_file" 2>&1 || true
    run_grid_tool srvctl status service -d "$DB_UNIQUE_NAME" >"$status_file" 2>&1 || true
    run_grid_tool srvctl config ons >"$ons_file" 2>&1 || true
  else
    printf "srvctl or DB_UNIQUE_NAME not available.\n" >"$config_file"
    printf "srvctl or DB_UNIQUE_NAME not available.\n" >"$status_file"
    printf "srvctl not available.\n" >"$ons_file"
  fi
  if grid_tool_available crsctl; then
    run_grid_tool crsctl stat res -t >"$crs_file" 2>&1 || true
  else
    printf "crsctl not available.\n" >"$crs_file"
  fi
  manifest_append "srvctl_service_config_evidence" "$config_file"
  manifest_append "srvctl_service_status_evidence" "$status_file"
  manifest_append "srvctl_ons_evidence" "$ons_file"
  manifest_append "crs_resource_evidence" "$crs_file"
}

write_scenario_evidence_report() {
  local report_file="$1"
  local title="$2"
  local purpose="$3"
  shift 3
  local evidence_file
  {
    printf "# %s\n\n" "$title"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    [[ -n "${TARGET_PDB:-}" ]] && printf -- '- PDB: `%s`\n' "$TARGET_PDB"
    printf '\n%s\n\n' "$purpose"
    printf "## Evidence Files\n\n"
    for evidence_file in "$@"; do
      [[ -n "$evidence_file" ]] || continue
      printf -- '- `%s`\n' "$evidence_file"
    done
    printf "\n## Guardrails\n\n"
    printf -- '- Keep this drill read-only until the exact lab topology, rollback path, and approval boundary are documented.\n'
    printf -- '- Capture before/after service, database, application, and monitoring evidence.\n'
    printf -- '- Do not claim RTO/RPO or replay success without measured client/application evidence.\n'
  } >"$report_file" || die "Unable to write report: $report_file"
}

scenario_ac_tac_replay_validation() {
  reset_actions
  local evidence_file report_file prefix
  prefix="${LOG_DIR}/crashsim_s83_${RUN_ID}_ac_tac"
  evidence_file="${prefix}.evidence"
  report_file="${prefix}.md"
  collect_service_continuity_evidence "$evidence_file"
  collect_scenario_srvctl_service_evidence "$prefix"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Application Continuity / TAC Replay Validation" \
    "This scenario validates whether services expose AC/TAC/Transaction Guard/FAN prerequisites and prepares an application replay drill. Full replay validation still requires an approved replay-safe client workload and driver/pool evidence." \
    "$evidence_file" "${prefix}_srvctl_config_service.out" "${prefix}_srvctl_status_service.out" "${prefix}_srvctl_config_ons.out"
  manifest_append "ac_tac_evidence" "$evidence_file"
  manifest_append "ac_tac_report" "$report_file"
  add_action "external" "AC_TAC_CLIENT_REPLAY" "Run an approved replay-safe client workload, trigger planned relocation or instance failure, and capture replay/FAN/application evidence; CrashSimulator keeps workload injection external."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_fan_ons_unavailable() {
  reset_actions
  local evidence_file report_file prefix onsctl_file
  prefix="${LOG_DIR}/crashsim_s84_${RUN_ID}_fan_ons"
  evidence_file="${prefix}.evidence"
  report_file="${prefix}.md"
  onsctl_file="${prefix}_onsctl.out"
  collect_service_continuity_evidence "$evidence_file"
  collect_scenario_srvctl_service_evidence "$prefix"
  if command -v onsctl >/dev/null 2>&1; then
    onsctl debug >"$onsctl_file" 2>&1 || onsctl ping >"$onsctl_file" 2>&1 || true
  else
    printf "onsctl not found in PATH.\n" >"$onsctl_file"
  fi
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator FAN / ONS Notification Availability" \
    "This scenario reviews FAN/ONS/service evidence and prepares a notification outage drill. Stopping ONS or breaking client notification paths is intentionally external because the correct action depends on Grid Infrastructure, client pools, and application failover design." \
    "$evidence_file" "${prefix}_srvctl_config_ons.out" "$onsctl_file" "${prefix}_crs_service_resources.out"
  manifest_append "fan_ons_evidence" "$evidence_file"
  manifest_append "fan_ons_report" "$report_file"
  add_action "external" "FAN_ONS_NOTIFICATION_PATH" "Approved lab action: interrupt ONS/FAN notification path, relocate/stop service, validate client reaction/replay, then restore notifications."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

collect_dg_transition_evidence() {
  local evidence_file="$1"
  sql_query "$evidence_file" "
select 'DATABASE|' || db_unique_name || '|' || database_role || '|' || open_mode || '|' || protection_mode || '|' || switchover_status || '|' || flashback_on
from v\$database;
select 'DEST|' || dest_id || '|' || nvl(status, 'UNKNOWN') || '|' || nvl(target, 'UNKNOWN') || '|' || nvl(destination, 'UNKNOWN') || '|' || nvl(db_unique_name, 'UNKNOWN') || '|' || nvl(error, 'NONE')
from v\$archive_dest
where target = 'STANDBY'
order by dest_id;
select 'DG_STAT|' || name || '|' || nvl(value, 'UNKNOWN') || '|' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
select 'SRL_COUNT|' || count(*) from v\$standby_log;
"
}

scenario_dg_switchover_drill() {
  reset_actions
  local evidence_file dgmgrl_file report_file
  evidence_file="${LOG_DIR}/crashsim_s85_${RUN_ID}_dg_switchover.evidence"
  dgmgrl_file="${LOG_DIR}/crashsim_s85_${RUN_ID}_dg_switchover_dgmgrl.out"
  report_file="${LOG_DIR}/crashsim_s85_${RUN_ID}_dg_switchover.md"
  collect_dg_transition_evidence "$evidence_file"
  collect_dgmgrl_fsfo_evidence "$dgmgrl_file" || true
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Planned Data Guard Switchover Drill" \
    "This scenario prepares a planned switchover rehearsal. Execution remains external so operators can choose the broker target, communication window, service behavior, application drain, validation, and optional switchback plan." \
    "$evidence_file" "$dgmgrl_file"
  manifest_append "dg_switchover_evidence" "$evidence_file"
  manifest_append "dg_switchover_report" "$report_file"
  add_action "external" "DG_SWITCHOVER" "Approved lab action: DGMGRL validate database/configuration, switchover to selected standby, validate role-based services/application, then document switchback/failback criteria."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_dg_failback_rehearsal() {
  reset_actions
  local evidence_file dgmgrl_file report_file
  evidence_file="${LOG_DIR}/crashsim_s86_${RUN_ID}_dg_failback.evidence"
  dgmgrl_file="${LOG_DIR}/crashsim_s86_${RUN_ID}_dg_failback_dgmgrl.out"
  report_file="${LOG_DIR}/crashsim_s86_${RUN_ID}_dg_failback.md"
  collect_dg_transition_evidence "$evidence_file"
  collect_dgmgrl_fsfo_evidence "$dgmgrl_file" || true
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Data Guard Failback Rehearsal" \
    "This scenario prepares failback/reinstate readiness after a failover or switchover. Execution remains external because the safe path depends on whether the original primary can be reinstated, flashed back, rebuilt, or switched back." \
    "$evidence_file" "$dgmgrl_file"
  manifest_append "dg_failback_evidence" "$evidence_file"
  manifest_append "dg_failback_report" "$report_file"
  add_action "external" "DG_FAILBACK_REINSTATE" "Approved lab action: validate broker state, reinstate or rebuild old primary as standby, validate apply/lag/services, then optionally switchover back."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_role_based_service_validation() {
  reset_actions
  local evidence_file report_file prefix
  prefix="${LOG_DIR}/crashsim_s87_${RUN_ID}_role_services"
  evidence_file="${prefix}.evidence"
  report_file="${prefix}.md"
  collect_service_continuity_evidence "$evidence_file"
  collect_scenario_srvctl_service_evidence "$prefix"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Role-Based Service Validation" \
    "This scenario reviews whether srvctl services are role-scoped for PRIMARY and PHYSICAL_STANDBY/ADG use. Full validation requires a switchover/failover rehearsal and application reconnect evidence." \
    "$evidence_file" "${prefix}_srvctl_config_service.out" "${prefix}_srvctl_status_service.out"
  manifest_append "role_service_evidence" "$evidence_file"
  manifest_append "role_service_report" "$report_file"
  add_action "external" "ROLE_BASED_SERVICES" "Run after an approved role transition: confirm primary services only start on primary and ADG/read-only services only start on standby role."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_pdb_pitr_drill() {
  reset_actions
  select_pdb_if_needed
  local evidence_file rman_file report_file aux_dest
  evidence_file="${LOG_DIR}/crashsim_s88_${RUN_ID}_pdb_pitr.evidence"
  rman_file="${LOG_DIR}/crashsim_s88_${RUN_ID}_pdb_pitr_preview.rman"
  report_file="${LOG_DIR}/crashsim_s88_${RUN_ID}_pdb_pitr.md"
  aux_dest="${CRASHSIM_PDB_PITR_AUX_DEST:-/tmp/crashsim_pdb_pitr_aux}"
  sql_query "$evidence_file" "
select 'DATABASE|' || db_unique_name || '|' || database_role || '|' || open_mode || '|' || log_mode || '|' || flashback_on
from v\$database;
select 'PDB|' || name || '|' || open_mode
from v\$pdbs
where name = $(sql_quote "$TARGET_PDB");
select 'DATAFILE|' || file_id || '|' || tablespace_name || '|' || file_name
from cdb_data_files
where con_id = (select con_id from v\$pdbs where name = $(sql_quote "$TARGET_PDB"))
order by file_id;
select 'BACKUP_JOB|' || nvl(status, 'UNKNOWN') || '|' || to_char(end_time, 'YYYY-MM-DD HH24:MI:SS')
from (
  select status, end_time
  from v\$rman_backup_job_details
  where end_time is not null
  order by end_time desc
)
where rownum <= 5;
"
  {
    printf "recover pluggable database %s until time \"to_date('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS')\" auxiliary destination '%s' preview;\n" "$(sql_identifier "$TARGET_PDB")" "$aux_dest"
    printf "# Replace the timestamp and auxiliary destination after approval; run preview/validate before any recovery.\n"
  } >"$rman_file" || die "Unable to write PDB PITR RMAN preview file: $rman_file"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator PDB Point-In-Time Recovery Drill" \
    "This scenario prepares PDB PITR evidence and an RMAN preview template. Actual PDB PITR is intentionally operator-approved because it can close/recover the PDB and consume auxiliary storage." \
    "$evidence_file" "$rman_file"
  manifest_append "pdb_pitr_evidence" "$evidence_file"
  manifest_append "pdb_pitr_rman_preview" "$rman_file"
  manifest_append "pdb_pitr_report" "$report_file"
  add_action "external" "PDB_PITR_${TARGET_PDB}" "Approved recovery action: select timestamp, run RMAN preview/validate, recover PDB using auxiliary destination, open/validate PDB and application."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_guaranteed_restore_point_drill() {
  reset_actions
  local evidence_file report_file sql_template flashback
  evidence_file="${LOG_DIR}/crashsim_s89_${RUN_ID}_grp.evidence"
  report_file="${LOG_DIR}/crashsim_s89_${RUN_ID}_grp.md"
  sql_template="${LOG_DIR}/crashsim_s89_${RUN_ID}_grp_template.sql"
  sql_query "$evidence_file" "
select 'DATABASE|' || name || '|' || db_unique_name || '|' || open_mode || '|' || database_role || '|' || flashback_on
from v\$database;
select 'RESTORE_POINT|' || name || '|' || guarantee_flashback_database || '|' || to_char(time, 'YYYY-MM-DD HH24:MI:SS') || '|' || storage_size
from v\$restore_point
order by time desc;
select 'FRA|' || name || '|' || space_limit || '|' || space_used || '|' || space_reclaimable
from v\$recovery_file_dest;
"
  flashback="$(awk -F'|' '/^DATABASE/ {print $6; exit}' "$evidence_file")"
  [[ "$flashback" == "YES" ]] || die "Scenario 89 requires Flashback Database enabled. Current FLASHBACK_ON=${flashback:-unknown}."
  {
    printf "create guaranteed restore point CRASHSIM_GRP_<YYYYMMDDHH24MISS>;\n"
    printf "-- execute approved change here\n"
    printf "shutdown immediate;\nstartup mount;\n"
    printf "flashback database to restore point CRASHSIM_GRP_<YYYYMMDDHH24MISS>;\n"
    printf "alter database open resetlogs;\n"
    printf "drop restore point CRASHSIM_GRP_<YYYYMMDDHH24MISS>;\n"
  } >"$sql_template" || die "Unable to write GRP template: $sql_template"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Guaranteed Restore Point Rollback Drill" \
    "This scenario validates Flashback/GRP readiness and creates an operator template for upgrade/patch/migration rollback drills. It does not create or flash back the database automatically." \
    "$evidence_file" "$sql_template"
  manifest_append "grp_evidence" "$evidence_file"
  manifest_append "grp_template" "$sql_template"
  manifest_append "grp_report" "$report_file"
  add_action "external" "GUARANTEED_RESTORE_POINT_ROLLBACK" "Approved change-window action: create GRP, execute change, flashback/open resetlogs if rollback is required, validate, and drop GRP when safe."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_database_patch_rollback_readiness() {
  reset_actions
  local evidence_file dgmgrl_file report_file
  evidence_file="${LOG_DIR}/crashsim_s90_${RUN_ID}_patch_rollback.evidence"
  dgmgrl_file="${LOG_DIR}/crashsim_s90_${RUN_ID}_patch_rollback_dgmgrl.out"
  report_file="${LOG_DIR}/crashsim_s90_${RUN_ID}_patch_rollback.md"
  sql_query "$evidence_file" "
select 'DATABASE|' || name || '|' || db_unique_name || '|' || open_mode || '|' || database_role || '|' || flashback_on || '|' || log_mode
from v\$database;
select 'REGISTRY|' || comp_id || '|' || version || '|' || status from dba_registry order by comp_id;
select 'SQLPATCH|' || patch_id || '|' || action || '|' || status || '|' || to_char(action_time, 'YYYY-MM-DD HH24:MI:SS') from dba_registry_sqlpatch order by action_time desc;
select 'RESTORE_POINT_COUNT|' || count(*) from v\$restore_point where guarantee_flashback_database = 'YES';
select 'BACKUP_JOB|' || nvl(status, 'UNKNOWN') || '|' || to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') || '|' || nvl(input_type, 'UNKNOWN')
from (
  select status, end_time, input_type
  from v\$rman_backup_job_details
  where end_time is not null
  order by end_time desc
)
where rownum <= 10;
"
  collect_dgmgrl_fsfo_evidence "$dgmgrl_file" || true
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Database Patch Rollback Readiness" \
    "This scenario reviews whether patch/upgrade rollback controls are ready: recent backups, Flashback/GRP posture, SQL patch inventory, Data Guard/Broker evidence, and service behavior." \
    "$evidence_file" "$dgmgrl_file"
  manifest_append "patch_rollback_evidence" "$evidence_file"
  manifest_append "patch_rollback_report" "$report_file"
  add_action "external" "PATCH_ROLLBACK_READINESS" "Approved lifecycle action: create baseline backup/GRP, validate standby/app services, patch in a lab, and rehearse fallback before production."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

write_platform_plan_report() {
  local report_file="$1" title="$2" purpose="$3" evidence_file="$4"
  write_scenario_evidence_report "$report_file" "$title" "$purpose" "$evidence_file"
}

scenario_exadata_plan() {
  reset_actions
  local code="$1" title="$2" focus="$3" evidence_file report_file
  evidence_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_exadata.evidence"
  report_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_exadata.md"
  {
    printf "Exadata tooling evidence generated UTC %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for tool in cellcli dcli exacli exachk; do
      printf "\n== %s ==\n" "$tool"
      command -v "$tool" 2>/dev/null || printf "not found\n"
    done
    printf "\n== database storage evidence ==\n"
  } >"$evidence_file"
  collect_managed_storage_targets "${evidence_file}.storage" || true
  cat "${evidence_file}.storage" >>"$evidence_file" 2>/dev/null || true
  write_platform_plan_report "$report_file" "$title" "$focus" "$evidence_file"
  manifest_append "${code}_evidence" "$evidence_file"
  manifest_append "${code}_report" "$report_file"
  add_action "external" "$code" "Exadata-specific fault injection requires Exadata lab approval, cell/storage evidence, monitoring, and recovery runbook validation."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_exadata_cell_failure_review() { scenario_exadata_plan "EXA01" "CrashSimulator Exadata Cell Failure Review" "Review Exadata cell failure readiness, cell status evidence, database service continuity, ASM redundancy, and storage-server repair/rebalance runbooks."; }
scenario_exadata_storage_server_outage() { scenario_exadata_plan "EXA02" "CrashSimulator Exadata Storage Server Outage" "Prepare storage-server outage validation with cell status, ASM redundancy, database service continuity, and application impact evidence."; }
scenario_exadata_smart_scan_validation() { scenario_exadata_plan "EXA03" "CrashSimulator Exadata Smart Scan Validation" "Prepare Smart Scan validation before and after storage changes, SQL plans, cell offload metrics, and performance baselines."; }
scenario_exadata_flash_cache_failure() { scenario_exadata_plan "EXA04" "CrashSimulator Exadata Flash Cache Failure" "Prepare Flash Cache failure/recovery validation with cell metrics, workload response, and repair/rebalance evidence."; }

scenario_oci_db_plan() {
  reset_actions
  local code="$1" title="$2" focus="$3" evidence_file report_file
  evidence_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_oci_db.evidence"
  report_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_oci_db.md"
  {
    printf "OCI DB evidence generated UTC %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "Host: %s\n" "$(hostname)"
    printf "\n== OCI CLI ==\n"
    command -v oci 2>/dev/null || printf "oci not found\n"
    [[ -n "${CRASHSIM_DB_SYSTEM_OCID:-}" ]] && printf "CRASHSIM_DB_SYSTEM_OCID=set\n" || printf "CRASHSIM_DB_SYSTEM_OCID=not set\n"
    [[ -n "${CRASHSIM_DB_HOME_OCID:-}" ]] && printf "CRASHSIM_DB_HOME_OCID=set\n" || printf "CRASHSIM_DB_HOME_OCID=not set\n"
    [[ -n "${CRASHSIM_DATABASE_OCID:-}" ]] && printf "CRASHSIM_DATABASE_OCID=set\n" || printf "CRASHSIM_DATABASE_OCID=not set\n"
    printf "\n== DBaaS tooling ==\n"
    for tool in /var/opt/oracle/dbaascli/dbaascli dbaascli dbcli odacli; do
      printf "%s: " "$tool"
      if command -v "$tool" >/dev/null 2>&1 || [[ -x "$tool" ]]; then
        printf "available\n"
      else
        printf "not found\n"
      fi
    done
  } >"$evidence_file"
  write_platform_plan_report "$report_file" "$title" "$focus" "$evidence_file"
  manifest_append "${code}_evidence" "$evidence_file"
  manifest_append "${code}_report" "$report_file"
  add_action "external" "$code" "OCI Base DB drill requires OCI CLI/DBaaS evidence, approved cloud-control-plane boundary, rollback path, and application validation."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_oci_db_backup_policy_validation() { scenario_oci_db_plan "OCI01" "CrashSimulator OCI Base DB Backup Policy Validation" "Validate OCI backup policy, RMAN/control-file evidence, retention, scheduling, Object Storage destination, and restore-test posture."; }
scenario_oci_cross_region_backup_recovery() { scenario_oci_db_plan "OCI02" "CrashSimulator OCI Cross-Region Backup Recovery" "Prepare cross-region backup restore validation, including target region, networking, encryption/wallets, RTO/RPO, and cleanup."; }
scenario_oci_db_system_failover() { scenario_oci_db_plan "OCI03" "CrashSimulator OCI Database System Failover" "Prepare DB system/node failure validation for OCI Base DB, including GI/RAC services, replacement procedures, and app reconnect."; }
scenario_oci_vcn_connectivity_loss() { scenario_oci_db_plan "OCI04" "CrashSimulator OCI VCN Connectivity Loss" "Prepare VCN connectivity-loss validation with route tables, NSGs, security lists, DNS, bastion, and client reconnect evidence."; }
scenario_oci_nsg_misconfiguration() { scenario_oci_db_plan "OCI05" "CrashSimulator OCI NSG Misconfiguration" "Prepare NSG/security-list misconfiguration validation with approved rollback and least-privilege evidence."; }

scenario_goldengate_plan() {
  reset_actions
  local code="$1" title="$2" focus="$3" evidence_file report_file
  evidence_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_goldengate.evidence"
  report_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_goldengate.md"
  {
    printf "GoldenGate evidence generated UTC %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for tool in ggsci adminclient oggca; do
      printf "\n== %s ==\n" "$tool"
      command -v "$tool" 2>/dev/null || printf "not found\n"
    done
    printf "\nOGG_HOME=%s\n" "${OGG_HOME:-not set}"
    printf "TNS_ADMIN=%s\n" "${TNS_ADMIN:-not set}"
  } >"$evidence_file"
  write_platform_plan_report "$report_file" "$title" "$focus" "$evidence_file"
  manifest_append "${code}_evidence" "$evidence_file"
  manifest_append "${code}_report" "$report_file"
  add_action "external" "$code" "GoldenGate drill requires approved deployment name, Extract/Replicat/trail targets, lag thresholds, and resync/recovery runbook."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_goldengate_extract_stopped() { scenario_goldengate_plan "GG01" "CrashSimulator GoldenGate Extract Stopped" "Prepare Extract stop/restart validation, checkpoint evidence, source capture lag, and downstream application impact evidence."; }
scenario_goldengate_replicat_stopped() { scenario_goldengate_plan "GG02" "CrashSimulator GoldenGate Replicat Stopped" "Prepare Replicat stop/restart validation, target apply lag, conflict handling, and resync evidence."; }
scenario_goldengate_lag_sla() { scenario_goldengate_plan "GG03" "CrashSimulator GoldenGate Lag Exceeds SLA" "Prepare GoldenGate lag threshold validation, monitoring evidence, alert routing, and catch-up behavior."; }
scenario_goldengate_trail_corruption() { scenario_goldengate_plan "GG04" "CrashSimulator GoldenGate Trail Corruption" "Prepare trail corruption/loss recovery runbook, including trail backup, reposition, resync, and data validation."; }

scenario_standby_apply_cancel() {
  reset_actions
  query_targets "$WORK_DIR/standby_apply_process.lst" "
select process || '|' || status
from (
  select process, status
  from v\$managed_standby
  where process like 'MRP%'
  order by process
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No managed standby recovery process was detected. Start apply before running scenario 50."
  add_action "sql" "alter database recover managed standby database cancel;" "cancel managed standby recovery"
  execute_actions
}

scenario_primary_transport_defer() {
  reset_actions
  plan_dg_transport_defer "defer remote archive destination"
}

scenario_rac_abort_instance() {
  reset_actions
  case "$CLUSTER_TYPE" in
    GI_SINGLE)
      add_action "srvctl_abort_database" "$DB_UNIQUE_NAME" "abort GI-managed single-instance database"
      ;;
    *)
      add_action "srvctl_abort_instance" "$INSTANCE_NAME" "abort current RAC instance"
      ;;
  esac
  execute_actions
}

csv_contains_value() {
  local csv="$1"
  local needle="$2"
  local item
  local -a csv_items
  csv="${csv// /}"
  IFS=',' read -ra csv_items <<<"$csv"
  for item in "${csv_items[@]}"; do
    [[ "$item" == "$needle" ]] && return "$SUCCESS"
  done
  return "$FAIL"
}

first_csv_value() {
  local csv="$1"
  local item
  local -a csv_items
  csv="${csv// /}"
  IFS=',' read -ra csv_items <<<"$csv"
  for item in "${csv_items[@]}"; do
    if [[ -n "$item" ]]; then
      printf "%s\n" "$item"
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

srvctl_database_instances_csv() {
  local status_file="$1"
  local instances
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  srvctl status database -d "$DB_UNIQUE_NAME" >"$status_file" 2>&1 ||
    die "Unable to collect srvctl database status for ${DB_UNIQUE_NAME}."
  instances="$(awk '/^Instance / {print $2}' "$status_file" | paste -sd, -)"
  [[ -n "$instances" ]] || return "$FAIL"
  printf "%s\n" "$instances"
}

scenario_rac_service_relocation() {
  reset_actions
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"

  local service config_file status_file db_status_file services_file
  local preferred running db_instances source_inst target_inst candidate
  local status_line service_count
  local -a service_candidates

  services_file="$WORK_DIR/srvctl_services.lst"
  srvctl config service -d "$DB_UNIQUE_NAME" >"$services_file" 2>&1 ||
    die "Unable to collect srvctl service configuration for ${DB_UNIQUE_NAME}."

  if [[ -n "$SERVICE_NAME" ]]; then
    service="$SERVICE_NAME"
  else
    service="$(awk -F': ' '/^Service name:/ {print $2; exit}' "$services_file")"
  fi
  [[ -n "$service" ]] || die "No srvctl-managed database service was found. Create a service before scenario 56."

  service_count="$(awk -F': ' '/^Service name:/ {count++} END {print count+0}' "$services_file")"
  if [[ -z "$SERVICE_NAME" && "${service_count:-0}" -gt 1 ]]; then
    warn "Multiple services were found; using first service '${service}'. Use --service-name to choose another service."
  fi

  config_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_config.out"
  status_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_status.out"
  db_status_file="$WORK_DIR/srvctl_database_status_for_services.out"

  srvctl config service -d "$DB_UNIQUE_NAME" -s "$service" >"$config_file" 2>&1 ||
    die "Service ${service} was not found in srvctl config for ${DB_UNIQUE_NAME}."
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" >"$status_file" 2>&1 ||
    die "Unable to collect srvctl service status for ${service}."

  echo "srvctl config service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$config_file"
  echo
  echo "srvctl status service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$status_file"
  echo

  preferred="$(awk -F': ' '/^Preferred instances:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$config_file")"
  status_line="$(grep -E '^Service .* is running on instance' "$status_file" | head -n 1 || true)"
  running="$(printf "%s" "$status_line" | sed -E 's/^.*instance\(s\)[[:space:]]*//; s/[[:space:]]//g')"
  [[ -n "$running" ]] || die "Service ${service} is not running. Start it before relocation/failure practice."

  db_instances="$(srvctl_database_instances_csv "$db_status_file" || true)"
  [[ -n "$db_instances" ]] || db_instances="$preferred"
  [[ -n "$db_instances" ]] || die "Unable to discover RAC database instances for scenario 56."

  source_inst="$(first_csv_value "$running" || true)"
  [[ -n "$source_inst" ]] || die "Unable to determine source instance for service ${service}."

  target_inst=""
  IFS=',' read -ra service_candidates <<<"${preferred:-$db_instances}"
  for candidate in "${service_candidates[@]}"; do
    candidate="${candidate// /}"
    [[ -n "$candidate" ]] || continue
    if ! csv_contains_value "$running" "$candidate"; then
      target_inst="$candidate"
      break
    fi
  done
  if [[ -z "$target_inst" ]]; then
    IFS=',' read -ra service_candidates <<<"$db_instances"
    for candidate in "${service_candidates[@]}"; do
      candidate="${candidate// /}"
      [[ -n "$candidate" ]] || continue
      if ! csv_contains_value "$running" "$candidate"; then
        target_inst="$candidate"
        break
      fi
    done
  fi

  manifest_append "scenario_56_service" "$service"
  manifest_append "scenario_56_running_instances_before" "$running"
  manifest_append "scenario_56_preferred_instances" "$preferred"
  manifest_append "scenario_56_database_instances" "$db_instances"

  if [[ -n "$target_inst" ]]; then
    manifest_append "scenario_56_mode" "relocate"
    manifest_append "scenario_56_source_instance" "$source_inst"
    manifest_append "scenario_56_target_instance" "$target_inst"
    add_action "srvctl_relocate_service" "$service" "${source_inst}|${target_inst}"
  else
    manifest_append "scenario_56_mode" "stop_start_instance"
    manifest_append "scenario_56_source_instance" "$source_inst"
    add_action "srvctl_stop_start_service_instance" "$service" "$source_inst"
  fi
  execute_actions
}

scenario_tde_wallet() {
  reset_actions
  local wallet_file="$WORK_DIR/wallet.env"
  sql_query "$wallet_file" "
select name || '=' || nvl(value, '')
from v\$parameter
where name in ('wallet_root','tde_configuration');
"
  local wallet_root=""
  while IFS='=' read -r param_name param_value; do
    if [[ "$param_name" == "wallet_root" ]]; then
      wallet_root="$param_value"
    fi
  done < <(trim_blank_lines <"$wallet_file")
  [[ -n "$wallet_root" ]] || die "No wallet_root parameter was detected."
  TARGET_ROWS=("$wallet_root")
  add_fs_rename_targets
  execute_actions
}

scenario_archivelog_loss() {
  reset_actions
  query_targets "$WORK_DIR/archivelog_loss.lst" "
select name
from (
  select name
  from v\$archived_log
  where name is not null
    and nvl(deleted, 'NO') = 'NO'
  order by completion_time desc
)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
}

scenario_fra_full() {
  reset_actions
  local fra_file="$WORK_DIR/fra_pressure.lst"
  local fra_line fra_name space_limit space_used space_reclaimable target_size headroom_bytes
  local sql_file sql_log

  query_targets "$fra_file" "
select name || '|' ||
       to_char(space_limit) || '|' ||
       to_char(space_used) || '|' ||
       to_char(space_reclaimable)
from v\$recovery_file_dest
where space_limit > 0;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No configured FRA destination was found in V\$RECOVERY_FILE_DEST."
  fra_line="${TARGET_ROWS[0]}"
  IFS='|' read -r fra_name space_limit space_used space_reclaimable <<<"$fra_line"
  [[ "$space_limit" =~ ^[0-9]+$ && "$space_used" =~ ^[0-9]+$ ]] ||
    die "Unable to parse FRA size evidence: ${fra_line}"
  [[ "$space_used" -gt 0 ]] ||
    die "FRA usage is zero. Generate archived redo or a small lab backup before running scenario 61."

  headroom_bytes=$((FRA_PRESSURE_HEADROOM_MB * 1024 * 1024))
  target_size="$(awk -v used="$space_used" -v pct="$FRA_PRESSURE_TARGET_PCT" -v headroom="$headroom_bytes" '
    BEGIN {
      by_pct = int((used * 100 / pct) + 0.999)
      by_headroom = used + headroom
      target = by_pct > by_headroom ? by_pct : by_headroom
      print target
    }')"
  [[ "$target_size" =~ ^[0-9]+$ ]] || die "Unable to calculate FRA pressure target size."
  if [[ "$target_size" -ge "$space_limit" ]]; then
    die "FRA pressure cannot be simulated by shrinking DB_RECOVERY_FILE_DEST_SIZE: current limit=${space_limit}, used=${space_used}, calculated target=${target_size}. Lower --fra-pressure-headroom-mb or generate more FRA usage in a lab."
  fi

  sql_file="${LOG_DIR}/crashsim_s61_${RUN_ID}_fra_pressure.sql"
  sql_log="${LOG_DIR}/crashsim_s61_${RUN_ID}_fra_pressure.log"
  write_fra_pressure_sql_file "$sql_file" "$space_limit" "$target_size"

  manifest_append "fra_name" "$fra_name"
  manifest_append "fra_original_size_bytes" "$space_limit"
  manifest_append "fra_space_used_bytes" "$space_used"
  manifest_append "fra_space_reclaimable_bytes" "$space_reclaimable"
  manifest_append "fra_pressure_target_size_bytes" "$target_size"
  manifest_append "fra_pressure_target_pct" "$FRA_PRESSURE_TARGET_PCT"
  manifest_append "fra_pressure_headroom_mb" "$FRA_PRESSURE_HEADROOM_MB"
  manifest_append "fra_pressure_sqlfile" "$sql_file"
  manifest_append "fra_pressure_log" "$sql_log"

  add_action "sqlfile" "$sql_file" "$sql_log"
  execute_actions
}

scenario_required_archivelog_recovery_gap() {
  reset_actions
  local archive_file="$WORK_DIR/required_archivelog_gap.lst"
  local row archive_name thread_no sequence_no first_change next_change completion_time rman_file

  query_targets "$archive_file" "
select name || '|' ||
       thread# || '|' ||
       sequence# || '|' ||
       first_change# || '|' ||
       next_change# || '|' ||
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS')
from (
  select name, thread#, sequence#, first_change#, next_change#, completion_time
  from v\$archived_log
  where name is not null
    and nvl(deleted, 'NO') = 'NO'
    and nvl(standby_dest, 'NO') = 'NO'
    and completion_time is not null
  order by completion_time desc
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No available local archived redo log was found for required-recovery simulation."
  row="${TARGET_ROWS[0]}"
  IFS='|' read -r archive_name thread_no sequence_no first_change next_change completion_time <<<"$row"
  [[ -n "$archive_name" && "$sequence_no" =~ ^[0-9]+$ && "$thread_no" =~ ^[0-9]+$ ]] ||
    die "Unable to parse archived-log candidate metadata: ${row}"

  rman_file="${LOG_DIR}/crashsim_s62_${RUN_ID}_recovery_decision.rman"
  {
    printf "crosscheck archivelog thread %s sequence %s;\n" "$thread_no" "$sequence_no"
    printf "list archivelog thread %s sequence %s;\n" "$thread_no" "$sequence_no"
    printf "restore archivelog thread %s sequence %s validate;\n" "$thread_no" "$sequence_no"
    printf "recover database preview;\n"
  } >"$rman_file" || die "Unable to write scenario 62 RMAN decision file: $rman_file"

  manifest_append "archivelog_name" "$archive_name"
  manifest_append "archivelog_thread" "$thread_no"
  manifest_append "archivelog_sequence" "$sequence_no"
  manifest_append "archivelog_first_change" "$first_change"
  manifest_append "archivelog_next_change" "$next_change"
  manifest_append "archivelog_completion_time" "$completion_time"
  manifest_append "archivelog_recovery_decision_rman" "$rman_file"

  if [[ "$archive_name" == +* ]]; then
    add_action "external" "$archive_name" "ASM archived-log removal requires an ASM-aware handler; RMAN decision file: ${rman_file}"
  else
    add_action "fs_rename" "$archive_name" "thread=${thread_no} sequence=${sequence_no}; RMAN decision file: ${rman_file}"
  fi
  execute_actions
}

scenario_temp_exhaustion() {
  reset_actions
  local temp_file="$WORK_DIR/temp_exhaustion.lst"
  local container_clause="" target_context="root/non-CDB" sql_file sql_log
  local target_pdb_literal

  if [[ "$DB_CDB" == "YES" && -n "$TARGET_PDB" ]]; then
    target_pdb_literal="$(sql_quote "$TARGET_PDB")"
    query_targets "$temp_file" "
select p.name || '|' || tf.tablespace_name || '|' || count(*) || '|' || to_char(sum(tf.bytes))
from cdb_temp_files tf
join v\$pdbs p on p.con_id = tf.con_id
where p.name = ${target_pdb_literal}
group by p.name, tf.tablespace_name
order by tf.tablespace_name;
"
    container_clause="alter session set container = ${TARGET_PDB};"
    target_context="PDB ${TARGET_PDB}"
  else
    query_targets "$temp_file" "
select 'CDB\$ROOT' || '|' || tablespace_name || '|' || count(*) || '|' || to_char(sum(bytes))
from dba_temp_files
group by tablespace_name
order by tablespace_name;
"
  fi
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No temporary tablespace/tempfile metadata was found for ${target_context}."

  sql_file="${LOG_DIR}/crashsim_s63_${RUN_ID}_temp_exhaustion.sql"
  sql_log="${LOG_DIR}/crashsim_s63_${RUN_ID}_temp_exhaustion.log"
  write_temp_exhaustion_sql_file "$sql_file" "$container_clause" "$TEMP_EXHAUST_MB"

  manifest_append "temp_exhaustion_context" "$target_context"
  manifest_append "temp_exhaustion_target_mb" "$TEMP_EXHAUST_MB"
  manifest_append "temp_exhaustion_sqlfile" "$sql_file"
  manifest_append "temp_exhaustion_log" "$sql_log"

  add_action "sqlfile" "$sql_file" "$sql_log"
  execute_actions
}

scenario_rto_validation() {
  reset_actions
  local report_file
  report_file="${LOG_DIR}/crashsim_rto_validation_${RUN_ID}.md"
  manifest_append "rto_validation_report" "$report_file"
  add_action "report" "RTO validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  write_rto_validation_report "$report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_rpo_validation() {
  reset_actions
  local sql_file evidence_file report_file
  sql_file="${LOG_DIR}/crashsim_rpo_validation_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_rpo_validation_${RUN_ID}.evidence"
  report_file="${LOG_DIR}/crashsim_rpo_validation_${RUN_ID}.md"
  manifest_append "rpo_validation_sqlfile" "$sql_file"
  manifest_append "rpo_validation_evidence" "$evidence_file"
  manifest_append "rpo_validation_report" "$report_file"
  add_action "report" "RPO validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  ensure_sqlplus
  write_rpo_validation_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "RPO validation SQL failed: $sql_file (evidence: $evidence_file)"
  parse_rpo_evidence_file "$evidence_file"
  write_rpo_validation_report "$report_file" "$evidence_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

apex_ords_container_sql_prefix() {
  local target_pdb
  target_pdb="$(apex_ords_report_target_pdb)"
  if [[ -n "$target_pdb" ]]; then
    printf "alter session set container = %s;\n" "$(sql_identifier "$target_pdb")"
  fi
}

query_apex_ords_runtime_user() {
  local output_file="$1"
  local container_sql
  container_sql="$(apex_ords_container_sql_prefix)"
  query_targets "$output_file" "
${container_sql}
select username
from (
  select username
  from dba_users
  where username in ('APEX_PUBLIC_USER','ORDS_PUBLIC_USER')
    and account_status not like '%LOCKED%'
  order by case username when 'APEX_PUBLIC_USER' then 1 else 2 end
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]]
}

apex_installed_in_target_container() {
  local output_file="$WORK_DIR/apex_installed_check.out"
  local container_sql
  local apex_count
  container_sql="$(apex_ords_container_sql_prefix)"
  query_targets "$output_file" "
${container_sql}
select count(*)
from dba_registry
where comp_id = 'APEX'
   or upper(comp_name) like '%APEX%';
"
  apex_count="$(printf "%s" "${TARGET_ROWS[0]:-}" | tr -d '[:space:]')"
  [[ "${#TARGET_ROWS[@]}" -gt 0 && "$apex_count" =~ ^[0-9]+$ && "$apex_count" -gt 0 ]]
}

resolve_ords_continuity_url() {
  if [[ -n "$ORDS_LB_URL" ]]; then
    printf "%s" "$ORDS_LB_URL"
    return "$SUCCESS"
  fi

  command -v curl >/dev/null 2>&1 || return "$FAIL"
  local candidate
  candidate="http://localhost:18080/ords/"
  if [[ "$candidate" != "$ORDS_URL" ]] && curl -fsS -L --max-time 5 "$candidate" >/dev/null 2>&1; then
    printf "%s" "$candidate"
    return "$SUCCESS"
  fi

  command -v olsnodes >/dev/null 2>&1 || return "$FAIL"

  local current_host node
  current_host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
  while read -r node _; do
    [[ -n "$node" ]] || continue
    [[ "$node" == "$current_host" ]] && continue
    candidate="http://${node}:8080/ords/"
    if curl -fsS -L --max-time 5 "$candidate" >/dev/null 2>&1; then
      printf "%s" "$candidate"
      return "$SUCCESS"
    fi
  done < <(olsnodes 2>/dev/null || true)

  return "$FAIL"
}

write_apex_ords_smoke_report() {
  local report_file="$1"
  local title="$2"
  local url_status="not checked"
  local lb_status="not supplied"

  if command -v curl >/dev/null 2>&1; then
    if curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1; then
      url_status="OK"
    else
      url_status="FAILED"
    fi
    if [[ -n "$ORDS_LB_URL" ]]; then
      if curl -fsS -L --max-time 10 "$ORDS_LB_URL" >/dev/null 2>&1; then
        lb_status="OK"
      else
        lb_status="FAILED"
      fi
    fi
  else
    url_status="curl not found"
    lb_status="curl not found"
  fi

  {
    printf "# %s\n\n" "$title"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- ORDS URL: `%s`\n' "$ORDS_URL"
    printf -- '- ORDS URL status: `%s`\n' "$url_status"
    printf -- '- ORDS load balancer URL: `%s`\n' "${ORDS_LB_URL:-not supplied}"
    printf -- '- ORDS load balancer status: `%s`\n' "$lb_status"
    printf "\n"
    printf "| Check | Result |\n"
    printf "| --- | --- |\n"
    printf '| ORDS smoke URL | `%s` |\n' "$(md_escape "$url_status")"
    printf '| Load balancer smoke URL | `%s` |\n' "$(md_escape "$lb_status")"
    printf "\nUse this smoke evidence together with application-specific APEX page URLs, login/session checks, and PDB/service health after database recovery.\n"
  } >"$report_file" || die "Unable to write APEX/ORDS smoke report: $report_file"
}

scenario_ords_service_unavailable() {
  reset_actions
  command -v ords >/dev/null 2>&1 ||
    die "ORDS binary was not found. Install ORDS before running ORDS service scenarios."
  ords_service_unit_exists ||
    die "ORDS systemd service unit was not found for service ${ORDS_SERVICE_NAME}."

  manifest_append "ords_service_name" "$ORDS_SERVICE_NAME"
  if can_control_ords_service; then
    add_action "systemctl_stop_service" "$ORDS_SERVICE_NAME" "simulate ORDS service outage; recover with --recover 73"
  else
    add_action "external" "$ORDS_SERVICE_NAME" "ORDS service control requires root or passwordless sudo for the current OS user"
  fi
  execute_actions
}

scenario_ords_config_unavailable() {
  reset_actions
  [[ -d "$ORDS_CONFIG_DIR" ]] ||
    die "ORDS configuration directory was not found: ${ORDS_CONFIG_DIR}."

  manifest_append "ords_config_dir" "$ORDS_CONFIG_DIR"
  if [[ -w "$ORDS_CONFIG_DIR" && -w "$(dirname "$ORDS_CONFIG_DIR")" ]]; then
    add_action "fs_rename" "$ORDS_CONFIG_DIR" "simulate ORDS configuration loss"
  elif ords_priv_helper_config_available; then
    add_action "ords_priv_config_rename" "$ORDS_CONFIG_DIR" "simulate ORDS configuration loss with approved helper; recover with --recover 74"
  else
    add_action "external" "$ORDS_CONFIG_DIR" "ORDS config directory is not writable by $(id -un); run with approved OS privileges or restore from config backup"
  fi
  execute_actions
}

scenario_ords_pool_misconfiguration() {
  reset_actions
  command -v ords >/dev/null 2>&1 ||
    die "ORDS binary was not found. Install ORDS before running ORDS pool scenarios."
  [[ -d "$ORDS_CONFIG_DIR" ]] ||
    die "ORDS configuration directory was not found: ${ORDS_CONFIG_DIR}."

  manifest_append "ords_config_dir" "$ORDS_CONFIG_DIR"
  manifest_append "ords_db_pool" "$ORDS_DB_POOL"
  if can_control_ords_service; then
    add_action "ords_pool_bad_service" "${ORDS_CONFIG_DIR}:${ORDS_DB_POOL}" "set db.servicename to a lab-bad value, restart ORDS, then recover with --recover 75"
  else
    add_action "external" "${ORDS_CONFIG_DIR}:${ORDS_DB_POOL}" "ORDS pool drill requires approved ORDS service restart privileges to mutate config and recover safely."
  fi
  execute_actions
}

scenario_apex_runtime_account_locked() {
  reset_actions
  local user_file runtime_user container_sql
  user_file="$WORK_DIR/apex_runtime_user.lst"
  query_apex_ords_runtime_user "$user_file" ||
    die "No unlocked APEX/ORDS runtime account was found. Install/configure APEX/ORDS or unlock APEX_PUBLIC_USER/ORDS_PUBLIC_USER first."
  runtime_user="${TARGET_ROWS[0]}"
  validate_oracle_name "$runtime_user" || die "Invalid runtime user discovered: $runtime_user"
  container_sql="$(apex_ords_container_sql_prefix)"

  manifest_append "apex_runtime_user" "$runtime_user"
  manifest_append "apex_runtime_target_container" "$(apex_ords_report_target_pdb || true)"
  add_action "sql" "${container_sql}alter user ${runtime_user} account lock;" "lock APEX/ORDS runtime account ${runtime_user}"
  execute_actions
}

scenario_apex_static_resources_unavailable() {
  reset_actions
  local images_dir
  images_dir="$(detect_apex_images_dir)" ||
    die "No APEX images/static files directory was found. Set --apex-images-dir or CRASHSIM_APEX_IMAGES_DIR after installing APEX static files."

  manifest_append "apex_images_dir" "$images_dir"
  if [[ -w "$images_dir" && -w "$(dirname "$images_dir")" ]]; then
    add_action "fs_rename" "$images_dir" "simulate missing APEX static files/images"
  else
    add_action "external" "$images_dir" "APEX static directory is not writable by $(id -un); run with approved OS privileges or use a writable lab static path"
  fi
  execute_actions
}

scenario_apex_application_availability_validation() {
  reset_actions
  command -v curl >/dev/null 2>&1 || die "curl was not found; cannot validate ORDS/APEX URL."
  curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1 ||
    die "ORDS/APEX smoke URL is not reachable now: ${ORDS_URL}."

  local report_file
  report_file="${LOG_DIR}/crashsim_apex_availability_s78_${RUN_ID}.md"
  manifest_append "apex_availability_report" "$report_file"
  add_action "report" "APEX/ORDS availability smoke validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  write_apex_ords_smoke_report "$report_file" "CrashSimulator APEX / ORDS Availability Smoke Evidence"
  cat "$report_file"
  maybe_render_html "$report_file"
}

run_apex_session_driver() {
  local report_file="$1"
  local session_url output_dir output_file headless_value
  local -a driver_cmd=()

  [[ -n "$APEX_SESSION_DRIVER" ]] || return "$SUCCESS"
  [[ -x "$APEX_SESSION_DRIVER" ]] ||
    die "APEX session driver is not executable: ${APEX_SESSION_DRIVER}"

  session_url="${APEX_SESSION_URL:-$ORDS_URL}"
  output_dir="${LOG_DIR}/apex_session_driver_s80_${RUN_ID}"
  output_file="${LOG_DIR}/crashsim_apex_session_driver_s80_${RUN_ID}.out"
  headless_value="true"
  [[ "$APEX_SESSION_HEADLESS" -eq 0 ]] && headless_value="false"

  manifest_append "apex_session_driver" "$APEX_SESSION_DRIVER"
  manifest_append "apex_session_driver_url" "$session_url"
  manifest_append "apex_session_driver_output_dir" "$output_dir"
  manifest_append "apex_session_driver_output_file" "$output_file"
  [[ -n "$APEX_SESSION_USERNAME" ]] && manifest_append "apex_session_driver_username" "$APEX_SESSION_USERNAME"
  [[ -n "$APEX_SESSION_SUCCESS_SELECTOR" ]] && manifest_append "apex_session_driver_success_selector" "$APEX_SESSION_SUCCESS_SELECTOR"

  driver_cmd=(
    "$APEX_SESSION_DRIVER"
    "--url" "$session_url"
    "--output-dir" "$output_dir"
    "--duration" "$APEX_SESSION_DURATION"
    "--interval" "$APEX_SESSION_INTERVAL"
    "--headless" "$headless_value"
    "--label" "scenario-80-${RUN_ID}"
  )
  [[ -n "$APEX_SESSION_USERNAME" ]] && driver_cmd+=("--username" "$APEX_SESSION_USERNAME")
  [[ -n "$APEX_SESSION_SUCCESS_SELECTOR" ]] && driver_cmd+=("--success-selector" "$APEX_SESSION_SUCCESS_SELECTOR")
  [[ -n "$APEX_SESSION_USERNAME_SELECTOR" ]] && driver_cmd+=("--username-selector" "$APEX_SESSION_USERNAME_SELECTOR")
  [[ -n "$APEX_SESSION_PASSWORD_SELECTOR" ]] && driver_cmd+=("--password-selector" "$APEX_SESSION_PASSWORD_SELECTOR")
  [[ -n "$APEX_SESSION_SUBMIT_SELECTOR" ]] && driver_cmd+=("--submit-selector" "$APEX_SESSION_SUBMIT_SELECTOR")

  echo "Running APEX browser-session driver: ${APEX_SESSION_DRIVER}"
  echo "Driver URL: ${session_url}"
  echo "Driver output directory: ${output_dir}"

  if CRASHSIM_APEX_SESSION_PASSWORD="$APEX_SESSION_PASSWORD" "${driver_cmd[@]}" >"$output_file" 2>&1; then
    manifest_append "apex_session_driver_status" "completed"
  else
    manifest_append "apex_session_driver_status" "failed"
    cat "$output_file" || true
    die "APEX browser-session driver failed. Output: ${output_file}"
  fi

  {
    printf "\n## Browser Session Driver\n\n"
    printf -- '- Driver: `%s`\n' "$(md_escape "$APEX_SESSION_DRIVER")"
    printf -- '- Session URL: `%s`\n' "$(md_escape "$session_url")"
    printf -- '- Duration seconds: `%s`\n' "$APEX_SESSION_DURATION"
    printf -- '- Interval seconds: `%s`\n' "$APEX_SESSION_INTERVAL"
    printf -- '- Headless: `%s`\n' "$headless_value"
    printf -- '- Driver output directory: `%s`\n' "$(md_escape "$output_dir")"
    printf -- '- Driver stdout/JSON: `%s`\n' "$(md_escape "$output_file")"
    if [[ -f "${output_dir}/apex_session_driver_report.md" ]]; then
      printf -- '- Driver Markdown report: `%s`\n' "$(md_escape "${output_dir}/apex_session_driver_report.md")"
    fi
    printf "\nDriver result JSON:\n\n"
    printf '```json\n'
    cat "$output_file"
    printf '\n```\n'
  } >>"$report_file" || die "Unable to append browser-session driver evidence: $report_file"
}

scenario_ords_lb_node_unavailable() {
  reset_actions
  local continuity_url report_file continuity_status
  command -v ords >/dev/null 2>&1 ||
    die "ORDS binary was not found. Install ORDS before running ORDS node-outage scenarios."
  ords_service_unit_exists ||
    die "ORDS systemd service unit was not found for service ${ORDS_SERVICE_NAME}."
  continuity_url="$(resolve_ords_continuity_url)" ||
    die "Scenario 79 requires --ords-lb-url/CRASHSIM_ORDS_LB_URL or a reachable peer ORDS node to validate continuity."

  manifest_append "ords_service_name" "$ORDS_SERVICE_NAME"
  manifest_append "ords_lb_url" "$continuity_url"
  if [[ -z "$ORDS_LB_URL" ]]; then
    manifest_append "ords_lb_url_source" "auto-detected peer ORDS URL"
  else
    manifest_append "ords_lb_url_source" "supplied"
  fi
  if can_control_ords_service; then
    add_action "systemctl_stop_service" "$ORDS_SERVICE_NAME" "simulate one ORDS node down behind load balancer; recover with --recover 79"
  else
    add_action "external" "$ORDS_SERVICE_NAME" "ORDS service control requires root or passwordless sudo for the current OS user"
  fi
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  continuity_status="NOT_REACHABLE"
  if curl -fsS -L --max-time 10 "$continuity_url" >/dev/null 2>&1; then
    continuity_status="OK"
  fi
  report_file="${LOG_DIR}/crashsim_ords_lb_node_s79_${RUN_ID}.md"
  manifest_append "ords_lb_node_report" "$report_file"
  manifest_append "ords_lb_node_continuity_status" "$continuity_status"
  {
    printf "# CrashSimulator ORDS Node Continuity Evidence\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Stopped local ORDS service: `%s`\n' "$ORDS_SERVICE_NAME"
    printf -- '- Continuity URL: `%s`\n' "$continuity_url"
    printf -- '- Continuity status: `%s`\n' "$continuity_status"
    printf "\nUse a real load balancer URL for production-grade validation. An auto-detected peer ORDS URL is acceptable for lab continuity practice but does not validate load-balancer health checks or routing policy.\n"
  } >"$report_file" || die "Unable to write scenario 79 report: $report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
  [[ "$continuity_status" == "OK" ]] ||
    die "Continuity URL was not reachable after stopping local ORDS service: ${continuity_url}"
}

scenario_apex_session_continuity() {
  reset_actions
  apex_installed_in_target_container ||
    die "APEX is not installed in the selected target container; session continuity evidence is not available yet."
  command -v curl >/dev/null 2>&1 || die "curl was not found; cannot validate ORDS/APEX URL."
  curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1 ||
    die "ORDS/APEX smoke URL is not reachable now: ${ORDS_URL}."
  if [[ -n "$APEX_SESSION_DRIVER" ]]; then
    [[ -x "$APEX_SESSION_DRIVER" ]] ||
      die "APEX session driver is not executable: ${APEX_SESSION_DRIVER}"
    "$APEX_SESSION_DRIVER" --self-check >/dev/null 2>&1 ||
      die "APEX session driver self-check failed: ${APEX_SESSION_DRIVER}. Verify Node.js, Playwright, and the Chromium browser runtime on this host."
    if [[ -n "$APEX_SESSION_USERNAME" && -z "$APEX_SESSION_PASSWORD" ]]; then
      die "APEX session username was supplied but CRASHSIM_APEX_SESSION_PASSWORD/--apex-session-password is empty."
    fi
  fi

  local report_file continuity_url continuity_status
  report_file="${LOG_DIR}/crashsim_apex_session_continuity_s80_${RUN_ID}.md"
  continuity_url="$(resolve_ords_continuity_url || true)"
  continuity_status="not supplied"
  if [[ -n "$continuity_url" ]]; then
    if curl -fsS -L --max-time 10 "$continuity_url" >/dev/null 2>&1; then
      continuity_status="OK"
    else
      continuity_status="NOT_REACHABLE"
    fi
  fi

  manifest_append "apex_session_continuity_report" "$report_file"
  manifest_append "apex_session_ords_url" "$ORDS_URL"
  [[ -n "$continuity_url" ]] && manifest_append "apex_session_continuity_url" "$continuity_url"
  add_action "report" "APEX session continuity evidence" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  {
    printf "# CrashSimulator APEX Session Continuity Evidence\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Target PDB: `%s`\n' "$(apex_ords_report_target_pdb || true)"
    printf -- '- ORDS URL: `%s`\n' "$ORDS_URL"
    printf -- '- Continuity URL: `%s`\n' "${continuity_url:-not supplied}"
    printf -- '- Continuity URL status: `%s`\n' "$continuity_status"
    printf "\n| Check | Result |\n"
    printf "| --- | --- |\n"
    printf '| ORDS/APEX smoke URL | `OK` |\n'
    printf '| Continuity or peer URL | `%s` |\n' "$(md_escape "$continuity_status")"
    if [[ -n "$APEX_SESSION_DRIVER" ]]; then
      printf "\nA seeded APEX browser-session driver is configured. Driver evidence will be appended below.\n"
    else
      printf '\nNo seeded browser-session driver was configured. Use `--apex-session-driver` with a seeded APEX application URL when full end-user behavior capture is needed.\n'
    fi
    printf "\nUse this report during a live APEX browser session. Record whether the user sees seamless continuation, retry, relogin, lost page state, or failed transaction after ORDS/RAC/service/database failover.\n"
  } >"$report_file" || die "Unable to write scenario 80 report: $report_file"
  run_apex_session_driver "$report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_apex_mail_config_validation() {
  reset_actions
  apex_installed_in_target_container ||
    die "APEX is not installed in the selected target container; mail configuration validation is not available yet."

  local report_file
  report_file="${LOG_DIR}/crashsim_apex_mail_s81_${RUN_ID}.md"
  manifest_append "apex_mail_report" "$report_file"
  add_action "report" "APEX mail/SMTP/wallet/ACL validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  {
    printf "# CrashSimulator APEX Mail Configuration Validation\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Target PDB: `%s`\n' "$(apex_ords_report_target_pdb || true)"
    printf -- '- Detailed APEX/ORDS report: run `./%s --apex-ords-report --pdb %s --html`\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf "\nValidation focus: SMTP parameters, wallet/TLS dependencies, network ACLs, failed mail queue evidence, and post-recovery notification testing.\n"
  } >"$report_file" || die "Unable to write scenario 81 report: $report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_apex_patch_rollback_readiness() {
  reset_actions
  apex_installed_in_target_container ||
    die "APEX is not installed in the selected target container; upgrade/rollback readiness is not available yet."

  local report_file
  report_file="${LOG_DIR}/crashsim_apex_patch_readiness_s82_${RUN_ID}.md"
  manifest_append "apex_patch_readiness_report" "$report_file"
  add_action "report" "APEX upgrade/patch rollback readiness" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  {
    printf "# CrashSimulator APEX Upgrade / Patch Rollback Readiness\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Target PDB: `%s`\n' "$(apex_ords_report_target_pdb || true)"
    printf -- '- ORDS version command: `ords --version`\n'
    printf "\nCapture APEX version/component status, invalid objects, runtime-user state, ORDS config/static-file backups, and representative application smoke checks before and after upgrade or rollback.\n"
  } >"$report_file" || die "Unable to write scenario 82 report: $report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_planned() {
  local id="$1"
  echo "Scenario ${id} is registered but gated for a topology that is not available in this environment yet."
  echo "It is intentionally present so RAC, Data Guard, and ASM coverage can be tested as those labs are provided."
  echo "No destructive action was planned or executed."
}

