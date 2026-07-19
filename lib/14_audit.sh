audit_effective_dir() {
  if [[ -z "$AUDIT_DIR" ]]; then
    AUDIT_DIR="${LOG_DIR}/audit"
  fi
}

audit_stream_capture_enabled() {
  case "$AUDIT_STREAM_CAPTURE" in
    1) return "$SUCCESS" ;;
    0) return "$FAIL" ;;
    auto)
      if [[ "$MODE" == "menu" && -t 1 ]]; then
        return "$FAIL"
      fi
      return "$SUCCESS"
      ;;
  esac
  return "$FAIL"
}

audit_redact_stream() {
  # -u: line-buffered. Without it GNU sed block-buffers ~4KB when its stdout is
  # a pipe (to tee), which leaves interactive confirmation prompts stuck in the
  # buffer while `read` blocks - the operator sees a hang at the safety gate.
  sed -u -E \
    -e 's#(connect catalog[[:space:]]+[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's#(CRASHSIM_RMAN_CATALOG=[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's#(CRASHSIM_SYS_PASSWORD=)[^[:space:]]+#\1<redacted>#g' \
    -e 's#(([A-Za-z0-9_.-]*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][A-Za-z0-9_.-]*|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd])[[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g' \
    -e 's#(([A-Za-z0-9_.-]*[Tt][Oo][Kk][Ee][Nn][A-Za-z0-9_.-]*|[Tt][Oo][Kk][Ee][Nn])[[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g' \
    -e 's#(([A-Za-z0-9_.-]*[Ss][Ee][Cc][Rr][Ee][Tt][A-Za-z0-9_.-]*|[Ss][Ee][Cc][Rr][Ee][Tt])[[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g'
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
      --sys-password|--rman-catalog|--apex-session-password)
        printf " %q" "$arg"
        redact_next=1
        ;;
      --sys-password=*|--rman-catalog=*|--apex-session-password=*)
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
  metadata_file="${AUDIT_RUN_DIR}/metadata.env"
  command_file="${AUDIT_RUN_DIR}/command.redacted"
  env_file="${AUDIT_RUN_DIR}/environment.redacted"

  touch "$AUDIT_MARKER_FILE" "$AUDIT_STDOUT_FILE" "$AUDIT_STDERR_FILE" ||
    die "Unable to initialize audit files under: $AUDIT_RUN_DIR"

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
  if ! audit_stream_capture_enabled; then
    {
      echo "Live stdout/stderr capture was disabled for this run."
      echo "Reason: interactive guided menu terminal sessions use direct terminal I/O to avoid startup deadlocks."
      echo "Generated CrashSimulator artifacts are still collected under this audit run at finalization."
    } >"$AUDIT_STDOUT_FILE"
    echo "Audit logging enabled: ${AUDIT_RUN_DIR}"
    echo "Audit stream capture: disabled for interactive guided menu; generated artifacts will still be retained."
    return "$SUCCESS"
  fi

  exec > >(audit_redact_stream | tee -a "$AUDIT_STDOUT_FILE") \
    2> >(audit_redact_stream | tee -a "$AUDIT_STDERR_FILE" >&2)

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

  confirm_show "" \
    "About to purge CrashSimulator audit run folders older than ${AUDIT_RETENTION_DAYS} days." \
    "Audit directory: ${AUDIT_DIR}" \
    "Type PURGE-AUDIT-LOGS to continue:"
  local answer
  confirm_reply answer
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

find_sqlplus_if_available() {
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
  return "$FAIL"
}

