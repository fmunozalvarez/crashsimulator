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

  if scenario_requires_sqlplus_context "$id"; then
    if ! find_sqlplus_if_available; then
      die "Scenario $id requires database SQL*Plus context, but sqlplus was not found. Set ORACLE_HOME or SQLPLUS after the database is created or installed."
    fi
    discover_environment
  elif find_sqlplus_if_available; then
    discover_environment
  fi

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
        storage_supports_gi_storage_planning ||
          die "Scenario $id requires ASM or GI-managed FEX/ACFS-style storage. Current storage: $STORAGE_TYPE"
        ;;
      gi)
        grid_tool_available crsctl || die "Scenario $id requires Grid Infrastructure commands. Set CRASHSIM_GRID_HOME or run with Grid Infrastructure tools in PATH."
        ;;
      *)
        die "Unknown requirement '$req' for scenario $id"
        ;;
    esac
  done
}

scenario_requires_sqlplus_context() {
  local id="$1"
  local requires=",${SCENARIO_REQUIRES[$id]:-},"

  case "$requires" in
    *",primary,"*|*",standby,"*|*",dg,"*|*",cdb,"*|*",pdb,"*|*",rac,"*|*",asm,"*)
      return "$SUCCESS"
      ;;
  esac

  return "$FAIL"
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
        storage_supports_gi_storage_planning || return "$FAIL"
        ;;
      gi)
        grid_tool_available crsctl || return "$FAIL"
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
    require_destructive_lab_ack "scenario ${id} execution"
    return "$SUCCESS"
  fi

  local -a prompt_lines=(
    ""
    "About to execute scenario ${id}: ${SCENARIO_TITLE[$id]}"
    "Database: ${DB_UNIQUE_NAME} (${DB_ROLE}, ${DB_OPEN_MODE})"
  )
  if [[ -n "$TARGET_PDB" ]]; then
    prompt_lines+=("PDB: ${TARGET_PDB}")
  fi
  if [[ -n "$TARGET_SCHEMA" ]]; then
    prompt_lines+=("Schema: ${TARGET_SCHEMA}")
  fi
  prompt_lines+=("Type EXECUTE-${id} to continue:")
  confirm_show "${prompt_lines[@]}"
  local answer
  confirm_reply answer
  [[ "$answer" == "EXECUTE-${id}" ]] || die "Confirmation did not match. Aborting."
  require_destructive_lab_ack "scenario ${id} execution"
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
      die "Scenario ${id} execution is blocked by readiness validation."
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
  manifest_append "scenario_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
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
    require_destructive_lab_ack "${mode_name,,} for scenario ${id}"
    return "$SUCCESS"
  fi

  local -a prompt_lines=(
    ""
    "About to execute ${mode_name,,} for scenario ${id}: ${SCENARIO_TITLE[$id]}"
    "Database: ${DB_UNIQUE_NAME:-unknown} (${DB_ROLE:-unknown}, ${DB_OPEN_MODE:-unknown})"
  )
  if [[ -n "$TARGET_PDB" ]]; then
    prompt_lines+=("PDB: ${TARGET_PDB}")
  fi
  prompt_lines+=("Type ${token} to continue:")
  confirm_show "${prompt_lines[@]}"
  local answer
  confirm_reply answer
  [[ "$answer" == "$token" ]] || die "Confirmation did not match. Aborting."
  require_destructive_lab_ack "${mode_name,,} for scenario ${id}"
}

require_destructive_lab_ack() {
  local action="$1"
  local answer

  [[ "$EXECUTE" -eq 1 ]] || return "$SUCCESS"
  [[ "${DESTRUCTIVE_LAB_ACK^^}" == "YES" ]] && return "$SUCCESS"

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    die "${action} is blocked because destructive lab acknowledgement is not set. Set CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES or pass --accept-destructive-lab only in an approved non-production lab."
  fi

  echo
  echo "Public safety guardrail: ${action} must run only in an approved non-production lab."
  echo "Type LAB-APPROVED to confirm this environment is approved for destructive CrashSimulator execution:"
  read -r answer
  [[ "$answer" == "LAB-APPROVED" ]] || die "Lab acknowledgement did not match. Aborting."
}

supports_file_recovery_automation() {
  local id="$1"
  case "$id" in
    5|7|8|9|10|12|14|15|17|22|30|32|33|34|35|37|39|40|41|42) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

supports_recovery_automation() {
  local id="$1"
  case "$id" in
    1|2|3|4|5|6|7|8|9|10|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|30|31|32|33|34|35|37|38|39|40|41|42|50|51|55|56|57|58|59|61|62|67|68|71|73|74|75|76|77|79) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

scenario_validation_capability() {
  printf "Automated readiness validation"
}

scenario_protection_capability() {
  local id="$1"
  if supports_file_recovery_automation "$id"; then
    printf "Automated --protect RMAN backup"
    return "$SUCCESS"
  fi

  case "$id" in
    53|64|65|69|78|81|82)
      printf "Not required: read-only report"
      ;;
    *)
      if [[ "${SCENARIO_IMPACT[$id]}" == "logical" ]]; then
        printf "Not required: logical drill"
      else
        printf "Manual baseline/runbook"
      fi
      ;;
  esac
}

scenario_execution_capability() {
  local id="$1"
  if [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]]; then
    printf "Placeholder: manual lab design pending"
    return "$SUCCESS"
  fi

  case "$id" in
    28)
      printf "guarded manual-only external restore plan"
      ;;
    46|47|48|49|52|54|66|70|72|85|86|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
      printf "guarded plan-only evidence; external approved action"
      ;;
    53|64|65|69|78|80|81|82|87)
      printf "Automated read-only report"
      ;;
    83|84)
      printf "Automated evidence collection; approved client/provider action external"
      ;;
    *)
      printf "Automated dry-run/execute with guardrails"
      ;;
  esac
}

