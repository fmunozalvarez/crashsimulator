menu_pause() {
  local answer
  echo
  echo "Press Enter to continue..."
  read -r answer || true
}

menu_selected_scenario_label() {
  if [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]; then
    printf "%s - %s" "$SCENARIO_ID" "${SCENARIO_TITLE[$SCENARIO_ID]}"
  else
    printf "none"
  fi
}

menu_discover_environment_optional() {
  if load_topology_cache; then
    return "$SUCCESS"
  fi

  if [[ "$ORACLE_USER_REQUIRED" -eq 1 && "$(id -un)" != "oracle" ]]; then
    warn "Database topology discovery skipped: this run requires OS user oracle, current user is $(id -un)."
    warn "ADB scenarios, ADB readiness reports, review, and configuration menus remain available."
    return "$SUCCESS"
  fi

  if ! find_sqlplus_if_available; then
    warn "Database topology discovery skipped: sqlplus was not found. Set ORACLE_HOME or SQLPLUS for database-host scenarios."
    warn "ADB scenarios, ADB readiness reports, review, and configuration menus remain available."
    return "$SUCCESS"
  fi

  discover_environment || warn "Database topology discovery did not complete. The guided menu will open with currently available context."
}

menu_print_header() {
  echo
  echo "CrashSimulator V2 ${VERSION}"
  echo "Database: ${DB_UNIQUE_NAME:-not discovered}  Role: ${DB_ROLE:-unknown}  Open: ${DB_OPEN_MODE:-unknown}  CDB: ${DB_CDB:-unknown}"
  echo "Instance: ${INSTANCE_NAME:-unknown}  Storage: ${STORAGE_TYPE:-unknown}  Cluster: ${CLUSTER_TYPE:-unknown}"
  echo
  echo "Selected scenario: $(menu_selected_scenario_label)"
  if [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]; then
    echo "Lifecycle: validation=$(scenario_validation_capability) | protection=$(scenario_protection_capability "$SCENARIO_ID") | recovery=$(scenario_recovery_capability "$SCENARIO_ID")"
  fi
  echo "PDB: ${TARGET_PDB:-not set}  Schema: ${TARGET_SCHEMA:-not set}  FILE#: ${TARGET_FILE_NO:-not set}"
  echo "Manifest: ${MANIFEST_FILE:-not set}"
  echo "Log dir: ${LOG_DIR}"
  echo "Report deep validation: ${REPORT_DEEP_VALIDATE}"
  echo "Baseline backup tag prefix: ${BASELINE_TAG_PREFIX}"
  echo "Config file: ${CONFIG_SOURCE:-not loaded}"
  echo "Audit retain: ${AUDIT_RETAIN}  Retention days: ${AUDIT_RETENTION_DAYS}  Audit dir: ${AUDIT_DIR}"
  echo "Scenario 25 guards: local-only=${LOCAL_ONLY}  max-targets=${MAX_TARGETS:-not set}  piece-handle=$([[ -n "$PIECE_HANDLE" ]] && echo set || echo not-set)"
  echo "RMAN catalog: $([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo configured || echo not configured)"
  echo "Password-file recovery: SYS password=$([[ -n "$SYS_PASSWORD" ]] && echo set || echo not-set)  service=${SERVICE_NAME:-not set}"
  echo "Scenario 61/63 knobs: FRA target=${FRA_PRESSURE_TARGET_PCT}%  FRA headroom=${FRA_PRESSURE_HEADROOM_MB}MB  TEMP workload=${TEMP_EXHAUST_MB}MB"
  echo "ADB scenario: ${ADB_SCENARIO_ID:-not set}"
}

menu_select_scenario() {
  local answer

  echo
  list_scenarios
  echo
  echo "Enter scenario id to select, or blank to keep current:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"

  if scenario_exists "$answer"; then
    SCENARIO_ID="$answer"
    MENU_SCHEMA_PROMPTED_SCENARIO=""
    echo "Selected scenario ${SCENARIO_ID}: ${SCENARIO_TITLE[$SCENARIO_ID]}"
    menu_ensure_scenario_context "select" "dry-run" || menu_show_selected_scenario_readiness
    echo "Use menu option 17 to generate the full topology-versus-scenario readiness report."
  else
    warn "Unknown scenario id: $answer"
    return "$FAIL"
  fi
}

menu_require_scenario() {
  if [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]; then
    return "$SUCCESS"
  fi
  menu_select_scenario
  [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]
}

menu_select_pdb() {
  local answer idx row name con_id open_mode

  discover_environment || true
  echo
  if [[ "$DB_CDB" != "YES" ]]; then
    warn "The discovered database is not a CDB. Leave PDB unset for non-CDB scenarios."
  elif [[ "${#PDB_ROWS[@]}" -gt 0 ]]; then
    echo "Available PDBs:"
    idx=1
    for row in "${PDB_ROWS[@]}"; do
      IFS='|' read -r name con_id open_mode <<<"$row"
      printf "  %2d. %-30s CON_ID=%-5s OPEN_MODE=%s\n" "$idx" "$name" "$con_id" "$open_mode"
      idx=$((idx + 1))
    done
  fi

  echo
  echo "Enter PDB name or number, c to clear, or blank to keep [${TARGET_PDB:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      TARGET_PDB=""
      echo "PDB target cleared."
      return "$SUCCESS"
      ;;
  esac

  if [[ "$answer" =~ ^[0-9]+$ && "${#PDB_ROWS[@]}" -gt 0 && "$answer" -ge 1 && "$answer" -le "${#PDB_ROWS[@]}" ]]; then
    IFS='|' read -r TARGET_PDB con_id open_mode <<<"${PDB_ROWS[$((answer - 1))]}"
  else
    TARGET_PDB="$(normalize_name "$answer")"
  fi
  validate_oracle_name "$TARGET_PDB" || {
    warn "Invalid PDB name: $TARGET_PDB"
    TARGET_PDB=""
    return "$FAIL"
  }
  echo "PDB target set to ${TARGET_PDB}."
}

scenario_requires_pdb_context() {
  local id="$1"
  [[ ",${SCENARIO_REQUIRES[$id]:-}," == *,pdb,* ]]
}

scenario_uses_schema_context() {
  local id="$1"
  case "$id" in
    11|36|43|44) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

scenario_schema_prompt_default_yes() {
  local id="$1"
  case "$id" in
    44) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

scenario_file_no_context_useful() {
  local id="$1"
  supports_file_recovery_automation "$id"
}

menu_auto_select_single_pdb() {
  local row con_id open_mode

  discover_environment || true
  [[ "$DB_CDB" == "YES" && -z "$TARGET_PDB" && "${#PDB_ROWS[@]}" -eq 1 ]] || return "$FAIL"
  IFS='|' read -r TARGET_PDB con_id open_mode <<<"${PDB_ROWS[0]}"
  echo "Using only available PDB: ${TARGET_PDB} (OPEN_MODE=${open_mode})"
}

menu_select_schema() {
  local answer idx row owner table_count index_count candidate_filter confirm_token schema_safe
  local target_file="$WORK_DIR/menu_schema_candidates.lst"

  echo
  echo "Schema selection"
  candidate_filter=""
  case "${SCENARIO_ID:-}" in
    11|36)
      candidate_filter="and exists (select 1 from dba_indexes i where i.owner = u.username and i.uniqueness = 'NONUNIQUE')"
      ;;
    43)
      candidate_filter="and exists (select 1 from dba_tables t where t.owner = u.username and t.nested = 'NO' and t.temporary = 'N' and t.secondary = 'N')"
      ;;
  esac
  # A configured CRASHSIM_PDB from another environment (e.g. the conf example's
  # CRASHPDB on a database whose PDB is named differently) used to flow straight
  # into 'alter session set container' here and die with a raw ORA-65011.
  # Validate it against the discovered PDB list first and fall back sensibly.
  if [[ -n "$TARGET_PDB" && "$DB_CDB" == "YES" ]] && ! pdb_exists "$TARGET_PDB"; then
    warn "Configured PDB ${TARGET_PDB} does not exist on this database (available: $(pdb_list_for_message))."
    warn "Check CRASHSIM_PDB in crashsimulator.conf (or the --pdb value)."
    if [[ "${#PDB_ROWS[@]}" -eq 1 ]]; then
      IFS='|' read -r TARGET_PDB _ _ <<<"${PDB_ROWS[0]}"
      echo "Falling back to the only available PDB: ${TARGET_PDB}"
    else
      TARGET_PDB=""
      return "$FAIL"
    fi
  fi
  if [[ -n "$TARGET_PDB" ]]; then
    sql_query "$target_file" "
alter session set container = ${TARGET_PDB};
select username || '|' ||
       (select count(*) from dba_tables t where t.owner = u.username and t.nested = 'NO' and t.temporary = 'N') || '|' ||
       (select count(*) from dba_indexes i where i.owner = u.username and i.uniqueness = 'NONUNIQUE')
from dba_users u
where u.oracle_maintained = 'N'
  and u.username not in ('SYS','SYSTEM')
  and u.username like 'CRASHSIM%'
  ${candidate_filter}
order by case when u.username like 'CRASHSIM%' then 0 else 1 end, u.username;
alter session set container = CDB\$ROOT;
"
  else
    sql_query "$target_file" "
select username || '|' ||
       (select count(*) from dba_tables t where t.owner = u.username and t.nested = 'NO' and t.temporary = 'N') || '|' ||
       (select count(*) from dba_indexes i where i.owner = u.username and i.uniqueness = 'NONUNIQUE')
from dba_users u
where u.oracle_maintained = 'N'
  and u.username not in ('SYS','SYSTEM')
  and (u.username like 'CRASHSIM%' or u.username like 'C##CRASHSIM%')
  ${candidate_filter}
