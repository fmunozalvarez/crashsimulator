config_record_applied() {
  local key="$1"
  local value="$2"
  CONFIG_APPLIED+=("${key}=$(redact_config_value "$key" "$value")")
}

config_record_skipped() {
  CONFIG_SKIPPED+=("$1")
}

config_record_warning() {
  CONFIG_WARNINGS+=("$1")
}

config_env_is_set() {
  local env_name="$1"
  [[ -n "${!env_name+x}" ]]
}

config_set_env_if_unset() {
  local key="$1"
  local value="$2"
  local var_name="$3"

  [[ -n "$var_name" ]] || var_name="$key"
  if config_env_is_set "$key"; then
    config_record_skipped "${key}: environment already set"
    return "$SUCCESS"
  fi
  export "${key}=${value}"
  if [[ -n "$var_name" ]]; then
    printf -v "$var_name" "%s" "$value"
  fi
  config_record_applied "$key" "$value"
}

config_set_value_if_env_unset() {
  local key="$1"
  local env_name="$2"
  local var_name="$3"
  local value="$4"

  if config_env_is_set "$env_name"; then
    config_record_skipped "${key}: ${env_name} environment already set"
    return "$SUCCESS"
  fi
  printf -v "$var_name" "%s" "$value"
  config_record_applied "$key" "$value"
}

config_validate_path_value() {
  local key="$1"
  local value="$2"
  [[ -n "$value" ]] || {
    config_record_warning "${key}: empty path ignored"
    return "$FAIL"
  }
  if printf "%s" "$value" | grep -q '[[:cntrl:]]'; then
    config_record_warning "${key}: control characters are not allowed"
    return "$FAIL"
  fi
  return "$SUCCESS"
}

