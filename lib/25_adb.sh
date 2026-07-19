adb_scenario_exists() {
  local id="$1"
  [[ -n "${ADB_SCENARIO_TITLE[$id]:-}" ]]
}

adb_latest_evidence_file() {
  local latest=""

  if [[ -f "${LOG_DIR}/crashsim_adb_readiness_latest.evidence" ]]; then
    latest="${LOG_DIR}/crashsim_adb_readiness_latest.evidence"
  else
    latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_adb_readiness_*.evidence' 2>/dev/null | sort | tail -n 1)"
  fi
  [[ -n "$latest" && -f "$latest" ]] || return "$FAIL"
  printf "%s\n" "$latest"
}

adb_load_latest_evidence() {
  local evidence_file
  evidence_file="$(adb_latest_evidence_file 2>/dev/null || true)"
  [[ -n "$evidence_file" ]] || return "$FAIL"
  parse_adb_evidence_file "$evidence_file"
}

adb_sql_probe_ok() {
  [[ "$(adb_value connect_status UNKNOWN)" == "OK" ]]
}

adb_sql_probe_reason() {
  local status reason
  status="$(adb_value connect_status UNKNOWN)"
  reason="$(adb_value connect_reason "")"
  if [[ "$status" == "OK" ]]; then
    printf "Live SQL probe connected to %s (%s/%s)." "$(adb_value db_name UNKNOWN)" "$(adb_value open_mode UNKNOWN)" "$(adb_value database_role UNKNOWN)"
  elif [[ -n "$reason" ]]; then
    if [[ "$reason" =~ [.!?]$ ]]; then
      printf "Live SQL probe status %s: %s" "$status" "$reason"
    else
      printf "Live SQL probe status %s: %s." "$status" "$reason"
    fi
  else
    printf "Live SQL probe has not connected yet. Run the ADB readiness report after configuring wallet/descriptor and password environment variables."
  fi
}

adb_control_plane_ready() {
  [[ -n "$ADB_OCID" ]] || return "$FAIL"
  command -v oci >/dev/null 2>&1 || return "$FAIL"
}

adb_wallet_ready() {
  if [[ -n "$ADB_WALLET_DIR" && -d "$ADB_WALLET_DIR" && -f "${ADB_WALLET_DIR}/tnsnames.ora" ]]; then
    return "$SUCCESS"
  fi
  adb_sql_probe_ok
}

adb_private_endpoint_ready() {
  [[ -n "$ADB_PRIVATE_ENDPOINT" ]]
}

adb_scenario_readiness() {
  local id="$1"
  local status_var="$2"
  local reason_var="$3"
  local readiness_status readiness_reason

  case "$id" in
    ADB01|ADB03|ADB04)
      if adb_sql_probe_ok; then
        readiness_status="RUNNABLE AFTER LAB SEED"
        readiness_reason="Live SQL probe is healthy; seed disposable ADB lab objects before enabling execution helpers."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="$(adb_sql_probe_reason)"
      fi
      ;;
    ADB02)
      if adb_sql_probe_ok; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Live SQL probe is healthy; schema-drop automation remains manual until clone/export workflow helpers are added."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="$(adb_sql_probe_reason)"
      fi
      ;;
    ADB05|ADB06|ADB07)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="Latest ADB readiness evidence includes OCI metadata; clone, PITR, and backup posture can be validated from control-plane data."
      elif adb_control_plane_ready; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="ADB OCID and OCI CLI are configured; collect clone/PITR/backup metadata before execution."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure CRASHSIM_ADB_OCID and OCI CLI/profile to validate clone, PITR, and backup recoverability."
      fi
      ;;
    ADB08)
      if adb_wallet_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Wallet/client path evidence exists; use the runbook to test rotation and reconnect."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Configure an ADB wallet directory or working descriptor and run the readiness report."
      fi
      ;;
    ADB09)
      if adb_private_endpoint_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Private endpoint context is configured; validate DNS, routing, NSGs, and bastion path before any fault injection."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Set CRASHSIM_ADB_PRIVATE_ENDPOINT or use the menu context option to document the expected private endpoint path."
      fi
      ;;
    ADB10|ADB11)
      if adb_sql_probe_ok; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Live SQL probe is healthy; approved workload limits and application retry boundaries are still required."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="$(adb_sql_probe_reason)"
      fi
      ;;
    ADB12|ADB13)
      if adb_truthy_value oci_is_data_guard_enabled; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="OCI metadata reports Autonomous Data Guard enabled; verify role, lag, transition eligibility, and application reconnect path."
      elif [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="ADG DISABLED"
        readiness_reason="OCI metadata reports Autonomous Data Guard is not enabled for this ADB; enable ADG or document that DR is out of scope before ADB12/ADB13."
      elif adb_control_plane_ready; then
        readiness_status="OCI VALIDATION READY IF ADG ENABLED"
        readiness_reason="ADB OCID and OCI CLI are configured; run the readiness report to inspect Autonomous Data Guard metadata."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile and ADB OCID to inspect Autonomous Data Guard metadata."
      fi
      ;;
    ADB14)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Latest ADB readiness evidence includes OCI metadata; keep IAM checks read-only unless an approved IAM test boundary exists."
      elif adb_control_plane_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="OCI metadata access is configured; keep IAM checks read-only unless an approved IAM test boundary exists."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile and ADB OCID or compartment context to review IAM posture."
      fi
      ;;
    ADB15)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Latest ADB readiness evidence includes OCI metadata; add bucket, credential, DBMS_CLOUD, and network evidence before execution."
      elif adb_control_plane_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="OCI metadata access is configured; add bucket, credential, DBMS_CLOUD, and network evidence before execution."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile and ADB/compartment context to validate Object Storage dependencies."
      fi
      ;;
    ADB16)
      if [[ -n "$ADB_DATABASE_ACTIONS_URL" && ( "$(adb_value oci_metadata_status UNKNOWN)" == "OK" || "$(adb_value connect_status UNKNOWN)" == "OK" ) ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Database Actions URL and database/OCI evidence are available; add URL smoke checks before outage execution."
      elif [[ -n "$ADB_DATABASE_ACTIONS_URL" ]]; then
        readiness_status="CONFIG PARTIAL"
        readiness_reason="Database Actions URL is configured, but SQL/OCI readiness evidence is not fresh."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Set CRASHSIM_ADB_DATABASE_ACTIONS_URL and refresh the ADB readiness report."
      fi
      ;;
    ADB17)
      if [[ -n "$ADB_APEX_URL" && adb_sql_probe_ok ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="APEX URL and live SQL probe are available; add workspace/application browser-smoke evidence before execution."
      elif [[ -n "$ADB_APEX_URL" ]]; then
        readiness_status="CONFIG PARTIAL"
        readiness_reason="APEX URL is configured, but live SQL probe evidence is not healthy or fresh."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Set CRASHSIM_ADB_APEX_URL and refresh SQL readiness evidence."
      fi
      ;;
    ADB18)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="OCI metadata is available; verify supported clone regions, target compartment, timestamp, cost limits, and cleanup before creating a cross-region clone."
      elif adb_control_plane_ready; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="ADB OCID and OCI CLI are configured; run readiness to inspect clone region and backup retention evidence."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure CRASHSIM_ADB_OCID plus OCI CLI/profile before validating cross-region clone readiness."
      fi
      ;;
    ADB19)
      if adb_wallet_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Wallet or working connect descriptor evidence exists; inventory application wallet distribution points before drift testing."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Configure ADB wallet directory or working descriptor before wallet drift validation."
      fi
      ;;
    ADB20)
      if adb_control_plane_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="OCI CLI/profile and ADB OCID are configured; validate auth mode, token freshness, and automation credential ownership."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile/auth mode and CRASHSIM_ADB_OCID before IAM token-expiration readiness."
      fi
      ;;
    *)
      readiness_status="UNKNOWN"
      readiness_reason="Unknown ADB scenario id."
      ;;
  esac

  printf -v "$status_var" "%s" "$readiness_status"
  printf -v "$reason_var" "%s" "$readiness_reason"
}

