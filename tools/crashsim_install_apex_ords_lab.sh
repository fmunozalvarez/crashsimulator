#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/u01/app/oracle/product/crashsim_apex_ords}"
APEX_ZIP="${APEX_ZIP:-${BASE_DIR}/media/apex_26.1_en.zip}"
ORDS_ZIP="${ORDS_ZIP:-${BASE_DIR}/media/ords-26.1.2.140.1916.zip}"
APEX_DIR="${APEX_DIR:-${BASE_DIR}/apex_26.1}"
ORDS_DIR="${ORDS_DIR:-${BASE_DIR}/ords_26.1.2}"
ORDS_CONFIG_DIR="${ORDS_CONFIG_DIR:-${BASE_DIR}/ords_config}"
LOG_DIR="${LOG_DIR:-${BASE_DIR}/logs/install_$(date -u +%Y%m%dT%H%M%SZ)}"
ORACLE_HOME="${ORACLE_HOME:-/u02/app/oracle/product/23.0.0.0/dbhome_1}"
ORACLE_SID="${ORACLE_SID:-crashdb1}"
JAVA_HOME="${JAVA_HOME:-/usr/java/jdk-17}"
PDB_NAME="${PDB_NAME:-CRASHPDB}"
DB_HOSTNAME="${DB_HOSTNAME:-10.0.0.216}"
DB_PORT="${DB_PORT:-1521}"
DB_SERVICE="${DB_SERVICE:-crashsim_tac}"
ORDS_POOL="${ORDS_POOL:-crashpdb}"
APEX_ADMIN_USER="${APEX_ADMIN_USER:-APEXLAB}"
APEX_ADMIN_EMAIL="${APEX_ADMIN_EMAIL:-apexlab@example.com}"
RESTORE_POINT="${RESTORE_POINT:-CSIM_APEX_$(date -u +%Y%m%d%H%M%S)}"

: "${SYS_PASSWORD:?Set SYS_PASSWORD for APEX/ORDS lab installation}"
: "${ORDS_PUBLIC_PASSWORD:?Set ORDS_PUBLIC_PASSWORD for ORDS_PUBLIC_USER}"
: "${APEX_ADMIN_PASSWORD:?Set APEX_ADMIN_PASSWORD for the APEX instance admin}"

export ORACLE_HOME ORACLE_SID JAVA_HOME
export PATH="${JAVA_HOME}/bin:${ORACLE_HOME}/bin:${PATH}"

mkdir -p "$BASE_DIR" "$LOG_DIR"
exec > >(tee -a "${LOG_DIR}/crashsim_apex_ords_install.log") 2>&1

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

need_file() {
  [[ -s "$1" ]] || {
    echo "Required file not found or empty: $1" >&2
    exit 1
  }
}

sql_sys() {
  sqlplus -s / as sysdba
}

apex_installed() {
  sql_sys <<SQL | grep -q '^APEX_INSTALLED=YES'
set heading off feedback off pages 0 verify off
alter session set container=${PDB_NAME};
select 'APEX_INSTALLED=YES'
from dba_registry
where comp_id='APEX'
  and status='VALID'
  and rownum=1;
exit
SQL
}

ords_installed() {
  sqlplus -s "SYS/${SYS_PASSWORD}@//${DB_HOSTNAME}:${DB_PORT}/${DB_SERVICE} as sysdba" <<'SQL' | grep -q '^ORDS_INSTALLED=YES'
set heading off feedback off pages 0 verify off
select 'ORDS_INSTALLED=YES'
from dba_objects
where owner='ORDS_METADATA'
  and object_name='ORDS'
  and rownum=1;
exit
SQL
}

prepare_media() {
  need_file "$APEX_ZIP"
  need_file "$ORDS_ZIP"
  if [[ ! -f "${APEX_DIR}/apex/apexins.sql" ]]; then
    log "Extracting APEX media to ${APEX_DIR}"
    rm -rf "$APEX_DIR"
    mkdir -p "$APEX_DIR"
    unzip -q "$APEX_ZIP" -d "$APEX_DIR"
  fi
  if [[ ! -x "${ORDS_DIR}/bin/ords" ]]; then
    log "Extracting ORDS media to ${ORDS_DIR}"
    rm -rf "$ORDS_DIR"
    mkdir -p "$ORDS_DIR"
    unzip -q "$ORDS_ZIP" -d "$ORDS_DIR"
  fi
  "${ORDS_DIR}/bin/ords" --version
}

create_restore_point() {
  log "Creating guaranteed restore point ${RESTORE_POINT}"
  sql_sys <<SQL
whenever sqlerror exit failure
create restore point ${RESTORE_POINT} guarantee flashback database;
exit
SQL
}

