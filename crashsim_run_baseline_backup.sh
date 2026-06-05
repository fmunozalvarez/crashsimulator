#!/usr/bin/env bash
#
# CrashSimulator fresh baseline backup helper.
#
# Creates a new RMAN baseline backup for the current target database using the
# configured RMAN channels. Dry-run is the default; --execute requires a typed
# confirmation unless --yes is supplied by automation.

set -uo pipefail

VERSION="2.0.0-dev"
SUCCESS=0
FAIL=1

PROGRAM="$(basename "$0")"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
TAG_STAMP="$(date -u +%y%m%d%H%M%S)"
EXECUTE=0
ASSUME_YES=0
VERBOSE=0
LOG_DIR="${CRASHSIM_LOG_DIR:-}"
TAG_PREFIX="${CRASHSIM_BASELINE_TAG_PREFIX:-CSIM_BASE}"
RMAN_CATALOG_CONNECT="${CRASHSIM_RMAN_CATALOG:-}"
RMAN_BIN="${RMAN:-}"
WORK_DIR=""

usage() {
  cat <<USAGE
CrashSimulator baseline backup helper ${VERSION}

Usage:
  ./${PROGRAM} [--dry-run|--execute] [--yes]

Options:
  --dry-run               Plan only. This is the default.
  --execute               Run the RMAN baseline backup.
  --yes                   Skip typed confirmation. Use only in trusted automation.
  --log-dir <dir>         Directory for logs. Defaults to ./crashsimulator_logs.
  --tag-prefix <prefix>   RMAN tag prefix. Default: CSIM_BASE. Maximum 11 chars.
  --rman-catalog <str>    RMAN recovery catalog connect string.
  --verbose               Print extra diagnostics.
  --help                  Show this help.

Environment:
  CRASHSIM_LOG_DIR              Default log directory.
  CRASHSIM_BASELINE_TAG_PREFIX  Default RMAN tag prefix.
  CRASHSIM_RMAN_CATALOG         RMAN recovery catalog connect string.
  RMAN                          RMAN executable override.

Generated RMAN tags:
  <prefix>_YYMMDDHH24MISS
  <prefix>_YYMMDDHH24MISS_ARCH
  <prefix>_YYMMDDHH24MISS_CTL
  <prefix>_YYMMDDHH24MISS_SPFILE

The helper uses BACKUP ... DATABASE FORCE so a fresh baseline is created even
when RMAN backup optimization is enabled.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit "$FAIL"
}

warn() {
  echo "WARN: $*" >&2
}

debug() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "DEBUG: $*" >&2
  fi
}

cleanup() {
  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

redact_rman_catalog_connect() {
  local connect="$1"
  if [[ -z "$connect" ]]; then
    return "$SUCCESS"
  fi
  printf "%s" "$connect" | sed -E 's#^([^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#'
}

validate_tag_prefix() {
  TAG_PREFIX="$(printf "%s" "$TAG_PREFIX" | tr '[:lower:]' '[:upper:]')"
  [[ "$TAG_PREFIX" =~ ^[A-Z0-9_]{1,11}$ ]] ||
    die "Invalid tag prefix '${TAG_PREFIX}'. Use 1-11 characters: A-Z, 0-9, underscore."
}

ensure_runtime() {
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="$(pwd)/crashsimulator_logs"
  fi
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/crashsim_baseline.${RUN_ID}.XXXXXX")" ||
    die "Unable to create temporary directory"
  trap cleanup EXIT
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

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
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
      --tag-prefix|--backup-tag-prefix|--baseline-tag-prefix)
        [[ "$#" -ge 2 ]] || die "$1 requires a tag prefix"
        TAG_PREFIX="$2"
        shift 2
        ;;
      --rman-catalog)
        [[ "$#" -ge 2 ]] || die "--rman-catalog requires a recovery catalog connect string"
        RMAN_CATALOG_CONNECT="$2"
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