scenario_recovery_capability() {
  local id="$1"
  if supports_recovery_automation "$id"; then
    printf "Automated --recover helper"
    return "$SUCCESS"
  fi

  case "$id" in
    53|64|65|69|78|80|81|82|87)
      printf "Not required: read-only report"
      ;;
    11|36|43|44)
      printf "Manual logical restore/reseed runbook"
      ;;
    28|29|45|46|47|48|49|52|54|60|63|66|70|72|83|84|85|86|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
      printf "Manual/external runbook"
      ;;
    *)
      printf "Manual runbook"
      ;;
  esac
}

scenario_runbook_capability() {
  printf "Automated --runbook artifact"
}

scenario_evidence_capability() {
  local id="$1"
  case "$id" in
    80)
      printf "Markdown report, SQL evidence, optional browser screenshots/JSON, manifest, audit"
      ;;
    53|64|65|69|78|80|81|82)
      printf "Markdown report, SQL evidence, manifest, audit"
      ;;
    52|54)
      printf "Manifest, audit, SQL/DGMGRL readiness evidence, runbook"
      ;;
    *)
      printf "Manifest, audit, runbook; SQL/RMAN/report evidence when used"
      ;;
  esac
}

scenario_lifecycle_next_step() {
  local id="$1"
  if [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]]; then
    printf "Implement scenario handler and lab validation."
    return "$SUCCESS"
  fi
  if ! supports_recovery_automation "$id"; then
    case "$id" in
      53|64|65|69|78|80|81|82|87)
        printf "No recovery helper required; keep report evidence current."
        ;;
      52|54|66|70|72|83|84|85|86|87|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
        printf "Plan-only by design; keep external-action runbook and evidence current."
        ;;
      11|36|43|44)
        printf "Keep logical seed/reseed and restore guidance current."
        ;;
      *)
        printf "Add automated recovery helper when safe and repeatable."
        ;;
    esac
    return "$SUCCESS"
  fi
  if [[ "${SCENARIO_IMPACT[$id]}" == "destructive" ]] && ! supports_file_recovery_automation "$id"; then
    printf "Use baseline backup/runbook; add --protect only where target-specific backup is meaningful."
    return "$SUCCESS"
  fi
  printf "Lifecycle covered where topology prerequisites are met."
}

generate_scenario_lifecycle_report() {
  local id report_file latest_file protection execution recovery next_step
  local total_count=0 auto_protect_count=0 auto_recover_count=0 plan_only_count=0 placeholder_count=0 read_only_count=0

  for id in "${SCENARIO_IDS[@]}"; do
    total_count=$((total_count + 1))
    supports_file_recovery_automation "$id" && auto_protect_count=$((auto_protect_count + 1))
    supports_recovery_automation "$id" && auto_recover_count=$((auto_recover_count + 1))
    [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]] && placeholder_count=$((placeholder_count + 1))
    case "$id" in
      46|47|48|49|52|54|66|70|72|83|84|85|86|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
        plan_only_count=$((plan_only_count + 1))
        ;;
      53|64|65|69|78|80|81|82|87)
        read_only_count=$((read_only_count + 1))
        ;;
    esac
  done

  report_file="${LOG_DIR}/crashsim_scenario_lifecycle_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_scenario_lifecycle_latest.md"

  {
    printf "# CrashSimulator Scenario Lifecycle Coverage Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf -- '- Registered scenarios: `%s`\n' "$total_count"
    printf '%s\n' ""
    printf '%s\n' 'This static report shows what lifecycle support the framework provides for each registered scenario. It complements `--scenario-readiness-report`, which checks whether a scenario can run in the current database topology.'
    printf '%s\n' ""

    printf '%s\n\n' "## Lifecycle Policy"
    printf '%s\n' "| Phase | Framework expectation |"
    printf '%s\n' "| --- | --- |"
    printf '%s\n' '| Validation | Every registered scenario has a readiness validator through `--validate-scenario`; live blockers are reported before destructive execution. |'
    printf '%s\n' '| Protection | Datafile/tablespace media drills use automated `--protect` when a targeted RMAN backup is meaningful. Other destructive drills require baseline backup, configuration backup, or manual pre-checks documented by the runbook. Logical/read-only drills do not require protection. |'
    printf '%s\n' "| Execution | Scenarios use automated dry-run and guarded execution where safe. External infrastructure drills remain plan-only until a matching lab and approval path exist. |"
    printf '%s\n' '| Recovery | Automated `--recover` is available where repeatable. Other scenarios provide manual recovery guidance and evidence targets. |'
    printf '%s\n' "| Runbook/evidence | Every scenario can generate a runbook artifact; scenario/protection/recovery actions write manifests and audit records, with SQL/RMAN/Markdown evidence where applicable. |"

    printf '%s\n\n' ""
    printf '%s\n\n' "## Summary"
    printf '%s\n' "| Metric | Count |"
    printf '%s\n' "| --- | ---: |"
    printf '| Registered scenarios | %s |\n' "$total_count"
    printf '| Automated `--protect` support | %s |\n' "$auto_protect_count"
    printf '| Automated `--recover` support | %s |\n' "$auto_recover_count"
    printf '| Plan-only external-action scenarios | %s |\n' "$plan_only_count"
    printf '| Placeholder scenarios awaiting implementation | %s |\n' "$placeholder_count"
    printf '| Read-only report/review scenarios | %s |\n' "$read_only_count"

    printf '%s\n\n' ""
    printf '%s\n\n' "## Scenario Lifecycle Matrix"
    printf '%s\n' "| ID | Group | Impact | Scenario | Validation | Protection | Execution | Recovery | Runbook / Evidence | Next step |"
    printf '%s\n' "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    for id in "${SCENARIO_IDS[@]}"; do
      protection="$(scenario_protection_capability "$id")"
      execution="$(scenario_execution_capability "$id")"
      recovery="$(scenario_recovery_capability "$id")"
      next_step="$(scenario_lifecycle_next_step "$id")"
      printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s / %s | %s |\n' \
        "$id" \
        "$(md_escape "${SCENARIO_GROUP[$id]}")" \
        "$(md_escape "${SCENARIO_IMPACT[$id]}")" \
        "$(md_escape "${SCENARIO_TITLE[$id]}")" \
        "$(md_escape "$(scenario_validation_capability "$id")")" \
        "$(md_escape "$protection")" \
        "$(md_escape "$execution")" \
        "$(md_escape "$recovery")" \
        "$(md_escape "$(scenario_runbook_capability "$id")")" \
        "$(md_escape "$(scenario_evidence_capability "$id")")" \
        "$(md_escape "$next_step")"
    done

    printf '%s\n\n' ""
    printf '%s\n\n' "## Recommended Use"
    printf -- '- Generate this report after new scenarios are added so lifecycle coverage stays visible.\n'
    printf -- '- Use `--scenario-readiness-report --pdb <pdb>` next to check the live target topology.\n'
    printf -- '- Use `--runbook <id> --html` before drills to produce scenario-specific recovery guidance and evidence expectations.\n'
    printf -- '- Treat manual/external entries as backlog candidates only after the required lab topology and safe recovery procedure exist.\n'
  } >"$report_file" || die "Unable to write scenario lifecycle report: $report_file"

  cp "$report_file" "$latest_file" || die "Unable to update latest scenario lifecycle report: $latest_file"
  echo "Scenario lifecycle coverage report generated: ${report_file}"
  echo "Latest scenario lifecycle coverage report: ${latest_file}"
  echo
  cat "$report_file"
  maybe_render_html "$report_file"
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    render_artifact_html "$latest_file"
  fi
}

