#!/usr/bin/env bash
set -uo pipefail

REMOTE_USER="${CRASHSIM_REMOTE_USER:-oracle}"
REMOTE_PATH="${CRASHSIM_REMOTE_PATH:-/tmp/crashsimulator}"
SSH_BIN="${CRASHSIM_SSH_BIN:-ssh}"
SSH_OPTS="${CRASHSIM_SSH_OPTS:-}"
LOCAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd)"

if [[ "$#" -gt 0 ]]; then
  NODES="$*"
else
  NODES="${CRASHSIM_REMOTE_NODES:-}"
fi

if [[ -z "$NODES" ]]; then
  echo "No remote nodes provided."
  echo "Set CRASHSIM_REMOTE_NODES='host1 host2' or pass hostnames as arguments."
  exit 0
fi

checksum_file() {
  local file="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    sha256sum "$file" | awk '{print $1}'
  fi
}

LOCAL_DRIVER_SUM="$(checksum_file "${LOCAL_ROOT}/CrashSimulatorV2.sh")"
FAILURES=0

echo "CrashSimulator multi-node sync check"
echo "Local root: ${LOCAL_ROOT}"
echo "Remote user/path: ${REMOTE_USER}@<node>:${REMOTE_PATH}"

for node in $NODES; do
  echo
  echo "Node: ${node}"
  remote_sum="$($SSH_BIN $SSH_OPTS "${REMOTE_USER}@${node}" "cd '${REMOTE_PATH}' 2>/dev/null && (shasum -a 256 CrashSimulatorV2.sh 2>/dev/null || sha256sum CrashSimulatorV2.sh 2>/dev/null) | awk '{print \\\$1}'" 2>/dev/null || true)"
  if [[ -z "$remote_sum" ]]; then
    echo "  FAIL: unable to read remote CrashSimulatorV2.sh checksum"
    FAILURES=$((FAILURES + 1))
  elif [[ "$remote_sum" == "$LOCAL_DRIVER_SUM" ]]; then
    echo "  OK: CrashSimulatorV2.sh checksum matches"
  else
    echo "  FAIL: CrashSimulatorV2.sh checksum differs"
    echo "       local=${LOCAL_DRIVER_SUM}"
    echo "       remote=${remote_sum}"
    FAILURES=$((FAILURES + 1))
  fi

  for helper in \
    tools/crashsim_configure_ha_lab.sh \
    tools/crashsim_install_apex_ords_lab.sh \
    tools/crashsim_apex_ords_state_check.sh \
    tools/crashsim_ords_wrapper.sh; do
    if [[ -f "${LOCAL_ROOT}/${helper}" ]]; then
      if $SSH_BIN $SSH_OPTS "${REMOTE_USER}@${node}" "test -f '${REMOTE_PATH}/${helper}'" >/dev/null 2>&1; then
        echo "  OK: ${helper} present"
      else
        echo "  WARN: ${helper} missing remotely"
      fi
    fi
  done
done

[[ "$FAILURES" -eq 0 ]]