apply_config_entry() {
  local key="$1"
  local value="$2"

  case "$key" in
    ORACLE_SID)
      [[ "$value" =~ ^[A-Za-z0-9_+#.$-]+$ ]] || {
        config_record_warning "${key}: invalid Oracle SID syntax"
        return "$SUCCESS"
      }
      config_set_env_if_unset "$key" "$value" ""
      ;;
    ORACLE_HOME|ORACLE_BASE|TNS_ADMIN|CRASHSIM_GRID_HOME)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_env_if_unset "$key" "$value" ""
      ;;
    SQLPLUS)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_env_if_unset "$key" "$value" "SQLPLUS_BIN"
      ;;
    RMAN)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_env_if_unset "$key" "$value" "RMAN_BIN"
      ;;
    NLS_LANG|TWO_TASK|LOCAL|CRASHSIM_ASM_SID)
      config_set_env_if_unset "$key" "$value" ""
      ;;
    CRASHSIM_PDB|CRASHSIM_DEFAULT_PDB|TARGET_PDB)
      config_set_value_if_env_unset "$key" "CRASHSIM_PDB" TARGET_PDB "$(normalize_name "$value")"
      ;;
    CRASHSIM_SCHEMA|CRASHSIM_DEFAULT_SCHEMA|TARGET_SCHEMA)
      config_set_value_if_env_unset "$key" "CRASHSIM_SCHEMA" TARGET_SCHEMA "$(normalize_name "$value")"
      ;;
    CRASHSIM_FILE_NO|TARGET_FILE_NO)
      config_set_value_if_env_unset "$key" "CRASHSIM_FILE_NO" TARGET_FILE_NO "$value"
      ;;
    CRASHSIM_PFILE|PFILE_PATH)
      config_set_value_if_env_unset "$key" "CRASHSIM_PFILE" PFILE_PATH "$value"
      ;;
    CRASHSIM_SERVICE_NAME|SERVICE_NAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_SERVICE_NAME" SERVICE_NAME "$value"
      ;;
    CRASHSIM_SYSBACKUP_USER|SYSBACKUP_USER)
      config_set_value_if_env_unset "$key" "CRASHSIM_SYSBACKUP_USER" SYSBACKUP_USER "$(normalize_name "$value")"
      ;;
    CRASHSIM_TEMPFILE_SIZE|TEMPFILE_SIZE)
      config_set_value_if_env_unset "$key" "CRASHSIM_TEMPFILE_SIZE" TEMPFILE_SIZE "$value"
      ;;
    CRASHSIM_GRID_USER|GRID_USER)
      config_set_value_if_env_unset "$key" "CRASHSIM_GRID_USER" GRID_USER "$value"
      ;;
    CRASHSIM_LOCAL_ONLY|LOCAL_ONLY)
      config_set_value_if_env_unset "$key" "CRASHSIM_LOCAL_ONLY" LOCAL_ONLY "$value"
      ;;
    CRASHSIM_MAX_TARGETS|MAX_TARGETS)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAX_TARGETS" MAX_TARGETS "$value"
      ;;
    CRASHSIM_PIECE_HANDLE|PIECE_HANDLE)
      config_set_value_if_env_unset "$key" "CRASHSIM_PIECE_HANDLE" PIECE_HANDLE "$value"
      ;;
    CRASHSIM_REPORT_DEEP_VALIDATE|REPORT_DEEP_VALIDATE)
      config_set_value_if_env_unset "$key" "CRASHSIM_REPORT_DEEP_VALIDATE" REPORT_DEEP_VALIDATE "$value"
      ;;
    CRASHSIM_RMAN_CATALOG|RMAN_CATALOG_CONNECT)
      config_set_value_if_env_unset "$key" "CRASHSIM_RMAN_CATALOG" RMAN_CATALOG_CONNECT "$value"
      ;;
    CRASHSIM_BASELINE_TAG_PREFIX|BASELINE_TAG_PREFIX)
      config_set_value_if_env_unset "$key" "CRASHSIM_BASELINE_TAG_PREFIX" BASELINE_TAG_PREFIX "$value"
      ;;
    CRASHSIM_FRA_PRESSURE_TARGET_PCT|FRA_PRESSURE_TARGET_PCT)
      config_set_value_if_env_unset "$key" "CRASHSIM_FRA_PRESSURE_TARGET_PCT" FRA_PRESSURE_TARGET_PCT "$value"
      ;;
    CRASHSIM_FRA_PRESSURE_HEADROOM_MB|FRA_PRESSURE_HEADROOM_MB)
      config_set_value_if_env_unset "$key" "CRASHSIM_FRA_PRESSURE_HEADROOM_MB" FRA_PRESSURE_HEADROOM_MB "$value"
      ;;
    CRASHSIM_TEMP_EXHAUST_MB|TEMP_EXHAUST_MB)
      config_set_value_if_env_unset "$key" "CRASHSIM_TEMP_EXHAUST_MB" TEMP_EXHAUST_MB "$value"
      ;;
    CRASHSIM_ORDS_SERVICE|ORDS_SERVICE_NAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_SERVICE" ORDS_SERVICE_NAME "$value"
      ;;
    CRASHSIM_ORDS_CONFIG_DIR|ORDS_CONFIG_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_CONFIG_DIR" ORDS_CONFIG_DIR "$value"
      ;;
    CRASHSIM_ORDS_URL|ORDS_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_URL" ORDS_URL "$value"
      ;;
    CRASHSIM_ORDS_LB_URL|ORDS_LB_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_LB_URL" ORDS_LB_URL "$value"
      ;;
    CRASHSIM_ORDS_DB_POOL|ORDS_DB_POOL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_DB_POOL" ORDS_DB_POOL "$value"
      ;;
    CRASHSIM_ORDS_PRIV_HELPER|ORDS_PRIV_HELPER)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_PRIV_HELPER" ORDS_PRIV_HELPER "$value"
      ;;
    CRASHSIM_APEX_IMAGES_DIR|APEX_IMAGES_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_IMAGES_DIR" APEX_IMAGES_DIR "$value"
      ;;
    CRASHSIM_APEX_SESSION_DRIVER|APEX_SESSION_DRIVER)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_DRIVER" APEX_SESSION_DRIVER "$value"
      ;;
    CRASHSIM_APEX_SESSION_URL|APEX_SESSION_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_URL" APEX_SESSION_URL "$value"
      ;;
    CRASHSIM_APEX_SESSION_USERNAME|APEX_SESSION_USERNAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_USERNAME" APEX_SESSION_USERNAME "$value"
      ;;
    CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR|APEX_SESSION_SUCCESS_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR" APEX_SESSION_SUCCESS_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_USERNAME_SELECTOR|APEX_SESSION_USERNAME_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_USERNAME_SELECTOR" APEX_SESSION_USERNAME_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_PASSWORD_SELECTOR|APEX_SESSION_PASSWORD_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_PASSWORD_SELECTOR" APEX_SESSION_PASSWORD_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_SUBMIT_SELECTOR|APEX_SESSION_SUBMIT_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_SUBMIT_SELECTOR" APEX_SESSION_SUBMIT_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_DURATION|APEX_SESSION_DURATION)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_DURATION" APEX_SESSION_DURATION "$value"
      ;;
    CRASHSIM_APEX_SESSION_INTERVAL|APEX_SESSION_INTERVAL)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_INTERVAL" APEX_SESSION_INTERVAL "$value"
      ;;
    CRASHSIM_APEX_SESSION_HEADLESS|APEX_SESSION_HEADLESS)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_HEADLESS" APEX_SESSION_HEADLESS "$value"
      ;;
    CRASHSIM_AUDIT_RETAIN|AUDIT_RETAIN)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_RETAIN" AUDIT_RETAIN "$value"
      ;;
    CRASHSIM_AUDIT_RETENTION_DAYS|AUDIT_RETENTION_DAYS)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_RETENTION_DAYS" AUDIT_RETENTION_DAYS "$value"
      ;;
    CRASHSIM_AUDIT_DIR|AUDIT_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_DIR" AUDIT_DIR "$value"
      ;;
    CRASHSIM_AUDIT_STREAM_CAPTURE|AUDIT_STREAM_CAPTURE)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_STREAM_CAPTURE" AUDIT_STREAM_CAPTURE "$value"
      ;;
    CRASHSIM_AUTO_SCORECARD|AUTO_SCORECARD)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUTO_SCORECARD" AUTO_SCORECARD "$value"
      ;;
    CRASHSIM_ACCEPT_DESTRUCTIVE_LAB|ACCEPT_DESTRUCTIVE_LAB|DESTRUCTIVE_LAB_ACK)
      config_set_value_if_env_unset "$key" "CRASHSIM_ACCEPT_DESTRUCTIVE_LAB" DESTRUCTIVE_LAB_ACK "$value"
      ;;
    CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS|TOPOLOGY_CACHE_TTL_SECONDS)
      config_set_value_if_env_unset "$key" "CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS" TOPOLOGY_CACHE_TTL_SECONDS "$value"
      ;;
    CRASHSIM_DISABLE_TOPOLOGY_CACHE|DISABLE_TOPOLOGY_CACHE)
      config_set_value_if_env_unset "$key" "CRASHSIM_DISABLE_TOPOLOGY_CACHE" TOPOLOGY_CACHE_DISABLED "$value"
      ;;
    CRASHSIM_SECRET_SCAN_PATH|SECRET_SCAN_PATH)
      config_set_value_if_env_unset "$key" "CRASHSIM_SECRET_SCAN_PATH" SECRET_SCAN_PATH "$value"
      ;;
    CRASHSIM_SANITIZE_SOURCE_DIR|SANITIZE_SOURCE_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_SANITIZE_SOURCE_DIR" SANITIZE_SOURCE_DIR "$value"
      ;;
    CRASHSIM_SANITIZE_OUTPUT_DIR|SANITIZE_OUTPUT_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_SANITIZE_OUTPUT_DIR" SANITIZE_OUTPUT_DIR "$value"
      ;;
    CRASHSIM_HTML_TARGET|HTML_TARGET)
      config_set_value_if_env_unset "$key" "CRASHSIM_HTML_TARGET" HTML_TARGET "$value"
      ;;
    CRASHSIM_REVIEW_TARGET|REVIEW_TARGET)
      config_set_value_if_env_unset "$key" "CRASHSIM_REVIEW_TARGET" REVIEW_TARGET "$value"
      ;;
    CRASHSIM_MAA_APP_NAME|MAA_APP_NAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_APP_NAME" MAA_APP_NAME "$value"
      ;;
    CRASHSIM_MAA_LOCAL_RTO|MAA_LOCAL_RTO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_LOCAL_RTO" MAA_LOCAL_RTO "$value"
      ;;
    CRASHSIM_MAA_LOCAL_RPO|MAA_LOCAL_RPO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_LOCAL_RPO" MAA_LOCAL_RPO "$value"
      ;;
    CRASHSIM_MAA_DR_RTO|MAA_DR_RTO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_DR_RTO" MAA_DR_RTO "$value"
      ;;
    CRASHSIM_MAA_DR_RPO|MAA_DR_RPO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_DR_RPO" MAA_DR_RPO "$value"
      ;;
    CRASHSIM_MAA_PLANNED_RTO|MAA_PLANNED_RTO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_PLANNED_RTO" MAA_PLANNED_RTO "$value"
      ;;
    CRASHSIM_MAA_PLANNED_RPO|MAA_PLANNED_RPO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_PLANNED_RPO" MAA_PLANNED_RPO "$value"
      ;;
    CRASHSIM_MAA_CRITICALITY|MAA_CRITICALITY)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_CRITICALITY" MAA_CRITICALITY "$value"
      ;;
    CRASHSIM_MAA_LOCAL_HA_TARGET|MAA_LOCAL_HA_TARGET)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_LOCAL_HA_TARGET" MAA_LOCAL_HA_TARGET "$value"
      ;;
    CRASHSIM_MAA_DR_REQUIRED|MAA_DR_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_DR_REQUIRED" MAA_DR_REQUIRED "$value"
      ;;
    CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED|MAA_AUTOMATIC_FAILOVER_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED" MAA_AUTOMATIC_FAILOVER_REQUIRED "$value"
      ;;
    CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED|MAA_ACTIVE_ACTIVE_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED" MAA_ACTIVE_ACTIVE_REQUIRED "$value"
      ;;
    CRASHSIM_MAA_PLATFORM_HINT|MAA_PLATFORM_HINT)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_PLATFORM_HINT" MAA_PLATFORM_HINT "$value"
      ;;
    CRASHSIM_MAA_STANDBY_SCOPE|MAA_STANDBY_SCOPE)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_STANDBY_SCOPE" MAA_STANDBY_SCOPE "$value"
      ;;
    CRASHSIM_ADB_WALLET_DIR|ADB_WALLET_DIR)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_WALLET_DIR" ADB_WALLET_DIR "$value"
      ;;
    CRASHSIM_ADB_CONNECT_ALIAS|ADB_CONNECT_ALIAS)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_CONNECT_ALIAS" ADB_CONNECT_ALIAS "$value"
      ;;
    CRASHSIM_ADB_CONNECT_DESCRIPTOR|ADB_CONNECT_DESCRIPTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_CONNECT_DESCRIPTOR" ADB_CONNECT_DESCRIPTOR "$value"
      ;;
    CRASHSIM_ADB_SERVICE_LEVEL|ADB_SERVICE_LEVEL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_SERVICE_LEVEL" ADB_SERVICE_LEVEL "$value"
      ;;
    CRASHSIM_ADB_USER|ADB_USER)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_USER" ADB_USER "$(normalize_name "$value")"
      ;;
    CRASHSIM_ADB_PASSWORD_ENV|ADB_PASSWORD_ENV)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_PASSWORD_ENV" ADB_PASSWORD_ENV "$value"
      ;;
    CRASHSIM_ADB_WALLET_PASSWORD_ENV|ADB_WALLET_PASSWORD_ENV)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_WALLET_PASSWORD_ENV" ADB_WALLET_PASSWORD_ENV "$value"
      ;;
    CRASHSIM_ADB_PYTHON|ADB_PYTHON)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_PYTHON" ADB_PYTHON "$value"
      ;;
    CRASHSIM_ADB_TLS_MODE|ADB_TLS_MODE)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_TLS_MODE" ADB_TLS_MODE "$value"
      ;;
    CRASHSIM_ADB_OCID|ADB_OCID)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCID" ADB_OCID "$value"
      ;;
    CRASHSIM_ADB_COMPARTMENT_OCID|ADB_COMPARTMENT_OCID)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_COMPARTMENT_OCID" ADB_COMPARTMENT_OCID "$value"
      ;;
    CRASHSIM_ADB_REGION|ADB_REGION)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_REGION" ADB_REGION "$value"
      ;;
    CRASHSIM_ADB_OCI_PROFILE|ADB_OCI_PROFILE)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCI_PROFILE" ADB_OCI_PROFILE "$value"
      ;;
    CRASHSIM_ADB_OCI_CONFIG_FILE|ADB_OCI_CONFIG_FILE)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCI_CONFIG_FILE" ADB_OCI_CONFIG_FILE "$value"
      ;;
    CRASHSIM_ADB_OCI_AUTH|ADB_OCI_AUTH)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCI_AUTH" ADB_OCI_AUTH "$value"
      ;;
    CRASHSIM_ADB_APEX_URL|ADB_APEX_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_APEX_URL" ADB_APEX_URL "$value"
      ;;
    CRASHSIM_ADB_DATABASE_ACTIONS_URL|ADB_DATABASE_ACTIONS_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_DATABASE_ACTIONS_URL" ADB_DATABASE_ACTIONS_URL "$value"
      ;;
    CRASHSIM_ADB_PRIVATE_ENDPOINT|ADB_PRIVATE_ENDPOINT)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_PRIVATE_ENDPOINT" ADB_PRIVATE_ENDPOINT "$value"
      ;;
    CRASHSIM_ADB_SCENARIO|ADB_SCENARIO_ID)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_SCENARIO" ADB_SCENARIO_ID "$(printf "%s" "$value" | tr '[:lower:]' '[:upper:]')"
      ;;
    CRASHSIM_MANIFEST|MANIFEST_FILE)
      config_set_value_if_env_unset "$key" "CRASHSIM_MANIFEST" MANIFEST_FILE "$value"
      [[ -n "$MANIFEST_FILE" ]] && MANIFEST_FROM_ARG=1
      ;;
    CRASHSIM_LOG_DIR|LOG_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_LOG_DIR" LOG_DIR "$value"
      ;;
    CRASHSIM_SQLPLUS_LOGON|SQLPLUS_LOGON)
      config_set_value_if_env_unset "$key" "CRASHSIM_SQLPLUS_LOGON" SQLPLUS_LOGON "$value"
      ;;
    CRASHSIM_ORACLE_USER_REQUIRED|ORACLE_USER_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORACLE_USER_REQUIRED" ORACLE_USER_REQUIRED "$value"
      ;;
    CRASHSIM_SYS_PASSWORD|SYS_PASSWORD|CRASHSIM_APEX_SESSION_PASSWORD|APEX_SESSION_PASSWORD|CRASHSIM_ADB_PASSWORD|ADB_PASSWORD|CRASHSIM_ADB_WALLET_PASSWORD|ADB_WALLET_PASSWORD)
      config_record_warning "${key}: sensitive values are intentionally ignored in config files; use environment variables, wallets, or guided prompts"
      ;;
    PATH|HOME|LD_LIBRARY_PATH)
      config_record_warning "${key}: ignored for safety; set it in the shell before starting CrashSimulator"
      ;;
    *)
      config_record_warning "${key}: unknown or unsupported configuration key"
      ;;
  esac
}