order by case when u.username like 'CRASHSIM%' then 0 else 1 end, u.username;
"
  fi
  load_rows "$target_file" || true

  if [[ "${#TARGET_ROWS[@]}" -gt 0 ]]; then
    echo "Available disposable CrashSimulator lab schemas:"
    idx=1
    for row in "${TARGET_ROWS[@]}"; do
      IFS='|' read -r owner table_count index_count <<<"$row"
      printf "  %2d. %-30s tables=%-6s nonunique_indexes=%s\n" "$idx" "$owner" "${table_count:-0}" "${index_count:-0}"
      idx=$((idx + 1))
      [[ "$idx" -le 30 ]] || break
    done
  else
    echo "No disposable CrashSimulator lab schemas were discovered in the current container context."
    echo "Re-run seed_crashsim_lab.sql in the relevant container or type a known disposable schema name manually."
  fi

  echo
  echo "Enter schema name or number, c to clear, or blank to keep/skip [${TARGET_SCHEMA:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      TARGET_SCHEMA=""
      echo "Schema target cleared."
      return "$SUCCESS"
      ;;
  esac

  if [[ "$answer" =~ ^[0-9]+$ && "${#TARGET_ROWS[@]}" -gt 0 && "$answer" -ge 1 && "$answer" -le "${#TARGET_ROWS[@]}" ]]; then
    IFS='|' read -r TARGET_SCHEMA table_count index_count <<<"${TARGET_ROWS[$((answer - 1))]}"
  else
    TARGET_SCHEMA="$(normalize_name "$answer")"
  fi
  validate_oracle_name "$TARGET_SCHEMA" || {
    warn "Invalid schema name: $TARGET_SCHEMA"
    TARGET_SCHEMA=""
    return "$FAIL"
  }
  schema_safe=0
  if [[ -n "$TARGET_PDB" ]]; then
    [[ "$TARGET_SCHEMA" == CRASHSIM* ]] && schema_safe=1
  else
    [[ "$TARGET_SCHEMA" == CRASHSIM* || "$TARGET_SCHEMA" == C##CRASHSIM* ]] && schema_safe=1
  fi
  if scenario_uses_schema_context "${SCENARIO_ID:-}" && [[ "$schema_safe" -ne 1 ]]; then
    echo
    warn "Schema ${TARGET_SCHEMA} does not look like a CrashSimulator lab schema."
    echo "Only use disposable lab schemas for destructive logical drills."
    confirm_token="USE-SCHEMA-${TARGET_SCHEMA}"
    echo "Type ${confirm_token} to accept this schema, or anything else to cancel:"
    read -r answer || return "$FAIL"
    if [[ "$answer" != "$confirm_token" ]]; then
      TARGET_SCHEMA=""
      warn "Schema selection cancelled."
      return "$FAIL"
    fi
  fi
  echo "Schema target set to ${TARGET_SCHEMA}."
}

menu_prompt_schema_if_useful() {
  local answer default_label

  scenario_uses_schema_context "$SCENARIO_ID" || return "$SUCCESS"
  [[ -z "$TARGET_SCHEMA" ]] || return "$SUCCESS"
  [[ "$MENU_SCHEMA_PROMPTED_SCENARIO" != "$SCENARIO_ID" ]] || return "$SUCCESS"
  MENU_SCHEMA_PROMPTED_SCENARIO="$SCENARIO_ID"

  echo
  echo "Scenario ${SCENARIO_ID} can use an optional schema filter."
  echo "Leaving schema unset lets CrashSimulator choose a disposable candidate during dry-run/execution."
  if scenario_schema_prompt_default_yes "$SCENARIO_ID"; then
    default_label="Y/n"
    echo "Select a schema now? [${default_label}]"
  else
    default_label="y/N"
    echo "Select a schema now? [${default_label}]"
  fi
  read -r answer || return "$FAIL"
  if scenario_schema_prompt_default_yes "$SCENARIO_ID"; then
    case "$answer" in
      n|N|no|NO) return "$SUCCESS" ;;
      *)
        menu_select_schema || {
          MENU_SCHEMA_PROMPTED_SCENARIO=""
          return "$FAIL"
        }
        ;;
    esac
  else
    case "$answer" in
      y|Y|yes|YES)
        menu_select_schema || {
          MENU_SCHEMA_PROMPTED_SCENARIO=""
          return "$FAIL"
        }
        ;;
      *) return "$SUCCESS" ;;
    esac
  fi
}

menu_apply_manifest_context_if_available() {
  local value

  [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]] || return "$SUCCESS"

  if [[ -z "$TARGET_PDB" ]]; then
    value="$(manifest_first_value "target_pdb" "target_1_pdb_name" "action_1_pdb_name" "apex_runtime_target_container" || true)"
    if [[ -n "$value" ]]; then
      value="$(normalize_name "$value")"
      if validate_oracle_name "$value"; then
        TARGET_PDB="$value"
        echo "PDB target loaded from manifest: ${TARGET_PDB}"
      fi
    fi
  fi

  if [[ -z "$TARGET_SCHEMA" ]]; then
    value="$(manifest_first_value "target_schema" "action_1_owner" || true)"
    if [[ -n "$value" ]]; then
      value="$(normalize_name "$value")"
      if validate_oracle_name "$value"; then
        TARGET_SCHEMA="$value"
        echo "Schema target loaded from manifest: ${TARGET_SCHEMA}"
      fi
    fi
  fi

  if [[ -z "$TARGET_FILE_NO" ]]; then
    value="$(manifest_first_value "recover_file_no" "target_1_file_no" "action_1_file_no" || true)"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      TARGET_FILE_NO="$value"
      echo "FILE# loaded from manifest: ${TARGET_FILE_NO}"
    fi
  fi
}

menu_prompt_oracle_name() {
  local label="$1"
  local var_name="$2"
  local current="$3"
  local answer normalized

  echo "Enter ${label}, c to clear, or blank to keep [${current:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      printf -v "$var_name" ""
      echo "${label} cleared."
      return "$SUCCESS"
      ;;
  esac
  normalized="$(normalize_name "$answer")"
  validate_oracle_name "$normalized" || {
    warn "Invalid ${label}: $normalized"
    return "$FAIL"
  }
  printf -v "$var_name" "%s" "$normalized"
  echo "${label} set to ${normalized}."
}

menu_prompt_path() {
  local label="$1"
  local var_name="$2"
  local current="$3"
  local answer

  echo "Enter ${label}, c to clear, or blank to keep [${current:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      printf -v "$var_name" ""
      echo "${label} cleared."
      return "$SUCCESS"
      ;;
  esac
  printf -v "$var_name" "%s" "$answer"
  echo "${label} set to ${answer}."
}

menu_prompt_audit_retain() {
  local answer

  echo "Retain per-run audit logs? [y/N, blank keeps current ${AUDIT_RETAIN}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    y|Y|yes|YES|1|true|TRUE|on|ON)
      AUDIT_RETAIN=1
      ;;
    n|N|no|NO|0|false|FALSE|off|OFF)
      AUDIT_RETAIN=0
      ;;
    *)
      warn "Invalid audit retain value: $answer"
      return "$FAIL"
      ;;
  esac
  echo "Audit retain set to ${AUDIT_RETAIN}."
}

menu_prompt_audit_retention_days() {
  local answer

  echo "Enter audit retention days, or blank to keep [${AUDIT_RETENTION_DAYS}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  [[ "$answer" =~ ^[0-9]+$ ]] || {
    warn "Invalid retention days: $answer"
    return "$FAIL"
  }
  AUDIT_RETENTION_DAYS="$answer"
  echo "Audit retention days set to ${AUDIT_RETENTION_DAYS}."
}

menu_prompt_integer_range() {
  local label="$1"
  local var_name="$2"
  local current="$3"
  local min_value="$4"
  local max_value="${5:-}"
  local answer

  echo "Enter ${label}, or blank to keep [${current}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  [[ "$answer" =~ ^[0-9]+$ ]] || {
    warn "Invalid ${label}: $answer"
    return "$FAIL"
  }
  if [[ -n "$min_value" && "$answer" -lt "$min_value" ]]; then
    warn "${label} must be >= ${min_value}."
    return "$FAIL"
  fi
  if [[ -n "$max_value" && "$answer" -gt "$max_value" ]]; then
    warn "${label} must be <= ${max_value}."
    return "$FAIL"
  fi
  printf -v "$var_name" "%s" "$answer"
  echo "${label} set to ${answer}."
}

menu_prompt_rman_catalog() {
  local answer

  echo "Enter RMAN recovery catalog connect string, c to clear, or blank to keep [$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo configured || echo not-set)]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      RMAN_CATALOG_CONNECT=""
      echo "RMAN recovery catalog connect string cleared."
      return "$SUCCESS"
      ;;
  esac

  RMAN_CATALOG_CONNECT="$answer"
  echo "RMAN recovery catalog connect string configured: $(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"
}

menu_prompt_file_no() {
  local answer target_file idx row file_no pdb_name tablespace size_mb file_name where_clause

  discover_environment || true
  target_file="$WORK_DIR/menu_datafiles.lst"
  if [[ "$DB_CDB" == "YES" ]]; then
    where_clause="where c.name <> 'PDB\$SEED'"
    if [[ -n "$TARGET_PDB" ]]; then
      where_clause="${where_clause} and c.name = $(sql_quote "$TARGET_PDB")"
    fi
    sql_query "$target_file" "
select vf.file# || '|' ||
       c.name || '|' ||
       nvl(ts.name, 'UNKNOWN') || '|' ||
       round(vf.bytes/1024/1024) || '|' ||
       vf.name
from v\$datafile vf
join v\$containers c
  on c.con_id = vf.con_id
left join v\$tablespace ts
  on ts.con_id = vf.con_id
 and ts.ts# = vf.ts#
${where_clause}
order by vf.con_id, vf.file#;
"
  else
    sql_query "$target_file" "
select vf.file# || '|NONCDB|' ||
       nvl(ts.name, 'UNKNOWN') || '|' ||
       round(vf.bytes/1024/1024) || '|' ||
       vf.name
from v\$datafile vf
left join v\$tablespace ts
  on ts.ts# = vf.ts#
order by vf.file#;
"
  fi
  load_rows "$target_file" || true

  echo
  echo "Datafile FILE# selection"
  if [[ "${#TARGET_ROWS[@]}" -gt 0 ]]; then
    echo "Available datafiles$([[ -n "$TARGET_PDB" ]] && printf " for PDB %s" "$TARGET_PDB"):"
    idx=1
    for row in "${TARGET_ROWS[@]}"; do
      IFS='|' read -r file_no pdb_name tablespace size_mb file_name <<<"$row"
      printf "  %2d. FILE#=%-5s PDB=%-20s TBS=%-24s SIZE_MB=%-8s %s\n" \
        "$idx" "$file_no" "$pdb_name" "$tablespace" "${size_mb:-unknown}" "$file_name"
      idx=$((idx + 1))
      [[ "$idx" -le 40 ]] || break
    done
  else
    echo "No datafiles were discovered for the current target context."
  fi

  echo
  echo "Enter list number or FILE#, c to clear, or blank to keep [${TARGET_FILE_NO:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      TARGET_FILE_NO=""
      echo "FILE# cleared."
      return "$SUCCESS"
      ;;
  esac
  [[ "$answer" =~ ^[0-9]+$ ]] || {
    warn "Invalid FILE#: $answer"
    return "$FAIL"
  }
  if [[ "${#TARGET_ROWS[@]}" -gt 0 && "$answer" -ge 1 && "$answer" -le "${#TARGET_ROWS[@]}" ]]; then
    IFS='|' read -r TARGET_FILE_NO pdb_name tablespace size_mb file_name <<<"${TARGET_ROWS[$((answer - 1))]}"
  else
    TARGET_FILE_NO="$answer"
  fi
  echo "FILE# set to ${TARGET_FILE_NO}."
}