print_adb_scenario_catalog() {
  local id status reason evidence_file

  evidence_file="$(adb_latest_evidence_file 2>/dev/null || true)"
  if [[ -n "$evidence_file" ]]; then
    parse_adb_evidence_file "$evidence_file" || true
    echo "ADB scenario catalog using latest evidence: ${evidence_file}"
  else
    ADB_EVIDENCE=()
    echo "ADB scenario catalog using current configuration only. Run --adb-readiness-report for live SQL evidence."
  fi
  echo
  printf "%-6s %-30s %-28s %s\n" "ID" "Area" "Status" "Scenario"
  printf "%-6s %-30s %-28s %s\n" "------" "------------------------------" "----------------------------" "--------"
  for id in "${ADB_SCENARIO_IDS[@]}"; do
    adb_scenario_readiness "$id" status reason
    printf "%-6s %-30s %-28s %s\n" "$id" "${ADB_SCENARIO_AREA[$id]}" "$status" "${ADB_SCENARIO_TITLE[$id]}"
  done
}

print_adb_scenario_detail() {
  local id="$1"
  local status reason evidence_file

  id="$(printf "%s" "$id" | tr '[:lower:]' '[:upper:]')"
  adb_scenario_exists "$id" || die "Unknown ADB scenario id: $id"
  evidence_file="$(adb_latest_evidence_file 2>/dev/null || true)"
  [[ -n "$evidence_file" ]] && parse_adb_evidence_file "$evidence_file" || ADB_EVIDENCE=()
  adb_scenario_readiness "$id" status reason

  echo "Autonomous Database scenario detail"
  echo "Scenario: ${id} - ${ADB_SCENARIO_TITLE[$id]}"
  echo "Area: ${ADB_SCENARIO_AREA[$id]}"
  echo "Status: ${status}"
  echo "Reason: ${reason}"
  echo "Validation: ${ADB_SCENARIO_VALIDATION[$id]}"
  echo "Recovery focus: ${ADB_SCENARIO_RECOVERY[$id]}"
  echo "Execution helper: ${ADB_SCENARIO_HELPER[$id]}"
  echo "Evidence: ${evidence_file:-not available}"
  echo
  echo "Run --adb-readiness-report --html to refresh readiness evidence before a drill."
}

list_scenarios() {
  printf "%-6s %-12s %-13s %-12s %s\n" "ID" "Group" "Scope" "Impact" "Scenario"
  printf "%-6s %-12s %-13s %-12s %s\n" "------" "-----" "-----" "------" "--------"
  local id
  for id in "${SCENARIO_IDS[@]}"; do
    printf "%-6s %-12s %-13s %-12s %s\n" \
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