write_rman_commands() {
  local cmd_file="$1"
  local catalog_connect="$2"
  local tag="$3"
  local catalog_redacted
  catalog_redacted="$(redact_rman_catalog_connect "$catalog_connect")"

  {
    if [[ -n "$catalog_connect" ]]; then
      printf "connect catalog %s\n" "$catalog_connect"
      printf "resync catalog;\n"
    fi
    printf "run {\n"
    printf "  sql \"alter system archive log current\";\n"
    printf "  backup as compressed backupset database force tag '%s';\n" "$tag"
    printf "  sql \"alter system archive log current\";\n"
    printf "  backup as compressed backupset archivelog all not backed up 1 times tag '%s_ARCH';\n" "$tag"
    printf "  backup current controlfile tag '%s_CTL';\n" "$tag"
    printf "  backup spfile tag '%s_SPFILE';\n" "$tag"
    printf "}\n"
    if [[ -n "$catalog_connect" ]]; then
      printf "resync catalog;\n"
    fi
    printf "list backup tag '%s';\n" "$tag"
    printf "list backup tag '%s_ARCH';\n" "$tag"
    printf "list backup tag '%s_CTL';\n" "$tag"
    printf "list backup tag '%s_SPFILE';\n" "$tag"
    printf "report schema;\n"
  } >"$cmd_file" || die "Unable to write RMAN command file: $cmd_file"

  if [[ -n "$catalog_connect" && "$catalog_connect" != "$catalog_redacted" ]]; then
    sed -E 's#^(connect catalog [^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#I' "$cmd_file"
  else
    cat "$cmd_file"
  fi
}

confirm_execution() {
  local tag="$1"
  if [[ "$EXECUTE" -eq 0 || "$ASSUME_YES" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  echo
  echo "About to run a fresh RMAN baseline backup."
  echo "Backup tag: ${tag}"
  echo "This is not destructive, but it can consume I/O, backup storage, and SBT/Object Storage bandwidth."
  echo "Type BASELINE-BACKUP to continue:"
  local answer
  read -r answer
  [[ "$answer" == "BASELINE-BACKUP" ]] || die "Confirmation did not match. Aborting."
}

scan_rman_log_for_errors() {
  local log_file="$1"
  if grep -Eq 'RMAN-00569|RMAN-03002|RMAN-03009|ORA-[0-9]{5}' "$log_file"; then
    die "RMAN baseline backup log contains errors. Review: $log_file"
  fi
}

run_baseline_backup() {
  local tag cmd_file actual_cmd_file display_cmd_file log_file catalog_redacted status
  tag="${TAG_PREFIX}_${TAG_STAMP}"
  cmd_file="${LOG_DIR}/crashsim_baseline_backup_${RUN_ID}.rman"
  log_file="${LOG_DIR}/crashsim_baseline_backup_${RUN_ID}.log"
  catalog_redacted="$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"

  if [[ -n "$RMAN_CATALOG_CONNECT" ]]; then
    actual_cmd_file="${WORK_DIR}/crashsim_baseline_backup_${RUN_ID}.rman"
    display_cmd_file="$cmd_file"
    write_rman_commands "$actual_cmd_file" "$RMAN_CATALOG_CONNECT" "$tag" >"$display_cmd_file"
  else
    actual_cmd_file="$cmd_file"
    display_cmd_file="$cmd_file"
    write_rman_commands "$actual_cmd_file" "" "$tag" >/dev/null
  fi

  echo "CrashSimulator fresh baseline backup"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Tag prefix: ${TAG_PREFIX}"
  echo "Backup tag: ${tag}"
  echo "RMAN catalog: $([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "configured (%s)" "$catalog_redacted" || printf "not configured")"
  echo "RMAN command file: ${display_cmd_file}"
  echo "RMAN log file: ${log_file}"
  echo

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run RMAN target / with this command file:"
    echo
    sed 's/^/  /' "$display_cmd_file"
    return "$SUCCESS"
  fi

  confirm_execution "$tag"
  ensure_rman
  debug "Using RMAN: $RMAN_BIN"

  "$RMAN_BIN" target / cmdfile="$actual_cmd_file" log="$log_file"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    die "RMAN baseline backup failed with status ${status}. Review: $log_file"
  fi
  scan_rman_log_for_errors "$log_file"

  echo "Baseline backup completed successfully."
  echo "Backup tag: ${tag}"
  echo "Log file: ${log_file}"
  echo "Command file: ${display_cmd_file}"
}

main() {
  parse_args "$@"
  validate_tag_prefix
  ensure_runtime
  run_baseline_backup
}

main "$@"