menu_show_selected_scenario_readiness() {
  [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]] || return "$SUCCESS"

  if validate_scenario_can_run "$SCENARIO_ID"; then
    echo "Readiness: RUNNABLE - ${SCENARIO_VALIDATION_REASON}"
  elif [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
    echo "Readiness: PLAN-ONLY - ${SCENARIO_VALIDATION_REASON}"
    echo "Execution remains blocked until the guardrail is resolved."
  else
    echo "Readiness: NOT RUNNABLE - ${SCENARIO_VALIDATION_REASON}"
    echo "This scenario cannot be executed in the current topology or target context."
  fi
}

menu_prompt_file_no_for_recovery_if_useful() {
  local answer

  scenario_file_no_context_useful "$SCENARIO_ID" || return "$SUCCESS"
  [[ -z "$TARGET_FILE_NO" ]] || return "$SUCCESS"
  [[ -z "$MANIFEST_FILE" ]] || return "$SUCCESS"

  echo
  echo "Recovery helper note"
  echo "No recovery manifest is selected. A manifest is preferred because it carries the exact target metadata."
  echo "You can optionally select a FILE# now for recovery override/live discovery fallback."
  echo "Select FILE# now? [y/N]"
  read -r answer || return "$FAIL"
  case "$answer" in
    y|Y|yes|YES) menu_prompt_file_no ;;
    *) return "$SUCCESS" ;;
  esac
}

menu_ensure_scenario_context() {
  local action="${1:-scenario}"
  local run_mode="${2:-dry-run}"

  [[ -n "$run_mode" ]] || run_mode="dry-run"
  menu_require_scenario || return "$FAIL"
  discover_environment || true

  if scenario_requires_pdb_context "$SCENARIO_ID" && [[ -z "$TARGET_PDB" ]]; then
    echo
    echo "Scenario ${SCENARIO_ID} requires a PDB target."
    if ! menu_auto_select_single_pdb; then
      menu_select_pdb || return "$FAIL"
    fi
    if [[ -z "$TARGET_PDB" ]]; then
      warn "PDB target is still not set. Select a PDB before continuing with scenario ${SCENARIO_ID}."
      return "$FAIL"
    fi
  fi

  menu_prompt_schema_if_useful || return "$FAIL"

  if [[ "$action" == "recover" ]]; then
    menu_apply_manifest_context_if_available
    menu_prompt_file_no_for_recovery_if_useful || return "$FAIL"
  fi

  echo
  menu_show_selected_scenario_readiness
}

menu_configure_scenario25() {
  local answer

  echo
  echo "Scenario 25 backup-piece guardrails"
  echo "Current local-only: ${LOCAL_ONLY}"
  echo "Set local-only? [y/N, blank keeps current]:"
  read -r answer || return "$FAIL"
  case "$answer" in
    y|Y|yes|YES) LOCAL_ONLY=1 ;;
    n|N|no|NO) LOCAL_ONLY=0 ;;
  esac

  echo "Enter max targets, c to clear, or blank to keep [${MAX_TARGETS:-not set}]:"
  read -r answer || return "$FAIL"
  if [[ -n "$answer" ]]; then
    case "$answer" in
      c|C|clear|CLEAR)
        MAX_TARGETS=""
        ;;
      *)
        [[ "$answer" =~ ^[1-9][0-9]*$ ]] || {
          warn "Invalid max targets: $answer"
          return "$FAIL"
        }
        MAX_TARGETS="$answer"
        ;;
    esac
  fi

  menu_prompt_path "backup-piece handle" PIECE_HANDLE "$PIECE_HANDLE"
}

menu_configure_resilience_drills() {
  echo
  echo "FRA / TEMP / RTO-RPO drill options"
  menu_prompt_integer_range "scenario 61 FRA target used percentage" FRA_PRESSURE_TARGET_PCT "$FRA_PRESSURE_TARGET_PCT" 50 100
  menu_prompt_integer_range "scenario 61 FRA free headroom MB" FRA_PRESSURE_HEADROOM_MB "$FRA_PRESSURE_HEADROOM_MB" 1
  menu_prompt_integer_range "scenario 63 TEMP workload MB" TEMP_EXHAUST_MB "$TEMP_EXHAUST_MB" 1
  echo
  echo "Use the MAA/SLA context menu to set RTO/RPO objectives consumed by scenarios 64 and 65."
}

menu_load_config_file() {
  local answer

  echo
  echo "Load CrashSimulator configuration file"
  echo "Enter path, or blank to keep current [${CONFIG_SOURCE:-${CONFIG_FILE:-not set}}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="${CONFIG_SOURCE:-${CONFIG_FILE:-}}"
  [[ -n "$answer" ]] || {
    warn "No configuration file path provided."
    return "$FAIL"
  }

  CONFIG_FILE="$answer"
  CONFIG_EXPLICIT=1
  load_config_file "$CONFIG_FILE"
  normalize_targets
  [[ -n "$LOG_DIR" ]] || LOG_DIR="$(pwd)/crashsimulator_logs"
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  audit_effective_dir
  echo "Configuration loaded: ${CONFIG_SOURCE}"
  echo "Existing shell environment values were preserved."
}

menu_write_config_template() {
  local answer old_yes

  echo
  echo "Write configuration template"
  echo "Enter output path [./crashsimulator.conf]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="./crashsimulator.conf"
  if [[ -e "$answer" ]]; then
    echo "File exists. Type OVERWRITE-CONFIG to replace it:"
    read -r old_yes || return "$FAIL"
    [[ "$old_yes" == "OVERWRITE-CONFIG" ]] || {
      warn "Configuration template write cancelled."
      return "$FAIL"
    }
    old_yes="$ASSUME_YES"
    ASSUME_YES=1
    write_config_template "$answer"
    ASSUME_YES="$old_yes"
  else
    write_config_template "$answer"
  fi
}

menu_config_file_options() {
  local answer

  while true; do
    echo
    echo "Configuration File Options"
    echo "  1. Load configuration file"
    echo "  2. Show active configuration"
    echo "  3. Validate active configuration"
    echo "  4. Write configuration template"
    echo "  5. Show lookup order and precedence"
    echo "  b. Back"
    echo
    echo "Loaded config: ${CONFIG_SOURCE:-not loaded}"
    echo "Precedence: CLI arguments > existing environment > config file > built-in defaults"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        menu_load_config_file
        menu_pause
        ;;
      2)
        show_active_config
        menu_pause
        ;;
      3)
        validate_config_runtime || true
        menu_pause
        ;;
      4)
        menu_write_config_template
        menu_pause
        ;;
      5)
        echo
        echo "Lookup order:"
        echo "  1. --config <file>"
        echo "  2. CRASHSIM_CONFIG"
        echo "  3. ./crashsimulator.conf"
        echo "  4. \$HOME/.crashsimulator/crashsimulator.conf"
        echo "  5. /etc/crashsimulator/crashsimulator.conf"
        echo
        echo "The file is parsed as allowlisted KEY=value entries, not sourced as shell code."
        echo "Do not store passwords or wallet secrets in the configuration file."
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown configuration-file menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_set_password_file_options() {
  local answer

  echo
  echo "Password-file recovery options"
  echo "Enter SYS password for this menu session, c to clear, or blank to keep current:"
  read -rs answer || return "$FAIL"
  echo
  if [[ -n "$answer" ]]; then
    case "$answer" in
      c|C|clear|CLEAR)
        SYS_PASSWORD=""
        echo "SYS password cleared from this process."
        ;;
      *)
        SYS_PASSWORD="$answer"
        echo "SYS password stored only in this running process."
        ;;
    esac
  fi

  menu_prompt_path "listener service name" SERVICE_NAME "$SERVICE_NAME"
  menu_prompt_oracle_name "SYSBACKUP user" SYSBACKUP_USER "$SYSBACKUP_USER"
}

menu_configure_options() {
  local answer

  while true; do
    echo
    echo "Configure Menu Context"
    echo "  1. Select PDB"
    echo "  2. Set schema"
    echo "  3. Set FILE#"
    echo "  4. Set recovery manifest"
    echo "  5. Set PFILE path"
    echo "  6. Scenario 25 backup-piece guardrails"
    echo "  7. Password-file recovery options"
    echo "  8. Set log directory"
    echo "  9. Set RMAN recovery catalog"
    echo " 10. Set baseline backup tag prefix"
    echo " 11. FRA/TEMP/RTO-RPO drill options"
    echo " 12. Configuration file options"
    echo " 13. Clear selected scenario and targets"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1) menu_select_pdb; menu_pause ;;
      2) menu_select_schema; menu_pause ;;
      3) menu_prompt_file_no; menu_pause ;;
      4)
        menu_prompt_path "manifest path" MANIFEST_FILE "$MANIFEST_FILE"
        [[ -n "$MANIFEST_FILE" ]] && MANIFEST_FROM_ARG=1
        menu_pause
        ;;
      5) menu_prompt_path "PFILE path" PFILE_PATH "$PFILE_PATH"; menu_pause ;;
      6) menu_configure_scenario25; menu_pause ;;
      7) menu_set_password_file_options; menu_pause ;;
      8)
        menu_prompt_path "log directory" LOG_DIR "$LOG_DIR"
        [[ -n "$LOG_DIR" ]] || LOG_DIR="$(pwd)/crashsimulator_logs"
        mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
        menu_pause
        ;;
      9)
        menu_prompt_rman_catalog
        menu_pause
        ;;
      10)
        menu_prompt_path "baseline backup tag prefix" BASELINE_TAG_PREFIX "$BASELINE_TAG_PREFIX"
        menu_pause
        ;;
      11)
        menu_configure_resilience_drills
        menu_pause
        ;;
      12)
        menu_config_file_options
        ;;
      13)
        SCENARIO_ID=""
        MENU_SCHEMA_PROMPTED_SCENARIO=""
        TARGET_PDB=""
        TARGET_SCHEMA=""
        TARGET_FILE_NO=""
        MANIFEST_FILE=""
        MANIFEST_FROM_ARG=0
        PFILE_PATH=""
        LOCAL_ONLY=0
        MAX_TARGETS=""
        PIECE_HANDLE=""
        RMAN_CATALOG_CONNECT=""
        BASELINE_TAG_PREFIX="${CRASHSIM_BASELINE_TAG_PREFIX:-CSIM_BASE}"
        FRA_PRESSURE_TARGET_PCT="${CRASHSIM_FRA_PRESSURE_TARGET_PCT:-98}"
        FRA_PRESSURE_HEADROOM_MB="${CRASHSIM_FRA_PRESSURE_HEADROOM_MB:-64}"
        TEMP_EXHAUST_MB="${CRASHSIM_TEMP_EXHAUST_MB:-512}"
        echo "Scenario and target context cleared."
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_latest_manifest() {
  find "$LOG_DIR" -maxdepth 1 -type f -name '*.manifest' 2>/dev/null | sort | tail -n 1
}

