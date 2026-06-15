#!/usr/bin/env bash
#
# Java-stable ORDS launcher for CrashSimulator labs.
#
# ORDS 26.x requires Java 17+. Some Oracle database homes still expose Java 8
# first in non-interactive shells, so scenario guards can fail even when ORDS is
# correctly installed as a systemd service. Install this wrapper as `ords` in a
# standard PATH directory and set CRASHSIM_ORDS_REAL_BIN if the ORDS binary lives
# outside the default CrashSimulator lab path.

set -euo pipefail

JAVA_HOME="${CRASHSIM_ORDS_JAVA_HOME:-/usr/java/jdk-17}"
ORDS_REAL_BIN="${CRASHSIM_ORDS_REAL_BIN:-/u01/app/oracle/product/crashsim_apex_ords/ords_26.1.2/bin/ords}"

if [[ ! -x "${JAVA_HOME}/bin/java" ]]; then
  echo "ERROR: Java runtime not found or not executable: ${JAVA_HOME}/bin/java" >&2
  exit 1
fi

if [[ ! -x "$ORDS_REAL_BIN" ]]; then
  echo "ERROR: ORDS binary not found or not executable: $ORDS_REAL_BIN" >&2
  exit 1
fi

export JAVA_HOME
export PATH="${JAVA_HOME}/bin:${PATH}"

exec "$ORDS_REAL_BIN" "$@"
