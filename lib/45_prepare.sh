run_project_tool() {
  local tool_name="$1"
  shift
  local tool_path
  tool_path="$(script_dir)/tools/${tool_name}"
  [[ -f "$tool_path" ]] || die "Required helper was not found: $tool_path"
  if [[ -x "$tool_path" ]]; then
    "$tool_path" "$@"
  else
    bash "$tool_path" "$@"
  fi
}

run_secret_scan() {
  run_project_tool "crashsim_secret_scan.sh" "$SECRET_SCAN_PATH"
}

run_sanitize_artifacts() {
  local -a args=("--source" "$SANITIZE_SOURCE_DIR")
  [[ -n "$SANITIZE_OUTPUT_DIR" ]] && args+=("--output" "$SANITIZE_OUTPUT_DIR")
  run_project_tool "crashsim_sanitize_artifacts.sh" "${args[@]}"
}

run_release_check() {
  run_project_tool "crashsim_release_check.sh"
}

run_node_sync_check() {
  run_project_tool "crashsim_node_sync_check.sh"
}

write_builtin_health_check_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write health-check SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
column name format a30
column database_role format a22
column open_mode format a22
column cdb format a5
column instance_name format a20
column status format a14
column pdb_name format a30
column file_name format a120

select name, database_role, open_mode, cdb
from v$database;

select instance_name, status, database_status, active_state
from v$instance;

declare
  l_cdb v$database.cdb%type;
begin
  select cdb into l_cdb from v$database;
  dbms_output.put_line('CDB=' || l_cdb);
  if l_cdb = 'YES' then
    for r in (
      select name, open_mode
      from v$pdbs
      where name <> 'PDB$SEED'
      order by con_id
    ) loop
      dbms_output.put_line('PDB ' || r.name || ' open_mode=' || r.open_mode);
    end loop;
  end if;
end;
/

select count(*) as recover_file_count
from v$recover_file;

select count(*) as block_corruption_count
from v$database_block_corruption;

exit
SQL
}

run_health_check() {
  local repo_sql sql_file log_file
  repo_sql="$(script_dir)/drill_health_check.sql"
  sql_file="$repo_sql"
  log_file="${LOG_DIR}/crashsim_health_check_${RUN_ID}.log"

  if [[ ! -f "$sql_file" ]]; then
    sql_file="${LOG_DIR}/crashsim_health_check_${RUN_ID}.sql"
    write_builtin_health_check_sql_file "$sql_file"
  fi

  echo "Running health check"
  echo "SQL file: ${sql_file}"
  echo "Log file: ${log_file}"
  echo

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$log_file" </dev/null ||
    die "Health check failed: $sql_file (log: $log_file)"

  sed 's/^/  /' "$log_file"
  maybe_render_html "$log_file"
}

run_baseline_backup() {
  local helper status
  local -a cmd=()

  helper="$(script_dir)/crashsim_run_baseline_backup.sh"
  [[ -f "$helper" ]] || die "Baseline backup helper not found: $helper"

  if [[ -x "$helper" ]]; then
    cmd=("$helper")
  else
    cmd=(bash "$helper")
  fi

  cmd+=("--log-dir" "$LOG_DIR")
  cmd+=("--tag-prefix" "$BASELINE_TAG_PREFIX")
  [[ "$EXECUTE" -eq 1 ]] && cmd+=("--execute") || cmd+=("--dry-run")
  [[ "$ASSUME_YES" -eq 1 ]] && cmd+=("--yes")
  [[ "$VERBOSE" -eq 1 ]] && cmd+=("--verbose")

  env CRASHSIM_RMAN_CATALOG="$RMAN_CATALOG_CONNECT" "${cmd[@]}"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    die "Baseline backup helper failed with status ${status}."
  fi
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    local baseline_artifact
    baseline_artifact="$(find_latest_artifact baseline 2>/dev/null || true)"
    [[ -n "$baseline_artifact" ]] && render_artifact_html "$baseline_artifact"
  fi
}

prepare_reset() {
  PREP_IDS=()
  PREP_TITLE=()
  PREP_STATUS=()
  PREP_REQUIRED=()
  PREP_EVIDENCE_TEXT=()
  PREP_ACTION=()
  PREP_AUTO=()
  PREP_COMMAND=()
  PREP_NOTES=()
}

prepare_add() {
  local id="$1" title="$2" status="$3" required="$4" evidence="$5" action="$6" auto="$7" command="$8" notes="$9"
  PREP_IDS+=("$id")
  PREP_TITLE[$id]="$title"
  PREP_STATUS[$id]="$status"
  PREP_REQUIRED[$id]="$required"
  PREP_EVIDENCE_TEXT[$id]="$evidence"
  PREP_ACTION[$id]="$action"
  PREP_AUTO[$id]="$auto"
  PREP_COMMAND[$id]="$command"
  PREP_NOTES[$id]="$notes"
}

