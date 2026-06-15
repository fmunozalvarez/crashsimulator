#!/usr/bin/env bash
set -uo pipefail

ORACLE_SID="${ORACLE_SID:-crashdb1}"
ORACLE_HOME="${ORACLE_HOME:-/u02/app/oracle/product/23.0.0.0/dbhome_1}"
GRID_HOME="${GRID_HOME:-/u01/app/23.0.0.0/gridhome_1}"
export ORACLE_SID ORACLE_HOME
export PATH="${ORACLE_HOME}/bin:${GRID_HOME}/bin:${PATH}"

echo "=== CrashSimulator APEX/ORDS state check ==="
date -u '+Generated UTC: %Y-%m-%dT%H:%M:%SZ'
echo "Host: $(hostname -f 2>/dev/null || hostname)"
echo "User: $(id -un)"
echo "ORACLE_SID=${ORACLE_SID}"
echo "ORACLE_HOME=${ORACLE_HOME}"
echo

echo "=== OS tooling ==="
for tool in java sqlplus ords curl systemctl unzip; do
  printf '%-10s %s\n' "${tool}:" "$(command -v "$tool" 2>/dev/null || echo NOT_FOUND)"
done
java -version 2>&1 | sed -n '1,5p'
echo

echo "=== Candidate media and configs ==="
find /u01 /u02 /opt /var/opt/oracle /tmp -maxdepth 7 \
  \( -iname 'apexins.sql' -o -iname 'apxremov.sql' -o -iname 'ords.war' -o -name ords -o -iname 'apex*.zip' -o -iname 'ords*.zip' \) \
  2>/dev/null | sort | sed -n '1,160p'
echo

echo "=== Database registry and runtime accounts ==="
if command -v sqlplus >/dev/null 2>&1; then
  sqlplus -s / as sysdba <<'SQL'
set pages 200 lines 220 trimspool on
col comp_id format a12
col comp_name format a38
col version format a18
col status format a12
select con_id, comp_id, comp_name, version, status
from cdb_registry
where comp_id in ('APEX','ORDS')
order by con_id, comp_id;

col username format a34
col account_status format a28
select con_id, username, account_status
from cdb_users
where username in ('APEX_PUBLIC_USER','ORDS_PUBLIC_USER','ORDS_METADATA')
   or username like 'APEX\_%' escape '\'
order by con_id, username;

col owner format a34
select con_id, owner, count(*) invalid_objects
from cdb_objects
where status <> 'VALID'
  and (owner like 'APEX\_%' escape '\' or owner in ('ORDS_METADATA','ORDS_PUBLIC_USER','APEX_PUBLIC_USER'))
group by con_id, owner
order by con_id, owner;

select con_id, name, open_mode from v$pdbs order by con_id;
SQL
else
  echo "sqlplus not found"
fi
echo

echo "=== ORDS service/config status ==="
if command -v systemctl >/dev/null 2>&1; then
  systemctl status ords --no-pager 2>&1 | sed -n '1,120p' || true
fi
for path in /etc/ords /var/log/ords /u01/app/oracle/product/crashsim_apex_ords; do
  if [[ -e "$path" ]]; then
    ls -ld "$path"
  else
    echo "missing: $path"
  fi
done
