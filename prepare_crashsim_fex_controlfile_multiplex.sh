#!/usr/bin/env bash
set -uo pipefail

PROGRAM="$(basename "$0")"
MODE="dry-run"
DEST=""
NEW_CONTROL_FILE_OVERRIDE=""
LOG_DIR="${CRASHSIM_LOG_DIR:-./crashsimulator_logs}"
CONFIRM_TOKEN="FEX-CONTROLFILE-MULTIPLEX"
YES=0
VERBOSE=0

usage() {
  cat <<USAGE
Usage: ${PROGRAM} [--dry-run|--execute] [--new-control-file <fex_file>] [--log-dir <dir>] [--yes] [--verbose]

Prepare control-file multiplexing for Oracle OCI FEX managed-file storage.

The helper:
  1. inventories the current RAC database control-file posture;
  2. proposes a second concrete FEX control-file handle; and
  3. writes a provider-aware runbook for an offline, byte-for-byte control-file copy.

Important:
  ALTER DATABASE BACKUP CONTROLFILE creates a backup control file, not a valid
  active multiplex member. Do not use it for CONTROL_FILES multiplexing on FEX.
  In OCI/FEX deployments where the @... database-file namespace is not exposed
  to cp/asmcmd, the copy step must use a provider-approved byte-copy operation
  or a controlled CREATE CONTROLFILE rebuild runbook.

Execution requires confirmation. Either pass --yes and set:

  CRASHSIM_CONFIRM=FEX-CONTROLFILE-MULTIPLEX

or type the token at the prompt.

Environment:
  ORACLE_HOME            Required unless sqlplus/rman are already in PATH.
  ORACLE_SID             Required for local bequeath connection.
  CRASHSIM_GRID_HOME     Optional Grid home. If unset, the helper searches common paths.
  CRASHSIM_NEW_CONTROL_FILE
                         Optional full FEX file handle to use for the second control file.
                         If unset, the helper creates a new file beside the current
                         FEX control-file handle.
USAGE
}

