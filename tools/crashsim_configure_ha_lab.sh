#!/usr/bin/env bash
set -euo pipefail

DB_UNIQUE_NAME="${DB_UNIQUE_NAME:-crashrac}"
ORACLE_SID="${ORACLE_SID:-crashdb1}"
ORACLE_HOME="${ORACLE_HOME:-/u02/app/oracle/product/23.0.0.0/dbhome_1}"
GRID_HOME="${GRID_HOME:-/u01/app/23.0.0.0/gridhome_1}"
PDB_NAME="${PDB_NAME:-CRASHPDB}"
CATALOG_USER="${CATALOG_USER:-RMAN_CATALOG}"
# Empty = auto: resolved from the target PDB's registered services at runtime
# (the old hardcoded crashdb_CRASHPDB.paas.oracle.com default only matched the
# original lab host).
CATALOG_SERVICE="${CATALOG_SERVICE:-}"
CATALOG_CONNECT="${CATALOG_CONNECT:-}"
AC_SERVICE="${AC_SERVICE:-crashsim_ac}"
TAC_SERVICE="${TAC_SERVICE:-crashsim_tac}"
PREFERRED_INSTANCES="${PREFERRED_INSTANCES:-crashdb1,crashdb2}"
RUN_ID="${RUN_ID:-$(date -u +%Y%m%d_%H%M%S)}"
LOG_DIR="${LOG_DIR:-/tmp/crashsimulator/crashsimulator_logs}"

export ORACLE_SID ORACLE_HOME
export PATH="${ORACLE_HOME}/bin:${GRID_HOME}/bin:${PATH}"

usage() {
  cat <<USAGE
Usage: $0 [--catalog] [--services] [--fsfo-check] [--all]

Environment:
  DB_UNIQUE_NAME                    Default: ${DB_UNIQUE_NAME}
  ORACLE_SID / ORACLE_HOME          Defaults: ${ORACLE_SID} / ${ORACLE_HOME}
  GRID_HOME                         Default: ${GRID_HOME}
  PDB_NAME                          Default: ${PDB_NAME} (falls back to the first
                                    READ WRITE user PDB when it does not exist)
  CATALOG_USER                      Default: ${CATALOG_USER}
  CATALOG_SERVICE                   Default: auto (the resolved PDB's default service)
  CRASHSIM_RMAN_CATALOG_PASSWORD    Required with --catalog
  AC_SERVICE / TAC_SERVICE          Defaults: ${AC_SERVICE} / ${TAC_SERVICE}
  PREFERRED_INSTANCES               Default: ${PREFERRED_INSTANCES}

The script is intended for CrashSimulator lab environments. Production
recovery catalogs should be placed outside the target database failure domain.
USAGE
}

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

need_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Required tool not found in PATH: $1" >&2
    exit 1
  }
}

sql_sys() {
  need_tool sqlplus
  sqlplus -s / as sysdba
}

# The configured PDB may not exist on this host (the defaults describe the
# original lab box). Mirror the seed scripts: use PDB_NAME when it is open
# READ WRITE, otherwise fall back to the first READ WRITE user PDB.
resolve_pdb_name() {
  local resolved
  resolved="$(sql_sys <<SQL | awk -F= '/^RESOLVED_PDB=/{print $2; exit}'
set heading off feedback off pages 0 verify off
select 'RESOLVED_PDB=' || nvl(
         (select name from v\$pdbs
           where name = upper('${PDB_NAME}')
             and open_mode like 'READ WRITE%' and rownum = 1),
         (select name from (select name from v\$pdbs
                             where name <> 'PDB\$SEED'
                               and open_mode like 'READ WRITE%'
                             order by con_id)
           where rownum = 1)) from dual;
exit
SQL
)"
  if [[ -z "$resolved" ]]; then
    echo "No open READ WRITE user PDB found (configured PDB_NAME=${PDB_NAME})." >&2
    exit 1
  fi
  if [[ "$resolved" != "$(printf '%s' "$PDB_NAME" | tr '[:lower:]' '[:upper:]')" ]]; then
    log "Configured PDB ${PDB_NAME} not found or not READ WRITE; using first user PDB: ${resolved}"
  fi
  PDB_NAME="$resolved"
}

