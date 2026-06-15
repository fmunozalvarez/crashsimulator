#!/usr/bin/env bash
set -uo pipefail

DB_UNIQUE_NAME="${DB_UNIQUE_NAME:-crashrac}"
ORACLE_SID="${ORACLE_SID:-crashdb1}"
ORACLE_HOME="${ORACLE_HOME:-/u02/app/oracle/product/23.0.0.0/dbhome_1}"
GRID_HOME="${GRID_HOME:-/u01/app/23.0.0.0/gridhome_1}"
export ORACLE_SID ORACLE_HOME
export PATH="${ORACLE_HOME}/bin:${GRID_HOME}/bin:${PATH}"

echo "=== CrashSimulator HA configuration collector ==="
date -u '+Generated UTC: %Y-%m-%dT%H:%M:%SZ'
echo "Host: $(hostname -f 2>/dev/null || hostname)"
echo "User: $(id -un)"
echo "DB_UNIQUE_NAME=${DB_UNIQUE_NAME}"
echo "ORACLE_SID=${ORACLE_SID}"
echo "ORACLE_HOME=${ORACLE_HOME}"
echo "GRID_HOME=${GRID_HOME}"
echo

echo "=== Tooling ==="
for tool in sqlplus rman dgmgrl srvctl crsctl onsctl; do
  printf '%-10s %s\n' "${tool}:" "$(command -v "${tool}" 2>/dev/null || echo NOT_FOUND)"
done
echo

echo "=== SQL evidence ==="
if command -v sqlplus >/dev/null 2>&1; then
  sqlplus -s / as sysdba <<'SQL'
set pages 200 lines 220 trimspool on
col name format a28
col db_unique_name format a24
col database_role format a22
col open_mode format a24
col protection_mode format a30
col switchover_status format a24
col flashback_on format a14
col log_mode format a14
col fs_failover_status format a28
col fs_failover_observer_present format a18
select name, db_unique_name, database_role, open_mode, protection_mode,
       switchover_status, flashback_on, log_mode, fs_failover_status,
       fs_failover_observer_present
from v$database;

col instance_name format a18
col host_name format a36
col status format a12
select inst_id, instance_name, host_name, status from gv$instance order by inst_id;

col name format a30
col open_mode format a22
select con_id, name, open_mode from v$pdbs order by con_id;

col value format a150
select name, value
from v$parameter
where name in ('db_recovery_file_dest','db_recovery_file_dest_size',
               'control_files','dg_broker_start','service_names',
               'remote_listener','local_listener')
order by name;

col destination format a70
col error format a80
select dest_id, status, target, destination, error
from v$archive_dest
where dest_id <= 10
order by dest_id;

col grantee format a30
col granted_role format a30
select con_id, grantee, granted_role
from cdb_role_privs
where granted_role='RECOVERY_CATALOG_OWNER'
order by con_id, grantee;

col object_name format a30
col object_type format a18
select con_id, owner, object_name, object_type, status
from cdb_objects
where object_name in ('RC_DATABASE','RC_BACKUP_SET','RC_RMAN_CONFIGURATION','DBINC')
  and owner not in ('SYS','SYSTEM')
order by con_id, owner, object_name;

col network_name format a48
col pdb format a18
col failover_method format a18
col failover_type format a18
col commit_outcome format a14
col aq_ha_notifications format a18
select name, network_name, pdb, failover_method, failover_type,
       failover_retries, failover_delay, commit_outcome,
       aq_ha_notifications, clb_goal, goal
from dba_services
order by name;
SQL
else
  echo "sqlplus not found"
fi
echo

echo "=== Data Guard Broker evidence ==="
if command -v dgmgrl >/dev/null 2>&1; then
  dgmgrl -silent / "show configuration" 2>&1 || true
  dgmgrl -silent / "show fast_start failover" 2>&1 || true
else
  echo "dgmgrl not found"
fi
echo

echo "=== GI service evidence ==="
if command -v srvctl >/dev/null 2>&1; then
  srvctl config database -d "${DB_UNIQUE_NAME}" 2>&1 || true
  srvctl status database -d "${DB_UNIQUE_NAME}" 2>&1 || true
  srvctl config service -d "${DB_UNIQUE_NAME}" 2>&1 || true
  srvctl status service -d "${DB_UNIQUE_NAME}" 2>&1 || true
  srvctl config ons 2>&1 || true
  srvctl status ons 2>&1 || true
else
  echo "srvctl not found"
fi
echo

echo "=== CRS storage evidence ==="
if command -v crsctl >/dev/null 2>&1; then
  crsctl stat res -t 2>&1 | sed -n '1,180p'
  crsctl stat res -p 2>&1 | grep -Ei '(^NAME=|TYPE=ora\\.(acfs|diskgroup)|MOUNTPOINT|VOLUME|ACL|ACTIVE_PLACEMENT|SERVER_POOLS)' | sed -n '1,240p'
else
  echo "crsctl not found"
fi
echo

echo "=== RMAN no-catalog smoke ==="
if command -v rman >/dev/null 2>&1; then
  rman target / <<'RMAN'
show all;
list incarnation;
exit;
RMAN
else
  echo "rman not found"
fi
