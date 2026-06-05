#!/usr/bin/env bash
#
# CrashSimulator redundant GI/ASM lab preparation helper.
#
# This helper is intentionally conservative. It can inspect a RAC/GI/ASM
# environment, build a NORMAL/HIGH redundancy ASM disk group plan from supplied
# shared disk paths, and optionally execute the disk group creation. OCR and
# voting-disk placement actions require separate explicit flags.

set -uo pipefail

VERSION="2.0.0-dev"
SUCCESS=0
FAIL=1

PROGRAM="$(basename "$0")"
RUN_ID="$(date +%Y%m%d_%H%M%S)"
EXECUTE=0
ASSUME_YES=0
CREATE_DISKGROUP=0
ADD_OCR=0
REPLACE_VOTEDISK=0
BACKUP_ASM_SPFILE=0
SCAN_ONLY=0
DG_NAME="${CRASHSIM_GI_LAB_DG:-CRASHGI}"
REDUNDANCY="${CRASHSIM_GI_LAB_REDUNDANCY:-NORMAL}"
GRID_HOME="${GRID_HOME:-}"
GRID_USER="${CRASHSIM_GRID_USER:-grid}"
ASM_SID="${CRASHSIM_ASM_SID:-}"
LOG_DIR="${CRASHSIM_LOG_DIR:-}"
PLAN_FILE=""
SQL_FILE=""

declare -a REGULAR_FG_SPECS=()
declare -a QUORUM_FG_SPECS=()

usage() {
  cat <<USAGE
CrashSimulator redundant GI/ASM lab preparation helper ${VERSION}

Usage:
  ./${PROGRAM} --scan
  ./${PROGRAM} --diskgroup CRASHGI --redundancy NORMAL \\
    --failure-group FG1:/dev/disk/by-id/scsi-... \\
    --failure-group FG2:/dev/disk/by-id/scsi-... \\
    --quorum-failure-group FGQ:/dev/disk/by-id/scsi-... \\
    --create-diskgroup [--dry-run|--execute]

Options:
  --scan                       Inspect current GI/ASM/OCR/voting posture.
  --dry-run                    Plan only. This is the default.
  --execute                    Execute requested changes after confirmation.
  --yes                        Skip typed confirmation. Use only in trusted automation.
  --diskgroup <name>           New redundant disk group name. Default: CRASHGI.
  --redundancy NORMAL|HIGH     ASM redundancy for the new disk group. Default: NORMAL.
  --failure-group <fg:paths>   Regular failure group and comma-separated disk paths.
                               Repeat this option for each failure group.
  --quorum-failure-group <fg:paths>
                               Quorum failure group and comma-separated disk paths.
                               Repeat when needed for Clusterware metadata.
  --create-diskgroup           Create the ASM disk group from supplied paths.
  --add-ocr                    Add the new disk group as an OCR location.
  --replace-votedisk           Replace voting disks into the new disk group.
  --backup-asm-spfile          Back up the current ASM SPFILE into the new disk group.
  --grid-home <path>           Grid home override.
  --grid-user <user>           Grid owner. Default: grid.
  --asm-sid <sid>              ASM SID override, for example +ASM1.
  --log-dir <dir>              Directory for generated plan files.
  --help                       Show this help.

Safety:
  - Existing EXTERN disk groups cannot be converted to NORMAL or HIGH.
  - The helper never uses FORCE when creating a disk group.
  - All disk paths must already exist as shared block devices on every RAC node.
  - OCR/voting actions require root privileges and explicit flags.
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
  echo "INFO: $*"
}

uppercase() {
  printf "%s" "$1" | tr '[:lower:]' '[:upper:]'
}

sanitize_name() {
  local value="$1"
  value="$(uppercase "$value" | sed -E 's/[^A-Z0-9_]/_/g')"
  value="$(printf "%s" "$value" | sed -E 's/^_+//;s/_+$//')"
  [[ -n "$value" ]] || value="FG"
  printf "%.24s" "$value"
}

confirm_or_die() {
  local token="$1"
  local reply
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return "$SUCCESS"
  fi
  echo
  echo "Type ${token} to continue:"
  read -r reply
  [[ "$reply" == "$token" ]] || die "Confirmation token did not match; aborting."
}