menu_latest_manifest_for_mode() {
  local mode_name="$1"
  local id="$2"
  find "$LOG_DIR" -maxdepth 1 -type f -name "crashsim_${mode_name}_s${id}_*.manifest" 2>/dev/null | sort | tail -n 1
}

menu_choose_recovery_manifest() {
  local latest answer

  if [[ -n "$MANIFEST_FILE" ]]; then
    return "$SUCCESS"
  fi

  if [[ -n "$SCENARIO_ID" ]]; then
    latest="$(menu_latest_manifest_for_mode "scenario" "$SCENARIO_ID")"
  else
    latest=""
  fi
  [[ -n "$latest" ]] || latest="$(menu_latest_manifest)"

  if [[ -n "$latest" ]]; then
    echo "Latest manifest: ${latest}"
    echo "Use this manifest for recovery? [Y/n]"
    read -r answer || return "$FAIL"
    case "$answer" in
      n|N|no|NO)
        ;;
      *)
        MANIFEST_FILE="$latest"
        MANIFEST_FROM_ARG=1
        return "$SUCCESS"
        ;;
    esac
  fi

  echo "Enter recovery manifest path, or blank to let the recovery helper decide when supported:"
  read -r answer || return "$FAIL"
  if [[ -n "$answer" ]]; then
    MANIFEST_FILE="$answer"
    MANIFEST_FROM_ARG=1
  fi
}

# A scenario manifest records restore points (rename_N_original/rename_N_backup)
# only when the scenario actually ran: a dry-run scenario (option 5) prints the
# plan and renames/backs up nothing. Recovery replays those restore points, so a
# dry-run scenario manifest can never recover - load_manifest_restore_pairs finds
# no pair and the helper stops with "Manifest is missing ... restore paths", which
# the guided menu surfaced only as a bare "Command exited with status 1". Detect
# it up front and say what to do instead. Scoped to fs_rename plans (the mechanism
# recovery replays) so scenarios that recover by other means are never blocked.
menu_recovery_manifest_is_recoverable() {
  local idx kind planned_rename run_id title

  [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]] || return "$SUCCESS"
  [[ "$(manifest_get "mode" || true)" == "scenario" ]] || return "$SUCCESS"

  planned_rename=0
  idx=1
  while :; do
    kind="$(manifest_get "action_${idx}_kind" || true)"
    [[ -n "$kind" ]] || break
    if [[ "$kind" == "fs_rename" ]]; then
      planned_rename=1
      break
    fi
    idx=$((idx + 1))
  done
  [[ "$planned_rename" -eq 1 ]] || return "$SUCCESS"

  # Mirror load_manifest_restore_pairs: it starts at rename_1 and reports no
  # pairs only when both sides are empty.
  [[ -z "$(manifest_get "rename_1_original" || true)" ]] || return "$SUCCESS"
  [[ -z "$(manifest_get "rename_1_backup" || true)" ]] || return "$SUCCESS"

  run_id="$(manifest_get "run_id" || true)"
  title="$(manifest_get "scenario_title" || true)"
  warn "This manifest is from a dry-run scenario preview - there is nothing to recover."
  echo "  Manifest: ${MANIFEST_FILE}"
  echo "  Scenario: ${SCENARIO_ID}${title:+ - ${title}}${run_id:+ (run ${run_id})}"
  echo
  echo "  A dry-run scenario prints the plan but renames and backs up no file, so this"
  echo "  manifest holds no restore point. Recovery replays those restore points, so it"
  echo "  would stop with \"Manifest is missing ... restore paths\"."
  echo
  echo "  Run menu option 8 (Execute selected scenario) first, then retry recovery:"
  echo "  the executed run writes its own manifest and the menu will offer that one."
  return "$FAIL"
}

# Scenario 16 (Loss of password file) recovers by RECREATING the file with
# orapwd, which embeds the SYS password - so execute-mode recovery cannot run
# without it. Mirrors the id -> recover_password_file_scenario mapping in the
# recovery dispatch.
menu_scenario_recovery_needs_sys_password() {
  case "${1:-}" in
    16) return "$SUCCESS" ;;
  esac
  return "$FAIL"
}

# Surface the SYS-password prerequisite at the right moments (field-tested
# 2026-07-18: the operator learned about it only AFTER typing RECOVER-16 and
# LAB-APPROVED):
#   - action=scenario (menu options 5 and 8): non-blocking heads-up BEFORE
#     breaking a password file the operator cannot yet recover; the scenario
#     itself runs fine without the password.
#   - action=recover in execute mode (menu option 10): fail early with the
#     fix, instead of letting the child die after the confirmation gates.
menu_warn_sys_password_for_scenario() {
  local action="$1" run_mode="$2"
  [[ -n "$SCENARIO_ID" ]] || return "$SUCCESS"
  menu_scenario_recovery_needs_sys_password "$SCENARIO_ID" || return "$SUCCESS"
  [[ -z "$SYS_PASSWORD" ]] || return "$SUCCESS"

  case "$action" in
    scenario)
      warn "Recovering scenario ${SCENARIO_ID} later will need the SYS password, which is not set."
      echo "  Recovery recreates the password file with orapwd, and execute-mode recovery"
      echo "  (option 10) refuses to run without the SYS password. Set it via option 12"
      echo "  (Configure targets and options -> Password-file recovery options) now or"
      echo "  before you recover. Continuing with the scenario itself is safe."
      echo
      ;;
    recover)
      if [[ "$run_mode" == "execute" ]]; then
        warn "Execute-mode recovery for scenario ${SCENARIO_ID} requires the SYS password, which is not set."
        echo "  Recovery recreates the password file with orapwd file=... password=<SYS>, so"
        echo "  the run would stop with \"Password-file recovery execution requires"
        echo "  --sys-password or CRASHSIM_SYS_PASSWORD\". Set the SYS password via option 12"
        echo "  (Configure targets and options -> Password-file recovery options), then retry."
        return "$FAIL"
      fi
      ;;
  esac
  return "$SUCCESS"
}