scenario_lifecycle_check() {
  local id report_file latest_file status failures=0 warnings=0 handler
  local title group scope impact requires notes validation protection execution recovery runbook evidence

  report_file="${LOG_DIR}/crashsim_scenario_lifecycle_check_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_scenario_lifecycle_check_latest.md"

  {
    printf "# CrashSimulator Scenario Lifecycle Consistency Check\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Registered database scenarios: `%s`\n' "${#SCENARIO_IDS[@]}"
    printf -- '- Registered ADB scenarios: `%s`\n' "${#ADB_SCENARIO_IDS[@]}"
    printf "\nThis check is release-oriented. It validates that each registered scenario has metadata, a callable handler, and lifecycle text for validation, protection, execution, recovery, runbook, and evidence posture. It does not connect to a database.\n\n"
    printf "## Scenario Checks\n\n"
    printf "| Status | ID | Scenario | Finding |\n"
    printf "| --- | --- | --- | --- |\n"
  } >"$report_file" || die "Unable to write lifecycle check report: $report_file"

  for id in "${SCENARIO_IDS[@]}"; do
    status="OK"
    title="${SCENARIO_TITLE[$id]:-}"
    group="${SCENARIO_GROUP[$id]:-}"
    scope="${SCENARIO_SCOPE[$id]:-}"
    impact="${SCENARIO_IMPACT[$id]:-}"
    requires="${SCENARIO_REQUIRES[$id]:-}"
    handler="${SCENARIO_HANDLER[$id]:-}"
    notes="${SCENARIO_NOTES[$id]:-}"
    validation="$(scenario_validation_capability "$id")"
    protection="$(scenario_protection_capability "$id")"
    execution="$(scenario_execution_capability "$id")"
    recovery="$(scenario_recovery_capability "$id")"
    runbook="$(scenario_runbook_capability "$id")"
    evidence="$(scenario_evidence_capability "$id")"

    if [[ -z "$title" || -z "$group" || -z "$scope" || -z "$impact" || -z "$requires" || -z "$handler" || -z "$notes" ]]; then
      printf '| `FAIL` | `%s` | %s | Missing required scenario metadata. |\n' "$id" "$(md_escape "${title:-unknown}")" >>"$report_file"
      failures=$((failures + 1))
      status="FAIL"
    fi
    if [[ -n "$handler" && -z "$(declare -F "$handler" 2>/dev/null)" ]]; then
      printf '| `FAIL` | `%s` | %s | Handler `%s` is not defined. |\n' "$id" "$(md_escape "${title:-unknown}")" "$(md_escape "$handler")" >>"$report_file"
      failures=$((failures + 1))
      status="FAIL"
    fi
    if [[ -z "$validation" || -z "$protection" || -z "$execution" || -z "$recovery" || -z "$runbook" || -z "$evidence" ]]; then
      printf '| `FAIL` | `%s` | %s | One or more lifecycle capability strings are empty. |\n' "$id" "$(md_escape "${title:-unknown}")" >>"$report_file"
      failures=$((failures + 1))
      status="FAIL"
    fi
    if [[ "$impact" == "destructive" && "$execution" != *"guard"* && "$execution" != *"plan-only"* ]]; then
      printf '| `WARN` | `%s` | %s | Destructive scenario execution text should mention guardrails or plan-only posture. |\n' "$id" "$(md_escape "$title")" >>"$report_file"
      warnings=$((warnings + 1))
    fi
    if [[ "$status" == "OK" ]]; then
      printf '| `OK` | `%s` | %s | Metadata, handler, and lifecycle text are present. |\n' "$id" "$(md_escape "$title")" >>"$report_file"
    fi
  done

  {
    printf "\n## Autonomous Database Scenario Checks\n\n"
    printf "| Status | ID | Scenario | Finding |\n"
    printf "| --- | --- | --- | --- |\n"
  } >>"$report_file"

  for id in "${ADB_SCENARIO_IDS[@]}"; do
    title="${ADB_SCENARIO_TITLE[$id]:-}"
    if [[ -z "$title" || -z "${ADB_SCENARIO_AREA[$id]:-}" || -z "${ADB_SCENARIO_VALIDATION[$id]:-}" || -z "${ADB_SCENARIO_RECOVERY[$id]:-}" || -z "${ADB_SCENARIO_HELPER[$id]:-}" ]]; then
      printf '| `FAIL` | `%s` | %s | Missing ADB scenario metadata. |\n' "$id" "$(md_escape "${title:-unknown}")" >>"$report_file"
      failures=$((failures + 1))
    else
      printf '| `OK` | `%s` | %s | ADB scenario metadata is present. |\n' "$id" "$(md_escape "$title")" >>"$report_file"
    fi
  done

  {
    printf "\n## Summary\n\n"
    printf -- '- Failures: `%s`\n' "$failures"
    printf -- '- Warnings: `%s`\n' "$warnings"
    printf -- '- Latest report: `%s`\n' "$latest_file"
  } >>"$report_file"

  cp "$report_file" "$latest_file" 2>/dev/null || true
  echo "Scenario lifecycle consistency check generated: ${report_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
  [[ "$failures" -eq 0 ]]
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
  if printf "%s\n" "$output" | grep -Eq '^[[:space:]]*[0-9]+\. asm_'; then
    if ! discover_grid_home_for_tool asmcmd >/dev/null 2>&1; then
      printf "Selected action requires asmcmd from Grid Infrastructure, but asmcmd was not found."
      return "$SUCCESS"
    fi
  fi
  return "$FAIL"
}

validation_requirement_blocker_reason() {
  local id="$1"
  local output="$2"

  case "$id" in
    50|67)
      if printf "%s\n" "$output" | grep -q "requires a standby role"; then
        printf "Scenario %s requires a physical standby database with managed recovery running. Run it on a standby environment, then confirm an MRP process is visible in V\$MANAGED_STANDBY." "$id"
        return "$SUCCESS"
      fi
      ;;
    51|68)
      if printf "%s\n" "$output" | grep -q "requires Data Guard metadata"; then
        printf "Scenario %s requires a primary database with a configured remote standby archive destination. Configure Data Guard transport, confirm a V\$ARCHIVE_DEST row with TARGET='STANDBY', then rerun validation." "$id"
        return "$SUCCESS"
      fi
      ;;
    52|66|69|85|86)
      if printf "%s\n" "$output" | grep -q "requires Data Guard metadata"; then
        printf "Scenario %s requires a Data Guard configuration. Configure a standby and verify SQL/Data Guard Broker evidence before running this scenario." "$id"
        return "$SUCCESS"
      fi
      ;;
    53)
      if printf "%s\n" "$output" | grep -q "requires a standby role"; then
        printf "Scenario 53 requires an Active Data Guard standby opened READ ONLY WITH APPLY. Run it on an ADG standby after confirming open mode and apply status."
        return "$SUCCESS"
      fi
      ;;
    54)
      if printf "%s\n" "$output" | grep -q "requires a standby role"; then
        printf "Scenario 54 requires a Data Guard physical standby that is approved for snapshot-standby conversion practice. Run it on the standby after confirming flashback, broker/transport posture, and restore-point policy."
        return "$SUCCESS"
      fi
      ;;
  esac

  return "$FAIL"
}

