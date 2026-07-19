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
    *'<redacted>'*|*'<password>'*|*'<pw>'*|*'<pwd>'*|*'<pass>'*|*'<secret>'*|*'<token>'*|*'<value>'*|*'not set'*|*'not-set'*|*'example'*|*'EXAMPLE'*|*'${'*|*'_ENV='*|*'_PASSWORD_ENV='*|*'_TOKEN_ENV='*|*'CRASHSIM_SECRET_SCAN_PATH='*)
      return 0
      ;;
    # HTML input hint text and OCID prefix-validation messages / placeholders
    # are documentation, not credentials: e.g. an SMTP/private-key <textarea>
    # placeholder, "must start with ocid1.user.", or an ocid1...<group-ocid>
    # template in a runbook.
    *'placeholder="-----BEGIN'*|*'must start with ocid1.'*|*'ocid1.fnfunc.'*|*'-ocid>'*)
      return 0
      ;;
    # sudoers 'NOPASSWD:' is sudo's no-password-required tag on a Cmnd rule
    # (the opposite of a secret), never a credential assignment - skip such
    # lines, e.g. the ASM-privilege sudoers examples in the user guide.
    *'ALL=('*'NOPASSWD:'*)
      return 0
      ;;
    *'ocid1.'*'...'*|*'BEGIN .*PRIVATE KEY'*|*'BEGIN [A-Z ]*PRIVATE KEY'*|*'"$upper" == *"-----BEGIN'*|*'Private key material detected.'*)
      return 0
      ;;
    *'--sys-password='*|*'--rman-catalog='*|*'--apex-session-password='*|*'sys.stdin.readline'*|*'Invalid '*' password environment variable name'*|*'passwordVisible'*|*'passwordSelector'*|*'input[type='*|*'process.env.CRASHSIM_'*)
      return 0
      ;;
    *'confirmation_token_hash'*|*'CONFIRMATION_TOKEN_HASH'*|*'tokenHashPresent'*)
      return 0
      ;;
    *'apex_application.g_f'*|*'apex_authentication.login'*|*'secrets_found'*)
      # APEX login binds p_password to a runtime form-field accessor
      # (apex_application.g_fNN); 'secrets_found' is a scan-count metric. Neither
      # carries a secret literal.
      return 0
      ;;
    *'p_web_password'*|*'p_new_password'*|*'p_change_password_on_first_use'*)
      # apex_util.create_user/edit_user named parameters (crashsim_user_admin_pkg);
      # these bind PL/SQL variables, not secret literals.
      return 0
      ;;
    *'password=null'*|*'password = null'*|*'password := null'*|*'password=NULL'*|*'password = NULL'*)
      # Assigning NULL SCRUBS a transient password column (e.g. the p75 user
      # provisioning queue clears web_password once processed) - the opposite
      # of embedding a secret.
      return 0
      ;;
    *'NOPASSWD:'*)
      # sudoers syntax in runbook/guide documentation (e.g. the ASM privilege
      # prerequisite): NOPASSWD is a privilege-grant keyword, not a secret.
      return 0
      ;;
  esac
  return 1
}

scan_text_file() {
  local file="$1" match line_no line upper pattern
  # The assignment class excludes '>' so a PL/SQL named-parameter association
  # (password => l_pw, p_output_password => p_password) is NOT read as an inline
  # secret - the value after '=>' is always a bind variable/expression, never a
  # literal. The OCID class requires the 24+ char suffix of a real OCID, so a
  # prefix reference (ocid1.user.) or placeholder (ocid1..<x>) does not match.
  pattern="-----BEGIN .*PRIVATE KEY-----|[A-Za-z0-9_]*(password|passwd|secret|token|private_key|access_key)[A-Za-z0-9_]*[[:space:]]*[:=][[:space:]]*[^[:space:]\"'<{\$\*>]|ocid1\\.[A-Za-z0-9_.-]{24,}"
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
    if [[ "$upper" =~ [A-Z0-9_]*(PASSWORD|PASSWD|SECRET|TOKEN|PRIVATE_KEY|ACCESS_KEY)[A-Z0-9_]*[[:space:]]*[:=][[:space:]]*[^[:space:]\"\'\<\{\$\*\>] ]]; then
      if ! line_is_placeholder "$line"; then
        print_finding "HIGH" "$file" "$line_no" "Possible inline secret assignment detected."
      fi
    fi
    if [[ "$line" =~ ocid1\.[A-Za-z0-9_.-]{24,} ]] && ! line_is_placeholder "$line"; then
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