load_config_file() {
  local file="$1"
  local line key value line_no

  [[ -f "$file" ]] || die "Configuration file was not found: $file"
  [[ -r "$file" ]] || die "Configuration file is not readable: $file"

  CONFIG_SOURCE="$file"
  CONFIG_LOADED=1
  CONFIG_APPLIED=()
  CONFIG_SKIPPED=()
  CONFIG_WARNINGS=()

  line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="$(trim_value "$line")"
    [[ -n "$line" ]] || continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" == export[[:space:]]* ]]; then
      line="$(trim_value "${line#export}")"
    fi
    if [[ "$line" != *=* ]]; then
      config_record_warning "line ${line_no}: expected KEY=value"
      continue
    fi
    key="$(trim_value "${line%%=*}")"
    value="$(strip_config_quotes "${line#*=}")"
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      config_record_warning "line ${line_no}: invalid key '${key}'"
      continue
    fi
    apply_config_entry "$key" "$value"
  done <"$file"
}

prescan_config_args() {
  CONFIG_FILE="${CRASHSIM_CONFIG:-}"
  CONFIG_EXPLICIT=0
  CONFIG_DISABLED=0

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --config)
        [[ "$#" -ge 2 ]] || die "--config requires a file path"
        CONFIG_FILE="$2"
        CONFIG_EXPLICIT=1
        shift 2
        ;;
      --no-config)
        CONFIG_DISABLED=1
        shift
        ;;
      --help|-h)
        CONFIG_DISABLED=1
        shift
        ;;
      --)
        break
        ;;
      *)
        shift
        ;;
    esac
  done
}

