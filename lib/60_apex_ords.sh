apex_ords_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${APEX_ORDS_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

apex_ords_positive() {
  local key="$1"
  local value
  value="$(apex_ords_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

apex_ords_zero() {
  local key="$1"
  local value
  value="$(apex_ords_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -eq 0 ]]
}

apex_ords_append_check() {
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

apex_ords_report_target_pdb() {
  if [[ "$DB_CDB" != "YES" ]]; then
    printf "%s" ""
    return "$SUCCESS"
  fi
  if [[ -n "$TARGET_PDB" ]]; then
    pdb_exists "$TARGET_PDB" ||
      die "PDB ${TARGET_PDB} was not found in this CDB. Available PDBs: $(pdb_list_for_message)"
    printf "%s" "$TARGET_PDB"
    return "$SUCCESS"
  fi
  if [[ "${#PDB_ROWS[@]}" -eq 1 ]]; then
    printf "%s" "$(printf "%s" "${PDB_ROWS[0]}" | cut -d'|' -f1)"
    return "$SUCCESS"
  fi
  printf "%s" ""
}

run_ords_priv_helper() {
  [[ -n "$ORDS_PRIV_HELPER" && -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  echo "sudo -n ${ORDS_PRIV_HELPER} $*"
  sudo -n "$ORDS_PRIV_HELPER" "$@"
}

ords_priv_helper_service_available() {
  local rc
  [[ -n "$ORDS_PRIV_HELPER" && -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  sudo -n "$ORDS_PRIV_HELPER" service status "$ORDS_SERVICE_NAME" >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 0 || "$rc" -eq 3 ]]
}

ords_priv_helper_config_available() {
  [[ -n "$ORDS_PRIV_HELPER" && -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  sudo -n "$ORDS_PRIV_HELPER" config-check "$ORDS_CONFIG_DIR" >/dev/null 2>&1
}

ords_sudo_systemctl_available() {
  local rc
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  sudo -n systemctl status "$ORDS_SERVICE_NAME" >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 0 || "$rc" -eq 3 ]]
}

ords_control_method() {
  if [[ "$(id -u)" -eq 0 ]]; then
    printf "systemctl"
    return "$SUCCESS"
  fi
  if ords_priv_helper_service_available; then
    printf "ords_priv_helper"
    return "$SUCCESS"
  fi
  if ords_sudo_systemctl_available; then
    printf "sudo_systemctl"
    return "$SUCCESS"
  fi
  return "$FAIL"
}

ords_control_command_prefix() {
  case "$(ords_control_method 2>/dev/null || true)" in
    systemctl)
      printf "systemctl"
      ;;
    ords_priv_helper)
      printf "sudo -n %s service" "$ORDS_PRIV_HELPER"
      ;;
    sudo_systemctl)
      printf "sudo -n systemctl"
      ;;
    *)
      return "$FAIL"
      ;;
  esac
}

can_control_ords_service() {
  command -v systemctl >/dev/null 2>&1 || [[ -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  ords_control_method >/dev/null 2>&1 || return "$FAIL"
}

ords_service_unit_exists() {
  local unit_output
  command -v systemctl >/dev/null 2>&1 || return "$FAIL"
  unit_output="$(systemctl list-unit-files "${ORDS_SERVICE_NAME}.service" --no-legend 2>/dev/null | trim_blank_lines || true)"
  [[ -n "$unit_output" ]] ||
    systemctl status "$ORDS_SERVICE_NAME" >/dev/null 2>&1
}

detect_apex_images_dir() {
  if [[ -n "$APEX_IMAGES_DIR" ]]; then
    [[ -d "$APEX_IMAGES_DIR" ]] && printf "%s" "$APEX_IMAGES_DIR" && return "$SUCCESS"
    return "$FAIL"
  fi

  local candidate
  for candidate in \
    /opt/oracle/apex/images \
    /u01/app/oracle/apex/images \
    /u01/app/oracle/product/apex/images \
    /tmp/apex/images; do
    if [[ -d "$candidate" ]]; then
      printf "%s" "$candidate"
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

run_apex_ords_report() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file evidence_file generated_at target_pdb
  local ords_bin ords_version ords_service_state ords_config_state ords_url_state ords_lb_state
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  target_pdb="$(apex_ords_report_target_pdb)"
  report_file="${LOG_DIR}/crashsim_apex_ords_report_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_apex_ords_report_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_apex_ords_report_${RUN_ID}.evidence"

  write_apex_ords_report_sql_file "$sql_file" "$target_pdb"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "APEX/ORDS report SQL failed: $sql_file (evidence: $evidence_file)"
  parse_apex_ords_evidence_file "$evidence_file"

  ords_bin="$(command -v ords 2>/dev/null || true)"
  if [[ -n "$ords_bin" ]]; then
    if command -v timeout >/dev/null 2>&1; then
      ords_version="$(timeout 15 ords --version 2>&1 | awk '/Oracle REST Data Services/ {line=$0} END {if (line != "") print line; else print "version unavailable"}' || true)"
    else
      ords_version="$(ords --version 2>&1 | awk '/Oracle REST Data Services/ {line=$0} END {if (line != "") print line; else print "version unavailable"}' || true)"
    fi
    [[ -n "$ords_version" ]] || ords_version="version unavailable"
  else
    ords_version="not found"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    ords_service_state="$(systemctl is-active "$ORDS_SERVICE_NAME" 2>/dev/null || true)"
    [[ -n "$ords_service_state" ]] || ords_service_state="unavailable"
  else
    ords_service_state="systemctl not found"
  fi
  if [[ -d "$ORDS_CONFIG_DIR" ]]; then
    ords_config_state="present"
  else
    ords_config_state="missing"
  fi
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1; then
      ords_url_state="OK"
    else
      ords_url_state="FAILED"
    fi
    if [[ -n "$ORDS_LB_URL" ]]; then
      if curl -fsS -L --max-time 10 "$ORDS_LB_URL" >/dev/null 2>&1; then
        ords_lb_state="OK"
      else
        ords_lb_state="FAILED"
      fi
    else
      ords_lb_state="not supplied"
    fi
  else
    ords_url_state="curl not found"
    ords_lb_state="curl not found"
  fi

  {
    printf "# CrashSimulator APEX / ORDS Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(apex_ords_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(apex_ords_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(apex_ords_value db_role "$DB_ROLE")" "$(apex_ords_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(apex_ords_value cdb "$DB_CDB")"
    printf -- '- Target PDB detail: `%s`\n' "${target_pdb:-not selected}"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf -- '- ORDS service name: `%s`\n' "$ORDS_SERVICE_NAME"
    printf -- '- ORDS config directory: `%s`\n' "$ORDS_CONFIG_DIR"
    printf -- '- ORDS smoke URL: `%s`\n' "$ORDS_URL"
    printf "\n"
    printf "This report treats APEX/ORDS as an application access-path dependency. A database can be technically recovered while users are still down because ORDS, static files, runtime users, wallet/TLS, or PDB/service mapping are not healthy.\n"
  } >"$report_file" || die "Unable to write APEX/ORDS report file: $report_file"

  append_report_section "$report_file" "Host-Side ORDS Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| ORDS binary | `%s` |\n' "$(md_escape "${ords_bin:-not found}")"
    printf '| ORDS version | `%s` |\n' "$(md_escape "$ords_version")"
    printf '| systemd service | `%s` |\n' "$(md_escape "$ORDS_SERVICE_NAME")"
    printf '| service state | `%s` |\n' "$(md_escape "$ords_service_state")"
    printf '| config directory | `%s` |\n' "$(md_escape "$ords_config_state")"
    printf '| smoke URL | `%s` |\n' "$(md_escape "$ords_url_state")"
    printf '| load balancer URL | `%s` |\n' "$(md_escape "$ords_lb_state")"
  } >>"$report_file"

  append_report_section "$report_file" "Database-Side APEX / ORDS Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| CDB APEX registry rows | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_registry_apex_count)")"
    printf '| CDB APEX versions/status | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_apex_versions)")"
    printf '| CDB ORDS registry rows | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_registry_ords_count)")"
    printf '| CDB ORDS versions/status | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_ords_versions)")"
    printf '| Current container | `%s` |\n' "$(md_escape "$(apex_ords_value current_container)")"
    printf '| Local APEX version/status | `%s` |\n' "$(md_escape "$(apex_ords_value local_apex_version)")"
    printf '| APEX_PUBLIC_USER | `%s` |\n' "$(md_escape "$(apex_ords_value local_apex_public_user_status)")"
    printf '| ORDS_PUBLIC_USER | `%s` |\n' "$(md_escape "$(apex_ords_value local_ords_public_user_status)")"
    printf '| ORDS_METADATA | `%s` |\n' "$(md_escape "$(apex_ords_value local_ords_metadata_user_status)")"
    printf '| Invalid APEX objects | `%s` |\n' "$(md_escape "$(apex_ords_value local_invalid_apex_objects)")"
    printf '| Invalid ORDS objects | `%s` |\n' "$(md_escape "$(apex_ords_value local_invalid_ords_objects)")"
    printf '| APEX workspaces | `%s` |\n' "$(md_escape "$(apex_ords_value apex_workspace_count)")"
    printf '| APEX applications | `%s` |\n' "$(md_escape "$(apex_ords_value apex_application_count)")"
    printf '| APEX SMTP parameters | `%s` |\n' "$(md_escape "$(apex_ords_value apex_smtp_parameter_count)")"
    printf '| APEX wallet parameters | `%s` |\n' "$(md_escape "$(apex_ords_value apex_wallet_parameter_count)")"
    printf '| Network ACLs | `%s` |\n' "$(md_escape "$(apex_ords_value local_network_acl_count)")"
  } >>"$report_file"

  append_report_section "$report_file" "Readiness Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ -n "$ords_bin" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS host" "ORDS binary available" "ords=${ords_bin}, version=${ords_version}" "Keep ORDS packaged or pinned consistently across all ORDS/RAC nodes."
  else
    apex_ords_append_check "$report_file" "GAP" "ORDS host" "ORDS binary available" "ords=not found" "Install ORDS on every intended mid-tier node before ORDS outage drills."
  fi
  if [[ "$ords_config_state" == "present" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS config" "Configuration directory present" "config=${ORDS_CONFIG_DIR}" "Back up ORDS config, wallets, pool settings, and static-file mappings."
  else
    apex_ords_append_check "$report_file" "GAP" "ORDS config" "Configuration directory present" "config=${ORDS_CONFIG_DIR} missing" "Run ORDS install/configuration and include the config directory in lab backups."
  fi
  if [[ "$ords_service_state" == "active" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS service" "Service active" "systemctl is-active ${ORDS_SERVICE_NAME}=active" "Validate restart, service monitoring, and node-outage behavior."
  else
    apex_ords_append_check "$report_file" "WARN" "ORDS service" "Service active" "systemctl is-active ${ORDS_SERVICE_NAME}=${ords_service_state}" "Start or configure the ORDS service before user-facing outage drills."
  fi
  if [[ "$ords_url_state" == "OK" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS access" "Smoke URL reachable" "url=${ORDS_URL}" "Use application-specific APEX URLs for deeper smoke checks."
  else
    apex_ords_append_check "$report_file" "GAP" "ORDS access" "Smoke URL reachable" "url=${ORDS_URL}, result=${ords_url_state}" "Fix listener/firewall/ORDS/service mapping before declaring application access recovered."
  fi
  if apex_ords_positive local_apex_registry_count; then
    apex_ords_append_check "$report_file" "OK" "APEX database" "APEX installed in target container" "APEX=$(apex_ords_value local_apex_version)" "Keep APEX patch/upgrade validation aligned with database recovery drills."
  else
    apex_ords_append_check "$report_file" "GAP" "APEX database" "APEX installed in target container" "APEX=$(apex_ords_value local_apex_version NONE)" "Install APEX in the intended PDB before APEX runtime/static/application scenarios can execute."
  fi
  if [[ "$(apex_ords_value local_apex_public_user_status MISSING)" == OPEN* && "$(apex_ords_value local_ords_public_user_status MISSING)" == OPEN* ]]; then
    apex_ords_append_check "$report_file" "OK" "Runtime accounts" "APEX/ORDS runtime accounts open" "APEX_PUBLIC_USER=$(apex_ords_value local_apex_public_user_status), ORDS_PUBLIC_USER=$(apex_ords_value local_ords_public_user_status)" "Include runtime-account lock/credential rotation drills in quarterly testing."
  else
    apex_ords_append_check "$report_file" "WARN" "Runtime accounts" "APEX/ORDS runtime accounts open" "APEX_PUBLIC_USER=$(apex_ords_value local_apex_public_user_status), ORDS_PUBLIC_USER=$(apex_ords_value local_ords_public_user_status)" "Unlock or configure runtime users after installation; test account-lock recovery before production use."
  fi
  if apex_ords_zero local_invalid_apex_objects && apex_ords_zero local_invalid_ords_objects; then
    apex_ords_append_check "$report_file" "OK" "Invalid objects" "APEX/ORDS objects valid" "APEX=$(apex_ords_value local_invalid_apex_objects), ORDS=$(apex_ords_value local_invalid_ords_objects)" "Re-check after PDB recovery, APEX patching, datapatch, and ORDS upgrades."
  else
    apex_ords_append_check "$report_file" "WARN" "Invalid objects" "APEX/ORDS objects valid" "APEX=$(apex_ords_value local_invalid_apex_objects), ORDS=$(apex_ords_value local_invalid_ords_objects)" "Compile and investigate invalid objects before application availability drills."
  fi

  append_report_section "$report_file" "Recommended APEX / ORDS Scenario Family"
  {
    printf '| ID | Scenario | Lifecycle posture |\n'
    printf '| --- | --- | --- |\n'
    printf '| `73` | ORDS service unavailable | Automatable when the OS user can control the ORDS systemd unit. |\n'
    printf '| `74` | ORDS configuration unavailable | Automatable only when the config directory is writable or explicitly run with approved OS privileges. |\n'
    printf '| `75` | ORDS database pool misconfiguration | Reversible db.servicename mutation when ORDS restart privileges are approved; --recover 75 restores the original value. |\n'
    printf '| `76` | APEX/ORDS runtime account locked | Automatable when APEX/ORDS runtime users exist in the target container. |\n'
    printf '| `77` | APEX static resources unavailable | Automatable when an APEX images/static directory is configured and writable. |\n'
    printf '| `78` | APEX application availability validation after recovery | Read-only smoke evidence after PDB/datafile recovery. |\n'
    printf '| `79` | One ORDS node unavailable behind load balancer | Automatable when ORDS service control and a load-balancer URL are supplied. |\n'
    printf '| `80` | APEX session continuity test | Read-only continuity evidence, with optional seeded Playwright browser-session driver for screenshots and JSON/Markdown evidence. |\n'
    printf '| `81` | APEX mail queue/configuration validation | Read-only APEX SMTP/wallet/ACL evidence. |\n'
    printf '| `82` | APEX upgrade/patch rollback readiness | Read-only pre/post evidence and runbook. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw APEX / ORDS SQL Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_APEX|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  if [[ -n "$ords_bin" ]]; then
    append_report_command "$report_file" "ORDS Version" ords --version
    if [[ -d "$ORDS_CONFIG_DIR" ]]; then
      append_report_command "$report_file" "ORDS Config List" ords --config "$ORDS_CONFIG_DIR" config list
    fi
  fi
  if command -v systemctl >/dev/null 2>&1; then
    append_report_command "$report_file" "ORDS Service Status" systemctl status "$ORDS_SERVICE_NAME"
  fi
  if command -v curl >/dev/null 2>&1; then
  append_report_command "$report_file" "ORDS Smoke URL" curl -sS -L -o /dev/null -D - --max-time 10 "$ORDS_URL"
  if [[ -n "$ORDS_LB_URL" ]]; then
    append_report_command "$report_file" "ORDS Load Balancer Smoke URL" curl -sS -L -o /dev/null -D - --max-time 10 "$ORDS_LB_URL"
  fi
  fi

  echo "APEX/ORDS readiness report generated: ${report_file}"
  maybe_render_html "$report_file"
}

write_maa_assessment_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write MAA assessment SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off
set serveroutput on size unlimited

select 'CSIM_MAA|db_name|' || name from v$database;
select 'CSIM_MAA|db_unique_name|' || db_unique_name from v$database;
select 'CSIM_MAA|db_role|' || database_role from v$database;
select 'CSIM_MAA|open_mode|' || open_mode from v$database;
select 'CSIM_MAA|cdb|' || cdb from v$database;
select 'CSIM_MAA|log_mode|' || log_mode from v$database;
select 'CSIM_MAA|force_logging|' || force_logging from v$database;
select 'CSIM_MAA|flashback_on|' || flashback_on from v$database;
select 'CSIM_MAA|protection_mode|' || protection_mode from v$database;
select 'CSIM_MAA|protection_level|' || protection_level from v$database;
select 'CSIM_MAA|switchover_status|' || switchover_status from v$database;
select 'CSIM_MAA|fsfo_status|' || nvl(fs_failover_status, 'UNKNOWN') from v$database;
select 'CSIM_MAA|fsfo_target|' || nvl(fs_failover_current_target, 'NONE') from v$database;
select 'CSIM_MAA|fsfo_threshold|' || nvl(to_char(fs_failover_threshold), 'UNKNOWN') from v$database;
select 'CSIM_MAA|fsfo_observer_present|' || nvl(fs_failover_observer_present, 'UNKNOWN') from v$database;
select 'CSIM_MAA|dbid|' || dbid from v$database;
select 'CSIM_MAA|platform_name|' || platform_name from v$database;

select 'CSIM_MAA|instance_name|' || instance_name from v$instance;
select 'CSIM_MAA|host_name|' || host_name from v$instance;
select 'CSIM_MAA|version|' || version from v$instance;
select 'CSIM_MAA|version_major|' || regexp_substr(version, '^[0-9]+') from v$instance;
select 'CSIM_MAA|instance_status|' || status from v$instance;
select 'CSIM_MAA|instance_parallel|' || parallel from v$instance;
select 'CSIM_MAA|instance_thread|' || thread# from v$instance;

select 'CSIM_MAA|cluster_database|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'cluster_database';
select 'CSIM_MAA|remote_login_passwordfile|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'remote_login_passwordfile';
select 'CSIM_MAA|db_recovery_file_dest|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'db_recovery_file_dest';
select 'CSIM_MAA|db_recovery_file_dest_size|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'db_recovery_file_dest_size';
select 'CSIM_MAA|local_undo_enabled|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'local_undo_enabled';
select 'CSIM_MAA|wallet_root|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'wallet_root';
select 'CSIM_MAA|tde_configuration|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'tde_configuration';
select 'CSIM_MAA|archive_lag_target|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'archive_lag_target';
select 'CSIM_MAA|adg_redirect_dml|' || nvl(max(value), 'UNAVAILABLE')
from v$parameter
where name = 'adg_redirect_dml';
select 'CSIM_MAA|adg_redirect_dml_modifiable|' || nvl(max(issys_modifiable), 'UNAVAILABLE')
from v$parameter
where name = 'adg_redirect_dml';

select 'CSIM_MAA|control_file_count|' || count(*) from v$controlfile;
select 'CSIM_MAA|redo_group_count|' || count(*) from v$log;
select 'CSIM_MAA|redo_min_members|' || nvl(min(members), 0) from v$log;
select 'CSIM_MAA|redo_groups_less_than_two_members|' || count(*) from v$log where members < 2;
select 'CSIM_MAA|recover_file_count|' || count(*) from v$recover_file;
select 'CSIM_MAA|block_corruption_count|' || count(*) from v$database_block_corruption;
select 'CSIM_MAA|copy_corruption_count|' || count(*) from v$copy_corruption;
select 'CSIM_MAA|backup_corruption_count|' || count(*) from v$backup_corruption;
select 'CSIM_MAA|guaranteed_restore_point_count|' || count(*)
from v$restore_point
where guarantee_flashback_database = 'YES';

select 'CSIM_MAA|fra_configured|' ||
       case when count(*) > 0 and max(space_limit) > 0 then 'YES' else 'NO' end
from v$recovery_file_dest;
select 'CSIM_MAA|fra_used_pct|' ||
       nvl(to_char(round(max(space_used) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;
select 'CSIM_MAA|fra_reclaimable_pct|' ||
       nvl(to_char(round(max(space_reclaimable) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;

select 'CSIM_MAA|recent_successful_backup_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status like 'COMPLETED%';
select 'CSIM_MAA|recent_failed_backup_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status not like 'COMPLETED%';
select 'CSIM_MAA|last_successful_backup_time|' ||
       nvl(to_char(max(end_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_MAA|last_successful_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(end_time)) * 24, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_MAA|backup_device_types|' ||
       nvl((
         select listagg(output_device_type, ',') within group (order by output_device_type)
         from (
           select distinct nvl(output_device_type, 'UNKNOWN') output_device_type
           from v$rman_backup_job_details
           where start_time >= sysdate - 30
         )
       ), 'NONE')
from dual;
select 'CSIM_MAA|datafiles_without_backup_metadata|' || count(*)
from (
  select df.file#
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
  having max(bdf.completion_time) is null
);

select 'CSIM_MAA|remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status <> 'INACTIVE';
select 'CSIM_MAA|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_MAA|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_MAA|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_MAA|dataguard_stats_count|' || count(*) from v$dataguard_stats;
select 'CSIM_MAA|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_MAA|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

select 'CSIM_MAA|tde_wallet_open_count|' || count(*)
from v$encryption_wallet
where status = 'OPEN';
select 'CSIM_MAA|tde_wallet_not_open_count|' || count(*)
from v$encryption_wallet
where status <> 'OPEN';
select 'CSIM_MAA|encrypted_tablespace_count|' || count(*)
from dba_tablespaces
where encrypted = 'YES';

select 'CSIM_MAA|pdb_count|' ||
       case when (select cdb from v$database) = 'YES'
            then (select count(*) from v$pdbs where name <> 'PDB$SEED')
            else 0
       end
from dual;
select 'CSIM_MAA|pdb_not_open_rw_count|' ||
       case when (select cdb from v$database) = 'YES'
            then (select count(*) from v$pdbs where name <> 'PDB$SEED' and open_mode <> 'READ WRITE')
            else 0
       end
from dual;

declare
  l_service_view varchar2(30) := 'DBA_SERVICES';
  l_aq_column varchar2(30);
  l_count number;
  l_has_failover_type boolean;
  l_has_commit_outcome boolean;
  l_has_aq_notification boolean;
  l_has_goal boolean;
  l_has_clb_goal boolean;
  l_has_drain_timeout boolean;
  l_has_session_state boolean;
  l_has_failover_restore boolean;
  l_has_pdb boolean;
  l_ac_condition varchar2(2000) := '1=0';
  l_tac_condition varchar2(2000) := '1=0';
  l_replay_condition varchar2(2000) := '1=0';
  l_user_filter varchar2(1000) := q'[name not like 'SYS$%' and upper(name) not in ('XDB')]';

  function has_column(p_table_name varchar2, p_column_name varchar2) return boolean is
    l_count number;
  begin
    select count(*)
    into l_count
    from all_tab_columns
    where table_name = upper(p_table_name)
      and column_name = upper(p_column_name);
    return l_count > 0;
  exception
    when others then
      return false;
  end;

  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_MAA|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  procedure emit_count(p_key varchar2, p_sql varchar2) is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    emit(p_key, to_char(l_count));
  exception
    when others then
      emit(p_key, 'UNKNOWN');
  end;
begin
  l_has_failover_type := has_column(l_service_view, 'FAILOVER_TYPE');
  l_has_commit_outcome := has_column(l_service_view, 'COMMIT_OUTCOME');
  if has_column(l_service_view, 'AQ_HA_NOTIFICATION') then
    l_has_aq_notification := true;
    l_aq_column := 'aq_ha_notification';
  elsif has_column(l_service_view, 'AQ_HA_NOTIFICATIONS') then
    l_has_aq_notification := true;
    l_aq_column := 'aq_ha_notifications';
  else
    l_has_aq_notification := false;
    l_aq_column := null;
  end if;
  l_has_goal := has_column(l_service_view, 'GOAL');
  l_has_clb_goal := has_column(l_service_view, 'CLB_GOAL');
  l_has_drain_timeout := has_column(l_service_view, 'DRAIN_TIMEOUT');
  l_has_session_state := has_column(l_service_view, 'SESSION_STATE_CONSISTENCY');
  l_has_failover_restore := has_column(l_service_view, 'FAILOVER_RESTORE');
  l_has_pdb := has_column(l_service_view, 'PDB');

  emit('service_attribute_source', l_service_view);
  emit('service_failover_type_column', case when l_has_failover_type then 'YES' else 'NO' end);
  emit('service_commit_outcome_column', case when l_has_commit_outcome then 'YES' else 'NO' end);
  emit('service_aq_ha_notification_column', case when l_has_aq_notification then 'YES' else 'NO' end);
  emit('service_drain_timeout_column', case when l_has_drain_timeout then 'YES' else 'NO' end);
  emit('service_session_state_column', case when l_has_session_state then 'YES' else 'NO' end);

  if l_has_failover_type then
    l_ac_condition := l_ac_condition || q'[ or upper(nvl(failover_type,'')) = 'TRANSACTION']';
    l_tac_condition := l_tac_condition || q'[ or upper(nvl(failover_type,'')) = 'AUTO']';
    l_replay_condition := l_replay_condition || q'[ or upper(nvl(failover_type,'')) in ('TRANSACTION','AUTO')]';
  end if;
  if l_has_commit_outcome then
    l_ac_condition := l_ac_condition || q'[ or upper(nvl(commit_outcome,'')) in ('YES','TRUE')]';
    l_replay_condition := l_replay_condition || q'[ or upper(nvl(commit_outcome,'')) in ('YES','TRUE')]';
  end if;

  emit_count('service_total_count', 'select count(*) from ' || l_service_view);
  emit_count('service_user_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter);
  emit_count('ac_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_ac_condition || ')');
  emit_count('tac_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_tac_condition || ')');
  emit_count('application_continuity_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_replay_condition || ')');
  emit_count('service_without_ac_tac_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and not (' || l_replay_condition || ')');

  if l_has_commit_outcome then
    emit_count('commit_outcome_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(commit_outcome,'')) in ('YES','TRUE')]');
  else
    emit('commit_outcome_service_count', 'UNKNOWN');
  end if;

  if l_has_aq_notification then
    emit_count('fan_notification_service_count', 'select count(*) from dba_services where name not like ''SYS$%'' and upper(name) not in (''XDB'') and upper(nvl(' || l_aq_column || ',''NO'')) in (''YES'',''TRUE'')');
  else
    emit('fan_notification_service_count', 'UNKNOWN');
  end if;

  if l_has_goal and l_has_clb_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and (upper(nvl(goal,'NONE')) <> 'NONE' or upper(nvl(clb_goal,'NONE')) <> 'NONE')]');
  elsif l_has_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(goal,'NONE')) <> 'NONE']');
  elsif l_has_clb_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(clb_goal,'NONE')) <> 'NONE']');
  else
    emit('runtime_load_balancing_service_count', 'UNKNOWN');
  end if;

  if l_has_drain_timeout then
    emit_count('drain_timeout_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and nvl(drain_timeout,0) > 0]');
  else
    emit('drain_timeout_service_count', 'UNKNOWN');
  end if;

  if l_has_session_state then
    emit_count('session_state_consistency_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(session_state_consistency,'NONE')) not in ('NONE','STATIC')]');
  else
    emit('session_state_consistency_service_count', 'UNKNOWN');
  end if;

  if l_has_failover_restore then
    emit_count('failover_restore_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(failover_restore,'NONE')) not in ('NONE','NO')]');
  else
    emit('failover_restore_service_count', 'UNKNOWN');
  end if;

  if l_has_pdb then
    emit_count('pdb_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and pdb is not null]');
  else
    emit('pdb_service_count', 'UNKNOWN');
  end if;

  begin
    execute immediate 'select count(*) from dba_capture' into l_count;
    emit('capture_process_count', to_char(l_count));
  exception
    when others then
      emit('capture_process_count', 'UNKNOWN');
  end;

  begin
    execute immediate 'select count(*) from dba_apply' into l_count;
    emit('apply_process_count', to_char(l_count));
  exception
    when others then
      emit('apply_process_count', 'UNKNOWN');
  end;
end;
/

exit
SQL
}

parse_maa_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  MAA_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_MAA" && -n "$key" ]] || continue
    MAA_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