menu_append_common_child_args() {
  [[ -n "$CONFIG_SOURCE" ]] && MENU_CMD+=("--config" "$CONFIG_SOURCE")
  [[ -n "$TARGET_PDB" ]] && MENU_CMD+=("--pdb" "$TARGET_PDB")
  [[ -n "$TARGET_SCHEMA" ]] && MENU_CMD+=("--schema" "$TARGET_SCHEMA")
  [[ -n "$TARGET_FILE_NO" ]] && MENU_CMD+=("--file-no" "$TARGET_FILE_NO")
  [[ -n "$PFILE_PATH" ]] && MENU_CMD+=("--pfile" "$PFILE_PATH")
  [[ -n "$SERVICE_NAME" ]] && MENU_CMD+=("--service-name" "$SERVICE_NAME")
  [[ -n "$ORDS_SERVICE_NAME" ]] && MENU_CMD+=("--ords-service" "$ORDS_SERVICE_NAME")
  [[ -n "$ORDS_CONFIG_DIR" ]] && MENU_CMD+=("--ords-config-dir" "$ORDS_CONFIG_DIR")
  [[ -n "$ORDS_URL" ]] && MENU_CMD+=("--ords-url" "$ORDS_URL")
  [[ -n "$ORDS_LB_URL" ]] && MENU_CMD+=("--ords-lb-url" "$ORDS_LB_URL")
  [[ -n "$ORDS_PRIV_HELPER" ]] && MENU_CMD+=("--ords-priv-helper" "$ORDS_PRIV_HELPER")
  [[ -n "$APEX_IMAGES_DIR" ]] && MENU_CMD+=("--apex-images-dir" "$APEX_IMAGES_DIR")
  [[ -n "$APEX_SESSION_DRIVER" ]] && MENU_CMD+=("--apex-session-driver" "$APEX_SESSION_DRIVER")
  [[ -n "$APEX_SESSION_URL" ]] && MENU_CMD+=("--apex-session-url" "$APEX_SESSION_URL")
  [[ -n "$APEX_SESSION_USERNAME" ]] && MENU_CMD+=("--apex-session-username" "$APEX_SESSION_USERNAME")
  [[ -n "$APEX_SESSION_SUCCESS_SELECTOR" ]] && MENU_CMD+=("--apex-session-success-selector" "$APEX_SESSION_SUCCESS_SELECTOR")
  [[ -n "$APEX_SESSION_USERNAME_SELECTOR" ]] && MENU_CMD+=("--apex-session-username-selector" "$APEX_SESSION_USERNAME_SELECTOR")
  [[ -n "$APEX_SESSION_PASSWORD_SELECTOR" ]] && MENU_CMD+=("--apex-session-password-selector" "$APEX_SESSION_PASSWORD_SELECTOR")
  [[ -n "$APEX_SESSION_SUBMIT_SELECTOR" ]] && MENU_CMD+=("--apex-session-submit-selector" "$APEX_SESSION_SUBMIT_SELECTOR")
  MENU_CMD+=("--apex-session-duration" "$APEX_SESSION_DURATION")
  MENU_CMD+=("--apex-session-interval" "$APEX_SESSION_INTERVAL")
  MENU_CMD+=("--apex-session-headless" "$APEX_SESSION_HEADLESS")
  [[ -n "$ADB_WALLET_DIR" ]] && MENU_CMD+=("--adb-wallet-dir" "$ADB_WALLET_DIR")
  [[ -n "$ADB_CONNECT_ALIAS" ]] && MENU_CMD+=("--adb-connect-alias" "$ADB_CONNECT_ALIAS")
  [[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && MENU_CMD+=("--adb-connect-descriptor" "$ADB_CONNECT_DESCRIPTOR")
  [[ -n "$ADB_SERVICE_LEVEL" ]] && MENU_CMD+=("--adb-service-level" "$ADB_SERVICE_LEVEL")
  [[ -n "$ADB_USER" ]] && MENU_CMD+=("--adb-user" "$ADB_USER")
  [[ -n "$ADB_PASSWORD_ENV" ]] && MENU_CMD+=("--adb-password-env" "$ADB_PASSWORD_ENV")
  [[ -n "$ADB_WALLET_PASSWORD_ENV" ]] && MENU_CMD+=("--adb-wallet-password-env" "$ADB_WALLET_PASSWORD_ENV")
  [[ -n "$ADB_PYTHON" ]] && MENU_CMD+=("--adb-python" "$ADB_PYTHON")
  [[ -n "$ADB_TLS_MODE" ]] && MENU_CMD+=("--adb-tls-mode" "$ADB_TLS_MODE")
  [[ -n "$ADB_OCID" ]] && MENU_CMD+=("--adb-ocid" "$ADB_OCID")
  [[ -n "$ADB_COMPARTMENT_OCID" ]] && MENU_CMD+=("--adb-compartment-ocid" "$ADB_COMPARTMENT_OCID")
  [[ -n "$ADB_REGION" ]] && MENU_CMD+=("--adb-region" "$ADB_REGION")
  [[ -n "$ADB_OCI_PROFILE" ]] && MENU_CMD+=("--adb-oci-profile" "$ADB_OCI_PROFILE")
  [[ -n "$ADB_OCI_CONFIG_FILE" ]] && MENU_CMD+=("--adb-oci-config-file" "$ADB_OCI_CONFIG_FILE")
  [[ -n "$ADB_OCI_AUTH" ]] && MENU_CMD+=("--adb-oci-auth" "$ADB_OCI_AUTH")
  [[ -n "$ADB_APEX_URL" ]] && MENU_CMD+=("--adb-apex-url" "$ADB_APEX_URL")
  [[ -n "$ADB_DATABASE_ACTIONS_URL" ]] && MENU_CMD+=("--adb-database-actions-url" "$ADB_DATABASE_ACTIONS_URL")
  [[ -n "$ADB_PRIVATE_ENDPOINT" ]] && MENU_CMD+=("--adb-private-endpoint" "$ADB_PRIVATE_ENDPOINT")
  [[ -n "$SYSBACKUP_USER" ]] && MENU_CMD+=("--sysbackup-user" "$SYSBACKUP_USER")
  [[ "$LOCAL_ONLY" == "1" ]] && MENU_CMD+=("--local-only")
  [[ -n "$MAX_TARGETS" ]] && MENU_CMD+=("--max-targets" "$MAX_TARGETS")
  [[ -n "$PIECE_HANDLE" ]] && MENU_CMD+=("--piece-handle" "$PIECE_HANDLE")
  MENU_CMD+=("--fra-pressure-target-pct" "$FRA_PRESSURE_TARGET_PCT")
  MENU_CMD+=("--fra-pressure-headroom-mb" "$FRA_PRESSURE_HEADROOM_MB")
  MENU_CMD+=("--temp-exhaust-mb" "$TEMP_EXHAUST_MB")
  [[ -n "$MAA_APP_NAME" ]] && MENU_CMD+=("--maa-app-name" "$MAA_APP_NAME")
  [[ -n "$MAA_LOCAL_RTO" ]] && MENU_CMD+=("--maa-local-rto" "$MAA_LOCAL_RTO")
  [[ -n "$MAA_LOCAL_RPO" ]] && MENU_CMD+=("--maa-local-rpo" "$MAA_LOCAL_RPO")
  [[ -n "$MAA_DR_RTO" ]] && MENU_CMD+=("--maa-dr-rto" "$MAA_DR_RTO")
  [[ -n "$MAA_DR_RPO" ]] && MENU_CMD+=("--maa-dr-rpo" "$MAA_DR_RPO")
  [[ -n "$MAA_PLANNED_RTO" ]] && MENU_CMD+=("--maa-planned-rto" "$MAA_PLANNED_RTO")
  [[ -n "$MAA_PLANNED_RPO" ]] && MENU_CMD+=("--maa-planned-rpo" "$MAA_PLANNED_RPO")
  [[ -n "$MAA_CRITICALITY" ]] && MENU_CMD+=("--maa-criticality" "$MAA_CRITICALITY")
  [[ -n "$MAA_LOCAL_HA_TARGET" ]] && MENU_CMD+=("--maa-local-ha-target" "$MAA_LOCAL_HA_TARGET")
  [[ -n "$MAA_DR_REQUIRED" ]] && MENU_CMD+=("--maa-dr-required" "$MAA_DR_REQUIRED")
  [[ -n "$MAA_AUTOMATIC_FAILOVER_REQUIRED" ]] && MENU_CMD+=("--maa-automatic-failover-required" "$MAA_AUTOMATIC_FAILOVER_REQUIRED")
  [[ -n "$MAA_ACTIVE_ACTIVE_REQUIRED" ]] && MENU_CMD+=("--maa-active-active-required" "$MAA_ACTIVE_ACTIVE_REQUIRED")
  [[ -n "$MAA_PLATFORM_HINT" ]] && MENU_CMD+=("--maa-platform-hint" "$MAA_PLATFORM_HINT")
  [[ -n "$MAA_STANDBY_SCOPE" ]] && MENU_CMD+=("--maa-standby-scope" "$MAA_STANDBY_SCOPE")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
}

menu_print_child_command() {
  local arg i
  printf "Running:"
  [[ -n "$SYS_PASSWORD" ]] && printf " CRASHSIM_SYS_PASSWORD=%q" "<redacted>"
  [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf " CRASHSIM_RMAN_CATALOG=%q" "$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"
  printf " CRASHSIM_AUDIT_RETAIN=%q" "$AUDIT_RETAIN"
  printf " CRASHSIM_AUDIT_RETENTION_DAYS=%q" "$AUDIT_RETENTION_DAYS"
  printf " CRASHSIM_AUDIT_DIR=%q" "$AUDIT_DIR"
  for ((i = 0; i < ${#MENU_CMD[@]}; i++)); do
    arg="${MENU_CMD[$i]}"
    printf " %q" "$arg"
    case "$arg" in
      --rman-catalog|--sys-password)
        if (( i + 1 < ${#MENU_CMD[@]} )); then
          i=$((i + 1))
          printf " %q" "<redacted>"
        fi
        ;;
    esac
  done
  printf "\n"
}

menu_run_child_command() {
  local status child_stream_capture
  # Guided-menu children have an operator at the terminal: audit stream capture
  # would wrap the child's stdout in the redaction pipe and its interactive
  # confirmation prompts (Type PREPARE-ENVIRONMENT / EXECUTE-<id> / ...) can
  # arrive late while `read` already blocks - the operator answers a safety
  # gate blind. Default capture OFF for children (same policy the audit module
  # applies to the menu itself; generated artifacts are still collected at
  # finalization). An explicit CRASHSIM_AUDIT_STREAM_CAPTURE=0/1 is respected.
  child_stream_capture="${AUDIT_STREAM_CAPTURE:-auto}"
  [[ "$child_stream_capture" == "auto" ]] && child_stream_capture=0
  menu_print_child_command
  echo
  env \
    CRASHSIM_SYS_PASSWORD="$SYS_PASSWORD" \
    CRASHSIM_RMAN_CATALOG="$RMAN_CATALOG_CONNECT" \
    CRASHSIM_AUDIT_RETAIN="$AUDIT_RETAIN" \
    CRASHSIM_AUDIT_RETENTION_DAYS="$AUDIT_RETENTION_DAYS" \
    CRASHSIM_AUDIT_DIR="$AUDIT_DIR" \
    CRASHSIM_AUDIT_STREAM_CAPTURE="$child_stream_capture" \
    "${MENU_CMD[@]}"
  status=$?
  echo
  if [[ "$status" -eq 0 ]]; then
    echo "Command completed successfully."
  else
    warn "Command exited with status ${status}."
  fi
  return "$status"
}

menu_run_child_action() {
  local action="$1"
  local run_mode="$2"
  local latest status capability

  menu_require_scenario || {
    warn "No scenario selected."
    return "$FAIL"
  }

  case "$action" in
    scenario)
      menu_warn_sys_password_for_scenario "scenario" "$run_mode"
      ;;
    protect)
      if ! supports_file_recovery_automation "$SCENARIO_ID"; then
        capability="$(scenario_protection_capability "$SCENARIO_ID")"
        warn "Automated protection is not available for scenario ${SCENARIO_ID}: ${capability}. Use menu option 4 for the runbook and refresh the backup baseline where appropriate."
        return "$FAIL"
      fi
      ;;
    recover)
      if ! supports_recovery_automation "$SCENARIO_ID"; then
        capability="$(scenario_recovery_capability "$SCENARIO_ID")"
        warn "Automated recovery is not available for scenario ${SCENARIO_ID}: ${capability}. Use menu option 4 for the recovery runbook and evidence guidance."
        return "$FAIL"
      fi
      menu_warn_sys_password_for_scenario "recover" "$run_mode" || return "$FAIL"
      menu_choose_recovery_manifest
      menu_apply_manifest_context_if_available
      menu_recovery_manifest_is_recoverable || return "$FAIL"
      ;;
    *)
      warn "Unknown action: $action"
      return "$FAIL"
      ;;
  esac

  menu_ensure_scenario_context "$action" "$run_mode" || return "$FAIL"

  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH")
  case "$action" in
    scenario) MENU_CMD+=("--scenario" "$SCENARIO_ID") ;;
    protect) MENU_CMD+=("--protect" "$SCENARIO_ID") ;;
    recover)
      MENU_CMD+=("--recover" "$SCENARIO_ID")
      [[ -n "$MANIFEST_FILE" ]] && MENU_CMD+=("--manifest" "$MANIFEST_FILE")
      ;;
  esac

  menu_append_common_child_args
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown run mode: $run_mode"; return "$FAIL" ;;
  esac

  menu_run_child_command
  status=$?

  if [[ "$action" == "scenario" && "$status" -eq 0 ]]; then
    latest="$(menu_latest_manifest_for_mode "scenario" "$SCENARIO_ID")"
    if [[ -n "$latest" ]]; then
      MANIFEST_FILE="$latest"
      MANIFEST_FROM_ARG=1
      echo "Current recovery manifest set to: ${MANIFEST_FILE}"
      echo "For destructive recovery, make sure this is the executed scenario manifest, not only a dry-run manifest."
    fi
  fi

  return "$status"
}

menu_run_validate_scenario() {
  menu_require_scenario || {
    warn "No scenario selected."
    return "$FAIL"
  }
  menu_ensure_scenario_context "validate" "dry-run" || return "$FAIL"

  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--validate-scenario" "$SCENARIO_ID")
  menu_append_common_child_args
  menu_run_child_command
}

menu_run_validate_all_scenarios() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--validate-all-scenarios")
  menu_append_common_child_args
  menu_run_child_command
}