detect_grid_home() {
  local tool
  if [[ -n "$GRID_HOME" ]]; then
    [[ -x "${GRID_HOME}/bin/asmcmd" || -x "${GRID_HOME}/bin/crsctl" ]] ||
      die "GRID_HOME does not look valid: $GRID_HOME"
    return "$SUCCESS"
  fi
  for tool in asmcmd crsctl srvctl; do
    if command -v "$tool" >/dev/null 2>&1; then
      GRID_HOME="$(cd "$(dirname "$(command -v "$tool")")/.." >/dev/null 2>&1 && pwd)"
      [[ -n "$GRID_HOME" ]] && return "$SUCCESS"
    fi
  done
  for GRID_HOME in /u01/app/19.0.0.0/gridhome_1 /u01/app/19.0.0.0/grid /u01/app/grid/product/19.0.0/grid; do
    [[ -x "${GRID_HOME}/bin/asmcmd" || -x "${GRID_HOME}/bin/crsctl" ]] && return "$SUCCESS"
  done
  die "Unable to discover Grid home. Use --grid-home."
}

detect_asm_sid() {
  if [[ -n "$ASM_SID" ]]; then
    return "$SUCCESS"
  fi
  ASM_SID="$(pgrep -af 'asm_pmon_' 2>/dev/null | awk -F'asm_pmon_' 'NF > 1 {print $2; exit}')"
  [[ -n "$ASM_SID" ]] || ASM_SID="+ASM"
}

run_as_grid() {
  detect_grid_home
  detect_asm_sid
  if [[ "$(id -un)" == "$GRID_USER" ]]; then
    env ORACLE_HOME="$GRID_HOME" ORACLE_SID="$ASM_SID" PATH="${GRID_HOME}/bin:${PATH}" "$@"
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required to run Grid commands as ${GRID_USER}."
    sudo -n -u "$GRID_USER" env ORACLE_HOME="$GRID_HOME" ORACLE_SID="$ASM_SID" PATH="${GRID_HOME}/bin:${PATH}" "$@"
  fi
}

run_as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    "$@"
  else
    command -v sudo >/dev/null 2>&1 || die "sudo is required for root Grid Infrastructure commands."
    sudo -n "$@"
  fi
}

print_cmd_output() {
  local title="$1"
  shift
  echo
  echo "## ${title}"
  if "$@" 2>&1 | sed 's/^/  /'; then
    return "$SUCCESS"
  fi
  warn "Unable to collect ${title}."
}

ensure_runtime() {
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="$(pwd)/crashsimulator_logs"
  fi
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  PLAN_FILE="${LOG_DIR}/crashsim_redundant_gi_lab_${RUN_ID}.plan"
  SQL_FILE="${LOG_DIR}/crashsim_create_${DG_NAME}_${RUN_ID}.sql"
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --scan)
        SCAN_ONLY=1
        shift
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
      --diskgroup)
        [[ "$#" -ge 2 ]] || die "--diskgroup requires a name"
        DG_NAME="$2"
        shift 2
        ;;
      --redundancy)
        [[ "$#" -ge 2 ]] || die "--redundancy requires NORMAL or HIGH"
        REDUNDANCY="$2"
        shift 2
        ;;
      --failure-group|--failgroup)
        [[ "$#" -ge 2 ]] || die "$1 requires fg:path[,path]"
        REGULAR_FG_SPECS+=("$2")
        shift 2
        ;;
      --quorum-failure-group|--quorum-failgroup)
        [[ "$#" -ge 2 ]] || die "$1 requires fg:path[,path]"
        QUORUM_FG_SPECS+=("$2")
        shift 2
        ;;
      --create-diskgroup)
        CREATE_DISKGROUP=1
        shift
        ;;
      --add-ocr)
        ADD_OCR=1
        shift
        ;;
      --replace-votedisk)
        REPLACE_VOTEDISK=1
        shift
        ;;
      --backup-asm-spfile)
        BACKUP_ASM_SPFILE=1
        shift
        ;;
      --grid-home)
        [[ "$#" -ge 2 ]] || die "--grid-home requires a path"
        GRID_HOME="$2"
        shift 2
        ;;
      --grid-user)
        [[ "$#" -ge 2 ]] || die "--grid-user requires a user"
        GRID_USER="$2"
        shift 2
        ;;
      --asm-sid)
        [[ "$#" -ge 2 ]] || die "--asm-sid requires a SID"
        ASM_SID="$2"
        shift 2
        ;;
      --log-dir)
        [[ "$#" -ge 2 ]] || die "--log-dir requires a directory"
        LOG_DIR="$2"
        shift 2
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