load_startup_config() {
  local candidate

  prescan_config_args "$@"
  [[ "$CONFIG_DISABLED" -eq 1 ]] && return "$SUCCESS"

  if [[ -n "$CONFIG_FILE" ]]; then
    load_config_file "$CONFIG_FILE"
    return "$SUCCESS"
  fi

  for candidate in \
    "./crashsimulator.conf" \
    "${HOME:-}/.crashsimulator/crashsimulator.conf" \
    "/etc/crashsimulator/crashsimulator.conf"; do
    [[ -n "$candidate" ]] || continue
    if [[ -f "$candidate" ]]; then
      CONFIG_FILE="$candidate"
      load_config_file "$candidate"
      return "$SUCCESS"
    fi
  done
}

show_active_config() {
  local item

  echo "CrashSimulator active startup configuration"
  echo "  Loaded config: ${CONFIG_SOURCE:-not loaded}"
  echo "  Config disabled: ${CONFIG_DISABLED}"
  echo
  echo "Oracle environment:"
  echo "  ORACLE_SID=${ORACLE_SID:-not set}"
  echo "  ORACLE_HOME=${ORACLE_HOME:-not set}"
  echo "  ORACLE_BASE=${ORACLE_BASE:-not set}"
  echo "  TNS_ADMIN=${TNS_ADMIN:-not set}"
  echo "  SQLPLUS=${SQLPLUS_BIN:-${SQLPLUS:-not set}}"
  echo "  RMAN=${RMAN_BIN:-${RMAN:-not set}}"
  echo "  CRASHSIM_GRID_HOME=${CRASHSIM_GRID_HOME:-not set}"
  echo "  CRASHSIM_ASM_SID=${CRASHSIM_ASM_SID:-not set}"
  echo
  echo "CrashSimulator defaults:"
  echo "  PDB=${TARGET_PDB:-not set}"
  echo "  Schema=${TARGET_SCHEMA:-not set}"
  echo "  FILE#=${TARGET_FILE_NO:-not set}"
  echo "  Log dir=${LOG_DIR:-not set}"
  echo "  SQL*Plus logon=$(redact_config_value SQLPLUS_LOGON "$SQLPLUS_LOGON")"
  echo "  Audit retain=${AUDIT_RETAIN}"
  echo "  Audit retention days=${AUDIT_RETENTION_DAYS}"
  echo "  Audit dir=${AUDIT_DIR:-not set}"
  echo "  Auto resilience scorecard refresh=${AUTO_SCORECARD}"
  echo "  Destructive lab acknowledgement=$([[ "${DESTRUCTIVE_LAB_ACK^^}" == "YES" ]] && echo set || echo not set)"
  echo "  Topology cache TTL seconds=${TOPOLOGY_CACHE_TTL_SECONDS}"
  echo "  Topology cache disabled=${TOPOLOGY_CACHE_DISABLED}"
  echo "  Secret scan path=${SECRET_SCAN_PATH}"
  echo "  Sanitize source=${SANITIZE_SOURCE_DIR}"
  echo "  Sanitize output=${SANITIZE_OUTPUT_DIR:-auto}"
  echo "  RMAN catalog=$(redact_config_value RMAN_CATALOG_CONNECT "$RMAN_CATALOG_CONNECT")"
  echo "  Baseline tag prefix=${BASELINE_TAG_PREFIX}"
  echo "  ORDS URL=${ORDS_URL:-not set}"
  echo "  ORDS config dir=${ORDS_CONFIG_DIR:-not set}"
  echo "  APEX session URL=${APEX_SESSION_URL:-not set}"
  echo
  echo "MAA decision-tree context:"
  echo "  Application=${MAA_APP_NAME:-not set}"
  echo "  Criticality=${MAA_CRITICALITY:-not set}"
  echo "  Local unplanned RTO=${MAA_LOCAL_RTO:-not set}"
  echo "  Local unplanned RPO=${MAA_LOCAL_RPO:-not set}"
  echo "  Local HA target=${MAA_LOCAL_HA_TARGET:-not set}"
  echo "  Disaster/site RTO=${MAA_DR_RTO:-not set}"
  echo "  Disaster/site RPO=${MAA_DR_RPO:-not set}"
  echo "  DR required=${MAA_DR_REQUIRED:-not set}"
  echo "  Automatic failover required=${MAA_AUTOMATIC_FAILOVER_REQUIRED:-not set}"
  echo "  Planned maintenance RTO=${MAA_PLANNED_RTO:-not set}"
  echo "  Planned maintenance RPO=${MAA_PLANNED_RPO:-not set}"
  echo "  Active-active required=${MAA_ACTIVE_ACTIVE_REQUIRED:-not set}"
  echo "  Platform hint=${MAA_PLATFORM_HINT:-not set}"
  echo "  Standby scope=${MAA_STANDBY_SCOPE:-unknown}"
  echo
  echo "Autonomous Database defaults:"
  echo "  ADB wallet dir=${ADB_WALLET_DIR:-not set}"
  echo "  ADB connect alias=${ADB_CONNECT_ALIAS:-not set}"
  echo "  ADB connect descriptor=$([[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && printf configured || printf "not set")"
  echo "  ADB service level=${ADB_SERVICE_LEVEL:-not set}"
  echo "  ADB user=${ADB_USER:-not set}"
  echo "  ADB TLS mode=${ADB_TLS_MODE:-not set}"
  echo "  ADB password env=${ADB_PASSWORD_ENV:-not set}"
  echo "  ADB wallet password env=${ADB_WALLET_PASSWORD_ENV:-not set}"
  echo "  ADB Python=${ADB_PYTHON:-not set}"
  echo "  ADB OCID=${ADB_OCID:-not set}"
  echo "  ADB compartment OCID=${ADB_COMPARTMENT_OCID:-not set}"
  echo "  ADB region=${ADB_REGION:-not set}"
  echo "  ADB OCI profile=${ADB_OCI_PROFILE:-not set}"
  echo "  ADB OCI config file=${ADB_OCI_CONFIG_FILE:-not set}"
  echo "  ADB OCI auth=${ADB_OCI_AUTH:-not set}"
  echo "  ADB APEX URL=${ADB_APEX_URL:-not set}"
  echo "  ADB Database Actions URL=${ADB_DATABASE_ACTIONS_URL:-not set}"
  echo "  ADB private endpoint=${ADB_PRIVATE_ENDPOINT:-not set}"
  echo "  ADB selected scenario=${ADB_SCENARIO_ID:-not set}"
  echo
  if [[ "${#CONFIG_APPLIED[@]}" -gt 0 ]]; then
    echo "Config values applied:"
    for item in "${CONFIG_APPLIED[@]}"; do
      echo "  - ${item}"
    done
  else
    echo "Config values applied: none"
  fi
  if [[ "${#CONFIG_SKIPPED[@]}" -gt 0 ]]; then
    echo
    echo "Config values skipped:"
    for item in "${CONFIG_SKIPPED[@]}"; do
      echo "  - ${item}"
    done
  fi
  if [[ "${#CONFIG_WARNINGS[@]}" -gt 0 ]]; then
    echo
    echo "Config warnings:"
    for item in "${CONFIG_WARNINGS[@]}"; do
      echo "  - ${item}"
    done
  fi
}