menu_run_scenario_readiness_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--scenario-readiness-report")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_scenario_lifecycle_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--scenario-lifecycle-report")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_random_scenario() {
  local run_mode="$1"
  select_random_scenario || return "$FAIL"
  menu_run_child_action "scenario" "$run_mode"
}

menu_run_health_check() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--health-check")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_configuration_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--config-report")
  [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && MENU_CMD+=("--deep-validate")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_backup_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--backup-report")
  [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && MENU_CMD+=("--deep-validate")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_baseline_backup() {
  local run_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--baseline-backup")
  [[ -n "$BASELINE_TAG_PREFIX" ]] && MENU_CMD+=("--tag-prefix" "$BASELINE_TAG_PREFIX")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown baseline backup mode: $run_mode"; return "$FAIL" ;;
  esac
  menu_run_child_command
}

menu_run_maa_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--maa-report")
  [[ -n "$MAA_APP_NAME" ]] && MENU_CMD+=("--maa-app-name" "$MAA_APP_NAME")
  [[ -n "$MAA_LOCAL_RTO" ]] && MENU_CMD+=("--maa-local-rto" "$MAA_LOCAL_RTO")
  [[ -n "$MAA_LOCAL_RPO" ]] && MENU_CMD+=("--maa-local-rpo" "$MAA_LOCAL_RPO")
  [[ -n "$MAA_DR_RTO" ]] && MENU_CMD+=("--maa-dr-rto" "$MAA_DR_RTO")
  [[ -n "$MAA_DR_RPO" ]] && MENU_CMD+=("--maa-dr-rpo" "$MAA_DR_RPO")
  [[ -n "$MAA_PLANNED_RTO" ]] && MENU_CMD+=("--maa-planned-rto" "$MAA_PLANNED_RTO")
  [[ -n "$MAA_PLANNED_RPO" ]] && MENU_CMD+=("--maa-planned-rpo" "$MAA_PLANNED_RPO")
  [[ -n "$MAA_CRITICALITY" ]] && MENU_CMD+=("--maa-criticality" "$MAA_CRITICALITY")
  [[ -n "$MAA_LOCAL_HA_TARGET" ]] && MENU_CMD+=("--maa-local-ha-target" "$MAA_LOCAL_HA_TARGET")
  [[ -n "$MAA_DR_REQUIRED" ]] && MENU_CMD+=("--maa-dr-required" "$MAA_DR_REQUIRED")
  [[ -n "$MAA_AUTOMATIC_FAILOVER_REQUIRED" ]] && MENU_CMD+=("--maa-automatic-failover-required" "$MAA_AUTOMATIC_FAILOVER_REQUIRED")
  [[ -n "$MAA_ACTIVE_ACTIVE_REQUIRED" ]] && MENU_CMD+=("--maa-active-active-required" "$MAA_ACTIVE_ACTIVE_REQUIRED")
  [[ -n "$MAA_PLATFORM_HINT" ]] && MENU_CMD+=("--maa-platform-hint" "$MAA_PLATFORM_HINT")
  [[ -n "$MAA_STANDBY_SCOPE" ]] && MENU_CMD+=("--maa-standby-scope" "$MAA_STANDBY_SCOPE")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_resilience_scorecard() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--resilience-scorecard")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_service_review() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--service-review")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_apex_ords_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--apex-ords-report")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_prepare_environment() {
  local run_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--prepare-environment")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown prepare mode: $run_mode"; return "$FAIL" ;;
  esac
  menu_run_child_command
}

menu_run_show_latest_prepare_report() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--show-artifact" "latest:prepare")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_prepare_environment() {
  local answer

  while true; do
    echo
    echo "Seed / Prepare Scenario Lab"
    echo "  1. Analyze missing preparations for current topology"
    echo "  2. Execute eligible missing preparations"
    echo "  3. Generate scenario readiness report after preparation"
    echo "  4. Show latest preparation report"
    echo "  5. Show latest preparation report and generate HTML"
    echo "  6. Run fresh RMAN baseline backup dry-run"
    echo "  7. Run fresh RMAN baseline backup after preparation"
    echo "  b. Back"
    echo
    echo "The prepare planner is topology-aware. It skips non-applicable seeds and does not auto-enable FSFO, provision disks, or install APEX/ORDS without required credentials/media."
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1|a|A)
        menu_run_prepare_environment "dry-run"
        menu_pause
        ;;
      2|e|E)
        menu_run_prepare_environment "execute"
        menu_pause
        ;;
      3)
        menu_run_scenario_readiness_report
        menu_pause
        ;;
      4)
        menu_run_show_latest_prepare_report "text"
        menu_pause
        ;;
      5)
        menu_run_show_latest_prepare_report "html"
        menu_pause
        ;;
      6)
        menu_run_baseline_backup "dry-run"
        menu_pause
        ;;
      7)
        menu_run_baseline_backup "execute"
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown prepare menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_run_simple_mode() {
  local mode_arg="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "$mode_arg")
  menu_append_common_child_args
  case "$mode_arg" in
    --doctor|--first-run|--public-limitations|--scenario-lifecycle-check) MENU_CMD+=("--html") ;;
  esac
  menu_run_child_command
}

menu_public_readiness() {
  local answer

  while true; do
    echo
    echo "Public Readiness And Safety"
    echo "  1. Run doctor / preflight"
    echo "  2. Generate first-run guide"
    echo "  3. Check scenario lifecycle consistency"
    echo "  4. Scan repository/artifacts for secrets"
    echo "  5. Create sanitized public artifact copies"
    echo "  6. Run multi-node sync check"
    echo "  7. Run full release check"
    echo "  8. Generate public limitations page"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1) menu_run_simple_mode "--doctor"; menu_pause ;;
      2) menu_run_simple_mode "--first-run"; menu_pause ;;
      3) menu_run_simple_mode "--scenario-lifecycle-check"; menu_pause ;;
      4) menu_run_simple_mode "--secret-scan"; menu_pause ;;
      5) menu_run_simple_mode "--sanitize-artifacts"; menu_pause ;;
      6) menu_run_simple_mode "--node-sync-check"; menu_pause ;;
      7) menu_run_simple_mode "--release-check"; menu_pause ;;
      8) menu_run_simple_mode "--public-limitations"; menu_pause ;;
      b|B|q|Q) return "$SUCCESS" ;;
      *) warn "Unknown public readiness choice: $answer"; menu_pause ;;
    esac
  done
}

menu_run_adb_readiness_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--adb-readiness-report")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_show_latest_adb_report() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--show-artifact" "latest:adb")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_configure_maa_context() {
  echo
  echo "MAA / SLA planning context"
  menu_prompt_path "application name" MAA_APP_NAME "$MAA_APP_NAME"
  menu_prompt_path "local unplanned-outage RTO" MAA_LOCAL_RTO "$MAA_LOCAL_RTO"
  menu_prompt_path "local unplanned-outage RPO" MAA_LOCAL_RPO "$MAA_LOCAL_RPO"
  menu_prompt_path "disaster/site-outage RTO" MAA_DR_RTO "$MAA_DR_RTO"
  menu_prompt_path "disaster/site-outage RPO" MAA_DR_RPO "$MAA_DR_RPO"
  menu_prompt_path "planned-maintenance RTO" MAA_PLANNED_RTO "$MAA_PLANNED_RTO"
  menu_prompt_path "planned-maintenance RPO" MAA_PLANNED_RPO "$MAA_PLANNED_RPO"
  menu_prompt_path "criticality (dev/production/mission-critical/ultra-critical)" MAA_CRITICALITY "$MAA_CRITICALITY"
  menu_prompt_path "local HA target (yes/no)" MAA_LOCAL_HA_TARGET "$MAA_LOCAL_HA_TARGET"
  menu_prompt_path "DR required (yes/no)" MAA_DR_REQUIRED "$MAA_DR_REQUIRED"
  menu_prompt_path "automatic failover required (yes/no)" MAA_AUTOMATIC_FAILOVER_REQUIRED "$MAA_AUTOMATIC_FAILOVER_REQUIRED"
  menu_prompt_path "active-active required (yes/no)" MAA_ACTIVE_ACTIVE_REQUIRED "$MAA_ACTIVE_ACTIVE_REQUIRED"
  menu_prompt_path "platform hint (generic/Exadata/ODA/BaseDB/etc.)" MAA_PLATFORM_HINT "$MAA_PLATFORM_HINT"
  menu_prompt_path "standby scope (local/remote/unknown)" MAA_STANDBY_SCOPE "$MAA_STANDBY_SCOPE"
}