validate_options() {
  DG_NAME="$(sanitize_name "$DG_NAME")"
  REDUNDANCY="$(uppercase "$REDUNDANCY")"
  case "$REDUNDANCY" in
    NORMAL|HIGH) ;;
    *) die "--redundancy must be NORMAL or HIGH" ;;
  esac
  if [[ "$CREATE_DISKGROUP" -eq 1 || "$ADD_OCR" -eq 1 || "$REPLACE_VOTEDISK" -eq 1 || "$BACKUP_ASM_SPFILE" -eq 1 ]]; then
    [[ "$SCAN_ONLY" -eq 0 ]] || die "--scan cannot be combined with change requests"
  fi
  if [[ "$CREATE_DISKGROUP" -eq 1 && "${#REGULAR_FG_SPECS[@]}" -eq 0 ]]; then
    die "--create-diskgroup requires at least two/three --failure-group options"
  fi
  if [[ "$ADD_OCR" -eq 1 || "$REPLACE_VOTEDISK" -eq 1 || "$BACKUP_ASM_SPFILE" -eq 1 ]]; then
    [[ -n "$DG_NAME" ]] || die "A target disk group is required"
  fi
}

split_spec() {
  local spec="$1"
  local name="${spec%%:*}"
  local paths="${spec#*:}"
  [[ "$spec" == *:* && -n "$name" && -n "$paths" ]] ||
    die "Invalid failure group spec '${spec}'. Expected fg:path[,path]"
  printf "%s|%s" "$(sanitize_name "$name")" "$paths"
}

validate_disk_path() {
  local path="$1"
  [[ -e "$path" ]] || die "Disk path does not exist on this node: $path"
  [[ -b "$path" ]] || die "Disk path is not a block device: $path"
  if lsblk -no MOUNTPOINT "$path" 2>/dev/null | grep -q '[^[:space:]]'; then
    die "Disk path appears mounted or has mounted children: $path"
  fi
  if blkid "$path" >/dev/null 2>&1; then
    warn "Disk path has existing metadata according to blkid: $path"
    warn "Do not use it unless it is a newly provisioned candidate disk."
  fi
}

count_paths_in_specs() {
  local count=0 spec parsed paths path
  for spec in "$@"; do
    parsed="$(split_spec "$spec")"
    paths="${parsed#*|}"
    IFS=',' read -r -a path_array <<<"$paths"
    for path in "${path_array[@]}"; do
      [[ -n "$path" ]] && count=$((count + 1))
    done
  done
  echo "$count"
}