validation_no_target_reason() {
  local id="$1"
  local output="$2"
  local no_target=0

  if printf "%s\n" "$output" | grep -q "No targets were found for this scenario"; then
    no_target=1
  fi

  case "$id" in
    3)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No multiplexed member was found in the CURRENT redo group. Add at least one additional online redo member to the current group, or multiplex all redo groups and switch logs until a multiplexed group is current, then rerun validation."
      ;;
    5)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No non-SYSTEM permanent datafile was found. Create a disposable user tablespace/datafile, or seed the CrashSimulator lab objects, before running scenario 5."
      ;;
    6|31)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No tempfile was found in the target scope. Add a tempfile to the database/PDB temporary tablespace before running this scenario."
      ;;
    7)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB SYSTEM datafile was visible to the validation query. Confirm the database is open and DBA_DATA_FILES is accessible before running scenario 7."
      ;;
    8)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB UNDO datafile was found. Confirm local undo/undo tablespace configuration before running scenario 8."
      ;;
    9)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB READ ONLY permanent tablespace was found. Create a controlled read-only lab tablespace, preferably CRASHSIM_ROOT_RO_TBS, set it READ ONLY, then rerun validation."
      ;;
    10)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB index-only tablespace was found. Create a controlled index-only lab tablespace, preferably CRASHSIM_ROOT_INDEX_TBS, with indexes and no heap tables before running scenario 10."
      ;;
    11)
      if printf "%s\n" "$output" | grep -q "No non-unique user index candidate"; then
        printf "No root/non-CDB non-unique user index candidate was found. Re-run seed_crashsim_lab.sql or provide --schema for a disposable lab schema with non-unique indexes."
      else
        return "$FAIL"
      fi
      ;;
    12)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No non-SYSTEM permanent tablespace target was found. Create a disposable user tablespace before running scenario 12."
      ;;
    13|38)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No temporary tablespace tempfile target was found. Add a tempfile to the target temporary tablespace before running this scenario."
      ;;
    14)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB SYSTEM tablespace datafile was visible. Confirm the database is open and dictionary access is available before scenario 14."
      ;;
    15)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB UNDO tablespace datafile was found. Confirm undo tablespace configuration before scenario 15."
      ;;
    17|41)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No datafiles were visible to the validation query. Confirm the database/PDB is open and V\$DATAFILE is accessible before running this all-datafile scenario."
      ;;
    18)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No online redo group with more than one member was found. Multiplex the online redo logs, preferably every group/thread in RAC, then rerun validation."
      ;;
    19)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No INACTIVE redo group members were found. Switch logs and checkpoint until at least one inactive redo group exists, then rerun validation."
      ;;
    20|21)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No active/current redo group members were found by the validation query. Confirm V\$LOG/V\$LOGFILE visibility and current redo status before running this redo scenario."
      ;;
    22|42)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No SYSTEM datafile target was found for header-corruption practice. Confirm the target database/PDB is open and SYSTEM datafile metadata is visible."
      ;;
    27|57)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No SQL*Net configuration files were found under TNS_ADMIN or ORACLE_HOME/network/admin. Create or locate listener.ora, tnsnames.ora, or sqlnet.ora before running this scenario."
      ;;
    30)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB non-SYSTEM datafile was found in ${TARGET_PDB:-the target PDB}. Create a disposable user tablespace/datafile in the PDB before running scenario 30."
      ;;
    32)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB SYSTEM datafile was visible in ${TARGET_PDB:-the target PDB}. Confirm the PDB is open and CDB_DATA_FILES metadata is accessible before running scenario 32."
      ;;
    33|40)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB UNDO datafile was found in ${TARGET_PDB:-the target PDB}. Confirm local undo is enabled and the PDB has an UNDO tablespace before running this scenario."
      ;;
    34)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No READ ONLY permanent tablespace was found in PDB ${TARGET_PDB:-not set}. Create a controlled PDB read-only lab tablespace, set it READ ONLY, then rerun validation."
      ;;
    35)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB index-only tablespace was found in ${TARGET_PDB:-the target PDB}. Create a controlled index-only lab tablespace with indexes and no heap tables before running scenario 35."
      ;;
    36)
      if printf "%s\n" "$output" | grep -q "No PDB non-unique user index candidate"; then
        printf "No PDB non-unique user index candidate was found in ${TARGET_PDB:-the target PDB}. Re-run seed_crashsim_lab.sql in the PDB or provide --schema for a disposable lab schema."
      else
        return "$FAIL"
      fi
      ;;
    37)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB non-SYSTEM permanent tablespace was found in ${TARGET_PDB:-the target PDB}. Create a disposable PDB user tablespace before running scenario 37."
      ;;
    39)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB SYSTEM tablespace datafile was visible in ${TARGET_PDB:-the target PDB}. Confirm the PDB is open and metadata is accessible before running scenario 39."
      ;;
    43)
      if printf "%s\n" "$output" | grep -Eq "No PDB user table candidate|No targets were found"; then
        printf "No PDB user table candidate was found in ${TARGET_PDB:-the target PDB}. Re-run seed_crashsim_lab.sql in the PDB or provide --schema for a disposable lab schema with test tables."
      else
        return "$FAIL"
      fi
      ;;
    44)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No disposable PDB user schema candidate was found in ${TARGET_PDB:-the target PDB}. Re-run seed_crashsim_lab.sql or provide --schema for a lab schema that can be dropped."
      ;;
    50)
      if printf "%s\n" "$output" | grep -q "No managed standby recovery process"; then
        printf "No managed standby recovery process was detected. Start standby apply and confirm an MRP process in V\$MANAGED_STANDBY before running scenario 50."
      else
        return "$FAIL"
      fi
      ;;
    51)
      if printf "%s\n" "$output" | grep -q "No remote standby archive destination"; then
        printf "No enabled remote standby archive destination was found. Configure Data Guard transport and confirm V\$ARCHIVE_DEST TARGET='STANDBY' before running scenario 51."
      else
        return "$FAIL"
      fi
      ;;
    58)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No TDE wallet/keystore location was detected. Configure WALLET_ROOT/TDE_CONFIGURATION or an sqlnet.ora wallet location before running scenario 58."
      ;;
    59)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No archived redo log file was found in control-file metadata. Generate and retain archived redo logs, then rerun validation."
      ;;
    60)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No RMAN catalog connect string was provided. Set --rman-catalog or CRASHSIM_RMAN_CATALOG to validate recovery catalog outage behavior."
      ;;
    61)
      if printf "%s\n" "$output" | grep -q "No configured FRA destination"; then
        printf "No configured FRA destination was found. Configure DB_RECOVERY_FILE_DEST and DB_RECOVERY_FILE_DEST_SIZE before running FRA pressure scenario 61."
      elif printf "%s\n" "$output" | grep -q "FRA usage is zero"; then
        printf "FRA pressure cannot be simulated because current FRA usage is zero. Generate archived redo or a small lab backup first, then rerun validation."
      elif printf "%s\n" "$output" | grep -q "FRA pressure cannot be simulated"; then
        printf "%s" "$(validation_reason_from_output "$output")"
      else
        return "$FAIL"
      fi
      ;;
    62)
      if printf "%s\n" "$output" | grep -q "No available local archived redo log"; then
        printf "No available local archived redo log was found. Generate archived redo with log switches and keep it available before running scenario 62."
      else
        return "$FAIL"
      fi
      ;;
    63)
      if printf "%s\n" "$output" | grep -q "No temporary tablespace/tempfile metadata"; then
        printf "No temporary tablespace/tempfile metadata was found for the selected container. Add a tempfile or choose a different PDB before running scenario 63."
      else
        return "$FAIL"
      fi
      ;;
    66)
      if printf "%s\n" "$output" | grep -q "FSFO observer was not detected"; then
        printf "FSFO observer was not detected. Enable Fast-Start Failover, start an observer, and confirm V\$DATABASE.FS_FAILOVER_OBSERVER_PRESENT or DGMGRL evidence before running scenario 66."
      else
        return "$FAIL"
      fi
      ;;
    67)
      if printf "%s\n" "$output" | grep -q "No managed standby recovery process"; then
        printf "No managed standby recovery process was detected. Start standby apply and confirm an MRP process in V\$MANAGED_STANDBY before running scenario 67."
      else
        return "$FAIL"
      fi
      ;;
    68)
      if printf "%s\n" "$output" | grep -q "No remote standby archive destination"; then
        printf "No enabled remote standby archive destination was found. Configure Data Guard transport and confirm V\$ARCHIVE_DEST TARGET='STANDBY' before running scenario 68."
      else
        return "$FAIL"
      fi
      ;;
    70)
      if printf "%s\n" "$output" | grep -q "No RAC VIP resources"; then
        printf "No RAC VIP resources were visible to crsctl. Run scenario 70 on a RAC/GI node with Grid Infrastructure commands in PATH."
      else
        return "$FAIL"
      fi
      ;;
    71)
      if printf "%s\n" "$output" | grep -Eq "No srvctl-managed database service|Service .* is not running"; then
        printf "No running srvctl-managed database service was available. Create/start a database service, or supply --service-name for scenario 71."
      else
        return "$FAIL"
      fi
      ;;
    72)
      if printf "%s\n" "$output" | grep -q "No redundant ASM disk candidate"; then
        printf "No redundant ASM disk candidate was found. Scenario 72 requires a NORMAL/HIGH/FLEX/EXTENDED redundancy ASM disk group with online disks; EXTERN redundancy remains plan-only unsuitable for single-disk failure practice."
      else
        return "$FAIL"
      fi
      ;;
    73|79)
      if printf "%s\n" "$output" | grep -q "ORDS binary was not found"; then
        printf "ORDS is not installed or not in PATH. Install/configure ORDS on this host before running scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "ORDS systemd service unit was not found"; then
        printf "The ORDS systemd service unit ${ORDS_SERVICE_NAME} was not found. Configure ORDS as a managed service before running scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "requires --ords-lb-url"; then
        printf "Scenario 79 requires --ords-lb-url/CRASHSIM_ORDS_LB_URL or a reachable peer ORDS node so the drill can validate continuity."
      else
        return "$FAIL"
      fi
      ;;
    74)
      if printf "%s\n" "$output" | grep -q "ORDS configuration directory was not found"; then
        printf "ORDS configuration directory was not found at ${ORDS_CONFIG_DIR}. Configure ORDS or pass --ords-config-dir before running scenario 74."
      elif printf "%s\n" "$output" | grep -q "ORDS config directory is not writable"; then
        printf "ORDS config directory cannot be renamed by $(id -un). Configure the approved ORDS helper ${ORDS_PRIV_HELPER}, or make the ORDS config parent writable in a lab."
      else
        return "$FAIL"
      fi
      ;;
    75)
      if printf "%s\n" "$output" | grep -q "ORDS binary was not found"; then
        printf "ORDS is not installed or not in PATH. Install/configure ORDS before running scenario 75."
      elif printf "%s\n" "$output" | grep -q "ORDS configuration directory was not found"; then
        printf "ORDS configuration directory was not found at ${ORDS_CONFIG_DIR}. Configure ORDS or pass --ords-config-dir before running scenario 75."
      elif printf "%s\n" "$output" | grep -q "requires approved ORDS service restart privileges"; then
        printf "Scenario 75 requires approved ORDS service restart privileges. Configure ${ORDS_PRIV_HELPER} or narrow sudo service control for ${ORDS_SERVICE_NAME}."
      else
        return "$FAIL"
      fi
      ;;
    76)
      if printf "%s\n" "$output" | grep -q "No unlocked APEX/ORDS runtime account"; then
        printf "No unlocked APEX/ORDS runtime account was found. Install/configure APEX/ORDS in the selected container and confirm APEX_PUBLIC_USER or ORDS_PUBLIC_USER exists before running scenario 76."
      else
        return "$FAIL"
      fi
      ;;
    77)
      if printf "%s\n" "$output" | grep -q "No APEX images/static files directory"; then
        printf "No APEX static images directory was found. Install APEX static files and pass --apex-images-dir before running scenario 77."
      else
        return "$FAIL"
      fi
      ;;
    78|80)
      if printf "%s\n" "$output" | grep -q "ORDS/APEX smoke URL is not reachable"; then
        printf "The ORDS/APEX smoke URL is not reachable: ${ORDS_URL}. Start/configure ORDS and validate network access before running scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "APEX is not installed"; then
        printf "APEX is not installed in the selected target container. Install APEX in the PDB and rerun validation for scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "APEX session driver is not executable"; then
        printf "Scenario 80 browser-session driver is not executable: ${APEX_SESSION_DRIVER}. Fix permissions or omit --apex-session-driver for read-only URL evidence."
      elif printf "%s\n" "$output" | grep -q "APEX session driver self-check failed"; then
        printf "Scenario 80 browser-session driver self-check failed for ${APEX_SESSION_DRIVER}. Verify Node.js, Playwright, and the Chromium browser runtime, or omit --apex-session-driver for read-only URL evidence."
      elif printf "%s\n" "$output" | grep -q "APEX session username was supplied"; then
        printf "Scenario 80 browser-session login needs CRASHSIM_APEX_SESSION_PASSWORD or --apex-session-password when --apex-session-username is supplied."
      else
        return "$FAIL"
      fi
      ;;
    81|82)
      if printf "%s\n" "$output" | grep -q "APEX is not installed"; then
        printf "APEX is not installed in the selected target container. Install APEX in the PDB and rerun validation for scenario %s." "$id"
      else
        return "$FAIL"
      fi
      ;;
    *)
      return "$FAIL"
      ;;
  esac
  return "$SUCCESS"
}