menu_configure_adb_context() {
  echo
  echo "Autonomous Database report context"
  menu_prompt_path "ADB wallet directory" ADB_WALLET_DIR "$ADB_WALLET_DIR"
  menu_prompt_path "ADB connect alias" ADB_CONNECT_ALIAS "$ADB_CONNECT_ALIAS"
  menu_prompt_path "ADB connect descriptor or Easy Connect string" ADB_CONNECT_DESCRIPTOR "$ADB_CONNECT_DESCRIPTOR"
  menu_prompt_path "ADB service-level hint" ADB_SERVICE_LEVEL "$ADB_SERVICE_LEVEL"
  menu_prompt_oracle_name "ADB user" ADB_USER "$ADB_USER"
  menu_prompt_path "ADB password environment variable name" ADB_PASSWORD_ENV "$ADB_PASSWORD_ENV"
  menu_prompt_path "ADB wallet password environment variable name" ADB_WALLET_PASSWORD_ENV "$ADB_WALLET_PASSWORD_ENV"
  menu_prompt_path "Python executable with python-oracledb" ADB_PYTHON "$ADB_PYTHON"
  menu_prompt_path "ADB TLS mode (mTLS or TLS)" ADB_TLS_MODE "$ADB_TLS_MODE"
  menu_prompt_path "ADB OCID" ADB_OCID "$ADB_OCID"
  menu_prompt_path "ADB compartment OCID" ADB_COMPARTMENT_OCID "$ADB_COMPARTMENT_OCID"
  menu_prompt_path "OCI region" ADB_REGION "$ADB_REGION"
  menu_prompt_path "OCI CLI profile" ADB_OCI_PROFILE "$ADB_OCI_PROFILE"
  menu_prompt_path "OCI CLI config file" ADB_OCI_CONFIG_FILE "$ADB_OCI_CONFIG_FILE"
  menu_prompt_path "OCI CLI auth mode" ADB_OCI_AUTH "$ADB_OCI_AUTH"
  menu_prompt_path "Autonomous APEX URL" ADB_APEX_URL "$ADB_APEX_URL"
  menu_prompt_path "Autonomous Database Actions URL" ADB_DATABASE_ACTIONS_URL "$ADB_DATABASE_ACTIONS_URL"
  menu_prompt_path "Private endpoint/DNS label" ADB_PRIVATE_ENDPOINT "$ADB_PRIVATE_ENDPOINT"
  echo
  echo "Passwords are not prompted here. Set the environment variables named above before running the report."
}

menu_selected_adb_scenario_label() {
  if [[ -n "$ADB_SCENARIO_ID" && -n "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]:-}" ]]; then
    printf "%s - %s" "$ADB_SCENARIO_ID" "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]}"
  else
    printf "none"
  fi
}

menu_select_adb_scenario() {
  local answer

  echo
  print_adb_scenario_catalog
  echo
  echo "Enter ADB scenario id to select, or blank to keep current:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  answer="$(printf "%s" "$answer" | tr '[:lower:]' '[:upper:]')"
  if adb_scenario_exists "$answer"; then
    ADB_SCENARIO_ID="$answer"
    echo "Selected ADB scenario ${ADB_SCENARIO_ID}: ${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]}"
  else
    warn "Unknown ADB scenario id: $answer"
    return "$FAIL"
  fi
}

menu_require_adb_scenario() {
  if [[ -n "$ADB_SCENARIO_ID" && -n "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]:-}" ]]; then
    return "$SUCCESS"
  fi
  menu_select_adb_scenario
  [[ -n "$ADB_SCENARIO_ID" && -n "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]:-}" ]]
}

menu_show_selected_adb_scenario() {
  menu_require_adb_scenario || return "$FAIL"
  print_adb_scenario_detail "$ADB_SCENARIO_ID"
}

menu_adb_helper_placeholder() {
  menu_require_adb_scenario || return "$FAIL"
  echo
  echo "ADB helper execution placeholder"
  echo "Scenario: ${ADB_SCENARIO_ID} - ${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]}"
  echo "Current helper posture: ${ADB_SCENARIO_HELPER[$ADB_SCENARIO_ID]}"
  echo
  echo "No ADB destructive/logical execution helper is enabled yet."
  echo "Use the readiness report and scenario detail now; when seeded logical and OCI helpers are implemented, this menu path can call them without changing the workflow."
}

menu_adb_scenarios() {
  local answer

  while true; do
    echo
    echo "Autonomous Database Scenarios"
    echo "Selected ADB scenario: $(menu_selected_adb_scenario_label)"
    echo "  1. List ADB01-ADB20 with readiness status"
    echo "  2. Select ADB scenario"
    echo "  3. Show selected ADB scenario detail and validation status"
    echo "  4. Configure Autonomous Database report context"
    echo "  5. Run fresh Autonomous Database readiness report"
    echo "  6. Show latest Autonomous Database readiness report"
    echo "  7. Show latest Autonomous Database readiness report and generate HTML"
    echo "  8. Future ADB helper placeholder for selected scenario"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1|l|L)
        print_adb_scenario_catalog
        menu_pause
        ;;
      2|s|S)
        menu_select_adb_scenario
        menu_pause
        ;;
      3|d|D)
        menu_show_selected_adb_scenario
        menu_pause
        ;;
      4|c|C)
        menu_configure_adb_context
        menu_pause
        ;;
      5|r|R)
        menu_run_adb_readiness_report
        menu_pause
        ;;
      6)
        menu_run_show_latest_adb_report "text"
        menu_pause
        ;;
      7)
        menu_run_show_latest_adb_report "html"
        menu_pause
        ;;
      8|e|E)
        menu_adb_helper_placeholder
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown Autonomous Database menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_run_audit_status() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--audit-status")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_audit_purge() {
  local run_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--purge-audit-logs")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown audit purge mode: $run_mode"; return "$FAIL" ;;
  esac
  menu_run_child_command
}

menu_run_review_index() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--review")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_review_topology() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--review-topology")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_prompt_artifact_reference() {
  local var_name="$1"
  local answer

  echo "Enter artifact path or latest:<kind> reference."
  echo "Kinds: topology, config, backup, service, apex-ords, adb, scenario-readiness, lifecycle, lifecycle-check, maa, health, doctor, first-run, public-limitations, scenario, protect, recover, runbook, baseline, review, audit, any"
  echo "Blank uses latest:any:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="latest:any"
  printf -v "$var_name" "%s" "$answer"
}

menu_run_show_artifact() {
  local html_mode="$1"
  local ref
  menu_prompt_artifact_reference ref || return "$FAIL"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--show-artifact" "$ref")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_render_html() {
  local ref
  menu_prompt_artifact_reference ref || return "$FAIL"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--render-html" "$ref")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

file_mtime_epoch() {
  local file="$1"
  local epoch

  epoch="$(stat -c %Y "$file" 2>/dev/null || true)"
  if [[ -z "$epoch" ]]; then
    epoch="$(stat -f %m "$file" 2>/dev/null || true)"
  fi
  [[ "$epoch" =~ ^[0-9]+$ ]] || epoch=0
  printf "%s" "$epoch"
}

format_epoch_local() {
  local epoch="$1"

  if date -d "@${epoch}" "+%Y-%m-%d %H:%M:%S %Z" >/dev/null 2>&1; then
    date -d "@${epoch}" "+%Y-%m-%d %H:%M:%S %Z"
  else
    date -r "$epoch" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf "unknown"
  fi
}

file_size_human() {
  local file="$1"
  du -h "$file" 2>/dev/null | awk '{print $1}' || printf "?"
}

artifact_kind_from_path() {
  local file="$1"
  local base

  base="$(basename "$file")"
  case "$base" in
    *.manifest) printf "manifest" ;;
    *.rman) printf "rman" ;;
    *.sql) printf "sql" ;;
    *.md) printf "report" ;;
    *.html) printf "html" ;;
    *.log) printf "log" ;;
    *.txt) printf "text" ;;
    *.evidence) printf "evidence" ;;
    *.out) printf "output" ;;
    metadata.env) printf "audit-meta" ;;
    command.redacted) printf "audit-cmd" ;;
    exit_status) printf "audit-exit" ;;
    artifact_index) printf "audit-index" ;;
    *) printf "file" ;;
  esac
}

menu_collect_artifacts() {
  local category="$1"
  local limit="${2:-60}"
  local file epoch record
  local -a records=()

  MENU_ARTIFACT_FILES=()
  case "$category" in
    recent)
      [[ -d "$LOG_DIR" ]] || return "$SUCCESS"
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        epoch="$(file_mtime_epoch "$file")"
        records+=("${epoch}|${file}")
      done < <(find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.manifest' -o -name '*.log' -o -name '*.rman' -o -name '*.sql' -o -name '*.md' -o -name '*.txt' -o -name '*.html' -o -name '*.out' -o -name '*.evidence' \) 2>/dev/null)
      ;;
    reports)
      [[ -d "$LOG_DIR" ]] || return "$SUCCESS"
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        epoch="$(file_mtime_epoch "$file")"
        records+=("${epoch}|${file}")
      done < <(find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.md' -o -name '*.html' \) 2>/dev/null)
      ;;
    audit)
      audit_effective_dir
      [[ -d "$AUDIT_DIR" ]] || return "$SUCCESS"
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        epoch="$(file_mtime_epoch "$file")"
        records+=("${epoch}|${file}")
      done < <(find "$AUDIT_DIR" -mindepth 1 -maxdepth 4 -type f \( -name '*.log' -o -name '*.env' -o -name '*.redacted' -o -name '*.manifest' -o -name '*.md' -o -name '*.txt' -o -name '*.rman' -o -name '*.sql' -o -name '*.out' -o -name '*.evidence' -o -name 'exit_status' -o -name 'artifact_index' \) 2>/dev/null)
      ;;
    *)
      warn "Unknown artifact category: $category"
      return "$FAIL"
      ;;
  esac

  while IFS= read -r record; do
    [[ -n "$record" ]] || continue
    MENU_ARTIFACT_FILES+=("${record#*|}")
  done < <(printf "%s\n" "${records[@]}" | sort -t'|' -k1,1rn | head -n "$limit")
}

menu_print_artifact_list() {
  local idx file epoch when kind size

  if [[ "${#MENU_ARTIFACT_FILES[@]}" -eq 0 ]]; then
    echo "No files found."
    return "$SUCCESS"
  fi

  printf "  %3s  %-22s %-12s %-8s %s\n" "No." "Generated" "Type" "Size" "File"
  printf "  %3s  %-22s %-12s %-8s %s\n" "---" "----------------------" "------------" "--------" "----"
  idx=1
  for file in "${MENU_ARTIFACT_FILES[@]}"; do
    epoch="$(file_mtime_epoch "$file")"
    when="$(format_epoch_local "$epoch")"
    kind="$(artifact_kind_from_path "$file")"
    size="$(file_size_human "$file")"
    printf "  %3d. %-22s %-12s %-8s %s\n" "$idx" "$when" "$kind" "$size" "$file"
    idx=$((idx + 1))
  done
}

