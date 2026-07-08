#!/usr/bin/env bash
#
# crashsim_seed_lab.sh — run seed_crashsim_lab.sql with a parameterised password.
#
# Removes the last hardcoded lab password (roadmap #3). The password is supplied
# at runtime — prompted hidden, or read from CRASHSIM_LAB_PASSWORD — and passed
# to SQL*Plus via a DEFINE on stdin. It never appears in argv, in a temp file,
# or (thanks to `set verify off` in the .sql) in SQL*Plus output.
#
# Usage:
#   tools/crashsim_seed_lab.sh [--connect "<sqlplus connect>"] [--sqlplus <bin>]
#
#   # interactive (prompts hidden, with confirmation):
#   tools/crashsim_seed_lab.sh
#
#   # non-interactive (CI / automation):
#   CRASHSIM_LAB_PASSWORD='Str0ng#Lab#Pass' tools/crashsim_seed_lab.sh
#
# Environment:
#   CRASHSIM_LAB_PASSWORD   If set, used as-is (no prompt). Keep it out of shell
#                           history; prefer a Vault/secret-manager injection.
#   CRASHSIM_SEED_CONNECT   SQL*Plus connect string. Default: "/ as sysdba".
#   SQLPLUS_BIN             sqlplus binary. Default: sqlplus (from PATH).
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
SEED_SQL="${ROOT_DIR}/seed_crashsim_lab.sql"

CONNECT="${CRASHSIM_SEED_CONNECT:-/ as sysdba}"
SQLPLUS_BIN="${SQLPLUS_BIN:-sqlplus}"

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --connect) CONNECT="$2"; shift 2;;
    --sqlplus) SQLPLUS_BIN="$2"; shift 2;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown argument: $1 (see --help)";;
  esac
done

[ -r "${SEED_SQL}" ] || die "seed script not found: ${SEED_SQL}"
command -v "${SQLPLUS_BIN}" >/dev/null 2>&1 || die "sqlplus not found: ${SQLPLUS_BIN} (set SQLPLUS_BIN or PATH)"

# Reject characters that would break a SQL*Plus DEFINE or a double-quoted
# Oracle password — namely quotes, ampersand (substitution), backslash, spaces.
validate_password() {
  local pw="$1"
  [ "${#pw}" -ge 8 ] || die "password must be at least 8 characters"
  case "$pw" in
    *\"*|*\'*|*'&'*|*'\'*) die "password must not contain \" ' & or backslash (SQL*Plus-unsafe)";;
    *[[:space:]]*)         die "password must not contain whitespace";;
  esac
}

# Resolve the password from the env var if present, else prompt hidden (twice).
if [ -n "${CRASHSIM_LAB_PASSWORD:-}" ]; then
  PW="${CRASHSIM_LAB_PASSWORD}"
  echo "Using password from CRASHSIM_LAB_PASSWORD."
else
  [ -t 0 ] || die "no CRASHSIM_LAB_PASSWORD set and stdin is not a TTY (cannot prompt)"
  printf 'Password for CrashSimulator lab users: ' >&2; read -rs PW;  echo >&2
  printf 'Confirm password: '                        >&2; read -rs PW2; echo >&2
  [ "${PW}" = "${PW2}" ] || die "passwords did not match"
  unset PW2
fi
validate_password "${PW}"

echo "Seeding lab schema via ${SQLPLUS_BIN} (connect: ${CONNECT}) ..."

# Feed DEFINE + @seed on stdin via a printf pipe: the value is a printf argument
# (not the format), so it stays literal, and nothing is written to disk or argv.
printf 'define crashsim_lab_password = "%s"\n@%s\n' "${PW}" "${SEED_SQL}" \
  | "${SQLPLUS_BIN}" -s -L "${CONNECT}"
rc=$?
unset PW

if [ "${rc}" -eq 0 ]; then
  echo "Lab seed completed."
else
  die "SQL*Plus exited with status ${rc} (see output above)"
fi
