#!/usr/bin/env bash
set -uo pipefail

TARGET_PATH="${1:-.}"
FINDINGS=0
WARNINGS=0

print_finding() {
  local severity="$1" file="$2" line="${3:-}" message="$4"
  if [[ -n "$line" ]]; then
    printf '%s|%s:%s|%s\n' "$severity" "$file" "$line" "$message"
  else
    printf '%s|%s|%s\n' "$severity" "$file" "$message"
  fi
  case "$severity" in
    HIGH) FINDINGS=$((FINDINGS + 1)) ;;
    WARN) WARNINGS=$((WARNINGS + 1)) ;;
  esac
}

should_scan_file() {
  local file="$1"
  case "$file" in
    *.sh|*.bash|*.sql|*.rman|*.md|*.txt|*.log|*.evidence|*.json|*.conf|*.example|*.sample|*.manifest|*.cjs|*.js|*.py|*.yml|*.yaml|*.csv)
      return 0
      ;;
  esac
  return 1
}

scan_sensitive_filename() {
  local file="$1" base
  base="$(basename "$file")"
  case "$base" in
    *.key|*.pem|id_rsa|id_dsa|id_ecdsa|id_ed25519|ewallet.p12|cwallet.sso|*.jks|*.keystore|Wallet_*.zip|wallet_*.zip)
      print_finding "HIGH" "$file" "" "Sensitive key/wallet-like file should not be published."
      ;;
  esac
}

line_is_placeholder() {
  local line="$1"
  case "$line" in
    *'<redacted>'*|*'<password>'*|*'<secret>'*|*'<token>'*|*'<value>'*|*'not set'*|*'not-set'*|*'example'*|*'EXAMPLE'*|*'${'*|*'_ENV='*|*'_PASSWORD_ENV='*|*'_TOKEN_ENV='*|*'CRASHSIM_SECRET_SCAN_PATH='*)
      return 0
      ;;
    *'ocid1.'*'...'*|*'BEGIN .*PRIVATE KEY'*|*'BEGIN [A-Z ]*PRIVATE KEY'*|*'"$upper" == *"-----BEGIN'*|*'Private key material detected.'*)
      return 0
      ;;
    *'--sys-password='*|*'--rman-catalog='*|*'--apex-session-password='*|*'sys.stdin.readline'*|*'Invalid '*' password environment variable name'*|*'passwordVisible'*|*'passwordSelector'*|*'input[type='*|*'process.env.CRASHSIM_'*)
      return 0
      ;;
  esac
  return 1
}

scan_text_file() {
  local file="$1" match line_no line upper pattern
  pattern="-----BEGIN .*PRIVATE KEY-----|[A-Za-z0-9_]*(password|passwd|secret|token|private_key|access_key)[A-Za-z0-9_]*[[:space:]]*[:=][[:space:]]*[^[:space:]\"'<{\$\*]|ocid1\\."
  while IFS= read -r match; do
    [[ -n "$match" ]] || continue
    line_no="${match%%:*}"
    line="${match#*:}"
    upper="$(printf '%s' "$line" | tr '[:lower:]' '[:upper:]')"
    if [[ "$upper" == *"-----BEGIN OPENSSH PRIVATE KEY-----"* ||
          "$upper" == *"-----BEGIN RSA PRIVATE KEY-----"* ||
          "$upper" == *"-----BEGIN EC PRIVATE KEY-----"* ||
          "$upper" == *"-----BEGIN PRIVATE KEY-----"* ]]; then
      if line_is_placeholder "$line"; then
        continue
      fi
      print_finding "HIGH" "$file" "$line_no" "Private key material detected."
      continue
    fi
    if [[ "$upper" =~ [A-Z0-9_]*(PASSWORD|PASSWD|SECRET|TOKEN|PRIVATE_KEY|ACCESS_KEY)[A-Z0-9_]*[[:space:]]*[:=][[:space:]]*[^[:space:]\"\'\<\{\$\*] ]]; then
      if ! line_is_placeholder "$line"; then
        print_finding "HIGH" "$file" "$line_no" "Possible inline secret assignment detected."
      fi
    fi
    if [[ "$line" =~ ocid1\.[A-Za-z0-9_.-]+ ]] && ! line_is_placeholder "$line"; then
      print_finding "WARN" "$file" "$line_no" "OCI OCID detected; verify whether this public artifact should expose it."
    fi
  done < <(grep -nEi -- "$pattern" "$file" 2>/dev/null || true)
}

echo "CrashSimulator secret scan"
echo "Target: ${TARGET_PATH}"
echo "Format: SEVERITY|path[:line]|message"

scan_file() {
  local file="$1"
  [[ -f "$file" ]] || return
  scan_sensitive_filename "$file"
  if should_scan_file "$file"; then
    scan_text_file "$file"
  fi
}

scan_tree() {
  local root="$1"
  if [[ -f "$root" ]]; then
    scan_file "$root"
    return
  fi
  [[ -d "$root" ]] || return
  while IFS= read -r file; do
    scan_file "$file"
  done < <(
    find "$root" \
      \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/crashsimulator_logs/*' -o -path '*/public_artifacts_sanitized_*/*' -o -path '*/assets/tutorial/*' -o -path '*/captures/*' -o -path '*/dist/*' \) -prune \
      -o -type f -print 2>/dev/null | sort
  )
}

if [[ "$TARGET_PATH" == "." ]]; then
  for root in \
    CrashSimulatorV2.sh \
    crashsimulator \
    crashsim_run_baseline_backup.sh \
    crashsim_prepare_redundant_gi_lab.sh \
    crashsim_ords_priv_helper.sh \
    prepare_crashsim_fex_controlfile_multiplex.sh \
    prepare_crashsim_fex_redo_multiplex.sql \
    README.md README_V2.md SCENARIO_STATUS.md \
    config docs reports tools; do
    scan_tree "$root"
  done
else
  scan_tree "$TARGET_PATH"
fi

echo "Summary: high=${FINDINGS} warnings=${WARNINGS}"
[[ "$FINDINGS" -eq 0 ]]