validate_failure_groups() {
  local regular_count quorum_count total_count
  regular_count="${#REGULAR_FG_SPECS[@]}"
  quorum_count="${#QUORUM_FG_SPECS[@]}"
  total_count=$((regular_count + quorum_count))

  if [[ "$CREATE_DISKGROUP" -eq 0 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$REDUNDANCY" == "NORMAL" && "$regular_count" -lt 2 ]]; then
    die "NORMAL redundancy requires at least two regular failure groups."
  fi
  if [[ "$REDUNDANCY" == "HIGH" && "$regular_count" -lt 3 ]]; then
    die "HIGH redundancy requires at least three regular failure groups."
  fi
  if [[ "$ADD_OCR" -eq 1 || "$REPLACE_VOTEDISK" -eq 1 ]]; then
    [[ "$total_count" -ge 3 ]] ||
      die "Clusterware OCR/voting placement should use at least three total failure groups."
  fi
}

validate_local_disks() {
  local spec parsed paths path
  for spec in "${REGULAR_FG_SPECS[@]}" "${QUORUM_FG_SPECS[@]}"; do
    [[ -n "$spec" ]] || continue
    parsed="$(split_spec "$spec")"
    paths="${parsed#*|}"
    IFS=',' read -r -a path_array <<<"$paths"
    for path in "${path_array[@]}"; do
      validate_disk_path "$path"
    done
  done
}

emit_disk_clauses() {
  local kind="$1"
  shift
  local spec parsed fg paths path disk_index disk_name prefix first_disk
  for spec in "$@"; do
    [[ -n "$spec" ]] || continue
    parsed="$(split_spec "$spec")"
    fg="${parsed%%|*}"
    paths="${parsed#*|}"
    prefix="$(sanitize_name "${DG_NAME}_${fg}")"
    if [[ "$kind" == "QUORUM" ]]; then
      printf "  QUORUM FAILGROUP %s DISK\n" "$fg"
    else
      printf "  FAILGROUP %s DISK\n" "$fg"
    fi
    IFS=',' read -r -a path_array <<<"$paths"
    disk_index=1
    first_disk=1
    for path in "${path_array[@]}"; do
      disk_name="$(printf "%.24s_%02d" "$prefix" "$disk_index")"
      if [[ "$first_disk" -eq 0 ]]; then
        printf ",\n"
      fi
      printf "    '%s' NAME %s" "$path" "$disk_name"
      first_disk=0
      disk_index=$((disk_index + 1))
    done
    printf "\n"
  done
}

write_create_diskgroup_sql() {
  {
    echo "set echo on"
    echo "set timing on"
    echo "whenever sqlerror exit failure"
    echo "CREATE DISKGROUP ${DG_NAME} ${REDUNDANCY} REDUNDANCY"
    emit_disk_clauses "REGULAR" "${REGULAR_FG_SPECS[@]}"
    emit_disk_clauses "QUORUM" "${QUORUM_FG_SPECS[@]}"
    echo "  ATTRIBUTE 'compatible.asm'='19.0.0.0.0',"
    echo "            'compatible.rdbms'='19.0.0.0.0',"
    echo "            'au_size'='4M';"
    echo "select name, state, type, total_mb, free_mb from v\\$asm_diskgroup where name='${DG_NAME}';"
    echo "exit success"
  } >"$SQL_FILE" || die "Unable to write SQL file: $SQL_FILE"
}

write_plan() {
  {
    echo "# CrashSimulator Redundant GI/ASM Lab Plan"
    echo
    echo "Run timestamp: ${RUN_ID}"
    echo "Disk group: ${DG_NAME}"
    echo "Redundancy: ${REDUNDANCY}"
    echo "Regular failure groups: ${#REGULAR_FG_SPECS[@]}"
    echo "Quorum failure groups: ${#QUORUM_FG_SPECS[@]}"
    echo "Create disk group: ${CREATE_DISKGROUP}"
    echo "Add OCR location: ${ADD_OCR}"
    echo "Replace voting disks: ${REPLACE_VOTEDISK}"
    echo "Backup ASM SPFILE: ${BACKUP_ASM_SPFILE}"
    echo
    if [[ "$CREATE_DISKGROUP" -eq 1 ]]; then
      echo "## CREATE DISKGROUP SQL"
      echo
      cat "$SQL_FILE"
      echo
    fi
    echo "## Follow-up validation"
    echo
    echo "- asmcmd lsdg ${DG_NAME}"
    echo "- ocrcheck"
    echo "- ocrconfig -showbackup"
    echo "- crsctl query css votedisk"
    echo "- crsctl check cluster -all"
  } >"$PLAN_FILE" || die "Unable to write plan file: $PLAN_FILE"
}

scan_posture() {
  detect_grid_home
  detect_asm_sid
  echo "CrashSimulator redundant GI/ASM lab scan"
  echo "Grid home: ${GRID_HOME}"
  echo "ASM SID: ${ASM_SID}"
  print_cmd_output "Cluster check" run_as_grid "${GRID_HOME}/bin/crsctl" check cluster -all
  print_cmd_output "ASM disk groups" run_as_grid "${GRID_HOME}/bin/asmcmd" lsdg
  print_cmd_output "ASM disks" run_as_grid "${GRID_HOME}/bin/asmcmd" lsdsk -p
  print_cmd_output "OCR check" run_as_root "${GRID_HOME}/bin/ocrcheck"
  print_cmd_output "OCR backups" run_as_root "${GRID_HOME}/bin/ocrconfig" -showbackup
  print_cmd_output "Voting disks" run_as_root "${GRID_HOME}/bin/crsctl" query css votedisk
  print_cmd_output "ASM SPFILE" run_as_grid "${GRID_HOME}/bin/asmcmd" spget
}

execute_create_diskgroup() {
  local token status
  token="CREATE_${DG_NAME}"
  confirm_or_die "$token"
  info "Creating ASM disk group ${DG_NAME}; SQL log will be beside ${SQL_FILE}."
  run_as_grid "${GRID_HOME}/bin/sqlplus" -s "/ as sysasm" @"$SQL_FILE"
  status=$?
  [[ "$status" -eq 0 ]] || die "CREATE DISKGROUP failed with status ${status}."
}

execute_add_ocr() {
  local token
  token="ADD_OCR_${DG_NAME}"
  confirm_or_die "$token"
  info "Adding OCR location +${DG_NAME}."
  run_as_root "${GRID_HOME}/bin/ocrconfig" -add "+${DG_NAME}" ||
    die "ocrconfig -add +${DG_NAME} failed."
  run_as_root "${GRID_HOME}/bin/ocrcheck"
}

execute_replace_votedisk() {
  local token
  token="REPLACE_VOTEDISK_${DG_NAME}"
  confirm_or_die "$token"
  info "Replacing voting disks into +${DG_NAME}."
  run_as_root "${GRID_HOME}/bin/crsctl" replace votedisk "+${DG_NAME}" ||
    die "crsctl replace votedisk +${DG_NAME} failed."
  run_as_root "${GRID_HOME}/bin/crsctl" query css votedisk
}

execute_backup_asm_spfile() {
  local source target stamp
  stamp="$(date -u +%Y%m%d_%H%M%S)"
  source="$(run_as_grid "${GRID_HOME}/bin/asmcmd" spget 2>/dev/null | awk 'NF {print; exit}')"
  [[ -n "$source" ]] || die "Unable to discover ASM SPFILE with asmcmd spget."
  target="+${DG_NAME}/crashsimu/asm_spfile_backup_${stamp}.bak"
  info "Backing up ASM SPFILE from ${source} to ${target}."
  run_as_grid "${GRID_HOME}/bin/asmcmd" mkdir "+${DG_NAME}/crashsimu" >/dev/null 2>&1 || true
  run_as_grid "${GRID_HOME}/bin/asmcmd" spbackup "$source" "$target" ||
    die "ASM SPFILE backup failed."
}

main() {
  parse_args "$@"
  validate_options
  detect_grid_home
  detect_asm_sid
  ensure_runtime

  if [[ "$SCAN_ONLY" -eq 1 || ( "$CREATE_DISKGROUP" -eq 0 && "$ADD_OCR" -eq 0 && "$REPLACE_VOTEDISK" -eq 0 && "$BACKUP_ASM_SPFILE" -eq 0 ) ]]; then
    scan_posture | tee "$PLAN_FILE"
    echo
    echo "Scan saved to: $PLAN_FILE"
    return "$SUCCESS"
  fi

  validate_failure_groups
  validate_local_disks
  if [[ "$CREATE_DISKGROUP" -eq 1 ]]; then
    write_create_diskgroup_sql
  fi
  write_plan
  echo "Plan saved to: $PLAN_FILE"
  [[ "$CREATE_DISKGROUP" -eq 1 ]] && echo "SQL saved to: $SQL_FILE"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN complete. Re-run with --execute to perform requested changes."
    return "$SUCCESS"
  fi

  [[ "$CREATE_DISKGROUP" -eq 1 ]] && execute_create_diskgroup
  [[ "$ADD_OCR" -eq 1 ]] && execute_add_ocr
  [[ "$REPLACE_VOTEDISK" -eq 1 ]] && execute_replace_votedisk
  [[ "$BACKUP_ASM_SPFILE" -eq 1 ]] && execute_backup_asm_spfile
  scan_posture
}

main "$@"
