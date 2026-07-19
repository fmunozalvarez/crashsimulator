adb_python_bin() {
  if [[ -n "$ADB_PYTHON" && -x "$ADB_PYTHON" ]]; then
    printf "%s" "$ADB_PYTHON"
    return "$SUCCESS"
  fi
  command -v "$ADB_PYTHON" 2>/dev/null || return "$FAIL"
}

adb_wallet_tnsnames() {
  [[ -n "$ADB_WALLET_DIR" && -f "${ADB_WALLET_DIR}/tnsnames.ora" ]] || return "$FAIL"
  printf "%s" "${ADB_WALLET_DIR}/tnsnames.ora"
}

adb_wallet_aliases() {
  local tns
  tns="$(adb_wallet_tnsnames)" || return "$FAIL"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/ {
      alias=$0
      sub(/=.*/, "", alias)
      gsub(/[[:space:]]/, "", alias)
      if (alias != "" && alias !~ /^\(/) print alias
    }
  ' "$tns" | sort -u
}

adb_default_alias() {
  local alias wanted first_alias

  if [[ -n "$ADB_CONNECT_ALIAS" ]]; then
    printf "%s" "$ADB_CONNECT_ALIAS"
    return "$SUCCESS"
  fi

  wanted="_$(printf "%s" "$ADB_SERVICE_LEVEL" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r alias; do
    [[ -n "$alias" ]] || continue
    [[ -n "$first_alias" ]] || first_alias="$alias"
    if [[ "$(printf "%s" "$alias" | tr '[:upper:]' '[:lower:]')" == *"${wanted}" ]]; then
      printf "%s" "$alias"
      return "$SUCCESS"
    fi
  done < <(adb_wallet_aliases 2>/dev/null || true)

  [[ -n "$first_alias" ]] || return "$FAIL"
  printf "%s" "$first_alias"
}

adb_effective_dsn() {
  if [[ -n "$ADB_CONNECT_DESCRIPTOR" ]]; then
    printf "%s" "$ADB_CONNECT_DESCRIPTOR"
    return "$SUCCESS"
  fi
  adb_default_alias
}

adb_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${ADB_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

adb_positive() {
  local key="$1"
  local value
  value="$(adb_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

adb_truthy_value() {
  local key="$1"
  local value
  value="$(printf "%s" "$(adb_value "$key" "false")" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]
}

parse_adb_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  ADB_EVIDENCE=()
  [[ -f "$evidence_file" ]] || return "$FAIL"
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_ADB" && -n "$key" ]] || continue
    ADB_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

collect_adb_oci_metadata() {
  local evidence_file="$1"
  local metadata_file="$2"
  local -a oci_cmd
  local py

  if [[ -z "$ADB_OCID" ]]; then
    printf 'CSIM_ADB|oci_metadata_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_reason|ADB OCID is not configured.\n' >>"$evidence_file"
    return "$SUCCESS"
  fi
  if ! command -v oci >/dev/null 2>&1; then
    printf 'CSIM_ADB|oci_metadata_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_reason|OCI CLI was not found in PATH.\n' >>"$evidence_file"
    return "$SUCCESS"
  fi

  oci_cmd=(oci db autonomous-database get --autonomous-database-id "$ADB_OCID")
  [[ -n "$ADB_OCI_PROFILE" ]] && oci_cmd+=(--profile "$ADB_OCI_PROFILE")
  [[ -n "$ADB_OCI_CONFIG_FILE" ]] && oci_cmd+=(--config-file "$ADB_OCI_CONFIG_FILE")
  [[ -n "$ADB_REGION" ]] && oci_cmd+=(--region "$ADB_REGION")
  [[ -n "$ADB_OCI_AUTH" ]] && oci_cmd+=(--auth "$ADB_OCI_AUTH")

  if ! "${oci_cmd[@]}" >"$metadata_file" 2>"${metadata_file}.err"; then
    printf 'CSIM_ADB|oci_metadata_status|ERROR\n' >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_file|%s\n' "$metadata_file" >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_reason|%s\n' "$(tr '\n' ' ' <"${metadata_file}.err" | cut -c1-1000)" >>"$evidence_file"
    return "$SUCCESS"
  fi

  printf 'CSIM_ADB|oci_metadata_status|OK\n' >>"$evidence_file"
  printf 'CSIM_ADB|oci_metadata_file|%s\n' "$metadata_file" >>"$evidence_file"
  py="$(adb_python_bin 2>/dev/null || command -v python3 2>/dev/null || true)"
  if [[ -z "$py" ]]; then
    printf 'CSIM_ADB|oci_metadata_parse_status|SKIPPED_NO_PYTHON\n' >>"$evidence_file"
    return "$SUCCESS"
  fi

  "$py" - "$metadata_file" >>"$evidence_file" <<'PY' || printf 'CSIM_ADB|oci_metadata_parse_status|ERROR\n' >>"$evidence_file"
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle).get("data", {})

def clean(value):
    if value is None:
        return "NONE"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (list, tuple)):
        return ", ".join(clean(v) for v in value) if value else "NONE"
    if isinstance(value, dict):
        return json.dumps(value, sort_keys=True)
    return str(value).replace("\n", " ").replace("\r", " ")[:4000]

fields = {
    "oci_display_name": "display-name",
    "oci_db_name": "db-name",
    "oci_lifecycle_state": "lifecycle-state",
    "oci_compartment_id": "compartment-id",
    "oci_time_created": "time-created",
    "oci_backup_retention_days": "backup-retention-period-in-days",
    "oci_total_backup_storage_gb": "total-backup-storage-size-in-gbs",
    "oci_manual_backup_type": ("backup-config", "manual-backup-type"),
    "oci_manual_backup_bucket_name": ("backup-config", "manual-backup-bucket-name"),
    "oci_is_backup_retention_locked": "is-backup-retention-locked",
    "oci_is_data_guard_enabled": "is-data-guard-enabled",
    "oci_is_local_data_guard_enabled": "is-local-data-guard-enabled",
    "oci_is_remote_data_guard_enabled": "is-remote-data-guard-enabled",
    "oci_dataguard_region_type": "dataguard-region-type",
    "oci_standby_db": "standby-db",
    "oci_peer_db_ids": "peer-db-ids",
    "oci_private_endpoint": "private-endpoint",
    "oci_private_endpoint_label": "private-endpoint-label",
    "oci_private_endpoint_ip": "private-endpoint-ip",
    "oci_nsg_ids": "nsg-ids",
    "oci_data_safe_status": "data-safe-status",
    "oci_operations_insights_status": "operations-insights-status",
    "oci_permission_level": "permission-level",
    "oci_license_model": "license-model",
    "oci_compute_model": "compute-model",
    "oci_compute_count": "compute-count",
    "oci_data_storage_size_gb": "data-storage-size-in-gbs",
    "oci_actual_used_data_storage_tb": "actual-used-data-storage-size-in-tbs",
    "oci_apex_version": ("apex-details", "apex-version"),
    "oci_ords_version": ("apex-details", "ords-version"),
    "oci_supported_clone_regions": "supported-regions-to-clone-to",
}

def value_for(selector):
    current = data
    if isinstance(selector, tuple):
        for item in selector:
            if not isinstance(current, dict):
                return None
            current = current.get(item)
        return current
    return data.get(selector)

print("CSIM_ADB|oci_metadata_parse_status|OK")
for key, selector in fields.items():
    print(f"CSIM_ADB|{key}|{clean(value_for(selector))}")
PY
}

adb_check_ok=0
adb_check_warn=0
adb_check_gap=0
adb_check_info=0
adb_scorecard_sum=0
adb_scorecard_count=0

adb_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  case "$status" in
    OK) adb_check_ok=$((adb_check_ok + 1)) ;;
    WARN) adb_check_warn=$((adb_check_warn + 1)) ;;
    GAP) adb_check_gap=$((adb_check_gap + 1)) ;;
    INFO) adb_check_info=$((adb_check_info + 1)) ;;
  esac

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

