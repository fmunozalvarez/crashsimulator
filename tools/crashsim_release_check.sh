#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
REPORT_DIR="${ROOT_DIR}/reports"
RUN_ID="$(date -u +%Y%m%d_%H%M%S)"
REPORT_FILE="${REPORT_DIR}/crashsim_release_check_${RUN_ID}.md"
FAILURES=0
WARNINGS=0

mkdir -p "$REPORT_DIR" || exit 1

add_row() {
  local status="$1" check="$2" evidence="$3" action="$4"
  printf '| `%s` | %s | %s | %s |\n' "$status" "$check" "$evidence" "$action" >>"$REPORT_FILE"
  case "$status" in
    FAIL) FAILURES=$((FAILURES + 1)) ;;
    WARN) WARNINGS=$((WARNINGS + 1)) ;;
  esac
}

one_line() {
  tr '\n' ' ' | sed 's/|/\\|/g' | cut -c1-500
}

run_check() {
  local check="$1" action="$2"
  shift 2
  local output status
  output="$("$@" 2>&1)"
  status=$?
  if [[ "$status" -eq 0 ]]; then
    add_row "OK" "$check" "passed" "No action needed."
  else
    add_row "FAIL" "$check" "$(printf '%s' "$output" | tr '\n' ' ' | sed 's/|/\\|/g' | cut -c1-500)" "$action"
  fi
}

run_secret_scan_check() {
  local output status summary high warnings evidence
  output="$(bash tools/crashsim_secret_scan.sh . 2>&1)"
  status=$?
  summary="$(printf '%s\n' "$output" | awk '/^Summary:/ {line=$0} END {print line}')"
  high="$(printf '%s' "$summary" | sed -n 's/.*high=\([0-9][0-9]*\).*/\1/p')"
  warnings="$(printf '%s' "$summary" | sed -n 's/.*warnings=\([0-9][0-9]*\).*/\1/p')"
  high="${high:-0}"
  warnings="${warnings:-0}"
  evidence="$(printf '%s' "${summary:-$output}" | one_line)"
  if [[ "$status" -ne 0 || "$high" -gt 0 ]]; then
    add_row "FAIL" "Secret scan" "$evidence" "Remove or sanitize secrets/wallets/keys before publishing."
  elif [[ "$warnings" -gt 0 ]]; then
    add_row "WARN" "Secret scan" "$evidence" "Review warnings and sanitize public artifacts when identifiers are not intended for publication."
  else
    add_row "OK" "Secret scan" "$evidence" "No action needed."
  fi
}

runtime_zip_required_entries() {
  cat <<'EOF'
CrashSimulatorV2.sh
crashsimulator
config/crashsimulator.conf.example
tools/crashsim_secret_scan.sh
tools/crashsim_sanitize_artifacts.sh
tools/crashsim_release_check.sh
tools/crashsim_node_sync_check.sh
tools/crashsim_build_runtime_zip.sh
tools/render_prepare_environment_tutorial_video.py
tools/render_first_run_public_readiness_tutorial_video.py
tools/render_public_limitations_tutorial_video.py
docs/CRASHSIMULATOR_USER_GUIDE.md
docs/CRASHSIMULATOR_V2_0_2_BETA_PRODUCT_OVERVIEW.md
docs/CRASHSIMULATOR_PUBLIC_LIMITATIONS.md
README.md
README_V2.md
SCENARIO_STATUS.md
EOF
}

check_runtime_zip_contents() {
  local zip_file="$1" entries root_prefix missing entry
  command -v unzip >/dev/null 2>&1 || { echo "unzip not available"; return 1; }
  entries="$(unzip -Z1 "$zip_file" 2>/dev/null)" || { echo "cannot list ZIP entries"; return 1; }
  root_prefix="$(printf '%s\n' "$entries" | awk -F/ 'NF > 1 {print $1; exit}')"
  [[ -n "$root_prefix" ]] || { echo "cannot determine ZIP root directory"; return 1; }
  missing=0
  while IFS= read -r entry; do
    [[ -n "$entry" ]] || continue
    if ! printf '%s\n' "$entries" | grep -qx "${root_prefix}/${entry}"; then
      echo "missing: ${entry}"
      missing=1
    fi
  done < <(runtime_zip_required_entries)
  [[ "$missing" -eq 0 ]]
}

check_runtime_zip_freshness() {
  local zip_file="$1" path newer
  [[ -f "$zip_file" ]] || { echo "ZIP not found"; return 1; }
  for path in \
    CrashSimulatorV2.sh \
    crashsimulator \
    README.md README_V2.md SCENARIO_STATUS.md \
    config docs reports tools \
    crashsim_run_baseline_backup.sh \
    crashsim_prepare_redundant_gi_lab.sh \
    crashsim_ords_priv_helper.sh; do
    [[ -e "$path" ]] || continue
    if [[ -f "$path" ]]; then
      if [[ "$path" -nt "$zip_file" ]]; then
        echo "$path is newer than $zip_file"
        return 1
      fi
    elif [[ -d "$path" ]]; then
      newer="$(find "$path" \
        \( -path '*/.git/*' \
        -o -path '*/node_modules/*' \
        -o -path '*/__pycache__/*' \
        -o -path '*/crashsimulator_logs/*' \
        -o -path '*/public_artifacts_sanitized_*/*' \
        -o -path '*/raw_archives/*' \
        -o -path 'captures/html/*' \
        -o -path '*/dist/*' \
        -o -name 'crashsim_release_check_*.md' \
        -o -name '.DS_Store' \
        -o -name '*.tgz' \
        -o -name '*.tar' \
        -o -name '*.gz' \
        -o -name '*.zip' \
        -o -name '*.mov' \
        -o -name '*.mp4' \
        -o -name '*.aiff' \
        -o -name '*.wav' \
        -o -name '*.key' \
        -o -name '*.pem' \) -prune \
        -o -type f -newer "$zip_file" -print 2>/dev/null | head -n 1)"
      if [[ -n "$newer" ]]; then
        echo "$newer is newer than $zip_file"
        return 1
      fi
    fi
  done
  return 0
}