validate_config_runtime() {
  local errors=0 warnings=0

  show_active_config
  echo
  echo "Configuration validation:"

  if [[ -n "$CONFIG_SOURCE" ]]; then
    if [[ ! -f "$CONFIG_SOURCE" ]]; then
      echo "  ERROR: loaded config no longer exists: $CONFIG_SOURCE"
      errors=$((errors + 1))
    elif [[ ! -r "$CONFIG_SOURCE" ]]; then
      echo "  ERROR: loaded config is not readable: $CONFIG_SOURCE"
      errors=$((errors + 1))
    else
      echo "  OK: config file is readable"
    fi
  else
    echo "  WARN: no configuration file was loaded"
    warnings=$((warnings + 1))
  fi

  if [[ -n "${ORACLE_HOME:-}" ]]; then
    if [[ -d "$ORACLE_HOME" ]]; then
      echo "  OK: ORACLE_HOME directory exists"
      if [[ -x "${ORACLE_HOME}/bin/sqlplus" ]]; then
        echo "  OK: sqlplus exists under ORACLE_HOME"
      else
        echo "  WARN: ${ORACLE_HOME}/bin/sqlplus is not executable"
        warnings=$((warnings + 1))
      fi
      if [[ -x "${ORACLE_HOME}/bin/rman" ]]; then
        echo "  OK: rman exists under ORACLE_HOME"
      else
        echo "  WARN: ${ORACLE_HOME}/bin/rman is not executable"
        warnings=$((warnings + 1))
      fi
    else
      echo "  ERROR: ORACLE_HOME directory does not exist: $ORACLE_HOME"
      errors=$((errors + 1))
    fi
  else
    echo "  WARN: ORACLE_HOME is not set; CrashSimulator will depend on PATH for sqlplus/rman"
    warnings=$((warnings + 1))
  fi

  if [[ -n "${ORACLE_SID:-}" ]]; then
    echo "  OK: ORACLE_SID is set to ${ORACLE_SID}"
  else
    echo "  WARN: ORACLE_SID is not set; local / as sysdba connections may fail"
    warnings=$((warnings + 1))
  fi

  if [[ -n "${TNS_ADMIN:-}" ]]; then
    if [[ -d "$TNS_ADMIN" ]]; then
      echo "  OK: TNS_ADMIN directory exists"
    else
      echo "  WARN: TNS_ADMIN directory does not exist: $TNS_ADMIN"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -n "${CRASHSIM_GRID_HOME:-}" ]]; then
    if [[ -d "$CRASHSIM_GRID_HOME" ]]; then
      echo "  OK: CRASHSIM_GRID_HOME directory exists"
    else
      echo "  WARN: CRASHSIM_GRID_HOME directory does not exist: $CRASHSIM_GRID_HOME"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -n "$LOG_DIR" ]]; then
    if [[ -d "$LOG_DIR" && -w "$LOG_DIR" ]]; then
      echo "  OK: log directory exists and is writable"
    else
      echo "  WARN: log directory is not currently writable or does not exist: $LOG_DIR"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -n "$ADB_WALLET_DIR" ]]; then
    if [[ -d "$ADB_WALLET_DIR" ]]; then
      echo "  OK: ADB wallet directory exists"
      if [[ -f "${ADB_WALLET_DIR}/tnsnames.ora" ]]; then
        echo "  OK: ADB tnsnames.ora exists"
      else
        echo "  WARN: ADB wallet directory does not contain tnsnames.ora"
        warnings=$((warnings + 1))
      fi
    else
      echo "  WARN: ADB wallet directory does not exist: $ADB_WALLET_DIR"
      warnings=$((warnings + 1))
    fi
  fi
  if [[ -n "$ADB_PYTHON" ]]; then
    if command -v "$ADB_PYTHON" >/dev/null 2>&1 || [[ -x "$ADB_PYTHON" ]]; then
      echo "  OK: ADB Python executable found"
    else
      echo "  WARN: ADB Python executable was not found: $ADB_PYTHON"
      warnings=$((warnings + 1))
    fi
  fi
  if [[ -n "$ADB_PASSWORD_ENV" ]]; then
    if [[ -n "${!ADB_PASSWORD_ENV:-}" ]]; then
      echo "  OK: ADB password environment variable is set"
    else
      echo "  INFO: ADB password environment variable is not set: $ADB_PASSWORD_ENV"
    fi
  fi

  echo "  Summary: errors=${errors} warnings=${warnings}"
  [[ "$errors" -eq 0 ]]
}

