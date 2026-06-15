#!/usr/bin/env bash
set -uo pipefail

SOURCE_DIR="."
OUTPUT_DIR=""

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --source)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --source requires a directory" >&2; exit 1; }
      SOURCE_DIR="$2"
      shift 2
      ;;
    --output)
      [[ "$#" -ge 2 ]] || { echo "ERROR: --output requires a directory" >&2; exit 1; }
      OUTPUT_DIR="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--source <dir>] [--output <dir>]"
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

[[ -d "$SOURCE_DIR" ]] || { echo "ERROR: source directory not found: $SOURCE_DIR" >&2; exit 1; }
if [[ -z "$OUTPUT_DIR" ]]; then
  OUTPUT_DIR="${SOURCE_DIR%/}/public_artifacts_sanitized_$(date -u +%Y%m%d_%H%M%S)"
fi
mkdir -p "$OUTPUT_DIR" || { echo "ERROR: cannot create output directory: $OUTPUT_DIR" >&2; exit 1; }

is_public_text_artifact() {
  local file="$1"
  case "$file" in
    *.md|*.txt|*.log|*.evidence|*.json|*.html|*.csv|*.sql|*.rman|*.manifest|*.conf|*.sample|*.example)
      return 0
      ;;
  esac
  return 1
}

sanitize_stream() {
  sed -E \
    -e 's#-----BEGIN [A-Z ]*PRIVATE KEY-----.*#-----BEGIN PRIVATE KEY-----<redacted>#g' \
    -e 's#-----END [A-Z ]*PRIVATE KEY-----#-----END PRIVATE KEY-----#g' \
    -e 's#ocid1\.[A-Za-z0-9_.-]+#ocid1.<redacted>#g' \
    -e 's#([0-9]{1,3}\.){3}[0-9]{1,3}#<ip-redacted>#g' \
    -e 's#([Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Pp][Aa][Ss][Ss][Ww][Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Tt][Oo][Kk][Ee][Nn])([[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]<][^[:space:]]*#\1\2<redacted>#g' \
    -e 's#(connect[[:space:]]+[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#Ig' \
    -e 's#(CRASHSIM_[A-Z0-9_]*(PASSWORD|TOKEN|SECRET)[A-Z0-9_]*=).*#\1<redacted>#g'
}

count=0
while IFS= read -r file; do
  [[ -f "$file" ]] || continue
  is_public_text_artifact "$file" || continue
  rel="${file#"$SOURCE_DIR"/}"
  dest="${OUTPUT_DIR}/${rel}"
  mkdir -p "$(dirname "$dest")" || exit 1
  sanitize_stream <"$file" >"$dest" || exit 1
  count=$((count + 1))
done < <(
  find "$SOURCE_DIR" \
    \( -path '*/.git/*' -o -path '*/node_modules/*' -o -path '*/__pycache__/*' -o -path '*/crashsimulator_logs/*' -o -path '*/public_artifacts_sanitized_*/*' \) -prune \
    -o -type f -print 2>/dev/null | sort
)

echo "Sanitized ${count} text artifact(s)."
echo "Output directory: ${OUTPUT_DIR}"