validation_guardrail_reason() {
  local id="$1"
  case "$id" in
    28)
      printf "Scenario 28 ORACLE_HOME loss requires an external restore/reinstall plan and is intentionally dry-run/manual only in this framework."
      return "$SUCCESS"
      ;;
    25)
      if [[ -z "$PIECE_HANDLE" ]]; then
        if [[ "$LOCAL_ONLY" != "1" || -z "$MAX_TARGETS" ]]; then
          printf "Scenario 25 can see local and object-storage backup handles; execution requires --piece-handle or --local-only --max-targets <n>."
          return "$SUCCESS"
        fi
      fi
      ;;
    45)
      if [[ -z "$TARGET_PDB" || "$TARGET_PDB" != CRASHSIM_* ]]; then
        printf "Scenario 45 can only execute against a disposable PDB whose name starts with CRASHSIM_. Current PDB: %s." "${TARGET_PDB:-not set}"
        return "$SUCCESS"
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
    if reason="$(validation_requirement_blocker_reason "$id" "$req_output")"; then
      SCENARIO_VALIDATION_REASON="$reason"
    else
      SCENARIO_VALIDATION_REASON="$(validation_reason_from_output "$req_output")"
    fi
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
    if reason="$(validation_no_target_reason "$id" "$plan_output")"; then
      SCENARIO_VALIDATION_REASON="$reason"
    else
      SCENARIO_VALIDATION_REASON="$(validation_reason_from_output "$plan_output")"
    fi
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

  if find_sqlplus_if_available; then
    discover_environment
  else
    warn "Database topology discovery skipped: sqlplus was not found. Database-scoped scenarios will be marked not runnable until ORACLE_HOME or SQLPLUS is set."
  fi

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