ensure_sqlplus() {
  if find_sqlplus_if_available; then
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

find_dgmgrl_bin() {
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/dgmgrl" ]]; then
    printf "%s" "${ORACLE_HOME}/bin/dgmgrl"
    return "$SUCCESS"
  fi
  command -v dgmgrl 2>/dev/null || true
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
  mapfile -t TARGET_ROWS < <(trim_blank_lines <"$file" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
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
  RESTORE_METHODS=()

  local idx original backup method
  idx=1
  while true; do
    original="$(manifest_get "rename_${idx}_original" || true)"
    backup="$(manifest_get "rename_${idx}_backup" || true)"
    method="$(manifest_get "rename_${idx}_method" || true)"
    if [[ -z "$original" && -z "$backup" ]]; then
      break
    fi
    [[ -n "$original" && -n "$backup" ]] ||
      die "Manifest has an incomplete restore pair for rename_${idx}."
    RESTORE_ORIGINALS+=("$original")
    RESTORE_BACKUPS+=("$backup")
    RESTORE_METHODS+=("${method:-rename}")
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

move_restore_pairs_to_originals() {
  local idx original backup method
  for idx in "${!RESTORE_ORIGINALS[@]}"; do
    original="${RESTORE_ORIGINALS[$idx]}"
    backup="${RESTORE_BACKUPS[$idx]}"
    method="${RESTORE_METHODS[$idx]:-rename}"
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would move $backup back to $original"
    else
      [[ -e "$backup" ]] || die "Scenario backup not found: $backup"
      if [[ -e "$original" ]]; then
        warn "Original path already exists while restoring ${original}; leaving backup in place: ${backup}"
        continue
      fi
      if [[ "$method" == "ords_priv_config_rename" ]]; then
        run_ords_priv_helper config-restore "$backup" "$original" ||
          die "Unable to restore ORDS config with approved helper: $backup -> $original"
      else
        echo "mv -- $backup $original"
        mv -- "$backup" "$original" || die "Unable to restore $original from $backup"
      fi
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

tempfile_metadata_for_path() {
  local path="$1"
  local file="$WORK_DIR/tempfile_metadata.$(printf "%s" "$path" | cksum | awk '{print $1}').lst"
  local path_literal
  path_literal="$(sql_quote "$path")"

  if [[ "$DB_CDB" == "YES" ]]; then
    sql_query "$file" "
select c.name || '|' ||
       vf.con_id || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$tempfile vf
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
from v\$tempfile vf
left join v\$tablespace ts
  on ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  fi

  local line pdb_name con_id file_no tablespace tempfile_name
  line="$(trim_blank_lines <"$file" | head -n 1)"
  IFS='|' read -r pdb_name con_id file_no tablespace tempfile_name <<<"$line"
  [[ -n "$tempfile_name" && "$file_no" =~ ^[0-9]+$ ]] || return "$FAIL"
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

  local idx action_no kind target detail metadata tempfile_metadata pdb_name con_id file_no tablespace path
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

    if [[ "$kind" == "fs_rename" || "$kind" == fs_corrupt_* || "$kind" == asm_* || "$kind" == "external" ]]; then
      metadata="$(datafile_metadata_for_path "$target" || true)"
      if [[ -n "$metadata" ]]; then
        IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$metadata"
        manifest_append "action_${action_no}_pdb_name" "$pdb_name"
        manifest_append "action_${action_no}_con_id" "$con_id"
        manifest_append "action_${action_no}_file_no" "$file_no"
        manifest_append "action_${action_no}_tablespace" "$tablespace"
        manifest_append "action_${action_no}_datafile" "$path"
      fi

      tempfile_metadata="$(tempfile_metadata_for_path "$target" || true)"
      if [[ -n "$tempfile_metadata" ]]; then
        IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$tempfile_metadata"
        manifest_append "action_${action_no}_pdb_name" "$pdb_name"
        manifest_append "action_${action_no}_con_id" "$con_id"
        manifest_append "action_${action_no}_file_no" "$file_no"
        manifest_append "action_${action_no}_tablespace" "$tablespace"
        manifest_append "action_${action_no}_tempfile" "$path"
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
    if [[ "$kind" == "sqlfile" ]]; then
      manifest_append "action_${action_no}_sqlfile" "$target"
      manifest_append "action_${action_no}_sqllog" "$detail"
    fi
    if [[ "$kind" == "report" ]]; then
      manifest_append "action_${action_no}_report_type" "$target"
      manifest_append "action_${action_no}_report_detail" "$detail"
    fi

    action_no=$((action_no + 1))
  done
}

