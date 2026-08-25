#!/usr/bin/env bash
set -uo pipefail

# Derive the version from the artifact being packaged, never from a literal
# here. A hardcoded default silently outlived four releases: the GA build was
# named crashsimulator-v2.0.3-rc-runtime.zip while the CrashSimulatorV2.sh
# inside it said 3.0.0. A package whose name disagrees with its contents is the
# first thing a user distrusts, and rightly.
VERSION="${CRASHSIM_RELEASE_VERSION:-$(sed -n 's/^VERSION="\(.*\)"/\1/p' "$(dirname "${BASH_SOURCE[0]}")/../CrashSimulatorV2.sh" | head -1)}"
if [[ -z "$VERSION" ]]; then
  echo "ERROR: cannot read VERSION from CrashSimulatorV2.sh - refusing to build." >&2
  exit 1
fi
PACKAGE_NAME="crashsimulator-v${VERSION}"
ZIP_NAME="${PACKAGE_NAME}-runtime.zip"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"
DIST_DIR="${ROOT_DIR}/dist"
WORK_DIR="${TMPDIR:-/tmp}/crashsim_runtime_pkg_$$"
PACKAGE_DIR="${WORK_DIR}/${PACKAGE_NAME}"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

copy_if_exists() {
  local src="$1" dest="$2"
  [[ -e "${ROOT_DIR}/${src}" ]] || return 0
  mkdir -p "$(dirname "${PACKAGE_DIR}/${dest}")" || exit 1
  cp -R "${ROOT_DIR}/${src}" "${PACKAGE_DIR}/${dest}" || exit 1
}

copy_directory_filtered() {
  local src="$1"
  [[ -d "${ROOT_DIR}/${src}" ]] || return 0
  mkdir -p "${PACKAGE_DIR}/${src}" || exit 1
  (
    cd "$ROOT_DIR" || exit 1
    find "$src" \
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
      -o -name '*.pem' \
      -o -name 'ewallet.p12' \
      -o -name 'cwallet.sso' \
      -o -name '*.jks' \
      -o -name '*.keystore' \
      \) -prune \
      -o -type f -print
  ) | while IFS= read -r file; do
    mkdir -p "$(dirname "${PACKAGE_DIR}/${file}")" || exit 1
    cp "${ROOT_DIR}/${file}" "${PACKAGE_DIR}/${file}" || exit 1
  done
}

sanitize_package_artifacts() {
  if [[ -x "${ROOT_DIR}/tools/crashsim_sanitize_artifacts.sh" ]]; then
    local sanitized="${WORK_DIR}/sanitized"
    bash "${ROOT_DIR}/tools/crashsim_sanitize_artifacts.sh" --source "$PACKAGE_DIR" --output "$sanitized" >/dev/null || exit 1
    cp -R "$sanitized"/. "$PACKAGE_DIR"/ || exit 1
  fi
}

mkdir -p "$PACKAGE_DIR" "$DIST_DIR" || exit 1

for path in \
  CrashSimulatorV2.sh \
  crashsimulator \
  crashsim_run_baseline_backup.sh \
  crashsim_prepare_redundant_gi_lab.sh \
  crashsim_ords_priv_helper.sh \
  prepare_crashsim_controlfile_multiplex.sql \
  prepare_crashsim_fex_controlfile_multiplex.sh \
  prepare_crashsim_fex_redo_multiplex.sql \
  prepare_crashsim_redundancy.sql \
  seed_crashsim_lab.sql \
  verify_crashsim_lab.sql \
  drill_health_check.sql \
  drill_identify_targets.sql \
  drill_open_pdbs_if_needed.sql \
  drill_post_stabilize_full_backup.rman \
  drill_post_stabilize_validate.rman \
  drill_protect_30_5.rman \
  drill_protect_s05_post30.rman \
  drill_recover_s05.rman \
  drill_recover_s30.rman \
  drill_validate_targets.rman \
  README.md \
  README_V2.md \
  SCENARIO_STATUS.md \
  LICENSE \
  .gitignore; do
  copy_if_exists "$path" "$path"
done

# reports/ and captures/ are NOT copied: they carried the owner's own
# estate evidence - including the live repository ADB endpoint - into every
# published artifact (found 2026-08-25, public since v3.0.0). The runtime
# still CREATES reports/ on the target at run time; what must never ship is
# a pre-populated one from the build tree.
for dir in config docs assets tools; do
  copy_directory_filtered "$dir"
done

sanitize_package_artifacts

# Licence guard, the mirror of the Enterprise one. This repository is the
# Apache-2.0 edition; the packaging list copies LICENSE verbatim, so a wrong
# file here would either strip the open-source grant from a package users are
# entitled to have it in, or - worse in the other direction - ship a commercial
# licence to the community. Assert the grant is present and that no proprietary
# licence has been substituted.
if [[ ! -f "${PACKAGE_DIR}/LICENSE" ]]; then
  echo "ERROR: the package has no LICENSE file - refusing to build." >&2
  rm -rf "$PACKAGE_DIR"; exit 1
fi
if ! grep -q 'TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION' \
     "${PACKAGE_DIR}/LICENSE"; then
  echo "ERROR: the package LICENSE is not the Apache License 2.0 grant." >&2
  echo "       This is the open-source edition; it ships under Apache-2.0." >&2
  rm -rf "$PACKAGE_DIR"; exit 1
fi
if grep -qi 'Commercial Software Licence Agreement' "${PACKAGE_DIR}/LICENSE"; then
  echo "ERROR: a commercial licence is present in an open-source package." >&2
  rm -rf "$PACKAGE_DIR"; exit 1
fi

find "$PACKAGE_DIR" -type f \
  \( -name '*.sh' -o -name 'crashsimulator' -o -name '*.cjs' -o -name '*.py' \) \
  -exec chmod +x {} \; 2>/dev/null || true

(
  cd "$WORK_DIR" || exit 1
  rm -f "${DIST_DIR}/${ZIP_NAME}" "${DIST_DIR}/${ZIP_NAME}.sha256"
  zip -qr "${DIST_DIR}/${ZIP_NAME}" "$PACKAGE_NAME" || exit 1
)

if command -v shasum >/dev/null 2>&1; then
  (
    cd "$DIST_DIR" || exit 1
    shasum -a 256 "$ZIP_NAME" >"${ZIP_NAME}.sha256" || exit 1
  )
elif command -v sha256sum >/dev/null 2>&1; then
  (
    cd "$DIST_DIR" || exit 1
    sha256sum "$ZIP_NAME" >"${ZIP_NAME}.sha256" || exit 1
  )
else
  echo "WARN: no sha256 tool available; checksum was not written" >&2
fi

echo "Runtime package: ${DIST_DIR}/${ZIP_NAME}"
[[ -f "${DIST_DIR}/${ZIP_NAME}.sha256" ]] && echo "Checksum: ${DIST_DIR}/${ZIP_NAME}.sha256"