adb_scorecard_reset() {
  adb_scorecard_sum=0
  adb_scorecard_count=0
}

adb_scorecard_points() {
  local status="$1"
  case "$status" in
    PASS) printf "100" ;;
    PARTIAL) printf "60" ;;
    WARN) printf "40" ;;
    GAP) printf "0" ;;
    INFO) printf "0" ;;
    *) printf "0" ;;
  esac
}

adb_append_scorecard_row() {
  local report_file="$1"
  local domain="$2"
  local status="$3"
  local evidence="$4"
  local recommendation="$5"
  local points

  points="$(adb_scorecard_points "$status")"
  if [[ "$status" != "INFO" ]]; then
    adb_scorecard_sum=$((adb_scorecard_sum + points))
    adb_scorecard_count=$((adb_scorecard_count + 1))
  fi

  printf '| %s | `%s` | %s | %s |\n' \
    "$(md_escape "$domain")" \
    "$(md_escape "$status")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

adb_scorecard_score() {
  if [[ "$adb_scorecard_count" -gt 0 ]]; then
    printf "%s" $((adb_scorecard_sum / adb_scorecard_count))
  else
    printf "0"
  fi
}

run_adb_sql_probe() {
  local evidence_file="$1"
  local python_bin dsn db_password wallet_password wallet_dir_arg tls_mode probe_script status

  : >"$evidence_file" || die "Unable to write ADB evidence file: $evidence_file"
  {
    printf 'CSIM_ADB|generated_utc|%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'CSIM_ADB|host|%s\n' "$(hostname 2>/dev/null || printf unknown)"
    printf 'CSIM_ADB|os_user|%s\n' "$(id -un 2>/dev/null || printf unknown)"
  } >>"$evidence_file"

  python_bin="$(adb_python_bin 2>/dev/null || true)"
  if [[ -z "$python_bin" ]]; then
    printf 'CSIM_ADB|python_status|NOT_FOUND\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_reason|Python executable not found: %s\n' "$ADB_PYTHON" >>"$evidence_file"
    return "$SUCCESS"
  fi
  printf 'CSIM_ADB|python_executable|%s\n' "$python_bin" >>"$evidence_file"

  dsn="$(adb_effective_dsn 2>/dev/null || true)"
  if [[ -z "$dsn" ]]; then
    printf 'CSIM_ADB|connect_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_reason|No ADB connect descriptor or wallet TNS alias was configured.\n' >>"$evidence_file"
    return "$SUCCESS"
  fi
  printf 'CSIM_ADB|dsn_source|%s\n' "$([[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && printf descriptor || printf alias)" >>"$evidence_file"
  printf 'CSIM_ADB|dsn_label|%s\n' "$([[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && printf configured_descriptor || printf "%s" "$dsn")" >>"$evidence_file"

  db_password="${!ADB_PASSWORD_ENV:-}"
  wallet_password="${!ADB_WALLET_PASSWORD_ENV:-}"
  [[ -n "$wallet_password" ]] || wallet_password="$db_password"
  if [[ -z "$db_password" ]]; then
    printf 'CSIM_ADB|connect_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_reason|Database password environment variable is not set: %s\n' "$ADB_PASSWORD_ENV" >>"$evidence_file"
    return "$SUCCESS"
  fi

  wallet_dir_arg=""
  if [[ -n "$ADB_WALLET_DIR" ]]; then
    wallet_dir_arg="$ADB_WALLET_DIR"
  fi
  tls_mode="$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')"
  probe_script="${WORK_DIR}/adb_probe.py"
  cat >"$probe_script" <<'PY' || die "Unable to write ADB probe script: $probe_script"
import os
import sys

wallet_dir = sys.argv[1]
dsn = sys.argv[2]
user = sys.argv[3]
tls_mode = sys.argv[4].lower()
db_password = sys.stdin.readline().rstrip("\n")
wallet_password = sys.stdin.readline().rstrip("\n")

def clean(value):
    if value is None:
        return "UNKNOWN"
    return str(value).replace("\n", " ").replace("\r", " ")[:4000]

def emit(key, value):
    print(f"CSIM_ADB|{key}|{clean(value)}")

try:
    import oracledb
except Exception as exc:
    emit("python_status", "ORACLEDB_IMPORT_FAILED")
    emit("connect_status", "SKIPPED")
    emit("connect_reason", exc)
    sys.exit(0)

emit("python_status", "OK")
emit("python_oracledb_version", getattr(oracledb, "__version__", "UNKNOWN"))

kwargs = {
    "user": user,
    "password": db_password,
    "dsn": dsn,
    "tcp_connect_timeout": 5,
    "retry_count": 0,
    "retry_delay": 0,
}
if wallet_dir:
    os.environ["TNS_ADMIN"] = wallet_dir
    kwargs["config_dir"] = wallet_dir
    if tls_mode == "mtls":
        kwargs["wallet_location"] = wallet_dir
        if wallet_password:
            kwargs["wallet_password"] = wallet_password

try:
    conn = oracledb.connect(**kwargs)
except Exception as exc:
    emit("connect_status", "ERROR")
    emit("connect_reason", exc)
    sys.exit(0)

emit("connect_status", "OK")

def scalar(key, sql, default="UNKNOWN"):
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            row = cur.fetchone()
            emit(key, row[0] if row and row[0] is not None else default)
    except Exception as exc:
        emit(key, "ERROR: " + clean(exc))

def list_value(key, sql, sep=", "):
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            values = [clean(row[0]) for row in cur.fetchall() if row and row[0] is not None]
            emit(key, sep.join(values) if values else "NONE")
    except Exception as exc:
        emit(key, "ERROR: " + clean(exc))

scalar("current_user", "select user from dual")
scalar("db_identity", "select name || '|' || open_mode || '|' || database_role || '|' || cdb || '|' || log_mode || '|' || flashback_on || '|' || protection_mode from v$database")
scalar("db_name", "select name from v$database")
scalar("open_mode", "select open_mode from v$database")
scalar("database_role", "select database_role from v$database")
scalar("cdb", "select cdb from v$database")
scalar("log_mode", "select log_mode from v$database")
scalar("flashback_on", "select flashback_on from v$database")
scalar("protection_mode", "select protection_mode from v$database")
scalar("version", "select banner_full from v$version where banner_full like 'Oracle%' fetch first 1 row only")
scalar("version_number", "select version_full from v$instance")
scalar("service_count", "select count(*) from v$services")
list_value("services", "select name from v$services order by name")
scalar("apex_registry_count", "select count(*) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%'")
scalar("apex_version_status", "select nvl(max(version || ':' || status), 'NONE') from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%'")
scalar("invalid_object_count", "select count(*) from dba_objects where status <> 'VALID'")
scalar("admin_object_count", "select count(*) from user_objects")
scalar("user_table_count", "select count(*) from user_tables")
scalar("recyclebin_count", "select count(*) from recyclebin")
scalar("tablespace_count", "select count(*) from dba_tablespaces")
scalar("encrypted_tablespace_count", "select count(*) from dba_tablespaces where encrypted = 'YES'")
scalar("segment_size_gb", "select round(sum(bytes)/1024/1024/1024, 2) from dba_segments")
scalar("flashback_archive_count", "select count(*) from dba_flashback_archive")
scalar("flashback_archive_retention_days", "select nvl(max(retention_in_days),0) from dba_flashback_archive")
scalar("open_application_user_count", "select count(*) from dba_users where oracle_maintained = 'N' and account_status like 'OPEN%'")
list_value("application_users", "select username || ':' || account_status from dba_users where oracle_maintained = 'N' order by username")
scalar("resource_plan", "select nvl(name, 'NONE') from v$rsrc_plan where is_top_plan = 'TRUE' fetch first 1 row only")
conn.close()
PY

  if { printf "%s\n%s\n" "$db_password" "$wallet_password"; } |
    "$python_bin" "$probe_script" "$wallet_dir_arg" "$dsn" "$ADB_USER" "$tls_mode" >>"$evidence_file" 2>&1; then
    status=0
  else
    status=$?
    printf 'CSIM_ADB|probe_exit_status|%s\n' "$status" >>"$evidence_file"
  fi
  return "$SUCCESS"
}

adb_append_scenario_row() {
  local report_file="$1"
  local id="$2"
  local scenario="$3"
  local status="$4"
  local validation="$5"
  local recovery="$6"

  printf '| `%s` | %s | `%s` | %s | %s |\n' \
    "$(md_escape "$id")" \
    "$(md_escape "$scenario")" \
    "$(md_escape "$status")" \
    "$(md_escape "$validation")" \
    "$(md_escape "$recovery")" >>"$report_file"
}

run_adb_readiness_report() {
  local report_file latest_file latest_evidence_file evidence_file oci_metadata_file generated_at aliases alias_list python_bin wallet_state tns_state dsn_label oci_state control_plane_state
  local score_den score id status reason
  local adb_domain_score resource_plan flashback_on connect_status tls_mode_lower backup_retention clone_regions metadata_status

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_adb_readiness_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_adb_readiness_latest.md"
  latest_evidence_file="${LOG_DIR}/crashsim_adb_readiness_latest.evidence"
  evidence_file="${LOG_DIR}/crashsim_adb_readiness_${RUN_ID}.evidence"
  oci_metadata_file="${LOG_DIR}/crashsim_adb_readiness_${RUN_ID}_oci_adb.json"
  adb_check_ok=0
  adb_check_warn=0
  adb_check_gap=0
  adb_check_info=0

  aliases="$(adb_wallet_aliases 2>/dev/null | awk 'BEGIN { first=1 } { printf "%s%s", (first ? "" : ", "), $0; first=0 } END { if (first) exit 1 }' 2>/dev/null || true)"
  [[ -n "$aliases" ]] || aliases="not available"
  python_bin="$(adb_python_bin 2>/dev/null || true)"
  wallet_state="not configured"
  tns_state="not configured"
  if [[ -n "$ADB_WALLET_DIR" ]]; then
    if [[ -d "$ADB_WALLET_DIR" ]]; then
      wallet_state="present"
      [[ -f "${ADB_WALLET_DIR}/tnsnames.ora" ]] && tns_state="present" || tns_state="missing"
    else
      wallet_state="missing"
      tns_state="missing"
    fi
  fi
  dsn_label="$(adb_effective_dsn 2>/dev/null || true)"
  [[ -n "$dsn_label" ]] || dsn_label="not configured"
  [[ -z "$ADB_CONNECT_DESCRIPTOR" ]] || dsn_label="configured descriptor"
  if command -v oci >/dev/null 2>&1; then
    oci_state="found"
  else
    oci_state="not found"
  fi
  if [[ -n "$ADB_OCID" && "$oci_state" == "found" ]]; then
    control_plane_state="configured"
  elif [[ -n "$ADB_OCID" ]]; then
    control_plane_state="OCID configured, OCI CLI not found"
  else
    control_plane_state="not configured"
  fi

  run_adb_sql_probe "$evidence_file"
  collect_adb_oci_metadata "$evidence_file" "$oci_metadata_file"
  parse_adb_evidence_file "$evidence_file" || true
  if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
    control_plane_state="metadata collected"
  elif [[ -n "$ADB_OCID" && "$oci_state" == "found" ]]; then
    control_plane_state="configured, metadata query $(adb_value oci_metadata_status UNKNOWN)"
  fi

  {
    printf "# CrashSimulator Autonomous Database Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- ADB user: `%s`\n' "$(md_escape "$ADB_USER")"
    printf -- '- TLS mode: `%s`\n' "$(md_escape "$ADB_TLS_MODE")"
    printf -- '- Evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "Autonomous Database hides OS, storage, ASM, Grid Infrastructure, control files, redo files, SPFILE, password file, and managed-backup internals from customers. This report therefore separates traditional CrashSimulator database-host scenarios from cloud-service scenarios that are realistic for ADB: logical/user-error recovery, clone/PITR, wallet/connectivity, service limits, Autonomous Data Guard, IAM, and Object Storage dependencies.\n"
  } >"$report_file" || die "Unable to write ADB readiness report: $report_file"

  append_report_section "$report_file" "Connection And Configuration"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| Wallet directory | `%s` |\n' "$(md_escape "${ADB_WALLET_DIR:-not configured}")"
    printf '| Wallet state | `%s` |\n' "$(md_escape "$wallet_state")"
    printf '| tnsnames.ora | `%s` |\n' "$(md_escape "$tns_state")"
    printf '| Wallet aliases | `%s` |\n' "$(md_escape "$aliases")"
    printf '| Connect alias / descriptor | `%s` |\n' "$(md_escape "$dsn_label")"
    printf '| Service-level hint | `%s` |\n' "$(md_escape "$ADB_SERVICE_LEVEL")"
    printf '| Password env var | `%s` |\n' "$(md_escape "$ADB_PASSWORD_ENV")"
    printf '| Wallet password env var | `%s` |\n' "$(md_escape "$ADB_WALLET_PASSWORD_ENV")"
    printf '| Python executable | `%s` |\n' "$(md_escape "${python_bin:-not found}")"
    printf '| python-oracledb | `%s` |\n' "$(md_escape "$(adb_value python_oracledb_version "$(adb_value python_status "not checked")")")"
    printf '| SQL connection | `%s` |\n' "$(md_escape "$(adb_value connect_status UNKNOWN)")"
    printf '| OCI CLI | `%s` |\n' "$(md_escape "$oci_state")"
    printf '| OCI control-plane posture | `%s` |\n' "$(md_escape "$control_plane_state")"
    printf '| OCI auth mode | `%s` |\n' "$(md_escape "${ADB_OCI_AUTH:-default}")"
    printf '| OCI metadata status | `%s` |\n' "$(md_escape "$(adb_value oci_metadata_status UNKNOWN)")"
    printf '| OCI ADB lifecycle | `%s` |\n' "$(md_escape "$(adb_value oci_lifecycle_state UNKNOWN)")"
    printf '| OCI backup retention days | `%s` |\n' "$(md_escape "$(adb_value oci_backup_retention_days UNKNOWN)")"
    printf '| APEX URL | `%s` |\n' "$(md_escape "${ADB_APEX_URL:-not configured}")"
    printf '| Database Actions URL | `%s` |\n' "$(md_escape "${ADB_DATABASE_ACTIONS_URL:-not configured}")"
    printf '| Private endpoint expectation | `%s` |\n' "$(md_escape "${ADB_PRIVATE_ENDPOINT:-not configured}")"
  } >>"$report_file"

  append_report_section "$report_file" "Live SQL Evidence Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| DB identity | `%s` |\n' "$(md_escape "$(adb_value db_identity "not connected")")"
    printf '| Version | `%s` |\n' "$(md_escape "$(adb_value version "not connected")")"
    printf '| Version number | `%s` |\n' "$(md_escape "$(adb_value version_number "not connected")")"
    printf '| Services | `%s` |\n' "$(md_escape "$(adb_value services "not connected")")"
    printf '| APEX registry | `%s` |\n' "$(md_escape "$(adb_value apex_version_status "not connected")")"
    printf '| Tablespaces | `%s` |\n' "$(md_escape "$(adb_value tablespace_count "not connected")")"
    printf '| Encrypted tablespaces | `%s` |\n' "$(md_escape "$(adb_value encrypted_tablespace_count "not connected")")"
    printf '| Segment size GB | `%s` |\n' "$(md_escape "$(adb_value segment_size_gb "not connected")")"
    printf '| Flashback archive count | `%s` |\n' "$(md_escape "$(adb_value flashback_archive_count "not connected")")"
    printf '| Flashback archive retention days | `%s` |\n' "$(md_escape "$(adb_value flashback_archive_retention_days "not connected")")"
    printf '| Open application users | `%s` |\n' "$(md_escape "$(adb_value open_application_user_count "not connected")")"
    printf '| Application users | `%s` |\n' "$(md_escape "$(adb_value application_users "not connected")")"
    printf '| Invalid objects | `%s` |\n' "$(md_escape "$(adb_value invalid_object_count "not connected")")"
    printf '| Recycle bin rows | `%s` |\n' "$(md_escape "$(adb_value recyclebin_count "not connected")")"
    printf '| Resource plan | `%s` |\n' "$(md_escape "$(adb_value resource_plan "not connected")")"
  } >>"$report_file"

  append_report_section "$report_file" "OCI Control-Plane Evidence Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| Metadata status | `%s` |\n' "$(md_escape "$(adb_value oci_metadata_status UNKNOWN)")"
    printf '| Metadata file | `%s` |\n' "$(md_escape "$(adb_value oci_metadata_file "not collected")")"
    printf '| Display name / DB name | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_display_name UNKNOWN)")" "$(md_escape "$(adb_value oci_db_name UNKNOWN)")"
    printf '| Lifecycle state | `%s` |\n' "$(md_escape "$(adb_value oci_lifecycle_state UNKNOWN)")"
    printf '| Compartment OCID | `%s` |\n' "$(md_escape "$(adb_value oci_compartment_id UNKNOWN)")"
    printf '| Backup retention days | `%s` |\n' "$(md_escape "$(adb_value oci_backup_retention_days UNKNOWN)")"
    printf '| Total backup storage GB | `%s` |\n' "$(md_escape "$(adb_value oci_total_backup_storage_gb UNKNOWN)")"
    printf '| Manual backup type / bucket | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_manual_backup_type UNKNOWN)")" "$(md_escape "$(adb_value oci_manual_backup_bucket_name UNKNOWN)")"
    printf '| Data Guard enabled | `%s` |\n' "$(md_escape "$(adb_value oci_is_data_guard_enabled UNKNOWN)")"
    printf '| Local / remote Data Guard | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_is_local_data_guard_enabled UNKNOWN)")" "$(md_escape "$(adb_value oci_is_remote_data_guard_enabled UNKNOWN)")"
    printf '| Data Guard region type | `%s` |\n' "$(md_escape "$(adb_value oci_dataguard_region_type UNKNOWN)")"
    printf '| Peer DB IDs | `%s` |\n' "$(md_escape "$(adb_value oci_peer_db_ids UNKNOWN)")"
    printf '| Private endpoint / label / IP | `%s` / `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_private_endpoint UNKNOWN)")" "$(md_escape "$(adb_value oci_private_endpoint_label UNKNOWN)")" "$(md_escape "$(adb_value oci_private_endpoint_ip UNKNOWN)")"
    printf '| NSGs | `%s` |\n' "$(md_escape "$(adb_value oci_nsg_ids UNKNOWN)")"
    printf '| Data Safe / Operations Insights | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_data_safe_status UNKNOWN)")" "$(md_escape "$(adb_value oci_operations_insights_status UNKNOWN)")"
    printf '| Permission level | `%s` |\n' "$(md_escape "$(adb_value oci_permission_level UNKNOWN)")"
    printf '| APEX / ORDS version | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_apex_version UNKNOWN)")" "$(md_escape "$(adb_value oci_ords_version UNKNOWN)")"
    printf '| Supported clone regions | `%s` |\n' "$(md_escape "$(adb_value oci_supported_clone_regions UNKNOWN)")"
  } >>"$report_file"

  append_report_section "$report_file" "ADB Readiness Scorecard"
  {
    printf 'This scorecard summarizes Autonomous Database resilience domains separately from host-based Oracle Database scenarios. PASS means CrashSimulator found direct evidence in the current report. PARTIAL means the control path or prerequisite exists, but a drill or deeper OCI metadata check is still needed. GAP means the report cannot currently prove the domain.\n\n'
    printf '| Domain | Status | Evidence | Next action |\n'
    printf '| --- | --- | --- | --- |\n'
  } >>"$report_file"

  adb_scorecard_reset
  connect_status="$(adb_value connect_status UNKNOWN)"
  flashback_on="$(adb_value flashback_on UNKNOWN)"
  resource_plan="$(adb_value resource_plan UNKNOWN)"
  metadata_status="$(adb_value oci_metadata_status UNKNOWN)"
  backup_retention="$(adb_value oci_backup_retention_days 0)"
  clone_regions="$(adb_value oci_supported_clone_regions NONE)"
  tls_mode_lower="$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')"

  if [[ "$metadata_status" == "OK" ]]; then
    if [[ "$backup_retention" =~ ^[0-9]+$ && "$backup_retention" -gt 0 ]]; then
      adb_append_scorecard_row "$report_file" "Backup Readiness" "PASS" "OCI backup retention is ${backup_retention} days; total backup storage is $(adb_value oci_total_backup_storage_gb UNKNOWN) GB." "Run ADB07 clone/restore validation to convert configured backup posture into measured recoverability evidence."
    else
      adb_append_scorecard_row "$report_file" "Backup Readiness" "GAP" "OCI metadata was collected, but backup retention is ${backup_retention}." "Review ADB backup policy and confirm restore/clone capability."
    fi
    if [[ "$backup_retention" =~ ^[0-9]+$ && "$backup_retention" -gt 0 && "$clone_regions" != "NONE" && "$clone_regions" != "UNKNOWN" ]]; then
      adb_append_scorecard_row "$report_file" "PITR Validation" "PARTIAL" "Backup retention is ${backup_retention} days and supported clone regions are visible." "Run ADB06 with a selected timestamp and record elapsed clone, validation, and data-merge evidence before marking PASS."
    else
      adb_append_scorecard_row "$report_file" "PITR Validation" "GAP" "PITR/clone evidence is incomplete: retention=${backup_retention}, clone_regions=${clone_regions}." "Validate clone-to-time eligibility and run an ADB06 drill."
    fi
    if adb_truthy_value oci_is_data_guard_enabled; then
      adb_append_scorecard_row "$report_file" "Autonomous Data Guard Protection" "PASS" "OCI reports Autonomous Data Guard enabled; local=$(adb_value oci_is_local_data_guard_enabled UNKNOWN), remote=$(adb_value oci_is_remote_data_guard_enabled UNKNOWN), peer=$(adb_value oci_peer_db_ids NONE)." "Run ADB12/ADB13 to measure failover/switchover RTO/RPO and application reconnect."
    else
      adb_append_scorecard_row "$report_file" "Autonomous Data Guard Protection" "GAP" "OCI reports Autonomous Data Guard disabled; local=$(adb_value oci_is_local_data_guard_enabled UNKNOWN), remote=$(adb_value oci_is_remote_data_guard_enabled UNKNOWN)." "Enable/configure Autonomous Data Guard when DR requirements require managed standby protection."
    fi
    if adb_truthy_value oci_is_remote_data_guard_enabled || [[ "$(adb_value oci_dataguard_region_type NONE)" != "NONE" && "$(adb_value oci_dataguard_region_type NONE)" != "UNKNOWN" ]]; then
      adb_append_scorecard_row "$report_file" "Cross-Region DR" "PASS" "OCI remote Data Guard evidence exists: region_type=$(adb_value oci_dataguard_region_type UNKNOWN), peer=$(adb_value oci_peer_db_ids NONE)." "Validate failover/reconnect behavior and fallback plan with ADB12/ADB13."
    else
      adb_append_scorecard_row "$report_file" "Cross-Region DR" "GAP" "No remote Autonomous Data Guard peer is visible in OCI metadata." "Configure cross-region ADG or document accepted risk when regional DR is not required."
    fi
    if [[ "$(adb_value oci_data_safe_status NONE)" == "REGISTERED" ]]; then
      adb_append_scorecard_row "$report_file" "IAM / Administrator Access" "PASS" "OCI metadata is available and Data Safe is registered; permission level=$(adb_value oci_permission_level UNKNOWN)." "Keep IAM policy, break-glass, and automation-principal evidence current."
    else
      adb_append_scorecard_row "$report_file" "IAM / Administrator Access" "PARTIAL" "OCI metadata is available; Data Safe status=$(adb_value oci_data_safe_status UNKNOWN), permission level=$(adb_value oci_permission_level UNKNOWN)." "Review policies, groups, break-glass access, automation principal, and least-privilege boundaries before marking PASS."
    fi
  else
    adb_append_scorecard_row "$report_file" "Backup Readiness" "GAP" "OCI control-plane evidence is not configured: ${control_plane_state}." "Set CRASHSIM_ADB_OCID, OCI CLI/profile, and region to validate backup retention/latest backup."
    adb_append_scorecard_row "$report_file" "PITR Validation" "GAP" "PITR/clone windows cannot be proven from SQL-only evidence." "Configure OCI metadata collection and run an ADB06 clone-to-time validation."
    adb_append_scorecard_row "$report_file" "Autonomous Data Guard Protection" "GAP" "Autonomous Data Guard status, peer, lag, and transition eligibility require OCI metadata." "Configure OCI metadata collection before ADB12/ADB13 readiness claims."
    adb_append_scorecard_row "$report_file" "Cross-Region DR" "GAP" "Cross-region peer/standby evidence is not available in this report." "Add OCI metadata and validate regional failover/reconnect behavior."
    adb_append_scorecard_row "$report_file" "IAM / Administrator Access" "GAP" "IAM policy/group/break-glass posture cannot be validated without OCI context." "Configure compartment/OCI context and keep IAM checks read-only unless an approved test boundary exists."
  fi

  if [[ "$tls_mode_lower" == "mtls" ]]; then
    if [[ "$wallet_state" == "present" && "$tns_state" == "present" && "$connect_status" == "OK" ]]; then
      adb_append_scorecard_row "$report_file" "Wallet Management" "PASS" "mTLS wallet and tnsnames.ora are present, aliases are visible, and SQL probe connects." "Keep wallet rotation owner, distribution inventory, expiry review, and reconnect test evidence current."
    elif [[ "$wallet_state" == "present" && "$tns_state" == "present" ]]; then
      adb_append_scorecard_row "$report_file" "Wallet Management" "PARTIAL" "mTLS wallet files are present, but live SQL connectivity is not proven." "Fix password/network/alias issues and rerun the report before wallet rotation drills."
    else
      adb_append_scorecard_row "$report_file" "Wallet Management" "GAP" "mTLS wallet state=${wallet_state}, tnsnames=${tns_state}." "Download/extract the wallet, protect it as a credential, and configure client distribution runbooks."
    fi
  else
    adb_append_scorecard_row "$report_file" "Wallet Management" "INFO" "TLS mode is ${ADB_TLS_MODE}; mTLS wallet may not be required for this client path." "Confirm walletless TLS, hostname verification, and certificate lifecycle procedures."
  fi

  if [[ "$(adb_value oci_private_endpoint NONE)" != "NONE" && "$(adb_value oci_private_endpoint UNKNOWN)" != "UNKNOWN" ]]; then
    adb_append_scorecard_row "$report_file" "Private Endpoint Validation" "PARTIAL" "OCI private endpoint is configured: endpoint=$(adb_value oci_private_endpoint), label=$(adb_value oci_private_endpoint_label NONE), ip=$(adb_value oci_private_endpoint_ip NONE)." "Add DNS, route-table, NSG/security-list, bastion, and client reconnect evidence before marking PASS."
  elif [[ -n "$ADB_PRIVATE_ENDPOINT" ]]; then
    adb_append_scorecard_row "$report_file" "Private Endpoint Validation" "PARTIAL" "Private endpoint expectation is documented: ${ADB_PRIVATE_ENDPOINT}." "Add DNS, route-table, NSG/security-list, bastion, and client reconnect evidence before marking PASS."
  else
    adb_append_scorecard_row "$report_file" "Private Endpoint Validation" "INFO" "No private endpoint expectation was configured." "Set CRASHSIM_ADB_PRIVATE_ENDPOINT when the ADB uses private endpoints."
  fi

  if [[ "$connect_status" == "OK" && "$resource_plan" != "NONE" && "$resource_plan" != "UNKNOWN" && "$resource_plan" != "not connected" && "$resource_plan" != ERROR:* ]]; then
    adb_append_scorecard_row "$report_file" "Resource Manager" "PASS" "Resource plan evidence: ${resource_plan}." "Add workload threshold evidence for ADB10/ADB11 when validating saturation or concurrency pressure."
  elif [[ "$connect_status" == "OK" ]]; then
    adb_append_scorecard_row "$report_file" "Resource Manager" "PARTIAL" "SQL connection works, but Resource Manager plan evidence is ${resource_plan}." "Capture service class, scaling, workload, and concurrency evidence before resource-pressure drills."
  else
    adb_append_scorecard_row "$report_file" "Resource Manager" "GAP" "No live SQL evidence is available for Resource Manager posture." "Fix ADB connectivity, then rerun readiness collection."
  fi

  if adb_positive flashback_archive_count; then
    adb_append_scorecard_row "$report_file" "Logical / Object Recovery" "PASS" "Flashback Archive rows exist with retention_days=$(adb_value flashback_archive_retention_days UNKNOWN)." "Run seeded ADB01/ADB03/ADB04 drills to prove object-level recovery, not only configuration."
  elif [[ "$flashback_on" == "YES" ]]; then
    adb_append_scorecard_row "$report_file" "Logical / Object Recovery" "PARTIAL" "Database flashback is reported as YES, but Flashback Archive evidence is not present." "Validate Flashback Query/Table, Data Pump export, and clone/PITR fallback paths."
  else
    adb_append_scorecard_row "$report_file" "Logical / Object Recovery" "GAP" "Flashback/logical recovery evidence is insufficient: flashback_on=${flashback_on}, archives=$(adb_value flashback_archive_count UNKNOWN)." "Seed logical ADB lab objects and validate flashback/export/clone recovery paths."
  fi

  if [[ "$connect_status" == "OK" && ( -n "$ADB_APEX_URL" || -n "$ADB_DATABASE_ACTIONS_URL" ) ]]; then
    adb_append_scorecard_row "$report_file" "Application Access Path" "PASS" "SQL probe connects and user-facing URL context is recorded." "Add URL smoke checks and application login/session validation after wallet, clone/PITR, or ADG drills."
  elif [[ -n "$ADB_APEX_URL" || -n "$ADB_DATABASE_ACTIONS_URL" || "$(adb_value apex_registry_count 0)" =~ ^[1-9][0-9]*$ ]]; then
    adb_append_scorecard_row "$report_file" "Application Access Path" "PARTIAL" "Application or APEX evidence exists, but complete user-path validation is not proven." "Configure URL checks and application-specific validation."
  else
    adb_append_scorecard_row "$report_file" "Application Access Path" "INFO" "No APEX/Database Actions/application URL context is configured." "Record application access paths when ADB hosts user-facing applications."
  fi

  adb_domain_score="$(adb_scorecard_score)"
  {
    printf "\n| Metric | Value |\n"
    printf "| --- | ---: |\n"
    printf "| ADB Readiness Score | %s%% |\n" "$adb_domain_score"
    printf "| Scored domains | %s |\n" "$adb_scorecard_count"
  } >>"$report_file"

  append_report_section "$report_file" "Readiness Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')" == "mtls" ]]; then
    if [[ "$wallet_state" == "present" && "$tns_state" == "present" ]]; then
      adb_append_check "$report_file" "OK" "Client connectivity" "mTLS wallet available" "wallet=${ADB_WALLET_DIR}, aliases=${aliases}" "Keep wallet rotation, expiry review, and application redeploy steps in the runbook."
    else
      adb_append_check "$report_file" "GAP" "Client connectivity" "mTLS wallet available" "wallet=${wallet_state}, tnsnames=${tns_state}" "Download/extract the ADB wallet, protect it as a credential, and configure CRASHSIM_ADB_WALLET_DIR."
    fi
  else
    adb_append_check "$report_file" "INFO" "Client connectivity" "TLS mode selected" "tls_mode=${ADB_TLS_MODE}" "For TLS connections, confirm walletless access, hostname verification, and network ACL/security-list posture."
  fi

  if [[ -n "$python_bin" && "$(adb_value python_status UNKNOWN)" == "OK" ]]; then
    adb_append_check "$report_file" "OK" "Client connectivity" "python-oracledb available" "python=${python_bin}, version=$(adb_value python_oracledb_version)" "Pin driver/runtime versions in automation hosts used for readiness reporting."
  elif [[ -n "$python_bin" ]]; then
    adb_append_check "$report_file" "WARN" "Client connectivity" "python-oracledb available" "python=${python_bin}, status=$(adb_value python_status UNKNOWN)" "Install python-oracledb in the configured Python environment."
  else
    adb_append_check "$report_file" "GAP" "Client connectivity" "python-oracledb available" "python=${ADB_PYTHON} not found" "Install Python and python-oracledb on the bastion/client where ADB reports run."
  fi

  if [[ "$(adb_value connect_status UNKNOWN)" == "OK" ]]; then
    adb_append_check "$report_file" "OK" "Database access" "Live SQL probe connects" "user=$(adb_value current_user), db=$(adb_value db_name), open=$(adb_value open_mode), role=$(adb_value database_role)" "Use this same client path for logical recovery drills and application smoke tests."
  else
    adb_append_check "$report_file" "GAP" "Database access" "Live SQL probe connects" "status=$(adb_value connect_status), reason=$(adb_value connect_reason not available)" "Fix wallet, alias/descriptor, password env vars, or network path before running ADB drills."
  fi

  if adb_positive apex_registry_count; then
    adb_append_check "$report_file" "OK" "Application access" "APEX component visible" "APEX=$(adb_value apex_version_status)" "Add APEX smoke/session checks for user-facing ADB applications."
  else
    adb_append_check "$report_file" "INFO" "Application access" "APEX component visible" "APEX=$(adb_value apex_version_status NONE)" "If this ADB hosts APEX apps, configure ADB_APEX_URL and include APEX user-path validation."
  fi

  if adb_positive flashback_archive_count; then
    adb_append_check "$report_file" "OK" "Logical recovery" "Flashback Archive evidence" "archives=$(adb_value flashback_archive_count), retention_days=$(adb_value flashback_archive_retention_days)" "Use flashback query/table and clone/PITR drills for logical user-error recovery validation."
  else
    adb_append_check "$report_file" "INFO" "Logical recovery" "Flashback Archive evidence" "archives=$(adb_value flashback_archive_count UNKNOWN)" "Validate logical-object recovery using flashback query, Data Pump exports, or restore/clone to a point in time."
  fi

  if [[ "$control_plane_state" == "configured" ]]; then
    adb_append_check "$report_file" "OK" "OCI control plane" "ADB OCID and OCI CLI configured" "ocid=set, region=${ADB_REGION:-profile/default}, profile=${ADB_OCI_PROFILE}" "Use OCI evidence to validate backup retention, PITR window, Autonomous Data Guard, clones, and IAM posture."
  else
    adb_append_check "$report_file" "WARN" "OCI control plane" "ADB OCID and OCI CLI configured" "state=${control_plane_state}" "Configure CRASHSIM_ADB_OCID plus OCI CLI/profile when backup/PITR/ADG/IAM readiness must be proven."
  fi

  if [[ -n "$ADB_APEX_URL" || -n "$ADB_DATABASE_ACTIONS_URL" ]]; then
    adb_append_check "$report_file" "OK" "Application access" "User-facing URLs recorded" "apex=${ADB_APEX_URL:-not set}, database_actions=${ADB_DATABASE_ACTIONS_URL:-not set}" "Use URL smoke checks and application-specific login validation after clone/PITR or wallet rotation."
  else
    adb_append_check "$report_file" "INFO" "Application access" "User-facing URLs recorded" "not configured" "Record APEX and Database Actions URLs for operational validation evidence."
  fi

  if [[ -n "$ADB_PRIVATE_ENDPOINT" ]]; then
    adb_append_check "$report_file" "OK" "Network" "Private endpoint expectation documented" "private_endpoint=${ADB_PRIVATE_ENDPOINT}" "Pair this with DNS, route-table, NSG, and bastion evidence for private endpoint loss drills."
  else
    adb_append_check "$report_file" "INFO" "Network" "Private endpoint expectation documented" "not configured" "Set CRASHSIM_ADB_PRIVATE_ENDPOINT when ADB uses private endpoints."
  fi

  append_report_section "$report_file" "Readiness Summary"
  score_den=$((adb_check_ok + adb_check_warn + adb_check_gap))
  if [[ "$score_den" -gt 0 ]]; then
    score=$((adb_check_ok * 100 / score_den))
  else
    score=0
  fi
  {
    printf '| Metric | Value |\n'
    printf '| --- | ---: |\n'
    printf '| ADB readiness scorecard | %s%% |\n' "$adb_domain_score"
    printf '| Operational check score | %s%% |\n' "$score"
    printf '| OK checks | %s |\n' "$adb_check_ok"
    printf '| Warnings | %s |\n' "$adb_check_warn"
    printf '| Gaps | %s |\n' "$adb_check_gap"
    printf '| Informational checks | %s |\n' "$adb_check_info"
  } >>"$report_file"

  append_report_section "$report_file" "Autonomous Scenario Coverage"
  {
    printf '| ID | Scenario | Status | Validation process | Recovery/runbook focus |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"
  for id in "${ADB_SCENARIO_IDS[@]}"; do
    adb_scenario_readiness "$id" status reason
    adb_append_scenario_row "$report_file" "$id" "${ADB_SCENARIO_TITLE[$id]}" "$status" "${ADB_SCENARIO_VALIDATION[$id]} ${reason}" "${ADB_SCENARIO_RECOVERY[$id]}"
  done

  append_report_section "$report_file" "Traditional CrashSimulator Scenarios Not Applicable To ADB"
  {
    printf "Autonomous Database customers cannot directly remove/corrupt managed OS files, ASM disks, Grid Infrastructure resources, control files, redo logs, password files, SPFILEs, ORACLE_HOME, or RMAN backup pieces. For ADB, those failure classes should be represented as OCI service/readiness checks, clone/PITR validation, Autonomous Data Guard drills, and application access-path tests rather than destructive host actions.\n"
  } >>"$report_file"

  append_report_section "$report_file" "Recommended Configuration File Keys"
  {
    printf 'Use non-secret keys in `crashsimulator.conf`, and keep passwords in environment variables named by the config keys.\n\n'
    printf '```text\n'
    printf 'CRASHSIM_ADB_WALLET_DIR=/path/to/wallet\n'
    printf 'CRASHSIM_ADB_CONNECT_ALIAS=myadb_low\n'
    printf 'CRASHSIM_ADB_SERVICE_LEVEL=low\n'
    printf 'CRASHSIM_ADB_USER=ADMIN\n'
    printf 'CRASHSIM_ADB_PASSWORD_ENV=CRASHSIM_ADB_PASSWORD\n'
    printf 'CRASHSIM_ADB_WALLET_PASSWORD_ENV=CRASHSIM_ADB_WALLET_PASSWORD\n'
    printf 'CRASHSIM_ADB_PYTHON=/path/to/python\n'
    printf 'CRASHSIM_ADB_OCID=ocid1.autonomousdatabase...\n'
    printf 'CRASHSIM_ADB_REGION=us-ashburn-1\n'
    printf 'CRASHSIM_ADB_OCI_PROFILE=DEFAULT\n'
    printf 'CRASHSIM_ADB_OCI_AUTH=security_token\n'
    printf 'CRASHSIM_ADB_APEX_URL=https://example.adb.region.oraclecloudapps.com/ords/apex\n'
    printf '```\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw ADB Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    audit_redact_stream <"$evidence_file"
    printf '```\n'
  } >>"$report_file"

  if [[ -n "$ADB_OCID" && "$oci_state" == "found" ]]; then
    local -a oci_cmd=(oci db autonomous-database get --autonomous-database-id "$ADB_OCID")
    [[ -n "$ADB_OCI_PROFILE" ]] && oci_cmd+=(--profile "$ADB_OCI_PROFILE")
    [[ -n "$ADB_OCI_CONFIG_FILE" ]] && oci_cmd+=(--config-file "$ADB_OCI_CONFIG_FILE")
    [[ -n "$ADB_REGION" ]] && oci_cmd+=(--region "$ADB_REGION")
    [[ -n "$ADB_OCI_AUTH" ]] && oci_cmd+=(--auth "$ADB_OCI_AUTH")
    append_report_command "$report_file" "OCI Autonomous Database Metadata" "${oci_cmd[@]}"
  fi

  cp "$report_file" "$latest_file" || die "Unable to update latest ADB readiness report: $latest_file"
  cp "$evidence_file" "$latest_evidence_file" || die "Unable to update latest ADB readiness evidence: $latest_evidence_file"
  echo "Autonomous Database readiness report generated: ${report_file}"
  echo "Latest Autonomous Database readiness report: ${latest_file}"
  echo "Latest Autonomous Database readiness evidence: ${latest_evidence_file}"
  maybe_render_html "$report_file"
}