{
  printf "# CrashSimulator Public Release Check\n\n"
  printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf -- '- Repository: `%s`\n' "$ROOT_DIR"
  printf "\n## Checks\n\n"
  printf "| Status | Check | Evidence | Recommended action |\n"
  printf "| --- | --- | --- | --- |\n"
} >"$REPORT_FILE"

cd "$ROOT_DIR" || exit 1

run_check "Bash syntax" "Fix shell syntax before publishing." bash -n CrashSimulatorV2.sh

if command -v git >/dev/null 2>&1 && [[ -d .git ]]; then
  run_check "Git whitespace check" "Fix whitespace/errors reported by git diff --check." git diff --check
else
  add_row "WARN" "Git whitespace check" "git or .git not available" "Run git diff --check from a source checkout before release."
fi

run_check "Scenario lifecycle consistency" "Fix missing scenario metadata/handlers/lifecycle text." \
  bash CrashSimulatorV2.sh --scenario-lifecycle-check --audit-retain no --no-auto-scorecard --log-dir "${ROOT_DIR}/crashsimulator_logs"

run_secret_scan_check

if [[ -d dist ]]; then
  latest_zip="$(find dist -maxdepth 1 -type f -name 'crashsimulator-*-runtime.zip' 2>/dev/null | sort | tail -n 1)"
  if [[ -n "${latest_zip:-}" ]]; then
    if command -v unzip >/dev/null 2>&1; then
      run_check "Runtime ZIP integrity" "Recreate the runtime ZIP." unzip -tq "$latest_zip"
      run_check "Runtime ZIP required contents" "Rebuild the runtime ZIP with tools/crashsim_build_runtime_zip.sh." check_runtime_zip_contents "$latest_zip"
      run_check "Runtime ZIP freshness" "Rebuild the runtime ZIP so dist/ matches the current source tree." check_runtime_zip_freshness "$latest_zip"
    else
      add_row "WARN" "Runtime ZIP integrity" "unzip not available" "Install unzip or validate the package on another host."
    fi
    if [[ -f "${latest_zip}.sha256" ]]; then
      if command -v shasum >/dev/null 2>&1; then
        expected="$(awk '{print $1}' "${latest_zip}.sha256")"
        actual="$(shasum -a 256 "$latest_zip" | awk '{print $1}')"
        if [[ "$expected" == "$actual" ]]; then
          add_row "OK" "Runtime ZIP checksum" "${latest_zip}.sha256 matches" "No action needed."
        else
          add_row "FAIL" "Runtime ZIP checksum" "checksum mismatch" "Regenerate the runtime ZIP checksum."
        fi
      elif command -v sha256sum >/dev/null 2>&1; then
        expected="$(awk '{print $1}' "${latest_zip}.sha256")"
        actual="$(sha256sum "$latest_zip" | awk '{print $1}')"
        if [[ "$expected" == "$actual" ]]; then
          add_row "OK" "Runtime ZIP checksum" "${latest_zip}.sha256 matches" "No action needed."
        else
          add_row "FAIL" "Runtime ZIP checksum" "checksum mismatch" "Regenerate the runtime ZIP checksum."
        fi
      else
        add_row "WARN" "Runtime ZIP checksum" "no sha256 tool available" "Validate checksum on another host."
      fi
    else
      add_row "WARN" "Runtime ZIP checksum" "checksum file not found for ${latest_zip}" "Publish a .sha256 checksum with the runtime ZIP."
    fi
  else
    add_row "WARN" "Runtime ZIP" "no runtime ZIP found under dist/" "Create the curated runtime ZIP before publishing a release."
  fi
else
  add_row "WARN" "Runtime ZIP" "dist/ not found" "Create the curated runtime ZIP before publishing a release."
fi

if grep -RInE 'validated and certified|now certified|Oracle certified' README.md README_V2.md docs reports SCENARIO_STATUS.md 2>/dev/null; then
  add_row "FAIL" "Certification wording" "certification-like wording found" "Use lab-validated/readiness language unless formal certification exists."
else
  add_row "OK" "Certification wording" "no prohibited certification phrase found" "No action needed."
fi

{
  printf "\n## Summary\n\n"
  printf -- '- Failures: `%s`\n' "$FAILURES"
  printf -- '- Warnings: `%s`\n' "$WARNINGS"
} >>"$REPORT_FILE"

echo "Release check report: ${REPORT_FILE}"
cat "$REPORT_FILE"
[[ "$FAILURES" -eq 0 ]]
