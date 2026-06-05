#!/usr/bin/env bash
#
# CrashSimulator V2 - Oracle HA/DR/backup and recovery practice framework.
#
# Default behavior is safe: discovery, listing, and dry-run planning do not
# damage the database. Destructive actions require --execute and confirmation.

set -uo pipefail

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "ERROR: CrashSimulator V2 requires Bash 4 or later. Current Bash: ${BASH_VERSION:-unknown}" >&2
  echo "On Oracle Linux, run it with /bin/bash from the database host." >&2
  exit 2
fi

VERSION="2.0.0-dev"
SUCCESS=0
FAIL=1

PROGRAM="$(basename "$0")"
MODE="menu"
SCENARIO_ID=""
TARGET_PDB="${CRASHSIM_PDB:-}"
TARGET_SCHEMA="${CRASHSIM_SCHEMA:-}"
TARGET_FILE_NO="${CRASHSIM_FILE_NO:-}"
PFILE_PATH="${CRASHSIM_PFILE:-}"
SYS_PASSWORD="${CRASHSIM_SYS_PASSWORD:-}"
SERVICE_NAME="${CRASHSIM_SERVICE_NAME:-}"
SYSBACKUP_USER="${CRASHSIM_SYSBACKUP_USER:-C##DBLCMUSER}"
TEMPFILE_SIZE="${CRASHSIM_TEMPFILE_SIZE:-100m}"
LOCAL_ONLY="${CRASHSIM_LOCAL_ONLY:-0}"
MAX_TARGETS="${CRASHSIM_MAX_TARGETS:-}"
PIECE_HANDLE="${CRASHSIM_PIECE_HANDLE:-}"
REPORT_DEEP_VALIDATE="${CRASHSIM_REPORT_DEEP_VALIDATE:-0}"
RMAN_CATALOG_CONNECT="${CRASHSIM_RMAN_CATALOG:-}"
BASELINE_TAG_PREFIX="${CRASHSIM_BASELINE_TAG_PREFIX:-CSIM_BASE}"
AUDIT_RETAIN="${CRASHSIM_AUDIT_RETAIN:-1}"
AUDIT_RETENTION_DAYS="${CRASHSIM_AUDIT_RETENTION_DAYS:-365}"
AUDIT_DIR="${CRASHSIM_AUDIT_DIR:-}"
HTML_OUTPUT=0
HTML_TARGET="${CRASHSIM_HTML_TARGET:-}"
REVIEW_TARGET="${CRASHSIM_REVIEW_TARGET:-}"
MAA_APP_NAME="${CRASHSIM_MAA_APP_NAME:-}"
MAA_LOCAL_RTO="${CRASHSIM_MAA_LOCAL_RTO:-}"
MAA_LOCAL_RPO="${CRASHSIM_MAA_LOCAL_RPO:-}"
MAA_DR_RTO="${CRASHSIM_MAA_DR_RTO:-}"
MAA_DR_RPO="${CRASHSIM_MAA_DR_RPO:-}"
MAA_PLANNED_RTO="${CRASHSIM_MAA_PLANNED_RTO:-}"
MAA_PLANNED_RPO="${CRASHSIM_MAA_PLANNED_RPO:-}"
LOG_DIR="${CRASHSIM_LOG_DIR:-}"
WORK_DIR=""
RUN_ID="$(date +%Y%m%d_%H%M%S)"
EXECUTE=0
ASSUME_YES=0
VERBOSE=0
SQLPLUS_BIN="${SQLPLUS:-}"
RMAN_BIN="${RMAN:-}"
SQLPLUS_LOGON="${CRASHSIM_SQLPLUS_LOGON:-/ as sysdba}"
ORACLE_USER_REQUIRED="${CRASHSIM_ORACLE_USER_REQUIRED:-0}"
MANIFEST_FILE="${CRASHSIM_MANIFEST:-}"
MANIFEST_FROM_ARG="${CRASHSIM_MANIFEST:+1}"
MANIFEST_FROM_ARG="${MANIFEST_FROM_ARG:-0}"
CURRENT_SCENARIO_ID=""
PLANNING_ONLY=0
AUDIT_RUN_DIR=""
AUDIT_MARKER_FILE=""
AUDIT_STDOUT_FILE=""
AUDIT_STDERR_FILE=""
AUDIT_STDOUT_FIFO=""
AUDIT_STDERR_FIFO=""
AUDIT_STARTED=0
AUDIT_FINALIZED=0

DB_NAME=""
DB_UNIQUE_NAME=""
DB_ROLE=""
DB_OPEN_MODE=""
DB_CDB=""
DB_PROTECTION_MODE=""
DB_SWITCHOVER_STATUS=""
INSTANCE_NAME=""
HOST_NAME=""
INSTANCE_STATUS=""
INSTANCE_PARALLEL=""
INSTANCE_THREAD=""
ORACLE_BASE_DETECTED=""
SPFILE_PATH=""
FRA_PATH=""
PASSWORD_FILE_PATH=""
CLUSTER_TYPE="UNKNOWN"
STORAGE_TYPE="UNKNOWN"
GI_MANAGED=0
DISCOVERED=0

declare -a PDB_ROWS=()
declare -a TARGET_ROWS=()
declare -a ACTION_KINDS=()
declare -a ACTION_TARGETS=()
declare -a ACTION_DETAILS=()
declare -a PLAN_TARGET_PATHS=()
declare -a PLAN_TARGET_PDBS=()
declare -a PLAN_TARGET_CON_IDS=()
declare -a PLAN_TARGET_FILE_NOS=()
declare -a PLAN_TARGET_TABLESPACES=()
declare -a RESTORE_ORIGINALS=()
declare -a RESTORE_BACKUPS=()
declare -a RECOVER_FILE_NOS=()
declare -a ORIGINAL_ARGS=("$@")
RENAME_COUNT=0

declare -a SCENARIO_IDS=()
declare -A SCENARIO_TITLE=()
declare -A SCENARIO_GROUP=()
declare -A SCENARIO_SCOPE=()
declare -A SCENARIO_IMPACT=()
declare -A SCENARIO_REQUIRES=()
declare -A SCENARIO_HANDLER=()
declare -A SCENARIO_NOTES=()
declare -A MAA_EVIDENCE=()
declare -A BACKUP_EVIDENCE=()

SCENARIO_VALIDATION_STATUS=""
SCENARIO_VALIDATION_REASON=""
SCENARIO_VALIDATION_OUTPUT=""

usage() {
  cat <<USAGE
CrashSimulator V2 ${VERSION}

Usage:
  ./${PROGRAM} --discover
  ./${PROGRAM} --list
  ./${PROGRAM} --menu
  ./${PROGRAM} --health-check
  ./${PROGRAM} --config-report [--deep-validate]
  ./${PROGRAM} --backup-report [--deep-validate]
  ./${PROGRAM} --baseline-backup [--dry-run|--execute]
  ./${PROGRAM} --audit-status
  ./${PROGRAM} --purge-audit-logs [--dry-run|--execute]
  ./${PROGRAM} --review
  ./${PROGRAM} --review-topology
  ./${PROGRAM} --show-artifact <path|latest[:kind]> [--html]
  ./${PROGRAM} --render-html <path|latest[:kind]>
  ./${PROGRAM} --maa-report
  ./${PROGRAM} --validate-scenario <id> [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --validate-all-scenarios [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --runbook <id> [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --protect <id> [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM} --recover <id> [--manifest <file>] [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM} --scenario <id> [--pdb <pdb_name>] [--dry-run]
  ./${PROGRAM} --scenario <id> [--pdb <pdb_name>] --execute [--yes]
  ./${PROGRAM} --random-scenario [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM}

Options:
  --discover              Print detected database topology and exits.
  --list                  List scenario registry and prerequisite gates.
  --menu                  Start guided terminal menu. This is the default.
  --health-check          Run a non-destructive SQL health check.
  --config-report         Generate a full target database/PDB configuration report.
  --configuration-report  Alias for --config-report.
  --report                Alias for --config-report.
  --backup-report         Generate backup strategy, recoverability, RTO/RPO report.
  --backup-assessment     Alias for --backup-report.
  --recoverability-report Alias for --backup-report.
  --baseline-backup       Create or dry-run a fresh RMAN baseline backup.
  --fresh-baseline-backup Alias for --baseline-backup.
  --audit-retain <yes|no> Enable or disable per-run audit log retention.
  --audit-retention-days <n>
                          Days to retain audit run folders before purge.
  --audit-dir <dir>       Audit archive directory. Default: <log-dir>/audit.
  --audit-status          Show audit settings, usage, and purge candidates.
  --purge-audit-logs      Purge audit run folders older than retention policy.
  --review                Generate and print an index of collected topology,
                          scenarios, runbooks, dry-runs, protection, health,
                          backup/config/MAA reports, audit records, and logs.
  --review-artifacts      Alias for --review.
  --review-topology       Print the latest collected topology snapshot/report.
  --show-artifact <path|latest[:kind]>
                          Print an already collected artifact.
  --render-html <path|latest[:kind]>
                          Generate an HTML copy of an artifact.
  --html                  With reports/show-artifact, also generate HTML output.
  --maa-report            Generate Oracle MAA posture, best-practice, and tier report.
  --maa-assessment        Alias for --maa-report.
  --maa-readiness         Alias for --maa-report.
  --deep-validate         With reports, run heavier RMAN restore/database validation.
  --validate-scenario <id>
                          Validate whether one scenario can run now and explain blockers.
  --validate <id>         Alias for --validate-scenario.
  --validate-all-scenarios
                          Validate every registered scenario for this topology.
  --runbook <id>          Print recovery practice hints for a scenario.
  --protect <id>          Generate or run pre-drill RMAN protection for a scenario.
  --recover <id>          Generate or run RMAN recovery for supported scenarios.
  --scenario <id>         Run or dry-run a scenario by id.
  --random-scenario       Pick and run a random topology-compatible scenario.
  --aleatory-scenario     Alias for --random-scenario.
  --pdb <name>            Select target PDB for PDB-scoped scenarios.
  --schema <owner>        Select target schema for logical object scenarios.
  --file-no <n>           File number to recover when DB discovery is unavailable.
  --manifest <file>       Read/write a drill manifest. Defaults under --log-dir.
  --pfile <file>          PFILE to use for SPFILE recovery.
  --sys-password <value>  SYS password for password-file remote-auth validation.
  --service-name <name>   Listener service for remote SYSDBA validation.
  --sysbackup-user <name> Common user to re-grant SYSBACKUP after password-file recovery.
  --local-only            Scenario 25: target local filesystem backup pieces only.
  --max-targets <n>       Limit selected targets. Strongly recommended for scenario 25.
  --piece-handle <handle> Scenario 25: target one exact RMAN backup-piece handle.
  --rman-catalog <str>   RMAN recovery catalog connect string for drills/reports/backups.
  --backup-tag-prefix <p> RMAN tag prefix for --baseline-backup. Default: CSIM_BASE.
  --maa-app-name <name>   Optional application name for MAA/SLA planning context.
  --maa-local-rto <value> Optional local unplanned-outage RTO objective.
  --maa-local-rpo <value> Optional local unplanned-outage RPO objective.
  --maa-dr-rto <value>    Optional disaster/site-outage RTO objective.
  --maa-dr-rpo <value>    Optional disaster/site-outage RPO objective.
  --maa-planned-rto <val> Optional planned-maintenance RTO objective.
  --maa-planned-rpo <val> Optional planned-maintenance RPO objective.
  --dry-run               Plan only. This is the default.
  --execute               Execute destructive actions after confirmation.
  --yes                   Skip interactive confirmation. Use only in labs.
  --log-dir <dir>         Directory for logs. Defaults to ./crashsimulator_logs.
  --sqlplus-logon <str>   SQL*Plus logon string. Default: / as sysdba.
  --verbose               Print extra diagnostics.
  --help                  Show this help.

Environment:
  CRASHSIM_PDB                  Default PDB target.
  CRASHSIM_SCHEMA               Default schema target.
  CRASHSIM_FILE_NO              Default RMAN datafile number for recovery.
  CRASHSIM_PFILE                Default PFILE for SPFILE recovery.
  CRASHSIM_SYS_PASSWORD         SYS password for password-file recovery validation.
  CRASHSIM_SERVICE_NAME         Listener service for password-file recovery validation.
  CRASHSIM_SYSBACKUP_USER       Common SYSBACKUP user to restore. Default: C##DBLCMUSER.
  CRASHSIM_TEMPFILE_SIZE        Tempfile size used by tempfile recovery. Default: 100m.
  CRASHSIM_LOCAL_ONLY           Set to 1 to target local filesystem pieces only.
  CRASHSIM_MAX_TARGETS          Limit selected targets.
  CRASHSIM_PIECE_HANDLE         Exact RMAN backup-piece handle for scenario 25.
  CRASHSIM_REPORT_DEEP_VALIDATE Set to 1 to run deep RMAN validation in reports.
  CRASHSIM_RMAN_CATALOG         RMAN recovery catalog connect string.
  CRASHSIM_BASELINE_TAG_PREFIX  RMAN tag prefix for fresh baseline backups.
  CRASHSIM_AUDIT_RETAIN         Set to 1/0 or yes/no. Default: 1.
  CRASHSIM_AUDIT_RETENTION_DAYS Days to keep audit run folders. Default: 365.
  CRASHSIM_AUDIT_DIR            Audit archive directory. Default: <log-dir>/audit.
  CRASHSIM_HTML_TARGET          Default artifact for --render-html.
  CRASHSIM_REVIEW_TARGET        Default artifact for --show-artifact.
  CRASHSIM_MAA_APP_NAME         Application name for MAA/SLA planning context.
  CRASHSIM_MAA_LOCAL_RTO        Local unplanned-outage RTO objective.
  CRASHSIM_MAA_LOCAL_RPO        Local unplanned-outage RPO objective.
  CRASHSIM_MAA_DR_RTO           Disaster/site-outage RTO objective.
  CRASHSIM_MAA_DR_RPO           Disaster/site-outage RPO objective.
  CRASHSIM_MAA_PLANNED_RTO      Planned-maintenance RTO objective.
  CRASHSIM_MAA_PLANNED_RPO      Planned-maintenance RPO objective.
  CRASHSIM_MANIFEST             Default manifest path.
  CRASHSIM_LOG_DIR              Default log directory.
  CRASHSIM_SQLPLUS_LOGON        Default SQL*Plus logon string.
  CRASHSIM_ORACLE_USER_REQUIRED Set to 1 to require OS user "oracle".

Safety:
  Destructive operations are never executed unless --execute is provided.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit "$FAIL"
}

warn() {
  echo "WARN: $*" >&2
}

info() {
  echo "$*"
}

debug() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "DEBUG: $*" >&2
  fi
}

trim_blank_lines() {
  sed '/^[[:space:]]*$/d'
}

sql_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

sql_identifier() {
  local value="$1"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

normalize_name() {
  printf "%s" "$1" | tr '[:lower:]' '[:upper:]'
}

validate_oracle_name() {
  local value="$1"
  [[ "$value" =~ ^[A-Za-z][A-Za-z0-9_#\$]{0,127}$ ]]
}

validate_tempfile_size() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+[KkMmGgTt]?$ ]]
}

normalize_bool() {
  local value="$1"
  case "$(printf "%s" "$value" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|y|on) printf "1" ;;
    0|false|no|n|off|"") printf "0" ;;
    *) return "$FAIL" ;;
  esac
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
  validate_tempfile_size "$TEMPFILE_SIZE" || die "Invalid tempfile size: $TEMPFILE_SIZE"
  LOCAL_ONLY="$(normalize_bool "$LOCAL_ONLY")" || die "Invalid local-only value: $LOCAL_ONLY"
  REPORT_DEEP_VALIDATE="$(normalize_bool "$REPORT_DEEP_VALIDATE")" || die "Invalid report deep-validate value: $REPORT_DEEP_VALIDATE"
  AUDIT_RETAIN="$(normalize_bool "$AUDIT_RETAIN")" || die "Invalid audit retain value: $AUDIT_RETAIN"
  [[ "$AUDIT_RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "Invalid audit retention days: $AUDIT_RETENTION_DAYS"
  if [[ -n "$MAX_TARGETS" && ! "$MAX_TARGETS" =~ ^[1-9][0-9]*$ ]]; then
    die "Invalid max targets value: $MAX_TARGETS"
  fi
}

audit_effective_dir() {
  if [[ -z "$AUDIT_DIR" ]]; then
    AUDIT_DIR="${LOG_DIR}/audit"
  fi
}

audit_redact_stream() {
  sed -E \
    -e 's#(connect catalog[[:space:]]+[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's#(CRASHSIM_RMAN_CATALOG=[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's#(CRASHSIM_SYS_PASSWORD=)[^[:space:]]+#\1<redacted>#g' \
    -e 's#([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][^=:]*[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g' \
    -e 's#([Tt][Oo][Kk][Ee][Nn][^=:]*[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g' \
    -e 's#([Ss][Ee][Cc][Rr][Ee][Tt][^=:]*[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g'
}

audit_print_redacted_command() {
  local arg redact_next=0

  printf "%q" "$0"
  for arg in "${ORIGINAL_ARGS[@]}"; do
    if [[ "$redact_next" -eq 1 ]]; then
      printf " %q" "<redacted>"
      redact_next=0
      continue
    fi

    case "$arg" in
      --sys-password|--rman-catalog)
        printf " %q" "$arg"
        redact_next=1
        ;;
      --sys-password=*|--rman-catalog=*)
        printf " %q" "${arg%%=*}=<redacted>"
        ;;
      *)
        printf " %q" "$arg"
        ;;
    esac
  done
  printf "\n"
}

audit_write_redacted_environment() {
  local env_file="$1"

  env | sort | awk -F= '
    {
      key=$1
      value=$0
      sub(/^[^=]*=/, "", value)
      upper=toupper(key)
      if (upper ~ /(PASS|PASSWORD|TOKEN|SECRET|CREDENTIAL|AUTH|PRIVATE.*KEY|ACCESS.*KEY)/ || key == "CRASHSIM_RMAN_CATALOG") {
        print key "=<redacted>"
      } else {
        print key "=" value
      }
    }
  ' >"$env_file" || warn "Unable to write redacted audit environment: $env_file"
}

audit_start() {
  local day_dir metadata_file command_file env_file

  [[ "$AUDIT_RETAIN" -eq 1 ]] || return "$SUCCESS"
  audit_effective_dir
  mkdir -p "$AUDIT_DIR" || die "Unable to create audit directory: $AUDIT_DIR"

  day_dir="${AUDIT_DIR}/$(date -u +%Y-%m-%d)"
  AUDIT_RUN_DIR="${day_dir}/crashsim_audit_${RUN_ID}_$$"
  mkdir -p "$AUDIT_RUN_DIR" || die "Unable to create audit run directory: $AUDIT_RUN_DIR"

  AUDIT_MARKER_FILE="${AUDIT_RUN_DIR}/start.marker"
  AUDIT_STDOUT_FILE="${AUDIT_RUN_DIR}/stdout.log"
  AUDIT_STDERR_FILE="${AUDIT_RUN_DIR}/stderr.log"
  AUDIT_STDOUT_FIFO="${AUDIT_RUN_DIR}/stdout.pipe"
  AUDIT_STDERR_FIFO="${AUDIT_RUN_DIR}/stderr.pipe"
  metadata_file="${AUDIT_RUN_DIR}/metadata.env"
  command_file="${AUDIT_RUN_DIR}/command.redacted"
  env_file="${AUDIT_RUN_DIR}/environment.redacted"

  touch "$AUDIT_MARKER_FILE" "$AUDIT_STDOUT_FILE" "$AUDIT_STDERR_FILE" ||
    die "Unable to initialize audit files under: $AUDIT_RUN_DIR"
  mkfifo "$AUDIT_STDOUT_FIFO" "$AUDIT_STDERR_FIFO" ||
    die "Unable to initialize audit capture pipes under: $AUDIT_RUN_DIR"

  {
    printf "version=%q\n" "$VERSION"
    printf "run_id=%q\n" "$RUN_ID"
    printf "started_at_utc=%q\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "program=%q\n" "$PROGRAM"
    printf "mode=%q\n" "$MODE"
    printf "execute=%q\n" "$EXECUTE"
    printf "assume_yes=%q\n" "$ASSUME_YES"
    printf "cwd=%q\n" "$(pwd)"
    printf "os_user=%q\n" "$(id -un 2>/dev/null || printf unknown)"
    printf "host=%q\n" "$(hostname 2>/dev/null || printf unknown)"
    printf "pid=%q\n" "$$"
    printf "log_dir=%q\n" "$LOG_DIR"
    printf "audit_dir=%q\n" "$AUDIT_DIR"
    printf "audit_retention_days=%q\n" "$AUDIT_RETENTION_DAYS"
  } >"$metadata_file" || die "Unable to write audit metadata: $metadata_file"

  audit_print_redacted_command >"$command_file" ||
    die "Unable to write redacted audit command: $command_file"
  audit_write_redacted_environment "$env_file"

  AUDIT_STARTED=1
  audit_redact_stream <"$AUDIT_STDOUT_FIFO" | tee -a "$AUDIT_STDOUT_FILE" &
  audit_redact_stream <"$AUDIT_STDERR_FIFO" | tee -a "$AUDIT_STDERR_FILE" >&2 &
  exec >"$AUDIT_STDOUT_FIFO" 2>"$AUDIT_STDERR_FIFO"
  rm -f "$AUDIT_STDOUT_FIFO" "$AUDIT_STDERR_FIFO" || true

  echo "Audit logging enabled: ${AUDIT_RUN_DIR}"
}

