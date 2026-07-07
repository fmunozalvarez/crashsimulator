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
    service|services|service-review|service-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_service_review_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    apex-ords|apex|ords|apex-report|ords-report|apex-ords-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_apex_ords_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    prepare|seed|prepare-environment|seed-environment|lab-prepare)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_prepare_environment_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    adb|autonomous|autonomous-database|adb-report|adb-readiness)
      if [[ -f "${LOG_DIR}/crashsim_adb_readiness_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_adb_readiness_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_adb_readiness_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    scenario-readiness|readiness|scenario-availability|topology-scenarios)
      if [[ -f "${LOG_DIR}/crashsim_scenario_readiness_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_scenario_readiness_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_readiness_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    lifecycle|scenario-lifecycle|lifecycle-report|scenario-coverage)
      if [[ -f "${LOG_DIR}/crashsim_scenario_lifecycle_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_scenario_lifecycle_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_lifecycle_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    maa|maa-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_maa_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    resilience|resilience-score|resilience-scorecard|scorecard)
      if [[ -f "${LOG_DIR}/crashsim_resilience_scorecard_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_resilience_scorecard_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    health)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_health_check_*.log' 2>/dev/null | sort | tail -n 1)"
      ;;
    doctor|preflight|public-readiness)
      if [[ -f "${LOG_DIR}/crashsim_doctor_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_doctor_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_doctor_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    first-run|getting-started)
      if [[ -f "${LOG_DIR}/crashsim_first_run_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_first_run_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_first_run_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    limitations|public-limitations|public-beta-limitations)
      if [[ -f "${LOG_DIR}/crashsim_public_limitations_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_public_limitations_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_public_limitations_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    lifecycle-check|scenario-lifecycle-check)
      if [[ -f "${LOG_DIR}/crashsim_scenario_lifecycle_check_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_scenario_lifecycle_check_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_lifecycle_check_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
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
  local report_file latest_topology latest_config latest_backup latest_service latest_readiness latest_lifecycle latest_maa latest_resilience latest_adb latest_health latest_review
  local manifest audit_dir metadata command status started mode

  report_file="${LOG_DIR}/crashsim_review_index_${RUN_ID}.md"
  latest_topology="$(find_latest_artifact topology 2>/dev/null || true)"
  latest_config="$(find_latest_artifact config 2>/dev/null || true)"
  latest_backup="$(find_latest_artifact backup 2>/dev/null || true)"
  latest_service="$(find_latest_artifact service 2>/dev/null || true)"
  latest_readiness="$(find_latest_artifact scenario-readiness 2>/dev/null || true)"
  latest_lifecycle="$(find_latest_artifact lifecycle 2>/dev/null || true)"
  latest_maa="$(find_latest_artifact maa 2>/dev/null || true)"
  latest_resilience="$(find_latest_artifact resilience 2>/dev/null || true)"
  latest_adb="$(find_latest_artifact adb 2>/dev/null || true)"
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
    [[ -n "$latest_service" ]] && printf -- '- Latest service HA review: `%s`\n' "$latest_service"
    [[ -n "$latest_readiness" ]] && printf -- '- Latest scenario readiness report: `%s`\n' "$latest_readiness"
    [[ -n "$latest_lifecycle" ]] && printf -- '- Latest scenario lifecycle coverage report: `%s`\n' "$latest_lifecycle"
    [[ -n "$latest_maa" ]] && printf -- '- Latest MAA readiness report: `%s`\n' "$latest_maa"
    [[ -n "$latest_resilience" ]] && printf -- '- Latest resilience scorecard: `%s`\n' "$latest_resilience"
    [[ -n "$latest_adb" ]] && printf -- '- Latest Autonomous Database readiness report: `%s`\n' "$latest_adb"
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
  review_append_file_list "$report_file" "Doctor / Public Readiness Reports" 20 -name 'crashsim_doctor_*.md'
  review_append_file_list "$report_file" "First-Run Guides" 20 -name 'crashsim_first_run_*.md'
  review_append_file_list "$report_file" "Public Limitations Pages" 20 -name 'crashsim_public_limitations_*.md'
  review_append_file_list "$report_file" "Configuration Reports" 20 -name 'crashsim_config_report_*.md'
  review_append_file_list "$report_file" "Backup Strategy / Recoverability Reports" 20 -name 'crashsim_backup_report_*.md'
  review_append_file_list "$report_file" "Service HA Reviews" 20 -name 'crashsim_service_review_*.md'
  review_append_file_list "$report_file" "APEX / ORDS Readiness Reports" 20 -name 'crashsim_apex_ords_report_*.md'
  review_append_file_list "$report_file" "Seed / Prepare Environment Reports" 20 -name 'crashsim_prepare_environment_*.md'
  review_append_file_list "$report_file" "Scenario Readiness Reports" 20 -name 'crashsim_scenario_readiness_*.md'
  review_append_file_list "$report_file" "Scenario Lifecycle Coverage Reports" 20 -name 'crashsim_scenario_lifecycle_*.md'
  review_append_file_list "$report_file" "Scenario Lifecycle Consistency Checks" 20 -name 'crashsim_scenario_lifecycle_check_*.md'
  review_append_file_list "$report_file" "MAA Readiness Reports" 20 -name 'crashsim_maa_report_*.md'
  review_append_file_list "$report_file" "Resilience Scorecards" 20 -name 'crashsim_resilience_scorecard_*.md'
  review_append_file_list "$report_file" "Autonomous Database Readiness Reports" 20 -name 'crashsim_adb_readiness_*.md'
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
    printf -- '- Show latest scenario readiness report: `./%s --show-artifact latest:scenario-readiness`\n' "$PROGRAM"
    printf -- '- Show latest scenario lifecycle report: `./%s --show-artifact latest:lifecycle`\n' "$PROGRAM"
    printf -- '- Show latest resilience scorecard: `./%s --show-artifact latest:resilience`\n' "$PROGRAM"
    printf -- '- Show latest Autonomous Database readiness report: `./%s --show-artifact latest:adb`\n' "$PROGRAM"
    printf -- '- Show latest public limitations page: `./%s --show-artifact latest:public-limitations`\n' "$PROGRAM"
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