install_apex() {
  if apex_installed; then
    log "APEX is already installed and VALID in ${PDB_NAME}; skipping APEX install"
    return
  fi

  log "Installing APEX into ${PDB_NAME}"
  (
    cd "${APEX_DIR}/apex"
    sqlplus -s / as sysdba <<SQL
whenever oserror exit failure
whenever sqlerror exit failure
alter session set container=${PDB_NAME};
spool ${LOG_DIR}/apexins.log
@apexins.sql USERS USERS TEMP /i/
spool off
exit
SQL
  )
}

configure_apex_runtime() {
  log "Creating/updating APEX instance administrator ${APEX_ADMIN_USER}"
  sqlplus -s / as sysdba <<SQL
set echo off feedback on serveroutput on
whenever sqlerror exit failure
alter session set container=${PDB_NAME};
alter session set current_schema=APEX_260100;
begin
  wwv_flow_instance_admin.create_or_update_admin_user(
    p_username => upper('${APEX_ADMIN_USER}'),
    p_email    => '${APEX_ADMIN_EMAIL}',
    p_password => '${APEX_ADMIN_PASSWORD}');
  commit;
  dbms_output.put_line('APEX_ADMIN_OK');
end;
/
alter user APEX_PUBLIC_USER identified by "${ORDS_PUBLIC_PASSWORD}" account unlock;
exit
SQL
}

install_ords() {
  mkdir -p "$ORDS_CONFIG_DIR"
  if ords_installed; then
    log "ORDS metadata is already installed; refreshing configuration only"
    printf '%s\n' "$ORDS_PUBLIC_PASSWORD" |
      "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" install \
        --config-only \
        --db-pool "$ORDS_POOL" \
        --db-hostname "$DB_HOSTNAME" \
        --db-port "$DB_PORT" \
        --db-servicename "$DB_SERVICE" \
        --db-user ORDS_PUBLIC_USER \
        --password-stdin
  else
    log "Installing ORDS metadata and pool ${ORDS_POOL}"
    printf '%s\n%s\n%s\n' "$SYS_PASSWORD" "$ORDS_PUBLIC_PASSWORD" "$ORDS_PUBLIC_PASSWORD" |
      "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" install \
        --log-folder "$LOG_DIR" \
        --admin-user SYS \
        --db-pool "$ORDS_POOL" \
        --db-hostname "$DB_HOSTNAME" \
        --db-port "$DB_PORT" \
        --db-servicename "$DB_SERVICE" \
        --schema-tablespace USERS \
        --schema-temp-tablespace TEMP \
        --proxy-user-tablespace USERS \
        --proxy-user-temp-tablespace TEMP \
        --gateway-mode proxied \
        --gateway-user APEX_PUBLIC_USER \
        --feature-sdw false \
        --feature-db-api false \
        --feature-rest-enabled-sql false \
        --password-stdin
  fi

  "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" config set standalone.http.port 8080
  "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" config set standalone.static.path "${APEX_DIR}/apex/images"
  "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" config set standalone.context.path /ords
  "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" config list
  "${ORDS_DIR}/bin/ords" --config "$ORDS_CONFIG_DIR" config --db-pool "$ORDS_POOL" verify
}

validate_db() {
  log "Validating APEX and ORDS database objects"
  sql_sys <<SQL
set pages 200 lines 220
col comp_name format a38
col version format a18
col status format a12
alter session set container=${PDB_NAME};
select comp_id, comp_name, version, status
from dba_registry
where comp_id in ('APEX','ORDS')
order by comp_id;
select username, account_status
from dba_users
where username in ('APEX_PUBLIC_USER','ORDS_PUBLIC_USER','ORDS_METADATA')
   or username like 'APEX\_%' escape '\'
order by username;
select owner, count(*) invalid_objects
from dba_objects
where status <> 'VALID'
  and (owner like 'APEX\_%' escape '\' or owner in ('ORDS_METADATA','ORDS_PUBLIC_USER','APEX_PUBLIC_USER'))
group by owner
order by owner;
exit
SQL
}

main() {
  log "CrashSimulator APEX/ORDS lab installation started"
  java -version
  prepare_media
  create_restore_point
  install_apex
  configure_apex_runtime
  install_ords
  validate_db
  log "CrashSimulator APEX/ORDS lab installation completed"
  log "APEX images: ${APEX_DIR}/apex/images"
  log "ORDS executable: ${ORDS_DIR}/bin/ords"
  log "ORDS config: ${ORDS_CONFIG_DIR}"
  log "Restore point: ${RESTORE_POINT}"
}

main "$@"
