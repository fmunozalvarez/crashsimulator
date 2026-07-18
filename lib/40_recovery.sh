recover_datafile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_file_recovery_automation "$id" ||
    die "Automated RMAN recovery is not registered for scenario ${id}. Use --runbook ${id} for manual guidance."

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

  local paths original backup pdb_name container_name sql_file sql_log has_restore_pairs target_tablespace
  load_manifest_tempfile_targets ||
    die "Manifest does not contain tempfile target metadata. Use a manifest from a scenario dry-run or executed run."
  original="${RECOVER_TEMPFILE_PATHS[0]}"
  backup=""
  has_restore_pairs=0
  if load_manifest_restore_pairs; then
    original="${RESTORE_ORIGINALS[0]}"
    backup="${RESTORE_BACKUPS[0]}"
    has_restore_pairs=1
  elif paths="$(manifest_rename_paths 2>/dev/null)"; then
    IFS='|' read -r original backup <<<"$paths"
  fi

  pdb_name="$TARGET_PDB"
  if [[ "$id" == "31" || "$id" == "38" ]]; then
    if [[ -z "$pdb_name" ]]; then
      pdb_name="$(manifest_first_value "target_pdb" "action_1_pdb_name" || true)"
      [[ -n "$pdb_name" ]] || pdb_name="$RECOVER_TEMPFILE_PDB"
    fi
  fi
  if [[ "$id" == "31" || "$id" == "38" ]]; then
    [[ -n "$pdb_name" ]] || die "Scenario ${id} recovery requires --pdb or a manifest target PDB."
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
  manifest_append "recover_tempfile_count" "${#RECOVER_TEMPFILE_PATHS[@]}"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Container: ${container_name}"
  echo "Tempfile target count: ${#RECOVER_TEMPFILE_PATHS[@]}"
  local tempfile_path
  for tempfile_path in "${RECOVER_TEMPFILE_PATHS[@]}"; do
    echo "  ${tempfile_path}"
  done
  if [[ -n "$backup" ]]; then
    echo "Scenario backup: ${backup}"
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_tempfile.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_tempfile.log"
  target_tablespace="$RECOVER_TEMPFILE_TABLESPACE"
  if [[ "${#RECOVER_TEMPFILE_PATHS[@]}" -eq 1 && -z "$target_tablespace" ]]; then
    write_tempfile_recovery_sql_file "$container_name" "$original" "$sql_file"
  else
    write_tempfile_list_recovery_sql_file "$container_name" "$target_tablespace" "$sql_file" "${RECOVER_TEMPFILE_PATHS[@]}"
  fi
  manifest_append "recover_tempfile_sqlfile" "$sql_file"
  manifest_append "recover_tempfile_log" "$sql_log"
  run_sql_script_file "$sql_file" "$sql_log"

  if [[ "$has_restore_pairs" -eq 1 ]]; then
    safe_remove_restore_backups
  elif [[ -n "$backup" ]]; then
    safe_remove_after_validation "$backup"
  fi
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

  # Checked BEFORE the typed confirmations: execute-mode recovery recreates the
  # password file with orapwd, which needs the SYS password - discovering that
  # only after RECOVER-<id> and LAB-APPROVED wastes the operator's gates
  # (field-tested 2026-07-18).
  [[ -n "$SYS_PASSWORD" || "$EXECUTE" -eq 0 ]] ||
    die "Password-file recovery execution requires --sys-password or CRASHSIM_SYS_PASSWORD."
  confirm_mode_execution "RECOVER" "$id"

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
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); validate spfile sets the exit
    # status on all supported releases.
  } >"$rman_file" || die "Unable to write SPFILE validation RMAN file: $rman_file"
  manifest_append "recover_spfile_validate_rman" "$rman_file"
  manifest_append "recover_spfile_validate_log" "$rman_log"
  run_rman_cmdfile "$rman_file" "$rman_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_fs_rename_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  load_manifest_restore_pairs ||
    die "Manifest is missing restore paths. Use a manifest from an executed scenario run."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Restore pair count: ${#RESTORE_ORIGINALS[@]}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  move_restore_pairs_to_originals
  run_health_check
  safe_remove_restore_backups
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
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); crosscheck/validate above set the
    # exit status on all supported releases.
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
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); crosscheck/validate above set the
    # exit status on all supported releases.
  } >"$validate_file" || die "Unable to write backup-piece validation RMAN file: $validate_file"
  manifest_append "recover_backuppiece_validate_rman" "$validate_file"
  manifest_append "recover_backuppiece_validate_log" "$validate_log"
  run_rman_cmdfile "$validate_file" "$validate_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_fra_full_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local original_size sql_file sql_log
  original_size="$(manifest_get "fra_original_size_bytes" || true)"
  [[ "$original_size" =~ ^[0-9]+$ ]] ||
    die "Manifest is missing fra_original_size_bytes. Use a manifest from executed scenario 61."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_restore_fra_size.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_restore_fra_size.log"
  write_fra_restore_sql_file "$sql_file" "$original_size"
  manifest_append "recover_fra_restore_sqlfile" "$sql_file"
  manifest_append "recover_fra_restore_log" "$sql_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Restore DB_RECOVERY_FILE_DEST_SIZE to: ${original_size}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run SQL script ${sql_file}"
    echo "DRY-RUN: would restore DB_RECOVERY_FILE_DEST_SIZE to ${original_size}"
    return "$SUCCESS"
  fi

  run_sql_script_file "$sql_file" "$sql_log"
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