menu_inspect_artifact_file() {
  local file="$1"

  [[ -f "$file" ]] || {
    warn "Selected file no longer exists: $file"
    return "$FAIL"
  }
  echo
  echo "Inspecting artifact"
  echo "Path: ${file}"
  echo "Generated: $(format_epoch_local "$(file_mtime_epoch "$file")")"
  echo "Type: $(artifact_kind_from_path "$file")"
  echo "Size: $(file_size_human "$file")"
  echo
  show_artifact "$file"
}

menu_browse_artifacts() {
  local title="$1"
  local category="$2"
  local limit="${3:-60}"
  local answer idx

  while true; do
    menu_collect_artifacts "$category" "$limit" || return "$FAIL"
    echo
    echo "$title"
    menu_print_artifact_list
    if [[ "${#MENU_ARTIFACT_FILES[@]}" -eq 0 ]]; then
      menu_pause
      return "$SUCCESS"
    fi
    echo
    echo "Enter a number to inspect, r to refresh, or b/blank to go back:"
    read -r answer || return "$FAIL"
    [[ -n "$answer" ]] || return "$SUCCESS"
    case "$answer" in
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      r|R)
        continue
        ;;
    esac
    if [[ "$answer" =~ ^[0-9]+$ && "$answer" -ge 1 && "$answer" -le "${#MENU_ARTIFACT_FILES[@]}" ]]; then
      idx=$((answer - 1))
      menu_inspect_artifact_file "${MENU_ARTIFACT_FILES[$idx]}"
      menu_pause
    else
      warn "Invalid selection: $answer"
      menu_pause
    fi
  done
}

menu_review_center() {
  local answer

  while true; do
    echo
    echo "Review Center"
    echo "  1. Show latest collected topology"
    echo "  2. Generate HTML for latest collected topology"
    echo "  3. Generate collected activity review index"
    echo "  4. Generate collected activity review index with HTML"
    echo "  5. Show artifact as text"
    echo "  6. Show artifact as text and generate HTML"
    echo "  7. Generate HTML for artifact"
    echo "  8. Show recent manifests, logs, reports, and HTML files"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        menu_run_review_topology "text"
        menu_pause
        ;;
      2)
        menu_run_review_topology "html"
        menu_pause
        ;;
      3)
        menu_run_review_index "text"
        menu_pause
        ;;
      4)
        menu_run_review_index "html"
        menu_pause
        ;;
      5)
        menu_run_show_artifact "text"
        menu_pause
        ;;
      6)
        menu_run_show_artifact "html"
        menu_pause
        ;;
      7)
        menu_run_render_html
        menu_pause
        ;;
      8)
        menu_browse_artifacts "Recent Manifests, Logs, Reports, And Helper Files" "recent" 60
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown review menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_audit_settings() {
  local answer

  while true; do
    echo
    echo "Audit / Retention Settings"
    echo "  1. Enable/disable audit log retention"
    echo "  2. Set audit retention days"
    echo "  3. Set audit directory"
    echo "  4. Show audit status"
    echo "  5. Dry-run audit purge"
    echo "  6. Execute audit purge"
    echo "  7. Browse audit logs and inspect contents"
    echo "  b. Back"
    echo
    echo "Current retain=${AUDIT_RETAIN} retention_days=${AUDIT_RETENTION_DAYS} audit_dir=${AUDIT_DIR}"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        menu_prompt_audit_retain
        menu_pause
        ;;
      2)
        menu_prompt_audit_retention_days
        menu_pause
        ;;
      3)
        menu_prompt_path "audit directory" AUDIT_DIR "$AUDIT_DIR"
        [[ -n "$AUDIT_DIR" ]] || audit_effective_dir
        mkdir -p "$AUDIT_DIR" || die "Unable to create audit directory: $AUDIT_DIR"
        menu_pause
        ;;
      4)
        menu_run_audit_status
        menu_pause
        ;;
      5)
        menu_run_audit_purge "dry-run"
        menu_pause
        ;;
      6)
        menu_run_audit_purge "execute"
        menu_pause
        ;;
      7)
        menu_browse_artifacts "Audit Logs And Retained Run Artifacts" "audit" 80
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown audit menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_reports() {
  local answer

  while true; do
    echo
    echo "Reports"
    echo "  1. Generate target configuration report"
    echo "  2. Generate target configuration report with deep RMAN validation (read-only, heavier)"
    echo "  3. Generate Oracle MAA readiness report"
    echo "  4. Set MAA / SLA planning context"
    echo "  5. Generate resilience scorecard"
    echo "  6. Generate Oracle service HA best-practice review"
    echo "  7. Generate backup strategy and recoverability report"
    echo "  8. Generate backup report with deep RMAN validation (read-only, heavier)"
    echo "  9. Dry-run fresh RMAN baseline backup"
    echo " 10. Run fresh RMAN baseline backup (requires BASELINE-BACKUP confirmation)"
    echo " 11. Generate scenario lifecycle coverage report"
    echo " 12. Generate APEX / ORDS readiness report"
    echo " 13. Set Autonomous Database report context"
    echo " 14. Generate Autonomous Database readiness report"
    echo " 15. Browse generated reports and inspect contents"
    echo " 16. List Autonomous Database scenarios with readiness status"
    echo " 17. Select Autonomous Database scenario"
    echo " 18. Show selected Autonomous Database scenario detail"
    echo " 19. Open Autonomous Database scenarios submenu"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        REPORT_DEEP_VALIDATE=0
        menu_run_configuration_report
        menu_pause
        ;;
      2)
        REPORT_DEEP_VALIDATE=1
        menu_run_configuration_report
        menu_pause
        ;;
      3)
        menu_run_maa_report
        menu_pause
        ;;
      4)
        menu_configure_maa_context
        menu_pause
        ;;
      5)
        menu_run_resilience_scorecard
        menu_pause
        ;;
      6)
        menu_run_service_review
        menu_pause
        ;;
      7)
        REPORT_DEEP_VALIDATE=0
        menu_run_backup_report
        menu_pause
        ;;
      8)
        REPORT_DEEP_VALIDATE=1
        menu_run_backup_report
        menu_pause
        ;;
      9)
        menu_run_baseline_backup "dry-run"
        menu_pause
        ;;
      10)
        menu_run_baseline_backup "execute"
        menu_pause
        ;;
      11)
        menu_run_scenario_lifecycle_report
        menu_pause
        ;;
      12)
        menu_run_apex_ords_report
        menu_pause
        ;;
      13)
        menu_configure_adb_context
        menu_pause
        ;;
      14)
        menu_run_adb_readiness_report
        menu_pause
        ;;
      15)
        menu_browse_artifacts "Generated Reports And HTML Artifacts" "reports" 80
        ;;
      16)
        print_adb_scenario_catalog
        menu_pause
        ;;
      17)
        menu_select_adb_scenario
        menu_pause
        ;;
      18)
        menu_show_selected_adb_scenario
        menu_pause
        ;;
      19)
        menu_adb_scenarios
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown reports choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_show_recent_artifacts() {
  menu_browse_artifacts "Recent Manifests, Logs, Reports, And Helper Files" "recent" 60
}

interactive_menu() {
  local answer

  while true; do
    menu_print_header
    echo
    echo "Guided Workflow"
    echo
    echo "Safe discovery and planning"
    echo "  1. Discover or refresh database topology"
    echo "  2. Select scenario"
    echo "  3. List all scenarios"
    echo "  4. Show recovery runbook for selected scenario"
    echo "  v. Validate selected scenario readiness"
    echo "  5. Dry-run selected scenario"
    echo "  6. Dry-run protection for selected scenario"
    echo "  9. Dry-run recovery for selected scenario"
    echo " 11. Run health check / validation"
    echo " 12. Configure targets and options"
    echo " 13. Browse recent manifests, logs, reports, and inspect contents"
    echo " 14. Dry-run random/aleatory scenario for this topology"
    echo " 16. Reports"
    echo " 17. Generate scenario readiness report for this topology"
    echo " 18. Audit / retention settings"
    echo " 19. Review collected topology, logs, reports, and history"
    echo " 20. Autonomous Database scenarios"
    echo " 21. Seed / prepare scenario lab for this topology"
    echo " 22. Public readiness and safety checks"
    echo
    echo "Execution actions - typed confirmation required"
    echo "  7. Execute protection for selected scenario"
    echo "  8. Execute selected scenario"
    echo " 10. Execute recovery for selected scenario"
    echo " 15. Execute random/aleatory scenario for this topology"
    echo "  q. Quit"
    echo
    echo "Choice:"
    read -r answer || break

    case "$answer" in
      1|d|D)
        discover_environment || true
        print_discovery
        menu_pause
        ;;
      2|s|S)
        menu_select_scenario
        menu_pause
        ;;
      3|l|L)
        list_scenarios
        menu_pause
        ;;
      4|r|R)
        if menu_require_scenario; then
          print_runbook_only "$SCENARIO_ID"
        fi
        menu_pause
        ;;
      v|V)
        menu_run_validate_scenario
        menu_pause
        ;;
      5)
        menu_run_child_action "scenario" "dry-run"
        menu_pause
        ;;
      6)
        menu_run_child_action "protect" "dry-run"
        menu_pause
        ;;
      7)
        menu_run_child_action "protect" "execute"
        menu_pause
        ;;
      8)
        menu_run_child_action "scenario" "execute"
        menu_pause
        ;;
      9)
        menu_run_child_action "recover" "dry-run"
        menu_pause
        ;;
      10)
        menu_run_child_action "recover" "execute"
        menu_pause
        ;;
      11|h|H)
        menu_run_health_check
        menu_pause
        ;;
      12|c|C)
        menu_configure_options
        ;;
      13|a|A)
        menu_show_recent_artifacts
        ;;
      14)
        menu_run_random_scenario "dry-run"
        menu_pause
        ;;
      15)
        menu_run_random_scenario "execute"
        menu_pause
        ;;
      16|p|P)
        menu_reports
        ;;
      17)
        menu_run_scenario_readiness_report
        menu_pause
        ;;
      18)
        menu_audit_settings
        ;;
      19)
        menu_review_center
        ;;
      20)
        menu_adb_scenarios
        ;;
      21)
        menu_prepare_environment
        ;;
      22)
        menu_public_readiness
        ;;
      q|Q|0)
        break
        ;;
      *)
        warn "Unknown menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

