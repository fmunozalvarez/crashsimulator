#!/usr/bin/env bash
set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
SCAN_ROOT="$ROOT_DIR"
SCAN_ALL=0
FAIL_ON_WARNINGS="${CRASHSIM_RELEASE_GATE_FAIL_ON_WARNINGS:-0}"
HIGH=0
WARNINGS=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--scan-path <path>] [--scan-all] [--fail-on-warnings]

Release-focused secret and evidence gate. The default profile scans the source
paths that are copied into the runtime ZIP and intentionally skips bulky capture
archives unless --scan-all is used.
EOF
}

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --scan-path)
      [[ "$#" -ge 2 ]] || { usage >&2; exit 2; }
      SCAN_ROOT="$2"
      shift 2
      ;;
    --scan-all)
      SCAN_ALL=1
      shift
      ;;
    --fail-on-warnings)
      FAIL_ON_WARNINGS=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

abs_path() {
  local path="$1"
  if [[ -d "$path" ]]; then
    (cd "$path" >/dev/null 2>&1 && pwd)
  else
    local dir base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    (cd "$dir" >/dev/null 2>&1 && printf "%s/%s" "$(pwd)" "$base")
  fi
}

SCAN_ROOT="$(abs_path "$SCAN_ROOT")"

print_issue() {
  local severity="$1" file="$2" message="$3"
  printf '%s|%s|%s\n' "$severity" "$file" "$message"
  case "$severity" in
    HIGH) HIGH=$((HIGH + 1)) ;;
    WARN) WARNINGS=$((WARNINGS + 1)) ;;
  esac
}

line_is_placeholder() {
  local line="$1"
  case "$line" in
    *'<password>'*|*'<redacted>'*|*'<secret>'*|*'<token>'*|*'example'*|*'EXAMPLE'*|*'ocid1.'*'...'|*'ocid1.<redacted>'*|*'CRASHSIM_'*'_ENV'*|*'PASSWORD_ENV'*|*'WALLET_PASSWORD_ENV'*)
      return 0
      ;;
  esac
  return 1
}

scan_one_file_name() {
  local file="$1" base lower
  base="$(basename "$file")"
  lower="$(printf "%s" "$base" | tr '[:upper:]' '[:lower:]')"

  case "$base" in
    *.key|*.pem|id_rsa|id_dsa|id_ecdsa|id_ed25519|ewallet.p12|cwallet.sso|*.sso|*.p12|*.jks|*.keystore|Wallet_*.zip|wallet_*.zip)
      print_issue "HIGH" "$file" "Private key or Oracle wallet artifact must not be included in release material."
      ;;
    *.tgz|*.tar|*.tar.gz)
      print_issue "HIGH" "$file" "Raw archive evidence should not be included in runtime release material."
      ;;
  esac

  if [[ "$file" == *"/crashsimulator_logs/audit/"* || "$file" == *"/audit/20"*"/crashsim_audit_"* ]]; then
    print_issue "HIGH" "$file" "Raw audit log/evidence directory detected."
  fi

  if [[ "$lower" == *dbsat* ]]; then
    case "$lower" in
      *sanitized*|*sanitize*|*summary*|*sample*|*fixture*) ;;
      *.html|*.json|*.xlsx|*.zip)
        print_issue "HIGH" "$file" "Raw DBSAT report-like file detected; keep only sanitized summaries."
        ;;
    esac
  fi
}

scan_one_text_file() {
  local file="$1" match line_no line
  case "$file" in
    *.sh|*.bash|*.sql|*.rman|*.md|*.txt|*.log|*.evidence|*.json|*.conf|*.example|*.sample|*.manifest|*.cjs|*.js|*.py|*.yml|*.yaml|*.csv|*.html)
      ;;
    *)
      return 0
      ;;
  esac

  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    line_no="${match%%:*}"
    line="${match#*:}"
    if line_is_placeholder "$line"; then
      continue
    fi
    if [[ "$line" =~ [A-Za-z0-9_.-]+/[\"\']?[^[:space:]@/\"\']+[\"\']?@[A-Za-z0-9_.:-]+ ]]; then
      print_issue "HIGH" "${file}:${line_no}" "Credential-bearing database connect string detected."
    fi
    if [[ "$line" =~ ocid1\.[A-Za-z0-9_.-]{24,} ]]; then
      print_issue "WARN" "${file}:${line_no}" "OCI OCID detected; confirm this artifact is intentionally public."
    fi
  done < <(grep -nE 'ocid1\.|[A-Za-z0-9_.-]+/["'\'']?[^[:space:]@/"'\'']+["'\'']?@[A-Za-z0-9_.:-]+' "$file" 2>/dev/null || true)
}

scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  scan_one_file_name "$file"
  scan_one_text_file "$file"
}

scan_path() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  if [[ -f "$path" ]]; then
    scan_file "$path"
    return 0
  fi
  while IFS= read -r file; do
    scan_file "$file"
  done < <(find "$path" \
    \( -path '*/.git/*' \
    -o -path '*/node_modules/*' \
    -o -path '*/__pycache__/*' \
    -o -path '*/dist/*' \
    -o -path '*/assets/tutorial/*' \
    -o -path '*/public_artifacts_sanitized_*/*' \) -prune \
    -o -type f -print 2>/dev/null)
}

echo "CrashSimulator release secret gate"
echo "Scan root: ${SCAN_ROOT}"
echo "Format: SEVERITY|path[:line]|message"

if [[ -x "${ROOT_DIR}/tools/crashsim_secret_scan.sh" ]]; then
  secret_output="$(bash "${ROOT_DIR}/tools/crashsim_secret_scan.sh" "$SCAN_ROOT" 2>&1)"
  printf "%s\n" "$secret_output" | sed -n '/^HIGH|/p;/^WARN|/p'
  secret_high="$(printf "%s\n" "$secret_output" | sed -n 's/^Summary: high=\([0-9][0-9]*\).*/\1/p' | tail -n 1)"
  secret_warn="$(printf "%s\n" "$secret_output" | sed -n 's/^Summary:.*warnings=\([0-9][0-9]*\).*/\1/p' | tail -n 1)"
  HIGH=$((HIGH + ${secret_high:-0}))
  WARNINGS=$((WARNINGS + ${secret_warn:-0}))
fi

if [[ "$SCAN_ALL" -eq 1 ]]; then
  scan_path "$SCAN_ROOT"
else
  for path in \
    CrashSimulatorV2.sh \
    crashsimulator \
    crashsim_run_baseline_backup.sh \
    crashsim_prepare_redundant_gi_lab.sh \
    crashsim_ords_priv_helper.sh \
    prepare_crashsim_fex_controlfile_multiplex.sh \
    prepare_crashsim_fex_redo_multiplex.sql \
    prepare_crashsim_redundancy.sql \
    seed_crashsim_lab.sql \
    verify_crashsim_lab.sql \
    config docs reports tools tests README.md README_V2.md SCENARIO_STATUS.md LICENSE .gitignore; do
    scan_path "${SCAN_ROOT}/${path}"
  done
fi

echo "Summary: high=${HIGH} warnings=${WARNINGS}"
if [[ "$HIGH" -gt 0 ]]; then
  exit 1
fi
if [[ "$FAIL_ON_WARNINGS" == "1" && "$WARNINGS" -gt 0 ]]; then
  exit 1
fi
exit 0