write_apex_ords_report_sql_file() {
  local sql_file="$1"
  local target_pdb="${2:-}"
  local target_pdb_sql=""

  if [[ -n "$target_pdb" ]]; then
    target_pdb_sql="alter session set container = $(sql_identifier "$target_pdb");"
  fi

  cat >"$sql_file" <<SQL || die "Unable to write APEX/ORDS report SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off
set serveroutput on size unlimited

select 'CSIM_APEX|db_name|' || name from v\$database;
select 'CSIM_APEX|db_unique_name|' || db_unique_name from v\$database;
select 'CSIM_APEX|db_role|' || database_role from v\$database;
select 'CSIM_APEX|open_mode|' || open_mode from v\$database;
select 'CSIM_APEX|cdb|' || cdb from v\$database;
select 'CSIM_APEX|instance_name|' || instance_name from v\$instance;
select 'CSIM_APEX|host_name|' || host_name from v\$instance;
select 'CSIM_APEX|version|' || version from v\$instance;

declare
  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_APEX|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  function scalar_value(p_sql varchar2, p_default varchar2 := 'UNKNOWN') return varchar2 is
    l_value varchar2(4000);
  begin
    execute immediate p_sql into l_value;
    return nvl(l_value, p_default);
  exception
    when others then
      return p_default;
  end;

  function scalar_count(p_sql varchar2, p_default varchar2 := 'UNKNOWN') return varchar2 is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    return to_char(l_count);
  exception
    when others then
      return p_default;
  end;
begin
  emit('target_pdb_requested', '${target_pdb:-not set}');
  emit('cdb_registry_apex_count', scalar_count(q'[select count(*) from cdb_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']'));
  emit('cdb_registry_ords_count', scalar_count(q'[select count(*) from cdb_registry where comp_id = 'ORDS' or upper(comp_name) like '%ORDS%']'));
  emit('cdb_apex_versions', scalar_value(q'[select listagg(con_id || ':' || version || ':' || status, ',') within group (order by con_id, version) from cdb_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']', 'NONE'));
  emit('cdb_ords_versions', scalar_value(q'[select listagg(con_id || ':' || version || ':' || status, ',') within group (order by con_id, version) from cdb_registry where comp_id = 'ORDS' or upper(comp_name) like '%ORDS%']', 'NONE'));
  emit('apex_public_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'APEX_PUBLIC_USER']'));
  emit('ords_public_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'ORDS_PUBLIC_USER']'));
  emit('ords_metadata_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'ORDS_METADATA']'));
  emit('runtime_locked_expired_count', scalar_count(q'[select count(*) from cdb_users where username in ('APEX_PUBLIC_USER','ORDS_PUBLIC_USER','ORDS_METADATA') and account_status not like 'OPEN%']'));
  emit('invalid_apex_object_count', scalar_count(q'[select count(*) from cdb_objects where owner like 'APEX\_%' escape '\' and status <> 'VALID']'));
  emit('invalid_ords_object_count', scalar_count(q'[select count(*) from cdb_objects where owner in ('ORDS_METADATA','ORDS_PUBLIC_USER') and status <> 'VALID']'));
  emit('network_acl_count', scalar_count(q'[select count(*) from dba_network_acls]'));