recover_rac_service_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  if [[ -z "$DB_UNIQUE_NAME" && -n "${ORACLE_UNQNAME:-}" ]]; then
    DB_UNIQUE_NAME="$ORACLE_UNQNAME"
  fi
  if [[ -z "$DB_UNIQUE_NAME" && -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    DB_UNIQUE_NAME="$(manifest_get "db_unique_name" || true)"
    [[ "$DB_UNIQUE_NAME" == "unknown" ]] && DB_UNIQUE_NAME=""
  fi
  if [[ -z "$DB_UNIQUE_NAME" ]]; then
    local srvctl_dbs
    mapfile -t srvctl_dbs < <(srvctl config database 2>/dev/null | trim_blank_lines)
    if [[ "${#srvctl_dbs[@]}" -eq 1 ]]; then
      DB_UNIQUE_NAME="${srvctl_dbs[0]}"
    fi
  fi
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"

  local service status_file service_status
  service="$SERVICE_NAME"
  if [[ -z "$service" && -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    service="$(manifest_first_value "scenario_56_service" "action_1_target" || true)"
  fi
  if [[ -z "$service" ]]; then
    local services_file
    services_file="$WORK_DIR/recover_s56_services.lst"
    srvctl config service -d "$DB_UNIQUE_NAME" >"$services_file" 2>&1 ||
      die "Unable to collect srvctl service configuration for ${DB_UNIQUE_NAME}."
    service="$(awk -F': ' '/^Service name:/ {print $2; exit}' "$services_file")"
  fi
  [[ -n "$service" ]] || die "Scenario 56 recovery could not determine a service. Use --service-name or a scenario manifest."

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_service_status.log"
  manifest_append "recover_service_name" "$service"
  manifest_append "recover_service_status_log" "$status_file"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Service: ${service}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run srvctl status service -d ${DB_UNIQUE_NAME} -s ${service}"
    echo "DRY-RUN: would run srvctl start service -d ${DB_UNIQUE_NAME} -s ${service} if the service is not running"
    echo "DRY-RUN: would validate database/PDB health with SQL*Plus"
    return "$SUCCESS"
  fi

  service_status="$(srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" 2>&1 | tee "$status_file")" || true
  if printf "%s\n" "$service_status" | grep -Eq 'is running|running on instance'; then
    echo "Service ${service} is already running."
  else
    echo "srvctl start service -d ${DB_UNIQUE_NAME} -s ${service}"
    srvctl start service -d "$DB_UNIQUE_NAME" -s "$service" ||
      die "Unable to start service ${service}."
    srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" | tee -a "$status_file"
  fi

  run_health_check
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_standby_apply_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  local apply_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_restart_apply.log"
  local validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_apply_status.log"
  manifest_append "recover_standby_apply_log" "$apply_log"
  manifest_append "recover_standby_apply_status_log" "$validate_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would restart managed standby recovery"
    echo "DRY-RUN: would query V\$MANAGED_STANDBY and V\$DATAGUARD_STATS"
    return "$SUCCESS"
  fi

  check_requirements "$id"
  run_sql_text "restart managed standby recovery" "
alter database recover managed standby database disconnect from session;
" "$apply_log"
  run_sql_text "validate standby apply status" "
select process || '|' || status
from v\$managed_standby
where process like 'MRP%'
order by process;
select name || '=' || nvl(value, 'UNKNOWN') || ' ' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
" "$validate_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_dg_transport_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  local dest_id dest_log validate_log
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    dest_id="$(manifest_first_value "dg_dest_id" || true)"
  else
    dest_id=""
  fi

  if [[ -z "$dest_id" ]]; then
    warn "No Data Guard destination id was found in the manifest; attempting live destination discovery."
    check_requirements "$id"
    local dest_file="$WORK_DIR/recover_dg_transport_dest.lst"
    query_targets "$dest_file" "
select dest_id
from (
  select dest_id
  from v\$archive_dest
  where target = 'STANDBY'
    and destination is not null
  order by case status when 'VALID' then 1 else 2 end, dest_id
)
where rownum = 1;
"
    [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No remote standby archive destination was found for recovery."
    dest_id="${TARGET_ROWS[0]}"
  fi
  [[ "$dest_id" =~ ^[0-9]+$ ]] || die "Invalid Data Guard destination id for recovery: ${dest_id}"

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  dest_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_enable_dest_${dest_id}.log"
  validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_transport_status.log"
  manifest_append "recover_dg_dest_id" "$dest_id"
  manifest_append "recover_dg_enable_log" "$dest_log"
  manifest_append "recover_dg_transport_status_log" "$validate_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Remote archive destination: LOG_ARCHIVE_DEST_${dest_id}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would enable LOG_ARCHIVE_DEST_STATE_${dest_id}"
    echo "DRY-RUN: would force a log switch and inspect V\$ARCHIVE_DEST / V\$DATAGUARD_STATS"
    return "$SUCCESS"
  fi

  check_requirements "$id"
  run_sql_text "enable Data Guard transport destination ${dest_id}" "
alter system set log_archive_dest_state_${dest_id}=enable scope=both;
alter system archive log current;
" "$dest_log"
  run_sql_text "validate Data Guard transport status" "
select dest_id || '|' || status || '|' || target || '|' || nvl(error, 'NO_ERROR')
from v\$archive_dest
where dest_id = ${dest_id};
select name || '=' || nvl(value, 'UNKNOWN') || ' ' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
" "$validate_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_ords_service_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  local service status_file smoke_file service_from_manifest lb_from_manifest effective_lb_url
  service="$ORDS_SERVICE_NAME"
  effective_lb_url="$ORDS_LB_URL"
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    service_from_manifest="$(manifest_first_value "ords_service_name" "action_1_target" || true)"
    [[ -n "$service_from_manifest" ]] && service="$service_from_manifest"
    lb_from_manifest="$(manifest_first_value "ords_lb_url" || true)"
    [[ -z "$effective_lb_url" && -n "$lb_from_manifest" ]] && effective_lb_url="$lb_from_manifest"
  fi
  [[ -n "$service" ]] || die "ORDS service name was not supplied."

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_ords_status.log"
  smoke_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_ords_smoke.md"
  manifest_append "recover_ords_service_name" "$service"
  manifest_append "recover_ords_status_log" "$status_file"
  manifest_append "recover_ords_smoke_report" "$smoke_file"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "ORDS service: ${service}"
  echo "ORDS URL: ${ORDS_URL}"
  [[ -n "$effective_lb_url" ]] && echo "ORDS continuity URL: ${effective_lb_url}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would start ORDS service ${service}"
    echo "DRY-RUN: would validate ${ORDS_URL}"
    [[ -n "$effective_lb_url" ]] && echo "DRY-RUN: would validate ${effective_lb_url}"
    return "$SUCCESS"
  fi

  perform_systemctl_service_action start "$service"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status "$service" >"$status_file" 2>&1 || true
  fi
  if [[ -n "$effective_lb_url" && -z "$ORDS_LB_URL" ]]; then
    ORDS_LB_URL="$effective_lb_url"
  fi
  write_apex_ords_smoke_report "$smoke_file" "CrashSimulator ORDS Recovery Smoke Evidence"
  cat "$smoke_file"
  maybe_render_html "$smoke_file"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_apex_runtime_account_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  local runtime_user runtime_container container_sql sql_file sql_log user_file
  runtime_user=""
  runtime_container=""
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    runtime_user="$(manifest_first_value "apex_runtime_user" "action_1_target" || true)"
    runtime_user="${runtime_user##*alter user }"
    runtime_user="${runtime_user%% account*}"
    runtime_container="$(manifest_first_value "apex_runtime_target_container" || true)"
  fi
  if [[ -z "$runtime_user" ]]; then
    user_file="$WORK_DIR/recover_apex_runtime_user.lst"
    query_apex_ords_runtime_user "$user_file" ||
      die "Could not discover an APEX/ORDS runtime account to unlock. Use --manifest from scenario 76 or select the correct PDB."
    runtime_user="${TARGET_ROWS[0]}"
  fi
  runtime_user="$(normalize_name "$runtime_user")"
  validate_oracle_name "$runtime_user" || die "Invalid runtime user for recovery: $runtime_user"
  runtime_container="$(normalize_name "$runtime_container")"
  if [[ -n "$runtime_container" ]]; then
    validate_oracle_name "$runtime_container" || die "Invalid runtime container for recovery: $runtime_container"
    container_sql="$(printf "alter session set container = %s;\n" "$(sql_identifier "$runtime_container")")"
  else
    container_sql="$(apex_ords_container_sql_prefix)"
    runtime_container="$(printf "%s" "$container_sql" | sed -n 's/^alter session set container = "\{0,1\}\([^";]*\)"\{0,1\};$/\1/p' | head -1)"
  fi

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_unlock_runtime_user.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_unlock_runtime_user.log"
  {
    printf 'whenever sqlerror exit sql.sqlcode\n'
    printf 'set feedback on pages 100 lines 220\n'
    printf '%s\n' "$container_sql"
    printf 'alter user %s account unlock;\n' "$runtime_user"
    printf "select username, account_status from dba_users where username = '%s';\n" "$runtime_user"
    printf 'exit\n'
  } >"$sql_file" || die "Unable to write APEX/ORDS runtime recovery SQL file: $sql_file"

  manifest_append "recover_apex_runtime_user" "$runtime_user"
  manifest_append "recover_apex_runtime_container" "$runtime_container"
  manifest_append "recover_apex_runtime_sqlfile" "$sql_file"
  manifest_append "recover_apex_runtime_log" "$sql_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Runtime user: ${runtime_user}"
  [[ -n "$runtime_container" ]] && echo "Runtime container: ${runtime_container}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would unlock ${runtime_user} using ${sql_file}"
    return "$SUCCESS"
  fi
  run_sql_script_file "$sql_file" "$sql_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_ords_pool_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local original_service bad_service smoke_file
  original_service="$(manifest_get "ords_pool_original_servicename" || true)"
  bad_service="$(manifest_get "ords_pool_bad_servicename" || true)"
  [[ -n "$original_service" ]] ||
    die "Manifest is missing ords_pool_original_servicename; use the manifest from executed scenario 75."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_ords_pool_original_servicename" "$original_service"
  [[ -n "$bad_service" ]] && manifest_append "recover_ords_pool_bad_servicename" "$bad_service"

  smoke_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_ords_pool_smoke.md"
  manifest_append "recover_ords_pool_smoke_report" "$smoke_file"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "ORDS config: ${ORDS_CONFIG_DIR}"
  echo "Restore db.servicename: ${original_service}"
  [[ -n "$bad_service" ]] && echo "Lab-bad db.servicename: ${bad_service}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would restore ORDS db.servicename to ${original_service}"
    echo "DRY-RUN: would restart ORDS service ${ORDS_SERVICE_NAME}"
    echo "DRY-RUN: would validate ${ORDS_URL}"
    return "$SUCCESS"
  fi

  ords_config_set_value db.servicename "$original_service" ||
    die "Unable to restore ORDS db.servicename."
  perform_systemctl_service_action restart "$ORDS_SERVICE_NAME"
  write_apex_ords_smoke_report "$smoke_file" "CrashSimulator ORDS Pool Recovery Smoke Evidence"
  cat "$smoke_file"
  maybe_render_html "$smoke_file"
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
    6|13|31|38)
      recover_tempfile_scenario "$id"
      ;;
    7|8|9|10|12|14|15|17|22|32|33|34|35|37|39|40|41|42)
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
    27|57|58)
      recover_fs_rename_scenario "$id"
      ;;
    50|67)
      recover_standby_apply_scenario "$id"
      ;;
    51|68)
      recover_dg_transport_scenario "$id"
      ;;
    73|79)
      recover_ords_service_scenario "$id"
      ;;
    74|77)
      recover_fs_rename_scenario "$id"
      ;;
    75)
      recover_ords_pool_scenario "$id"
      ;;
    76)
      recover_apex_runtime_account_scenario "$id"
      ;;
    55)
      recover_srvctl_database_scenario "$id"
      ;;
    56|71)
      recover_rac_service_scenario "$id"
      ;;
    59)
      recover_archivelog_scenario "$id"
      ;;
    61)
      recover_fra_full_scenario "$id"
      ;;
    62)
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

