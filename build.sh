#!/usr/bin/env bash
#
# build.sh - Assemble CrashSimulatorV2.sh from the lib/*.sh source modules.
#
# CrashSimulatorV2.sh is a GENERATED, single-file artifact so that deployment to
# targets stays a one-file copy and the runtime behaviour is byte-for-byte
# identical to the modular sources. Develop in lib/*.sh; run this to regenerate.
#
# Usage:
#   ./build.sh            Assemble lib/*.sh -> CrashSimulatorV2.sh (in place).
#   ./build.sh --check    Verify CrashSimulatorV2.sh matches lib/*.sh; do not
#                         write. Exit non-zero on drift (for CI / pre-commit).
#
# The parts are CONTIGUOUS slices of the original script at clean function
# boundaries (no functions were reordered), so the assembled output is identical
# to the pre-split file. PART_ORDER below is the source of truth for order.

set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
OUTPUT="${SCRIPT_DIR}/CrashSimulatorV2.sh"

# Explicit assembly order (do not rely on glob sorting).
PART_ORDER=(
  00_header.sh
  10_core.sh
  12_config.sh
  14_audit.sh
  16_topology.sh
  20_registry.sh
  25_adb.sh
  30_planning.sh
  40_recovery.sh
  45_prepare.sh
  50_artifacts.sh
  55_adb_reports.sh
  60_apex_ords.sh
  65_maa.sh
  70_reports.sh
  75_scenarios.sh
  90_argparse.sh
  80_menu.sh
  99_main.sh
)

CHECK_ONLY=0
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=1

# Assemble parts into a temp file.
tmp="$(mktemp "${TMPDIR:-/tmp}/crashsim_build.XXXXXX")" || { echo "ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -f "$tmp"' EXIT

missing=0
for part in "${PART_ORDER[@]}"; do
  if [[ ! -f "${LIB_DIR}/${part}" ]]; then
    echo "ERROR: missing source module: lib/${part}" >&2
    missing=1
  fi
done
[[ "$missing" -eq 0 ]] || exit 2

# Guard: refuse to include stray lib/*.sh not listed in PART_ORDER (prevents a
# new module being silently dropped from the build).
for f in "${LIB_DIR}"/*.sh; do
  base="$(basename "$f")"
  found=0
  for part in "${PART_ORDER[@]}"; do [[ "$part" == "$base" ]] && found=1 && break; done
  if [[ "$found" -eq 0 ]]; then
    echo "ERROR: lib/${base} exists but is not listed in PART_ORDER (build.sh)" >&2
    exit 2
  fi
done

for part in "${PART_ORDER[@]}"; do
  cat "${LIB_DIR}/${part}" >>"$tmp" || { echo "ERROR: failed reading lib/${part}" >&2; exit 2; }
done

# Sanity: the assembled script must parse.
if ! bash -n "$tmp" 2>/tmp/crashsim_build_syntax.$$; then
  echo "ERROR: assembled script failed 'bash -n':" >&2
  cat /tmp/crashsim_build_syntax.$$ >&2
  rm -f /tmp/crashsim_build_syntax.$$
  exit 1
fi
rm -f /tmp/crashsim_build_syntax.$$

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  if [[ ! -f "$OUTPUT" ]]; then
    echo "DRIFT: ${OUTPUT} does not exist; run ./build.sh" >&2
    exit 1
  fi
  if cmp -s "$tmp" "$OUTPUT"; then
    echo "OK: CrashSimulatorV2.sh is in sync with lib/*.sh"
    exit 0
  fi
  echo "DRIFT: CrashSimulatorV2.sh differs from lib/*.sh. Run ./build.sh to regenerate." >&2
  diff <(sha256sum "$OUTPUT" | awk '{print $1}') <(sha256sum "$tmp" | awk '{print $1}') >&2 || true
  exit 1
fi

# Write in place, preserving executable bit.
mode="$(stat -f '%Lp' "$OUTPUT" 2>/dev/null || stat -c '%a' "$OUTPUT" 2>/dev/null || echo 755)"
cat "$tmp" >"$OUTPUT"
chmod "$mode" "$OUTPUT" 2>/dev/null || chmod 755 "$OUTPUT"
echo "Built ${OUTPUT} from ${#PART_ORDER[@]} modules ($(wc -l <"$OUTPUT") lines, sha256 $(sha256sum "$OUTPUT" | awk '{print $1}'))."