# Derive the catalog connect string from the resolved PDB's registered
# services unless the operator set CATALOG_SERVICE / CATALOG_CONNECT.
resolve_catalog_connect() {
  if [[ -z "$CATALOG_SERVICE" ]]; then
    CATALOG_SERVICE="$(sql_sys <<SQL | awk -F= '/^PDB_SERVICE=/{print $2; exit}'
set heading off feedback off pages 0 verify off
select 'PDB_SERVICE=' || nvl(
         (select s.name from v\$services s join v\$pdbs p on s.con_id = p.con_id
           where p.name = upper('${PDB_NAME}')
             and upper(s.name) = upper('${PDB_NAME}') and rownum = 1),
         (select s.name from v\$services s join v\$pdbs p on s.con_id = p.con_id
           where p.name = upper('${PDB_NAME}') and rownum = 1)) from dual;
exit
SQL
)"
    if [[ -z "$CATALOG_SERVICE" ]]; then
      echo "Unable to resolve a database service for PDB ${PDB_NAME}." >&2
      exit 1
    fi
    log "Resolved catalog service: ${CATALOG_SERVICE}"
  fi
  if [[ -z "$CATALOG_CONNECT" ]]; then
    # Ask the listener for its real TCP endpoint instead of assuming
    # localhost:1521 - lab listeners are often bound to the hostname and/or a
    # non-default port (e.g. testone:1522), where a loopback guess fails with
    # ORA-12541 even though the service is registered.
    local endpoint=""
    if command -v lsnrctl >/dev/null 2>&1; then
      endpoint="$(lsnrctl status 2>/dev/null |
        sed -n 's/.*(PROTOCOL=[Tt][Cc][Pp])(HOST=\([^)]*\))(PORT=\([0-9]*\)).*/\1:\2/p' |
        head -n 1)"
    fi
    [[ -n "$endpoint" ]] || endpoint="localhost:1521"
    log "Resolved listener endpoint: ${endpoint}"
    CATALOG_CONNECT="//${endpoint}/${CATALOG_SERVICE}"
  fi
}

service_exists() {
  local service="$1"
  srvctl config service -d "$DB_UNIQUE_NAME" -service "$service" >/dev/null 2>&1
}

start_service_if_needed() {
  local service="$1"
  if srvctl status service -d "$DB_UNIQUE_NAME" -service "$service" 2>&1 | grep -qi 'is running'; then
    log "Service ${service} is already running"
  else
    log "Starting service ${service}"
    srvctl start service -d "$DB_UNIQUE_NAME" -service "$service"
  fi
}

configure_service_common() {
  local service="$1"
  shift
  local placement_args=()
  if [[ "${PREFERRED_INSTANCES}" == *,* ]]; then
    placement_args=(-preferred "$PREFERRED_INSTANCES")
  fi

  if service_exists "$service"; then
    log "Modifying existing service ${service}"
    srvctl modify service -db "$DB_UNIQUE_NAME" -service "$service" "$@"
  else
    log "Adding service ${service}"
    srvctl add service -db "$DB_UNIQUE_NAME" -service "$service" \
      "${placement_args[@]}" -pdb "$PDB_NAME" -role PRIMARY \
      -policy AUTOMATIC "$@"
  fi
  start_service_if_needed "$service"
  srvctl config service -d "$DB_UNIQUE_NAME" -service "$service"
}

configure_services() {
  need_tool srvctl
  log "Configuring CrashSimulator AC/TAC/FAN lab services"
  configure_service_common "$AC_SERVICE" \
    -notification TRUE -clbgoal LONG -rlbgoal SERVICE_TIME \
    -failovertype TRANSACTION -failoverretry 30 -failoverdelay 3 \
    -failover_restore LEVEL1 -commit_outcome TRUE \
    -retention 86400 -replay_init_time 300 -session_state DYNAMIC \
    -drain_timeout 300 -stopoption TRANSACTIONAL

  configure_service_common "$TAC_SERVICE" \
    -notification TRUE -clbgoal LONG -rlbgoal SERVICE_TIME \
    -failovertype AUTO -failoverretry 30 -failoverdelay 3 \
    -failover_restore LEVEL1 -commit_outcome TRUE \
    -retention 86400 -replay_init_time 300 \
    -drain_timeout 300 -stopoption TRANSACTIONAL

  log "ONS status"
  srvctl config ons || true
  srvctl status ons || true
}

# credentials go through the heredoc CONNECT (never on argv/ps output)
catalog_metadata_exists() {
  sqlplus -s /nolog <<SQL 2>/dev/null | grep -q '^CATALOG_EXISTS=YES'
connect ${CATALOG_USER}/"${CRASHSIM_RMAN_CATALOG_PASSWORD}"@${CATALOG_CONNECT}
set heading off feedback off pages 0 verify off
select 'CATALOG_EXISTS=YES' from user_objects where object_name='RC_DATABASE' and rownum=1;
exit
SQL
}