log() { printf '%s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) MODE="dry-run"; shift ;;
    --execute) MODE="execute"; shift ;;
    --dest)
      [[ $# -ge 2 ]] || die "--dest requires a value"
      DEST="$2"; shift 2 ;;
    --new-control-file)
      [[ $# -ge 2 ]] || die "--new-control-file requires a value"
      NEW_CONTROL_FILE_OVERRIDE="$2"; shift 2 ;;
    --log-dir)
      [[ $# -ge 2 ]] || die "--log-dir requires a value"
      LOG_DIR="$2"; shift 2 ;;
    --yes|-y) YES=1; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

[[ -n "${DEST}" ]] || DEST="${CRASHSIM_CONTROLFILE_DEST:-}"
[[ -n "${NEW_CONTROL_FILE_OVERRIDE}" ]] || NEW_CONTROL_FILE_OVERRIDE="${CRASHSIM_NEW_CONTROL_FILE:-}"

if [[ -n "${ORACLE_HOME:-}" ]]; then
  export PATH="${ORACLE_HOME}/bin:${PATH}"
fi

SQLPLUS_BIN="${SQLPLUS:-$(command -v sqlplus 2>/dev/null || true)}"
[[ -n "$SQLPLUS_BIN" && -x "$SQLPLUS_BIN" ]] || die "sqlplus not found. Set ORACLE_HOME or SQLPLUS."
[[ -n "${ORACLE_SID:-}" ]] || die "ORACLE_SID is not set."

find_srvctl() {
  local candidate
  for candidate in \
    "${CRASHSIM_GRID_HOME:-}/bin/srvctl" \
    "${GRID_HOME:-}/bin/srvctl" \
    /u01/app/23.0.0.0/gridhome_1/bin/srvctl \
    /u01/app/21.0.0.0/gridhome_1/bin/srvctl \
    /u01/app/19.0.0.0/gridhome_1/bin/srvctl \
    "$(command -v srvctl 2>/dev/null || true)"; do
    [[ -n "$candidate" && -x "$candidate" ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  return 1
}

SRVCTL_BIN="$(find_srvctl || true)"
[[ -n "$SRVCTL_BIN" ]] || die "srvctl not found. Set CRASHSIM_GRID_HOME."

mkdir -p "$LOG_DIR" || die "Could not create log directory: $LOG_DIR"
RUN_ID="$(date -u +%Y%m%d_%H%M%S)"
WORK_DIR="${LOG_DIR}/controlfile_multiplex_${RUN_ID}"
mkdir -p "$WORK_DIR" || die "Could not create work directory: $WORK_DIR"

sql_scalar() {
  local stmt="$1"
  "$SQLPLUS_BIN" -s / as sysdba <<SQL
set heading off feedback off pages 0 verify off echo off trimspool on lines 32767
whenever sqlerror exit sql.sqlcode
${stmt}
exit
SQL
}

sql_run_file() {
  local sql_file="$1" log_file="$2"
  "$SQLPLUS_BIN" -s / as sysdba @"$sql_file" >"$log_file" </dev/null
}

DB_UNIQUE_NAME="$(sql_scalar 'select db_unique_name from v$database;' | awk 'NF {print $1; exit}')"
DB_NAME="$(sql_scalar 'select name from v$database;' | awk 'NF {print $1; exit}')"
CONTROL_COUNT="$(sql_scalar 'select count(*) from v$controlfile;' | awk 'NF {print $1; exit}')"
CURRENT_LIST="$(sql_scalar 'select listagg(name, chr(10)) within group (order by name) from v$controlfile;' | sed '/^[[:space:]]*$/d')"
RECOVERY_DEST="$(sql_scalar "select value from v\$parameter where name='db_recovery_file_dest';" | sed '/^[[:space:]]*$/d' | tail -1)"
DATA_DEST="$(sql_scalar "select value from v\$parameter where name='db_create_file_dest';" | sed '/^[[:space:]]*$/d' | tail -1)"
[[ -n "$DEST" ]] || DEST="$RECOVERY_DEST"

cat >"${WORK_DIR}/inventory.txt" <<EOF
CrashSimulator FEX control-file multiplex inventory
Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
Host: $(hostname)
Oracle SID: ${ORACLE_SID}
Oracle home: ${ORACLE_HOME:-<unset>}
Grid srvctl: ${SRVCTL_BIN}
Database name: ${DB_NAME}
DB unique name: ${DB_UNIQUE_NAME}
Current control-file count: ${CONTROL_COUNT}
DB create file dest: ${DATA_DEST:-<unset>}
DB recovery file dest: ${RECOVERY_DEST:-<unset>}
Selected new control-file destination: ${DEST:-<unset>}

Current control files:
${CURRENT_LIST}
EOF

log "Inventory: ${WORK_DIR}/inventory.txt"
sed 's/^/  /' "${WORK_DIR}/inventory.txt"

[[ -n "$DB_UNIQUE_NAME" ]] || die "Could not determine DB_UNIQUE_NAME."
[[ -n "$CONTROL_COUNT" ]] || die "Could not determine control-file count."

if [[ "$CONTROL_COUNT" -ge 2 ]]; then
  log "Control files are already multiplexed (count=${CONTROL_COUNT}). No SPFILE change required."
  exit 0
fi

FIRST_CONTROL_FILE="$(printf '%s\n' "$CURRENT_LIST" | awk 'NF {print; exit}')"
[[ -n "$FIRST_CONTROL_FILE" ]] || die "Could not identify the existing control file."
CONTROL_DIR="${FIRST_CONTROL_FILE%/*}"
if [[ -n "$NEW_CONTROL_FILE_OVERRIDE" ]]; then
  NEW_CONTROL_FILE="$NEW_CONTROL_FILE_OVERRIDE"
else
  NEW_CONTROL_FILE="${CONTROL_DIR}/crashsim_control02_${RUN_ID}.ctl"
fi

case "$NEW_CONTROL_FILE" in
  @*) ;;
  *) warn "Selected new control-file path does not look like an OCI FEX managed-file handle: $NEW_CONTROL_FILE" ;;
esac

RUNBOOK_FILE="${WORK_DIR}/fex_controlfile_multiplex_runbook.md"
cat >"$RUNBOOK_FILE" <<EOF
# FEX Control-File Multiplexing Runbook

Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Current Evidence

- Database unique name: \`${DB_UNIQUE_NAME}\`
- Existing control file: \`${FIRST_CONTROL_FILE}\`
- Proposed second control file: \`${NEW_CONTROL_FILE}\`
- Grid command: \`${SRVCTL_BIN}\`

## Required Method

FEX exposes Oracle database files as managed \`@...\` handles. On this host,
the database-file namespace is not exposed through \`cp\`, \`asmcmd\`, or the
visible DBaaS ACFS mount. A valid multiplexed control file must be a
byte-for-byte current control file copied while the database is stopped, or must
be recreated through an approved CREATE CONTROLFILE procedure.

Do not use:

\`\`\`sql
alter database backup controlfile to '${NEW_CONTROL_FILE}';
\`\`\`

That command creates a backup control file. It can be older than the current
control-file version at the next startup and can raise ORA-00214.

## Provider-Aware Offline Copy Pattern

1. Confirm a recent baseline backup and control-file autobackup.
2. Set the SPFILE target after the byte-copy method is approved:

\`\`\`sql
alter system set control_files='${FIRST_CONTROL_FILE}','${NEW_CONTROL_FILE}' scope=spfile sid='*';
\`\`\`

3. Stop the RAC database:

\`\`\`bash
${SRVCTL_BIN} stop database -d ${DB_UNIQUE_NAME} -o immediate
\`\`\`

4. Use the OCI/FEX/provider-approved byte-copy method to copy:

\`\`\`text
${FIRST_CONTROL_FILE}
to
${NEW_CONTROL_FILE}
\`\`\`

5. Start and validate:

\`\`\`bash
${SRVCTL_BIN} start database -d ${DB_UNIQUE_NAME}
\`\`\`

\`\`\`sql
select name from v\\\$controlfile order by name;
select inst_id, instance_name, status from gv\\\$instance order by inst_id;
select count(*) from v\\\$recover_file;
\`\`\`

## Rollback

If startup fails, start one instance NOMOUNT if needed, restore the original
SPFILE value, shut down, and start with srvctl:

\`\`\`sql
startup nomount;
alter system set control_files='${FIRST_CONTROL_FILE}' scope=spfile sid='*';
shutdown abort;
\`\`\`

\`\`\`bash
${SRVCTL_BIN} start database -d ${DB_UNIQUE_NAME}
\`\`\`
EOF

cat >"${WORK_DIR}/validate_after.sql" <<'SQL'
set lines 220 pages 200 trimspool on
whenever sqlerror exit sql.sqlcode
column name format a120
select name, open_mode, database_role, controlfile_type from v$database;
select inst_id, instance_name, status from gv$instance order by inst_id;
select name from v$controlfile order by name;
select con_id, name, open_mode from v$pdbs order by con_id;
select count(*) as recover_file_count from v$recover_file;
exit
SQL

if [[ "$MODE" != "execute" ]]; then
  log
  log "DRY-RUN: proposed second FEX control-file handle:"
  log "  ${NEW_CONTROL_FILE}"
  log "DRY-RUN: provider-aware runbook:"
  log "  ${RUNBOOK_FILE}"
  log "DRY-RUN: after a provider-approved byte copy is available, the planned RAC commands are:"
  log "  ${SRVCTL_BIN} stop database -d ${DB_UNIQUE_NAME} -o immediate"
  log "  ${SRVCTL_BIN} start database -d ${DB_UNIQUE_NAME}"
  log "DRY-RUN: would validate with ${WORK_DIR}/validate_after.sql"
  exit 0
fi

if [[ "${CRASHSIM_CONFIRM:-}" != "$CONFIRM_TOKEN" ]]; then
  if [[ "$YES" -eq 1 ]]; then
    die "Set CRASHSIM_CONFIRM=${CONFIRM_TOKEN} when using --yes."
  fi
  printf 'Type %s to continue: ' "$CONFIRM_TOKEN" >&2
  read -r typed
  [[ "$typed" == "$CONFIRM_TOKEN" ]] || die "Confirmation token did not match."
fi

die "Automated FEX control-file multiplexing is blocked because no provider-approved byte-copy utility is available on this host. Runbook: ${RUNBOOK_FILE}"

SET_SQL="${WORK_DIR}/set_control_files.sql"
{
  printf 'set echo on feedback on serveroutput on\n'
  printf 'whenever sqlerror exit sql.sqlcode\n'
  printf 'alter system set control_files='
  first=1
  while IFS= read -r cf; do
    [[ -n "$cf" ]] || continue
    [[ "$first" -eq 1 ]] || printf ','
    printf "'%s'" "$cf"
    first=0
  done <<<"$CURRENT_LIST"
  printf ",'%s' scope=spfile sid='*';\n" "$NEW_CONTROL_FILE"
  printf 'exit\n'
} >"$SET_SQL"

SET_LOG="${WORK_DIR}/set_control_files.log"
log "Updating CONTROL_FILES in SPFILE"
sql_run_file "$SET_SQL" "$SET_LOG" || die "Failed to update CONTROL_FILES. Log: $SET_LOG"

log "Restarting database ${DB_UNIQUE_NAME} with srvctl"
"$SRVCTL_BIN" stop database -d "$DB_UNIQUE_NAME" -o immediate >"${WORK_DIR}/srvctl_stop.log" 2>&1
stop_status=$?
if [[ "$stop_status" -ne 0 ]]; then
  warn "srvctl stop returned ${stop_status}; continuing to start validation. Log: ${WORK_DIR}/srvctl_stop.log"
fi

"$SRVCTL_BIN" start database -d "$DB_UNIQUE_NAME" >"${WORK_DIR}/srvctl_start.log" 2>&1
start_status=$?
if [[ "$start_status" -ne 0 ]]; then
  warn "srvctl start failed. Attempting to restore original CONTROL_FILES in SPFILE."
  "$SQLPLUS_BIN" -s / as sysdba <<SQL >"${WORK_DIR}/rollback_control_files.log" 2>&1
whenever sqlerror exit sql.sqlcode
startup nomount
alter system set control_files=$(printf "%s\n" "$CURRENT_LIST" | awk 'BEGIN{first=1} NF{gsub(/\047/, "\047\047", $0); if(!first) printf ","; printf "\047%s\047", $0; first=0}') scope=spfile sid='*';
shutdown abort
exit
SQL
  "$SRVCTL_BIN" start database -d "$DB_UNIQUE_NAME" >>"${WORK_DIR}/rollback_control_files.log" 2>&1 || true
  die "srvctl start failed after CONTROL_FILES update. Rollback attempted. Logs: ${WORK_DIR}"
fi

VALIDATE_LOG="${WORK_DIR}/validate_after.log"
log "Validating post-restart database state"
sql_run_file "${WORK_DIR}/validate_after.sql" "$VALIDATE_LOG" || die "Post-restart validation failed. Log: $VALIDATE_LOG"

FINAL_COUNT="$(sql_scalar 'select count(*) from v$controlfile;' | awk 'NF {print $1; exit}')"
[[ "$FINAL_COUNT" -ge 2 ]] || die "Post-restart control-file count is ${FINAL_COUNT}; expected at least 2. Logs: ${WORK_DIR}"

log "Control-file multiplexing completed. Final count: ${FINAL_COUNT}"
log "Evidence directory: ${WORK_DIR}"
[[ "$VERBOSE" -eq 1 ]] && sed 's/^/  /' "$VALIDATE_LOG"
