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
RENAME_COUNT=0

declare -a SCENARIO_IDS=()
declare -A SCENARIO_TITLE=()
declare -A SCENARIO_GROUP=()
declare -A SCENARIO_SCOPE=()
declare -A SCENARIO_IMPACT=()
declare -A SCENARIO_REQUIRES=()
declare -A SCENARIO_HANDLER=()
declare -A SCENARIO_NOTES=()

usage() {
  cat <<USAGE
CrashSimulator V2 ${VERSION}

Usage:
  ./${PROGRAM} --discover
  ./${PROGRAM} --list
  ./${PROGRAM} --menu
  ./${PROGRAM} --health-check
  ./${PROGRAM} --runbook <id> [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --protect <id> [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM} --recover <id> [--manifest <file>] [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM} --scenario <id> [--pdb <pdb_name>] [--dry-run]
  ./${PROGRAM} --scenario <id> [--pdb <pdb_name>] --execute [--yes]
  ./${PROGRAM}

Options:
  --discover              Print detected database topology and exits.
  --list                  List scenario registry and prerequisite gates.
  --menu                  Start guided terminal menu. This is the default.
  --health-check          Run a non-destructive SQL health check.
  --runbook <id>          Print recovery practice hints for a scenario.
  --protect <id>          Generate or run pre-drill RMAN protection for a scenario.
  --recover <id>          Generate or run RMAN recovery for supported scenarios.
  --scenario <id>         Run or dry-run a scenario by id.
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
  if [[ -n "$MAX_TARGETS" && ! "$MAX_TARGETS" =~ ^[1-9][0-9]*$ ]]; then
    die "Invalid max targets value: $MAX_TARGETS"
  fi
}

init_runtime() {
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="$(pwd)/crashsimulator_logs"
  fi
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/crashsimulator.${RUN_ID}.XXXXXX")" ||
    die "Unable to create temporary directory"
  trap cleanup EXIT
}

cleanup() {
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

    if [[ "$kind" == "fs_rename" || "$kind" == fs_corrupt_* ]]; then
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
    [[ "$kind" == "fs_rename" ]] || continue

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
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$script_file" >"$log_file" ||
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

print_discovery() {
  discover_environment
  cat <<DISCOVERY
CrashSimulator V2 discovery
  Version:           ${VERSION}
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
    info "  PDBs:"
    if [[ "${#PDB_ROWS[@]}" -eq 0 ]]; then
      info "    none found"
    else
      local row name con_id open_mode
      for row in "${PDB_ROWS[@]}"; do
        IFS='|' read -r name con_id open_mode <<<"$row"
        info "    ${name} (CON_ID=${con_id}, OPEN_MODE=${open_mode})"
      done
    fi
  fi
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
  register_scenario "46" "ASM data disk group unavailable"                   "ASM"        "ASM"        "destructive" "asm"               "scenario_planned"           "Gated for an ASM test environment."
  register_scenario "47" "OCR loss or restore drill"                         "GI"         "Cluster"    "destructive" "gi"                "scenario_planned"           "Gated for a Grid Infrastructure test environment."
  register_scenario "48" "Voting disk loss or restore drill"                 "GI"         "Cluster"    "destructive" "gi"                "scenario_planned"           "Gated for a Grid Infrastructure test environment."
  register_scenario "49" "ASM SPFILE loss"                                   "ASM"        "ASM"        "destructive" "asm"               "scenario_planned"           "Gated for an ASM test environment."
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
  register_scenario "60" "Recovery catalog unavailable"                      "Backup"     "External"   "logical"      "any"               "scenario_planned"           "Usually simulated outside the target database."
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

select_pdb_if_needed() {
  if [[ "$DB_CDB" != "YES" ]]; then
    return "$FAIL"
  fi
  if [[ -n "$TARGET_PDB" ]]; then
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
    1|2|3|4|5|6|7|14|16|17|18|19|20|21|23|24|25|26|30|31|32|39|41|59) return "$SUCCESS" ;;
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
  count="$(manifest_get "planned_action_count" || true)"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0

  idx=1
  while [[ "$idx" -le "$count" ]]; do
    file_no="$(manifest_get "action_${idx}_file_no" || true)"
    if [[ -n "$file_no" ]]; then
      [[ "$file_no" =~ ^[0-9]+$ ]] || die "Manifest has invalid FILE# for action_${idx}: $file_no"
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
  write_recover_rman_file "$id" "$file_no" "$cmd_file"
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
  write_recover_datafile_list_rman_file "$file_list" "$cmd_file"
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

  local sql_file sql_log rman_file rman_log
  load_manifest_restore_pairs ||
    die "Manifest is missing redo restore paths. Use a manifest from an executed scenario run."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_redo.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_redo.log"
  write_redo_validation_sql_file "$sql_file"
  manifest_append "recover_redo_validate_sqlfile" "$sql_file"
  manifest_append "recover_redo_validate_log" "$sql_log"

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_database.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_database.log"
  write_redo_validation_rman_file "$rman_file"
  manifest_append "recover_redo_validate_rman" "$rman_file"
  manifest_append "recover_redo_validate_rman_log" "$rman_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Redo member restore count: ${#RESTORE_ORIGINALS[@]}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  copy_restore_pairs_to_originals
  force_database_open
  run_sql_script_file "$sql_file" "$sql_log"
  run_rman_cmdfile "$rman_file" "$rman_log"

  safe_remove_restore_backups
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
    59)
      recover_archivelog_scenario "$id"
      ;;
  esac
}

print_runbook_only() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"

  echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Group: ${SCENARIO_GROUP[$id]}"
  echo "Scope: ${SCENARIO_SCOPE[$id]}"
  echo "Impact: ${SCENARIO_IMPACT[$id]}"
  echo "Requires: ${SCENARIO_REQUIRES[$id]}"
  echo "Notes: ${SCENARIO_NOTES[$id]}"
  echo
  print_recovery_runbook "$id"
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
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$log_file" ||
    die "Health check failed: $sql_file (log: $log_file)"

  sed 's/^/  /' "$log_file"
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
  local owner_filter=""
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and i.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
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
  add_action "sql" "$sql_text" "drop non-unique indexes"
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
  local owner_filter=""
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and i.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
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
  add_action "sql" "$sql_text" "drop PDB non-unique indexes"
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
  local owner_filter=""
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
  local owner_filter=""
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

scenario_standby_apply_cancel() {
  reset_actions
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
  add_action "srvctl_abort_instance" "$INSTANCE_NAME" "abort current RAC instance"
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
  echo "Scenario 25 guards: local-only=${LOCAL_ONLY}  max-targets=${MAX_TARGETS:-not set}  piece-handle=$([[ -n "$PIECE_HANDLE" ]] && echo set || echo not-set)"
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
    echo "  9. Clear selected scenario and targets"
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
  local arg
  printf "Running:"
  for arg in "${MENU_CMD[@]}"; do
    printf " %q" "$arg"
  done
  printf "\n"
}

menu_run_child_command() {
  local status
  menu_print_child_command
  echo
  env CRASHSIM_SYS_PASSWORD="$SYS_PASSWORD" "${MENU_CMD[@]}"
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

menu_run_health_check() {
  MENU_CMD=("$0" "--health-check")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_show_recent_artifacts() {
  echo
  echo "Recent files in ${LOG_DIR}:"
  find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.manifest' -o -name '*.log' -o -name '*.rman' -o -name '*.sql' \) 2>/dev/null |
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
    echo "  1. Discover or refresh database topology"
    echo "  2. Select scenario"
    echo "  3. List all scenarios"
    echo "  4. Show recovery runbook for selected scenario"
    echo "  5. Dry-run selected scenario"
    echo "  6. Dry-run protection for selected scenario"
    echo "  7. Execute protection for selected scenario"
    echo "  8. Execute selected scenario"
    echo "  9. Dry-run recovery for selected scenario"
    echo " 10. Execute recovery for selected scenario"
    echo " 11. Run health check / validation"
    echo " 12. Configure targets and options"
    echo " 13. Show recent manifests and logs"
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
    runbook)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_runbook_only "$SCENARIO_ID"
      ;;
    scenario)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      run_scenario "$SCENARIO_ID"
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