audit_copy_artifact() {
  local source_file="$1"
  local artifact_dir="$2"
  local dest_file redacted

  dest_file="${artifact_dir}/$(basename "$source_file")"
  redacted="no"
  case "$source_file" in
    *.evidence|*.log|*.manifest|*.md|*.out|*.rman|*.sql|*.txt)
      audit_redact_stream <"$source_file" >"$dest_file" ||
        return "$FAIL"
      redacted="yes"
      ;;
    *)
      cp -p -- "$source_file" "$dest_file" ||
        return "$FAIL"
      ;;
  esac

  printf "%s|%s|redacted=%s\n" "$source_file" "$dest_file" "$redacted"
}

audit_collect_artifacts() {
  local artifact_dir index_file found=0 file

  [[ "$AUDIT_STARTED" -eq 1 && -n "$AUDIT_RUN_DIR" ]] || return "$SUCCESS"
  [[ -n "$LOG_DIR" && -d "$LOG_DIR" && -f "$AUDIT_MARKER_FILE" ]] || return "$SUCCESS"

  artifact_dir="${AUDIT_RUN_DIR}/artifacts"
  index_file="${AUDIT_RUN_DIR}/artifacts.index"
  mkdir -p "$artifact_dir" || {
    warn "Unable to create audit artifact directory: $artifact_dir"
    return "$FAIL"
  }
  : >"$index_file" || {
    warn "Unable to write audit artifact index: $index_file"
    return "$FAIL"
  }

  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    case "$file" in
      "$AUDIT_RUN_DIR"/*) continue ;;
    esac
    if audit_copy_artifact "$file" "$artifact_dir" >>"$index_file"; then
      found=1
    else
      printf "%s|copy_failed\n" "$file" >>"$index_file"
    fi
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -newer "$AUDIT_MARKER_FILE" 2>/dev/null | sort)

  if [[ "$found" -eq 0 ]]; then
    printf "No generated log artifacts were detected for this run.\n" >"$index_file"
  fi
}

audit_finalize() {
  local status="$1"
  local metadata_file

  [[ "$AUDIT_STARTED" -eq 1 && "$AUDIT_FINALIZED" -eq 0 ]] || return "$SUCCESS"
  AUDIT_FINALIZED=1

  audit_collect_artifacts || true
  metadata_file="${AUDIT_RUN_DIR}/metadata.env"
  {
    printf "ended_at_utc=%q\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "exit_status=%q\n" "$status"
  } >>"$metadata_file" || true
  printf "%s\n" "$status" >"${AUDIT_RUN_DIR}/exit_status" || true
  echo "Audit record finalized: ${AUDIT_RUN_DIR}"
}

audit_status() {
  local candidate_count run_count usage

  audit_effective_dir
  echo "CrashSimulator audit status"
  echo "Audit retain: $([[ "$AUDIT_RETAIN" -eq 1 ]] && echo enabled || echo disabled)"
  echo "Audit directory: ${AUDIT_DIR}"
  echo "Retention days: ${AUDIT_RETENTION_DAYS}"

  if [[ ! -d "$AUDIT_DIR" ]]; then
    echo "Audit directory does not exist yet."
    return "$SUCCESS"
  fi

  run_count="$(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' 2>/dev/null | wc -l | tr -d ' ')"
  candidate_count="$(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' -mtime +"$AUDIT_RETENTION_DAYS" 2>/dev/null | wc -l | tr -d ' ')"
  usage="$(du -sh "$AUDIT_DIR" 2>/dev/null | awk '{print $1}')"
  echo "Audit run folders: ${run_count:-0}"
  echo "Purge candidates: ${candidate_count:-0}"
  echo "Disk usage: ${usage:-unknown}"
}

confirm_audit_purge() {
  if [[ "$EXECUTE" -eq 0 || "$ASSUME_YES" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  echo
  echo "About to purge CrashSimulator audit run folders older than ${AUDIT_RETENTION_DAYS} days."
  echo "Audit directory: ${AUDIT_DIR}"
  echo "Type PURGE-AUDIT-LOGS to continue:"
  local answer
  read -r answer
  [[ "$answer" == "PURGE-AUDIT-LOGS" ]] || die "Confirmation did not match. Aborting."
}

purge_audit_logs() {
  local -a purge_dirs=()
  local dir count=0

  audit_effective_dir
  echo "CrashSimulator audit purge"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Audit directory: ${AUDIT_DIR}"
  echo "Retention days: ${AUDIT_RETENTION_DAYS}"

  if [[ ! -d "$AUDIT_DIR" ]]; then
    echo "Audit directory does not exist. Nothing to purge."
    return "$SUCCESS"
  fi

  mapfile -t purge_dirs < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' -mtime +"$AUDIT_RETENTION_DAYS" 2>/dev/null | sort)
  if [[ "${#purge_dirs[@]}" -eq 0 ]]; then
    echo "No audit run folders are older than the retention policy."
    return "$SUCCESS"
  fi

  echo
  echo "Audit run folders selected for purge:"
  for dir in "${purge_dirs[@]}"; do
    [[ -n "$AUDIT_RUN_DIR" && "$dir" == "$AUDIT_RUN_DIR" ]] && continue
    echo "  ${dir}"
    count=$((count + 1))
  done

  if [[ "$count" -eq 0 ]]; then
    echo "Only the current audit run matched the age filter; it will not be purged."
    return "$SUCCESS"
  fi

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo
    echo "DRY-RUN: no audit folders were removed. Re-run with --execute to purge."
    return "$SUCCESS"
  fi

  confirm_audit_purge
  for dir in "${purge_dirs[@]}"; do
    [[ -n "$AUDIT_RUN_DIR" && "$dir" == "$AUDIT_RUN_DIR" ]] && continue
    rm -rf -- "$dir" || die "Unable to remove audit folder: $dir"
  done
  find "$AUDIT_DIR" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
  echo "Purged ${count} audit run folder(s)."
}

init_runtime() {
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="$(pwd)/crashsimulator_logs"
  fi
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  audit_effective_dir
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/crashsimulator.${RUN_ID}.XXXXXX")" ||
    die "Unable to create temporary directory"
  trap cleanup EXIT
}

cleanup() {
  local status=$?
  audit_finalize "$status" || true
  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

ensure_sqlplus() {
  if [[ -n "$SQLPLUS_BIN" && -x "$SQLPLUS_BIN" ]]; then
    return "$SUCCESS"
  fi
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/sqlplus" ]]; then
    SQLPLUS_BIN="${ORACLE_HOME}/bin/sqlplus"
    return "$SUCCESS"
  fi
  SQLPLUS_BIN="$(command -v sqlplus 2>/dev/null || true)"
  if [[ -n "$SQLPLUS_BIN" && -x "$SQLPLUS_BIN" ]]; then
    return "$SUCCESS"
  fi
  die "sqlplus was not found. Set ORACLE_HOME or SQLPLUS."
}

ensure_rman() {
  if [[ -n "$RMAN_BIN" && -x "$RMAN_BIN" ]]; then
    return "$SUCCESS"
  fi
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/rman" ]]; then
    RMAN_BIN="${ORACLE_HOME}/bin/rman"
    return "$SUCCESS"
  fi
  RMAN_BIN="$(command -v rman 2>/dev/null || true)"
  if [[ -n "$RMAN_BIN" && -x "$RMAN_BIN" ]]; then
    return "$SUCCESS"
  fi
  die "rman was not found. Set ORACLE_HOME or RMAN."
}

ensure_orapwd() {
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/orapwd" ]]; then
    printf "%s\n" "${ORACLE_HOME}/bin/orapwd"
    return "$SUCCESS"
  fi
  local orapwd_bin
  orapwd_bin="$(command -v orapwd 2>/dev/null || true)"
  [[ -n "$orapwd_bin" && -x "$orapwd_bin" ]] || die "orapwd was not found. Set ORACLE_HOME or PATH."
  printf "%s\n" "$orapwd_bin"
}

ensure_os_user() {
  if [[ "$ORACLE_USER_REQUIRED" -eq 1 && "$(id -un)" != "oracle" ]]; then
    die "This run requires OS user oracle. Current user: $(id -un)"
  fi
}

sql_query() {
  local output_file="$1"
  shift
  local sql_text="$*"
  ensure_sqlplus
  debug "SQL output: $output_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" >"$output_file" <<SQL
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off termout off
set linesize 32767 trimspool on trimout on tab off
${sql_text}
exit
SQL
}

load_rows() {
  local file="$1"
  TARGET_ROWS=()
  if [[ ! -f "$file" ]]; then
    return "$FAIL"
  fi
  mapfile -t TARGET_ROWS < <(trim_blank_lines <"$file")
  local row
  for row in "${TARGET_ROWS[@]}"; do
    case "$row" in
      SP2-*|ORA-*|PLS-*)
        die "SQL*Plus returned an error while selecting scenario targets: $row"
        ;;
    esac
  done
  return "$SUCCESS"
}

run_sql_action() {
  local title="$1"
  local sql_text="$2"
  local output_file="$WORK_DIR/action.$(printf "%s" "$title" | tr -cd '[:alnum:]_').out"

  if [[ "$EXECUTE" -eq 0 ]]; then
    info "DRY-RUN SQL: $title"
    printf "%s\n" "$sql_text"
    return "$SUCCESS"
  fi

  sql_query "$output_file" "$sql_text"
}

manifest_append() {
  local key="$1"
  local value="$2"
  [[ -n "$MANIFEST_FILE" ]] || return "$SUCCESS"
  printf "%s=%s\n" "$key" "$value" >>"$MANIFEST_FILE"
}

manifest_get() {
  local key="$1"
  [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]] || return "$FAIL"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$MANIFEST_FILE"
}

require_manifest() {
  [[ -n "$MANIFEST_FILE" ]] || die "Recovery requires --manifest <file> for this scenario."
  [[ -f "$MANIFEST_FILE" ]] || die "Manifest file not found: $MANIFEST_FILE"
}

manifest_get_required() {
  local key="$1"
  local value
  value="$(manifest_get "$key" || true)"
  [[ -n "$value" ]] || die "Manifest is missing required key: $key"
  printf "%s\n" "$value"
}

manifest_first_value() {
  local key value
  for key in "$@"; do
    value="$(manifest_get "$key" || true)"
    if [[ -n "$value" ]]; then
      printf "%s\n" "$value"
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

manifest_rename_paths() {
  local original backup
  original="$(manifest_first_value "rename_1_original" "action_1_target" || true)"
  backup="$(manifest_get "rename_1_backup" || true)"
  [[ -n "$original" ]] || return "$FAIL"
  [[ -n "$backup" ]] || return "$FAIL"
  printf "%s|%s\n" "$original" "$backup"
}

load_manifest_restore_pairs() {
  RESTORE_ORIGINALS=()
  RESTORE_BACKUPS=()

  local idx original backup
  idx=1
  while true; do
    original="$(manifest_get "rename_${idx}_original" || true)"
    backup="$(manifest_get "rename_${idx}_backup" || true)"
    if [[ -z "$original" && -z "$backup" ]]; then
      break
    fi
    [[ -n "$original" && -n "$backup" ]] ||
      die "Manifest has an incomplete restore pair for rename_${idx}."
    RESTORE_ORIGINALS+=("$original")
    RESTORE_BACKUPS+=("$backup")
    idx=$((idx + 1))
  done

  [[ "${#RESTORE_ORIGINALS[@]}" -gt 0 ]] || return "$FAIL"
}

copy_restore_pairs_to_originals() {
  local idx original backup
  for idx in "${!RESTORE_ORIGINALS[@]}"; do
    original="${RESTORE_ORIGINALS[$idx]}"
    backup="${RESTORE_BACKUPS[$idx]}"
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would copy $backup back to $original"
    else
      [[ -f "$backup" ]] || die "Scenario backup not found: $backup"
      echo "cp -p -- $backup $original"
      cp -p -- "$backup" "$original" || die "Unable to restore $original from $backup"
    fi
  done
}

safe_remove_restore_backups() {
  local backup
  for backup in "${RESTORE_BACKUPS[@]}"; do
    safe_remove_after_validation "$backup"
  done
}

init_manifest() {
  local mode_name="$1"
  local id="$2"

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    MANIFEST_FILE="${LOG_DIR}/crashsim_${mode_name}_s${id}_${RUN_ID}.manifest"
  fi

  : >"$MANIFEST_FILE" || die "Unable to write manifest: $MANIFEST_FILE"
  manifest_append "version" "$VERSION"
  manifest_append "run_id" "$RUN_ID"
  manifest_append "mode" "$mode_name"
  manifest_append "scenario_id" "$id"
  manifest_append "scenario_title" "${SCENARIO_TITLE[$id]:-unknown}"
  manifest_append "started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "db_name" "${DB_NAME:-unknown}"
  manifest_append "db_unique_name" "${DB_UNIQUE_NAME:-unknown}"
  manifest_append "db_role" "${DB_ROLE:-unknown}"
  manifest_append "db_cdb" "${DB_CDB:-unknown}"
  manifest_append "cluster_type" "${CLUSTER_TYPE:-unknown}"
  manifest_append "gi_managed" "${GI_MANAGED:-0}"
  manifest_append "storage_type" "${STORAGE_TYPE:-unknown}"
  manifest_append "target_pdb" "${TARGET_PDB:-}"
  manifest_append "target_schema" "${TARGET_SCHEMA:-}"
}

datafile_metadata_for_path() {
  local path="$1"
  local file="$WORK_DIR/datafile_metadata.$(printf "%s" "$path" | cksum | awk '{print $1}').lst"
  local path_literal
  path_literal="$(sql_quote "$path")"

  if [[ "$DB_CDB" == "YES" ]]; then
    sql_query "$file" "
select c.name || '|' ||
       vf.con_id || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$datafile vf
join v\$containers c
  on c.con_id = vf.con_id
left join v\$tablespace ts
  on ts.con_id = vf.con_id
 and ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  else
    sql_query "$file" "
select 'NONCDB' || '|' ||
       0 || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$datafile vf
left join v\$tablespace ts
  on ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  fi

  local line pdb_name con_id file_no tablespace datafile_name
  line="$(trim_blank_lines <"$file" | head -n 1)"
  IFS='|' read -r pdb_name con_id file_no tablespace datafile_name <<<"$line"
  [[ -n "$datafile_name" && "$file_no" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$line"
}

redo_metadata_for_path() {
  local path="$1"
  local file="$WORK_DIR/redo_metadata.$(printf "%s" "$path" | cksum | awk '{print $1}').lst"
  local path_literal
  path_literal="$(sql_quote "$path")"

  sql_query "$file" "
select lf.group# || '|' ||
       l.thread# || '|' ||
       l.status || '|' ||
       l.archived || '|' ||
       lf.type || '|' ||
       lf.member
from v\$logfile lf
join v\$log l
  on l.group# = lf.group#
where lf.member = ${path_literal};
"

  local line group_no thread_no status archived member_type member
  line="$(trim_blank_lines <"$file" | head -n 1)"
  IFS='|' read -r group_no thread_no status archived member_type member <<<"$line"
  [[ -n "$member" && "$group_no" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$line"
}

reset_plan_targets() {
  PLAN_TARGET_PATHS=()
  PLAN_TARGET_PDBS=()
  PLAN_TARGET_CON_IDS=()
  PLAN_TARGET_FILE_NOS=()
  PLAN_TARGET_TABLESPACES=()
}

record_action_targets() {
  [[ -n "$MANIFEST_FILE" ]] || return "$SUCCESS"

  local idx action_no kind target detail metadata pdb_name con_id file_no tablespace path
  local redo_metadata group_no thread_no status archived member_type member
  manifest_append "planned_action_count" "${#ACTION_KINDS[@]}"
  action_no=1
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    detail="${ACTION_DETAILS[$idx]}"
    manifest_append "action_${action_no}_kind" "$kind"
    manifest_append "action_${action_no}_target" "$target"
    manifest_append "action_${action_no}_detail" "$detail"

    if [[ "$kind" == "fs_rename" || "$kind" == fs_corrupt_* || "$kind" == "external" ]]; then
      metadata="$(datafile_metadata_for_path "$target" || true)"
      if [[ -n "$metadata" ]]; then
        IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$metadata"
        manifest_append "action_${action_no}_pdb_name" "$pdb_name"
        manifest_append "action_${action_no}_con_id" "$con_id"
        manifest_append "action_${action_no}_file_no" "$file_no"
        manifest_append "action_${action_no}_tablespace" "$tablespace"
        manifest_append "action_${action_no}_datafile" "$path"
      fi

      redo_metadata="$(redo_metadata_for_path "$target" || true)"
      if [[ -n "$redo_metadata" ]]; then
        IFS='|' read -r group_no thread_no status archived member_type member <<<"$redo_metadata"
        manifest_append "action_${action_no}_redo_group" "$group_no"
        manifest_append "action_${action_no}_redo_thread" "$thread_no"
        manifest_append "action_${action_no}_redo_status" "$status"
        manifest_append "action_${action_no}_redo_archived" "$archived"
        manifest_append "action_${action_no}_redo_type" "$member_type"
        manifest_append "action_${action_no}_redo_member" "$member"
      fi
    fi

    action_no=$((action_no + 1))
  done
}

collect_datafile_plan() {
  reset_plan_targets

  local idx kind target metadata pdb_name con_id file_no tablespace path target_no
  target_no=1
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    case "$kind" in
      fs_rename|external)
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

  sql_query "$db_file" "
select name || '|' ||
       db_unique_name || '|' ||
       database_role || '|' ||
       open_mode || '|' ||
       cdb || '|' ||
       protection_mode || '|' ||
       switchover_status
from v\$database;
"
  local db_line
  db_line="$(trim_blank_lines <"$db_file" | head -n 1)"
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

  if command -v srvctl >/dev/null 2>&1; then
    local srvctl_config srvctl_type
    srvctl_config="$(srvctl config database -d "$DB_UNIQUE_NAME" 2>/dev/null || true)"
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
        if command -v crsctl >/dev/null 2>&1; then
          CLUSTER_TYPE="GI_SINGLE"
        else
          CLUSTER_TYPE="SINGLE"
        fi
        ;;
      "")
        if [[ "$INSTANCE_PARALLEL" == "YES" ]]; then
          CLUSTER_TYPE="RAC"
        elif [[ "$GI_MANAGED" -eq 1 || -x "${ORACLE_HOME:-}/bin/srvctl" ]]; then
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
  elif command -v crsctl >/dev/null 2>&1; then
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
  if [[ "$SPFILE_PATH" == +* || "$FRA_PATH" == +* ]]; then
    STORAGE_TYPE="ASM"
  elif trim_blank_lines <"$file" | grep -Eq '^[[:space:]]*[+]'; then
    STORAGE_TYPE="ASM"
  else
    STORAGE_TYPE="FILESYSTEM"
  fi
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

register_scenario() {
  local id="$1"
  local title="$2"
  local group="$3"
  local scope="$4"
  local impact="$5"
  local requires="$6"
  local handler="$7"
  local notes="$8"
  SCENARIO_IDS+=("$id")
  SCENARIO_TITLE["$id"]="$title"
  SCENARIO_GROUP["$id"]="$group"
  SCENARIO_SCOPE["$id"]="$scope"
  SCENARIO_IMPACT["$id"]="$impact"
  SCENARIO_REQUIRES["$id"]="$requires"
  SCENARIO_HANDLER["$id"]="$handler"
  SCENARIO_NOTES["$id"]="$notes"
}

register_scenarios() {
  register_scenario "1"  "Loss of one control file"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_control_one"       "Renames one control file and optionally aborts the target instance."
  register_scenario "2"  "Loss of all control files"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_control_all"       "Renames all control files and optionally aborts the target instance."
  register_scenario "3"  "Loss of one member from current redo group"         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_redo_member_one"   "Targets one member of the current redo group."
  register_scenario "4"  "Loss of all members from current redo group"        "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_current_redo_all"  "Targets all members of the current redo group."
  register_scenario "5"  "Loss of one non-system datafile"                   "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_non_system_one"    "Does not assume USERS exists."
  register_scenario "6"  "Loss of one temporary file"                        "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_temp_one"          "Targets a database temporary file."
  register_scenario "7"  "Loss of one SYSTEM datafile"                       "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_system_one"        "High-impact SYSTEM datafile scenario."
  register_scenario "8"  "Loss of one UNDO datafile"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_undo_one"          "Targets an online UNDO tablespace file."
  register_scenario "9"  "Loss of a read-only tablespace"                    "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_readonly_tbs"      "Targets all files in one read-only tablespace."
  register_scenario "10" "Loss of an index-only tablespace"                  "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_indexonly_tbs"     "Targets a tablespace with indexes and no tables."
  register_scenario "11" "Drop non-unique indexes outside Oracle schemas"     "Logical"    "CDB/non-CDB" "logical"      "primary"           "scenario_drop_indexes"      "Logical object loss for rebuild practice."
  register_scenario "12" "Loss of a non-system tablespace"                   "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_non_system_tbs"    "Targets all files in one non-system permanent tablespace."
  register_scenario "13" "Loss of a temporary tablespace"                    "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_temp_tbs"          "Targets all files in one temporary tablespace."
  register_scenario "14" "Loss of SYSTEM tablespace"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_system_tbs"        "Targets all SYSTEM datafiles."
  register_scenario "15" "Loss of UNDO tablespace"                           "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_undo_tbs"          "Targets all files in one UNDO tablespace."
  register_scenario "16" "Loss of password file"                             "Config"     "CDB/non-CDB" "destructive" "primary"           "scenario_password_file"     "Uses srvctl metadata where available; falls back to ORACLE_HOME/dbs."
  register_scenario "17" "Loss of all datafiles"                             "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_all_datafiles"     "Very high-impact full database restore practice."
  register_scenario "18" "Loss of one member from multiplexed redo group"     "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_redo_member_one"   "Requires a group with more than one member."
  register_scenario "19" "Loss of all inactive redo groups"                  "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_inactive_redo_all" "Targets inactive redo groups."
  register_scenario "20" "Loss of all active redo groups"                    "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_active_redo_all"   "Switches logfile first, then targets active groups."
  register_scenario "21" "Loss of all current redo group members"            "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_current_redo_all"  "Targets current redo group members."
  register_scenario "22" "Datafile header corruption"                        "Corrupt"    "CDB/non-CDB" "destructive" "primary"           "scenario_file_header_corrupt" "Overwrites one block in a SYSTEM datafile."
  register_scenario "23" "Control file corruption"                           "Corrupt"    "CDB/non-CDB" "destructive" "primary"           "scenario_control_corrupt"   "Overwrites bytes in all control files."
  register_scenario "24" "Redo log corruption"                               "Corrupt"    "CDB/non-CDB" "destructive" "primary"           "scenario_redo_corrupt"      "Overwrites bytes in active redo members."
  register_scenario "25" "Loss of RMAN backup pieces"                        "Backup"     "CDB/non-CDB" "destructive" "any"               "scenario_rman_backups"      "Targets backup pieces known in V\$BACKUP_PIECE."
  register_scenario "26" "Loss of SPFILE"                                    "Config"     "CDB/non-CDB" "destructive" "primary"           "scenario_spfile"            "Targets the active SPFILE."
  register_scenario "27" "Loss of SQL*Net config files"                      "Config"     "CDB/non-CDB" "destructive" "any"               "scenario_sqlnet"            "Targets listener.ora, tnsnames.ora, sqlnet.ora if present."
  register_scenario "28" "Loss of ORACLE_HOME"                               "Config"     "CDB/non-CDB" "destructive" "any"               "scenario_oracle_home"       "Renames ORACLE_HOME; lab only."
  register_scenario "29" "Loss of FRA destination"                           "Backup"     "CDB/non-CDB" "destructive" "primary"           "scenario_fra"               "Renames configured FRA destination."
  register_scenario "30" "PDB loss of one non-system datafile"               "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_non_system_one" "Requires --pdb."
  register_scenario "31" "PDB loss of one temporary file"                    "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_temp_one"      "Requires --pdb."
  register_scenario "32" "PDB loss of one SYSTEM datafile"                   "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_system_one"    "Requires --pdb."
  register_scenario "33" "PDB loss of one UNDO datafile"                     "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_undo_one"      "Requires local undo and --pdb."
  register_scenario "34" "PDB loss of read-only tablespace"                  "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_readonly_tbs"  "Requires --pdb."
  register_scenario "35" "PDB loss of index-only tablespace"                 "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_indexonly_tbs" "Requires --pdb."
  register_scenario "36" "PDB drop non-unique indexes"                       "PDB"        "PDB"        "logical"      "cdb,pdb,primary"   "scenario_pdb_drop_indexes"  "Requires --pdb."
  register_scenario "37" "PDB loss of non-system tablespace"                 "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_non_system_tbs" "Requires --pdb."
  register_scenario "38" "PDB loss of temporary tablespace"                  "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_temp_tbs"      "Requires --pdb."
  register_scenario "39" "PDB loss of SYSTEM tablespace"                     "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_system_tbs"    "Requires --pdb."
  register_scenario "40" "PDB loss of UNDO tablespace"                       "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_undo_tbs"      "Requires --pdb."
  register_scenario "41" "PDB loss of all datafiles"                         "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_all_datafiles" "Requires --pdb."
  register_scenario "42" "PDB SYSTEM file header corruption"                 "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_file_header_corrupt" "Requires --pdb."
  register_scenario "43" "PDB loss of one user table"                        "PDB"        "PDB"        "logical"      "cdb,pdb,primary"   "scenario_pdb_drop_table"    "Requires --pdb."
  register_scenario "44" "PDB loss of one user schema"                       "PDB"        "PDB"        "logical"      "cdb,pdb,primary"   "scenario_pdb_drop_schema"   "Requires --pdb."
  register_scenario "45" "Drop selected PDB including datafiles"             "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_drop_pdb"          "Requires --pdb."
  register_scenario "46" "ASM data disk group unavailable"                   "ASM"        "ASM"        "destructive" "asm"               "scenario_asm_diskgroup_unavailable" "Plans ASM disk group outage practice; execution requires an ASM-aware handler."
  register_scenario "47" "OCR loss or restore drill"                         "GI"         "Cluster"    "destructive" "gi"                "scenario_ocr_restore_drill" "Plans OCR backup/restore practice; execution requires root/Grid procedure approval."
  register_scenario "48" "Voting disk loss or restore drill"                 "GI"         "Cluster"    "destructive" "gi"                "scenario_voting_disk_drill" "Plans voting disk replacement practice; execution requires root/Grid procedure approval."
  register_scenario "49" "ASM SPFILE loss"                                   "ASM"        "ASM"        "destructive" "asm"               "scenario_asm_spfile_loss"   "Plans ASM SPFILE loss practice; execution requires an ASM-aware handler."
  register_scenario "50" "Standby managed recovery cancelled"                "DataGuard"  "Standby"    "logical"      "standby"           "scenario_standby_apply_cancel" "For physical standby apply practice."
  register_scenario "51" "Primary transport destination deferred"            "DataGuard"  "Primary"    "logical"      "primary,dg"        "scenario_primary_transport_defer" "Defers the first remote archive destination."
  register_scenario "52" "Data Guard broker configuration unavailable"       "DataGuard"  "DG"         "logical"      "dg"                "scenario_planned"           "Gated for a broker-enabled DG environment."
  register_scenario "53" "Active Data Guard read-only session pressure"      "ADG"        "Standby"    "logical"      "standby"           "scenario_planned"           "Gated for Active Data Guard."
  register_scenario "54" "Snapshot standby conversion practice"              "DataGuard"  "Standby"    "logical"      "standby"           "scenario_planned"           "Gated for a DG test environment."
  register_scenario "55" "RAC abort one instance"                            "RAC"        "RAC"        "destructive" "rac"               "scenario_rac_abort_instance" "Uses srvctl where available."
  register_scenario "56" "RAC service relocation failure practice"           "RAC"        "RAC"        "logical"      "rac"               "scenario_planned"           "Gated for RAC."
  register_scenario "57" "Listener config unavailable"                       "Network"    "CDB/non-CDB" "destructive" "any"               "scenario_sqlnet"            "Alias for network file loss."
  register_scenario "58" "TDE wallet or keystore unavailable"                "Security"   "CDB/non-CDB" "destructive" "primary"           "scenario_tde_wallet"        "Renames detected wallet root if configured."
  register_scenario "59" "Missing archived redo log"                         "Backup"     "CDB/non-CDB" "destructive" "primary"           "scenario_archivelog_loss"   "Targets one archived log known to the control file."
  register_scenario "60" "Recovery catalog unavailable"                      "Backup"     "External"   "logical"      "any"               "scenario_recovery_catalog_unavailable" "Validates catalog connectivity and NOCATALOG fallback behavior."
}

list_scenarios() {
  printf "%-4s %-12s %-13s %-12s %s\n" "ID" "Group" "Scope" "Impact" "Scenario"
  printf "%-4s %-12s %-13s %-12s %s\n" "--" "-----" "-----" "------" "--------"
  local id
  for id in "${SCENARIO_IDS[@]}"; do
    printf "%-4s %-12s %-13s %-12s %s\n" \
      "$id" \
      "${SCENARIO_GROUP[$id]}" \
      "${SCENARIO_SCOPE[$id]}" \
      "${SCENARIO_IMPACT[$id]}" \
      "${SCENARIO_TITLE[$id]}"
  done
}

scenario_exists() {
  local id="$1"
  [[ -n "${SCENARIO_TITLE[$id]:-}" ]]
}

pdb_exists() {
  local pdb="$1"
  local row name con_id open_mode
  for row in "${PDB_ROWS[@]}"; do
    IFS='|' read -r name con_id open_mode <<<"$row"
    if [[ "$name" == "$pdb" ]]; then
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

pdb_list_for_message() {
  local row name con_id open_mode
  for row in "${PDB_ROWS[@]}"; do
    IFS='|' read -r name con_id open_mode <<<"$row"
    printf "%s " "$name"
  done
}

select_pdb_if_needed() {
  if [[ "$DB_CDB" != "YES" ]]; then
    return "$FAIL"
  fi
  if [[ -n "$TARGET_PDB" ]]; then
    pdb_exists "$TARGET_PDB" ||
      die "PDB ${TARGET_PDB} was not found in this CDB. Available PDBs: $(pdb_list_for_message)"
    return "$SUCCESS"
  fi
  if [[ "${#PDB_ROWS[@]}" -eq 1 ]]; then
    TARGET_PDB="$(printf "%s" "${PDB_ROWS[0]}" | cut -d'|' -f1)"
    info "Using only available PDB: $TARGET_PDB"
    return "$SUCCESS"
  fi
  die "This scenario requires --pdb. Available PDBs: $(printf "%s " "${PDB_ROWS[@]}" | cut -d'|' -f1)"
}

check_requirements() {
  local id="$1"
  local requires="${SCENARIO_REQUIRES[$id]}"
  discover_environment

  IFS=',' read -ra reqs <<<"$requires"
  local req
  for req in "${reqs[@]}"; do
    case "$req" in
      any|"") ;;
      primary)
        [[ "$DB_ROLE" == "PRIMARY" ]] || die "Scenario $id requires PRIMARY role. Current role: $DB_ROLE"
        ;;
      standby)
        [[ "$DB_ROLE" == *"STANDBY"* ]] || die "Scenario $id requires a standby role. Current role: $DB_ROLE"
        ;;
      dg)
        has_data_guard || die "Scenario $id requires Data Guard metadata."
        ;;
      cdb)
        [[ "$DB_CDB" == "YES" ]] || die "Scenario $id requires a CDB."
        ;;
      pdb)
        select_pdb_if_needed
        ;;
      rac)
        [[ "$INSTANCE_PARALLEL" == "YES" ||
           "$CLUSTER_TYPE" == "RAC" ||
           "$CLUSTER_TYPE" == "RACONE" ||
           "$CLUSTER_TYPE" == "RACONENODE" ||
           "$CLUSTER_TYPE" == "RAC_ONE_NODE" ||
           "$CLUSTER_TYPE" == "GI_SINGLE" ]] || die "Scenario $id requires RAC, RAC One Node, or a GI-managed database."
        ;;
      asm)
        [[ "$STORAGE_TYPE" == "ASM" ]] || die "Scenario $id requires ASM storage."
        ;;
      gi)
        command -v crsctl >/dev/null 2>&1 || die "Scenario $id requires Grid Infrastructure commands."
        ;;
      *)
        die "Unknown requirement '$req' for scenario $id"
        ;;
    esac
  done
}

scenario_is_topology_compatible() {
  local id="$1"
  local requires="${SCENARIO_REQUIRES[$id]}"
  local handler="${SCENARIO_HANDLER[$id]}"
  local req
  local -a reqs

  scenario_exists "$id" || return "$FAIL"
  [[ "$handler" != "scenario_planned" ]] || return "$FAIL"
  case "$id" in
    25)
      [[ -n "$PIECE_HANDLE" || ( "$LOCAL_ONLY" == "1" && -n "$MAX_TARGETS" ) ]] || return "$FAIL"
      ;;
  esac

  IFS=',' read -ra reqs <<<"$requires"
  for req in "${reqs[@]}"; do
    case "$req" in
      any|"") ;;
      primary)
        [[ "$DB_ROLE" == "PRIMARY" ]] || return "$FAIL"
        ;;
      standby)
        [[ "$DB_ROLE" == *"STANDBY"* ]] || return "$FAIL"
        ;;
      dg)
        has_data_guard || return "$FAIL"
        ;;
      cdb)
        [[ "$DB_CDB" == "YES" ]] || return "$FAIL"
        ;;
      pdb)
        [[ "$DB_CDB" == "YES" ]] || return "$FAIL"
        [[ -n "$TARGET_PDB" || "${#PDB_ROWS[@]}" -eq 1 ]] || return "$FAIL"
        ;;
      rac)
        [[ "$INSTANCE_PARALLEL" == "YES" ||
           "$CLUSTER_TYPE" == "RAC" ||
           "$CLUSTER_TYPE" == "RACONE" ||
           "$CLUSTER_TYPE" == "RACONENODE" ||
           "$CLUSTER_TYPE" == "RAC_ONE_NODE" ||
           "$CLUSTER_TYPE" == "GI_SINGLE" ]] || return "$FAIL"
        ;;
      asm)
        [[ "$STORAGE_TYPE" == "ASM" ]] || return "$FAIL"
        ;;
      gi)
        command -v crsctl >/dev/null 2>&1 || return "$FAIL"
        ;;
      *)
        return "$FAIL"
        ;;
    esac
  done
}

scenario_can_plan_randomly() {
  local id="$1"
  validate_scenario_can_run "$id" >/dev/null 2>&1
}

select_random_scenario() {
  discover_environment

  local candidates=()
  local all_candidates=()
  local id candidate_count index selected=""
  for id in "${SCENARIO_IDS[@]}"; do
    if scenario_is_topology_compatible "$id"; then
      candidates+=("$id")
    fi
  done
  all_candidates=("${candidates[@]}")

  candidate_count="${#candidates[@]}"
  [[ "$candidate_count" -gt 0 ]] ||
    die "No topology-compatible implemented scenarios were found for this environment."

  while [[ "${#candidates[@]}" -gt 0 ]]; do
    index=$((RANDOM % ${#candidates[@]}))
    id="${candidates[$index]}"
    candidates=("${candidates[@]:0:$index}" "${candidates[@]:$((index + 1))}")
    if scenario_can_plan_randomly "$id"; then
      selected="$id"
      break
    fi
  done

  [[ -n "$selected" ]] ||
    die "No topology-compatible scenarios could plan usable targets in this environment."

  SCENARIO_ID="$selected"

  echo "Aleatory scenario selected from ${candidate_count} topology-compatible scenarios after target planning checks:"
  echo "  ${SCENARIO_ID}: ${SCENARIO_TITLE[$SCENARIO_ID]}"
  echo "Topology: role=${DB_ROLE:-unknown}, cdb=${DB_CDB:-unknown}, storage=${STORAGE_TYPE:-unknown}, cluster=${CLUSTER_TYPE:-unknown}"
  if [[ -n "$TARGET_PDB" ]]; then
    echo "PDB target context: ${TARGET_PDB}"
  elif [[ "${SCENARIO_REQUIRES[$SCENARIO_ID]}" == *pdb* && "${#PDB_ROWS[@]}" -eq 1 ]]; then
    echo "PDB target context: only available PDB will be selected by requirement checks"
  fi
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "Candidate IDs: ${all_candidates[*]}"
  fi
  echo
}

run_random_scenario() {
  select_random_scenario
  run_scenario "$SCENARIO_ID"
}

has_data_guard() {
  if [[ "$DB_ROLE" != "PRIMARY" ]]; then
    return "$SUCCESS"
  fi
  local dg_file="$WORK_DIR/dg.env"
  sql_query "$dg_file" "
select count(*)
from v\$archive_dest
where target = 'STANDBY'
  and status <> 'INACTIVE';
"
  local count
  count="$(trim_blank_lines <"$dg_file" | head -n 1 | tr -d ' ')"
  [[ "${count:-0}" =~ ^[0-9]+$ && "${count:-0}" -gt 0 ]]
}

confirm_execution() {
  local id="$1"
  if [[ "$EXECUTE" -eq 0 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  echo
  echo "About to execute scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Database: ${DB_UNIQUE_NAME} (${DB_ROLE}, ${DB_OPEN_MODE})"
  if [[ -n "$TARGET_PDB" ]]; then
    echo "PDB: ${TARGET_PDB}"
  fi
  if [[ -n "$TARGET_SCHEMA" ]]; then
    echo "Schema: ${TARGET_SCHEMA}"
  fi
  echo "Type EXECUTE-${id} to continue:"
  local answer
  read -r answer
  [[ "$answer" == "EXECUTE-${id}" ]] || die "Confirmation did not match. Aborting."
}

run_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"

  if validate_scenario_can_run "$id"; then
    echo "Validation: RUNNABLE - ${SCENARIO_VALIDATION_REASON}"
    echo
  else
    echo "Validation: NOT RUNNABLE"
    echo "Scenario ${id} is not possible to run at this moment."
    echo "Reason: ${SCENARIO_VALIDATION_REASON}"
    if [[ "$EXECUTE" -eq 1 || "$SCENARIO_VALIDATION_STATUS" != "PLAN_ONLY" ]]; then
      return "$FAIL"
    fi
    echo "Continuing with dry-run planning only; execution will remain blocked until the validation blocker is resolved."
    echo
  fi

  check_requirements "$id"
  CURRENT_SCENARIO_ID="$id"
  RENAME_COUNT=0
  init_manifest "scenario" "$id"

  echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Group: ${SCENARIO_GROUP[$id]}"
  echo "Scope: ${SCENARIO_SCOPE[$id]}"
  echo "Impact: ${SCENARIO_IMPACT[$id]}"
  echo "Requires: ${SCENARIO_REQUIRES[$id]}"
  echo "Notes: ${SCENARIO_NOTES[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Manifest: ${MANIFEST_FILE}"
  echo

  print_recovery_runbook "$id"
  echo

  confirm_execution "$id"

  local handler="${SCENARIO_HANDLER[$id]}"
  "$handler" "$id"
}

confirm_mode_execution() {
  local mode_name="$1"
  local id="$2"
  local token
  token="${mode_name}-${id}"

  if [[ "$EXECUTE" -eq 0 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  echo
  echo "About to execute ${mode_name,,} for scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Database: ${DB_UNIQUE_NAME:-unknown} (${DB_ROLE:-unknown}, ${DB_OPEN_MODE:-unknown})"
  if [[ -n "$TARGET_PDB" ]]; then
    echo "PDB: ${TARGET_PDB}"
  fi
  echo "Type ${token} to continue:"
  local answer
  read -r answer
  [[ "$answer" == "$token" ]] || die "Confirmation did not match. Aborting."
}

supports_file_recovery_automation() {
  local id="$1"
  case "$id" in
    5|7|14|17|30|32|39|41) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

supports_recovery_automation() {
  local id="$1"
  case "$id" in
    1|2|3|4|5|6|7|14|16|17|18|19|20|21|23|24|25|26|30|31|32|39|41|55|59) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

plan_scenario_actions() {
  local id="$1"
  local handler old_execute old_planning

  check_requirements "$id"
  handler="${SCENARIO_HANDLER[$id]}"
  old_execute="$EXECUTE"
  old_planning="$PLANNING_ONLY"
  EXECUTE=0
  PLANNING_ONLY=1
  "$handler" "$id"
  EXECUTE="$old_execute"
  PLANNING_ONLY="$old_planning"
}

validation_reason_from_output() {
  local output="$1"
  local reason
  reason="$(printf "%s\n" "$output" | awk '
    /^[[:space:]]*$/ {next}
    {last=$0}
    END {print last}
  ')"
  reason="${reason#ERROR: }"
  reason="${reason#WARN: }"
  [[ -n "$reason" ]] || reason="Scenario target validation did not produce a runnable target."
  printf "%s" "$reason"
}

validation_single_line() {
  tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

validation_external_reason() {
  local output="$1"
  local line detail
  line="$(printf "%s\n" "$output" | grep -E '^[[:space:]]*[0-9]+\. external[[:space:]]+' | head -n 1 || true)"
  [[ -n "$line" ]] || return "$FAIL"
  detail="$(printf "%s" "$line" | sed -E 's/^[[:space:]]*[0-9]+\. external[[:space:]]+//')"
  printf "Selected target requires a provider-specific or manual handler before safe execution: %s" "$detail"
}

validation_missing_fs_target_reason() {
  local output="$1"
  local target
  while IFS= read -r target; do
    target="${target%% (*}"
    if [[ -n "$target" && "$target" == /* && ! -e "$target" ]]; then
      printf "Selected filesystem target does not exist or is not visible to this OS user: %s" "$target"
      return "$SUCCESS"
    fi
  done < <(printf "%s\n" "$output" |
    sed -nE 's/^[[:space:]]*[0-9]+\. (fs_rename|fs_corrupt_header|fs_corrupt_body)[[:space:]]+(.+)$/\2/p')
  return "$FAIL"
}

validation_missing_tool_reason() {
  local output="$1"
  if printf "%s\n" "$output" | grep -Eq '^[[:space:]]*[0-9]+\. srvctl_'; then
    if ! command -v srvctl >/dev/null 2>&1; then
      printf "Selected action requires srvctl, but srvctl was not found in PATH."
      return "$SUCCESS"
    fi
  fi
  return "$FAIL"
}

validation_guardrail_reason() {
  local id="$1"
  case "$id" in
    25)
      if [[ -z "$PIECE_HANDLE" ]]; then
        if [[ "$LOCAL_ONLY" != "1" || -z "$MAX_TARGETS" ]]; then
          printf "Scenario 25 can see local and object-storage backup handles; execution requires --piece-handle or --local-only --max-targets <n>."
          return "$SUCCESS"
        fi
      fi
      ;;
  esac
  return "$FAIL"
}

validate_scenario_can_run() {
  local id="$1"
  local req_output req_status plan_output plan_status reason

  SCENARIO_VALIDATION_STATUS="NOT_RUNNABLE"
  SCENARIO_VALIDATION_REASON=""
  SCENARIO_VALIDATION_OUTPUT=""

  if ! scenario_exists "$id"; then
    SCENARIO_VALIDATION_REASON="Unknown scenario id: $id"
    return "$FAIL"
  fi

  req_output="$( (check_requirements "$id") 2>&1 )"
  req_status=$?
  if [[ "$req_status" -ne 0 ]]; then
    SCENARIO_VALIDATION_OUTPUT="$req_output"
    SCENARIO_VALIDATION_REASON="$(validation_reason_from_output "$req_output")"
    return "$FAIL"
  fi

  if [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]]; then
    SCENARIO_VALIDATION_REASON="Scenario $id is registered as a placeholder for ${SCENARIO_SCOPE[$id]} testing, but a runnable handler is not implemented yet."
    return "$FAIL"
  fi

  if reason="$(validation_guardrail_reason "$id")"; then
    SCENARIO_VALIDATION_STATUS="PLAN_ONLY"
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  plan_output="$( (
    EXECUTE=0
    ASSUME_YES=1
    PLANNING_ONLY=1
    MANIFEST_FILE=""
    MANIFEST_FROM_ARG=0
    CURRENT_SCENARIO_ID="$id"
    RENAME_COUNT=0
    reset_actions
    plan_scenario_actions "$id"
  ) 2>&1)"
  plan_status=$?
  SCENARIO_VALIDATION_OUTPUT="$plan_output"
  if [[ "$plan_status" -ne 0 ]]; then
    SCENARIO_VALIDATION_REASON="$(validation_reason_from_output "$plan_output")"
    return "$FAIL"
  fi

  if reason="$(validation_external_reason "$plan_output")"; then
    SCENARIO_VALIDATION_STATUS="PLAN_ONLY"
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  if reason="$(validation_missing_fs_target_reason "$plan_output")"; then
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  if reason="$(validation_missing_tool_reason "$plan_output")"; then
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  SCENARIO_VALIDATION_STATUS="RUNNABLE"
  SCENARIO_VALIDATION_REASON="Requirements passed and target selection produced executable actions."
  return "$SUCCESS"
}

print_scenario_validation() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"

  echo "Scenario readiness validation"
  echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Group: ${SCENARIO_GROUP[$id]}"
  echo "Scope: ${SCENARIO_SCOPE[$id]}"
  echo "Impact: ${SCENARIO_IMPACT[$id]}"
  echo "Requires: ${SCENARIO_REQUIRES[$id]}"
  echo

  if validate_scenario_can_run "$id"; then
    echo "Result: RUNNABLE"
    echo "Reason: ${SCENARIO_VALIDATION_REASON}"
    if [[ "$VERBOSE" -eq 1 && -n "$SCENARIO_VALIDATION_OUTPUT" ]]; then
      echo
      echo "Validation planning output:"
      printf "%s\n" "$SCENARIO_VALIDATION_OUTPUT"
    fi
    return "$SUCCESS"
  fi

  if [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
    echo "Result: NOT RUNNABLE (dry-run planning only)"
  else
    echo "Result: NOT RUNNABLE"
  fi
  echo "Scenario ${id} is not possible to run at this moment."
  echo "Reason: ${SCENARIO_VALIDATION_REASON}"
  if [[ "$VERBOSE" -eq 1 && -n "$SCENARIO_VALIDATION_OUTPUT" ]]; then
    echo
    echo "Validation planning output:"
    printf "%s\n" "$SCENARIO_VALIDATION_OUTPUT"
  fi
  return "$FAIL"
}

validate_all_scenarios() {
  local id status reason runnable_count=0 blocked_count=0

  discover_environment

  printf "%-4s %-12s %s\n" "ID" "Status" "Reason"
  printf "%-4s %-12s %s\n" "--" "------" "------"
  for id in "${SCENARIO_IDS[@]}"; do
    if validate_scenario_can_run "$id"; then
      status="RUNNABLE"
      reason="$SCENARIO_VALIDATION_REASON"
      runnable_count=$((runnable_count + 1))
    else
      if [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
        status="PLAN-ONLY"
      else
        status="NOT-RUNNABLE"
      fi
      reason="$SCENARIO_VALIDATION_REASON"
      blocked_count=$((blocked_count + 1))
    fi
    reason="$(printf "%s" "$reason" | validation_single_line)"
    printf "%-4s %-12s %s\n" "$id" "$status" "$reason"
  done
  echo
  echo "Runnable scenarios: ${runnable_count}"
  echo "Not runnable at this moment: ${blocked_count}"
}

write_protect_rman_file() {
  local id="$1"
  local cmd_file="$2"
  local tag="$3"
  local file_list
  file_list="$(join_csv "${PLAN_TARGET_FILE_NOS[@]}")"

  {
    printf "run {\n"
    printf "  sql \"alter system archive log current\";\n"
    printf "  backup as compressed backupset datafile %s tag '%s';\n" "$file_list" "$tag"
    printf "  backup current controlfile tag '%s_CTL';\n" "$tag"
    printf "}\n"
    printf "list backup tag '%s';\n" "$tag"
    printf "list backup tag '%s_CTL';\n" "$tag"
  } >"$cmd_file" || die "Unable to write RMAN command file: $cmd_file"

  manifest_append "protect_rman_cmdfile" "$cmd_file"
  manifest_append "backup_tag" "$tag"
}

protect_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_file_recovery_automation "$id" ||
    die "Automated RMAN protection currently supports datafile scenarios 5, 7, 14, 17, 30, 32, 39, and 41. Use --runbook $id for manual guidance."

  check_requirements "$id"
  CURRENT_SCENARIO_ID="$id"
  init_manifest "protect" "$id"

  echo "Protect scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  plan_scenario_actions "$id"
  collect_datafile_plan

  local tag cmd_file log_file
  tag="$(rman_tag "$id")"
  cmd_file="${LOG_DIR}/crashsim_protect_s${id}_${RUN_ID}.rman"
  log_file="${LOG_DIR}/crashsim_protect_s${id}_${RUN_ID}.log"
  write_protect_rman_file "$id" "$cmd_file" "$tag"

  echo
  echo "Protection target datafiles:"
  local idx
  for idx in "${!PLAN_TARGET_FILE_NOS[@]}"; do
    printf "  FILE# %-5s %-12s %-16s %s\n" \
      "${PLAN_TARGET_FILE_NOS[$idx]}" \
      "${PLAN_TARGET_PDBS[$idx]}" \
      "${PLAN_TARGET_TABLESPACES[$idx]}" \
      "${PLAN_TARGET_PATHS[$idx]}"
  done
  echo "Backup tag: ${tag}"
  echo

  confirm_mode_execution "PROTECT" "$id"
  run_rman_cmdfile "$cmd_file" "$log_file"
  manifest_append "protect_rman_log" "$log_file"
}

write_recover_rman_file() {
  local id="$1"
  local file_no="$2"
  local cmd_file="$3"

  {
    printf "startup force mount;\n"
    printf "restore datafile %s;\n" "$file_no"
    printf "recover datafile %s;\n" "$file_no"
    printf "sql \"alter database open\";\n"
  } >"$cmd_file" || die "Unable to write RMAN recovery command file: $cmd_file"

  manifest_append "recover_rman_cmdfile" "$cmd_file"
}

write_recover_datafile_list_rman_file() {
  local file_list="$1"
  local cmd_file="$2"

  {
    printf "startup force mount;\n"
    printf "restore datafile %s;\n" "$file_list"
    printf "recover datafile %s;\n" "$file_list"
    printf "sql \"alter database open\";\n"
  } >"$cmd_file" || die "Unable to write RMAN datafile-list recovery file: $cmd_file"

  manifest_append "recover_rman_cmdfile" "$cmd_file"
}

write_recover_pdb_datafile_rman_file() {
  local file_list="$1"
  local cmd_file="$2"

  {
    printf "restore datafile %s;\n" "$file_list"
    printf "recover datafile %s;\n" "$file_list"
  } >"$cmd_file" || die "Unable to write RMAN PDB datafile recovery file: $cmd_file"

  manifest_append "recover_rman_cmdfile" "$cmd_file"
}

write_validate_datafile_list_rman_file() {
  local file_list="$1"
  local cmd_file="$2"

  {
    printf "backup validate datafile %s;\n" "$file_list"
    printf "list failure;\n"
  } >"$cmd_file" || die "Unable to write RMAN datafile-list validation file: $cmd_file"
}

write_controlfile_validate_rman_file() {
  local cmd_file="$1"

  {
    printf "validate current controlfile;\n"
    printf "list failure;\n"
  } >"$cmd_file" || die "Unable to write control-file validation RMAN file: $cmd_file"
}

write_redo_validation_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write redo validation SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
select group#, thread#, sequence#, bytes, blocksize, members, archived, status
from v$log
order by thread#, group#;
select group#, type, status, member
from v$logfile
order by group#, member;
alter system switch logfile;
select group#, thread#, sequence#, archived, status
from v$log
order by thread#, group#;
exit
SQL
}

write_redo_validation_rman_file() {
  local cmd_file="$1"

  {
    printf "run {\n"
    printf "  allocate channel csimv1 device type disk;\n"
    printf "  backup validate database;\n"
    printf "  release channel csimv1;\n"
    printf "}\n"
    printf "list failure;\n"
  } >"$cmd_file" || die "Unable to write redo RMAN validation file: $cmd_file"
}

redo_replacement_diskgroup() {
  local member="$1"
  case "$member" in
    +DATA/*|+DATA) printf "+DATA" ;;
    +RECO/*|+RECO) printf "+RECO" ;;
    +*)
      printf "%s" "$member" | awk -F/ '{print $1}'
      ;;
    *)
      return "$FAIL"
      ;;
  esac
}

write_asm_redo_recovery_sql_file() {
  local group_no="$1"
  local missing_member="$2"
  local diskgroup="$3"
  local sql_file="$4"
  local missing_literal diskgroup_literal
  missing_literal="$(sql_quote "$missing_member")"
  diskgroup_literal="$(sql_quote "$diskgroup")"

  cat >"$sql_file" <<SQL || die "Unable to write ASM redo recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
alter system switch logfile;
alter system switch logfile;
alter system checkpoint;
declare
  l_member varchar2(512) := ${missing_literal};
  l_count number;
begin
  select count(*)
    into l_count
    from v\$logfile
   where member = l_member;

  if l_count > 0 then
    execute immediate 'alter database drop logfile member ''' ||
      replace(l_member, '''', '''''') || '''';
  else
    dbms_output.put_line('Redo member is already absent from control-file metadata: ' || l_member);
  end if;
end;
/
alter database add logfile member ${diskgroup_literal} to group ${group_no};
alter system switch logfile;
select l.group#, l.thread#, l.sequence#, l.status, l.archived, count(lf.member) members
from v\$log l join v\$logfile lf on lf.group# = l.group#
group by l.group#, l.thread#, l.sequence#, l.status, l.archived
order by l.thread#, l.group#;
select lf.group#, l.status, lf.member
from v\$logfile lf join v\$log l on l.group# = lf.group#
order by lf.group#, lf.member;
exit
SQL
}

write_pdb_open_sql_file() {
  local pdb_name="$1"
  local sql_file="$2"

  cat >"$sql_file" <<SQL || die "Unable to write PDB open SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
declare
  l_open_mode v\$pdbs.open_mode%type;
begin
  select open_mode
    into l_open_mode
    from v\$pdbs
   where name = '${pdb_name}';

  if l_open_mode not in ('READ WRITE', 'READ ONLY', 'READ ONLY WITH APPLY') then
    execute immediate 'alter pluggable database ${pdb_name} open';
  else
    dbms_output.put_line('PDB ${pdb_name} already open: ' || l_open_mode);
  end if;
end;
/
exit
SQL

  manifest_append "recover_pdb_open_sqlfile" "$sql_file"
}

load_manifest_datafile_numbers() {
  RECOVER_FILE_NOS=()

  local idx file_no count seen
  local key_prefix count_key

  for key_prefix in action target; do
    case "$key_prefix" in
      action) count_key="planned_action_count" ;;
      target) count_key="target_count" ;;
    esac
    count="$(manifest_get "$count_key" || true)"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0

    idx=1
    while [[ "$idx" -le "$count" ]]; do
      file_no="$(manifest_get "${key_prefix}_${idx}_file_no" || true)"
      if [[ -n "$file_no" ]]; then
        [[ "$file_no" =~ ^[0-9]+$ ]] || die "Manifest has invalid FILE# for ${key_prefix}_${idx}: $file_no"
        seen=0
        local existing
        for existing in "${RECOVER_FILE_NOS[@]}"; do
          if [[ "$existing" == "$file_no" ]]; then
            seen=1
            break
          fi
        done
        [[ "$seen" -eq 1 ]] || RECOVER_FILE_NOS+=("$file_no")
      fi
      idx=$((idx + 1))
    done
  done

  if [[ "${#RECOVER_FILE_NOS[@]}" -eq 0 ]]; then
    file_no="$(manifest_first_value "recover_file_no" "target_1_file_no" "action_1_file_no" || true)"
    if [[ -n "$file_no" ]]; then
      [[ "$file_no" =~ ^[0-9]+$ ]] || die "Manifest has invalid FILE#: $file_no"
      seen=0
      local existing
      for existing in "${RECOVER_FILE_NOS[@]}"; do
        if [[ "$existing" == "$file_no" ]]; then
          seen=1
          break
        fi
      done
      [[ "$seen" -eq 1 ]] || RECOVER_FILE_NOS+=("$file_no")
    fi
  fi

  [[ "${#RECOVER_FILE_NOS[@]}" -gt 0 ]] || return "$FAIL"
}

scenario_uses_pdb_recovery() {
  local id="$1"
  case "$id" in
    30|32|39|41) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

recover_datafile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_file_recovery_automation "$id" ||
    die "Automated RMAN recovery currently supports scenarios 5 and 30. Use --runbook $id for manual guidance."

  CURRENT_SCENARIO_ID="$id"

  local file_no pdb_name existing_manifest created_manifest
  file_no="$TARGET_FILE_NO"
  pdb_name="$TARGET_PDB"
  existing_manifest=0
  created_manifest=0
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    existing_manifest=1
  fi

  if [[ -z "$file_no" && "$existing_manifest" -eq 1 ]]; then
    file_no="$(manifest_get "target_1_file_no" || true)"
    if [[ -z "$file_no" ]]; then
      file_no="$(manifest_get "action_1_file_no" || true)"
    fi
  fi
  if [[ "$id" == "30" && -z "$pdb_name" && "$existing_manifest" -eq 1 ]]; then
    pdb_name="$(manifest_get "target_1_pdb_name" || true)"
    if [[ -z "$pdb_name" ]]; then
      pdb_name="$(manifest_get "action_1_pdb_name" || true)"
    fi
  fi

  if [[ -z "$file_no" ]]; then
    warn "No --file-no or manifest file number was supplied; attempting live discovery."
    check_requirements "$id"
    if [[ "$existing_manifest" -eq 0 ]]; then
      init_manifest "recover" "$id"
      created_manifest=1
    fi
    plan_scenario_actions "$id"
    collect_datafile_plan
    file_no="${PLAN_TARGET_FILE_NOS[0]}"
    if [[ "$id" == "30" && -z "$pdb_name" ]]; then
      pdb_name="${PLAN_TARGET_PDBS[0]}"
    fi
  fi

  [[ -n "$file_no" && "$file_no" =~ ^[0-9]+$ ]] || die "Recovery requires a valid file number. Use --file-no <n> or --manifest <file>."

  if [[ "$id" == "30" ]]; then
    [[ -n "$pdb_name" ]] || die "Scenario 30 recovery requires --pdb <name> or a manifest with target_1_pdb_name."
    pdb_name="$(normalize_name "$pdb_name")"
    validate_oracle_name "$pdb_name" || die "Invalid PDB name: $pdb_name"
    TARGET_PDB="$pdb_name"
  fi

  if [[ "$existing_manifest" -eq 0 && "$created_manifest" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ "$existing_manifest" -eq 1 ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  local cmd_file log_file sql_file sql_log
  cmd_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}.rman"
  log_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}.log"
  if scenario_uses_pdb_recovery "$id"; then
    write_recover_pdb_datafile_rman_file "$file_no" "$cmd_file"
  else
    write_recover_rman_file "$id" "$file_no" "$cmd_file"
  fi
  manifest_append "recover_file_no" "$file_no"
  manifest_append "recover_rman_log" "$log_file"

  if [[ "$id" == "30" ]]; then
    sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_pdb.sql"
    sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_pdb.log"
    write_pdb_open_sql_file "$pdb_name" "$sql_file"
    manifest_append "recover_pdb_open_log" "$sql_log"
  fi

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "FILE#: ${file_no}"
  if [[ "$id" == "30" ]]; then
    echo "PDB: ${pdb_name}"
  fi
  if [[ -n "$MANIFEST_FILE" ]]; then
    echo "Manifest: ${MANIFEST_FILE}"
  fi
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  run_rman_cmdfile "$cmd_file" "$log_file"
  if [[ "$id" == "30" ]]; then
    run_sql_script_file "$sql_file" "$sql_log"
  fi
}

recover_datafile_list_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local file_list pdb_name cmd_file log_file validate_file validate_log sql_file sql_log has_restore_pairs
  load_manifest_datafile_numbers ||
    die "Manifest does not contain datafile FILE# metadata. Use a manifest from a scenario dry-run or executed run."
  file_list="$(join_csv "${RECOVER_FILE_NOS[@]}")"

  pdb_name="$TARGET_PDB"
  if scenario_uses_pdb_recovery "$id"; then
    if [[ -z "$pdb_name" ]]; then
      pdb_name="$(manifest_first_value "target_pdb" "action_1_pdb_name" || true)"
    fi
    [[ -n "$pdb_name" ]] || die "Scenario ${id} recovery requires --pdb or a manifest target PDB."
    pdb_name="$(normalize_name "$pdb_name")"
    validate_oracle_name "$pdb_name" || die "Invalid PDB name: $pdb_name"
    TARGET_PDB="$pdb_name"
  fi

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_file_list" "$file_list"

  cmd_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_datafiles.rman"
  log_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_datafiles.log"
  if scenario_uses_pdb_recovery "$id"; then
    write_recover_pdb_datafile_rman_file "$file_list" "$cmd_file"
  else
    write_recover_datafile_list_rman_file "$file_list" "$cmd_file"
  fi
  manifest_append "recover_rman_log" "$log_file"

  validate_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_datafiles.rman"
  validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_datafiles.log"
  write_validate_datafile_list_rman_file "$file_list" "$validate_file"
  manifest_append "recover_validate_rman_cmdfile" "$validate_file"
  manifest_append "recover_validate_rman_log" "$validate_log"

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_containers.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_containers.log"
  if scenario_uses_pdb_recovery "$id"; then
    write_pdb_open_sql_file "$pdb_name" "$sql_file"
  else
    write_open_pdbs_sql_file "$sql_file"
  fi
  manifest_append "recover_open_sqlfile" "$sql_file"
  manifest_append "recover_open_log" "$sql_log"

  has_restore_pairs=0
  if load_manifest_restore_pairs; then
    has_restore_pairs=1
  fi

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "FILE# list: ${file_list}"
  if scenario_uses_pdb_recovery "$id"; then
    echo "PDB: ${pdb_name}"
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  run_rman_cmdfile "$cmd_file" "$log_file"
  run_sql_script_file "$sql_file" "$sql_log"
  run_rman_cmdfile "$validate_file" "$validate_log"

  if [[ "$has_restore_pairs" -eq 1 ]]; then
    safe_remove_restore_backups
  fi
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_controlfile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local rman_file rman_log
  load_manifest_restore_pairs ||
    die "Manifest is missing control-file restore paths. Use a manifest from an executed scenario run."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_controlfile.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_controlfile.log"
  write_controlfile_validate_rman_file "$rman_file"
  manifest_append "recover_controlfile_validate_rman" "$rman_file"
  manifest_append "recover_controlfile_validate_log" "$rman_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Control file restore count: ${#RESTORE_ORIGINALS[@]}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  copy_restore_pairs_to_originals
  force_database_open
  run_rman_cmdfile "$rman_file" "$rman_log"

  safe_remove_restore_backups
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_redo_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local sql_file sql_log rman_file rman_log restore_pair_mode asm_redo_mode
  local redo_group redo_member redo_diskgroup
  restore_pair_mode=0
  asm_redo_mode=0
  if load_manifest_restore_pairs; then
    restore_pair_mode=1
  else
    redo_group="$(manifest_first_value "action_1_redo_group" "action_1_redo_group_no" || true)"
    redo_member="$(manifest_first_value "action_1_redo_member" "action_1_target" || true)"
    if [[ -n "$redo_group" && "$redo_group" =~ ^[0-9]+$ && "$redo_member" == +* ]]; then
      redo_diskgroup="$(redo_replacement_diskgroup "$redo_member" || true)"
      [[ -n "$redo_diskgroup" ]] || die "Unable to derive ASM disk group from redo member: $redo_member"
      asm_redo_mode=1
    else
      die "Manifest is missing redo restore paths or ASM redo metadata. Use a manifest from an executed scenario run."
    fi
  fi

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_redo.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_redo.log"
  if [[ "$asm_redo_mode" -eq 1 ]]; then
    write_asm_redo_recovery_sql_file "$redo_group" "$redo_member" "$redo_diskgroup" "$sql_file"
    manifest_append "recover_redo_asm_sqlfile" "$sql_file"
    manifest_append "recover_redo_asm_log" "$sql_log"
    manifest_append "recover_redo_group" "$redo_group"
    manifest_append "recover_redo_missing_member" "$redo_member"
    manifest_append "recover_redo_replacement_diskgroup" "$redo_diskgroup"
  else
    write_redo_validation_sql_file "$sql_file"
    manifest_append "recover_redo_validate_sqlfile" "$sql_file"
    manifest_append "recover_redo_validate_log" "$sql_log"
  fi

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_database.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_database.log"
  write_redo_validation_rman_file "$rman_file"
  manifest_append "recover_redo_validate_rman" "$rman_file"
  manifest_append "recover_redo_validate_rman_log" "$rman_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  if [[ "$asm_redo_mode" -eq 1 ]]; then
    echo "ASM redo group: ${redo_group}"
    echo "Missing member: ${redo_member}"
    echo "Replacement disk group: ${redo_diskgroup}"
  else
    echo "Redo member restore count: ${#RESTORE_ORIGINALS[@]}"
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$restore_pair_mode" -eq 1 ]]; then
    copy_restore_pairs_to_originals
  fi
  force_database_open
  run_sql_script_file "$sql_file" "$sql_log"
  run_rman_cmdfile "$rman_file" "$rman_log"

  if [[ "$restore_pair_mode" -eq 1 ]]; then
    safe_remove_restore_backups
  fi
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_tempfile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup pdb_name container_name sql_file sql_log
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"
  pdb_name="$TARGET_PDB"
  if [[ "$id" == "31" && -z "$pdb_name" ]]; then
    pdb_name="$(manifest_first_value "target_pdb" "action_1_pdb_name" || true)"
  fi
  if [[ "$id" == "31" ]]; then
    [[ -n "$pdb_name" ]] || die "Scenario 31 recovery requires --pdb or a manifest target_pdb."
    pdb_name="$(normalize_name "$pdb_name")"
    validate_oracle_name "$pdb_name" || die "Invalid PDB name: $pdb_name"
    TARGET_PDB="$pdb_name"
    container_name="$pdb_name"
  else
    container_name="CDB\$ROOT"
  fi

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Container: ${container_name}"
  echo "Original tempfile: ${original}"
  echo "Scenario backup: ${backup}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_tempfile.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_tempfile.log"
  write_tempfile_recovery_sql_file "$container_name" "$original" "$sql_file"
  manifest_append "recover_tempfile_sqlfile" "$sql_file"
  manifest_append "recover_tempfile_log" "$sql_log"
  run_sql_script_file "$sql_file" "$sql_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_password_file_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup password_display orapwd_bin
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"
  password_display="********"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Password file: ${original}"
  echo "Scenario backup: ${backup}"
  echo "SYSBACKUP user to restore if present: ${SYSBACKUP_USER:-none}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  [[ -n "$SYS_PASSWORD" || "$EXECUTE" -eq 0 ]] ||
    die "Password-file recovery execution requires --sys-password or CRASHSIM_SYS_PASSWORD."

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run orapwd file=${original} password=${password_display} entries=30 force=y"
  else
    ensure_database_open
    echo "orapwd file=${original} password=${password_display} entries=30 force=y"
    orapwd_bin="$(ensure_orapwd)"
    "$orapwd_bin" file="$original" password="$SYS_PASSWORD" entries=30 force=y ||
      die "orapwd failed for $original"
  fi

  restore_sysbackup_user_if_present
  remote_sysdba_test
  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

write_spfile_recovery_sql_file() {
  local pfile_path="$1"
  local spfile_path="$2"
  local sql_file="$3"
  local mode="$4"

  if [[ "$mode" == "cold" ]]; then
    cat >"$sql_file" <<SQL || die "Unable to write SPFILE recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
startup nomount pfile='${pfile_path}'
create spfile='${spfile_path}' from pfile='${pfile_path}';
shutdown abort
startup
exit
SQL
  else
    cat >"$sql_file" <<SQL || die "Unable to write SPFILE recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
create spfile='${spfile_path}' from pfile='${pfile_path}';
shutdown abort
startup
exit
SQL
  fi
}

recover_spfile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup status_file status sql_file sql_log rman_file rman_log recovery_mode
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "SPFILE path: ${original}"
  echo "Scenario backup: ${backup}"
  if [[ -n "$PFILE_PATH" ]]; then
    echo "PFILE: ${PFILE_PATH}"
  else
    echo "PFILE: not supplied; will restore the scenario backup if execution is requested."
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"

  if [[ -n "$PFILE_PATH" ]]; then
    [[ "$EXECUTE" -eq 0 || -f "$PFILE_PATH" ]] || die "PFILE not found: $PFILE_PATH"
    status_file="$WORK_DIR/spfile_instance_status.out"
    recovery_mode="warm"
    if [[ "$EXECUTE" -eq 1 ]]; then
      if ! query_instance_status "$status_file"; then
        recovery_mode="cold"
      else
        status="$(trim_blank_lines <"$status_file" | head -n 1 | tr -d ' ')"
        [[ -n "$status" ]] || recovery_mode="cold"
      fi
    fi

    sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_spfile.sql"
    sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_spfile.log"
    write_spfile_recovery_sql_file "$PFILE_PATH" "$original" "$sql_file" "$recovery_mode"
    manifest_append "recover_spfile_sqlfile" "$sql_file"
    manifest_append "recover_spfile_log" "$sql_log"
    run_sql_script_file "$sql_file" "$sql_log"
    ensure_database_open
  else
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would copy validated scenario backup $backup back to $original"
    else
      [[ -f "$backup" ]] || die "Scenario SPFILE backup not found: $backup"
      echo "cp -p -- $backup $original"
      cp -p -- "$backup" "$original" || die "Unable to restore SPFILE from scenario backup."
      ensure_database_open
    fi
  fi

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_spfile.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_spfile.log"
  {
    printf "validate spfile;\n"
    printf "list failure;\n"
  } >"$rman_file" || die "Unable to write SPFILE validation RMAN file: $rman_file"
  manifest_append "recover_spfile_validate_rman" "$rman_file"
  manifest_append "recover_spfile_validate_log" "$rman_log"
  run_rman_cmdfile "$rman_file" "$rman_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_archivelog_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup seq rman_file rman_log restore_file restore_log
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Archived log: ${original}"
  echo "Scenario backup: ${backup}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would discover archived-log sequence for $original"
    echo "DRY-RUN: would crosscheck missing log, copy $backup to $original, crosscheck again, validate, then remove backup"
    return "$SUCCESS"
  fi

  seq="$(archivelog_sequence_for_path "$original")" ||
    die "Could not determine archived-log sequence for $original"
  manifest_append "recover_archivelog_sequence" "$seq"

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_archivelog.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_archivelog.log"
  {
    printf "crosscheck archivelog sequence %s;\n" "$seq"
    printf "list archivelog sequence %s;\n" "$seq"
  } >"$rman_file" || die "Unable to write archived-log crosscheck RMAN file: $rman_file"
  run_rman_cmdfile "$rman_file" "$rman_log"

  [[ -f "$backup" ]] || die "Archived-log scenario backup not found: $backup"
  echo "cp -p -- $backup $original"
  cp -p -- "$backup" "$original" || die "Unable to copy archived-log backup to original path."

  restore_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_archivelog.rman"
  restore_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_archivelog.log"
  {
    printf "crosscheck archivelog sequence %s;\n" "$seq"
    printf "validate archivelog sequence %s;\n" "$seq"
    printf "list archivelog sequence %s;\n" "$seq"
    printf "list failure;\n"
  } >"$restore_file" || die "Unable to write archived-log validation RMAN file: $restore_file"
  manifest_append "recover_archivelog_validate_rman" "$restore_file"
  manifest_append "recover_archivelog_validate_log" "$restore_log"
  run_rman_cmdfile "$restore_file" "$restore_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_rman_backup_piece_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup bs_key missing_file missing_log validate_file validate_log
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"

  [[ "$original" == /* ]] || die "Scenario 25 recovery supports local filesystem backup pieces only: $original"
  [[ "$backup" == /* ]] || die "Scenario 25 recovery backup must be a local filesystem path: $backup"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Backup piece: ${original}"
  echo "Scenario backup: ${backup}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  bs_key="$(backupset_key_for_piece "$original")" ||
    die "Could not determine RMAN backup set key for backup piece: $original"
  manifest_append "recover_backupset_key" "$bs_key"

  missing_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_backuppiece.rman"
  missing_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_backuppiece.log"
  {
    printf "crosscheck backupset %s;\n" "$bs_key"
    printf "list backupset %s;\n" "$bs_key"
  } >"$missing_file" || die "Unable to write backup-piece crosscheck RMAN file: $missing_file"
  manifest_append "recover_backuppiece_missing_rman" "$missing_file"
  manifest_append "recover_backuppiece_missing_log" "$missing_log"
  run_rman_cmdfile "$missing_file" "$missing_log"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would copy $backup back to $original"
  else
    [[ -f "$backup" ]] || die "Scenario backup piece not found: $backup"
    echo "cp -p -- $backup $original"
    cp -p -- "$backup" "$original" || die "Unable to copy backup piece back to original path."
  fi

  validate_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_backuppiece.rman"
  validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_backuppiece.log"
  {
    printf "crosscheck backupset %s;\n" "$bs_key"
    printf "list backupset %s;\n" "$bs_key"
    printf "validate backupset %s;\n" "$bs_key"
    printf "list failure;\n"
  } >"$validate_file" || die "Unable to write backup-piece validation RMAN file: $validate_file"
  manifest_append "recover_backuppiece_validate_rman" "$validate_file"
  manifest_append "recover_backuppiece_validate_log" "$validate_log"
  run_rman_cmdfile "$validate_file" "$validate_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

srvctl_database_is_running() {
  local output_file="$1"
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  srvctl status database -d "$DB_UNIQUE_NAME" >"$output_file" 2>&1 || return "$FAIL"
  grep -Eq 'is running|is online|Instance .* is running' "$output_file"
}

srvctl_service_is_running() {
  local output_file="$1"
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  srvctl status service -d "$DB_UNIQUE_NAME" >"$output_file" 2>&1 || return "$FAIL"
  grep -Eq 'is running|is online|running on instance' "$output_file"
}

recover_srvctl_database_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  if [[ -n "$DB_UNIQUE_NAME" ]] && ! validate_oracle_name "$DB_UNIQUE_NAME"; then
    DB_UNIQUE_NAME=""
  fi
  if [[ -z "$DB_UNIQUE_NAME" && -n "${ORACLE_UNQNAME:-}" ]]; then
    DB_UNIQUE_NAME="$ORACLE_UNQNAME"
  fi
  if [[ -z "$DB_UNIQUE_NAME" ]] && command -v srvctl >/dev/null 2>&1; then
    local srvctl_dbs
    mapfile -t srvctl_dbs < <(srvctl config database 2>/dev/null | trim_blank_lines)
    if [[ "${#srvctl_dbs[@]}" -eq 1 ]]; then
      DB_UNIQUE_NAME="${srvctl_dbs[0]}"
    fi
  fi
  if [[ -z "$INSTANCE_NAME" && -n "${ORACLE_SID:-}" ]]; then
    INSTANCE_NAME="$ORACLE_SID"
  fi
  if [[ -z "$CLUSTER_TYPE" || "$CLUSTER_TYPE" == "UNKNOWN" ]]; then
    CLUSTER_TYPE="GI_SINGLE"
  fi
  [[ -n "$DB_UNIQUE_NAME" ]] ||
    die "Scenario 55 recovery requires DB_UNIQUE_NAME. Set ORACLE_UNQNAME or run with --sqlplus-logon against an open database."

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Database resource: ${DB_UNIQUE_NAME}"
  echo "Instance: ${INSTANCE_NAME}"
  echo "Cluster type: ${CLUSTER_TYPE}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run srvctl status database -d ${DB_UNIQUE_NAME}"
    echo "DRY-RUN: would run srvctl start database -d ${DB_UNIQUE_NAME} if the database is not running"
    echo "DRY-RUN: would run srvctl start service -d ${DB_UNIQUE_NAME} if services are not running"
    echo "DRY-RUN: would validate database/PDB health with SQL*Plus"
    return "$SUCCESS"
  fi

  local db_status_file service_status_file
  db_status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_srvctl_database_status.log"
  service_status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_srvctl_service_status.log"
  manifest_append "recover_srvctl_database_status_log" "$db_status_file"
  manifest_append "recover_srvctl_service_status_log" "$service_status_file"

  if srvctl_database_is_running "$db_status_file"; then
    echo "Database resource is already running."
  else
    echo "srvctl start database -d ${DB_UNIQUE_NAME}"
    srvctl start database -d "$DB_UNIQUE_NAME" ||
      die "Unable to start database resource ${DB_UNIQUE_NAME}"
  fi

  if srvctl_service_is_running "$service_status_file"; then
    echo "Database services are already running."
  else
    echo "srvctl start service -d ${DB_UNIQUE_NAME}"
    srvctl start service -d "$DB_UNIQUE_NAME" ||
      warn "srvctl start service reported a non-zero status; continuing to SQL health validation."
  fi

  ensure_database_open
  run_health_check
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_recovery_automation "$id" ||
    die "Automated recovery is not yet implemented for scenario $id. Use --runbook $id for manual guidance."

  case "$id" in
    1|2|23)
      recover_controlfile_scenario "$id"
      ;;
    3|4|18|19|20|21|24)
      recover_redo_scenario "$id"
      ;;
    5|30)
      recover_datafile_scenario "$id"
      ;;
    6|31)
      recover_tempfile_scenario "$id"
      ;;
    7|14|17|32|39|41)
      recover_datafile_list_scenario "$id"
      ;;
    16)
      recover_password_file_scenario "$id"
      ;;
    25)
      recover_rman_backup_piece_scenario "$id"
      ;;
    26)
      recover_spfile_scenario "$id"
      ;;
    55)
      recover_srvctl_database_scenario "$id"
      ;;
    59)
      recover_archivelog_scenario "$id"
      ;;
  esac
}

print_runbook_only() {
  local id="$1"
  local runbook_file
  scenario_exists "$id" || die "Unknown scenario id: $id"

  runbook_file="${LOG_DIR}/crashsim_runbook_s${id}_${RUN_ID}.txt"
  {
    echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
    echo "Group: ${SCENARIO_GROUP[$id]}"
    echo "Scope: ${SCENARIO_SCOPE[$id]}"
    echo "Impact: ${SCENARIO_IMPACT[$id]}"
    echo "Requires: ${SCENARIO_REQUIRES[$id]}"
    echo "Notes: ${SCENARIO_NOTES[$id]}"
    echo "Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    print_recovery_runbook "$id"
  } >"$runbook_file" || die "Unable to write runbook artifact: $runbook_file"

  cat "$runbook_file"
  echo
  echo "Runbook artifact: ${runbook_file}"
  maybe_render_html "$runbook_file"
}

script_dir() {
  local source_path="${BASH_SOURCE[0]}"
  local dir_name
  dir_name="$(dirname "$source_path")"
  (cd "$dir_name" >/dev/null 2>&1 && pwd)
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

html_escape_stream() {
  awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }
    { print esc($0) }
  '
}

render_artifact_html() {
  local input_file="$1"
  local output_file="${2:-}"
  local title generated

  [[ -f "$input_file" ]] || die "Artifact not found: $input_file"
  [[ -n "$output_file" ]] || output_file="${input_file}.html"
  title="$(basename "$input_file")"
  generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf '%s\n' '<!doctype html>'
    printf '%s\n' '<html lang="en">'
    printf '%s\n' '<head>'
    printf '%s\n' '<meta charset="utf-8">'
    printf '<title>%s</title>\n' "$(printf "%s" "$title" | html_escape_stream)"
    printf '%s\n' '<style>'
    printf '%s\n' ':root { color-scheme: light dark; }'
    printf '%s\n' 'body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f6f7f9; color: #16181d; }'
    printf '%s\n' 'main { max-width: 1180px; margin: 0 auto; padding: 28px; }'
    printf '%s\n' 'header { margin-bottom: 18px; border-bottom: 1px solid #d8dde6; padding-bottom: 14px; }'
    printf '%s\n' 'h1 { font-size: 22px; margin: 0 0 8px; }'
    printf '%s\n' '.meta { font-size: 13px; color: #596170; line-height: 1.5; }'
    printf '%s\n' 'pre { white-space: pre-wrap; word-break: break-word; background: #fff; border: 1px solid #d8dde6; border-radius: 8px; padding: 18px; overflow: auto; line-height: 1.45; font-size: 13px; }'
    printf '%s\n' '@media (prefers-color-scheme: dark) { body { background: #101318; color: #eef1f5; } pre { background: #161a22; border-color: #303846; } header { border-color: #303846; } .meta { color: #a9b2c3; } }'
    printf '%s\n' '</style>'
    printf '%s\n' '</head>'
    printf '%s\n' '<body><main>'
    printf '<header><h1>%s</h1><div class="meta">Source: %s<br>Generated UTC: %s</div></header>\n' \
      "$(printf "%s" "$title" | html_escape_stream)" \
      "$(printf "%s" "$input_file" | html_escape_stream)" \
      "$(printf "%s" "$generated" | html_escape_stream)"
    printf '%s\n' '<pre>'
    audit_redact_stream <"$input_file" | html_escape_stream
    printf '%s\n' '</pre>'
    printf '%s\n' '</main></body></html>'
  } >"$output_file" || die "Unable to write HTML artifact: $output_file"

  echo "HTML artifact generated: ${output_file}"
}

maybe_render_html() {
  local input_file="$1"
  [[ "$HTML_OUTPUT" -eq 1 ]] || return "$SUCCESS"
  render_artifact_html "$input_file"
}

find_latest_artifact() {
  local kind="${1:-any}"
  local latest=""

  case "$kind" in
    topology)
      if [[ -f "${LOG_DIR}/crashsim_topology_latest.txt" ]]; then
        latest="${LOG_DIR}/crashsim_topology_latest.txt"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_topology_*.txt' 2>/dev/null | sort | tail -n 1)"
      fi
      [[ -n "$latest" ]] || latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_config_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    config|configuration)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_config_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    backup|backup-report|recoverability)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_backup_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    maa|maa-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_maa_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    health)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_health_check_*.log' 2>/dev/null | sort | tail -n 1)"
      ;;
    scenario)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_s*.manifest' 2>/dev/null | sort | tail -n 1)"
      ;;
    protect|protection)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_protect_s*.manifest' 2>/dev/null | sort | tail -n 1)"
      ;;
    recover|recovery)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_recover_s*.manifest' 2>/dev/null | sort | tail -n 1)"
      ;;
    runbook)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_runbook_s*.txt' 2>/dev/null | sort | tail -n 1)"
      ;;
    baseline)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_baseline_backup_*.rman' 2>/dev/null | sort | tail -n 1)"
      ;;
    review)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_review_index_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    audit)
      audit_effective_dir
      local audit_dir
      while IFS= read -r audit_dir; do
        [[ -n "$AUDIT_RUN_DIR" && "$audit_dir" == "$AUDIT_RUN_DIR" ]] && continue
        [[ -f "${audit_dir}/exit_status" ]] || continue
        [[ -f "${audit_dir}/stdout.log" ]] && latest="${audit_dir}/stdout.log"
      done < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' 2>/dev/null | sort)
      ;;
    any|latest)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f 2>/dev/null | sort | tail -n 1)"
      ;;
    *)
      return "$FAIL"
      ;;
  esac

  [[ -n "$latest" && -f "$latest" ]] || return "$FAIL"
  printf "%s\n" "$latest"
}

resolve_artifact_reference() {
  local ref="$1"
  local kind

  [[ -n "$ref" ]] || return "$FAIL"
  case "$ref" in
    latest)
      find_latest_artifact "any"
      ;;
    latest:*)
      kind="${ref#latest:}"
      find_latest_artifact "$kind"
      ;;
    *)
      [[ -f "$ref" ]] || return "$FAIL"
      printf "%s\n" "$ref"
      ;;
  esac
}

review_manifest_summary() {
  local manifest="$1"
  awk -F= '
    $1 == "mode" {mode=$2}
    $1 == "scenario_id" {id=$2}
    $1 == "scenario_title" {title=$2}
    $1 == "started_at_utc" {started=$2}
    END {
      if (mode == "") mode="unknown"
      if (id == "") id="-"
      if (title == "") title="-"
      if (started == "") started="-"
      printf "%s | %s | %s | %s", mode, id, started, title
    }
  ' "$manifest"
}

review_append_file_list() {
  local report_file="$1"
  local title="$2"
  local limit="$3"
  shift 3
  local -a files=()
  local file

  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done < <(find "$LOG_DIR" -maxdepth 1 -type f "$@" 2>/dev/null | sort | tail -n "$limit")

  {
    printf "\n## %s\n\n" "$title"
    if [[ "${#files[@]}" -eq 0 ]]; then
      printf "No stored artifacts found.\n"
    else
      for file in "${files[@]}"; do
        printf -- '- `%s`\n' "$file"
      done
    fi
  } >>"$report_file"
}

generate_review_index() {
  local report_file latest_topology latest_config latest_backup latest_maa latest_health latest_review
  local manifest audit_dir metadata command status started mode

  report_file="${LOG_DIR}/crashsim_review_index_${RUN_ID}.md"
  latest_topology="$(find_latest_artifact topology 2>/dev/null || true)"
  latest_config="$(find_latest_artifact config 2>/dev/null || true)"
  latest_backup="$(find_latest_artifact backup 2>/dev/null || true)"
  latest_maa="$(find_latest_artifact maa 2>/dev/null || true)"
  latest_health="$(find_latest_artifact health 2>/dev/null || true)"

  {
    printf "# CrashSimulator Review Center\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf -- '- Audit directory: `%s`\n' "$AUDIT_DIR"
    printf "\nThis index lists previously collected CrashSimulator topology snapshots, scenario manifests, runbooks, dry-run/execution audit records, health checks, and reports. It does not reconnect to the database.\n\n"

    printf "## Latest Collected Topology\n\n"
    if [[ -n "$latest_topology" ]]; then
      printf -- '- Latest topology artifact: `%s`\n' "$latest_topology"
    else
      printf -- '- No cached topology snapshot found. Run `--discover` or `--config-report` to collect one.\n'
    fi
    [[ -n "$latest_config" ]] && printf -- '- Latest configuration report: `%s`\n' "$latest_config"
    [[ -n "$latest_backup" ]] && printf -- '- Latest backup/recoverability report: `%s`\n' "$latest_backup"
    [[ -n "$latest_maa" ]] && printf -- '- Latest MAA readiness report: `%s`\n' "$latest_maa"
    [[ -n "$latest_health" ]] && printf -- '- Latest health check: `%s`\n' "$latest_health"

    printf "\n## Scenario / Protection / Recovery Manifests\n\n"
  } >"$report_file" || die "Unable to write review index: $report_file"

  local manifest_count=0
  while IFS= read -r manifest; do
    printf -- '- `%s` - %s\n' "$manifest" "$(review_manifest_summary "$manifest")" >>"$report_file"
    manifest_count=$((manifest_count + 1))
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.manifest' 2>/dev/null | sort | tail -n 40)
  [[ "$manifest_count" -gt 0 ]] || printf "No stored manifests found.\n" >>"$report_file"

  review_append_file_list "$report_file" "Runbooks" 20 -name 'crashsim_runbook_s*.txt'
  review_append_file_list "$report_file" "Health Checks" 20 -name 'crashsim_health_check_*.log'
  review_append_file_list "$report_file" "Configuration Reports" 20 -name 'crashsim_config_report_*.md'
  review_append_file_list "$report_file" "Backup Strategy / Recoverability Reports" 20 -name 'crashsim_backup_report_*.md'
  review_append_file_list "$report_file" "MAA Readiness Reports" 20 -name 'crashsim_maa_report_*.md'
  review_append_file_list "$report_file" "Baseline Backup Plans And Logs" 20 \( -name 'crashsim_baseline_backup_*.rman' -o -name 'crashsim_baseline_backup_*.log' \)
  review_append_file_list "$report_file" "RMAN And SQL Helper Files" 30 \( -name '*.rman' -o -name '*.sql' \)

  {
    printf "\n## Audit Records\n\n"
  } >>"$report_file"
  local audit_count=0
  audit_effective_dir
  while IFS= read -r audit_dir; do
    [[ -n "$AUDIT_RUN_DIR" && "$audit_dir" == "$AUDIT_RUN_DIR" ]] && continue
    metadata="${audit_dir}/metadata.env"
    command="${audit_dir}/command.redacted"
    status="${audit_dir}/exit_status"
    [[ -f "$status" ]] || continue
    started="$(awk -F= '$1=="started_at_utc"{print $2}' "$metadata" 2>/dev/null | tail -n 1)"
    mode="$(awk -F= '$1=="mode"{print $2}' "$metadata" 2>/dev/null | tail -n 1)"
    printf -- '- `%s` - mode `%s`, started `%s`, exit `%s`\n' \
      "$audit_dir" "${mode:-unknown}" "${started:-unknown}" "$([[ -f "$status" ]] && cat "$status" || printf unknown)" >>"$report_file"
    [[ -f "$command" ]] && printf '  Command: `%s`\n' "$(cat "$command")" >>"$report_file"
    audit_count=$((audit_count + 1))
  done < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' 2>/dev/null | sort | tail -n 30)
  [[ "$audit_count" -gt 0 ]] || printf "No audit records found.\n" >>"$report_file"

  {
    printf "\n## Access Shortcuts\n\n"
    printf -- '- Show latest topology: `./%s --review-topology`\n' "$PROGRAM"
    printf -- '- Show latest health check: `./%s --show-artifact latest:health`\n' "$PROGRAM"
    printf -- '- Generate HTML for latest review index: `./%s --render-html latest:review`\n' "$PROGRAM"
    printf -- '- Generate HTML for a specific artifact: `./%s --render-html /path/to/artifact`\n' "$PROGRAM"
  } >>"$report_file"

  latest_review="$report_file"
  echo "Review index generated: ${latest_review}"
  cat "$latest_review"
  maybe_render_html "$latest_review"
}

review_topology() {
  local topology_file
  topology_file="$(find_latest_artifact topology 2>/dev/null || true)"
  if [[ -z "$topology_file" ]]; then
    echo "No collected topology artifact was found in ${LOG_DIR}."
    echo "Run --discover or --config-report to collect topology evidence first."
    return "$FAIL"
  fi
  echo "Latest collected topology artifact: ${topology_file}"
  echo
  cat "$topology_file"
  maybe_render_html "$topology_file"
}

show_artifact() {
  local ref="$1"
  local artifact

  artifact="$(resolve_artifact_reference "$ref")" ||
    die "Artifact not found for reference '${ref}'. Use a path or latest:<kind>."
  echo "Artifact: ${artifact}"
  echo
  cat "$artifact"
  maybe_render_html "$artifact"
}

render_html_target() {
  local ref="$1"
  local artifact

  artifact="$(resolve_artifact_reference "$ref")" ||
    die "Artifact not found for reference '${ref}'. Use a path or latest:<kind>."
  render_artifact_html "$artifact"
}

append_report_section() {
  local report_file="$1"
  local title="$2"
  {
    printf "\n## %s\n\n" "$title"
  } >>"$report_file"
}

append_report_text() {
  local report_file="$1"
  shift
  printf "%s\n" "$*" >>"$report_file"
}

md_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//|/\\|}"
  printf "%s" "$value"
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
  l_count number;
begin
  begin
    execute immediate q'[select count(*) from dba_services where failover_type in ('TRANSACTION','AUTO') or commit_outcome = 'YES']'
      into l_count;
  exception
    when others then
      l_count := -1;
  end;
  dbms_output.put_line('CSIM_MAA|application_continuity_service_count|' || l_count);

  begin
    execute immediate 'select count(*) from dba_capture' into l_count;
  exception
    when others then
      l_count := -1;
  end;
  dbms_output.put_line('CSIM_MAA|capture_process_count|' || l_count);

  begin
    execute immediate 'select count(*) from dba_apply' into l_count;
  exception
    when others then
      l_count := -1;
  end;
  dbms_output.put_line('CSIM_MAA|apply_process_count|' || l_count);
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

maa_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${MAA_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

maa_positive() {
  local key="$1"
  local value
  value="$(maa_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

maa_zero() {
  local key="$1"
  local value
  value="$(maa_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -eq 0 ]]
}

maa_append_check() {
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

maa_sla_hint() {
  local local_rto local_rpo dr_rto dr_rpo planned_rto combined
  local_rto="$(printf "%s" "$MAA_LOCAL_RTO" | tr '[:upper:]' '[:lower:]')"
  local_rpo="$(printf "%s" "$MAA_LOCAL_RPO" | tr '[:upper:]' '[:lower:]')"
  dr_rto="$(printf "%s" "$MAA_DR_RTO" | tr '[:upper:]' '[:lower:]')"
  dr_rpo="$(printf "%s" "$MAA_DR_RPO" | tr '[:upper:]' '[:lower:]')"
  planned_rto="$(printf "%s" "$MAA_PLANNED_RTO" | tr '[:upper:]' '[:lower:]')"
  combined="${local_rto} ${local_rpo} ${dr_rto} ${dr_rpo} ${planned_rto}"

  if [[ -z "${combined// }" ]]; then
    printf "No SLA objectives supplied yet. Provide CRASHSIM_MAA_* values or --maa-* options in a future run to compare target objectives against detected posture."
  elif [[ "$combined" =~ zero|near.zero|seconds|sub.minute|subminute ]]; then
    printf "Supplied objectives appear very aggressive. Expect at least Gold for site protection, and Platinum/Diamond patterns when application-visible downtime must approach zero."
  elif [[ "$combined" =~ minute|min|hour ]]; then
    printf "Supplied objectives suggest Silver may cover local instance/server events, while Gold is normally required for low-RTO/low-RPO disaster recovery."
  else
    printf "Supplied objectives may be compatible with Bronze or Silver if backup/restore testing proves the required recovery windows. Validate with timed CrashSimulator drills."
  fi
}

run_maa_report() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file evidence_file generated_at
  local detected_level detected_reason readiness_status sla_hint
  local has_silver=0 has_gold=0 has_platinum=0 has_diamond=0 baseline_gap=0
  local version_major app_continuity capture_count apply_count

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.evidence"
  write_maa_assessment_sql_file "$sql_file"

  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "MAA assessment SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"

  case "$CLUSTER_TYPE" in
    RAC|RACONE|RACONENODE|RAC_ONE_NODE)
      has_silver=1
      ;;
  esac
  if [[ "$(maa_value cluster_database FALSE)" == "TRUE" || "$(maa_value instance_parallel NO)" == "YES" ]]; then
    has_silver=1
  fi
  if [[ "$(maa_value db_role UNKNOWN)" != "PRIMARY" ]] || maa_positive remote_standby_dest_count; then
    has_gold=1
  fi
  capture_count="$(maa_value capture_process_count 0)"
  apply_count="$(maa_value apply_process_count 0)"
  app_continuity="$(maa_value application_continuity_service_count 0)"
  if [[ "$has_gold" -eq 1 && "$capture_count" =~ ^[0-9]+$ && "$apply_count" =~ ^[0-9]+$ &&
        ( "$capture_count" -gt 0 || "$apply_count" -gt 0 ) ]]; then
    has_platinum=1
  fi
  version_major="$(maa_value version_major 0)"
  if [[ "$has_platinum" -eq 1 && "$version_major" =~ ^[0-9]+$ && "$version_major" -ge 26 ]]; then
    has_diamond=1
  fi

  detected_level="Bronze"
  detected_reason="Single-instance, Oracle Restart, or no RAC/Data Guard/GoldenGate topology was detected."
  if [[ "$has_silver" -eq 1 ]]; then
    detected_level="Silver"
    detected_reason="RAC or RAC One Node style topology was detected."
  fi
  if [[ "$has_gold" -eq 1 ]]; then
    detected_level="Gold"
    detected_reason="Data Guard standby role or remote standby transport destination was detected."
  fi
  if [[ "$has_platinum" -eq 1 ]]; then
    detected_level="Platinum"
    detected_reason="Data Guard plus GoldenGate/replication dictionary evidence was detected."
  fi
  if [[ "$has_diamond" -eq 1 ]]; then
    detected_level="Diamond"
    detected_reason="26ai-or-later plus Platinum-style replication evidence was detected. Exadata and active/active details still require manual confirmation."
  fi

  [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]] || baseline_gap=1
  [[ "$(maa_value force_logging UNKNOWN)" == "YES" ]] || baseline_gap=1
  maa_positive recent_successful_backup_jobs_7d || baseline_gap=1
  maa_zero datafiles_without_backup_metadata || baseline_gap=1
  maa_zero recover_file_count || baseline_gap=1
  maa_zero block_corruption_count || baseline_gap=1

  readiness_status="Baseline checks passed"
  [[ "$baseline_gap" -eq 0 ]] || readiness_status="Baseline gaps detected"
  sla_hint="$(maa_sla_hint)"

  {
    printf "# CrashSimulator Oracle MAA Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Application context: `%s`\n' "${MAA_APP_NAME:-not supplied}"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(maa_value cdb "$DB_CDB")"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Storage type: `%s`\n' "$STORAGE_TYPE"
    printf -- '- Detected MAA posture: `%s`\n' "$detected_level"
    printf -- '- Readiness status: `%s`\n' "$readiness_status"
    printf -- '- Raw SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This report is a best-effort posture assessment, not an Oracle certification. It maps observable database, Grid Infrastructure, backup, Data Guard, and security evidence to the MAA reference architecture model and highlights gaps that should be validated with timed drills.\n\n"
  } >"$report_file" || die "Unable to write MAA report file: $report_file"

  append_report_section "$report_file" "Detected MAA Level"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    printf '| Detected posture | `%s` |\n' "$(md_escape "$detected_level")"
    printf '| Basis | %s |\n' "$(md_escape "$detected_reason")"
    printf '| Baseline readiness | `%s` |\n' "$(md_escape "$readiness_status")"
    printf '| Detection confidence | %s |\n' "$(md_escape "Medium: based on target-host SQL/GI evidence; application failover behavior and external schedulers require confirmation.")"
  } >>"$report_file"

  append_report_section "$report_file" "MAA Reference Model Used"
  {
    printf '| MAA level | Observable capabilities used by this report |\n'
    printf '| --- | --- |\n'
    printf '| Bronze | Single-instance or Oracle Restart style database with ARCHIVELOG, RMAN backup/recovery evidence, corruption checks, and basic restart/restore readiness. |\n'
    printf '| Silver | Bronze plus RAC or RAC One Node style local HA; Application Continuity evidence is checked when dictionary columns are available. |\n'
    printf '| Gold | Silver/Bronze plus Data Guard or Active Data Guard evidence for disaster recovery and low/zero data-loss posture. |\n'
    printf '| Platinum | Gold plus GoldenGate/advanced replication or sharding-style evidence for near-zero or zero application outage patterns. |\n'
    printf '| Diamond | Next-generation 26ai-or-later/Exadata/GoldenGate active-active pattern; this report can only flag partial evidence and requires manual confirmation. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Evidence Summary"
  {
    printf '| Area | Evidence |\n'
    printf '| --- | --- |\n'
    printf '| Database | Role `%s`, open mode `%s`, log mode `%s`, force logging `%s`, flashback `%s` |\n' \
      "$(md_escape "$(maa_value db_role)")" "$(md_escape "$(maa_value open_mode)")" \
      "$(md_escape "$(maa_value log_mode)")" "$(md_escape "$(maa_value force_logging)")" \
      "$(md_escape "$(maa_value flashback_on)")"
    printf '| Local HA | Cluster `%s`, cluster_database `%s`, instance parallel `%s`, GI managed `%s`, storage `%s` |\n' \
      "$(md_escape "$CLUSTER_TYPE")" "$(md_escape "$(maa_value cluster_database)")" \
      "$(md_escape "$(maa_value instance_parallel)")" "$(md_escape "$GI_MANAGED")" "$(md_escape "$STORAGE_TYPE")"
    printf '| Backup | Recent successful jobs 7d `%s`, failed jobs 7d `%s`, last success `%s`, datafiles without backup metadata `%s`, devices `%s` |\n' \
      "$(md_escape "$(maa_value recent_successful_backup_jobs_7d)")" \
      "$(md_escape "$(maa_value recent_failed_backup_jobs_7d)")" \
      "$(md_escape "$(maa_value last_successful_backup_time)")" \
      "$(md_escape "$(maa_value datafiles_without_backup_metadata)")" \
      "$(md_escape "$(maa_value backup_device_types)")"
    printf '| Data Guard | Remote standby destinations `%s`, valid destinations `%s`, FSFO `%s`, observer `%s`, transport lag `%s`, apply lag `%s` |\n' \
      "$(md_escape "$(maa_value remote_standby_dest_count)")" \
      "$(md_escape "$(maa_value valid_remote_standby_dest_count)")" \
      "$(md_escape "$(maa_value fsfo_status)")" "$(md_escape "$(maa_value fsfo_observer_present)")" \
      "$(md_escape "$(maa_value dataguard_transport_lag)")" "$(md_escape "$(maa_value dataguard_apply_lag)")"
    printf '| Storage/config | Control files `%s`, redo min members `%s`, redo groups with <2 members `%s`, FRA configured `%s`, FRA used `%s%%` |\n' \
      "$(md_escape "$(maa_value control_file_count)")" "$(md_escape "$(maa_value redo_min_members)")" \
      "$(md_escape "$(maa_value redo_groups_less_than_two_members)")" \
      "$(md_escape "$(maa_value fra_configured)")" "$(md_escape "$(maa_value fra_used_pct)")"
    printf '| Security | Wallet open rows `%s`, wallet not-open rows `%s`, encrypted tablespaces `%s`, TDE config `%s` |\n' \
      "$(md_escape "$(maa_value tde_wallet_open_count)")" \
      "$(md_escape "$(maa_value tde_wallet_not_open_count)")" \
      "$(md_escape "$(maa_value encrypted_tablespace_count)")" \
      "$(md_escape "$(maa_value tde_configuration)")"
    printf '| Application continuity / replication | AC-style services `%s`, capture processes `%s`, apply processes `%s` |\n' \
      "$(md_escape "$app_continuity")" "$(md_escape "$capture_count")" "$(md_escape "$apply_count")"
  } >>"$report_file"

  append_report_section "$report_file" "Best-Practice Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]]; then
    maa_append_check "$report_file" "OK" "Recoverability" "ARCHIVELOG enabled" "LOG_MODE=$(maa_value log_mode)" "Keep validating archived-log backup, restore, and gap handling."
  else
    maa_append_check "$report_file" "GAP" "Recoverability" "ARCHIVELOG enabled" "LOG_MODE=$(maa_value log_mode)" "Enable ARCHIVELOG before expecting meaningful point-in-time or DR recovery."
  fi
  if [[ "$(maa_value force_logging UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Data protection" "FORCE LOGGING enabled" "FORCE_LOGGING=$(maa_value force_logging)" "Keep FORCE LOGGING enabled for Data Guard/readiness unless an exception is explicitly approved."
  else
    maa_append_check "$report_file" "WARN" "Data protection" "FORCE LOGGING enabled" "FORCE_LOGGING=$(maa_value force_logging)" "Enable FORCE LOGGING before Data Guard or strict RPO validation."
  fi
  if maa_positive recent_successful_backup_jobs_7d && maa_zero datafiles_without_backup_metadata; then
    maa_append_check "$report_file" "OK" "Backup" "Recent complete RMAN backup coverage" "jobs_7d=$(maa_value recent_successful_backup_jobs_7d), no_backup_files=$(maa_value datafiles_without_backup_metadata)" "Continue scheduled restore preview/validate drills and retain off-host copies."
  else
    maa_append_check "$report_file" "GAP" "Backup" "Recent complete RMAN backup coverage" "jobs_7d=$(maa_value recent_successful_backup_jobs_7d), no_backup_files=$(maa_value datafiles_without_backup_metadata)" "Fix backup coverage before destructive drills; run RMAN backup, preview, and validate."
  fi
  if maa_zero recent_failed_backup_jobs_7d; then
    maa_append_check "$report_file" "OK" "Backup" "No recent failed RMAN jobs" "failed_jobs_7d=$(maa_value recent_failed_backup_jobs_7d)" "Continue monitoring failed backup jobs and alerting."
  else
    maa_append_check "$report_file" "WARN" "Backup" "No recent failed RMAN jobs" "failed_jobs_7d=$(maa_value recent_failed_backup_jobs_7d)" "Review failed RMAN jobs and confirm they do not represent missing required backup windows."
  fi
  if maa_zero recover_file_count && maa_zero block_corruption_count; then
    maa_append_check "$report_file" "OK" "Health" "No media recovery or block corruption rows" "recover_file=$(maa_value recover_file_count), block_corruption=$(maa_value block_corruption_count)" "Keep periodic validation and corruption monitoring."
  else
    maa_append_check "$report_file" "GAP" "Health" "No media recovery or block corruption rows" "recover_file=$(maa_value recover_file_count), block_corruption=$(maa_value block_corruption_count)" "Resolve recovery/corruption rows before measuring MAA readiness."
  fi
  if [[ "$(maa_value flashback_on UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Recovery" "Flashback Database enabled" "FLASHBACK_ON=$(maa_value flashback_on)" "Use guaranteed restore points deliberately for risky changes and validate retention."
  else
    maa_append_check "$report_file" "WARN" "Recovery" "Flashback Database enabled" "FLASHBACK_ON=$(maa_value flashback_on)" "Consider Flashback Database for faster logical-error and failed-change recovery where storage allows."
  fi
  if maa_positive remote_standby_dest_count || [[ "$(maa_value db_role UNKNOWN)" != "PRIMARY" ]]; then
    maa_append_check "$report_file" "OK" "Disaster recovery" "Data Guard topology detected" "role=$(maa_value db_role), standby_dests=$(maa_value remote_standby_dest_count), valid=$(maa_value valid_remote_standby_dest_count)" "Validate switchover/failover, FSFO, transport/apply lag, and application reconnection."
  else
    maa_append_check "$report_file" "GAP" "Disaster recovery" "Data Guard topology detected" "role=$(maa_value db_role), standby_dests=$(maa_value remote_standby_dest_count)" "Gold or higher MAA posture needs Data Guard/Active Data Guard or equivalent DR architecture."
  fi
  if [[ "$(maa_value fsfo_status UNKNOWN)" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED ]] || [[ "$(maa_value fsfo_observer_present UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Disaster recovery" "Fast-Start Failover evidence" "FSFO=$(maa_value fsfo_status), observer=$(maa_value fsfo_observer_present)" "Keep testing observer placement and failover/failback runbooks."
  else
    maa_append_check "$report_file" "INFO" "Disaster recovery" "Fast-Start Failover evidence" "FSFO=$(maa_value fsfo_status), observer=$(maa_value fsfo_observer_present)" "For strict RTO/RPO, evaluate FSFO with appropriate protection mode and observer design."
  fi
  if [[ "$has_silver" -eq 1 ]]; then
    maa_append_check "$report_file" "OK" "Local HA" "RAC/RAC One Node evidence" "cluster=${CLUSTER_TYPE}, cluster_database=$(maa_value cluster_database), parallel=$(maa_value instance_parallel)" "Validate service placement, FAN/ONS, Application Continuity, and rolling maintenance drills."
  else
    maa_append_check "$report_file" "INFO" "Local HA" "RAC/RAC One Node evidence" "cluster=${CLUSTER_TYPE}, cluster_database=$(maa_value cluster_database)" "Silver or higher local HA normally requires RAC or RAC One Node plus service failover design."
  fi
  if [[ "$app_continuity" =~ ^[0-9]+$ && "$app_continuity" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Application continuity" "AC-style service metadata" "services=$(maa_value application_continuity_service_count)" "Validate replay safety with application teams and planned/unplanned failover drills."
  else
    maa_append_check "$report_file" "INFO" "Application continuity" "AC-style service metadata" "services=$(maa_value application_continuity_service_count)" "For Silver/Platinum readiness, review services, drivers, FAN/ONS, TAC/AC, and request boundaries."
  fi
  if [[ "$(maa_value redo_min_members 0)" =~ ^[0-9]+$ && "$(maa_value redo_min_members 0)" -ge 2 && "$(maa_value control_file_count 0)" =~ ^[0-9]+$ && "$(maa_value control_file_count 0)" -ge 2 ]]; then
    maa_append_check "$report_file" "OK" "File redundancy" "Control file and redo multiplexing" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members)" "Keep members separated across failure domains where possible."
  else
    maa_append_check "$report_file" "WARN" "File redundancy" "Control file and redo multiplexing" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members), redo_under2=$(maa_value redo_groups_less_than_two_members)" "Multiplex control files and redo members across independent storage failure domains."
  fi
  if [[ "$(maa_value tde_wallet_not_open_count 0)" == "0" && "$(maa_value encrypted_tablespace_count 0)" != "0" ]]; then
    maa_append_check "$report_file" "OK" "Security" "TDE wallet open for encrypted data" "wallet_open=$(maa_value tde_wallet_open_count), encrypted_tbs=$(maa_value encrypted_tablespace_count)" "Keep wallet backups synchronized across RAC/Data Guard sites."
  elif [[ "$(maa_value encrypted_tablespace_count 0)" == "0" ]]; then
    maa_append_check "$report_file" "INFO" "Security" "TDE wallet open for encrypted data" "encrypted_tbs=0" "Confirm whether encryption is required by policy, compliance, or cloud-service defaults."
  else
    maa_append_check "$report_file" "GAP" "Security" "TDE wallet open for encrypted data" "wallet_not_open=$(maa_value tde_wallet_not_open_count), encrypted_tbs=$(maa_value encrypted_tablespace_count)" "Open/repair keystore state and validate encrypted tablespace and backup access."
  fi

  append_report_section "$report_file" "SLA / RTO / RPO Planning Context"
  {
    printf '| Requirement | Supplied value |\n'
    printf '| --- | --- |\n'
    printf '| Application | `%s` |\n' "$(md_escape "${MAA_APP_NAME:-not supplied}")"
    printf '| Local unplanned RTO | `%s` |\n' "$(md_escape "${MAA_LOCAL_RTO:-not supplied}")"
    printf '| Local unplanned RPO | `%s` |\n' "$(md_escape "${MAA_LOCAL_RPO:-not supplied}")"
    printf '| Disaster/site RTO | `%s` |\n' "$(md_escape "${MAA_DR_RTO:-not supplied}")"
    printf '| Disaster/site RPO | `%s` |\n' "$(md_escape "${MAA_DR_RPO:-not supplied}")"
    printf '| Planned maintenance RTO | `%s` |\n' "$(md_escape "${MAA_PLANNED_RTO:-not supplied}")"
    printf '| Planned maintenance RPO | `%s` |\n\n' "$(md_escape "${MAA_PLANNED_RPO:-not supplied}")"
    printf "Preliminary recommendation hint: %s\n" "$sla_hint"
  } >>"$report_file"

  append_report_section "$report_file" "Suggested CrashSimulator Validation Coverage"
  {
    printf '| Objective | Suggested drills |\n'
    printf '| --- | --- |\n'
    printf '| Bronze backup/restart readiness | Health check, config report, scenarios `5`, `6`, `25`, `26`, `59`, and timed restore-preview/validate runs. |\n'
    printf '| Silver local HA readiness | Service/instance relocation or restart drills such as `55` and `56`, plus client FAN/ONS/Application Continuity validation. |\n'
    printf '| Gold DR readiness | Data Guard transport/apply, switchover/failover, FSFO, archive gap, and standby recovery drills such as `50`, `51`, `52`, `59`. |\n'
    printf '| Platinum/Diamond application continuity | GoldenGate/active-active or sharding failover, conflict handling, zero-downtime planned maintenance, and application transaction replay tests. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html\n'
    printf -- '- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html\n'
    printf -- '- User RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw MAA Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_MAA|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  if command -v dgmgrl >/dev/null 2>&1; then
    append_report_command "$report_file" "Data Guard Broker Evidence" bash -lc "printf 'show configuration verbose;\nshow fast_start failover;\nexit\n' | dgmgrl -silent /"
  else
    append_report_section "$report_file" "Data Guard Broker Evidence"
    append_report_text "$report_file" "dgmgrl was not found in PATH."
  fi
  if command -v srvctl >/dev/null 2>&1 && [[ -n "$DB_UNIQUE_NAME" ]]; then
    append_report_command "$report_file" "srvctl Database And Service Evidence" bash -lc "srvctl config database -d '${DB_UNIQUE_NAME}' 2>&1; srvctl status database -d '${DB_UNIQUE_NAME}' 2>&1; srvctl config service -d '${DB_UNIQUE_NAME}' 2>&1; srvctl status service -d '${DB_UNIQUE_NAME}' 2>&1"
  fi

  echo "MAA readiness report generated: ${report_file}"
  echo "Detected MAA posture: ${detected_level}"
  echo "Readiness status: ${readiness_status}"
  maybe_render_html "$report_file"
}

append_report_command() {
  local report_file="$1"
  local title="$2"
  shift 2
  local status

  append_report_section "$report_file" "$title"
  {
    printf "Command:"
    printf " %q" "$@"
    printf "\n\n"
    printf '```text\n'
  } >>"$report_file"
  "$@" >>"$report_file" 2>&1
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
where incremental_level = 0;
select 'CSIM_BKP|last_level0_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile
where incremental_level = 0;
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
  where incremental_level = 0
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
    where incremental_level = 0
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

  local report_file sql_file generated_at grid_home crsctl_bin asm_sid
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

  if command -v dgmgrl >/dev/null 2>&1; then
    append_report_command "$report_file" "Data Guard Broker Configuration" bash -lc "printf 'show configuration verbose;\nshow fast_start failover;\nexit\n' | dgmgrl -silent /"
  else
    append_report_section "$report_file" "Data Guard Broker Configuration"
    append_report_text "$report_file" "dgmgrl was not found in PATH. SQL Data Guard/FSFO evidence is still included above."
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
    5|8|9|10|12|15|22|59)
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
    25|29|60)
      cat <<'RUNBOOK'
  - Backup/FRA/catalog loss:
    1. Run CROSSCHECK and LIST BACKUP/ARCHIVELOG to separate missing local files from object-storage/catalog metadata.
    2. Restore missing local autobackups or backup pieces from secondary/object storage if available.
    3. If FRA was moved/lost, recreate the directory, permissions, and DB_RECOVERY_FILE_DEST capacity.
    4. For catalog outage, practice NOCATALOG recovery using control-file metadata, then resync when the catalog returns.
    5. Finish by running RESTORE VALIDATE DATABASE and taking a fresh backup.
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
    46|49)
      cat <<'RUNBOOK'
  - ASM disk group/SPFILE recovery:
    1. Use asmcmd/SQL to inspect disk group mount state and missing disks.
    2. Restore ASM metadata/SPFILE from backup or OCR/srvctl metadata where applicable.
    3. Rebalance, mount disk groups, then validate database files and Clusterware resources.
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
    50)
      cat <<'RUNBOOK'
  - Standby apply cancelled:
    1. Restart managed recovery:
       alter database recover managed standby database disconnect from session;
    2. If using broker, set apply state through DGMGRL and validate configuration.
    3. Monitor V$DATAGUARD_STATS, V$ARCHIVE_DEST_STATUS, alert log, and apply lag until caught up.
RUNBOOK
      ;;
    51|52|54)
      cat <<'RUNBOOK'
  - Data Guard transport/broker/snapshot drill:
    1. Restore transport state, then force a log switch on the primary.
    2. Validate broker configuration with DGMGRL SHOW CONFIGURATION and SHOW DATABASE VERBOSE.
    3. Monitor transport/apply lag, archive gaps, protection mode, and FSFO observer state if enabled.
RUNBOOK
      ;;
    53)
      cat <<'RUNBOOK'
  - Active Data Guard read-only pressure:
    1. Confirm the standby remains read-only with apply, and distinguish query pressure from apply lag.
    2. Validate services, resource manager limits, session cleanup, and lag metrics.
RUNBOOK
      ;;
    55|56)
      cat <<'RUNBOOK'
  - RAC instance/service recovery:
    1. Check crsctl stat res -t, srvctl status database, srvctl status service, and alert logs on all nodes.
    2. Restart the failed instance or relocate services with srvctl.
    3. Validate FAN/TAF/Application Continuity behavior and service placement after recovery.
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
      sql)
        run_sql_action "$detail" "$target"
        ;;
      srvctl_abort_instance)
        perform_srvctl_abort_instance "$target"
        ;;
      srvctl_abort_database)
        perform_srvctl_abort_database
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

perform_fs_rename() {
  local path="$1"
  if [[ "$path" == +* ]]; then
    die "ASM path detected ($path). Filesystem rename is not valid; use ASM-aware scenarios."
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
  if [[ "$path" == +* ]]; then
    die "ASM path detected ($path). Filesystem dd is not valid; use ASM-aware scenarios."
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
  local row
  for row in "${TARGET_ROWS[@]}"; do
    if [[ "$row" == +* ]]; then
      add_action "external" "$row" "ASM path requires ASM-aware crash injection; filesystem rename is not valid"
    else
      add_action "fs_rename" "$row"
    fi
  done
}

add_fs_corrupt_targets() {
  local kind="$1"
  local row
  for row in "${TARGET_ROWS[@]}"; do
    if [[ "$row" == +* ]]; then
      add_action "external" "$row" "ASM path requires ASM-aware corruption handling; filesystem dd is not valid"
    else
      add_action "$kind" "$row"
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
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_temp_one() {
  reset_actions
  query_nonpdb_tempfiles "$WORK_DIR/temp_one.lst" "1 = 1" "$(one_row)"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_system_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/system_one.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_undo_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/undo_one.lst" "ts.contents = 'UNDO'" "$(one_row)"
  add_fs_rename_targets
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
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_fs_rename_targets
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
  select i.tablespace_name
  from index_ts i
  left join table_ts t on t.tablespace_name = i.tablespace_name
  where t.tablespace_name is null
    and i.tablespace_name not in ('SYSTEM','SYSAUX')
    and rownum = 1
)
select df.file_name
from dba_data_files df
join target_ts t on t.tablespace_name = df.tablespace_name
order by df.file_id;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_drop_indexes() {
  reset_actions
  local owner_filter="and 1 = 1"
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
  add_fs_rename_targets
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
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_system_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/system_tbs.lst" "df.tablespace_name = 'SYSTEM'" ""
  add_fs_rename_targets
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
  add_fs_rename_targets
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
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_file_header_corrupt() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/file_header_corrupt.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_fs_corrupt_targets "fs_corrupt_header"
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
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_temp_one() {
  reset_actions
  query_pdb_tempfiles "$WORK_DIR/pdb_temp_one.lst" "1 = 1" "$(one_row)"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_system_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_system_one.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_undo_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_undo_one.lst" "ts.contents = 'UNDO'" "$(one_row)"
  add_fs_rename_targets
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
  add_fs_rename_targets
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
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_drop_indexes() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and 1 = 1"
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
  add_fs_rename_targets
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
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_system_tbs() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_system_tbs.lst" "df.tablespace_name = 'SYSTEM'" ""
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_undo_tbs() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_undo_tbs.lst" "ts.contents = 'UNDO'" ""
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_all_datafiles() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_all_datafiles.lst" "1 = 1" ""
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_file_header_corrupt() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_file_header_corrupt.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_fs_corrupt_targets "fs_corrupt_header"
  execute_actions
  abort_target_instance
}

scenario_pdb_drop_table() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and 1 = 1"
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
  local owner_filter="and 1 = 1"
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

run_asmcmd_with_grid_env() {
  local asmcmd_bin asm_home asm_sid
  asmcmd_bin="$(command -v asmcmd 2>/dev/null || true)"
  [[ -n "$asmcmd_bin" ]] || return "$FAIL"
  asm_home="$(cd "$(dirname "$asmcmd_bin")/.." >/dev/null 2>&1 && pwd)"
  [[ -n "$asm_home" ]] || return "$FAIL"
  asm_sid="${CRASHSIM_ASM_SID:-}"
  [[ -n "$asm_sid" ]] || asm_sid="$(detect_asm_sid_from_process || true)"
  [[ -n "$asm_sid" ]] || asm_sid="+ASM"
  env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
}

scenario_asm_diskgroup_unavailable() {
  reset_actions
  local dg_file row dg_name dg_state dg_type dg_total dg_free target_dg=""
  echo "ASM disk group planning helper"
  dg_file="$WORK_DIR/asm_diskgroups.lst"
  sql_query "$dg_file" "
select name || '|' || state || '|' || type || '|' || total_mb || '|' || free_mb
from v\$asm_diskgroup
order by name;
"
  mapfile -t TARGET_ROWS < <(trim_blank_lines <"$dg_file")
  if [[ "${#TARGET_ROWS[@]}" -eq 0 ]]; then
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
  if command -v ocrcheck >/dev/null 2>&1; then
    print_optional_tool_output "ocrcheck" ocrcheck
  else
    warn "ocrcheck not found in PATH."
  fi
  if command -v ocrconfig >/dev/null 2>&1; then
    print_optional_tool_output "ocrconfig -showbackup" ocrconfig -showbackup
  else
    warn "ocrconfig not found in PATH."
  fi
  add_action "external" "OCR" "OCR restore practice must use a root/Grid procedure, verified OCR backups, and CRS validation"
  execute_actions
}

scenario_voting_disk_drill() {
  reset_actions
  echo "Voting disk planning helper"
  if command -v crsctl >/dev/null 2>&1; then
    print_optional_tool_output "crsctl query css votedisk" crsctl query css votedisk
  else
    warn "crsctl not found in PATH."
  fi
  add_action "external" "VOTING_DISK" "Voting disk replacement practice must use a root/Grid procedure and cluster membership validation"
  execute_actions
}

scenario_asm_spfile_loss() {
  reset_actions
  local asm_spfile="" asm_config_file
  echo "ASM SPFILE planning helper"
  if command -v srvctl >/dev/null 2>&1; then
    asm_config_file="$WORK_DIR/srvctl_config_asm.out"
    if srvctl config asm >"$asm_config_file" 2>&1; then
      echo
      echo "srvctl config asm:"
      sed 's/^/  /' "$asm_config_file"
    else
      warn "Unable to collect srvctl config asm."
    fi
  fi
  if command -v asmcmd >/dev/null 2>&1; then
    asm_spfile="$(run_asmcmd_with_grid_env spget 2>/dev/null | trim_blank_lines | head -n 1 || true)"
    if [[ -n "$asm_spfile" ]]; then
      print_optional_tool_output "asmcmd spget" run_asmcmd_with_grid_env spget
    else
      warn "asmcmd spget was not available from the current OS user; use the Grid owner if ASM SPFILE path discovery is required."
    fi
  else
    warn "asmcmd not found in PATH."
  fi
  [[ -n "$asm_spfile" ]] || asm_spfile="+ASM_SPFILE"
  add_action "external" "$asm_spfile" "ASM SPFILE loss requires ASM-aware backup/restore flow and Clusterware resource validation"
  execute_actions
}

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
  local dest_file="$WORK_DIR/remote_dest.lst"
  query_targets "$dest_file" "
select dest_id
from (
  select dest_id
  from v\$archive_dest
  where target = 'STANDBY'
    and status <> 'INACTIVE'
  order by dest_id
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No remote standby archive destination was found."
  local dest_id="${TARGET_ROWS[0]}"
  add_action "sql" "alter system set log_archive_dest_state_${dest_id}=defer scope=both;" "defer remote archive destination ${dest_id}"
  execute_actions
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
    and deleted = 'NO'
  order by completion_time desc
)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
}

scenario_planned() {
  local id="$1"
  echo "Scenario ${id} is registered but gated for a topology that is not available in this environment yet."
  echo "It is intentionally present so RAC, Data Guard, and ASM coverage can be tested as those labs are provided."
  echo "No destructive action was planned or executed."
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --discover)
        MODE="discover"
        shift
        ;;
      --list)
        MODE="list"
        shift
        ;;
      --menu)
        MODE="menu"
        shift
        ;;
      --health-check)
        MODE="health"
        shift
        ;;
      --config-report|--configuration-report|--report)
        MODE="report"
        shift
        ;;
      --backup-report|--backup-assessment|--recoverability-report)
        MODE="backup_report"
        shift
        ;;
      --baseline-backup|--fresh-baseline-backup|--run-baseline-backup)
        MODE="baseline_backup"
        shift
        ;;
      --audit-status|--audit-info)
        MODE="audit_status"
        shift
        ;;
      --purge-audit-logs|--audit-purge|--purge-logs)
        MODE="audit_purge"
        shift
        ;;
      --review|--review-artifacts|--history|--activity-history)
        MODE="review"
        shift
        ;;
      --review-topology|--show-topology-cache|--topology-cache)
        MODE="review_topology"
        shift
        ;;
      --show-artifact|--view-artifact)
        [[ "$#" -ge 2 ]] || die "$1 requires an artifact path or latest:<kind>"
        MODE="show_artifact"
        REVIEW_TARGET="$2"
        shift 2
        ;;
      --render-html|--html-artifact|--artifact-html)
        [[ "$#" -ge 2 ]] || die "$1 requires an artifact path or latest:<kind>"
        MODE="render_html"
        HTML_TARGET="$2"
        shift 2
        ;;
      --maa-report|--maa-assessment|--maa-readiness)
        MODE="maa_report"
        shift
        ;;
      --deep-validate)
        REPORT_DEEP_VALIDATE=1
        shift
        ;;
      --html|--html-output)
        HTML_OUTPUT=1
        shift
        ;;
      --validate-scenario|--validate|--check-scenario)
        [[ "$#" -ge 2 ]] || die "$1 requires an id"
        MODE="validate"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --validate-all-scenarios|--validate-scenarios|--check-scenarios)
        MODE="validate_all"
        SCENARIO_ID=""
        shift
        ;;
      --runbook)
        [[ "$#" -ge 2 ]] || die "--runbook requires an id"
        MODE="runbook"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --protect)
        [[ "$#" -ge 2 ]] || die "--protect requires an id"
        MODE="protect"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --recover)
        [[ "$#" -ge 2 ]] || die "--recover requires an id"
        MODE="recover"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --scenario)
        [[ "$#" -ge 2 ]] || die "--scenario requires an id"
        MODE="scenario"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --random-scenario|--aleatory-scenario)
        MODE="random"
        SCENARIO_ID=""
        shift
        ;;
      --pdb)
        [[ "$#" -ge 2 ]] || die "--pdb requires a PDB name"
        TARGET_PDB="$2"
        shift 2
        ;;
      --schema)
        [[ "$#" -ge 2 ]] || die "--schema requires a schema name"
        TARGET_SCHEMA="$2"
        shift 2
        ;;
      --file-no)
        [[ "$#" -ge 2 ]] || die "--file-no requires a file number"
        TARGET_FILE_NO="$2"
        shift 2
        ;;
      --manifest)
        [[ "$#" -ge 2 ]] || die "--manifest requires a file path"
        MANIFEST_FILE="$2"
        MANIFEST_FROM_ARG=1
        shift 2
        ;;
      --pfile)
        [[ "$#" -ge 2 ]] || die "--pfile requires a file path"
        PFILE_PATH="$2"
        shift 2
        ;;
      --sys-password)
        [[ "$#" -ge 2 ]] || die "--sys-password requires a value"
        SYS_PASSWORD="$2"
        shift 2
        ;;
      --service-name)
        [[ "$#" -ge 2 ]] || die "--service-name requires a service name"
        SERVICE_NAME="$2"
        shift 2
        ;;
      --sysbackup-user)
        [[ "$#" -ge 2 ]] || die "--sysbackup-user requires a user name"
        SYSBACKUP_USER="$2"
        shift 2
        ;;
      --local-only)
        LOCAL_ONLY=1
        shift
        ;;
      --max-targets)
        [[ "$#" -ge 2 ]] || die "--max-targets requires a positive integer"
        MAX_TARGETS="$2"
        shift 2
        ;;
      --piece-handle)
        [[ "$#" -ge 2 ]] || die "--piece-handle requires a backup-piece handle"
        PIECE_HANDLE="$2"
        shift 2
        ;;
      --rman-catalog)
        [[ "$#" -ge 2 ]] || die "--rman-catalog requires a recovery catalog connect string"
        RMAN_CATALOG_CONNECT="$2"
        shift 2
        ;;
      --backup-tag-prefix|--baseline-tag-prefix|--tag-prefix)
        [[ "$#" -ge 2 ]] || die "$1 requires a tag prefix"
        BASELINE_TAG_PREFIX="$2"
        shift 2
        ;;
      --audit-retain|--retain-logs)
        [[ "$#" -ge 2 ]] || die "$1 requires yes or no"
        AUDIT_RETAIN="$2"
        shift 2
        ;;
      --no-audit-retain|--no-retain-logs)
        AUDIT_RETAIN=0
        shift
        ;;
      --audit-retention-days|--log-retention-days)
        [[ "$#" -ge 2 ]] || die "$1 requires a number of days"
        AUDIT_RETENTION_DAYS="$2"
        shift 2
        ;;
      --audit-dir)
        [[ "$#" -ge 2 ]] || die "--audit-dir requires a directory"
        AUDIT_DIR="$2"
        shift 2
        ;;
      --maa-app-name)
        [[ "$#" -ge 2 ]] || die "--maa-app-name requires a value"
        MAA_APP_NAME="$2"
        shift 2
        ;;
      --maa-local-rto)
        [[ "$#" -ge 2 ]] || die "--maa-local-rto requires a value"
        MAA_LOCAL_RTO="$2"
        shift 2
        ;;
      --maa-local-rpo)
        [[ "$#" -ge 2 ]] || die "--maa-local-rpo requires a value"
        MAA_LOCAL_RPO="$2"
        shift 2
        ;;
      --maa-dr-rto)
        [[ "$#" -ge 2 ]] || die "--maa-dr-rto requires a value"
        MAA_DR_RTO="$2"
        shift 2
        ;;
      --maa-dr-rpo)
        [[ "$#" -ge 2 ]] || die "--maa-dr-rpo requires a value"
        MAA_DR_RPO="$2"
        shift 2
        ;;
      --maa-planned-rto)
        [[ "$#" -ge 2 ]] || die "--maa-planned-rto requires a value"
        MAA_PLANNED_RTO="$2"
        shift 2
        ;;
      --maa-planned-rpo)
        [[ "$#" -ge 2 ]] || die "--maa-planned-rpo requires a value"
        MAA_PLANNED_RPO="$2"
        shift 2
        ;;
      --dry-run)
        EXECUTE=0
        shift
        ;;
      --execute)
        EXECUTE=1
        shift
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      --log-dir)
        [[ "$#" -ge 2 ]] || die "--log-dir requires a directory"
        LOG_DIR="$2"
        shift 2
        ;;
      --sqlplus-logon)
        [[ "$#" -ge 2 ]] || die "--sqlplus-logon requires a logon string"
        SQLPLUS_LOGON="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE=1
        shift
        ;;
      --help|-h)
        usage
        exit "$SUCCESS"
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

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

menu_print_header() {
  echo
  echo "CrashSimulator V2 ${VERSION}"
  echo "Database: ${DB_UNIQUE_NAME:-not discovered}  Role: ${DB_ROLE:-unknown}  Open: ${DB_OPEN_MODE:-unknown}  CDB: ${DB_CDB:-unknown}"
  echo "Instance: ${INSTANCE_NAME:-unknown}  Storage: ${STORAGE_TYPE:-unknown}  Cluster: ${CLUSTER_TYPE:-unknown}"
  echo
  echo "Selected scenario: $(menu_selected_scenario_label)"
  echo "PDB: ${TARGET_PDB:-not set}  Schema: ${TARGET_SCHEMA:-not set}  FILE#: ${TARGET_FILE_NO:-not set}"
  echo "Manifest: ${MANIFEST_FILE:-not set}"
  echo "Log dir: ${LOG_DIR}"
  echo "Report deep validation: ${REPORT_DEEP_VALIDATE}"
  echo "Baseline backup tag prefix: ${BASELINE_TAG_PREFIX}"
  echo "Audit retain: ${AUDIT_RETAIN}  Retention days: ${AUDIT_RETENTION_DAYS}  Audit dir: ${AUDIT_DIR}"
  echo "Scenario 25 guards: local-only=${LOCAL_ONLY}  max-targets=${MAX_TARGETS:-not set}  piece-handle=$([[ -n "$PIECE_HANDLE" ]] && echo set || echo not-set)"
  echo "RMAN catalog: $([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo configured || echo not configured)"
  echo "Password-file recovery: SYS password=$([[ -n "$SYS_PASSWORD" ]] && echo set || echo not-set)  service=${SERVICE_NAME:-not set}"
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
    echo "Selected scenario ${SCENARIO_ID}: ${SCENARIO_TITLE[$SCENARIO_ID]}"
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
  local answer
  echo "Enter FILE#, c to clear, or blank to keep [${TARGET_FILE_NO:-not set}]:"
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
  TARGET_FILE_NO="$answer"
  echo "FILE# set to ${TARGET_FILE_NO}."
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
    echo " 11. Clear selected scenario and targets"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1) menu_select_pdb; menu_pause ;;
      2) menu_prompt_oracle_name "schema" TARGET_SCHEMA "$TARGET_SCHEMA"; menu_pause ;;
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
        SCENARIO_ID=""
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

menu_append_common_child_args() {
  [[ -n "$TARGET_PDB" ]] && MENU_CMD+=("--pdb" "$TARGET_PDB")
  [[ -n "$TARGET_SCHEMA" ]] && MENU_CMD+=("--schema" "$TARGET_SCHEMA")
  [[ -n "$TARGET_FILE_NO" ]] && MENU_CMD+=("--file-no" "$TARGET_FILE_NO")
  [[ -n "$PFILE_PATH" ]] && MENU_CMD+=("--pfile" "$PFILE_PATH")
  [[ -n "$SERVICE_NAME" ]] && MENU_CMD+=("--service-name" "$SERVICE_NAME")
  [[ -n "$SYSBACKUP_USER" ]] && MENU_CMD+=("--sysbackup-user" "$SYSBACKUP_USER")
  [[ "$LOCAL_ONLY" == "1" ]] && MENU_CMD+=("--local-only")
  [[ -n "$MAX_TARGETS" ]] && MENU_CMD+=("--max-targets" "$MAX_TARGETS")
  [[ -n "$PIECE_HANDLE" ]] && MENU_CMD+=("--piece-handle" "$PIECE_HANDLE")
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
  local status
  menu_print_child_command
  echo
  env \
    CRASHSIM_SYS_PASSWORD="$SYS_PASSWORD" \
    CRASHSIM_RMAN_CATALOG="$RMAN_CATALOG_CONNECT" \
    CRASHSIM_AUDIT_RETAIN="$AUDIT_RETAIN" \
    CRASHSIM_AUDIT_RETENTION_DAYS="$AUDIT_RETENTION_DAYS" \
    CRASHSIM_AUDIT_DIR="$AUDIT_DIR" \
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
  local latest status

  menu_require_scenario || {
    warn "No scenario selected."
    return "$FAIL"
  }

  MENU_CMD=("$0")
  case "$action" in
    scenario)
      MENU_CMD+=("--scenario" "$SCENARIO_ID")
      ;;
    protect)
      MENU_CMD+=("--protect" "$SCENARIO_ID")
      ;;
    recover)
      menu_choose_recovery_manifest
      MENU_CMD+=("--recover" "$SCENARIO_ID")
      [[ -n "$MANIFEST_FILE" ]] && MENU_CMD+=("--manifest" "$MANIFEST_FILE")
      ;;
    *)
      warn "Unknown action: $action"
      return "$FAIL"
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

  MENU_CMD=("$0" "--validate-scenario" "$SCENARIO_ID")
  menu_append_common_child_args
  menu_run_child_command
}

menu_run_validate_all_scenarios() {
  MENU_CMD=("$0" "--validate-all-scenarios")
  menu_append_common_child_args
  menu_run_child_command
}

menu_run_random_scenario() {
  local run_mode="$1"
  select_random_scenario || return "$FAIL"
  menu_run_child_action "scenario" "$run_mode"
}

menu_run_health_check() {
  MENU_CMD=("$0" "--health-check")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_configuration_report() {
  MENU_CMD=("$0" "--config-report")
  [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && MENU_CMD+=("--deep-validate")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_backup_report() {
  MENU_CMD=("$0" "--backup-report")
  [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && MENU_CMD+=("--deep-validate")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_baseline_backup() {
  local run_mode="$1"
  MENU_CMD=("$0" "--baseline-backup")
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
  MENU_CMD=("$0" "--maa-report")
  [[ -n "$MAA_APP_NAME" ]] && MENU_CMD+=("--maa-app-name" "$MAA_APP_NAME")
  [[ -n "$MAA_LOCAL_RTO" ]] && MENU_CMD+=("--maa-local-rto" "$MAA_LOCAL_RTO")
  [[ -n "$MAA_LOCAL_RPO" ]] && MENU_CMD+=("--maa-local-rpo" "$MAA_LOCAL_RPO")
  [[ -n "$MAA_DR_RTO" ]] && MENU_CMD+=("--maa-dr-rto" "$MAA_DR_RTO")
  [[ -n "$MAA_DR_RPO" ]] && MENU_CMD+=("--maa-dr-rpo" "$MAA_DR_RPO")
  [[ -n "$MAA_PLANNED_RTO" ]] && MENU_CMD+=("--maa-planned-rto" "$MAA_PLANNED_RTO")
  [[ -n "$MAA_PLANNED_RPO" ]] && MENU_CMD+=("--maa-planned-rpo" "$MAA_PLANNED_RPO")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
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
}

menu_run_audit_status() {
  MENU_CMD=("$0" "--audit-status")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_audit_purge() {
  local run_mode="$1"
  MENU_CMD=("$0" "--purge-audit-logs")
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
  MENU_CMD=("$0" "--review")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_review_topology() {
  local html_mode="$1"
  MENU_CMD=("$0" "--review-topology")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_prompt_artifact_reference() {
  local var_name="$1"
  local answer

  echo "Enter artifact path or latest:<kind> reference."
  echo "Kinds: topology, config, backup, maa, health, scenario, protect, recover, runbook, baseline, review, audit, any"
  echo "Blank uses latest:any:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="latest:any"
  printf -v "$var_name" "%s" "$answer"
}

menu_run_show_artifact() {
  local html_mode="$1"
  local ref
  menu_prompt_artifact_reference ref || return "$FAIL"
  MENU_CMD=("$0" "--show-artifact" "$ref")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_render_html() {
  local ref
  menu_prompt_artifact_reference ref || return "$FAIL"
  MENU_CMD=("$0" "--render-html" "$ref")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
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
        menu_show_recent_artifacts
        menu_pause
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
    echo "  5. Generate backup strategy and recoverability report"
    echo "  6. Generate backup report with deep RMAN validation (read-only, heavier)"
    echo "  7. Dry-run fresh RMAN baseline backup"
    echo "  8. Run fresh RMAN baseline backup"
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
        REPORT_DEEP_VALIDATE=0
        menu_run_backup_report
        menu_pause
        ;;
      6)
        REPORT_DEEP_VALIDATE=1
        menu_run_backup_report
        menu_pause
        ;;
      7)
        menu_run_baseline_backup "dry-run"
        menu_pause
        ;;
      8)
        menu_run_baseline_backup "execute"
        menu_pause
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
  echo
  echo "Recent files in ${LOG_DIR}:"
  find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.manifest' -o -name '*.log' -o -name '*.rman' -o -name '*.sql' -o -name '*.md' -o -name '*.txt' -o -name '*.html' \) 2>/dev/null |
    sort |
    tail -40 |
    sed 's/^/  /'
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
    echo " 13. Show recent manifests and logs"
    echo " 14. Dry-run random/aleatory scenario for this topology"
    echo " 16. Reports"
    echo " 17. Validate all scenarios for this topology"
    echo " 18. Audit / retention settings"
    echo " 19. Review collected topology, logs, reports, and history"
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
        menu_pause
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
        menu_run_validate_all_scenarios
        menu_pause
        ;;
      18)
        menu_audit_settings
        ;;
      19)
        menu_review_center
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

main() {
  register_scenarios
  parse_args "$@"
  normalize_targets
  init_runtime
  audit_start

  case "$MODE" in
    discover)
      print_discovery
      ;;
    list)
      list_scenarios
      ;;
    health)
      run_health_check
      ;;
    report)
      run_configuration_report
      ;;
    backup_report)
      run_backup_report
      ;;
    baseline_backup)
      run_baseline_backup
      ;;
    audit_status)
      audit_status
      ;;
    audit_purge)
      purge_audit_logs
      ;;
    review)
      generate_review_index
      ;;
    review_topology)
      review_topology
      ;;
    show_artifact)
      [[ -n "$REVIEW_TARGET" ]] || die "No artifact reference provided."
      show_artifact "$REVIEW_TARGET"
      ;;
    render_html)
      [[ -n "$HTML_TARGET" ]] || die "No artifact reference provided."
      render_html_target "$HTML_TARGET"
      ;;
    maa_report)
      run_maa_report
      ;;
    validate)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_scenario_validation "$SCENARIO_ID"
      ;;
    validate_all)
      validate_all_scenarios
      ;;
    runbook)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_runbook_only "$SCENARIO_ID"
      ;;
    scenario)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      run_scenario "$SCENARIO_ID"
      ;;
    random)
      run_random_scenario
      ;;
    protect)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      protect_scenario "$SCENARIO_ID"
      ;;
    recover)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      recover_scenario "$SCENARIO_ID"
      ;;
    menu)
      discover_environment || true
      interactive_menu
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac
}

main "$@"