scenario_readiness_append_rows() {
  local report_file="$1"
  local empty_message="$2"
  shift 2
  local row

  if [[ "$#" -eq 0 ]]; then
    printf "%s\n" "$empty_message" >>"$report_file"
    return "$SUCCESS"
  fi

  printf "| ID | Group | Scope | Impact | Scenario | Reason |\n" >>"$report_file"
  printf "| --- | --- | --- | --- | --- | --- |\n" >>"$report_file"
  for row in "$@"; do
    printf "%s\n" "$row" >>"$report_file"
  done
}

generate_scenario_readiness_report() {
  local id status reason row name con_id open_mode discovery_note
  local runnable_count=0 plan_only_count=0 not_runnable_count=0 total_count=0
  local report_file latest_file
  local -a runnable_rows=()
  local -a plan_only_rows=()
  local -a not_runnable_rows=()

  if find_sqlplus_if_available; then
    discover_environment
    discovery_note="SQL*Plus discovery completed."
  else
    discovery_note="SQL*Plus was not found. Database-scoped scenarios are blocked until ORACLE_HOME or SQLPLUS is set on a host with a created database."
    warn "Database topology discovery skipped: sqlplus was not found. Scenario readiness report will still be generated with blockers."
  fi

  for id in "${SCENARIO_IDS[@]}"; do
    total_count=$((total_count + 1))
    if validate_scenario_can_run "$id"; then
      status="RUNNABLE"
      reason="$SCENARIO_VALIDATION_REASON"
      runnable_count=$((runnable_count + 1))
    else
      if [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
        status="PLAN-ONLY"
        plan_only_count=$((plan_only_count + 1))
      else
        status="NOT-RUNNABLE"
        not_runnable_count=$((not_runnable_count + 1))
      fi
      reason="$SCENARIO_VALIDATION_REASON"
    fi

    reason="$(printf "%s" "$reason" | validation_single_line)"
    row="| \`${id}\` | $(md_escape "${SCENARIO_GROUP[$id]}") | $(md_escape "${SCENARIO_SCOPE[$id]}") | $(md_escape "${SCENARIO_IMPACT[$id]}") | $(md_escape "${SCENARIO_TITLE[$id]}") | $(md_escape "$reason") |"
    case "$status" in
      RUNNABLE) runnable_rows+=("$row") ;;
      PLAN-ONLY) plan_only_rows+=("$row") ;;
      *) not_runnable_rows+=("$row") ;;
    esac
  done

  report_file="${LOG_DIR}/crashsim_scenario_readiness_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_scenario_readiness_latest.md"

  {
    printf "# CrashSimulator Scenario Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf -- '- Target PDB context: `%s`\n' "${TARGET_PDB:-not set}"
    printf -- '- Target schema context: `%s`\n' "${TARGET_SCHEMA:-not set}"
    printf -- '- Target FILE# context: `%s`\n' "${TARGET_FILE_NO:-not set}"
    printf "\nThis report validates the discovered target environment against the CrashSimulator scenario registry. The same requirement checks, topology gates, target selection, and execution guardrails are used by scenario execution, so unavailable scenarios are blocked before destructive code runs.\n"

    printf "\n## Current Topology\n\n"
    printf "| Signal | Value |\n"
    printf "| --- | --- |\n"
    printf "| Host | %s |\n" "$(md_escape "${HOST_NAME:-unknown}")"
    printf "| OS user | %s |\n" "$(md_escape "$(id -un)")"
    printf "| Oracle home | %s |\n" "$(md_escape "${ORACLE_HOME:-unknown}")"
    printf "| SQL*Plus | %s |\n" "$(md_escape "${SQLPLUS_BIN:-unknown}")"
    printf "| Discovery note | %s |\n" "$(md_escape "$discovery_note")"
    printf "| Database name | %s |\n" "$(md_escape "${DB_NAME:-unknown}")"
    printf "| DB unique name | %s |\n" "$(md_escape "${DB_UNIQUE_NAME:-unknown}")"
    printf "| Database role | %s |\n" "$(md_escape "${DB_ROLE:-unknown}")"
    printf "| Open mode | %s |\n" "$(md_escape "${DB_OPEN_MODE:-unknown}")"
    printf "| CDB | %s |\n" "$(md_escape "${DB_CDB:-unknown}")"
    printf "| Instance | %s |\n" "$(md_escape "${INSTANCE_NAME:-unknown}")"
    printf "| Thread | %s |\n" "$(md_escape "${INSTANCE_THREAD:-unknown}")"
    printf "| RAC parallel | %s |\n" "$(md_escape "${INSTANCE_PARALLEL:-unknown}")"
    printf "| Cluster type | %s |\n" "$(md_escape "${CLUSTER_TYPE:-unknown}")"
    printf "| GI managed | %s |\n" "$(md_escape "${GI_MANAGED:-0}")"
    printf "| Storage type | %s |\n" "$(md_escape "${STORAGE_TYPE:-unknown}")"
    printf "| Protection mode | %s |\n" "$(md_escape "${DB_PROTECTION_MODE:-unknown}")"
    printf "| Switchover status | %s |\n" "$(md_escape "${DB_SWITCHOVER_STATUS:-unknown}")"
    printf "| SPFILE | %s |\n" "$(md_escape "${SPFILE_PATH:-not detected}")"
    printf "| Password file | %s |\n" "$(md_escape "${PASSWORD_FILE_PATH:-not detected}")"
    printf "| FRA | %s |\n" "$(md_escape "${FRA_PATH:-not configured}")"

    if [[ "$DB_CDB" == "YES" ]]; then
      printf "\n## PDBs\n\n"
      if [[ "${#PDB_ROWS[@]}" -eq 0 ]]; then
        printf "No user PDBs were discovered.\n"
      else
        printf "| PDB | CON_ID | Open mode |\n"
        printf "| --- | --- | --- |\n"
        for row in "${PDB_ROWS[@]}"; do
          IFS='|' read -r name con_id open_mode <<<"$row"
          printf "| %s | %s | %s |\n" "$(md_escape "$name")" "$(md_escape "$con_id")" "$(md_escape "$open_mode")"
        done
      fi
    fi

    printf "\n## Readiness Summary\n\n"
    printf "| Status | Count | Meaning |\n"
    printf "| --- | ---: | --- |\n"
    printf "| RUNNABLE | %s | Scenario can be selected for dry-run and, when requested, execution. |\n" "$runnable_count"
    printf "| PLAN-ONLY | %s | Scenario can produce useful dry-run/runbook evidence, but execution is blocked by a guardrail or provider-specific limitation. |\n" "$plan_only_count"
    printf "| NOT-RUNNABLE | %s | Scenario is not available in the current topology or target context. |\n" "$not_runnable_count"
    printf "| TOTAL | %s | Registered scenarios evaluated. |\n" "$total_count"
  } >"$report_file" || die "Unable to write scenario readiness report: $report_file"

  append_report_section "$report_file" "Runnable Scenarios"
  scenario_readiness_append_rows "$report_file" "No scenarios are runnable in the current target context." "${runnable_rows[@]}"

  append_report_section "$report_file" "Dry-Run Planning Only"
  scenario_readiness_append_rows "$report_file" "No scenarios are limited to dry-run planning only." "${plan_only_rows[@]}"

  append_report_section "$report_file" "Not Runnable Now"
  scenario_readiness_append_rows "$report_file" "No scenarios are blocked by topology or target context." "${not_runnable_rows[@]}"

  append_report_section "$report_file" "How CrashSimulator Uses This Result"
  {
    printf -- '- `--scenario <id> --execute`, `--protect <id> --execute`, and aleatory scenario execution run readiness validation before confirmation or destructive actions.\n'
    printf -- '- Guided Workflow scenario selection now shows the selected scenario readiness status immediately.\n'
    printf -- '- Use only `RUNNABLE` scenarios for execution drills. Review `PLAN-ONLY` and `NOT-RUNNABLE` reasons before changing topology, targets, or helper coverage.\n'
    printf -- '- Re-run this report after changing database topology, adding PDBs, multiplexing redo/control files, configuring Data Guard, adding ASM/GI lab disks, reseeding logical objects, or taking fresh backups.\n'
  } >>"$report_file"

  append_report_section "$report_file" "Recommended Next Commands"
  {
    printf '```bash\n'
    printf './%s --validate-scenario <id> --pdb %s\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf './%s --scenario <id> --pdb %s --dry-run\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf './%s --runbook <id> --pdb %s\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf './%s --health-check --pdb %s\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf '```\n'
  } >>"$report_file"

  cp "$report_file" "$latest_file" || die "Unable to update latest scenario readiness report: $latest_file"

  echo "Scenario readiness report generated: ${report_file}"
  echo "Latest scenario readiness report: ${latest_file}"
  echo
  cat "$report_file"
  maybe_render_html "$report_file"
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    render_artifact_html "$latest_file"
  fi
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
    die "Automated RMAN protection is not registered for scenario ${id}. Use --runbook ${id} for manual guidance."

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
    30|32|33|34|35|37|39|40|41|42) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