end;
/

${target_pdb_sql}
set serveroutput on size unlimited

select 'CSIM_APEX|current_container|' || sys_context('USERENV','CON_NAME') from dual;

declare
  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_APEX|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  function scalar_value(p_sql varchar2, p_default varchar2 := 'UNAVAILABLE') return varchar2 is
    l_value varchar2(4000);
  begin
    execute immediate p_sql into l_value;
    return nvl(l_value, p_default);
  exception
    when others then
      return p_default;
  end;

  function scalar_count(p_sql varchar2, p_default varchar2 := 'UNAVAILABLE') return varchar2 is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    return to_char(l_count);
  exception
    when others then
      return p_default;
  end;
begin
  emit('local_apex_registry_count', scalar_count(q'[select count(*) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']'));
  emit('local_apex_version', scalar_value(q'[select max(version || ':' || status) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']', 'NONE'));
  emit('local_ords_registry_count', scalar_count(q'[select count(*) from dba_registry where comp_id = 'ORDS' or upper(comp_name) like '%ORDS%']'));
  emit('local_apex_public_user_status', scalar_value(q'[select max(account_status) from dba_users where username = 'APEX_PUBLIC_USER']', 'MISSING'));
  emit('local_ords_public_user_status', scalar_value(q'[select max(account_status) from dba_users where username = 'ORDS_PUBLIC_USER']', 'MISSING'));
  emit('local_ords_metadata_user_status', scalar_value(q'[select max(account_status) from dba_users where username = 'ORDS_METADATA']', 'MISSING'));
  emit('local_invalid_apex_objects', scalar_count(q'[select count(*) from dba_objects where owner like 'APEX\_%' escape '\' and status <> 'VALID']'));
  emit('local_invalid_ords_objects', scalar_count(q'[select count(*) from dba_objects where owner in ('ORDS_METADATA','ORDS_PUBLIC_USER') and status <> 'VALID']'));
  emit('apex_workspace_count', scalar_count(q'[select count(*) from apex_workspaces]'));
  emit('apex_application_count', scalar_count(q'[select count(*) from apex_applications]'));
  emit('apex_smtp_parameter_count', scalar_count(q'[select count(*) from apex_instance_parameters where upper(name) like 'SMTP%' and value is not null]'));
  emit('apex_wallet_parameter_count', scalar_count(q'[select count(*) from apex_instance_parameters where upper(name) like '%WALLET%' and value is not null]'));
  emit('local_network_acl_count', scalar_count(q'[select count(*) from dba_network_acls]'));
end;
/

exit
SQL
}

parse_apex_ords_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  APEX_ORDS_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_APEX" && -n "$key" ]] || continue
    APEX_ORDS_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