prepare_value() {
  local key="$1"
  local default="${2:-UNKNOWN}"
  printf "%s" "${PREP_EVIDENCE[$key]:-$default}"
}

parse_prepare_evidence_file() {
  local file="$1"
  local line key value

  PREP_EVIDENCE=()
  [[ -f "$file" ]] || return "$FAIL"
  while IFS= read -r line; do
    case "$line" in
      *CSIM_PREP\|*\|*)
        key="${line#*CSIM_PREP|}"
        value="${key#*|}"
        key="${key%%|*}"
        PREP_EVIDENCE[$key]="$value"
        ;;
    esac
  done <"$file"
}

write_prepare_environment_sql_file() {
  local sql_file="$1"
  local target_pdb_literal
  target_pdb_literal="$(sql_quote "$TARGET_PDB")"

  cat >"$sql_file" <<SQL || die "Unable to write prepare-environment SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback off pages 0 lines 32767 trimspool on verify off

declare
  l_cdb varchar2(3) := 'NO';
  l_target_pdb varchar2(128) := ${target_pdb_literal};
  l_target_con_id number := null;

  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_PREP|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  function scalar_value(p_sql varchar2, p_default varchar2 := 'UNKNOWN') return varchar2 is
    l_value varchar2(32767);
  begin
    execute immediate p_sql into l_value;
    return nvl(l_value, p_default);
  exception
    when others then
      return 'ERROR:' || sqlcode;
  end;

  function scalar_count(p_sql varchar2) return varchar2 is
    l_value number;
  begin
    execute immediate p_sql into l_value;
    return to_char(nvl(l_value, 0));
  exception
    when others then
      return 'ERROR:' || sqlcode;
  end;
begin
  select cdb into l_cdb from v\$database;

  emit('db_name', scalar_value(q'[select name from v\$database]'));
  emit('db_unique_name', scalar_value(q'[select db_unique_name from v\$database]'));
  emit('database_role', scalar_value(q'[select database_role from v\$database]'));
  emit('open_mode', scalar_value(q'[select open_mode from v\$database]'));
  emit('cdb', l_cdb);
  emit('log_mode', scalar_value(q'[select log_mode from v\$database]'));
  emit('flashback_on', scalar_value(q'[select flashback_on from v\$database]'));
  emit('fs_failover_status', scalar_value(q'[select fs_failover_status from v\$database]'));
  emit('fs_failover_observer_present', scalar_value(q'[select fs_failover_observer_present from v\$database]'));
  emit('dg_broker_start', scalar_value(q'[select value from v\$parameter where name = 'dg_broker_start']'));
  emit('standby_dest_count', scalar_count(q'[select count(*) from v\$archive_dest where target = 'STANDBY' and destination is not null]'));
  emit('redo_groups_under2', scalar_count(q'[select count(*) from v\$log where members < 2]'));
  emit('redo_min_members', scalar_value(q'[select min(members) from v\$log]', '0'));
  emit('control_file_count', scalar_count(q'[select count(*) from v\$controlfile]'));
  emit('fra_dest', scalar_value(q'[select value from v\$parameter where name = 'db_recovery_file_dest']', ''));
  emit('db_create_file_dest', scalar_value(q'[select value from v\$parameter where name = 'db_create_file_dest']', ''));

  if l_cdb = 'YES' then
    if l_target_pdb is null then
      begin
        select coalesce(
                 max(case when name = 'CRASHPDB' and open_mode = 'READ WRITE' then name end),
                 min(case when name <> 'PDB\$SEED' and open_mode = 'READ WRITE' then name end)
               )
        into l_target_pdb
        from v\$pdbs;
      exception
        when others then
          l_target_pdb := null;
      end;
    end if;

    if l_target_pdb is not null then
      begin
        execute immediate 'select con_id from v\$pdbs where name = :1' into l_target_con_id using upper(l_target_pdb);
      exception
        when others then
          l_target_con_id := null;
      end;
    end if;

    emit('target_pdb', l_target_pdb);
    emit('target_con_id', case when l_target_con_id is null then null else to_char(l_target_con_id) end);
    emit('root_lab_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'C##CRASHSIM_ROOT_LAB']'));
    emit('root_lab_tablespace_count', scalar_count(q'[select count(*) from cdb_tablespaces where tablespace_name in ('CRASHSIM_ROOT_RO_TBS','CRASHSIM_ROOT_INDEX_TBS')]'));
    if l_target_con_id is not null then
      emit('pdb_lab_user_count', scalar_count('select count(*) from cdb_users where con_id = ' || l_target_con_id || q'[ and username in ('CRASHSIM_TABLE_LAB','CRASHSIM_SCHEMA_LAB','CRASHSIM_INDEX_LAB')]'));
      emit('pdb_lab_tablespace_count', scalar_count('select count(*) from cdb_tablespaces where con_id = ' || l_target_con_id || q'[ and tablespace_name in ('CRASHSIM_RO_TBS','CRASHSIM_INDEX_TBS')]'));
      emit('target_apex_registry_count', scalar_count('select count(*) from cdb_registry where con_id = ' || l_target_con_id || q'[ and (comp_id = 'APEX' or upper(comp_name) like '%APEX%')]'));
      emit('target_ords_user_count', scalar_count('select count(*) from cdb_users where con_id = ' || l_target_con_id || q'[ and username in ('ORDS_PUBLIC_USER','ORDS_METADATA','APEX_PUBLIC_USER')]'));
    else
      emit('pdb_lab_user_count', '0');
      emit('pdb_lab_tablespace_count', '0');
      emit('target_apex_registry_count', '0');
      emit('target_ords_user_count', '0');
    end if;
    emit('catalog_owner_count', scalar_count(q'[select count(*) from cdb_role_privs where granted_role = 'RECOVERY_CATALOG_OWNER']'));
    emit('catalog_metadata_count', scalar_count(q'[select count(*) from cdb_objects where object_name = 'RC_DATABASE' and owner not in ('SYS','SYSTEM')]'));
  else
    emit('target_pdb', '');
    emit('target_con_id', '');
    emit('root_lab_user_count', '0');
    emit('root_lab_tablespace_count', '0');
    emit('pdb_lab_user_count', scalar_count(q'[select count(*) from dba_users where username in ('CRASHSIM_TABLE_LAB','CRASHSIM_SCHEMA_LAB','CRASHSIM_INDEX_LAB')]'));
    emit('pdb_lab_tablespace_count', scalar_count(q'[select count(*) from dba_tablespaces where tablespace_name in ('CRASHSIM_RO_TBS','CRASHSIM_INDEX_TBS')]'));
    emit('target_apex_registry_count', scalar_count(q'[select count(*) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']'));
    emit('target_ords_user_count', scalar_count(q'[select count(*) from dba_users where username in ('ORDS_PUBLIC_USER','ORDS_METADATA','APEX_PUBLIC_USER')]'));
    emit('catalog_owner_count', scalar_count(q'[select count(*) from dba_role_privs where granted_role = 'RECOVERY_CATALOG_OWNER']'));
    emit('catalog_metadata_count', scalar_count(q'[select count(*) from dba_objects where object_name = 'RC_DATABASE' and owner not in ('SYS','SYSTEM')]'));
  end if;

  emit('service_crashsim_count', scalar_count(q'[select count(*) from dba_services where lower(name) in ('crashsim_ac','crashsim_tac')]'));
  emit('service_crashsim_ha_count', scalar_count(q'[select count(*) from dba_services where lower(name) in ('crashsim_ac','crashsim_tac') and (aq_ha_notifications = 'YES' or failover_type in ('TRANSACTION','AUTO'))]'));
end;
/

exit
SQL
}

collect_prepare_environment_evidence() {
  local sql_file="$1" evidence_file="$2"
  write_prepare_environment_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Prepare-environment SQL failed: $sql_file (evidence: $evidence_file)"
  parse_prepare_evidence_file "$evidence_file"

  PREP_EVIDENCE[cluster_type]="$CLUSTER_TYPE"
  PREP_EVIDENCE[storage_type]="$STORAGE_TYPE"
  PREP_EVIDENCE[gi_managed]="$GI_MANAGED"
  PREP_EVIDENCE[instance_parallel]="$INSTANCE_PARALLEL"
  PREP_EVIDENCE[db_unique_name_discovered]="$DB_UNIQUE_NAME"
  PREP_EVIDENCE[baseline_artifact_count]="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_baseline_backup_*.log' 2>/dev/null | wc -l | tr -d '[:space:]')"
  PREP_EVIDENCE[ords_binary]="$(command -v ords 2>/dev/null || true)"
  if command -v systemctl >/dev/null 2>&1; then
    PREP_EVIDENCE[ords_service_state]="$(systemctl is-active "$ORDS_SERVICE_NAME" 2>/dev/null || true)"
  else
    PREP_EVIDENCE[ords_service_state]="systemctl_not_found"
  fi
  if [[ -d "$ORDS_CONFIG_DIR" ]]; then
    PREP_EVIDENCE[ords_config_state]="present"
  else
    PREP_EVIDENCE[ords_config_state]="missing"
  fi
  if [[ -n "$APEX_IMAGES_DIR" && -d "$APEX_IMAGES_DIR" ]]; then
    PREP_EVIDENCE[apex_images_state]="present"
  else
    PREP_EVIDENCE[apex_images_state]="missing"
  fi
}

prepare_numeric_ge() {
  local value="$1" threshold="$2"
  [[ "$value" =~ ^[0-9]+$ && "$value" -ge "$threshold" ]]
}

prepare_is_primary() {
  [[ "$(prepare_value database_role)" == "PRIMARY" ]]
}

prepare_is_cdb() {
  [[ "$(prepare_value cdb)" == "YES" ]]
}

evaluate_prepare_environment() {
  local script_root
  local cdb redo_under control_count service_count service_ha_count apex_count ords_count
  local root_users root_tbs pdb_users pdb_tbs catalog_owners catalog_metadata baseline_count
  local dg_dest fsfo_status fsfo_observer cluster storage gi ords_bin ords_service ords_config apex_images

  prepare_reset
  script_root="$(script_dir)"
  cdb="$(prepare_value cdb)"
  redo_under="$(prepare_value redo_groups_under2 0)"
  control_count="$(prepare_value control_file_count 0)"
  service_count="$(prepare_value service_crashsim_count 0)"
  service_ha_count="$(prepare_value service_crashsim_ha_count 0)"
  apex_count="$(prepare_value target_apex_registry_count 0)"
  ords_count="$(prepare_value target_ords_user_count 0)"
  root_users="$(prepare_value root_lab_user_count 0)"
  root_tbs="$(prepare_value root_lab_tablespace_count 0)"
  pdb_users="$(prepare_value pdb_lab_user_count 0)"
  pdb_tbs="$(prepare_value pdb_lab_tablespace_count 0)"
  catalog_owners="$(prepare_value catalog_owner_count 0)"
  catalog_metadata="$(prepare_value catalog_metadata_count 0)"
  baseline_count="$(prepare_value baseline_artifact_count 0)"
  dg_dest="$(prepare_value standby_dest_count 0)"
  fsfo_status="$(prepare_value fs_failover_status UNKNOWN)"
  fsfo_observer="$(prepare_value fs_failover_observer_present UNKNOWN)"
  cluster="$(prepare_value cluster_type "$CLUSTER_TYPE")"
  storage="$(prepare_value storage_type "$STORAGE_TYPE")"
  gi="$(prepare_value gi_managed "$GI_MANAGED")"
  ords_bin="$(prepare_value ords_binary)"
  ords_service="$(prepare_value ords_service_state)"
  ords_config="$(prepare_value ords_config_state)"
  apex_images="$(prepare_value apex_images_state)"

  if prepare_is_cdb; then
    if prepare_numeric_ge "$root_users" 1 && prepare_numeric_ge "$root_tbs" 2 &&
       prepare_numeric_ge "$pdb_users" 3 && prepare_numeric_ge "$pdb_tbs" 2; then
      prepare_add "logical_lab" "Logical/root/PDB lab objects" "PRESENT" "Required for table/schema/index/read-only/index-only scenarios" \
        "root_users=${root_users}, root_tbs=${root_tbs}, pdb_users=${pdb_users}, pdb_tbs=${pdb_tbs}, target_pdb=$(prepare_value target_pdb)" \
        "No action needed." "no" "" "Re-run only when logical drills intentionally dropped lab objects."
    else
      prepare_add "logical_lab" "Logical/root/PDB lab objects" "MISSING" "Required for scenarios 9-11, 34-36, 43-44 and related logical drills" \
        "root_users=${root_users}, root_tbs=${root_tbs}, pdb_users=${pdb_users}, pdb_tbs=${pdb_tbs}, target_pdb=$(prepare_value target_pdb)" \
        "Run seed_crashsim_lab.sql. This recreates disposable CRASHSIM lab schemas and tablespaces." \
        "yes" "${SQLPLUS_BIN:-sqlplus} ${SQLPLUS_LOGON} @${script_root}/seed_crashsim_lab.sql" \
        "Destructive only to CRASHSIM disposable lab schemas/tablespaces."
    fi
  elif prepare_numeric_ge "$pdb_users" 3 && prepare_numeric_ge "$pdb_tbs" 2; then
    prepare_add "logical_lab" "Logical lab objects" "PRESENT" "Required for logical scenarios" \
      "users=${pdb_users}, tbs=${pdb_tbs}" "No action needed." "no" "" "Non-CDB seed posture detected."
  else
    prepare_add "logical_lab" "Logical lab objects" "PLAN_ONLY" "Required for logical scenarios" \
      "cdb=${cdb}, users=${pdb_users}, tbs=${pdb_tbs}" \
      "Create/reseed disposable CRASHSIM schemas and read-only/index-only tablespaces for this non-CDB target." \
      "no" "" "Current seed_crashsim_lab.sql is CDB-oriented; use a non-CDB seed helper before automation."
  fi

  if [[ "$redo_under" =~ ^[0-9]+$ && "$redo_under" -eq 0 ]]; then
    prepare_add "redo_multiplex" "Multiplex online redo logs" "PRESENT" "Required for redo-loss scenarios 3 and 18" \
      "redo_groups_under2=${redo_under}, min_members=$(prepare_value redo_min_members)" "No action needed." "no" "" "Redo is already multiplexed."
  elif prepare_is_primary; then
    prepare_add "redo_multiplex" "Multiplex online redo logs" "MISSING" "Required for redo-loss scenarios 3 and 18" \
      "redo_groups_under2=${redo_under}, storage=${storage}, fra=$(prepare_value fra_dest)" \
      "Add missing redo members using the topology-aware redo preparation SQL." \
      "yes" "${SQLPLUS_BIN:-sqlplus} ${SQLPLUS_LOGON} @${script_root}/prepare_crashsim_fex_redo_multiplex.sql" \
      "Uses the configured recovery destination for this FEX/OCI posture."
  else
    prepare_add "redo_multiplex" "Multiplex online redo logs" "NOT_REQUIRED" "Primary database required" \
      "role=$(prepare_value database_role)" "Run only on the primary database." "no" "" ""
  fi

  if [[ "$control_count" =~ ^[0-9]+$ && "$control_count" -ge 2 ]]; then
    prepare_add "controlfile_multiplex" "Multiplex control files" "PRESENT" "Recommended before control-file scenarios 1, 2, and 23" \
      "control_file_count=${control_count}" "No action needed." "no" "" "Control files are already multiplexed."
  elif prepare_is_primary; then
    prepare_add "controlfile_multiplex" "Multiplex control files" "PLAN_ONLY" "Recommended before control-file scenarios 1, 2, and 23" \
      "control_file_count=${control_count}, storage=${storage}" \
      "Generate provider-aware control-file multiplexing runbook." \
      "no" "${script_root}/prepare_crashsim_fex_controlfile_multiplex.sh --dry-run --log-dir ${LOG_DIR}" \
      "Requires outage/restart and provider-approved byte-copy or CREATE CONTROLFILE procedure; not auto-executed."
  else
    prepare_add "controlfile_multiplex" "Multiplex control files" "NOT_REQUIRED" "Primary database required" \
      "role=$(prepare_value database_role)" "Run only on the primary database." "no" "" ""
  fi

  if [[ "$cluster" == RAC* || "$cluster" == "GI_SINGLE" || "$gi" == "1" ]]; then
    if prepare_numeric_ge "$service_count" 2 && prepare_numeric_ge "$service_ha_count" 2; then
      prepare_add "services_ac_tac" "AC/TAC/FAN lab services" "PRESENT" "Required for service continuity scenarios 56, 83, 84, and 87" \
        "services=${service_count}, ha_services=${service_ha_count}" "No action needed." "no" "" "CrashSimulator AC/TAC services are present."
    else
      prepare_add "services_ac_tac" "AC/TAC/FAN lab services" "MISSING" "Required for service continuity scenarios 56, 83, 84, and 87" \
        "cluster=${cluster}, services=${service_count}, ha_services=${service_ha_count}" \
        "Create or repair crashsim_ac and crashsim_tac services with FAN/AC/TAC attributes." \
        "yes" "${script_root}/tools/crashsim_configure_ha_lab.sh --services" \
        "Requires srvctl/GI privileges and current DB_UNIQUE_NAME/PDB defaults."
    fi
  else
    prepare_add "services_ac_tac" "AC/TAC/FAN lab services" "NOT_REQUIRED" "RAC/GI-managed topology required" \
      "cluster=${cluster}, gi=${gi}" "Standalone database does not need RAC service lab seeds." "no" "" ""
  fi

  if prepare_numeric_ge "$apex_count" 1 && prepare_numeric_ge "$ords_count" 2 &&
     [[ -n "$ords_bin" && "$ords_service" == "active" && "$ords_config" == "present" ]]; then
    prepare_add "apex_ords" "APEX/ORDS application access path" "PRESENT" "Required for APEX/ORDS scenarios 73-82" \
      "apex=${apex_count}, ords_users=${ords_count}, ords_service=${ords_service}, config=${ords_config}, images=${apex_images}" \
      "No action needed." "no" "" "Scenario 79 still needs a load-balancer or peer URL when executed."
  else
    prepare_add "apex_ords" "APEX/ORDS application access path" "MISSING" "Required for APEX/ORDS scenarios 73-82" \
      "apex=${apex_count}, ords_users=${ords_count}, ords_bin=${ords_bin:-not_found}, ords_service=${ords_service}, config=${ords_config}, images=${apex_images}" \
      "Install/configure APEX and ORDS with the lab helper when media and passwords are approved." \
      "conditional" "${script_root}/tools/crashsim_install_apex_ords_lab.sh" \
      "Requires APEX/ORDS media plus SYS_PASSWORD, ORDS_PUBLIC_PASSWORD, and APEX_ADMIN_PASSWORD environment variables."
  fi

  if [[ -n "$RMAN_CATALOG_CONNECT" ]] || prepare_numeric_ge "$catalog_metadata" 1; then
    if prepare_numeric_ge "$catalog_metadata" 1; then
      prepare_add "rman_catalog" "RMAN recovery catalog" "PRESENT" "Required for catalog outage and catalog-aware backup evidence" \
        "catalog_owners=${catalog_owners}, catalog_metadata=${catalog_metadata}, configured=$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)" \
        "No action needed." "no" "" "Confirm catalog is outside the target failure domain for production-like DR tests."
    else
      prepare_add "rman_catalog" "RMAN recovery catalog" "MISSING" "Required for catalog outage and catalog-aware backup evidence" \
        "catalog_owners=${catalog_owners}, catalog_metadata=${catalog_metadata}, configured=yes" \
        "Create local lab recovery catalog metadata and register/resync the target." \
        "conditional" "${script_root}/tools/crashsim_configure_ha_lab.sh --catalog" \
        "Requires CRASHSIM_RMAN_CATALOG_PASSWORD; production catalogs should live outside the target DB."
    fi
  else
    prepare_add "rman_catalog" "RMAN recovery catalog" "MISSING" "Optional unless testing recovery-catalog scenarios/reporting" \
      "catalog_owners=${catalog_owners}, catalog_metadata=${catalog_metadata}, configured=no" \
      "Set CRASHSIM_RMAN_CATALOG and create/configure a catalog when catalog scenarios are in scope." \
      "conditional" "${script_root}/tools/crashsim_configure_ha_lab.sh --catalog" \
      "Skipped by default because it requires credentials and topology decisions."
  fi

  if prepare_numeric_ge "$dg_dest" 1 || [[ "$(prepare_value database_role)" == *"STANDBY"* ]]; then
    if [[ "$fsfo_status" == *"SYNCHRONIZED"* || "$fsfo_status" == *"TARGET"* || "$fsfo_status" == *"ENABLED"* || "$fsfo_observer" == "YES" ]]; then
      prepare_add "fsfo" "Data Guard FSFO observer posture" "PRESENT" "Required for FSFO observer scenario 66 and FSFO MAA evidence" \
        "dg_dest=${dg_dest}, fsfo_status=${fsfo_status}, observer=${fsfo_observer}" "No action needed." "no" "" "Validate observer placement and preferred observer hosts."
    else
      prepare_add "fsfo" "Data Guard FSFO observer posture" "PLAN_ONLY" "Required for FSFO observer scenario 66 and FSFO MAA evidence" \
        "dg_dest=${dg_dest}, fsfo_status=${fsfo_status}, observer=${fsfo_observer}, broker=$(prepare_value dg_broker_start)" \
        "Run FSFO readiness checks and configure observer only after Broker, flashback, SRLs, transport, and apply are healthy." \
        "no" "${script_root}/tools/crashsim_configure_ha_lab.sh --fsfo-check" \
        "FSFO enablement is disruptive/risk-sensitive and remains runbook-driven."
    fi
  else
    prepare_add "fsfo" "Data Guard FSFO observer posture" "NOT_REQUIRED" "Data Guard topology required" \
      "dg_dest=${dg_dest}, role=$(prepare_value database_role)" "No standby/transport evidence detected." "no" "" ""
  fi

  if [[ "$storage" == "ASM" || "$storage" == "FEX_ACFS" || "$gi" == "1" ]]; then
    prepare_add "asm_gi_redundant_lab" "ASM/GI redundant storage lab" "PLAN_ONLY" "Required for ASM/FEX/GI destructive storage scenarios 46-49 and 72" \
      "storage=${storage}, gi=${gi}" \
      "Review or create a purpose-built redundant GI/ASM lab with additional shared disks and failgroups." \
      "no" "${script_root}/crashsim_prepare_redundant_gi_lab.sh --dry-run" \
      "Needs explicit disk/LUN approval; never auto-create storage from the generic prepare menu."
  else
    prepare_add "asm_gi_redundant_lab" "ASM/GI redundant storage lab" "NOT_REQUIRED" "ASM/GI/FEX topology required" \
      "storage=${storage}, gi=${gi}" "Filesystem-only topology does not require ASM/GI storage lab seeds." "no" "" ""
  fi

  if prepare_numeric_ge "$baseline_count" 1; then
    prepare_add "baseline_backup" "Fresh RMAN baseline backup evidence" "PRESENT" "Recommended after environment preparation changes" \
      "baseline_logs=${baseline_count}, catalog_configured=$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)" \
      "Run again after executing any preparation changes." "no" "" "Use Reports -> Run fresh RMAN baseline backup after changes."
  else
    prepare_add "baseline_backup" "Fresh RMAN baseline backup evidence" "MISSING" "Recommended before destructive scenario batches" \
      "baseline_logs=${baseline_count}, catalog_configured=$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)" \
      "Run a dry-run or confirmed baseline backup from the Reports menu." \
      "no" "${SCRIPT_PATH} --baseline-backup --dry-run" \
      "Not auto-executed because it can consume backup storage and I/O."
  fi
}

write_prepare_environment_report() {
  local report_file="$1" evidence_file="$2"
  local id generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf "# CrashSimulator Seed / Prepare Environment Planner\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(md_escape "$(prepare_value db_name "$DB_NAME")")"
    printf -- '- DB unique name: `%s`\n' "$(md_escape "$(prepare_value db_unique_name "$DB_UNIQUE_NAME")")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(md_escape "$(prepare_value database_role "$DB_ROLE")")" "$(md_escape "$(prepare_value open_mode "$DB_OPEN_MODE")")"
    printf -- '- CDB / target PDB: `%s` / `%s`\n' "$(md_escape "$(prepare_value cdb "$DB_CDB")")" "$(md_escape "$(prepare_value target_pdb "${TARGET_PDB:-not selected}")")"
    printf -- '- Cluster/storage: `%s` / `%s`\n' "$(md_escape "$(prepare_value cluster_type "$CLUSTER_TYPE")")" "$(md_escape "$(prepare_value storage_type "$STORAGE_TYPE")")"
    printf -- '- Mode: `%s`\n' "$([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This planner detects missing lab seeds and environment preparations needed by the scenario catalog. It only recommends actions relevant to the current topology. Execution remains guarded; credentials, storage provisioning, FSFO enablement, and provider-specific copy operations are not guessed.\n"
  } >"$report_file" || die "Unable to write prepare-environment report: $report_file"

  append_report_section "$report_file" "Preparation Matrix"
  {
    printf '| ID | Preparation | Status | Required for | Evidence | Action | Auto-execute |\n'
    printf '| --- | --- | --- | --- | --- | --- | --- |\n'
    for id in "${PREP_IDS[@]}"; do
      printf '| `%s` | %s | `%s` | %s | %s | %s | `%s` |\n' \
        "$(md_escape "$id")" \
        "$(md_escape "${PREP_TITLE[$id]}")" \
        "$(md_escape "${PREP_STATUS[$id]}")" \
        "$(md_escape "${PREP_REQUIRED[$id]}")" \
        "$(md_escape "${PREP_EVIDENCE_TEXT[$id]}")" \
        "$(md_escape "${PREP_ACTION[$id]}")" \
        "$(md_escape "${PREP_AUTO[$id]}")"
    done
  } >>"$report_file"

  append_report_section "$report_file" "Suggested Commands"
  {
    printf '| ID | Command / Helper |\n'
    printf '| --- | --- |\n'
    for id in "${PREP_IDS[@]}"; do
      [[ -n "${PREP_COMMAND[$id]}" ]] || continue
      printf '| `%s` | `%s` |\n' "$(md_escape "$id")" "$(md_escape "${PREP_COMMAND[$id]}")"
    done
  } >>"$report_file"

  append_report_section "$report_file" "Notes And Guardrails"
  {
    for id in "${PREP_IDS[@]}"; do
      [[ -n "${PREP_NOTES[$id]}" ]] || continue
      printf -- '- `%s`: %s\n' "$(md_escape "$id")" "$(md_escape "${PREP_NOTES[$id]}")"
    done
  } >>"$report_file"

  append_report_section "$report_file" "Raw Evidence"
  {
    printf '```text\n'
    for id in "${!PREP_EVIDENCE[@]}"; do
      printf 'CSIM_PREP|%s|%s\n' "$id" "${PREP_EVIDENCE[$id]}"
    done | sort
    printf '```\n'
  } >>"$report_file"
}

confirm_prepare_environment_execution() {
  local token="PREPARE-ENVIRONMENT"

  [[ "$EXECUTE" -eq 1 ]] || return "$SUCCESS"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    require_destructive_lab_ack "environment preparation"
    return "$SUCCESS"
  fi
  echo
  echo "About to execute eligible CrashSimulator environment preparation helpers."
  echo "Database: ${DB_UNIQUE_NAME:-unknown} ($(prepare_value database_role "$DB_ROLE"), $(prepare_value open_mode "$DB_OPEN_MODE"))"
  echo "Only items marked auto-execute yes/conditional and currently missing will be attempted."
  echo "Type ${token} to continue:"
  local answer
  read -r answer
  [[ "$answer" == "$token" ]] || die "Confirmation did not match. Aborting."
  require_destructive_lab_ack "environment preparation"
}

run_prepare_helper_command() {
  local id="$1"
  shift
  echo
  echo "Preparing ${id}: ${PREP_TITLE[$id]}"
  printf "Command:"
  printf " %q" "$@"
  printf "\n"
  "$@"
}

execute_prepare_environment_actions() {
  local id helper status
  local script_root
  script_root="$(script_dir)"

  [[ "$EXECUTE" -eq 1 ]] || return "$SUCCESS"
  confirm_prepare_environment_execution

  for id in "${PREP_IDS[@]}"; do
    [[ "${PREP_STATUS[$id]}" == "MISSING" ]] || continue
    case "$id" in
      logical_lab)
        [[ "${PREP_AUTO[$id]}" == "yes" ]] || continue
        run_prepare_helper_command "$id" "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"${script_root}/seed_crashsim_lab.sql" \
          >"${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log" 2>&1
        status=$?
        [[ "$status" -eq 0 ]] || die "Preparation ${id} failed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        echo "Preparation ${id} completed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        ;;
      redo_multiplex)
        [[ "${PREP_AUTO[$id]}" == "yes" ]] || continue
        helper="${script_root}/prepare_crashsim_fex_redo_multiplex.sql"
        [[ -f "$helper" ]] || die "Redo preparation SQL not found: $helper"
        run_prepare_helper_command "$id" "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$helper" \
          >"${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log" 2>&1
        status=$?
        [[ "$status" -eq 0 ]] || die "Preparation ${id} failed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        echo "Preparation ${id} completed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        ;;
      services_ac_tac)
        [[ "${PREP_AUTO[$id]}" == "yes" ]] || continue
        helper="${script_root}/tools/crashsim_configure_ha_lab.sh"
        [[ -f "$helper" ]] || die "HA lab helper not found: $helper"
        run_prepare_helper_command "$id" bash "$helper" --services
        ;;
      apex_ords)
        [[ "${PREP_AUTO[$id]}" == "conditional" ]] || continue
        if [[ -n "${SYS_PASSWORD:-}" && -n "${ORDS_PUBLIC_PASSWORD:-}" && -n "${APEX_ADMIN_PASSWORD:-}" ]]; then
          helper="${script_root}/tools/crashsim_install_apex_ords_lab.sh"
          [[ -f "$helper" ]] || die "APEX/ORDS lab helper not found: $helper"
          run_prepare_helper_command "$id" bash "$helper"
        else
          warn "Skipping ${id}: SYS_PASSWORD, ORDS_PUBLIC_PASSWORD, and APEX_ADMIN_PASSWORD must be set in the environment."
        fi
        ;;
      rman_catalog)
        [[ "${PREP_AUTO[$id]}" == "conditional" ]] || continue
        if [[ -n "${CRASHSIM_RMAN_CATALOG_PASSWORD:-}" ]]; then
          helper="${script_root}/tools/crashsim_configure_ha_lab.sh"
          [[ -f "$helper" ]] || die "HA lab helper not found: $helper"
          run_prepare_helper_command "$id" bash "$helper" --catalog
        else
          warn "Skipping ${id}: CRASHSIM_RMAN_CATALOG_PASSWORD is required."
        fi
        ;;
      *)
        ;;
    esac
  done
}

run_prepare_environment() {
  local sql_file evidence_file report_file

  discover_environment
  ensure_sqlplus
  sql_file="${LOG_DIR}/crashsim_prepare_environment_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_prepare_environment_${RUN_ID}.evidence"
  report_file="${LOG_DIR}/crashsim_prepare_environment_${RUN_ID}.md"

  collect_prepare_environment_evidence "$sql_file" "$evidence_file"
  evaluate_prepare_environment
  write_prepare_environment_report "$report_file" "$evidence_file"
  echo "Seed/prepare environment planner generated: ${report_file}"
  maybe_render_html "$report_file"

  execute_prepare_environment_actions
}