create_catalog_user() {
  log "Creating or refreshing local lab RMAN catalog owner ${CATALOG_USER} in ${PDB_NAME}"
  sql_sys <<SQL
whenever sqlerror exit failure
alter session set container=${PDB_NAME};
declare
  user_count number;
  perm_ts    varchar2(128);
  temp_ts    varchar2(128);
begin
  -- use the PDB's own defaults instead of assuming USERS/TEMP exist
  select property_value into perm_ts from database_properties
   where property_name = 'DEFAULT_PERMANENT_TABLESPACE';
  select property_value into temp_ts from database_properties
   where property_name = 'DEFAULT_TEMP_TABLESPACE';
  select count(*) into user_count from dba_users where username = upper('${CATALOG_USER}');
  if user_count = 0 then
    execute immediate 'create user ${CATALOG_USER} identified by "${CRASHSIM_RMAN_CATALOG_PASSWORD}"'
      || ' default tablespace ' || perm_ts || ' temporary tablespace ' || temp_ts
      || ' quota unlimited on ' || perm_ts;
  else
    execute immediate 'alter user ${CATALOG_USER} identified by "${CRASHSIM_RMAN_CATALOG_PASSWORD}" account unlock';
    execute immediate 'alter user ${CATALOG_USER} quota unlimited on ' || perm_ts;
  end if;
end;
/
grant recovery_catalog_owner to ${CATALOG_USER};
exit
SQL
}

configure_catalog() {
  : "${CRASHSIM_RMAN_CATALOG_PASSWORD:?Set CRASHSIM_RMAN_CATALOG_PASSWORD for --catalog}"
  need_tool sqlplus
  need_tool rman
  resolve_pdb_name
  resolve_catalog_connect
  create_catalog_user

  if catalog_metadata_exists; then
    log "RMAN catalog metadata already exists for ${CATALOG_USER}; skipping CREATE CATALOG"
  else
    log "Creating RMAN catalog metadata"
    rman <<RMAN
connect catalog ${CATALOG_USER}/"${CRASHSIM_RMAN_CATALOG_PASSWORD}"@${CATALOG_CONNECT}
create catalog;
exit;
RMAN
  fi

  log "Registering/resyncing target database"
  set +e
  rman target / <<RMAN
connect catalog ${CATALOG_USER}/"${CRASHSIM_RMAN_CATALOG_PASSWORD}"@${CATALOG_CONNECT}
register database;
resync catalog;
report schema;
exit;
RMAN
  local rman_status=$?
  set -e
  if [[ "$rman_status" -ne 0 ]]; then
    log "REGISTER DATABASE may already be complete; retrying RESYNC/REPORT only"
    rman target / <<RMAN
connect catalog ${CATALOG_USER}/"${CRASHSIM_RMAN_CATALOG_PASSWORD}"@${CATALOG_CONNECT}
resync catalog;
report schema;
exit;
RMAN
  fi
}

fsfo_check() {
  need_tool sqlplus
  log "Checking Data Guard/FSFO prerequisites"
  sql_sys <<'SQL'
set pages 100 lines 180
col name format a12
col db_unique_name format a18
col database_role format a20
col open_mode format a24
col fs_failover_status format a28
select name, db_unique_name, database_role, open_mode, protection_mode,
       flashback_on, fs_failover_status, fs_failover_observer_present
from v$database;
select name, value from v$parameter where name='dg_broker_start';
select dest_id, status, target, destination, error
from v$archive_dest
where target='STANDBY' or destination is not null
order by dest_id;
exit
SQL
  if command -v dgmgrl >/dev/null 2>&1; then
    dgmgrl -silent / "show configuration" || true
    dgmgrl -silent / "show fast_start failover" || true
  fi
  cat <<'NOTE'
FSFO is only configurable after a Broker-managed Data Guard configuration exists,
flashback is enabled on all members, standby redo/transport/apply are healthy,
and an observer host can reach both primary and standby connect identifiers.
NOTE
}

main() {
  local do_catalog=0 do_services=0 do_fsfo=0
  [[ "$#" -gt 0 ]] || { usage; exit 0; }
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --catalog) do_catalog=1 ;;
      --services) do_services=1 ;;
      --fsfo-check) do_fsfo=1 ;;
      --all) do_catalog=1; do_services=1; do_fsfo=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
    esac
    shift
  done

  mkdir -p "$LOG_DIR"
  exec > >(tee -a "${LOG_DIR}/crashsim_ha_lab_config_${RUN_ID}.log") 2>&1
  log "CrashSimulator HA lab configuration started"
  [[ "$do_catalog" -eq 1 ]] && configure_catalog
  [[ "$do_services" -eq 1 ]] && configure_services
  [[ "$do_fsfo" -eq 1 ]] && fsfo_check
  log "CrashSimulator HA lab configuration completed"
}

main "$@"