write_config_template() {
  local file="$1"
  local dir template_sqlplus_logon

  [[ -n "$file" ]] || die "No configuration template path provided."
  if [[ -e "$file" && "$ASSUME_YES" -ne 1 ]]; then
    die "Refusing to overwrite existing file without --yes: $file"
  fi
  dir="$(dirname "$file")"
  [[ "$dir" == "." || -d "$dir" ]] || mkdir -p "$dir" || die "Unable to create directory: $dir"
  template_sqlplus_logon="/ as sysdba"
  if [[ "${SQLPLUS_LOGON:-}" == /* ]]; then
    template_sqlplus_logon="$SQLPLUS_LOGON"
  fi

  cat >"$file" <<EOF || die "Unable to write configuration template: $file"
# CrashSimulator startup configuration
# Precedence: CLI arguments > existing environment variables > this file > built-in defaults.
# Do not store SYS, RMAN catalog, APEX, wallet, token, or other secrets in this file.

ORACLE_SID=${ORACLE_SID:-}
ORACLE_HOME=${ORACLE_HOME:-}
ORACLE_BASE=${ORACLE_BASE:-}
TNS_ADMIN=${TNS_ADMIN:-}

# Optional Grid/ASM context for RAC/ASM reports and planning helpers.
CRASHSIM_GRID_HOME=${CRASHSIM_GRID_HOME:-}
CRASHSIM_ASM_SID=${CRASHSIM_ASM_SID:-}
CRASHSIM_GRID_USER=${GRID_USER:-grid}

# CrashSimulator defaults.
CRASHSIM_PDB=${TARGET_PDB:-}
CRASHSIM_SCHEMA=${TARGET_SCHEMA:-}
CRASHSIM_LOG_DIR=${LOG_DIR:-}
CRASHSIM_SQLPLUS_LOGON='${template_sqlplus_logon}'
CRASHSIM_AUDIT_RETAIN=${AUDIT_RETAIN}
CRASHSIM_AUDIT_RETENTION_DAYS=${AUDIT_RETENTION_DAYS}
CRASHSIM_AUTO_SCORECARD=${AUTO_SCORECARD}
CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=
CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS=${TOPOLOGY_CACHE_TTL_SECONDS}
CRASHSIM_DISABLE_TOPOLOGY_CACHE=${TOPOLOGY_CACHE_DISABLED}
CRASHSIM_SECRET_SCAN_PATH=${SECRET_SCAN_PATH}
CRASHSIM_SANITIZE_SOURCE_DIR=${SANITIZE_SOURCE_DIR}
CRASHSIM_SANITIZE_OUTPUT_DIR=${SANITIZE_OUTPUT_DIR}
# Optional RMAN catalog connect string. Prefer an Oracle wallet alias such as
# CRASHSIM_RMAN_CATALOG=/@crashsim_rman_catalog instead of a password here.
CRASHSIM_RMAN_CATALOG=
CRASHSIM_BASELINE_TAG_PREFIX=${BASELINE_TAG_PREFIX}

# Optional MAA decision-tree context. These are non-secret planning values.
CRASHSIM_MAA_APP_NAME="${MAA_APP_NAME}"
CRASHSIM_MAA_LOCAL_RTO="${MAA_LOCAL_RTO}"
CRASHSIM_MAA_LOCAL_RPO="${MAA_LOCAL_RPO}"
CRASHSIM_MAA_DR_RTO="${MAA_DR_RTO}"
CRASHSIM_MAA_DR_RPO="${MAA_DR_RPO}"
CRASHSIM_MAA_PLANNED_RTO="${MAA_PLANNED_RTO}"
CRASHSIM_MAA_PLANNED_RPO="${MAA_PLANNED_RPO}"
CRASHSIM_MAA_CRITICALITY="${MAA_CRITICALITY}"
CRASHSIM_MAA_LOCAL_HA_TARGET="${MAA_LOCAL_HA_TARGET}"
CRASHSIM_MAA_DR_REQUIRED="${MAA_DR_REQUIRED}"
CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED="${MAA_AUTOMATIC_FAILOVER_REQUIRED}"
CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED="${MAA_ACTIVE_ACTIVE_REQUIRED}"
CRASHSIM_MAA_PLATFORM_HINT="${MAA_PLATFORM_HINT}"
CRASHSIM_MAA_STANDBY_SCOPE="${MAA_STANDBY_SCOPE}"

# Optional APEX/ORDS defaults.
CRASHSIM_ORDS_SERVICE=${ORDS_SERVICE_NAME}
CRASHSIM_ORDS_CONFIG_DIR=${ORDS_CONFIG_DIR}
CRASHSIM_ORDS_URL=${ORDS_URL}
CRASHSIM_ORDS_LB_URL=${ORDS_LB_URL}
CRASHSIM_APEX_IMAGES_DIR=${APEX_IMAGES_DIR}
CRASHSIM_APEX_SESSION_URL=${APEX_SESSION_URL}
CRASHSIM_APEX_SESSION_USERNAME=${APEX_SESSION_USERNAME}

# Optional Autonomous Database defaults. Keep passwords in environment
# variables named by CRASHSIM_ADB_PASSWORD_ENV and
# CRASHSIM_ADB_WALLET_PASSWORD_ENV.
CRASHSIM_ADB_WALLET_DIR=${ADB_WALLET_DIR}
CRASHSIM_ADB_CONNECT_ALIAS=${ADB_CONNECT_ALIAS}
CRASHSIM_ADB_CONNECT_DESCRIPTOR=${ADB_CONNECT_DESCRIPTOR}
CRASHSIM_ADB_SERVICE_LEVEL=${ADB_SERVICE_LEVEL}
CRASHSIM_ADB_USER=${ADB_USER}
CRASHSIM_ADB_PASSWORD_ENV=${ADB_PASSWORD_ENV}
CRASHSIM_ADB_WALLET_PASSWORD_ENV=${ADB_WALLET_PASSWORD_ENV}
CRASHSIM_ADB_PYTHON=${ADB_PYTHON}
CRASHSIM_ADB_TLS_MODE=${ADB_TLS_MODE}
CRASHSIM_ADB_OCID=${ADB_OCID}
CRASHSIM_ADB_COMPARTMENT_OCID=${ADB_COMPARTMENT_OCID}
CRASHSIM_ADB_REGION=${ADB_REGION}
CRASHSIM_ADB_OCI_PROFILE=${ADB_OCI_PROFILE}
CRASHSIM_ADB_OCI_CONFIG_FILE=${ADB_OCI_CONFIG_FILE}
CRASHSIM_ADB_OCI_AUTH=${ADB_OCI_AUTH}
CRASHSIM_ADB_APEX_URL=${ADB_APEX_URL}
CRASHSIM_ADB_DATABASE_ACTIONS_URL=${ADB_DATABASE_ACTIONS_URL}
CRASHSIM_ADB_PRIVATE_ENDPOINT=${ADB_PRIVATE_ENDPOINT}
CRASHSIM_ADB_SCENARIO=${ADB_SCENARIO_ID}
EOF

  chmod 600 "$file" 2>/dev/null || true
  echo "Configuration template written: $file"
  echo "Review it, remove unused values, and keep secrets in environment variables or wallets."
}

normalize_targets() {
  if [[ -n "$TARGET_PDB" ]]; then
    TARGET_PDB="$(normalize_name "$TARGET_PDB")"
    validate_oracle_name "$TARGET_PDB" || die "Invalid PDB name: $TARGET_PDB"
  fi
  if [[ -n "$TARGET_SCHEMA" ]]; then
    TARGET_SCHEMA="$(normalize_name "$TARGET_SCHEMA")"
    validate_oracle_name "$TARGET_SCHEMA" || die "Invalid schema name: $TARGET_SCHEMA"
  fi
  if [[ -n "$TARGET_FILE_NO" && ! "$TARGET_FILE_NO" =~ ^[0-9]+$ ]]; then
    die "Invalid file number: $TARGET_FILE_NO"
  fi
  if [[ -n "$SYSBACKUP_USER" ]]; then
    SYSBACKUP_USER="$(normalize_name "$SYSBACKUP_USER")"
    validate_oracle_name "$SYSBACKUP_USER" || die "Invalid SYSBACKUP user name: $SYSBACKUP_USER"
  fi
  if [[ -n "$ADB_USER" ]]; then
    ADB_USER="$(normalize_name "$ADB_USER")"
    validate_oracle_name "$ADB_USER" || die "Invalid ADB user name: $ADB_USER"
  fi
  if [[ -n "$ADB_SCENARIO_ID" ]]; then
    ADB_SCENARIO_ID="$(printf "%s" "$ADB_SCENARIO_ID" | tr '[:lower:]' '[:upper:]')"
    adb_scenario_exists "$ADB_SCENARIO_ID" || die "Invalid ADB scenario id: $ADB_SCENARIO_ID"
  fi
  validate_tempfile_size "$TEMPFILE_SIZE" || die "Invalid tempfile size: $TEMPFILE_SIZE"
  LOCAL_ONLY="$(normalize_bool "$LOCAL_ONLY")" || die "Invalid local-only value: $LOCAL_ONLY"
  REPORT_DEEP_VALIDATE="$(normalize_bool "$REPORT_DEEP_VALIDATE")" || die "Invalid report deep-validate value: $REPORT_DEEP_VALIDATE"
  AUDIT_RETAIN="$(normalize_bool "$AUDIT_RETAIN")" || die "Invalid audit retain value: $AUDIT_RETAIN"
  local raw_auto_scorecard="$AUTO_SCORECARD"
  AUTO_SCORECARD="$(normalize_bool "$raw_auto_scorecard")" || die "Invalid auto scorecard value: $raw_auto_scorecard"
  local raw_topology_cache_disabled="$TOPOLOGY_CACHE_DISABLED"
  TOPOLOGY_CACHE_DISABLED="$(normalize_bool "$raw_topology_cache_disabled")" ||
    die "Invalid topology cache disabled value: $raw_topology_cache_disabled"
  [[ "$TOPOLOGY_CACHE_TTL_SECONDS" =~ ^[0-9]+$ ]] ||
    die "Invalid topology cache TTL seconds: $TOPOLOGY_CACHE_TTL_SECONDS"
  AUDIT_STREAM_CAPTURE="$(normalize_auto_bool "$AUDIT_STREAM_CAPTURE")" ||
    die "Invalid audit stream capture value: $AUDIT_STREAM_CAPTURE"
  [[ "$AUDIT_RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "Invalid audit retention days: $AUDIT_RETENTION_DAYS"
  [[ "$FRA_PRESSURE_TARGET_PCT" =~ ^[0-9]+$ && "$FRA_PRESSURE_TARGET_PCT" -ge 50 && "$FRA_PRESSURE_TARGET_PCT" -le 100 ]] ||
    die "Invalid FRA pressure target percentage: $FRA_PRESSURE_TARGET_PCT"
  [[ "$FRA_PRESSURE_HEADROOM_MB" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid FRA pressure headroom MB: $FRA_PRESSURE_HEADROOM_MB"
  [[ "$TEMP_EXHAUST_MB" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid TEMP exhaust MB: $TEMP_EXHAUST_MB"
  [[ "$APEX_SESSION_DURATION" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid APEX session duration seconds: $APEX_SESSION_DURATION"
  [[ "$APEX_SESSION_INTERVAL" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid APEX session interval seconds: $APEX_SESSION_INTERVAL"
  APEX_SESSION_HEADLESS="$(normalize_bool "$APEX_SESSION_HEADLESS")" ||
    die "Invalid APEX session headless value: $APEX_SESSION_HEADLESS"
  [[ "$ADB_PASSWORD_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] ||
    die "Invalid ADB password environment variable name: $ADB_PASSWORD_ENV"
  [[ "$ADB_WALLET_PASSWORD_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] ||
    die "Invalid ADB wallet password environment variable name: $ADB_WALLET_PASSWORD_ENV"
  case "$(printf "%s" "$ADB_SERVICE_LEVEL" | tr '[:upper:]' '[:lower:]')" in
    low|medium|high|tp|tpurgent) ;;
    *) die "Invalid ADB service level: $ADB_SERVICE_LEVEL" ;;
  esac
  case "$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')" in
    tls|mtls) ;;
    *) die "Invalid ADB TLS mode: $ADB_TLS_MODE" ;;
  esac
  if [[ -n "$MAX_TARGETS" && ! "$MAX_TARGETS" =~ ^[1-9][0-9]*$ ]]; then
    die "Invalid max targets value: $MAX_TARGETS"
  fi
}

