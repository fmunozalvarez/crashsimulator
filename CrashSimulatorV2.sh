#!/usr/bin/env bash
#
# CrashSimulator V2 - Oracle HA/DR/backup and recovery practice framework.
#
# Default behavior is safe: discovery, listing, and dry-run planning do not
# damage the database. Destructive actions require --execute and confirmation.

set -uo pipefail

if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  echo "ERROR: CrashSimulator V2 requires Bash 4 or later. Current Bash: ${BASH_VERSION:-unknown}" >&2
  echo "On Oracle Linux, run it with /bin/bash from the database host." >&2
  exit 2
fi

VERSION="2.0.3-rc4"
SUCCESS=0
FAIL=1

PROGRAM="$(basename "$0")"
BASH_EXECUTABLE="${BASH:-bash}"
SCRIPT_SOURCE="${BASH_SOURCE[0]:-$0}"
case "$SCRIPT_SOURCE" in
  */*)
    SCRIPT_PATH="$(cd -P "$(dirname "$SCRIPT_SOURCE")" >/dev/null 2>&1 && pwd)/$(basename "$SCRIPT_SOURCE")"
    ;;
  *)
    SCRIPT_PATH="$(command -v "$SCRIPT_SOURCE" 2>/dev/null || true)"
    [[ -n "$SCRIPT_PATH" ]] || SCRIPT_PATH="./$SCRIPT_SOURCE"
    ;;
esac
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_PATH")" >/dev/null 2>&1 && pwd)"
MODE="menu"
SCENARIO_ID=""
TARGET_PDB="${CRASHSIM_PDB:-}"
TARGET_SCHEMA="${CRASHSIM_SCHEMA:-}"
TARGET_FILE_NO="${CRASHSIM_FILE_NO:-}"
PFILE_PATH="${CRASHSIM_PFILE:-}"
SYS_PASSWORD="${CRASHSIM_SYS_PASSWORD:-}"
SERVICE_NAME="${CRASHSIM_SERVICE_NAME:-}"
SYSBACKUP_USER="${CRASHSIM_SYSBACKUP_USER:-C##DBLCMUSER}"
TEMPFILE_SIZE="${CRASHSIM_TEMPFILE_SIZE:-100m}"
GRID_USER="${CRASHSIM_GRID_USER:-grid}"
LOCAL_ONLY="${CRASHSIM_LOCAL_ONLY:-0}"
MAX_TARGETS="${CRASHSIM_MAX_TARGETS:-}"
PIECE_HANDLE="${CRASHSIM_PIECE_HANDLE:-}"
REPORT_DEEP_VALIDATE="${CRASHSIM_REPORT_DEEP_VALIDATE:-0}"
RMAN_CATALOG_CONNECT="${CRASHSIM_RMAN_CATALOG:-}"
BASELINE_TAG_PREFIX="${CRASHSIM_BASELINE_TAG_PREFIX:-CSIM_BASE}"
FRA_PRESSURE_TARGET_PCT="${CRASHSIM_FRA_PRESSURE_TARGET_PCT:-98}"
FRA_PRESSURE_HEADROOM_MB="${CRASHSIM_FRA_PRESSURE_HEADROOM_MB:-64}"
TEMP_EXHAUST_MB="${CRASHSIM_TEMP_EXHAUST_MB:-512}"
ORDS_SERVICE_NAME="${CRASHSIM_ORDS_SERVICE:-ords}"
ORDS_CONFIG_DIR="${CRASHSIM_ORDS_CONFIG_DIR:-/etc/ords/config}"
ORDS_URL="${CRASHSIM_ORDS_URL:-http://localhost:8080/ords/}"
ORDS_LB_URL="${CRASHSIM_ORDS_LB_URL:-}"
ORDS_DB_POOL="${CRASHSIM_ORDS_DB_POOL:-default}"
ORDS_PRIV_HELPER="${CRASHSIM_ORDS_PRIV_HELPER:-/usr/local/bin/crashsim_ords_priv}"
APEX_IMAGES_DIR="${CRASHSIM_APEX_IMAGES_DIR:-}"
APEX_SESSION_DRIVER="${CRASHSIM_APEX_SESSION_DRIVER:-}"
APEX_SESSION_URL="${CRASHSIM_APEX_SESSION_URL:-}"
APEX_SESSION_USERNAME="${CRASHSIM_APEX_SESSION_USERNAME:-}"
APEX_SESSION_PASSWORD="${CRASHSIM_APEX_SESSION_PASSWORD:-}"
APEX_SESSION_SUCCESS_SELECTOR="${CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR:-}"
APEX_SESSION_USERNAME_SELECTOR="${CRASHSIM_APEX_SESSION_USERNAME_SELECTOR:-}"
APEX_SESSION_PASSWORD_SELECTOR="${CRASHSIM_APEX_SESSION_PASSWORD_SELECTOR:-}"
APEX_SESSION_SUBMIT_SELECTOR="${CRASHSIM_APEX_SESSION_SUBMIT_SELECTOR:-}"
APEX_SESSION_DURATION="${CRASHSIM_APEX_SESSION_DURATION:-90}"
APEX_SESSION_INTERVAL="${CRASHSIM_APEX_SESSION_INTERVAL:-10}"
APEX_SESSION_HEADLESS="${CRASHSIM_APEX_SESSION_HEADLESS:-1}"
AUDIT_RETAIN="${CRASHSIM_AUDIT_RETAIN:-1}"
AUDIT_RETENTION_DAYS="${CRASHSIM_AUDIT_RETENTION_DAYS:-365}"
AUDIT_DIR="${CRASHSIM_AUDIT_DIR:-}"
AUDIT_STREAM_CAPTURE="${CRASHSIM_AUDIT_STREAM_CAPTURE:-auto}"
AUTO_SCORECARD="${CRASHSIM_AUTO_SCORECARD:-1}"
DESTRUCTIVE_LAB_ACK="${CRASHSIM_ACCEPT_DESTRUCTIVE_LAB:-}"
TOPOLOGY_CACHE_TTL_SECONDS="${CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS:-300}"
TOPOLOGY_CACHE_REFRESH=0
TOPOLOGY_CACHE_DISABLED="${CRASHSIM_DISABLE_TOPOLOGY_CACHE:-0}"
SECRET_SCAN_PATH="${CRASHSIM_SECRET_SCAN_PATH:-.}"
SANITIZE_SOURCE_DIR="${CRASHSIM_SANITIZE_SOURCE_DIR:-.}"
SANITIZE_OUTPUT_DIR="${CRASHSIM_SANITIZE_OUTPUT_DIR:-}"
HTML_OUTPUT=0
HTML_TARGET="${CRASHSIM_HTML_TARGET:-}"
REVIEW_TARGET="${CRASHSIM_REVIEW_TARGET:-}"
MAA_APP_NAME="${CRASHSIM_MAA_APP_NAME:-}"
MAA_LOCAL_RTO="${CRASHSIM_MAA_LOCAL_RTO:-}"
MAA_LOCAL_RPO="${CRASHSIM_MAA_LOCAL_RPO:-}"
MAA_DR_RTO="${CRASHSIM_MAA_DR_RTO:-}"
MAA_DR_RPO="${CRASHSIM_MAA_DR_RPO:-}"
MAA_PLANNED_RTO="${CRASHSIM_MAA_PLANNED_RTO:-}"
MAA_PLANNED_RPO="${CRASHSIM_MAA_PLANNED_RPO:-}"
MAA_CRITICALITY="${CRASHSIM_MAA_CRITICALITY:-}"
MAA_LOCAL_HA_TARGET="${CRASHSIM_MAA_LOCAL_HA_TARGET:-}"
MAA_DR_REQUIRED="${CRASHSIM_MAA_DR_REQUIRED:-}"
MAA_AUTOMATIC_FAILOVER_REQUIRED="${CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED:-}"
MAA_ACTIVE_ACTIVE_REQUIRED="${CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED:-}"
MAA_PLATFORM_HINT="${CRASHSIM_MAA_PLATFORM_HINT:-}"
MAA_STANDBY_SCOPE="${CRASHSIM_MAA_STANDBY_SCOPE:-unknown}"
ADB_WALLET_DIR="${CRASHSIM_ADB_WALLET_DIR:-}"
ADB_CONNECT_ALIAS="${CRASHSIM_ADB_CONNECT_ALIAS:-}"
ADB_CONNECT_DESCRIPTOR="${CRASHSIM_ADB_CONNECT_DESCRIPTOR:-}"
ADB_SERVICE_LEVEL="${CRASHSIM_ADB_SERVICE_LEVEL:-low}"
ADB_USER="${CRASHSIM_ADB_USER:-ADMIN}"
ADB_PASSWORD_ENV="${CRASHSIM_ADB_PASSWORD_ENV:-CRASHSIM_ADB_PASSWORD}"
ADB_WALLET_PASSWORD_ENV="${CRASHSIM_ADB_WALLET_PASSWORD_ENV:-CRASHSIM_ADB_WALLET_PASSWORD}"
ADB_PYTHON="${CRASHSIM_ADB_PYTHON:-python3}"
ADB_TLS_MODE="${CRASHSIM_ADB_TLS_MODE:-mTLS}"
ADB_OCID="${CRASHSIM_ADB_OCID:-}"
ADB_COMPARTMENT_OCID="${CRASHSIM_ADB_COMPARTMENT_OCID:-}"
ADB_REGION="${CRASHSIM_ADB_REGION:-}"
ADB_OCI_PROFILE="${CRASHSIM_ADB_OCI_PROFILE:-DEFAULT}"
ADB_OCI_CONFIG_FILE="${CRASHSIM_ADB_OCI_CONFIG_FILE:-}"
ADB_OCI_AUTH="${CRASHSIM_ADB_OCI_AUTH:-}"
ADB_APEX_URL="${CRASHSIM_ADB_APEX_URL:-}"
ADB_DATABASE_ACTIONS_URL="${CRASHSIM_ADB_DATABASE_ACTIONS_URL:-}"
ADB_PRIVATE_ENDPOINT="${CRASHSIM_ADB_PRIVATE_ENDPOINT:-}"
ADB_SCENARIO_ID="${CRASHSIM_ADB_SCENARIO:-}"
LOG_DIR="${CRASHSIM_LOG_DIR:-}"
CONFIG_FILE="${CRASHSIM_CONFIG:-}"
CONFIG_SOURCE=""
CONFIG_EXPLICIT=0
CONFIG_DISABLED=0
CONFIG_LOADED=0
CONFIG_TEMPLATE_FILE=""
WORK_DIR=""
RUN_ID="$(date +%Y%m%d_%H%M%S)"
EXECUTE=0
ASSUME_YES=0
VERBOSE=0
SQLPLUS_BIN="${SQLPLUS:-}"
RMAN_BIN="${RMAN:-}"
SQLPLUS_LOGON="${CRASHSIM_SQLPLUS_LOGON:-/ as sysdba}"
ORACLE_USER_REQUIRED="${CRASHSIM_ORACLE_USER_REQUIRED:-0}"
MANIFEST_FILE="${CRASHSIM_MANIFEST:-}"
MANIFEST_FROM_ARG="${CRASHSIM_MANIFEST:+1}"
MANIFEST_FROM_ARG="${MANIFEST_FROM_ARG:-0}"
CURRENT_SCENARIO_ID=""
PLANNING_ONLY=0
AUDIT_RUN_DIR=""
AUDIT_MARKER_FILE=""
AUDIT_STDOUT_FILE=""
AUDIT_STDERR_FILE=""
AUDIT_STDOUT_FIFO=""
AUDIT_STDERR_FIFO=""
AUDIT_STARTED=0
AUDIT_FINALIZED=0
AUTO_SCORECARD_REFRESHING=0
MENU_SCHEMA_PROMPTED_SCENARIO=""

DB_NAME=""
DB_UNIQUE_NAME=""
DB_ROLE=""
DB_OPEN_MODE=""
DB_CDB=""
DB_PROTECTION_MODE=""
DB_SWITCHOVER_STATUS=""
INSTANCE_NAME=""
HOST_NAME=""
INSTANCE_STATUS=""
INSTANCE_PARALLEL=""
INSTANCE_THREAD=""
ORACLE_BASE_DETECTED=""
SPFILE_PATH=""
FRA_PATH=""
PASSWORD_FILE_PATH=""
CLUSTER_TYPE="UNKNOWN"
STORAGE_TYPE="UNKNOWN"
GI_MANAGED=0
DISCOVERED=0

declare -a PDB_ROWS=()
declare -a TARGET_ROWS=()
declare -a CONFIG_APPLIED=()
declare -a CONFIG_SKIPPED=()
declare -a CONFIG_WARNINGS=()
declare -a MENU_ARTIFACT_FILES=()
declare -a ACTION_KINDS=()
declare -a ACTION_TARGETS=()
declare -a ACTION_DETAILS=()
declare -a PLAN_TARGET_PATHS=()
declare -a PLAN_TARGET_PDBS=()
declare -a PLAN_TARGET_CON_IDS=()
declare -a PLAN_TARGET_FILE_NOS=()
declare -a PLAN_TARGET_TABLESPACES=()
declare -a RESTORE_ORIGINALS=()
declare -a RESTORE_BACKUPS=()
declare -a RESTORE_METHODS=()
declare -a RECOVER_FILE_NOS=()
declare -a RECOVER_TEMPFILE_PATHS=()
declare -a ORIGINAL_ARGS=("$@")
RENAME_COUNT=0
RECOVER_TEMPFILE_TABLESPACE=""
RECOVER_TEMPFILE_PDB=""

declare -a SCENARIO_IDS=()
declare -A SCENARIO_TITLE=()
declare -A SCENARIO_GROUP=()
declare -A SCENARIO_SCOPE=()
declare -A SCENARIO_IMPACT=()
declare -A SCENARIO_REQUIRES=()
declare -A SCENARIO_HANDLER=()
declare -A SCENARIO_NOTES=()
declare -A MAA_EVIDENCE=()
declare -A BACKUP_EVIDENCE=()
declare -A RPO_EVIDENCE=()
declare -A APEX_ORDS_EVIDENCE=()
declare -A ADB_EVIDENCE=()
declare -A PREP_EVIDENCE=()
declare -a PREP_IDS=()
declare -A PREP_TITLE=()
declare -A PREP_STATUS=()
declare -A PREP_REQUIRED=()
declare -A PREP_EVIDENCE_TEXT=()
declare -A PREP_ACTION=()
declare -A PREP_AUTO=()
declare -A PREP_COMMAND=()
declare -A PREP_NOTES=()
declare -a ADB_SCENARIO_IDS=()
declare -A ADB_SCENARIO_TITLE=()
declare -A ADB_SCENARIO_AREA=()
declare -A ADB_SCENARIO_VALIDATION=()
declare -A ADB_SCENARIO_RECOVERY=()
declare -A ADB_SCENARIO_HELPER=()

SCENARIO_VALIDATION_STATUS=""
SCENARIO_VALIDATION_REASON=""
SCENARIO_VALIDATION_OUTPUT=""

usage() {
  cat <<USAGE
CrashSimulator V2 ${VERSION}

Usage:
  ./${PROGRAM} --discover
  ./${PROGRAM} --list
  ./${PROGRAM} --menu
  ./${PROGRAM} --doctor [--html]
  ./${PROGRAM} --first-run [--html]
  ./${PROGRAM} --public-limitations [--html]
  ./${PROGRAM} --health-check
  ./${PROGRAM} --config-report [--deep-validate]
  ./${PROGRAM} --backup-report [--deep-validate]
  ./${PROGRAM} --service-review [--html]
  ./${PROGRAM} --apex-ords-report [--pdb <pdb_name>] [--html]
  ./${PROGRAM} --prepare-environment [--dry-run|--execute] [--html]
  ./${PROGRAM} --adb-readiness-report [--html]
  ./${PROGRAM} --list-adb-scenarios
  ./${PROGRAM} --adb-scenario <ADB01-ADB20>
  ./${PROGRAM} --baseline-backup [--dry-run|--execute]
  ./${PROGRAM} --audit-status
  ./${PROGRAM} --purge-audit-logs [--dry-run|--execute]
  ./${PROGRAM} --show-config [--config <file>]
  ./${PROGRAM} --validate-config [--config <file>]
  ./${PROGRAM} --write-config-template <file>
  ./${PROGRAM} --review
  ./${PROGRAM} --review-topology
  ./${PROGRAM} --show-artifact <path|latest[:kind]> [--html]
  ./${PROGRAM} --render-html <path|latest[:kind]>
  ./${PROGRAM} --maa-report
  ./${PROGRAM} --resilience-scorecard [--html]
  ./${PROGRAM} --validate-scenario <id> [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --validate-all-scenarios [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --scenario-readiness-report [--pdb <pdb_name>] [--schema <owner>] [--html]
  ./${PROGRAM} --scenario-lifecycle-report [--html]
  ./${PROGRAM} --scenario-lifecycle-check [--html]
  ./${PROGRAM} --secret-scan [--scan-path <path>]
  ./${PROGRAM} --sanitize-artifacts [--sanitize-source <dir>] [--sanitize-output <dir>]
  ./${PROGRAM} --node-sync-check
  ./${PROGRAM} --release-check
  ./${PROGRAM} --runbook <id> [--pdb <pdb_name>] [--schema <owner>]
  ./${PROGRAM} --protect <id> [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM} --recover <id> [--manifest <file>] [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM} --scenario <id> [--pdb <pdb_name>] [--dry-run]
  ./${PROGRAM} --scenario <id> [--pdb <pdb_name>] --execute [--yes]
  ./${PROGRAM} --random-scenario [--pdb <pdb_name>] [--dry-run|--execute]
  ./${PROGRAM}

Options:
  --discover              Print detected database topology and exits.
  --list                  List scenario registry and prerequisite gates.
  --list-scenarios        Alias for --list.
  --menu                  Start guided terminal menu. This is the default.
  --doctor                Run a non-destructive public-readiness preflight.
  --preflight             Alias for --doctor.
  --first-run             Generate a first-run checklist and safe starter flow.
  --public-limitations    Generate a public beta limitations and expectations page.
  --limitations           Alias for --public-limitations.
  --health-check          Run a non-destructive SQL health check.
  --config-report         Generate a full target database/PDB configuration report.
  --configuration-report  Alias for --config-report.
  --report                Alias for --config-report.
  --backup-report         Generate backup strategy, recoverability, RTO/RPO report.
  --backup-assessment     Alias for --backup-report.
  --recoverability-report Alias for --backup-report.
  --service-review        Generate AC/TAC, FSFO, DML redirection, and service
                          best-practice review.
  --service-assessment    Alias for --service-review.
  --services-report       Alias for --service-review.
  --apex-ords-report      Generate APEX/ORDS readiness and user access-path report.
  --apex-report           Alias for --apex-ords-report.
  --ords-report           Alias for --apex-ords-report.
  --prepare-environment   Detect missing scenario lab seeds/preparations for the
                          current topology and optionally run eligible helpers.
  --seed-environment      Alias for --prepare-environment.
  --prepare-lab           Alias for --prepare-environment.
  --adb-readiness-report  Generate Autonomous Database readiness and scenario
                          coverage report.
  --adb-discover          Alias for --adb-readiness-report.
  --list-adb-scenarios    List ADB01-ADB20 with current readiness status.
  --adb-scenario <id>     Show one ADB cloud-service scenario detail.
  --baseline-backup       Create or dry-run a fresh RMAN baseline backup.
  --fresh-baseline-backup Alias for --baseline-backup.
  --audit-retain <yes|no> Enable or disable per-run audit log retention.
  --audit-retention-days <n>
                          Days to retain audit run folders before purge.
  --audit-dir <dir>       Audit archive directory. Default: <log-dir>/audit.
  --audit-status          Show audit settings, usage, and purge candidates.
  --purge-audit-logs      Purge audit run folders older than retention policy.
  --config <file>         Read startup defaults from an allowlisted KEY=value file.
  --no-config             Do not auto-load startup configuration files.
  --show-config           Show the active CrashSimulator/Oracle startup settings.
  --validate-config       Validate loaded configuration syntax and key paths.
  --write-config-template <file>
                          Write a sanitized configuration template.
  --review                Generate and print an index of collected topology,
                          scenarios, runbooks, dry-runs, protection, health,
                          backup/config/MAA reports, audit records, and logs.
  --review-artifacts      Alias for --review.
  --review-topology       Print the latest collected topology snapshot/report.
  --show-artifact <path|latest[:kind]>
                          Print an already collected artifact.
  --render-html <path|latest[:kind]>
                          Generate an HTML copy of an artifact.
  --html                  With reports/show-artifact, also generate HTML output.
  --maa-report            Generate Oracle MAA posture, best-practice, and tier report.
  --maa-assessment        Alias for --maa-report.
  --maa-readiness         Alias for --maa-report.
  --resilience-scorecard  Generate executive resilience scorecard from current
                          topology, MAA, backup, scenario, and drill evidence.
  --resilience-score      Alias for --resilience-scorecard.
  --auto-scorecard <yes|no>
                          Refresh latest scorecard after drills when possible.
  --no-auto-scorecard     Disable post-action scorecard refresh for this run.
  --deep-validate         With reports, run heavier RMAN restore/database validation.
  --validate-scenario <id>
                          Validate whether one scenario can run now and explain blockers.
  --validate <id>         Alias for --validate-scenario.
  --validate-all-scenarios
                          Validate every registered scenario for this topology.
  --scenario-readiness-report
                          Generate a topology-aware scenario availability report.
  --scenario-lifecycle-report
                          Generate static validation/protection/execution/recovery
                          coverage for every registered scenario.
  --scenario-lifecycle-check
                          Enforce scenario metadata/handler/lifecycle consistency.
  --secret-scan           Scan repo/artifacts for obvious secrets and wallets.
  --scan-path <path>      Path used by --secret-scan. Default: current directory.
  --sanitize-artifacts    Create sanitized public copies of text artifacts.
  --sanitize-source <dir> Source directory for --sanitize-artifacts.
  --sanitize-output <dir> Output directory for sanitized artifacts.
  --node-sync-check       Check CrashSimulator driver/helper presence across
                          CRASHSIM_REMOTE_NODES for RAC/ORDS labs.
  --release-check         Run public release checks: syntax, lifecycle, secrets,
                          package integrity, and common documentation checks.
  --runbook <id>          Print recovery practice hints for a scenario.
  --protect <id>          Generate or run pre-drill RMAN protection for a scenario.
  --recover <id>          Generate or run RMAN recovery for supported scenarios.
  --scenario <id>         Run or dry-run a scenario by id.
  --random-scenario       Pick and run a random topology-compatible scenario.
  --aleatory-scenario     Alias for --random-scenario.
  --pdb <name>            Select target PDB for PDB-scoped scenarios.
  --schema <owner>        Select target schema for logical object scenarios.
  --file-no <n>           File number to recover when DB discovery is unavailable.
  --manifest <file>       Read/write a drill manifest. Defaults under --log-dir.
  --pfile <file>          PFILE to use for SPFILE recovery.
  --sys-password <value>  SYS password for password-file remote-auth validation.
  --service-name <name>   Listener service for remote SYSDBA validation.
  --ords-service <name>   ORDS systemd service name. Default: ords.
  --ords-config-dir <dir> ORDS configuration directory. Default: /etc/ords/config.
  --ords-url <url>        ORDS health/smoke URL. Default: http://localhost:8080/ords/.
  --ords-lb-url <url>     Optional load balancer URL for ORDS node-outage drills.
  --ords-priv-helper <p>  Optional sudo helper for narrowly approved ORDS OS actions.
  --apex-images-dir <dir> APEX images/static files directory for static-file drills.
  --apex-session-driver <p>
                          Optional seeded APEX browser-session driver for scenario 80.
  --apex-session-url <url>
                          Scenario 80 APEX application URL. Default: --ords-url.
  --apex-session-username <u>
                          Scenario 80 APEX test user for browser login.
  --apex-session-password <v>
                          Scenario 80 APEX test password. Prefer env var.
  --apex-session-success-selector <css>
                          Scenario 80 CSS selector that proves the app session is open.
  --apex-session-username-selector <css>
                          Optional scenario 80 login username CSS selector.
  --apex-session-password-selector <css>
                          Optional scenario 80 login password CSS selector.
  --apex-session-submit-selector <css>
                          Optional scenario 80 login submit CSS selector.
  --apex-session-duration <sec>
                          Scenario 80 browser polling duration. Default: 90.
  --apex-session-interval <sec>
                          Scenario 80 browser polling interval. Default: 10.
  --apex-session-headless <yes|no>
                          Scenario 80 browser headless mode. Default: yes.
  --sysbackup-user <name> Common user to re-grant SYSBACKUP after password-file recovery.
  --local-only            Scenario 25: target local filesystem backup pieces only.
  --max-targets <n>       Limit selected targets. Strongly recommended for scenario 25.
  --piece-handle <handle> Scenario 25: target one exact RMAN backup-piece handle.
  --rman-catalog <str>   RMAN recovery catalog connect string for drills/reports/backups.
  --backup-tag-prefix <p> RMAN tag prefix for --baseline-backup. Default: CSIM_BASE.
  --fra-pressure-target-pct <n>
                          Scenario 61 target FRA used percentage. Default: 98.
  --fra-pressure-headroom-mb <n>
                          Scenario 61 minimum free FRA headroom after shrink. Default: 64.
  --temp-exhaust-mb <n>   Scenario 63 requested TEMP-consuming workload size. Default: 512.
  --maa-app-name <name>   Optional application name for MAA/SLA planning context.
  --maa-local-rto <value> Optional local unplanned-outage RTO objective.
  --maa-local-rpo <value> Optional local unplanned-outage RPO objective.
  --maa-dr-rto <value>    Optional disaster/site-outage RTO objective.
  --maa-dr-rpo <value>    Optional disaster/site-outage RPO objective.
  --maa-planned-rto <val> Optional planned-maintenance RTO objective.
  --maa-planned-rpo <val> Optional planned-maintenance RPO objective.
  --maa-criticality <val> Optional criticality hint: dev, production,
                          mission-critical, ultra-critical.
  --maa-local-ha-target <yes|no>
                          Whether local node/instance HA is a business target.
  --maa-dr-required <yes|no>
                          Whether site/region disaster recovery is required.
  --maa-automatic-failover-required <yes|no>
                          Whether automatic failover is a business target.
  --maa-active-active-required <yes|no>
                          Whether active-active/distributed resilience is required.
  --maa-platform-hint <val>
                          Platform hint such as generic, Exadata, ODA, BaseDB.
  --maa-standby-scope <local|remote|unknown>
                          Classify detected standby as local HA or remote DR.
  --adb-wallet-dir <dir>  Autonomous Database wallet directory for mTLS.
  --adb-connect-alias <a> Autonomous Database TNS alias.
  --adb-service-level <l> Autonomous service level alias hint: low, medium,
                          high, tp, or tpurgent. Default: low.
  --adb-connect-descriptor <d>
                          Autonomous Database descriptor or Easy Connect string.
  --adb-user <user>       Autonomous Database user. Default: ADMIN.
  --adb-password-env <e>  Environment variable containing ADB password.
  --adb-wallet-password-env <e>
                          Environment variable containing wallet password.
  --adb-python <path>     Python executable with python-oracledb installed.
  --adb-tls-mode <mode>   ADB client TLS mode: mTLS or TLS. Default: mTLS.
  --adb-ocid <ocid>       Autonomous Database OCID for OCI control-plane checks.
  --adb-compartment-ocid <ocid>
                          Compartment OCID for OCI control-plane checks.
  --adb-region <region>   OCI region for ADB control-plane checks.
  --adb-oci-profile <p>   OCI CLI profile. Default: DEFAULT.
  --adb-oci-config-file <path>
                          OCI CLI config file.
  --adb-oci-auth <mode>   OCI CLI auth mode, for example security_token.
  --adb-apex-url <url>    Autonomous APEX URL.
  --adb-database-actions-url <url>
                          Autonomous Database Actions URL.
  --adb-private-endpoint <value>
                          Expected private endpoint/DNS/network label.
  --dry-run               Plan only. This is the default.
  --execute               Execute destructive actions after confirmation.
  --yes                   Skip interactive confirmation. Use only in labs.
  --accept-destructive-lab
                          Acknowledge this is an approved non-production lab for
                          destructive --execute actions in this process.
  --topology-cache-ttl <s>
                          Guided menu topology cache TTL in seconds. Default: 300.
  --refresh-topology      Ignore cached topology for this run.
  --no-topology-cache     Disable topology cache reads for this run.
  --log-dir <dir>         Directory for logs. Defaults to ./crashsimulator_logs.
  --sqlplus-logon <str>   SQL*Plus logon string. Default: / as sysdba.
  --verbose               Print extra diagnostics.
  --help                  Show this help.

Environment:
  CRASHSIM_CONFIG               Startup configuration file path.
  CRASHSIM_PDB                  Default PDB target.
  CRASHSIM_SCHEMA               Default schema target.
  CRASHSIM_FILE_NO              Default RMAN datafile number for recovery.
  CRASHSIM_PFILE                Default PFILE for SPFILE recovery.
  CRASHSIM_SYS_PASSWORD         SYS password for password-file recovery validation.
  CRASHSIM_SERVICE_NAME         Listener service for password-file recovery validation.
  CRASHSIM_ORDS_SERVICE         ORDS systemd service name. Default: ords.
  CRASHSIM_ORDS_CONFIG_DIR      ORDS configuration directory.
  CRASHSIM_ORDS_URL             ORDS health/smoke URL.
  CRASHSIM_ORDS_LB_URL          Optional ORDS load balancer URL.
  CRASHSIM_ORDS_PRIV_HELPER     Optional sudo helper path for ORDS service/config drills.
  CRASHSIM_APEX_IMAGES_DIR      APEX images/static files directory.
  CRASHSIM_APEX_SESSION_DRIVER  Optional seeded APEX browser-session driver.
  CRASHSIM_APEX_SESSION_URL     Optional scenario 80 APEX application URL.
  CRASHSIM_APEX_SESSION_USERNAME Scenario 80 APEX test user.
  CRASHSIM_APEX_SESSION_PASSWORD Scenario 80 APEX test password.
  CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR Scenario 80 success CSS selector.
  CRASHSIM_APEX_SESSION_USERNAME_SELECTOR Optional login username CSS selector.
  CRASHSIM_APEX_SESSION_PASSWORD_SELECTOR Optional login password CSS selector.
  CRASHSIM_APEX_SESSION_SUBMIT_SELECTOR Optional login submit CSS selector.
  CRASHSIM_APEX_SESSION_DURATION Scenario 80 browser polling duration.
  CRASHSIM_APEX_SESSION_INTERVAL Scenario 80 browser polling interval.
  CRASHSIM_APEX_SESSION_HEADLESS Scenario 80 browser headless mode.
  CRASHSIM_SYSBACKUP_USER       Common SYSBACKUP user to restore. Default: C##DBLCMUSER.
  CRASHSIM_TEMPFILE_SIZE        Tempfile size used by tempfile recovery. Default: 100m.
  CRASHSIM_LOCAL_ONLY           Set to 1 to target local filesystem pieces only.
  CRASHSIM_MAX_TARGETS          Limit selected targets.
  CRASHSIM_PIECE_HANDLE         Exact RMAN backup-piece handle for scenario 25.
  CRASHSIM_REPORT_DEEP_VALIDATE Set to 1 to run deep RMAN validation in reports.
  CRASHSIM_RMAN_CATALOG         RMAN recovery catalog connect string.
  CRASHSIM_BASELINE_TAG_PREFIX  RMAN tag prefix for fresh baseline backups.
  CRASHSIM_FRA_PRESSURE_TARGET_PCT Scenario 61 target FRA pressure percentage.
  CRASHSIM_FRA_PRESSURE_HEADROOM_MB Scenario 61 minimum FRA headroom in MB.
  CRASHSIM_TEMP_EXHAUST_MB      Scenario 63 TEMP workload size in MB.
  CRASHSIM_AUDIT_RETAIN         Set to 1/0 or yes/no. Default: 1.
  CRASHSIM_AUDIT_RETENTION_DAYS Days to keep audit run folders. Default: 365.
  CRASHSIM_AUDIT_DIR            Audit archive directory. Default: <log-dir>/audit.
  CRASHSIM_AUDIT_STREAM_CAPTURE Capture live stdout/stderr: auto, yes, or no. Auto disables live capture for interactive menu TTYs.
  CRASHSIM_AUTO_SCORECARD       1/0 or yes/no post-action scorecard refresh.
  CRASHSIM_ACCEPT_DESTRUCTIVE_LAB Set to YES to allow non-interactive destructive --execute lab runs.
  CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS Guided menu topology cache TTL. Default: 300.
  CRASHSIM_DISABLE_TOPOLOGY_CACHE Set to 1 to disable guided menu cache reads.
  CRASHSIM_SECRET_SCAN_PATH     Default path for --secret-scan.
  CRASHSIM_SANITIZE_SOURCE_DIR  Default source directory for --sanitize-artifacts.
  CRASHSIM_SANITIZE_OUTPUT_DIR  Default output directory for sanitized artifacts.
  CRASHSIM_HTML_TARGET          Default artifact for --render-html.
  CRASHSIM_REVIEW_TARGET        Default artifact for --show-artifact.
  CRASHSIM_MAA_APP_NAME         Application name for MAA/SLA planning context.
  CRASHSIM_MAA_LOCAL_RTO        Local unplanned-outage RTO objective.
  CRASHSIM_MAA_LOCAL_RPO        Local unplanned-outage RPO objective.
  CRASHSIM_MAA_DR_RTO           Disaster/site-outage RTO objective.
  CRASHSIM_MAA_DR_RPO           Disaster/site-outage RPO objective.
  CRASHSIM_MAA_PLANNED_RTO      Planned-maintenance RTO objective.
  CRASHSIM_MAA_PLANNED_RPO      Planned-maintenance RPO objective.
  CRASHSIM_MAA_CRITICALITY      Criticality hint for target MAA tiering.
  CRASHSIM_MAA_LOCAL_HA_TARGET  yes/no local HA business target.
  CRASHSIM_MAA_DR_REQUIRED      yes/no site or region DR requirement.
  CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED yes/no automatic failover target.
  CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED yes/no active-active/global requirement.
  CRASHSIM_MAA_PLATFORM_HINT    Platform hint such as generic or Exadata.
  CRASHSIM_MAA_STANDBY_SCOPE    local, remote, or unknown standby scope.
  CRASHSIM_ADB_WALLET_DIR       Autonomous Database wallet directory.
  CRASHSIM_ADB_CONNECT_ALIAS    Autonomous Database TNS alias.
  CRASHSIM_ADB_CONNECT_DESCRIPTOR Autonomous Database descriptor/Easy Connect.
  CRASHSIM_ADB_SERVICE_LEVEL    Service-level alias hint: low/medium/high/tp/tpurgent.
  CRASHSIM_ADB_USER             Autonomous Database user. Default: ADMIN.
  CRASHSIM_ADB_PASSWORD_ENV     Env var name containing ADB password.
  CRASHSIM_ADB_WALLET_PASSWORD_ENV Env var name containing wallet password.
  CRASHSIM_ADB_PYTHON           Python with python-oracledb. Default: python3.
  CRASHSIM_ADB_TLS_MODE         ADB client TLS mode: mTLS or TLS.
  CRASHSIM_ADB_OCID             Autonomous Database OCID for OCI checks.
  CRASHSIM_ADB_COMPARTMENT_OCID Compartment OCID for OCI checks.
  CRASHSIM_ADB_REGION           OCI region for ADB control-plane checks.
  CRASHSIM_ADB_OCI_PROFILE      OCI CLI profile. Default: DEFAULT.
  CRASHSIM_ADB_OCI_CONFIG_FILE  OCI CLI config file.
  CRASHSIM_ADB_OCI_AUTH         OCI CLI auth mode, for example security_token.
  CRASHSIM_ADB_APEX_URL         Autonomous APEX URL.
  CRASHSIM_ADB_DATABASE_ACTIONS_URL Autonomous Database Actions URL.
  CRASHSIM_ADB_PRIVATE_ENDPOINT Expected private endpoint/DNS/network label.
  CRASHSIM_ADB_SCENARIO         Optional selected ADB scenario id for CLI/menu.
  CRASHSIM_MANIFEST             Default manifest path.
  CRASHSIM_LOG_DIR              Default log directory.
  CRASHSIM_SQLPLUS_LOGON        Default SQL*Plus logon string.
  CRASHSIM_ORACLE_USER_REQUIRED Set to 1 to require OS user "oracle".

Safety:
  Destructive operations are never executed unless --execute is provided.
  Non-interactive destructive --execute actions also require
  CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES or --accept-destructive-lab.
USAGE
}

die() {
  echo "ERROR: $*" >&2
  exit "$FAIL"
}

warn() {
  echo "WARN: $*" >&2
}

# Interactive confirmation I/O. Under audit stream capture stdout is wrapped
# in a redaction pipe, so prompt lines written there can reach the terminal
# late (or, on builds without line-buffered redaction, only at exit) while
# `read` blocks - the operator ends up answering a safety gate they cannot
# see. Mirror prompt lines to the controlling terminal whenever stdout is not
# a tty, and prefer /dev/tty for the reply when stdin is not a tty.
confirm_show() {
  printf "%s\n" "$@"
  if [[ ! -t 1 && -e /dev/tty ]]; then
    # group so a failed /dev/tty open (no controlling terminal) stays silent
    { printf "%s\n" "$@" >/dev/tty; } 2>/dev/null || true
  fi
}

confirm_reply() {
  local __var="$1" __reply=""
  if [[ -t 0 ]]; then
    IFS= read -r __reply
  elif [[ -e /dev/tty ]] && { IFS= read -r __reply </dev/tty; } 2>/dev/null; then
    :
  else
    IFS= read -r __reply || true
  fi
  printf -v "$__var" '%s' "$__reply"
}

info() {
  echo "$*"
}

debug() {
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "DEBUG: $*" >&2
  fi
}

trim_blank_lines() {
  sed '/^[[:space:]]*$/d'
}

trim_value() {
  printf "%s" "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

sql_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "$value"
}

sql_identifier() {
  local value="$1"
  value="${value//\"/\"\"}"
  printf '"%s"' "$value"
}

normalize_name() {
  printf "%s" "$1" | tr '[:lower:]' '[:upper:]'
}

validate_oracle_name() {
  local value="$1"
  [[ "$value" =~ ^[A-Za-z][A-Za-z0-9_#\$]{0,127}$ ]]
}

validate_tempfile_size() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+[KkMmGgTt]?$ ]]
}

normalize_bool() {
  local value="$1"
  case "$(printf "%s" "$value" | tr '[:upper:]' '[:lower:]')" in
    1|true|yes|y|on) printf "1" ;;
    0|false|no|n|off|"") printf "0" ;;
    *) return "$FAIL" ;;
  esac
}

normalize_auto_bool() {
  local value="$1"
  case "$(printf "%s" "$value" | tr '[:upper:]' '[:lower:]')" in
    auto|"") printf "auto" ;;
    1|true|yes|y|on) printf "1" ;;
    0|false|no|n|off) printf "0" ;;
    *) return "$FAIL" ;;
  esac
}

trim_value() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf "%s" "$value"
}

strip_config_quotes() {
  local value
  value="$(trim_value "$1")"
  if [[ "${#value}" -ge 2 ]]; then
    if [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    else
      value="${value%%[[:space:]]#*}"
      value="$(trim_value "$value")"
    fi
  fi
  printf "%s" "$value"
}

redact_config_value() {
  local key="$1"
  local value="$2"
  case "$key" in
    *PASSWORD*|*SECRET*|*TOKEN*|*CATALOG*|*CONNECT*)
      [[ -n "$value" ]] && printf "<redacted>" || printf "not set"
      ;;
    *)
      printf "%s" "${value:-not set}"
      ;;
  esac
}

config_record_applied() {
  local key="$1"
  local value="$2"
  CONFIG_APPLIED+=("${key}=$(redact_config_value "$key" "$value")")
}

config_record_skipped() {
  CONFIG_SKIPPED+=("$1")
}

config_record_warning() {
  CONFIG_WARNINGS+=("$1")
}

config_env_is_set() {
  local env_name="$1"
  [[ -n "${!env_name+x}" ]]
}

config_set_env_if_unset() {
  local key="$1"
  local value="$2"
  local var_name="$3"

  [[ -n "$var_name" ]] || var_name="$key"
  if config_env_is_set "$key"; then
    config_record_skipped "${key}: environment already set"
    return "$SUCCESS"
  fi
  export "${key}=${value}"
  if [[ -n "$var_name" ]]; then
    printf -v "$var_name" "%s" "$value"
  fi
  config_record_applied "$key" "$value"
}

config_set_value_if_env_unset() {
  local key="$1"
  local env_name="$2"
  local var_name="$3"
  local value="$4"

  if config_env_is_set "$env_name"; then
    config_record_skipped "${key}: ${env_name} environment already set"
    return "$SUCCESS"
  fi
  printf -v "$var_name" "%s" "$value"
  config_record_applied "$key" "$value"
}

config_validate_path_value() {
  local key="$1"
  local value="$2"
  [[ -n "$value" ]] || {
    config_record_warning "${key}: empty path ignored"
    return "$FAIL"
  }
  if printf "%s" "$value" | grep -q '[[:cntrl:]]'; then
    config_record_warning "${key}: control characters are not allowed"
    return "$FAIL"
  fi
  return "$SUCCESS"
}

apply_config_entry() {
  local key="$1"
  local value="$2"

  case "$key" in
    ORACLE_SID)
      [[ "$value" =~ ^[A-Za-z0-9_+#.$-]+$ ]] || {
        config_record_warning "${key}: invalid Oracle SID syntax"
        return "$SUCCESS"
      }
      config_set_env_if_unset "$key" "$value" ""
      ;;
    ORACLE_HOME|ORACLE_BASE|TNS_ADMIN|CRASHSIM_GRID_HOME)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_env_if_unset "$key" "$value" ""
      ;;
    SQLPLUS)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_env_if_unset "$key" "$value" "SQLPLUS_BIN"
      ;;
    RMAN)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_env_if_unset "$key" "$value" "RMAN_BIN"
      ;;
    NLS_LANG|TWO_TASK|LOCAL|CRASHSIM_ASM_SID)
      config_set_env_if_unset "$key" "$value" ""
      ;;
    CRASHSIM_PDB|CRASHSIM_DEFAULT_PDB|TARGET_PDB)
      config_set_value_if_env_unset "$key" "CRASHSIM_PDB" TARGET_PDB "$(normalize_name "$value")"
      ;;
    CRASHSIM_SCHEMA|CRASHSIM_DEFAULT_SCHEMA|TARGET_SCHEMA)
      config_set_value_if_env_unset "$key" "CRASHSIM_SCHEMA" TARGET_SCHEMA "$(normalize_name "$value")"
      ;;
    CRASHSIM_FILE_NO|TARGET_FILE_NO)
      config_set_value_if_env_unset "$key" "CRASHSIM_FILE_NO" TARGET_FILE_NO "$value"
      ;;
    CRASHSIM_PFILE|PFILE_PATH)
      config_set_value_if_env_unset "$key" "CRASHSIM_PFILE" PFILE_PATH "$value"
      ;;
    CRASHSIM_SERVICE_NAME|SERVICE_NAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_SERVICE_NAME" SERVICE_NAME "$value"
      ;;
    CRASHSIM_SYSBACKUP_USER|SYSBACKUP_USER)
      config_set_value_if_env_unset "$key" "CRASHSIM_SYSBACKUP_USER" SYSBACKUP_USER "$(normalize_name "$value")"
      ;;
    CRASHSIM_TEMPFILE_SIZE|TEMPFILE_SIZE)
      config_set_value_if_env_unset "$key" "CRASHSIM_TEMPFILE_SIZE" TEMPFILE_SIZE "$value"
      ;;
    CRASHSIM_GRID_USER|GRID_USER)
      config_set_value_if_env_unset "$key" "CRASHSIM_GRID_USER" GRID_USER "$value"
      ;;
    CRASHSIM_LOCAL_ONLY|LOCAL_ONLY)
      config_set_value_if_env_unset "$key" "CRASHSIM_LOCAL_ONLY" LOCAL_ONLY "$value"
      ;;
    CRASHSIM_MAX_TARGETS|MAX_TARGETS)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAX_TARGETS" MAX_TARGETS "$value"
      ;;
    CRASHSIM_PIECE_HANDLE|PIECE_HANDLE)
      config_set_value_if_env_unset "$key" "CRASHSIM_PIECE_HANDLE" PIECE_HANDLE "$value"
      ;;
    CRASHSIM_REPORT_DEEP_VALIDATE|REPORT_DEEP_VALIDATE)
      config_set_value_if_env_unset "$key" "CRASHSIM_REPORT_DEEP_VALIDATE" REPORT_DEEP_VALIDATE "$value"
      ;;
    CRASHSIM_RMAN_CATALOG|RMAN_CATALOG_CONNECT)
      config_set_value_if_env_unset "$key" "CRASHSIM_RMAN_CATALOG" RMAN_CATALOG_CONNECT "$value"
      ;;
    CRASHSIM_BASELINE_TAG_PREFIX|BASELINE_TAG_PREFIX)
      config_set_value_if_env_unset "$key" "CRASHSIM_BASELINE_TAG_PREFIX" BASELINE_TAG_PREFIX "$value"
      ;;
    CRASHSIM_FRA_PRESSURE_TARGET_PCT|FRA_PRESSURE_TARGET_PCT)
      config_set_value_if_env_unset "$key" "CRASHSIM_FRA_PRESSURE_TARGET_PCT" FRA_PRESSURE_TARGET_PCT "$value"
      ;;
    CRASHSIM_FRA_PRESSURE_HEADROOM_MB|FRA_PRESSURE_HEADROOM_MB)
      config_set_value_if_env_unset "$key" "CRASHSIM_FRA_PRESSURE_HEADROOM_MB" FRA_PRESSURE_HEADROOM_MB "$value"
      ;;
    CRASHSIM_TEMP_EXHAUST_MB|TEMP_EXHAUST_MB)
      config_set_value_if_env_unset "$key" "CRASHSIM_TEMP_EXHAUST_MB" TEMP_EXHAUST_MB "$value"
      ;;
    CRASHSIM_ORDS_SERVICE|ORDS_SERVICE_NAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_SERVICE" ORDS_SERVICE_NAME "$value"
      ;;
    CRASHSIM_ORDS_CONFIG_DIR|ORDS_CONFIG_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_CONFIG_DIR" ORDS_CONFIG_DIR "$value"
      ;;
    CRASHSIM_ORDS_URL|ORDS_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_URL" ORDS_URL "$value"
      ;;
    CRASHSIM_ORDS_LB_URL|ORDS_LB_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_LB_URL" ORDS_LB_URL "$value"
      ;;
    CRASHSIM_ORDS_DB_POOL|ORDS_DB_POOL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_DB_POOL" ORDS_DB_POOL "$value"
      ;;
    CRASHSIM_ORDS_PRIV_HELPER|ORDS_PRIV_HELPER)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORDS_PRIV_HELPER" ORDS_PRIV_HELPER "$value"
      ;;
    CRASHSIM_APEX_IMAGES_DIR|APEX_IMAGES_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_IMAGES_DIR" APEX_IMAGES_DIR "$value"
      ;;
    CRASHSIM_APEX_SESSION_DRIVER|APEX_SESSION_DRIVER)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_DRIVER" APEX_SESSION_DRIVER "$value"
      ;;
    CRASHSIM_APEX_SESSION_URL|APEX_SESSION_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_URL" APEX_SESSION_URL "$value"
      ;;
    CRASHSIM_APEX_SESSION_USERNAME|APEX_SESSION_USERNAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_USERNAME" APEX_SESSION_USERNAME "$value"
      ;;
    CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR|APEX_SESSION_SUCCESS_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_SUCCESS_SELECTOR" APEX_SESSION_SUCCESS_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_USERNAME_SELECTOR|APEX_SESSION_USERNAME_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_USERNAME_SELECTOR" APEX_SESSION_USERNAME_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_PASSWORD_SELECTOR|APEX_SESSION_PASSWORD_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_PASSWORD_SELECTOR" APEX_SESSION_PASSWORD_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_SUBMIT_SELECTOR|APEX_SESSION_SUBMIT_SELECTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_SUBMIT_SELECTOR" APEX_SESSION_SUBMIT_SELECTOR "$value"
      ;;
    CRASHSIM_APEX_SESSION_DURATION|APEX_SESSION_DURATION)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_DURATION" APEX_SESSION_DURATION "$value"
      ;;
    CRASHSIM_APEX_SESSION_INTERVAL|APEX_SESSION_INTERVAL)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_INTERVAL" APEX_SESSION_INTERVAL "$value"
      ;;
    CRASHSIM_APEX_SESSION_HEADLESS|APEX_SESSION_HEADLESS)
      config_set_value_if_env_unset "$key" "CRASHSIM_APEX_SESSION_HEADLESS" APEX_SESSION_HEADLESS "$value"
      ;;
    CRASHSIM_AUDIT_RETAIN|AUDIT_RETAIN)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_RETAIN" AUDIT_RETAIN "$value"
      ;;
    CRASHSIM_AUDIT_RETENTION_DAYS|AUDIT_RETENTION_DAYS)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_RETENTION_DAYS" AUDIT_RETENTION_DAYS "$value"
      ;;
    CRASHSIM_AUDIT_DIR|AUDIT_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_DIR" AUDIT_DIR "$value"
      ;;
    CRASHSIM_AUDIT_STREAM_CAPTURE|AUDIT_STREAM_CAPTURE)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUDIT_STREAM_CAPTURE" AUDIT_STREAM_CAPTURE "$value"
      ;;
    CRASHSIM_AUTO_SCORECARD|AUTO_SCORECARD)
      config_set_value_if_env_unset "$key" "CRASHSIM_AUTO_SCORECARD" AUTO_SCORECARD "$value"
      ;;
    CRASHSIM_ACCEPT_DESTRUCTIVE_LAB|ACCEPT_DESTRUCTIVE_LAB|DESTRUCTIVE_LAB_ACK)
      config_set_value_if_env_unset "$key" "CRASHSIM_ACCEPT_DESTRUCTIVE_LAB" DESTRUCTIVE_LAB_ACK "$value"
      ;;
    CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS|TOPOLOGY_CACHE_TTL_SECONDS)
      config_set_value_if_env_unset "$key" "CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS" TOPOLOGY_CACHE_TTL_SECONDS "$value"
      ;;
    CRASHSIM_DISABLE_TOPOLOGY_CACHE|DISABLE_TOPOLOGY_CACHE)
      config_set_value_if_env_unset "$key" "CRASHSIM_DISABLE_TOPOLOGY_CACHE" TOPOLOGY_CACHE_DISABLED "$value"
      ;;
    CRASHSIM_SECRET_SCAN_PATH|SECRET_SCAN_PATH)
      config_set_value_if_env_unset "$key" "CRASHSIM_SECRET_SCAN_PATH" SECRET_SCAN_PATH "$value"
      ;;
    CRASHSIM_SANITIZE_SOURCE_DIR|SANITIZE_SOURCE_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_SANITIZE_SOURCE_DIR" SANITIZE_SOURCE_DIR "$value"
      ;;
    CRASHSIM_SANITIZE_OUTPUT_DIR|SANITIZE_OUTPUT_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_SANITIZE_OUTPUT_DIR" SANITIZE_OUTPUT_DIR "$value"
      ;;
    CRASHSIM_HTML_TARGET|HTML_TARGET)
      config_set_value_if_env_unset "$key" "CRASHSIM_HTML_TARGET" HTML_TARGET "$value"
      ;;
    CRASHSIM_REVIEW_TARGET|REVIEW_TARGET)
      config_set_value_if_env_unset "$key" "CRASHSIM_REVIEW_TARGET" REVIEW_TARGET "$value"
      ;;
    CRASHSIM_MAA_APP_NAME|MAA_APP_NAME)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_APP_NAME" MAA_APP_NAME "$value"
      ;;
    CRASHSIM_MAA_LOCAL_RTO|MAA_LOCAL_RTO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_LOCAL_RTO" MAA_LOCAL_RTO "$value"
      ;;
    CRASHSIM_MAA_LOCAL_RPO|MAA_LOCAL_RPO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_LOCAL_RPO" MAA_LOCAL_RPO "$value"
      ;;
    CRASHSIM_MAA_DR_RTO|MAA_DR_RTO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_DR_RTO" MAA_DR_RTO "$value"
      ;;
    CRASHSIM_MAA_DR_RPO|MAA_DR_RPO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_DR_RPO" MAA_DR_RPO "$value"
      ;;
    CRASHSIM_MAA_PLANNED_RTO|MAA_PLANNED_RTO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_PLANNED_RTO" MAA_PLANNED_RTO "$value"
      ;;
    CRASHSIM_MAA_PLANNED_RPO|MAA_PLANNED_RPO)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_PLANNED_RPO" MAA_PLANNED_RPO "$value"
      ;;
    CRASHSIM_MAA_CRITICALITY|MAA_CRITICALITY)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_CRITICALITY" MAA_CRITICALITY "$value"
      ;;
    CRASHSIM_MAA_LOCAL_HA_TARGET|MAA_LOCAL_HA_TARGET)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_LOCAL_HA_TARGET" MAA_LOCAL_HA_TARGET "$value"
      ;;
    CRASHSIM_MAA_DR_REQUIRED|MAA_DR_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_DR_REQUIRED" MAA_DR_REQUIRED "$value"
      ;;
    CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED|MAA_AUTOMATIC_FAILOVER_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED" MAA_AUTOMATIC_FAILOVER_REQUIRED "$value"
      ;;
    CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED|MAA_ACTIVE_ACTIVE_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED" MAA_ACTIVE_ACTIVE_REQUIRED "$value"
      ;;
    CRASHSIM_MAA_PLATFORM_HINT|MAA_PLATFORM_HINT)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_PLATFORM_HINT" MAA_PLATFORM_HINT "$value"
      ;;
    CRASHSIM_MAA_STANDBY_SCOPE|MAA_STANDBY_SCOPE)
      config_set_value_if_env_unset "$key" "CRASHSIM_MAA_STANDBY_SCOPE" MAA_STANDBY_SCOPE "$value"
      ;;
    CRASHSIM_ADB_WALLET_DIR|ADB_WALLET_DIR)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_WALLET_DIR" ADB_WALLET_DIR "$value"
      ;;
    CRASHSIM_ADB_CONNECT_ALIAS|ADB_CONNECT_ALIAS)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_CONNECT_ALIAS" ADB_CONNECT_ALIAS "$value"
      ;;
    CRASHSIM_ADB_CONNECT_DESCRIPTOR|ADB_CONNECT_DESCRIPTOR)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_CONNECT_DESCRIPTOR" ADB_CONNECT_DESCRIPTOR "$value"
      ;;
    CRASHSIM_ADB_SERVICE_LEVEL|ADB_SERVICE_LEVEL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_SERVICE_LEVEL" ADB_SERVICE_LEVEL "$value"
      ;;
    CRASHSIM_ADB_USER|ADB_USER)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_USER" ADB_USER "$(normalize_name "$value")"
      ;;
    CRASHSIM_ADB_PASSWORD_ENV|ADB_PASSWORD_ENV)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_PASSWORD_ENV" ADB_PASSWORD_ENV "$value"
      ;;
    CRASHSIM_ADB_WALLET_PASSWORD_ENV|ADB_WALLET_PASSWORD_ENV)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_WALLET_PASSWORD_ENV" ADB_WALLET_PASSWORD_ENV "$value"
      ;;
    CRASHSIM_ADB_PYTHON|ADB_PYTHON)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_PYTHON" ADB_PYTHON "$value"
      ;;
    CRASHSIM_ADB_TLS_MODE|ADB_TLS_MODE)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_TLS_MODE" ADB_TLS_MODE "$value"
      ;;
    CRASHSIM_ADB_OCID|ADB_OCID)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCID" ADB_OCID "$value"
      ;;
    CRASHSIM_ADB_COMPARTMENT_OCID|ADB_COMPARTMENT_OCID)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_COMPARTMENT_OCID" ADB_COMPARTMENT_OCID "$value"
      ;;
    CRASHSIM_ADB_REGION|ADB_REGION)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_REGION" ADB_REGION "$value"
      ;;
    CRASHSIM_ADB_OCI_PROFILE|ADB_OCI_PROFILE)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCI_PROFILE" ADB_OCI_PROFILE "$value"
      ;;
    CRASHSIM_ADB_OCI_CONFIG_FILE|ADB_OCI_CONFIG_FILE)
      config_validate_path_value "$key" "$value" || return "$SUCCESS"
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCI_CONFIG_FILE" ADB_OCI_CONFIG_FILE "$value"
      ;;
    CRASHSIM_ADB_OCI_AUTH|ADB_OCI_AUTH)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_OCI_AUTH" ADB_OCI_AUTH "$value"
      ;;
    CRASHSIM_ADB_APEX_URL|ADB_APEX_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_APEX_URL" ADB_APEX_URL "$value"
      ;;
    CRASHSIM_ADB_DATABASE_ACTIONS_URL|ADB_DATABASE_ACTIONS_URL)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_DATABASE_ACTIONS_URL" ADB_DATABASE_ACTIONS_URL "$value"
      ;;
    CRASHSIM_ADB_PRIVATE_ENDPOINT|ADB_PRIVATE_ENDPOINT)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_PRIVATE_ENDPOINT" ADB_PRIVATE_ENDPOINT "$value"
      ;;
    CRASHSIM_ADB_SCENARIO|ADB_SCENARIO_ID)
      config_set_value_if_env_unset "$key" "CRASHSIM_ADB_SCENARIO" ADB_SCENARIO_ID "$(printf "%s" "$value" | tr '[:lower:]' '[:upper:]')"
      ;;
    CRASHSIM_MANIFEST|MANIFEST_FILE)
      config_set_value_if_env_unset "$key" "CRASHSIM_MANIFEST" MANIFEST_FILE "$value"
      [[ -n "$MANIFEST_FILE" ]] && MANIFEST_FROM_ARG=1
      ;;
    CRASHSIM_LOG_DIR|LOG_DIR)
      config_set_value_if_env_unset "$key" "CRASHSIM_LOG_DIR" LOG_DIR "$value"
      ;;
    CRASHSIM_SQLPLUS_LOGON|SQLPLUS_LOGON)
      config_set_value_if_env_unset "$key" "CRASHSIM_SQLPLUS_LOGON" SQLPLUS_LOGON "$value"
      ;;
    CRASHSIM_ORACLE_USER_REQUIRED|ORACLE_USER_REQUIRED)
      config_set_value_if_env_unset "$key" "CRASHSIM_ORACLE_USER_REQUIRED" ORACLE_USER_REQUIRED "$value"
      ;;
    CRASHSIM_SYS_PASSWORD|SYS_PASSWORD|CRASHSIM_APEX_SESSION_PASSWORD|APEX_SESSION_PASSWORD|CRASHSIM_ADB_PASSWORD|ADB_PASSWORD|CRASHSIM_ADB_WALLET_PASSWORD|ADB_WALLET_PASSWORD)
      config_record_warning "${key}: sensitive values are intentionally ignored in config files; use environment variables, wallets, or guided prompts"
      ;;
    PATH|HOME|LD_LIBRARY_PATH)
      config_record_warning "${key}: ignored for safety; set it in the shell before starting CrashSimulator"
      ;;
    *)
      config_record_warning "${key}: unknown or unsupported configuration key"
      ;;
  esac
}

load_config_file() {
  local file="$1"
  local line key value line_no

  [[ -f "$file" ]] || die "Configuration file was not found: $file"
  [[ -r "$file" ]] || die "Configuration file is not readable: $file"

  CONFIG_SOURCE="$file"
  CONFIG_LOADED=1
  CONFIG_APPLIED=()
  CONFIG_SKIPPED=()
  CONFIG_WARNINGS=()

  line_no=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    line_no=$((line_no + 1))
    line="$(trim_value "$line")"
    [[ -n "$line" ]] || continue
    [[ "$line" == \#* ]] && continue
    if [[ "$line" == export[[:space:]]* ]]; then
      line="$(trim_value "${line#export}")"
    fi
    if [[ "$line" != *=* ]]; then
      config_record_warning "line ${line_no}: expected KEY=value"
      continue
    fi
    key="$(trim_value "${line%%=*}")"
    value="$(strip_config_quotes "${line#*=}")"
    if [[ ! "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      config_record_warning "line ${line_no}: invalid key '${key}'"
      continue
    fi
    apply_config_entry "$key" "$value"
  done <"$file"
}

prescan_config_args() {
  CONFIG_FILE="${CRASHSIM_CONFIG:-}"
  CONFIG_EXPLICIT=0
  CONFIG_DISABLED=0

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --config)
        [[ "$#" -ge 2 ]] || die "--config requires a file path"
        CONFIG_FILE="$2"
        CONFIG_EXPLICIT=1
        shift 2
        ;;
      --no-config)
        CONFIG_DISABLED=1
        shift
        ;;
      --help|-h)
        CONFIG_DISABLED=1
        shift
        ;;
      --)
        break
        ;;
      *)
        shift
        ;;
    esac
  done
}

load_startup_config() {
  local candidate

  prescan_config_args "$@"
  [[ "$CONFIG_DISABLED" -eq 1 ]] && return "$SUCCESS"

  if [[ -n "$CONFIG_FILE" ]]; then
    load_config_file "$CONFIG_FILE"
    return "$SUCCESS"
  fi

  for candidate in \
    "./crashsimulator.conf" \
    "${SCRIPT_DIR:-}/crashsimulator.conf" \
    "${HOME:-}/.crashsimulator/crashsimulator.conf" \
    "/etc/crashsimulator/crashsimulator.conf"; do
    [[ -n "$candidate" ]] || continue
    if [[ -f "$candidate" ]]; then
      CONFIG_FILE="$candidate"
      load_config_file "$candidate"
      return "$SUCCESS"
    fi
  done
}

show_active_config() {
  local item

  echo "CrashSimulator active startup configuration"
  echo "  Loaded config: ${CONFIG_SOURCE:-not loaded}"
  echo "  Config disabled: ${CONFIG_DISABLED}"
  echo
  echo "Oracle environment:"
  echo "  ORACLE_SID=${ORACLE_SID:-not set}"
  echo "  ORACLE_HOME=${ORACLE_HOME:-not set}"
  echo "  ORACLE_BASE=${ORACLE_BASE:-not set}"
  echo "  TNS_ADMIN=${TNS_ADMIN:-not set}"
  echo "  SQLPLUS=${SQLPLUS_BIN:-${SQLPLUS:-not set}}"
  echo "  RMAN=${RMAN_BIN:-${RMAN:-not set}}"
  echo "  CRASHSIM_GRID_HOME=${CRASHSIM_GRID_HOME:-not set}"
  echo "  CRASHSIM_ASM_SID=${CRASHSIM_ASM_SID:-not set}"
  echo
  echo "CrashSimulator defaults:"
  echo "  PDB=${TARGET_PDB:-not set}"
  echo "  Schema=${TARGET_SCHEMA:-not set}"
  echo "  FILE#=${TARGET_FILE_NO:-not set}"
  echo "  Log dir=${LOG_DIR:-not set}"
  echo "  SQL*Plus logon=$(redact_config_value SQLPLUS_LOGON "$SQLPLUS_LOGON")"
  echo "  Audit retain=${AUDIT_RETAIN}"
  echo "  Audit retention days=${AUDIT_RETENTION_DAYS}"
  echo "  Audit dir=${AUDIT_DIR:-not set}"
  echo "  Auto resilience scorecard refresh=${AUTO_SCORECARD}"
  echo "  Destructive lab acknowledgement=$([[ "${DESTRUCTIVE_LAB_ACK^^}" == "YES" ]] && echo set || echo not set)"
  echo "  Topology cache TTL seconds=${TOPOLOGY_CACHE_TTL_SECONDS}"
  echo "  Topology cache disabled=${TOPOLOGY_CACHE_DISABLED}"
  echo "  Secret scan path=${SECRET_SCAN_PATH}"
  echo "  Sanitize source=${SANITIZE_SOURCE_DIR}"
  echo "  Sanitize output=${SANITIZE_OUTPUT_DIR:-auto}"
  echo "  RMAN catalog=$(redact_config_value RMAN_CATALOG_CONNECT "$RMAN_CATALOG_CONNECT")"
  echo "  Baseline tag prefix=${BASELINE_TAG_PREFIX}"
  echo "  ORDS URL=${ORDS_URL:-not set}"
  echo "  ORDS config dir=${ORDS_CONFIG_DIR:-not set}"
  echo "  APEX session URL=${APEX_SESSION_URL:-not set}"
  echo
  echo "MAA decision-tree context:"
  echo "  Application=${MAA_APP_NAME:-not set}"
  echo "  Criticality=${MAA_CRITICALITY:-not set}"
  echo "  Local unplanned RTO=${MAA_LOCAL_RTO:-not set}"
  echo "  Local unplanned RPO=${MAA_LOCAL_RPO:-not set}"
  echo "  Local HA target=${MAA_LOCAL_HA_TARGET:-not set}"
  echo "  Disaster/site RTO=${MAA_DR_RTO:-not set}"
  echo "  Disaster/site RPO=${MAA_DR_RPO:-not set}"
  echo "  DR required=${MAA_DR_REQUIRED:-not set}"
  echo "  Automatic failover required=${MAA_AUTOMATIC_FAILOVER_REQUIRED:-not set}"
  echo "  Planned maintenance RTO=${MAA_PLANNED_RTO:-not set}"
  echo "  Planned maintenance RPO=${MAA_PLANNED_RPO:-not set}"
  echo "  Active-active required=${MAA_ACTIVE_ACTIVE_REQUIRED:-not set}"
  echo "  Platform hint=${MAA_PLATFORM_HINT:-not set}"
  echo "  Standby scope=${MAA_STANDBY_SCOPE:-unknown}"
  echo
  echo "Autonomous Database defaults:"
  echo "  ADB wallet dir=${ADB_WALLET_DIR:-not set}"
  echo "  ADB connect alias=${ADB_CONNECT_ALIAS:-not set}"
  echo "  ADB connect descriptor=$([[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && printf configured || printf "not set")"
  echo "  ADB service level=${ADB_SERVICE_LEVEL:-not set}"
  echo "  ADB user=${ADB_USER:-not set}"
  echo "  ADB TLS mode=${ADB_TLS_MODE:-not set}"
  echo "  ADB password env=${ADB_PASSWORD_ENV:-not set}"
  echo "  ADB wallet password env=${ADB_WALLET_PASSWORD_ENV:-not set}"
  echo "  ADB Python=${ADB_PYTHON:-not set}"
  echo "  ADB OCID=${ADB_OCID:-not set}"
  echo "  ADB compartment OCID=${ADB_COMPARTMENT_OCID:-not set}"
  echo "  ADB region=${ADB_REGION:-not set}"
  echo "  ADB OCI profile=${ADB_OCI_PROFILE:-not set}"
  echo "  ADB OCI config file=${ADB_OCI_CONFIG_FILE:-not set}"
  echo "  ADB OCI auth=${ADB_OCI_AUTH:-not set}"
  echo "  ADB APEX URL=${ADB_APEX_URL:-not set}"
  echo "  ADB Database Actions URL=${ADB_DATABASE_ACTIONS_URL:-not set}"
  echo "  ADB private endpoint=${ADB_PRIVATE_ENDPOINT:-not set}"
  echo "  ADB selected scenario=${ADB_SCENARIO_ID:-not set}"
  echo
  if [[ "${#CONFIG_APPLIED[@]}" -gt 0 ]]; then
    echo "Config values applied:"
    for item in "${CONFIG_APPLIED[@]}"; do
      echo "  - ${item}"
    done
  else
    echo "Config values applied: none"
  fi
  if [[ "${#CONFIG_SKIPPED[@]}" -gt 0 ]]; then
    echo
    echo "Config values skipped:"
    for item in "${CONFIG_SKIPPED[@]}"; do
      echo "  - ${item}"
    done
  fi
  if [[ "${#CONFIG_WARNINGS[@]}" -gt 0 ]]; then
    echo
    echo "Config warnings:"
    for item in "${CONFIG_WARNINGS[@]}"; do
      echo "  - ${item}"
    done
  fi
}

validate_config_runtime() {
  local errors=0 warnings=0

  show_active_config
  echo
  echo "Configuration validation:"

  if [[ -n "$CONFIG_SOURCE" ]]; then
    if [[ ! -f "$CONFIG_SOURCE" ]]; then
      echo "  ERROR: loaded config no longer exists: $CONFIG_SOURCE"
      errors=$((errors + 1))
    elif [[ ! -r "$CONFIG_SOURCE" ]]; then
      echo "  ERROR: loaded config is not readable: $CONFIG_SOURCE"
      errors=$((errors + 1))
    else
      echo "  OK: config file is readable"
    fi
  else
    echo "  WARN: no configuration file was loaded"
    warnings=$((warnings + 1))
  fi

  if [[ -n "${ORACLE_HOME:-}" ]]; then
    if [[ -d "$ORACLE_HOME" ]]; then
      echo "  OK: ORACLE_HOME directory exists"
      if [[ -x "${ORACLE_HOME}/bin/sqlplus" ]]; then
        echo "  OK: sqlplus exists under ORACLE_HOME"
      else
        echo "  WARN: ${ORACLE_HOME}/bin/sqlplus is not executable"
        warnings=$((warnings + 1))
      fi
      if [[ -x "${ORACLE_HOME}/bin/rman" ]]; then
        echo "  OK: rman exists under ORACLE_HOME"
      else
        echo "  WARN: ${ORACLE_HOME}/bin/rman is not executable"
        warnings=$((warnings + 1))
      fi
    else
      echo "  ERROR: ORACLE_HOME directory does not exist: $ORACLE_HOME"
      errors=$((errors + 1))
    fi
  else
    echo "  WARN: ORACLE_HOME is not set; CrashSimulator will depend on PATH for sqlplus/rman"
    warnings=$((warnings + 1))
  fi

  if [[ -n "${ORACLE_SID:-}" ]]; then
    echo "  OK: ORACLE_SID is set to ${ORACLE_SID}"
  else
    echo "  WARN: ORACLE_SID is not set; local / as sysdba connections may fail"
    warnings=$((warnings + 1))
  fi

  if [[ -n "${TNS_ADMIN:-}" ]]; then
    if [[ -d "$TNS_ADMIN" ]]; then
      echo "  OK: TNS_ADMIN directory exists"
    else
      echo "  WARN: TNS_ADMIN directory does not exist: $TNS_ADMIN"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -n "${CRASHSIM_GRID_HOME:-}" ]]; then
    if [[ -d "$CRASHSIM_GRID_HOME" ]]; then
      echo "  OK: CRASHSIM_GRID_HOME directory exists"
    else
      echo "  WARN: CRASHSIM_GRID_HOME directory does not exist: $CRASHSIM_GRID_HOME"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -n "$LOG_DIR" ]]; then
    if [[ -d "$LOG_DIR" && -w "$LOG_DIR" ]]; then
      echo "  OK: log directory exists and is writable"
    else
      echo "  WARN: log directory is not currently writable or does not exist: $LOG_DIR"
      warnings=$((warnings + 1))
    fi
  fi

  if [[ -n "$ADB_WALLET_DIR" ]]; then
    if [[ -d "$ADB_WALLET_DIR" ]]; then
      echo "  OK: ADB wallet directory exists"
      if [[ -f "${ADB_WALLET_DIR}/tnsnames.ora" ]]; then
        echo "  OK: ADB tnsnames.ora exists"
      else
        echo "  WARN: ADB wallet directory does not contain tnsnames.ora"
        warnings=$((warnings + 1))
      fi
    else
      echo "  WARN: ADB wallet directory does not exist: $ADB_WALLET_DIR"
      warnings=$((warnings + 1))
    fi
  fi
  if [[ -n "$ADB_PYTHON" ]]; then
    if command -v "$ADB_PYTHON" >/dev/null 2>&1 || [[ -x "$ADB_PYTHON" ]]; then
      echo "  OK: ADB Python executable found"
    else
      echo "  WARN: ADB Python executable was not found: $ADB_PYTHON"
      warnings=$((warnings + 1))
    fi
  fi
  if [[ -n "$ADB_PASSWORD_ENV" ]]; then
    if [[ -n "${!ADB_PASSWORD_ENV:-}" ]]; then
      echo "  OK: ADB password environment variable is set"
    else
      echo "  INFO: ADB password environment variable is not set: $ADB_PASSWORD_ENV"
    fi
  fi

  echo "  Summary: errors=${errors} warnings=${warnings}"
  [[ "$errors" -eq 0 ]]
}

write_config_template() {
  local file="$1"
  local dir template_sqlplus_logon

  [[ -n "$file" ]] || die "No configuration template path provided."
  if [[ -e "$file" && "$ASSUME_YES" -ne 1 ]]; then
    die "Refusing to overwrite existing file without --yes: $file"
  fi
  dir="$(dirname "$file")"
  [[ "$dir" == "." || -d "$dir" ]] || mkdir -p "$dir" || die "Unable to create directory: $dir"
  template_sqlplus_logon="/ as sysdba"
  if [[ "${SQLPLUS_LOGON:-}" == /* ]]; then
    template_sqlplus_logon="$SQLPLUS_LOGON"
  fi

  cat >"$file" <<EOF || die "Unable to write configuration template: $file"
# CrashSimulator startup configuration
# Precedence: CLI arguments > existing environment variables > this file > built-in defaults.
# Do not store SYS, RMAN catalog, APEX, wallet, token, or other secrets in this file.

ORACLE_SID=${ORACLE_SID:-}
ORACLE_HOME=${ORACLE_HOME:-}
ORACLE_BASE=${ORACLE_BASE:-}
TNS_ADMIN=${TNS_ADMIN:-}

# Optional Grid/ASM context for RAC/ASM reports and planning helpers.
CRASHSIM_GRID_HOME=${CRASHSIM_GRID_HOME:-}
CRASHSIM_ASM_SID=${CRASHSIM_ASM_SID:-}
CRASHSIM_GRID_USER=${GRID_USER:-grid}

# CrashSimulator defaults.
CRASHSIM_PDB=${TARGET_PDB:-}
CRASHSIM_SCHEMA=${TARGET_SCHEMA:-}
CRASHSIM_LOG_DIR=${LOG_DIR:-}
CRASHSIM_SQLPLUS_LOGON='${template_sqlplus_logon}'
CRASHSIM_AUDIT_RETAIN=${AUDIT_RETAIN}
CRASHSIM_AUDIT_RETENTION_DAYS=${AUDIT_RETENTION_DAYS}
CRASHSIM_AUTO_SCORECARD=${AUTO_SCORECARD}
CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=
CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS=${TOPOLOGY_CACHE_TTL_SECONDS}
CRASHSIM_DISABLE_TOPOLOGY_CACHE=${TOPOLOGY_CACHE_DISABLED}
CRASHSIM_SECRET_SCAN_PATH=${SECRET_SCAN_PATH}
CRASHSIM_SANITIZE_SOURCE_DIR=${SANITIZE_SOURCE_DIR}
CRASHSIM_SANITIZE_OUTPUT_DIR=${SANITIZE_OUTPUT_DIR}
# Optional RMAN catalog connect string. Prefer an Oracle wallet alias such as
# CRASHSIM_RMAN_CATALOG=/@crashsim_rman_catalog instead of a password here.
CRASHSIM_RMAN_CATALOG=
CRASHSIM_BASELINE_TAG_PREFIX=${BASELINE_TAG_PREFIX}

# Optional MAA decision-tree context. These are non-secret planning values.
CRASHSIM_MAA_APP_NAME="${MAA_APP_NAME}"
CRASHSIM_MAA_LOCAL_RTO="${MAA_LOCAL_RTO}"
CRASHSIM_MAA_LOCAL_RPO="${MAA_LOCAL_RPO}"
CRASHSIM_MAA_DR_RTO="${MAA_DR_RTO}"
CRASHSIM_MAA_DR_RPO="${MAA_DR_RPO}"
CRASHSIM_MAA_PLANNED_RTO="${MAA_PLANNED_RTO}"
CRASHSIM_MAA_PLANNED_RPO="${MAA_PLANNED_RPO}"
CRASHSIM_MAA_CRITICALITY="${MAA_CRITICALITY}"
CRASHSIM_MAA_LOCAL_HA_TARGET="${MAA_LOCAL_HA_TARGET}"
CRASHSIM_MAA_DR_REQUIRED="${MAA_DR_REQUIRED}"
CRASHSIM_MAA_AUTOMATIC_FAILOVER_REQUIRED="${MAA_AUTOMATIC_FAILOVER_REQUIRED}"
CRASHSIM_MAA_ACTIVE_ACTIVE_REQUIRED="${MAA_ACTIVE_ACTIVE_REQUIRED}"
CRASHSIM_MAA_PLATFORM_HINT="${MAA_PLATFORM_HINT}"
CRASHSIM_MAA_STANDBY_SCOPE="${MAA_STANDBY_SCOPE}"

# Optional APEX/ORDS defaults.
CRASHSIM_ORDS_SERVICE=${ORDS_SERVICE_NAME}
CRASHSIM_ORDS_CONFIG_DIR=${ORDS_CONFIG_DIR}
CRASHSIM_ORDS_URL=${ORDS_URL}
CRASHSIM_ORDS_LB_URL=${ORDS_LB_URL}
CRASHSIM_APEX_IMAGES_DIR=${APEX_IMAGES_DIR}
CRASHSIM_APEX_SESSION_URL=${APEX_SESSION_URL}
CRASHSIM_APEX_SESSION_USERNAME=${APEX_SESSION_USERNAME}

# Optional Autonomous Database defaults. Keep passwords in environment
# variables named by CRASHSIM_ADB_PASSWORD_ENV and
# CRASHSIM_ADB_WALLET_PASSWORD_ENV.
CRASHSIM_ADB_WALLET_DIR=${ADB_WALLET_DIR}
CRASHSIM_ADB_CONNECT_ALIAS=${ADB_CONNECT_ALIAS}
CRASHSIM_ADB_CONNECT_DESCRIPTOR=${ADB_CONNECT_DESCRIPTOR}
CRASHSIM_ADB_SERVICE_LEVEL=${ADB_SERVICE_LEVEL}
CRASHSIM_ADB_USER=${ADB_USER}
CRASHSIM_ADB_PASSWORD_ENV=${ADB_PASSWORD_ENV}
CRASHSIM_ADB_WALLET_PASSWORD_ENV=${ADB_WALLET_PASSWORD_ENV}
CRASHSIM_ADB_PYTHON=${ADB_PYTHON}
CRASHSIM_ADB_TLS_MODE=${ADB_TLS_MODE}
CRASHSIM_ADB_OCID=${ADB_OCID}
CRASHSIM_ADB_COMPARTMENT_OCID=${ADB_COMPARTMENT_OCID}
CRASHSIM_ADB_REGION=${ADB_REGION}
CRASHSIM_ADB_OCI_PROFILE=${ADB_OCI_PROFILE}
CRASHSIM_ADB_OCI_CONFIG_FILE=${ADB_OCI_CONFIG_FILE}
CRASHSIM_ADB_OCI_AUTH=${ADB_OCI_AUTH}
CRASHSIM_ADB_APEX_URL=${ADB_APEX_URL}
CRASHSIM_ADB_DATABASE_ACTIONS_URL=${ADB_DATABASE_ACTIONS_URL}
CRASHSIM_ADB_PRIVATE_ENDPOINT=${ADB_PRIVATE_ENDPOINT}
CRASHSIM_ADB_SCENARIO=${ADB_SCENARIO_ID}
EOF

  chmod 600 "$file" 2>/dev/null || true
  echo "Configuration template written: $file"
  echo "Review it, remove unused values, and keep secrets in environment variables or wallets."
}

normalize_targets() {
  if [[ -n "$TARGET_PDB" ]]; then
    TARGET_PDB="$(normalize_name "$TARGET_PDB")"
    validate_oracle_name "$TARGET_PDB" || die "Invalid PDB name: $TARGET_PDB"
  fi
  if [[ -n "$TARGET_SCHEMA" ]]; then
    TARGET_SCHEMA="$(normalize_name "$TARGET_SCHEMA")"
    validate_oracle_name "$TARGET_SCHEMA" || die "Invalid schema name: $TARGET_SCHEMA"
  fi
  if [[ -n "$TARGET_FILE_NO" && ! "$TARGET_FILE_NO" =~ ^[0-9]+$ ]]; then
    die "Invalid file number: $TARGET_FILE_NO"
  fi
  if [[ -n "$SYSBACKUP_USER" ]]; then
    SYSBACKUP_USER="$(normalize_name "$SYSBACKUP_USER")"
    validate_oracle_name "$SYSBACKUP_USER" || die "Invalid SYSBACKUP user name: $SYSBACKUP_USER"
  fi
  if [[ -n "$ADB_USER" ]]; then
    ADB_USER="$(normalize_name "$ADB_USER")"
    validate_oracle_name "$ADB_USER" || die "Invalid ADB user name: $ADB_USER"
  fi
  if [[ -n "$ADB_SCENARIO_ID" ]]; then
    ADB_SCENARIO_ID="$(printf "%s" "$ADB_SCENARIO_ID" | tr '[:lower:]' '[:upper:]')"
    adb_scenario_exists "$ADB_SCENARIO_ID" || die "Invalid ADB scenario id: $ADB_SCENARIO_ID"
  fi
  validate_tempfile_size "$TEMPFILE_SIZE" || die "Invalid tempfile size: $TEMPFILE_SIZE"
  LOCAL_ONLY="$(normalize_bool "$LOCAL_ONLY")" || die "Invalid local-only value: $LOCAL_ONLY"
  REPORT_DEEP_VALIDATE="$(normalize_bool "$REPORT_DEEP_VALIDATE")" || die "Invalid report deep-validate value: $REPORT_DEEP_VALIDATE"
  AUDIT_RETAIN="$(normalize_bool "$AUDIT_RETAIN")" || die "Invalid audit retain value: $AUDIT_RETAIN"
  local raw_auto_scorecard="$AUTO_SCORECARD"
  AUTO_SCORECARD="$(normalize_bool "$raw_auto_scorecard")" || die "Invalid auto scorecard value: $raw_auto_scorecard"
  local raw_topology_cache_disabled="$TOPOLOGY_CACHE_DISABLED"
  TOPOLOGY_CACHE_DISABLED="$(normalize_bool "$raw_topology_cache_disabled")" ||
    die "Invalid topology cache disabled value: $raw_topology_cache_disabled"
  [[ "$TOPOLOGY_CACHE_TTL_SECONDS" =~ ^[0-9]+$ ]] ||
    die "Invalid topology cache TTL seconds: $TOPOLOGY_CACHE_TTL_SECONDS"
  AUDIT_STREAM_CAPTURE="$(normalize_auto_bool "$AUDIT_STREAM_CAPTURE")" ||
    die "Invalid audit stream capture value: $AUDIT_STREAM_CAPTURE"
  [[ "$AUDIT_RETENTION_DAYS" =~ ^[0-9]+$ ]] || die "Invalid audit retention days: $AUDIT_RETENTION_DAYS"
  [[ "$FRA_PRESSURE_TARGET_PCT" =~ ^[0-9]+$ && "$FRA_PRESSURE_TARGET_PCT" -ge 50 && "$FRA_PRESSURE_TARGET_PCT" -le 100 ]] ||
    die "Invalid FRA pressure target percentage: $FRA_PRESSURE_TARGET_PCT"
  [[ "$FRA_PRESSURE_HEADROOM_MB" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid FRA pressure headroom MB: $FRA_PRESSURE_HEADROOM_MB"
  [[ "$TEMP_EXHAUST_MB" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid TEMP exhaust MB: $TEMP_EXHAUST_MB"
  [[ "$APEX_SESSION_DURATION" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid APEX session duration seconds: $APEX_SESSION_DURATION"
  [[ "$APEX_SESSION_INTERVAL" =~ ^[1-9][0-9]*$ ]] ||
    die "Invalid APEX session interval seconds: $APEX_SESSION_INTERVAL"
  APEX_SESSION_HEADLESS="$(normalize_bool "$APEX_SESSION_HEADLESS")" ||
    die "Invalid APEX session headless value: $APEX_SESSION_HEADLESS"
  # NOTE: never echo these two values back - a common mistake is pasting the
  # literal password into the *_ENV field, and the "invalid" value would then
  # leak into terminals and logs.
  [[ "$ADB_PASSWORD_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] ||
    die "Invalid CRASHSIM_ADB_PASSWORD_ENV (value hidden: it may be a pasted secret). It must be the NAME of an environment variable, e.g. CRASHSIM_ADB_PASSWORD; export the actual password in that variable instead."
  [[ "$ADB_WALLET_PASSWORD_ENV" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] ||
    die "Invalid CRASHSIM_ADB_WALLET_PASSWORD_ENV (value hidden: it may be a pasted secret). It must be the NAME of an environment variable, e.g. CRASHSIM_ADB_WALLET_PASSWORD; export the actual wallet password in that variable instead."
  case "$(printf "%s" "$ADB_SERVICE_LEVEL" | tr '[:upper:]' '[:lower:]')" in
    low|medium|high|tp|tpurgent) ;;
    *) die "Invalid ADB service level: $ADB_SERVICE_LEVEL" ;;
  esac
  case "$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')" in
    tls|mtls) ;;
    *) die "Invalid ADB TLS mode: $ADB_TLS_MODE" ;;
  esac
  if [[ -n "$MAX_TARGETS" && ! "$MAX_TARGETS" =~ ^[1-9][0-9]*$ ]]; then
    die "Invalid max targets value: $MAX_TARGETS"
  fi
}

audit_effective_dir() {
  if [[ -z "$AUDIT_DIR" ]]; then
    AUDIT_DIR="${LOG_DIR}/audit"
  fi
}

audit_stream_capture_enabled() {
  case "$AUDIT_STREAM_CAPTURE" in
    1) return "$SUCCESS" ;;
    0) return "$FAIL" ;;
    auto)
      if [[ "$MODE" == "menu" && -t 1 ]]; then
        return "$FAIL"
      fi
      return "$SUCCESS"
      ;;
  esac
  return "$FAIL"
}

audit_redact_stream() {
  # -u: line-buffered. Without it GNU sed block-buffers ~4KB when its stdout is
  # a pipe (to tee), which leaves interactive confirmation prompts stuck in the
  # buffer while `read` blocks - the operator sees a hang at the safety gate.
  sed -u -E \
    -e 's#(connect catalog[[:space:]]+[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's#(CRASHSIM_RMAN_CATALOG=[^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#g' \
    -e 's#(CRASHSIM_SYS_PASSWORD=)[^[:space:]]+#\1<redacted>#g' \
    -e 's#(([A-Za-z0-9_.-]*[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd][A-Za-z0-9_.-]*|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd])[[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g' \
    -e 's#(([A-Za-z0-9_.-]*[Tt][Oo][Kk][Ee][Nn][A-Za-z0-9_.-]*|[Tt][Oo][Kk][Ee][Nn])[[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g' \
    -e 's#(([A-Za-z0-9_.-]*[Ss][Ee][Cc][Rr][Ee][Tt][A-Za-z0-9_.-]*|[Ss][Ee][Cc][Rr][Ee][Tt])[[:space:]_-]{0,20}[=:][[:space:]]*)[^[:space:]]+#\1<redacted>#g'
}

audit_print_redacted_command() {
  local arg redact_next=0

  printf "%q" "$0"
  for arg in "${ORIGINAL_ARGS[@]}"; do
    if [[ "$redact_next" -eq 1 ]]; then
      printf " %q" "<redacted>"
      redact_next=0
      continue
    fi

    case "$arg" in
      --sys-password|--rman-catalog|--apex-session-password)
        printf " %q" "$arg"
        redact_next=1
        ;;
      --sys-password=*|--rman-catalog=*|--apex-session-password=*)
        printf " %q" "${arg%%=*}=<redacted>"
        ;;
      *)
        printf " %q" "$arg"
        ;;
    esac
  done
  printf "\n"
}

audit_write_redacted_environment() {
  local env_file="$1"

  env | sort | awk -F= '
    {
      key=$1
      value=$0
      sub(/^[^=]*=/, "", value)
      upper=toupper(key)
      if (upper ~ /(PASS|PASSWORD|TOKEN|SECRET|CREDENTIAL|AUTH|PRIVATE.*KEY|ACCESS.*KEY)/ || key == "CRASHSIM_RMAN_CATALOG") {
        print key "=<redacted>"
      } else {
        print key "=" value
      }
    }
  ' >"$env_file" || warn "Unable to write redacted audit environment: $env_file"
}

audit_start() {
  local day_dir metadata_file command_file env_file

  [[ "$AUDIT_RETAIN" -eq 1 ]] || return "$SUCCESS"
  audit_effective_dir
  mkdir -p "$AUDIT_DIR" || die "Unable to create audit directory: $AUDIT_DIR"

  day_dir="${AUDIT_DIR}/$(date -u +%Y-%m-%d)"
  AUDIT_RUN_DIR="${day_dir}/crashsim_audit_${RUN_ID}_$$"
  mkdir -p "$AUDIT_RUN_DIR" || die "Unable to create audit run directory: $AUDIT_RUN_DIR"

  AUDIT_MARKER_FILE="${AUDIT_RUN_DIR}/start.marker"
  AUDIT_STDOUT_FILE="${AUDIT_RUN_DIR}/stdout.log"
  AUDIT_STDERR_FILE="${AUDIT_RUN_DIR}/stderr.log"
  metadata_file="${AUDIT_RUN_DIR}/metadata.env"
  command_file="${AUDIT_RUN_DIR}/command.redacted"
  env_file="${AUDIT_RUN_DIR}/environment.redacted"

  touch "$AUDIT_MARKER_FILE" "$AUDIT_STDOUT_FILE" "$AUDIT_STDERR_FILE" ||
    die "Unable to initialize audit files under: $AUDIT_RUN_DIR"

  {
    printf "version=%q\n" "$VERSION"
    printf "run_id=%q\n" "$RUN_ID"
    printf "started_at_utc=%q\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "program=%q\n" "$PROGRAM"
    printf "mode=%q\n" "$MODE"
    printf "execute=%q\n" "$EXECUTE"
    printf "assume_yes=%q\n" "$ASSUME_YES"
    printf "cwd=%q\n" "$(pwd)"
    printf "os_user=%q\n" "$(id -un 2>/dev/null || printf unknown)"
    printf "host=%q\n" "$(hostname 2>/dev/null || printf unknown)"
    printf "pid=%q\n" "$$"
    printf "log_dir=%q\n" "$LOG_DIR"
    printf "audit_dir=%q\n" "$AUDIT_DIR"
    printf "audit_retention_days=%q\n" "$AUDIT_RETENTION_DAYS"
  } >"$metadata_file" || die "Unable to write audit metadata: $metadata_file"

  audit_print_redacted_command >"$command_file" ||
    die "Unable to write redacted audit command: $command_file"
  audit_write_redacted_environment "$env_file"

  AUDIT_STARTED=1
  if ! audit_stream_capture_enabled; then
    {
      echo "Live stdout/stderr capture was disabled for this run."
      echo "Reason: interactive guided menu terminal sessions use direct terminal I/O to avoid startup deadlocks."
      echo "Generated CrashSimulator artifacts are still collected under this audit run at finalization."
    } >"$AUDIT_STDOUT_FILE"
    echo "Audit logging enabled: ${AUDIT_RUN_DIR}"
    echo "Audit stream capture: disabled for interactive guided menu; generated artifacts will still be retained."
    return "$SUCCESS"
  fi

  exec > >(audit_redact_stream | tee -a "$AUDIT_STDOUT_FILE") \
    2> >(audit_redact_stream | tee -a "$AUDIT_STDERR_FILE" >&2)

  echo "Audit logging enabled: ${AUDIT_RUN_DIR}"
}

audit_copy_artifact() {
  local source_file="$1"
  local artifact_dir="$2"
  local dest_file redacted

  dest_file="${artifact_dir}/$(basename "$source_file")"
  redacted="no"
  case "$source_file" in
    *.evidence|*.log|*.manifest|*.md|*.out|*.rman|*.sql|*.txt)
      audit_redact_stream <"$source_file" >"$dest_file" ||
        return "$FAIL"
      redacted="yes"
      ;;
    *)
      cp -p -- "$source_file" "$dest_file" ||
        return "$FAIL"
      ;;
  esac

  printf "%s|%s|redacted=%s\n" "$source_file" "$dest_file" "$redacted"
}

audit_collect_artifacts() {
  local artifact_dir index_file found=0 file

  [[ "$AUDIT_STARTED" -eq 1 && -n "$AUDIT_RUN_DIR" ]] || return "$SUCCESS"
  [[ -n "$LOG_DIR" && -d "$LOG_DIR" && -f "$AUDIT_MARKER_FILE" ]] || return "$SUCCESS"

  artifact_dir="${AUDIT_RUN_DIR}/artifacts"
  index_file="${AUDIT_RUN_DIR}/artifacts.index"
  mkdir -p "$artifact_dir" || {
    warn "Unable to create audit artifact directory: $artifact_dir"
    return "$FAIL"
  }
  : >"$index_file" || {
    warn "Unable to write audit artifact index: $index_file"
    return "$FAIL"
  }

  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    case "$file" in
      "$AUDIT_RUN_DIR"/*) continue ;;
    esac
    if audit_copy_artifact "$file" "$artifact_dir" >>"$index_file"; then
      found=1
    else
      printf "%s|copy_failed\n" "$file" >>"$index_file"
    fi
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -newer "$AUDIT_MARKER_FILE" 2>/dev/null | sort)

  if [[ "$found" -eq 0 ]]; then
    printf "No generated log artifacts were detected for this run.\n" >"$index_file"
  fi
}

audit_finalize() {
  local status="$1"
  local metadata_file

  [[ "$AUDIT_STARTED" -eq 1 && "$AUDIT_FINALIZED" -eq 0 ]] || return "$SUCCESS"
  AUDIT_FINALIZED=1

  audit_collect_artifacts || true
  metadata_file="${AUDIT_RUN_DIR}/metadata.env"
  {
    printf "ended_at_utc=%q\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "exit_status=%q\n" "$status"
  } >>"$metadata_file" || true
  printf "%s\n" "$status" >"${AUDIT_RUN_DIR}/exit_status" || true
  echo "Audit record finalized: ${AUDIT_RUN_DIR}"
}

audit_status() {
  local candidate_count run_count usage

  audit_effective_dir
  echo "CrashSimulator audit status"
  echo "Audit retain: $([[ "$AUDIT_RETAIN" -eq 1 ]] && echo enabled || echo disabled)"
  echo "Audit directory: ${AUDIT_DIR}"
  echo "Retention days: ${AUDIT_RETENTION_DAYS}"

  if [[ ! -d "$AUDIT_DIR" ]]; then
    echo "Audit directory does not exist yet."
    return "$SUCCESS"
  fi

  run_count="$(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' 2>/dev/null | wc -l | tr -d ' ')"
  candidate_count="$(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' -mtime +"$AUDIT_RETENTION_DAYS" 2>/dev/null | wc -l | tr -d ' ')"
  usage="$(du -sh "$AUDIT_DIR" 2>/dev/null | awk '{print $1}')"
  echo "Audit run folders: ${run_count:-0}"
  echo "Purge candidates: ${candidate_count:-0}"
  echo "Disk usage: ${usage:-unknown}"
}

confirm_audit_purge() {
  if [[ "$EXECUTE" -eq 0 || "$ASSUME_YES" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  confirm_show "" \
    "About to purge CrashSimulator audit run folders older than ${AUDIT_RETENTION_DAYS} days." \
    "Audit directory: ${AUDIT_DIR}" \
    "Type PURGE-AUDIT-LOGS to continue:"
  local answer
  confirm_reply answer
  [[ "$answer" == "PURGE-AUDIT-LOGS" ]] || die "Confirmation did not match. Aborting."
}

purge_audit_logs() {
  local -a purge_dirs=()
  local dir count=0

  audit_effective_dir
  echo "CrashSimulator audit purge"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Audit directory: ${AUDIT_DIR}"
  echo "Retention days: ${AUDIT_RETENTION_DAYS}"

  if [[ ! -d "$AUDIT_DIR" ]]; then
    echo "Audit directory does not exist. Nothing to purge."
    return "$SUCCESS"
  fi

  mapfile -t purge_dirs < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' -mtime +"$AUDIT_RETENTION_DAYS" 2>/dev/null | sort)
  if [[ "${#purge_dirs[@]}" -eq 0 ]]; then
    echo "No audit run folders are older than the retention policy."
    return "$SUCCESS"
  fi

  echo
  echo "Audit run folders selected for purge:"
  for dir in "${purge_dirs[@]}"; do
    [[ -n "$AUDIT_RUN_DIR" && "$dir" == "$AUDIT_RUN_DIR" ]] && continue
    echo "  ${dir}"
    count=$((count + 1))
  done

  if [[ "$count" -eq 0 ]]; then
    echo "Only the current audit run matched the age filter; it will not be purged."
    return "$SUCCESS"
  fi

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo
    echo "DRY-RUN: no audit folders were removed. Re-run with --execute to purge."
    return "$SUCCESS"
  fi

  confirm_audit_purge
  for dir in "${purge_dirs[@]}"; do
    [[ -n "$AUDIT_RUN_DIR" && "$dir" == "$AUDIT_RUN_DIR" ]] && continue
    rm -rf -- "$dir" || die "Unable to remove audit folder: $dir"
  done
  find "$AUDIT_DIR" -mindepth 1 -maxdepth 1 -type d -empty -delete 2>/dev/null || true
  echo "Purged ${count} audit run folder(s)."
}

init_runtime() {
  if [[ -z "$LOG_DIR" ]]; then
    LOG_DIR="$(pwd)/crashsimulator_logs"
  fi
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  audit_effective_dir
  WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/crashsimulator.${RUN_ID}.XXXXXX")" ||
    die "Unable to create temporary directory"
  trap cleanup EXIT
}

cleanup() {
  local status=$?
  audit_finalize "$status" || true
  if [[ -n "${WORK_DIR:-}" && -d "$WORK_DIR" ]]; then
    rm -rf "$WORK_DIR"
  fi
}

find_sqlplus_if_available() {
  if [[ -n "$SQLPLUS_BIN" && -x "$SQLPLUS_BIN" ]]; then
    return "$SUCCESS"
  fi
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/sqlplus" ]]; then
    SQLPLUS_BIN="${ORACLE_HOME}/bin/sqlplus"
    return "$SUCCESS"
  fi
  SQLPLUS_BIN="$(command -v sqlplus 2>/dev/null || true)"
  if [[ -n "$SQLPLUS_BIN" && -x "$SQLPLUS_BIN" ]]; then
    return "$SUCCESS"
  fi
  return "$FAIL"
}

ensure_sqlplus() {
  if find_sqlplus_if_available; then
    return "$SUCCESS"
  fi
  die "sqlplus was not found. Set ORACLE_HOME or SQLPLUS."
}

ensure_rman() {
  if [[ -n "$RMAN_BIN" && -x "$RMAN_BIN" ]]; then
    return "$SUCCESS"
  fi
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/rman" ]]; then
    RMAN_BIN="${ORACLE_HOME}/bin/rman"
    return "$SUCCESS"
  fi
  RMAN_BIN="$(command -v rman 2>/dev/null || true)"
  if [[ -n "$RMAN_BIN" && -x "$RMAN_BIN" ]]; then
    return "$SUCCESS"
  fi
  die "rman was not found. Set ORACLE_HOME or RMAN."
}

find_dgmgrl_bin() {
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/dgmgrl" ]]; then
    printf "%s" "${ORACLE_HOME}/bin/dgmgrl"
    return "$SUCCESS"
  fi
  command -v dgmgrl 2>/dev/null || true
}

ensure_orapwd() {
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/orapwd" ]]; then
    printf "%s\n" "${ORACLE_HOME}/bin/orapwd"
    return "$SUCCESS"
  fi
  local orapwd_bin
  orapwd_bin="$(command -v orapwd 2>/dev/null || true)"
  [[ -n "$orapwd_bin" && -x "$orapwd_bin" ]] || die "orapwd was not found. Set ORACLE_HOME or PATH."
  printf "%s\n" "$orapwd_bin"
}

ensure_os_user() {
  if [[ "$ORACLE_USER_REQUIRED" -eq 1 && "$(id -un)" != "oracle" ]]; then
    die "This run requires OS user oracle. Current user: $(id -un)"
  fi
}

sql_query() {
  local output_file="$1"
  shift
  local sql_text="$*"
  ensure_sqlplus
  debug "SQL output: $output_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" >"$output_file" <<SQL
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off termout off
set linesize 32767 trimspool on trimout on tab off
${sql_text}
exit
SQL
}

load_rows() {
  local file="$1"
  TARGET_ROWS=()
  if [[ ! -f "$file" ]]; then
    return "$FAIL"
  fi
  mapfile -t TARGET_ROWS < <(trim_blank_lines <"$file" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  local row
  for row in "${TARGET_ROWS[@]}"; do
    case "$row" in
      SP2-*|ORA-*|PLS-*)
        die "SQL*Plus returned an error while selecting scenario targets: $row"
        ;;
    esac
  done
  return "$SUCCESS"
}

run_sql_action() {
  local title="$1"
  local sql_text="$2"
  local output_file="$WORK_DIR/action.$(printf "%s" "$title" | tr -cd '[:alnum:]_').out"

  if [[ "$EXECUTE" -eq 0 ]]; then
    info "DRY-RUN SQL: $title"
    printf "%s\n" "$sql_text"
    return "$SUCCESS"
  fi

  sql_query "$output_file" "$sql_text"
}

manifest_append() {
  local key="$1"
  local value="$2"
  [[ -n "$MANIFEST_FILE" ]] || return "$SUCCESS"
  printf "%s=%s\n" "$key" "$value" >>"$MANIFEST_FILE"
}

manifest_get() {
  local key="$1"
  [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]] || return "$FAIL"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$MANIFEST_FILE"
}

require_manifest() {
  [[ -n "$MANIFEST_FILE" ]] || die "Recovery requires --manifest <file> for this scenario."
  [[ -f "$MANIFEST_FILE" ]] || die "Manifest file not found: $MANIFEST_FILE"
}

manifest_get_required() {
  local key="$1"
  local value
  value="$(manifest_get "$key" || true)"
  [[ -n "$value" ]] || die "Manifest is missing required key: $key"
  printf "%s\n" "$value"
}

manifest_first_value() {
  local key value
  for key in "$@"; do
    value="$(manifest_get "$key" || true)"
    if [[ -n "$value" ]]; then
      printf "%s\n" "$value"
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

manifest_rename_paths() {
  local original backup
  original="$(manifest_first_value "rename_1_original" "action_1_target" || true)"
  backup="$(manifest_get "rename_1_backup" || true)"
  [[ -n "$original" ]] || return "$FAIL"
  [[ -n "$backup" ]] || return "$FAIL"
  printf "%s|%s\n" "$original" "$backup"
}

load_manifest_restore_pairs() {
  RESTORE_ORIGINALS=()
  RESTORE_BACKUPS=()
  RESTORE_METHODS=()

  local idx original backup method
  idx=1
  while true; do
    original="$(manifest_get "rename_${idx}_original" || true)"
    backup="$(manifest_get "rename_${idx}_backup" || true)"
    method="$(manifest_get "rename_${idx}_method" || true)"
    if [[ -z "$original" && -z "$backup" ]]; then
      break
    fi
    [[ -n "$original" && -n "$backup" ]] ||
      die "Manifest has an incomplete restore pair for rename_${idx}."
    RESTORE_ORIGINALS+=("$original")
    RESTORE_BACKUPS+=("$backup")
    RESTORE_METHODS+=("${method:-rename}")
    idx=$((idx + 1))
  done

  [[ "${#RESTORE_ORIGINALS[@]}" -gt 0 ]] || return "$FAIL"
}

copy_restore_pairs_to_originals() {
  local idx original backup
  for idx in "${!RESTORE_ORIGINALS[@]}"; do
    original="${RESTORE_ORIGINALS[$idx]}"
    backup="${RESTORE_BACKUPS[$idx]}"
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would copy $backup back to $original"
    else
      [[ -f "$backup" ]] || die "Scenario backup not found: $backup"
      echo "cp -p -- $backup $original"
      cp -p -- "$backup" "$original" || die "Unable to restore $original from $backup"
    fi
  done
}

move_restore_pairs_to_originals() {
  local idx original backup method
  for idx in "${!RESTORE_ORIGINALS[@]}"; do
    original="${RESTORE_ORIGINALS[$idx]}"
    backup="${RESTORE_BACKUPS[$idx]}"
    method="${RESTORE_METHODS[$idx]:-rename}"
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would move $backup back to $original"
    else
      [[ -e "$backup" ]] || die "Scenario backup not found: $backup"
      if [[ -e "$original" ]]; then
        warn "Original path already exists while restoring ${original}; leaving backup in place: ${backup}"
        continue
      fi
      if [[ "$method" == "ords_priv_config_rename" ]]; then
        run_ords_priv_helper config-restore "$backup" "$original" ||
          die "Unable to restore ORDS config with approved helper: $backup -> $original"
      else
        echo "mv -- $backup $original"
        mv -- "$backup" "$original" || die "Unable to restore $original from $backup"
      fi
    fi
  done
}

safe_remove_restore_backups() {
  local backup
  for backup in "${RESTORE_BACKUPS[@]}"; do
    safe_remove_after_validation "$backup"
  done
}

init_manifest() {
  local mode_name="$1"
  local id="$2"

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    MANIFEST_FILE="${LOG_DIR}/crashsim_${mode_name}_s${id}_${RUN_ID}.manifest"
  fi

  : >"$MANIFEST_FILE" || die "Unable to write manifest: $MANIFEST_FILE"
  manifest_append "version" "$VERSION"
  manifest_append "run_id" "$RUN_ID"
  manifest_append "mode" "$mode_name"
  manifest_append "scenario_id" "$id"
  manifest_append "scenario_title" "${SCENARIO_TITLE[$id]:-unknown}"
  manifest_append "started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "db_name" "${DB_NAME:-unknown}"
  manifest_append "db_unique_name" "${DB_UNIQUE_NAME:-unknown}"
  manifest_append "db_role" "${DB_ROLE:-unknown}"
  manifest_append "db_cdb" "${DB_CDB:-unknown}"
  manifest_append "cluster_type" "${CLUSTER_TYPE:-unknown}"
  manifest_append "gi_managed" "${GI_MANAGED:-0}"
  manifest_append "storage_type" "${STORAGE_TYPE:-unknown}"
  manifest_append "target_pdb" "${TARGET_PDB:-}"
  manifest_append "target_schema" "${TARGET_SCHEMA:-}"
}

datafile_metadata_for_path() {
  local path="$1"
  local file="$WORK_DIR/datafile_metadata.$(printf "%s" "$path" | cksum | awk '{print $1}').lst"
  local path_literal
  path_literal="$(sql_quote "$path")"

  if [[ "$DB_CDB" == "YES" ]]; then
    sql_query "$file" "
select c.name || '|' ||
       vf.con_id || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$datafile vf
join v\$containers c
  on c.con_id = vf.con_id
left join v\$tablespace ts
  on ts.con_id = vf.con_id
 and ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  else
    sql_query "$file" "
select 'NONCDB' || '|' ||
       0 || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$datafile vf
left join v\$tablespace ts
  on ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  fi

  local line pdb_name con_id file_no tablespace datafile_name
  line="$(trim_blank_lines <"$file" | head -n 1)"
  IFS='|' read -r pdb_name con_id file_no tablespace datafile_name <<<"$line"
  [[ -n "$datafile_name" && "$file_no" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$line"
}

tempfile_metadata_for_path() {
  local path="$1"
  local file="$WORK_DIR/tempfile_metadata.$(printf "%s" "$path" | cksum | awk '{print $1}').lst"
  local path_literal
  path_literal="$(sql_quote "$path")"

  if [[ "$DB_CDB" == "YES" ]]; then
    sql_query "$file" "
select c.name || '|' ||
       vf.con_id || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$tempfile vf
join v\$containers c
  on c.con_id = vf.con_id
left join v\$tablespace ts
  on ts.con_id = vf.con_id
 and ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  else
    sql_query "$file" "
select 'NONCDB' || '|' ||
       0 || '|' ||
       vf.file# || '|' ||
       ts.name || '|' ||
       vf.name
from v\$tempfile vf
left join v\$tablespace ts
  on ts.ts# = vf.ts#
where vf.name = ${path_literal};
"
  fi

  local line pdb_name con_id file_no tablespace tempfile_name
  line="$(trim_blank_lines <"$file" | head -n 1)"
  IFS='|' read -r pdb_name con_id file_no tablespace tempfile_name <<<"$line"
  [[ -n "$tempfile_name" && "$file_no" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$line"
}

redo_metadata_for_path() {
  local path="$1"
  local file="$WORK_DIR/redo_metadata.$(printf "%s" "$path" | cksum | awk '{print $1}').lst"
  local path_literal
  path_literal="$(sql_quote "$path")"

  sql_query "$file" "
select lf.group# || '|' ||
       l.thread# || '|' ||
       l.status || '|' ||
       l.archived || '|' ||
       lf.type || '|' ||
       lf.member
from v\$logfile lf
join v\$log l
  on l.group# = lf.group#
where lf.member = ${path_literal};
"

  local line group_no thread_no status archived member_type member
  line="$(trim_blank_lines <"$file" | head -n 1)"
  IFS='|' read -r group_no thread_no status archived member_type member <<<"$line"
  [[ -n "$member" && "$group_no" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$line"
}

reset_plan_targets() {
  PLAN_TARGET_PATHS=()
  PLAN_TARGET_PDBS=()
  PLAN_TARGET_CON_IDS=()
  PLAN_TARGET_FILE_NOS=()
  PLAN_TARGET_TABLESPACES=()
}

record_action_targets() {
  [[ -n "$MANIFEST_FILE" ]] || return "$SUCCESS"

  local idx action_no kind target detail metadata tempfile_metadata pdb_name con_id file_no tablespace path
  local redo_metadata group_no thread_no status archived member_type member
  manifest_append "planned_action_count" "${#ACTION_KINDS[@]}"
  action_no=1
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    detail="${ACTION_DETAILS[$idx]}"
    manifest_append "action_${action_no}_kind" "$kind"
    manifest_append "action_${action_no}_target" "$target"
    manifest_append "action_${action_no}_detail" "$detail"

    if [[ "$kind" == "fs_rename" || "$kind" == fs_corrupt_* || "$kind" == asm_* || "$kind" == "external" ]]; then
      metadata="$(datafile_metadata_for_path "$target" || true)"
      if [[ -n "$metadata" ]]; then
        IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$metadata"
        manifest_append "action_${action_no}_pdb_name" "$pdb_name"
        manifest_append "action_${action_no}_con_id" "$con_id"
        manifest_append "action_${action_no}_file_no" "$file_no"
        manifest_append "action_${action_no}_tablespace" "$tablespace"
        manifest_append "action_${action_no}_datafile" "$path"
      fi

      tempfile_metadata="$(tempfile_metadata_for_path "$target" || true)"
      if [[ -n "$tempfile_metadata" ]]; then
        IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$tempfile_metadata"
        manifest_append "action_${action_no}_pdb_name" "$pdb_name"
        manifest_append "action_${action_no}_con_id" "$con_id"
        manifest_append "action_${action_no}_file_no" "$file_no"
        manifest_append "action_${action_no}_tablespace" "$tablespace"
        manifest_append "action_${action_no}_tempfile" "$path"
      fi

      redo_metadata="$(redo_metadata_for_path "$target" || true)"
      if [[ -n "$redo_metadata" ]]; then
        IFS='|' read -r group_no thread_no status archived member_type member <<<"$redo_metadata"
        manifest_append "action_${action_no}_redo_group" "$group_no"
        manifest_append "action_${action_no}_redo_thread" "$thread_no"
        manifest_append "action_${action_no}_redo_status" "$status"
        manifest_append "action_${action_no}_redo_archived" "$archived"
        manifest_append "action_${action_no}_redo_type" "$member_type"
        manifest_append "action_${action_no}_redo_member" "$member"
      fi
    fi
    if [[ "$kind" == "sqlfile" ]]; then
      manifest_append "action_${action_no}_sqlfile" "$target"
      manifest_append "action_${action_no}_sqllog" "$detail"
    fi
    if [[ "$kind" == "report" ]]; then
      manifest_append "action_${action_no}_report_type" "$target"
      manifest_append "action_${action_no}_report_detail" "$detail"
    fi

    action_no=$((action_no + 1))
  done
}

# srvctl ships inside EVERY database home, so a runnable srvctl proves nothing
# about Grid Infrastructure / Oracle Restart being installed (misreading it
# classified plain single-instance labs as GI_SINGLE and the seed planner then
# attempted srvctl service creation that can never work there). Only the OLR
# registration laid down by root.sh, or a live HAS stack, count as evidence.
topology_grid_stack_present() {
  [[ -f /etc/oracle/olr.loc || -f /var/opt/oracle/olr.loc ]] && return "$SUCCESS"
  if grid_tool_available crsctl; then
    run_grid_tool crsctl check has 2>/dev/null | grep -qi "online" && return "$SUCCESS"
  fi
  return "$FAIL"
}

collect_datafile_plan() {
  reset_plan_targets

  local idx kind target metadata pdb_name con_id file_no tablespace path target_no
  target_no=1
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    case "$kind" in
      fs_rename|fs_corrupt_header|asm_rm|asm_corrupt_header|external)
        ;;
      *)
        continue
        ;;
    esac

    metadata="$(datafile_metadata_for_path "$target" || true)"
    if [[ -z "$metadata" ]]; then
      warn "Skipping non-datafile target for RMAN protection: $target"
      continue
    fi

    IFS='|' read -r pdb_name con_id file_no tablespace path <<<"$metadata"
    PLAN_TARGET_PATHS+=("$path")
    PLAN_TARGET_PDBS+=("$pdb_name")
    PLAN_TARGET_CON_IDS+=("$con_id")
    PLAN_TARGET_FILE_NOS+=("$file_no")
    PLAN_TARGET_TABLESPACES+=("$tablespace")

    manifest_append "target_${target_no}_path" "$path"
    manifest_append "target_${target_no}_pdb_name" "$pdb_name"
    manifest_append "target_${target_no}_con_id" "$con_id"
    manifest_append "target_${target_no}_file_no" "$file_no"
    manifest_append "target_${target_no}_tablespace" "$tablespace"
    target_no=$((target_no + 1))
  done

  manifest_append "target_count" "${#PLAN_TARGET_FILE_NOS[@]}"
  [[ "${#PLAN_TARGET_FILE_NOS[@]}" -gt 0 ]] || die "No datafile targets were found for RMAN protection/recovery."
}

join_csv() {
  local IFS=,
  printf "%s" "$*"
}

rman_tag() {
  local id="$1"
  printf "CSIM%s_%s" "$id" "$RUN_ID"
}

run_sql_script_file() {
  local script_file="$1"
  local log_file="$2"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "SQL*Plus script: $script_file"
    sed 's/^/  /' "$script_file"
    return "$SUCCESS"
  fi

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$script_file" >"$log_file" </dev/null ||
    die "SQL*Plus script failed: $script_file (log: $log_file)"
}

run_rman_cmdfile() {
  local cmd_file="$1"
  local log_file="$2"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "RMAN command file: $cmd_file"
    sed 's/^/  /' "$cmd_file"
    return "$SUCCESS"
  fi

  ensure_rman
  "$RMAN_BIN" target / cmdfile="$cmd_file" log="$log_file" ||
    die "RMAN command file failed: $cmd_file (log: $log_file)"
}

safe_remove_after_validation() {
  local path="$1"
  [[ -n "$path" ]] || return "$SUCCESS"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would remove validated scenario backup $path"
    return "$SUCCESS"
  fi
  [[ -e "$path" ]] || return "$SUCCESS"
  echo "rm -f -- $path"
  rm -f -- "$path" || die "Unable to remove validated scenario backup: $path"
}

write_open_pdbs_sql_file() {
  local sql_file="$1"
  cat >"$sql_file" <<'SQL' || die "Unable to write PDB open SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
declare
  l_cdb v$database.cdb%type;
begin
  select cdb into l_cdb from v$database;

  if l_cdb = 'YES' then
    for r in (
      select name, open_mode
      from v$pdbs
      where name <> 'PDB$SEED'
      order by con_id
    ) loop
      if r.open_mode not in ('READ WRITE', 'READ ONLY', 'READ ONLY WITH APPLY') then
        execute immediate 'alter pluggable database ' || dbms_assert.simple_sql_name(r.name) || ' open';
      else
        dbms_output.put_line('PDB ' || r.name || ' already open: ' || r.open_mode);
      end if;
    end loop;
  end if;
end;
/
exit
SQL
}

run_sql_text() {
  local title="$1"
  local sql_text="$2"
  local output_file="$3"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN SQL: $title"
    printf "%s\n" "$sql_text" | sed 's/^/  /'
    return "$SUCCESS"
  fi

  sql_query "$output_file" "$sql_text" ||
    die "SQL failed: $title (log: $output_file)"
}

query_instance_status() {
  local output_file="$1"
  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" >"$output_file" <<SQL
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off termout off
set linesize 32767 trimspool on trimout on tab off
select status from v\$instance;
exit
SQL
}

ensure_database_open() {
  local status_file="$WORK_DIR/instance_status.out"
  local open_file="$WORK_DIR/open_database.sql"
  local open_log="$LOG_DIR/crashsim_recover_open_database_${RUN_ID}.log"
  local status

  if [[ "$EXECUTE" -eq 0 ]]; then
    cat >"$open_file" <<'SQL' || die "Unable to write database-open SQL file: $open_file"
whenever sqlerror exit sql.sqlcode
-- Recovery will query V$INSTANCE and then STARTUP, ALTER DATABASE MOUNT,
-- or ALTER DATABASE OPEN only when the current state requires it.
exit
SQL
    echo "SQL*Plus script: $open_file"
    sed 's/^/  /' "$open_file"
    return "$SUCCESS"
  fi

  if ! query_instance_status "$status_file"; then
    cat >"$open_file" <<'SQL' || die "Unable to write database startup SQL file: $open_file"
whenever sqlerror exit sql.sqlcode
startup
exit
SQL
    run_sql_script_file "$open_file" "$open_log"
  else
    status="$(trim_blank_lines <"$status_file" | head -n 1 | tr -d ' ')"
    case "$status" in
      OPEN)
        ;;
      MOUNTED)
        run_sql_text "open mounted database" "alter database open;" "$open_log"
        ;;
      STARTED)
        run_sql_text "mount and open started database" "
alter database mount;
alter database open;
" "$open_log"
        ;;
      *)
        die "Unsupported instance status during recovery: ${status:-unknown}"
        ;;
    esac
  fi

  local pdb_sql="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.sql"
  local pdb_log="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.log"
  write_open_pdbs_sql_file "$pdb_sql"
  run_sql_script_file "$pdb_sql" "$pdb_log"
}

force_database_open() {
  local open_file="$WORK_DIR/startup_force_database.sql"
  local open_log="$LOG_DIR/crashsim_recover_startup_force_${RUN_ID}.log"

  cat >"$open_file" <<'SQL' || die "Unable to write startup-force SQL file: $open_file"
whenever sqlerror exit sql.sqlcode
startup force
exit
SQL
  run_sql_script_file "$open_file" "$open_log"

  local pdb_sql="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.sql"
  local pdb_log="$LOG_DIR/crashsim_recover_open_pdbs_${RUN_ID}.log"
  write_open_pdbs_sql_file "$pdb_sql"
  run_sql_script_file "$pdb_sql" "$pdb_log"
}

write_tempfile_recovery_sql_file() {
  local container_name="$1"
  local original_path="$2"
  local sql_file="$3"
  local container_sql=""
  local original_literal

  original_literal="$(sql_quote "$original_path")"
  if [[ -n "$container_name" && "$container_name" != "CDB\$ROOT" && "$container_name" != "ROOT" && "$container_name" != "NONCDB" ]]; then
    container_sql="alter session set container = $(sql_identifier "$container_name");"
  fi

  cat >"$sql_file" <<SQL || die "Unable to write tempfile recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
${container_sql}
declare
  l_tempfile_count number := 0;
  l_temp_tbs database_properties.property_value%type;
  l_omf_dest varchar2(4000);
begin
  select property_value
    into l_temp_tbs
    from database_properties
   where property_name = 'DEFAULT_TEMP_TABLESPACE';

  select value
    into l_omf_dest
    from v\$parameter
   where name = 'db_create_file_dest';

  select count(*)
    into l_tempfile_count
    from v\$tempfile
   where con_id = to_number(sys_context('USERENV', 'CON_ID'));

  dbms_output.put_line('Default temporary tablespace: ' || l_temp_tbs);
  dbms_output.put_line('Current tempfile count before metadata repair: ' || l_tempfile_count);

  begin
    dbms_output.put_line('Dropping missing tempfile metadata for ${original_path}');
    execute immediate 'alter database tempfile ' || chr(39) || ${original_literal} || chr(39) || ' drop including datafiles';
  exception
    when others then
      if sqlcode = -1516 then
        dbms_output.put_line('Original tempfile is not in metadata; an OMF replacement may already exist.');
      else
        raise;
      end if;
  end;

  select count(*)
    into l_tempfile_count
    from v\$tempfile
   where con_id = to_number(sys_context('USERENV', 'CON_ID'));

  dbms_output.put_line('Current tempfile count after metadata repair: ' || l_tempfile_count);

  if l_tempfile_count <= 0 then
    dbms_output.put_line('Adding replacement tempfile to ' || l_temp_tbs);
    -- ADD TEMPFILE without a file name is OMF-only (ORA-02236 otherwise):
    -- reuse the original path, freed by the scenario rename, when
    -- db_create_file_dest is not configured.
    if l_omf_dest is not null then
      execute immediate 'alter tablespace ' || dbms_assert.simple_sql_name(l_temp_tbs) ||
        ' add tempfile size ${TEMPFILE_SIZE} autoextend on next 10m maxsize unlimited';
    else
      execute immediate 'alter tablespace ' || dbms_assert.simple_sql_name(l_temp_tbs) ||
        ' add tempfile ' || chr(39) || ${original_literal} || chr(39) ||
        ' size ${TEMPFILE_SIZE} reuse autoextend on next 10m maxsize unlimited';
    end if;
  end if;

  select count(*)
    into l_tempfile_count
    from v\$tempfile
   where con_id = to_number(sys_context('USERENV', 'CON_ID'));

  if l_tempfile_count <= 0 then
    raise_application_error(-20001, 'Temporary tablespace ' || l_temp_tbs || ' has no tempfiles after recovery.');
  end if;
end;
/
select file#, status, enabled, name
from v\$tempfile
where con_id = to_number(sys_context('USERENV', 'CON_ID'))
order by file#;
exit
SQL
}

load_manifest_tempfile_targets() {
  RECOVER_TEMPFILE_PATHS=()
  RECOVER_TEMPFILE_TABLESPACE=""
  RECOVER_TEMPFILE_PDB=""

  local count idx kind path tablespace pdb_name
  count="$(manifest_get "planned_action_count" || true)"
  [[ "$count" =~ ^[0-9]+$ ]] || count=0

  idx=1
  while [[ "$idx" -le "$count" ]]; do
    kind="$(manifest_get "action_${idx}_kind" || true)"
    case "$kind" in
      fs_rename|asm_tempfile_rm)
        path="$(manifest_first_value "action_${idx}_tempfile" "action_${idx}_target" || true)"
        if [[ -n "$path" ]]; then
          RECOVER_TEMPFILE_PATHS+=("$path")
          tablespace="$(manifest_get "action_${idx}_tablespace" || true)"
          pdb_name="$(manifest_get "action_${idx}_pdb_name" || true)"
          [[ -n "$RECOVER_TEMPFILE_TABLESPACE" || -z "$tablespace" ]] ||
            RECOVER_TEMPFILE_TABLESPACE="$tablespace"
          [[ -n "$RECOVER_TEMPFILE_PDB" || -z "$pdb_name" ]] ||
            RECOVER_TEMPFILE_PDB="$pdb_name"
        fi
        ;;
    esac
    idx=$((idx + 1))
  done

  if [[ "${#RECOVER_TEMPFILE_PATHS[@]}" -eq 0 ]]; then
    local paths original backup
    if paths="$(manifest_rename_paths 2>/dev/null)"; then
      IFS='|' read -r original backup <<<"$paths"
      [[ -n "$original" ]] && RECOVER_TEMPFILE_PATHS+=("$original")
    fi
  fi

  [[ "${#RECOVER_TEMPFILE_PATHS[@]}" -gt 0 ]]
}

write_tempfile_list_recovery_sql_file() {
  local container_name="$1"
  local tablespace_name="$2"
  local sql_file="$3"
  shift 3

  local container_sql="" tablespace_literal path path_literal first_literal
  if [[ -n "$container_name" && "$container_name" != "CDB\$ROOT" && "$container_name" != "ROOT" && "$container_name" != "NONCDB" ]]; then
    container_sql="alter session set container = $(sql_identifier "$container_name");"
  fi
  tablespace_literal="$(sql_quote "$tablespace_name")"
  first_literal="$(sql_quote "${1:-}")"

  {
    cat <<SQL
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
${container_sql}
declare
  l_tempfile_count number := 0;
  l_temp_tbs varchar2(128) := ${tablespace_literal};
  l_omf_dest varchar2(4000);
begin
  if l_temp_tbs is null then
    select property_value
      into l_temp_tbs
      from database_properties
     where property_name = 'DEFAULT_TEMP_TABLESPACE';
  end if;

  dbms_output.put_line('Temporary tablespace selected for repair: ' || l_temp_tbs);

  select value
    into l_omf_dest
    from v\$parameter
   where name = 'db_create_file_dest';
SQL

    for path in "$@"; do
      path_literal="$(sql_quote "$path")"
      cat <<SQL
  begin
    dbms_output.put_line('Dropping missing tempfile metadata for ${path}');
    execute immediate 'alter database tempfile ' || chr(39) || ${path_literal} || chr(39) || ' drop including datafiles';
  exception
    when others then
      if sqlcode in (-1516, -1116, -1110) then
        dbms_output.put_line('Tempfile metadata was already absent or not usable: ${path}');
      else
        raise;
      end if;
  end;
SQL
    done

    cat <<'SQL'

  select count(*)
    into l_tempfile_count
    from v$tempfile tf
    join v$tablespace ts
      on ts.con_id = tf.con_id
     and ts.ts# = tf.ts#
   where tf.con_id = to_number(sys_context('USERENV', 'CON_ID'))
     and ts.name = l_temp_tbs;

  dbms_output.put_line('Current tempfile count after metadata repair: ' || l_tempfile_count);

  if l_tempfile_count <= 0 then
    dbms_output.put_line('Adding replacement tempfile to ' || l_temp_tbs);
SQL
    # ADD TEMPFILE without a file name is OMF-only (ORA-02236 otherwise):
    # reuse the first original path (freed by the scenario rename) when
    # db_create_file_dest is not configured.
    printf "    if l_omf_dest is not null then\n"
    printf "      execute immediate 'alter tablespace ' || dbms_assert.simple_sql_name(l_temp_tbs) ||\n"
    printf "        ' add tempfile size %s autoextend on next 10m maxsize unlimited';\n" "$TEMPFILE_SIZE"
    printf "    else\n"
    printf "      execute immediate 'alter tablespace ' || dbms_assert.simple_sql_name(l_temp_tbs) ||\n"
    printf "        ' add tempfile ' || chr(39) || %s || chr(39) ||\n" "$first_literal"
    printf "        ' size %s reuse autoextend on next 10m maxsize unlimited';\n" "$TEMPFILE_SIZE"
    printf "    end if;\n"
    cat <<'SQL'
  end if;

  select count(*)
    into l_tempfile_count
    from v$tempfile tf
    join v$tablespace ts
      on ts.con_id = tf.con_id
     and ts.ts# = tf.ts#
   where tf.con_id = to_number(sys_context('USERENV', 'CON_ID'))
     and ts.name = l_temp_tbs;

  if l_tempfile_count <= 0 then
    raise_application_error(-20001, 'Temporary tablespace ' || l_temp_tbs || ' has no tempfiles after recovery.');
  end if;
end;
/
select tf.file#, tf.status, tf.enabled, ts.name tablespace_name, tf.name
from v$tempfile tf
join v$tablespace ts
  on ts.con_id = tf.con_id
 and ts.ts# = tf.ts#
where tf.con_id = to_number(sys_context('USERENV', 'CON_ID'))
order by ts.name, tf.file#;
exit
SQL
  } >"$sql_file" || die "Unable to write tempfile-list recovery SQL file: $sql_file"
}

discover_service_name() {
  if [[ -n "$SERVICE_NAME" ]]; then
    printf "%s\n" "$SERVICE_NAME"
    return "$SUCCESS"
  fi

  local file="$WORK_DIR/service_name.out"
  sql_query "$file" "
select regexp_substr(value, '[^,]+', 1, 1)
from v\$parameter
where name = 'service_names';
" || return "$FAIL"
  SERVICE_NAME="$(trim_blank_lines <"$file" | head -n 1 | tr -d ' ')"
  [[ -n "$SERVICE_NAME" ]] || return "$FAIL"
  printf "%s\n" "$SERVICE_NAME"
}

# Pure parser: extract host:port from a local_listener ADDRESS string, e.g.
# (ADDRESS=(PROTOCOL=TCP)(HOST=testone)(PORT=1522)) -> testone:1522.
# Fails when the value is empty, an alias (no ADDRESS to parse), or malformed.
parse_listener_endpoint_from_address() {
  local value="${1:-}" host="" port=""
  # Patterns live in variables: a literal ')' inside an inline [[ =~ ]] regex
  # is a bash syntax error.
  local host_re='\([Hh][Oo][Ss][Tt][[:space:]]*=[[:space:]]*([^)[:space:]]+)[[:space:]]*\)'
  local port_re='\([Pp][Oo][Rr][Tt][[:space:]]*=[[:space:]]*([0-9]+)[[:space:]]*\)'
  [[ -n "$value" ]] || return "$FAIL"
  if [[ "$value" =~ $host_re ]]; then
    host="${BASH_REMATCH[1]}"
  fi
  if [[ "$value" =~ $port_re ]]; then
    port="${BASH_REMATCH[1]}"
  fi
  [[ -n "$host" && -n "$port" ]] || return "$FAIL"
  printf "%s:%s\n" "$host" "$port"
}

# EZConnect endpoint (host:port) for listener-routed validation connects.
# Priority: CRASHSIM_LISTENER_ENDPOINT override, then the database's own
# local_listener ADDRESS - authoritative on labs with non-default listeners
# (field-tested 2026-07-18: a lab listening on port 1522 made the previous
# hardcoded localhost:1521 remote SYSDBA validation fail ORA-12541 on an
# otherwise healthy system) - then the localhost:1521 default.
discover_listener_endpoint() {
  if [[ -n "${CRASHSIM_LISTENER_ENDPOINT:-}" ]]; then
    printf "%s\n" "$CRASHSIM_LISTENER_ENDPOINT"
    return "$SUCCESS"
  fi

  local file="$WORK_DIR/local_listener.out" value endpoint
  if sql_query "$file" "
select value
from v\$parameter
where name = 'local_listener';
"; then
    value="$(trim_blank_lines <"$file" | head -n 1)"
    if endpoint="$(parse_listener_endpoint_from_address "$value")"; then
      printf "%s\n" "$endpoint"
      return "$SUCCESS"
    fi
  fi
  printf "localhost:1521\n"
}

sqlplus_password_literal() {
  local value="$1"
  value="${value//\"/\\\"}"
  printf "%s" "$value"
}

remote_sysdba_test() {
  local service output_file status password_escaped
  [[ -n "$SYS_PASSWORD" ]] || die "Password-file recovery requires --sys-password or CRASHSIM_SYS_PASSWORD for remote SYSDBA validation."
  password_escaped="$(sqlplus_password_literal "$SYS_PASSWORD")"
  output_file="$WORK_DIR/remote_sysdba_test.out"

  if [[ "$EXECUTE" -eq 0 ]]; then
    service="${SERVICE_NAME:-<service_name>}"
    cat <<DRYRUN
DRY-RUN: would validate remote SYSDBA using:
  connect sys/"********"@//<listener endpoint from local_listener, default localhost:1521>/${service} as sysdba
  require output prefix: REMOTE_SYSDBA_OK|
DRYRUN
    return "$SUCCESS"
  fi

  service="$(discover_service_name)" || die "Could not discover listener service name. Use --service-name or CRASHSIM_SERVICE_NAME."
  # The endpoint comes from the database's own local_listener (labs often run
  # non-default listeners, e.g. port 1522), never a hardcoded default.
  local endpoint
  endpoint="$(discover_listener_endpoint)"
  echo "Remote SYSDBA validation endpoint: //${endpoint}/${service}"
  ensure_sqlplus
  "$SQLPLUS_BIN" -L -s /nolog >"$output_file" <<SQL
connect sys/"${password_escaped}"@//${endpoint}/${service} as sysdba
set heading off feedback off pages 0 verify off echo off
select 'REMOTE_SYSDBA_OK|' || name || '|' || open_mode from v\$database;
exit
SQL
  status=$?
  cat "$output_file"
  [[ "$status" -eq 0 ]] ||
    die "Remote SYSDBA SQL*Plus exited with status $status (endpoint //${endpoint}/${service}; if the listener runs elsewhere, set CRASHSIM_LISTENER_ENDPOINT=host:port)."
  grep -q '^REMOTE_SYSDBA_OK|' "$output_file" ||
    die "Remote SYSDBA validation did not return REMOTE_SYSDBA_OK (endpoint //${endpoint}/${service}; check the listener is up and the service is registered, or set CRASHSIM_LISTENER_ENDPOINT=host:port)."
}

restore_sysbackup_user_if_present() {
  [[ -n "$SYSBACKUP_USER" ]] || return "$SUCCESS"

  local user_literal
  user_literal="$(sql_quote "$SYSBACKUP_USER")"
  run_sql_text "restore SYSBACKUP grant for ${SYSBACKUP_USER} if account exists" "
declare
  l_count number;
begin
  select count(*)
    into l_count
    from cdb_users
   where username = ${user_literal}
     and common = 'YES';

  if l_count > 0 then
    execute immediate 'grant sysbackup to ${SYSBACKUP_USER} container=all';
  end if;
end;
/
" "$LOG_DIR/crashsim_recover_sysbackup_${RUN_ID}.log"
}

archivelog_sequence_for_path() {
  local path="$1"
  local path_literal file seq
  path_literal="$(sql_quote "$path")"
  file="$WORK_DIR/archivelog_sequence.out"
  sql_query "$file" "
select sequence#
from v\$archived_log
where name = ${path_literal}
  and rownum = 1;
" || return "$FAIL"
  seq="$(trim_blank_lines <"$file" | head -n 1 | tr -d ' ')"
  [[ "$seq" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$seq"
}

backupset_key_for_piece() {
  local path="$1"
  local path_literal file key
  path_literal="$(sql_quote "$path")"
  file="$WORK_DIR/backupset_key.out"
  sql_query "$file" "
select bs.recid
from v\$backup_piece bp
join v\$backup_set bs
  on bs.set_stamp = bp.set_stamp
 and bs.set_count = bp.set_count
where bp.handle = ${path_literal}
  and rownum = 1;
" || return "$FAIL"
  key="$(trim_blank_lines <"$file" | head -n 1 | tr -d ' ')"
  [[ "$key" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$key"
}

discover_environment() {
  if [[ "$DISCOVERED" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  ensure_os_user
  ensure_sqlplus

  local db_file="$WORK_DIR/db.env"
  local instance_file="$WORK_DIR/instance.env"
  local params_file="$WORK_DIR/params.env"
  local pdb_file="$WORK_DIR/pdbs.env"

  # Fail closed if v$database is unreadable: with the instance down, sqlplus
  # prints the failing statement + ORA-01034 and this parser used to swallow
  # that as topology (DB_ROLE became a stray quote from the echoed SQL), so
  # readiness gates blamed the database ROLE instead of the dead instance.
  if ! sql_query "$db_file" "
select name || '|' ||
       db_unique_name || '|' ||
       database_role || '|' ||
       open_mode || '|' ||
       cdb || '|' ||
       protection_mode || '|' ||
       switchover_status
from v\$database;
"; then
    local ora_hint
    ora_hint="$(grep -m 1 -oE 'ORA-[0-9]+.*' "$db_file" 2>/dev/null)"
    die "Topology discovery cannot read v\$database (${ora_hint:-SQL*Plus connection failed}).
The Oracle instance is not available. Start it (sqlplus / as sysdba; startup) - or, if a
destructive scenario was injected earlier and never recovered, run --recover for that
scenario first - then retry."
  fi
  local db_line
  db_line="$(trim_blank_lines <"$db_file" | head -n 1)"
  case "$db_line" in
    *"|"*"|"*"|"*"|"*"|"*"|"*) ;;
    *) die "Topology discovery returned unexpected output instead of v\$database data: ${db_line:-<empty>}" ;;
  esac
  IFS='|' read -r DB_NAME DB_UNIQUE_NAME DB_ROLE DB_OPEN_MODE DB_CDB DB_PROTECTION_MODE DB_SWITCHOVER_STATUS <<<"$db_line"

  sql_query "$instance_file" "
select instance_name || '|' ||
       host_name || '|' ||
       status || '|' ||
       parallel || '|' ||
       thread#
from v\$instance;
"
  local instance_line
  instance_line="$(trim_blank_lines <"$instance_file" | head -n 1)"
  IFS='|' read -r INSTANCE_NAME HOST_NAME INSTANCE_STATUS INSTANCE_PARALLEL INSTANCE_THREAD <<<"$instance_line"

  sql_query "$params_file" "
select name || '=' || nvl(value, '')
from v\$parameter
where name in ('spfile','db_recovery_file_dest','oracle_base')
order by name;
"
  while IFS='=' read -r param_name param_value; do
    case "$param_name" in
      db_recovery_file_dest) FRA_PATH="$param_value" ;;
      oracle_base) ORACLE_BASE_DETECTED="$param_value" ;;
      spfile) SPFILE_PATH="$param_value" ;;
    esac
  done < <(trim_blank_lines <"$params_file")

  if grid_tool_available srvctl; then
    local srvctl_config srvctl_type srvctl_rc=0
    # srvctl prints failures to STDOUT (e.g. "Start Oracle Clusterware stack
    # and try again." on hosts with no Oracle Restart at all), so non-empty
    # output alone is NOT config data - the exit status must be checked too.
    srvctl_config="$(run_grid_tool srvctl config database -d "$DB_UNIQUE_NAME" 2>/dev/null)" || srvctl_rc=$?
    if [[ "$srvctl_rc" -ne 0 ]]; then
      srvctl_config=""
    fi
    if [[ -n "$srvctl_config" ]]; then
      GI_MANAGED=1
      PASSWORD_FILE_PATH="$(printf "%s\n" "$srvctl_config" |
        awk -F': ' '/^Password file:/ {print $2; exit}')"
      srvctl_type="$(printf "%s\n" "$srvctl_config" |
        awk -F': ' '/^Type:/ {print $2; exit}' |
        tr '[:lower:]' '[:upper:]' |
        tr -cd '[:alnum:]_')"
    else
      srvctl_type=""
    fi

    case "$srvctl_type" in
      RAC|RACONE|RACONENODE|RAC_ONE_NODE)
        CLUSTER_TYPE="$srvctl_type"
        ;;
      SINGLE)
        if grid_tool_available crsctl; then
          CLUSTER_TYPE="GI_SINGLE"
        else
          CLUSTER_TYPE="SINGLE"
        fi
        ;;
      "")
        if [[ "$INSTANCE_PARALLEL" == "YES" ]]; then
          CLUSTER_TYPE="RAC"
        elif [[ "$GI_MANAGED" -eq 1 ]] || topology_grid_stack_present; then
          CLUSTER_TYPE="GI_SINGLE"
        else
          CLUSTER_TYPE="SINGLE"
        fi
        ;;
      *)
        CLUSTER_TYPE="$srvctl_type"
        ;;
    esac
  elif [[ "$INSTANCE_PARALLEL" == "YES" ]]; then
    CLUSTER_TYPE="RAC"
  elif grid_tool_available crsctl; then
    CLUSTER_TYPE="GI_SINGLE"
  else
    CLUSTER_TYPE="SINGLE"
  fi

  detect_password_file

  if [[ "$DB_CDB" == "YES" ]]; then
    sql_query "$pdb_file" "
select name || '|' || con_id || '|' || open_mode
from v\$pdbs
where name <> 'PDB\$SEED'
order by con_id;
"
    mapfile -t PDB_ROWS < <(trim_blank_lines <"$pdb_file")
  fi

  detect_storage_type
  DISCOVERED=1
}

detect_storage_type() {
  local file="$WORK_DIR/storage.env"
  local srvctl_storage_file="$WORK_DIR/storage_srvctl.env"
  local crs_storage_file="$WORK_DIR/storage_crs.env"
  local has_asm=0 has_fex=0 has_acfs=0 has_fs=0 line class
  sql_query "$file" "
select name from v\$datafile where rownum <= 50
union all
select name from v\$tempfile where rownum <= 50
union all
select name from v\$controlfile where rownum <= 10
union all
select value
from v\$parameter
where name in ('spfile','db_recovery_file_dest')
  and value is not null
"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    line="$(trim_value "$line")"
    class="$(storage_path_class "$line")"
    case "$class" in
      asm) has_asm=1 ;;
      fex) has_fex=1 ;;
      acfs) has_acfs=1 ;;
      filesystem) has_fs=1 ;;
    esac
  done < <(trim_blank_lines <"$file")

  if [[ -n "$DB_UNIQUE_NAME" ]] && grid_tool_available srvctl; then
    if run_grid_tool srvctl config database -d "$DB_UNIQUE_NAME" >"$srvctl_storage_file" 2>/dev/null; then
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        case "$line" in
          "Mount point paths:"*|"Spfile:"*|"Password file:"*)
            line="${line#*:}"
            ;;
          *)
            continue
            ;;
        esac
        line="$(trim_value "$line")"
        [[ -n "$line" ]] || continue
        IFS=',' read -r -a storage_values <<<"$line"
        local storage_value
        for storage_value in "${storage_values[@]}"; do
          storage_value="$(trim_value "$storage_value")"
          [[ -n "$storage_value" ]] || continue
          class="$(storage_path_class "$storage_value")"
          case "$class" in
            asm) has_asm=1 ;;
            fex) has_fex=1 ;;
            acfs) has_acfs=1 ;;
            filesystem) has_fs=1 ;;
          esac
        done
      done <"$srvctl_storage_file"
    fi
  fi

  if grid_tool_available crsctl; then
    if run_grid_tool crsctl stat res -p >"$crs_storage_file" 2>/dev/null; then
      while IFS= read -r line; do
        [[ "$line" == MOUNTPOINT_PATH=* || "$line" == INTERNAL_MOUNTPOINT_PATH=* || "$line" == VOLUME_DEVICE=* ]] || continue
        line="${line#*=}"
        line="$(trim_value "$line")"
        [[ -n "$line" ]] || continue
        class="$(storage_path_class "$line")"
        case "$class" in
          asm) has_asm=1 ;;
          fex) has_fex=1 ;;
          acfs) has_acfs=1 ;;
          filesystem) has_fs=1 ;;
        esac
      done <"$crs_storage_file"
    fi
  fi

  for line in "$SPFILE_PATH" "$FRA_PATH" "$PASSWORD_FILE_PATH"; do
    [[ -n "$line" ]] || continue
    line="$(trim_value "$line")"
    class="$(storage_path_class "$line")"
    case "$class" in
      asm) has_asm=1 ;;
      fex) has_fex=1 ;;
      acfs) has_acfs=1 ;;
      filesystem) has_fs=1 ;;
    esac
  done

  if [[ "$has_asm" -eq 1 && ( "$has_fex" -eq 1 || "$has_acfs" -eq 1 || "$has_fs" -eq 1 ) ]]; then
    STORAGE_TYPE="MIXED"
  elif [[ "$has_asm" -eq 1 ]]; then
    STORAGE_TYPE="ASM"
  elif [[ "$has_fex" -eq 1 && "$has_acfs" -eq 1 ]]; then
    STORAGE_TYPE="FEX_ACFS"
  elif [[ "$has_fex" -eq 1 ]]; then
    STORAGE_TYPE="FEX"
  elif [[ "$has_acfs" -eq 1 ]]; then
    STORAGE_TYPE="ACFS"
  elif [[ "$has_fs" -eq 1 ]]; then
    STORAGE_TYPE="FILESYSTEM"
  else
    STORAGE_TYPE="UNKNOWN"
  fi
}

storage_path_class() {
  local path="$1"
  local first_char
  path="$(printf "%s" "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  first_char="${path:0:1}"
  case "$first_char" in
    +) printf "asm" ;;
    @) printf "fex" ;;
    /)
      if [[ "$path" == *"/dbaas_acfs/"* ||
            "$path" == *"/acfs/"* ||
            "$path" == /acfs/* ||
            "$path" == /acfs ||
            "$path" == /var/opt/oracle/dbaas_acfs ||
            "$path" == /var/opt/oracle/dbaas_acfs/* ]]; then
        printf "acfs"
      else
        printf "filesystem"
      fi
      ;;
    *) printf "unknown" ;;
  esac
}

storage_path_is_local_filesystem() {
  local class
  class="$(storage_path_class "$1")"
  [[ "$class" == "filesystem" || "$class" == "acfs" ]]
}

storage_path_is_provider_managed() {
  local class
  class="$(storage_path_class "$1")"
  [[ "$class" == "asm" || "$class" == "fex" ]]
}

storage_path_provider_reason() {
  local path="$1"
  local operation="${2:-crash injection}"
  case "$(storage_path_class "$path")" in
    asm)
      printf "ASM path requires ASM-aware %s; filesystem rename/dd is not valid" "$operation"
      ;;
    fex)
      printf "FEX/ACFS managed storage handle requires provider-aware %s; this @... handle is not a local filesystem path" "$operation"
      ;;
    acfs)
      printf "ACFS-backed local path can use filesystem actions when visible and writable to the current OS user"
      ;;
    filesystem)
      printf "filesystem path"
      ;;
    *)
      printf "unknown storage path format requires manual validation before %s" "$operation"
      ;;
  esac
}

storage_supports_gi_storage_planning() {
  case "$STORAGE_TYPE" in
    ASM|FEX|FEX_ACFS|ACFS|MIXED) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

detect_password_file() {
  if [[ -n "$PASSWORD_FILE_PATH" ]]; then
    return "$SUCCESS"
  fi
  if [[ -z "${ORACLE_HOME:-}" ]]; then
    return "$SUCCESS"
  fi

  local candidate
  local db_lower
  local db_unique_lower
  db_lower="$(printf "%s" "$DB_NAME" | tr '[:upper:]' '[:lower:]')"
  db_unique_lower="$(printf "%s" "$DB_UNIQUE_NAME" | tr '[:upper:]' '[:lower:]')"

  for candidate in \
    "${ORACLE_HOME}/dbs/orapw${ORACLE_SID:-}" \
    "${ORACLE_HOME}/dbs/orapw${INSTANCE_NAME:-}" \
    "${ORACLE_HOME}/dbs/orapw${db_lower}" \
    "${ORACLE_HOME}/dbs/orapw${DB_NAME}" \
    "${ORACLE_HOME}/dbs/orapw${db_unique_lower}" \
    "${ORACLE_HOME}/dbs/orapw${DB_UNIQUE_NAME}"; do
    if [[ -n "$candidate" && -f "$candidate" ]]; then
      PASSWORD_FILE_PATH="$candidate"
      return "$SUCCESS"
    fi
  done
}

write_discovery_text() {
  local output_file="$1"
  local row name con_id open_mode

  {
    cat <<DISCOVERY
CrashSimulator V2 discovery
  Version:           ${VERSION}
  Generated UTC:     $(date -u +%Y-%m-%dT%H:%M:%SZ)
  Host:              ${HOST_NAME}
  OS user:           $(id -un)
  Oracle home:       ${ORACLE_HOME:-unknown}
  SQL*Plus:          ${SQLPLUS_BIN}
  Database name:     ${DB_NAME}
  DB unique name:    ${DB_UNIQUE_NAME}
  Version family:    12c or later required by v2
  CDB:               ${DB_CDB}
  Open mode:         ${DB_OPEN_MODE}
  Database role:     ${DB_ROLE}
  Protection mode:   ${DB_PROTECTION_MODE}
  Switchover status: ${DB_SWITCHOVER_STATUS}
  Instance:          ${INSTANCE_NAME}
  Thread:            ${INSTANCE_THREAD}
  RAC parallel:      ${INSTANCE_PARALLEL}
  Cluster type:      ${CLUSTER_TYPE}
  GI managed:        ${GI_MANAGED}
  Storage type:      ${STORAGE_TYPE}
  SPFILE:            ${SPFILE_PATH:-not detected}
  Password file:     ${PASSWORD_FILE_PATH:-not detected}
  FRA:               ${FRA_PATH:-not configured}
DISCOVERY

    if [[ "$DB_CDB" == "YES" ]]; then
      printf "  PDBs:\n"
      if [[ "${#PDB_ROWS[@]}" -eq 0 ]]; then
        printf "    none found\n"
      else
        for row in "${PDB_ROWS[@]}"; do
          IFS='|' read -r name con_id open_mode <<<"$row"
          printf "    %s (CON_ID=%s, OPEN_MODE=%s)\n" "$name" "$con_id" "$open_mode"
        done
      fi
    fi
  } >"$output_file" || die "Unable to write discovery text: $output_file"
}

print_discovery() {
  local topology_file latest_file
  discover_environment

  topology_file="${LOG_DIR}/crashsim_topology_${RUN_ID}.txt"
  latest_file="${LOG_DIR}/crashsim_topology_latest.txt"
  write_discovery_text "$topology_file"
  cp -p -- "$topology_file" "$latest_file" 2>/dev/null || true
  cat "$topology_file"
  echo
  echo "Topology snapshot: ${topology_file}"
  echo "Latest topology snapshot: ${latest_file}"
  maybe_render_html "$topology_file"
}

file_mtime_epoch() {
  local file="$1"
  stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null || return "$FAIL"
}

topology_cache_value() {
  local file="$1" label="$2"
  awk -F: -v label="$label" '
    index($1, label) {
      value=$0
      sub(/^[^:]*:[[:space:]]*/, "", value)
      print value
      exit
    }
  ' "$file"
}

load_topology_cache() {
  local cache_file="${LOG_DIR}/crashsim_topology_latest.txt"
  local now mtime age row name con_id open_mode

  [[ "$TOPOLOGY_CACHE_DISABLED" -eq 0 ]] || return "$FAIL"
  [[ "$TOPOLOGY_CACHE_REFRESH" -eq 0 ]] || return "$FAIL"
  [[ "$TOPOLOGY_CACHE_TTL_SECONDS" -gt 0 ]] || return "$FAIL"
  [[ -f "$cache_file" ]] || return "$FAIL"

  now="$(date +%s)"
  mtime="$(file_mtime_epoch "$cache_file")" || return "$FAIL"
  age=$((now - mtime))
  [[ "$age" -le "$TOPOLOGY_CACHE_TTL_SECONDS" ]] || return "$FAIL"

  HOST_NAME="$(topology_cache_value "$cache_file" "Host")"
  DB_NAME="$(topology_cache_value "$cache_file" "Database name")"
  DB_UNIQUE_NAME="$(topology_cache_value "$cache_file" "DB unique name")"
  DB_CDB="$(topology_cache_value "$cache_file" "CDB")"
  DB_OPEN_MODE="$(topology_cache_value "$cache_file" "Open mode")"
  DB_ROLE="$(topology_cache_value "$cache_file" "Database role")"
  DB_PROTECTION_MODE="$(topology_cache_value "$cache_file" "Protection mode")"
  DB_SWITCHOVER_STATUS="$(topology_cache_value "$cache_file" "Switchover status")"
  INSTANCE_NAME="$(topology_cache_value "$cache_file" "Instance")"
  INSTANCE_THREAD="$(topology_cache_value "$cache_file" "Thread")"
  INSTANCE_PARALLEL="$(topology_cache_value "$cache_file" "RAC parallel")"
  CLUSTER_TYPE="$(topology_cache_value "$cache_file" "Cluster type")"
  GI_MANAGED="$(topology_cache_value "$cache_file" "GI managed")"
  STORAGE_TYPE="$(topology_cache_value "$cache_file" "Storage type")"
  SPFILE_PATH="$(topology_cache_value "$cache_file" "SPFILE")"
  PASSWORD_FILE_PATH="$(topology_cache_value "$cache_file" "Password file")"
  FRA_PATH="$(topology_cache_value "$cache_file" "FRA")"

  PDB_ROWS=()
  while IFS= read -r row; do
    if [[ "$row" =~ ^[[:space:]]+([^[:space:]]+)[[:space:]]+\(CON_ID=([^,]+),[[:space:]]*OPEN_MODE=(.*)\)$ ]]; then
      name="${BASH_REMATCH[1]}"
      con_id="${BASH_REMATCH[2]}"
      open_mode="${BASH_REMATCH[3]}"
      PDB_ROWS+=("${name}|${con_id}|${open_mode}")
    fi
  done <"$cache_file"

  echo "Using cached topology snapshot (${age}s old): ${cache_file}"
  return "$SUCCESS"
}

doctor_tool_path() {
  local tool="$1"
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/bin/${tool}" ]]; then
    printf "%s" "${ORACLE_HOME}/bin/${tool}"
    return "$SUCCESS"
  fi
  if [[ -n "${CRASHSIM_GRID_HOME:-}" && -x "${CRASHSIM_GRID_HOME}/bin/${tool}" ]]; then
    printf "%s" "${CRASHSIM_GRID_HOME}/bin/${tool}"
    return "$SUCCESS"
  fi
  command -v "$tool" 2>/dev/null || true
}

DOCTOR_REPORT_FILE=""
DOCTOR_ERRORS=0
DOCTOR_WARNINGS=0

doctor_add_check() {
  local status="$1" area="$2" check="$3" evidence="$4" action="$5"
  case "$status" in
    GAP|ERROR) DOCTOR_ERRORS=$((DOCTOR_ERRORS + 1)) ;;
    WARN) DOCTOR_WARNINGS=$((DOCTOR_WARNINGS + 1)) ;;
  esac
  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$status" \
    "$(md_escape "$area")" \
    "$(md_escape "$check")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$action")" >>"$DOCTOR_REPORT_FILE"
}

doctor_check_command() {
  local tool="$1" area="$2" required="$3" reason="$4"
  local path
  path="$(doctor_tool_path "$tool")"
  if [[ -n "$path" ]]; then
    doctor_add_check "OK" "$area" "${tool} available" "$path" "No action needed."
  elif [[ "$required" == "required" ]]; then
    doctor_add_check "GAP" "$area" "${tool} available" "not found" "$reason"
  else
    doctor_add_check "WARN" "$area" "${tool} available" "not found" "$reason"
  fi
}

run_doctor() {
  local report_file latest_file bash_major bash_status log_probe node_path script_root
  local config_status destructive_status cache_status

  report_file="${LOG_DIR}/crashsim_doctor_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_doctor_latest.md"
  DOCTOR_REPORT_FILE="$report_file"
  DOCTOR_ERRORS=0
  DOCTOR_WARNINGS=0
  script_root="$(script_dir)"

  {
    printf "# CrashSimulator Doctor / Public Readiness Preflight\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un)"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf '%s\n\n' 'This preflight is read-only. It checks local tooling, configuration hygiene, public-release safety posture, and optional HA/DR helpers. Use `--health-check`, `--scenario-readiness-report`, and `--prepare-environment --dry-run` for database-specific evidence.'
    printf "## Evidence Policy\n\n"
    printf "| Evidence state | Meaning |\n"
    printf "| --- | --- |\n"
    printf "| Confirmed | Direct dated evidence from this environment exists. |\n"
    printf "| Observed | Tool output or configuration was observed, but not tested end to end. |\n"
    printf "| Candidate | Component appears installed/configured; service-level claims still need drills. |\n"
    printf "| Inferred | Conclusion follows from topology pattern; verify before relying on it. |\n"
    printf "| Gap | Evidence is absent, stale, or contradictory. |\n"
    printf "\n## Checks\n\n"
    printf "| Status | Area | Check | Evidence | Recommended action |\n"
    printf "| --- | --- | --- | --- | --- |\n"
  } >"$report_file" || die "Unable to write doctor report: $report_file"

  bash_major="${BASH_VERSINFO[0]:-0}"
  if [[ "$bash_major" -ge 4 ]]; then
    doctor_add_check "OK" "Runtime" "Bash version" "${BASH_VERSION}" "No action needed."
  else
    doctor_add_check "GAP" "Runtime" "Bash version" "${BASH_VERSION:-unknown}" "Run with Bash 4 or later."
  fi

  if [[ -w "$LOG_DIR" ]]; then
    log_probe="${LOG_DIR}/.crashsim_doctor_write_test_${RUN_ID}"
    if : >"$log_probe" 2>/dev/null; then
      rm -f "$log_probe" 2>/dev/null || true
      doctor_add_check "OK" "Logging" "Log directory writable" "$LOG_DIR" "No action needed."
    else
      doctor_add_check "GAP" "Logging" "Log directory writable" "$LOG_DIR" "Fix permissions or choose --log-dir."
    fi
  else
    doctor_add_check "GAP" "Logging" "Log directory writable" "$LOG_DIR" "Fix permissions or choose --log-dir."
  fi

  if [[ -n "$CONFIG_SOURCE" ]]; then
    config_status="loaded: ${CONFIG_SOURCE}"
  else
    config_status="not loaded"
  fi
  doctor_add_check "INFO" "Configuration" "Startup config" "$config_status" "Run --write-config-template to create a reusable non-secret config."

  if [[ "${DESTRUCTIVE_LAB_ACK^^}" == "YES" ]]; then
    destructive_status="set for this run"
    doctor_add_check "WARN" "Safety" "Destructive lab acknowledgement" "$destructive_status" "Keep this enabled only in approved non-production labs."
  else
    destructive_status="not set"
    doctor_add_check "OK" "Safety" "Destructive lab acknowledgement" "$destructive_status" "Destructive --execute --yes actions remain blocked until explicitly acknowledged."
  fi

  if [[ "$TOPOLOGY_CACHE_DISABLED" -eq 1 ]]; then
    cache_status="disabled"
  else
    cache_status="ttl=${TOPOLOGY_CACHE_TTL_SECONDS}s"
  fi
  doctor_add_check "INFO" "Efficiency" "Topology cache" "$cache_status" "Use --refresh-topology when you need live topology discovery."

  [[ -n "${ORACLE_HOME:-}" && -d "${ORACLE_HOME:-}" ]] &&
    doctor_add_check "OK" "Oracle environment" "ORACLE_HOME" "$ORACLE_HOME" "No action needed." ||
    doctor_add_check "WARN" "Oracle environment" "ORACLE_HOME" "${ORACLE_HOME:-not set}" "Set ORACLE_HOME or use SQLPLUS/RMAN overrides before database-host scenarios."
  [[ -n "${ORACLE_SID:-}" ]] &&
    doctor_add_check "OK" "Oracle environment" "ORACLE_SID" "$ORACLE_SID" "No action needed." ||
    doctor_add_check "WARN" "Oracle environment" "ORACLE_SID" "not set" "Set ORACLE_SID for bequeath SYSDBA workflows."

  doctor_check_command "sqlplus" "Oracle client" "required" "Install Oracle client/database software or set SQLPLUS."
  doctor_check_command "rman" "Oracle client" "required" "Install Oracle client/database software or set RMAN."
  doctor_check_command "lsnrctl" "Oracle network" "optional" "Install Oracle networking tools for listener checks."
  doctor_check_command "srvctl" "RAC/GI" "optional" "Required only for RAC/GI service and instance drills."
  doctor_check_command "crsctl" "RAC/GI" "optional" "Required only for Grid Infrastructure readiness checks."
  doctor_check_command "asmcmd" "ASM/GI" "optional" "Required only for ASM/FEX/ACFS storage evidence."
  doctor_check_command "dgmgrl" "Data Guard" "optional" "Required only for Broker/FSFO checks."
  doctor_check_command "ords" "APEX/ORDS" "optional" "Required only for ORDS/APEX service-path scenarios."
  doctor_check_command "oci" "OCI/ADB" "optional" "Required only for OCI control-plane and ADB readiness checks."
  doctor_check_command "java" "APEX/ORDS" "optional" "Required for ORDS installation/runtime validation."
  doctor_check_command "curl" "HTTP smoke" "optional" "Useful for ORDS/APEX/ADB smoke URLs."
  doctor_check_command "node" "APEX session driver" "optional" "Required only for the optional Playwright APEX session driver."
  doctor_check_command "git" "Release" "optional" "Useful for release checks and source synchronization."
  doctor_check_command "zip" "Release" "optional" "Useful for runtime package creation."
  doctor_check_command "unzip" "Release" "optional" "Useful for runtime package validation."

  node_path="$(doctor_tool_path node)"
  if [[ -n "$node_path" && -f "${script_root}/tools/crashsim_apex_session_driver.cjs" ]]; then
    if "$node_path" -e "require('playwright')" >/dev/null 2>&1; then
      doctor_add_check "OK" "APEX session driver" "Playwright Node module" "available" "No action needed."
    else
      doctor_add_check "WARN" "APEX session driver" "Playwright Node module" "not found in current Node path" "Install Playwright only if scenario 80 browser-session evidence is required."
    fi
  fi

  if [[ -n "${CRASHSIM_REMOTE_NODES:-}" ]]; then
    doctor_add_check "INFO" "Multi-node" "Remote node sync list" "${CRASHSIM_REMOTE_NODES}" "Run tools/crashsim_node_sync_check.sh before RAC/ORDS multi-node drills."
  else
    doctor_add_check "INFO" "Multi-node" "Remote node sync list" "not set" "Set CRASHSIM_REMOTE_NODES for RAC/ORDS multi-node version/config sync checks."
  fi

  {
    printf "\n## Summary\n\n"
    printf -- '- Errors/Gaps: `%s`\n' "$DOCTOR_ERRORS"
    printf -- '- Warnings: `%s`\n' "$DOCTOR_WARNINGS"
    printf -- '- Latest report: `%s`\n' "$latest_file"
    printf "\n## Suggested First Public-Readiness Sequence\n\n"
    printf '```bash\n'
    printf "./%s --doctor --html\n" "$PROGRAM"
    printf "./%s --secret-scan --scan-path .\n" "$PROGRAM"
    printf "./%s --scenario-lifecycle-check --html\n" "$PROGRAM"
    printf "./%s --prepare-environment --dry-run --html\n" "$PROGRAM"
    printf "./%s --scenario-readiness-report --html\n" "$PROGRAM"
    printf "./%s --release-check\n" "$PROGRAM"
    printf '```\n'
  } >>"$report_file"

  cp "$report_file" "$latest_file" 2>/dev/null || true
  echo "Doctor report generated: ${report_file}"
  echo "Latest doctor report: ${latest_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
  [[ "$DOCTOR_ERRORS" -eq 0 ]]
}

run_first_run_guide() {
  local report_file latest_file
  report_file="${LOG_DIR}/crashsim_first_run_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_first_run_latest.md"
  {
    printf "# CrashSimulator First-Run Guide\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf "\nThis guide is intentionally read-only. It gives new users a safe order of operations before they try destructive drills.\n\n"
    printf "## Recommended Flow\n\n"
    printf '1. Configure the Oracle environment or create `crashsimulator.conf`, then run `./%s --show-config` and `./%s --validate-config`.\n' "$PROGRAM" "$PROGRAM"
    printf '2. Run `./%s --public-limitations --html` so the team understands plan-only, provider-specific, ADB, licensing-sensitive, and destructive-drill expectations.\n' "$PROGRAM"
    printf '3. Run `./%s --doctor --html` to check local tooling, config, and public-safety posture.\n' "$PROGRAM"
    printf '4. Run `./%s --discover` or open the Guided Workflow menu to collect topology evidence.\n' "$PROGRAM"
    printf '5. Run `./%s --prepare-environment --dry-run --html` to detect missing lab seeds for this topology without changing the database.\n' "$PROGRAM"
    printf '6. Run `./%s --scenario-readiness-report --html` to see which scenarios are runnable, plan-only, or blocked.\n' "$PROGRAM"
    printf '7. Run `./%s --scenario-lifecycle-report --html` to review validation/protection/execution/recovery/runbook/evidence coverage.\n' "$PROGRAM"
    printf "8. Start with read-only reports, then low-risk logical/tempfile drills, then destructive drills only after backup, runbook, and recovery validation review.\n"
    printf '%s\n' '9. Before any non-interactive destructive execution, set `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` only in an approved non-production lab.'
    printf "\n## Safe Starter Commands\n\n"
    printf '```bash\n'
    printf "./%s --show-config\n" "$PROGRAM"
    printf "./%s --validate-config\n" "$PROGRAM"
    printf "./%s --public-limitations --html\n" "$PROGRAM"
    printf "./%s --doctor --html\n" "$PROGRAM"
    printf "./%s --discover\n" "$PROGRAM"
    printf "./%s --prepare-environment --dry-run --html\n" "$PROGRAM"
    printf "./%s --scenario-lifecycle-check --html\n" "$PROGRAM"
    printf "./%s --scenario-readiness-report --html\n" "$PROGRAM"
    printf "./%s --backup-report\n" "$PROGRAM"
    printf "./%s --maa-report --html\n" "$PROGRAM"
    printf "./%s --resilience-scorecard --html\n" "$PROGRAM"
    printf '```\n'
    printf "\n## Evidence Interpretation\n\n"
    printf "Treat installed or configured components as candidates until a drill has measured them. Do not claim near-zero downtime without client/service/FAN/AC/TAC evidence, and do not claim zero data loss without synchronous protection and tested transition evidence.\n"
    printf "\n## Safe Starter Scenario Ideas\n\n"
    printf -- '- Read-only first: health check, configuration report, backup/recoverability report, MAA report, service review, resilience scorecard, APEX/ORDS readiness, and ADB readiness where applicable.\n'
    printf -- '- Low-risk drills after readiness passes: scenarios `6` and `31` for tempfile loss, `11` and `36` for disposable index rebuild practice, `43` for disposable table loss, and `63` for controlled TEMP pressure.\n'
    printf -- '- Defer plan-only/provider-specific drills such as ASM/GI/OCR/voting, OCI control-plane, Exadata, GoldenGate, switchover/failback, PDB PITR, GRP rollback, and AC/TAC replay until the external runbook and approvals are complete.\n'
  } >"$report_file" || die "Unable to write first-run guide: $report_file"
  cp "$report_file" "$latest_file" 2>/dev/null || true
  echo "First-run guide generated: ${report_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
}

run_public_limitations_page() {
  local report_file latest_file docs_file
  report_file="${LOG_DIR}/crashsim_public_limitations_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_public_limitations_latest.md"
  docs_file="$(script_dir)/docs/CRASHSIMULATOR_PUBLIC_LIMITATIONS.md"

  {
    printf "# CrashSimulator Public Beta Limitations And Expectations\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf "\nCrashSimulator is an open-source resilience validation platform for Oracle Database labs. It helps teams practice, validate, and document recoverability, but it is not a production chaos tool, an Oracle certification program, a licensing verifier, or a substitute for tested backups and change control.\n"

    printf "\n## Safety Expectations\n\n"
    printf -- '- Dry-run is the default. Destructive activity requires `--execute`, typed confirmation, and for non-interactive runs `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` or `--accept-destructive-lab`.\n'
    printf -- '- Use destructive scenarios only in approved non-production or dedicated resilience-test environments.\n'
    printf -- '- Run `--doctor`, `--discover`, `--prepare-environment --dry-run`, `--scenario-readiness-report`, `--runbook <id>`, and a backup/recoverability review before destructive drills.\n'
    printf -- '- Keep manifests, runbooks, health checks, RMAN/SQL evidence, audit logs, and HTML reports until recovery validation is complete.\n'

    printf "\n## Plan-Only And Provider-Specific Scenarios\n\n"
    printf "Some scenarios intentionally produce runbook/evidence instead of directly changing infrastructure. This is by design when the safe action depends on storage provider, Grid/root privileges, OCI control-plane boundaries, load balancers, GoldenGate deployment names, application client behavior, or a formal change window.\n\n"
    printf "| Scenario family | Examples | Public expectation |\n"
    printf "| --- | --- | --- |\n"
    printf '%s\n' '| ASM/GI/FEX/ACFS storage | `46`, `47`, `48`, `49`, `72` | Plan-only or provider-aware until redundant lab disks, failgroups, OCR/voting recovery, and rollback are explicitly approved. |'
    printf '%s\n' '| Data Guard role transition | `52`, `54`, `66`, `85`, `86` | Broker/FSFO/switchover/failback evidence and runbooks first; role transitions remain operator-approved. |'
    printf '%s\n' '| RAC network/service infrastructure | `70`, selected `83`, `84`, `87` | Validate services/FAN/AC/TAC metadata; client replay and VIP/notification disruption need application evidence and approval. |'
    printf '%s\n' '| PDB PITR and lifecycle rollback | `88`, `89`, `90` | Generate evidence and templates; actual PDB PITR, GRP flashback, patch rollback, and resetlogs remain change-window actions. |'
    printf '%s\n' '| Exadata | `EXA01`-`EXA04` | Requires Exadata tooling, cell/storage evidence, and supportable lab procedures; generic hosts remain readiness-only. |'
    printf '%s\n' '| OCI Base Database | `OCI01`-`OCI05` | Requires OCI CLI/profile/OCIDs and approved cloud-control-plane scope; network/security-list changes are not guessed. |'
    printf '%s\n' '| GoldenGate | `GG01`-`GG04` | Requires deployment-specific Extract/Replicat/trail targets, lag thresholds, and resync runbooks. |'

    printf "\n## Autonomous Database Differences\n\n"
    printf "Autonomous Database does not expose host-level files, ASM disks, control files, redo members, password files, SPFILEs, or ORACLE_HOME for destructive manipulation. ADB scenarios use a separate coverage model focused on logical/user-error recovery, PITR/clone readiness, wallet/connectivity, private endpoints, IAM, Object Storage, Autonomous Data Guard, resource pressure, Database Actions, APEX, and application access-path checks. OCI metadata checks require a configured OCI CLI/profile and the relevant OCIDs.\n"

    printf "\n## Licensing And Support Sensitivity\n\n"
    printf "CrashSimulator can detect and report signals for features such as RAC, Active Data Guard, Application Continuity/TAC, Diagnostics/Tuning-related evidence, TDE, Exadata, GoldenGate, and OCI services, but it does not validate license entitlement or support contracts. Confirm licensing and supportability with Oracle documentation, contracts, and authorized advisors before relying on a feature in production.\n"

    printf "\n## Evidence And MAA Claims\n\n"
    printf -- '- Treat installed/configured components as candidate capabilities until measured drills prove the service level.\n'
    printf -- '- Do not claim zero data loss without protection mode, synchronous transport/commit behavior, standby receive/apply state, and tested transition evidence.\n'
    printf -- '- Do not claim near-zero downtime without service placement, FAN/ONS, AC/TAC or client retry evidence, draining/replay behavior, and measured outage timing.\n'
    printf -- '- Use `--resilience-scorecard`, MAA reports, and scenario lifecycle/readiness reports as evidence summaries, not as formal certification.\n'

    printf "\n## Recommended New-User Order\n\n"
    printf '```bash\n'
    printf "./%s --show-config\n" "$PROGRAM"
    printf "./%s --validate-config\n" "$PROGRAM"
    printf "./%s --doctor --html\n" "$PROGRAM"
    printf "./%s --discover\n" "$PROGRAM"
    printf "./%s --prepare-environment --dry-run --html\n" "$PROGRAM"
    printf "./%s --scenario-readiness-report --html\n" "$PROGRAM"
    printf "./%s --scenario-lifecycle-report --html\n" "$PROGRAM"
    printf "./%s --backup-report --html\n" "$PROGRAM"
    printf "./%s --runbook 6 --html\n" "$PROGRAM"
    printf "./%s --scenario 6 --dry-run\n" "$PROGRAM"
    printf '```\n'

    printf "\n## Safe Starter Scenario Ideas\n\n"
    printf -- '- Read-only/reporting: `--health-check`, `--config-report`, `--backup-report`, `--service-review`, `--maa-report`, `--resilience-scorecard`, `--apex-ords-report`, `--adb-readiness-report`.\n'
    printf -- '- Low-risk database drills after readiness passes: `6`/`31` tempfile loss, `11`/`36` disposable index rebuild, `43` disposable table loss, `63` controlled TEMP pressure.\n'
    printf -- '- RAC/Data Guard/application drills should start with readiness/reporting scenarios before service relocation, apply/transport lag, switchover/failback, or client replay tests.\n'
  } >"$report_file" || die "Unable to write public limitations page: $report_file"

  cp "$report_file" "$latest_file" 2>/dev/null || true
  if [[ -d "$(dirname "$docs_file")" ]]; then
    cp "$report_file" "$docs_file" 2>/dev/null || true
  fi
  echo "Public limitations page generated: ${report_file}"
  echo "Latest public limitations page: ${latest_file}"
  [[ -f "$docs_file" ]] && echo "Documentation copy: ${docs_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
}

register_scenario() {
  local id="$1"
  local title="$2"
  local group="$3"
  local scope="$4"
  local impact="$5"
  local requires="$6"
  local handler="$7"
  local notes="$8"
  SCENARIO_IDS+=("$id")
  SCENARIO_TITLE["$id"]="$title"
  SCENARIO_GROUP["$id"]="$group"
  SCENARIO_SCOPE["$id"]="$scope"
  SCENARIO_IMPACT["$id"]="$impact"
  SCENARIO_REQUIRES["$id"]="$requires"
  SCENARIO_HANDLER["$id"]="$handler"
  SCENARIO_NOTES["$id"]="$notes"
}

register_scenarios() {
  register_scenario "1"  "Loss of one control file"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_control_one"       "Renames one control file and optionally aborts the target instance."
  register_scenario "2"  "Loss of all control files"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_control_all"       "Renames all control files and optionally aborts the target instance."
  register_scenario "3"  "Loss of one member from current redo group"         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_redo_member_one"   "Targets one member of the current redo group."
  register_scenario "4"  "Loss of all members from current redo group"        "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_current_redo_all"  "Targets all members of the current redo group."
  register_scenario "5"  "Loss of one non-system datafile"                   "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_non_system_one"    "Does not assume USERS exists."
  register_scenario "6"  "Loss of one temporary file"                        "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_temp_one"          "Targets a database temporary file."
  register_scenario "7"  "Loss of one SYSTEM datafile"                       "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_system_one"        "High-impact SYSTEM datafile scenario."
  register_scenario "8"  "Loss of one UNDO datafile"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_undo_one"          "Targets an online UNDO tablespace file."
  register_scenario "9"  "Loss of a read-only tablespace"                    "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_readonly_tbs"      "Targets all files in one read-only tablespace."
  register_scenario "10" "Loss of an index-only tablespace"                  "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_indexonly_tbs"     "Targets a tablespace with indexes and no tables."
  register_scenario "11" "Drop non-unique indexes outside Oracle schemas"     "Logical"    "CDB/non-CDB" "logical"      "primary"           "scenario_drop_indexes"      "Logical object loss for rebuild practice."
  register_scenario "12" "Loss of a non-system tablespace"                   "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_non_system_tbs"    "Targets all files in one non-system permanent tablespace."
  register_scenario "13" "Loss of a temporary tablespace"                    "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_temp_tbs"          "Targets all files in one temporary tablespace."
  register_scenario "14" "Loss of SYSTEM tablespace"                         "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_system_tbs"        "Targets all SYSTEM datafiles."
  register_scenario "15" "Loss of UNDO tablespace"                           "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_undo_tbs"          "Targets all files in one UNDO tablespace."
  register_scenario "16" "Loss of password file"                             "Config"     "CDB/non-CDB" "destructive" "primary"           "scenario_password_file"     "Uses srvctl metadata where available; falls back to ORACLE_HOME/dbs."
  register_scenario "17" "Loss of all datafiles"                             "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_all_datafiles"     "Very high-impact full database restore practice."
  register_scenario "18" "Loss of one member from multiplexed redo group"     "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_redo_member_one"   "Requires a group with more than one member."
  register_scenario "19" "Loss of all inactive redo groups"                  "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_inactive_redo_all" "Targets inactive redo groups."
  register_scenario "20" "Loss of all active redo groups"                    "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_active_redo_all"   "Switches logfile first, then targets active groups."
  register_scenario "21" "Loss of all current redo group members"            "Core"       "CDB/non-CDB" "destructive" "primary"           "scenario_current_redo_all"  "Targets current redo group members."
  register_scenario "22" "Datafile header corruption"                        "Corrupt"    "CDB/non-CDB" "destructive" "primary"           "scenario_file_header_corrupt" "Overwrites one block in a SYSTEM datafile."
  register_scenario "23" "Control file corruption"                           "Corrupt"    "CDB/non-CDB" "destructive" "primary"           "scenario_control_corrupt"   "Overwrites bytes in all control files."
  register_scenario "24" "Redo log corruption"                               "Corrupt"    "CDB/non-CDB" "destructive" "primary"           "scenario_redo_corrupt"      "Overwrites bytes in active redo members."
  register_scenario "25" "Loss of RMAN backup pieces"                        "Backup"     "CDB/non-CDB" "destructive" "any"               "scenario_rman_backups"      "Targets backup pieces known in V\$BACKUP_PIECE."
  register_scenario "26" "Loss of SPFILE"                                    "Config"     "CDB/non-CDB" "destructive" "primary"           "scenario_spfile"            "Targets the active SPFILE."
  register_scenario "27" "Loss of SQL*Net config files"                      "Config"     "CDB/non-CDB" "destructive" "any"               "scenario_sqlnet"            "Targets listener.ora, tnsnames.ora, sqlnet.ora if present."
  register_scenario "28" "Loss of ORACLE_HOME"                               "Config"     "CDB/non-CDB" "destructive" "any"               "scenario_oracle_home"       "Renames ORACLE_HOME; lab only."
  register_scenario "29" "Loss of FRA destination"                           "Backup"     "CDB/non-CDB" "destructive" "primary"           "scenario_fra"               "Renames configured FRA destination."
  register_scenario "30" "PDB loss of one non-system datafile"               "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_non_system_one" "Requires --pdb."
  register_scenario "31" "PDB loss of one temporary file"                    "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_temp_one"      "Requires --pdb."
  register_scenario "32" "PDB loss of one SYSTEM datafile"                   "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_system_one"    "Requires --pdb."
  register_scenario "33" "PDB loss of one UNDO datafile"                     "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_undo_one"      "Requires local undo and --pdb."
  register_scenario "34" "PDB loss of read-only tablespace"                  "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_readonly_tbs"  "Requires --pdb."
  register_scenario "35" "PDB loss of index-only tablespace"                 "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_indexonly_tbs" "Requires --pdb."
  register_scenario "36" "PDB drop non-unique indexes"                       "PDB"        "PDB"        "logical"      "cdb,pdb,primary"   "scenario_pdb_drop_indexes"  "Requires --pdb."
  register_scenario "37" "PDB loss of non-system tablespace"                 "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_non_system_tbs" "Requires --pdb."
  register_scenario "38" "PDB loss of temporary tablespace"                  "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_temp_tbs"      "Requires --pdb."
  register_scenario "39" "PDB loss of SYSTEM tablespace"                     "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_system_tbs"    "Requires --pdb."
  register_scenario "40" "PDB loss of UNDO tablespace"                       "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_undo_tbs"      "Requires --pdb."
  register_scenario "41" "PDB loss of all datafiles"                         "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_all_datafiles" "Requires --pdb."
  register_scenario "42" "PDB SYSTEM file header corruption"                 "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_pdb_file_header_corrupt" "Requires --pdb."
  register_scenario "43" "PDB loss of one user table"                        "PDB"        "PDB"        "logical"      "cdb,pdb,primary"   "scenario_pdb_drop_table"    "Requires --pdb."
  register_scenario "44" "PDB loss of one user schema"                       "PDB"        "PDB"        "logical"      "cdb,pdb,primary"   "scenario_pdb_drop_schema"   "Requires --pdb."
  register_scenario "45" "Drop selected PDB including datafiles"             "PDB"        "PDB"        "destructive" "cdb,pdb,primary"   "scenario_drop_pdb"          "Requires --pdb."
  register_scenario "46" "ASM/FEX data storage unavailable"                  "ASM"        "ASM/FEX"    "destructive" "asm"               "scenario_asm_diskgroup_unavailable" "Plans ASM disk group or FEX/ACFS managed-storage outage practice; execution requires a provider-aware handler."
  register_scenario "47" "OCR loss or restore drill"                         "GI"         "Cluster"    "destructive" "gi"                "scenario_ocr_restore_drill" "Plans OCR backup/restore practice; execution requires root/Grid procedure approval."
  register_scenario "48" "Voting disk loss or restore drill"                 "GI"         "Cluster"    "destructive" "gi"                "scenario_voting_disk_drill" "Plans voting disk replacement practice; execution requires root/Grid procedure approval."
  register_scenario "49" "ASM/FEX SPFILE loss"                              "ASM"        "ASM/FEX"    "destructive" "asm"               "scenario_asm_spfile_loss"   "Plans ASM or FEX/ACFS managed SPFILE loss practice; execution requires a provider-aware handler."
  register_scenario "50" "Standby managed recovery cancelled"                "DataGuard"  "Standby"    "logical"      "standby"           "scenario_standby_apply_cancel" "For physical standby apply practice."
  register_scenario "51" "Primary transport destination deferred"            "DataGuard"  "Primary"    "logical"      "primary,dg"        "scenario_primary_transport_defer" "Defers the first remote archive destination."
  register_scenario "52" "Data Guard broker configuration unavailable"       "DataGuard"  "DG"         "logical"      "dg"                "scenario_dg_broker_config_unavailable" "Plan-only broker outage drill with SQL/DGMGRL evidence."
  register_scenario "53" "Active Data Guard read-only session pressure"      "ADG"        "Standby"    "logical"      "standby"           "scenario_adg_readonly_session_pressure" "Read-only ADG pressure readiness evidence for READ ONLY WITH APPLY standbys."
  register_scenario "54" "Snapshot standby conversion practice"              "DataGuard"  "Standby"    "logical"      "standby"           "scenario_snapshot_standby_conversion_practice" "Plan-only snapshot-standby conversion readiness evidence."
  register_scenario "55" "RAC abort one instance"                            "RAC"        "RAC"        "destructive" "rac"               "scenario_rac_abort_instance" "Uses srvctl where available."
  register_scenario "56" "RAC service relocation failure practice"           "RAC"        "RAC"        "logical"      "rac"               "scenario_rac_service_relocation" "Relocates a singleton service when possible, or stop/start validates an all-instances service."
  register_scenario "57" "Listener config unavailable"                       "Network"    "CDB/non-CDB" "destructive" "any"               "scenario_sqlnet"            "Alias for network file loss."
  register_scenario "58" "TDE wallet or keystore unavailable"                "Security"   "CDB/non-CDB" "destructive" "primary"           "scenario_tde_wallet"        "Renames detected wallet root if configured."
  register_scenario "59" "Missing archived redo log"                         "Backup"     "CDB/non-CDB" "destructive" "primary"           "scenario_archivelog_loss"   "Targets one archived log known to the control file."
  register_scenario "60" "Recovery catalog unavailable"                      "Backup"     "External"   "logical"      "any"               "scenario_recovery_catalog_unavailable" "Validates catalog connectivity and NOCATALOG fallback behavior."
  register_scenario "61" "FRA reaches critical utilization"                  "Backup"     "CDB/non-CDB" "destructive" "primary"           "scenario_fra_full"          "Safely simulates FRA pressure by shrinking DB_RECOVERY_FILE_DEST_SIZE near current usage."
  register_scenario "62" "Missing required archived log during recovery"      "Backup"     "CDB/non-CDB" "destructive" "primary"           "scenario_required_archivelog_recovery_gap" "Targets one available archived log and generates recovery-decision evidence."
  register_scenario "63" "TEMP tablespace exhaustion"                        "Core"       "CDB/non-CDB" "logical"      "primary"           "scenario_temp_exhaustion"   "Runs a controlled disposable TEMP-consuming workload; optional --pdb context is supported."
  register_scenario "64" "RTO validation drill"                              "Compliance" "CDB/non-CDB" "logical"      "any"               "scenario_rto_validation"    "Read-only report comparing latest recovery manifest timing to supplied RTO objectives."
  register_scenario "65" "RPO validation drill"                              "Compliance" "CDB/non-CDB" "logical"      "any"               "scenario_rpo_validation"    "Read-only report estimating recoverable-data window from archived redo, backups, and DG evidence."
  register_scenario "66" "FSFO observer unavailable"                         "DataGuard"  "DG"         "logical"      "dg"                "scenario_fsfo_observer_unavailable" "Plans observer outage practice and captures broker/SQL FSFO evidence."
  register_scenario "67" "Data Guard apply lag exceeds SLA"                  "DataGuard"  "Standby"    "logical"      "standby"           "scenario_dg_apply_lag"      "Pauses standby apply to create measurable lag, then recovery restarts apply."
  register_scenario "68" "Data Guard transport network partition"            "DataGuard"  "Primary"    "logical"      "primary,dg"        "scenario_dg_transport_partition" "Defers one remote standby archive destination to simulate transport isolation."
  register_scenario "69" "Standby redo log misconfiguration review"          "DataGuard"  "DG"         "logical"      "dg"                "scenario_standby_redo_log_misconfig" "Read-only SRL sizing/count review against online redo threads."
  register_scenario "70" "RAC VIP relocation drill"                          "RAC"        "RAC"        "logical"      "rac,gi"            "scenario_rac_vip_relocation" "Plans VIP relocation and client survivability validation."
  register_scenario "71" "RAC service placement failure"                     "RAC"        "RAC"        "logical"      "rac"               "scenario_rac_service_placement_failure" "Stops/starts one running service on an instance to validate placement recovery."
  register_scenario "72" "ASM/FEX storage component failure"                 "ASM"        "ASM/FEX"    "destructive" "asm"               "scenario_asm_single_disk_failure" "Plans single-disk failure for redundant ASM disk groups or provider-managed FEX/ACFS storage-component review."
  register_scenario "73" "ORDS service unavailable"                          "APEX/ORDS"  "Application" "logical"     "any"               "scenario_ords_service_unavailable" "Stops the ORDS systemd service when OS service control is available."
  register_scenario "74" "ORDS configuration unavailable"                    "APEX/ORDS"  "Application" "destructive" "any"               "scenario_ords_config_unavailable" "Renames ORDS config only when the config directory is writable; otherwise plan-only."
  register_scenario "75" "ORDS database pool misconfiguration"               "APEX/ORDS"  "Application" "logical"     "any"               "scenario_ords_pool_misconfiguration" "Reversible ORDS pool service-name misconfiguration drill when service restart privileges are approved."
  register_scenario "76" "APEX/ORDS runtime account locked"                  "APEX/ORDS"  "Application" "logical"     "any"               "scenario_apex_runtime_account_locked" "Locks an available APEX/ORDS runtime account and validates unlock recovery."
  register_scenario "77" "APEX static resources unavailable"                 "APEX/ORDS"  "Application" "destructive" "any"               "scenario_apex_static_resources_unavailable" "Renames APEX images/static directory when explicitly configured and writable."
  register_scenario "78" "APEX application availability validation after recovery" "APEX/ORDS" "Application" "logical" "any"         "scenario_apex_application_availability_validation" "Read-only ORDS/APEX smoke evidence after database/PDB recovery."
  register_scenario "79" "ORDS node unavailable behind load balancer"         "APEX/ORDS"  "Application" "logical"     "any"               "scenario_ords_lb_node_unavailable" "Stops local ORDS service and validates optional load-balancer URL."
  register_scenario "80" "APEX session continuity test"                      "APEX/ORDS"  "Application" "logical"     "any"               "scenario_apex_session_continuity" "Read-only APEX/ORDS continuity evidence, with optional seeded browser-session driver for full validation."
  register_scenario "81" "APEX mail queue and configuration validation"       "APEX/ORDS"  "Application" "logical"     "any"               "scenario_apex_mail_config_validation" "Read-only SMTP/wallet/ACL evidence for notification recovery readiness."
  register_scenario "82" "APEX upgrade or patch rollback readiness"           "APEX/ORDS"  "Application" "logical"     "any"               "scenario_apex_patch_rollback_readiness" "Read-only pre/post APEX version, object, and runtime-account evidence."
  register_scenario "83" "Application Continuity replay validation"           "Services"   "Application" "logical"     "any"               "scenario_ac_tac_replay_validation" "Validates AC/TAC service metadata and plans replay-safe client drill evidence."
  register_scenario "84" "FAN notification unavailable"                       "Services"   "RAC/GI"      "logical"     "rac,gi"            "scenario_fan_ons_unavailable" "Captures FAN/ONS/service evidence and plans notification outage validation."
  register_scenario "85" "Planned Data Guard switchover"                      "DataGuard"  "DG"          "logical"     "dg"                "scenario_dg_switchover_drill" "Plan-only DGMGRL/SQL readiness drill for planned switchover."
  register_scenario "86" "Data Guard failback rehearsal"                      "DataGuard"  "DG"          "logical"     "dg"                "scenario_dg_failback_rehearsal" "Plan-only failback/reinstate readiness drill after failover or switchover."
  register_scenario "87" "Role-based service validation"                      "Services"   "RAC/DG"      "logical"     "rac"               "scenario_role_based_service_validation" "Read-only srvctl/SQL evidence for PRIMARY and STANDBY role-scoped services."
  register_scenario "88" "PDB point-in-time recovery drill"                   "PDB"        "PDB"        "logical"     "cdb,pdb,primary"   "scenario_pdb_pitr_drill" "Generates RMAN PDB PITR validation/runbook evidence; execution remains operator-approved."
  register_scenario "89" "Guaranteed restore point rollback"                  "Recovery"   "CDB/non-CDB" "logical"     "primary"           "scenario_guaranteed_restore_point_drill" "Validates Flashback/GRP posture and generates rollback runbook evidence."
  register_scenario "90" "Database patch rollback readiness"                  "Lifecycle"  "CDB/non-CDB" "logical"     "primary"           "scenario_database_patch_rollback_readiness" "Read-only patch fallback readiness review for backups, GRP, Data Guard, and services."
  register_scenario "EXA01" "Exadata cell failure review"                     "Exadata"    "Platform"   "logical"     "any"               "scenario_exadata_cell_failure_review" "Read-only Exadata cell/storage evidence when Exadata tooling is present; otherwise plan-only."
  register_scenario "EXA02" "Exadata storage server outage"                   "Exadata"    "Platform"   "logical"     "any"               "scenario_exadata_storage_server_outage" "Plan-only storage-server outage runbook with cellcli/exachk evidence hooks."
  register_scenario "EXA03" "Exadata Smart Scan validation"                   "Exadata"    "Platform"   "logical"     "any"               "scenario_exadata_smart_scan_validation" "Read-only Smart Scan readiness and validation planning."
  register_scenario "EXA04" "Exadata Flash Cache failure"                     "Exadata"    "Platform"   "logical"     "any"               "scenario_exadata_flash_cache_failure" "Plan-only Flash Cache failure/recovery evidence and runbook."
  register_scenario "OCI01" "OCI Base DB backup policy validation"            "OCI DB"     "Cloud"      "logical"     "any"               "scenario_oci_db_backup_policy_validation" "Read-only OCI/DB backup-policy posture and DBaaS backup evidence."
  register_scenario "OCI02" "OCI cross-region backup recovery"                "OCI DB"     "Cloud"      "logical"     "any"               "scenario_oci_cross_region_backup_recovery" "Plan-only cross-region backup restore validation drill."
  register_scenario "OCI03" "OCI database system failover"                    "OCI DB"     "Cloud"      "logical"     "any"               "scenario_oci_db_system_failover" "Plan-only DB system failure/recovery evidence for OCI Base DB."
  register_scenario "OCI04" "OCI VCN connectivity loss"                       "OCI DB"     "Cloud"      "logical"     "any"               "scenario_oci_vcn_connectivity_loss" "Read-only network-context evidence and plan-only VCN connectivity drill."
  register_scenario "OCI05" "OCI NSG misconfiguration"                        "OCI DB"     "Cloud"      "logical"     "any"               "scenario_oci_nsg_misconfiguration" "Plan-only NSG/security-list misconfiguration validation with OCI evidence hooks."
  register_scenario "GG01" "GoldenGate Extract stopped"                       "GoldenGate" "Replication" "logical"    "any"               "scenario_goldengate_extract_stopped" "Read-only GoldenGate deployment/process evidence and plan-only Extract stop drill."
  register_scenario "GG02" "GoldenGate Replicat stopped"                      "GoldenGate" "Replication" "logical"    "any"               "scenario_goldengate_replicat_stopped" "Read-only GoldenGate deployment/process evidence and plan-only Replicat stop drill."
  register_scenario "GG03" "GoldenGate lag exceeds SLA"                       "GoldenGate" "Replication" "logical"    "any"               "scenario_goldengate_lag_sla" "Read-only lag evidence hooks and SLA runbook for GoldenGate."
  register_scenario "GG04" "GoldenGate trail corruption"                      "GoldenGate" "Replication" "destructive" "any"              "scenario_goldengate_trail_corruption" "Plan-only trail corruption/loss recovery runbook; no file changes are automated."
}

register_adb_scenario() {
  local id="$1"
  local title="$2"
  local area="$3"
  local validation="$4"
  local recovery="$5"
  local helper="$6"

  ADB_SCENARIO_IDS+=("$id")
  ADB_SCENARIO_TITLE["$id"]="$title"
  ADB_SCENARIO_AREA["$id"]="$area"
  ADB_SCENARIO_VALIDATION["$id"]="$validation"
  ADB_SCENARIO_RECOVERY["$id"]="$recovery"
  ADB_SCENARIO_HELPER["$id"]="$helper"
}

register_adb_scenarios() {
  [[ "${#ADB_SCENARIO_IDS[@]}" -eq 0 ]] || return "$SUCCESS"

  register_adb_scenario "ADB01" "Drop critical application table" "Logical recovery" "Live SQL connection, disposable lab table, flashback eligibility, clone/export fallback." "Flashback Table, PITR clone, Data Pump/object merge, application validation." "Future seeded logical helper."
  register_adb_scenario "ADB02" "Drop application schema" "Logical recovery" "Live SQL connection, disposable schema, grants/object inventory, export or clone/PITR path." "Clone/export recovery, user/grant restoration, application validation." "Plan/runbook first; destructive helper pending."
  register_adb_scenario "ADB03" "Mass DELETE without WHERE clause" "Logical recovery" "Live SQL connection, disposable lab table, before/after row counts, flashback query window." "Flashback Query/Table, clone comparison, data merge." "Future seeded logical helper."
  register_adb_scenario "ADB04" "Incorrect UPDATE corrupts business data" "Logical recovery" "Live SQL connection, disposable lab table, before image evidence, validation query." "Flashback Versions Query, object restore, data comparison." "Future seeded logical helper."
  register_adb_scenario "ADB05" "Recover from clone" "Clone/PITR" "OCI metadata for clone permissions, source database, timestamp, compartment, and restore target." "Create clone, validate objects/application, merge recovered data." "OCI control-plane helper pending."
  register_adb_scenario "ADB06" "Point-in-time recovery drill" "Clone/PITR" "OCI PITR or clone-to-time window, backup retention, timestamp selection, and validation target." "Measure RTO/RPO, validate clone, extract/merge recovered data." "OCI control-plane helper pending."
  register_adb_scenario "ADB07" "Validate backup recoverability" "Backup readiness" "OCI backup retention, latest backup, PITR window, restore/clone capability, and evidence freshness." "Evidence-only or clone-based restore validation." "OCI control-plane helper pending."
  register_adb_scenario "ADB08" "Expired or rotated client wallet" "Connectivity" "Wallet directory, aliases, rotation owner, application distribution points, and reconnect test path." "Download new wallet, update clients, reconnect, smoke-test applications." "Plan/runbook; reconnect helper pending."
  register_adb_scenario "ADB09" "Private endpoint connectivity loss" "Network" "Private endpoint DNS/label, bastion path, routes, NSGs/security lists, and approved fault boundary." "Restore network/DNS/security-list path and validate client reconnect." "Plan/runbook; network evidence helper pending."
  register_adb_scenario "ADB10" "Connection pool saturation" "Resource limits" "Live SQL connection, approved workload limits, service-level target, and application retry/backoff boundaries." "Tune pool limits, retries, service class, and application backoff." "Plan/runbook; workload helper pending."
  register_adb_scenario "ADB11" "Resource Manager or concurrency pressure" "Resource limits" "Live SQL connection, approved workload generator, resource plan/service class, and measurable threshold." "Review service class, scaling posture, consumer limits, workload scheduling." "Plan/runbook; workload helper pending."
  register_adb_scenario "ADB12" "Cross-region DR validation" "Autonomous Data Guard" "OCI Autonomous Data Guard metadata, peer/standby region, lag, failover eligibility, and app reconnect path." "Failover validation, reconnect, RTO/RPO measurement, fallback plan." "OCI/ADG helper pending."
  register_adb_scenario "ADB13" "Autonomous Data Guard role transition" "Autonomous Data Guard" "OCI ADG role, region, lag, switchover/failover eligibility, URL/service validation." "Switchover/failover and fallback runbook." "OCI/ADG helper pending."
  register_adb_scenario "ADB14" "IAM administrator access misconfiguration" "OCI/IAM" "Read-only IAM policy/group/compartment evidence, break-glass account, and approved test boundary." "Restore IAM access and validate admin and automation access." "Plan/runbook; IAM helper pending."
  register_adb_scenario "ADB15" "Object Storage export dependency unavailable" "Object Storage" "Bucket, credential, DBMS_CLOUD object, network path, IAM policy, and export/import procedure evidence." "Restore bucket/policy/credential/network access; validate export/import." "Plan/runbook; object-storage helper pending."
  register_adb_scenario "ADB16" "Database Actions unavailable" "Application access" "Database Actions URL, SQL probe, OCI service state, wallet/connectivity, and administrator access evidence." "Restore Database Actions/ORDS access path, validate SQL/API access, and capture application smoke evidence." "Plan/runbook; URL smoke helper pending."
  register_adb_scenario "ADB17" "APEX workspace unavailable" "APEX" "APEX URL, workspace/application inventory, SQL probe, runtime users, and browser/login smoke-test path." "Restore workspace/application access, validate runtime users and application login." "Plan/runbook; browser helper pending."
  register_adb_scenario "ADB18" "Cross-region clone validation" "Clone/PITR" "OCI metadata for supported clone regions, backup retention, target compartment/region, and validation timestamp." "Create cross-region clone, validate data/application access, measure elapsed time, and clean up clone." "OCI control-plane helper pending."
  register_adb_scenario "ADB19" "Wallet distribution drift" "Connectivity" "Wallet age, local bundle path, tnsnames aliases, application distribution inventory, and reconnect smoke path." "Refresh wallet distribution, rotate credentials where required, and validate all client pools." "Plan/runbook; wallet inventory helper pending."
  register_adb_scenario "ADB20" "OCI IAM token expiration" "OCI/IAM" "OCI CLI auth mode/profile, token/session freshness, break-glass path, and automation credential ownership." "Refresh/rotate OCI auth, validate control-plane access, and update automation secrets." "Plan/runbook; OCI auth helper pending."
}

adb_scenario_exists() {
  local id="$1"
  [[ -n "${ADB_SCENARIO_TITLE[$id]:-}" ]]
}

adb_latest_evidence_file() {
  local latest=""

  if [[ -f "${LOG_DIR}/crashsim_adb_readiness_latest.evidence" ]]; then
    latest="${LOG_DIR}/crashsim_adb_readiness_latest.evidence"
  else
    latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_adb_readiness_*.evidence' 2>/dev/null | sort | tail -n 1)"
  fi
  [[ -n "$latest" && -f "$latest" ]] || return "$FAIL"
  printf "%s\n" "$latest"
}

adb_load_latest_evidence() {
  local evidence_file
  evidence_file="$(adb_latest_evidence_file 2>/dev/null || true)"
  [[ -n "$evidence_file" ]] || return "$FAIL"
  parse_adb_evidence_file "$evidence_file"
}

adb_sql_probe_ok() {
  [[ "$(adb_value connect_status UNKNOWN)" == "OK" ]]
}

adb_sql_probe_reason() {
  local status reason
  status="$(adb_value connect_status UNKNOWN)"
  reason="$(adb_value connect_reason "")"
  if [[ "$status" == "OK" ]]; then
    printf "Live SQL probe connected to %s (%s/%s)." "$(adb_value db_name UNKNOWN)" "$(adb_value open_mode UNKNOWN)" "$(adb_value database_role UNKNOWN)"
  elif [[ -n "$reason" ]]; then
    if [[ "$reason" =~ [.!?]$ ]]; then
      printf "Live SQL probe status %s: %s" "$status" "$reason"
    else
      printf "Live SQL probe status %s: %s." "$status" "$reason"
    fi
  else
    printf "Live SQL probe has not connected yet. Run the ADB readiness report after configuring wallet/descriptor and password environment variables."
  fi
}

adb_control_plane_ready() {
  [[ -n "$ADB_OCID" ]] || return "$FAIL"
  command -v oci >/dev/null 2>&1 || return "$FAIL"
}

adb_wallet_ready() {
  if [[ -n "$ADB_WALLET_DIR" && -d "$ADB_WALLET_DIR" && -f "${ADB_WALLET_DIR}/tnsnames.ora" ]]; then
    return "$SUCCESS"
  fi
  adb_sql_probe_ok
}

adb_private_endpoint_ready() {
  [[ -n "$ADB_PRIVATE_ENDPOINT" ]]
}

adb_scenario_readiness() {
  local id="$1"
  local status_var="$2"
  local reason_var="$3"
  local readiness_status readiness_reason

  case "$id" in
    ADB01|ADB03|ADB04)
      if adb_sql_probe_ok; then
        readiness_status="RUNNABLE AFTER LAB SEED"
        readiness_reason="Live SQL probe is healthy; seed disposable ADB lab objects before enabling execution helpers."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="$(adb_sql_probe_reason)"
      fi
      ;;
    ADB02)
      if adb_sql_probe_ok; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Live SQL probe is healthy; schema-drop automation remains manual until clone/export workflow helpers are added."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="$(adb_sql_probe_reason)"
      fi
      ;;
    ADB05|ADB06|ADB07)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="Latest ADB readiness evidence includes OCI metadata; clone, PITR, and backup posture can be validated from control-plane data."
      elif adb_control_plane_ready; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="ADB OCID and OCI CLI are configured; collect clone/PITR/backup metadata before execution."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure CRASHSIM_ADB_OCID and OCI CLI/profile to validate clone, PITR, and backup recoverability."
      fi
      ;;
    ADB08)
      if adb_wallet_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Wallet/client path evidence exists; use the runbook to test rotation and reconnect."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Configure an ADB wallet directory or working descriptor and run the readiness report."
      fi
      ;;
    ADB09)
      if adb_private_endpoint_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Private endpoint context is configured; validate DNS, routing, NSGs, and bastion path before any fault injection."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Set CRASHSIM_ADB_PRIVATE_ENDPOINT or use the menu context option to document the expected private endpoint path."
      fi
      ;;
    ADB10|ADB11)
      if adb_sql_probe_ok; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Live SQL probe is healthy; approved workload limits and application retry boundaries are still required."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="$(adb_sql_probe_reason)"
      fi
      ;;
    ADB12|ADB13)
      if adb_truthy_value oci_is_data_guard_enabled; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="OCI metadata reports Autonomous Data Guard enabled; verify role, lag, transition eligibility, and application reconnect path."
      elif [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="ADG DISABLED"
        readiness_reason="OCI metadata reports Autonomous Data Guard is not enabled for this ADB; enable ADG or document that DR is out of scope before ADB12/ADB13."
      elif adb_control_plane_ready; then
        readiness_status="OCI VALIDATION READY IF ADG ENABLED"
        readiness_reason="ADB OCID and OCI CLI are configured; run the readiness report to inspect Autonomous Data Guard metadata."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile and ADB OCID to inspect Autonomous Data Guard metadata."
      fi
      ;;
    ADB14)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Latest ADB readiness evidence includes OCI metadata; keep IAM checks read-only unless an approved IAM test boundary exists."
      elif adb_control_plane_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="OCI metadata access is configured; keep IAM checks read-only unless an approved IAM test boundary exists."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile and ADB OCID or compartment context to review IAM posture."
      fi
      ;;
    ADB15)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Latest ADB readiness evidence includes OCI metadata; add bucket, credential, DBMS_CLOUD, and network evidence before execution."
      elif adb_control_plane_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="OCI metadata access is configured; add bucket, credential, DBMS_CLOUD, and network evidence before execution."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile and ADB/compartment context to validate Object Storage dependencies."
      fi
      ;;
    ADB16)
      if [[ -n "$ADB_DATABASE_ACTIONS_URL" && ( "$(adb_value oci_metadata_status UNKNOWN)" == "OK" || "$(adb_value connect_status UNKNOWN)" == "OK" ) ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Database Actions URL and database/OCI evidence are available; add URL smoke checks before outage execution."
      elif [[ -n "$ADB_DATABASE_ACTIONS_URL" ]]; then
        readiness_status="CONFIG PARTIAL"
        readiness_reason="Database Actions URL is configured, but SQL/OCI readiness evidence is not fresh."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Set CRASHSIM_ADB_DATABASE_ACTIONS_URL and refresh the ADB readiness report."
      fi
      ;;
    ADB17)
      if [[ -n "$ADB_APEX_URL" && adb_sql_probe_ok ]]; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="APEX URL and live SQL probe are available; add workspace/application browser-smoke evidence before execution."
      elif [[ -n "$ADB_APEX_URL" ]]; then
        readiness_status="CONFIG PARTIAL"
        readiness_reason="APEX URL is configured, but live SQL probe evidence is not healthy or fresh."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Set CRASHSIM_ADB_APEX_URL and refresh SQL readiness evidence."
      fi
      ;;
    ADB18)
      if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="OCI metadata is available; verify supported clone regions, target compartment, timestamp, cost limits, and cleanup before creating a cross-region clone."
      elif adb_control_plane_ready; then
        readiness_status="OCI VALIDATION READY"
        readiness_reason="ADB OCID and OCI CLI are configured; run readiness to inspect clone region and backup retention evidence."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure CRASHSIM_ADB_OCID plus OCI CLI/profile before validating cross-region clone readiness."
      fi
      ;;
    ADB19)
      if adb_wallet_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="Wallet or working connect descriptor evidence exists; inventory application wallet distribution points before drift testing."
      else
        readiness_status="CONFIG NEEDED"
        readiness_reason="Configure ADB wallet directory or working descriptor before wallet drift validation."
      fi
      ;;
    ADB20)
      if adb_control_plane_ready; then
        readiness_status="PLAN/RUNBOOK"
        readiness_reason="OCI CLI/profile and ADB OCID are configured; validate auth mode, token freshness, and automation credential ownership."
      else
        readiness_status="OCI CONFIG NEEDED"
        readiness_reason="Configure OCI CLI/profile/auth mode and CRASHSIM_ADB_OCID before IAM token-expiration readiness."
      fi
      ;;
    *)
      readiness_status="UNKNOWN"
      readiness_reason="Unknown ADB scenario id."
      ;;
  esac

  printf -v "$status_var" "%s" "$readiness_status"
  printf -v "$reason_var" "%s" "$readiness_reason"
}

print_adb_scenario_catalog() {
  local id status reason evidence_file

  evidence_file="$(adb_latest_evidence_file 2>/dev/null || true)"
  if [[ -n "$evidence_file" ]]; then
    parse_adb_evidence_file "$evidence_file" || true
    echo "ADB scenario catalog using latest evidence: ${evidence_file}"
  else
    ADB_EVIDENCE=()
    echo "ADB scenario catalog using current configuration only. Run --adb-readiness-report for live SQL evidence."
  fi
  echo
  printf "%-6s %-30s %-28s %s\n" "ID" "Area" "Status" "Scenario"
  printf "%-6s %-30s %-28s %s\n" "------" "------------------------------" "----------------------------" "--------"
  for id in "${ADB_SCENARIO_IDS[@]}"; do
    adb_scenario_readiness "$id" status reason
    printf "%-6s %-30s %-28s %s\n" "$id" "${ADB_SCENARIO_AREA[$id]}" "$status" "${ADB_SCENARIO_TITLE[$id]}"
  done
}

print_adb_scenario_detail() {
  local id="$1"
  local status reason evidence_file

  id="$(printf "%s" "$id" | tr '[:lower:]' '[:upper:]')"
  adb_scenario_exists "$id" || die "Unknown ADB scenario id: $id"
  evidence_file="$(adb_latest_evidence_file 2>/dev/null || true)"
  [[ -n "$evidence_file" ]] && parse_adb_evidence_file "$evidence_file" || ADB_EVIDENCE=()
  adb_scenario_readiness "$id" status reason

  echo "Autonomous Database scenario detail"
  echo "Scenario: ${id} - ${ADB_SCENARIO_TITLE[$id]}"
  echo "Area: ${ADB_SCENARIO_AREA[$id]}"
  echo "Status: ${status}"
  echo "Reason: ${reason}"
  echo "Validation: ${ADB_SCENARIO_VALIDATION[$id]}"
  echo "Recovery focus: ${ADB_SCENARIO_RECOVERY[$id]}"
  echo "Execution helper: ${ADB_SCENARIO_HELPER[$id]}"
  echo "Evidence: ${evidence_file:-not available}"
  echo
  echo "Run --adb-readiness-report --html to refresh readiness evidence before a drill."
}

list_scenarios() {
  printf "%-6s %-12s %-13s %-12s %s\n" "ID" "Group" "Scope" "Impact" "Scenario"
  printf "%-6s %-12s %-13s %-12s %s\n" "------" "-----" "-----" "------" "--------"
  local id
  for id in "${SCENARIO_IDS[@]}"; do
    printf "%-6s %-12s %-13s %-12s %s\n" \
      "$id" \
      "${SCENARIO_GROUP[$id]}" \
      "${SCENARIO_SCOPE[$id]}" \
      "${SCENARIO_IMPACT[$id]}" \
      "${SCENARIO_TITLE[$id]}"
  done
}

scenario_exists() {
  local id="$1"
  [[ -n "${SCENARIO_TITLE[$id]:-}" ]]
}

pdb_exists() {
  local pdb="$1"
  local row name con_id open_mode
  for row in "${PDB_ROWS[@]}"; do
    IFS='|' read -r name con_id open_mode <<<"$row"
    if [[ "$name" == "$pdb" ]]; then
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

pdb_list_for_message() {
  local row name con_id open_mode
  for row in "${PDB_ROWS[@]}"; do
    IFS='|' read -r name con_id open_mode <<<"$row"
    printf "%s " "$name"
  done
}

select_pdb_if_needed() {
  if [[ "$DB_CDB" != "YES" ]]; then
    return "$FAIL"
  fi
  if [[ -n "$TARGET_PDB" ]]; then
    pdb_exists "$TARGET_PDB" ||
      die "PDB ${TARGET_PDB} was not found in this CDB. Available PDBs: $(pdb_list_for_message)"
    return "$SUCCESS"
  fi
  if [[ "${#PDB_ROWS[@]}" -eq 1 ]]; then
    TARGET_PDB="$(printf "%s" "${PDB_ROWS[0]}" | cut -d'|' -f1)"
    info "Using only available PDB: $TARGET_PDB"
    return "$SUCCESS"
  fi
  die "This scenario requires --pdb. Available PDBs: $(printf "%s " "${PDB_ROWS[@]}" | cut -d'|' -f1)"
}

check_requirements() {
  local id="$1"
  local requires="${SCENARIO_REQUIRES[$id]}"

  if scenario_requires_sqlplus_context "$id"; then
    if ! find_sqlplus_if_available; then
      die "Scenario $id requires database SQL*Plus context, but sqlplus was not found. Set ORACLE_HOME or SQLPLUS after the database is created or installed."
    fi
    discover_environment
  elif find_sqlplus_if_available; then
    discover_environment
  fi

  IFS=',' read -ra reqs <<<"$requires"
  local req
  for req in "${reqs[@]}"; do
    case "$req" in
      any|"") ;;
      primary)
        [[ "$DB_ROLE" == "PRIMARY" ]] || die "Scenario $id requires PRIMARY role. Current role: $DB_ROLE"
        ;;
      standby)
        [[ "$DB_ROLE" == *"STANDBY"* ]] || die "Scenario $id requires a standby role. Current role: $DB_ROLE"
        ;;
      dg)
        has_data_guard || die "Scenario $id requires Data Guard metadata."
        ;;
      cdb)
        [[ "$DB_CDB" == "YES" ]] || die "Scenario $id requires a CDB."
        ;;
      pdb)
        select_pdb_if_needed
        ;;
      rac)
        [[ "$INSTANCE_PARALLEL" == "YES" ||
           "$CLUSTER_TYPE" == "RAC" ||
           "$CLUSTER_TYPE" == "RACONE" ||
           "$CLUSTER_TYPE" == "RACONENODE" ||
           "$CLUSTER_TYPE" == "RAC_ONE_NODE" ||
           "$CLUSTER_TYPE" == "GI_SINGLE" ]] || die "Scenario $id requires RAC, RAC One Node, or a GI-managed database."
        ;;
      asm)
        storage_supports_gi_storage_planning ||
          die "Scenario $id requires ASM or GI-managed FEX/ACFS-style storage. Current storage: $STORAGE_TYPE"
        ;;
      gi)
        grid_tool_available crsctl || die "Scenario $id requires Grid Infrastructure commands. Set CRASHSIM_GRID_HOME or run with Grid Infrastructure tools in PATH."
        ;;
      *)
        die "Unknown requirement '$req' for scenario $id"
        ;;
    esac
  done
}

scenario_requires_sqlplus_context() {
  local id="$1"
  local requires=",${SCENARIO_REQUIRES[$id]:-},"

  case "$requires" in
    *",primary,"*|*",standby,"*|*",dg,"*|*",cdb,"*|*",pdb,"*|*",rac,"*|*",asm,"*)
      return "$SUCCESS"
      ;;
  esac

  return "$FAIL"
}

scenario_is_topology_compatible() {
  local id="$1"
  local requires="${SCENARIO_REQUIRES[$id]}"
  local handler="${SCENARIO_HANDLER[$id]}"
  local req
  local -a reqs

  scenario_exists "$id" || return "$FAIL"
  [[ "$handler" != "scenario_planned" ]] || return "$FAIL"
  case "$id" in
    25)
      [[ -n "$PIECE_HANDLE" || ( "$LOCAL_ONLY" == "1" && -n "$MAX_TARGETS" ) ]] || return "$FAIL"
      ;;
  esac

  IFS=',' read -ra reqs <<<"$requires"
  for req in "${reqs[@]}"; do
    case "$req" in
      any|"") ;;
      primary)
        [[ "$DB_ROLE" == "PRIMARY" ]] || return "$FAIL"
        ;;
      standby)
        [[ "$DB_ROLE" == *"STANDBY"* ]] || return "$FAIL"
        ;;
      dg)
        has_data_guard || return "$FAIL"
        ;;
      cdb)
        [[ "$DB_CDB" == "YES" ]] || return "$FAIL"
        ;;
      pdb)
        [[ "$DB_CDB" == "YES" ]] || return "$FAIL"
        [[ -n "$TARGET_PDB" || "${#PDB_ROWS[@]}" -eq 1 ]] || return "$FAIL"
        ;;
      rac)
        [[ "$INSTANCE_PARALLEL" == "YES" ||
           "$CLUSTER_TYPE" == "RAC" ||
           "$CLUSTER_TYPE" == "RACONE" ||
           "$CLUSTER_TYPE" == "RACONENODE" ||
           "$CLUSTER_TYPE" == "RAC_ONE_NODE" ||
           "$CLUSTER_TYPE" == "GI_SINGLE" ]] || return "$FAIL"
        ;;
      asm)
        storage_supports_gi_storage_planning || return "$FAIL"
        ;;
      gi)
        grid_tool_available crsctl || return "$FAIL"
        ;;
      *)
        return "$FAIL"
        ;;
    esac
  done
}

scenario_can_plan_randomly() {
  local id="$1"
  validate_scenario_can_run "$id" >/dev/null 2>&1
}

select_random_scenario() {
  discover_environment

  local candidates=()
  local all_candidates=()
  local id candidate_count index selected=""
  for id in "${SCENARIO_IDS[@]}"; do
    if scenario_is_topology_compatible "$id"; then
      candidates+=("$id")
    fi
  done
  all_candidates=("${candidates[@]}")

  candidate_count="${#candidates[@]}"
  [[ "$candidate_count" -gt 0 ]] ||
    die "No topology-compatible implemented scenarios were found for this environment."

  while [[ "${#candidates[@]}" -gt 0 ]]; do
    index=$((RANDOM % ${#candidates[@]}))
    id="${candidates[$index]}"
    candidates=("${candidates[@]:0:$index}" "${candidates[@]:$((index + 1))}")
    if scenario_can_plan_randomly "$id"; then
      selected="$id"
      break
    fi
  done

  [[ -n "$selected" ]] ||
    die "No topology-compatible scenarios could plan usable targets in this environment."

  SCENARIO_ID="$selected"

  echo "Aleatory scenario selected from ${candidate_count} topology-compatible scenarios after target planning checks:"
  echo "  ${SCENARIO_ID}: ${SCENARIO_TITLE[$SCENARIO_ID]}"
  echo "Topology: role=${DB_ROLE:-unknown}, cdb=${DB_CDB:-unknown}, storage=${STORAGE_TYPE:-unknown}, cluster=${CLUSTER_TYPE:-unknown}"
  if [[ -n "$TARGET_PDB" ]]; then
    echo "PDB target context: ${TARGET_PDB}"
  elif [[ "${SCENARIO_REQUIRES[$SCENARIO_ID]}" == *pdb* && "${#PDB_ROWS[@]}" -eq 1 ]]; then
    echo "PDB target context: only available PDB will be selected by requirement checks"
  fi
  if [[ "$VERBOSE" -eq 1 ]]; then
    echo "Candidate IDs: ${all_candidates[*]}"
  fi
  echo
}

run_random_scenario() {
  select_random_scenario
  run_scenario "$SCENARIO_ID"
}

has_data_guard() {
  if [[ "$DB_ROLE" != "PRIMARY" ]]; then
    return "$SUCCESS"
  fi
  local dg_file="$WORK_DIR/dg.env"
  sql_query "$dg_file" "
select count(*)
from v\$archive_dest
where target = 'STANDBY'
  and status <> 'INACTIVE';
"
  local count
  count="$(trim_blank_lines <"$dg_file" | head -n 1 | tr -d ' ')"
  [[ "${count:-0}" =~ ^[0-9]+$ && "${count:-0}" -gt 0 ]]
}

confirm_execution() {
  local id="$1"
  if [[ "$EXECUTE" -eq 0 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    require_destructive_lab_ack "scenario ${id} execution"
    return "$SUCCESS"
  fi

  local -a prompt_lines=(
    ""
    "About to execute scenario ${id}: ${SCENARIO_TITLE[$id]}"
    "Database: ${DB_UNIQUE_NAME} (${DB_ROLE}, ${DB_OPEN_MODE})"
  )
  if [[ -n "$TARGET_PDB" ]]; then
    prompt_lines+=("PDB: ${TARGET_PDB}")
  fi
  if [[ -n "$TARGET_SCHEMA" ]]; then
    prompt_lines+=("Schema: ${TARGET_SCHEMA}")
  fi
  prompt_lines+=("Type EXECUTE-${id} to continue:")
  confirm_show "${prompt_lines[@]}"
  local answer
  confirm_reply answer
  [[ "$answer" == "EXECUTE-${id}" ]] || die "Confirmation did not match. Aborting."
  require_destructive_lab_ack "scenario ${id} execution"
}

run_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"

  if validate_scenario_can_run "$id"; then
    echo "Validation: RUNNABLE - ${SCENARIO_VALIDATION_REASON}"
    echo
  else
    echo "Validation: NOT RUNNABLE"
    echo "Scenario ${id} is not possible to run at this moment."
    echo "Reason: ${SCENARIO_VALIDATION_REASON}"
    if [[ "$EXECUTE" -eq 1 || "$SCENARIO_VALIDATION_STATUS" != "PLAN_ONLY" ]]; then
      die "Scenario ${id} execution is blocked by readiness validation."
    fi
    echo "Continuing with dry-run planning only; execution will remain blocked until the validation blocker is resolved."
    echo
  fi

  check_requirements "$id"
  CURRENT_SCENARIO_ID="$id"
  RENAME_COUNT=0
  init_manifest "scenario" "$id"

  echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Group: ${SCENARIO_GROUP[$id]}"
  echo "Scope: ${SCENARIO_SCOPE[$id]}"
  echo "Impact: ${SCENARIO_IMPACT[$id]}"
  echo "Requires: ${SCENARIO_REQUIRES[$id]}"
  echo "Notes: ${SCENARIO_NOTES[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Manifest: ${MANIFEST_FILE}"
  echo

  print_recovery_runbook "$id"
  echo

  confirm_execution "$id"

  local handler="${SCENARIO_HANDLER[$id]}"
  "$handler" "$id"
  manifest_append "scenario_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

confirm_mode_execution() {
  local mode_name="$1"
  local id="$2"
  local token
  token="${mode_name}-${id}"

  if [[ "$EXECUTE" -eq 0 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    require_destructive_lab_ack "${mode_name,,} for scenario ${id}"
    return "$SUCCESS"
  fi

  local -a prompt_lines=(
    ""
    "About to execute ${mode_name,,} for scenario ${id}: ${SCENARIO_TITLE[$id]}"
    "Database: ${DB_UNIQUE_NAME:-unknown} (${DB_ROLE:-unknown}, ${DB_OPEN_MODE:-unknown})"
  )
  if [[ -n "$TARGET_PDB" ]]; then
    prompt_lines+=("PDB: ${TARGET_PDB}")
  fi
  prompt_lines+=("Type ${token} to continue:")
  confirm_show "${prompt_lines[@]}"
  local answer
  confirm_reply answer
  [[ "$answer" == "$token" ]] || die "Confirmation did not match. Aborting."
  require_destructive_lab_ack "${mode_name,,} for scenario ${id}"
}

require_destructive_lab_ack() {
  local action="$1"
  local answer

  [[ "$EXECUTE" -eq 1 ]] || return "$SUCCESS"
  [[ "${DESTRUCTIVE_LAB_ACK^^}" == "YES" ]] && return "$SUCCESS"

  if [[ "$ASSUME_YES" -eq 1 ]]; then
    die "${action} is blocked because destructive lab acknowledgement is not set. Set CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES or pass --accept-destructive-lab only in an approved non-production lab."
  fi

  echo
  echo "Public safety guardrail: ${action} must run only in an approved non-production lab."
  echo "Type LAB-APPROVED to confirm this environment is approved for destructive CrashSimulator execution:"
  read -r answer
  [[ "$answer" == "LAB-APPROVED" ]] || die "Lab acknowledgement did not match. Aborting."
}

supports_file_recovery_automation() {
  local id="$1"
  case "$id" in
    5|7|8|9|10|12|14|15|17|22|30|32|33|34|35|37|39|40|41|42) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

supports_recovery_automation() {
  local id="$1"
  case "$id" in
    1|2|3|4|5|6|7|8|9|10|12|13|14|15|16|17|18|19|20|21|22|23|24|25|26|27|30|31|32|33|34|35|37|38|39|40|41|42|50|51|55|56|57|58|59|61|62|67|68|71|73|74|75|76|77|79) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

scenario_validation_capability() {
  printf "Automated readiness validation"
}

scenario_protection_capability() {
  local id="$1"
  if supports_file_recovery_automation "$id"; then
    printf "Automated --protect RMAN backup"
    return "$SUCCESS"
  fi

  case "$id" in
    53|64|65|69|78|81|82)
      printf "Not required: read-only report"
      ;;
    *)
      if [[ "${SCENARIO_IMPACT[$id]}" == "logical" ]]; then
        printf "Not required: logical drill"
      else
        printf "Manual baseline/runbook"
      fi
      ;;
  esac
}

scenario_execution_capability() {
  local id="$1"
  if [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]]; then
    printf "Placeholder: manual lab design pending"
    return "$SUCCESS"
  fi

  case "$id" in
    28)
      printf "guarded manual-only external restore plan"
      ;;
    46|47|48|49|52|54|66|70|72|85|86|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
      printf "guarded plan-only evidence; external approved action"
      ;;
    53|64|65|69|78|80|81|82|87)
      printf "Automated read-only report"
      ;;
    83|84)
      printf "Automated evidence collection; approved client/provider action external"
      ;;
    *)
      printf "Automated dry-run/execute with guardrails"
      ;;
  esac
}

scenario_recovery_capability() {
  local id="$1"
  if supports_recovery_automation "$id"; then
    printf "Automated --recover helper"
    return "$SUCCESS"
  fi

  case "$id" in
    53|64|65|69|78|80|81|82|87)
      printf "Not required: read-only report"
      ;;
    11|36|43|44)
      printf "Manual logical restore/reseed runbook"
      ;;
    28|29|45|46|47|48|49|52|54|60|63|66|70|72|83|84|85|86|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
      printf "Manual/external runbook"
      ;;
    *)
      printf "Manual runbook"
      ;;
  esac
}

scenario_runbook_capability() {
  printf "Automated --runbook artifact"
}

scenario_evidence_capability() {
  local id="$1"
  case "$id" in
    80)
      printf "Markdown report, SQL evidence, optional browser screenshots/JSON, manifest, audit"
      ;;
    53|64|65|69|78|80|81|82)
      printf "Markdown report, SQL evidence, manifest, audit"
      ;;
    52|54)
      printf "Manifest, audit, SQL/DGMGRL readiness evidence, runbook"
      ;;
    *)
      printf "Manifest, audit, runbook; SQL/RMAN/report evidence when used"
      ;;
  esac
}

scenario_lifecycle_next_step() {
  local id="$1"
  if [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]]; then
    printf "Implement scenario handler and lab validation."
    return "$SUCCESS"
  fi
  if ! supports_recovery_automation "$id"; then
    case "$id" in
      53|64|65|69|78|80|81|82|87)
        printf "No recovery helper required; keep report evidence current."
        ;;
      52|54|66|70|72|83|84|85|86|87|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
        printf "Plan-only by design; keep external-action runbook and evidence current."
        ;;
      11|36|43|44)
        printf "Keep logical seed/reseed and restore guidance current."
        ;;
      *)
        printf "Add automated recovery helper when safe and repeatable."
        ;;
    esac
    return "$SUCCESS"
  fi
  if [[ "${SCENARIO_IMPACT[$id]}" == "destructive" ]] && ! supports_file_recovery_automation "$id"; then
    printf "Use baseline backup/runbook; add --protect only where target-specific backup is meaningful."
    return "$SUCCESS"
  fi
  printf "Lifecycle covered where topology prerequisites are met."
}

generate_scenario_lifecycle_report() {
  local id report_file latest_file protection execution recovery next_step
  local total_count=0 auto_protect_count=0 auto_recover_count=0 plan_only_count=0 placeholder_count=0 read_only_count=0

  for id in "${SCENARIO_IDS[@]}"; do
    total_count=$((total_count + 1))
    supports_file_recovery_automation "$id" && auto_protect_count=$((auto_protect_count + 1))
    supports_recovery_automation "$id" && auto_recover_count=$((auto_recover_count + 1))
    [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]] && placeholder_count=$((placeholder_count + 1))
    case "$id" in
      46|47|48|49|52|54|66|70|72|83|84|85|86|88|89|90|EXA01|EXA02|EXA03|EXA04|OCI01|OCI02|OCI03|OCI04|OCI05|GG01|GG02|GG03|GG04)
        plan_only_count=$((plan_only_count + 1))
        ;;
      53|64|65|69|78|80|81|82|87)
        read_only_count=$((read_only_count + 1))
        ;;
    esac
  done

  report_file="${LOG_DIR}/crashsim_scenario_lifecycle_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_scenario_lifecycle_latest.md"

  {
    printf "# CrashSimulator Scenario Lifecycle Coverage Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf -- '- Registered scenarios: `%s`\n' "$total_count"
    printf '%s\n' ""
    printf '%s\n' 'This static report shows what lifecycle support the framework provides for each registered scenario. It complements `--scenario-readiness-report`, which checks whether a scenario can run in the current database topology.'
    printf '%s\n' ""

    printf '%s\n\n' "## Lifecycle Policy"
    printf '%s\n' "| Phase | Framework expectation |"
    printf '%s\n' "| --- | --- |"
    printf '%s\n' '| Validation | Every registered scenario has a readiness validator through `--validate-scenario`; live blockers are reported before destructive execution. |'
    printf '%s\n' '| Protection | Datafile/tablespace media drills use automated `--protect` when a targeted RMAN backup is meaningful. Other destructive drills require baseline backup, configuration backup, or manual pre-checks documented by the runbook. Logical/read-only drills do not require protection. |'
    printf '%s\n' "| Execution | Scenarios use automated dry-run and guarded execution where safe. External infrastructure drills remain plan-only until a matching lab and approval path exist. |"
    printf '%s\n' '| Recovery | Automated `--recover` is available where repeatable. Other scenarios provide manual recovery guidance and evidence targets. |'
    printf '%s\n' "| Runbook/evidence | Every scenario can generate a runbook artifact; scenario/protection/recovery actions write manifests and audit records, with SQL/RMAN/Markdown evidence where applicable. |"

    printf '%s\n\n' ""
    printf '%s\n\n' "## Summary"
    printf '%s\n' "| Metric | Count |"
    printf '%s\n' "| --- | ---: |"
    printf '| Registered scenarios | %s |\n' "$total_count"
    printf '| Automated `--protect` support | %s |\n' "$auto_protect_count"
    printf '| Automated `--recover` support | %s |\n' "$auto_recover_count"
    printf '| Plan-only external-action scenarios | %s |\n' "$plan_only_count"
    printf '| Placeholder scenarios awaiting implementation | %s |\n' "$placeholder_count"
    printf '| Read-only report/review scenarios | %s |\n' "$read_only_count"

    printf '%s\n\n' ""
    printf '%s\n\n' "## Scenario Lifecycle Matrix"
    printf '%s\n' "| ID | Group | Impact | Scenario | Validation | Protection | Execution | Recovery | Runbook / Evidence | Next step |"
    printf '%s\n' "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    for id in "${SCENARIO_IDS[@]}"; do
      protection="$(scenario_protection_capability "$id")"
      execution="$(scenario_execution_capability "$id")"
      recovery="$(scenario_recovery_capability "$id")"
      next_step="$(scenario_lifecycle_next_step "$id")"
      printf '| `%s` | %s | %s | %s | %s | %s | %s | %s | %s / %s | %s |\n' \
        "$id" \
        "$(md_escape "${SCENARIO_GROUP[$id]}")" \
        "$(md_escape "${SCENARIO_IMPACT[$id]}")" \
        "$(md_escape "${SCENARIO_TITLE[$id]}")" \
        "$(md_escape "$(scenario_validation_capability "$id")")" \
        "$(md_escape "$protection")" \
        "$(md_escape "$execution")" \
        "$(md_escape "$recovery")" \
        "$(md_escape "$(scenario_runbook_capability "$id")")" \
        "$(md_escape "$(scenario_evidence_capability "$id")")" \
        "$(md_escape "$next_step")"
    done

    printf '%s\n\n' ""
    printf '%s\n\n' "## Recommended Use"
    printf -- '- Generate this report after new scenarios are added so lifecycle coverage stays visible.\n'
    printf -- '- Use `--scenario-readiness-report --pdb <pdb>` next to check the live target topology.\n'
    printf -- '- Use `--runbook <id> --html` before drills to produce scenario-specific recovery guidance and evidence expectations.\n'
    printf -- '- Treat manual/external entries as backlog candidates only after the required lab topology and safe recovery procedure exist.\n'
  } >"$report_file" || die "Unable to write scenario lifecycle report: $report_file"

  cp "$report_file" "$latest_file" || die "Unable to update latest scenario lifecycle report: $latest_file"
  echo "Scenario lifecycle coverage report generated: ${report_file}"
  echo "Latest scenario lifecycle coverage report: ${latest_file}"
  echo
  cat "$report_file"
  maybe_render_html "$report_file"
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    render_artifact_html "$latest_file"
  fi
}

scenario_lifecycle_check() {
  local id report_file latest_file status failures=0 warnings=0 handler
  local title group scope impact requires notes validation protection execution recovery runbook evidence

  report_file="${LOG_DIR}/crashsim_scenario_lifecycle_check_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_scenario_lifecycle_check_latest.md"

  {
    printf "# CrashSimulator Scenario Lifecycle Consistency Check\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Registered database scenarios: `%s`\n' "${#SCENARIO_IDS[@]}"
    printf -- '- Registered ADB scenarios: `%s`\n' "${#ADB_SCENARIO_IDS[@]}"
    printf "\nThis check is release-oriented. It validates that each registered scenario has metadata, a callable handler, and lifecycle text for validation, protection, execution, recovery, runbook, and evidence posture. It does not connect to a database.\n\n"
    printf "## Scenario Checks\n\n"
    printf "| Status | ID | Scenario | Finding |\n"
    printf "| --- | --- | --- | --- |\n"
  } >"$report_file" || die "Unable to write lifecycle check report: $report_file"

  for id in "${SCENARIO_IDS[@]}"; do
    status="OK"
    title="${SCENARIO_TITLE[$id]:-}"
    group="${SCENARIO_GROUP[$id]:-}"
    scope="${SCENARIO_SCOPE[$id]:-}"
    impact="${SCENARIO_IMPACT[$id]:-}"
    requires="${SCENARIO_REQUIRES[$id]:-}"
    handler="${SCENARIO_HANDLER[$id]:-}"
    notes="${SCENARIO_NOTES[$id]:-}"
    validation="$(scenario_validation_capability "$id")"
    protection="$(scenario_protection_capability "$id")"
    execution="$(scenario_execution_capability "$id")"
    recovery="$(scenario_recovery_capability "$id")"
    runbook="$(scenario_runbook_capability "$id")"
    evidence="$(scenario_evidence_capability "$id")"

    if [[ -z "$title" || -z "$group" || -z "$scope" || -z "$impact" || -z "$requires" || -z "$handler" || -z "$notes" ]]; then
      printf '| `FAIL` | `%s` | %s | Missing required scenario metadata. |\n' "$id" "$(md_escape "${title:-unknown}")" >>"$report_file"
      failures=$((failures + 1))
      status="FAIL"
    fi
    if [[ -n "$handler" && -z "$(declare -F "$handler" 2>/dev/null)" ]]; then
      printf '| `FAIL` | `%s` | %s | Handler `%s` is not defined. |\n' "$id" "$(md_escape "${title:-unknown}")" "$(md_escape "$handler")" >>"$report_file"
      failures=$((failures + 1))
      status="FAIL"
    fi
    if [[ -z "$validation" || -z "$protection" || -z "$execution" || -z "$recovery" || -z "$runbook" || -z "$evidence" ]]; then
      printf '| `FAIL` | `%s` | %s | One or more lifecycle capability strings are empty. |\n' "$id" "$(md_escape "${title:-unknown}")" >>"$report_file"
      failures=$((failures + 1))
      status="FAIL"
    fi
    if [[ "$impact" == "destructive" && "$execution" != *"guard"* && "$execution" != *"plan-only"* ]]; then
      printf '| `WARN` | `%s` | %s | Destructive scenario execution text should mention guardrails or plan-only posture. |\n' "$id" "$(md_escape "$title")" >>"$report_file"
      warnings=$((warnings + 1))
    fi
    if [[ "$status" == "OK" ]]; then
      printf '| `OK` | `%s` | %s | Metadata, handler, and lifecycle text are present. |\n' "$id" "$(md_escape "$title")" >>"$report_file"
    fi
  done

  {
    printf "\n## Autonomous Database Scenario Checks\n\n"
    printf "| Status | ID | Scenario | Finding |\n"
    printf "| --- | --- | --- | --- |\n"
  } >>"$report_file"

  for id in "${ADB_SCENARIO_IDS[@]}"; do
    title="${ADB_SCENARIO_TITLE[$id]:-}"
    if [[ -z "$title" || -z "${ADB_SCENARIO_AREA[$id]:-}" || -z "${ADB_SCENARIO_VALIDATION[$id]:-}" || -z "${ADB_SCENARIO_RECOVERY[$id]:-}" || -z "${ADB_SCENARIO_HELPER[$id]:-}" ]]; then
      printf '| `FAIL` | `%s` | %s | Missing ADB scenario metadata. |\n' "$id" "$(md_escape "${title:-unknown}")" >>"$report_file"
      failures=$((failures + 1))
    else
      printf '| `OK` | `%s` | %s | ADB scenario metadata is present. |\n' "$id" "$(md_escape "$title")" >>"$report_file"
    fi
  done

  {
    printf "\n## Summary\n\n"
    printf -- '- Failures: `%s`\n' "$failures"
    printf -- '- Warnings: `%s`\n' "$warnings"
    printf -- '- Latest report: `%s`\n' "$latest_file"
  } >>"$report_file"

  cp "$report_file" "$latest_file" 2>/dev/null || true
  echo "Scenario lifecycle consistency check generated: ${report_file}"
  cat "$report_file"
  maybe_render_html "$report_file"
  [[ "$failures" -eq 0 ]]
}

plan_scenario_actions() {
  local id="$1"
  local handler old_execute old_planning

  check_requirements "$id"
  handler="${SCENARIO_HANDLER[$id]}"
  old_execute="$EXECUTE"
  old_planning="$PLANNING_ONLY"
  EXECUTE=0
  PLANNING_ONLY=1
  "$handler" "$id"
  EXECUTE="$old_execute"
  PLANNING_ONLY="$old_planning"
}

validation_reason_from_output() {
  local output="$1"
  local reason
  reason="$(printf "%s\n" "$output" | awk '
    /^[[:space:]]*$/ {next}
    {last=$0}
    END {print last}
  ')"
  reason="${reason#ERROR: }"
  reason="${reason#WARN: }"
  [[ -n "$reason" ]] || reason="Scenario target validation did not produce a runnable target."
  printf "%s" "$reason"
}

validation_single_line() {
  tr '\n' ' ' | sed 's/[[:space:]][[:space:]]*/ /g; s/^ //; s/ $//'
}

validation_external_reason() {
  local output="$1"
  local line detail
  line="$(printf "%s\n" "$output" | grep -E '^[[:space:]]*[0-9]+\. external[[:space:]]+' | head -n 1 || true)"
  [[ -n "$line" ]] || return "$FAIL"
  detail="$(printf "%s" "$line" | sed -E 's/^[[:space:]]*[0-9]+\. external[[:space:]]+//')"
  printf "Selected target requires a provider-specific or manual handler before safe execution: %s" "$detail"
}

validation_missing_fs_target_reason() {
  local output="$1"
  local target
  while IFS= read -r target; do
    target="${target%% (*}"
    if [[ -n "$target" && "$target" == /* && ! -e "$target" ]]; then
      printf "Selected filesystem target does not exist or is not visible to this OS user: %s" "$target"
      return "$SUCCESS"
    fi
  done < <(printf "%s\n" "$output" |
    sed -nE 's/^[[:space:]]*[0-9]+\. (fs_rename|fs_corrupt_header|fs_corrupt_body)[[:space:]]+(.+)$/\2/p')
  return "$FAIL"
}

validation_missing_tool_reason() {
  local output="$1"
  if printf "%s\n" "$output" | grep -Eq '^[[:space:]]*[0-9]+\. srvctl_'; then
    if ! command -v srvctl >/dev/null 2>&1; then
      printf "Selected action requires srvctl, but srvctl was not found in PATH."
      return "$SUCCESS"
    fi
  fi
  if printf "%s\n" "$output" | grep -Eq '^[[:space:]]*[0-9]+\. asm_'; then
    if ! discover_grid_home_for_tool asmcmd >/dev/null 2>&1; then
      printf "Selected action requires asmcmd from Grid Infrastructure, but asmcmd was not found."
      return "$SUCCESS"
    fi
  fi
  return "$FAIL"
}

validation_requirement_blocker_reason() {
  local id="$1"
  local output="$2"

  case "$id" in
    50|67)
      if printf "%s\n" "$output" | grep -q "requires a standby role"; then
        printf "Scenario %s requires a physical standby database with managed recovery running. Run it on a standby environment, then confirm an MRP process is visible in V\$MANAGED_STANDBY." "$id"
        return "$SUCCESS"
      fi
      ;;
    51|68)
      if printf "%s\n" "$output" | grep -q "requires Data Guard metadata"; then
        printf "Scenario %s requires a primary database with a configured remote standby archive destination. Configure Data Guard transport, confirm a V\$ARCHIVE_DEST row with TARGET='STANDBY', then rerun validation." "$id"
        return "$SUCCESS"
      fi
      ;;
    52|66|69|85|86)
      if printf "%s\n" "$output" | grep -q "requires Data Guard metadata"; then
        printf "Scenario %s requires a Data Guard configuration. Configure a standby and verify SQL/Data Guard Broker evidence before running this scenario." "$id"
        return "$SUCCESS"
      fi
      ;;
    53)
      if printf "%s\n" "$output" | grep -q "requires a standby role"; then
        printf "Scenario 53 requires an Active Data Guard standby opened READ ONLY WITH APPLY. Run it on an ADG standby after confirming open mode and apply status."
        return "$SUCCESS"
      fi
      ;;
    54)
      if printf "%s\n" "$output" | grep -q "requires a standby role"; then
        printf "Scenario 54 requires a Data Guard physical standby that is approved for snapshot-standby conversion practice. Run it on the standby after confirming flashback, broker/transport posture, and restore-point policy."
        return "$SUCCESS"
      fi
      ;;
  esac

  return "$FAIL"
}

validation_no_target_reason() {
  local id="$1"
  local output="$2"
  local no_target=0

  if printf "%s\n" "$output" | grep -q "No targets were found for this scenario"; then
    no_target=1
  fi

  case "$id" in
    3)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No multiplexed member was found in the CURRENT redo group. Add at least one additional online redo member to the current group, or multiplex all redo groups and switch logs until a multiplexed group is current, then rerun validation."
      ;;
    5)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No non-SYSTEM permanent datafile was found. Create a disposable user tablespace/datafile, or seed the CrashSimulator lab objects, before running scenario 5."
      ;;
    6|31)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No tempfile was found in the target scope. Add a tempfile to the database/PDB temporary tablespace before running this scenario."
      ;;
    7)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB SYSTEM datafile was visible to the validation query. Confirm the database is open and DBA_DATA_FILES is accessible before running scenario 7."
      ;;
    8)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB UNDO datafile was found. Confirm local undo/undo tablespace configuration before running scenario 8."
      ;;
    9)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB READ ONLY permanent tablespace was found. Create a controlled read-only lab tablespace, preferably CRASHSIM_ROOT_RO_TBS, set it READ ONLY, then rerun validation."
      ;;
    10)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB index-only tablespace was found. Create a controlled index-only lab tablespace, preferably CRASHSIM_ROOT_INDEX_TBS, with indexes and no heap tables before running scenario 10."
      ;;
    11)
      if printf "%s\n" "$output" | grep -q "No non-unique user index candidate"; then
        printf "No root/non-CDB non-unique user index candidate was found. Re-run seed_crashsim_lab.sql or provide --schema for a disposable lab schema with non-unique indexes."
      else
        return "$FAIL"
      fi
      ;;
    12)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No non-SYSTEM permanent tablespace target was found. Create a disposable user tablespace before running scenario 12."
      ;;
    13|38)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No temporary tablespace tempfile target was found. Add a tempfile to the target temporary tablespace before running this scenario."
      ;;
    14)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB SYSTEM tablespace datafile was visible. Confirm the database is open and dictionary access is available before scenario 14."
      ;;
    15)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No root/non-CDB UNDO tablespace datafile was found. Confirm undo tablespace configuration before scenario 15."
      ;;
    17|41)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No datafiles were visible to the validation query. Confirm the database/PDB is open and V\$DATAFILE is accessible before running this all-datafile scenario."
      ;;
    18)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No online redo group with more than one member was found. Multiplex the online redo logs, preferably every group/thread in RAC, then rerun validation."
      ;;
    19)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No INACTIVE redo group members were found. Switch logs and checkpoint until at least one inactive redo group exists, then rerun validation."
      ;;
    20|21)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No active/current redo group members were found by the validation query. Confirm V\$LOG/V\$LOGFILE visibility and current redo status before running this redo scenario."
      ;;
    22|42)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No SYSTEM datafile target was found for header-corruption practice. Confirm the target database/PDB is open and SYSTEM datafile metadata is visible."
      ;;
    27|57)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No SQL*Net configuration files were found under TNS_ADMIN or ORACLE_HOME/network/admin. Create or locate listener.ora, tnsnames.ora, or sqlnet.ora before running this scenario."
      ;;
    30)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB non-SYSTEM datafile was found in ${TARGET_PDB:-the target PDB}. Create a disposable user tablespace/datafile in the PDB before running scenario 30."
      ;;
    32)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB SYSTEM datafile was visible in ${TARGET_PDB:-the target PDB}. Confirm the PDB is open and CDB_DATA_FILES metadata is accessible before running scenario 32."
      ;;
    33|40)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB UNDO datafile was found in ${TARGET_PDB:-the target PDB}. Confirm local undo is enabled and the PDB has an UNDO tablespace before running this scenario."
      ;;
    34)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No READ ONLY permanent tablespace was found in PDB ${TARGET_PDB:-not set}. Create a controlled PDB read-only lab tablespace, set it READ ONLY, then rerun validation."
      ;;
    35)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB index-only tablespace was found in ${TARGET_PDB:-the target PDB}. Create a controlled index-only lab tablespace with indexes and no heap tables before running scenario 35."
      ;;
    36)
      if printf "%s\n" "$output" | grep -q "No PDB non-unique user index candidate"; then
        printf "No PDB non-unique user index candidate was found in ${TARGET_PDB:-the target PDB}. Re-run seed_crashsim_lab.sql in the PDB or provide --schema for a disposable lab schema."
      else
        return "$FAIL"
      fi
      ;;
    37)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB non-SYSTEM permanent tablespace was found in ${TARGET_PDB:-the target PDB}. Create a disposable PDB user tablespace before running scenario 37."
      ;;
    39)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No PDB SYSTEM tablespace datafile was visible in ${TARGET_PDB:-the target PDB}. Confirm the PDB is open and metadata is accessible before running scenario 39."
      ;;
    43)
      if printf "%s\n" "$output" | grep -Eq "No PDB user table candidate|No targets were found"; then
        printf "No PDB user table candidate was found in ${TARGET_PDB:-the target PDB}. Re-run seed_crashsim_lab.sql in the PDB or provide --schema for a disposable lab schema with test tables."
      else
        return "$FAIL"
      fi
      ;;
    44)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No disposable PDB user schema candidate was found in ${TARGET_PDB:-the target PDB}. Re-run seed_crashsim_lab.sql or provide --schema for a lab schema that can be dropped."
      ;;
    50)
      if printf "%s\n" "$output" | grep -q "No managed standby recovery process"; then
        printf "No managed standby recovery process was detected. Start standby apply and confirm an MRP process in V\$MANAGED_STANDBY before running scenario 50."
      else
        return "$FAIL"
      fi
      ;;
    51)
      if printf "%s\n" "$output" | grep -q "No remote standby archive destination"; then
        printf "No enabled remote standby archive destination was found. Configure Data Guard transport and confirm V\$ARCHIVE_DEST TARGET='STANDBY' before running scenario 51."
      else
        return "$FAIL"
      fi
      ;;
    58)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No TDE wallet/keystore location was detected. Configure WALLET_ROOT/TDE_CONFIGURATION or an sqlnet.ora wallet location before running scenario 58."
      ;;
    59)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No archived redo log file was found in control-file metadata. Generate and retain archived redo logs, then rerun validation."
      ;;
    60)
      [[ "$no_target" -eq 1 ]] || return "$FAIL"
      printf "No RMAN catalog connect string was provided. Set --rman-catalog or CRASHSIM_RMAN_CATALOG to validate recovery catalog outage behavior."
      ;;
    61)
      if printf "%s\n" "$output" | grep -q "No configured FRA destination"; then
        printf "No configured FRA destination was found. Configure DB_RECOVERY_FILE_DEST and DB_RECOVERY_FILE_DEST_SIZE before running FRA pressure scenario 61."
      elif printf "%s\n" "$output" | grep -q "FRA usage is zero"; then
        printf "FRA pressure cannot be simulated because current FRA usage is zero. Generate archived redo or a small lab backup first, then rerun validation."
      elif printf "%s\n" "$output" | grep -q "FRA pressure cannot be simulated"; then
        printf "%s" "$(validation_reason_from_output "$output")"
      else
        return "$FAIL"
      fi
      ;;
    62)
      if printf "%s\n" "$output" | grep -q "No available local archived redo log"; then
        printf "No available local archived redo log was found. Generate archived redo with log switches and keep it available before running scenario 62."
      else
        return "$FAIL"
      fi
      ;;
    63)
      if printf "%s\n" "$output" | grep -q "No temporary tablespace/tempfile metadata"; then
        printf "No temporary tablespace/tempfile metadata was found for the selected container. Add a tempfile or choose a different PDB before running scenario 63."
      else
        return "$FAIL"
      fi
      ;;
    66)
      if printf "%s\n" "$output" | grep -q "FSFO observer was not detected"; then
        printf "FSFO observer was not detected. Enable Fast-Start Failover, start an observer, and confirm V\$DATABASE.FS_FAILOVER_OBSERVER_PRESENT or DGMGRL evidence before running scenario 66."
      else
        return "$FAIL"
      fi
      ;;
    67)
      if printf "%s\n" "$output" | grep -q "No managed standby recovery process"; then
        printf "No managed standby recovery process was detected. Start standby apply and confirm an MRP process in V\$MANAGED_STANDBY before running scenario 67."
      else
        return "$FAIL"
      fi
      ;;
    68)
      if printf "%s\n" "$output" | grep -q "No remote standby archive destination"; then
        printf "No enabled remote standby archive destination was found. Configure Data Guard transport and confirm V\$ARCHIVE_DEST TARGET='STANDBY' before running scenario 68."
      else
        return "$FAIL"
      fi
      ;;
    70)
      if printf "%s\n" "$output" | grep -q "No RAC VIP resources"; then
        printf "No RAC VIP resources were visible to crsctl. Run scenario 70 on a RAC/GI node with Grid Infrastructure commands in PATH."
      else
        return "$FAIL"
      fi
      ;;
    71)
      if printf "%s\n" "$output" | grep -Eq "No srvctl-managed database service|Service .* is not running"; then
        printf "No running srvctl-managed database service was available. Create/start a database service, or supply --service-name for scenario 71."
      else
        return "$FAIL"
      fi
      ;;
    72)
      if printf "%s\n" "$output" | grep -q "No redundant ASM disk candidate"; then
        printf "No redundant ASM disk candidate was found. Scenario 72 requires a NORMAL/HIGH/FLEX/EXTENDED redundancy ASM disk group with online disks; EXTERN redundancy remains plan-only unsuitable for single-disk failure practice."
      else
        return "$FAIL"
      fi
      ;;
    73|79)
      if printf "%s\n" "$output" | grep -q "ORDS binary was not found"; then
        printf "ORDS is not installed or not in PATH. Install/configure ORDS on this host before running scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "ORDS systemd service unit was not found"; then
        printf "The ORDS systemd service unit ${ORDS_SERVICE_NAME} was not found. Configure ORDS as a managed service before running scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "requires --ords-lb-url"; then
        printf "Scenario 79 requires --ords-lb-url/CRASHSIM_ORDS_LB_URL or a reachable peer ORDS node so the drill can validate continuity."
      else
        return "$FAIL"
      fi
      ;;
    74)
      if printf "%s\n" "$output" | grep -q "ORDS configuration directory was not found"; then
        printf "ORDS configuration directory was not found at ${ORDS_CONFIG_DIR}. Configure ORDS or pass --ords-config-dir before running scenario 74."
      elif printf "%s\n" "$output" | grep -q "ORDS config directory is not writable"; then
        printf "ORDS config directory cannot be renamed by $(id -un). Configure the approved ORDS helper ${ORDS_PRIV_HELPER}, or make the ORDS config parent writable in a lab."
      else
        return "$FAIL"
      fi
      ;;
    75)
      if printf "%s\n" "$output" | grep -q "ORDS binary was not found"; then
        printf "ORDS is not installed or not in PATH. Install/configure ORDS before running scenario 75."
      elif printf "%s\n" "$output" | grep -q "ORDS configuration directory was not found"; then
        printf "ORDS configuration directory was not found at ${ORDS_CONFIG_DIR}. Configure ORDS or pass --ords-config-dir before running scenario 75."
      elif printf "%s\n" "$output" | grep -q "requires approved ORDS service restart privileges"; then
        printf "Scenario 75 requires approved ORDS service restart privileges. Configure ${ORDS_PRIV_HELPER} or narrow sudo service control for ${ORDS_SERVICE_NAME}."
      else
        return "$FAIL"
      fi
      ;;
    76)
      if printf "%s\n" "$output" | grep -q "No unlocked APEX/ORDS runtime account"; then
        printf "No unlocked APEX/ORDS runtime account was found. Install/configure APEX/ORDS in the selected container and confirm APEX_PUBLIC_USER or ORDS_PUBLIC_USER exists before running scenario 76."
      else
        return "$FAIL"
      fi
      ;;
    77)
      if printf "%s\n" "$output" | grep -q "No APEX images/static files directory"; then
        printf "No APEX static images directory was found. Install APEX static files and pass --apex-images-dir before running scenario 77."
      else
        return "$FAIL"
      fi
      ;;
    78|80)
      if printf "%s\n" "$output" | grep -q "ORDS/APEX smoke URL is not reachable"; then
        printf "The ORDS/APEX smoke URL is not reachable: ${ORDS_URL}. Start/configure ORDS and validate network access before running scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "APEX is not installed"; then
        printf "APEX is not installed in the selected target container. Install APEX in the PDB and rerun validation for scenario %s." "$id"
      elif printf "%s\n" "$output" | grep -q "APEX session driver is not executable"; then
        printf "Scenario 80 browser-session driver is not executable: ${APEX_SESSION_DRIVER}. Fix permissions or omit --apex-session-driver for read-only URL evidence."
      elif printf "%s\n" "$output" | grep -q "APEX session driver self-check failed"; then
        printf "Scenario 80 browser-session driver self-check failed for ${APEX_SESSION_DRIVER}. Verify Node.js, Playwright, and the Chromium browser runtime, or omit --apex-session-driver for read-only URL evidence."
      elif printf "%s\n" "$output" | grep -q "APEX session username was supplied"; then
        printf "Scenario 80 browser-session login needs CRASHSIM_APEX_SESSION_PASSWORD or --apex-session-password when --apex-session-username is supplied."
      else
        return "$FAIL"
      fi
      ;;
    81|82)
      if printf "%s\n" "$output" | grep -q "APEX is not installed"; then
        printf "APEX is not installed in the selected target container. Install APEX in the PDB and rerun validation for scenario %s." "$id"
      else
        return "$FAIL"
      fi
      ;;
    *)
      return "$FAIL"
      ;;
  esac
  return "$SUCCESS"
}

validation_guardrail_reason() {
  local id="$1"
  case "$id" in
    28)
      printf "Scenario 28 ORACLE_HOME loss requires an external restore/reinstall plan and is intentionally dry-run/manual only in this framework."
      return "$SUCCESS"
      ;;
    25)
      if [[ -z "$PIECE_HANDLE" ]]; then
        if [[ "$LOCAL_ONLY" != "1" || -z "$MAX_TARGETS" ]]; then
          printf "Scenario 25 can see local and object-storage backup handles; execution requires --piece-handle or --local-only --max-targets <n>."
          return "$SUCCESS"
        fi
      fi
      ;;
    45)
      if [[ -z "$TARGET_PDB" || "$TARGET_PDB" != CRASHSIM_* ]]; then
        printf "Scenario 45 can only execute against a disposable PDB whose name starts with CRASHSIM_. Current PDB: %s." "${TARGET_PDB:-not set}"
        return "$SUCCESS"
      fi
      ;;
  esac
  return "$FAIL"
}

validate_scenario_can_run() {
  local id="$1"
  local req_output req_status plan_output plan_status reason

  SCENARIO_VALIDATION_STATUS="NOT_RUNNABLE"
  SCENARIO_VALIDATION_REASON=""
  SCENARIO_VALIDATION_OUTPUT=""

  if ! scenario_exists "$id"; then
    SCENARIO_VALIDATION_REASON="Unknown scenario id: $id"
    return "$FAIL"
  fi

  req_output="$( (check_requirements "$id") 2>&1 )"
  req_status=$?
  if [[ "$req_status" -ne 0 ]]; then
    SCENARIO_VALIDATION_OUTPUT="$req_output"
    if reason="$(validation_requirement_blocker_reason "$id" "$req_output")"; then
      SCENARIO_VALIDATION_REASON="$reason"
    else
      SCENARIO_VALIDATION_REASON="$(validation_reason_from_output "$req_output")"
    fi
    return "$FAIL"
  fi

  if [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]]; then
    SCENARIO_VALIDATION_REASON="Scenario $id is registered as a placeholder for ${SCENARIO_SCOPE[$id]} testing, but a runnable handler is not implemented yet."
    return "$FAIL"
  fi

  if reason="$(validation_guardrail_reason "$id")"; then
    SCENARIO_VALIDATION_STATUS="PLAN_ONLY"
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  plan_output="$( (
    EXECUTE=0
    ASSUME_YES=1
    PLANNING_ONLY=1
    MANIFEST_FILE=""
    MANIFEST_FROM_ARG=0
    CURRENT_SCENARIO_ID="$id"
    RENAME_COUNT=0
    reset_actions
    plan_scenario_actions "$id"
  ) 2>&1)"
  plan_status=$?
  SCENARIO_VALIDATION_OUTPUT="$plan_output"
  if [[ "$plan_status" -ne 0 ]]; then
    if reason="$(validation_no_target_reason "$id" "$plan_output")"; then
      SCENARIO_VALIDATION_REASON="$reason"
    else
      SCENARIO_VALIDATION_REASON="$(validation_reason_from_output "$plan_output")"
    fi
    return "$FAIL"
  fi

  if reason="$(validation_external_reason "$plan_output")"; then
    SCENARIO_VALIDATION_STATUS="PLAN_ONLY"
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  if reason="$(validation_missing_fs_target_reason "$plan_output")"; then
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  if reason="$(validation_missing_tool_reason "$plan_output")"; then
    SCENARIO_VALIDATION_REASON="$reason"
    return "$FAIL"
  fi

  SCENARIO_VALIDATION_STATUS="RUNNABLE"
  SCENARIO_VALIDATION_REASON="Requirements passed and target selection produced executable actions."
  return "$SUCCESS"
}

print_scenario_validation() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"

  echo "Scenario readiness validation"
  echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Group: ${SCENARIO_GROUP[$id]}"
  echo "Scope: ${SCENARIO_SCOPE[$id]}"
  echo "Impact: ${SCENARIO_IMPACT[$id]}"
  echo "Requires: ${SCENARIO_REQUIRES[$id]}"
  echo

  if validate_scenario_can_run "$id"; then
    echo "Result: RUNNABLE"
    echo "Reason: ${SCENARIO_VALIDATION_REASON}"
    if [[ "$VERBOSE" -eq 1 && -n "$SCENARIO_VALIDATION_OUTPUT" ]]; then
      echo
      echo "Validation planning output:"
      printf "%s\n" "$SCENARIO_VALIDATION_OUTPUT"
    fi
    return "$SUCCESS"
  fi

  if [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
    echo "Result: NOT RUNNABLE (dry-run planning only)"
  else
    echo "Result: NOT RUNNABLE"
  fi
  echo "Scenario ${id} is not possible to run at this moment."
  echo "Reason: ${SCENARIO_VALIDATION_REASON}"
  if [[ "$VERBOSE" -eq 1 && -n "$SCENARIO_VALIDATION_OUTPUT" ]]; then
    echo
    echo "Validation planning output:"
    printf "%s\n" "$SCENARIO_VALIDATION_OUTPUT"
  fi
  return "$FAIL"
}

validate_all_scenarios() {
  local id status reason runnable_count=0 blocked_count=0

  if find_sqlplus_if_available; then
    discover_environment
  else
    warn "Database topology discovery skipped: sqlplus was not found. Database-scoped scenarios will be marked not runnable until ORACLE_HOME or SQLPLUS is set."
  fi

  printf "%-4s %-12s %s\n" "ID" "Status" "Reason"
  printf "%-4s %-12s %s\n" "--" "------" "------"
  for id in "${SCENARIO_IDS[@]}"; do
    if validate_scenario_can_run "$id"; then
      status="RUNNABLE"
      reason="$SCENARIO_VALIDATION_REASON"
      runnable_count=$((runnable_count + 1))
    else
      if [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
        status="PLAN-ONLY"
      else
        status="NOT-RUNNABLE"
      fi
      reason="$SCENARIO_VALIDATION_REASON"
      blocked_count=$((blocked_count + 1))
    fi
    reason="$(printf "%s" "$reason" | validation_single_line)"
    printf "%-4s %-12s %s\n" "$id" "$status" "$reason"
  done
  echo
  echo "Runnable scenarios: ${runnable_count}"
  echo "Not runnable at this moment: ${blocked_count}"
}

scenario_readiness_append_rows() {
  local report_file="$1"
  local empty_message="$2"
  shift 2
  local row

  if [[ "$#" -eq 0 ]]; then
    printf "%s\n" "$empty_message" >>"$report_file"
    return "$SUCCESS"
  fi

  printf "| ID | Group | Scope | Impact | Scenario | Reason |\n" >>"$report_file"
  printf "| --- | --- | --- | --- | --- | --- |\n" >>"$report_file"
  for row in "$@"; do
    printf "%s\n" "$row" >>"$report_file"
  done
}

generate_scenario_readiness_report() {
  local id status reason row name con_id open_mode discovery_note
  local runnable_count=0 plan_only_count=0 not_runnable_count=0 total_count=0
  local report_file latest_file
  local -a runnable_rows=()
  local -a plan_only_rows=()
  local -a not_runnable_rows=()

  if find_sqlplus_if_available; then
    discover_environment
    discovery_note="SQL*Plus discovery completed."
  else
    discovery_note="SQL*Plus was not found. Database-scoped scenarios are blocked until ORACLE_HOME or SQLPLUS is set on a host with a created database."
    warn "Database topology discovery skipped: sqlplus was not found. Scenario readiness report will still be generated with blockers."
  fi

  for id in "${SCENARIO_IDS[@]}"; do
    total_count=$((total_count + 1))
    if validate_scenario_can_run "$id"; then
      status="RUNNABLE"
      reason="$SCENARIO_VALIDATION_REASON"
      runnable_count=$((runnable_count + 1))
    else
      if [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
        status="PLAN-ONLY"
        plan_only_count=$((plan_only_count + 1))
      else
        status="NOT-RUNNABLE"
        not_runnable_count=$((not_runnable_count + 1))
      fi
      reason="$SCENARIO_VALIDATION_REASON"
    fi

    reason="$(printf "%s" "$reason" | validation_single_line)"
    row="| \`${id}\` | $(md_escape "${SCENARIO_GROUP[$id]}") | $(md_escape "${SCENARIO_SCOPE[$id]}") | $(md_escape "${SCENARIO_IMPACT[$id]}") | $(md_escape "${SCENARIO_TITLE[$id]}") | $(md_escape "$reason") |"
    case "$status" in
      RUNNABLE) runnable_rows+=("$row") ;;
      PLAN-ONLY) plan_only_rows+=("$row") ;;
      *) not_runnable_rows+=("$row") ;;
    esac
  done

  report_file="${LOG_DIR}/crashsim_scenario_readiness_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_scenario_readiness_latest.md"

  {
    printf "# CrashSimulator Scenario Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf -- '- Target PDB context: `%s`\n' "${TARGET_PDB:-not set}"
    printf -- '- Target schema context: `%s`\n' "${TARGET_SCHEMA:-not set}"
    printf -- '- Target FILE# context: `%s`\n' "${TARGET_FILE_NO:-not set}"
    printf "\nThis report validates the discovered target environment against the CrashSimulator scenario registry. The same requirement checks, topology gates, target selection, and execution guardrails are used by scenario execution, so unavailable scenarios are blocked before destructive code runs.\n"

    printf "\n## Current Topology\n\n"
    printf "| Signal | Value |\n"
    printf "| --- | --- |\n"
    printf "| Host | %s |\n" "$(md_escape "${HOST_NAME:-unknown}")"
    printf "| OS user | %s |\n" "$(md_escape "$(id -un)")"
    printf "| Oracle home | %s |\n" "$(md_escape "${ORACLE_HOME:-unknown}")"
    printf "| SQL*Plus | %s |\n" "$(md_escape "${SQLPLUS_BIN:-unknown}")"
    printf "| Discovery note | %s |\n" "$(md_escape "$discovery_note")"
    printf "| Database name | %s |\n" "$(md_escape "${DB_NAME:-unknown}")"
    printf "| DB unique name | %s |\n" "$(md_escape "${DB_UNIQUE_NAME:-unknown}")"
    printf "| Database role | %s |\n" "$(md_escape "${DB_ROLE:-unknown}")"
    printf "| Open mode | %s |\n" "$(md_escape "${DB_OPEN_MODE:-unknown}")"
    printf "| CDB | %s |\n" "$(md_escape "${DB_CDB:-unknown}")"
    printf "| Instance | %s |\n" "$(md_escape "${INSTANCE_NAME:-unknown}")"
    printf "| Thread | %s |\n" "$(md_escape "${INSTANCE_THREAD:-unknown}")"
    printf "| RAC parallel | %s |\n" "$(md_escape "${INSTANCE_PARALLEL:-unknown}")"
    printf "| Cluster type | %s |\n" "$(md_escape "${CLUSTER_TYPE:-unknown}")"
    printf "| GI managed | %s |\n" "$(md_escape "${GI_MANAGED:-0}")"
    printf "| Storage type | %s |\n" "$(md_escape "${STORAGE_TYPE:-unknown}")"
    printf "| Protection mode | %s |\n" "$(md_escape "${DB_PROTECTION_MODE:-unknown}")"
    printf "| Switchover status | %s |\n" "$(md_escape "${DB_SWITCHOVER_STATUS:-unknown}")"
    printf "| SPFILE | %s |\n" "$(md_escape "${SPFILE_PATH:-not detected}")"
    printf "| Password file | %s |\n" "$(md_escape "${PASSWORD_FILE_PATH:-not detected}")"
    printf "| FRA | %s |\n" "$(md_escape "${FRA_PATH:-not configured}")"

    if [[ "$DB_CDB" == "YES" ]]; then
      printf "\n## PDBs\n\n"
      if [[ "${#PDB_ROWS[@]}" -eq 0 ]]; then
        printf "No user PDBs were discovered.\n"
      else
        printf "| PDB | CON_ID | Open mode |\n"
        printf "| --- | --- | --- |\n"
        for row in "${PDB_ROWS[@]}"; do
          IFS='|' read -r name con_id open_mode <<<"$row"
          printf "| %s | %s | %s |\n" "$(md_escape "$name")" "$(md_escape "$con_id")" "$(md_escape "$open_mode")"
        done
      fi
    fi

    printf "\n## Readiness Summary\n\n"
    printf "| Status | Count | Meaning |\n"
    printf "| --- | ---: | --- |\n"
    printf "| RUNNABLE | %s | Scenario can be selected for dry-run and, when requested, execution. |\n" "$runnable_count"
    printf "| PLAN-ONLY | %s | Scenario can produce useful dry-run/runbook evidence, but execution is blocked by a guardrail or provider-specific limitation. |\n" "$plan_only_count"
    printf "| NOT-RUNNABLE | %s | Scenario is not available in the current topology or target context. |\n" "$not_runnable_count"
    printf "| TOTAL | %s | Registered scenarios evaluated. |\n" "$total_count"
  } >"$report_file" || die "Unable to write scenario readiness report: $report_file"

  append_report_section "$report_file" "Runnable Scenarios"
  scenario_readiness_append_rows "$report_file" "No scenarios are runnable in the current target context." "${runnable_rows[@]}"

  append_report_section "$report_file" "Dry-Run Planning Only"
  scenario_readiness_append_rows "$report_file" "No scenarios are limited to dry-run planning only." "${plan_only_rows[@]}"

  append_report_section "$report_file" "Not Runnable Now"
  scenario_readiness_append_rows "$report_file" "No scenarios are blocked by topology or target context." "${not_runnable_rows[@]}"

  append_report_section "$report_file" "How CrashSimulator Uses This Result"
  {
    printf -- '- `--scenario <id> --execute`, `--protect <id> --execute`, and aleatory scenario execution run readiness validation before confirmation or destructive actions.\n'
    printf -- '- Guided Workflow scenario selection now shows the selected scenario readiness status immediately.\n'
    printf -- '- Use only `RUNNABLE` scenarios for execution drills. Review `PLAN-ONLY` and `NOT-RUNNABLE` reasons before changing topology, targets, or helper coverage.\n'
    printf -- '- Re-run this report after changing database topology, adding PDBs, multiplexing redo/control files, configuring Data Guard, adding ASM/GI lab disks, reseeding logical objects, or taking fresh backups.\n'
  } >>"$report_file"

  append_report_section "$report_file" "Recommended Next Commands"
  {
    printf '```bash\n'
    printf './%s --validate-scenario <id> --pdb %s\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf './%s --scenario <id> --pdb %s --dry-run\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf './%s --runbook <id> --pdb %s\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf './%s --health-check --pdb %s\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf '```\n'
  } >>"$report_file"

  cp "$report_file" "$latest_file" || die "Unable to update latest scenario readiness report: $latest_file"

  echo "Scenario readiness report generated: ${report_file}"
  echo "Latest scenario readiness report: ${latest_file}"
  echo
  cat "$report_file"
  maybe_render_html "$report_file"
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    render_artifact_html "$latest_file"
  fi
}

write_protect_rman_file() {
  local id="$1"
  local cmd_file="$2"
  local tag="$3"
  local file_list
  file_list="$(join_csv "${PLAN_TARGET_FILE_NOS[@]}")"

  {
    printf "run {\n"
    printf "  sql \"alter system archive log current\";\n"
    printf "  backup as compressed backupset datafile %s tag '%s';\n" "$file_list" "$tag"
    printf "  backup current controlfile tag '%s_CTL';\n" "$tag"
    printf "}\n"
    printf "list backup tag '%s';\n" "$tag"
    printf "list backup tag '%s_CTL';\n" "$tag"
  } >"$cmd_file" || die "Unable to write RMAN command file: $cmd_file"

  manifest_append "protect_rman_cmdfile" "$cmd_file"
  manifest_append "backup_tag" "$tag"
}

protect_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_file_recovery_automation "$id" ||
    die "Automated RMAN protection is not registered for scenario ${id}. Use --runbook ${id} for manual guidance."

  check_requirements "$id"
  CURRENT_SCENARIO_ID="$id"
  init_manifest "protect" "$id"

  echo "Protect scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  plan_scenario_actions "$id"
  collect_datafile_plan

  local tag cmd_file log_file
  tag="$(rman_tag "$id")"
  cmd_file="${LOG_DIR}/crashsim_protect_s${id}_${RUN_ID}.rman"
  log_file="${LOG_DIR}/crashsim_protect_s${id}_${RUN_ID}.log"
  write_protect_rman_file "$id" "$cmd_file" "$tag"

  echo
  echo "Protection target datafiles:"
  local idx
  for idx in "${!PLAN_TARGET_FILE_NOS[@]}"; do
    printf "  FILE# %-5s %-12s %-16s %s\n" \
      "${PLAN_TARGET_FILE_NOS[$idx]}" \
      "${PLAN_TARGET_PDBS[$idx]}" \
      "${PLAN_TARGET_TABLESPACES[$idx]}" \
      "${PLAN_TARGET_PATHS[$idx]}"
  done
  echo "Backup tag: ${tag}"
  echo

  confirm_mode_execution "PROTECT" "$id"
  run_rman_cmdfile "$cmd_file" "$log_file"
  manifest_append "protect_rman_log" "$log_file"
}

write_recover_rman_file() {
  local id="$1"
  local file_no="$2"
  local cmd_file="$3"

  {
    printf "startup force mount;\n"
    printf "restore datafile %s;\n" "$file_no"
    printf "recover datafile %s;\n" "$file_no"
    printf "sql \"alter database open\";\n"
  } >"$cmd_file" || die "Unable to write RMAN recovery command file: $cmd_file"

  manifest_append "recover_rman_cmdfile" "$cmd_file"
}

write_recover_datafile_list_rman_file() {
  local file_list="$1"
  local cmd_file="$2"

  {
    printf "startup force mount;\n"
    printf "restore datafile %s;\n" "$file_list"
    printf "recover datafile %s;\n" "$file_list"
    printf "sql \"alter database open\";\n"
  } >"$cmd_file" || die "Unable to write RMAN datafile-list recovery file: $cmd_file"

  manifest_append "recover_rman_cmdfile" "$cmd_file"
}

write_recover_pdb_datafile_rman_file() {
  local file_list="$1"
  local cmd_file="$2"

  {
    printf "restore datafile %s;\n" "$file_list"
    printf "recover datafile %s;\n" "$file_list"
  } >"$cmd_file" || die "Unable to write RMAN PDB datafile recovery file: $cmd_file"

  manifest_append "recover_rman_cmdfile" "$cmd_file"
}

write_validate_datafile_list_rman_file() {
  local file_list="$1"
  local cmd_file="$2"

  {
    printf "backup validate datafile %s;\n" "$file_list"
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); the validate above sets the exit
    # status and reports any corruption on all supported releases.
  } >"$cmd_file" || die "Unable to write RMAN datafile-list validation file: $cmd_file"
}

write_controlfile_validate_rman_file() {
  local cmd_file="$1"

  {
    printf "validate current controlfile;\n"
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); the validate above sets the exit
    # status and reports any corruption on all supported releases.
  } >"$cmd_file" || die "Unable to write control-file validation RMAN file: $cmd_file"
}

write_redo_validation_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write redo validation SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
select group#, thread#, sequence#, bytes, blocksize, members, archived, status
from v$log
order by thread#, group#;
select group#, type, status, member
from v$logfile
order by group#, member;
alter system switch logfile;
select group#, thread#, sequence#, archived, status
from v$log
order by thread#, group#;
exit
SQL
}

write_redo_validation_rman_file() {
  local cmd_file="$1"

  {
    printf "run {\n"
    printf "  allocate channel csimv1 device type disk;\n"
    printf "  backup validate database;\n"
    printf "  release channel csimv1;\n"
    printf "}\n"
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); backup validate above sets the exit
    # status and reports any corruption on all supported releases.
  } >"$cmd_file" || die "Unable to write redo RMAN validation file: $cmd_file"
}

redo_replacement_diskgroup() {
  local member="$1"
  case "$member" in
    +DATA/*|+DATA) printf "+DATA" ;;
    +RECO/*|+RECO) printf "+RECO" ;;
    +*)
      printf "%s" "$member" | awk -F/ '{print $1}'
      ;;
    *)
      return "$FAIL"
      ;;
  esac
}

write_asm_redo_recovery_sql_file() {
  local group_no="$1"
  local missing_member="$2"
  local diskgroup="$3"
  local sql_file="$4"
  local missing_literal diskgroup_literal
  missing_literal="$(sql_quote "$missing_member")"
  diskgroup_literal="$(sql_quote "$diskgroup")"

  cat >"$sql_file" <<SQL || die "Unable to write ASM redo recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
alter system switch logfile;
alter system switch logfile;
alter system checkpoint;
declare
  l_member varchar2(512) := ${missing_literal};
  l_count number;
begin
  select count(*)
    into l_count
    from v\$logfile
   where member = l_member;

  if l_count > 0 then
    execute immediate 'alter database drop logfile member ''' ||
      replace(l_member, '''', '''''') || '''';
  else
    dbms_output.put_line('Redo member is already absent from control-file metadata: ' || l_member);
  end if;
end;
/
alter database add logfile member ${diskgroup_literal} to group ${group_no};
alter system switch logfile;
select l.group#, l.thread#, l.sequence#, l.status, l.archived, count(lf.member) members
from v\$log l join v\$logfile lf on lf.group# = l.group#
group by l.group#, l.thread#, l.sequence#, l.status, l.archived
order by l.thread#, l.group#;
select lf.group#, l.status, lf.member
from v\$logfile lf join v\$log l on l.group# = lf.group#
order by lf.group#, lf.member;
exit
SQL
}

write_pdb_open_sql_file() {
  local pdb_name="$1"
  local sql_file="$2"

  cat >"$sql_file" <<SQL || die "Unable to write PDB open SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
declare
  l_open_mode v\$pdbs.open_mode%type;
begin
  select open_mode
    into l_open_mode
    from v\$pdbs
   where name = '${pdb_name}';

  if l_open_mode not in ('READ WRITE', 'READ ONLY', 'READ ONLY WITH APPLY') then
    execute immediate 'alter pluggable database ${pdb_name} open';
  else
    dbms_output.put_line('PDB ${pdb_name} already open: ' || l_open_mode);
  end if;
end;
/
exit
SQL

  manifest_append "recover_pdb_open_sqlfile" "$sql_file"
}

load_manifest_datafile_numbers() {
  RECOVER_FILE_NOS=()

  local idx file_no count seen
  local key_prefix count_key

  for key_prefix in action target; do
    case "$key_prefix" in
      action) count_key="planned_action_count" ;;
      target) count_key="target_count" ;;
    esac
    count="$(manifest_get "$count_key" || true)"
    [[ "$count" =~ ^[0-9]+$ ]] || count=0

    idx=1
    while [[ "$idx" -le "$count" ]]; do
      file_no="$(manifest_get "${key_prefix}_${idx}_file_no" || true)"
      if [[ -n "$file_no" ]]; then
        [[ "$file_no" =~ ^[0-9]+$ ]] || die "Manifest has invalid FILE# for ${key_prefix}_${idx}: $file_no"
        seen=0
        local existing
        for existing in "${RECOVER_FILE_NOS[@]}"; do
          if [[ "$existing" == "$file_no" ]]; then
            seen=1
            break
          fi
        done
        [[ "$seen" -eq 1 ]] || RECOVER_FILE_NOS+=("$file_no")
      fi
      idx=$((idx + 1))
    done
  done

  if [[ "${#RECOVER_FILE_NOS[@]}" -eq 0 ]]; then
    file_no="$(manifest_first_value "recover_file_no" "target_1_file_no" "action_1_file_no" || true)"
    if [[ -n "$file_no" ]]; then
      [[ "$file_no" =~ ^[0-9]+$ ]] || die "Manifest has invalid FILE#: $file_no"
      seen=0
      local existing
      for existing in "${RECOVER_FILE_NOS[@]}"; do
        if [[ "$existing" == "$file_no" ]]; then
          seen=1
          break
        fi
      done
      [[ "$seen" -eq 1 ]] || RECOVER_FILE_NOS+=("$file_no")
    fi
  fi

  [[ "${#RECOVER_FILE_NOS[@]}" -gt 0 ]] || return "$FAIL"
}

scenario_uses_pdb_recovery() {
  local id="$1"
  case "$id" in
    30|32|33|34|35|37|39|40|41|42) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

recover_datafile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_file_recovery_automation "$id" ||
    die "Automated RMAN recovery is not registered for scenario ${id}. Use --runbook ${id} for manual guidance."

  CURRENT_SCENARIO_ID="$id"

  local file_no pdb_name existing_manifest created_manifest
  file_no="$TARGET_FILE_NO"
  pdb_name="$TARGET_PDB"
  existing_manifest=0
  created_manifest=0
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    existing_manifest=1
  fi

  if [[ -z "$file_no" && "$existing_manifest" -eq 1 ]]; then
    file_no="$(manifest_get "target_1_file_no" || true)"
    if [[ -z "$file_no" ]]; then
      file_no="$(manifest_get "action_1_file_no" || true)"
    fi
  fi
  if [[ "$id" == "30" && -z "$pdb_name" && "$existing_manifest" -eq 1 ]]; then
    pdb_name="$(manifest_get "target_1_pdb_name" || true)"
    if [[ -z "$pdb_name" ]]; then
      pdb_name="$(manifest_get "action_1_pdb_name" || true)"
    fi
  fi

  if [[ -z "$file_no" ]]; then
    warn "No --file-no or manifest file number was supplied; attempting live discovery."
    check_requirements "$id"
    if [[ "$existing_manifest" -eq 0 ]]; then
      init_manifest "recover" "$id"
      created_manifest=1
    fi
    plan_scenario_actions "$id"
    collect_datafile_plan
    file_no="${PLAN_TARGET_FILE_NOS[0]}"
    if [[ "$id" == "30" && -z "$pdb_name" ]]; then
      pdb_name="${PLAN_TARGET_PDBS[0]}"
    fi
  fi

  [[ -n "$file_no" && "$file_no" =~ ^[0-9]+$ ]] || die "Recovery requires a valid file number. Use --file-no <n> or --manifest <file>."

  if [[ "$id" == "30" ]]; then
    [[ -n "$pdb_name" ]] || die "Scenario 30 recovery requires --pdb <name> or a manifest with target_1_pdb_name."
    pdb_name="$(normalize_name "$pdb_name")"
    validate_oracle_name "$pdb_name" || die "Invalid PDB name: $pdb_name"
    TARGET_PDB="$pdb_name"
  fi

  if [[ "$existing_manifest" -eq 0 && "$created_manifest" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ "$existing_manifest" -eq 1 ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  local cmd_file log_file sql_file sql_log
  cmd_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}.rman"
  log_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}.log"
  if scenario_uses_pdb_recovery "$id"; then
    write_recover_pdb_datafile_rman_file "$file_no" "$cmd_file"
  else
    write_recover_rman_file "$id" "$file_no" "$cmd_file"
  fi
  manifest_append "recover_file_no" "$file_no"
  manifest_append "recover_rman_log" "$log_file"

  if [[ "$id" == "30" ]]; then
    sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_pdb.sql"
    sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_pdb.log"
    write_pdb_open_sql_file "$pdb_name" "$sql_file"
    manifest_append "recover_pdb_open_log" "$sql_log"
  fi

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "FILE#: ${file_no}"
  if [[ "$id" == "30" ]]; then
    echo "PDB: ${pdb_name}"
  fi
  if [[ -n "$MANIFEST_FILE" ]]; then
    echo "Manifest: ${MANIFEST_FILE}"
  fi
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  run_rman_cmdfile "$cmd_file" "$log_file"
  if [[ "$id" == "30" ]]; then
    run_sql_script_file "$sql_file" "$sql_log"
  fi
}

recover_datafile_list_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local file_list pdb_name cmd_file log_file validate_file validate_log sql_file sql_log has_restore_pairs
  load_manifest_datafile_numbers ||
    die "Manifest does not contain datafile FILE# metadata. Use a manifest from a scenario dry-run or executed run."
  file_list="$(join_csv "${RECOVER_FILE_NOS[@]}")"

  pdb_name="$TARGET_PDB"
  if scenario_uses_pdb_recovery "$id"; then
    if [[ -z "$pdb_name" ]]; then
      pdb_name="$(manifest_first_value "target_pdb" "action_1_pdb_name" || true)"
    fi
    [[ -n "$pdb_name" ]] || die "Scenario ${id} recovery requires --pdb or a manifest target PDB."
    pdb_name="$(normalize_name "$pdb_name")"
    validate_oracle_name "$pdb_name" || die "Invalid PDB name: $pdb_name"
    TARGET_PDB="$pdb_name"
  fi

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_file_list" "$file_list"

  cmd_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_datafiles.rman"
  log_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_datafiles.log"
  if scenario_uses_pdb_recovery "$id"; then
    write_recover_pdb_datafile_rman_file "$file_list" "$cmd_file"
  else
    write_recover_datafile_list_rman_file "$file_list" "$cmd_file"
  fi
  manifest_append "recover_rman_log" "$log_file"

  validate_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_datafiles.rman"
  validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_datafiles.log"
  write_validate_datafile_list_rman_file "$file_list" "$validate_file"
  manifest_append "recover_validate_rman_cmdfile" "$validate_file"
  manifest_append "recover_validate_rman_log" "$validate_log"

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_containers.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_open_containers.log"
  if scenario_uses_pdb_recovery "$id"; then
    write_pdb_open_sql_file "$pdb_name" "$sql_file"
  else
    write_open_pdbs_sql_file "$sql_file"
  fi
  manifest_append "recover_open_sqlfile" "$sql_file"
  manifest_append "recover_open_log" "$sql_log"

  has_restore_pairs=0
  if load_manifest_restore_pairs; then
    has_restore_pairs=1
  fi

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "FILE# list: ${file_list}"
  if scenario_uses_pdb_recovery "$id"; then
    echo "PDB: ${pdb_name}"
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  run_rman_cmdfile "$cmd_file" "$log_file"
  run_sql_script_file "$sql_file" "$sql_log"
  run_rman_cmdfile "$validate_file" "$validate_log"

  if [[ "$has_restore_pairs" -eq 1 ]]; then
    safe_remove_restore_backups
  fi
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_controlfile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local rman_file rman_log
  load_manifest_restore_pairs ||
    die "Manifest is missing control-file restore paths. Use a manifest from an executed scenario run."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_controlfile.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_controlfile.log"
  write_controlfile_validate_rman_file "$rman_file"
  manifest_append "recover_controlfile_validate_rman" "$rman_file"
  manifest_append "recover_controlfile_validate_log" "$rman_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Control file restore count: ${#RESTORE_ORIGINALS[@]}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  copy_restore_pairs_to_originals
  force_database_open
  run_rman_cmdfile "$rman_file" "$rman_log"

  safe_remove_restore_backups
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_redo_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local sql_file sql_log rman_file rman_log restore_pair_mode asm_redo_mode
  local redo_group redo_member redo_diskgroup
  restore_pair_mode=0
  asm_redo_mode=0
  if load_manifest_restore_pairs; then
    restore_pair_mode=1
  else
    redo_group="$(manifest_first_value "action_1_redo_group" "action_1_redo_group_no" || true)"
    redo_member="$(manifest_first_value "action_1_redo_member" "action_1_target" || true)"
    if [[ -n "$redo_group" && "$redo_group" =~ ^[0-9]+$ && "$redo_member" == +* ]]; then
      redo_diskgroup="$(redo_replacement_diskgroup "$redo_member" || true)"
      [[ -n "$redo_diskgroup" ]] || die "Unable to derive ASM disk group from redo member: $redo_member"
      asm_redo_mode=1
    else
      die "Manifest is missing redo restore paths or ASM redo metadata. Use a manifest from an executed scenario run."
    fi
  fi

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_redo.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_redo.log"
  if [[ "$asm_redo_mode" -eq 1 ]]; then
    write_asm_redo_recovery_sql_file "$redo_group" "$redo_member" "$redo_diskgroup" "$sql_file"
    manifest_append "recover_redo_asm_sqlfile" "$sql_file"
    manifest_append "recover_redo_asm_log" "$sql_log"
    manifest_append "recover_redo_group" "$redo_group"
    manifest_append "recover_redo_missing_member" "$redo_member"
    manifest_append "recover_redo_replacement_diskgroup" "$redo_diskgroup"
  else
    write_redo_validation_sql_file "$sql_file"
    manifest_append "recover_redo_validate_sqlfile" "$sql_file"
    manifest_append "recover_redo_validate_log" "$sql_log"
  fi

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_database.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_database.log"
  write_redo_validation_rman_file "$rman_file"
  manifest_append "recover_redo_validate_rman" "$rman_file"
  manifest_append "recover_redo_validate_rman_log" "$rman_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  if [[ "$asm_redo_mode" -eq 1 ]]; then
    echo "ASM redo group: ${redo_group}"
    echo "Missing member: ${redo_member}"
    echo "Replacement disk group: ${redo_diskgroup}"
  else
    echo "Redo member restore count: ${#RESTORE_ORIGINALS[@]}"
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$restore_pair_mode" -eq 1 ]]; then
    copy_restore_pairs_to_originals
  fi
  force_database_open
  run_sql_script_file "$sql_file" "$sql_log"
  run_rman_cmdfile "$rman_file" "$rman_log"

  if [[ "$restore_pair_mode" -eq 1 ]]; then
    safe_remove_restore_backups
  fi
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_tempfile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup pdb_name container_name sql_file sql_log has_restore_pairs target_tablespace
  load_manifest_tempfile_targets ||
    die "Manifest does not contain tempfile target metadata. Use a manifest from a scenario dry-run or executed run."
  original="${RECOVER_TEMPFILE_PATHS[0]}"
  backup=""
  has_restore_pairs=0
  if load_manifest_restore_pairs; then
    original="${RESTORE_ORIGINALS[0]}"
    backup="${RESTORE_BACKUPS[0]}"
    has_restore_pairs=1
  elif paths="$(manifest_rename_paths 2>/dev/null)"; then
    IFS='|' read -r original backup <<<"$paths"
  fi

  pdb_name="$TARGET_PDB"
  if [[ "$id" == "31" || "$id" == "38" ]]; then
    if [[ -z "$pdb_name" ]]; then
      pdb_name="$(manifest_first_value "target_pdb" "action_1_pdb_name" || true)"
      [[ -n "$pdb_name" ]] || pdb_name="$RECOVER_TEMPFILE_PDB"
    fi
  fi
  if [[ "$id" == "31" || "$id" == "38" ]]; then
    [[ -n "$pdb_name" ]] || die "Scenario ${id} recovery requires --pdb or a manifest target PDB."
    pdb_name="$(normalize_name "$pdb_name")"
    validate_oracle_name "$pdb_name" || die "Invalid PDB name: $pdb_name"
    TARGET_PDB="$pdb_name"
    container_name="$pdb_name"
  else
    container_name="CDB\$ROOT"
  fi

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"
  manifest_append "recover_tempfile_count" "${#RECOVER_TEMPFILE_PATHS[@]}"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Container: ${container_name}"
  echo "Tempfile target count: ${#RECOVER_TEMPFILE_PATHS[@]}"
  local tempfile_path
  for tempfile_path in "${RECOVER_TEMPFILE_PATHS[@]}"; do
    echo "  ${tempfile_path}"
  done
  if [[ -n "$backup" ]]; then
    echo "Scenario backup: ${backup}"
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_tempfile.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_tempfile.log"
  target_tablespace="$RECOVER_TEMPFILE_TABLESPACE"
  if [[ "${#RECOVER_TEMPFILE_PATHS[@]}" -eq 1 && -z "$target_tablespace" ]]; then
    write_tempfile_recovery_sql_file "$container_name" "$original" "$sql_file"
  else
    write_tempfile_list_recovery_sql_file "$container_name" "$target_tablespace" "$sql_file" "${RECOVER_TEMPFILE_PATHS[@]}"
  fi
  manifest_append "recover_tempfile_sqlfile" "$sql_file"
  manifest_append "recover_tempfile_log" "$sql_log"
  run_sql_script_file "$sql_file" "$sql_log"

  if [[ "$has_restore_pairs" -eq 1 ]]; then
    safe_remove_restore_backups
  elif [[ -n "$backup" ]]; then
    safe_remove_after_validation "$backup"
  fi
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_password_file_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup password_display orapwd_bin
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"
  password_display="********"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Password file: ${original}"
  echo "Scenario backup: ${backup}"
  echo "SYSBACKUP user to restore if present: ${SYSBACKUP_USER:-none}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  # Checked BEFORE the typed confirmations: execute-mode recovery recreates the
  # password file with orapwd, which needs the SYS password - discovering that
  # only after RECOVER-<id> and LAB-APPROVED wastes the operator's gates
  # (field-tested 2026-07-18).
  [[ -n "$SYS_PASSWORD" || "$EXECUTE" -eq 0 ]] ||
    die "Password-file recovery execution requires --sys-password or CRASHSIM_SYS_PASSWORD."
  confirm_mode_execution "RECOVER" "$id"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run orapwd file=${original} password=${password_display} entries=30 force=y"
  else
    ensure_database_open
    echo "orapwd file=${original} password=${password_display} entries=30 force=y"
    orapwd_bin="$(ensure_orapwd)"
    "$orapwd_bin" file="$original" password="$SYS_PASSWORD" entries=30 force=y ||
      die "orapwd failed for $original"
  fi

  restore_sysbackup_user_if_present
  remote_sysdba_test
  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

write_spfile_recovery_sql_file() {
  local pfile_path="$1"
  local spfile_path="$2"
  local sql_file="$3"
  local mode="$4"

  if [[ "$mode" == "cold" ]]; then
    cat >"$sql_file" <<SQL || die "Unable to write SPFILE recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
startup nomount pfile='${pfile_path}'
create spfile='${spfile_path}' from pfile='${pfile_path}';
shutdown abort
startup
exit
SQL
  else
    cat >"$sql_file" <<SQL || die "Unable to write SPFILE recovery SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
create spfile='${spfile_path}' from pfile='${pfile_path}';
shutdown abort
startup
exit
SQL
  fi
}

recover_spfile_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup status_file status sql_file sql_log rman_file rman_log recovery_mode
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "SPFILE path: ${original}"
  echo "Scenario backup: ${backup}"
  if [[ -n "$PFILE_PATH" ]]; then
    echo "PFILE: ${PFILE_PATH}"
  else
    echo "PFILE: not supplied; will restore the scenario backup if execution is requested."
  fi
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"

  if [[ -n "$PFILE_PATH" ]]; then
    [[ "$EXECUTE" -eq 0 || -f "$PFILE_PATH" ]] || die "PFILE not found: $PFILE_PATH"
    status_file="$WORK_DIR/spfile_instance_status.out"
    recovery_mode="warm"
    if [[ "$EXECUTE" -eq 1 ]]; then
      if ! query_instance_status "$status_file"; then
        recovery_mode="cold"
      else
        status="$(trim_blank_lines <"$status_file" | head -n 1 | tr -d ' ')"
        [[ -n "$status" ]] || recovery_mode="cold"
      fi
    fi

    sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_spfile.sql"
    sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_spfile.log"
    write_spfile_recovery_sql_file "$PFILE_PATH" "$original" "$sql_file" "$recovery_mode"
    manifest_append "recover_spfile_sqlfile" "$sql_file"
    manifest_append "recover_spfile_log" "$sql_log"
    run_sql_script_file "$sql_file" "$sql_log"
    ensure_database_open
  else
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would copy validated scenario backup $backup back to $original"
    else
      [[ -f "$backup" ]] || die "Scenario SPFILE backup not found: $backup"
      echo "cp -p -- $backup $original"
      cp -p -- "$backup" "$original" || die "Unable to restore SPFILE from scenario backup."
      ensure_database_open
    fi
  fi

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_spfile.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_spfile.log"
  {
    printf "validate spfile;\n"
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); validate spfile sets the exit
    # status on all supported releases.
  } >"$rman_file" || die "Unable to write SPFILE validation RMAN file: $rman_file"
  manifest_append "recover_spfile_validate_rman" "$rman_file"
  manifest_append "recover_spfile_validate_log" "$rman_log"
  run_rman_cmdfile "$rman_file" "$rman_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_fs_rename_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  load_manifest_restore_pairs ||
    die "Manifest is missing restore paths. Use a manifest from an executed scenario run."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Restore pair count: ${#RESTORE_ORIGINALS[@]}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  move_restore_pairs_to_originals
  run_health_check
  safe_remove_restore_backups
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_archivelog_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup seq rman_file rman_log restore_file restore_log
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Archived log: ${original}"
  echo "Scenario backup: ${backup}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would discover archived-log sequence for $original"
    echo "DRY-RUN: would crosscheck missing log, copy $backup to $original, crosscheck again, validate, then remove backup"
    return "$SUCCESS"
  fi

  seq="$(archivelog_sequence_for_path "$original")" ||
    die "Could not determine archived-log sequence for $original"
  manifest_append "recover_archivelog_sequence" "$seq"

  rman_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_archivelog.rman"
  rman_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_archivelog.log"
  {
    printf "crosscheck archivelog sequence %s;\n" "$seq"
    printf "list archivelog sequence %s;\n" "$seq"
  } >"$rman_file" || die "Unable to write archived-log crosscheck RMAN file: $rman_file"
  run_rman_cmdfile "$rman_file" "$rman_log"

  [[ -f "$backup" ]] || die "Archived-log scenario backup not found: $backup"
  echo "cp -p -- $backup $original"
  cp -p -- "$backup" "$original" || die "Unable to copy archived-log backup to original path."

  restore_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_archivelog.rman"
  restore_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_archivelog.log"
  {
    printf "crosscheck archivelog sequence %s;\n" "$seq"
    printf "validate archivelog sequence %s;\n" "$seq"
    printf "list archivelog sequence %s;\n" "$seq"
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); crosscheck/validate above set the
    # exit status on all supported releases.
  } >"$restore_file" || die "Unable to write archived-log validation RMAN file: $restore_file"
  manifest_append "recover_archivelog_validate_rman" "$restore_file"
  manifest_append "recover_archivelog_validate_log" "$restore_log"
  run_rman_cmdfile "$restore_file" "$restore_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_rman_backup_piece_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local paths original backup bs_key missing_file missing_log validate_file validate_log
  paths="$(manifest_rename_paths)" || die "Manifest is missing scenario rename paths. Use a manifest from an executed scenario run."
  IFS='|' read -r original backup <<<"$paths"

  [[ "$original" == /* ]] || die "Scenario 25 recovery supports local filesystem backup pieces only: $original"
  [[ "$backup" == /* ]] || die "Scenario 25 recovery backup must be a local filesystem path: $backup"

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_original_path" "$original"
  manifest_append "recover_backup_path" "$backup"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Backup piece: ${original}"
  echo "Scenario backup: ${backup}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  ensure_database_open

  bs_key="$(backupset_key_for_piece "$original")" ||
    die "Could not determine RMAN backup set key for backup piece: $original"
  manifest_append "recover_backupset_key" "$bs_key"

  missing_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_backuppiece.rman"
  missing_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_missing_backuppiece.log"
  {
    printf "crosscheck backupset %s;\n" "$bs_key"
    printf "list backupset %s;\n" "$bs_key"
  } >"$missing_file" || die "Unable to write backup-piece crosscheck RMAN file: $missing_file"
  manifest_append "recover_backuppiece_missing_rman" "$missing_file"
  manifest_append "recover_backuppiece_missing_log" "$missing_log"
  run_rman_cmdfile "$missing_file" "$missing_log"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would copy $backup back to $original"
  else
    [[ -f "$backup" ]] || die "Scenario backup piece not found: $backup"
    echo "cp -p -- $backup $original"
    cp -p -- "$backup" "$original" || die "Unable to copy backup piece back to original path."
  fi

  validate_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_backuppiece.rman"
  validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_validate_backuppiece.log"
  {
    printf "crosscheck backupset %s;\n" "$bs_key"
    printf "list backupset %s;\n" "$bs_key"
    printf "validate backupset %s;\n" "$bs_key"
    # Data Recovery Advisor 'list failure' is desupported in 23ai (RMAN-01009
    # parse error aborts the whole cmdfile); crosscheck/validate above set the
    # exit status on all supported releases.
  } >"$validate_file" || die "Unable to write backup-piece validation RMAN file: $validate_file"
  manifest_append "recover_backuppiece_validate_rman" "$validate_file"
  manifest_append "recover_backuppiece_validate_log" "$validate_log"
  run_rman_cmdfile "$validate_file" "$validate_log"

  safe_remove_after_validation "$backup"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_fra_full_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local original_size sql_file sql_log
  original_size="$(manifest_get "fra_original_size_bytes" || true)"
  [[ "$original_size" =~ ^[0-9]+$ ]] ||
    die "Manifest is missing fra_original_size_bytes. Use a manifest from executed scenario 61."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_restore_fra_size.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_restore_fra_size.log"
  write_fra_restore_sql_file "$sql_file" "$original_size"
  manifest_append "recover_fra_restore_sqlfile" "$sql_file"
  manifest_append "recover_fra_restore_log" "$sql_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Restore DB_RECOVERY_FILE_DEST_SIZE to: ${original_size}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run SQL script ${sql_file}"
    echo "DRY-RUN: would restore DB_RECOVERY_FILE_DEST_SIZE to ${original_size}"
    return "$SUCCESS"
  fi

  run_sql_script_file "$sql_file" "$sql_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

srvctl_database_is_running() {
  local output_file="$1"
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  srvctl status database -d "$DB_UNIQUE_NAME" >"$output_file" 2>&1 || return "$FAIL"
  grep -Eq 'is running|is online|Instance .* is running' "$output_file"
}

srvctl_service_is_running() {
  local output_file="$1"
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  srvctl status service -d "$DB_UNIQUE_NAME" >"$output_file" 2>&1 || return "$FAIL"
  grep -Eq 'is running|is online|running on instance' "$output_file"
}

recover_srvctl_database_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  if [[ -n "$DB_UNIQUE_NAME" ]] && ! validate_oracle_name "$DB_UNIQUE_NAME"; then
    DB_UNIQUE_NAME=""
  fi
  if [[ -z "$DB_UNIQUE_NAME" && -n "${ORACLE_UNQNAME:-}" ]]; then
    DB_UNIQUE_NAME="$ORACLE_UNQNAME"
  fi
  if [[ -z "$DB_UNIQUE_NAME" ]] && command -v srvctl >/dev/null 2>&1; then
    local srvctl_dbs
    mapfile -t srvctl_dbs < <(srvctl config database 2>/dev/null | trim_blank_lines)
    if [[ "${#srvctl_dbs[@]}" -eq 1 ]]; then
      DB_UNIQUE_NAME="${srvctl_dbs[0]}"
    fi
  fi
  if [[ -z "$INSTANCE_NAME" && -n "${ORACLE_SID:-}" ]]; then
    INSTANCE_NAME="$ORACLE_SID"
  fi
  if [[ -z "$CLUSTER_TYPE" || "$CLUSTER_TYPE" == "UNKNOWN" ]]; then
    CLUSTER_TYPE="GI_SINGLE"
  fi
  [[ -n "$DB_UNIQUE_NAME" ]] ||
    die "Scenario 55 recovery requires DB_UNIQUE_NAME. Set ORACLE_UNQNAME or run with --sqlplus-logon against an open database."

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Database resource: ${DB_UNIQUE_NAME}"
  echo "Instance: ${INSTANCE_NAME}"
  echo "Cluster type: ${CLUSTER_TYPE}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run srvctl status database -d ${DB_UNIQUE_NAME}"
    echo "DRY-RUN: would run srvctl start database -d ${DB_UNIQUE_NAME} if the database is not running"
    echo "DRY-RUN: would run srvctl start service -d ${DB_UNIQUE_NAME} if services are not running"
    echo "DRY-RUN: would validate database/PDB health with SQL*Plus"
    return "$SUCCESS"
  fi

  local db_status_file service_status_file
  db_status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_srvctl_database_status.log"
  service_status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_srvctl_service_status.log"
  manifest_append "recover_srvctl_database_status_log" "$db_status_file"
  manifest_append "recover_srvctl_service_status_log" "$service_status_file"

  if srvctl_database_is_running "$db_status_file"; then
    echo "Database resource is already running."
  else
    echo "srvctl start database -d ${DB_UNIQUE_NAME}"
    srvctl start database -d "$DB_UNIQUE_NAME" ||
      die "Unable to start database resource ${DB_UNIQUE_NAME}"
  fi

  if srvctl_service_is_running "$service_status_file"; then
    echo "Database services are already running."
  else
    echo "srvctl start service -d ${DB_UNIQUE_NAME}"
    srvctl start service -d "$DB_UNIQUE_NAME" ||
      warn "srvctl start service reported a non-zero status; continuing to SQL health validation."
  fi

  ensure_database_open
  run_health_check
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_rac_service_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  if [[ -z "$DB_UNIQUE_NAME" && -n "${ORACLE_UNQNAME:-}" ]]; then
    DB_UNIQUE_NAME="$ORACLE_UNQNAME"
  fi
  if [[ -z "$DB_UNIQUE_NAME" && -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    DB_UNIQUE_NAME="$(manifest_get "db_unique_name" || true)"
    [[ "$DB_UNIQUE_NAME" == "unknown" ]] && DB_UNIQUE_NAME=""
  fi
  if [[ -z "$DB_UNIQUE_NAME" ]]; then
    local srvctl_dbs
    mapfile -t srvctl_dbs < <(srvctl config database 2>/dev/null | trim_blank_lines)
    if [[ "${#srvctl_dbs[@]}" -eq 1 ]]; then
      DB_UNIQUE_NAME="${srvctl_dbs[0]}"
    fi
  fi
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"

  local service status_file service_status
  service="$SERVICE_NAME"
  if [[ -z "$service" && -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    service="$(manifest_first_value "scenario_56_service" "action_1_target" || true)"
  fi
  if [[ -z "$service" ]]; then
    local services_file
    services_file="$WORK_DIR/recover_s56_services.lst"
    srvctl config service -d "$DB_UNIQUE_NAME" >"$services_file" 2>&1 ||
      die "Unable to collect srvctl service configuration for ${DB_UNIQUE_NAME}."
    service="$(awk -F': ' '/^Service name:/ {print $2; exit}' "$services_file")"
  fi
  [[ -n "$service" ]] || die "Scenario 56 recovery could not determine a service. Use --service-name or a scenario manifest."

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_service_status.log"
  manifest_append "recover_service_name" "$service"
  manifest_append "recover_service_status_log" "$status_file"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Service: ${service}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run srvctl status service -d ${DB_UNIQUE_NAME} -s ${service}"
    echo "DRY-RUN: would run srvctl start service -d ${DB_UNIQUE_NAME} -s ${service} if the service is not running"
    echo "DRY-RUN: would validate database/PDB health with SQL*Plus"
    return "$SUCCESS"
  fi

  service_status="$(srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" 2>&1 | tee "$status_file")" || true
  if printf "%s\n" "$service_status" | grep -Eq 'is running|running on instance'; then
    echo "Service ${service} is already running."
  else
    echo "srvctl start service -d ${DB_UNIQUE_NAME} -s ${service}"
    srvctl start service -d "$DB_UNIQUE_NAME" -s "$service" ||
      die "Unable to start service ${service}."
    srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" | tee -a "$status_file"
  fi

  run_health_check
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_standby_apply_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  local apply_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_restart_apply.log"
  local validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_apply_status.log"
  manifest_append "recover_standby_apply_log" "$apply_log"
  manifest_append "recover_standby_apply_status_log" "$validate_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would restart managed standby recovery"
    echo "DRY-RUN: would query V\$MANAGED_STANDBY and V\$DATAGUARD_STATS"
    return "$SUCCESS"
  fi

  check_requirements "$id"
  run_sql_text "restart managed standby recovery" "
alter database recover managed standby database disconnect from session;
" "$apply_log"
  run_sql_text "validate standby apply status" "
select process || '|' || status
from v\$managed_standby
where process like 'MRP%'
order by process;
select name || '=' || nvl(value, 'UNKNOWN') || ' ' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
" "$validate_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_dg_transport_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  local dest_id dest_log validate_log
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    dest_id="$(manifest_first_value "dg_dest_id" || true)"
  else
    dest_id=""
  fi

  if [[ -z "$dest_id" ]]; then
    warn "No Data Guard destination id was found in the manifest; attempting live destination discovery."
    check_requirements "$id"
    local dest_file="$WORK_DIR/recover_dg_transport_dest.lst"
    query_targets "$dest_file" "
select dest_id
from (
  select dest_id
  from v\$archive_dest
  where target = 'STANDBY'
    and destination is not null
  order by case status when 'VALID' then 1 else 2 end, dest_id
)
where rownum = 1;
"
    [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No remote standby archive destination was found for recovery."
    dest_id="${TARGET_ROWS[0]}"
  fi
  [[ "$dest_id" =~ ^[0-9]+$ ]] || die "Invalid Data Guard destination id for recovery: ${dest_id}"

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  dest_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_enable_dest_${dest_id}.log"
  validate_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_transport_status.log"
  manifest_append "recover_dg_dest_id" "$dest_id"
  manifest_append "recover_dg_enable_log" "$dest_log"
  manifest_append "recover_dg_transport_status_log" "$validate_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Remote archive destination: LOG_ARCHIVE_DEST_${dest_id}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would enable LOG_ARCHIVE_DEST_STATE_${dest_id}"
    echo "DRY-RUN: would force a log switch and inspect V\$ARCHIVE_DEST / V\$DATAGUARD_STATS"
    return "$SUCCESS"
  fi

  check_requirements "$id"
  run_sql_text "enable Data Guard transport destination ${dest_id}" "
alter system set log_archive_dest_state_${dest_id}=enable scope=both;
alter system archive log current;
" "$dest_log"
  run_sql_text "validate Data Guard transport status" "
select dest_id || '|' || status || '|' || target || '|' || nvl(error, 'NO_ERROR')
from v\$archive_dest
where dest_id = ${dest_id};
select name || '=' || nvl(value, 'UNKNOWN') || ' ' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
" "$validate_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_ords_service_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  local service status_file smoke_file service_from_manifest lb_from_manifest effective_lb_url
  service="$ORDS_SERVICE_NAME"
  effective_lb_url="$ORDS_LB_URL"
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    service_from_manifest="$(manifest_first_value "ords_service_name" "action_1_target" || true)"
    [[ -n "$service_from_manifest" ]] && service="$service_from_manifest"
    lb_from_manifest="$(manifest_first_value "ords_lb_url" || true)"
    [[ -z "$effective_lb_url" && -n "$lb_from_manifest" ]] && effective_lb_url="$lb_from_manifest"
  fi
  [[ -n "$service" ]] || die "ORDS service name was not supplied."

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  status_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_ords_status.log"
  smoke_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_ords_smoke.md"
  manifest_append "recover_ords_service_name" "$service"
  manifest_append "recover_ords_status_log" "$status_file"
  manifest_append "recover_ords_smoke_report" "$smoke_file"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "ORDS service: ${service}"
  echo "ORDS URL: ${ORDS_URL}"
  [[ -n "$effective_lb_url" ]] && echo "ORDS continuity URL: ${effective_lb_url}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would start ORDS service ${service}"
    echo "DRY-RUN: would validate ${ORDS_URL}"
    [[ -n "$effective_lb_url" ]] && echo "DRY-RUN: would validate ${effective_lb_url}"
    return "$SUCCESS"
  fi

  perform_systemctl_service_action start "$service"
  if command -v systemctl >/dev/null 2>&1; then
    systemctl status "$service" >"$status_file" 2>&1 || true
  fi
  if [[ -n "$effective_lb_url" && -z "$ORDS_LB_URL" ]]; then
    ORDS_LB_URL="$effective_lb_url"
  fi
  write_apex_ords_smoke_report "$smoke_file" "CrashSimulator ORDS Recovery Smoke Evidence"
  cat "$smoke_file"
  maybe_render_html "$smoke_file"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_apex_runtime_account_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  CURRENT_SCENARIO_ID="$id"

  local runtime_user runtime_container container_sql sql_file sql_log user_file
  runtime_user=""
  runtime_container=""
  if [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]]; then
    runtime_user="$(manifest_first_value "apex_runtime_user" "action_1_target" || true)"
    runtime_user="${runtime_user##*alter user }"
    runtime_user="${runtime_user%% account*}"
    runtime_container="$(manifest_first_value "apex_runtime_target_container" || true)"
  fi
  if [[ -z "$runtime_user" ]]; then
    user_file="$WORK_DIR/recover_apex_runtime_user.lst"
    query_apex_ords_runtime_user "$user_file" ||
      die "Could not discover an APEX/ORDS runtime account to unlock. Use --manifest from scenario 76 or select the correct PDB."
    runtime_user="${TARGET_ROWS[0]}"
  fi
  runtime_user="$(normalize_name "$runtime_user")"
  validate_oracle_name "$runtime_user" || die "Invalid runtime user for recovery: $runtime_user"
  runtime_container="$(normalize_name "$runtime_container")"
  if [[ -n "$runtime_container" ]]; then
    validate_oracle_name "$runtime_container" || die "Invalid runtime container for recovery: $runtime_container"
    container_sql="$(printf "alter session set container = %s;\n" "$(sql_identifier "$runtime_container")")"
  else
    container_sql="$(apex_ords_container_sql_prefix)"
    runtime_container="$(printf "%s" "$container_sql" | sed -n 's/^alter session set container = "\{0,1\}\([^";]*\)"\{0,1\};$/\1/p' | head -1)"
  fi

  if [[ -z "$MANIFEST_FILE" || "$MANIFEST_FROM_ARG" -eq 0 ]]; then
    init_manifest "recover" "$id"
  elif [[ -f "$MANIFEST_FILE" ]]; then
    manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi

  sql_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_unlock_runtime_user.sql"
  sql_log="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_unlock_runtime_user.log"
  {
    printf 'whenever sqlerror exit sql.sqlcode\n'
    printf 'set feedback on pages 100 lines 220\n'
    printf '%s\n' "$container_sql"
    printf 'alter user %s account unlock;\n' "$runtime_user"
    printf "select username, account_status from dba_users where username = '%s';\n" "$runtime_user"
    printf 'exit\n'
  } >"$sql_file" || die "Unable to write APEX/ORDS runtime recovery SQL file: $sql_file"

  manifest_append "recover_apex_runtime_user" "$runtime_user"
  manifest_append "recover_apex_runtime_container" "$runtime_container"
  manifest_append "recover_apex_runtime_sqlfile" "$sql_file"
  manifest_append "recover_apex_runtime_log" "$sql_log"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "Runtime user: ${runtime_user}"
  [[ -n "$runtime_container" ]] && echo "Runtime container: ${runtime_container}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would unlock ${runtime_user} using ${sql_file}"
    return "$SUCCESS"
  fi
  run_sql_script_file "$sql_file" "$sql_log"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_ords_pool_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  require_manifest

  local original_service bad_service smoke_file
  original_service="$(manifest_get "ords_pool_original_servicename" || true)"
  bad_service="$(manifest_get "ords_pool_bad_servicename" || true)"
  [[ -n "$original_service" ]] ||
    die "Manifest is missing ords_pool_original_servicename; use the manifest from executed scenario 75."

  manifest_append "recovery_started_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  manifest_append "recover_ords_pool_original_servicename" "$original_service"
  [[ -n "$bad_service" ]] && manifest_append "recover_ords_pool_bad_servicename" "$bad_service"

  smoke_file="${LOG_DIR}/crashsim_recover_s${id}_${RUN_ID}_ords_pool_smoke.md"
  manifest_append "recover_ords_pool_smoke_report" "$smoke_file"

  echo "Recover scenario ${id}: ${SCENARIO_TITLE[$id]}"
  echo "Mode: $([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
  echo "ORDS config: ${ORDS_CONFIG_DIR}"
  echo "Restore db.servicename: ${original_service}"
  [[ -n "$bad_service" ]] && echo "Lab-bad db.servicename: ${bad_service}"
  echo "Manifest: ${MANIFEST_FILE}"
  echo
  print_recovery_runbook "$id"
  echo

  confirm_mode_execution "RECOVER" "$id"
  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would restore ORDS db.servicename to ${original_service}"
    echo "DRY-RUN: would restart ORDS service ${ORDS_SERVICE_NAME}"
    echo "DRY-RUN: would validate ${ORDS_URL}"
    return "$SUCCESS"
  fi

  ords_config_set_value db.servicename "$original_service" ||
    die "Unable to restore ORDS db.servicename."
  perform_systemctl_service_action restart "$ORDS_SERVICE_NAME"
  write_apex_ords_smoke_report "$smoke_file" "CrashSimulator ORDS Pool Recovery Smoke Evidence"
  cat "$smoke_file"
  maybe_render_html "$smoke_file"
  manifest_append "recovery_completed_at_utc" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}

recover_scenario() {
  local id="$1"
  scenario_exists "$id" || die "Unknown scenario id: $id"
  supports_recovery_automation "$id" ||
    die "Automated recovery is not yet implemented for scenario $id. Use --runbook $id for manual guidance."

  case "$id" in
    1|2|23)
      recover_controlfile_scenario "$id"
      ;;
    3|4|18|19|20|21|24)
      recover_redo_scenario "$id"
      ;;
    5|30)
      recover_datafile_scenario "$id"
      ;;
    6|13|31|38)
      recover_tempfile_scenario "$id"
      ;;
    7|8|9|10|12|14|15|17|22|32|33|34|35|37|39|40|41|42)
      recover_datafile_list_scenario "$id"
      ;;
    16)
      recover_password_file_scenario "$id"
      ;;
    25)
      recover_rman_backup_piece_scenario "$id"
      ;;
    26)
      recover_spfile_scenario "$id"
      ;;
    27|57|58)
      recover_fs_rename_scenario "$id"
      ;;
    50|67)
      recover_standby_apply_scenario "$id"
      ;;
    51|68)
      recover_dg_transport_scenario "$id"
      ;;
    73|79)
      recover_ords_service_scenario "$id"
      ;;
    74|77)
      recover_fs_rename_scenario "$id"
      ;;
    75)
      recover_ords_pool_scenario "$id"
      ;;
    76)
      recover_apex_runtime_account_scenario "$id"
      ;;
    55)
      recover_srvctl_database_scenario "$id"
      ;;
    56|71)
      recover_rac_service_scenario "$id"
      ;;
    59)
      recover_archivelog_scenario "$id"
      ;;
    61)
      recover_fra_full_scenario "$id"
      ;;
    62)
      recover_archivelog_scenario "$id"
      ;;
  esac
}

print_runbook_only() {
  local id="$1"
  local runbook_file
  scenario_exists "$id" || die "Unknown scenario id: $id"

  runbook_file="${LOG_DIR}/crashsim_runbook_s${id}_${RUN_ID}.txt"
  {
    echo "Scenario ${id}: ${SCENARIO_TITLE[$id]}"
    echo "Group: ${SCENARIO_GROUP[$id]}"
    echo "Scope: ${SCENARIO_SCOPE[$id]}"
    echo "Impact: ${SCENARIO_IMPACT[$id]}"
    echo "Requires: ${SCENARIO_REQUIRES[$id]}"
    echo "Notes: ${SCENARIO_NOTES[$id]}"
    echo "Generated UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo
    print_recovery_runbook "$id"
  } >"$runbook_file" || die "Unable to write runbook artifact: $runbook_file"

  cat "$runbook_file"
  echo
  echo "Runbook artifact: ${runbook_file}"
  maybe_render_html "$runbook_file"
}

script_dir() {
  local source_path="${BASH_SOURCE[0]}"
  local dir_name
  dir_name="$(dirname "$source_path")"
  (cd "$dir_name" >/dev/null 2>&1 && pwd)
}

run_project_tool() {
  local tool_name="$1"
  shift
  local tool_path
  tool_path="$(script_dir)/tools/${tool_name}"
  [[ -f "$tool_path" ]] || die "Required helper was not found: $tool_path"
  if [[ -x "$tool_path" ]]; then
    "$tool_path" "$@"
  else
    bash "$tool_path" "$@"
  fi
}

run_secret_scan() {
  run_project_tool "crashsim_secret_scan.sh" "$SECRET_SCAN_PATH"
}

run_sanitize_artifacts() {
  local -a args=("--source" "$SANITIZE_SOURCE_DIR")
  [[ -n "$SANITIZE_OUTPUT_DIR" ]] && args+=("--output" "$SANITIZE_OUTPUT_DIR")
  run_project_tool "crashsim_sanitize_artifacts.sh" "${args[@]}"
}

run_release_check() {
  run_project_tool "crashsim_release_check.sh"
}

run_node_sync_check() {
  run_project_tool "crashsim_node_sync_check.sh"
}

write_builtin_health_check_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write health-check SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
column name format a30
column database_role format a22
column open_mode format a22
column cdb format a5
column instance_name format a20
column status format a14
column pdb_name format a30
column file_name format a120

select name, database_role, open_mode, cdb
from v$database;

select instance_name, status, database_status, active_state
from v$instance;

declare
  l_cdb v$database.cdb%type;
begin
  select cdb into l_cdb from v$database;
  dbms_output.put_line('CDB=' || l_cdb);
  if l_cdb = 'YES' then
    for r in (
      select name, open_mode
      from v$pdbs
      where name <> 'PDB$SEED'
      order by con_id
    ) loop
      dbms_output.put_line('PDB ' || r.name || ' open_mode=' || r.open_mode);
    end loop;
  end if;
end;
/

select count(*) as recover_file_count
from v$recover_file;

select count(*) as block_corruption_count
from v$database_block_corruption;

exit
SQL
}

run_health_check() {
  local repo_sql sql_file log_file
  repo_sql="$(script_dir)/drill_health_check.sql"
  sql_file="$repo_sql"
  log_file="${LOG_DIR}/crashsim_health_check_${RUN_ID}.log"

  if [[ ! -f "$sql_file" ]]; then
    sql_file="${LOG_DIR}/crashsim_health_check_${RUN_ID}.sql"
    write_builtin_health_check_sql_file "$sql_file"
  fi

  echo "Running health check"
  echo "SQL file: ${sql_file}"
  echo "Log file: ${log_file}"
  echo

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$log_file" </dev/null ||
    die "Health check failed: $sql_file (log: $log_file)"

  sed 's/^/  /' "$log_file"
  maybe_render_html "$log_file"
}

run_baseline_backup() {
  local helper status
  local -a cmd=()

  helper="$(script_dir)/crashsim_run_baseline_backup.sh"
  [[ -f "$helper" ]] || die "Baseline backup helper not found: $helper"

  if [[ -x "$helper" ]]; then
    cmd=("$helper")
  else
    cmd=(bash "$helper")
  fi

  cmd+=("--log-dir" "$LOG_DIR")
  cmd+=("--tag-prefix" "$BASELINE_TAG_PREFIX")
  [[ "$EXECUTE" -eq 1 ]] && cmd+=("--execute") || cmd+=("--dry-run")
  [[ "$ASSUME_YES" -eq 1 ]] && cmd+=("--yes")
  [[ "$VERBOSE" -eq 1 ]] && cmd+=("--verbose")

  env CRASHSIM_RMAN_CATALOG="$RMAN_CATALOG_CONNECT" "${cmd[@]}"
  status=$?
  if [[ "$status" -ne 0 ]]; then
    die "Baseline backup helper failed with status ${status}."
  fi
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    local baseline_artifact
    baseline_artifact="$(find_latest_artifact baseline 2>/dev/null || true)"
    [[ -n "$baseline_artifact" ]] && render_artifact_html "$baseline_artifact"
  fi
}

prepare_reset() {
  PREP_IDS=()
  PREP_TITLE=()
  PREP_STATUS=()
  PREP_REQUIRED=()
  PREP_EVIDENCE_TEXT=()
  PREP_ACTION=()
  PREP_AUTO=()
  PREP_COMMAND=()
  PREP_NOTES=()
}

prepare_add() {
  local id="$1" title="$2" status="$3" required="$4" evidence="$5" action="$6" auto="$7" command="$8" notes="$9"
  PREP_IDS+=("$id")
  PREP_TITLE[$id]="$title"
  PREP_STATUS[$id]="$status"
  PREP_REQUIRED[$id]="$required"
  PREP_EVIDENCE_TEXT[$id]="$evidence"
  PREP_ACTION[$id]="$action"
  PREP_AUTO[$id]="$auto"
  PREP_COMMAND[$id]="$command"
  PREP_NOTES[$id]="$notes"
}

prepare_value() {
  local key="$1"
  local default="${2:-UNKNOWN}"
  printf "%s" "${PREP_EVIDENCE[$key]:-$default}"
}

parse_prepare_evidence_file() {
  local file="$1"
  local line key value

  PREP_EVIDENCE=()
  [[ -f "$file" ]] || return "$FAIL"
  while IFS= read -r line; do
    case "$line" in
      *CSIM_PREP\|*\|*)
        key="${line#*CSIM_PREP|}"
        value="${key#*|}"
        key="${key%%|*}"
        PREP_EVIDENCE[$key]="$value"
        ;;
    esac
  done <"$file"
}

write_prepare_environment_sql_file() {
  local sql_file="$1"
  local target_pdb_literal
  target_pdb_literal="$(sql_quote "$TARGET_PDB")"

  cat >"$sql_file" <<SQL || die "Unable to write prepare-environment SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback off pages 0 lines 32767 trimspool on verify off

declare
  l_cdb varchar2(3) := 'NO';
  l_target_pdb varchar2(128) := ${target_pdb_literal};
  l_target_con_id number := null;

  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_PREP|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  function scalar_value(p_sql varchar2, p_default varchar2 := 'UNKNOWN') return varchar2 is
    l_value varchar2(32767);
  begin
    execute immediate p_sql into l_value;
    return nvl(l_value, p_default);
  exception
    when others then
      return 'ERROR:' || sqlcode;
  end;

  function scalar_count(p_sql varchar2) return varchar2 is
    l_value number;
  begin
    execute immediate p_sql into l_value;
    return to_char(nvl(l_value, 0));
  exception
    when others then
      return 'ERROR:' || sqlcode;
  end;
begin
  select cdb into l_cdb from v\$database;

  emit('db_name', scalar_value(q'[select name from v\$database]'));
  emit('db_unique_name', scalar_value(q'[select db_unique_name from v\$database]'));
  emit('database_role', scalar_value(q'[select database_role from v\$database]'));
  emit('open_mode', scalar_value(q'[select open_mode from v\$database]'));
  emit('cdb', l_cdb);
  emit('log_mode', scalar_value(q'[select log_mode from v\$database]'));
  emit('flashback_on', scalar_value(q'[select flashback_on from v\$database]'));
  emit('fs_failover_status', scalar_value(q'[select fs_failover_status from v\$database]'));
  emit('fs_failover_observer_present', scalar_value(q'[select fs_failover_observer_present from v\$database]'));
  emit('dg_broker_start', scalar_value(q'[select value from v\$parameter where name = 'dg_broker_start']'));
  emit('standby_dest_count', scalar_count(q'[select count(*) from v\$archive_dest where target = 'STANDBY' and destination is not null]'));
  emit('redo_groups_under2', scalar_count(q'[select count(*) from v\$log where members < 2]'));
  emit('redo_min_members', scalar_value(q'[select min(members) from v\$log]', '0'));
  emit('control_file_count', scalar_count(q'[select count(*) from v\$controlfile]'));
  emit('fra_dest', scalar_value(q'[select value from v\$parameter where name = 'db_recovery_file_dest']', ''));
  emit('db_create_file_dest', scalar_value(q'[select value from v\$parameter where name = 'db_create_file_dest']', ''));

  if l_cdb = 'YES' then
    if l_target_pdb is null then
      begin
        select coalesce(
                 max(case when name = 'CRASHPDB' and open_mode = 'READ WRITE' then name end),
                 min(case when name <> 'PDB\$SEED' and open_mode = 'READ WRITE' then name end)
               )
        into l_target_pdb
        from v\$pdbs;
      exception
        when others then
          l_target_pdb := null;
      end;
    end if;

    if l_target_pdb is not null then
      begin
        execute immediate 'select con_id from v\$pdbs where name = :1' into l_target_con_id using upper(l_target_pdb);
      exception
        when others then
          l_target_con_id := null;
      end;
    end if;

    emit('target_pdb', l_target_pdb);
    emit('target_con_id', case when l_target_con_id is null then null else to_char(l_target_con_id) end);
    emit('root_lab_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'C##CRASHSIM_ROOT_LAB']'));
    emit('root_lab_tablespace_count', scalar_count(q'[select count(*) from cdb_tablespaces where tablespace_name in ('CRASHSIM_ROOT_RO_TBS','CRASHSIM_ROOT_INDEX_TBS')]'));
    if l_target_con_id is not null then
      emit('pdb_lab_user_count', scalar_count('select count(*) from cdb_users where con_id = ' || l_target_con_id || q'[ and username in ('CRASHSIM_TABLE_LAB','CRASHSIM_SCHEMA_LAB','CRASHSIM_INDEX_LAB')]'));
      emit('pdb_lab_tablespace_count', scalar_count('select count(*) from cdb_tablespaces where con_id = ' || l_target_con_id || q'[ and tablespace_name in ('CRASHSIM_RO_TBS','CRASHSIM_INDEX_TBS')]'));
      emit('target_apex_registry_count', scalar_count('select count(*) from cdb_registry where con_id = ' || l_target_con_id || q'[ and (comp_id = 'APEX' or upper(comp_name) like '%APEX%')]'));
      emit('target_ords_user_count', scalar_count('select count(*) from cdb_users where con_id = ' || l_target_con_id || q'[ and username in ('ORDS_PUBLIC_USER','ORDS_METADATA','APEX_PUBLIC_USER')]'));
    else
      emit('pdb_lab_user_count', '0');
      emit('pdb_lab_tablespace_count', '0');
      emit('target_apex_registry_count', '0');
      emit('target_ords_user_count', '0');
    end if;
    emit('catalog_owner_count', scalar_count(q'[select count(*) from cdb_role_privs where granted_role = 'RECOVERY_CATALOG_OWNER']'));
    emit('catalog_metadata_count', scalar_count(q'[select count(*) from cdb_objects where object_name = 'RC_DATABASE' and owner not in ('SYS','SYSTEM')]'));
  else
    emit('target_pdb', '');
    emit('target_con_id', '');
    emit('root_lab_user_count', '0');
    emit('root_lab_tablespace_count', '0');
    emit('pdb_lab_user_count', scalar_count(q'[select count(*) from dba_users where username in ('CRASHSIM_TABLE_LAB','CRASHSIM_SCHEMA_LAB','CRASHSIM_INDEX_LAB')]'));
    emit('pdb_lab_tablespace_count', scalar_count(q'[select count(*) from dba_tablespaces where tablespace_name in ('CRASHSIM_RO_TBS','CRASHSIM_INDEX_TBS')]'));
    emit('target_apex_registry_count', scalar_count(q'[select count(*) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']'));
    emit('target_ords_user_count', scalar_count(q'[select count(*) from dba_users where username in ('ORDS_PUBLIC_USER','ORDS_METADATA','APEX_PUBLIC_USER')]'));
    emit('catalog_owner_count', scalar_count(q'[select count(*) from dba_role_privs where granted_role = 'RECOVERY_CATALOG_OWNER']'));
    emit('catalog_metadata_count', scalar_count(q'[select count(*) from dba_objects where object_name = 'RC_DATABASE' and owner not in ('SYS','SYSTEM')]'));
  end if;

  emit('service_crashsim_count', scalar_count(q'[select count(*) from dba_services where lower(name) in ('crashsim_ac','crashsim_tac')]'));
  emit('service_crashsim_ha_count', scalar_count(q'[select count(*) from dba_services where lower(name) in ('crashsim_ac','crashsim_tac') and (aq_ha_notifications = 'YES' or failover_type in ('TRANSACTION','AUTO'))]'));
end;
/

exit
SQL
}

collect_prepare_environment_evidence() {
  local sql_file="$1" evidence_file="$2"
  write_prepare_environment_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Prepare-environment SQL failed: $sql_file (evidence: $evidence_file)"
  parse_prepare_evidence_file "$evidence_file"

  PREP_EVIDENCE[cluster_type]="$CLUSTER_TYPE"
  PREP_EVIDENCE[storage_type]="$STORAGE_TYPE"
  PREP_EVIDENCE[gi_managed]="$GI_MANAGED"
  PREP_EVIDENCE[instance_parallel]="$INSTANCE_PARALLEL"
  PREP_EVIDENCE[db_unique_name_discovered]="$DB_UNIQUE_NAME"
  PREP_EVIDENCE[baseline_artifact_count]="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_baseline_backup_*.log' 2>/dev/null | wc -l | tr -d '[:space:]')"
  PREP_EVIDENCE[ords_binary]="$(command -v ords 2>/dev/null || true)"
  if command -v systemctl >/dev/null 2>&1; then
    PREP_EVIDENCE[ords_service_state]="$(systemctl is-active "$ORDS_SERVICE_NAME" 2>/dev/null || true)"
  else
    PREP_EVIDENCE[ords_service_state]="systemctl_not_found"
  fi
  if [[ -d "$ORDS_CONFIG_DIR" ]]; then
    PREP_EVIDENCE[ords_config_state]="present"
  else
    PREP_EVIDENCE[ords_config_state]="missing"
  fi
  if [[ -n "$APEX_IMAGES_DIR" && -d "$APEX_IMAGES_DIR" ]]; then
    PREP_EVIDENCE[apex_images_state]="present"
  else
    PREP_EVIDENCE[apex_images_state]="missing"
  fi
}

prepare_numeric_ge() {
  local value="$1" threshold="$2"
  [[ "$value" =~ ^[0-9]+$ && "$value" -ge "$threshold" ]]
}

prepare_is_primary() {
  [[ "$(prepare_value database_role)" == "PRIMARY" ]]
}

prepare_is_cdb() {
  [[ "$(prepare_value cdb)" == "YES" ]]
}

evaluate_prepare_environment() {
  local script_root
  local cdb redo_under control_count service_count service_ha_count apex_count ords_count
  local root_users root_tbs pdb_users pdb_tbs catalog_owners catalog_metadata baseline_count
  local dg_dest fsfo_status fsfo_observer cluster storage gi ords_bin ords_service ords_config apex_images

  prepare_reset
  script_root="$(script_dir)"
  cdb="$(prepare_value cdb)"
  redo_under="$(prepare_value redo_groups_under2 0)"
  control_count="$(prepare_value control_file_count 0)"
  service_count="$(prepare_value service_crashsim_count 0)"
  service_ha_count="$(prepare_value service_crashsim_ha_count 0)"
  apex_count="$(prepare_value target_apex_registry_count 0)"
  ords_count="$(prepare_value target_ords_user_count 0)"
  root_users="$(prepare_value root_lab_user_count 0)"
  root_tbs="$(prepare_value root_lab_tablespace_count 0)"
  pdb_users="$(prepare_value pdb_lab_user_count 0)"
  pdb_tbs="$(prepare_value pdb_lab_tablespace_count 0)"
  catalog_owners="$(prepare_value catalog_owner_count 0)"
  catalog_metadata="$(prepare_value catalog_metadata_count 0)"
  baseline_count="$(prepare_value baseline_artifact_count 0)"
  dg_dest="$(prepare_value standby_dest_count 0)"
  fsfo_status="$(prepare_value fs_failover_status UNKNOWN)"
  fsfo_observer="$(prepare_value fs_failover_observer_present UNKNOWN)"
  cluster="$(prepare_value cluster_type "$CLUSTER_TYPE")"
  storage="$(prepare_value storage_type "$STORAGE_TYPE")"
  gi="$(prepare_value gi_managed "$GI_MANAGED")"
  ords_bin="$(prepare_value ords_binary)"
  ords_service="$(prepare_value ords_service_state)"
  ords_config="$(prepare_value ords_config_state)"
  apex_images="$(prepare_value apex_images_state)"

  if prepare_is_cdb; then
    if prepare_numeric_ge "$root_users" 1 && prepare_numeric_ge "$root_tbs" 2 &&
       prepare_numeric_ge "$pdb_users" 3 && prepare_numeric_ge "$pdb_tbs" 2; then
      prepare_add "logical_lab" "Logical/root/PDB lab objects" "PRESENT" "Required for table/schema/index/read-only/index-only scenarios" \
        "root_users=${root_users}, root_tbs=${root_tbs}, pdb_users=${pdb_users}, pdb_tbs=${pdb_tbs}, target_pdb=$(prepare_value target_pdb)" \
        "No action needed." "no" "" "Re-run only when logical drills intentionally dropped lab objects."
    else
      prepare_add "logical_lab" "Logical/root/PDB lab objects" "MISSING" "Required for scenarios 9-11, 34-36, 43-44 and related logical drills" \
        "root_users=${root_users}, root_tbs=${root_tbs}, pdb_users=${pdb_users}, pdb_tbs=${pdb_tbs}, target_pdb=$(prepare_value target_pdb)" \
        "Run tools/crashsim_seed_lab.sh (recreates disposable CRASHSIM lab schemas and tablespaces; prompts for a lab password)." \
        "yes" "${script_root}/tools/crashsim_seed_lab.sh --connect \"${SQLPLUS_LOGON}\"" \
        "Destructive only to CRASHSIM disposable lab schemas/tablespaces. During --execute preparation the lab password is generated automatically."
    fi
  elif prepare_numeric_ge "$pdb_users" 3 && prepare_numeric_ge "$pdb_tbs" 2; then
    prepare_add "logical_lab" "Logical lab objects" "PRESENT" "Required for logical scenarios" \
      "users=${pdb_users}, tbs=${pdb_tbs}" "No action needed." "no" "" "Non-CDB seed posture detected."
  else
    prepare_add "logical_lab" "Logical lab objects" "PLAN_ONLY" "Required for logical scenarios" \
      "cdb=${cdb}, users=${pdb_users}, tbs=${pdb_tbs}" \
      "Create/reseed disposable CRASHSIM schemas and read-only/index-only tablespaces for this non-CDB target." \
      "no" "" "Current seed_crashsim_lab.sql is CDB-oriented; use a non-CDB seed helper before automation."
  fi

  if [[ "$redo_under" =~ ^[0-9]+$ && "$redo_under" -eq 0 ]]; then
    prepare_add "redo_multiplex" "Multiplex online redo logs" "PRESENT" "Required for redo-loss scenarios 3 and 18" \
      "redo_groups_under2=${redo_under}, min_members=$(prepare_value redo_min_members)" "No action needed." "no" "" "Redo is already multiplexed."
  elif prepare_is_primary; then
    prepare_add "redo_multiplex" "Multiplex online redo logs" "MISSING" "Required for redo-loss scenarios 3 and 18" \
      "redo_groups_under2=${redo_under}, storage=${storage}, fra=$(prepare_value fra_dest)" \
      "Add missing redo members using the topology-aware redo preparation SQL." \
      "yes" "${SQLPLUS_BIN:-sqlplus} ${SQLPLUS_LOGON} @${script_root}/prepare_crashsim_fex_redo_multiplex.sql" \
      "Uses the configured recovery destination for this FEX/OCI posture."
  else
    prepare_add "redo_multiplex" "Multiplex online redo logs" "NOT_REQUIRED" "Primary database required" \
      "role=$(prepare_value database_role)" "Run only on the primary database." "no" "" ""
  fi

  if [[ "$control_count" =~ ^[0-9]+$ && "$control_count" -ge 2 ]]; then
    prepare_add "controlfile_multiplex" "Multiplex control files" "PRESENT" "Recommended before control-file scenarios 1, 2, and 23" \
      "control_file_count=${control_count}" "No action needed." "no" "" "Control files are already multiplexed."
  elif prepare_is_primary; then
    prepare_add "controlfile_multiplex" "Multiplex control files" "PLAN_ONLY" "Recommended before control-file scenarios 1, 2, and 23" \
      "control_file_count=${control_count}, storage=${storage}" \
      "Generate provider-aware control-file multiplexing runbook." \
      "no" "${script_root}/prepare_crashsim_fex_controlfile_multiplex.sh --dry-run --log-dir ${LOG_DIR}" \
      "Requires outage/restart and provider-approved byte-copy or CREATE CONTROLFILE procedure; not auto-executed."
  else
    prepare_add "controlfile_multiplex" "Multiplex control files" "NOT_REQUIRED" "Primary database required" \
      "role=$(prepare_value database_role)" "Run only on the primary database." "no" "" ""
  fi

  if [[ "$cluster" == RAC* || "$cluster" == "GI_SINGLE" || "$gi" == "1" ]]; then
    if prepare_numeric_ge "$service_count" 2 && prepare_numeric_ge "$service_ha_count" 2; then
      prepare_add "services_ac_tac" "AC/TAC/FAN lab services" "PRESENT" "Required for service continuity scenarios 56, 83, 84, and 87" \
        "services=${service_count}, ha_services=${service_ha_count}" "No action needed." "no" "" "CrashSimulator AC/TAC services are present."
    else
      prepare_add "services_ac_tac" "AC/TAC/FAN lab services" "MISSING" "Required for service continuity scenarios 56, 83, 84, and 87" \
        "cluster=${cluster}, services=${service_count}, ha_services=${service_ha_count}" \
        "Create or repair crashsim_ac and crashsim_tac services with FAN/AC/TAC attributes." \
        "yes" "${script_root}/tools/crashsim_configure_ha_lab.sh --services" \
        "Requires srvctl/GI privileges and current DB_UNIQUE_NAME/PDB defaults."
    fi
  else
    prepare_add "services_ac_tac" "AC/TAC/FAN lab services" "NOT_REQUIRED" "RAC/GI-managed topology required" \
      "cluster=${cluster}, gi=${gi}" "Standalone database does not need RAC service lab seeds." "no" "" ""
  fi

  if prepare_numeric_ge "$apex_count" 1 && prepare_numeric_ge "$ords_count" 2 &&
     [[ -n "$ords_bin" && "$ords_service" == "active" && "$ords_config" == "present" ]]; then
    prepare_add "apex_ords" "APEX/ORDS application access path" "PRESENT" "Required for APEX/ORDS scenarios 73-82" \
      "apex=${apex_count}, ords_users=${ords_count}, ords_service=${ords_service}, config=${ords_config}, images=${apex_images}" \
      "No action needed." "no" "" "Scenario 79 still needs a load-balancer or peer URL when executed."
  else
    prepare_add "apex_ords" "APEX/ORDS application access path" "MISSING" "Required for APEX/ORDS scenarios 73-82" \
      "apex=${apex_count}, ords_users=${ords_count}, ords_bin=${ords_bin:-not_found}, ords_service=${ords_service}, config=${ords_config}, images=${apex_images}" \
      "Install/configure APEX and ORDS with the lab helper when media and passwords are approved." \
      "conditional" "${script_root}/tools/crashsim_install_apex_ords_lab.sh" \
      "Requires APEX/ORDS media plus SYS_PASSWORD, ORDS_PUBLIC_PASSWORD, and APEX_ADMIN_PASSWORD environment variables."
  fi

  if [[ -n "$RMAN_CATALOG_CONNECT" ]] || prepare_numeric_ge "$catalog_metadata" 1; then
    if prepare_numeric_ge "$catalog_metadata" 1; then
      prepare_add "rman_catalog" "RMAN recovery catalog" "PRESENT" "Required for catalog outage and catalog-aware backup evidence" \
        "catalog_owners=${catalog_owners}, catalog_metadata=${catalog_metadata}, configured=$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)" \
        "No action needed." "no" "" "Confirm catalog is outside the target failure domain for production-like DR tests."
    else
      prepare_add "rman_catalog" "RMAN recovery catalog" "MISSING" "Required for catalog outage and catalog-aware backup evidence" \
        "catalog_owners=${catalog_owners}, catalog_metadata=${catalog_metadata}, configured=yes" \
        "Create local lab recovery catalog metadata and register/resync the target." \
        "conditional" "${script_root}/tools/crashsim_configure_ha_lab.sh --catalog" \
        "Requires CRASHSIM_RMAN_CATALOG_PASSWORD; production catalogs should live outside the target DB."
    fi
  else
    prepare_add "rman_catalog" "RMAN recovery catalog" "MISSING" "Optional unless testing recovery-catalog scenarios/reporting" \
      "catalog_owners=${catalog_owners}, catalog_metadata=${catalog_metadata}, configured=no" \
      "Set CRASHSIM_RMAN_CATALOG and create/configure a catalog when catalog scenarios are in scope." \
      "conditional" "${script_root}/tools/crashsim_configure_ha_lab.sh --catalog" \
      "Skipped by default because it requires credentials and topology decisions."
  fi

  if prepare_numeric_ge "$dg_dest" 1 || [[ "$(prepare_value database_role)" == *"STANDBY"* ]]; then
    if [[ "$fsfo_status" == *"SYNCHRONIZED"* || "$fsfo_status" == *"TARGET"* || "$fsfo_status" == *"ENABLED"* || "$fsfo_observer" == "YES" ]]; then
      prepare_add "fsfo" "Data Guard FSFO observer posture" "PRESENT" "Required for FSFO observer scenario 66 and FSFO MAA evidence" \
        "dg_dest=${dg_dest}, fsfo_status=${fsfo_status}, observer=${fsfo_observer}" "No action needed." "no" "" "Validate observer placement and preferred observer hosts."
    else
      prepare_add "fsfo" "Data Guard FSFO observer posture" "PLAN_ONLY" "Required for FSFO observer scenario 66 and FSFO MAA evidence" \
        "dg_dest=${dg_dest}, fsfo_status=${fsfo_status}, observer=${fsfo_observer}, broker=$(prepare_value dg_broker_start)" \
        "Run FSFO readiness checks and configure observer only after Broker, flashback, SRLs, transport, and apply are healthy." \
        "no" "${script_root}/tools/crashsim_configure_ha_lab.sh --fsfo-check" \
        "FSFO enablement is disruptive/risk-sensitive and remains runbook-driven."
    fi
  else
    prepare_add "fsfo" "Data Guard FSFO observer posture" "NOT_REQUIRED" "Data Guard topology required" \
      "dg_dest=${dg_dest}, role=$(prepare_value database_role)" "No standby/transport evidence detected." "no" "" ""
  fi

  if [[ "$storage" == "ASM" || "$storage" == "FEX_ACFS" || "$gi" == "1" ]]; then
    prepare_add "asm_gi_redundant_lab" "ASM/GI redundant storage lab" "PLAN_ONLY" "Required for ASM/FEX/GI destructive storage scenarios 46-49 and 72" \
      "storage=${storage}, gi=${gi}" \
      "Review or create a purpose-built redundant GI/ASM lab with additional shared disks and failgroups." \
      "no" "${script_root}/crashsim_prepare_redundant_gi_lab.sh --dry-run" \
      "Needs explicit disk/LUN approval; never auto-create storage from the generic prepare menu."
  else
    prepare_add "asm_gi_redundant_lab" "ASM/GI redundant storage lab" "NOT_REQUIRED" "ASM/GI/FEX topology required" \
      "storage=${storage}, gi=${gi}" "Filesystem-only topology does not require ASM/GI storage lab seeds." "no" "" ""
  fi

  if prepare_numeric_ge "$baseline_count" 1; then
    prepare_add "baseline_backup" "Fresh RMAN baseline backup evidence" "PRESENT" "Recommended after environment preparation changes" \
      "baseline_logs=${baseline_count}, catalog_configured=$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)" \
      "Run again after executing any preparation changes." "no" "" "Use Reports -> Run fresh RMAN baseline backup after changes."
  else
    prepare_add "baseline_backup" "Fresh RMAN baseline backup evidence" "MISSING" "Recommended before destructive scenario batches" \
      "baseline_logs=${baseline_count}, catalog_configured=$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)" \
      "Run a dry-run or confirmed baseline backup from the Reports menu." \
      "no" "${SCRIPT_PATH} --baseline-backup --dry-run" \
      "Not auto-executed because it can consume backup storage and I/O."
  fi
}

write_prepare_environment_report() {
  local report_file="$1" evidence_file="$2"
  local id generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf "# CrashSimulator Seed / Prepare Environment Planner\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(md_escape "$(prepare_value db_name "$DB_NAME")")"
    printf -- '- DB unique name: `%s`\n' "$(md_escape "$(prepare_value db_unique_name "$DB_UNIQUE_NAME")")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(md_escape "$(prepare_value database_role "$DB_ROLE")")" "$(md_escape "$(prepare_value open_mode "$DB_OPEN_MODE")")"
    printf -- '- CDB / target PDB: `%s` / `%s`\n' "$(md_escape "$(prepare_value cdb "$DB_CDB")")" "$(md_escape "$(prepare_value target_pdb "${TARGET_PDB:-not selected}")")"
    printf -- '- Cluster/storage: `%s` / `%s`\n' "$(md_escape "$(prepare_value cluster_type "$CLUSTER_TYPE")")" "$(md_escape "$(prepare_value storage_type "$STORAGE_TYPE")")"
    printf -- '- Mode: `%s`\n' "$([[ "$EXECUTE" -eq 1 ]] && echo EXECUTE || echo DRY-RUN)"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This planner detects missing lab seeds and environment preparations needed by the scenario catalog. It only recommends actions relevant to the current topology. Execution remains guarded; credentials, storage provisioning, FSFO enablement, and provider-specific copy operations are not guessed.\n"
  } >"$report_file" || die "Unable to write prepare-environment report: $report_file"

  append_report_section "$report_file" "Preparation Matrix"
  {
    printf '| ID | Preparation | Status | Required for | Evidence | Action | Auto-execute |\n'
    printf '| --- | --- | --- | --- | --- | --- | --- |\n'
    for id in "${PREP_IDS[@]}"; do
      printf '| `%s` | %s | `%s` | %s | %s | %s | `%s` |\n' \
        "$(md_escape "$id")" \
        "$(md_escape "${PREP_TITLE[$id]}")" \
        "$(md_escape "${PREP_STATUS[$id]}")" \
        "$(md_escape "${PREP_REQUIRED[$id]}")" \
        "$(md_escape "${PREP_EVIDENCE_TEXT[$id]}")" \
        "$(md_escape "${PREP_ACTION[$id]}")" \
        "$(md_escape "${PREP_AUTO[$id]}")"
    done
  } >>"$report_file"

  append_report_section "$report_file" "Suggested Commands"
  {
    printf '| ID | Command / Helper |\n'
    printf '| --- | --- |\n'
    for id in "${PREP_IDS[@]}"; do
      [[ -n "${PREP_COMMAND[$id]}" ]] || continue
      printf '| `%s` | `%s` |\n' "$(md_escape "$id")" "$(md_escape "${PREP_COMMAND[$id]}")"
    done
  } >>"$report_file"

  append_report_section "$report_file" "Notes And Guardrails"
  {
    for id in "${PREP_IDS[@]}"; do
      [[ -n "${PREP_NOTES[$id]}" ]] || continue
      printf -- '- `%s`: %s\n' "$(md_escape "$id")" "$(md_escape "${PREP_NOTES[$id]}")"
    done
  } >>"$report_file"

  append_report_section "$report_file" "Raw Evidence"
  {
    printf '```text\n'
    for id in "${!PREP_EVIDENCE[@]}"; do
      printf 'CSIM_PREP|%s|%s\n' "$id" "${PREP_EVIDENCE[$id]}"
    done | sort
    printf '```\n'
  } >>"$report_file"
}

confirm_prepare_environment_execution() {
  local token="PREPARE-ENVIRONMENT"

  [[ "$EXECUTE" -eq 1 ]] || return "$SUCCESS"
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    require_destructive_lab_ack "environment preparation"
    return "$SUCCESS"
  fi
  confirm_show "" \
    "About to execute eligible CrashSimulator environment preparation helpers." \
    "Database: ${DB_UNIQUE_NAME:-unknown} ($(prepare_value database_role "$DB_ROLE"), $(prepare_value open_mode "$DB_OPEN_MODE"))" \
    "Only items marked auto-execute yes/conditional and currently missing will be attempted." \
    "Type ${token} to continue:"
  local answer
  confirm_reply answer
  [[ "$answer" == "$token" ]] || die "Confirmation did not match. Aborting."
  require_destructive_lab_ack "environment preparation"
}

# Generate a strong, SQL*Plus-safe password for the disposable CRASHSIM lab
# users. These users are never logged into (drills act on their objects via
# SYSDBA), so the value only needs to satisfy Oracle complexity at creation and
# is never recorded. Excludes " ' & \\ and whitespace so it is safe inside a
# SQL*Plus DEFINE and a double-quoted Oracle password.
generate_lab_password() {
  local body
  body="$(LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom 2>/dev/null | head -c 24)"
  [[ ${#body} -ge 16 ]] || body="Fallback$$$(date +%s 2>/dev/null)"
  printf 'Lb#%sz9' "$body"
}

# Run seed_crashsim_lab.sql with a generated lab password supplied via a DEFINE
# on stdin (never argv, never a temp file; seed_crashsim_lab.sql sets
# 'verify off' so the value is not echoed). Mirrors tools/crashsim_seed_lab.sh
# for the monolith's automated environment preparation.
run_seed_lab_prepare() {
  local id="$1" seed="$2"
  local pw
  pw="$(generate_lab_password)"
  echo
  echo "Preparing ${id}: ${PREP_TITLE[$id]}"
  echo "Command: (piped) ${SQLPLUS_BIN} -s ${SQLPLUS_LOGON} @${seed} [lab password generated, not shown]"
  printf 'define crashsim_lab_password = "%s"\n@%s\n' "$pw" "$seed" \
    | "$SQLPLUS_BIN" -s ${SQLPLUS_LOGON}
  local rc=$?
  unset pw
  return "$rc"
}

run_prepare_helper_command() {
  local id="$1"
  shift
  echo
  echo "Preparing ${id}: ${PREP_TITLE[$id]}"
  printf "Command:"
  printf " %q" "$@"
  printf "\n"
  "$@"
}

execute_prepare_environment_actions() {
  local id helper status
  local script_root
  script_root="$(script_dir)"

  [[ "$EXECUTE" -eq 1 ]] || return "$SUCCESS"
  confirm_prepare_environment_execution

  for id in "${PREP_IDS[@]}"; do
    [[ "${PREP_STATUS[$id]}" == "MISSING" ]] || continue
    case "$id" in
      logical_lab)
        [[ "${PREP_AUTO[$id]}" == "yes" ]] || continue
        run_seed_lab_prepare "$id" "${script_root}/seed_crashsim_lab.sql" \
          >"${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log" 2>&1
        status=$?
        [[ "$status" -eq 0 ]] || die "Preparation ${id} failed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        echo "Preparation ${id} completed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        ;;
      redo_multiplex)
        [[ "${PREP_AUTO[$id]}" == "yes" ]] || continue
        helper="${script_root}/prepare_crashsim_fex_redo_multiplex.sql"
        [[ -f "$helper" ]] || die "Redo preparation SQL not found: $helper"
        run_prepare_helper_command "$id" "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$helper" \
          >"${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log" 2>&1
        status=$?
        [[ "$status" -eq 0 ]] || die "Preparation ${id} failed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        echo "Preparation ${id} completed. Log: ${LOG_DIR}/crashsim_prepare_${id}_${RUN_ID}.log"
        ;;
      services_ac_tac)
        [[ "${PREP_AUTO[$id]}" == "yes" ]] || continue
        helper="${script_root}/tools/crashsim_configure_ha_lab.sh"
        [[ -f "$helper" ]] || die "HA lab helper not found: $helper"
        run_prepare_helper_command "$id" bash "$helper" --services
        ;;
      apex_ords)
        [[ "${PREP_AUTO[$id]}" == "conditional" ]] || continue
        if [[ -n "${SYS_PASSWORD:-}" && -n "${ORDS_PUBLIC_PASSWORD:-}" && -n "${APEX_ADMIN_PASSWORD:-}" ]]; then
          helper="${script_root}/tools/crashsim_install_apex_ords_lab.sh"
          [[ -f "$helper" ]] || die "APEX/ORDS lab helper not found: $helper"
          run_prepare_helper_command "$id" bash "$helper"
        else
          warn "Skipping ${id}: SYS_PASSWORD, ORDS_PUBLIC_PASSWORD, and APEX_ADMIN_PASSWORD must be set in the environment."
        fi
        ;;
      rman_catalog)
        [[ "${PREP_AUTO[$id]}" == "conditional" ]] || continue
        if [[ -n "${CRASHSIM_RMAN_CATALOG_PASSWORD:-}" ]]; then
          helper="${script_root}/tools/crashsim_configure_ha_lab.sh"
          [[ -f "$helper" ]] || die "HA lab helper not found: $helper"
          run_prepare_helper_command "$id" bash "$helper" --catalog
        else
          warn "Skipping ${id}: CRASHSIM_RMAN_CATALOG_PASSWORD is required."
        fi
        ;;
      *)
        ;;
    esac
  done
}

run_prepare_environment() {
  local sql_file evidence_file report_file

  discover_environment
  ensure_sqlplus
  sql_file="${LOG_DIR}/crashsim_prepare_environment_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_prepare_environment_${RUN_ID}.evidence"
  report_file="${LOG_DIR}/crashsim_prepare_environment_${RUN_ID}.md"

  collect_prepare_environment_evidence "$sql_file" "$evidence_file"
  evaluate_prepare_environment
  write_prepare_environment_report "$report_file" "$evidence_file"
  echo "Seed/prepare environment planner generated: ${report_file}"
  maybe_render_html "$report_file"

  execute_prepare_environment_actions
}

html_escape_stream() {
  awk '
    function esc(s) {
      gsub(/&/, "\\&amp;", s)
      gsub(/</, "\\&lt;", s)
      gsub(/>/, "\\&gt;", s)
      return s
    }
    { print esc($0) }
  '
}

render_artifact_html() {
  local input_file="$1"
  local output_file="${2:-}"
  local title generated

  [[ -f "$input_file" ]] || die "Artifact not found: $input_file"
  [[ -n "$output_file" ]] || output_file="${input_file}.html"
  title="$(basename "$input_file")"
  generated="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  {
    printf '%s\n' '<!doctype html>'
    printf '%s\n' '<html lang="en">'
    printf '%s\n' '<head>'
    printf '%s\n' '<meta charset="utf-8">'
    printf '<title>%s</title>\n' "$(printf "%s" "$title" | html_escape_stream)"
    printf '%s\n' '<style>'
    printf '%s\n' ':root { color-scheme: light dark; }'
    printf '%s\n' 'body { margin: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; background: #f6f7f9; color: #16181d; }'
    printf '%s\n' 'main { max-width: 1180px; margin: 0 auto; padding: 28px; }'
    printf '%s\n' 'header { margin-bottom: 18px; border-bottom: 1px solid #d8dde6; padding-bottom: 14px; }'
    printf '%s\n' 'h1 { font-size: 22px; margin: 0 0 8px; }'
    printf '%s\n' '.meta { font-size: 13px; color: #596170; line-height: 1.5; }'
    printf '%s\n' 'pre { white-space: pre-wrap; word-break: break-word; background: #fff; border: 1px solid #d8dde6; border-radius: 8px; padding: 18px; overflow: auto; line-height: 1.45; font-size: 13px; }'
    printf '%s\n' '@media (prefers-color-scheme: dark) { body { background: #101318; color: #eef1f5; } pre { background: #161a22; border-color: #303846; } header { border-color: #303846; } .meta { color: #a9b2c3; } }'
    printf '%s\n' '</style>'
    printf '%s\n' '</head>'
    printf '%s\n' '<body><main>'
    printf '<header><h1>%s</h1><div class="meta">Source: %s<br>Generated UTC: %s</div></header>\n' \
      "$(printf "%s" "$title" | html_escape_stream)" \
      "$(printf "%s" "$input_file" | html_escape_stream)" \
      "$(printf "%s" "$generated" | html_escape_stream)"
    printf '%s\n' '<pre>'
    audit_redact_stream <"$input_file" | html_escape_stream
    printf '%s\n' '</pre>'
    printf '%s\n' '</main></body></html>'
  } >"$output_file" || die "Unable to write HTML artifact: $output_file"

  echo "HTML artifact generated: ${output_file}"
}

maybe_render_html() {
  local input_file="$1"
  [[ "$HTML_OUTPUT" -eq 1 ]] || return "$SUCCESS"
  render_artifact_html "$input_file"
}

find_latest_artifact() {
  local kind="${1:-any}"
  local latest=""

  case "$kind" in
    topology)
      if [[ -f "${LOG_DIR}/crashsim_topology_latest.txt" ]]; then
        latest="${LOG_DIR}/crashsim_topology_latest.txt"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_topology_*.txt' 2>/dev/null | sort | tail -n 1)"
      fi
      [[ -n "$latest" ]] || latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_config_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    config|configuration)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_config_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    backup|backup-report|recoverability)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_backup_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    service|services|service-review|service-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_service_review_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    apex-ords|apex|ords|apex-report|ords-report|apex-ords-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_apex_ords_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    prepare|seed|prepare-environment|seed-environment|lab-prepare)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_prepare_environment_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    adb|autonomous|autonomous-database|adb-report|adb-readiness)
      if [[ -f "${LOG_DIR}/crashsim_adb_readiness_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_adb_readiness_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_adb_readiness_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    scenario-readiness|readiness|scenario-availability|topology-scenarios)
      if [[ -f "${LOG_DIR}/crashsim_scenario_readiness_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_scenario_readiness_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_readiness_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    lifecycle|scenario-lifecycle|lifecycle-report|scenario-coverage)
      if [[ -f "${LOG_DIR}/crashsim_scenario_lifecycle_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_scenario_lifecycle_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_lifecycle_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    maa|maa-report)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_maa_report_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    resilience|resilience-score|resilience-scorecard|scorecard)
      if [[ -f "${LOG_DIR}/crashsim_resilience_scorecard_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_resilience_scorecard_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    health)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_health_check_*.log' 2>/dev/null | sort | tail -n 1)"
      ;;
    doctor|preflight|public-readiness)
      if [[ -f "${LOG_DIR}/crashsim_doctor_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_doctor_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_doctor_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    first-run|getting-started)
      if [[ -f "${LOG_DIR}/crashsim_first_run_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_first_run_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_first_run_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    limitations|public-limitations|public-beta-limitations)
      if [[ -f "${LOG_DIR}/crashsim_public_limitations_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_public_limitations_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_public_limitations_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    lifecycle-check|scenario-lifecycle-check)
      if [[ -f "${LOG_DIR}/crashsim_scenario_lifecycle_check_latest.md" ]]; then
        latest="${LOG_DIR}/crashsim_scenario_lifecycle_check_latest.md"
      else
        latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_lifecycle_check_*.md' 2>/dev/null | sort | tail -n 1)"
      fi
      ;;
    scenario)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_scenario_s*.manifest' 2>/dev/null | sort | tail -n 1)"
      ;;
    protect|protection)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_protect_s*.manifest' 2>/dev/null | sort | tail -n 1)"
      ;;
    recover|recovery)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_recover_s*.manifest' 2>/dev/null | sort | tail -n 1)"
      ;;
    runbook)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_runbook_s*.txt' 2>/dev/null | sort | tail -n 1)"
      ;;
    baseline)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_baseline_backup_*.rman' 2>/dev/null | sort | tail -n 1)"
      ;;
    review)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_review_index_*.md' 2>/dev/null | sort | tail -n 1)"
      ;;
    audit)
      audit_effective_dir
      local audit_dir
      while IFS= read -r audit_dir; do
        [[ -n "$AUDIT_RUN_DIR" && "$audit_dir" == "$AUDIT_RUN_DIR" ]] && continue
        [[ -f "${audit_dir}/exit_status" ]] || continue
        [[ -f "${audit_dir}/stdout.log" ]] && latest="${audit_dir}/stdout.log"
      done < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' 2>/dev/null | sort)
      ;;
    any|latest)
      latest="$(find "$LOG_DIR" -maxdepth 1 -type f 2>/dev/null | sort | tail -n 1)"
      ;;
    *)
      return "$FAIL"
      ;;
  esac

  [[ -n "$latest" && -f "$latest" ]] || return "$FAIL"
  printf "%s\n" "$latest"
}

resolve_artifact_reference() {
  local ref="$1"
  local kind

  [[ -n "$ref" ]] || return "$FAIL"
  case "$ref" in
    latest)
      find_latest_artifact "any"
      ;;
    latest:*)
      kind="${ref#latest:}"
      find_latest_artifact "$kind"
      ;;
    *)
      [[ -f "$ref" ]] || return "$FAIL"
      printf "%s\n" "$ref"
      ;;
  esac
}

review_manifest_summary() {
  local manifest="$1"
  awk -F= '
    $1 == "mode" {mode=$2}
    $1 == "scenario_id" {id=$2}
    $1 == "scenario_title" {title=$2}
    $1 == "started_at_utc" {started=$2}
    END {
      if (mode == "") mode="unknown"
      if (id == "") id="-"
      if (title == "") title="-"
      if (started == "") started="-"
      printf "%s | %s | %s | %s", mode, id, started, title
    }
  ' "$manifest"
}

review_append_file_list() {
  local report_file="$1"
  local title="$2"
  local limit="$3"
  shift 3
  local -a files=()
  local file

  while IFS= read -r file; do
    [[ -n "$file" ]] && files+=("$file")
  done < <(find "$LOG_DIR" -maxdepth 1 -type f "$@" 2>/dev/null | sort | tail -n "$limit")

  {
    printf "\n## %s\n\n" "$title"
    if [[ "${#files[@]}" -eq 0 ]]; then
      printf "No stored artifacts found.\n"
    else
      for file in "${files[@]}"; do
        printf -- '- `%s`\n' "$file"
      done
    fi
  } >>"$report_file"
}

generate_review_index() {
  local report_file latest_topology latest_config latest_backup latest_service latest_readiness latest_lifecycle latest_maa latest_resilience latest_adb latest_health latest_review
  local manifest audit_dir metadata command status started mode

  report_file="${LOG_DIR}/crashsim_review_index_${RUN_ID}.md"
  latest_topology="$(find_latest_artifact topology 2>/dev/null || true)"
  latest_config="$(find_latest_artifact config 2>/dev/null || true)"
  latest_backup="$(find_latest_artifact backup 2>/dev/null || true)"
  latest_service="$(find_latest_artifact service 2>/dev/null || true)"
  latest_readiness="$(find_latest_artifact scenario-readiness 2>/dev/null || true)"
  latest_lifecycle="$(find_latest_artifact lifecycle 2>/dev/null || true)"
  latest_maa="$(find_latest_artifact maa 2>/dev/null || true)"
  latest_resilience="$(find_latest_artifact resilience 2>/dev/null || true)"
  latest_adb="$(find_latest_artifact adb 2>/dev/null || true)"
  latest_health="$(find_latest_artifact health 2>/dev/null || true)"

  {
    printf "# CrashSimulator Review Center\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Log directory: `%s`\n' "$LOG_DIR"
    printf -- '- Audit directory: `%s`\n' "$AUDIT_DIR"
    printf "\nThis index lists previously collected CrashSimulator topology snapshots, scenario manifests, runbooks, dry-run/execution audit records, health checks, and reports. It does not reconnect to the database.\n\n"

    printf "## Latest Collected Topology\n\n"
    if [[ -n "$latest_topology" ]]; then
      printf -- '- Latest topology artifact: `%s`\n' "$latest_topology"
    else
      printf -- '- No cached topology snapshot found. Run `--discover` or `--config-report` to collect one.\n'
    fi
    [[ -n "$latest_config" ]] && printf -- '- Latest configuration report: `%s`\n' "$latest_config"
    [[ -n "$latest_backup" ]] && printf -- '- Latest backup/recoverability report: `%s`\n' "$latest_backup"
    [[ -n "$latest_service" ]] && printf -- '- Latest service HA review: `%s`\n' "$latest_service"
    [[ -n "$latest_readiness" ]] && printf -- '- Latest scenario readiness report: `%s`\n' "$latest_readiness"
    [[ -n "$latest_lifecycle" ]] && printf -- '- Latest scenario lifecycle coverage report: `%s`\n' "$latest_lifecycle"
    [[ -n "$latest_maa" ]] && printf -- '- Latest MAA readiness report: `%s`\n' "$latest_maa"
    [[ -n "$latest_resilience" ]] && printf -- '- Latest resilience scorecard: `%s`\n' "$latest_resilience"
    [[ -n "$latest_adb" ]] && printf -- '- Latest Autonomous Database readiness report: `%s`\n' "$latest_adb"
    [[ -n "$latest_health" ]] && printf -- '- Latest health check: `%s`\n' "$latest_health"

    printf "\n## Scenario / Protection / Recovery Manifests\n\n"
  } >"$report_file" || die "Unable to write review index: $report_file"

  local manifest_count=0
  while IFS= read -r manifest; do
    printf -- '- `%s` - %s\n' "$manifest" "$(review_manifest_summary "$manifest")" >>"$report_file"
    manifest_count=$((manifest_count + 1))
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name '*.manifest' 2>/dev/null | sort | tail -n 40)
  [[ "$manifest_count" -gt 0 ]] || printf "No stored manifests found.\n" >>"$report_file"

  review_append_file_list "$report_file" "Runbooks" 20 -name 'crashsim_runbook_s*.txt'
  review_append_file_list "$report_file" "Health Checks" 20 -name 'crashsim_health_check_*.log'
  review_append_file_list "$report_file" "Doctor / Public Readiness Reports" 20 -name 'crashsim_doctor_*.md'
  review_append_file_list "$report_file" "First-Run Guides" 20 -name 'crashsim_first_run_*.md'
  review_append_file_list "$report_file" "Public Limitations Pages" 20 -name 'crashsim_public_limitations_*.md'
  review_append_file_list "$report_file" "Configuration Reports" 20 -name 'crashsim_config_report_*.md'
  review_append_file_list "$report_file" "Backup Strategy / Recoverability Reports" 20 -name 'crashsim_backup_report_*.md'
  review_append_file_list "$report_file" "Service HA Reviews" 20 -name 'crashsim_service_review_*.md'
  review_append_file_list "$report_file" "APEX / ORDS Readiness Reports" 20 -name 'crashsim_apex_ords_report_*.md'
  review_append_file_list "$report_file" "Seed / Prepare Environment Reports" 20 -name 'crashsim_prepare_environment_*.md'
  review_append_file_list "$report_file" "Scenario Readiness Reports" 20 -name 'crashsim_scenario_readiness_*.md'
  review_append_file_list "$report_file" "Scenario Lifecycle Coverage Reports" 20 -name 'crashsim_scenario_lifecycle_*.md'
  review_append_file_list "$report_file" "Scenario Lifecycle Consistency Checks" 20 -name 'crashsim_scenario_lifecycle_check_*.md'
  review_append_file_list "$report_file" "MAA Readiness Reports" 20 -name 'crashsim_maa_report_*.md'
  review_append_file_list "$report_file" "Resilience Scorecards" 20 -name 'crashsim_resilience_scorecard_*.md'
  review_append_file_list "$report_file" "Autonomous Database Readiness Reports" 20 -name 'crashsim_adb_readiness_*.md'
  review_append_file_list "$report_file" "Baseline Backup Plans And Logs" 20 \( -name 'crashsim_baseline_backup_*.rman' -o -name 'crashsim_baseline_backup_*.log' \)
  review_append_file_list "$report_file" "RMAN And SQL Helper Files" 30 \( -name '*.rman' -o -name '*.sql' \)

  {
    printf "\n## Audit Records\n\n"
  } >>"$report_file"
  local audit_count=0
  audit_effective_dir
  while IFS= read -r audit_dir; do
    [[ -n "$AUDIT_RUN_DIR" && "$audit_dir" == "$AUDIT_RUN_DIR" ]] && continue
    metadata="${audit_dir}/metadata.env"
    command="${audit_dir}/command.redacted"
    status="${audit_dir}/exit_status"
    [[ -f "$status" ]] || continue
    started="$(awk -F= '$1=="started_at_utc"{print $2}' "$metadata" 2>/dev/null | tail -n 1)"
    mode="$(awk -F= '$1=="mode"{print $2}' "$metadata" 2>/dev/null | tail -n 1)"
    printf -- '- `%s` - mode `%s`, started `%s`, exit `%s`\n' \
      "$audit_dir" "${mode:-unknown}" "${started:-unknown}" "$([[ -f "$status" ]] && cat "$status" || printf unknown)" >>"$report_file"
    [[ -f "$command" ]] && printf '  Command: `%s`\n' "$(cat "$command")" >>"$report_file"
    audit_count=$((audit_count + 1))
  done < <(find "$AUDIT_DIR" -mindepth 2 -maxdepth 2 -type d -name 'crashsim_audit_*' 2>/dev/null | sort | tail -n 30)
  [[ "$audit_count" -gt 0 ]] || printf "No audit records found.\n" >>"$report_file"

  {
    printf "\n## Access Shortcuts\n\n"
    printf -- '- Show latest topology: `./%s --review-topology`\n' "$PROGRAM"
    printf -- '- Show latest scenario readiness report: `./%s --show-artifact latest:scenario-readiness`\n' "$PROGRAM"
    printf -- '- Show latest scenario lifecycle report: `./%s --show-artifact latest:lifecycle`\n' "$PROGRAM"
    printf -- '- Show latest resilience scorecard: `./%s --show-artifact latest:resilience`\n' "$PROGRAM"
    printf -- '- Show latest Autonomous Database readiness report: `./%s --show-artifact latest:adb`\n' "$PROGRAM"
    printf -- '- Show latest public limitations page: `./%s --show-artifact latest:public-limitations`\n' "$PROGRAM"
    printf -- '- Show latest health check: `./%s --show-artifact latest:health`\n' "$PROGRAM"
    printf -- '- Generate HTML for latest review index: `./%s --render-html latest:review`\n' "$PROGRAM"
    printf -- '- Generate HTML for a specific artifact: `./%s --render-html /path/to/artifact`\n' "$PROGRAM"
  } >>"$report_file"

  latest_review="$report_file"
  echo "Review index generated: ${latest_review}"
  cat "$latest_review"
  maybe_render_html "$latest_review"
}

review_topology() {
  local topology_file
  topology_file="$(find_latest_artifact topology 2>/dev/null || true)"
  if [[ -z "$topology_file" ]]; then
    echo "No collected topology artifact was found in ${LOG_DIR}."
    echo "Run --discover or --config-report to collect topology evidence first."
    return "$FAIL"
  fi
  echo "Latest collected topology artifact: ${topology_file}"
  echo
  cat "$topology_file"
  maybe_render_html "$topology_file"
}

show_artifact() {
  local ref="$1"
  local artifact

  artifact="$(resolve_artifact_reference "$ref")" ||
    die "Artifact not found for reference '${ref}'. Use a path or latest:<kind>."
  echo "Artifact: ${artifact}"
  echo
  cat "$artifact"
  maybe_render_html "$artifact"
}

render_html_target() {
  local ref="$1"
  local artifact

  artifact="$(resolve_artifact_reference "$ref")" ||
    die "Artifact not found for reference '${ref}'. Use a path or latest:<kind>."
  render_artifact_html "$artifact"
}

append_report_section() {
  local report_file="$1"
  local title="$2"
  {
    printf "\n## %s\n\n" "$title"
  } >>"$report_file"
}

append_report_text() {
  local report_file="$1"
  shift
  printf "%s\n" "$*" >>"$report_file"
}

md_escape() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//|/\\|}"
  printf "%s" "$value"
}

adb_python_bin() {
  if [[ -n "$ADB_PYTHON" && -x "$ADB_PYTHON" ]]; then
    printf "%s" "$ADB_PYTHON"
    return "$SUCCESS"
  fi
  command -v "$ADB_PYTHON" 2>/dev/null || return "$FAIL"
}

adb_wallet_tnsnames() {
  [[ -n "$ADB_WALLET_DIR" && -f "${ADB_WALLET_DIR}/tnsnames.ora" ]] || return "$FAIL"
  printf "%s" "${ADB_WALLET_DIR}/tnsnames.ora"
}

adb_wallet_aliases() {
  local tns
  tns="$(adb_wallet_tnsnames)" || return "$FAIL"
  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/ {
      alias=$0
      sub(/=.*/, "", alias)
      gsub(/[[:space:]]/, "", alias)
      if (alias != "" && alias !~ /^\(/) print alias
    }
  ' "$tns" | sort -u
}

adb_default_alias() {
  local alias wanted first_alias

  if [[ -n "$ADB_CONNECT_ALIAS" ]]; then
    printf "%s" "$ADB_CONNECT_ALIAS"
    return "$SUCCESS"
  fi

  wanted="_$(printf "%s" "$ADB_SERVICE_LEVEL" | tr '[:upper:]' '[:lower:]')"
  while IFS= read -r alias; do
    [[ -n "$alias" ]] || continue
    [[ -n "$first_alias" ]] || first_alias="$alias"
    if [[ "$(printf "%s" "$alias" | tr '[:upper:]' '[:lower:]')" == *"${wanted}" ]]; then
      printf "%s" "$alias"
      return "$SUCCESS"
    fi
  done < <(adb_wallet_aliases 2>/dev/null || true)

  [[ -n "$first_alias" ]] || return "$FAIL"
  printf "%s" "$first_alias"
}

adb_effective_dsn() {
  if [[ -n "$ADB_CONNECT_DESCRIPTOR" ]]; then
    printf "%s" "$ADB_CONNECT_DESCRIPTOR"
    return "$SUCCESS"
  fi
  adb_default_alias
}

adb_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${ADB_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

adb_positive() {
  local key="$1"
  local value
  value="$(adb_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

adb_truthy_value() {
  local key="$1"
  local value
  value="$(printf "%s" "$(adb_value "$key" "false")" | tr '[:upper:]' '[:lower:]')"
  [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]
}

parse_adb_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  ADB_EVIDENCE=()
  [[ -f "$evidence_file" ]] || return "$FAIL"
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_ADB" && -n "$key" ]] || continue
    ADB_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

collect_adb_oci_metadata() {
  local evidence_file="$1"
  local metadata_file="$2"
  local -a oci_cmd
  local py

  if [[ -z "$ADB_OCID" ]]; then
    printf 'CSIM_ADB|oci_metadata_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_reason|ADB OCID is not configured.\n' >>"$evidence_file"
    return "$SUCCESS"
  fi
  if ! command -v oci >/dev/null 2>&1; then
    printf 'CSIM_ADB|oci_metadata_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_reason|OCI CLI was not found in PATH.\n' >>"$evidence_file"
    return "$SUCCESS"
  fi

  oci_cmd=(oci db autonomous-database get --autonomous-database-id "$ADB_OCID")
  [[ -n "$ADB_OCI_PROFILE" ]] && oci_cmd+=(--profile "$ADB_OCI_PROFILE")
  [[ -n "$ADB_OCI_CONFIG_FILE" ]] && oci_cmd+=(--config-file "$ADB_OCI_CONFIG_FILE")
  [[ -n "$ADB_REGION" ]] && oci_cmd+=(--region "$ADB_REGION")
  [[ -n "$ADB_OCI_AUTH" ]] && oci_cmd+=(--auth "$ADB_OCI_AUTH")

  if ! "${oci_cmd[@]}" >"$metadata_file" 2>"${metadata_file}.err"; then
    printf 'CSIM_ADB|oci_metadata_status|ERROR\n' >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_file|%s\n' "$metadata_file" >>"$evidence_file"
    printf 'CSIM_ADB|oci_metadata_reason|%s\n' "$(tr '\n' ' ' <"${metadata_file}.err" | cut -c1-1000)" >>"$evidence_file"
    return "$SUCCESS"
  fi

  printf 'CSIM_ADB|oci_metadata_status|OK\n' >>"$evidence_file"
  printf 'CSIM_ADB|oci_metadata_file|%s\n' "$metadata_file" >>"$evidence_file"
  py="$(adb_python_bin 2>/dev/null || command -v python3 2>/dev/null || true)"
  if [[ -z "$py" ]]; then
    printf 'CSIM_ADB|oci_metadata_parse_status|SKIPPED_NO_PYTHON\n' >>"$evidence_file"
    return "$SUCCESS"
  fi

  "$py" - "$metadata_file" >>"$evidence_file" <<'PY' || printf 'CSIM_ADB|oci_metadata_parse_status|ERROR\n' >>"$evidence_file"
import json
import sys

path = sys.argv[1]
with open(path, "r", encoding="utf-8") as handle:
    data = json.load(handle).get("data", {})

def clean(value):
    if value is None:
        return "NONE"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (list, tuple)):
        return ", ".join(clean(v) for v in value) if value else "NONE"
    if isinstance(value, dict):
        return json.dumps(value, sort_keys=True)
    return str(value).replace("\n", " ").replace("\r", " ")[:4000]

fields = {
    "oci_display_name": "display-name",
    "oci_db_name": "db-name",
    "oci_lifecycle_state": "lifecycle-state",
    "oci_compartment_id": "compartment-id",
    "oci_time_created": "time-created",
    "oci_backup_retention_days": "backup-retention-period-in-days",
    "oci_total_backup_storage_gb": "total-backup-storage-size-in-gbs",
    "oci_manual_backup_type": ("backup-config", "manual-backup-type"),
    "oci_manual_backup_bucket_name": ("backup-config", "manual-backup-bucket-name"),
    "oci_is_backup_retention_locked": "is-backup-retention-locked",
    "oci_is_data_guard_enabled": "is-data-guard-enabled",
    "oci_is_local_data_guard_enabled": "is-local-data-guard-enabled",
    "oci_is_remote_data_guard_enabled": "is-remote-data-guard-enabled",
    "oci_dataguard_region_type": "dataguard-region-type",
    "oci_standby_db": "standby-db",
    "oci_peer_db_ids": "peer-db-ids",
    "oci_private_endpoint": "private-endpoint",
    "oci_private_endpoint_label": "private-endpoint-label",
    "oci_private_endpoint_ip": "private-endpoint-ip",
    "oci_nsg_ids": "nsg-ids",
    "oci_data_safe_status": "data-safe-status",
    "oci_operations_insights_status": "operations-insights-status",
    "oci_permission_level": "permission-level",
    "oci_license_model": "license-model",
    "oci_compute_model": "compute-model",
    "oci_compute_count": "compute-count",
    "oci_data_storage_size_gb": "data-storage-size-in-gbs",
    "oci_actual_used_data_storage_tb": "actual-used-data-storage-size-in-tbs",
    "oci_apex_version": ("apex-details", "apex-version"),
    "oci_ords_version": ("apex-details", "ords-version"),
    "oci_supported_clone_regions": "supported-regions-to-clone-to",
}

def value_for(selector):
    current = data
    if isinstance(selector, tuple):
        for item in selector:
            if not isinstance(current, dict):
                return None
            current = current.get(item)
        return current
    return data.get(selector)

print("CSIM_ADB|oci_metadata_parse_status|OK")
for key, selector in fields.items():
    print(f"CSIM_ADB|{key}|{clean(value_for(selector))}")
PY
}

adb_check_ok=0
adb_check_warn=0
adb_check_gap=0
adb_check_info=0
adb_scorecard_sum=0
adb_scorecard_count=0

adb_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  case "$status" in
    OK) adb_check_ok=$((adb_check_ok + 1)) ;;
    WARN) adb_check_warn=$((adb_check_warn + 1)) ;;
    GAP) adb_check_gap=$((adb_check_gap + 1)) ;;
    INFO) adb_check_info=$((adb_check_info + 1)) ;;
  esac

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

adb_scorecard_reset() {
  adb_scorecard_sum=0
  adb_scorecard_count=0
}

adb_scorecard_points() {
  local status="$1"
  case "$status" in
    PASS) printf "100" ;;
    PARTIAL) printf "60" ;;
    WARN) printf "40" ;;
    GAP) printf "0" ;;
    INFO) printf "0" ;;
    *) printf "0" ;;
  esac
}

adb_append_scorecard_row() {
  local report_file="$1"
  local domain="$2"
  local status="$3"
  local evidence="$4"
  local recommendation="$5"
  local points

  points="$(adb_scorecard_points "$status")"
  if [[ "$status" != "INFO" ]]; then
    adb_scorecard_sum=$((adb_scorecard_sum + points))
    adb_scorecard_count=$((adb_scorecard_count + 1))
  fi

  printf '| %s | `%s` | %s | %s |\n' \
    "$(md_escape "$domain")" \
    "$(md_escape "$status")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

adb_scorecard_score() {
  if [[ "$adb_scorecard_count" -gt 0 ]]; then
    printf "%s" $((adb_scorecard_sum / adb_scorecard_count))
  else
    printf "0"
  fi
}

run_adb_sql_probe() {
  local evidence_file="$1"
  local python_bin dsn db_password wallet_password wallet_dir_arg tls_mode probe_script status

  : >"$evidence_file" || die "Unable to write ADB evidence file: $evidence_file"
  {
    printf 'CSIM_ADB|generated_utc|%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'CSIM_ADB|host|%s\n' "$(hostname 2>/dev/null || printf unknown)"
    printf 'CSIM_ADB|os_user|%s\n' "$(id -un 2>/dev/null || printf unknown)"
  } >>"$evidence_file"

  python_bin="$(adb_python_bin 2>/dev/null || true)"
  if [[ -z "$python_bin" ]]; then
    printf 'CSIM_ADB|python_status|NOT_FOUND\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_reason|Python executable not found: %s\n' "$ADB_PYTHON" >>"$evidence_file"
    return "$SUCCESS"
  fi
  printf 'CSIM_ADB|python_executable|%s\n' "$python_bin" >>"$evidence_file"

  dsn="$(adb_effective_dsn 2>/dev/null || true)"
  if [[ -z "$dsn" ]]; then
    printf 'CSIM_ADB|connect_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_reason|No ADB connect descriptor or wallet TNS alias was configured.\n' >>"$evidence_file"
    return "$SUCCESS"
  fi
  printf 'CSIM_ADB|dsn_source|%s\n' "$([[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && printf descriptor || printf alias)" >>"$evidence_file"
  printf 'CSIM_ADB|dsn_label|%s\n' "$([[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && printf configured_descriptor || printf "%s" "$dsn")" >>"$evidence_file"

  db_password="${!ADB_PASSWORD_ENV:-}"
  wallet_password="${!ADB_WALLET_PASSWORD_ENV:-}"
  [[ -n "$wallet_password" ]] || wallet_password="$db_password"
  if [[ -z "$db_password" ]]; then
    printf 'CSIM_ADB|connect_status|SKIPPED\n' >>"$evidence_file"
    printf 'CSIM_ADB|connect_reason|Database password environment variable is not set: %s\n' "$ADB_PASSWORD_ENV" >>"$evidence_file"
    return "$SUCCESS"
  fi

  wallet_dir_arg=""
  if [[ -n "$ADB_WALLET_DIR" ]]; then
    wallet_dir_arg="$ADB_WALLET_DIR"
  fi
  tls_mode="$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')"
  probe_script="${WORK_DIR}/adb_probe.py"
  cat >"$probe_script" <<'PY' || die "Unable to write ADB probe script: $probe_script"
import os
import sys

wallet_dir = sys.argv[1]
dsn = sys.argv[2]
user = sys.argv[3]
tls_mode = sys.argv[4].lower()
db_password = sys.stdin.readline().rstrip("\n")
wallet_password = sys.stdin.readline().rstrip("\n")

def clean(value):
    if value is None:
        return "UNKNOWN"
    return str(value).replace("\n", " ").replace("\r", " ")[:4000]

def emit(key, value):
    print(f"CSIM_ADB|{key}|{clean(value)}")

try:
    import oracledb
except Exception as exc:
    emit("python_status", "ORACLEDB_IMPORT_FAILED")
    emit("connect_status", "SKIPPED")
    emit("connect_reason", exc)
    sys.exit(0)

emit("python_status", "OK")
emit("python_oracledb_version", getattr(oracledb, "__version__", "UNKNOWN"))

kwargs = {
    "user": user,
    "password": db_password,
    "dsn": dsn,
    "tcp_connect_timeout": 5,
    "retry_count": 0,
    "retry_delay": 0,
}
if wallet_dir:
    os.environ["TNS_ADMIN"] = wallet_dir
    kwargs["config_dir"] = wallet_dir
    if tls_mode == "mtls":
        kwargs["wallet_location"] = wallet_dir
        if wallet_password:
            kwargs["wallet_password"] = wallet_password

try:
    conn = oracledb.connect(**kwargs)
except Exception as exc:
    emit("connect_status", "ERROR")
    emit("connect_reason", exc)
    sys.exit(0)

emit("connect_status", "OK")

def scalar(key, sql, default="UNKNOWN"):
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            row = cur.fetchone()
            emit(key, row[0] if row and row[0] is not None else default)
    except Exception as exc:
        emit(key, "ERROR: " + clean(exc))

def list_value(key, sql, sep=", "):
    try:
        with conn.cursor() as cur:
            cur.execute(sql)
            values = [clean(row[0]) for row in cur.fetchall() if row and row[0] is not None]
            emit(key, sep.join(values) if values else "NONE")
    except Exception as exc:
        emit(key, "ERROR: " + clean(exc))

scalar("current_user", "select user from dual")
scalar("db_identity", "select name || '|' || open_mode || '|' || database_role || '|' || cdb || '|' || log_mode || '|' || flashback_on || '|' || protection_mode from v$database")
scalar("db_name", "select name from v$database")
scalar("open_mode", "select open_mode from v$database")
scalar("database_role", "select database_role from v$database")
scalar("cdb", "select cdb from v$database")
scalar("log_mode", "select log_mode from v$database")
scalar("flashback_on", "select flashback_on from v$database")
scalar("protection_mode", "select protection_mode from v$database")
scalar("version", "select banner_full from v$version where banner_full like 'Oracle%' fetch first 1 row only")
scalar("version_number", "select version_full from v$instance")
scalar("service_count", "select count(*) from v$services")
list_value("services", "select name from v$services order by name")
scalar("apex_registry_count", "select count(*) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%'")
scalar("apex_version_status", "select nvl(max(version || ':' || status), 'NONE') from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%'")
scalar("invalid_object_count", "select count(*) from dba_objects where status <> 'VALID'")
scalar("admin_object_count", "select count(*) from user_objects")
scalar("user_table_count", "select count(*) from user_tables")
scalar("recyclebin_count", "select count(*) from recyclebin")
scalar("tablespace_count", "select count(*) from dba_tablespaces")
scalar("encrypted_tablespace_count", "select count(*) from dba_tablespaces where encrypted = 'YES'")
scalar("segment_size_gb", "select round(sum(bytes)/1024/1024/1024, 2) from dba_segments")
scalar("flashback_archive_count", "select count(*) from dba_flashback_archive")
scalar("flashback_archive_retention_days", "select nvl(max(retention_in_days),0) from dba_flashback_archive")
scalar("open_application_user_count", "select count(*) from dba_users where oracle_maintained = 'N' and account_status like 'OPEN%'")
list_value("application_users", "select username || ':' || account_status from dba_users where oracle_maintained = 'N' order by username")
scalar("resource_plan", "select nvl(name, 'NONE') from v$rsrc_plan where is_top_plan = 'TRUE' fetch first 1 row only")
conn.close()
PY

  if { printf "%s\n%s\n" "$db_password" "$wallet_password"; } |
    "$python_bin" "$probe_script" "$wallet_dir_arg" "$dsn" "$ADB_USER" "$tls_mode" >>"$evidence_file" 2>&1; then
    status=0
  else
    status=$?
    printf 'CSIM_ADB|probe_exit_status|%s\n' "$status" >>"$evidence_file"
  fi
  return "$SUCCESS"
}

adb_append_scenario_row() {
  local report_file="$1"
  local id="$2"
  local scenario="$3"
  local status="$4"
  local validation="$5"
  local recovery="$6"

  printf '| `%s` | %s | `%s` | %s | %s |\n' \
    "$(md_escape "$id")" \
    "$(md_escape "$scenario")" \
    "$(md_escape "$status")" \
    "$(md_escape "$validation")" \
    "$(md_escape "$recovery")" >>"$report_file"
}

run_adb_readiness_report() {
  local report_file latest_file latest_evidence_file evidence_file oci_metadata_file generated_at aliases alias_list python_bin wallet_state tns_state dsn_label oci_state control_plane_state
  local score_den score id status reason
  local adb_domain_score resource_plan flashback_on connect_status tls_mode_lower backup_retention clone_regions metadata_status

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_adb_readiness_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_adb_readiness_latest.md"
  latest_evidence_file="${LOG_DIR}/crashsim_adb_readiness_latest.evidence"
  evidence_file="${LOG_DIR}/crashsim_adb_readiness_${RUN_ID}.evidence"
  oci_metadata_file="${LOG_DIR}/crashsim_adb_readiness_${RUN_ID}_oci_adb.json"
  adb_check_ok=0
  adb_check_warn=0
  adb_check_gap=0
  adb_check_info=0

  aliases="$(adb_wallet_aliases 2>/dev/null | awk 'BEGIN { first=1 } { printf "%s%s", (first ? "" : ", "), $0; first=0 } END { if (first) exit 1 }' 2>/dev/null || true)"
  [[ -n "$aliases" ]] || aliases="not available"
  python_bin="$(adb_python_bin 2>/dev/null || true)"
  wallet_state="not configured"
  tns_state="not configured"
  if [[ -n "$ADB_WALLET_DIR" ]]; then
    if [[ -d "$ADB_WALLET_DIR" ]]; then
      wallet_state="present"
      [[ -f "${ADB_WALLET_DIR}/tnsnames.ora" ]] && tns_state="present" || tns_state="missing"
    else
      wallet_state="missing"
      tns_state="missing"
    fi
  fi
  dsn_label="$(adb_effective_dsn 2>/dev/null || true)"
  [[ -n "$dsn_label" ]] || dsn_label="not configured"
  [[ -z "$ADB_CONNECT_DESCRIPTOR" ]] || dsn_label="configured descriptor"
  if command -v oci >/dev/null 2>&1; then
    oci_state="found"
  else
    oci_state="not found"
  fi
  if [[ -n "$ADB_OCID" && "$oci_state" == "found" ]]; then
    control_plane_state="configured"
  elif [[ -n "$ADB_OCID" ]]; then
    control_plane_state="OCID configured, OCI CLI not found"
  else
    control_plane_state="not configured"
  fi

  run_adb_sql_probe "$evidence_file"
  collect_adb_oci_metadata "$evidence_file" "$oci_metadata_file"
  parse_adb_evidence_file "$evidence_file" || true
  if [[ "$(adb_value oci_metadata_status UNKNOWN)" == "OK" ]]; then
    control_plane_state="metadata collected"
  elif [[ -n "$ADB_OCID" && "$oci_state" == "found" ]]; then
    control_plane_state="configured, metadata query $(adb_value oci_metadata_status UNKNOWN)"
  fi

  {
    printf "# CrashSimulator Autonomous Database Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Tool version: `%s`\n' "$VERSION"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- ADB user: `%s`\n' "$(md_escape "$ADB_USER")"
    printf -- '- TLS mode: `%s`\n' "$(md_escape "$ADB_TLS_MODE")"
    printf -- '- Evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "Autonomous Database hides OS, storage, ASM, Grid Infrastructure, control files, redo files, SPFILE, password file, and managed-backup internals from customers. This report therefore separates traditional CrashSimulator database-host scenarios from cloud-service scenarios that are realistic for ADB: logical/user-error recovery, clone/PITR, wallet/connectivity, service limits, Autonomous Data Guard, IAM, and Object Storage dependencies.\n"
  } >"$report_file" || die "Unable to write ADB readiness report: $report_file"

  append_report_section "$report_file" "Connection And Configuration"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| Wallet directory | `%s` |\n' "$(md_escape "${ADB_WALLET_DIR:-not configured}")"
    printf '| Wallet state | `%s` |\n' "$(md_escape "$wallet_state")"
    printf '| tnsnames.ora | `%s` |\n' "$(md_escape "$tns_state")"
    printf '| Wallet aliases | `%s` |\n' "$(md_escape "$aliases")"
    printf '| Connect alias / descriptor | `%s` |\n' "$(md_escape "$dsn_label")"
    printf '| Service-level hint | `%s` |\n' "$(md_escape "$ADB_SERVICE_LEVEL")"
    printf '| Password env var | `%s` |\n' "$(md_escape "$ADB_PASSWORD_ENV")"
    printf '| Wallet password env var | `%s` |\n' "$(md_escape "$ADB_WALLET_PASSWORD_ENV")"
    printf '| Python executable | `%s` |\n' "$(md_escape "${python_bin:-not found}")"
    printf '| python-oracledb | `%s` |\n' "$(md_escape "$(adb_value python_oracledb_version "$(adb_value python_status "not checked")")")"
    printf '| SQL connection | `%s` |\n' "$(md_escape "$(adb_value connect_status UNKNOWN)")"
    printf '| OCI CLI | `%s` |\n' "$(md_escape "$oci_state")"
    printf '| OCI control-plane posture | `%s` |\n' "$(md_escape "$control_plane_state")"
    printf '| OCI auth mode | `%s` |\n' "$(md_escape "${ADB_OCI_AUTH:-default}")"
    printf '| OCI metadata status | `%s` |\n' "$(md_escape "$(adb_value oci_metadata_status UNKNOWN)")"
    printf '| OCI ADB lifecycle | `%s` |\n' "$(md_escape "$(adb_value oci_lifecycle_state UNKNOWN)")"
    printf '| OCI backup retention days | `%s` |\n' "$(md_escape "$(adb_value oci_backup_retention_days UNKNOWN)")"
    printf '| APEX URL | `%s` |\n' "$(md_escape "${ADB_APEX_URL:-not configured}")"
    printf '| Database Actions URL | `%s` |\n' "$(md_escape "${ADB_DATABASE_ACTIONS_URL:-not configured}")"
    printf '| Private endpoint expectation | `%s` |\n' "$(md_escape "${ADB_PRIVATE_ENDPOINT:-not configured}")"
  } >>"$report_file"

  append_report_section "$report_file" "Live SQL Evidence Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| DB identity | `%s` |\n' "$(md_escape "$(adb_value db_identity "not connected")")"
    printf '| Version | `%s` |\n' "$(md_escape "$(adb_value version "not connected")")"
    printf '| Version number | `%s` |\n' "$(md_escape "$(adb_value version_number "not connected")")"
    printf '| Services | `%s` |\n' "$(md_escape "$(adb_value services "not connected")")"
    printf '| APEX registry | `%s` |\n' "$(md_escape "$(adb_value apex_version_status "not connected")")"
    printf '| Tablespaces | `%s` |\n' "$(md_escape "$(adb_value tablespace_count "not connected")")"
    printf '| Encrypted tablespaces | `%s` |\n' "$(md_escape "$(adb_value encrypted_tablespace_count "not connected")")"
    printf '| Segment size GB | `%s` |\n' "$(md_escape "$(adb_value segment_size_gb "not connected")")"
    printf '| Flashback archive count | `%s` |\n' "$(md_escape "$(adb_value flashback_archive_count "not connected")")"
    printf '| Flashback archive retention days | `%s` |\n' "$(md_escape "$(adb_value flashback_archive_retention_days "not connected")")"
    printf '| Open application users | `%s` |\n' "$(md_escape "$(adb_value open_application_user_count "not connected")")"
    printf '| Application users | `%s` |\n' "$(md_escape "$(adb_value application_users "not connected")")"
    printf '| Invalid objects | `%s` |\n' "$(md_escape "$(adb_value invalid_object_count "not connected")")"
    printf '| Recycle bin rows | `%s` |\n' "$(md_escape "$(adb_value recyclebin_count "not connected")")"
    printf '| Resource plan | `%s` |\n' "$(md_escape "$(adb_value resource_plan "not connected")")"
  } >>"$report_file"

  append_report_section "$report_file" "OCI Control-Plane Evidence Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| Metadata status | `%s` |\n' "$(md_escape "$(adb_value oci_metadata_status UNKNOWN)")"
    printf '| Metadata file | `%s` |\n' "$(md_escape "$(adb_value oci_metadata_file "not collected")")"
    printf '| Display name / DB name | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_display_name UNKNOWN)")" "$(md_escape "$(adb_value oci_db_name UNKNOWN)")"
    printf '| Lifecycle state | `%s` |\n' "$(md_escape "$(adb_value oci_lifecycle_state UNKNOWN)")"
    printf '| Compartment OCID | `%s` |\n' "$(md_escape "$(adb_value oci_compartment_id UNKNOWN)")"
    printf '| Backup retention days | `%s` |\n' "$(md_escape "$(adb_value oci_backup_retention_days UNKNOWN)")"
    printf '| Total backup storage GB | `%s` |\n' "$(md_escape "$(adb_value oci_total_backup_storage_gb UNKNOWN)")"
    printf '| Manual backup type / bucket | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_manual_backup_type UNKNOWN)")" "$(md_escape "$(adb_value oci_manual_backup_bucket_name UNKNOWN)")"
    printf '| Data Guard enabled | `%s` |\n' "$(md_escape "$(adb_value oci_is_data_guard_enabled UNKNOWN)")"
    printf '| Local / remote Data Guard | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_is_local_data_guard_enabled UNKNOWN)")" "$(md_escape "$(adb_value oci_is_remote_data_guard_enabled UNKNOWN)")"
    printf '| Data Guard region type | `%s` |\n' "$(md_escape "$(adb_value oci_dataguard_region_type UNKNOWN)")"
    printf '| Peer DB IDs | `%s` |\n' "$(md_escape "$(adb_value oci_peer_db_ids UNKNOWN)")"
    printf '| Private endpoint / label / IP | `%s` / `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_private_endpoint UNKNOWN)")" "$(md_escape "$(adb_value oci_private_endpoint_label UNKNOWN)")" "$(md_escape "$(adb_value oci_private_endpoint_ip UNKNOWN)")"
    printf '| NSGs | `%s` |\n' "$(md_escape "$(adb_value oci_nsg_ids UNKNOWN)")"
    printf '| Data Safe / Operations Insights | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_data_safe_status UNKNOWN)")" "$(md_escape "$(adb_value oci_operations_insights_status UNKNOWN)")"
    printf '| Permission level | `%s` |\n' "$(md_escape "$(adb_value oci_permission_level UNKNOWN)")"
    printf '| APEX / ORDS version | `%s` / `%s` |\n' "$(md_escape "$(adb_value oci_apex_version UNKNOWN)")" "$(md_escape "$(adb_value oci_ords_version UNKNOWN)")"
    printf '| Supported clone regions | `%s` |\n' "$(md_escape "$(adb_value oci_supported_clone_regions UNKNOWN)")"
  } >>"$report_file"

  append_report_section "$report_file" "ADB Readiness Scorecard"
  {
    printf 'This scorecard summarizes Autonomous Database resilience domains separately from host-based Oracle Database scenarios. PASS means CrashSimulator found direct evidence in the current report. PARTIAL means the control path or prerequisite exists, but a drill or deeper OCI metadata check is still needed. GAP means the report cannot currently prove the domain.\n\n'
    printf '| Domain | Status | Evidence | Next action |\n'
    printf '| --- | --- | --- | --- |\n'
  } >>"$report_file"

  adb_scorecard_reset
  connect_status="$(adb_value connect_status UNKNOWN)"
  flashback_on="$(adb_value flashback_on UNKNOWN)"
  resource_plan="$(adb_value resource_plan UNKNOWN)"
  metadata_status="$(adb_value oci_metadata_status UNKNOWN)"
  backup_retention="$(adb_value oci_backup_retention_days 0)"
  clone_regions="$(adb_value oci_supported_clone_regions NONE)"
  tls_mode_lower="$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')"

  if [[ "$metadata_status" == "OK" ]]; then
    if [[ "$backup_retention" =~ ^[0-9]+$ && "$backup_retention" -gt 0 ]]; then
      adb_append_scorecard_row "$report_file" "Backup Readiness" "PASS" "OCI backup retention is ${backup_retention} days; total backup storage is $(adb_value oci_total_backup_storage_gb UNKNOWN) GB." "Run ADB07 clone/restore validation to convert configured backup posture into measured recoverability evidence."
    else
      adb_append_scorecard_row "$report_file" "Backup Readiness" "GAP" "OCI metadata was collected, but backup retention is ${backup_retention}." "Review ADB backup policy and confirm restore/clone capability."
    fi
    if [[ "$backup_retention" =~ ^[0-9]+$ && "$backup_retention" -gt 0 && "$clone_regions" != "NONE" && "$clone_regions" != "UNKNOWN" ]]; then
      adb_append_scorecard_row "$report_file" "PITR Validation" "PARTIAL" "Backup retention is ${backup_retention} days and supported clone regions are visible." "Run ADB06 with a selected timestamp and record elapsed clone, validation, and data-merge evidence before marking PASS."
    else
      adb_append_scorecard_row "$report_file" "PITR Validation" "GAP" "PITR/clone evidence is incomplete: retention=${backup_retention}, clone_regions=${clone_regions}." "Validate clone-to-time eligibility and run an ADB06 drill."
    fi
    if adb_truthy_value oci_is_data_guard_enabled; then
      adb_append_scorecard_row "$report_file" "Autonomous Data Guard Protection" "PASS" "OCI reports Autonomous Data Guard enabled; local=$(adb_value oci_is_local_data_guard_enabled UNKNOWN), remote=$(adb_value oci_is_remote_data_guard_enabled UNKNOWN), peer=$(adb_value oci_peer_db_ids NONE)." "Run ADB12/ADB13 to measure failover/switchover RTO/RPO and application reconnect."
    else
      adb_append_scorecard_row "$report_file" "Autonomous Data Guard Protection" "GAP" "OCI reports Autonomous Data Guard disabled; local=$(adb_value oci_is_local_data_guard_enabled UNKNOWN), remote=$(adb_value oci_is_remote_data_guard_enabled UNKNOWN)." "Enable/configure Autonomous Data Guard when DR requirements require managed standby protection."
    fi
    if adb_truthy_value oci_is_remote_data_guard_enabled || [[ "$(adb_value oci_dataguard_region_type NONE)" != "NONE" && "$(adb_value oci_dataguard_region_type NONE)" != "UNKNOWN" ]]; then
      adb_append_scorecard_row "$report_file" "Cross-Region DR" "PASS" "OCI remote Data Guard evidence exists: region_type=$(adb_value oci_dataguard_region_type UNKNOWN), peer=$(adb_value oci_peer_db_ids NONE)." "Validate failover/reconnect behavior and fallback plan with ADB12/ADB13."
    else
      adb_append_scorecard_row "$report_file" "Cross-Region DR" "GAP" "No remote Autonomous Data Guard peer is visible in OCI metadata." "Configure cross-region ADG or document accepted risk when regional DR is not required."
    fi
    if [[ "$(adb_value oci_data_safe_status NONE)" == "REGISTERED" ]]; then
      adb_append_scorecard_row "$report_file" "IAM / Administrator Access" "PASS" "OCI metadata is available and Data Safe is registered; permission level=$(adb_value oci_permission_level UNKNOWN)." "Keep IAM policy, break-glass, and automation-principal evidence current."
    else
      adb_append_scorecard_row "$report_file" "IAM / Administrator Access" "PARTIAL" "OCI metadata is available; Data Safe status=$(adb_value oci_data_safe_status UNKNOWN), permission level=$(adb_value oci_permission_level UNKNOWN)." "Review policies, groups, break-glass access, automation principal, and least-privilege boundaries before marking PASS."
    fi
  else
    adb_append_scorecard_row "$report_file" "Backup Readiness" "GAP" "OCI control-plane evidence is not configured: ${control_plane_state}." "Set CRASHSIM_ADB_OCID, OCI CLI/profile, and region to validate backup retention/latest backup."
    adb_append_scorecard_row "$report_file" "PITR Validation" "GAP" "PITR/clone windows cannot be proven from SQL-only evidence." "Configure OCI metadata collection and run an ADB06 clone-to-time validation."
    adb_append_scorecard_row "$report_file" "Autonomous Data Guard Protection" "GAP" "Autonomous Data Guard status, peer, lag, and transition eligibility require OCI metadata." "Configure OCI metadata collection before ADB12/ADB13 readiness claims."
    adb_append_scorecard_row "$report_file" "Cross-Region DR" "GAP" "Cross-region peer/standby evidence is not available in this report." "Add OCI metadata and validate regional failover/reconnect behavior."
    adb_append_scorecard_row "$report_file" "IAM / Administrator Access" "GAP" "IAM policy/group/break-glass posture cannot be validated without OCI context." "Configure compartment/OCI context and keep IAM checks read-only unless an approved test boundary exists."
  fi

  if [[ "$tls_mode_lower" == "mtls" ]]; then
    if [[ "$wallet_state" == "present" && "$tns_state" == "present" && "$connect_status" == "OK" ]]; then
      adb_append_scorecard_row "$report_file" "Wallet Management" "PASS" "mTLS wallet and tnsnames.ora are present, aliases are visible, and SQL probe connects." "Keep wallet rotation owner, distribution inventory, expiry review, and reconnect test evidence current."
    elif [[ "$wallet_state" == "present" && "$tns_state" == "present" ]]; then
      adb_append_scorecard_row "$report_file" "Wallet Management" "PARTIAL" "mTLS wallet files are present, but live SQL connectivity is not proven." "Fix password/network/alias issues and rerun the report before wallet rotation drills."
    else
      adb_append_scorecard_row "$report_file" "Wallet Management" "GAP" "mTLS wallet state=${wallet_state}, tnsnames=${tns_state}." "Download/extract the wallet, protect it as a credential, and configure client distribution runbooks."
    fi
  else
    adb_append_scorecard_row "$report_file" "Wallet Management" "INFO" "TLS mode is ${ADB_TLS_MODE}; mTLS wallet may not be required for this client path." "Confirm walletless TLS, hostname verification, and certificate lifecycle procedures."
  fi

  if [[ "$(adb_value oci_private_endpoint NONE)" != "NONE" && "$(adb_value oci_private_endpoint UNKNOWN)" != "UNKNOWN" ]]; then
    adb_append_scorecard_row "$report_file" "Private Endpoint Validation" "PARTIAL" "OCI private endpoint is configured: endpoint=$(adb_value oci_private_endpoint), label=$(adb_value oci_private_endpoint_label NONE), ip=$(adb_value oci_private_endpoint_ip NONE)." "Add DNS, route-table, NSG/security-list, bastion, and client reconnect evidence before marking PASS."
  elif [[ -n "$ADB_PRIVATE_ENDPOINT" ]]; then
    adb_append_scorecard_row "$report_file" "Private Endpoint Validation" "PARTIAL" "Private endpoint expectation is documented: ${ADB_PRIVATE_ENDPOINT}." "Add DNS, route-table, NSG/security-list, bastion, and client reconnect evidence before marking PASS."
  else
    adb_append_scorecard_row "$report_file" "Private Endpoint Validation" "INFO" "No private endpoint expectation was configured." "Set CRASHSIM_ADB_PRIVATE_ENDPOINT when the ADB uses private endpoints."
  fi

  if [[ "$connect_status" == "OK" && "$resource_plan" != "NONE" && "$resource_plan" != "UNKNOWN" && "$resource_plan" != "not connected" && "$resource_plan" != ERROR:* ]]; then
    adb_append_scorecard_row "$report_file" "Resource Manager" "PASS" "Resource plan evidence: ${resource_plan}." "Add workload threshold evidence for ADB10/ADB11 when validating saturation or concurrency pressure."
  elif [[ "$connect_status" == "OK" ]]; then
    adb_append_scorecard_row "$report_file" "Resource Manager" "PARTIAL" "SQL connection works, but Resource Manager plan evidence is ${resource_plan}." "Capture service class, scaling, workload, and concurrency evidence before resource-pressure drills."
  else
    adb_append_scorecard_row "$report_file" "Resource Manager" "GAP" "No live SQL evidence is available for Resource Manager posture." "Fix ADB connectivity, then rerun readiness collection."
  fi

  if adb_positive flashback_archive_count; then
    adb_append_scorecard_row "$report_file" "Logical / Object Recovery" "PASS" "Flashback Archive rows exist with retention_days=$(adb_value flashback_archive_retention_days UNKNOWN)." "Run seeded ADB01/ADB03/ADB04 drills to prove object-level recovery, not only configuration."
  elif [[ "$flashback_on" == "YES" ]]; then
    adb_append_scorecard_row "$report_file" "Logical / Object Recovery" "PARTIAL" "Database flashback is reported as YES, but Flashback Archive evidence is not present." "Validate Flashback Query/Table, Data Pump export, and clone/PITR fallback paths."
  else
    adb_append_scorecard_row "$report_file" "Logical / Object Recovery" "GAP" "Flashback/logical recovery evidence is insufficient: flashback_on=${flashback_on}, archives=$(adb_value flashback_archive_count UNKNOWN)." "Seed logical ADB lab objects and validate flashback/export/clone recovery paths."
  fi

  if [[ "$connect_status" == "OK" && ( -n "$ADB_APEX_URL" || -n "$ADB_DATABASE_ACTIONS_URL" ) ]]; then
    adb_append_scorecard_row "$report_file" "Application Access Path" "PASS" "SQL probe connects and user-facing URL context is recorded." "Add URL smoke checks and application login/session validation after wallet, clone/PITR, or ADG drills."
  elif [[ -n "$ADB_APEX_URL" || -n "$ADB_DATABASE_ACTIONS_URL" || "$(adb_value apex_registry_count 0)" =~ ^[1-9][0-9]*$ ]]; then
    adb_append_scorecard_row "$report_file" "Application Access Path" "PARTIAL" "Application or APEX evidence exists, but complete user-path validation is not proven." "Configure URL checks and application-specific validation."
  else
    adb_append_scorecard_row "$report_file" "Application Access Path" "INFO" "No APEX/Database Actions/application URL context is configured." "Record application access paths when ADB hosts user-facing applications."
  fi

  adb_domain_score="$(adb_scorecard_score)"
  {
    printf "\n| Metric | Value |\n"
    printf "| --- | ---: |\n"
    printf "| ADB Readiness Score | %s%% |\n" "$adb_domain_score"
    printf "| Scored domains | %s |\n" "$adb_scorecard_count"
  } >>"$report_file"

  append_report_section "$report_file" "Readiness Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$(printf "%s" "$ADB_TLS_MODE" | tr '[:upper:]' '[:lower:]')" == "mtls" ]]; then
    if [[ "$wallet_state" == "present" && "$tns_state" == "present" ]]; then
      adb_append_check "$report_file" "OK" "Client connectivity" "mTLS wallet available" "wallet=${ADB_WALLET_DIR}, aliases=${aliases}" "Keep wallet rotation, expiry review, and application redeploy steps in the runbook."
    else
      adb_append_check "$report_file" "GAP" "Client connectivity" "mTLS wallet available" "wallet=${wallet_state}, tnsnames=${tns_state}" "Download/extract the ADB wallet, protect it as a credential, and configure CRASHSIM_ADB_WALLET_DIR."
    fi
  else
    adb_append_check "$report_file" "INFO" "Client connectivity" "TLS mode selected" "tls_mode=${ADB_TLS_MODE}" "For TLS connections, confirm walletless access, hostname verification, and network ACL/security-list posture."
  fi

  if [[ -n "$python_bin" && "$(adb_value python_status UNKNOWN)" == "OK" ]]; then
    adb_append_check "$report_file" "OK" "Client connectivity" "python-oracledb available" "python=${python_bin}, version=$(adb_value python_oracledb_version)" "Pin driver/runtime versions in automation hosts used for readiness reporting."
  elif [[ -n "$python_bin" ]]; then
    adb_append_check "$report_file" "WARN" "Client connectivity" "python-oracledb available" "python=${python_bin}, status=$(adb_value python_status UNKNOWN)" "Install python-oracledb in the configured Python environment."
  else
    adb_append_check "$report_file" "GAP" "Client connectivity" "python-oracledb available" "python=${ADB_PYTHON} not found" "Install Python and python-oracledb on the bastion/client where ADB reports run."
  fi

  if [[ "$(adb_value connect_status UNKNOWN)" == "OK" ]]; then
    adb_append_check "$report_file" "OK" "Database access" "Live SQL probe connects" "user=$(adb_value current_user), db=$(adb_value db_name), open=$(adb_value open_mode), role=$(adb_value database_role)" "Use this same client path for logical recovery drills and application smoke tests."
  else
    adb_append_check "$report_file" "GAP" "Database access" "Live SQL probe connects" "status=$(adb_value connect_status), reason=$(adb_value connect_reason not available)" "Fix wallet, alias/descriptor, password env vars, or network path before running ADB drills."
  fi

  if adb_positive apex_registry_count; then
    adb_append_check "$report_file" "OK" "Application access" "APEX component visible" "APEX=$(adb_value apex_version_status)" "Add APEX smoke/session checks for user-facing ADB applications."
  else
    adb_append_check "$report_file" "INFO" "Application access" "APEX component visible" "APEX=$(adb_value apex_version_status NONE)" "If this ADB hosts APEX apps, configure ADB_APEX_URL and include APEX user-path validation."
  fi

  if adb_positive flashback_archive_count; then
    adb_append_check "$report_file" "OK" "Logical recovery" "Flashback Archive evidence" "archives=$(adb_value flashback_archive_count), retention_days=$(adb_value flashback_archive_retention_days)" "Use flashback query/table and clone/PITR drills for logical user-error recovery validation."
  else
    adb_append_check "$report_file" "INFO" "Logical recovery" "Flashback Archive evidence" "archives=$(adb_value flashback_archive_count UNKNOWN)" "Validate logical-object recovery using flashback query, Data Pump exports, or restore/clone to a point in time."
  fi

  if [[ "$control_plane_state" == "configured" ]]; then
    adb_append_check "$report_file" "OK" "OCI control plane" "ADB OCID and OCI CLI configured" "ocid=set, region=${ADB_REGION:-profile/default}, profile=${ADB_OCI_PROFILE}" "Use OCI evidence to validate backup retention, PITR window, Autonomous Data Guard, clones, and IAM posture."
  else
    adb_append_check "$report_file" "WARN" "OCI control plane" "ADB OCID and OCI CLI configured" "state=${control_plane_state}" "Configure CRASHSIM_ADB_OCID plus OCI CLI/profile when backup/PITR/ADG/IAM readiness must be proven."
  fi

  if [[ -n "$ADB_APEX_URL" || -n "$ADB_DATABASE_ACTIONS_URL" ]]; then
    adb_append_check "$report_file" "OK" "Application access" "User-facing URLs recorded" "apex=${ADB_APEX_URL:-not set}, database_actions=${ADB_DATABASE_ACTIONS_URL:-not set}" "Use URL smoke checks and application-specific login validation after clone/PITR or wallet rotation."
  else
    adb_append_check "$report_file" "INFO" "Application access" "User-facing URLs recorded" "not configured" "Record APEX and Database Actions URLs for operational validation evidence."
  fi

  if [[ -n "$ADB_PRIVATE_ENDPOINT" ]]; then
    adb_append_check "$report_file" "OK" "Network" "Private endpoint expectation documented" "private_endpoint=${ADB_PRIVATE_ENDPOINT}" "Pair this with DNS, route-table, NSG, and bastion evidence for private endpoint loss drills."
  else
    adb_append_check "$report_file" "INFO" "Network" "Private endpoint expectation documented" "not configured" "Set CRASHSIM_ADB_PRIVATE_ENDPOINT when ADB uses private endpoints."
  fi

  append_report_section "$report_file" "Readiness Summary"
  score_den=$((adb_check_ok + adb_check_warn + adb_check_gap))
  if [[ "$score_den" -gt 0 ]]; then
    score=$((adb_check_ok * 100 / score_den))
  else
    score=0
  fi
  {
    printf '| Metric | Value |\n'
    printf '| --- | ---: |\n'
    printf '| ADB readiness scorecard | %s%% |\n' "$adb_domain_score"
    printf '| Operational check score | %s%% |\n' "$score"
    printf '| OK checks | %s |\n' "$adb_check_ok"
    printf '| Warnings | %s |\n' "$adb_check_warn"
    printf '| Gaps | %s |\n' "$adb_check_gap"
    printf '| Informational checks | %s |\n' "$adb_check_info"
  } >>"$report_file"

  append_report_section "$report_file" "Autonomous Scenario Coverage"
  {
    printf '| ID | Scenario | Status | Validation process | Recovery/runbook focus |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"
  for id in "${ADB_SCENARIO_IDS[@]}"; do
    adb_scenario_readiness "$id" status reason
    adb_append_scenario_row "$report_file" "$id" "${ADB_SCENARIO_TITLE[$id]}" "$status" "${ADB_SCENARIO_VALIDATION[$id]} ${reason}" "${ADB_SCENARIO_RECOVERY[$id]}"
  done

  append_report_section "$report_file" "Traditional CrashSimulator Scenarios Not Applicable To ADB"
  {
    printf "Autonomous Database customers cannot directly remove/corrupt managed OS files, ASM disks, Grid Infrastructure resources, control files, redo logs, password files, SPFILEs, ORACLE_HOME, or RMAN backup pieces. For ADB, those failure classes should be represented as OCI service/readiness checks, clone/PITR validation, Autonomous Data Guard drills, and application access-path tests rather than destructive host actions.\n"
  } >>"$report_file"

  append_report_section "$report_file" "Recommended Configuration File Keys"
  {
    printf 'Use non-secret keys in `crashsimulator.conf`, and keep passwords in environment variables named by the config keys.\n\n'
    printf '```text\n'
    printf 'CRASHSIM_ADB_WALLET_DIR=/path/to/wallet\n'
    printf 'CRASHSIM_ADB_CONNECT_ALIAS=myadb_low\n'
    printf 'CRASHSIM_ADB_SERVICE_LEVEL=low\n'
    printf 'CRASHSIM_ADB_USER=ADMIN\n'
    printf 'CRASHSIM_ADB_PASSWORD_ENV=CRASHSIM_ADB_PASSWORD\n'
    printf 'CRASHSIM_ADB_WALLET_PASSWORD_ENV=CRASHSIM_ADB_WALLET_PASSWORD\n'
    printf 'CRASHSIM_ADB_PYTHON=/path/to/python\n'
    printf 'CRASHSIM_ADB_OCID=ocid1.autonomousdatabase...\n'
    printf 'CRASHSIM_ADB_REGION=us-ashburn-1\n'
    printf 'CRASHSIM_ADB_OCI_PROFILE=DEFAULT\n'
    printf 'CRASHSIM_ADB_OCI_AUTH=security_token\n'
    printf 'CRASHSIM_ADB_APEX_URL=https://example.adb.region.oraclecloudapps.com/ords/apex\n'
    printf '```\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw ADB Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    audit_redact_stream <"$evidence_file"
    printf '```\n'
  } >>"$report_file"

  if [[ -n "$ADB_OCID" && "$oci_state" == "found" ]]; then
    local -a oci_cmd=(oci db autonomous-database get --autonomous-database-id "$ADB_OCID")
    [[ -n "$ADB_OCI_PROFILE" ]] && oci_cmd+=(--profile "$ADB_OCI_PROFILE")
    [[ -n "$ADB_OCI_CONFIG_FILE" ]] && oci_cmd+=(--config-file "$ADB_OCI_CONFIG_FILE")
    [[ -n "$ADB_REGION" ]] && oci_cmd+=(--region "$ADB_REGION")
    [[ -n "$ADB_OCI_AUTH" ]] && oci_cmd+=(--auth "$ADB_OCI_AUTH")
    append_report_command "$report_file" "OCI Autonomous Database Metadata" "${oci_cmd[@]}"
  fi

  cp "$report_file" "$latest_file" || die "Unable to update latest ADB readiness report: $latest_file"
  cp "$evidence_file" "$latest_evidence_file" || die "Unable to update latest ADB readiness evidence: $latest_evidence_file"
  echo "Autonomous Database readiness report generated: ${report_file}"
  echo "Latest Autonomous Database readiness report: ${latest_file}"
  echo "Latest Autonomous Database readiness evidence: ${latest_evidence_file}"
  maybe_render_html "$report_file"
}

write_apex_ords_report_sql_file() {
  local sql_file="$1"
  local target_pdb="${2:-}"
  local target_pdb_sql=""

  if [[ -n "$target_pdb" ]]; then
    target_pdb_sql="alter session set container = $(sql_identifier "$target_pdb");"
  fi

  cat >"$sql_file" <<SQL || die "Unable to write APEX/ORDS report SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off
set serveroutput on size unlimited

select 'CSIM_APEX|db_name|' || name from v\$database;
select 'CSIM_APEX|db_unique_name|' || db_unique_name from v\$database;
select 'CSIM_APEX|db_role|' || database_role from v\$database;
select 'CSIM_APEX|open_mode|' || open_mode from v\$database;
select 'CSIM_APEX|cdb|' || cdb from v\$database;
select 'CSIM_APEX|instance_name|' || instance_name from v\$instance;
select 'CSIM_APEX|host_name|' || host_name from v\$instance;
select 'CSIM_APEX|version|' || version from v\$instance;

declare
  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_APEX|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  function scalar_value(p_sql varchar2, p_default varchar2 := 'UNKNOWN') return varchar2 is
    l_value varchar2(4000);
  begin
    execute immediate p_sql into l_value;
    return nvl(l_value, p_default);
  exception
    when others then
      return p_default;
  end;

  function scalar_count(p_sql varchar2, p_default varchar2 := 'UNKNOWN') return varchar2 is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    return to_char(l_count);
  exception
    when others then
      return p_default;
  end;
begin
  emit('target_pdb_requested', '${target_pdb:-not set}');
  emit('cdb_registry_apex_count', scalar_count(q'[select count(*) from cdb_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']'));
  emit('cdb_registry_ords_count', scalar_count(q'[select count(*) from cdb_registry where comp_id = 'ORDS' or upper(comp_name) like '%ORDS%']'));
  emit('cdb_apex_versions', scalar_value(q'[select listagg(con_id || ':' || version || ':' || status, ',') within group (order by con_id, version) from cdb_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']', 'NONE'));
  emit('cdb_ords_versions', scalar_value(q'[select listagg(con_id || ':' || version || ':' || status, ',') within group (order by con_id, version) from cdb_registry where comp_id = 'ORDS' or upper(comp_name) like '%ORDS%']', 'NONE'));
  emit('apex_public_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'APEX_PUBLIC_USER']'));
  emit('ords_public_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'ORDS_PUBLIC_USER']'));
  emit('ords_metadata_user_count', scalar_count(q'[select count(*) from cdb_users where username = 'ORDS_METADATA']'));
  emit('runtime_locked_expired_count', scalar_count(q'[select count(*) from cdb_users where username in ('APEX_PUBLIC_USER','ORDS_PUBLIC_USER','ORDS_METADATA') and account_status not like 'OPEN%']'));
  emit('invalid_apex_object_count', scalar_count(q'[select count(*) from cdb_objects where owner like 'APEX\_%' escape '\' and status <> 'VALID']'));
  emit('invalid_ords_object_count', scalar_count(q'[select count(*) from cdb_objects where owner in ('ORDS_METADATA','ORDS_PUBLIC_USER') and status <> 'VALID']'));
  emit('network_acl_count', scalar_count(q'[select count(*) from dba_network_acls]'));
end;
/

${target_pdb_sql}
set serveroutput on size unlimited

select 'CSIM_APEX|current_container|' || sys_context('USERENV','CON_NAME') from dual;

declare
  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_APEX|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  function scalar_value(p_sql varchar2, p_default varchar2 := 'UNAVAILABLE') return varchar2 is
    l_value varchar2(4000);
  begin
    execute immediate p_sql into l_value;
    return nvl(l_value, p_default);
  exception
    when others then
      return p_default;
  end;

  function scalar_count(p_sql varchar2, p_default varchar2 := 'UNAVAILABLE') return varchar2 is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    return to_char(l_count);
  exception
    when others then
      return p_default;
  end;
begin
  emit('local_apex_registry_count', scalar_count(q'[select count(*) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']'));
  emit('local_apex_version', scalar_value(q'[select max(version || ':' || status) from dba_registry where comp_id = 'APEX' or upper(comp_name) like '%APEX%']', 'NONE'));
  emit('local_ords_registry_count', scalar_count(q'[select count(*) from dba_registry where comp_id = 'ORDS' or upper(comp_name) like '%ORDS%']'));
  emit('local_apex_public_user_status', scalar_value(q'[select max(account_status) from dba_users where username = 'APEX_PUBLIC_USER']', 'MISSING'));
  emit('local_ords_public_user_status', scalar_value(q'[select max(account_status) from dba_users where username = 'ORDS_PUBLIC_USER']', 'MISSING'));
  emit('local_ords_metadata_user_status', scalar_value(q'[select max(account_status) from dba_users where username = 'ORDS_METADATA']', 'MISSING'));
  emit('local_invalid_apex_objects', scalar_count(q'[select count(*) from dba_objects where owner like 'APEX\_%' escape '\' and status <> 'VALID']'));
  emit('local_invalid_ords_objects', scalar_count(q'[select count(*) from dba_objects where owner in ('ORDS_METADATA','ORDS_PUBLIC_USER') and status <> 'VALID']'));
  emit('apex_workspace_count', scalar_count(q'[select count(*) from apex_workspaces]'));
  emit('apex_application_count', scalar_count(q'[select count(*) from apex_applications]'));
  emit('apex_smtp_parameter_count', scalar_count(q'[select count(*) from apex_instance_parameters where upper(name) like 'SMTP%' and value is not null]'));
  emit('apex_wallet_parameter_count', scalar_count(q'[select count(*) from apex_instance_parameters where upper(name) like '%WALLET%' and value is not null]'));
  emit('local_network_acl_count', scalar_count(q'[select count(*) from dba_network_acls]'));
end;
/

exit
SQL
}

parse_apex_ords_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  APEX_ORDS_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_APEX" && -n "$key" ]] || continue
    APEX_ORDS_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

apex_ords_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${APEX_ORDS_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

apex_ords_positive() {
  local key="$1"
  local value
  value="$(apex_ords_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

apex_ords_zero() {
  local key="$1"
  local value
  value="$(apex_ords_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -eq 0 ]]
}

apex_ords_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

apex_ords_report_target_pdb() {
  if [[ "$DB_CDB" != "YES" ]]; then
    printf "%s" ""
    return "$SUCCESS"
  fi
  if [[ -n "$TARGET_PDB" ]]; then
    pdb_exists "$TARGET_PDB" ||
      die "PDB ${TARGET_PDB} was not found in this CDB. Available PDBs: $(pdb_list_for_message)"
    printf "%s" "$TARGET_PDB"
    return "$SUCCESS"
  fi
  if [[ "${#PDB_ROWS[@]}" -eq 1 ]]; then
    printf "%s" "$(printf "%s" "${PDB_ROWS[0]}" | cut -d'|' -f1)"
    return "$SUCCESS"
  fi
  printf "%s" ""
}

run_ords_priv_helper() {
  [[ -n "$ORDS_PRIV_HELPER" && -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  echo "sudo -n ${ORDS_PRIV_HELPER} $*"
  sudo -n "$ORDS_PRIV_HELPER" "$@"
}

ords_priv_helper_service_available() {
  local rc
  [[ -n "$ORDS_PRIV_HELPER" && -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  sudo -n "$ORDS_PRIV_HELPER" service status "$ORDS_SERVICE_NAME" >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 0 || "$rc" -eq 3 ]]
}

ords_priv_helper_config_available() {
  [[ -n "$ORDS_PRIV_HELPER" && -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  sudo -n "$ORDS_PRIV_HELPER" config-check "$ORDS_CONFIG_DIR" >/dev/null 2>&1
}

ords_sudo_systemctl_available() {
  local rc
  command -v sudo >/dev/null 2>&1 || return "$FAIL"
  sudo -n systemctl status "$ORDS_SERVICE_NAME" >/dev/null 2>&1
  rc=$?
  [[ "$rc" -eq 0 || "$rc" -eq 3 ]]
}

ords_control_method() {
  if [[ "$(id -u)" -eq 0 ]]; then
    printf "systemctl"
    return "$SUCCESS"
  fi
  if ords_priv_helper_service_available; then
    printf "ords_priv_helper"
    return "$SUCCESS"
  fi
  if ords_sudo_systemctl_available; then
    printf "sudo_systemctl"
    return "$SUCCESS"
  fi
  return "$FAIL"
}

ords_control_command_prefix() {
  case "$(ords_control_method 2>/dev/null || true)" in
    systemctl)
      printf "systemctl"
      ;;
    ords_priv_helper)
      printf "sudo -n %s service" "$ORDS_PRIV_HELPER"
      ;;
    sudo_systemctl)
      printf "sudo -n systemctl"
      ;;
    *)
      return "$FAIL"
      ;;
  esac
}

can_control_ords_service() {
  command -v systemctl >/dev/null 2>&1 || [[ -e "$ORDS_PRIV_HELPER" ]] || return "$FAIL"
  ords_control_method >/dev/null 2>&1 || return "$FAIL"
}

ords_service_unit_exists() {
  local unit_output
  command -v systemctl >/dev/null 2>&1 || return "$FAIL"
  unit_output="$(systemctl list-unit-files "${ORDS_SERVICE_NAME}.service" --no-legend 2>/dev/null | trim_blank_lines || true)"
  [[ -n "$unit_output" ]] ||
    systemctl status "$ORDS_SERVICE_NAME" >/dev/null 2>&1
}

detect_apex_images_dir() {
  if [[ -n "$APEX_IMAGES_DIR" ]]; then
    [[ -d "$APEX_IMAGES_DIR" ]] && printf "%s" "$APEX_IMAGES_DIR" && return "$SUCCESS"
    return "$FAIL"
  fi

  local candidate
  for candidate in \
    /opt/oracle/apex/images \
    /u01/app/oracle/apex/images \
    /u01/app/oracle/product/apex/images \
    /tmp/apex/images; do
    if [[ -d "$candidate" ]]; then
      printf "%s" "$candidate"
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

run_apex_ords_report() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file evidence_file generated_at target_pdb
  local ords_bin ords_version ords_service_state ords_config_state ords_url_state ords_lb_state
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  target_pdb="$(apex_ords_report_target_pdb)"
  report_file="${LOG_DIR}/crashsim_apex_ords_report_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_apex_ords_report_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_apex_ords_report_${RUN_ID}.evidence"

  write_apex_ords_report_sql_file "$sql_file" "$target_pdb"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "APEX/ORDS report SQL failed: $sql_file (evidence: $evidence_file)"
  parse_apex_ords_evidence_file "$evidence_file"

  ords_bin="$(command -v ords 2>/dev/null || true)"
  if [[ -n "$ords_bin" ]]; then
    if command -v timeout >/dev/null 2>&1; then
      ords_version="$(timeout 15 ords --version 2>&1 | awk '/Oracle REST Data Services/ {line=$0} END {if (line != "") print line; else print "version unavailable"}' || true)"
    else
      ords_version="$(ords --version 2>&1 | awk '/Oracle REST Data Services/ {line=$0} END {if (line != "") print line; else print "version unavailable"}' || true)"
    fi
    [[ -n "$ords_version" ]] || ords_version="version unavailable"
  else
    ords_version="not found"
  fi
  if command -v systemctl >/dev/null 2>&1; then
    ords_service_state="$(systemctl is-active "$ORDS_SERVICE_NAME" 2>/dev/null || true)"
    [[ -n "$ords_service_state" ]] || ords_service_state="unavailable"
  else
    ords_service_state="systemctl not found"
  fi
  if [[ -d "$ORDS_CONFIG_DIR" ]]; then
    ords_config_state="present"
  else
    ords_config_state="missing"
  fi
  if command -v curl >/dev/null 2>&1; then
    if curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1; then
      ords_url_state="OK"
    else
      ords_url_state="FAILED"
    fi
    if [[ -n "$ORDS_LB_URL" ]]; then
      if curl -fsS -L --max-time 10 "$ORDS_LB_URL" >/dev/null 2>&1; then
        ords_lb_state="OK"
      else
        ords_lb_state="FAILED"
      fi
    else
      ords_lb_state="not supplied"
    fi
  else
    ords_url_state="curl not found"
    ords_lb_state="curl not found"
  fi

  {
    printf "# CrashSimulator APEX / ORDS Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(apex_ords_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(apex_ords_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(apex_ords_value db_role "$DB_ROLE")" "$(apex_ords_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(apex_ords_value cdb "$DB_CDB")"
    printf -- '- Target PDB detail: `%s`\n' "${target_pdb:-not selected}"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf -- '- ORDS service name: `%s`\n' "$ORDS_SERVICE_NAME"
    printf -- '- ORDS config directory: `%s`\n' "$ORDS_CONFIG_DIR"
    printf -- '- ORDS smoke URL: `%s`\n' "$ORDS_URL"
    printf "\n"
    printf "This report treats APEX/ORDS as an application access-path dependency. A database can be technically recovered while users are still down because ORDS, static files, runtime users, wallet/TLS, or PDB/service mapping are not healthy.\n"
  } >"$report_file" || die "Unable to write APEX/ORDS report file: $report_file"

  append_report_section "$report_file" "Host-Side ORDS Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| ORDS binary | `%s` |\n' "$(md_escape "${ords_bin:-not found}")"
    printf '| ORDS version | `%s` |\n' "$(md_escape "$ords_version")"
    printf '| systemd service | `%s` |\n' "$(md_escape "$ORDS_SERVICE_NAME")"
    printf '| service state | `%s` |\n' "$(md_escape "$ords_service_state")"
    printf '| config directory | `%s` |\n' "$(md_escape "$ords_config_state")"
    printf '| smoke URL | `%s` |\n' "$(md_escape "$ords_url_state")"
    printf '| load balancer URL | `%s` |\n' "$(md_escape "$ords_lb_state")"
  } >>"$report_file"

  append_report_section "$report_file" "Database-Side APEX / ORDS Summary"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| CDB APEX registry rows | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_registry_apex_count)")"
    printf '| CDB APEX versions/status | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_apex_versions)")"
    printf '| CDB ORDS registry rows | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_registry_ords_count)")"
    printf '| CDB ORDS versions/status | `%s` |\n' "$(md_escape "$(apex_ords_value cdb_ords_versions)")"
    printf '| Current container | `%s` |\n' "$(md_escape "$(apex_ords_value current_container)")"
    printf '| Local APEX version/status | `%s` |\n' "$(md_escape "$(apex_ords_value local_apex_version)")"
    printf '| APEX_PUBLIC_USER | `%s` |\n' "$(md_escape "$(apex_ords_value local_apex_public_user_status)")"
    printf '| ORDS_PUBLIC_USER | `%s` |\n' "$(md_escape "$(apex_ords_value local_ords_public_user_status)")"
    printf '| ORDS_METADATA | `%s` |\n' "$(md_escape "$(apex_ords_value local_ords_metadata_user_status)")"
    printf '| Invalid APEX objects | `%s` |\n' "$(md_escape "$(apex_ords_value local_invalid_apex_objects)")"
    printf '| Invalid ORDS objects | `%s` |\n' "$(md_escape "$(apex_ords_value local_invalid_ords_objects)")"
    printf '| APEX workspaces | `%s` |\n' "$(md_escape "$(apex_ords_value apex_workspace_count)")"
    printf '| APEX applications | `%s` |\n' "$(md_escape "$(apex_ords_value apex_application_count)")"
    printf '| APEX SMTP parameters | `%s` |\n' "$(md_escape "$(apex_ords_value apex_smtp_parameter_count)")"
    printf '| APEX wallet parameters | `%s` |\n' "$(md_escape "$(apex_ords_value apex_wallet_parameter_count)")"
    printf '| Network ACLs | `%s` |\n' "$(md_escape "$(apex_ords_value local_network_acl_count)")"
  } >>"$report_file"

  append_report_section "$report_file" "Readiness Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ -n "$ords_bin" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS host" "ORDS binary available" "ords=${ords_bin}, version=${ords_version}" "Keep ORDS packaged or pinned consistently across all ORDS/RAC nodes."
  else
    apex_ords_append_check "$report_file" "GAP" "ORDS host" "ORDS binary available" "ords=not found" "Install ORDS on every intended mid-tier node before ORDS outage drills."
  fi
  if [[ "$ords_config_state" == "present" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS config" "Configuration directory present" "config=${ORDS_CONFIG_DIR}" "Back up ORDS config, wallets, pool settings, and static-file mappings."
  else
    apex_ords_append_check "$report_file" "GAP" "ORDS config" "Configuration directory present" "config=${ORDS_CONFIG_DIR} missing" "Run ORDS install/configuration and include the config directory in lab backups."
  fi
  if [[ "$ords_service_state" == "active" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS service" "Service active" "systemctl is-active ${ORDS_SERVICE_NAME}=active" "Validate restart, service monitoring, and node-outage behavior."
  else
    apex_ords_append_check "$report_file" "WARN" "ORDS service" "Service active" "systemctl is-active ${ORDS_SERVICE_NAME}=${ords_service_state}" "Start or configure the ORDS service before user-facing outage drills."
  fi
  if [[ "$ords_url_state" == "OK" ]]; then
    apex_ords_append_check "$report_file" "OK" "ORDS access" "Smoke URL reachable" "url=${ORDS_URL}" "Use application-specific APEX URLs for deeper smoke checks."
  else
    apex_ords_append_check "$report_file" "GAP" "ORDS access" "Smoke URL reachable" "url=${ORDS_URL}, result=${ords_url_state}" "Fix listener/firewall/ORDS/service mapping before declaring application access recovered."
  fi
  if apex_ords_positive local_apex_registry_count; then
    apex_ords_append_check "$report_file" "OK" "APEX database" "APEX installed in target container" "APEX=$(apex_ords_value local_apex_version)" "Keep APEX patch/upgrade validation aligned with database recovery drills."
  else
    apex_ords_append_check "$report_file" "GAP" "APEX database" "APEX installed in target container" "APEX=$(apex_ords_value local_apex_version NONE)" "Install APEX in the intended PDB before APEX runtime/static/application scenarios can execute."
  fi
  if [[ "$(apex_ords_value local_apex_public_user_status MISSING)" == OPEN* && "$(apex_ords_value local_ords_public_user_status MISSING)" == OPEN* ]]; then
    apex_ords_append_check "$report_file" "OK" "Runtime accounts" "APEX/ORDS runtime accounts open" "APEX_PUBLIC_USER=$(apex_ords_value local_apex_public_user_status), ORDS_PUBLIC_USER=$(apex_ords_value local_ords_public_user_status)" "Include runtime-account lock/credential rotation drills in quarterly testing."
  else
    apex_ords_append_check "$report_file" "WARN" "Runtime accounts" "APEX/ORDS runtime accounts open" "APEX_PUBLIC_USER=$(apex_ords_value local_apex_public_user_status), ORDS_PUBLIC_USER=$(apex_ords_value local_ords_public_user_status)" "Unlock or configure runtime users after installation; test account-lock recovery before production use."
  fi
  if apex_ords_zero local_invalid_apex_objects && apex_ords_zero local_invalid_ords_objects; then
    apex_ords_append_check "$report_file" "OK" "Invalid objects" "APEX/ORDS objects valid" "APEX=$(apex_ords_value local_invalid_apex_objects), ORDS=$(apex_ords_value local_invalid_ords_objects)" "Re-check after PDB recovery, APEX patching, datapatch, and ORDS upgrades."
  else
    apex_ords_append_check "$report_file" "WARN" "Invalid objects" "APEX/ORDS objects valid" "APEX=$(apex_ords_value local_invalid_apex_objects), ORDS=$(apex_ords_value local_invalid_ords_objects)" "Compile and investigate invalid objects before application availability drills."
  fi

  append_report_section "$report_file" "Recommended APEX / ORDS Scenario Family"
  {
    printf '| ID | Scenario | Lifecycle posture |\n'
    printf '| --- | --- | --- |\n'
    printf '| `73` | ORDS service unavailable | Automatable when the OS user can control the ORDS systemd unit. |\n'
    printf '| `74` | ORDS configuration unavailable | Automatable only when the config directory is writable or explicitly run with approved OS privileges. |\n'
    printf '| `75` | ORDS database pool misconfiguration | Reversible db.servicename mutation when ORDS restart privileges are approved; --recover 75 restores the original value. |\n'
    printf '| `76` | APEX/ORDS runtime account locked | Automatable when APEX/ORDS runtime users exist in the target container. |\n'
    printf '| `77` | APEX static resources unavailable | Automatable when an APEX images/static directory is configured and writable. |\n'
    printf '| `78` | APEX application availability validation after recovery | Read-only smoke evidence after PDB/datafile recovery. |\n'
    printf '| `79` | One ORDS node unavailable behind load balancer | Automatable when ORDS service control and a load-balancer URL are supplied. |\n'
    printf '| `80` | APEX session continuity test | Read-only continuity evidence, with optional seeded Playwright browser-session driver for screenshots and JSON/Markdown evidence. |\n'
    printf '| `81` | APEX mail queue/configuration validation | Read-only APEX SMTP/wallet/ACL evidence. |\n'
    printf '| `82` | APEX upgrade/patch rollback readiness | Read-only pre/post evidence and runbook. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw APEX / ORDS SQL Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_APEX|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  if [[ -n "$ords_bin" ]]; then
    append_report_command "$report_file" "ORDS Version" ords --version
    if [[ -d "$ORDS_CONFIG_DIR" ]]; then
      append_report_command "$report_file" "ORDS Config List" ords --config "$ORDS_CONFIG_DIR" config list
    fi
  fi
  if command -v systemctl >/dev/null 2>&1; then
    append_report_command "$report_file" "ORDS Service Status" systemctl status "$ORDS_SERVICE_NAME"
  fi
  if command -v curl >/dev/null 2>&1; then
  append_report_command "$report_file" "ORDS Smoke URL" curl -sS -L -o /dev/null -D - --max-time 10 "$ORDS_URL"
  if [[ -n "$ORDS_LB_URL" ]]; then
    append_report_command "$report_file" "ORDS Load Balancer Smoke URL" curl -sS -L -o /dev/null -D - --max-time 10 "$ORDS_LB_URL"
  fi
  fi

  echo "APEX/ORDS readiness report generated: ${report_file}"
  maybe_render_html "$report_file"
}

write_maa_assessment_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write MAA assessment SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off
set serveroutput on size unlimited

select 'CSIM_MAA|db_name|' || name from v$database;
select 'CSIM_MAA|db_unique_name|' || db_unique_name from v$database;
select 'CSIM_MAA|db_role|' || database_role from v$database;
select 'CSIM_MAA|open_mode|' || open_mode from v$database;
select 'CSIM_MAA|cdb|' || cdb from v$database;
select 'CSIM_MAA|log_mode|' || log_mode from v$database;
select 'CSIM_MAA|force_logging|' || force_logging from v$database;
select 'CSIM_MAA|flashback_on|' || flashback_on from v$database;
select 'CSIM_MAA|protection_mode|' || protection_mode from v$database;
select 'CSIM_MAA|protection_level|' || protection_level from v$database;
select 'CSIM_MAA|switchover_status|' || switchover_status from v$database;
select 'CSIM_MAA|fsfo_status|' || nvl(fs_failover_status, 'UNKNOWN') from v$database;
select 'CSIM_MAA|fsfo_target|' || nvl(fs_failover_current_target, 'NONE') from v$database;
select 'CSIM_MAA|fsfo_threshold|' || nvl(to_char(fs_failover_threshold), 'UNKNOWN') from v$database;
select 'CSIM_MAA|fsfo_observer_present|' || nvl(fs_failover_observer_present, 'UNKNOWN') from v$database;
select 'CSIM_MAA|dbid|' || dbid from v$database;
select 'CSIM_MAA|platform_name|' || platform_name from v$database;

select 'CSIM_MAA|instance_name|' || instance_name from v$instance;
select 'CSIM_MAA|host_name|' || host_name from v$instance;
select 'CSIM_MAA|version|' || version from v$instance;
select 'CSIM_MAA|version_major|' || regexp_substr(version, '^[0-9]+') from v$instance;
select 'CSIM_MAA|instance_status|' || status from v$instance;
select 'CSIM_MAA|instance_parallel|' || parallel from v$instance;
select 'CSIM_MAA|instance_thread|' || thread# from v$instance;

select 'CSIM_MAA|cluster_database|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'cluster_database';
select 'CSIM_MAA|remote_login_passwordfile|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'remote_login_passwordfile';
select 'CSIM_MAA|db_recovery_file_dest|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'db_recovery_file_dest';
select 'CSIM_MAA|db_recovery_file_dest_size|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'db_recovery_file_dest_size';
select 'CSIM_MAA|local_undo_enabled|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'local_undo_enabled';
select 'CSIM_MAA|wallet_root|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'wallet_root';
select 'CSIM_MAA|tde_configuration|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'tde_configuration';
select 'CSIM_MAA|archive_lag_target|' || nvl(max(value), 'UNKNOWN')
from v$parameter
where name = 'archive_lag_target';
select 'CSIM_MAA|adg_redirect_dml|' || nvl(max(value), 'UNAVAILABLE')
from v$parameter
where name = 'adg_redirect_dml';
select 'CSIM_MAA|adg_redirect_dml_modifiable|' || nvl(max(issys_modifiable), 'UNAVAILABLE')
from v$parameter
where name = 'adg_redirect_dml';

select 'CSIM_MAA|control_file_count|' || count(*) from v$controlfile;
select 'CSIM_MAA|redo_group_count|' || count(*) from v$log;
select 'CSIM_MAA|redo_min_members|' || nvl(min(members), 0) from v$log;
select 'CSIM_MAA|redo_groups_less_than_two_members|' || count(*) from v$log where members < 2;
select 'CSIM_MAA|recover_file_count|' || count(*) from v$recover_file;
select 'CSIM_MAA|block_corruption_count|' || count(*) from v$database_block_corruption;
select 'CSIM_MAA|copy_corruption_count|' || count(*) from v$copy_corruption;
select 'CSIM_MAA|backup_corruption_count|' || count(*) from v$backup_corruption;
select 'CSIM_MAA|guaranteed_restore_point_count|' || count(*)
from v$restore_point
where guarantee_flashback_database = 'YES';

select 'CSIM_MAA|fra_configured|' ||
       case when count(*) > 0 and max(space_limit) > 0 then 'YES' else 'NO' end
from v$recovery_file_dest;
select 'CSIM_MAA|fra_used_pct|' ||
       nvl(to_char(round(max(space_used) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;
select 'CSIM_MAA|fra_reclaimable_pct|' ||
       nvl(to_char(round(max(space_reclaimable) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;

select 'CSIM_MAA|recent_successful_backup_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status like 'COMPLETED%';
select 'CSIM_MAA|recent_failed_backup_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status not like 'COMPLETED%';
select 'CSIM_MAA|last_successful_backup_time|' ||
       nvl(to_char(max(end_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_MAA|last_successful_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(end_time)) * 24, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_MAA|backup_device_types|' ||
       nvl((
         select listagg(output_device_type, ',') within group (order by output_device_type)
         from (
           select distinct nvl(output_device_type, 'UNKNOWN') output_device_type
           from v$rman_backup_job_details
           where start_time >= sysdate - 30
         )
       ), 'NONE')
from dual;
select 'CSIM_MAA|datafiles_without_backup_metadata|' || count(*)
from (
  select df.file#
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
  having max(bdf.completion_time) is null
);

select 'CSIM_MAA|remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status <> 'INACTIVE';
select 'CSIM_MAA|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_MAA|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_MAA|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_MAA|dataguard_stats_count|' || count(*) from v$dataguard_stats;
select 'CSIM_MAA|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_MAA|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

select 'CSIM_MAA|tde_wallet_open_count|' || count(*)
from v$encryption_wallet
where status = 'OPEN';
select 'CSIM_MAA|tde_wallet_not_open_count|' || count(*)
from v$encryption_wallet
where status <> 'OPEN';
select 'CSIM_MAA|encrypted_tablespace_count|' || count(*)
from dba_tablespaces
where encrypted = 'YES';

select 'CSIM_MAA|pdb_count|' ||
       case when (select cdb from v$database) = 'YES'
            then (select count(*) from v$pdbs where name <> 'PDB$SEED')
            else 0
       end
from dual;
select 'CSIM_MAA|pdb_not_open_rw_count|' ||
       case when (select cdb from v$database) = 'YES'
            then (select count(*) from v$pdbs where name <> 'PDB$SEED' and open_mode <> 'READ WRITE')
            else 0
       end
from dual;

declare
  l_service_view varchar2(30) := 'DBA_SERVICES';
  l_aq_column varchar2(30);
  l_count number;
  l_has_failover_type boolean;
  l_has_commit_outcome boolean;
  l_has_aq_notification boolean;
  l_has_goal boolean;
  l_has_clb_goal boolean;
  l_has_drain_timeout boolean;
  l_has_session_state boolean;
  l_has_failover_restore boolean;
  l_has_pdb boolean;
  l_ac_condition varchar2(2000) := '1=0';
  l_tac_condition varchar2(2000) := '1=0';
  l_replay_condition varchar2(2000) := '1=0';
  l_user_filter varchar2(1000) := q'[name not like 'SYS$%' and upper(name) not in ('XDB')]';

  function has_column(p_table_name varchar2, p_column_name varchar2) return boolean is
    l_count number;
  begin
    select count(*)
    into l_count
    from all_tab_columns
    where table_name = upper(p_table_name)
      and column_name = upper(p_column_name);
    return l_count > 0;
  exception
    when others then
      return false;
  end;

  procedure emit(p_key varchar2, p_value varchar2) is
  begin
    dbms_output.put_line('CSIM_MAA|' || p_key || '|' || nvl(p_value, 'UNKNOWN'));
  end;

  procedure emit_count(p_key varchar2, p_sql varchar2) is
    l_count number;
  begin
    execute immediate p_sql into l_count;
    emit(p_key, to_char(l_count));
  exception
    when others then
      emit(p_key, 'UNKNOWN');
  end;
begin
  l_has_failover_type := has_column(l_service_view, 'FAILOVER_TYPE');
  l_has_commit_outcome := has_column(l_service_view, 'COMMIT_OUTCOME');
  if has_column(l_service_view, 'AQ_HA_NOTIFICATION') then
    l_has_aq_notification := true;
    l_aq_column := 'aq_ha_notification';
  elsif has_column(l_service_view, 'AQ_HA_NOTIFICATIONS') then
    l_has_aq_notification := true;
    l_aq_column := 'aq_ha_notifications';
  else
    l_has_aq_notification := false;
    l_aq_column := null;
  end if;
  l_has_goal := has_column(l_service_view, 'GOAL');
  l_has_clb_goal := has_column(l_service_view, 'CLB_GOAL');
  l_has_drain_timeout := has_column(l_service_view, 'DRAIN_TIMEOUT');
  l_has_session_state := has_column(l_service_view, 'SESSION_STATE_CONSISTENCY');
  l_has_failover_restore := has_column(l_service_view, 'FAILOVER_RESTORE');
  l_has_pdb := has_column(l_service_view, 'PDB');

  emit('service_attribute_source', l_service_view);
  emit('service_failover_type_column', case when l_has_failover_type then 'YES' else 'NO' end);
  emit('service_commit_outcome_column', case when l_has_commit_outcome then 'YES' else 'NO' end);
  emit('service_aq_ha_notification_column', case when l_has_aq_notification then 'YES' else 'NO' end);
  emit('service_drain_timeout_column', case when l_has_drain_timeout then 'YES' else 'NO' end);
  emit('service_session_state_column', case when l_has_session_state then 'YES' else 'NO' end);

  if l_has_failover_type then
    l_ac_condition := l_ac_condition || q'[ or upper(nvl(failover_type,'')) = 'TRANSACTION']';
    l_tac_condition := l_tac_condition || q'[ or upper(nvl(failover_type,'')) = 'AUTO']';
    l_replay_condition := l_replay_condition || q'[ or upper(nvl(failover_type,'')) in ('TRANSACTION','AUTO')]';
  end if;
  if l_has_commit_outcome then
    l_ac_condition := l_ac_condition || q'[ or upper(nvl(commit_outcome,'')) in ('YES','TRUE')]';
    l_replay_condition := l_replay_condition || q'[ or upper(nvl(commit_outcome,'')) in ('YES','TRUE')]';
  end if;

  emit_count('service_total_count', 'select count(*) from ' || l_service_view);
  emit_count('service_user_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter);
  emit_count('ac_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_ac_condition || ')');
  emit_count('tac_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_tac_condition || ')');
  emit_count('application_continuity_service_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and (' || l_replay_condition || ')');
  emit_count('service_without_ac_tac_count', 'select count(*) from ' || l_service_view || ' where ' || l_user_filter || ' and not (' || l_replay_condition || ')');

  if l_has_commit_outcome then
    emit_count('commit_outcome_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(commit_outcome,'')) in ('YES','TRUE')]');
  else
    emit('commit_outcome_service_count', 'UNKNOWN');
  end if;

  if l_has_aq_notification then
    emit_count('fan_notification_service_count', 'select count(*) from dba_services where name not like ''SYS$%'' and upper(name) not in (''XDB'') and upper(nvl(' || l_aq_column || ',''NO'')) in (''YES'',''TRUE'')');
  else
    emit('fan_notification_service_count', 'UNKNOWN');
  end if;

  if l_has_goal and l_has_clb_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and (upper(nvl(goal,'NONE')) <> 'NONE' or upper(nvl(clb_goal,'NONE')) <> 'NONE')]');
  elsif l_has_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(goal,'NONE')) <> 'NONE']');
  elsif l_has_clb_goal then
    emit_count('runtime_load_balancing_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(clb_goal,'NONE')) <> 'NONE']');
  else
    emit('runtime_load_balancing_service_count', 'UNKNOWN');
  end if;

  if l_has_drain_timeout then
    emit_count('drain_timeout_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and nvl(drain_timeout,0) > 0]');
  else
    emit('drain_timeout_service_count', 'UNKNOWN');
  end if;

  if l_has_session_state then
    emit_count('session_state_consistency_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(session_state_consistency,'NONE')) not in ('NONE','STATIC')]');
  else
    emit('session_state_consistency_service_count', 'UNKNOWN');
  end if;

  if l_has_failover_restore then
    emit_count('failover_restore_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and upper(nvl(failover_restore,'NONE')) not in ('NONE','NO')]');
  else
    emit('failover_restore_service_count', 'UNKNOWN');
  end if;

  if l_has_pdb then
    emit_count('pdb_service_count', q'[select count(*) from dba_services where name not like 'SYS$%' and upper(name) not in ('XDB') and pdb is not null]');
  else
    emit('pdb_service_count', 'UNKNOWN');
  end if;

  begin
    execute immediate 'select count(*) from dba_capture' into l_count;
    emit('capture_process_count', to_char(l_count));
  exception
    when others then
      emit('capture_process_count', 'UNKNOWN');
  end;

  begin
    execute immediate 'select count(*) from dba_apply' into l_count;
    emit('apply_process_count', to_char(l_count));
  exception
    when others then
      emit('apply_process_count', 'UNKNOWN');
  end;
end;
/

exit
SQL
}

parse_maa_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  MAA_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_MAA" && -n "$key" ]] || continue
    MAA_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

maa_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${MAA_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

maa_positive() {
  local key="$1"
  local value
  value="$(maa_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -gt 0 ]]
}

maa_zero() {
  local key="$1"
  local value
  value="$(maa_value "$key" "0")"
  [[ "$value" =~ ^[0-9]+$ && "$value" -eq 0 ]]
}

maa_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

maa_promote_count_from_srvctl() {
  local target_key="$1"
  shift
  local current source_key source_value promoted=0

  current="$(maa_value "$target_key" "0")"
  [[ "$current" =~ ^[0-9]+$ ]] || current=0
  for source_key in "$@"; do
    source_value="$(maa_value "$source_key" "0")"
    [[ "$source_value" =~ ^[0-9]+$ ]] || source_value=0
    promoted=$((promoted + source_value))
  done

  if [[ "$promoted" -gt "$current" ]]; then
    MAA_EVIDENCE["$target_key"]="$promoted"
  fi
}

collect_srvctl_service_evidence() {
  local output_file="$1"
  local summary_file="${output_file}.summary"
  local status="UNAVAILABLE"

  MAA_EVIDENCE["srvctl_available"]="NO"
  MAA_EVIDENCE["srvctl_service_status"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_role_based_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_primary_role_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_standby_role_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_all_role_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_automatic_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_singleton_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_uniform_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_ac_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_tac_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_fan_notification_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_commit_outcome_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_runtime_load_balancing_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_drain_timeout_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_session_state_consistency_service_count"]="UNAVAILABLE"
  MAA_EVIDENCE["srvctl_failover_restore_service_count"]="UNAVAILABLE"

  if ! grid_tool_available srvctl || [[ -z "$DB_UNIQUE_NAME" ]]; then
    {
      printf "srvctl unavailable or DB_UNIQUE_NAME not discovered.\n"
      printf "srvctl=%s\n" "$(discover_grid_home_for_tool srvctl 2>/dev/null || printf not-found)"
      printf "DB_UNIQUE_NAME=%s\n" "${DB_UNIQUE_NAME:-unknown}"
    } >"$output_file" || true
    return "$SUCCESS"
  fi

  MAA_EVIDENCE["srvctl_available"]="YES"
  if run_grid_tool srvctl config service -d "$DB_UNIQUE_NAME" >"$output_file" 2>&1; then
    status="OK"
  else
    status="ERROR_OR_NO_SERVICES"
  fi
  MAA_EVIDENCE["srvctl_service_status"]="$status"

  awk '
    BEGIN {
      service_count=0
      role_based=0
      primary_role=0
      standby_role=0
      all_role=0
      automatic=0
      singleton=0
      uniform=0
      ac=0
      tac=0
      fan=0
      commit=0
      rlb=0
      drain=0
      session_state=0
      failover_restore=0
      in_service=0
    }
    function trim(v) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
      return v
    }
    function field_value(line) {
      sub(/^[^:]+:[[:space:]]*/, "", line)
      return trim(line)
    }
    function flush_service() {
      if (!in_service) return
      if (svc_role != "" && svc_role != "none" && svc_role != "null") role_based++
      if (svc_role ~ /primary/) primary_role++
      if (svc_role ~ /standby|physical_standby|logical_standby|snapshot_standby/) standby_role++
      if (svc_role ~ /all/) all_role++
      if (svc_policy ~ /automatic/) automatic++
      if (svc_cardinality ~ /singleton/) singleton++
      if (svc_cardinality ~ /uniform/) uniform++
      if (svc_failover_type == "transaction") ac++
      if (svc_failover_type == "auto") tac++
      if (svc_fan ~ /true|yes/) fan++
      if (svc_commit ~ /true|yes/) commit++
      if (svc_rlb !~ /^$|none/) rlb++
      if (svc_drain + 0 > 0) drain++
      if (svc_session_state !~ /^$|none|static/) session_state++
      if (svc_failover_restore !~ /^$|none|no/) failover_restore++
    }
    function reset_service() {
      svc_role=""
      svc_policy=""
      svc_cardinality=""
      svc_failover_type=""
      svc_fan=""
      svc_commit=""
      svc_rlb=""
      svc_drain=0
      svc_session_state=""
      svc_failover_restore=""
    }
    /^Service name:/ {
      flush_service()
      reset_service()
      in_service=1
      service_count++
      next
    }
    /^(Service )?[Rr]ole:/ {
      svc_role=tolower(field_value($0))
      next
    }
    /^Management policy:/ {
      svc_policy=tolower(field_value($0))
      next
    }
    /^Cardinality:/ {
      svc_cardinality=tolower(field_value($0))
      next
    }
    /^Failover type:/ {
      svc_failover_type=tolower(field_value($0))
      next
    }
    /^AQ HA notifications:/ {
      svc_fan=tolower(field_value($0))
      next
    }
    /^Commit Outcome:/ {
      svc_commit=tolower(field_value($0))
      next
    }
    /^Runtime Load Balancing Goal:/ {
      svc_rlb=tolower(field_value($0))
      next
    }
    /^Drain timeout:/ {
      value=tolower(field_value($0))
      gsub(/[^0-9]/, "", value)
      svc_drain=value + 0
      next
    }
    /^Session State Consistency:/ {
      svc_session_state=tolower(field_value($0))
      next
    }
    /^Failover restore:/ {
      svc_failover_restore=tolower(field_value($0))
      next
    }
    END {
      flush_service()
      print "srvctl_service_count=" service_count
      print "srvctl_role_based_service_count=" role_based
      print "srvctl_primary_role_service_count=" primary_role
      print "srvctl_standby_role_service_count=" standby_role
      print "srvctl_all_role_service_count=" all_role
      print "srvctl_automatic_service_count=" automatic
      print "srvctl_singleton_service_count=" singleton
      print "srvctl_uniform_service_count=" uniform
      print "srvctl_ac_service_count=" ac
      print "srvctl_tac_service_count=" tac
      print "srvctl_fan_notification_service_count=" fan
      print "srvctl_commit_outcome_service_count=" commit
      print "srvctl_runtime_load_balancing_service_count=" rlb
      print "srvctl_drain_timeout_service_count=" drain
      print "srvctl_session_state_consistency_service_count=" session_state
      print "srvctl_failover_restore_service_count=" failover_restore
    }
  ' "$output_file" >"$summary_file" 2>/dev/null || true

  while IFS='=' read -r key value; do
    [[ -n "$key" ]] || continue
    MAA_EVIDENCE["$key"]="${value:-0}"
  done <"$summary_file"

  maa_promote_count_from_srvctl "ac_service_count" "srvctl_ac_service_count"
  maa_promote_count_from_srvctl "tac_service_count" "srvctl_tac_service_count"
  maa_promote_count_from_srvctl "application_continuity_service_count" "srvctl_ac_service_count" "srvctl_tac_service_count"
  maa_promote_count_from_srvctl "commit_outcome_service_count" "srvctl_commit_outcome_service_count"
  maa_promote_count_from_srvctl "fan_notification_service_count" "srvctl_fan_notification_service_count"
  maa_promote_count_from_srvctl "runtime_load_balancing_service_count" "srvctl_runtime_load_balancing_service_count"
  maa_promote_count_from_srvctl "drain_timeout_service_count" "srvctl_drain_timeout_service_count"
  maa_promote_count_from_srvctl "session_state_consistency_service_count" "srvctl_session_state_consistency_service_count"
  maa_promote_count_from_srvctl "failover_restore_service_count" "srvctl_failover_restore_service_count"
}

maa_observer_csv_add_unique() {
  local csv="$1"
  local value="$2"

  value="$(strip_config_quotes "$value")"
  value="${value%%[[:space:]](*}"
  value="${value%%[[:space:]]-*}"
  value="$(trim_value "$value")"
  [[ -n "$value" ]] || printf "%s" "$csv"
  [[ -n "$value" ]] || return "$SUCCESS"
  [[ "$value" == "(none)" || "$value" == "none" || "$value" == "UNKNOWN" ]] && {
    printf "%s" "$csv"
    return "$SUCCESS"
  }

  case ",${csv}," in
    *,"${value}",*) printf "%s" "$csv" ;;
    *)
      if [[ -n "$csv" ]]; then
        printf "%s,%s" "$csv" "$value"
      else
        printf "%s" "$value"
      fi
      ;;
  esac
}

maa_count_csv_values() {
  local csv="$1"
  local old_ifs count=0 item
  [[ -n "$csv" ]] || {
    printf "0"
    return "$SUCCESS"
  }
  old_ifs="$IFS"
  IFS=','
  for item in $csv; do
    item="$(trim_value "$item")"
    [[ -n "$item" ]] && count=$((count + 1))
  done
  IFS="$old_ifs"
  printf "%s" "$count"
}

maa_reset_fsfo_observer_evidence() {
  MAA_EVIDENCE["dgmgrl_available"]="NO"
  MAA_EVIDENCE["dgmgrl_fsfo_status"]="UNAVAILABLE"
  MAA_EVIDENCE["dgmgrl_fsfo_evidence_file"]="UNAVAILABLE"
  MAA_EVIDENCE["dgmgrl_bin"]="UNAVAILABLE"
  MAA_EVIDENCE["dgmgrl_fsfo_state"]="UNKNOWN"
  MAA_EVIDENCE["fsfo_active_observer"]="UNKNOWN"
  MAA_EVIDENCE["fsfo_observer_names"]="NONE"
  MAA_EVIDENCE["fsfo_observer_count"]="0"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts"]="NONE"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts_configured"]="NO"
}

parse_maa_dgmgrl_fsfo_evidence() {
  local output_file="$1"
  local line normalized lower value observer_names="" active_observer=""
  local observer_count=0 in_observers=0 preferred_lines="" preferred_configured="NO"
  local preferred_entry preferred_value
  local observer_list_re='^"?([^"[:space:]]+)"?[[:space:]]*[-(]'

  [[ -f "$output_file" ]] || return "$SUCCESS"

  while IFS= read -r line; do
    line="${line//$'\r'/}"
    normalized="$(trim_value "$line")"
    if [[ -z "$normalized" ]]; then
      in_observers=0
      continue
    fi

    if [[ "$normalized" =~ ^Fast-Start[[:space:]]+Failover:[[:space:]]*(.*)$ ]]; then
      MAA_EVIDENCE["dgmgrl_fsfo_state"]="$(trim_value "${BASH_REMATCH[1]}")"
      continue
    fi

    if [[ "$normalized" =~ ^Observers:[[:space:]]*$ ]]; then
      in_observers=1
      continue
    fi

    if [[ "$normalized" =~ ^Observer:[[:space:]]*(.*)$ ]]; then
      value="$(strip_config_quotes "${BASH_REMATCH[1]}")"
      value="$(trim_value "$value")"
      if [[ -n "$value" && "$value" != "(none)" && "$value" != "NONE" ]]; then
        active_observer="$value"
        observer_names="$(maa_observer_csv_add_unique "$observer_names" "$value")"
      fi
      continue
    fi

    if [[ "$in_observers" -eq 1 && "$normalized" =~ $observer_list_re ]]; then
      value="${BASH_REMATCH[1]}"
      observer_names="$(maa_observer_csv_add_unique "$observer_names" "$value")"
      if [[ "$normalized" =~ [Mm]aster|[Aa]ctive ]] && [[ -z "$active_observer" ]]; then
        active_observer="$(strip_config_quotes "$value")"
      fi
      continue
    fi

    if [[ "$normalized" =~ Preferred[[:space:]_]*Observer[[:space:]_]*Hosts ]]; then
      preferred_entry="$normalized"
      if [[ "$normalized" == *"="* ]]; then
        preferred_value="$(strip_config_quotes "${normalized#*=}")"
        preferred_value="$(trim_value "$preferred_value")"
        [[ -n "$preferred_value" ]] || preferred_value="EMPTY"
        preferred_entry="$preferred_value"
      fi
      if [[ -z "$preferred_lines" ]]; then
        preferred_lines="$preferred_entry"
      elif [[ "; ${preferred_lines}; " != *"; ${preferred_entry}; "* ]]; then
        preferred_lines="${preferred_lines}; ${preferred_entry}"
      fi
      lower="$(printf "%s" "$normalized" | tr '[:upper:]' '[:lower:]')"
      if [[ ! "$lower" =~ "''" &&
            ! "$lower" =~ "\(none\)" &&
            ! "$lower" =~ "not set" &&
            ! "$lower" =~ "null" &&
            ! "$lower" =~ "unknown" &&
            ! "$lower" =~ =[[:space:]]*$ &&
            ! "$lower" =~ :[[:space:]]*$ ]]; then
        preferred_configured="YES"
      fi
      continue
    fi
  done <"$output_file"

  observer_count="$(maa_count_csv_values "$observer_names")"
  MAA_EVIDENCE["fsfo_active_observer"]="${active_observer:-UNKNOWN}"
  MAA_EVIDENCE["fsfo_observer_names"]="${observer_names:-NONE}"
  MAA_EVIDENCE["fsfo_observer_count"]="$observer_count"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts"]="${preferred_lines:-NONE}"
  MAA_EVIDENCE["fsfo_preferred_observer_hosts_configured"]="$preferred_configured"
}

collect_maa_dgmgrl_fsfo_evidence() {
  local output_file="$1"
  local status target current_db target_db dgmgrl_bin

  maa_reset_fsfo_observer_evidence
  MAA_EVIDENCE["dgmgrl_fsfo_evidence_file"]="$output_file"

  dgmgrl_bin="$(find_dgmgrl_bin)"
  if [[ -z "$dgmgrl_bin" || ! -x "$dgmgrl_bin" ]]; then
    printf "dgmgrl not found in ORACLE_HOME/bin or PATH.\n" >"$output_file" || true
    return "$SUCCESS"
  fi

  MAA_EVIDENCE["dgmgrl_available"]="YES"
  MAA_EVIDENCE["dgmgrl_bin"]="$dgmgrl_bin"
  current_db="${DB_UNIQUE_NAME:-$(maa_value db_unique_name "")}"
  target="$(maa_value fsfo_target NONE)"
  case "$target" in
    NONE|UNKNOWN|"") target_db="" ;;
    *) target_db="$target" ;;
  esac

  {
    printf 'show configuration verbose;\n'
    printf 'show fast_start failover;\n'
    if [[ -n "$current_db" ]]; then
      printf 'show database verbose "%s";\n' "$current_db"
    fi
    if [[ -n "$target_db" && "$target_db" != "$current_db" ]]; then
      printf 'show database verbose "%s";\n' "$target_db"
    fi
    printf 'exit\n'
  } | "$dgmgrl_bin" -silent / >"$output_file" 2>&1
  status=$?

  if [[ "$status" -eq 0 ]]; then
    MAA_EVIDENCE["dgmgrl_fsfo_status"]="OK"
  else
    MAA_EVIDENCE["dgmgrl_fsfo_status"]="ERROR"
    printf "\n[dgmgrl exited with status %s]\n" "$status" >>"$output_file" || true
  fi

  parse_maa_dgmgrl_fsfo_evidence "$output_file"
  return "$SUCCESS"
}

append_service_awareness_sections() {
  local report_file="$1"
  local dg_detected=0
  local adg_standby=0
  local ac_count tac_count replay_gap user_services role_services
  local fan_count rlb_count drain_count commit_count state_count restore_count
  local dml_redirect fsfo_status fsfo_observer db_role open_mode
  local fsfo_observer_count fsfo_observer_names fsfo_active_observer
  local fsfo_pref_hosts fsfo_pref_configured dgmgrl_fsfo_status dgmgrl_available
  local fsfo_enabled=0

  db_role="$(maa_value db_role UNKNOWN)"
  open_mode="$(maa_value open_mode UNKNOWN)"

  if [[ "$db_role" != "PRIMARY" && "$db_role" != "UNKNOWN" ]] || maa_positive remote_standby_dest_count; then
    dg_detected=1
  fi
  if [[ "$db_role" == *"STANDBY"* && "$open_mode" == *"READ ONLY WITH APPLY"* ]]; then
    adg_standby=1
  fi

  ac_count="$(maa_value ac_service_count "$(maa_value application_continuity_service_count 0)")"
  tac_count="$(maa_value tac_service_count 0)"
  replay_gap="$(maa_value service_without_ac_tac_count UNKNOWN)"
  user_services="$(maa_value service_user_count UNKNOWN)"
  role_services="$(maa_value srvctl_role_based_service_count UNKNOWN)"
  fan_count="$(maa_value fan_notification_service_count 0)"
  rlb_count="$(maa_value runtime_load_balancing_service_count 0)"
  drain_count="$(maa_value drain_timeout_service_count 0)"
  commit_count="$(maa_value commit_outcome_service_count 0)"
  state_count="$(maa_value session_state_consistency_service_count 0)"
  restore_count="$(maa_value failover_restore_service_count 0)"
  dml_redirect="$(maa_value adg_redirect_dml UNAVAILABLE)"
  fsfo_status="$(maa_value fsfo_status UNKNOWN)"
  fsfo_observer="$(maa_value fsfo_observer_present UNKNOWN)"
  fsfo_observer_count="$(maa_value fsfo_observer_count 0)"
  fsfo_observer_names="$(maa_value fsfo_observer_names NONE)"
  fsfo_active_observer="$(maa_value fsfo_active_observer UNKNOWN)"
  fsfo_pref_hosts="$(maa_value fsfo_preferred_observer_hosts NONE)"
  fsfo_pref_configured="$(maa_value fsfo_preferred_observer_hosts_configured NO)"
  dgmgrl_fsfo_status="$(maa_value dgmgrl_fsfo_status UNAVAILABLE)"
  dgmgrl_available="$(maa_value dgmgrl_available NO)"
  if [[ "$fsfo_status" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED ]] ||
     [[ "$fsfo_observer" == "YES" ]] ||
     [[ "$(maa_value dgmgrl_fsfo_state UNKNOWN)" =~ Enabled|enabled ]]; then
    fsfo_enabled=1
  fi

  append_report_section "$report_file" "Application Continuity, TAC, FSFO, DML Redirection, And Services Review"
  {
    printf '| Area | Evidence |\n'
    printf '| --- | --- |\n'
    printf '| SQL service dictionary | Source `%s`, services `%s`, application services `%s`, PDB services `%s` |\n' \
      "$(md_escape "$(maa_value service_attribute_source UNKNOWN)")" \
      "$(md_escape "$(maa_value service_total_count UNKNOWN)")" \
      "$(md_escape "$user_services")" \
      "$(md_escape "$(maa_value pdb_service_count UNKNOWN)")"
    printf '| Application Continuity / TAC | AC `%s`, TAC `%s`, Commit Outcome `%s`, missing AC/TAC `%s` |\n' \
      "$(md_escape "$ac_count")" "$(md_escape "$tac_count")" \
      "$(md_escape "$commit_count")" "$(md_escape "$replay_gap")"
    printf '| Client HA service attributes | FAN/AQ `%s`, RLB goals `%s`, drain timeout `%s`, session state consistency `%s`, failover restore `%s` |\n' \
      "$(md_escape "$fan_count")" "$(md_escape "$rlb_count")" \
      "$(md_escape "$drain_count")" "$(md_escape "$state_count")" "$(md_escape "$restore_count")"
    printf '| Data Guard / FSFO | DG detected `%s`, FSFO status `%s`, FSFO target `%s`, observer `%s`, threshold `%s` |\n' \
      "$(md_escape "$dg_detected")" "$(md_escape "$fsfo_status")" \
      "$(md_escape "$(maa_value fsfo_target NONE)")" "$(md_escape "$fsfo_observer")" \
      "$(md_escape "$(maa_value fsfo_threshold UNKNOWN)")"
    printf '| FSFO observer best-practice evidence | DGMGRL `%s/%s` from `%s`, active observer `%s`, observer count `%s`, observers `%s`, PreferredObserverHosts `%s` |\n' \
      "$(md_escape "$dgmgrl_available")" "$(md_escape "$dgmgrl_fsfo_status")" \
      "$(md_escape "$(maa_value dgmgrl_bin UNAVAILABLE)")" \
      "$(md_escape "$fsfo_active_observer")" "$(md_escape "$fsfo_observer_count")" \
      "$(md_escape "$fsfo_observer_names")" "$(md_escape "$fsfo_pref_configured")"
    printf '| Active Data Guard DML redirection | adg_redirect_dml `%s`, ADG standby context `%s` |\n' \
      "$(md_escape "$dml_redirect")" "$(md_escape "$adg_standby")"
    printf '| srvctl service metadata | srvctl `%s`, status `%s`, services `%s`, role-based `%s`, primary-role `%s`, standby-role `%s`, automatic `%s` |\n' \
      "$(md_escape "$(maa_value srvctl_available NO)")" \
      "$(md_escape "$(maa_value srvctl_service_status UNAVAILABLE)")" \
      "$(md_escape "$(maa_value srvctl_service_count UNKNOWN)")" \
      "$(md_escape "$role_services")" \
      "$(md_escape "$(maa_value srvctl_primary_role_service_count UNKNOWN)")" \
      "$(md_escape "$(maa_value srvctl_standby_role_service_count UNKNOWN)")" \
      "$(md_escape "$(maa_value srvctl_automatic_service_count UNKNOWN)")"
  } >>"$report_file"

  append_report_section "$report_file" "Service Best-Practice Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$user_services" =~ ^[0-9]+$ && "$user_services" -eq 0 ]]; then
    maa_append_check "$report_file" "INFO" "Services" "Application services visible" "application_services=${user_services}" "Create dedicated application services instead of relying on default database services."
  elif [[ "$user_services" =~ ^[0-9]+$ ]]; then
    maa_append_check "$report_file" "OK" "Services" "Application services visible" "application_services=${user_services}" "Keep services workload-specific so HA, DR, and maintenance policies can differ by application."
  else
    maa_append_check "$report_file" "INFO" "Services" "Application services visible" "application_services=${user_services}" "Service dictionary columns could not be fully inspected on this release/session."
  fi

  if [[ "$tac_count" =~ ^[0-9]+$ && "$tac_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Transparent Application Continuity services" "tac_services=${tac_count}" "Validate request replay with planned relocation, instance abort, and application smoke tests."
  elif [[ "$ac_count" =~ ^[0-9]+$ && "$ac_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Application Continuity services" "ac_services=${ac_count}, tac_services=${tac_count}" "Consider TAC where supported; confirm Transaction Guard, replay boundaries, and driver settings."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Replay-capable services" "ac_services=${ac_count}, tac_services=${tac_count}" "For user-facing services, evaluate TAC or AC with FAN/ONS and compatible drivers before HA drills."
  fi

  if [[ "$commit_count" =~ ^[0-9]+$ && "$commit_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Commit Outcome / Transaction Guard" "commit_outcome_services=${commit_count}" "Keep retention aligned with application replay windows and failure detection."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Commit Outcome / Transaction Guard" "commit_outcome_services=${commit_count}" "Enable Commit Outcome for AC/TAC candidate services where the application is replay-safe."
  fi

  if [[ "$fan_count" =~ ^[0-9]+$ && "$fan_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Client HA" "FAN/AQ notification services" "fan_services=${fan_count}" "Confirm ONS/FAN delivery with client pools during RAC/Data Guard failover drills."
  else
    maa_append_check "$report_file" "WARN" "Client HA" "FAN/AQ notification services" "fan_services=${fan_count}" "Enable HA notifications for application services and validate client-side failover behavior."
  fi

  if [[ "$rlb_count" =~ ^[0-9]+$ && "$rlb_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Client HA" "Runtime/client load balancing goals" "rlb_services=${rlb_count}" "Validate service-time or throughput goals with connection pools and service relocation."
  else
    maa_append_check "$report_file" "INFO" "Client HA" "Runtime/client load balancing goals" "rlb_services=${rlb_count}" "Define CLB/RLB goals for services that need predictable RAC load balancing."
  fi

  if [[ "$drain_count" =~ ^[0-9]+$ && "$drain_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Planned maintenance" "Service drain timeout" "drain_timeout_services=${drain_count}" "Use drain timeout and stop options during rolling maintenance and service relocation drills."
  else
    maa_append_check "$report_file" "INFO" "Planned maintenance" "Service drain timeout" "drain_timeout_services=${drain_count}" "Set drain timeout for services that need graceful planned maintenance."
  fi

  if [[ "$state_count" =~ ^[0-9]+$ && "$state_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Session state consistency" "session_state_services=${state_count}" "Validate whether dynamic or auto session state handling matches application replay assumptions."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Session state consistency" "session_state_services=${state_count}" "Review session-state consistency before enabling AC/TAC for stateful applications."
  fi

  if [[ "$restore_count" =~ ^[0-9]+$ && "$restore_count" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "AC/TAC" "Failover restore" "failover_restore_services=${restore_count}" "Test restored session state with planned and unplanned outages."
  else
    maa_append_check "$report_file" "INFO" "AC/TAC" "Failover restore" "failover_restore_services=${restore_count}" "For TAC/AC candidates, review failover restore behavior with the application team."
  fi

  if [[ "$dg_detected" -eq 1 ]]; then
    if [[ "$role_services" =~ ^[0-9]+$ && "$role_services" -gt 0 ]]; then
      maa_append_check "$report_file" "OK" "Data Guard services" "Role-based services" "role_based_services=${role_services}, primary=$(maa_value srvctl_primary_role_service_count UNKNOWN), standby=$(maa_value srvctl_standby_role_service_count UNKNOWN)" "Keep primary write services and ADG read-only services role-scoped; validate after switchover and failover."
    elif [[ "$(maa_value srvctl_available NO)" == "YES" ]]; then
      maa_append_check "$report_file" "GAP" "Data Guard services" "Role-based services" "role_based_services=${role_services}" "Configure srvctl role-based services for PRIMARY and PHYSICAL_STANDBY/ADG workloads before DG/ADG drills."
    else
      maa_append_check "$report_file" "INFO" "Data Guard services" "Role-based services" "srvctl_available=$(maa_value srvctl_available NO)" "Run the review on a GI-managed host or provide srvctl evidence to validate role-based services."
    fi
  else
    maa_append_check "$report_file" "INFO" "Data Guard services" "Role-based services" "dg_detected=0" "Role-based services become critical once Data Guard or Active Data Guard is configured."
  fi

  if [[ "$dg_detected" -eq 1 ]]; then
    if [[ "$fsfo_enabled" -eq 1 ]]; then
      maa_append_check "$report_file" "OK" "FSFO" "Fast-Start Failover awareness" "fsfo=${fsfo_status}, observer=${fsfo_observer}, threshold=$(maa_value fsfo_threshold UNKNOWN)" "Validate observer location, failover threshold, target, reinstate/failback runbook, and application service movement."
    else
      maa_append_check "$report_file" "INFO" "FSFO" "Fast-Start Failover awareness" "fsfo=${fsfo_status}, observer=${fsfo_observer}" "For low RTO Data Guard designs, evaluate FSFO and rehearse observer failure/failback handling."
    fi
  else
    maa_append_check "$report_file" "INFO" "FSFO" "Fast-Start Failover awareness" "dg_detected=0" "FSFO applies after a broker-managed Data Guard configuration is in place."
  fi

  if [[ "$dg_detected" -eq 1 && "$fsfo_enabled" -eq 1 ]]; then
    if [[ "$fsfo_observer" == "YES" || "$fsfo_active_observer" != "UNKNOWN" || ( "$fsfo_observer_count" =~ ^[0-9]+$ && "$fsfo_observer_count" -gt 0 ) ]]; then
      maa_append_check "$report_file" "OK" "FSFO observer" "Active observer present" "observer_present=${fsfo_observer}, active=${fsfo_active_observer}, count=${fsfo_observer_count}" "Keep the active observer on an external site when possible; if no external site exists, run it with the primary site and keep a secondary-site observer ready after role transition."
    else
      maa_append_check "$report_file" "GAP" "FSFO observer" "Active observer present" "observer_present=${fsfo_observer}, active=${fsfo_active_observer}, count=${fsfo_observer_count}" "Start an FSFO observer before relying on automatic failover."
    fi

    if [[ "$fsfo_observer_count" =~ ^[0-9]+$ && "$fsfo_observer_count" -ge 2 ]]; then
      maa_append_check "$report_file" "OK" "FSFO observer" "Multiple observers configured" "observers=${fsfo_observer_names}" "Use multiple observers for observer high availability and validate master/backup observer behavior."
    else
      maa_append_check "$report_file" "WARN" "FSFO observer" "Multiple observers configured" "observer_count=${fsfo_observer_count}, observers=${fsfo_observer_names}" "Configure at least two observers when possible so observer availability does not become a single operational dependency."
    fi

    if [[ "$fsfo_pref_configured" == "YES" ]]; then
      maa_append_check "$report_file" "OK" "FSFO observer" "PreferredObserverHosts configured" "preferred_hosts=${fsfo_pref_hosts}" "Use PreferredObserverHosts to prefer external/primary-site observer hosts and avoid running the observer with the standby database."
    else
      maa_append_check "$report_file" "WARN" "FSFO observer" "PreferredObserverHosts configured" "preferred_hosts=${fsfo_pref_hosts}, dgmgrl=${dgmgrl_available}/${dgmgrl_fsfo_status}" "Configure PreferredObserverHosts on Data Guard members so the active observer is not placed with the standby database after role transitions."
    fi

    if [[ "$fsfo_pref_configured" == "YES" ]]; then
      maa_append_check "$report_file" "INFO" "FSFO observer" "Observer site placement" "active=${fsfo_active_observer}, preferred_hosts_configured=YES" "Confirm the preferred-host list maps to an external site first, primary site second, and does not prefer the standby database site."
    else
      maa_append_check "$report_file" "WARN" "FSFO observer" "Observer site placement" "active=${fsfo_active_observer}, preferred_hosts_configured=NO" "CrashSimulator cannot prove external/primary/standby site placement without PreferredObserverHosts or site metadata; never intentionally place the active observer with the standby database."
    fi
  elif [[ "$dg_detected" -eq 1 ]]; then
    maa_append_check "$report_file" "INFO" "FSFO observer" "Observer best-practice placement" "fsfo_enabled=${fsfo_enabled}, observer=${fsfo_observer}" "When FSFO is enabled, prefer external-site observers, avoid standby-site placement, configure multiple observers, and set PreferredObserverHosts."
  else
    maa_append_check "$report_file" "INFO" "FSFO observer" "Observer best-practice placement" "dg_detected=0" "Observer placement checks become applicable after Data Guard Broker and FSFO are configured."
  fi

  if [[ "$adg_standby" -eq 1 ]]; then
    if [[ "$(printf "%s" "$dml_redirect" | tr '[:lower:]' '[:upper:]')" =~ TRUE|YES|AUTO ]]; then
      maa_append_check "$report_file" "OK" "ADG DML redirection" "DML redirection configuration" "adg_redirect_dml=${dml_redirect}" "Validate redirected DML latency, application semantics, and primary impact before exposing ADG write-capable sessions."
    else
      maa_append_check "$report_file" "INFO" "ADG DML redirection" "DML redirection configuration" "adg_redirect_dml=${dml_redirect}" "Enable only for approved ADG services that require occasional DML; keep read-only services strictly read-only by default."
    fi
  elif [[ "$dg_detected" -eq 1 ]]; then
    maa_append_check "$report_file" "INFO" "ADG DML redirection" "DML redirection configuration" "role=${db_role}, open_mode=${open_mode}, adg_redirect_dml=${dml_redirect}" "Run this review on an ADG standby to confirm DML redirection posture for standby read services."
  else
    maa_append_check "$report_file" "INFO" "ADG DML redirection" "DML redirection configuration" "adg_redirect_dml=${dml_redirect}" "DML redirection is relevant for Active Data Guard standby services."
  fi
}

maa_sla_hint() {
  local local_rto local_rpo dr_rto dr_rpo planned_rto combined
  local_rto="$(printf "%s" "$MAA_LOCAL_RTO" | tr '[:upper:]' '[:lower:]')"
  local_rpo="$(printf "%s" "$MAA_LOCAL_RPO" | tr '[:upper:]' '[:lower:]')"
  dr_rto="$(printf "%s" "$MAA_DR_RTO" | tr '[:upper:]' '[:lower:]')"
  dr_rpo="$(printf "%s" "$MAA_DR_RPO" | tr '[:upper:]' '[:lower:]')"
  planned_rto="$(printf "%s" "$MAA_PLANNED_RTO" | tr '[:upper:]' '[:lower:]')"
  combined="${local_rto} ${local_rpo} ${dr_rto} ${dr_rpo} ${planned_rto}"

  if [[ -z "${combined// }" ]]; then
    printf "No SLA objectives supplied yet. Provide CRASHSIM_MAA_* values or --maa-* options in a future run to compare target objectives against detected posture."
  elif [[ "$combined" =~ zero|near.zero|seconds|sub.minute|subminute ]]; then
    printf "Supplied objectives appear very aggressive. Expect at least Gold for site protection, and Platinum/Diamond patterns when application-visible downtime must approach zero."
  elif [[ "$combined" =~ minute|min|hour ]]; then
    printf "Supplied objectives suggest Silver may cover local instance/server events, while Gold is normally required for low-RTO/low-RPO disaster recovery."
  else
    printf "Supplied objectives may be compatible with Bronze or Silver if backup/restore testing proves the required recovery windows. Validate with timed CrashSimulator drills."
  fi
}

maa_normalized_yes_no() {
  local raw="$1"
  raw="$(printf "%s" "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    y|yes|true|1|required|enabled|enable) printf "yes" ;;
    n|no|false|0|not|required|disabled|disable|none) printf "no" ;;
    *) printf "unknown" ;;
  esac
}

maa_duration_le() {
  local value="$1"
  local threshold="$2"
  local seconds
  seconds="$(duration_to_seconds "$value" 2>/dev/null)" || return "$FAIL"
  [[ "$seconds" -le "$threshold" ]]
}

maa_tier_rank() {
  case "$1" in
    Below\ Bronze) printf "0" ;;
    Bronze) printf "1" ;;
    Silver) printf "2" ;;
    Gold) printf "3" ;;
    Platinum) printf "4" ;;
    Diamond) printf "5" ;;
    *) printf "0" ;;
  esac
}

maa_rank_tier() {
  case "$1" in
    5) printf "Diamond" ;;
    4) printf "Platinum" ;;
    3) printf "Gold" ;;
    2) printf "Silver" ;;
    1) printf "Bronze" ;;
    *) printf "Below Bronze" ;;
  esac
}

maa_latest_manifest_for_ids() {
  local ids_csv="$1"
  local manifest scenario_id
  while IFS= read -r manifest; do
    scenario_id="$(awk -F= '$1=="scenario_id"{print $2; exit}' "$manifest" 2>/dev/null || true)"
    [[ -n "$scenario_id" ]] || continue
    case ",${ids_csv}," in
      *,"${scenario_id}",*) printf "%s\n" "$manifest"; return "$SUCCESS" ;;
    esac
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_*s*.manifest' 2>/dev/null | sort -r)
  return "$FAIL"
}

maa_target_tier_from_context() {
  local criticality local_ha dr_required auto_failover active_active platform
  local target="Unknown" reason="Business RTO/RPO and outage-class context is incomplete."
  local gaps=""

  criticality="$(printf "%s" "$MAA_CRITICALITY" | tr '[:upper:]' '[:lower:]')"
  local_ha="$(maa_normalized_yes_no "$MAA_LOCAL_HA_TARGET")"
  dr_required="$(maa_normalized_yes_no "$MAA_DR_REQUIRED")"
  auto_failover="$(maa_normalized_yes_no "$MAA_AUTOMATIC_FAILOVER_REQUIRED")"
  active_active="$(maa_normalized_yes_no "$MAA_ACTIVE_ACTIVE_REQUIRED")"
  platform="$(printf "%s" "$MAA_PLATFORM_HINT" | tr '[:upper:]' '[:lower:]')"

  [[ -n "$MAA_CRITICALITY" ]] || gaps="${gaps}criticality; "
  [[ -n "$MAA_LOCAL_RTO" || -n "$MAA_DR_RTO" || -n "$MAA_PLANNED_RTO" ]] || gaps="${gaps}RTO objectives; "
  [[ -n "$MAA_LOCAL_RPO" || -n "$MAA_DR_RPO" || -n "$MAA_PLANNED_RPO" ]] || gaps="${gaps}RPO objectives; "
  [[ "$local_ha" != "unknown" ]] || gaps="${gaps}local HA target; "
  [[ "$dr_required" != "unknown" ]] || gaps="${gaps}DR requirement; "

  if [[ "$active_active" == "yes" ]] ||
     [[ "$criticality" =~ ultra|extreme ]] ||
     { maa_duration_le "$MAA_DR_RTO" 60 && maa_duration_le "$MAA_DR_RPO" 60; }; then
    target="Diamond"
    reason="Business context indicates active-active/extreme availability or very-low-seconds DR RTO/RPO."
  elif [[ "$platform" =~ exadata|engineered ]] &&
       { maa_duration_le "$MAA_PLANNED_RTO" 60 || maa_duration_le "$MAA_DR_RTO" 300; }; then
    target="Platinum"
    reason="Business context indicates near-zero interruption on an Exadata or engineered-platform strategy."
  elif [[ "$dr_required" == "yes" || "$auto_failover" == "yes" ]] ||
       maa_duration_le "$MAA_DR_RTO" 900 ||
       [[ "$(printf "%s" "$MAA_DR_RPO" | tr '[:upper:]' '[:lower:]')" =~ ^(zero|near-zero|near\ zero)$ ]]; then
    # Gold DR RTO threshold: low-minute DR (<= 15m) or zero/near-zero DR RPO
    # maps to Gold. A 15-minute DR RTO is still a Data Guard-class objective;
    # grading it below Gold understated the required architecture.
    target="Gold"
    reason="Business context indicates low-minute disaster recovery, strong RPO, or automatic failover."
  elif [[ "$local_ha" == "yes" ]] ||
       maa_duration_le "$MAA_LOCAL_RTO" 60 ||
       [[ "$criticality" =~ production|mission ]]; then
    target="Silver"
    reason="Business context indicates production-grade local HA or sub-minute local recovery."
  elif [[ -n "$MAA_LOCAL_RTO$MAA_DR_RTO$MAA_PLANNED_RTO$MAA_LOCAL_RPO$MAA_DR_RPO$MAA_PLANNED_RPO$MAA_CRITICALITY" ]]; then
    target="Bronze"
    reason="Supplied context appears compatible with restart/restore-based recoverability."
  fi

  MAA_TARGET_LEVEL="$target"
  MAA_TARGET_REASON="$reason"
  MAA_TARGET_GAPS="${gaps%; }"
}

maa_compute_decision_model() {
  local db_role open_mode standby_scope platform version_major
  local capture_count apply_count app_continuity user_services role_services fan_count rlb_count drain_count
  local fsfo_status fsfo_observer observer_count dgmgrl_status backup_manifest
  local local_manifest dr_manifest app_manifest
  local candidate="Bronze" candidate_reason="Backup/restart posture only; no local HA, DR, or active-replication topology was confirmed."
  local evidenced_rank=0 evidenced_reason=""
  local dg_detected=0 local_ha_candidate=0 remote_dg_candidate=0

  maa_target_tier_from_context

  db_role="$(maa_value db_role UNKNOWN)"
  open_mode="$(maa_value open_mode UNKNOWN)"
  standby_scope="$(printf "%s" "${MAA_STANDBY_SCOPE:-unknown}" | tr '[:upper:]' '[:lower:]')"
  platform="$(printf "%s" "$MAA_PLATFORM_HINT $STORAGE_TYPE $(maa_value platform_name UNKNOWN)" | tr '[:upper:]' '[:lower:]')"
  version_major="$(maa_value version_major 0)"
  capture_count="$(maa_value capture_process_count 0)"
  apply_count="$(maa_value apply_process_count 0)"
  app_continuity="$(maa_value application_continuity_service_count 0)"
  user_services="$(maa_value service_user_count UNKNOWN)"
  role_services="$(maa_value srvctl_role_based_service_count UNKNOWN)"
  fan_count="$(maa_value fan_notification_service_count 0)"
  rlb_count="$(maa_value runtime_load_balancing_service_count 0)"
  drain_count="$(maa_value drain_timeout_service_count 0)"
  fsfo_status="$(maa_value fsfo_status UNKNOWN)"
  fsfo_observer="$(maa_value fsfo_observer_present UNKNOWN)"
  observer_count="$(maa_value fsfo_observer_count 0)"
  dgmgrl_status="$(maa_value dgmgrl_fsfo_status UNAVAILABLE)"

  if [[ "$db_role" != "PRIMARY" && "$db_role" != "UNKNOWN" ]] || maa_positive remote_standby_dest_count; then
    dg_detected=1
  fi
  if [[ "$CLUSTER_TYPE" =~ ^(RAC|RACONE|RACONENODE|RAC_ONE_NODE)$ ||
        "$(maa_value cluster_database FALSE)" == "TRUE" ||
        "$(maa_value instance_parallel NO)" == "YES" ]]; then
    local_ha_candidate=1
  fi
  if [[ "$dg_detected" -eq 1 && "$standby_scope" == "local" ]]; then
    local_ha_candidate=1
  fi
  if [[ "$dg_detected" -eq 1 && "$standby_scope" != "local" ]]; then
    remote_dg_candidate=1
  fi

  if [[ "$local_ha_candidate" -eq 1 ]]; then
    candidate="Silver"
    candidate_reason="RAC/RAC One Node or explicitly local Data Guard standby evidence indicates a Silver local-HA candidate."
  fi
  if [[ "$remote_dg_candidate" -eq 1 ]]; then
    candidate="Gold"
    candidate_reason="Data Guard/Active Data Guard or remote standby transport evidence indicates a Gold DR candidate."
  fi
  if [[ "$candidate" == "Gold" &&
        "$capture_count" =~ ^[0-9]+$ && "$apply_count" =~ ^[0-9]+$ &&
        ( "$capture_count" -gt 0 || "$apply_count" -gt 0 ) ]]; then
    candidate="Platinum"
    candidate_reason="Data Guard plus replication dictionary evidence indicates a Platinum candidate; GoldenGate/active-replication supportability still needs manual confirmation."
  fi
  if [[ "$candidate" == "Platinum" &&
        "$version_major" =~ ^[0-9]+$ && "$version_major" -ge 26 &&
        "$(maa_normalized_yes_no "$MAA_ACTIVE_ACTIVE_REQUIRED")" == "yes" &&
        "$platform" =~ exadata ]]; then
    candidate="Diamond"
    candidate_reason="26ai, Exadata/platform hint, and active-active requirement indicate a Diamond candidate; architecture and measured evidence require manual confirmation."
  fi

  MAA_CANDIDATE_LEVEL="$candidate"
  MAA_CANDIDATE_REASON="$candidate_reason"
  MAA_DG_DETECTED="$dg_detected"
  MAA_LOCAL_HA_CANDIDATE="$local_ha_candidate"
  MAA_REMOTE_DG_CANDIDATE="$remote_dg_candidate"

  MAA_SCORE_BUSINESS=0
  [[ -n "$MAA_LOCAL_RTO$MAA_LOCAL_RPO$MAA_DR_RTO$MAA_DR_RPO$MAA_PLANNED_RTO$MAA_PLANNED_RPO" ]] && MAA_SCORE_BUSINESS=2
  [[ -n "$MAA_CRITICALITY" && "$MAA_SCORE_BUSINESS" -gt 0 ]] && MAA_SCORE_BUSINESS=3
  [[ -n "$MAA_CRITICALITY" && -n "$MAA_LOCAL_RTO" && -n "$MAA_DR_RTO" && -n "$MAA_LOCAL_RPO" && -n "$MAA_DR_RPO" ]] && MAA_SCORE_BUSINESS=4

  MAA_SCORE_BACKUP=0
  [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]] && MAA_SCORE_BACKUP=1
  maa_positive recent_successful_backup_jobs_7d && MAA_SCORE_BACKUP=2
  if maa_positive recent_successful_backup_jobs_7d && maa_zero datafiles_without_backup_metadata &&
     maa_zero recover_file_count && maa_zero block_corruption_count; then
    MAA_SCORE_BACKUP=3
  fi
  backup_manifest="$(latest_completed_recovery_manifest 2>/dev/null || true)"
  [[ -n "$backup_manifest" && "$MAA_SCORE_BACKUP" -ge 3 ]] && MAA_SCORE_BACKUP=4

  MAA_SCORE_LOCAL_HA=0
  [[ "$local_ha_candidate" -eq 1 ]] && MAA_SCORE_LOCAL_HA=1
  [[ "$user_services" =~ ^[0-9]+$ && "$user_services" -gt 0 && "$MAA_SCORE_LOCAL_HA" -gt 0 ]] && MAA_SCORE_LOCAL_HA=2
  if [[ "$MAA_SCORE_LOCAL_HA" -gt 0 ]] &&
     { [[ "$role_services" =~ ^[0-9]+$ && "$role_services" -gt 0 ]] ||
       [[ "$fan_count" =~ ^[0-9]+$ && "$fan_count" -gt 0 ]] ||
       [[ "$rlb_count" =~ ^[0-9]+$ && "$rlb_count" -gt 0 ]] ||
       [[ "$drain_count" =~ ^[0-9]+$ && "$drain_count" -gt 0 ]]; }; then
    MAA_SCORE_LOCAL_HA=3
  fi
  local_manifest="$(maa_latest_manifest_for_ids "55,56,70,71" 2>/dev/null || true)"
  [[ -n "$local_manifest" && "$MAA_SCORE_LOCAL_HA" -ge 3 ]] && MAA_SCORE_LOCAL_HA=4

  MAA_SCORE_DR=0
  [[ "$dg_detected" -eq 1 ]] && MAA_SCORE_DR=1
  [[ "$dg_detected" -eq 1 && ( "$(maa_value valid_remote_standby_dest_count 0)" =~ ^[0-9]+$ || "$db_role" == *"STANDBY"* ) ]] && MAA_SCORE_DR=2
  if [[ "$dg_detected" -eq 1 ]] &&
     { [[ "$dgmgrl_status" == "OK" ]] ||
       [[ "$(maa_value dataguard_stats_count 0)" =~ ^[1-9][0-9]*$ ]] ||
       [[ "$role_services" =~ ^[0-9]+$ && "$role_services" -gt 0 ]]; }; then
    MAA_SCORE_DR=3
  fi
  dr_manifest="$(maa_latest_manifest_for_ids "50,51,52,54,66,67,68,69" 2>/dev/null || true)"
  [[ -n "$dr_manifest" && "$MAA_SCORE_DR" -ge 3 ]] && MAA_SCORE_DR=4
  if [[ "$MAA_SCORE_DR" -ge 3 &&
        ( "$fsfo_status" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED || "$fsfo_observer" == "YES" ) &&
        "$observer_count" =~ ^[0-9]+$ && "$observer_count" -gt 0 ]]; then
    MAA_SCORE_DR=4
  fi

  MAA_SCORE_APP=0
  [[ "$user_services" =~ ^[0-9]+$ && "$user_services" -gt 0 ]] && MAA_SCORE_APP=1
  if [[ "$fan_count" =~ ^[0-9]+$ && "$fan_count" -gt 0 ]] ||
     [[ "$rlb_count" =~ ^[0-9]+$ && "$rlb_count" -gt 0 ]] ||
     [[ "$drain_count" =~ ^[0-9]+$ && "$drain_count" -gt 0 ]]; then
    MAA_SCORE_APP=2
  fi
  [[ "$app_continuity" =~ ^[0-9]+$ && "$app_continuity" -gt 0 ]] && MAA_SCORE_APP=3
  app_manifest="$(maa_latest_manifest_for_ids "56,70,71,80" 2>/dev/null || true)"
  [[ -n "$app_manifest" && "$MAA_SCORE_APP" -ge 2 ]] && MAA_SCORE_APP=4

  MAA_SCORE_OPERATIONS=1
  [[ "$AUDIT_RETAIN" =~ ^(1|yes|true)$ ]] && MAA_SCORE_OPERATIONS=2
  [[ -n "$(find "$LOG_DIR" -maxdepth 1 -type f \( -name 'crashsim_scenario_lifecycle_*.md' -o -name 'crashsim_scenario_readiness_*.md' \) 2>/dev/null | head -n 1)" ]] && MAA_SCORE_OPERATIONS=3

  if [[ "$MAA_SCORE_BACKUP" -ge 3 ]]; then
    evidenced_rank=1
    evidenced_reason="Bronze evidenced: backup/recovery baseline is configured and no immediate recovery/corruption blockers were detected."
  else
    evidenced_rank=0
    evidenced_reason="Below Bronze: backup/recovery baseline lacks enough evidence for Bronze confirmation."
  fi
  if [[ "$evidenced_rank" -ge 1 && "$MAA_SCORE_LOCAL_HA" -ge 4 && "$MAA_SCORE_APP" -ge 3 ]]; then
    evidenced_rank=2
    evidenced_reason="Silver evidenced: Bronze plus local HA, application-service integration, and measured local-failure evidence were found."
  fi
  if [[ "$evidenced_rank" -ge 2 && "$MAA_SCORE_DR" -ge 4 && "$MAA_SCORE_APP" -ge 3 ]]; then
    evidenced_rank=3
    evidenced_reason="Gold evidenced: Silver plus Data Guard/ADG DR evidence, role/service integration, and measured DR/lag/failover evidence were found."
  fi
  if [[ "$evidenced_rank" -ge 3 && "$MAA_CANDIDATE_LEVEL" =~ Platinum|Diamond &&
        "$MAA_SCORE_APP" -ge 4 && "$MAA_SCORE_OPERATIONS" -ge 4 ]]; then
    evidenced_rank=4
    evidenced_reason="Platinum evidenced: Gold plus active-replication/platform and measured application-continuity evidence were found."
  fi
  if [[ "$evidenced_rank" -ge 4 && "$MAA_CANDIDATE_LEVEL" == "Diamond" &&
        "$MAA_SCORE_OPERATIONS" -ge 4 ]]; then
    evidenced_rank=5
    evidenced_reason="Diamond evidenced: extreme-availability candidate plus operational evidence was found; verify supportability manually."
  fi

  MAA_EVIDENCED_LEVEL="$(maa_rank_tier "$evidenced_rank")"
  MAA_EVIDENCED_REASON="$evidenced_reason"
  MAA_FIT_GAP_RANK=$(( $(maa_tier_rank "${MAA_TARGET_LEVEL:-Unknown}") - evidenced_rank ))
  if [[ "${MAA_TARGET_LEVEL:-Unknown}" == "Unknown" ]]; then
    MAA_FIT_GAP_SUMMARY="Target MAA level is unknown because business context is incomplete."
  elif [[ "$MAA_FIT_GAP_RANK" -le 0 ]]; then
    MAA_FIT_GAP_SUMMARY="Current evidenced level meets or exceeds the supplied target context."
  else
    MAA_FIT_GAP_SUMMARY="Current evidenced level is below the supplied target context by ${MAA_FIT_GAP_RANK} tier(s)."
  fi
}

score_clamp() {
  local value="$1"
  [[ "$value" =~ ^-?[0-9]+$ ]] || value=0
  (( value < 0 )) && value=0
  (( value > 100 )) && value=100
  printf "%s" "$value"
}

score_from_maturity() {
  local value="$1"
  [[ "$value" =~ ^[0-9]+$ ]] || value=0
  score_clamp $((value * 20))
}

score_level_gap_points() {
  local target="$1"
  local evidenced="$2"
  local gap
  if [[ "$target" == "Unknown" || -z "$target" ]]; then
    printf "50"
    return "$SUCCESS"
  fi
  gap=$(( $(maa_tier_rank "$target") - $(maa_tier_rank "$evidenced") ))
  if [[ "$gap" -le 0 ]]; then
    printf "100"
  else
    score_clamp $((100 - gap * 20))
  fi
}

resilience_score_level() {
  local score="$1"
  if [[ "$score" -ge 90 ]]; then
    printf "Excellent"
  elif [[ "$score" -ge 80 ]]; then
    printf "Strong"
  elif [[ "$score" -ge 70 ]]; then
    printf "Good"
  elif [[ "$score" -ge 55 ]]; then
    printf "Developing"
  elif [[ "$score" -ge 40 ]]; then
    printf "At Risk"
  else
    printf "Critical Gaps"
  fi
}

score_badge() {
  local score="$1"
  local label
  label="$(resilience_score_level "$score")"
  printf "%s/100 (%s)" "$score" "$label"
}

resilience_domain_append() {
  local report_file="$1"
  local domain="$2"
  local score="$3"
  local weight="$4"
  local evidence="$5"
  local recommendation="$6"
  local weighted
  weighted=$((score * weight))
  RESILIENCE_TOTAL_WEIGHT=$((RESILIENCE_TOTAL_WEIGHT + weight))
  RESILIENCE_WEIGHTED_SUM=$((RESILIENCE_WEIGHTED_SUM + weighted))
  printf '| %s | `%s` | `%s%%` | %s | %s |\n' \
    "$(md_escape "$domain")" \
    "$(md_escape "$(score_badge "$score")")" \
    "$weight" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

resilience_scenario_coverage_score() {
  local id total=0 automated=0 read_only=0 plan_only=0 placeholder=0 score
  for id in "${SCENARIO_IDS[@]}"; do
    total=$((total + 1))
    if supports_recovery_automation "$id" || supports_file_recovery_automation "$id"; then
      automated=$((automated + 1))
    fi
    case "$id" in
      53|64|65|69|78|80|81|82) read_only=$((read_only + 1)) ;;
      46|47|48|49|52|54|66|70|72) plan_only=$((plan_only + 1)) ;;
    esac
    [[ "${SCENARIO_HANDLER[$id]}" == "scenario_planned" ]] && placeholder=$((placeholder + 1))
  done
  if [[ "$total" -eq 0 ]]; then
    printf "0|registered=0"
    return "$SUCCESS"
  fi
  score=$(( (automated * 70 + read_only * 55 + plan_only * 35) / total ))
  (( placeholder > 0 )) && score=$((score - placeholder * 2))
  score="$(score_clamp "$score")"
  printf "%s|registered=%s, automated=%s, read_only=%s, plan_only=%s, placeholders=%s" \
    "$score" "$total" "$automated" "$read_only" "$plan_only" "$placeholder"
}

run_resilience_scorecard() {
  discover_environment
  ensure_sqlplus

  local report_file latest_file sql_file evidence_file srvctl_service_file dgmgrl_fsfo_file generated_at
  local backup_score rac_score security_score dr_score recoverability_score maa_score scenario_score app_score
  local scenario_evidence overall score_line backup_manifest rto_manifest rpo_manifest
  local encrypted wallet_not_open wallet_open tde_config log_mode force_logging recent_jobs missing_files failed_jobs
  local recover_files corrupt_rows flashback

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}.md"
  latest_file="${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
  sql_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}.evidence"
  srvctl_service_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}_srvctl_services.out"
  dgmgrl_fsfo_file="${LOG_DIR}/crashsim_resilience_scorecard_${RUN_ID}_dgmgrl_fsfo.out"

  write_maa_assessment_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Resilience scorecard SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"
  collect_srvctl_service_evidence "$srvctl_service_file"
  collect_maa_dgmgrl_fsfo_evidence "$dgmgrl_fsfo_file"
  maa_compute_decision_model

  log_mode="$(maa_value log_mode UNKNOWN)"
  force_logging="$(maa_value force_logging UNKNOWN)"
  recent_jobs="$(maa_value recent_successful_backup_jobs_7d 0)"
  missing_files="$(maa_value datafiles_without_backup_metadata 0)"
  failed_jobs="$(maa_value recent_failed_backup_jobs_7d 0)"
  recover_files="$(maa_value recover_file_count 0)"
  corrupt_rows=$(( $(maa_value block_corruption_count 0) + $(maa_value copy_corruption_count 0) + $(maa_value backup_corruption_count 0) ))
  flashback="$(maa_value flashback_on UNKNOWN)"
  wallet_open="$(maa_value tde_wallet_open_count 0)"
  wallet_not_open="$(maa_value tde_wallet_not_open_count 0)"
  encrypted="$(maa_value encrypted_tablespace_count 0)"
  tde_config="$(maa_value tde_configuration NONE)"

  backup_score=0
  [[ "$log_mode" == "ARCHIVELOG" ]] && backup_score=$((backup_score + 20))
  [[ "$recent_jobs" =~ ^[0-9]+$ && "$recent_jobs" -gt 0 ]] && backup_score=$((backup_score + 25))
  [[ "$missing_files" =~ ^[0-9]+$ && "$missing_files" -eq 0 ]] && backup_score=$((backup_score + 25))
  [[ "$failed_jobs" =~ ^[0-9]+$ && "$failed_jobs" -eq 0 ]] && backup_score=$((backup_score + 15))
  backup_manifest="$(latest_completed_recovery_manifest 2>/dev/null || true)"
  [[ -n "$backup_manifest" ]] && backup_score=$((backup_score + 15))
  backup_score="$(score_clamp "$backup_score")"

  rac_score="$(score_from_maturity "${MAA_SCORE_LOCAL_HA:-0}")"
  app_score="$(score_from_maturity "${MAA_SCORE_APP:-0}")"
  dr_score="$(score_from_maturity "${MAA_SCORE_DR:-0}")"

  security_score=20
  [[ "$force_logging" == "YES" ]] && security_score=$((security_score + 20))
  [[ "$tde_config" != "NONE" && "$tde_config" != "UNKNOWN" ]] && security_score=$((security_score + 15))
  [[ "$wallet_not_open" =~ ^[0-9]+$ && "$wallet_not_open" -eq 0 ]] && security_score=$((security_score + 20))
  [[ "$encrypted" =~ ^[0-9]+$ && "$encrypted" -gt 0 ]] && security_score=$((security_score + 15))
  [[ "$wallet_open" =~ ^[0-9]+$ && "$wallet_open" -gt 0 ]] && security_score=$((security_score + 10))
  security_score="$(score_clamp "$security_score")"

  recoverability_score=0
  [[ "$log_mode" == "ARCHIVELOG" ]] && recoverability_score=$((recoverability_score + 20))
  [[ "$flashback" == "YES" ]] && recoverability_score=$((recoverability_score + 15))
  [[ "$recover_files" =~ ^[0-9]+$ && "$recover_files" -eq 0 ]] && recoverability_score=$((recoverability_score + 20))
  [[ "$corrupt_rows" -eq 0 ]] && recoverability_score=$((recoverability_score + 20))
  [[ -n "$backup_manifest" ]] && recoverability_score=$((recoverability_score + 15))
  rto_manifest="$(maa_latest_manifest_for_ids "64" 2>/dev/null || true)"
  rpo_manifest="$(maa_latest_manifest_for_ids "65" 2>/dev/null || true)"
  [[ -n "$rto_manifest" || -n "$rpo_manifest" ]] && recoverability_score=$((recoverability_score + 10))
  recoverability_score="$(score_clamp "$recoverability_score")"

  maa_score="$(score_level_gap_points "${MAA_TARGET_LEVEL:-Unknown}" "${MAA_EVIDENCED_LEVEL:-Below Bronze}")"
  if [[ "${MAA_TARGET_LEVEL:-Unknown}" == "Unknown" ]]; then
    maa_score=$((maa_score - 15))
  fi
  maa_score="$(score_clamp "$maa_score")"

  score_line="$(resilience_scenario_coverage_score)"
  scenario_score="${score_line%%|*}"
  scenario_evidence="${score_line#*|}"

  RESILIENCE_TOTAL_WEIGHT=0
  RESILIENCE_WEIGHTED_SUM=0

  {
    printf "# CrashSimulator Resilience Scorecard\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- Cluster/storage: `%s` / `%s`\n' "$CLUSTER_TYPE" "$STORAGE_TYPE"
    printf -- '- Target MAA level: `%s`\n' "${MAA_TARGET_LEVEL:-Unknown}"
    printf -- '- Candidate MAA level: `%s`\n' "${MAA_CANDIDATE_LEVEL:-Unknown}"
    printf -- '- Current evidenced MAA level: `%s`\n' "${MAA_EVIDENCED_LEVEL:-Unknown}"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This scorecard is an evidence-weighted management view. Scores are planning indicators, not Oracle certification or SLA guarantees. Re-run after topology changes, backups, recovery drills, switchover/failover tests, and scenario validations.\n\n"

    printf "## Domain Scores\n\n"
    printf '| Domain | Score | Weight | Evidence | Recommendation |\n'
    printf '| --- | ---: | ---: | --- | --- |\n'
  } >"$report_file" || die "Unable to write resilience scorecard: $report_file"

  resilience_domain_append "$report_file" "Backup" "$backup_score" 15 "ARCHIVELOG=${log_mode}, jobs_7d=${recent_jobs}, failed_7d=${failed_jobs}, missing_datafiles=${missing_files}, recovery_manifest=$([[ -n "$backup_manifest" ]] && printf yes || printf no)" "Keep backup cadence aligned to RPO and prove restore time with timed recovery drills."
  resilience_domain_append "$report_file" "RAC / Local HA" "$rac_score" 12 "candidate=${MAA_LOCAL_HA_CANDIDATE:-0}, score=${MAA_SCORE_LOCAL_HA:-0}/5, services=$(maa_value service_user_count UNKNOWN), FAN=$(maa_value fan_notification_service_count UNKNOWN), local_drill=$([[ -n "$(maa_latest_manifest_for_ids "55,56,70,71" 2>/dev/null || true)" ]] && printf yes || printf no)" "Use services, FAN/ONS, drain, AC/TAC where applicable, and measure local failure drills."
  resilience_domain_append "$report_file" "Security" "$security_score" 10 "force_logging=${force_logging}, tde_config=${tde_config}, encrypted_tbs=${encrypted}, wallet_open=${wallet_open}, wallet_not_open=${wallet_not_open}" "Validate TDE/wallet backup posture and add DBSAT/Data Safe evidence for a fuller security score."
  resilience_domain_append "$report_file" "DR / Data Guard" "$dr_score" 15 "dg_detected=${MAA_DG_DETECTED:-0}, valid_standby_dests=$(maa_value valid_remote_standby_dest_count 0), FSFO=$(maa_value fsfo_status UNKNOWN), observer=$(maa_value fsfo_observer_present UNKNOWN), score=${MAA_SCORE_DR:-0}/5" "Validate Broker, lag, role-based services, FSFO observer placement, switchover/failover, and application reconnect behavior."
  resilience_domain_append "$report_file" "Recoverability" "$recoverability_score" 15 "recover_files=${recover_files}, corruption_rows=${corrupt_rows}, flashback=${flashback}, recovery_manifest=$([[ -n "$backup_manifest" ]] && printf yes || printf no), rto_rpo_drills=$([[ -n "$rto_manifest$rpo_manifest" ]] && printf yes || printf no)" "Use scenarios 64/65 and timed recoveries to prove actual RTO/RPO, not only configuration readiness."
  resilience_domain_append "$report_file" "MAA Alignment" "$maa_score" 15 "target=${MAA_TARGET_LEVEL:-Unknown}, candidate=${MAA_CANDIDATE_LEVEL:-Unknown}, evidenced=${MAA_EVIDENCED_LEVEL:-Unknown}, gap=${MAA_FIT_GAP_SUMMARY:-Unknown}" "Close the largest target-versus-evidence gaps first; avoid claiming candidate tiers without measured evidence."
  resilience_domain_append "$report_file" "Scenario Coverage" "$scenario_score" 10 "$scenario_evidence" "Run scenario readiness/lifecycle reports and prioritize missing automation for high-value HA/DR drills."
  resilience_domain_append "$report_file" "Application Continuity" "$app_score" 8 "score=${MAA_SCORE_APP:-0}/5, AC=$(maa_value ac_service_count 0), TAC=$(maa_value tac_service_count 0), role_services=$(maa_value srvctl_role_based_service_count UNKNOWN), APEX/session_drill=$([[ -n "$(maa_latest_manifest_for_ids "80" 2>/dev/null || true)" ]] && printf yes || printf no)" "Validate client pools, FAN/ONS, AC/TAC replay safety, role-based services, and APEX/ORDS session behavior where applicable."

  if [[ "$RESILIENCE_TOTAL_WEIGHT" -gt 0 ]]; then
    overall=$((RESILIENCE_WEIGHTED_SUM / RESILIENCE_TOTAL_WEIGHT))
  else
    overall=0
  fi

  {
    printf "\n## Overall Score\n\n"
    printf '| Metric | Value |\n'
    printf '| --- | --- |\n'
    printf '| Resilience Score | `%s` |\n' "$(score_badge "$overall")"
    printf '| Total weight | `%s` |\n' "$RESILIENCE_TOTAL_WEIGHT"
    printf '| MAA fit-gap | %s |\n' "$(md_escape "${MAA_FIT_GAP_SUMMARY:-Unknown}")"

    printf "\n## How The Score Updates\n\n"
    printf -- '- New backups, RMAN validation, and recovery manifests improve Backup and Recoverability evidence.\n'
    printf -- '- RAC/service relocation, VIP/service placement, and APEX session manifests improve Local HA and Application Continuity evidence.\n'
    printf -- '- Data Guard apply/transport, FSFO, SRL, switchover/failover, and standby drill manifests improve DR evidence.\n'
    printf -- '- Updated MAA context can raise or lower the target tier; measured evidence determines the evidenced tier.\n'

    printf "\n## Recommended Next Actions\n\n"
    if [[ "$dr_score" -lt 60 ]]; then
      printf -- '- DR score is low: validate or configure Data Guard/ADG, Broker, SRLs, lag monitoring, role-based services, and FSFO where required.\n'
    fi
    if [[ "$recoverability_score" -lt 75 ]]; then
      printf -- '- Recoverability needs stronger proof: run timed restore/recovery drills and scenarios `64` and `65` for RTO/RPO validation.\n'
    fi
    if [[ "$rac_score" -lt 70 && "${MAA_LOCAL_HA_TARGET:-}" =~ ^(yes|YES|true|TRUE|1)$ ]]; then
      printf -- '- Local HA target is set but score is below target: validate service relocation, FAN/ONS, drain, AC/TAC, and instance failure behavior.\n'
    fi
    if [[ "$security_score" -lt 75 ]]; then
      printf -- '- Security score is partial: add DBSAT/Data Safe evidence and validate TDE wallet backup/open behavior across RAC/DG sites.\n'
    fi
    if [[ "$scenario_score" -lt 70 ]]; then
      printf -- '- Scenario coverage can improve: run `--scenario-lifecycle-report` and prioritize lifecycle helpers for high-risk HA/DR scenarios.\n'
    fi
    printf -- '- Save this report as audit evidence before and after major resilience improvements.\n'

    printf "\n## Raw Evidence References\n\n"
    printf -- '- MAA SQL evidence: `%s`\n' "$evidence_file"
    printf -- '- srvctl service evidence: `%s`\n' "$srvctl_service_file"
    printf -- '- DGMGRL/FSFO evidence: `%s`\n' "$dgmgrl_fsfo_file"
  } >>"$report_file"

  cp "$report_file" "$latest_file" || die "Unable to update latest resilience scorecard: $latest_file"
  echo "Resilience scorecard generated: ${report_file}"
  echo "Latest resilience scorecard: ${latest_file}"
  echo "Resilience Score: $(score_badge "$overall")"
  maybe_render_html "$report_file"
  if [[ "$HTML_OUTPUT" -eq 1 ]]; then
    render_artifact_html "$latest_file"
  fi
}

maybe_refresh_resilience_scorecard() {
  local trigger="$1"
  local id="${2:-}"
  local probe_sql probe_out refresh_out

  [[ "${AUTO_SCORECARD:-0}" -eq 1 ]] || return "$SUCCESS"
  [[ "${AUTO_SCORECARD_REFRESHING:-0}" -eq 0 ]] || return "$SUCCESS"

  case "$trigger" in
    scenario|random|protect|recover|validate|validate_all|scenario_readiness_report|scenario_lifecycle_report|health|baseline_backup)
      ;;
    *)
      return "$SUCCESS"
      ;;
  esac

  if ! ensure_sqlplus >/dev/null 2>&1; then
    warn "Resilience scorecard auto-refresh skipped after ${trigger}: SQL*Plus is not available."
    return "$SUCCESS"
  fi

  mkdir -p "$WORK_DIR" 2>/dev/null || return "$SUCCESS"
  probe_sql="${WORK_DIR}/crashsim_resilience_scorecard_probe_${RUN_ID}.sql"
  probe_out="${WORK_DIR}/crashsim_resilience_scorecard_probe_${RUN_ID}.out"
  refresh_out="${WORK_DIR}/crashsim_resilience_scorecard_refresh_${RUN_ID}.out"
  {
    printf "set heading off feedback off pages 0 verify off echo off termout on\n"
    printf "whenever sqlerror exit failure\n"
    printf "select 'OK' from dual;\n"
    printf "exit\n"
  } >"$probe_sql" || return "$SUCCESS"

  if ! "$SQLPLUS_BIN" -L -s "$SQLPLUS_LOGON" @"$probe_sql" >"$probe_out" 2>&1 </dev/null; then
    warn "Resilience scorecard auto-refresh skipped after ${trigger}: target database is not ready for SQL evidence collection."
    return "$SUCCESS"
  fi

  if (
    AUTO_SCORECARD_REFRESHING=1
    HTML_OUTPUT=0
    run_resilience_scorecard >"$refresh_out" 2>&1
  ); then
    if [[ -n "$id" ]]; then
      echo "Resilience scorecard auto-refreshed after ${trigger} ${id}: ${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
    else
      echo "Resilience scorecard auto-refreshed after ${trigger}: ${LOG_DIR}/crashsim_resilience_scorecard_latest.md"
    fi
  else
    warn "Resilience scorecard auto-refresh skipped after ${trigger}; details: ${refresh_out}"
  fi
}

write_maa_report_sqlplus_blocked_stub() {
  local report_file="$1"
  local generated_at="$2"
  {
    printf "# CrashSimulator Oracle MAA Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Application context: `%s`\n' "${MAA_APP_NAME:-not supplied}"
    printf -- '- Database evidence: `blocked (SQL*Plus not available)`\n'
    printf -- '- Target MAA level: `Unknown`\n'
    printf -- '- Candidate MAA level: `Unknown`\n'
    printf -- '- Current evidenced MAA level: `Unknown`\n'
    printf -- '- Readiness status: `BLOCKED`\n'
    printf "\n"
    printf "This report is a best-effort posture assessment, not an Oracle certification. SQL*Plus was not found on this host, so no live database, Grid Infrastructure, or Data Guard evidence could be collected. Every database-derived section is therefore reported as a blocker rather than an assessed result.\n\n"
  } >"$report_file" || die "Unable to write MAA report file: $report_file"

  append_report_section "$report_file" "Database Evidence Blockers"
  {
    printf '| Evidence domain | Status | Unblock action |\n'
    printf '| --- | --- | --- |\n'
    printf '| Database topology (role, open mode, CDB) | `blocked` | Set ORACLE_HOME or SQLPLUS on a host with a created, open database, then re-run `--maa-report`. |\n'
    printf '| Backup and recovery (ARCHIVELOG, RMAN) | `blocked` | Provide SQL*Plus access to the target database and re-run the report. |\n'
    printf '| Local HA (RAC / services) | `blocked` | Provide SQL*Plus and Grid Infrastructure access on the database host and re-run the report. |\n'
    printf '| Data Guard / ADG / FSFO | `blocked` | Provide SQL*Plus and Data Guard Broker access and re-run the report. |\n'
    printf '| Application continuity (services, FAN/AC) | `blocked` | Provide SQL*Plus access to the target database and re-run the report. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "How To Unblock"
  {
    printf -- '- Set `ORACLE_HOME` so that `$ORACLE_HOME/bin/sqlplus` exists, or set `SQLPLUS` to the sqlplus binary.\n'
    printf -- '- Run this report on a host where the target database has been created and is open.\n'
    printf -- '- Re-run `./%s --maa-report` once SQL*Plus can reach the database to replace these blockers with assessed evidence.\n' "$PROGRAM"
  } >>"$report_file"

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html\n'
    printf -- '- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html\n'
  } >>"$report_file"
}

run_maa_report() {
  local report_file sql_file evidence_file srvctl_service_file dgmgrl_fsfo_file generated_at
  local readiness_status sla_hint baseline_gap=0
  local app_continuity capture_count apply_count

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.md"

  if ! find_sqlplus_if_available; then
    warn "SQL*Plus was not found. The MAA readiness report will still be generated, with all database evidence marked as blockers until ORACLE_HOME or SQLPLUS is set on a host with a created database."
    write_maa_report_sqlplus_blocked_stub "$report_file" "$generated_at"
    echo "MAA readiness report generated with blockers: ${report_file}"
    echo "Target MAA level: Unknown (database evidence blocked: SQL*Plus not available)"
    maybe_render_html "$report_file"
    return "$SUCCESS"
  fi

  discover_environment
  ensure_sqlplus

  sql_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}.evidence"
  srvctl_service_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}_srvctl_services.out"
  dgmgrl_fsfo_file="${LOG_DIR}/crashsim_maa_report_${RUN_ID}_dgmgrl_fsfo.out"
  write_maa_assessment_sql_file "$sql_file"

  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "MAA assessment SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"
  collect_srvctl_service_evidence "$srvctl_service_file"
  collect_maa_dgmgrl_fsfo_evidence "$dgmgrl_fsfo_file"

  capture_count="$(maa_value capture_process_count 0)"
  apply_count="$(maa_value apply_process_count 0)"
  app_continuity="$(maa_value application_continuity_service_count 0)"

  [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]] || baseline_gap=1
  [[ "$(maa_value force_logging UNKNOWN)" == "YES" ]] || baseline_gap=1
  maa_positive recent_successful_backup_jobs_7d || baseline_gap=1
  maa_zero datafiles_without_backup_metadata || baseline_gap=1
  maa_zero recover_file_count || baseline_gap=1
  maa_zero block_corruption_count || baseline_gap=1

  readiness_status="Baseline checks passed"
  [[ "$baseline_gap" -eq 0 ]] || readiness_status="Baseline gaps detected"
  sla_hint="$(maa_sla_hint)"
  maa_compute_decision_model

  {
    printf "# CrashSimulator Oracle MAA Readiness Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Application context: `%s`\n' "${MAA_APP_NAME:-not supplied}"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(maa_value cdb "$DB_CDB")"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Storage type: `%s`\n' "$STORAGE_TYPE"
    printf -- '- Target MAA level: `%s`\n' "${MAA_TARGET_LEVEL:-Unknown}"
    printf -- '- Candidate MAA level: `%s`\n' "${MAA_CANDIDATE_LEVEL:-Unknown}"
    printf -- '- Current evidenced MAA level: `%s`\n' "${MAA_EVIDENCED_LEVEL:-Unknown}"
    printf -- '- Readiness status: `%s`\n' "$readiness_status"
    printf -- '- Raw SQL evidence file: `%s`\n' "$evidence_file"
    printf -- '- Data Guard Broker FSFO evidence file: `%s`\n' "$dgmgrl_fsfo_file"
    printf "\n"
    printf "This report is a best-effort posture assessment, not an Oracle certification. It separates business target, topology candidate, and current evidenced MAA level so product presence alone does not overclaim HA/DR maturity.\n\n"
  } >"$report_file" || die "Unable to write MAA report file: $report_file"

  append_report_section "$report_file" "MAA Decision-Tree Result"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    printf '| Target MAA level | `%s` |\n' "$(md_escape "${MAA_TARGET_LEVEL:-Unknown}")"
    printf '| Target basis | %s |\n' "$(md_escape "${MAA_TARGET_REASON:-Unknown}")"
    printf '| Target gaps to verify | %s |\n' "$(md_escape "${MAA_TARGET_GAPS:-none}")"
    printf '| Candidate MAA level | `%s` |\n' "$(md_escape "${MAA_CANDIDATE_LEVEL:-Unknown}")"
    printf '| Candidate basis | %s |\n' "$(md_escape "${MAA_CANDIDATE_REASON:-Unknown}")"
    printf '| Current evidenced MAA level | `%s` |\n' "$(md_escape "${MAA_EVIDENCED_LEVEL:-Unknown}")"
    printf '| Evidenced basis | %s |\n' "$(md_escape "${MAA_EVIDENCED_REASON:-Unknown}")"
    printf '| Fit-gap summary | %s |\n' "$(md_escape "${MAA_FIT_GAP_SUMMARY:-Unknown}")"
    printf '| Baseline readiness | `%s` |\n' "$(md_escape "$readiness_status")"
    printf '| Detection confidence | %s |\n' "$(md_escape "Medium: based on target-host SQL/GI evidence; application failover behavior, external monitoring, and measured business outage need confirmation.")"
  } >>"$report_file"

  append_report_section "$report_file" "Evidence Maturity Scorecard"
  {
    printf '| Domain | Score | Meaning |\n'
    printf '| --- | ---: | --- |\n'
    printf '| Business requirements | `%s` | RTO/RPO, criticality, outage class, and target context completeness. |\n' "${MAA_SCORE_BUSINESS:-0}"
    printf '| Backup and recovery | `%s` | ARCHIVELOG, RMAN coverage, corruption/recovery blockers, and measured recovery manifest evidence. |\n' "${MAA_SCORE_BACKUP:-0}"
    printf '| Local HA | `%s` | RAC/RAC One/local standby, service placement, client HA attributes, and measured local-failure drills. |\n' "${MAA_SCORE_LOCAL_HA:-0}"
    printf '| Data Guard / ADG / FSFO | `%s` | DG configuration, Broker/lag/role services, FSFO observer, and measured role/lag/failover drills. |\n' "${MAA_SCORE_DR:-0}"
    printf '| Application continuity | `%s` | Dedicated services, FAN/RLB/drain, AC/TAC/replay, and application/session validation evidence. |\n' "${MAA_SCORE_APP:-0}"
    printf '| Operations and evidence | `%s` | Audit retention, readiness/lifecycle evidence, runbook/report evidence, and repeatability. |\n' "${MAA_SCORE_OPERATIONS:-0}"
  } >>"$report_file"

  append_report_section "$report_file" "MAA Reference Model Used"
  {
    printf '| MAA level | Observable capabilities used by this report |\n'
    printf '| --- | --- |\n'
    printf '| Bronze | Single-instance or Oracle Restart style database with ARCHIVELOG, RMAN backup/recovery evidence, corruption checks, and basic restart/restore readiness. |\n'
    printf '| Silver | Bronze plus strong local HA using RAC/RAC One Node or explicitly local Data Guard standby, with service/client failover and application-aware continuity evidence. |\n'
    printf '| Gold | Silver plus Data Guard/Active Data Guard DR evidence, Broker/lag/role-services/FSFO where applicable, and measured role-transition/application behavior. |\n'
    printf '| Platinum | Gold plus Exadata/optimized platform and/or supported active replication patterns with seconds-class measured service behavior. |\n'
    printf '| Diamond | Extreme-availability active/global architecture such as 26ai/Exadata/GoldenGate or distributed patterns; supportability and measured evidence require manual confirmation. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Evidence Summary"
  {
    printf '| Area | Evidence |\n'
    printf '| --- | --- |\n'
    printf '| Database | Role `%s`, open mode `%s`, log mode `%s`, force logging `%s`, flashback `%s` |\n' \
      "$(md_escape "$(maa_value db_role)")" "$(md_escape "$(maa_value open_mode)")" \
      "$(md_escape "$(maa_value log_mode)")" "$(md_escape "$(maa_value force_logging)")" \
      "$(md_escape "$(maa_value flashback_on)")"
    printf '| Local HA | Cluster `%s`, cluster_database `%s`, instance parallel `%s`, GI managed `%s`, storage `%s` |\n' \
      "$(md_escape "$CLUSTER_TYPE")" "$(md_escape "$(maa_value cluster_database)")" \
      "$(md_escape "$(maa_value instance_parallel)")" "$(md_escape "$GI_MANAGED")" "$(md_escape "$STORAGE_TYPE")"
    printf '| Backup | Recent successful jobs 7d `%s`, failed jobs 7d `%s`, last success `%s`, datafiles without backup metadata `%s`, devices `%s` |\n' \
      "$(md_escape "$(maa_value recent_successful_backup_jobs_7d)")" \
      "$(md_escape "$(maa_value recent_failed_backup_jobs_7d)")" \
      "$(md_escape "$(maa_value last_successful_backup_time)")" \
      "$(md_escape "$(maa_value datafiles_without_backup_metadata)")" \
      "$(md_escape "$(maa_value backup_device_types)")"
    printf '| Data Guard | Remote standby destinations `%s`, valid destinations `%s`, FSFO `%s`, observer `%s`, transport lag `%s`, apply lag `%s` |\n' \
      "$(md_escape "$(maa_value remote_standby_dest_count)")" \
      "$(md_escape "$(maa_value valid_remote_standby_dest_count)")" \
      "$(md_escape "$(maa_value fsfo_status)")" "$(md_escape "$(maa_value fsfo_observer_present)")" \
      "$(md_escape "$(maa_value dataguard_transport_lag)")" "$(md_escape "$(maa_value dataguard_apply_lag)")"
    printf '| Storage/config | Control files `%s`, redo min members `%s`, redo groups with <2 members `%s`, FRA configured `%s`, FRA used `%s%%` |\n' \
      "$(md_escape "$(maa_value control_file_count)")" "$(md_escape "$(maa_value redo_min_members)")" \
      "$(md_escape "$(maa_value redo_groups_less_than_two_members)")" \
      "$(md_escape "$(maa_value fra_configured)")" "$(md_escape "$(maa_value fra_used_pct)")"
    printf '| Security | Wallet open rows `%s`, wallet not-open rows `%s`, encrypted tablespaces `%s`, TDE config `%s` |\n' \
      "$(md_escape "$(maa_value tde_wallet_open_count)")" \
      "$(md_escape "$(maa_value tde_wallet_not_open_count)")" \
      "$(md_escape "$(maa_value encrypted_tablespace_count)")" \
      "$(md_escape "$(maa_value tde_configuration)")"
    printf '| Application continuity / services | Replay-capable services `%s`, AC `%s`, TAC `%s`, missing AC/TAC `%s`, role-based srvctl services `%s` |\n' \
      "$(md_escape "$app_continuity")" \
      "$(md_escape "$(maa_value ac_service_count "$app_continuity")")" \
      "$(md_escape "$(maa_value tac_service_count 0)")" \
      "$(md_escape "$(maa_value service_without_ac_tac_count UNKNOWN)")" \
      "$(md_escape "$(maa_value srvctl_role_based_service_count UNKNOWN)")"
    printf '| ADG DML redirection | adg_redirect_dml `%s`, modifiable `%s` |\n' \
      "$(md_escape "$(maa_value adg_redirect_dml UNAVAILABLE)")" \
      "$(md_escape "$(maa_value adg_redirect_dml_modifiable UNAVAILABLE)")"
    printf '| Replication dictionary | capture processes `%s`, apply processes `%s` |\n' \
      "$(md_escape "$capture_count")" "$(md_escape "$apply_count")"
  } >>"$report_file"

  append_report_section "$report_file" "Best-Practice Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  if [[ "$(maa_value log_mode UNKNOWN)" == "ARCHIVELOG" ]]; then
    maa_append_check "$report_file" "OK" "Recoverability" "ARCHIVELOG enabled" "LOG_MODE=$(maa_value log_mode)" "Keep validating archived-log backup, restore, and gap handling."
  else
    maa_append_check "$report_file" "GAP" "Recoverability" "ARCHIVELOG enabled" "LOG_MODE=$(maa_value log_mode)" "Enable ARCHIVELOG before expecting meaningful point-in-time or DR recovery."
  fi
  if [[ "$(maa_value force_logging UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Data protection" "FORCE LOGGING enabled" "FORCE_LOGGING=$(maa_value force_logging)" "Keep FORCE LOGGING enabled for Data Guard/readiness unless an exception is explicitly approved."
  else
    maa_append_check "$report_file" "WARN" "Data protection" "FORCE LOGGING enabled" "FORCE_LOGGING=$(maa_value force_logging)" "Enable FORCE LOGGING before Data Guard or strict RPO validation."
  fi
  if maa_positive recent_successful_backup_jobs_7d && maa_zero datafiles_without_backup_metadata; then
    maa_append_check "$report_file" "OK" "Backup" "Recent complete RMAN backup coverage" "jobs_7d=$(maa_value recent_successful_backup_jobs_7d), no_backup_files=$(maa_value datafiles_without_backup_metadata)" "Continue scheduled restore preview/validate drills and retain off-host copies."
  else
    maa_append_check "$report_file" "GAP" "Backup" "Recent complete RMAN backup coverage" "jobs_7d=$(maa_value recent_successful_backup_jobs_7d), no_backup_files=$(maa_value datafiles_without_backup_metadata)" "Fix backup coverage before destructive drills; run RMAN backup, preview, and validate."
  fi
  if maa_zero recent_failed_backup_jobs_7d; then
    maa_append_check "$report_file" "OK" "Backup" "No recent failed RMAN jobs" "failed_jobs_7d=$(maa_value recent_failed_backup_jobs_7d)" "Continue monitoring failed backup jobs and alerting."
  else
    maa_append_check "$report_file" "WARN" "Backup" "No recent failed RMAN jobs" "failed_jobs_7d=$(maa_value recent_failed_backup_jobs_7d)" "Review failed RMAN jobs and confirm they do not represent missing required backup windows."
  fi
  if maa_zero recover_file_count && maa_zero block_corruption_count; then
    maa_append_check "$report_file" "OK" "Health" "No media recovery or block corruption rows" "recover_file=$(maa_value recover_file_count), block_corruption=$(maa_value block_corruption_count)" "Keep periodic validation and corruption monitoring."
  else
    maa_append_check "$report_file" "GAP" "Health" "No media recovery or block corruption rows" "recover_file=$(maa_value recover_file_count), block_corruption=$(maa_value block_corruption_count)" "Resolve recovery/corruption rows before measuring MAA readiness."
  fi
  if [[ "$(maa_value flashback_on UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Recovery" "Flashback Database enabled" "FLASHBACK_ON=$(maa_value flashback_on)" "Use guaranteed restore points deliberately for risky changes and validate retention."
  else
    maa_append_check "$report_file" "WARN" "Recovery" "Flashback Database enabled" "FLASHBACK_ON=$(maa_value flashback_on)" "Consider Flashback Database for faster logical-error and failed-change recovery where storage allows."
  fi
  if maa_positive remote_standby_dest_count || [[ "$(maa_value db_role UNKNOWN)" != "PRIMARY" && "$(maa_value db_role UNKNOWN)" != "UNKNOWN" ]]; then
    maa_append_check "$report_file" "OK" "Disaster recovery" "Data Guard topology detected" "role=$(maa_value db_role), standby_dests=$(maa_value remote_standby_dest_count), valid=$(maa_value valid_remote_standby_dest_count)" "Validate switchover/failover, FSFO, transport/apply lag, and application reconnection."
  else
    maa_append_check "$report_file" "GAP" "Disaster recovery" "Data Guard topology detected" "role=$(maa_value db_role), standby_dests=$(maa_value remote_standby_dest_count)" "Gold or higher MAA posture needs Data Guard/Active Data Guard or equivalent DR architecture."
  fi
  if [[ "$(maa_value fsfo_status UNKNOWN)" =~ SYNCHRONIZED|TARGET|PRIMARY|READY|ENABLED ]] || [[ "$(maa_value fsfo_observer_present UNKNOWN)" == "YES" ]]; then
    maa_append_check "$report_file" "OK" "Disaster recovery" "Fast-Start Failover evidence" "FSFO=$(maa_value fsfo_status), observer=$(maa_value fsfo_observer_present)" "Keep testing observer placement and failover/failback runbooks."
  else
    maa_append_check "$report_file" "INFO" "Disaster recovery" "Fast-Start Failover evidence" "FSFO=$(maa_value fsfo_status), observer=$(maa_value fsfo_observer_present)" "For strict RTO/RPO, evaluate FSFO with appropriate protection mode and observer design."
  fi
  if [[ "${MAA_LOCAL_HA_CANDIDATE:-0}" -eq 1 ]]; then
    maa_append_check "$report_file" "OK" "Local HA" "RAC/RAC One/local standby candidate" "cluster=${CLUSTER_TYPE}, cluster_database=$(maa_value cluster_database), parallel=$(maa_value instance_parallel), standby_scope=${MAA_STANDBY_SCOPE:-unknown}" "Validate service placement, FAN/ONS, Application Continuity, and measured local-failure drills before claiming Silver evidenced."
  else
    maa_append_check "$report_file" "INFO" "Local HA" "RAC/RAC One/local standby candidate" "cluster=${CLUSTER_TYPE}, cluster_database=$(maa_value cluster_database), standby_scope=${MAA_STANDBY_SCOPE:-unknown}" "Silver local HA normally requires RAC/RAC One Node or an explicitly local standby plus service/client failover design."
  fi
  if [[ "$app_continuity" =~ ^[0-9]+$ && "$app_continuity" -gt 0 ]]; then
    maa_append_check "$report_file" "OK" "Application continuity" "AC-style service metadata" "services=$(maa_value application_continuity_service_count)" "Validate replay safety with application teams and planned/unplanned failover drills."
  else
    maa_append_check "$report_file" "INFO" "Application continuity" "AC-style service metadata" "services=$(maa_value application_continuity_service_count)" "For Silver/Platinum readiness, review services, drivers, FAN/ONS, TAC/AC, and request boundaries."
  fi
  if [[ "$(maa_value redo_min_members 0)" =~ ^[0-9]+$ && "$(maa_value redo_min_members 0)" -ge 2 && "$(maa_value control_file_count 0)" =~ ^[0-9]+$ && "$(maa_value control_file_count 0)" -ge 2 ]]; then
    maa_append_check "$report_file" "OK" "File redundancy" "Control file and redo multiplexing" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members)" "Keep members separated across failure domains where possible."
  elif [[ "$STORAGE_TYPE" =~ ^FEX && "$(maa_value redo_min_members 0)" =~ ^[0-9]+$ && "$(maa_value redo_min_members 0)" -ge 2 && "$(maa_value control_file_count 0)" == "1" ]]; then
    maa_append_check "$report_file" "INFO" "File redundancy" "FEX control-file posture" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members), storage=${STORAGE_TYPE}" "OCI FEX exposes provider-managed @... file handles and may not expose a host byte-copy path for manual control-file multiplexing. Validate control-file autobackups, fresh baseline backups, provider storage redundancy, and use a provider-approved offline byte-copy or CREATE CONTROLFILE runbook before attempting active multiplexing."
  else
    maa_append_check "$report_file" "WARN" "File redundancy" "Control file and redo multiplexing" "control_files=$(maa_value control_file_count), redo_min_members=$(maa_value redo_min_members), redo_under2=$(maa_value redo_groups_less_than_two_members)" "Multiplex control files and redo members across independent storage failure domains."
  fi
  if [[ "$(maa_value tde_wallet_not_open_count 0)" == "0" && "$(maa_value encrypted_tablespace_count 0)" != "0" ]]; then
    maa_append_check "$report_file" "OK" "Security" "TDE wallet open for encrypted data" "wallet_open=$(maa_value tde_wallet_open_count), encrypted_tbs=$(maa_value encrypted_tablespace_count)" "Keep wallet backups synchronized across RAC/Data Guard sites."
  elif [[ "$(maa_value encrypted_tablespace_count 0)" == "0" ]]; then
    maa_append_check "$report_file" "INFO" "Security" "TDE wallet open for encrypted data" "encrypted_tbs=0" "Confirm whether encryption is required by policy, compliance, or cloud-service defaults."
  else
    maa_append_check "$report_file" "GAP" "Security" "TDE wallet open for encrypted data" "wallet_not_open=$(maa_value tde_wallet_not_open_count), encrypted_tbs=$(maa_value encrypted_tablespace_count)" "Open/repair keystore state and validate encrypted tablespace and backup access."
  fi

  append_service_awareness_sections "$report_file"

  append_report_section "$report_file" "SLA / RTO / RPO Planning Context"
  {
    printf '| Requirement | Supplied value |\n'
    printf '| --- | --- |\n'
    printf '| Application | `%s` |\n' "$(md_escape "${MAA_APP_NAME:-not supplied}")"
    printf '| Local unplanned RTO | `%s` |\n' "$(md_escape "${MAA_LOCAL_RTO:-not supplied}")"
    printf '| Local unplanned RPO | `%s` |\n' "$(md_escape "${MAA_LOCAL_RPO:-not supplied}")"
    printf '| Disaster/site RTO | `%s` |\n' "$(md_escape "${MAA_DR_RTO:-not supplied}")"
    printf '| Disaster/site RPO | `%s` |\n' "$(md_escape "${MAA_DR_RPO:-not supplied}")"
    printf '| Planned maintenance RTO | `%s` |\n' "$(md_escape "${MAA_PLANNED_RTO:-not supplied}")"
    printf '| Planned maintenance RPO | `%s` |\n' "$(md_escape "${MAA_PLANNED_RPO:-not supplied}")"
    printf '| Criticality | `%s` |\n' "$(md_escape "${MAA_CRITICALITY:-not supplied}")"
    printf '| Local HA target | `%s` |\n' "$(md_escape "${MAA_LOCAL_HA_TARGET:-not supplied}")"
    printf '| DR required | `%s` |\n' "$(md_escape "${MAA_DR_REQUIRED:-not supplied}")"
    printf '| Automatic failover required | `%s` |\n' "$(md_escape "${MAA_AUTOMATIC_FAILOVER_REQUIRED:-not supplied}")"
    printf '| Active-active required | `%s` |\n' "$(md_escape "${MAA_ACTIVE_ACTIVE_REQUIRED:-not supplied}")"
    printf '| Platform hint | `%s` |\n' "$(md_escape "${MAA_PLATFORM_HINT:-not supplied}")"
    printf '| Standby scope | `%s` |\n\n' "$(md_escape "${MAA_STANDBY_SCOPE:-unknown}")"
    printf "Preliminary recommendation hint: %s\n" "$sla_hint"
  } >>"$report_file"

  append_report_section "$report_file" "Suggested CrashSimulator Validation Coverage"
  {
    printf '| Objective | Suggested drills |\n'
    printf '| --- | --- |\n'
    printf '| Bronze backup/restart readiness | Health check, config report, scenarios `5`, `6`, `25`, `26`, `59`, and timed restore-preview/validate runs. |\n'
    printf '| Silver local HA readiness | Service/instance relocation or restart drills such as `55` and `56`, plus client FAN/ONS/Application Continuity validation. |\n'
    printf '| Gold DR readiness | Data Guard transport/apply, switchover/failover, FSFO, archive gap, and standby recovery drills such as `50`, `51`, `52`, `59`. |\n'
    printf '| Platinum/Diamond application continuity | GoldenGate/active-active or sharding failover, conflict handling, zero-downtime planned maintenance, and application transaction replay tests. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html\n'
    printf -- '- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html\n'
    printf -- '- User RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery\n'
    printf -- '- FSFO observer placement reference: https://www.ludovicocaldara.net/blog/video-where-should-i-put-the-observer-in-a-fast-start-failover-configuration/\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw MAA Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_MAA|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  append_report_file "$report_file" "Data Guard Broker Evidence" "$dgmgrl_fsfo_file"
  if command -v srvctl >/dev/null 2>&1 && [[ -n "$DB_UNIQUE_NAME" ]]; then
    append_report_command "$report_file" "srvctl Database And Service Evidence" bash -lc "srvctl config database -d '${DB_UNIQUE_NAME}' 2>&1; srvctl status database -d '${DB_UNIQUE_NAME}' 2>&1; srvctl config service -d '${DB_UNIQUE_NAME}' 2>&1; srvctl status service -d '${DB_UNIQUE_NAME}' 2>&1"
  fi

  echo "MAA readiness report generated: ${report_file}"
  echo "Target MAA level: ${MAA_TARGET_LEVEL:-Unknown}"
  echo "Candidate MAA level: ${MAA_CANDIDATE_LEVEL:-Unknown}"
  echo "Current evidenced MAA level: ${MAA_EVIDENCED_LEVEL:-Unknown}"
  echo "Readiness status: ${readiness_status}"
  maybe_render_html "$report_file"
}

run_service_review() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file evidence_file srvctl_service_file dgmgrl_fsfo_file generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}.evidence"
  srvctl_service_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}_srvctl_services.out"
  dgmgrl_fsfo_file="${LOG_DIR}/crashsim_service_review_${RUN_ID}_dgmgrl_fsfo.out"

  write_maa_assessment_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Service review SQL failed: $sql_file (evidence: $evidence_file)"
  parse_maa_evidence_file "$evidence_file"
  collect_srvctl_service_evidence "$srvctl_service_file"
  collect_maa_dgmgrl_fsfo_evidence "$dgmgrl_fsfo_file"

  {
    printf "# CrashSimulator Oracle Service HA Best-Practice Review\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(maa_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(maa_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(maa_value db_role "$DB_ROLE")" "$(maa_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(maa_value cdb "$DB_CDB")"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Storage type: `%s`\n' "$STORAGE_TYPE"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf -- '- srvctl service evidence file: `%s`\n' "$srvctl_service_file"
    printf -- '- Data Guard Broker FSFO evidence file: `%s`\n' "$dgmgrl_fsfo_file"
    printf "\n"
    printf "This report is read-only. It reviews Oracle Database service metadata, AC/TAC readiness signals, FAN/client HA attributes, Data Guard FSFO posture, Active Data Guard DML redirection configuration, and role-based service evidence when srvctl is available.\n"
  } >"$report_file" || die "Unable to write service review file: $report_file"

  append_service_awareness_sections "$report_file"

  append_report_section "$report_file" "Recommended Validation Drills"
  {
    printf '| Objective | Suggested validation |\n'
    printf '| --- | --- |\n'
    printf '| AC/TAC request replay | Run planned service relocation and scenario `55`/`56`; verify client replay, Transaction Guard outcomes, and application smoke tests. |\n'
    printf '| FAN and service draining | Stop/start or relocate one service through srvctl; confirm connection pools receive FAN/ONS events and drain gracefully. |\n'
    printf '| Data Guard role services | Switchover/failover in a lab; confirm PRIMARY services start only on the new primary and ADG read services start only on the standby role. |\n'
    printf '| FSFO | Validate observer placement, failover threshold, failover target, automatic failover, reinstate, and failback runbooks. |\n'
    printf '| ADG DML redirection | On an ADG standby, test approved redirected DML paths separately from read-only services and measure primary impact. |\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw Service Evidence"
  {
    printf 'SQL evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_MAA|/p' "$evidence_file"
    printf '```\n\n'
    printf 'srvctl service evidence file: `%s`\n\n' "$srvctl_service_file"
    printf '```text\n'
    cat "$srvctl_service_file" 2>/dev/null || true
    printf '```\n\n'
    printf 'Data Guard Broker FSFO evidence file: `%s`\n\n' "$dgmgrl_fsfo_file"
    printf '```text\n'
    cat "$dgmgrl_fsfo_file" 2>/dev/null || true
    printf '```\n'
  } >>"$report_file"

  if command -v srvctl >/dev/null 2>&1 && [[ -n "$DB_UNIQUE_NAME" ]]; then
    append_report_command "$report_file" "srvctl Service Status" srvctl status service -d "$DB_UNIQUE_NAME"
  fi
  append_report_file "$report_file" "Data Guard Broker FSFO Evidence" "$dgmgrl_fsfo_file"

  echo "Oracle service HA review generated: ${report_file}"
  maybe_render_html "$report_file"
}

append_report_command() {
  local report_file="$1"
  local title="$2"
  shift 2
  local status timeout_seconds
  timeout_seconds="${CRASHSIM_REPORT_COMMAND_TIMEOUT:-30}"
  [[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || timeout_seconds=30

  append_report_section "$report_file" "$title"
  {
    printf "Command:"
    printf " %q" "$@"
    printf "\n\n"
    printf '```text\n'
  } >>"$report_file"
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_seconds" "$@" >>"$report_file" 2>&1
  else
    "$@" >>"$report_file" 2>&1
  fi
  status=$?
  if [[ "$status" -ne 0 ]]; then
    printf "\n[command exited with status %s]\n" "$status" >>"$report_file"
  fi
  printf '```\n' >>"$report_file"
}

append_report_file() {
  local report_file="$1"
  local title="$2"
  local path="$3"

  append_report_section "$report_file" "$title"
  if [[ -f "$path" ]]; then
    {
      printf 'File: `%s`\n\n' "$path"
      printf '```text\n'
      sed 's/\r$//' "$path"
      printf '```\n'
    } >>"$report_file"
  else
    printf 'File not found: `%s`\n' "$path" >>"$report_file"
  fi
}

append_report_environment() {
  local report_file="$1"

  append_report_section "$report_file" "Operating System And Oracle Environment"
  {
    printf "Command: env | sort with secret redaction\n\n"
    printf '```text\n'
    env | sort | awk -F= '
      BEGIN {
        secret_pattern = "(PASS|PASSWORD|TOKEN|SECRET|CREDENTIAL|AUTH|PRIVATE.*KEY|ACCESS.*KEY|KEY_FILE)"
      }
      {
        key = $1
        upper_key = toupper(key)
        if (upper_key ~ secret_pattern) {
          print key "=<redacted>"
        } else {
          print
        }
      }
    '
    printf '```\n'
  } >>"$report_file"
}

append_network_config_files() {
  local report_file="$1"
  local net_dirs=()
  local dir file lsnrctl_bin lsnrctl_home found

  if [[ -n "${TNS_ADMIN:-}" ]]; then
    net_dirs+=("$TNS_ADMIN")
  fi
  if [[ -n "${ORACLE_HOME:-}" ]]; then
    net_dirs+=("${ORACLE_HOME}/network/admin")
  fi
  lsnrctl_bin="$(command -v lsnrctl 2>/dev/null || true)"
  if [[ -n "$lsnrctl_bin" ]]; then
    lsnrctl_home="$(cd "$(dirname "$lsnrctl_bin")/.." >/dev/null 2>&1 && pwd || true)"
    [[ -n "$lsnrctl_home" ]] && net_dirs+=("${lsnrctl_home}/network/admin")
  fi

  local unique_dirs=()
  for dir in "${net_dirs[@]}"; do
    [[ -n "$dir" ]] || continue
    found=0
    local existing
    for existing in "${unique_dirs[@]}"; do
      [[ "$existing" == "$dir" ]] && found=1 && break
    done
    [[ "$found" -eq 1 ]] || unique_dirs+=("$dir")
  done

  for dir in "${unique_dirs[@]}"; do
    for file in listener.ora tnsnames.ora sqlnet.ora; do
      append_report_file "$report_file" "Network config: ${dir}/${file}" "${dir}/${file}"
    done
  done
}

write_backup_report_evidence_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write backup report evidence SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off

select 'CSIM_BKP|db_name|' || name from v$database;
select 'CSIM_BKP|db_unique_name|' || db_unique_name from v$database;
select 'CSIM_BKP|dbid|' || dbid from v$database;
select 'CSIM_BKP|database_role|' || database_role from v$database;
select 'CSIM_BKP|open_mode|' || open_mode from v$database;
select 'CSIM_BKP|cdb|' || cdb from v$database;
select 'CSIM_BKP|log_mode|' || log_mode from v$database;
select 'CSIM_BKP|force_logging|' || force_logging from v$database;
select 'CSIM_BKP|flashback_on|' || flashback_on from v$database;
select 'CSIM_BKP|platform_name|' || platform_name from v$database;

select 'CSIM_BKP|control_file_record_keep_time|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'control_file_record_keep_time';
select 'CSIM_BKP|archive_lag_target|' || nvl(max(display_value), 'UNKNOWN')
from v$parameter
where name = 'archive_lag_target';
select 'CSIM_BKP|db_recovery_file_dest|' || nvl(max(value), 'NONE')
from v$parameter
where name = 'db_recovery_file_dest';

select 'CSIM_BKP|rman_retention_policy|' ||
       nvl(max(case when name = 'RETENTION POLICY' then value end), 'DEFAULT')
from v$rman_configuration;
select 'CSIM_BKP|rman_controlfile_autobackup|' ||
       nvl(max(case when name = 'CONTROLFILE AUTOBACKUP' then value end), 'DEFAULT/OFF')
from v$rman_configuration;
select 'CSIM_BKP|rman_backup_optimization|' ||
       nvl(max(case when name = 'BACKUP OPTIMIZATION' then value end), 'DEFAULT/OFF')
from v$rman_configuration;
select 'CSIM_BKP|rman_encryption|' ||
       nvl(max(case when name = 'ENCRYPTION FOR DATABASE' then value end), 'DEFAULT')
from v$rman_configuration;
select 'CSIM_BKP|rman_compression|' ||
       nvl(max(case when name = 'COMPRESSION ALGORITHM' then value end), 'DEFAULT')
from v$rman_configuration;
select 'CSIM_BKP|rman_channel_config_count|' ||
       count(*)
from v$rman_configuration
where name like 'CHANNEL%';

select 'CSIM_BKP|datafile_count|' || count(*) from v$datafile;
select 'CSIM_BKP|tempfile_count|' || count(*) from v$tempfile;
select 'CSIM_BKP|database_size_gb|' || round(sum(bytes)/1024/1024/1024, 2)
from v$datafile;
select 'CSIM_BKP|datafile_copy_count|' || count(*) from v$datafile_copy;

select 'CSIM_BKP|datafiles_without_backup_metadata|' || count(*)
from (
  select df.file#
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
  having max(bdf.completion_time) is null
);
select 'CSIM_BKP|oldest_datafile_backup_time|' ||
       nvl(to_char(min(last_backup_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from (
  select df.file#, max(bdf.completion_time) last_backup_time
  from v$datafile df
  left join v$backup_datafile bdf on bdf.file# = df.file#
  group by df.file#
);
select 'CSIM_BKP|last_datafile_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_datafile;
select 'CSIM_BKP|last_datafile_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile;
select 'CSIM_BKP|last_level0_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_datafile
where incremental_level = 0
   or incremental_level is null;
select 'CSIM_BKP|last_level0_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile
where incremental_level = 0
   or incremental_level is null;
select 'CSIM_BKP|last_level1_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_datafile
where incremental_level = 1;
select 'CSIM_BKP|last_level1_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_datafile
where incremental_level = 1;

select 'CSIM_BKP|level0_count_30d|' || count(*)
from (
  select distinct set_stamp, set_count
  from v$backup_datafile
  where (incremental_level = 0 or incremental_level is null)
    and completion_time >= sysdate - 30
);
select 'CSIM_BKP|level1_count_30d|' || count(*)
from (
  select distinct set_stamp, set_count
  from v$backup_datafile
  where incremental_level = 1
    and completion_time >= sysdate - 30
);
select 'CSIM_BKP|level0_avg_gap_hours|' ||
       nvl(to_char(round(avg((completion_time - prev_time) * 24), 1)), 'UNKNOWN')
from (
  select completion_time,
         lag(completion_time) over (order by completion_time) prev_time
  from (
    select distinct completion_time
    from v$backup_datafile
    where (incremental_level = 0 or incremental_level is null)
      and completion_time >= sysdate - 90
  )
)
where prev_time is not null;
select 'CSIM_BKP|level1_avg_gap_hours|' ||
       nvl(to_char(round(avg((completion_time - prev_time) * 24), 1)), 'UNKNOWN')
from (
  select completion_time,
         lag(completion_time) over (order by completion_time) prev_time
  from (
    select distinct completion_time
    from v$backup_datafile
    where incremental_level = 1
      and completion_time >= sysdate - 90
  )
)
where prev_time is not null;

select 'CSIM_BKP|successful_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status like 'COMPLETED%';
select 'CSIM_BKP|failed_jobs_7d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 7
  and status not like 'COMPLETED%';
select 'CSIM_BKP|successful_jobs_30d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status like 'COMPLETED%';
select 'CSIM_BKP|failed_jobs_30d|' || count(*)
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status not like 'COMPLETED%';
select 'CSIM_BKP|last_successful_job_time|' ||
       nvl(to_char(max(end_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_BKP|last_successful_job_age_hours|' ||
       nvl(to_char(round((sysdate - max(end_time)) * 24, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where status like 'COMPLETED%';
select 'CSIM_BKP|backup_device_types|' ||
       nvl((
         select listagg(output_device_type, ',') within group (order by output_device_type)
         from (
           select distinct nvl(output_device_type, 'UNKNOWN') output_device_type
           from v$rman_backup_job_details
           where start_time >= sysdate - 30
         )
       ), 'NONE')
from dual;
select 'CSIM_BKP|avg_successful_job_elapsed_minutes_30d|' ||
       nvl(to_char(round(avg(elapsed_seconds) / 60, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status like 'COMPLETED%';
select 'CSIM_BKP|max_successful_job_elapsed_minutes_30d|' ||
       nvl(to_char(round(max(elapsed_seconds) / 60, 1)), 'UNKNOWN')
from v$rman_backup_job_details
where start_time >= sysdate - 30
  and status like 'COMPLETED%';

select 'CSIM_BKP|archivelog_backup_sets_30d|' || count(*)
from v$backup_set
where backup_type = 'L'
  and completion_time >= sysdate - 30;
select 'CSIM_BKP|last_archivelog_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_set
where backup_type = 'L';
select 'CSIM_BKP|last_archivelog_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_set
where backup_type = 'L';
select 'CSIM_BKP|archivelog_backup_avg_gap_hours|' ||
       nvl(to_char(round(avg((completion_time - prev_time) * 24), 1)), 'UNKNOWN')
from (
  select completion_time,
         lag(completion_time) over (order by completion_time) prev_time
  from (
    select distinct completion_time
    from v$backup_set
    where backup_type = 'L'
      and completion_time >= sysdate - 90
  )
)
where prev_time is not null;
select 'CSIM_BKP|archivelogs_known_7d|' || count(*)
from v$archived_log
where completion_time >= sysdate - 7
  and name is not null
  and nvl(deleted, 'NO') = 'NO';
select 'CSIM_BKP|archivelogs_not_backed_7d|' || count(*)
from v$archived_log
where completion_time >= sysdate - 7
  and name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0;
select 'CSIM_BKP|oldest_unbacked_archivelog_time|' ||
       nvl(to_char(min(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0;
select 'CSIM_BKP|oldest_unbacked_archivelog_age_hours|' ||
       nvl(to_char(round((sysdate - min(completion_time)) * 24, 1)), 'UNKNOWN')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0;
select 'CSIM_BKP|latest_archivelog_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';

select 'CSIM_BKP|controlfile_backup_count_30d|' || count(*)
from v$backup_set
where controlfile_included = 'YES'
  and completion_time >= sysdate - 30;
select 'CSIM_BKP|last_controlfile_backup_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_set
where controlfile_included = 'YES';
select 'CSIM_BKP|last_controlfile_backup_age_hours|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 24, 1)), 'UNKNOWN')
from v$backup_set
where controlfile_included = 'YES';

select 'CSIM_BKP|backup_piece_available_count|' || count(*)
from v$backup_piece
where status = 'A';
select 'CSIM_BKP|backup_piece_expired_count|' || count(*)
from v$backup_piece
where status = 'X';
select 'CSIM_BKP|backup_piece_deleted_count|' || count(*)
from v$backup_piece
where status = 'D';
select 'CSIM_BKP|backup_piece_unavailable_count|' || count(*)
from v$backup_piece
where status not in ('A', 'D', 'X');
select 'CSIM_BKP|latest_backup_piece_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$backup_piece;
select 'CSIM_BKP|backup_piece_device_types|' ||
       nvl((
         select listagg(device_type, ',') within group (order by device_type)
         from (
           select distinct nvl(device_type, 'UNKNOWN') device_type
           from v$backup_piece
           where completion_time >= sysdate - 30
         )
       ), 'NONE')
from dual;

select 'CSIM_BKP|recover_file_count|' || count(*) from v$recover_file;
select 'CSIM_BKP|block_corruption_count|' || count(*) from v$database_block_corruption;
select 'CSIM_BKP|copy_corruption_count|' || count(*) from v$copy_corruption;
select 'CSIM_BKP|backup_corruption_count|' || count(*) from v$backup_corruption;

select 'CSIM_BKP|fra_configured|' ||
       case when count(*) > 0 and max(space_limit) > 0 then 'YES' else 'NO' end
from v$recovery_file_dest;
select 'CSIM_BKP|fra_used_pct|' ||
       nvl(to_char(round(max(space_used) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;
select 'CSIM_BKP|fra_reclaimable_pct|' ||
       nvl(to_char(round(max(space_reclaimable) / nullif(max(space_limit), 0) * 100, 2)), 'UNKNOWN')
from v$recovery_file_dest;

select 'CSIM_BKP|remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status <> 'INACTIVE';
select 'CSIM_BKP|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_BKP|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_BKP|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_BKP|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_BKP|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

exit
SQL
}

write_backup_report_detail_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write backup report detail SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 500 lines 260 trimspool on tab off verify off feedback on
set numwidth 20
column name format a38
column value format a120
column input_type format a24
column status format a24
column start_time format a20
column end_time format a20
column completion_time format a20
column file_name format a150
column handle format a150
column device_type format a18
column backup_status format a34
column backup_class format a22
column start_day format a10

prompt # Backup SQL Evidence
prompt
prompt ## Database Backup Context
select name, db_unique_name, database_role, open_mode, cdb, log_mode,
       force_logging, flashback_on
from v$database;

prompt ## RMAN Configuration
select name, value from v$rman_configuration order by name;

prompt ## RMAN Job History - Last 60 Jobs
select *
from (
  select session_key, input_type, status,
         to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') start_time,
         to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') end_time,
         round(elapsed_seconds / 60, 1) elapsed_minutes,
         output_device_type, input_bytes_display, output_bytes_display
  from v$rman_backup_job_details
  order by start_time desc
)
where rownum <= 60;

prompt ## Observed Job Cadence By Type, Day, And Hour
select nvl(input_type, 'UNKNOWN') input_type,
       to_char(start_time, 'DY', 'NLS_DATE_LANGUAGE=English') start_day,
       to_char(start_time, 'HH24') start_hour,
       count(*) job_count,
       to_char(min(start_time), 'YYYY-MM-DD HH24:MI:SS') first_observed,
       to_char(max(start_time), 'YYYY-MM-DD HH24:MI:SS') last_observed
from v$rman_backup_job_details
where start_time >= sysdate - 60
group by nvl(input_type, 'UNKNOWN'),
         to_char(start_time, 'DY', 'NLS_DATE_LANGUAGE=English'),
         to_char(start_time, 'HH24')
order by input_type, job_count desc, start_day, start_hour;

prompt ## Datafile Backup Coverage
select df.file#, df.name file_name,
       to_char(max(bdf.completion_time), 'YYYY-MM-DD HH24:MI:SS') last_backup_time,
       min(bdf.incremental_level) keep (dense_rank last order by bdf.completion_time nulls first) last_incremental_level,
       case when max(bdf.completion_time) is null then 'NO BACKUP IN CONTROL FILE METADATA'
            else 'BACKUP METADATA FOUND'
       end backup_status
from v$datafile df
left join v$backup_datafile bdf on bdf.file# = df.file#
group by df.file#, df.name
order by df.file#;

prompt ## Datafile Backup Levels - Last 90 Days
select case when incremental_level is null then 'FULL/NON-INCREMENTAL'
            else 'LEVEL ' || to_char(incremental_level)
       end backup_class,
       count(*) backed_file_entries,
       to_char(min(completion_time), 'YYYY-MM-DD HH24:MI:SS') first_observed,
       to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS') last_observed
from v$backup_datafile
where completion_time >= sysdate - 90
group by incremental_level
order by backup_class;

prompt ## Backup Piece Status
select status, device_type, count(*) piece_count,
       to_char(min(completion_time), 'YYYY-MM-DD HH24:MI:SS') oldest_completion,
       to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS') latest_completion
from v$backup_piece
group by status, device_type
order by status, device_type;

prompt ## Recent Backup Pieces
select *
from (
  select recid, stamp, status, device_type,
         to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time,
         round(bytes/1024/1024/1024, 2) size_gb,
         compressed, handle
  from v$backup_piece
  order by completion_time desc nulls last
)
where rownum <= 80;

prompt ## Archived Redo Backup Coverage - Last 7 Days
select thread#, sequence#,
       to_char(first_time, 'YYYY-MM-DD HH24:MI:SS') first_time,
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time,
       deleted, backup_count, name
from v$archived_log
where completion_time >= sysdate - 7
  and name is not null
order by thread#, sequence#;

prompt ## Unbacked Archived Redo Logs
select thread#, sequence#,
       to_char(first_time, 'YYYY-MM-DD HH24:MI:SS') first_time,
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time,
       deleted, backup_count, name
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) = 0
order by completion_time;

prompt ## Backup Corruption Views
select 'V$DATABASE_BLOCK_CORRUPTION' source_name, count(*) row_count from v$database_block_corruption
union all
select 'V$COPY_CORRUPTION' source_name, count(*) row_count from v$copy_corruption
union all
select 'V$BACKUP_CORRUPTION' source_name, count(*) row_count from v$backup_corruption;

prompt ## Files Requiring Media Recovery
select * from v$recover_file order by file#;

prompt ## FRA Usage
select name, round(space_limit/1024/1024/1024,2) space_limit_gb,
       round(space_used/1024/1024/1024,2) space_used_gb,
       round(space_reclaimable/1024/1024/1024,2) space_reclaimable_gb,
       number_of_files
from v$recovery_file_dest;

prompt ## FRA Usage By File Type
select file_type, percent_space_used, percent_space_reclaimable, number_of_files
from v$flash_recovery_area_usage
order by file_type;

prompt ## Data Guard / RPO Adjacent Evidence
select dest_id, status, target, destination, db_unique_name, valid_now, error
from v$archive_dest
where destination is not null
order by dest_id;

select name, value, unit, time_computed, datum_time
from v$dataguard_stats
order by name;

exit
SQL
}

parse_backup_evidence_file() {
  local evidence_file="$1"
  local prefix key value

  BACKUP_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_BKP" && -n "$key" ]] || continue
    BACKUP_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

backup_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${BACKUP_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

backup_is_number() {
  [[ "$1" =~ ^([0-9]+([.][0-9]+)?|[.][0-9]+)$ ]]
}

backup_display_number() {
  local value="$1"
  if [[ "$value" == .* ]]; then
    printf "0%s" "$value"
  else
    printf "%s" "$value"
  fi
}

backup_display_value() {
  local value="$1"
  if backup_is_number "$value"; then
    backup_display_number "$value"
  else
    printf "%s" "$value"
  fi
}

backup_num_gt() {
  backup_is_number "$1" && backup_is_number "$2" &&
    awk -v a="$1" -v b="$2" 'BEGIN { exit (a > b) ? 0 : 1 }'
}

backup_num_le() {
  backup_is_number "$1" && backup_is_number "$2" &&
    awk -v a="$1" -v b="$2" 'BEGIN { exit (a <= b) ? 0 : 1 }'
}

backup_cadence_label() {
  local hours="$1"
  if ! backup_is_number "$hours"; then
    printf "not enough history"
  elif backup_num_le "$hours" "2"; then
    printf "roughly hourly or better"
  elif backup_num_le "$hours" "8"; then
    printf "several times per day"
  elif backup_num_le "$hours" "30"; then
    printf "roughly daily"
  elif backup_num_le "$hours" "190"; then
    printf "roughly weekly"
  else
    printf "less frequent than weekly"
  fi
}

backup_detect_strategy() {
  local level0 level1 arch copies
  level0="$(backup_value level0_count_30d 0)"
  level1="$(backup_value level1_count_30d 0)"
  arch="$(backup_value archivelog_backup_sets_30d 0)"
  copies="$(backup_value datafile_copy_count 0)"

  if [[ "$level0" =~ ^[0-9]+$ && "$level1" =~ ^[0-9]+$ && "$level0" -gt 0 && "$level1" -gt 0 ]]; then
    printf "Level 0 plus Level 1 incremental strategy observed"
  elif [[ "$level0" =~ ^[0-9]+$ && "$level0" -gt 0 ]]; then
    printf "Level 0/full datafile backup strategy observed"
  elif [[ "$copies" =~ ^[0-9]+$ && "$copies" -gt 0 ]]; then
    printf "Datafile image copy metadata observed"
  else
    printf "No complete datafile backup strategy is visible in RMAN metadata"
  fi

  if [[ "$arch" =~ ^[0-9]+$ && "$arch" -gt 0 ]]; then
    printf " with archived redo backups"
  else
    printf " without visible archived redo backup history"
  fi
}

backup_estimated_rpo() {
  local log_mode arch_age unbacked_age arch_sets dg_count
  local arch_age_display unbacked_age_display
  log_mode="$(backup_value log_mode UNKNOWN)"
  arch_age="$(backup_value last_archivelog_backup_age_hours UNKNOWN)"
  unbacked_age="$(backup_value oldest_unbacked_archivelog_age_hours UNKNOWN)"
  arch_sets="$(backup_value archivelog_backup_sets_30d 0)"
  dg_count="$(backup_value valid_remote_standby_dest_count 0)"

  if [[ "$log_mode" != "ARCHIVELOG" ]]; then
    printf "Backup-only RPO is at risk: NOARCHIVELOG mode generally limits recovery to the last whole backup."
  elif [[ "$arch_sets" =~ ^[0-9]+$ && "$arch_sets" -eq 0 ]]; then
    printf "Backup-only RPO is not proven: no archived redo backup sets were observed in the last 30 days. Local archived logs may reduce data loss only if the local FRA/storage survives."
  elif backup_is_number "$arch_age"; then
    arch_age_display="$(backup_display_number "$arch_age")"
    printf "Backup-only RPO is approximately the age of the latest archived redo backup, currently about %s hours; actual data loss can be lower if required archived logs and online redo survive locally." "$arch_age_display"
  else
    printf "Backup-only RPO could not be estimated from visible archived redo backup metadata."
  fi

  if backup_is_number "$unbacked_age"; then
    unbacked_age_display="$(backup_display_number "$unbacked_age")"
    printf " Oldest currently unbacked archived redo is about %s hours old." "$unbacked_age_display"
  fi
  if [[ "$dg_count" =~ ^[0-9]+$ && "$dg_count" -gt 0 ]]; then
    printf " Valid Data Guard destinations are visible and may provide a lower HA/DR RPO than backup-only recovery; validate transport/apply lag separately."
  fi
}

backup_estimated_rto() {
  local missing level0_age level1_age db_gb avg_job max_job copies
  missing="$(backup_value datafiles_without_backup_metadata 0)"
  level0_age="$(backup_value last_level0_backup_age_hours UNKNOWN)"
  level1_age="$(backup_value last_level1_backup_age_hours UNKNOWN)"
  db_gb="$(backup_value database_size_gb UNKNOWN)"
  avg_job="$(backup_value avg_successful_job_elapsed_minutes_30d UNKNOWN)"
  max_job="$(backup_value max_successful_job_elapsed_minutes_30d UNKNOWN)"
  copies="$(backup_value datafile_copy_count 0)"

  if [[ "$missing" =~ ^[0-9]+$ && "$missing" -gt 0 ]]; then
    printf "RTO is not safely estimable because %s datafile(s) have no visible backup metadata." "$missing"
    return
  fi

  if [[ "$level0_age" == "UNKNOWN" ]]; then
    printf "RTO is not safely estimable because no Level 0/full datafile backup is visible."
    return
  fi

  if [[ "$copies" =~ ^[0-9]+$ && "$copies" -gt 0 ]]; then
    printf "Potential RTO may be lower if image copies are current and switch-to-copy/roll-forward is practiced."
  else
    printf "Potential RTO is likely hours for full database restore/recovery unless timed drills prove otherwise."
  fi
  printf " Visible database size is %s GB." "$db_gb"
  printf " Latest Level 0/full backup age is %s hours." "$(backup_display_number "$level0_age")"
  if backup_is_number "$level1_age"; then
    printf " Latest Level 1 incremental backup age is %s hours, so recovery must restore/roll forward backups and apply redo after that point." "$(backup_display_number "$level1_age")"
  fi
  if backup_is_number "$avg_job" || backup_is_number "$max_job"; then
    printf " Recent successful backup job duration averages %s minutes and maxes at %s minutes; restore time can differ and must be measured." "$(backup_display_number "$avg_job")" "$(backup_display_number "$max_job")"
  fi
}

backup_append_check() {
  local report_file="$1"
  local status="$2"
  local area="$3"
  local check_name="$4"
  local evidence="$5"
  local recommendation="$6"

  printf '| `%s` | %s | %s | %s | %s |\n' \
    "$(md_escape "$status")" \
    "$(md_escape "$area")" \
    "$(md_escape "$check_name")" \
    "$(md_escape "$evidence")" \
    "$(md_escape "$recommendation")" >>"$report_file"
}

write_backup_report_rman_repository_file() {
  local cmd_file="$1"

  {
    [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "connect catalog %s\n" "$RMAN_CATALOG_CONNECT"
    printf "show all;\n"
    printf "list backup summary;\n"
    printf "list backup of database summary;\n"
    printf "list backup of archivelog all summary;\n"
    printf "list expired backup summary;\n"
    printf "list expired archivelog all;\n"
    printf "report schema;\n"
    printf "report need backup;\n"
    printf "report obsolete;\n"
    printf "restore database preview summary;\n"
    printf "exit;\n"
  } >"$cmd_file" || die "Unable to write RMAN repository report file: $cmd_file"
  chmod 600 "$cmd_file" 2>/dev/null || true
}

write_backup_report_rman_validate_file() {
  local cmd_file="$1"

  {
    [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "connect catalog %s\n" "$RMAN_CATALOG_CONNECT"
    printf "restore database validate;\n"
    printf "restore archivelog all validate;\n"
    printf "validate database check logical;\n"
    printf "exit;\n"
  } >"$cmd_file" || die "Unable to write RMAN validation report file: $cmd_file"
  chmod 600 "$cmd_file" 2>/dev/null || true
}

append_report_rman_cmdfile() {
  local report_file="$1"
  local title="$2"
  local cmd_file="$3"
  local log_file="$4"
  local status

  append_report_section "$report_file" "$title"
  {
    printf 'Repository source requested: `%s`\n\n' "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "recovery catalog plus target control file" || printf "target control file")"
    printf 'Command: `%s target / cmdfile=%s log=%s`\n\n' "$(basename "$RMAN_BIN")" "$cmd_file" "$log_file"
    printf '```text\n'
  } >>"$report_file"

  "$RMAN_BIN" target / cmdfile="$cmd_file" log="$log_file" >/dev/null 2>&1
  status=$?
  if [[ -f "$log_file" ]]; then
    print_redacted_rman_log "$log_file" >>"$report_file"
  else
    printf "RMAN log file was not created: %s\n" "$log_file" >>"$report_file"
  fi
  if [[ "$status" -ne 0 ]]; then
    printf "\n[command exited with status %s]\n" "$status" >>"$report_file"
  fi
  printf '```\n' >>"$report_file"
  return "$status"
}

run_backup_report() {
  discover_environment
  ensure_sqlplus
  ensure_rman

  local report_file evidence_sql evidence_file detail_sql generated_at rman_cmd_dir
  local rman_repo_file rman_repo_log rman_validate_file rman_validate_log
  local repo_status=0 validate_status=0
  local strategy rpo_hint rto_hint level0_gap level1_gap arch_gap
  local missing failed7 failed30 expired unavailable deleted recover_files corruptions fra_used
  local controlfile_auto retention catalog_redacted

  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_backup_report_${RUN_ID}.md"
  evidence_sql="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_evidence.sql"
  evidence_file="${LOG_DIR}/crashsim_backup_report_${RUN_ID}.evidence"
  detail_sql="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_detail.sql"
  rman_cmd_dir="$LOG_DIR"
  [[ -n "$RMAN_CATALOG_CONNECT" ]] && rman_cmd_dir="$WORK_DIR"
  rman_repo_file="${rman_cmd_dir}/crashsim_backup_report_${RUN_ID}_repository.rman"
  rman_repo_log="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_repository.log"
  rman_validate_file="${rman_cmd_dir}/crashsim_backup_report_${RUN_ID}_validate.rman"
  rman_validate_log="${LOG_DIR}/crashsim_backup_report_${RUN_ID}_validate.log"

  write_backup_report_evidence_sql_file "$evidence_sql"
  write_backup_report_detail_sql_file "$detail_sql"

  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$evidence_sql" >"$evidence_file" </dev/null ||
    die "Backup evidence SQL failed: $evidence_sql (evidence: $evidence_file)"
  parse_backup_evidence_file "$evidence_file"

  strategy="$(backup_detect_strategy)"
  rpo_hint="$(backup_estimated_rpo)"
  rto_hint="$(backup_estimated_rto)"
  level0_gap="$(backup_cadence_label "$(backup_value level0_avg_gap_hours UNKNOWN)")"
  level1_gap="$(backup_cadence_label "$(backup_value level1_avg_gap_hours UNKNOWN)")"
  arch_gap="$(backup_cadence_label "$(backup_value archivelog_backup_avg_gap_hours UNKNOWN)")"
  catalog_redacted="$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"

  {
    printf "# CrashSimulator Backup Strategy And Recoverability Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "$(backup_value db_name "$DB_NAME")"
    printf -- '- DB unique name: `%s`\n' "$(backup_value db_unique_name "$DB_UNIQUE_NAME")"
    printf -- '- DBID: `%s`\n' "$(backup_value dbid UNKNOWN)"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(backup_value database_role "$DB_ROLE")" "$(backup_value open_mode "$DB_OPEN_MODE")"
    printf -- '- CDB: `%s`\n' "$(backup_value cdb "$DB_CDB")"
    printf -- '- Storage: `%s`\n' "$STORAGE_TYPE"
    printf -- '- Cluster type: `%s`\n' "$CLUSTER_TYPE"
    printf -- '- Deep RMAN validation: `%s`\n' "$([[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && printf enabled || printf disabled)"
    printf -- '- RMAN repository source requested: `%s`\n' "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "recovery catalog plus target control file" || printf "target control file")"
    [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf -- '- RMAN catalog connect: `%s`\n' "$catalog_redacted"
    printf -- '- SQL evidence file: `%s`\n' "$evidence_file"
    printf "\n"
    printf "This report estimates recoverability from current database/RMAN metadata and optional RMAN validation output. RTO/RPO values are planning estimates, not guarantees; prove them with timed restore, recovery, and application validation drills.\n"
  } >"$report_file" || die "Unable to write backup report file: $report_file"

  append_report_section "$report_file" "Executive Summary"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    printf '| Strategy detected | %s |\n' "$(md_escape "$strategy")"
    printf '| Level 0/full cadence | %s; last backup `%s`, age `%s` hours |\n' \
      "$(md_escape "$level0_gap")" "$(md_escape "$(backup_value last_level0_backup_time NONE)")" "$(md_escape "$(backup_display_value "$(backup_value last_level0_backup_age_hours UNKNOWN)")")"
    printf '| Level 1 incremental cadence | %s; last backup `%s`, age `%s` hours |\n' \
      "$(md_escape "$level1_gap")" "$(md_escape "$(backup_value last_level1_backup_time NONE)")" "$(md_escape "$(backup_display_value "$(backup_value last_level1_backup_age_hours UNKNOWN)")")"
    printf '| Archived redo backup cadence | %s; last backup `%s`, age `%s` hours |\n' \
      "$(md_escape "$arch_gap")" "$(md_escape "$(backup_value last_archivelog_backup_time NONE)")" "$(md_escape "$(backup_display_value "$(backup_value last_archivelog_backup_age_hours UNKNOWN)")")"
    printf '| Visible database size | `%s` GB across `%s` datafiles |\n' "$(md_escape "$(backup_value database_size_gb UNKNOWN)")" "$(md_escape "$(backup_value datafile_count UNKNOWN)")"
    printf '| Backup device types | `%s` |\n' "$(md_escape "$(backup_value backup_device_types NONE)")"
    printf '| Backup piece device types | `%s` |\n' "$(md_escape "$(backup_value backup_piece_device_types NONE)")"
    printf '| Backup-only RPO estimate | %s |\n' "$(md_escape "$rpo_hint")"
    printf '| Backup/recovery RTO estimate | %s |\n' "$(md_escape "$rto_hint")"
  } >>"$report_file"

  append_report_section "$report_file" "Backup Health Checks"
  {
    printf '| Status | Area | Check | Evidence | Recommendation |\n'
    printf '| --- | --- | --- | --- | --- |\n'
  } >>"$report_file"

  missing="$(backup_value datafiles_without_backup_metadata 0)"
  if [[ "$missing" =~ ^[0-9]+$ && "$missing" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Coverage" "Every datafile has backup metadata" "missing_datafiles=${missing}" "Keep validating restore paths and catalog/control-file metadata retention."
  else
    backup_append_check "$report_file" "GAP" "Coverage" "Datafile backup coverage" "missing_datafiles=${missing}" "Run a database backup or investigate files not represented in RMAN metadata before destructive drills."
  fi

  if backup_is_number "$(backup_value last_level0_backup_age_hours UNKNOWN)" && backup_num_le "$(backup_value last_level0_backup_age_hours UNKNOWN)" "168"; then
    backup_append_check "$report_file" "OK" "Baseline" "Recent Level 0/full backup" "age_hours=$(backup_display_value "$(backup_value last_level0_backup_age_hours)")" "Keep Level 0/full backups aligned with restore-time objectives."
  else
    backup_append_check "$report_file" "WARN" "Baseline" "Recent Level 0/full backup" "age_hours=$(backup_display_value "$(backup_value last_level0_backup_age_hours UNKNOWN)")" "Review Level 0/full backup cadence; weekly or better is common for many RMAN strategies, but tune to SLA and restore throughput."
  fi

  if [[ "$(backup_value log_mode UNKNOWN)" == "ARCHIVELOG" ]]; then
    backup_append_check "$report_file" "OK" "Recoverability" "ARCHIVELOG mode" "log_mode=ARCHIVELOG" "Continue backing archived redo frequently enough to meet RPO."
  else
    backup_append_check "$report_file" "GAP" "Recoverability" "ARCHIVELOG mode" "log_mode=$(backup_value log_mode UNKNOWN)" "Enable ARCHIVELOG if point-in-time/media recovery is required."
  fi

  if backup_is_number "$(backup_value last_archivelog_backup_age_hours UNKNOWN)" && backup_num_le "$(backup_value last_archivelog_backup_age_hours UNKNOWN)" "24"; then
    backup_append_check "$report_file" "OK" "RPO" "Recent archived redo backup" "age_hours=$(backup_display_value "$(backup_value last_archivelog_backup_age_hours)")" "Back up archived redo more frequently than the required backup-only RPO."
  else
    backup_append_check "$report_file" "WARN" "RPO" "Recent archived redo backup" "age_hours=$(backup_display_value "$(backup_value last_archivelog_backup_age_hours UNKNOWN)")" "Increase archived-log backup frequency if backup-only RPO must be less than a day."
  fi

  failed7="$(backup_value failed_jobs_7d 0)"
  failed30="$(backup_value failed_jobs_30d 0)"
  if [[ "$failed7" =~ ^[0-9]+$ && "$failed7" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Reliability" "No failed RMAN jobs in last 7 days" "failed_7d=${failed7}, failed_30d=${failed30}" "Keep alerting on failed backup jobs."
  else
    backup_append_check "$report_file" "WARN" "Reliability" "Failed RMAN jobs" "failed_7d=${failed7}, failed_30d=${failed30}" "Investigate failed backup jobs and confirm they did not break required backup windows."
  fi

  expired="$(backup_value backup_piece_expired_count 0)"
  unavailable="$(backup_value backup_piece_unavailable_count 0)"
  deleted="$(backup_value backup_piece_deleted_count 0)"
  if [[ "$expired" =~ ^[0-9]+$ && "$unavailable" =~ ^[0-9]+$ && "$expired" -eq 0 && "$unavailable" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Repository" "Backup piece status" "available=$(backup_value backup_piece_available_count 0), expired=${expired}, unavailable=${unavailable}, deleted=${deleted}" "Schedule periodic CROSSCHECK and cleanup obsolete/expired records."
  else
    backup_append_check "$report_file" "WARN" "Repository" "Backup piece status" "available=$(backup_value backup_piece_available_count 0), expired=${expired}, unavailable=${unavailable}, deleted=${deleted}" "Run RMAN CROSSCHECK and resolve expired/unavailable pieces before relying on them."
  fi

  controlfile_auto="$(backup_value rman_controlfile_autobackup DEFAULT/OFF)"
  if [[ "$controlfile_auto" == *"ON"* ]]; then
    backup_append_check "$report_file" "OK" "Control file" "Control file autobackup" "$controlfile_auto" "Keep autobackup enabled and test restore controlfile from autobackup."
  else
    backup_append_check "$report_file" "WARN" "Control file" "Control file autobackup" "$controlfile_auto" "Enable CONFIGURE CONTROLFILE AUTOBACKUP ON unless an equivalent control-file/SPFILE backup process exists."
  fi

  recover_files="$(backup_value recover_file_count 0)"
  corruptions="$(( $(backup_value block_corruption_count 0) + $(backup_value copy_corruption_count 0) + $(backup_value backup_corruption_count 0) ))"
  if [[ "$recover_files" =~ ^[0-9]+$ && "$recover_files" -eq 0 && "$corruptions" -eq 0 ]]; then
    backup_append_check "$report_file" "OK" "Validation" "Recovery/corruption views" "recover_files=${recover_files}, corruption_rows=${corruptions}" "Continue scheduled validation and corruption monitoring."
  else
    backup_append_check "$report_file" "GAP" "Validation" "Recovery/corruption views" "recover_files=${recover_files}, corruption_rows=${corruptions}" "Resolve files needing media recovery or corruption rows before further destructive testing."
  fi

  fra_used="$(backup_value fra_used_pct UNKNOWN)"
  if backup_is_number "$fra_used" && backup_num_gt "$fra_used" "85"; then
    backup_append_check "$report_file" "WARN" "FRA" "FRA utilization" "fra_used_pct=${fra_used}" "Increase FRA size or adjust retention/backup deletion to avoid archived-log pressure."
  else
    backup_append_check "$report_file" "OK" "FRA" "FRA utilization" "fra_used_pct=${fra_used}" "Keep FRA capacity monitored against archive generation and retention."
  fi

  retention="$(backup_value rman_retention_policy DEFAULT)"
  append_report_section "$report_file" "Strategy Interpretation And Recommendations"
  {
    printf -- '- Observed strategy: %s.\n' "$strategy"
    printf -- '- RMAN retention policy: `%s`.\n' "$retention"
    printf -- '- Control file record keep time: `%s` days. If no catalog is used, keep this long enough to preserve restore history for your retention window.\n' "$(backup_value control_file_record_keep_time UNKNOWN)"
    printf -- '- Backup repository source: `%s`.\n' "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && printf "Recovery catalog requested; RMAN output below confirms whether it connected successfully." || printf "Target control file only for this report run.")"
    printf -- '- RTO guidance: %s\n' "$rto_hint"
    printf -- '- RPO guidance: %s\n' "$rpo_hint"
    printf -- '- Best-practice direction: run periodic RMAN restore validation, validate selected backups when pieces are suspected missing, keep repository metadata accurate with crosschecks, protect control file/SPFILE backups, and run timed CrashSimulator restore drills to prove actual RTO/RPO.\n'
  } >>"$report_file"

  append_report_section "$report_file" "SQL Backup Repository Details"
  append_report_command "$report_file" "Control-File SQL Backup Evidence" "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$detail_sql"

  write_backup_report_rman_repository_file "$rman_repo_file"
  append_report_rman_cmdfile "$report_file" "RMAN Repository, Restore Preview, Need-Backup, And Obsolete Report" "$rman_repo_file" "$rman_repo_log" || repo_status=$?

  if [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]]; then
    write_backup_report_rman_validate_file "$rman_validate_file"
    append_report_rman_cmdfile "$report_file" "RMAN Deep Validation - Restore Database, Archivelogs, And Logical Database Check" "$rman_validate_file" "$rman_validate_log" || validate_status=$?
  else
    append_report_section "$report_file" "RMAN Deep Validation"
    append_report_text "$report_file" 'Skipped by default. Re-run with `--deep-validate` or set `CRASHSIM_REPORT_DEEP_VALIDATE=1` to run `RESTORE DATABASE VALIDATE`, `RESTORE ARCHIVELOG ALL VALIDATE`, and `VALIDATE DATABASE CHECK LOGICAL`. Those checks are read-only but can be I/O intensive, especially for SBT/Object Storage.'
  fi

  append_report_section "$report_file" "References"
  {
    printf -- '- Oracle Database 19c backup and recovery administration: https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/performing-backup-and-recovery.html\n'
    printf -- '- Oracle Maximum Availability Architecture overview: https://www.oracle.com/database/technologies/maximum-availability-architecture/\n'
    printf -- '- CrashSimulator RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw Backup Evidence"
  {
    printf 'Evidence file: `%s`\n\n' "$evidence_file"
    printf '```text\n'
    sed -n '/^CSIM_BKP|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  echo "Backup strategy and recoverability report generated: ${report_file}"
  echo "Strategy detected: ${strategy}"
  echo "RPO estimate: ${rpo_hint}"
  echo "RTO estimate: ${rto_hint}"
  maybe_render_html "$report_file"
  if [[ "$repo_status" -ne 0 || "$validate_status" -ne 0 ]]; then
    warn "One or more RMAN report/validation sections exited with a non-zero status. Review: ${report_file}"
  fi
}

write_config_report_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write configuration report SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 500 lines 260 trimspool on tab off verify off feedback on
set numwidth 20
column name format a34
column value format a120
column display_value format a120
column file_name format a150
column member format a150
column destination format a120
column error format a120
column handle format a120
column path format a150
column pdb_name format a30
column tablespace_name format a30
column parameter_name format a42
column start_time format a20
column end_time format a20
column completion_time format a20

prompt # SQL Evidence
prompt
prompt ## Database Identity
select name, db_unique_name, dbid, platform_name, database_role, open_mode,
       cdb, log_mode, force_logging, flashback_on, protection_mode,
       switchover_status
from v$database;

prompt ## Instance Identity
select instance_name, host_name, version, status, database_status, active_state,
       parallel, thread#, archiver, to_char(startup_time, 'YYYY-MM-DD HH24:MI:SS') startup_time
from v$instance;

prompt ## Database Version
select banner_full from v$version where banner_full like 'Oracle Database%';

prompt ## Key Paths And Parameters
select name, display_value
from v$parameter
where name in (
  'spfile',
  'control_files',
  'db_name',
  'db_unique_name',
  'db_recovery_file_dest',
  'db_recovery_file_dest_size',
  'db_create_file_dest',
  'db_create_online_log_dest_1',
  'db_create_online_log_dest_2',
  'diagnostic_dest',
  'audit_file_dest',
  'adg_redirect_dml',
  'compatible',
  'cluster_database',
  'remote_login_passwordfile',
  'enable_pluggable_database',
  'local_undo_enabled',
  'wallet_root',
  'tde_configuration'
)
order by name;

prompt ## Non-Default Database Parameters
select name parameter_name, type, isdefault, ismodified, issys_modifiable, ispdb_modifiable, display_value
from v$parameter
where isdefault = 'FALSE'
order by name;

prompt ## Diagnostic And Trace Locations
select name, value from v$diag_info order by name;

prompt ## Control Files
select name from v$controlfile order by name;

prompt ## Redo Log Groups
select l.group#, l.thread#, l.sequence#, round(l.bytes/1024/1024,2) size_mb,
       l.blocksize, l.members, l.archived, l.status
from v$log l
order by l.thread#, l.group#;

prompt ## Redo Log Members
select lf.group#, l.thread#, l.status, lf.type, lf.is_recovery_dest_file, lf.member
from v$logfile lf
join v$log l on l.group# = lf.group#
order by lf.group#, lf.member;

prompt ## Database Size Summary
select 'DATAFILES' component, count(*) file_count, round(sum(bytes)/1024/1024/1024,2) size_gb
from v$datafile
union all
select 'TEMPFILES' component, count(*) file_count, round(nvl(sum(bytes),0)/1024/1024/1024,2) size_gb
from v$tempfile
union all
select 'ONLINE REDO' component, count(*) file_count, round(nvl(sum(bytes),0)/1024/1024/1024,2) size_gb
from v$log;

prompt ## SYSTEM And UNDO Datafiles
select df.file#, ts.name tablespace_name,
       case when ts.name = 'SYSTEM' then 'SYSTEM'
            when ts.name like 'UNDO%' then 'UNDO'
            else 'OTHER'
       end tablespace_class,
       round(df.bytes/1024/1024,2) size_mb,
       df.status, df.enabled, df.name file_name
from v$datafile df
join v$tablespace ts on ts.ts# = df.ts# and ts.con_id = df.con_id
where ts.name = 'SYSTEM'
   or ts.name like 'UNDO%'
order by df.con_id, df.file#;

prompt ## Temporary Files
select tf.file#, ts.name tablespace_name, round(tf.bytes/1024/1024,2) size_mb,
       tf.status, tf.enabled, tf.name file_name
from v$tempfile tf
join v$tablespace ts on ts.ts# = tf.ts# and ts.con_id = tf.con_id
order by tf.con_id, tf.file#;

prompt ## FRA Destination And Usage
select name, round(space_limit/1024/1024/1024,2) space_limit_gb,
       round(space_used/1024/1024/1024,2) space_used_gb,
       round(space_reclaimable/1024/1024/1024,2) space_reclaimable_gb,
       number_of_files
from v$recovery_file_dest;

prompt ## FRA Usage By File Type
select file_type, percent_space_used, percent_space_reclaimable, number_of_files
from v$flash_recovery_area_usage
order by file_type;

prompt ## RMAN Configuration
select name, value from v$rman_configuration order by name;

prompt ## Recent RMAN Backup Jobs
select *
from (
  select session_key, input_type, status,
         to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') start_time,
         to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') end_time,
         elapsed_seconds, output_device_type, input_bytes_display, output_bytes_display
  from v$rman_backup_job_details
  order by start_time desc
)
where rownum <= 40;

prompt ## Backup Set Summary
select *
from (
  select recid backup_set_recid, set_stamp, set_count, backup_type,
         incremental_level, controlfile_included, pieces piece_count,
         to_char(start_time, 'YYYY-MM-DD HH24:MI:SS') start_time,
         to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS') completion_time
  from v$backup_set
  order by completion_time desc
)
where rownum <= 60;

prompt ## Observed Backup Methodology From RMAN History
select nvl(input_type, 'UNKNOWN') input_type, status, count(*) job_count,
       to_char(min(start_time), 'YYYY-MM-DD HH24:MI:SS') first_observed,
       to_char(max(start_time), 'YYYY-MM-DD HH24:MI:SS') last_observed
from v$rman_backup_job_details
where start_time >= sysdate - 60
group by input_type, status
order by input_type, status;

prompt ## Datafile Backup Coverage
select df.file#, df.name file_name,
       to_char(max(bdf.completion_time), 'YYYY-MM-DD HH24:MI:SS') last_backup_time,
       case when max(bdf.completion_time) is null then 'NO BACKUP IN CONTROL FILE METADATA'
            else 'BACKUP METADATA FOUND'
       end backup_status
from v$datafile df
left join v$backup_datafile bdf on bdf.file# = df.file#
group by df.file#, df.name
order by df.file#;

prompt ## Backup Piece Status
select status, device_type, count(*) piece_count,
       to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS') latest_completion
from v$backup_piece
group by status, device_type
order by status, device_type;

prompt ## Recoverability Indicators
select file#, checkpoint_change#, to_char(checkpoint_time, 'YYYY-MM-DD HH24:MI:SS') checkpoint_time,
       unrecoverable_change#, to_char(unrecoverable_time, 'YYYY-MM-DD HH24:MI:SS') unrecoverable_time,
       name
from v$datafile
order by file#;

prompt ## Files Requiring Media Recovery
select * from v$recover_file order by file#;

prompt ## Database Block Corruption
select * from v$database_block_corruption order by file#, block#;

prompt ## Copy Corruption
select * from v$copy_corruption order by file#, block#;

prompt ## Backup Corruption
select * from v$backup_corruption order by file#, block#;

prompt ## Restore Points
select name, scn, time, database_incarnation#, guarantee_flashback_database, storage_size
from v$restore_point
order by time desc;

prompt ## Data Guard Role And FSFO Columns
select database_role, protection_mode, protection_level, switchover_status,
       fs_failover_status, fs_failover_current_target,
       fs_failover_threshold, fs_failover_observer_present
from v$database;

prompt ## Data Guard Destinations
select dest_id, status, target, destination, db_unique_name, valid_now, error
from v$archive_dest
where destination is not null
order by dest_id;

prompt ## Archive Gaps
select * from v$archive_gap;

prompt ## Data Guard Stats
select name, value, unit, time_computed, datum_time
from v$dataguard_stats
order by name;

prompt ## TDE Wallet Status
select * from v$encryption_wallet;

prompt ## Encrypted Tablespaces
select tablespace_name, encrypted
from dba_tablespaces
where encrypted = 'YES'
order by tablespace_name;

prompt ## Encrypted Columns
select owner, table_name, count(*) encrypted_column_count
from dba_encrypted_columns
group by owner, table_name
order by owner, table_name;
SQL

  if [[ "$DB_CDB" == "YES" ]]; then
    cat >>"$sql_file" <<'SQL' || die "Unable to write CDB report SQL file: $sql_file"

prompt ## PDB State And Size
select p.name pdb_name, p.con_id, p.open_mode, p.restricted,
       round(p.total_size/1024/1024/1024,2) total_size_gb,
       to_char(p.open_time, 'YYYY-MM-DD HH24:MI:SS') open_time
from v$pdbs p
order by p.con_id;

prompt ## Datafile Count And Size By Container
select c.name pdb_name, c.con_id, count(df.file#) datafile_count,
       round(nvl(sum(df.bytes),0)/1024/1024/1024,2) datafile_gb,
       round(nvl(tf.temp_bytes,0)/1024/1024/1024,2) tempfile_gb
from v$containers c
left join v$datafile df on df.con_id = c.con_id
left join (
  select con_id, sum(bytes) temp_bytes
  from v$tempfile
  group by con_id
) tf on tf.con_id = c.con_id
group by c.name, c.con_id, tf.temp_bytes
order by c.con_id;

prompt ## Tablespaces By Container
select p.name pdb_name, t.tablespace_name, t.contents, t.status, t.bigfile,
       t.logging, t.extent_management, t.allocation_type, t.segment_space_management,
       round(nvl(df.bytes,0)/1024/1024,2) data_mb,
       round(nvl(tf.bytes,0)/1024/1024,2) temp_mb
from cdb_tablespaces t
join v$containers p on p.con_id = t.con_id
left join (
  select con_id, tablespace_name, sum(bytes) bytes
  from cdb_data_files
  group by con_id, tablespace_name
) df on df.con_id = t.con_id and df.tablespace_name = t.tablespace_name
left join (
  select con_id, tablespace_name, sum(bytes) bytes
  from cdb_temp_files
  group by con_id, tablespace_name
) tf on tf.con_id = t.con_id and tf.tablespace_name = t.tablespace_name
order by p.con_id, t.tablespace_name;

prompt ## Datafiles By Container
select p.name pdb_name, df.file_id, df.tablespace_name,
       round(df.bytes/1024/1024,2) size_mb, df.status, df.online_status,
       df.autoextensible, df.file_name
from cdb_data_files df
join v$containers p on p.con_id = df.con_id
order by p.con_id, df.file_id;

prompt ## Tempfiles By Container
select p.name pdb_name, tf.file_id, tf.tablespace_name,
       round(tf.bytes/1024/1024,2) size_mb, tf.status, tf.autoextensible, tf.file_name
from cdb_temp_files tf
join v$containers p on p.con_id = tf.con_id
order by p.con_id, tf.file_id;

prompt ## Encrypted Tablespaces By Container
select p.name pdb_name, t.tablespace_name, t.encrypted
from cdb_tablespaces t
join v$containers p on p.con_id = t.con_id
where t.encrypted = 'YES'
order by p.con_id, t.tablespace_name;
SQL
  else
    cat >>"$sql_file" <<'SQL' || die "Unable to write non-CDB report SQL file: $sql_file"

prompt ## Tablespaces
select t.tablespace_name, t.contents, t.status, t.bigfile, t.logging,
       t.extent_management, t.allocation_type, t.segment_space_management,
       round(nvl(df.bytes,0)/1024/1024,2) data_mb,
       round(nvl(tf.bytes,0)/1024/1024,2) temp_mb
from dba_tablespaces t
left join (
  select tablespace_name, sum(bytes) bytes
  from dba_data_files
  group by tablespace_name
) df on df.tablespace_name = t.tablespace_name
left join (
  select tablespace_name, sum(bytes) bytes
  from dba_temp_files
  group by tablespace_name
) tf on tf.tablespace_name = t.tablespace_name
order by t.tablespace_name;

prompt ## Datafiles
select file_id, tablespace_name, round(bytes/1024/1024,2) size_mb,
       status, online_status, autoextensible, file_name
from dba_data_files
order by file_id;

prompt ## Tempfiles
select file_id, tablespace_name, round(bytes/1024/1024,2) size_mb,
       status, autoextensible, file_name
from dba_temp_files
order by file_id;
SQL
  fi

  cat >>"$sql_file" <<'SQL' || die "Unable to finish report SQL file: $sql_file"

exit
SQL
}

run_configuration_report() {
  discover_environment
  ensure_sqlplus

  local report_file sql_file generated_at grid_home crsctl_bin asm_sid dgmgrl_bin
  local rman_show_file rman_preview_file rman_restore_validate_file rman_db_validate_file
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  report_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}.md"
  sql_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}.sql"
  rman_show_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_show_all.rman"
  rman_preview_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_restore_preview.rman"
  rman_restore_validate_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_restore_validate.rman"
  rman_db_validate_file="${LOG_DIR}/crashsim_config_report_${RUN_ID}_database_validate.rman"
  write_config_report_sql_file "$sql_file"

  {
    printf "# CrashSimulator Target Database Configuration Report\n\n"
    printf -- '- Generated UTC: `%s`\n' "$generated_at"
    printf -- '- Host: `%s`\n' "$(hostname 2>/dev/null || printf unknown)"
    printf -- '- OS user: `%s`\n' "$(id -un 2>/dev/null || printf unknown)"
    printf -- '- Database: `%s`\n' "${DB_NAME:-unknown}"
    printf -- '- DB unique name: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Instance/SID: `%s`\n' "${INSTANCE_NAME:-${ORACLE_SID:-unknown}}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- CDB: `%s`\n' "${DB_CDB:-unknown}"
    printf -- '- Storage: `%s`\n' "${STORAGE_TYPE:-unknown}"
    printf -- '- Cluster type: `%s`\n' "${CLUSTER_TYPE:-unknown}"
    printf -- '- Oracle home: `%s`\n' "${ORACLE_HOME:-unknown}"
    printf -- '- Deep RMAN validation: `%s`\n' "$([[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && printf enabled || printf disabled)"
    printf -- '- SQL evidence file: `%s`\n' "$sql_file"
    printf "\n"
    printf "Backup and recoverability notes: this report includes RMAN metadata, backup coverage by datafile, corruption views, and an RMAN restore preview. External schedulers or OCI backup policies may need separate inspection when they are not visible in target database RMAN history.\n"
  } >"$report_file" || die "Unable to write report file: $report_file"

  append_report_command "$report_file" "SQL Database, PDB, Storage, Backup, TDE, Data Guard, And Corruption Evidence" \
    "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file"

  append_report_section "$report_file" "RMAN Catalog And Restore Preview"
  {
    printf 'The report invokes RMAN with `target /` only. If the output says it is using the target control file, no recovery catalog was used by this report session. This does not prove that an external scheduler never uses a catalog; it reports what is detectable from the target host/session.\n\n'
  } >>"$report_file"
  ensure_rman
  {
    printf "show all;\n"
    printf "exit\n"
  } >"$rman_show_file" || die "Unable to write RMAN report file: $rman_show_file"
  {
    printf "restore database preview summary;\n"
    printf "exit\n"
  } >"$rman_preview_file" || die "Unable to write RMAN report file: $rman_preview_file"
  append_report_command "$report_file" "RMAN SHOW ALL" "$RMAN_BIN" target / cmdfile="$rman_show_file"
  append_report_command "$report_file" "RMAN RESTORE DATABASE PREVIEW SUMMARY" "$RMAN_BIN" target / cmdfile="$rman_preview_file"
  if [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]]; then
    {
      printf "restore database validate;\n"
      printf "exit\n"
    } >"$rman_restore_validate_file" || die "Unable to write RMAN report file: $rman_restore_validate_file"
    {
      printf "validate database check logical;\n"
      printf "exit\n"
    } >"$rman_db_validate_file" || die "Unable to write RMAN report file: $rman_db_validate_file"
    append_report_command "$report_file" "RMAN RESTORE DATABASE VALIDATE" "$RMAN_BIN" target / cmdfile="$rman_restore_validate_file"
    append_report_command "$report_file" "RMAN VALIDATE DATABASE CHECK LOGICAL" "$RMAN_BIN" target / cmdfile="$rman_db_validate_file"
  else
    append_report_section "$report_file" "Deep RMAN Validation"
    append_report_text "$report_file" 'Skipped by default. Re-run with `--deep-validate` or set `CRASHSIM_REPORT_DEEP_VALIDATE=1` to run RMAN restore/database validation. Those checks are read-only but can be I/O intensive.'
  fi

  append_report_environment "$report_file"
  append_report_command "$report_file" "Host Kernel And Identity" uname -a
  append_report_command "$report_file" "ORACLE_HOME Directory" bash -lc "ls -ld '${ORACLE_HOME:-}' 2>&1; du -sh '${ORACLE_HOME:-}' 2>&1"
  if [[ -n "${ORACLE_HOME:-}" && -x "${ORACLE_HOME}/OPatch/opatch" ]]; then
    append_report_command "$report_file" "OPatch LSPatches" "${ORACLE_HOME}/OPatch/opatch" lspatches
  fi

  if command -v lsnrctl >/dev/null 2>&1; then
    append_report_command "$report_file" "Listener Status" lsnrctl status
    append_report_command "$report_file" "Listener Services" lsnrctl services
  else
    append_report_section "$report_file" "Listener Status"
    append_report_text "$report_file" "lsnrctl was not found in PATH."
  fi
  append_network_config_files "$report_file"

  if command -v srvctl >/dev/null 2>&1; then
    if [[ -n "$DB_UNIQUE_NAME" ]]; then
      append_report_command "$report_file" "srvctl config database" srvctl config database -d "$DB_UNIQUE_NAME"
      append_report_command "$report_file" "srvctl status database" srvctl status database -d "$DB_UNIQUE_NAME"
      append_report_command "$report_file" "srvctl config services" srvctl config service -d "$DB_UNIQUE_NAME"
      append_report_command "$report_file" "srvctl status services" srvctl status service -d "$DB_UNIQUE_NAME"
    fi
    append_report_command "$report_file" "srvctl config asm" srvctl config asm
    append_report_command "$report_file" "srvctl status asm" srvctl status asm
  fi

  if command -v crsctl >/dev/null 2>&1; then
    append_report_command "$report_file" "Grid Infrastructure CRS Check" crsctl check crs
    append_report_command "$report_file" "Grid Infrastructure Resource Status" crsctl stat res -t
    append_report_command "$report_file" "Voting Disk Status" crsctl query css votedisk
  fi
  if command -v ocrcheck >/dev/null 2>&1; then
    append_report_command "$report_file" "OCR Check" ocrcheck
  fi
  if command -v ocrconfig >/dev/null 2>&1; then
    append_report_command "$report_file" "OCR Backups" ocrconfig -showbackup
  fi

  crsctl_bin="$(command -v crsctl 2>/dev/null || true)"
  if [[ -n "$crsctl_bin" ]]; then
    grid_home="$(cd "$(dirname "$crsctl_bin")/.." >/dev/null 2>&1 && pwd || true)"
    if [[ -n "$grid_home" && -x "${grid_home}/bin/asmcmd" ]]; then
      asm_sid="${CRASHSIM_ASM_SID:-}"
      [[ -n "$asm_sid" ]] || asm_sid="$(detect_asm_sid_from_process || true)"
      [[ -n "$asm_sid" ]] || asm_sid="+ASM"
      append_report_command "$report_file" "ASM Disk Groups" env ORACLE_HOME="$grid_home" ORACLE_SID="$asm_sid" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/asmcmd" lsdg
      append_report_command "$report_file" "ASM SPFILE" env ORACLE_HOME="$grid_home" ORACLE_SID="$asm_sid" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/asmcmd" spget
    fi
  elif command -v asmcmd >/dev/null 2>&1; then
    append_report_command "$report_file" "ASM Disk Groups" run_asmcmd_with_grid_env lsdg
    append_report_command "$report_file" "ASM SPFILE" run_asmcmd_with_grid_env spget
  fi

  dgmgrl_bin="$(find_dgmgrl_bin)"
  if [[ -n "$dgmgrl_bin" && -x "$dgmgrl_bin" ]]; then
    append_report_command "$report_file" "Data Guard Broker Configuration" bash -lc "printf 'show configuration verbose;\nshow fast_start failover;\nexit\n' | \"${dgmgrl_bin}\" -silent /"
  else
    append_report_section "$report_file" "Data Guard Broker Configuration"
    append_report_text "$report_file" "dgmgrl was not found in ORACLE_HOME/bin or PATH. SQL Data Guard/FSFO evidence is still included above."
  fi

  echo "Configuration report generated: ${report_file}"
  maybe_render_html "$report_file"
}

print_recovery_runbook() {
  local id="$1"

  echo "Recovery runbook hints:"
  cat <<'RUNBOOK'
  - Capture evidence first: alert log, trace files, Data Guard/RAC status, RMAN output, and exact error stack.
  - Confirm scope: CDB root vs PDB, file number/name, tablespace, redo group/thread, database role, and storage backend.
  - Prefer restoring from known-good backups or copies; do not reuse files corrupted by the scenario.
  - Record RTO/RPO timestamps: fault injection, detection, restore start, recovery complete, application validation.
RUNBOOK

  case "$id" in
    1|2|23)
      cat <<'RUNBOOK'
  - Control file loss/corruption:
    1. If one multiplexed control file remains, shut down, copy it to the missing location, then start the database.
    2. If all control files are lost, start NOMOUNT and restore a control file from autobackup or a known copy:
       rman target /
       startup nomount;
       restore controlfile from autobackup;
       alter database mount;
       catalog start with '<fra_or_backup_location>' noprompt;
       recover database;
    3. If a backup control file was used, expect OPEN RESETLOGS after recovery.
    4. Recreate multiplexing and verify CONTROL_FILES, V$CONTROLFILE, and alert log health.
RUNBOOK
      ;;
    3|4|18|19|20|21|24)
      cat <<'RUNBOOK'
  - Redo log loss/corruption:
    1. Identify thread/group/member status in V$LOG and V$LOGFILE before choosing a recovery action.
    2. For lost inactive groups, practice ALTER DATABASE CLEAR LOGFILE GROUP <group#> when appropriate.
    3. For active/current redo loss, expect crash/incomplete-recovery decisions; validate whether backups plus archived redo meet RPO.
    4. In RAC, include THREAD# and instance ownership. In Data Guard, consider failover/switchover if primary current redo is unrecoverable.
    5. Recreate multiplexed members and force several log switches after recovery.
RUNBOOK
      ;;
    5|8|9|10|12|15|22|59|62)
      cat <<'RUNBOOK'
  - Non-SYSTEM datafile/tablespace or archived-log recovery:
    1. Identify FILE#, TABLESPACE_NAME, CHECKPOINT_CHANGE#, and ONLINE_STATUS from V$DATAFILE, DBA_DATA_FILES, and V$RECOVER_FILE.
    2. If the database can stay open, offline the affected datafile or tablespace.
    3. Restore and recover the datafile/tablespace:
       rman target /
       sql "alter database datafile <file#> offline";
       restore datafile <file#>;
       recover datafile <file#>;
       sql "alter database datafile <file#> online";
    4. For missing archived redo, restore the archived log first or decide whether incomplete recovery is acceptable.
    5. Validate with RMAN VALIDATE, V$DATABASE_BLOCK_CORRUPTION, application checks, and a fresh backup.
RUNBOOK
      ;;
    6|13|31|38)
      cat <<'RUNBOOK'
  - Temporary file/tablespace loss:
    1. Tempfiles usually do not require media recovery.
    2. Drop the missing tempfile metadata if needed, then add a new tempfile to the temporary tablespace.
    3. Confirm DBA_TEMP_FILES, V$TEMPFILE, temp tablespace defaults, and representative sort/temp workloads.
RUNBOOK
      ;;
    7|14|17)
      cat <<'RUNBOOK'
  - SYSTEM/all-datafile database recovery:
    1. Expect MOUNT-mode recovery for SYSTEM or whole-database datafile loss.
    2. Restore and recover with RMAN:
       rman target /
       startup mount;
       restore database;
       recover database;
       alter database open;
    3. If incomplete recovery is required, document the chosen UNTIL SCN/TIME and use OPEN RESETLOGS.
    4. Validate dictionary health, components, invalid objects, listener/services, and take a new baseline backup.
RUNBOOK
      ;;
    11|36)
      cat <<'RUNBOOK'
  - Non-unique index loss:
    1. Identify dropped indexes from DDL repository, recycle bin/flashback metadata, schema export, or application deployment scripts.
    2. Rebuild with CREATE INDEX or application DDL. For unusable indexes, use ALTER INDEX ... REBUILD.
    3. Gather statistics if needed and validate execution plans for affected queries.
RUNBOOK
      ;;
    16)
      cat <<'RUNBOOK'
  - Password file loss:
    1. Recreate with orapwd for standalone filesystem deployments, matching password format/version requirements.
    2. For srvctl-managed databases, update Clusterware metadata if the password-file path changes.
    3. In Data Guard/RAC, synchronize password files across required nodes/standbys.
    4. Test local and remote SYSDBA authentication, redo transport, and broker connectivity.
RUNBOOK
      ;;
    25|29|60|61)
      cat <<'RUNBOOK'
  - Backup/FRA/catalog loss:
    1. Run CROSSCHECK and LIST BACKUP/ARCHIVELOG to separate missing local files from object-storage/catalog metadata.
    2. Restore missing local autobackups or backup pieces from secondary/object storage if available.
    3. If FRA was moved/lost, recreate the directory, permissions, and DB_RECOVERY_FILE_DEST capacity.
    4. For FRA pressure/full drills, restore DB_RECOVERY_FILE_DEST_SIZE, free reclaimable space safely, and confirm archiving resumes.
    5. For catalog outage, practice NOCATALOG recovery using control-file metadata, then resync when the catalog returns.
    6. Finish by running RESTORE VALIDATE DATABASE and taking a fresh backup.
RUNBOOK
      ;;
    26)
      cat <<'RUNBOOK'
  - SPFILE loss:
    1. If the instance is still up, create a pfile from memory or from the surviving spfile location.
    2. If down, rebuild a pfile from alert-log parameter history and known configuration.
    3. Start with pfile, create spfile from pfile, then restart normally.
    4. For RAC/ASM, ensure srvctl and ASM metadata point to the restored SPFILE.
RUNBOOK
      ;;
    27|57)
      cat <<'RUNBOOK'
  - SQL*Net/listener config loss:
    1. Restore listener.ora, tnsnames.ora, sqlnet.ora, and wallet/network includes from config backup or automation.
    2. Reload or restart listener: lsnrctl reload/start.
    3. Validate local bequeath, service registration, client TNS aliases, SCAN/VIP names if clustered, and Data Guard transport aliases.
RUNBOOK
      ;;
    28)
      cat <<'RUNBOOK'
  - ORACLE_HOME loss:
    1. Restore or reinstall the same Oracle Home version/RU and one-off patch level.
    2. Reattach inventory if needed, validate OPatch inventory, relink binaries if required.
    3. Restore network/admin, dbs password/SPFILE links, wallet/client config, and custom scripts.
    4. Start database/listener and run datapatch sanity checks if the home was rebuilt.
RUNBOOK
      ;;
    30|32|33|34|35|37|39|40|41|42)
      cat <<'RUNBOOK'
  - PDB datafile/tablespace recovery:
    1. Identify target PDB, FILE#, tablespace, and whether local undo is enabled.
    2. Close the affected PDB if needed:
       alter pluggable database <pdb_name> close immediate;
    3. Restore/recover at PDB or datafile granularity:
       rman target /
       restore pluggable database <pdb_name>;
       recover pluggable database <pdb_name>;
       sql "alter pluggable database <pdb_name> open";
    4. For single datafiles, restore/recover DATAFILE <file#> where possible.
    5. Validate PDB open mode, application services, invalid objects, and PDB-local backup posture.
RUNBOOK
      ;;
    43)
      cat <<'RUNBOOK'
  - PDB table loss:
    1. Try FLASHBACK TABLE if recycle bin/flashback requirements are met.
    2. Otherwise recover via Data Pump import, table-level RMAN recovery, PDB PITR clone, or application DDL/data reload.
    3. Validate dependent indexes, constraints, grants, triggers, statistics, and application row counts.
RUNBOOK
      ;;
    44)
      cat <<'RUNBOOK'
  - PDB schema loss:
    1. Prefer Data Pump schema import if exports are part of the DR design.
    2. Otherwise practice PDB point-in-time recovery to an auxiliary location and extract/import the schema.
    3. Recreate grants, synonyms, jobs, scheduler objects, statistics, and application credentials.
RUNBOOK
      ;;
    45)
      cat <<'RUNBOOK'
  - Dropped PDB recovery:
    1. If unplug metadata exists, evaluate plug-in recovery paths; otherwise use RMAN/PITR or restore the CDB to recover the PDB.
    2. Practice RESTORE PLUGGABLE DATABASE and RECOVER PLUGGABLE DATABASE where backups support it.
    3. Recreate services, open modes, save state, local users, wallets, and application connectivity.
RUNBOOK
      ;;
    46|49|72)
      cat <<'RUNBOOK'
  - ASM disk, disk group, or SPFILE recovery:
    1. Use asmcmd/SQL to inspect disk group mount state, redundancy, failgroups, missing/offline disks, and rebalance operations.
    2. For single-disk failure, confirm redundancy is still intact, monitor ASM rebalance, and restore/replace/drop/add the disk according to lab design.
    3. Restore ASM metadata/SPFILE from backup or OCR/srvctl metadata where applicable.
    4. Mount disk groups, then validate database files and Clusterware resources.
    5. For FEX/ACFS-style @... managed storage, use provider-approved storage controls, validate GI/database services, and collect provider redundancy/rebuild evidence before allowing destructive execution.
RUNBOOK
      ;;
    47|48)
      cat <<'RUNBOOK'
  - OCR/voting disk recovery:
    1. Capture crsctl query css votedisk and ocrcheck output before repair.
    2. Practice OCR restore from automatic backup and voting disk replacement per Grid Infrastructure version.
    3. Validate CRS stack, node membership, database resources, services, and post-recovery backups.
RUNBOOK
      ;;
    50|67)
      cat <<'RUNBOOK'
  - Standby apply cancelled or apply-lag simulation:
    1. Restart managed recovery:
       alter database recover managed standby database disconnect from session;
    2. If using broker, set apply state through DGMGRL and validate configuration.
    3. Monitor V$DATAGUARD_STATS, V$ARCHIVE_DEST_STATUS, alert log, and apply lag until caught up.
    4. Compare actual lag duration against RPO/SLA and confirm alerting detected the breach.
RUNBOOK
      ;;
    51|52|54|68)
      cat <<'RUNBOOK'
  - Data Guard transport/broker/snapshot drill:
    1. Restore transport state, then force a log switch on the primary.
    2. Validate broker configuration with DGMGRL SHOW CONFIGURATION and SHOW DATABASE VERBOSE.
    3. Monitor transport/apply lag, archive gaps, protection mode, and FSFO observer state if enabled.
RUNBOOK
      ;;
    66)
      cat <<'RUNBOOK'
  - FSFO observer unavailable:
    1. Confirm FSFO status, observer location, failover target, threshold, and protection mode with DGMGRL and V$DATABASE.
    2. Stop or isolate only the observer in an approved lab; do not break primary-standby redo transport unless that is a separate scenario.
    3. Validate broker warnings, failover expectations, monitoring alerts, and observer restart procedure.
    4. Restart the observer and confirm FSFO returns to the expected synchronized/ready state.
RUNBOOK
      ;;
    69)
      cat <<'RUNBOOK'
  - Standby redo log misconfiguration:
    1. Compare online redo groups and sizes per thread against standby redo logs.
    2. Add SRLs so each thread has at least online redo group count plus one, with SRLs at least as large as online redo.
    3. In RAC, validate every redo thread and every standby site.
    4. Force log switches, confirm real-time apply, and validate Data Guard broker status after changes.
RUNBOOK
      ;;
    53)
      cat <<'RUNBOOK'
  - Active Data Guard read-only pressure:
    1. Confirm the standby remains read-only with apply, and distinguish query pressure from apply lag.
    2. Validate services, resource manager limits, session cleanup, and lag metrics.
RUNBOOK
      ;;
    55|56|70|71)
      cat <<'RUNBOOK'
  - RAC instance/service recovery:
    1. Check crsctl stat res -t, srvctl status database, srvctl status service, and alert logs on all nodes.
    2. Restart the failed instance, relocate VIP/services, or start services with srvctl as appropriate.
    3. Validate FAN/ONS, TAF/Application Continuity/TAC behavior, connection pool response, and service placement after recovery.
    4. For VIP drills, validate SCAN/VIP listener behavior and client retry timing from outside the cluster.
RUNBOOK
      ;;
    58)
      cat <<'RUNBOOK'
  - TDE wallet/keystore loss:
    1. Restore wallet/keystore files from secure backup, preserving permissions and wallet_root layout.
    2. Open the keystore and validate encrypted tablespaces/backups.
    3. In RAC/Data Guard, synchronize wallet material to every required node/site and test redo apply.
RUNBOOK
      ;;
    63)
      cat <<'RUNBOOK'
  - TEMP exhaustion:
    1. Confirm which SQL, module, user, or PDB consumed TEMP from V$TEMPSEG_USAGE and ASH/AWR evidence where licensed.
    2. Relieve pressure by stopping the runaway workload, adding TEMP capacity, or adjusting workload/resource manager limits.
    3. Validate temporary tablespace defaults, tempfile autoextend/maxsize posture, and alerts for ORA-01652.
    4. Clean up disposable lab objects and confirm representative reporting/ETL workloads can complete.
RUNBOOK
      ;;
    64|65)
      cat <<'RUNBOOK'
  - RTO/RPO validation drill:
    1. Supply realistic objectives with --maa-local-rto/--maa-local-rpo, --maa-dr-rto/--maa-dr-rpo, or guided MAA/SLA context.
    2. For RTO, run a scenario recovery first so CrashSimulator has measured recovery start/complete timestamps.
    3. For RPO, review archived redo, backed-up archived redo, Data Guard lag, and archive-gap evidence.
    4. Treat PASS/FAIL as an operational drill result, then update backup cadence, Data Guard transport/apply, monitoring, and runbooks.
RUNBOOK
      ;;
    83|84|87)
      cat <<'RUNBOOK'
  - Service continuity, AC/TAC, FAN/ONS, and role-service validation:
    1. Inventory service attributes from SQL and srvctl before changing anything.
    2. Confirm application drivers/pools support FAN, Transaction Guard, AC/TAC, and service drain behavior.
    3. Run replay/notification tests with a replay-safe client workload and capture application-visible behavior.
    4. For Data Guard role services, validate service placement before and after an approved role transition.
RUNBOOK
      ;;
    85|86)
      cat <<'RUNBOOK'
  - Data Guard switchover/failback:
    1. Validate Broker configuration, lag, SRLs, flashback, protection mode, and service role placement before transition.
    2. Communicate the planned window, drain services, run DGMGRL validation, and capture pre-transition evidence.
    3. Execute switchover/failback only in an approved lab or change window.
    4. Validate new roles, apply, services, applications, monitoring, backups, and the path back to the original topology.
RUNBOOK
      ;;
    88)
      cat <<'RUNBOOK'
  - PDB point-in-time recovery:
    1. Choose an exact recovery timestamp/SCN and confirm backups plus archived redo cover it.
    2. Allocate an auxiliary destination with enough free space and run RMAN preview before recovery.
    3. Recover only the intended PDB, validate open state, services, application data, and invalid objects.
    4. Take a fresh backup after successful PITR and document RTO/RPO.
RUNBOOK
      ;;
    89|90)
      cat <<'RUNBOOK'
  - Restore point and patch rollback readiness:
    1. Confirm Flashback Database, FRA headroom, recent backups, restore points, and Data Guard/app service posture.
    2. Create a guaranteed restore point only for an approved change window and monitor FRA growth.
    3. Validate rollback in a lab, including OPEN RESETLOGS consequences where applicable.
    4. Drop restore points only after fallback closure and a new backup baseline.
RUNBOOK
      ;;
    EXA01|EXA02|EXA03|EXA04)
      cat <<'RUNBOOK'
  - Exadata platform drill:
    1. Collect cell, ASM, database, service, and workload evidence before any platform fault.
    2. Use an Exadata-approved lab and tooling path; do not simulate storage/cell faults from generic OS commands.
    3. Validate rebalance/repair, database service continuity, Smart Scan/Flash Cache behavior, and application impact.
RUNBOOK
      ;;
    OCI01|OCI02|OCI03|OCI04|OCI05)
      cat <<'RUNBOOK'
  - OCI Base Database Service drill:
    1. Capture OCI control-plane, DBaaS tooling, RMAN, network, service, and wallet evidence.
    2. Keep cloud fault injection inside an approved compartment/VCN/lab boundary with rollback commands prepared.
    3. Validate backups, cross-region restore, DB system recovery, DNS/VCN/NSG behavior, and application reconnect.
RUNBOOK
      ;;
    GG01|GG02|GG03|GG04)
      cat <<'RUNBOOK'
  - GoldenGate drill:
    1. Inventory deployment, Extract, Replicat, trail, checkpoint, heartbeat, and lag evidence.
    2. Confirm source/target consistency checks and resync path before stopping processes or manipulating trails.
    3. Validate lag alerts, restart/catch-up behavior, trail recovery, and application/data consistency after the drill.
RUNBOOK
      ;;
    73|79)
      cat <<'RUNBOOK'
  - ORDS service or ORDS node outage:
    1. Confirm user impact with the ORDS/APEX smoke URL, load balancer URL if present, and application-specific APEX page checks.
    2. Restart the affected ORDS service with systemctl, then validate service status, logs, and HTTP response.
    3. In RAC or multi-node ORDS, confirm the load balancer removed/added the node as expected and sessions behaved acceptably.
    4. Capture timing for detection, restart, application availability, and any required user retry/relogin.
RUNBOOK
      ;;
    74|75)
      cat <<'RUNBOOK'
  - ORDS configuration loss or pool misconfiguration:
    1. Restore the ORDS configuration directory, wallets, pool settings, and static-file mappings from a known-good backup.
    2. Validate database service name, credentials, wallet/TLS settings, connection pool sizing, and PL/SQL gateway mode.
    3. Restart ORDS and test the ORDS landing page, APEX application URL, SQL Developer Web if enabled, and logs.
    4. Keep ORDS config backups synchronized across ORDS nodes and document credential rotation steps.
RUNBOOK
      ;;
    76)
      cat <<'RUNBOOK'
  - APEX/ORDS runtime account locked:
    1. Identify whether APEX_PUBLIC_USER, ORDS_PUBLIC_USER, or ORDS_METADATA is locked/expired in the target PDB.
    2. Unlock the account or rotate credentials according to policy, then update ORDS config if passwords changed.
    3. Restart ORDS if credential changes require it and validate APEX/ORDS URL access.
    4. Capture audit evidence for who changed the account and why.
RUNBOOK
      ;;
    77)
      cat <<'RUNBOOK'
  - APEX static resources unavailable:
    1. Restore the APEX images/static directory or ORDS static mapping from backup.
    2. Confirm ownership, permissions, context path such as /i/, and ORDS config static resource settings.
    3. Validate APEX pages for CSS, JavaScript, images, login, and application runtime behavior.
RUNBOOK
      ;;
    78|80)
      cat <<'RUNBOOK'
  - APEX application/session availability:
    1. Validate the ORDS landing page and a real APEX application URL after database/PDB/ORDS recovery.
    2. For session continuity, keep an active test session open during ORDS, RAC service, Data Guard, or database recovery drills.
    3. When possible, use the seeded browser-session driver with a disposable APEX app and a stable success selector such as #CRASHSIM_SESSION_OK.
    4. Record whether users see retry, relogin, lost state, failed transaction, or seamless continuation.
    5. Feed findings into service AC/TAC, FAN/ONS, pool retry, and APEX session timeout design.
RUNBOOK
      ;;
    81)
      cat <<'RUNBOOK'
  - APEX mail queue/configuration validation:
    1. Review SMTP host/port/wallet parameters, network ACLs, and TLS certificate dependencies.
    2. Validate notification delivery after PDB recovery, wallet restore, ORDS restart, and network changes.
    3. Capture failed mail queue evidence and document the operational restart/resubmit procedure.
RUNBOOK
      ;;
    82)
      cat <<'RUNBOOK'
  - APEX upgrade or patch rollback readiness:
    1. Capture APEX version, component status, invalid objects, runtime users, ORDS version/config, and static-file version before changes.
    2. Take database and ORDS config/static-file backups before patching.
    3. After patch or rollback, validate APEX registry, invalid objects, workspaces/apps, ORDS URL, and representative applications.
    4. Document cutover, rollback decision points, and evidence required by change control.
RUNBOOK
      ;;
    *)
      cat <<'RUNBOOK'
  - Generic recovery:
    1. Identify failed component and choose restore/recreate/failover based on RTO/RPO.
    2. Validate database consistency and application behavior.
    3. Capture lessons learned and update backups, monitoring, and runbooks.
RUNBOOK
      ;;
  esac
}

add_action() {
  local kind="$1"
  local target="$2"
  local detail="${3:-}"
  ACTION_KINDS+=("$kind")
  ACTION_TARGETS+=("$target")
  ACTION_DETAILS+=("$detail")
}

reset_actions() {
  ACTION_KINDS=()
  ACTION_TARGETS=()
  ACTION_DETAILS=()
}

print_actions() {
  local kind target detail
  local i=1
  local idx
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    detail="${ACTION_DETAILS[$idx]}"
    printf "%2d. %-14s %s" "$i" "$kind" "$target"
    if [[ -n "$detail" ]]; then
      printf " (%s)" "$detail"
    fi
    printf "\n"
    i=$((i + 1))
  done
}

execute_actions() {
  if [[ "${#ACTION_KINDS[@]}" -eq 0 ]]; then
    die "No targets were found for this scenario."
  fi

  echo "Planned actions:"
  print_actions
  echo
  if [[ "$PLANNING_ONLY" -eq 1 ]]; then
    return "$SUCCESS"
  fi
  if [[ "$PLANNING_ONLY" -eq 0 ]]; then
    record_action_targets
  fi

  local has_external=0
  local external_idx
  for external_idx in "${!ACTION_KINDS[@]}"; do
    if [[ "${ACTION_KINDS[$external_idx]}" == "external" ]]; then
      has_external=1
      break
    fi
  done

  if [[ "$EXECUTE" -eq 0 ]]; then
    if [[ "$has_external" -eq 1 ]]; then
      info "DRY-RUN complete. One or more targets require a provider-specific handler before execution."
      return "$SUCCESS"
    fi
    info "DRY-RUN complete. Re-run with --execute to perform these actions."
    return "$SUCCESS"
  fi
  [[ "$has_external" -eq 0 ]] ||
    die "One or more planned targets require a provider-specific handler and cannot be executed safely yet."

  local kind target detail idx
  for idx in "${!ACTION_KINDS[@]}"; do
    kind="${ACTION_KINDS[$idx]}"
    target="${ACTION_TARGETS[$idx]}"
    detail="${ACTION_DETAILS[$idx]}"
    case "$kind" in
      fs_rename)
        perform_fs_rename "$target"
        ;;
      fs_corrupt_header)
        perform_fs_corrupt "$target" 1 1
        ;;
      fs_corrupt_body)
        perform_fs_corrupt "$target" 1 30
        ;;
      asm_rm|asm_tempfile_rm)
        perform_asm_rm "$target"
        ;;
      asm_corrupt_header)
        perform_asm_rm "$target"
        ;;
      sql)
        run_sql_action "$detail" "$target"
        ;;
      sqlfile)
        run_sql_script_file "$target" "$detail"
        ;;
      report)
        echo "Report action: ${target} ${detail}"
        ;;
      srvctl_abort_instance)
        perform_srvctl_abort_instance "$target"
        ;;
      srvctl_abort_database)
        perform_srvctl_abort_database
        ;;
      srvctl_relocate_service)
        perform_srvctl_relocate_service "$target" "$detail"
        ;;
      srvctl_stop_start_service_instance)
        perform_srvctl_stop_start_service_instance "$target" "$detail"
        ;;
      systemctl_stop_service)
        perform_systemctl_service_action stop "$target"
        ;;
      systemctl_start_service)
        perform_systemctl_service_action start "$target"
        ;;
      ords_priv_config_rename)
        perform_ords_priv_config_rename "$target"
        ;;
      ords_pool_bad_service)
        perform_ords_pool_bad_service
        ;;
      external)
        die "External target requires a provider-specific handler and was not executed: $target"
        ;;
      *)
        die "Unknown action kind: $kind"
        ;;
    esac
  done
}

perform_asm_rm() {
  local path="$1"
  [[ "$(storage_path_class "$path")" == "asm" ]] || die "ASM remove action received a non-ASM path: $path"
  echo "asmcmd rm $path (Grid owner: ${GRID_USER})"
  run_asmcmd_with_grid_env rm "$path" ||
    die "Unable to remove ASM file with asmcmd: $path"
}

perform_systemctl_service_action() {
  local action="$1"
  local service="$2"
  local method

  [[ -n "$service" ]] || die "No systemd service name was supplied."

  case "$action" in
    start|stop|restart|status) ;;
    *) die "Unsupported systemctl action: $action" ;;
  esac

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run systemctl ${action} ${service}"
    return "$SUCCESS"
  fi

  method="$(ords_control_method || true)"
  if [[ "$method" == "systemctl" ]]; then
    command -v systemctl >/dev/null 2>&1 || die "systemctl was not found."
    echo "systemctl ${action} ${service}"
    systemctl "$action" "$service" ||
      die "systemctl ${action} ${service} failed."
  elif [[ "$method" == "ords_priv_helper" ]]; then
    run_ords_priv_helper service "$action" "$service" ||
      die "approved ORDS helper service ${action} ${service} failed."
  elif [[ "$method" == "sudo_systemctl" ]]; then
    echo "sudo -n systemctl ${action} ${service}"
    sudo -n systemctl "$action" "$service" ||
      die "sudo systemctl ${action} ${service} failed."
  else
    die "systemctl ${action} ${service} requires root or passwordless sudo for the current OS user."
  fi
}

ords_config_get_value() {
  local key="$1"
  local output
  command -v ords >/dev/null 2>&1 || return "$FAIL"
  output="$(ords --config "$ORDS_CONFIG_DIR" config get "$key" 2>/dev/null | trim_blank_lines || true)"
  printf "%s" "$output" | tail -n 1
}

ords_config_set_value() {
  local key="$1"
  local value="$2"
  command -v ords >/dev/null 2>&1 || return "$FAIL"
  echo "ords --config ${ORDS_CONFIG_DIR} config set ${key} ${value}"
  ords --config "$ORDS_CONFIG_DIR" config set "$key" "$value" >/dev/null
}

perform_ords_pool_bad_service() {
  local original_service bad_service state

  [[ -d "$ORDS_CONFIG_DIR" ]] || die "ORDS config directory not found: $ORDS_CONFIG_DIR"
  can_control_ords_service || die "ORDS pool drill requires approved ORDS service restart privileges."
  command -v curl >/dev/null 2>&1 || die "curl was not found; cannot validate ORDS pool outage evidence."

  original_service="$(ords_config_get_value db.servicename)"
  [[ -n "$original_service" ]] || die "Could not read ORDS db.servicename from ${ORDS_CONFIG_DIR}."
  bad_service="CRASHSIM_BAD_SERVICE_${RUN_ID}"

  manifest_append "ords_config_dir" "$ORDS_CONFIG_DIR"
  manifest_append "ords_db_pool" "$ORDS_DB_POOL"
  manifest_append "ords_pool_original_servicename" "$original_service"
  manifest_append "ords_pool_bad_servicename" "$bad_service"
  manifest_append "ords_service_name" "$ORDS_SERVICE_NAME"

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would set ORDS db.servicename from ${original_service} to ${bad_service}"
    echo "DRY-RUN: would restart ORDS service ${ORDS_SERVICE_NAME}"
    echo "DRY-RUN: would validate ${ORDS_URL} is affected, then recover with --recover 75"
    return "$SUCCESS"
  fi

  ords_config_set_value db.servicename "$bad_service" ||
    die "Unable to set ORDS db.servicename to lab-bad value."
  perform_systemctl_service_action restart "$ORDS_SERVICE_NAME"

  if curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1; then
    state="reachable"
    warn "ORDS smoke URL remained reachable after pool misconfiguration; review whether the URL exercises the changed pool."
  else
    state="outage-confirmed"
  fi
  manifest_append "ords_pool_fault_state" "$state"
  echo "ORDS pool misconfiguration state: ${state}"
}

perform_ords_priv_config_rename() {
  local path="$1"
  local backup="${path}.${RUN_ID}.crashsim.bak"

  [[ "$path" == "$ORDS_CONFIG_DIR" ]] ||
    die "Approved ORDS config rename only supports the configured ORDS config directory: ${ORDS_CONFIG_DIR}"
  ords_priv_helper_config_available ||
    die "Approved ORDS config helper is not available for ${path}."

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run approved helper config-rename $path $backup"
    return "$SUCCESS"
  fi

  run_ords_priv_helper config-rename "$path" "$backup" ||
    die "Unable to rename ORDS config with approved helper: $path"
  RENAME_COUNT=$((RENAME_COUNT + 1))
  manifest_append "rename_${RENAME_COUNT}_original" "$path"
  manifest_append "rename_${RENAME_COUNT}_backup" "$backup"
  manifest_append "rename_${RENAME_COUNT}_method" "ords_priv_config_rename"
}

perform_fs_rename() {
  local path="$1"
  if storage_path_is_provider_managed "$path"; then
    die "$(storage_path_provider_reason "$path" "crash injection")."
  fi
  [[ -e "$path" ]] || die "Target does not exist: $path"
  local backup="${path}.${RUN_ID}.crashsim.bak"
  echo "mv -- $path $backup"
  mv -- "$path" "$backup"
  RENAME_COUNT=$((RENAME_COUNT + 1))
  manifest_append "rename_${RENAME_COUNT}_original" "$path"
  manifest_append "rename_${RENAME_COUNT}_backup" "$backup"
  manifest_append "rename_${RENAME_COUNT}_method" "rename"
}

backup_before_corrupt() {
  local path="$1"
  local backup="${path}.${RUN_ID}.crashsim.bak"
  [[ -e "$path" ]] || die "Target does not exist: $path"
  echo "cp -p -- $path $backup"
  cp -p -- "$path" "$backup" || die "Unable to create scenario backup before corruption: $backup"
  RENAME_COUNT=$((RENAME_COUNT + 1))
  manifest_append "rename_${RENAME_COUNT}_original" "$path"
  manifest_append "rename_${RENAME_COUNT}_backup" "$backup"
  manifest_append "rename_${RENAME_COUNT}_method" "copy_before_corrupt"
}

perform_fs_corrupt() {
  local path="$1"
  local seek_blocks="$2"
  local count_blocks="$3"
  if storage_path_is_provider_managed "$path"; then
    die "$(storage_path_provider_reason "$path" "corruption handling")."
  fi
  [[ -e "$path" ]] || die "Target does not exist: $path"
  backup_before_corrupt "$path"
  echo "dd if=/dev/zero of=$path bs=8192 seek=$seek_blocks count=$count_blocks conv=notrunc"
  dd if=/dev/zero of="$path" bs=8192 seek="$seek_blocks" count="$count_blocks" conv=notrunc
}

perform_srvctl_abort_instance() {
  local instance="$1"
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl stop instance -d $DB_UNIQUE_NAME -i $instance -o abort"
  srvctl stop instance -d "$DB_UNIQUE_NAME" -i "$instance" -o abort
}

perform_srvctl_abort_database() {
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl stop database -d $DB_UNIQUE_NAME -o abort"
  srvctl stop database -d "$DB_UNIQUE_NAME" -o abort
}

perform_srvctl_relocate_service() {
  local service="$1"
  local detail="$2"
  local old_inst new_inst
  IFS='|' read -r old_inst new_inst <<<"$detail"
  [[ -n "$service" && -n "$old_inst" && -n "$new_inst" ]] ||
    die "Service relocation action is missing service/source/target metadata."
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl relocate service -d $DB_UNIQUE_NAME -s $service -oldinst $old_inst -newinst $new_inst"
  srvctl relocate service -d "$DB_UNIQUE_NAME" -s "$service" -oldinst "$old_inst" -newinst "$new_inst"
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service"
}

perform_srvctl_stop_start_service_instance() {
  local service="$1"
  local instance="$2"
  [[ -n "$service" && -n "$instance" ]] ||
    die "Service stop/start action is missing service or instance metadata."
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  echo "srvctl stop service -d $DB_UNIQUE_NAME -s $service -i $instance"
  srvctl stop service -d "$DB_UNIQUE_NAME" -s "$service" -i "$instance"
  echo "srvctl start service -d $DB_UNIQUE_NAME -s $service -i $instance"
  srvctl start service -d "$DB_UNIQUE_NAME" -s "$service" -i "$instance"
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service"
}

discover_pmon_spid() {
  local output_file="$WORK_DIR/pmon_spid.out"
  sql_query "$output_file" "
select p.spid
from v\$bgprocess b
join v\$process p on p.addr = b.paddr
where b.name = 'PMON'
  and p.spid is not null;
" || return "$FAIL"
  trim_blank_lines <"$output_file" | head -n 1 | tr -d ' '
}

abort_target_instance() {
  if [[ "$PLANNING_ONLY" -eq 1 ]]; then
    return "$SUCCESS"
  fi

  if [[ "$EXECUTE" -eq 0 ]]; then
    info "DRY-RUN: would abort target instance ${INSTANCE_NAME}"
    return "$SUCCESS"
  fi

  if [[ "$CLUSTER_TYPE" == "RAC" || "$INSTANCE_PARALLEL" == "YES" ]]; then
    perform_srvctl_abort_instance "$INSTANCE_NAME"
    return "$SUCCESS"
  fi

  local pmon_pattern="ora_pmon_${ORACLE_SID:-$INSTANCE_NAME}"
  local pid
  pid="$(discover_pmon_spid || true)"
  if [[ -z "$pid" ]]; then
    pid="$(pgrep -f "$pmon_pattern" | head -n 1 || true)"
  fi
  [[ -n "$pid" ]] || die "Could not find PMON for ${ORACLE_SID:-$INSTANCE_NAME}"
  echo "kill -9 $pid (PMON ${ORACLE_SID:-$INSTANCE_NAME})"
  kill -9 "$pid"
}

query_targets() {
  local file="$1"
  local sql_text="$2"
  sql_query "$file" "$sql_text"
  load_rows "$file"
}

add_fs_rename_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" || "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "crash injection")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "crash injection")"
    fi
  done
}

add_datafile_loss_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" ]]; then
      add_action "asm_rm" "$row" "ASM datafile loss via asmcmd rm"
    elif [[ "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "datafile loss injection")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "datafile loss injection")"
    fi
  done
}

add_tempfile_loss_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" ]]; then
      add_action "asm_tempfile_rm" "$row" "ASM tempfile loss via asmcmd rm"
    elif [[ "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "tempfile loss injection")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "tempfile loss injection")"
    fi
  done
}

add_fs_corrupt_targets() {
  local kind="$1"
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" || "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "corruption handling")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "$kind" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "corruption handling")"
    fi
  done
}

add_datafile_header_corrupt_targets() {
  local row class
  for row in "${TARGET_ROWS[@]}"; do
    class="$(storage_path_class "$row")"
    if [[ "$class" == "asm" ]]; then
      add_action "asm_corrupt_header" "$row" "ASM header-corruption surrogate: remove ASM datafile and recover FILE#"
    elif [[ "$class" == "fex" ]]; then
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "header-corruption handling")"
    elif storage_path_is_local_filesystem "$row"; then
      add_action "fs_corrupt_header" "$row"
    else
      add_action "external" "$row" "$(storage_path_provider_reason "$row" "header-corruption handling")"
    fi
  done
}

query_nonpdb_datafiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  query_targets "$file" "
select file_name
from (
  select df.file_name
  from dba_data_files df
  join dba_tablespaces ts on ts.tablespace_name = df.tablespace_name
  where ${where_clause}
  order by df.file_id
)
${limit_clause};
"
}

query_nonpdb_tempfiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  query_targets "$file" "
select file_name
from (
  select tf.file_name
  from dba_temp_files tf
  join dba_tablespaces ts on ts.tablespace_name = tf.tablespace_name
  where ${where_clause}
  order by tf.file_id
)
${limit_clause};
"
}

query_pdb_datafiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_targets "$file" "
select file_name
from (
  select df.file_name
  from cdb_data_files df
  join cdb_tablespaces ts
    on ts.con_id = df.con_id
   and ts.tablespace_name = df.tablespace_name
  join v\$pdbs p on p.con_id = df.con_id
  where p.name = ${pdb_literal}
    and ${where_clause}
  order by df.file_id
)
${limit_clause};
"
}

query_pdb_tempfiles() {
  local file="$1"
  local where_clause="$2"
  local limit_clause="${3:-}"
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_targets "$file" "
select file_name
from (
  select tf.file_name
  from cdb_temp_files tf
  join cdb_tablespaces ts
    on ts.con_id = tf.con_id
   and ts.tablespace_name = tf.tablespace_name
  join v\$pdbs p on p.con_id = tf.con_id
  where p.name = ${pdb_literal}
    and ${where_clause}
  order by tf.file_id
)
${limit_clause};
"
}

query_all_datafiles() {
  local file="$1"
  if [[ "$DB_CDB" == "YES" ]]; then
    query_targets "$file" "
select name
from v\$datafile
order by con_id, file#;
"
  else
    query_targets "$file" "
select name
from v\$datafile
order by file#;
"
  fi
}

one_row() {
  echo "where rownum = 1"
}

scenario_control_one() {
  reset_actions
  query_targets "$WORK_DIR/control_one.lst" "
select name
from (select name from v\$controlfile order by name)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_control_all() {
  reset_actions
  query_targets "$WORK_DIR/control_all.lst" "
select name from v\$controlfile order by name;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_redo_member_one() {
  reset_actions
  local id="${1:-$CURRENT_SCENARIO_ID}"
  local status_filter="and 1 = 1"
  local status_rank="case l.status when 'INACTIVE' then 1 when 'ACTIVE' then 2 when 'CURRENT' then 3 else 4 end"

  if [[ "$id" == "3" ]]; then
    status_filter="and l.status = 'CURRENT'"
    status_rank="1"
  fi

  query_targets "$WORK_DIR/redo_member_one.lst" "
select member
from (
  select lf.member
  from v\$log l
  join v\$logfile lf on lf.group# = l.group#
  where l.group# in (
    select group#
    from v\$logfile
    group by group#
    having count(*) > 1
  )
  ${status_filter}
  order by ${status_rank}, lf.group#, lf.member
)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_current_redo_all() {
  reset_actions
  query_targets "$WORK_DIR/current_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'CURRENT'
order by lf.group#, lf.member;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_inactive_redo_all() {
  reset_actions
  query_targets "$WORK_DIR/inactive_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'INACTIVE'
order by lf.group#, lf.member;
"
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_active_redo_all() {
  reset_actions
  run_sql_action "switch logfile before active redo selection" "alter system switch logfile;"
  if [[ "$EXECUTE" -eq 0 ]]; then
    query_targets "$WORK_DIR/active_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'CURRENT'
order by lf.group#, lf.member;
"
  else
    query_targets "$WORK_DIR/active_redo_all.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'ACTIVE'
order by lf.group#, lf.member;
"
  fi
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_non_system_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/non_system_one.lst" \
    "ts.contents = 'PERMANENT' and df.tablespace_name not in ('SYSTEM','SYSAUX')" \
    "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_temp_one() {
  reset_actions
  query_nonpdb_tempfiles "$WORK_DIR/temp_one.lst" "1 = 1" "$(one_row)"
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_system_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/system_one.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_undo_one() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/undo_one.lst" "ts.contents = 'UNDO'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_readonly_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/readonly_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where status = 'READ ONLY'
      and contents = 'PERMANENT'
      and tablespace_name not in ('SYSTEM','SYSAUX')
    order by case
               when tablespace_name = 'CRASHSIM_ROOT_RO_TBS' then 0
               when tablespace_name like 'CRASHSIM%' then 1
               else 2
             end,
             tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_indexonly_tbs() {
  reset_actions
  query_targets "$WORK_DIR/indexonly_tbs.lst" "
with index_ts as (
  select tablespace_name
  from dba_indexes
  where tablespace_name is not null
  group by tablespace_name
),
table_ts as (
  select tablespace_name
  from dba_tables
  where tablespace_name is not null
  group by tablespace_name
),
target_ts as (
  select tablespace_name
  from (
    select i.tablespace_name
    from index_ts i
    left join table_ts t on t.tablespace_name = i.tablespace_name
    where t.tablespace_name is null
      and i.tablespace_name not in ('SYSTEM','SYSAUX')
    order by case
               when i.tablespace_name = 'CRASHSIM_ROOT_INDEX_TBS' then 0
               when i.tablespace_name like 'CRASHSIM%' then 1
               else 2
             end,
             i.tablespace_name
  )
  where rownum = 1
)
select df.file_name
from dba_data_files df
join target_ts t on t.tablespace_name = df.tablespace_name
order by df.file_id;
"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_drop_indexes() {
  reset_actions
  local owner_filter="and (i.owner like 'CRASHSIM%' or i.owner like 'C##CRASHSIM%')"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and i.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
  query_targets "$WORK_DIR/drop_indexes.lst" "
select owner || '.' || index_name
from (
  select i.owner, i.index_name
  from dba_indexes i
  join dba_users u on u.username = i.owner
  where i.uniqueness = 'NONUNIQUE'
    and i.owner not in ('SYS','SYSTEM')
    and u.oracle_maintained = 'N'
    ${owner_filter}
  order by i.owner, i.index_name
)
where rownum <= 20;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No non-unique user index candidate was found. Re-run seed_crashsim_lab.sql or use --schema for a lab schema."
  local sql_text="
begin
  for rec in (
    select i.owner, i.index_name
    from dba_indexes i
    join dba_users u on u.username = i.owner
    where i.uniqueness = 'NONUNIQUE'
      and i.owner not in ('SYS','SYSTEM')
      and u.oracle_maintained = 'N'
      ${owner_filter}
      and rownum <= 20
  ) loop
    execute immediate 'drop index \"' || rec.owner || '\".\"' || rec.index_name || '\"';
  end loop;
end;
/
"
  add_action "sql" "$sql_text" "drop non-unique indexes (${#TARGET_ROWS[@]} candidates)"
  execute_actions
}

scenario_non_system_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/non_system_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where contents = 'PERMANENT'
      and tablespace_name not in ('SYSTEM','SYSAUX')
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_temp_tbs() {
  reset_actions
  query_nonpdb_tempfiles "$WORK_DIR/temp_tbs.lst" "
tf.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where contents = 'TEMPORARY'
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_system_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/system_tbs.lst" "df.tablespace_name = 'SYSTEM'" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_undo_tbs() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/undo_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select tablespace_name
    from dba_tablespaces
    where contents = 'UNDO'
    order by tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_password_file() {
  reset_actions
  local path="$PASSWORD_FILE_PATH"
  if [[ -z "$path" && -n "${ORACLE_HOME:-}" && -n "${ORACLE_SID:-}" ]]; then
    if [[ -f "${ORACLE_HOME}/dbs/orapw${ORACLE_SID}" ]]; then
      path="${ORACLE_HOME}/dbs/orapw${ORACLE_SID}"
    elif [[ -f "${ORACLE_HOME}/dbs/orapw${DB_NAME}" ]]; then
      path="${ORACLE_HOME}/dbs/orapw${DB_NAME}"
    fi
  fi
  [[ -n "$path" ]] || die "Password file path was not discovered."
  TARGET_ROWS=("$path")
  add_fs_rename_targets
  execute_actions
}

scenario_all_datafiles() {
  reset_actions
  query_all_datafiles "$WORK_DIR/all_datafiles.lst"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_file_header_corrupt() {
  reset_actions
  query_nonpdb_datafiles "$WORK_DIR/file_header_corrupt.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_header_corrupt_targets
  execute_actions
  abort_target_instance
}

scenario_control_corrupt() {
  reset_actions
  query_targets "$WORK_DIR/control_corrupt.lst" "
select name from v\$controlfile order by name;
"
  add_fs_corrupt_targets "fs_corrupt_body"
  execute_actions
  abort_target_instance
}

scenario_redo_corrupt() {
  reset_actions
  run_sql_action "switch logfile before redo corruption selection" "alter system switch logfile;"
  if [[ "$EXECUTE" -eq 0 ]]; then
    query_targets "$WORK_DIR/redo_corrupt.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'CURRENT'
order by lf.group#, lf.member;
"
  else
    query_targets "$WORK_DIR/redo_corrupt.lst" "
select lf.member
from v\$log l
join v\$logfile lf on lf.group# = l.group#
where l.status = 'ACTIVE'
order by lf.group#, lf.member;
"
  fi
  add_fs_corrupt_targets "fs_corrupt_body"
  execute_actions
  abort_target_instance
}

scenario_rman_backups() {
  reset_actions
  local where_clause="status = 'A' and handle is not null"
  local limit_clause=""
  local piece_literal

  if [[ -n "$PIECE_HANDLE" ]]; then
    piece_literal="$(sql_quote "$PIECE_HANDLE")"
    where_clause="${where_clause} and handle = ${piece_literal}"
  fi
  if [[ "$LOCAL_ONLY" -eq 1 ]]; then
    where_clause="${where_clause} and handle like '/%'"
  fi
  if [[ -n "$MAX_TARGETS" ]]; then
    limit_clause="where rownum <= ${MAX_TARGETS}"
  fi

  if [[ "$EXECUTE" -eq 1 ]]; then
    if [[ -z "$PIECE_HANDLE" ]]; then
      [[ "$LOCAL_ONLY" -eq 1 ]] ||
        die "Scenario 25 execution requires --local-only or --piece-handle."
      [[ -n "$MAX_TARGETS" ]] ||
        die "Scenario 25 execution with --local-only also requires --max-targets <n>."
    fi
  fi

  manifest_append "scenario_25_local_only" "$LOCAL_ONLY"
  manifest_append "scenario_25_max_targets" "$MAX_TARGETS"
  manifest_append "scenario_25_piece_handle" "$PIECE_HANDLE"

  query_targets "$WORK_DIR/rman_backup_pieces.lst" "
select handle
from (
  select handle
  from v\$backup_piece
  where ${where_clause}
  order by completion_time nulls last, recid
)
${limit_clause};
"
  local row
  for row in "${TARGET_ROWS[@]}"; do
    if [[ "$row" == /* ]]; then
      add_action "fs_rename" "$row"
    else
      add_action "external" "$row" "non-filesystem RMAN backup piece"
    fi
  done
  if [[ "$EXECUTE" -eq 1 ]]; then
    local idx
    for idx in "${!ACTION_KINDS[@]}"; do
      [[ "${ACTION_KINDS[$idx]}" == "fs_rename" ]] ||
        die "Scenario 25 execution can only operate on local filesystem backup pieces. Non-local handle: ${ACTION_TARGETS[$idx]}"
    done
  fi
  execute_actions
}

scenario_spfile() {
  reset_actions
  [[ -n "$SPFILE_PATH" ]] || die "SPFILE path was not discovered."
  TARGET_ROWS=("$SPFILE_PATH")
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_sqlnet() {
  reset_actions
  local net_dir="${TNS_ADMIN:-${ORACLE_HOME:-}/network/admin}"
  [[ -d "$net_dir" ]] || die "Network admin directory was not found: $net_dir"
  TARGET_ROWS=()
  local file
  for file in listener.ora tnsnames.ora sqlnet.ora; do
    if [[ -f "${net_dir}/${file}" ]]; then
      TARGET_ROWS+=("${net_dir}/${file}")
    fi
  done
  add_fs_rename_targets
  execute_actions
}

scenario_oracle_home() {
  reset_actions
  [[ -n "${ORACLE_HOME:-}" && -d "$ORACLE_HOME" ]] || die "ORACLE_HOME was not found."
  TARGET_ROWS=("$ORACLE_HOME")
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_fra() {
  reset_actions
  [[ -n "$FRA_PATH" ]] || die "FRA is not configured."
  TARGET_ROWS=("$FRA_PATH")
  add_fs_rename_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_non_system_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_non_system_one.lst" \
    "ts.contents = 'PERMANENT' and df.tablespace_name not in ('SYSTEM','SYSAUX')" \
    "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_temp_one() {
  reset_actions
  query_pdb_tempfiles "$WORK_DIR/pdb_temp_one.lst" "1 = 1" "$(one_row)"
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_system_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_system_one.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_undo_one() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_undo_one.lst" "ts.contents = 'UNDO'" "$(one_row)"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_readonly_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_pdb_datafiles "$WORK_DIR/pdb_readonly_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select ts.tablespace_name
    from cdb_tablespaces ts
    join v\$pdbs p on p.con_id = ts.con_id
    where p.name = ${pdb_literal}
      and ts.status = 'READ ONLY'
    order by ts.tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_indexonly_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_targets "$WORK_DIR/pdb_indexonly_tbs.lst" "
with target_pdb as (
  select con_id from v\$pdbs where name = ${pdb_literal}
),
index_ts as (
  select tablespace_name
  from cdb_indexes
  where con_id = (select con_id from target_pdb)
    and tablespace_name is not null
  group by tablespace_name
),
table_ts as (
  select tablespace_name
  from cdb_tables
  where con_id = (select con_id from target_pdb)
    and tablespace_name is not null
  group by tablespace_name
),
target_ts as (
  select i.tablespace_name
  from index_ts i
  left join table_ts t on t.tablespace_name = i.tablespace_name
  where t.tablespace_name is null
    and i.tablespace_name not in ('SYSTEM','SYSAUX')
    and rownum = 1
)
select df.file_name
from cdb_data_files df
join target_pdb p on p.con_id = df.con_id
join target_ts t on t.tablespace_name = df.tablespace_name
order by df.file_id;
"
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_drop_indexes() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and i.owner like 'CRASHSIM%'"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and i.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
  local target_file="$WORK_DIR/pdb_drop_indexes.lst"
  sql_query "$target_file" "
alter session set container = ${pdb};
select owner || '.' || index_name
from (
  select i.owner, i.index_name
  from dba_indexes i
  join dba_users u on u.username = i.owner
  where i.uniqueness = 'NONUNIQUE'
    and i.owner not in ('SYS','SYSTEM')
    and u.oracle_maintained = 'N'
    ${owner_filter}
  order by i.owner, i.index_name
)
where rownum <= 20;
alter session set container = CDB\$ROOT;
"
  load_rows "$target_file"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No PDB non-unique user index candidate was found. Re-run seed_crashsim_lab.sql or use --schema for a lab schema."
  local sql_text="
alter session set container = ${pdb};
begin
  for rec in (
    select i.owner, i.index_name
    from dba_indexes i
    join dba_users u on u.username = i.owner
    where i.uniqueness = 'NONUNIQUE'
      and i.owner not in ('SYS','SYSTEM')
      and u.oracle_maintained = 'N'
      ${owner_filter}
      and rownum <= 20
  ) loop
    execute immediate 'drop index \"' || rec.owner || '\".\"' || rec.index_name || '\"';
  end loop;
end;
/
alter session set container = CDB\$ROOT;
"
  add_action "sql" "$sql_text" "drop PDB non-unique indexes (${#TARGET_ROWS[@]} candidates)"
  execute_actions
}

scenario_pdb_non_system_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_pdb_datafiles "$WORK_DIR/pdb_non_system_tbs.lst" "
df.tablespace_name = (
  select tablespace_name
  from (
    select ts.tablespace_name
    from cdb_tablespaces ts
    join v\$pdbs p on p.con_id = ts.con_id
    where p.name = ${pdb_literal}
      and ts.contents = 'PERMANENT'
      and ts.tablespace_name not in ('SYSTEM','SYSAUX')
    order by ts.tablespace_name
  )
  where rownum = 1
)" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_temp_tbs() {
  reset_actions
  local pdb_literal
  pdb_literal="$(sql_quote "$TARGET_PDB")"
  query_pdb_tempfiles "$WORK_DIR/pdb_temp_tbs.lst" "
tf.tablespace_name = (
  select tablespace_name
  from (
    select ts.tablespace_name
    from cdb_tablespaces ts
    join v\$pdbs p on p.con_id = ts.con_id
    where p.name = ${pdb_literal}
      and ts.contents = 'TEMPORARY'
    order by ts.tablespace_name
  )
  where rownum = 1
)" ""
  add_tempfile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_system_tbs() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_system_tbs.lst" "df.tablespace_name = 'SYSTEM'" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_undo_tbs() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_undo_tbs.lst" "ts.contents = 'UNDO'" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_all_datafiles() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_all_datafiles.lst" "1 = 1" ""
  add_datafile_loss_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_file_header_corrupt() {
  reset_actions
  query_pdb_datafiles "$WORK_DIR/pdb_file_header_corrupt.lst" "df.tablespace_name = 'SYSTEM'" "$(one_row)"
  add_datafile_header_corrupt_targets
  execute_actions
  abort_target_instance
}

scenario_pdb_drop_table() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and t.owner like 'CRASHSIM%'"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and t.owner = $(sql_quote "$TARGET_SCHEMA")"
  fi
  local target_file="$WORK_DIR/pdb_drop_table.lst"
  sql_query "$target_file" "
alter session set container = ${pdb};
select owner || '|' || table_name
from (
  select t.owner, t.table_name
  from dba_tables t
  join dba_users u on u.username = t.owner
  where t.owner not in ('SYS','SYSTEM')
    and u.oracle_maintained = 'N'
    and t.nested = 'NO'
    and t.temporary = 'N'
    and t.secondary = 'N'
    ${owner_filter}
  order by t.owner, t.table_name
)
where rownum = 1;
alter session set container = CDB\$ROOT;
"
  load_rows "$target_file"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No PDB user table candidate was found."
  local owner table_name
  IFS='|' read -r owner table_name <<<"${TARGET_ROWS[0]}"
  local owner_sql table_sql
  owner_sql="$(sql_identifier "$owner")"
  table_sql="$(sql_identifier "$table_name")"
  local sql_text="
alter session set container = ${pdb};
drop table ${owner_sql}.${table_sql} purge;
alter session set container = CDB\$ROOT;
"
  add_action "sql" "$sql_text" "drop PDB table ${owner}.${table_name}"
  execute_actions
}

scenario_pdb_drop_schema() {
  reset_actions
  local pdb="$TARGET_PDB"
  local owner_filter="and username like 'CRASHSIM%'"
  if [[ -n "$TARGET_SCHEMA" ]]; then
    owner_filter="and username = $(sql_quote "$TARGET_SCHEMA")"
  fi
  local target_file="$WORK_DIR/pdb_drop_schema.lst"
  sql_query "$target_file" "
alter session set container = ${pdb};
select username
from (
  select username
  from dba_users
  where oracle_maintained = 'N'
    and username not in ('SYS','SYSTEM')
    and account_status not like 'LOCKED%'
    ${owner_filter}
  order by username
)
where rownum = 1;
alter session set container = CDB\$ROOT;
"
  load_rows "$target_file"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No PDB user schema candidate was found."
  local username username_sql
  username="${TARGET_ROWS[0]}"
  username_sql="$(sql_identifier "$username")"
  local sql_text="
alter session set container = ${pdb};
drop user ${username_sql} cascade;
alter session set container = CDB\$ROOT;
"
  add_action "sql" "$sql_text" "drop PDB schema ${username}"
  execute_actions
}

scenario_drop_pdb() {
  reset_actions
  local pdb="$TARGET_PDB"
  [[ "$pdb" != "CDB\$ROOT" && "$pdb" != "PDB\$SEED" ]] || die "Refusing to drop protected container: $pdb"
  [[ "$pdb" == CRASHSIM_* ]] ||
    die "Refusing to drop non-disposable PDB '${pdb}'. Scenario 45 requires a PDB name starting with CRASHSIM_."
  local sql_text="
alter pluggable database ${pdb} close immediate instances=all;
drop pluggable database ${pdb} including datafiles;
"
  add_action "sql" "$sql_text" "drop selected PDB including datafiles"
  execute_actions
}

redact_rman_catalog_connect() {
  local value="$1"
  if [[ -z "$value" ]]; then
    printf "not configured"
    return "$SUCCESS"
  fi
  printf "%s" "$value" | sed -E 's#([^/@[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#'
}

write_recovery_catalog_check_rman() {
  local cmd_file="$1"
  cat >"$cmd_file" <<RMAN || die "Unable to write recovery catalog RMAN file: $cmd_file"
connect catalog ${RMAN_CATALOG_CONNECT}
resync catalog;
list incarnation;
report schema;
exit
RMAN
  chmod 600 "$cmd_file" 2>/dev/null || true
}

write_recovery_catalog_fallback_rman() {
  local cmd_file="$1"
  cat >"$cmd_file" <<'RMAN' || die "Unable to write NOCATALOG fallback RMAN file: $cmd_file"
list incarnation;
report schema;
list backup summary;
restore database preview summary;
exit
RMAN
  chmod 600 "$cmd_file" 2>/dev/null || true
}

print_redacted_rman_log() {
  local log_file="$1"
  sed -E 's#(connect catalog [^/[:space:]]+/)[^@[:space:]]+@#\1<redacted>@#Ig' "$log_file"
}

scenario_recovery_catalog_unavailable() {
  reset_actions
  local redacted catalog_cmd catalog_log fallback_cmd fallback_log
  redacted="$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"
  catalog_cmd="${LOG_DIR}/crashsim_s60_${RUN_ID}_catalog_check.rman"
  catalog_log="${LOG_DIR}/crashsim_s60_${RUN_ID}_catalog_check.log"
  fallback_cmd="${LOG_DIR}/crashsim_s60_${RUN_ID}_nocatalog_fallback.rman"
  fallback_log="${LOG_DIR}/crashsim_s60_${RUN_ID}_nocatalog_fallback.log"

  echo "Recovery catalog drill"
  echo "Catalog connect string: ${redacted}"
  echo "Purpose: validate catalog resync/reporting, then validate target-control-file NOCATALOG fallback."
  echo

  manifest_append "rman_catalog_configured" "$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo yes || echo no)"
  manifest_append "rman_catalog_connect_redacted" "$redacted"
  manifest_append "rman_catalog_check_cmdfile" "$catalog_cmd"
  manifest_append "rman_catalog_check_log" "$catalog_log"
  manifest_append "rman_nocatalog_fallback_cmdfile" "$fallback_cmd"
  manifest_append "rman_nocatalog_fallback_log" "$fallback_log"

  if [[ -z "$RMAN_CATALOG_CONNECT" ]]; then
    echo "No recovery catalog connect string was supplied."
    echo "Set --rman-catalog or CRASHSIM_RMAN_CATALOG to validate the catalog phase."
    if [[ "$EXECUTE" -eq 0 ]]; then
      echo "DRY-RUN: would still validate NOCATALOG fallback against the target control file."
      return "$SUCCESS"
    fi
    ensure_rman
    write_recovery_catalog_fallback_rman "$fallback_cmd"
    "$RMAN_BIN" target / cmdfile="$fallback_cmd" log="$fallback_log" ||
      die "RMAN NOCATALOG fallback validation failed: $fallback_log"
    cat "$fallback_log"
    return "$SUCCESS"
  fi

  if [[ "$EXECUTE" -eq 0 ]]; then
    echo "DRY-RUN: would run RMAN target / with catalog connect string ${redacted}"
    echo "DRY-RUN: would run resync catalog, list incarnation, and report schema."
    echo "DRY-RUN: would run RMAN target / without catalog for fallback list/report/restore preview."
    return "$SUCCESS"
  fi

  ensure_rman
  write_recovery_catalog_check_rman "$catalog_cmd"
  write_recovery_catalog_fallback_rman "$fallback_cmd"

  "$RMAN_BIN" target / cmdfile="$catalog_cmd" log="$catalog_log" ||
    die "RMAN recovery catalog validation failed: $catalog_log"
  print_redacted_rman_log "$catalog_log"

  "$RMAN_BIN" target / cmdfile="$fallback_cmd" log="$fallback_log" ||
    die "RMAN NOCATALOG fallback validation failed: $fallback_log"
  cat "$fallback_log"
}

iso_to_epoch() {
  local value="$1"
  local epoch=""
  [[ -n "$value" ]] || return "$FAIL"
  epoch="$(date -u -d "$value" +%s 2>/dev/null || true)"
  if [[ -z "$epoch" ]]; then
    epoch="$(date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$value" +%s 2>/dev/null || true)"
  fi
  [[ "$epoch" =~ ^[0-9]+$ ]] || return "$FAIL"
  printf "%s\n" "$epoch"
}

duration_to_seconds() {
  local raw="$1"
  local text number unit
  text="$(printf "%s" "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$text" in
    ""|not\ supplied) return "$FAIL" ;;
    zero|near\ zero|near-zero) printf "0\n"; return "$SUCCESS" ;;
  esac
  number="$(printf "%s" "$text" | sed -nE 's/^[^0-9]*([0-9]+([.][0-9]+)?).*/\1/p' | head -n 1)"
  [[ -n "$number" ]] || return "$FAIL"
  if printf "%s" "$text" | grep -Eq 'day|d\b'; then
    unit=86400
  elif printf "%s" "$text" | grep -Eq 'hour|hr|h\b'; then
    unit=3600
  elif printf "%s" "$text" | grep -Eq 'minute|min|m\b'; then
    unit=60
  else
    unit=1
  fi
  awk -v n="$number" -v u="$unit" 'BEGIN {printf "%d\n", int(n*u + 0.999)}'
}

format_seconds() {
  local seconds="$1"
  [[ "$seconds" =~ ^[0-9]+$ ]] || { printf "%s" "$seconds"; return "$SUCCESS"; }
  local days hours mins secs remainder
  days=$((seconds / 86400))
  remainder=$((seconds % 86400))
  hours=$((remainder / 3600))
  remainder=$((remainder % 3600))
  mins=$((remainder / 60))
  secs=$((remainder % 60))
  if [[ "$days" -gt 0 ]]; then
    printf "%sd %sh %sm %ss" "$days" "$hours" "$mins" "$secs"
  elif [[ "$hours" -gt 0 ]]; then
    printf "%sh %sm %ss" "$hours" "$mins" "$secs"
  elif [[ "$mins" -gt 0 ]]; then
    printf "%sm %ss" "$mins" "$secs"
  else
    printf "%ss" "$secs"
  fi
}

latest_completed_recovery_manifest() {
  local manifest
  while IFS= read -r manifest; do
    if grep -q '^recovery_completed_at_utc=' "$manifest" 2>/dev/null; then
      printf "%s\n" "$manifest"
      return "$SUCCESS"
    fi
  done < <(find "$LOG_DIR" -maxdepth 1 -type f -name 'crashsim_recover_s*.manifest' 2>/dev/null | sort -r)
  return "$FAIL"
}

write_rto_validation_report() {
  local report_file="$1"
  local latest_manifest scenario_id scenario_title started completed start_epoch complete_epoch actual_seconds
  local objective label target_seconds status

  latest_manifest="$(latest_completed_recovery_manifest || true)"

  {
    printf "# CrashSimulator RTO Validation Drill\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- Latest completed recovery manifest: `%s`\n\n' "${latest_manifest:-none found}"
    printf '%s\n\n' 'This read-only drill measures actual recovery time from CrashSimulator recovery manifests. It does not infer RTO from backup size alone; it needs a completed `--recover <id> --execute` run to produce a measured result.'
  } >"$report_file" || die "Unable to write RTO validation report: $report_file"

  append_report_section "$report_file" "Measured Recovery"
  {
    printf '| Field | Value |\n'
    printf '| --- | --- |\n'
    if [[ -n "$latest_manifest" ]]; then
      scenario_id="$(awk -F= '$1=="scenario_id"{print $2; exit}' "$latest_manifest")"
      scenario_title="$(awk -F= '$1=="scenario_title"{print $2; exit}' "$latest_manifest")"
      started="$(awk -F= '$1=="recovery_started_at_utc"{print $2; exit}' "$latest_manifest")"
      completed="$(awk -F= '$1=="recovery_completed_at_utc"{print $2; exit}' "$latest_manifest")"
      if start_epoch="$(iso_to_epoch "$started")" && complete_epoch="$(iso_to_epoch "$completed")" && [[ "$complete_epoch" -ge "$start_epoch" ]]; then
        actual_seconds=$((complete_epoch - start_epoch))
      else
        actual_seconds=""
      fi
      printf '| Scenario | `%s - %s` |\n' "$(md_escape "${scenario_id:-unknown}")" "$(md_escape "${scenario_title:-unknown}")"
      printf '| Recovery started | `%s` |\n' "$(md_escape "${started:-unknown}")"
      printf '| Recovery completed | `%s` |\n' "$(md_escape "${completed:-unknown}")"
      if [[ -n "$actual_seconds" ]]; then
        printf '| Actual RTO | `%s` (`%s` seconds) |\n' "$(format_seconds "$actual_seconds")" "$actual_seconds"
      else
        printf '| Actual RTO | `UNKNOWN` |\n'
      fi
    else
      printf '| Actual RTO | `NOT MEASURED` |\n'
      printf '| Reason | No completed CrashSimulator recovery manifest was found. |\n'
    fi
  } >>"$report_file"

  append_report_section "$report_file" "Objective Comparison"
  {
    printf '| Objective | Supplied target | Parsed target | Result |\n'
    printf '| --- | --- | --- | --- |\n'
    for label in \
      "Local unplanned RTO|${MAA_LOCAL_RTO:-}" \
      "Disaster/site RTO|${MAA_DR_RTO:-}" \
      "Planned maintenance RTO|${MAA_PLANNED_RTO:-}"; do
      objective="${label#*|}"
      label="${label%%|*}"
      if target_seconds="$(duration_to_seconds "$objective")"; then
        if [[ -n "${actual_seconds:-}" ]]; then
          if [[ "$actual_seconds" -le "$target_seconds" ]]; then
            status="PASS"
          else
            status="FAIL"
          fi
        else
          status="NOT MEASURED"
        fi
        printf '| %s | `%s` | `%s` (`%s` seconds) | `%s` |\n' \
          "$(md_escape "$label")" "$(md_escape "$objective")" "$(format_seconds "$target_seconds")" "$target_seconds" "$status"
      else
        printf '| %s | `%s` | `not supplied or not parseable` | `INFO` |\n' \
          "$(md_escape "$label")" "$(md_escape "${objective:-not supplied}")"
      fi
    done
  } >>"$report_file"

  append_report_section "$report_file" "Next Steps"
  {
    printf -- '- To create a measured RTO, execute a controlled scenario recovery and then re-run scenario `64`.\n'
    printf -- '- Record application validation separately; database-open time is necessary but not always sufficient for business RTO.\n'
    printf -- '- Use the same scenario repeatedly to trend operational improvement over time.\n'
  } >>"$report_file"
}

write_rpo_validation_sql_file() {
  local sql_file="$1"
  cat >"$sql_file" <<'SQL' || die "Unable to write RPO validation SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 0 lines 32767 trimspool on tab off verify off feedback off heading off

select 'CSIM_RPO|database_role|' || database_role from v$database;
select 'CSIM_RPO|open_mode|' || open_mode from v$database;
select 'CSIM_RPO|current_scn|' || current_scn from v$database;
select 'CSIM_RPO|log_mode|' || log_mode from v$database;
select 'CSIM_RPO|force_logging|' || force_logging from v$database;
select 'CSIM_RPO|flashback_on|' || flashback_on from v$database;
select 'CSIM_RPO|current_time|' || to_char(systimestamp at time zone 'UTC', 'YYYY-MM-DD HH24:MI:SS TZH:TZM') from dual;

select 'CSIM_RPO|latest_archived_log_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';
select 'CSIM_RPO|latest_archived_log_age_seconds|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 86400)), 'UNKNOWN')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';
select 'CSIM_RPO|latest_archived_log_thread_sequence|' ||
       nvl(max(to_char(thread#) || ':' || to_char(sequence#)) keep (dense_rank last order by completion_time), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO';

select 'CSIM_RPO|latest_backed_archivelog_time|' ||
       nvl(to_char(max(completion_time), 'YYYY-MM-DD HH24:MI:SS'), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) > 0;
select 'CSIM_RPO|latest_backed_archivelog_age_seconds|' ||
       nvl(to_char(round((sysdate - max(completion_time)) * 86400)), 'UNKNOWN')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) > 0;
select 'CSIM_RPO|latest_backed_archivelog_thread_sequence|' ||
       nvl(max(to_char(thread#) || ':' || to_char(sequence#)) keep (dense_rank last order by completion_time), 'NONE')
from v$archived_log
where name is not null
  and nvl(deleted, 'NO') = 'NO'
  and nvl(backup_count, 0) > 0;

select 'CSIM_RPO|unbacked_archivelog_count|' || count(*)
from v$archived_log al
where al.name is not null
  and nvl(al.deleted, 'NO') = 'NO'
  and nvl(al.backup_count, 0) = 0;

select 'CSIM_RPO|valid_remote_standby_dest_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and status = 'VALID';
select 'CSIM_RPO|standby_dest_error_count|' || count(*)
from v$archive_dest
where target = 'STANDBY'
  and destination is not null
  and error is not null;
select 'CSIM_RPO|archive_gap_count|' || count(*) from v$archive_gap;
select 'CSIM_RPO|dataguard_transport_lag|' ||
       nvl(max(case when name = 'transport lag' then value end), 'UNKNOWN')
from v$dataguard_stats;
select 'CSIM_RPO|dataguard_apply_lag|' ||
       nvl(max(case when name = 'apply lag' then value end), 'UNKNOWN')
from v$dataguard_stats;

exit
SQL
}

parse_rpo_evidence_file() {
  local evidence_file="$1"
  local prefix key value
  RPO_EVIDENCE=()
  while IFS='|' read -r prefix key value; do
    [[ "$prefix" == "CSIM_RPO" && -n "$key" ]] || continue
    RPO_EVIDENCE["$key"]="${value:-}"
  done <"$evidence_file"
}

rpo_value() {
  local key="$1"
  local default_value="${2:-UNKNOWN}"
  local value="${RPO_EVIDENCE[$key]:-}"
  if [[ -n "$value" ]]; then
    printf "%s" "$value"
  else
    printf "%s" "$default_value"
  fi
}

write_rpo_validation_report() {
  local report_file="$1"
  local evidence_file="$2"
  local backup_age archive_age actual_seconds actual_basis objective label target_seconds status

  backup_age="$(rpo_value latest_backed_archivelog_age_seconds UNKNOWN)"
  archive_age="$(rpo_value latest_archived_log_age_seconds UNKNOWN)"
  if [[ "$backup_age" =~ ^[0-9]+$ ]]; then
    actual_seconds="$backup_age"
    actual_basis="Backup-only RPO based on latest backed-up archived redo."
  elif [[ "$archive_age" =~ ^[0-9]+$ ]]; then
    actual_seconds="$archive_age"
    actual_basis="Control-file archived redo visibility; backup-only RPO was not measurable."
  else
    actual_seconds=""
    actual_basis="No archived redo age was measurable from target control-file evidence."
  fi

  {
    printf "# CrashSimulator RPO Validation Drill\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "$(rpo_value database_role "$DB_ROLE")" "$(rpo_value open_mode "$DB_OPEN_MODE")"
    printf -- '- Evidence file: `%s`\n\n' "$evidence_file"
    printf "This read-only drill estimates the currently recoverable data window from archived redo, archived-redo backup metadata, and Data Guard lag evidence. It is an operational RPO indicator, not a substitute for a timed restore/recovery drill.\n\n"
  } >"$report_file" || die "Unable to write RPO validation report: $report_file"

  append_report_section "$report_file" "Recoverable Data Window"
  {
    printf '| Signal | Value |\n'
    printf '| --- | --- |\n'
    printf '| Actual RPO estimate | `%s` |\n' "$([[ -n "$actual_seconds" ]] && format_seconds "$actual_seconds" || printf UNKNOWN)"
    printf '| Actual RPO seconds | `%s` |\n' "${actual_seconds:-UNKNOWN}"
    printf '| Basis | %s |\n' "$(md_escape "$actual_basis")"
    printf '| Latest archived redo | `%s` sequence `%s`, age `%s` |\n' \
      "$(md_escape "$(rpo_value latest_archived_log_time NONE)")" \
      "$(md_escape "$(rpo_value latest_archived_log_thread_sequence NONE)")" \
      "$(md_escape "$(rpo_value latest_archived_log_age_seconds UNKNOWN)")"
    printf '| Latest backed-up archived redo | `%s` sequence `%s`, age `%s` |\n' \
      "$(md_escape "$(rpo_value latest_backed_archivelog_time NONE)")" \
      "$(md_escape "$(rpo_value latest_backed_archivelog_thread_sequence NONE)")" \
      "$(md_escape "$(rpo_value latest_backed_archivelog_age_seconds UNKNOWN)")"
    printf '| Unbacked archived logs | `%s` |\n' "$(md_escape "$(rpo_value unbacked_archivelog_count UNKNOWN)")"
    printf '| Data Guard destinations | valid `%s`, errors `%s`, archive gaps `%s` |\n' \
      "$(md_escape "$(rpo_value valid_remote_standby_dest_count UNKNOWN)")" \
      "$(md_escape "$(rpo_value standby_dest_error_count UNKNOWN)")" \
      "$(md_escape "$(rpo_value archive_gap_count UNKNOWN)")"
    printf '| Data Guard lag | transport `%s`, apply `%s` |\n' \
      "$(md_escape "$(rpo_value dataguard_transport_lag UNKNOWN)")" \
      "$(md_escape "$(rpo_value dataguard_apply_lag UNKNOWN)")"
  } >>"$report_file"

  append_report_section "$report_file" "Objective Comparison"
  {
    printf '| Objective | Supplied target | Parsed target | Result |\n'
    printf '| --- | --- | --- | --- |\n'
    for label in \
      "Local unplanned RPO|${MAA_LOCAL_RPO:-}" \
      "Disaster/site RPO|${MAA_DR_RPO:-}" \
      "Planned maintenance RPO|${MAA_PLANNED_RPO:-}"; do
      objective="${label#*|}"
      label="${label%%|*}"
      if target_seconds="$(duration_to_seconds "$objective")"; then
        if [[ -n "$actual_seconds" ]]; then
          if [[ "$actual_seconds" -le "$target_seconds" ]]; then
            status="PASS"
          else
            status="FAIL"
          fi
        else
          status="NOT MEASURED"
        fi
        printf '| %s | `%s` | `%s` (`%s` seconds) | `%s` |\n' \
          "$(md_escape "$label")" "$(md_escape "$objective")" "$(format_seconds "$target_seconds")" "$target_seconds" "$status"
      else
        printf '| %s | `%s` | `not supplied or not parseable` | `INFO` |\n' \
          "$(md_escape "$label")" "$(md_escape "${objective:-not supplied}")"
      fi
    done
  } >>"$report_file"

  append_report_section "$report_file" "Raw RPO Evidence"
  {
    printf '```text\n'
    sed -n '/^CSIM_RPO|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"
}

write_fra_pressure_sql_file() {
  local sql_file="$1"
  local original_size="$2"
  local target_size="$3"
  cat >"$sql_file" <<SQL || die "Unable to write FRA pressure SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
prompt FRA usage before pressure change
select name, space_limit, space_used, space_reclaimable, number_of_files
from v\$recovery_file_dest;
alter system set db_recovery_file_dest_size=${target_size} scope=both;
prompt FRA usage after shrinking DB_RECOVERY_FILE_DEST_SIZE
select name, space_limit, space_used,
       round(space_used / nullif(space_limit, 0) * 100, 2) used_pct,
       space_reclaimable, number_of_files
from v\$recovery_file_dest;
declare
begin
  execute immediate 'alter system archive log current';
  dbms_output.put_line('ARCHIVE LOG CURRENT completed. FRA pressure may not be high enough; lower headroom or generate more redo in a lab.');
exception
  when others then
    if sqlcode in (-19809, -19815, -16038, -257) then
      dbms_output.put_line('Expected FRA pressure symptom captured: ' || sqlerrm);
    else
      raise;
    end if;
end;
/
prompt Restore command for recovery helper
prompt alter system set db_recovery_file_dest_size=${original_size} scope=both;
exit
SQL
}

write_fra_restore_sql_file() {
  local sql_file="$1"
  local original_size="$2"
  cat >"$sql_file" <<SQL || die "Unable to write FRA restore SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on pages 100 lines 220
alter system set db_recovery_file_dest_size=${original_size} scope=both;
select name, space_limit, space_used,
       round(space_used / nullif(space_limit, 0) * 100, 2) used_pct,
       space_reclaimable, number_of_files
from v\$recovery_file_dest;
alter system archive log current;
exit
SQL
}

write_temp_exhaustion_sql_file() {
  local sql_file="$1"
  local container_clause="$2"
  local target_mb="$3"
  local rows
  rows=$(( (target_mb * 1024 * 1024 / 3000) + 1 ))
  cat >"$sql_file" <<SQL || die "Unable to write TEMP exhaustion SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set serveroutput on size unlimited feedback on timing on pages 100 lines 220
${container_clause}
prompt TEMP usage before controlled pressure
select tablespace, round(sum(blocks * 8192)/1024/1024, 2) used_mb
from v\$tempseg_usage
group by tablespace
order by tablespace;
declare
  l_rows number := ${rows};
  l_mb number := ${target_mb};
begin
  begin
    execute immediate 'drop table crashsim_temp_pressure purge';
  exception
    when others then
      if sqlcode != -942 then
        raise;
      end if;
  end;

  execute immediate 'create global temporary table crashsim_temp_pressure (id number, payload varchar2(4000)) on commit preserve rows';
  dbms_output.put_line('Attempting controlled TEMP pressure: approximately ' || l_mb || ' MB using ' || l_rows || ' rows.');

  begin
    insert into crashsim_temp_pressure
    select level, rpad('X', 3000, 'X')
    from dual
    connect by level <= l_rows
    order by dbms_random.value;
    dbms_output.put_line('TEMP pressure workload completed without ORA-01652. Increase --temp-exhaust-mb for a stronger lab drill.');
  exception
    when others then
      if sqlcode = -1652 then
        dbms_output.put_line('Expected TEMP exhaustion symptom captured: ' || sqlerrm);
      else
        raise;
      end if;
  end;

  rollback;
  execute immediate 'drop table crashsim_temp_pressure purge';
end;
/
prompt TEMP usage after controlled pressure cleanup
select tablespace, round(sum(blocks * 8192)/1024/1024, 2) used_mb
from v\$tempseg_usage
group by tablespace
order by tablespace;
exit
SQL
}

print_optional_tool_output() {
  local title="$1"
  shift
  echo
  echo "${title}:"
  if "$@" 2>&1 | sed 's/^/  /'; then
    return "$SUCCESS"
  fi
  warn "Unable to collect ${title}."
}

detect_asm_sid_from_process() {
  pgrep -af 'asm_pmon_' 2>/dev/null |
    awk -F'asm_pmon_' 'NF > 1 {print $2; exit}'
}

discover_grid_home_for_tool() {
  local tool="$1"
  local tool_path candidate

  if [[ -n "${CRASHSIM_GRID_HOME:-}" && -x "${CRASHSIM_GRID_HOME}/bin/${tool}" ]]; then
    printf "%s" "$CRASHSIM_GRID_HOME"
    return "$SUCCESS"
  fi

  tool_path="$(command -v "$tool" 2>/dev/null || true)"
  if [[ -n "$tool_path" ]]; then
    candidate="$(cd "$(dirname "$tool_path")/.." >/dev/null 2>&1 && pwd || true)"
    if [[ -n "$candidate" && -x "${candidate}/bin/${tool}" ]]; then
      printf "%s" "$candidate"
      return "$SUCCESS"
    fi
  fi

  for tool_path in \
    "/u01/app/23.0.0.0/gridhome_1/bin/${tool}" \
    "/u01/app/23.0.0.0/grid/bin/${tool}" \
    "/u01/app/grid/product/23.0.0/grid/bin/${tool}" \
    "/u01/app/19.0.0.0/gridhome_1/bin/${tool}" \
    "/u01/app/19.0.0.0/grid/bin/${tool}" \
    "/u01/app/grid/product/19.0.0/grid/bin/${tool}"; do
    if [[ -x "$tool_path" ]]; then
      candidate="$(cd "$(dirname "$tool_path")/.." >/dev/null 2>&1 && pwd || true)"
      if [[ -n "$candidate" ]]; then
        printf "%s" "$candidate"
        return "$SUCCESS"
      fi
    fi
  done

  return "$FAIL"
}

grid_tool_available() {
  local tool="$1"
  discover_grid_home_for_tool "$tool" >/dev/null 2>&1
}

run_grid_tool() {
  local tool="$1"
  shift
  local grid_home status
  grid_home="$(discover_grid_home_for_tool "$tool" || true)"
  [[ -n "$grid_home" && -x "${grid_home}/bin/${tool}" ]] || return "$FAIL"

  if [[ "$(id -un 2>/dev/null || true)" == "$GRID_USER" ]]; then
    env ORACLE_HOME="$grid_home" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/${tool}" "$@"
    return "$?"
  fi

  env ORACLE_HOME="$grid_home" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/${tool}" "$@"
  status=$?
  [[ "$status" -eq 0 ]] && return "$SUCCESS"

  if command -v sudo >/dev/null 2>&1 && sudo -n -u "$GRID_USER" true >/dev/null 2>&1; then
    sudo -n -u "$GRID_USER" env ORACLE_HOME="$grid_home" PATH="${grid_home}/bin:${PATH}" "${grid_home}/bin/${tool}" "$@"
    return "$?"
  fi

  return "$status"
}

run_asmcmd_with_grid_env() {
  local asmcmd_bin asm_home asm_sid
  asm_home="$(discover_grid_home_for_tool asmcmd || true)"
  [[ -n "$asm_home" ]] || return "$FAIL"
  asmcmd_bin="${asm_home}/bin/asmcmd"
  [[ -x "$asmcmd_bin" ]] || return "$FAIL"
  asm_sid="${CRASHSIM_ASM_SID:-}"
  [[ -n "$asm_sid" ]] || asm_sid="$(detect_asm_sid_from_process || true)"
  [[ -n "$asm_sid" ]] || asm_sid="+ASM"
  if [[ "$(id -un 2>/dev/null || true)" == "$GRID_USER" ]]; then
    env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo -n -u "$GRID_USER" env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
  else
    env ORACLE_HOME="$asm_home" ORACLE_SID="$asm_sid" PATH="${asm_home}/bin:${PATH}" "$asmcmd_bin" "$@"
  fi
}

collect_managed_storage_targets() {
  local output_file="$1"
  sql_query "$output_file" "
select name || '=' || nvl(value, '')
from v\$parameter
where name in (
  'control_files',
  'db_create_file_dest',
  'db_create_online_log_dest_1',
  'db_create_online_log_dest_2',
  'db_recovery_file_dest',
  'spfile'
)
  and value is not null
order by name;
"
}

first_managed_storage_target() {
  local evidence_file="$1"
  local value
  value="$(awk -F= '
    $2 ~ /^[@+]/ {print $2; exit}
    $2 ~ /^\\/.*(dbaas_acfs|\\/acfs\\/|^\\/acfs\\/)/ {print $2; exit}
  ' "$evidence_file" 2>/dev/null || true)"
  [[ -n "$value" ]] || value="${FRA_PATH:-${SPFILE_PATH:-FEX_ACFS_STORAGE}}"
  printf "%s" "$value"
}

print_managed_storage_evidence() {
  local evidence_file="$1"
  if [[ -s "$evidence_file" ]]; then
    echo
    echo "Managed storage destinations visible to the database:"
    sed 's/^/  /' "$evidence_file"
  fi
}

scenario_asm_diskgroup_unavailable() {
  reset_actions
  local dg_file managed_file row dg_name dg_state dg_type dg_total dg_free target_dg=""
  echo "ASM/FEX managed data storage planning helper"
  dg_file="$WORK_DIR/asm_diskgroups.lst"
  managed_file="$WORK_DIR/managed_storage_targets.lst"
  sql_query "$dg_file" "
select name || '|' || state || '|' || type || '|' || total_mb || '|' || free_mb
from v\$asm_diskgroup
order by name;
"
  collect_managed_storage_targets "$managed_file" || true
  mapfile -t TARGET_ROWS < <(trim_blank_lines <"$dg_file")
  if [[ "${#TARGET_ROWS[@]}" -eq 0 ]]; then
    print_managed_storage_evidence "$managed_file"
    if [[ "$STORAGE_TYPE" == "FEX" || "$STORAGE_TYPE" == "FEX_ACFS" || "$STORAGE_TYPE" == "ACFS" ]]; then
      target_dg="$(first_managed_storage_target "$managed_file")"
      add_action "external" "$target_dg" "FEX/ACFS managed storage outage requires provider-aware fault injection, service impact validation, and RMAN/GI recovery checks"
      execute_actions
      return "$SUCCESS"
    fi
    warn "No ASM disk groups were visible from V\$ASM_DISKGROUP."
    target_dg="+ASM_DISKGROUP"
  else
    echo
    echo "ASM disk groups visible to the database:"
    for row in "${TARGET_ROWS[@]}"; do
      IFS='|' read -r dg_name dg_state dg_type dg_total dg_free <<<"$row"
      printf "  %-12s state=%-12s type=%-8s total_mb=%-10s free_mb=%s\n" \
        "$dg_name" "$dg_state" "$dg_type" "$dg_total" "$dg_free"
      if [[ "$dg_name" == "DATA" ]]; then
        target_dg="+${dg_name}"
      fi
    done
    if [[ -z "$target_dg" ]]; then
      IFS='|' read -r dg_name dg_state dg_type dg_total dg_free <<<"${TARGET_ROWS[0]}"
      target_dg="+${dg_name}"
    fi
  fi
  add_action "external" "$target_dg" "ASM disk group outage requires explicit ASM-aware fault injection and restore/rebalance steps"
  execute_actions
}

scenario_ocr_restore_drill() {
  reset_actions
  echo "OCR restore planning helper"
  if grid_tool_available ocrcheck; then
    print_optional_tool_output "ocrcheck" run_grid_tool ocrcheck
  else
    warn "ocrcheck not found in Grid Infrastructure home or PATH."
  fi
  if grid_tool_available ocrconfig; then
    print_optional_tool_output "ocrconfig -showbackup" run_grid_tool ocrconfig -showbackup
  else
    warn "ocrconfig not found in Grid Infrastructure home or PATH."
  fi
  add_action "external" "OCR" "OCR restore practice must use a root/Grid procedure, verified OCR backups, and CRS validation"
  execute_actions
}

scenario_voting_disk_drill() {
  reset_actions
  echo "Voting disk planning helper"
  if grid_tool_available crsctl; then
    print_optional_tool_output "crsctl query css votedisk" run_grid_tool crsctl query css votedisk
  else
    warn "crsctl not found in Grid Infrastructure home or PATH."
  fi
  add_action "external" "VOTING_DISK" "Voting disk replacement practice must use a root/Grid procedure and cluster membership validation"
  execute_actions
}

scenario_asm_spfile_loss() {
  reset_actions
  local asm_spfile="" asm_config_file db_config_file
  echo "ASM/FEX managed SPFILE planning helper"
  if grid_tool_available srvctl; then
    if [[ -n "$DB_UNIQUE_NAME" ]]; then
      db_config_file="$WORK_DIR/srvctl_config_database.out"
      if run_grid_tool srvctl config database -d "$DB_UNIQUE_NAME" >"$db_config_file" 2>&1; then
        echo
        echo "srvctl config database -d ${DB_UNIQUE_NAME}:"
        sed 's/^/  /' "$db_config_file"
      else
        warn "Unable to collect srvctl database configuration for ${DB_UNIQUE_NAME}."
      fi
    fi
    asm_config_file="$WORK_DIR/srvctl_config_asm.out"
    if run_grid_tool srvctl config asm >"$asm_config_file" 2>&1; then
      echo
      echo "srvctl config asm:"
      sed 's/^/  /' "$asm_config_file"
    else
      warn "Unable to collect srvctl config asm."
    fi
  else
    warn "srvctl not found in Grid Infrastructure home or PATH."
  fi
  if grid_tool_available asmcmd; then
    asm_spfile="$(run_asmcmd_with_grid_env spget 2>/dev/null | trim_blank_lines | head -n 1 || true)"
    if [[ -n "$asm_spfile" ]]; then
      print_optional_tool_output "asmcmd spget" run_asmcmd_with_grid_env spget
    else
      warn "asmcmd spget was not available from the current OS user; use the Grid owner if ASM SPFILE path discovery is required."
    fi
  else
    warn "asmcmd not found in Grid Infrastructure home or PATH."
  fi
  if [[ -z "$asm_spfile" && "$(storage_path_class "$SPFILE_PATH")" == "fex" ]]; then
    asm_spfile="$SPFILE_PATH"
  elif [[ -z "$asm_spfile" && "$(storage_path_class "$SPFILE_PATH")" == "acfs" ]]; then
    asm_spfile="$SPFILE_PATH"
  fi
  [[ -n "$asm_spfile" ]] || asm_spfile="+ASM_SPFILE"
  if [[ "$(storage_path_class "$asm_spfile")" == "fex" ]]; then
    add_action "external" "$asm_spfile" "FEX/ACFS managed SPFILE loss requires provider-aware metadata restore, srvctl database validation, and instance restart/recovery checks"
  elif [[ "$(storage_path_class "$asm_spfile")" == "acfs" ]]; then
    add_action "external" "$asm_spfile" "ACFS-backed SPFILE loss should be practiced with an approved backup/restore wrapper, srvctl database validation, and instance restart/recovery checks"
  else
    add_action "external" "$asm_spfile" "ASM SPFILE loss requires ASM-aware backup/restore flow and Clusterware resource validation"
  fi
  execute_actions
}

collect_dgmgrl_fsfo_evidence() {
  local output_file="$1"
  local dgmgrl_bin

  dgmgrl_bin="$(find_dgmgrl_bin)"
  if [[ -z "$dgmgrl_bin" || ! -x "$dgmgrl_bin" ]]; then
    printf "dgmgrl not found in ORACLE_HOME/bin or PATH.\n" >"$output_file" || true
    return "$FAIL"
  fi
  printf 'show configuration verbose;\nshow fast_start failover;\nexit\n' |
    "$dgmgrl_bin" -silent / >"$output_file" 2>&1 || return "$FAIL"
}

write_adg_pressure_sql_file() {
  local sql_file="$1"

  cat >"$sql_file" <<'SQL' || die "Unable to write ADG pressure SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set heading off feedback off pagesize 0 verify off echo off termout on
set linesize 32767 trimspool on trimout on tab off

select 'CSIM_ADG|database|' ||
       'db_unique_name=' || db_unique_name ||
       '|role=' || database_role ||
       '|open_mode=' || open_mode ||
       '|flashback=' || flashback_on ||
       '|protection=' || protection_mode
from v$database;

select 'CSIM_ADG|managed_standby|' || process || '|' || status || '|' ||
       nvl(client_process, 'UNKNOWN') || '|' || nvl(sequence#, 0)
from v$managed_standby
where process in ('MRP0','MRP','RFS','LNS')
   or process like 'MRP%'
order by process;

select 'CSIM_ADG|lag|' || name || '|' || nvl(value, 'UNKNOWN') || '|' || nvl(unit, '')
from v$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;

select 'CSIM_ADG|user_session_count|' || count(*)
from v$session
where type = 'USER';

select 'CSIM_ADG|session_by_user|' || nvl(username, 'UNKNOWN') || '|' || count(*)
from v$session
where type = 'USER'
group by nvl(username, 'UNKNOWN')
order by count(*) desc, nvl(username, 'UNKNOWN');

exit
SQL
}

write_adg_pressure_report() {
  local report_file="$1"
  local evidence_file="$2"

  {
    printf "# CrashSimulator Active Data Guard Read-Only Pressure Readiness\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- Evidence file: `%s`\n\n' "$evidence_file"
    printf "This read-only scenario validates that the target is an Active Data Guard standby and captures baseline evidence before any approved reporting/query-pressure workload is introduced. It does not generate load by itself; use the evidence to size a controlled workload and monitor apply lag, user sessions, services, and Resource Manager behavior.\n\n"
  } >"$report_file" || die "Unable to write ADG pressure report: $report_file"

  append_report_section "$report_file" "Evidence"
  {
    printf '```text\n'
    sed -n '/^CSIM_ADG|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  append_report_section "$report_file" "Guardrails"
  {
    printf -- '- Run only on a standby opened `READ ONLY WITH APPLY`.\n'
    printf -- '- Keep workload read-only and disposable; do not use production reporting spikes as an unbounded stress test.\n'
    printf -- '- Monitor `V$DATAGUARD_STATS`, standby alert logs, service placement, query response time, and application retry behavior.\n'
    printf -- '- If apply lag breaches the SLA, stop the pressure workload first, then validate apply catch-up before continuing.\n'
  } >>"$report_file"
}

scenario_dg_broker_config_unavailable() {
  reset_actions
  local broker_file="$WORK_DIR/dg_broker_config_sql.lst"
  local dgmgrl_file="$WORK_DIR/dg_broker_config_dgmgrl.out"
  local broker_start

  sql_query "$broker_file" "
select 'DATABASE|' || db_unique_name || '|' || database_role || '|' || open_mode || '|' || protection_mode
from v\$database;
select 'DG_BROKER_START=' || value
from v\$parameter
where name = 'dg_broker_start';
select 'DEST|' || dest_id || '|' || nvl(status, 'UNKNOWN') || '|' || nvl(destination, 'UNKNOWN') || '|' || nvl(db_unique_name, 'UNKNOWN')
from v\$archive_dest
where target = 'STANDBY'
order by dest_id;
"
  broker_start="$(awk -F= '/^DG_BROKER_START=/ {print toupper($2); exit}' "$broker_file")"
  [[ "$broker_start" == "TRUE" ]] ||
    die "Data Guard broker is not enabled (DG_BROKER_START=${broker_start:-unknown}). Enable broker and validate DGMGRL before scenario 52."

  echo "Data Guard broker SQL evidence:"
  sed 's/^/  /' "$broker_file"
  manifest_append "dg_broker_sql_evidence" "$broker_file"

  if collect_dgmgrl_fsfo_evidence "$dgmgrl_file"; then
    echo
    echo "DGMGRL broker evidence:"
    sed 's/^/  /' "$dgmgrl_file"
    manifest_append "dg_broker_dgmgrl_evidence" "$dgmgrl_file"
  else
    warn "DGMGRL evidence was not available or broker connection failed. Scenario 52 remains plan-only until DGMGRL evidence is clean."
    manifest_append "dg_broker_dgmgrl_evidence" "$dgmgrl_file"
  fi

  add_action "external" "DG_BROKER_CONFIG" "Approved lab action only: make broker configuration unavailable or stop broker management, then validate DGMGRL/SQL warnings and restore broker configuration. CrashSimulator keeps this plan-only."
  execute_actions
}

scenario_adg_readonly_session_pressure() {
  reset_actions
  local role_file="$WORK_DIR/adg_open_mode.lst"
  local role_line open_mode sql_file evidence_file report_file

  sql_query "$role_file" "
select database_role || '|' || open_mode || '|' || nvl(guard_status, 'UNKNOWN')
from v\$database;
"
  role_line="$(trim_blank_lines <"$role_file" | head -n 1)"
  IFS='|' read -r DB_ROLE open_mode _guard_status <<<"$role_line"
  [[ "$DB_ROLE" == *"STANDBY"* ]] ||
    die "Scenario 53 requires a standby role. Current role: ${DB_ROLE:-unknown}"
  [[ "$open_mode" == "READ ONLY WITH APPLY" ]] ||
    die "Scenario 53 requires Active Data Guard open mode READ ONLY WITH APPLY. Current open mode: ${open_mode:-unknown}"

  sql_file="${LOG_DIR}/crashsim_s53_${RUN_ID}_adg_pressure.sql"
  evidence_file="${LOG_DIR}/crashsim_s53_${RUN_ID}_adg_pressure.evidence"
  report_file="${LOG_DIR}/crashsim_s53_${RUN_ID}_adg_pressure.md"
  write_adg_pressure_sql_file "$sql_file"
  manifest_append "adg_pressure_sqlfile" "$sql_file"
  manifest_append "adg_pressure_evidence" "$evidence_file"
  manifest_append "adg_pressure_report" "$report_file"

  add_action "report" "Active Data Guard read-only pressure readiness" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "ADG pressure readiness SQL failed: $sql_file (evidence: $evidence_file)"
  grep -q '^CSIM_ADG|' "$evidence_file" ||
    die "ADG pressure readiness SQL produced no evidence rows: $evidence_file"
  write_adg_pressure_report "$report_file" "$evidence_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_snapshot_standby_conversion_practice() {
  reset_actions
  local snapshot_file="$WORK_DIR/snapshot_standby_readiness.lst"
  local dgmgrl_file="$WORK_DIR/snapshot_standby_dgmgrl.out"
  local role open_mode flashback force_logging
  local line

  sql_query "$snapshot_file" "
select db_unique_name || '|' || database_role || '|' || open_mode || '|' || flashback_on || '|' || force_logging
from v\$database;
select 'RESTORE_POINT_COUNT=' || count(*)
from v\$restore_point;
select 'DG_STAT|' || name || '|' || nvl(value, 'UNKNOWN') || '|' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
"
  line="$(trim_blank_lines <"$snapshot_file" | head -n 1)"
  IFS='|' read -r _db_unique role open_mode flashback force_logging <<<"$line"
  [[ "$role" == *"STANDBY"* ]] ||
    die "Scenario 54 requires a standby role. Current role: ${role:-unknown}"
  [[ "$flashback" == "YES" ]] ||
    die "Snapshot standby conversion requires Flashback Database enabled on the standby. Current FLASHBACK_ON=${flashback:-unknown}."

  echo "Snapshot standby readiness SQL evidence:"
  sed 's/^/  /' "$snapshot_file"
  manifest_append "snapshot_standby_sql_evidence" "$snapshot_file"
  manifest_append "snapshot_standby_role" "$role"
  manifest_append "snapshot_standby_open_mode" "$open_mode"
  manifest_append "snapshot_standby_flashback_on" "$flashback"
  manifest_append "snapshot_standby_force_logging" "$force_logging"

  if collect_dgmgrl_fsfo_evidence "$dgmgrl_file"; then
    echo
    echo "DGMGRL snapshot-standby context evidence:"
    sed 's/^/  /' "$dgmgrl_file"
    manifest_append "snapshot_standby_dgmgrl_evidence" "$dgmgrl_file"
  else
    warn "DGMGRL evidence was not available; collect broker evidence manually before conversion."
    manifest_append "snapshot_standby_dgmgrl_evidence" "$dgmgrl_file"
  fi

  add_action "external" "SNAPSHOT_STANDBY_CONVERSION" "Approved standby-only action: convert to snapshot standby, run disposable write tests, convert back to physical standby, restart apply, and validate lag. CrashSimulator keeps conversion execution plan-only."
  execute_actions
}

plan_dg_transport_defer() {
  local detail="$1"
  local dest_file="$WORK_DIR/remote_standby_dest.lst"
  local row dest_id status destination db_unique_name

  query_targets "$dest_file" "
select dest_id || '|' ||
       nvl(status, 'UNKNOWN') || '|' ||
       nvl(destination, 'UNKNOWN') || '|' ||
       nvl(db_unique_name, 'UNKNOWN')
from (
  select dest_id, status, destination, db_unique_name
  from v\$archive_dest
  where target = 'STANDBY'
    and destination is not null
    and status <> 'INACTIVE'
  order by case status when 'VALID' then 1 else 2 end, dest_id
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No remote standby archive destination was found."
  row="${TARGET_ROWS[0]}"
  IFS='|' read -r dest_id status destination db_unique_name <<<"$row"
  [[ "$dest_id" =~ ^[0-9]+$ ]] || die "Unable to parse Data Guard destination metadata: ${row}"

  manifest_append "dg_dest_id" "$dest_id"
  manifest_append "dg_dest_status_before" "$status"
  manifest_append "dg_dest_destination" "$destination"
  manifest_append "dg_dest_db_unique_name" "$db_unique_name"

  add_action "sql" "alter system set log_archive_dest_state_${dest_id}=defer scope=both;" "$detail for LOG_ARCHIVE_DEST_${dest_id}"
  execute_actions
}

write_standby_redo_log_review_sql_file() {
  local sql_file="$1"
  cat >"$sql_file" <<'SQL' || die "Unable to write standby redo log review SQL file: $sql_file"
whenever sqlerror exit sql.sqlcode
set pages 200 lines 260 trimspool on tab off feedback off heading off

select 'CSIM_SRL|database_role|' || database_role from v$database;
select 'CSIM_SRL|protection_mode|' || protection_mode from v$database;
select 'CSIM_SRL|open_mode|' || open_mode from v$database;

select 'CSIM_SRL|online_thread|' || thread# ||
       '|online_groups|' || count(*) ||
       '|online_max_mb|' || round(max(bytes)/1024/1024, 2)
from v$log
group by thread#
order by thread#;

select 'CSIM_SRL|standby_thread|' || thread# ||
       '|srl_groups|' || count(*) ||
       '|srl_max_mb|' || round(max(bytes)/1024/1024, 2)
from v$standby_log
group by thread#
order by thread#;

with online_redo as (
  select thread#, count(*) online_groups, max(bytes) max_online_bytes
  from v$log
  group by thread#
),
standby_redo as (
  select thread#, count(*) srl_groups, max(bytes) max_srl_bytes
  from v$standby_log
  group by thread#
),
threads as (
  select thread# from online_redo
  union
  select thread# from standby_redo
)
select 'CSIM_SRL|thread|' || t.thread# ||
       '|online_groups|' || nvl(o.online_groups, 0) ||
       '|required_srl_groups|' || (nvl(o.online_groups, 0) + 1) ||
       '|actual_srl_groups|' || nvl(s.srl_groups, 0) ||
       '|online_max_mb|' || round(nvl(o.max_online_bytes, 0)/1024/1024, 2) ||
       '|srl_max_mb|' || round(nvl(s.max_srl_bytes, 0)/1024/1024, 2) ||
       '|status|' ||
       case
         when nvl(s.srl_groups, 0) = 0 then 'MISSING_SRLS'
         when nvl(s.srl_groups, 0) < nvl(o.online_groups, 0) + 1 then 'TOO_FEW_SRLS'
         when nvl(s.max_srl_bytes, 0) < nvl(o.max_online_bytes, 0) then 'SRL_TOO_SMALL'
         else 'OK'
       end
from threads t
left join online_redo o on o.thread# = t.thread#
left join standby_redo s on s.thread# = t.thread#
order by t.thread#;

exit
SQL
}

write_standby_redo_log_review_report() {
  local report_file="$1"
  local evidence_file="$2"
  {
    printf "# CrashSimulator Standby Redo Log Review\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    printf -- '- Evidence file: `%s`\n\n' "$evidence_file"
    printf "This read-only scenario checks whether standby redo logs appear to meet a common Data Guard baseline: each redo thread should have at least one more SRL group than online redo groups, and SRL size should be at least the largest online redo size for that thread.\n\n"
  } >"$report_file" || die "Unable to write standby redo log report: $report_file"

  append_report_section "$report_file" "Thread Results"
  {
    printf '```text\n'
    sed -n '/^CSIM_SRL|thread|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"

  append_report_section "$report_file" "Recommendations"
  {
    printf -- '- If a thread reports `MISSING_SRLS`, add standby redo logs before relying on real-time apply or low RPO.\n'
    printf -- '- If a thread reports `TOO_FEW_SRLS`, add at least enough SRL groups to reach online redo group count plus one.\n'
    printf -- '- If a thread reports `SRL_TOO_SMALL`, recreate SRLs so each thread has SRLs at least as large as the largest online redo log.\n'
    printf -- '- In RAC, validate every redo thread, not only the currently active instance.\n'
  } >>"$report_file"

  append_report_section "$report_file" "Raw Evidence"
  {
    printf '```text\n'
    sed -n '/^CSIM_SRL|/p' "$evidence_file"
    printf '```\n'
  } >>"$report_file"
}

scenario_fsfo_observer_unavailable() {
  reset_actions
  local fsfo_file="$WORK_DIR/fsfo_observer_sql.lst"
  local dgmgrl_file="$WORK_DIR/fsfo_observer_dgmgrl.out"
  local line fsfo_status fsfo_target fsfo_threshold observer_present observer_seen=0

  sql_query "$fsfo_file" "
select nvl(fs_failover_status, 'UNKNOWN') || '|' ||
       nvl(fs_failover_current_target, 'UNKNOWN') || '|' ||
       nvl(to_char(fs_failover_threshold), 'UNKNOWN') || '|' ||
       nvl(fs_failover_observer_present, 'UNKNOWN')
from v\$database;
"
  line="$(trim_blank_lines <"$fsfo_file" | head -n 1)"
  IFS='|' read -r fsfo_status fsfo_target fsfo_threshold observer_present <<<"$line"
  [[ -n "$fsfo_status" ]] || die "Unable to collect FSFO status from V\$DATABASE."

  echo "FSFO SQL evidence: status=${fsfo_status}, target=${fsfo_target}, threshold=${fsfo_threshold}, observer=${observer_present}"
  if [[ "$observer_present" == "YES" ]]; then
    observer_seen=1
  fi

  if collect_dgmgrl_fsfo_evidence "$dgmgrl_file"; then
    echo
    echo "DGMGRL FSFO evidence:"
    sed 's/^/  /' "$dgmgrl_file"
    if grep -Eiq 'observer[[:space:]]*:[[:space:]]*[^[:space:](]+' "$dgmgrl_file" ||
       grep -Eiq 'observer[[:space:]_]*(host|name|present)[^:]*:[[:space:]]*[^[:space:](]+' "$dgmgrl_file"; then
      observer_seen=1
    fi
  else
    warn "DGMGRL FSFO evidence was not available; relying on SQL FSFO columns."
  fi

  [[ "$observer_seen" -eq 1 ]] ||
    die "FSFO observer was not detected. Enable FSFO and start an observer before scenario 66."

  manifest_append "fsfo_status" "$fsfo_status"
  manifest_append "fsfo_target" "$fsfo_target"
  manifest_append "fsfo_threshold" "$fsfo_threshold"
  manifest_append "fsfo_observer_present" "$observer_present"
  manifest_append "fsfo_dgmgrl_evidence" "$dgmgrl_file"

  add_action "external" "FSFO_OBSERVER" "Stop or isolate the observer host/process, then validate broker status, failover expectations, and observer restart. CrashSimulator keeps this plan-only."
  execute_actions
}

scenario_dg_apply_lag() {
  reset_actions
  local apply_file="$WORK_DIR/dg_apply_lag_process.lst"
  local lag_file="$WORK_DIR/dg_apply_lag_stats.lst"
  local row process_name process_status

  query_targets "$apply_file" "
select process || '|' || status
from (
  select process, status
  from v\$managed_standby
  where process like 'MRP%'
  order by process
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No managed standby recovery process was detected. Start apply before running scenario 67."
  row="${TARGET_ROWS[0]}"
  IFS='|' read -r process_name process_status <<<"$row"

  sql_query "$lag_file" "
select name || '=' || nvl(value, 'UNKNOWN') || ' ' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
"
  echo "Current Data Guard lag evidence:"
  sed 's/^/  /' "$lag_file"

  manifest_append "dg_apply_process" "$process_name"
  manifest_append "dg_apply_process_status" "$process_status"
  manifest_append "dg_apply_lag_evidence" "$lag_file"

  add_action "sql" "alter database recover managed standby database cancel;" "pause standby apply to create measurable apply lag"
  execute_actions
}

scenario_dg_transport_partition() {
  reset_actions
  plan_dg_transport_defer "simulate Data Guard transport network partition"
}

scenario_standby_redo_log_misconfig() {
  reset_actions
  local sql_file evidence_file report_file
  sql_file="${LOG_DIR}/crashsim_s69_${RUN_ID}_standby_redo_review.sql"
  evidence_file="${LOG_DIR}/crashsim_s69_${RUN_ID}_standby_redo_review.evidence"
  report_file="${LOG_DIR}/crashsim_s69_${RUN_ID}_standby_redo_review.md"

  write_standby_redo_log_review_sql_file "$sql_file"
  manifest_append "standby_redo_review_sqlfile" "$sql_file"
  manifest_append "standby_redo_review_evidence" "$evidence_file"
  manifest_append "standby_redo_review_report" "$report_file"

  add_action "report" "Standby redo log review" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  ensure_sqlplus
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "Standby redo log review SQL failed: $sql_file (evidence: $evidence_file)"
  write_standby_redo_log_review_report "$report_file" "$evidence_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_rac_vip_relocation() {
  reset_actions
  command -v crsctl >/dev/null 2>&1 || die "crsctl not found"
  local vip_file="$WORK_DIR/rac_vip_resources.out"
  local vip_detail_file="$WORK_DIR/rac_vip_resources_detail.out"
  local vip_resource

  crsctl stat res -t >"$vip_file" 2>&1 ||
    die "Unable to collect Clusterware resource status with crsctl."
  crsctl stat res -w "TYPE = ora.cluster_vip_net1.type" -p >"$vip_detail_file" 2>&1 || true

  vip_resource="$(awk '/^ora\..*\.vip([[:space:]]|$)/ {print $1; exit}' "$vip_file")"
  if [[ -z "$vip_resource" ]]; then
    vip_resource="$(awk -F= '/^NAME=ora\..*\.vip$/ {print $2; exit}' "$vip_detail_file")"
  fi
  [[ -n "$vip_resource" ]] || die "No RAC VIP resources were visible to crsctl."

  echo "RAC VIP evidence:"
  sed 's/^/  /' "$vip_file"
  manifest_append "rac_vip_resource" "$vip_resource"
  manifest_append "rac_vip_status_evidence" "$vip_file"
  manifest_append "rac_vip_detail_evidence" "$vip_detail_file"

  add_action "external" "$vip_resource" "Relocate VIP with srvctl/crsctl under Grid owner approval, then validate client connect strings, FAN/ONS, and service failover. CrashSimulator keeps VIP movement plan-only."
  execute_actions
}

scenario_rac_service_placement_failure() {
  reset_actions
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"

  local service services_file status_file config_file status_line running source_inst
  services_file="$WORK_DIR/srvctl_services_placement.lst"
  srvctl config service -d "$DB_UNIQUE_NAME" >"$services_file" 2>&1 ||
    die "Unable to collect srvctl service configuration for ${DB_UNIQUE_NAME}."

  if [[ -n "$SERVICE_NAME" ]]; then
    service="$SERVICE_NAME"
  else
    service="$(awk -F': ' '/^Service name:/ {print $2; exit}' "$services_file")"
  fi
  [[ -n "$service" ]] || die "No srvctl-managed database service was found. Create a service before scenario 71."

  config_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_placement_config.out"
  status_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_placement_status.out"
  srvctl config service -d "$DB_UNIQUE_NAME" -s "$service" >"$config_file" 2>&1 ||
    die "Service ${service} was not found in srvctl config for ${DB_UNIQUE_NAME}."
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" >"$status_file" 2>&1 ||
    die "Unable to collect srvctl service status for ${service}."

  echo "srvctl config service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$config_file"
  echo
  echo "srvctl status service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$status_file"

  status_line="$(grep -E '^Service .* is running on instance' "$status_file" | head -n 1 || true)"
  running="$(printf "%s" "$status_line" | sed -E 's/^.*instance\(s\)[[:space:]]*//; s/[[:space:]]//g')"
  [[ -n "$running" ]] || die "Service ${service} is not running. Start it before service placement failure practice."
  source_inst="$(first_csv_value "$running" || true)"
  [[ -n "$source_inst" ]] || die "Unable to determine a running source instance for service ${service}."

  manifest_append "scenario_71_service" "$service"
  manifest_append "scenario_71_running_instances_before" "$running"
  manifest_append "scenario_71_source_instance" "$source_inst"
  manifest_append "scenario_71_config_evidence" "$config_file"
  manifest_append "scenario_71_status_evidence" "$status_file"

  add_action "srvctl_stop_start_service_instance" "$service" "$source_inst"
  execute_actions
}

scenario_asm_single_disk_failure() {
  reset_actions
  local disk_file="$WORK_DIR/asm_single_disk_candidates.lst"
  local all_disk_file="$WORK_DIR/asm_single_disk_all.lst"
  local managed_file="$WORK_DIR/managed_storage_targets.lst"
  local row dg_name dg_type disk_name failgroup disk_path mount_status header_status mode_status state target

  echo "ASM/FEX storage component failure planning helper"

  query_targets "$disk_file" "
select dg.name || '|' ||
       dg.type || '|' ||
       d.name || '|' ||
       nvl(d.failgroup, 'UNKNOWN') || '|' ||
       nvl(d.path, 'UNKNOWN') || '|' ||
       nvl(d.mount_status, 'UNKNOWN') || '|' ||
       nvl(d.header_status, 'UNKNOWN') || '|' ||
       nvl(d.mode_status, 'UNKNOWN') || '|' ||
       nvl(d.state, 'UNKNOWN')
from v\$asm_disk d
join v\$asm_diskgroup dg on dg.group_number = d.group_number
where dg.type not in ('EXTERN', 'EXTERNAL')
  and d.name is not null
  and d.mount_status = 'CACHED'
  and d.mode_status = 'ONLINE'
order by case dg.type when 'HIGH' then 1 when 'NORMAL' then 2 else 3 end,
         dg.name, d.failgroup, d.name;
"
  if [[ "${#TARGET_ROWS[@]}" -eq 0 ]]; then
    sql_query "$all_disk_file" "
select dg.name || '|' || dg.type || '|' || count(*) || ' disks'
from v\$asm_disk d
join v\$asm_diskgroup dg on dg.group_number = d.group_number
group by dg.name, dg.type
order by dg.name;
"
    if [[ -s "$all_disk_file" ]]; then
      echo "ASM disk group evidence:"
      sed 's/^/  /' "$all_disk_file"
    fi
    if [[ "$STORAGE_TYPE" == "FEX" || "$STORAGE_TYPE" == "FEX_ACFS" || "$STORAGE_TYPE" == "ACFS" ]]; then
      collect_managed_storage_targets "$managed_file" || true
      print_managed_storage_evidence "$managed_file"
      target="$(first_managed_storage_target "$managed_file")"
      add_action "external" "$target" "FEX/ACFS storage-component failure should be injected through provider-approved storage controls; validate database service continuity, GI resources, RMAN recoverability, and provider redundancy/rebuild evidence"
      execute_actions
      return "$SUCCESS"
    fi
    die "No redundant ASM disk candidate was found. Scenario 72 requires NORMAL, HIGH, FLEX, or EXTENDED redundancy with online disks."
  fi

  row="${TARGET_ROWS[0]}"
  IFS='|' read -r dg_name dg_type disk_name failgroup disk_path mount_status header_status mode_status state <<<"$row"
  [[ -n "$dg_name" && -n "$disk_name" ]] || die "Unable to parse ASM disk candidate metadata: ${row}"

  manifest_append "asm_diskgroup_name" "$dg_name"
  manifest_append "asm_diskgroup_type" "$dg_type"
  manifest_append "asm_disk_name" "$disk_name"
  manifest_append "asm_disk_failgroup" "$failgroup"
  manifest_append "asm_disk_path" "$disk_path"
  manifest_append "asm_disk_mount_status" "$mount_status"
  manifest_append "asm_disk_header_status" "$header_status"
  manifest_append "asm_disk_mode_status" "$mode_status"
  manifest_append "asm_disk_state" "$state"

  add_action "external" "${dg_name}:${disk_name}" "Single ASM disk failure should be injected only in a redundant lab. Example plan: alter diskgroup ${dg_name} offline disk ${disk_name}; monitor rebalance; restore with online/drop/add disk as appropriate."
  execute_actions
}

collect_service_continuity_evidence() {
  local evidence_file="$1"
  sql_query "$evidence_file" "
select 'DATABASE|' || name || '|' || db_unique_name || '|' || database_role || '|' || open_mode
from v\$database;
select 'SERVICE_COLUMN|' || column_name
from dba_tab_columns
where owner = 'SYS'
  and table_name = 'DBA_SERVICES'
  and column_name in (
    'NAME','NETWORK_NAME','PDB','FAILOVER_TYPE','FAILOVER_METHOD',
    'COMMIT_OUTCOME','REPLAY_INITIATION_TIMEOUT','RETENTION_TIMEOUT',
    'SESSION_STATE_CONSISTENCY','FAILOVER_RESTORE','AQ_HA_NOTIFICATIONS',
    'DRAIN_TIMEOUT','STOP_OPTION','CLB_GOAL','GOAL'
  )
order by column_name;
select 'SERVICE|' || name || '|' || nvl(network_name, 'UNKNOWN') || '|' || nvl(pdb, 'UNKNOWN')
from dba_services
where name not like 'SYS\$%'
order by name;
select 'GV_SERVICE|' || inst_id || '|' || name || '|' || nvl(network_name, 'UNKNOWN') || '|' || nvl(pdb, 'UNKNOWN')
from gv\$services
where name not like 'SYS\$%'
order by inst_id, name;
"
}

collect_scenario_srvctl_service_evidence() {
  local prefix="$1"
  local config_file="${prefix}_srvctl_config_service.out"
  local status_file="${prefix}_srvctl_status_service.out"
  local ons_file="${prefix}_srvctl_config_ons.out"
  local crs_file="${prefix}_crs_service_resources.out"

  if [[ -n "$DB_UNIQUE_NAME" ]] && grid_tool_available srvctl; then
    run_grid_tool srvctl config service -d "$DB_UNIQUE_NAME" >"$config_file" 2>&1 || true
    run_grid_tool srvctl status service -d "$DB_UNIQUE_NAME" >"$status_file" 2>&1 || true
    run_grid_tool srvctl config ons >"$ons_file" 2>&1 || true
  else
    printf "srvctl or DB_UNIQUE_NAME not available.\n" >"$config_file"
    printf "srvctl or DB_UNIQUE_NAME not available.\n" >"$status_file"
    printf "srvctl not available.\n" >"$ons_file"
  fi
  if grid_tool_available crsctl; then
    run_grid_tool crsctl stat res -t >"$crs_file" 2>&1 || true
  else
    printf "crsctl not available.\n" >"$crs_file"
  fi
  manifest_append "srvctl_service_config_evidence" "$config_file"
  manifest_append "srvctl_service_status_evidence" "$status_file"
  manifest_append "srvctl_ons_evidence" "$ons_file"
  manifest_append "crs_resource_evidence" "$crs_file"
}

write_scenario_evidence_report() {
  local report_file="$1"
  local title="$2"
  local purpose="$3"
  shift 3
  local evidence_file
  {
    printf "# %s\n\n" "$title"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Database: `%s`\n' "${DB_UNIQUE_NAME:-unknown}"
    printf -- '- Role/open mode: `%s` / `%s`\n' "${DB_ROLE:-unknown}" "${DB_OPEN_MODE:-unknown}"
    [[ -n "${TARGET_PDB:-}" ]] && printf -- '- PDB: `%s`\n' "$TARGET_PDB"
    printf '\n%s\n\n' "$purpose"
    printf "## Evidence Files\n\n"
    for evidence_file in "$@"; do
      [[ -n "$evidence_file" ]] || continue
      printf -- '- `%s`\n' "$evidence_file"
    done
    printf "\n## Guardrails\n\n"
    printf -- '- Keep this drill read-only until the exact lab topology, rollback path, and approval boundary are documented.\n'
    printf -- '- Capture before/after service, database, application, and monitoring evidence.\n'
    printf -- '- Do not claim RTO/RPO or replay success without measured client/application evidence.\n'
  } >"$report_file" || die "Unable to write report: $report_file"
}

scenario_ac_tac_replay_validation() {
  reset_actions
  local evidence_file report_file prefix
  prefix="${LOG_DIR}/crashsim_s83_${RUN_ID}_ac_tac"
  evidence_file="${prefix}.evidence"
  report_file="${prefix}.md"
  collect_service_continuity_evidence "$evidence_file"
  collect_scenario_srvctl_service_evidence "$prefix"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Application Continuity / TAC Replay Validation" \
    "This scenario validates whether services expose AC/TAC/Transaction Guard/FAN prerequisites and prepares an application replay drill. Full replay validation still requires an approved replay-safe client workload and driver/pool evidence." \
    "$evidence_file" "${prefix}_srvctl_config_service.out" "${prefix}_srvctl_status_service.out" "${prefix}_srvctl_config_ons.out"
  manifest_append "ac_tac_evidence" "$evidence_file"
  manifest_append "ac_tac_report" "$report_file"
  add_action "external" "AC_TAC_CLIENT_REPLAY" "Run an approved replay-safe client workload, trigger planned relocation or instance failure, and capture replay/FAN/application evidence; CrashSimulator keeps workload injection external."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_fan_ons_unavailable() {
  reset_actions
  local evidence_file report_file prefix onsctl_file
  prefix="${LOG_DIR}/crashsim_s84_${RUN_ID}_fan_ons"
  evidence_file="${prefix}.evidence"
  report_file="${prefix}.md"
  onsctl_file="${prefix}_onsctl.out"
  collect_service_continuity_evidence "$evidence_file"
  collect_scenario_srvctl_service_evidence "$prefix"
  if command -v onsctl >/dev/null 2>&1; then
    onsctl debug >"$onsctl_file" 2>&1 || onsctl ping >"$onsctl_file" 2>&1 || true
  else
    printf "onsctl not found in PATH.\n" >"$onsctl_file"
  fi
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator FAN / ONS Notification Availability" \
    "This scenario reviews FAN/ONS/service evidence and prepares a notification outage drill. Stopping ONS or breaking client notification paths is intentionally external because the correct action depends on Grid Infrastructure, client pools, and application failover design." \
    "$evidence_file" "${prefix}_srvctl_config_ons.out" "$onsctl_file" "${prefix}_crs_service_resources.out"
  manifest_append "fan_ons_evidence" "$evidence_file"
  manifest_append "fan_ons_report" "$report_file"
  add_action "external" "FAN_ONS_NOTIFICATION_PATH" "Approved lab action: interrupt ONS/FAN notification path, relocate/stop service, validate client reaction/replay, then restore notifications."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

collect_dg_transition_evidence() {
  local evidence_file="$1"
  sql_query "$evidence_file" "
select 'DATABASE|' || db_unique_name || '|' || database_role || '|' || open_mode || '|' || protection_mode || '|' || switchover_status || '|' || flashback_on
from v\$database;
select 'DEST|' || dest_id || '|' || nvl(status, 'UNKNOWN') || '|' || nvl(target, 'UNKNOWN') || '|' || nvl(destination, 'UNKNOWN') || '|' || nvl(db_unique_name, 'UNKNOWN') || '|' || nvl(error, 'NONE')
from v\$archive_dest
where target = 'STANDBY'
order by dest_id;
select 'DG_STAT|' || name || '|' || nvl(value, 'UNKNOWN') || '|' || nvl(unit, '')
from v\$dataguard_stats
where name in ('transport lag','apply lag','apply finish time')
order by name;
select 'SRL_COUNT|' || count(*) from v\$standby_log;
"
}

scenario_dg_switchover_drill() {
  reset_actions
  local evidence_file dgmgrl_file report_file
  evidence_file="${LOG_DIR}/crashsim_s85_${RUN_ID}_dg_switchover.evidence"
  dgmgrl_file="${LOG_DIR}/crashsim_s85_${RUN_ID}_dg_switchover_dgmgrl.out"
  report_file="${LOG_DIR}/crashsim_s85_${RUN_ID}_dg_switchover.md"
  collect_dg_transition_evidence "$evidence_file"
  collect_dgmgrl_fsfo_evidence "$dgmgrl_file" || true
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Planned Data Guard Switchover Drill" \
    "This scenario prepares a planned switchover rehearsal. Execution remains external so operators can choose the broker target, communication window, service behavior, application drain, validation, and optional switchback plan." \
    "$evidence_file" "$dgmgrl_file"
  manifest_append "dg_switchover_evidence" "$evidence_file"
  manifest_append "dg_switchover_report" "$report_file"
  add_action "external" "DG_SWITCHOVER" "Approved lab action: DGMGRL validate database/configuration, switchover to selected standby, validate role-based services/application, then document switchback/failback criteria."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_dg_failback_rehearsal() {
  reset_actions
  local evidence_file dgmgrl_file report_file
  evidence_file="${LOG_DIR}/crashsim_s86_${RUN_ID}_dg_failback.evidence"
  dgmgrl_file="${LOG_DIR}/crashsim_s86_${RUN_ID}_dg_failback_dgmgrl.out"
  report_file="${LOG_DIR}/crashsim_s86_${RUN_ID}_dg_failback.md"
  collect_dg_transition_evidence "$evidence_file"
  collect_dgmgrl_fsfo_evidence "$dgmgrl_file" || true
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Data Guard Failback Rehearsal" \
    "This scenario prepares failback/reinstate readiness after a failover or switchover. Execution remains external because the safe path depends on whether the original primary can be reinstated, flashed back, rebuilt, or switched back." \
    "$evidence_file" "$dgmgrl_file"
  manifest_append "dg_failback_evidence" "$evidence_file"
  manifest_append "dg_failback_report" "$report_file"
  add_action "external" "DG_FAILBACK_REINSTATE" "Approved lab action: validate broker state, reinstate or rebuild old primary as standby, validate apply/lag/services, then optionally switchover back."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_role_based_service_validation() {
  reset_actions
  local evidence_file report_file prefix
  prefix="${LOG_DIR}/crashsim_s87_${RUN_ID}_role_services"
  evidence_file="${prefix}.evidence"
  report_file="${prefix}.md"
  collect_service_continuity_evidence "$evidence_file"
  collect_scenario_srvctl_service_evidence "$prefix"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Role-Based Service Validation" \
    "This scenario reviews whether srvctl services are role-scoped for PRIMARY and PHYSICAL_STANDBY/ADG use. Full validation requires a switchover/failover rehearsal and application reconnect evidence." \
    "$evidence_file" "${prefix}_srvctl_config_service.out" "${prefix}_srvctl_status_service.out"
  manifest_append "role_service_evidence" "$evidence_file"
  manifest_append "role_service_report" "$report_file"
  add_action "external" "ROLE_BASED_SERVICES" "Run after an approved role transition: confirm primary services only start on primary and ADG/read-only services only start on standby role."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_pdb_pitr_drill() {
  reset_actions
  select_pdb_if_needed
  local evidence_file rman_file report_file aux_dest
  evidence_file="${LOG_DIR}/crashsim_s88_${RUN_ID}_pdb_pitr.evidence"
  rman_file="${LOG_DIR}/crashsim_s88_${RUN_ID}_pdb_pitr_preview.rman"
  report_file="${LOG_DIR}/crashsim_s88_${RUN_ID}_pdb_pitr.md"
  aux_dest="${CRASHSIM_PDB_PITR_AUX_DEST:-/tmp/crashsim_pdb_pitr_aux}"
  sql_query "$evidence_file" "
select 'DATABASE|' || db_unique_name || '|' || database_role || '|' || open_mode || '|' || log_mode || '|' || flashback_on
from v\$database;
select 'PDB|' || name || '|' || open_mode
from v\$pdbs
where name = $(sql_quote "$TARGET_PDB");
select 'DATAFILE|' || file_id || '|' || tablespace_name || '|' || file_name
from cdb_data_files
where con_id = (select con_id from v\$pdbs where name = $(sql_quote "$TARGET_PDB"))
order by file_id;
select 'BACKUP_JOB|' || nvl(status, 'UNKNOWN') || '|' || to_char(end_time, 'YYYY-MM-DD HH24:MI:SS')
from (
  select status, end_time
  from v\$rman_backup_job_details
  where end_time is not null
  order by end_time desc
)
where rownum <= 5;
"
  {
    printf "recover pluggable database %s until time \"to_date('<YYYY-MM-DD HH24:MI:SS>','YYYY-MM-DD HH24:MI:SS')\" auxiliary destination '%s' preview;\n" "$(sql_identifier "$TARGET_PDB")" "$aux_dest"
    printf "# Replace the timestamp and auxiliary destination after approval; run preview/validate before any recovery.\n"
  } >"$rman_file" || die "Unable to write PDB PITR RMAN preview file: $rman_file"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator PDB Point-In-Time Recovery Drill" \
    "This scenario prepares PDB PITR evidence and an RMAN preview template. Actual PDB PITR is intentionally operator-approved because it can close/recover the PDB and consume auxiliary storage." \
    "$evidence_file" "$rman_file"
  manifest_append "pdb_pitr_evidence" "$evidence_file"
  manifest_append "pdb_pitr_rman_preview" "$rman_file"
  manifest_append "pdb_pitr_report" "$report_file"
  add_action "external" "PDB_PITR_${TARGET_PDB}" "Approved recovery action: select timestamp, run RMAN preview/validate, recover PDB using auxiliary destination, open/validate PDB and application."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_guaranteed_restore_point_drill() {
  reset_actions
  local evidence_file report_file sql_template flashback
  evidence_file="${LOG_DIR}/crashsim_s89_${RUN_ID}_grp.evidence"
  report_file="${LOG_DIR}/crashsim_s89_${RUN_ID}_grp.md"
  sql_template="${LOG_DIR}/crashsim_s89_${RUN_ID}_grp_template.sql"
  sql_query "$evidence_file" "
select 'DATABASE|' || name || '|' || db_unique_name || '|' || open_mode || '|' || database_role || '|' || flashback_on
from v\$database;
select 'RESTORE_POINT|' || name || '|' || guarantee_flashback_database || '|' || to_char(time, 'YYYY-MM-DD HH24:MI:SS') || '|' || storage_size
from v\$restore_point
order by time desc;
select 'FRA|' || name || '|' || space_limit || '|' || space_used || '|' || space_reclaimable
from v\$recovery_file_dest;
"
  flashback="$(awk -F'|' '/^DATABASE/ {print $6; exit}' "$evidence_file")"
  [[ "$flashback" == "YES" ]] || die "Scenario 89 requires Flashback Database enabled. Current FLASHBACK_ON=${flashback:-unknown}."
  {
    printf "create guaranteed restore point CRASHSIM_GRP_<YYYYMMDDHH24MISS>;\n"
    printf "-- execute approved change here\n"
    printf "shutdown immediate;\nstartup mount;\n"
    printf "flashback database to restore point CRASHSIM_GRP_<YYYYMMDDHH24MISS>;\n"
    printf "alter database open resetlogs;\n"
    printf "drop restore point CRASHSIM_GRP_<YYYYMMDDHH24MISS>;\n"
  } >"$sql_template" || die "Unable to write GRP template: $sql_template"
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Guaranteed Restore Point Rollback Drill" \
    "This scenario validates Flashback/GRP readiness and creates an operator template for upgrade/patch/migration rollback drills. It does not create or flash back the database automatically." \
    "$evidence_file" "$sql_template"
  manifest_append "grp_evidence" "$evidence_file"
  manifest_append "grp_template" "$sql_template"
  manifest_append "grp_report" "$report_file"
  add_action "external" "GUARANTEED_RESTORE_POINT_ROLLBACK" "Approved change-window action: create GRP, execute change, flashback/open resetlogs if rollback is required, validate, and drop GRP when safe."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_database_patch_rollback_readiness() {
  reset_actions
  local evidence_file dgmgrl_file report_file
  evidence_file="${LOG_DIR}/crashsim_s90_${RUN_ID}_patch_rollback.evidence"
  dgmgrl_file="${LOG_DIR}/crashsim_s90_${RUN_ID}_patch_rollback_dgmgrl.out"
  report_file="${LOG_DIR}/crashsim_s90_${RUN_ID}_patch_rollback.md"
  sql_query "$evidence_file" "
select 'DATABASE|' || name || '|' || db_unique_name || '|' || open_mode || '|' || database_role || '|' || flashback_on || '|' || log_mode
from v\$database;
select 'REGISTRY|' || comp_id || '|' || version || '|' || status from dba_registry order by comp_id;
select 'SQLPATCH|' || patch_id || '|' || action || '|' || status || '|' || to_char(action_time, 'YYYY-MM-DD HH24:MI:SS') from dba_registry_sqlpatch order by action_time desc;
select 'RESTORE_POINT_COUNT|' || count(*) from v\$restore_point where guarantee_flashback_database = 'YES';
select 'BACKUP_JOB|' || nvl(status, 'UNKNOWN') || '|' || to_char(end_time, 'YYYY-MM-DD HH24:MI:SS') || '|' || nvl(input_type, 'UNKNOWN')
from (
  select status, end_time, input_type
  from v\$rman_backup_job_details
  where end_time is not null
  order by end_time desc
)
where rownum <= 10;
"
  collect_dgmgrl_fsfo_evidence "$dgmgrl_file" || true
  write_scenario_evidence_report "$report_file" \
    "CrashSimulator Database Patch Rollback Readiness" \
    "This scenario reviews whether patch/upgrade rollback controls are ready: recent backups, Flashback/GRP posture, SQL patch inventory, Data Guard/Broker evidence, and service behavior." \
    "$evidence_file" "$dgmgrl_file"
  manifest_append "patch_rollback_evidence" "$evidence_file"
  manifest_append "patch_rollback_report" "$report_file"
  add_action "external" "PATCH_ROLLBACK_READINESS" "Approved lifecycle action: create baseline backup/GRP, validate standby/app services, patch in a lab, and rehearse fallback before production."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

write_platform_plan_report() {
  local report_file="$1" title="$2" purpose="$3" evidence_file="$4"
  write_scenario_evidence_report "$report_file" "$title" "$purpose" "$evidence_file"
}

scenario_exadata_plan() {
  reset_actions
  local code="$1" title="$2" focus="$3" evidence_file report_file
  evidence_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_exadata.evidence"
  report_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_exadata.md"
  {
    printf "Exadata tooling evidence generated UTC %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for tool in cellcli dcli exacli exachk; do
      printf "\n== %s ==\n" "$tool"
      command -v "$tool" 2>/dev/null || printf "not found\n"
    done
    printf "\n== database storage evidence ==\n"
  } >"$evidence_file"
  collect_managed_storage_targets "${evidence_file}.storage" || true
  cat "${evidence_file}.storage" >>"$evidence_file" 2>/dev/null || true
  write_platform_plan_report "$report_file" "$title" "$focus" "$evidence_file"
  manifest_append "${code}_evidence" "$evidence_file"
  manifest_append "${code}_report" "$report_file"
  add_action "external" "$code" "Exadata-specific fault injection requires Exadata lab approval, cell/storage evidence, monitoring, and recovery runbook validation."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_exadata_cell_failure_review() { scenario_exadata_plan "EXA01" "CrashSimulator Exadata Cell Failure Review" "Review Exadata cell failure readiness, cell status evidence, database service continuity, ASM redundancy, and storage-server repair/rebalance runbooks."; }
scenario_exadata_storage_server_outage() { scenario_exadata_plan "EXA02" "CrashSimulator Exadata Storage Server Outage" "Prepare storage-server outage validation with cell status, ASM redundancy, database service continuity, and application impact evidence."; }
scenario_exadata_smart_scan_validation() { scenario_exadata_plan "EXA03" "CrashSimulator Exadata Smart Scan Validation" "Prepare Smart Scan validation before and after storage changes, SQL plans, cell offload metrics, and performance baselines."; }
scenario_exadata_flash_cache_failure() { scenario_exadata_plan "EXA04" "CrashSimulator Exadata Flash Cache Failure" "Prepare Flash Cache failure/recovery validation with cell metrics, workload response, and repair/rebalance evidence."; }

scenario_oci_db_plan() {
  reset_actions
  local code="$1" title="$2" focus="$3" evidence_file report_file
  evidence_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_oci_db.evidence"
  report_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_oci_db.md"
  {
    printf "OCI DB evidence generated UTC %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf "Host: %s\n" "$(hostname)"
    printf "\n== OCI CLI ==\n"
    command -v oci 2>/dev/null || printf "oci not found\n"
    [[ -n "${CRASHSIM_DB_SYSTEM_OCID:-}" ]] && printf "CRASHSIM_DB_SYSTEM_OCID=set\n" || printf "CRASHSIM_DB_SYSTEM_OCID=not set\n"
    [[ -n "${CRASHSIM_DB_HOME_OCID:-}" ]] && printf "CRASHSIM_DB_HOME_OCID=set\n" || printf "CRASHSIM_DB_HOME_OCID=not set\n"
    [[ -n "${CRASHSIM_DATABASE_OCID:-}" ]] && printf "CRASHSIM_DATABASE_OCID=set\n" || printf "CRASHSIM_DATABASE_OCID=not set\n"
    printf "\n== DBaaS tooling ==\n"
    for tool in /var/opt/oracle/dbaascli/dbaascli dbaascli dbcli odacli; do
      printf "%s: " "$tool"
      if command -v "$tool" >/dev/null 2>&1 || [[ -x "$tool" ]]; then
        printf "available\n"
      else
        printf "not found\n"
      fi
    done
  } >"$evidence_file"
  write_platform_plan_report "$report_file" "$title" "$focus" "$evidence_file"
  manifest_append "${code}_evidence" "$evidence_file"
  manifest_append "${code}_report" "$report_file"
  add_action "external" "$code" "OCI Base DB drill requires OCI CLI/DBaaS evidence, approved cloud-control-plane boundary, rollback path, and application validation."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_oci_db_backup_policy_validation() { scenario_oci_db_plan "OCI01" "CrashSimulator OCI Base DB Backup Policy Validation" "Validate OCI backup policy, RMAN/control-file evidence, retention, scheduling, Object Storage destination, and restore-test posture."; }
scenario_oci_cross_region_backup_recovery() { scenario_oci_db_plan "OCI02" "CrashSimulator OCI Cross-Region Backup Recovery" "Prepare cross-region backup restore validation, including target region, networking, encryption/wallets, RTO/RPO, and cleanup."; }
scenario_oci_db_system_failover() { scenario_oci_db_plan "OCI03" "CrashSimulator OCI Database System Failover" "Prepare DB system/node failure validation for OCI Base DB, including GI/RAC services, replacement procedures, and app reconnect."; }
scenario_oci_vcn_connectivity_loss() { scenario_oci_db_plan "OCI04" "CrashSimulator OCI VCN Connectivity Loss" "Prepare VCN connectivity-loss validation with route tables, NSGs, security lists, DNS, bastion, and client reconnect evidence."; }
scenario_oci_nsg_misconfiguration() { scenario_oci_db_plan "OCI05" "CrashSimulator OCI NSG Misconfiguration" "Prepare NSG/security-list misconfiguration validation with approved rollback and least-privilege evidence."; }

scenario_goldengate_plan() {
  reset_actions
  local code="$1" title="$2" focus="$3" evidence_file report_file
  evidence_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_goldengate.evidence"
  report_file="${LOG_DIR}/crashsim_${code}_${RUN_ID}_goldengate.md"
  {
    printf "GoldenGate evidence generated UTC %s\n" "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    for tool in ggsci adminclient oggca; do
      printf "\n== %s ==\n" "$tool"
      command -v "$tool" 2>/dev/null || printf "not found\n"
    done
    printf "\nOGG_HOME=%s\n" "${OGG_HOME:-not set}"
    printf "TNS_ADMIN=%s\n" "${TNS_ADMIN:-not set}"
  } >"$evidence_file"
  write_platform_plan_report "$report_file" "$title" "$focus" "$evidence_file"
  manifest_append "${code}_evidence" "$evidence_file"
  manifest_append "${code}_report" "$report_file"
  add_action "external" "$code" "GoldenGate drill requires approved deployment name, Extract/Replicat/trail targets, lag thresholds, and resync/recovery runbook."
  execute_actions
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_goldengate_extract_stopped() { scenario_goldengate_plan "GG01" "CrashSimulator GoldenGate Extract Stopped" "Prepare Extract stop/restart validation, checkpoint evidence, source capture lag, and downstream application impact evidence."; }
scenario_goldengate_replicat_stopped() { scenario_goldengate_plan "GG02" "CrashSimulator GoldenGate Replicat Stopped" "Prepare Replicat stop/restart validation, target apply lag, conflict handling, and resync evidence."; }
scenario_goldengate_lag_sla() { scenario_goldengate_plan "GG03" "CrashSimulator GoldenGate Lag Exceeds SLA" "Prepare GoldenGate lag threshold validation, monitoring evidence, alert routing, and catch-up behavior."; }
scenario_goldengate_trail_corruption() { scenario_goldengate_plan "GG04" "CrashSimulator GoldenGate Trail Corruption" "Prepare trail corruption/loss recovery runbook, including trail backup, reposition, resync, and data validation."; }

scenario_standby_apply_cancel() {
  reset_actions
  query_targets "$WORK_DIR/standby_apply_process.lst" "
select process || '|' || status
from (
  select process, status
  from v\$managed_standby
  where process like 'MRP%'
  order by process
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] ||
    die "No managed standby recovery process was detected. Start apply before running scenario 50."
  add_action "sql" "alter database recover managed standby database cancel;" "cancel managed standby recovery"
  execute_actions
}

scenario_primary_transport_defer() {
  reset_actions
  plan_dg_transport_defer "defer remote archive destination"
}

scenario_rac_abort_instance() {
  reset_actions
  case "$CLUSTER_TYPE" in
    GI_SINGLE)
      add_action "srvctl_abort_database" "$DB_UNIQUE_NAME" "abort GI-managed single-instance database"
      ;;
    *)
      add_action "srvctl_abort_instance" "$INSTANCE_NAME" "abort current RAC instance"
      ;;
  esac
  execute_actions
}

csv_contains_value() {
  local csv="$1"
  local needle="$2"
  local item
  local -a csv_items
  csv="${csv// /}"
  IFS=',' read -ra csv_items <<<"$csv"
  for item in "${csv_items[@]}"; do
    [[ "$item" == "$needle" ]] && return "$SUCCESS"
  done
  return "$FAIL"
}

first_csv_value() {
  local csv="$1"
  local item
  local -a csv_items
  csv="${csv// /}"
  IFS=',' read -ra csv_items <<<"$csv"
  for item in "${csv_items[@]}"; do
    if [[ -n "$item" ]]; then
      printf "%s\n" "$item"
      return "$SUCCESS"
    fi
  done
  return "$FAIL"
}

srvctl_database_instances_csv() {
  local status_file="$1"
  local instances
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"
  srvctl status database -d "$DB_UNIQUE_NAME" >"$status_file" 2>&1 ||
    die "Unable to collect srvctl database status for ${DB_UNIQUE_NAME}."
  instances="$(awk '/^Instance / {print $2}' "$status_file" | paste -sd, -)"
  [[ -n "$instances" ]] || return "$FAIL"
  printf "%s\n" "$instances"
}

scenario_rac_service_relocation() {
  reset_actions
  command -v srvctl >/dev/null 2>&1 || die "srvctl not found"
  [[ -n "$DB_UNIQUE_NAME" ]] || die "DB_UNIQUE_NAME was not discovered"

  local service config_file status_file db_status_file services_file
  local preferred running db_instances source_inst target_inst candidate
  local status_line service_count
  local -a service_candidates

  services_file="$WORK_DIR/srvctl_services.lst"
  srvctl config service -d "$DB_UNIQUE_NAME" >"$services_file" 2>&1 ||
    die "Unable to collect srvctl service configuration for ${DB_UNIQUE_NAME}."

  if [[ -n "$SERVICE_NAME" ]]; then
    service="$SERVICE_NAME"
  else
    service="$(awk -F': ' '/^Service name:/ {print $2; exit}' "$services_file")"
  fi
  [[ -n "$service" ]] || die "No srvctl-managed database service was found. Create a service before scenario 56."

  service_count="$(awk -F': ' '/^Service name:/ {count++} END {print count+0}' "$services_file")"
  if [[ -z "$SERVICE_NAME" && "${service_count:-0}" -gt 1 ]]; then
    warn "Multiple services were found; using first service '${service}'. Use --service-name to choose another service."
  fi

  config_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_config.out"
  status_file="$WORK_DIR/srvctl_service_${service//[^A-Za-z0-9_.-]/_}_status.out"
  db_status_file="$WORK_DIR/srvctl_database_status_for_services.out"

  srvctl config service -d "$DB_UNIQUE_NAME" -s "$service" >"$config_file" 2>&1 ||
    die "Service ${service} was not found in srvctl config for ${DB_UNIQUE_NAME}."
  srvctl status service -d "$DB_UNIQUE_NAME" -s "$service" >"$status_file" 2>&1 ||
    die "Unable to collect srvctl service status for ${service}."

  echo "srvctl config service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$config_file"
  echo
  echo "srvctl status service -d ${DB_UNIQUE_NAME} -s ${service}:"
  sed 's/^/  /' "$status_file"
  echo

  preferred="$(awk -F': ' '/^Preferred instances:/ {gsub(/[[:space:]]/, "", $2); print $2; exit}' "$config_file")"
  status_line="$(grep -E '^Service .* is running on instance' "$status_file" | head -n 1 || true)"
  running="$(printf "%s" "$status_line" | sed -E 's/^.*instance\(s\)[[:space:]]*//; s/[[:space:]]//g')"
  [[ -n "$running" ]] || die "Service ${service} is not running. Start it before relocation/failure practice."

  db_instances="$(srvctl_database_instances_csv "$db_status_file" || true)"
  [[ -n "$db_instances" ]] || db_instances="$preferred"
  [[ -n "$db_instances" ]] || die "Unable to discover RAC database instances for scenario 56."

  source_inst="$(first_csv_value "$running" || true)"
  [[ -n "$source_inst" ]] || die "Unable to determine source instance for service ${service}."

  target_inst=""
  IFS=',' read -ra service_candidates <<<"${preferred:-$db_instances}"
  for candidate in "${service_candidates[@]}"; do
    candidate="${candidate// /}"
    [[ -n "$candidate" ]] || continue
    if ! csv_contains_value "$running" "$candidate"; then
      target_inst="$candidate"
      break
    fi
  done
  if [[ -z "$target_inst" ]]; then
    IFS=',' read -ra service_candidates <<<"$db_instances"
    for candidate in "${service_candidates[@]}"; do
      candidate="${candidate// /}"
      [[ -n "$candidate" ]] || continue
      if ! csv_contains_value "$running" "$candidate"; then
        target_inst="$candidate"
        break
      fi
    done
  fi

  manifest_append "scenario_56_service" "$service"
  manifest_append "scenario_56_running_instances_before" "$running"
  manifest_append "scenario_56_preferred_instances" "$preferred"
  manifest_append "scenario_56_database_instances" "$db_instances"

  if [[ -n "$target_inst" ]]; then
    manifest_append "scenario_56_mode" "relocate"
    manifest_append "scenario_56_source_instance" "$source_inst"
    manifest_append "scenario_56_target_instance" "$target_inst"
    add_action "srvctl_relocate_service" "$service" "${source_inst}|${target_inst}"
  else
    manifest_append "scenario_56_mode" "stop_start_instance"
    manifest_append "scenario_56_source_instance" "$source_inst"
    add_action "srvctl_stop_start_service_instance" "$service" "$source_inst"
  fi
  execute_actions
}

scenario_tde_wallet() {
  reset_actions
  local wallet_file="$WORK_DIR/wallet.env"
  sql_query "$wallet_file" "
select name || '=' || nvl(value, '')
from v\$parameter
where name in ('wallet_root','tde_configuration');
"
  local wallet_root=""
  while IFS='=' read -r param_name param_value; do
    if [[ "$param_name" == "wallet_root" ]]; then
      wallet_root="$param_value"
    fi
  done < <(trim_blank_lines <"$wallet_file")
  [[ -n "$wallet_root" ]] || die "No wallet_root parameter was detected."
  TARGET_ROWS=("$wallet_root")
  add_fs_rename_targets
  execute_actions
}

scenario_archivelog_loss() {
  reset_actions
  query_targets "$WORK_DIR/archivelog_loss.lst" "
select name
from (
  select name
  from v\$archived_log
  where name is not null
    and nvl(deleted, 'NO') = 'NO'
  order by completion_time desc
)
where rownum = 1;
"
  add_fs_rename_targets
  execute_actions
}

scenario_fra_full() {
  reset_actions
  local fra_file="$WORK_DIR/fra_pressure.lst"
  local fra_line fra_name space_limit space_used space_reclaimable target_size headroom_bytes
  local sql_file sql_log

  query_targets "$fra_file" "
select name || '|' ||
       to_char(space_limit) || '|' ||
       to_char(space_used) || '|' ||
       to_char(space_reclaimable)
from v\$recovery_file_dest
where space_limit > 0;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No configured FRA destination was found in V\$RECOVERY_FILE_DEST."
  fra_line="${TARGET_ROWS[0]}"
  IFS='|' read -r fra_name space_limit space_used space_reclaimable <<<"$fra_line"
  [[ "$space_limit" =~ ^[0-9]+$ && "$space_used" =~ ^[0-9]+$ ]] ||
    die "Unable to parse FRA size evidence: ${fra_line}"
  [[ "$space_used" -gt 0 ]] ||
    die "FRA usage is zero. Generate archived redo or a small lab backup before running scenario 61."

  headroom_bytes=$((FRA_PRESSURE_HEADROOM_MB * 1024 * 1024))
  target_size="$(awk -v used="$space_used" -v pct="$FRA_PRESSURE_TARGET_PCT" -v headroom="$headroom_bytes" '
    BEGIN {
      by_pct = int((used * 100 / pct) + 0.999)
      by_headroom = used + headroom
      target = by_pct > by_headroom ? by_pct : by_headroom
      print target
    }')"
  [[ "$target_size" =~ ^[0-9]+$ ]] || die "Unable to calculate FRA pressure target size."
  if [[ "$target_size" -ge "$space_limit" ]]; then
    die "FRA pressure cannot be simulated by shrinking DB_RECOVERY_FILE_DEST_SIZE: current limit=${space_limit}, used=${space_used}, calculated target=${target_size}. Lower --fra-pressure-headroom-mb or generate more FRA usage in a lab."
  fi

  sql_file="${LOG_DIR}/crashsim_s61_${RUN_ID}_fra_pressure.sql"
  sql_log="${LOG_DIR}/crashsim_s61_${RUN_ID}_fra_pressure.log"
  write_fra_pressure_sql_file "$sql_file" "$space_limit" "$target_size"

  manifest_append "fra_name" "$fra_name"
  manifest_append "fra_original_size_bytes" "$space_limit"
  manifest_append "fra_space_used_bytes" "$space_used"
  manifest_append "fra_space_reclaimable_bytes" "$space_reclaimable"
  manifest_append "fra_pressure_target_size_bytes" "$target_size"
  manifest_append "fra_pressure_target_pct" "$FRA_PRESSURE_TARGET_PCT"
  manifest_append "fra_pressure_headroom_mb" "$FRA_PRESSURE_HEADROOM_MB"
  manifest_append "fra_pressure_sqlfile" "$sql_file"
  manifest_append "fra_pressure_log" "$sql_log"

  add_action "sqlfile" "$sql_file" "$sql_log"
  execute_actions
}

scenario_required_archivelog_recovery_gap() {
  reset_actions
  local archive_file="$WORK_DIR/required_archivelog_gap.lst"
  local row archive_name thread_no sequence_no first_change next_change completion_time rman_file

  query_targets "$archive_file" "
select name || '|' ||
       thread# || '|' ||
       sequence# || '|' ||
       first_change# || '|' ||
       next_change# || '|' ||
       to_char(completion_time, 'YYYY-MM-DD HH24:MI:SS')
from (
  select name, thread#, sequence#, first_change#, next_change#, completion_time
  from v\$archived_log
  where name is not null
    and nvl(deleted, 'NO') = 'NO'
    and nvl(standby_dest, 'NO') = 'NO'
    and completion_time is not null
  order by completion_time desc
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No available local archived redo log was found for required-recovery simulation."
  row="${TARGET_ROWS[0]}"
  IFS='|' read -r archive_name thread_no sequence_no first_change next_change completion_time <<<"$row"
  [[ -n "$archive_name" && "$sequence_no" =~ ^[0-9]+$ && "$thread_no" =~ ^[0-9]+$ ]] ||
    die "Unable to parse archived-log candidate metadata: ${row}"

  rman_file="${LOG_DIR}/crashsim_s62_${RUN_ID}_recovery_decision.rman"
  {
    printf "crosscheck archivelog thread %s sequence %s;\n" "$thread_no" "$sequence_no"
    printf "list archivelog thread %s sequence %s;\n" "$thread_no" "$sequence_no"
    printf "restore archivelog thread %s sequence %s validate;\n" "$thread_no" "$sequence_no"
    printf "recover database preview;\n"
  } >"$rman_file" || die "Unable to write scenario 62 RMAN decision file: $rman_file"

  manifest_append "archivelog_name" "$archive_name"
  manifest_append "archivelog_thread" "$thread_no"
  manifest_append "archivelog_sequence" "$sequence_no"
  manifest_append "archivelog_first_change" "$first_change"
  manifest_append "archivelog_next_change" "$next_change"
  manifest_append "archivelog_completion_time" "$completion_time"
  manifest_append "archivelog_recovery_decision_rman" "$rman_file"

  if [[ "$archive_name" == +* ]]; then
    add_action "external" "$archive_name" "ASM archived-log removal requires an ASM-aware handler; RMAN decision file: ${rman_file}"
  else
    add_action "fs_rename" "$archive_name" "thread=${thread_no} sequence=${sequence_no}; RMAN decision file: ${rman_file}"
  fi
  execute_actions
}

scenario_temp_exhaustion() {
  reset_actions
  local temp_file="$WORK_DIR/temp_exhaustion.lst"
  local container_clause="" target_context="root/non-CDB" sql_file sql_log
  local target_pdb_literal

  if [[ "$DB_CDB" == "YES" && -n "$TARGET_PDB" ]]; then
    target_pdb_literal="$(sql_quote "$TARGET_PDB")"
    query_targets "$temp_file" "
select p.name || '|' || tf.tablespace_name || '|' || count(*) || '|' || to_char(sum(tf.bytes))
from cdb_temp_files tf
join v\$pdbs p on p.con_id = tf.con_id
where p.name = ${target_pdb_literal}
group by p.name, tf.tablespace_name
order by tf.tablespace_name;
"
    container_clause="alter session set container = ${TARGET_PDB};"
    target_context="PDB ${TARGET_PDB}"
  else
    query_targets "$temp_file" "
select 'CDB\$ROOT' || '|' || tablespace_name || '|' || count(*) || '|' || to_char(sum(bytes))
from dba_temp_files
group by tablespace_name
order by tablespace_name;
"
  fi
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]] || die "No temporary tablespace/tempfile metadata was found for ${target_context}."

  sql_file="${LOG_DIR}/crashsim_s63_${RUN_ID}_temp_exhaustion.sql"
  sql_log="${LOG_DIR}/crashsim_s63_${RUN_ID}_temp_exhaustion.log"
  write_temp_exhaustion_sql_file "$sql_file" "$container_clause" "$TEMP_EXHAUST_MB"

  manifest_append "temp_exhaustion_context" "$target_context"
  manifest_append "temp_exhaustion_target_mb" "$TEMP_EXHAUST_MB"
  manifest_append "temp_exhaustion_sqlfile" "$sql_file"
  manifest_append "temp_exhaustion_log" "$sql_log"

  add_action "sqlfile" "$sql_file" "$sql_log"
  execute_actions
}

scenario_rto_validation() {
  reset_actions
  local report_file
  report_file="${LOG_DIR}/crashsim_rto_validation_${RUN_ID}.md"
  manifest_append "rto_validation_report" "$report_file"
  add_action "report" "RTO validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  write_rto_validation_report "$report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_rpo_validation() {
  reset_actions
  local sql_file evidence_file report_file
  sql_file="${LOG_DIR}/crashsim_rpo_validation_${RUN_ID}.sql"
  evidence_file="${LOG_DIR}/crashsim_rpo_validation_${RUN_ID}.evidence"
  report_file="${LOG_DIR}/crashsim_rpo_validation_${RUN_ID}.md"
  manifest_append "rpo_validation_sqlfile" "$sql_file"
  manifest_append "rpo_validation_evidence" "$evidence_file"
  manifest_append "rpo_validation_report" "$report_file"
  add_action "report" "RPO validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  ensure_sqlplus
  write_rpo_validation_sql_file "$sql_file"
  "$SQLPLUS_BIN" -s "$SQLPLUS_LOGON" @"$sql_file" >"$evidence_file" </dev/null ||
    die "RPO validation SQL failed: $sql_file (evidence: $evidence_file)"
  parse_rpo_evidence_file "$evidence_file"
  write_rpo_validation_report "$report_file" "$evidence_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

apex_ords_container_sql_prefix() {
  local target_pdb
  target_pdb="$(apex_ords_report_target_pdb)"
  if [[ -n "$target_pdb" ]]; then
    printf "alter session set container = %s;\n" "$(sql_identifier "$target_pdb")"
  fi
}

query_apex_ords_runtime_user() {
  local output_file="$1"
  local container_sql
  container_sql="$(apex_ords_container_sql_prefix)"
  query_targets "$output_file" "
${container_sql}
select username
from (
  select username
  from dba_users
  where username in ('APEX_PUBLIC_USER','ORDS_PUBLIC_USER')
    and account_status not like '%LOCKED%'
  order by case username when 'APEX_PUBLIC_USER' then 1 else 2 end
)
where rownum = 1;
"
  [[ "${#TARGET_ROWS[@]}" -gt 0 ]]
}

apex_installed_in_target_container() {
  local output_file="$WORK_DIR/apex_installed_check.out"
  local container_sql
  local apex_count
  container_sql="$(apex_ords_container_sql_prefix)"
  query_targets "$output_file" "
${container_sql}
select count(*)
from dba_registry
where comp_id = 'APEX'
   or upper(comp_name) like '%APEX%';
"
  apex_count="$(printf "%s" "${TARGET_ROWS[0]:-}" | tr -d '[:space:]')"
  [[ "${#TARGET_ROWS[@]}" -gt 0 && "$apex_count" =~ ^[0-9]+$ && "$apex_count" -gt 0 ]]
}

resolve_ords_continuity_url() {
  if [[ -n "$ORDS_LB_URL" ]]; then
    printf "%s" "$ORDS_LB_URL"
    return "$SUCCESS"
  fi

  command -v curl >/dev/null 2>&1 || return "$FAIL"
  local candidate
  candidate="http://localhost:18080/ords/"
  if [[ "$candidate" != "$ORDS_URL" ]] && curl -fsS -L --max-time 5 "$candidate" >/dev/null 2>&1; then
    printf "%s" "$candidate"
    return "$SUCCESS"
  fi

  command -v olsnodes >/dev/null 2>&1 || return "$FAIL"

  local current_host node
  current_host="$(hostname -s 2>/dev/null || hostname 2>/dev/null || true)"
  while read -r node _; do
    [[ -n "$node" ]] || continue
    [[ "$node" == "$current_host" ]] && continue
    candidate="http://${node}:8080/ords/"
    if curl -fsS -L --max-time 5 "$candidate" >/dev/null 2>&1; then
      printf "%s" "$candidate"
      return "$SUCCESS"
    fi
  done < <(olsnodes 2>/dev/null || true)

  return "$FAIL"
}

write_apex_ords_smoke_report() {
  local report_file="$1"
  local title="$2"
  local url_status="not checked"
  local lb_status="not supplied"

  if command -v curl >/dev/null 2>&1; then
    if curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1; then
      url_status="OK"
    else
      url_status="FAILED"
    fi
    if [[ -n "$ORDS_LB_URL" ]]; then
      if curl -fsS -L --max-time 10 "$ORDS_LB_URL" >/dev/null 2>&1; then
        lb_status="OK"
      else
        lb_status="FAILED"
      fi
    fi
  else
    url_status="curl not found"
    lb_status="curl not found"
  fi

  {
    printf "# %s\n\n" "$title"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- ORDS URL: `%s`\n' "$ORDS_URL"
    printf -- '- ORDS URL status: `%s`\n' "$url_status"
    printf -- '- ORDS load balancer URL: `%s`\n' "${ORDS_LB_URL:-not supplied}"
    printf -- '- ORDS load balancer status: `%s`\n' "$lb_status"
    printf "\n"
    printf "| Check | Result |\n"
    printf "| --- | --- |\n"
    printf '| ORDS smoke URL | `%s` |\n' "$(md_escape "$url_status")"
    printf '| Load balancer smoke URL | `%s` |\n' "$(md_escape "$lb_status")"
    printf "\nUse this smoke evidence together with application-specific APEX page URLs, login/session checks, and PDB/service health after database recovery.\n"
  } >"$report_file" || die "Unable to write APEX/ORDS smoke report: $report_file"
}

scenario_ords_service_unavailable() {
  reset_actions
  command -v ords >/dev/null 2>&1 ||
    die "ORDS binary was not found. Install ORDS before running ORDS service scenarios."
  ords_service_unit_exists ||
    die "ORDS systemd service unit was not found for service ${ORDS_SERVICE_NAME}."

  manifest_append "ords_service_name" "$ORDS_SERVICE_NAME"
  if can_control_ords_service; then
    add_action "systemctl_stop_service" "$ORDS_SERVICE_NAME" "simulate ORDS service outage; recover with --recover 73"
  else
    add_action "external" "$ORDS_SERVICE_NAME" "ORDS service control requires root or passwordless sudo for the current OS user"
  fi
  execute_actions
}

scenario_ords_config_unavailable() {
  reset_actions
  [[ -d "$ORDS_CONFIG_DIR" ]] ||
    die "ORDS configuration directory was not found: ${ORDS_CONFIG_DIR}."

  manifest_append "ords_config_dir" "$ORDS_CONFIG_DIR"
  if [[ -w "$ORDS_CONFIG_DIR" && -w "$(dirname "$ORDS_CONFIG_DIR")" ]]; then
    add_action "fs_rename" "$ORDS_CONFIG_DIR" "simulate ORDS configuration loss"
  elif ords_priv_helper_config_available; then
    add_action "ords_priv_config_rename" "$ORDS_CONFIG_DIR" "simulate ORDS configuration loss with approved helper; recover with --recover 74"
  else
    add_action "external" "$ORDS_CONFIG_DIR" "ORDS config directory is not writable by $(id -un); run with approved OS privileges or restore from config backup"
  fi
  execute_actions
}

scenario_ords_pool_misconfiguration() {
  reset_actions
  command -v ords >/dev/null 2>&1 ||
    die "ORDS binary was not found. Install ORDS before running ORDS pool scenarios."
  [[ -d "$ORDS_CONFIG_DIR" ]] ||
    die "ORDS configuration directory was not found: ${ORDS_CONFIG_DIR}."

  manifest_append "ords_config_dir" "$ORDS_CONFIG_DIR"
  manifest_append "ords_db_pool" "$ORDS_DB_POOL"
  if can_control_ords_service; then
    add_action "ords_pool_bad_service" "${ORDS_CONFIG_DIR}:${ORDS_DB_POOL}" "set db.servicename to a lab-bad value, restart ORDS, then recover with --recover 75"
  else
    add_action "external" "${ORDS_CONFIG_DIR}:${ORDS_DB_POOL}" "ORDS pool drill requires approved ORDS service restart privileges to mutate config and recover safely."
  fi
  execute_actions
}

scenario_apex_runtime_account_locked() {
  reset_actions
  local user_file runtime_user container_sql
  user_file="$WORK_DIR/apex_runtime_user.lst"
  query_apex_ords_runtime_user "$user_file" ||
    die "No unlocked APEX/ORDS runtime account was found. Install/configure APEX/ORDS or unlock APEX_PUBLIC_USER/ORDS_PUBLIC_USER first."
  runtime_user="${TARGET_ROWS[0]}"
  validate_oracle_name "$runtime_user" || die "Invalid runtime user discovered: $runtime_user"
  container_sql="$(apex_ords_container_sql_prefix)"

  manifest_append "apex_runtime_user" "$runtime_user"
  manifest_append "apex_runtime_target_container" "$(apex_ords_report_target_pdb || true)"
  add_action "sql" "${container_sql}alter user ${runtime_user} account lock;" "lock APEX/ORDS runtime account ${runtime_user}"
  execute_actions
}

scenario_apex_static_resources_unavailable() {
  reset_actions
  local images_dir
  images_dir="$(detect_apex_images_dir)" ||
    die "No APEX images/static files directory was found. Set --apex-images-dir or CRASHSIM_APEX_IMAGES_DIR after installing APEX static files."

  manifest_append "apex_images_dir" "$images_dir"
  if [[ -w "$images_dir" && -w "$(dirname "$images_dir")" ]]; then
    add_action "fs_rename" "$images_dir" "simulate missing APEX static files/images"
  else
    add_action "external" "$images_dir" "APEX static directory is not writable by $(id -un); run with approved OS privileges or use a writable lab static path"
  fi
  execute_actions
}

scenario_apex_application_availability_validation() {
  reset_actions
  command -v curl >/dev/null 2>&1 || die "curl was not found; cannot validate ORDS/APEX URL."
  curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1 ||
    die "ORDS/APEX smoke URL is not reachable now: ${ORDS_URL}."

  local report_file
  report_file="${LOG_DIR}/crashsim_apex_availability_s78_${RUN_ID}.md"
  manifest_append "apex_availability_report" "$report_file"
  add_action "report" "APEX/ORDS availability smoke validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  write_apex_ords_smoke_report "$report_file" "CrashSimulator APEX / ORDS Availability Smoke Evidence"
  cat "$report_file"
  maybe_render_html "$report_file"
}

run_apex_session_driver() {
  local report_file="$1"
  local session_url output_dir output_file headless_value
  local -a driver_cmd=()

  [[ -n "$APEX_SESSION_DRIVER" ]] || return "$SUCCESS"
  [[ -x "$APEX_SESSION_DRIVER" ]] ||
    die "APEX session driver is not executable: ${APEX_SESSION_DRIVER}"

  session_url="${APEX_SESSION_URL:-$ORDS_URL}"
  output_dir="${LOG_DIR}/apex_session_driver_s80_${RUN_ID}"
  output_file="${LOG_DIR}/crashsim_apex_session_driver_s80_${RUN_ID}.out"
  headless_value="true"
  [[ "$APEX_SESSION_HEADLESS" -eq 0 ]] && headless_value="false"

  manifest_append "apex_session_driver" "$APEX_SESSION_DRIVER"
  manifest_append "apex_session_driver_url" "$session_url"
  manifest_append "apex_session_driver_output_dir" "$output_dir"
  manifest_append "apex_session_driver_output_file" "$output_file"
  [[ -n "$APEX_SESSION_USERNAME" ]] && manifest_append "apex_session_driver_username" "$APEX_SESSION_USERNAME"
  [[ -n "$APEX_SESSION_SUCCESS_SELECTOR" ]] && manifest_append "apex_session_driver_success_selector" "$APEX_SESSION_SUCCESS_SELECTOR"

  driver_cmd=(
    "$APEX_SESSION_DRIVER"
    "--url" "$session_url"
    "--output-dir" "$output_dir"
    "--duration" "$APEX_SESSION_DURATION"
    "--interval" "$APEX_SESSION_INTERVAL"
    "--headless" "$headless_value"
    "--label" "scenario-80-${RUN_ID}"
  )
  [[ -n "$APEX_SESSION_USERNAME" ]] && driver_cmd+=("--username" "$APEX_SESSION_USERNAME")
  [[ -n "$APEX_SESSION_SUCCESS_SELECTOR" ]] && driver_cmd+=("--success-selector" "$APEX_SESSION_SUCCESS_SELECTOR")
  [[ -n "$APEX_SESSION_USERNAME_SELECTOR" ]] && driver_cmd+=("--username-selector" "$APEX_SESSION_USERNAME_SELECTOR")
  [[ -n "$APEX_SESSION_PASSWORD_SELECTOR" ]] && driver_cmd+=("--password-selector" "$APEX_SESSION_PASSWORD_SELECTOR")
  [[ -n "$APEX_SESSION_SUBMIT_SELECTOR" ]] && driver_cmd+=("--submit-selector" "$APEX_SESSION_SUBMIT_SELECTOR")

  echo "Running APEX browser-session driver: ${APEX_SESSION_DRIVER}"
  echo "Driver URL: ${session_url}"
  echo "Driver output directory: ${output_dir}"

  if CRASHSIM_APEX_SESSION_PASSWORD="$APEX_SESSION_PASSWORD" "${driver_cmd[@]}" >"$output_file" 2>&1; then
    manifest_append "apex_session_driver_status" "completed"
  else
    manifest_append "apex_session_driver_status" "failed"
    cat "$output_file" || true
    die "APEX browser-session driver failed. Output: ${output_file}"
  fi

  {
    printf "\n## Browser Session Driver\n\n"
    printf -- '- Driver: `%s`\n' "$(md_escape "$APEX_SESSION_DRIVER")"
    printf -- '- Session URL: `%s`\n' "$(md_escape "$session_url")"
    printf -- '- Duration seconds: `%s`\n' "$APEX_SESSION_DURATION"
    printf -- '- Interval seconds: `%s`\n' "$APEX_SESSION_INTERVAL"
    printf -- '- Headless: `%s`\n' "$headless_value"
    printf -- '- Driver output directory: `%s`\n' "$(md_escape "$output_dir")"
    printf -- '- Driver stdout/JSON: `%s`\n' "$(md_escape "$output_file")"
    if [[ -f "${output_dir}/apex_session_driver_report.md" ]]; then
      printf -- '- Driver Markdown report: `%s`\n' "$(md_escape "${output_dir}/apex_session_driver_report.md")"
    fi
    printf "\nDriver result JSON:\n\n"
    printf '```json\n'
    cat "$output_file"
    printf '\n```\n'
  } >>"$report_file" || die "Unable to append browser-session driver evidence: $report_file"
}

scenario_ords_lb_node_unavailable() {
  reset_actions
  local continuity_url report_file continuity_status
  command -v ords >/dev/null 2>&1 ||
    die "ORDS binary was not found. Install ORDS before running ORDS node-outage scenarios."
  ords_service_unit_exists ||
    die "ORDS systemd service unit was not found for service ${ORDS_SERVICE_NAME}."
  continuity_url="$(resolve_ords_continuity_url)" ||
    die "Scenario 79 requires --ords-lb-url/CRASHSIM_ORDS_LB_URL or a reachable peer ORDS node to validate continuity."

  manifest_append "ords_service_name" "$ORDS_SERVICE_NAME"
  manifest_append "ords_lb_url" "$continuity_url"
  if [[ -z "$ORDS_LB_URL" ]]; then
    manifest_append "ords_lb_url_source" "auto-detected peer ORDS URL"
  else
    manifest_append "ords_lb_url_source" "supplied"
  fi
  if can_control_ords_service; then
    add_action "systemctl_stop_service" "$ORDS_SERVICE_NAME" "simulate one ORDS node down behind load balancer; recover with --recover 79"
  else
    add_action "external" "$ORDS_SERVICE_NAME" "ORDS service control requires root or passwordless sudo for the current OS user"
  fi
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"

  continuity_status="NOT_REACHABLE"
  if curl -fsS -L --max-time 10 "$continuity_url" >/dev/null 2>&1; then
    continuity_status="OK"
  fi
  report_file="${LOG_DIR}/crashsim_ords_lb_node_s79_${RUN_ID}.md"
  manifest_append "ords_lb_node_report" "$report_file"
  manifest_append "ords_lb_node_continuity_status" "$continuity_status"
  {
    printf "# CrashSimulator ORDS Node Continuity Evidence\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Stopped local ORDS service: `%s`\n' "$ORDS_SERVICE_NAME"
    printf -- '- Continuity URL: `%s`\n' "$continuity_url"
    printf -- '- Continuity status: `%s`\n' "$continuity_status"
    printf "\nUse a real load balancer URL for production-grade validation. An auto-detected peer ORDS URL is acceptable for lab continuity practice but does not validate load-balancer health checks or routing policy.\n"
  } >"$report_file" || die "Unable to write scenario 79 report: $report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
  [[ "$continuity_status" == "OK" ]] ||
    die "Continuity URL was not reachable after stopping local ORDS service: ${continuity_url}"
}

scenario_apex_session_continuity() {
  reset_actions
  apex_installed_in_target_container ||
    die "APEX is not installed in the selected target container; session continuity evidence is not available yet."
  command -v curl >/dev/null 2>&1 || die "curl was not found; cannot validate ORDS/APEX URL."
  curl -fsS -L --max-time 10 "$ORDS_URL" >/dev/null 2>&1 ||
    die "ORDS/APEX smoke URL is not reachable now: ${ORDS_URL}."
  if [[ -n "$APEX_SESSION_DRIVER" ]]; then
    [[ -x "$APEX_SESSION_DRIVER" ]] ||
      die "APEX session driver is not executable: ${APEX_SESSION_DRIVER}"
    "$APEX_SESSION_DRIVER" --self-check >/dev/null 2>&1 ||
      die "APEX session driver self-check failed: ${APEX_SESSION_DRIVER}. Verify Node.js, Playwright, and the Chromium browser runtime on this host."
    if [[ -n "$APEX_SESSION_USERNAME" && -z "$APEX_SESSION_PASSWORD" ]]; then
      die "APEX session username was supplied but CRASHSIM_APEX_SESSION_PASSWORD/--apex-session-password is empty."
    fi
  fi

  local report_file continuity_url continuity_status
  report_file="${LOG_DIR}/crashsim_apex_session_continuity_s80_${RUN_ID}.md"
  continuity_url="$(resolve_ords_continuity_url || true)"
  continuity_status="not supplied"
  if [[ -n "$continuity_url" ]]; then
    if curl -fsS -L --max-time 10 "$continuity_url" >/dev/null 2>&1; then
      continuity_status="OK"
    else
      continuity_status="NOT_REACHABLE"
    fi
  fi

  manifest_append "apex_session_continuity_report" "$report_file"
  manifest_append "apex_session_ords_url" "$ORDS_URL"
  [[ -n "$continuity_url" ]] && manifest_append "apex_session_continuity_url" "$continuity_url"
  add_action "report" "APEX session continuity evidence" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  {
    printf "# CrashSimulator APEX Session Continuity Evidence\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Target PDB: `%s`\n' "$(apex_ords_report_target_pdb || true)"
    printf -- '- ORDS URL: `%s`\n' "$ORDS_URL"
    printf -- '- Continuity URL: `%s`\n' "${continuity_url:-not supplied}"
    printf -- '- Continuity URL status: `%s`\n' "$continuity_status"
    printf "\n| Check | Result |\n"
    printf "| --- | --- |\n"
    printf '| ORDS/APEX smoke URL | `OK` |\n'
    printf '| Continuity or peer URL | `%s` |\n' "$(md_escape "$continuity_status")"
    if [[ -n "$APEX_SESSION_DRIVER" ]]; then
      printf "\nA seeded APEX browser-session driver is configured. Driver evidence will be appended below.\n"
    else
      printf '\nNo seeded browser-session driver was configured. Use `--apex-session-driver` with a seeded APEX application URL when full end-user behavior capture is needed.\n'
    fi
    printf "\nUse this report during a live APEX browser session. Record whether the user sees seamless continuation, retry, relogin, lost page state, or failed transaction after ORDS/RAC/service/database failover.\n"
  } >"$report_file" || die "Unable to write scenario 80 report: $report_file"
  run_apex_session_driver "$report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_apex_mail_config_validation() {
  reset_actions
  apex_installed_in_target_container ||
    die "APEX is not installed in the selected target container; mail configuration validation is not available yet."

  local report_file
  report_file="${LOG_DIR}/crashsim_apex_mail_s81_${RUN_ID}.md"
  manifest_append "apex_mail_report" "$report_file"
  add_action "report" "APEX mail/SMTP/wallet/ACL validation" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  {
    printf "# CrashSimulator APEX Mail Configuration Validation\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Target PDB: `%s`\n' "$(apex_ords_report_target_pdb || true)"
    printf -- '- Detailed APEX/ORDS report: run `./%s --apex-ords-report --pdb %s --html`\n' "$PROGRAM" "${TARGET_PDB:-<pdb_name>}"
    printf "\nValidation focus: SMTP parameters, wallet/TLS dependencies, network ACLs, failed mail queue evidence, and post-recovery notification testing.\n"
  } >"$report_file" || die "Unable to write scenario 81 report: $report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_apex_patch_rollback_readiness() {
  reset_actions
  apex_installed_in_target_container ||
    die "APEX is not installed in the selected target container; upgrade/rollback readiness is not available yet."

  local report_file
  report_file="${LOG_DIR}/crashsim_apex_patch_readiness_s82_${RUN_ID}.md"
  manifest_append "apex_patch_readiness_report" "$report_file"
  add_action "report" "APEX upgrade/patch rollback readiness" "$report_file"
  execute_actions
  [[ "$PLANNING_ONLY" -eq 1 || "$EXECUTE" -eq 0 ]] && return "$SUCCESS"
  {
    printf "# CrashSimulator APEX Upgrade / Patch Rollback Readiness\n\n"
    printf -- '- Generated UTC: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf -- '- Target PDB: `%s`\n' "$(apex_ords_report_target_pdb || true)"
    printf -- '- ORDS version command: `ords --version`\n'
    printf "\nCapture APEX version/component status, invalid objects, runtime-user state, ORDS config/static-file backups, and representative application smoke checks before and after upgrade or rollback.\n"
  } >"$report_file" || die "Unable to write scenario 82 report: $report_file"
  cat "$report_file"
  maybe_render_html "$report_file"
}

scenario_planned() {
  local id="$1"
  echo "Scenario ${id} is registered but gated for a topology that is not available in this environment yet."
  echo "It is intentionally present so RAC, Data Guard, and ASM coverage can be tested as those labs are provided."
  echo "No destructive action was planned or executed."
}

parse_args() {
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --discover)
        MODE="discover"
        shift
        ;;
      --list|--list-scenarios|--scenarios)
        MODE="list"
        shift
        ;;
      --menu)
        MODE="menu"
        shift
        ;;
      --doctor|--preflight|--public-readiness)
        MODE="doctor"
        shift
        ;;
      --first-run|--first-run-guide|--getting-started)
        MODE="first_run"
        shift
        ;;
      --public-limitations|--limitations|--public-beta-limitations)
        MODE="public_limitations"
        shift
        ;;
      --health-check)
        MODE="health"
        shift
        ;;
      --config-report|--configuration-report|--report)
        MODE="report"
        shift
        ;;
      --backup-report|--backup-assessment|--recoverability-report)
        MODE="backup_report"
        shift
        ;;
      --service-review|--service-assessment|--services-report|--service-report)
        MODE="service_review"
        shift
        ;;
      --apex-ords-report|--apex-report|--ords-report|--apex-ords-readiness|--apex-readiness|--ords-readiness)
        MODE="apex_ords_report"
        shift
        ;;
      --prepare-environment|--seed-environment|--prepare-lab|--prepare-scenario-lab|--scenario-lab-prepare)
        MODE="prepare_environment"
        shift
        ;;
      --adb-readiness-report|--adb-report|--adb-discover|--autonomous-readiness|--autonomous-report|--autonomous-database-report)
        MODE="adb_readiness_report"
        shift
        ;;
      --list-adb-scenarios|--adb-scenarios|--adb-scenario-catalog|--autonomous-scenarios)
        MODE="adb_scenarios"
        shift
        ;;
      --baseline-backup|--fresh-baseline-backup|--run-baseline-backup)
        MODE="baseline_backup"
        shift
        ;;
      --audit-status|--audit-info)
        MODE="audit_status"
        shift
        ;;
      --purge-audit-logs|--audit-purge|--purge-logs)
        MODE="audit_purge"
        shift
        ;;
      --config)
        [[ "$#" -ge 2 ]] || die "--config requires a file path"
        CONFIG_FILE="$2"
        shift 2
        ;;
      --no-config)
        CONFIG_DISABLED=1
        shift
        ;;
      --show-config|--config-status)
        MODE="show_config"
        shift
        ;;
      --validate-config|--check-config)
        MODE="validate_config"
        shift
        ;;
      --write-config-template|--save-config-template)
        [[ "$#" -ge 2 ]] || die "$1 requires a file path"
        MODE="write_config_template"
        CONFIG_TEMPLATE_FILE="$2"
        shift 2
        ;;
      --review|--review-artifacts|--history|--activity-history)
        MODE="review"
        shift
        ;;
      --review-topology|--show-topology-cache|--topology-cache)
        MODE="review_topology"
        shift
        ;;
      --show-artifact|--view-artifact)
        [[ "$#" -ge 2 ]] || die "$1 requires an artifact path or latest:<kind>"
        MODE="show_artifact"
        REVIEW_TARGET="$2"
        shift 2
        ;;
      --render-html|--html-artifact|--artifact-html)
        [[ "$#" -ge 2 ]] || die "$1 requires an artifact path or latest:<kind>"
        MODE="render_html"
        HTML_TARGET="$2"
        shift 2
        ;;
      --maa-report|--maa-assessment|--maa-readiness)
        MODE="maa_report"
        shift
        ;;
      --resilience-scorecard|--resilience-score|--scorecard|--resilience-report)
        MODE="resilience_scorecard"
        shift
        ;;
      --deep-validate)
        REPORT_DEEP_VALIDATE=1
        shift
        ;;
      --html|--html-output)
        HTML_OUTPUT=1
        shift
        ;;
      --validate-scenario|--validate|--check-scenario)
        [[ "$#" -ge 2 ]] || die "$1 requires an id"
        MODE="validate"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --validate-all-scenarios|--validate-scenarios|--check-scenarios)
        MODE="validate_all"
        SCENARIO_ID=""
        shift
        ;;
      --scenario-readiness-report|--topology-scenario-report|--environment-scenario-report|--scenario-availability-report|--validate-environment-scenarios)
        MODE="scenario_readiness_report"
        SCENARIO_ID=""
        shift
        ;;
      --scenario-lifecycle-report|--scenario-lifecycle|--lifecycle-report|--scenario-coverage-report|--lifecycle-coverage-report)
        MODE="scenario_lifecycle_report"
        SCENARIO_ID=""
        shift
        ;;
      --scenario-lifecycle-check|--lifecycle-check|--scenario-coverage-check)
        MODE="scenario_lifecycle_check"
        SCENARIO_ID=""
        shift
        ;;
      --secret-scan|--scan-secrets)
        MODE="secret_scan"
        shift
        ;;
      --scan-path)
        [[ "$#" -ge 2 ]] || die "--scan-path requires a path"
        SECRET_SCAN_PATH="$2"
        shift 2
        ;;
      --sanitize-artifacts|--sanitize-public-artifacts)
        MODE="sanitize_artifacts"
        shift
        ;;
      --sanitize-source)
        [[ "$#" -ge 2 ]] || die "--sanitize-source requires a directory"
        SANITIZE_SOURCE_DIR="$2"
        shift 2
        ;;
      --sanitize-output)
        [[ "$#" -ge 2 ]] || die "--sanitize-output requires a directory"
        SANITIZE_OUTPUT_DIR="$2"
        shift 2
        ;;
      --release-check|--public-release-check)
        MODE="release_check"
        shift
        ;;
      --node-sync-check|--multi-node-sync-check)
        MODE="node_sync_check"
        shift
        ;;
      --runbook)
        [[ "$#" -ge 2 ]] || die "--runbook requires an id"
        MODE="runbook"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --protect)
        [[ "$#" -ge 2 ]] || die "--protect requires an id"
        MODE="protect"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --recover)
        [[ "$#" -ge 2 ]] || die "--recover requires an id"
        MODE="recover"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --scenario)
        [[ "$#" -ge 2 ]] || die "--scenario requires an id"
        MODE="scenario"
        SCENARIO_ID="$2"
        shift 2
        ;;
      --random-scenario|--aleatory-scenario)
        MODE="random"
        SCENARIO_ID=""
        shift
        ;;
      --adb-scenario)
        [[ "$#" -ge 2 ]] || die "--adb-scenario requires an ADB scenario id"
        MODE="adb_scenario_detail"
        ADB_SCENARIO_ID="$2"
        shift 2
        ;;
      --pdb)
        [[ "$#" -ge 2 ]] || die "--pdb requires a PDB name"
        TARGET_PDB="$2"
        shift 2
        ;;
      --schema)
        [[ "$#" -ge 2 ]] || die "--schema requires a schema name"
        TARGET_SCHEMA="$2"
        shift 2
        ;;
      --file-no)
        [[ "$#" -ge 2 ]] || die "--file-no requires a file number"
        TARGET_FILE_NO="$2"
        shift 2
        ;;
      --manifest)
        [[ "$#" -ge 2 ]] || die "--manifest requires a file path"
        MANIFEST_FILE="$2"
        MANIFEST_FROM_ARG=1
        shift 2
        ;;
      --pfile)
        [[ "$#" -ge 2 ]] || die "--pfile requires a file path"
        PFILE_PATH="$2"
        shift 2
        ;;
      --sys-password)
        [[ "$#" -ge 2 ]] || die "--sys-password requires a value"
        SYS_PASSWORD="$2"
        shift 2
        ;;
      --service-name)
        [[ "$#" -ge 2 ]] || die "--service-name requires a service name"
        SERVICE_NAME="$2"
        shift 2
        ;;
      --ords-service)
        [[ "$#" -ge 2 ]] || die "--ords-service requires a service name"
        ORDS_SERVICE_NAME="$2"
        shift 2
        ;;
      --ords-config-dir)
        [[ "$#" -ge 2 ]] || die "--ords-config-dir requires a directory"
        ORDS_CONFIG_DIR="$2"
        shift 2
        ;;
      --ords-url)
        [[ "$#" -ge 2 ]] || die "--ords-url requires a URL"
        ORDS_URL="$2"
        shift 2
        ;;
      --ords-lb-url)
        [[ "$#" -ge 2 ]] || die "--ords-lb-url requires a URL"
        ORDS_LB_URL="$2"
        shift 2
        ;;
      --ords-priv-helper)
        [[ "$#" -ge 2 ]] || die "--ords-priv-helper requires a path"
        ORDS_PRIV_HELPER="$2"
        shift 2
        ;;
      --apex-images-dir)
        [[ "$#" -ge 2 ]] || die "--apex-images-dir requires a directory"
        APEX_IMAGES_DIR="$2"
        shift 2
        ;;
      --apex-session-driver)
        [[ "$#" -ge 2 ]] || die "--apex-session-driver requires a path"
        APEX_SESSION_DRIVER="$2"
        shift 2
        ;;
      --apex-session-url)
        [[ "$#" -ge 2 ]] || die "--apex-session-url requires a URL"
        APEX_SESSION_URL="$2"
        shift 2
        ;;
      --apex-session-username)
        [[ "$#" -ge 2 ]] || die "--apex-session-username requires a user name"
        APEX_SESSION_USERNAME="$2"
        shift 2
        ;;
      --apex-session-password)
        [[ "$#" -ge 2 ]] || die "--apex-session-password requires a value"
        APEX_SESSION_PASSWORD="$2"
        shift 2
        ;;
      --apex-session-success-selector)
        [[ "$#" -ge 2 ]] || die "--apex-session-success-selector requires a CSS selector"
        APEX_SESSION_SUCCESS_SELECTOR="$2"
        shift 2
        ;;
      --apex-session-username-selector)
        [[ "$#" -ge 2 ]] || die "--apex-session-username-selector requires a CSS selector"
        APEX_SESSION_USERNAME_SELECTOR="$2"
        shift 2
        ;;
      --apex-session-password-selector)
        [[ "$#" -ge 2 ]] || die "--apex-session-password-selector requires a CSS selector"
        APEX_SESSION_PASSWORD_SELECTOR="$2"
        shift 2
        ;;
      --apex-session-submit-selector)
        [[ "$#" -ge 2 ]] || die "--apex-session-submit-selector requires a CSS selector"
        APEX_SESSION_SUBMIT_SELECTOR="$2"
        shift 2
        ;;
      --apex-session-duration)
        [[ "$#" -ge 2 ]] || die "--apex-session-duration requires seconds"
        APEX_SESSION_DURATION="$2"
        shift 2
        ;;
      --apex-session-interval)
        [[ "$#" -ge 2 ]] || die "--apex-session-interval requires seconds"
        APEX_SESSION_INTERVAL="$2"
        shift 2
        ;;
      --apex-session-headless)
        [[ "$#" -ge 2 ]] || die "--apex-session-headless requires yes/no"
        APEX_SESSION_HEADLESS="$2"
        shift 2
        ;;
      --adb-wallet-dir)
        [[ "$#" -ge 2 ]] || die "--adb-wallet-dir requires a directory"
        ADB_WALLET_DIR="$2"
        shift 2
        ;;
      --adb-connect-alias)
        [[ "$#" -ge 2 ]] || die "--adb-connect-alias requires an alias"
        ADB_CONNECT_ALIAS="$2"
        shift 2
        ;;
      --adb-service-level)
        [[ "$#" -ge 2 ]] || die "--adb-service-level requires a value"
        ADB_SERVICE_LEVEL="$2"
        shift 2
        ;;
      --adb-connect-descriptor)
        [[ "$#" -ge 2 ]] || die "--adb-connect-descriptor requires a descriptor or Easy Connect string"
        ADB_CONNECT_DESCRIPTOR="$2"
        shift 2
        ;;
      --adb-user)
        [[ "$#" -ge 2 ]] || die "--adb-user requires a user name"
        ADB_USER="$2"
        shift 2
        ;;
      --adb-password-env)
        [[ "$#" -ge 2 ]] || die "--adb-password-env requires an environment variable name"
        ADB_PASSWORD_ENV="$2"
        shift 2
        ;;
      --adb-wallet-password-env)
        [[ "$#" -ge 2 ]] || die "--adb-wallet-password-env requires an environment variable name"
        ADB_WALLET_PASSWORD_ENV="$2"
        shift 2
        ;;
      --adb-python)
        [[ "$#" -ge 2 ]] || die "--adb-python requires a Python executable"
        ADB_PYTHON="$2"
        shift 2
        ;;
      --adb-tls-mode)
        [[ "$#" -ge 2 ]] || die "--adb-tls-mode requires TLS or mTLS"
        ADB_TLS_MODE="$2"
        shift 2
        ;;
      --adb-ocid)
        [[ "$#" -ge 2 ]] || die "--adb-ocid requires an OCID"
        ADB_OCID="$2"
        shift 2
        ;;
      --adb-compartment-ocid)
        [[ "$#" -ge 2 ]] || die "--adb-compartment-ocid requires an OCID"
        ADB_COMPARTMENT_OCID="$2"
        shift 2
        ;;
      --adb-region)
        [[ "$#" -ge 2 ]] || die "--adb-region requires a region"
        ADB_REGION="$2"
        shift 2
        ;;
      --adb-oci-profile)
        [[ "$#" -ge 2 ]] || die "--adb-oci-profile requires a profile name"
        ADB_OCI_PROFILE="$2"
        shift 2
        ;;
      --adb-oci-config-file)
        [[ "$#" -ge 2 ]] || die "--adb-oci-config-file requires a file path"
        ADB_OCI_CONFIG_FILE="$2"
        shift 2
        ;;
      --adb-oci-auth)
        [[ "$#" -ge 2 ]] || die "--adb-oci-auth requires an auth mode"
        ADB_OCI_AUTH="$2"
        shift 2
        ;;
      --adb-apex-url)
        [[ "$#" -ge 2 ]] || die "--adb-apex-url requires a URL"
        ADB_APEX_URL="$2"
        shift 2
        ;;
      --adb-database-actions-url)
        [[ "$#" -ge 2 ]] || die "--adb-database-actions-url requires a URL"
        ADB_DATABASE_ACTIONS_URL="$2"
        shift 2
        ;;
      --adb-private-endpoint)
        [[ "$#" -ge 2 ]] || die "--adb-private-endpoint requires a value"
        ADB_PRIVATE_ENDPOINT="$2"
        shift 2
        ;;
      --sysbackup-user)
        [[ "$#" -ge 2 ]] || die "--sysbackup-user requires a user name"
        SYSBACKUP_USER="$2"
        shift 2
        ;;
      --local-only)
        LOCAL_ONLY=1
        shift
        ;;
      --max-targets)
        [[ "$#" -ge 2 ]] || die "--max-targets requires a positive integer"
        MAX_TARGETS="$2"
        shift 2
        ;;
      --piece-handle)
        [[ "$#" -ge 2 ]] || die "--piece-handle requires a backup-piece handle"
        PIECE_HANDLE="$2"
        shift 2
        ;;
      --rman-catalog)
        [[ "$#" -ge 2 ]] || die "--rman-catalog requires a recovery catalog connect string"
        RMAN_CATALOG_CONNECT="$2"
        shift 2
        ;;
      --backup-tag-prefix|--baseline-tag-prefix|--tag-prefix)
        [[ "$#" -ge 2 ]] || die "$1 requires a tag prefix"
        BASELINE_TAG_PREFIX="$2"
        shift 2
        ;;
      --fra-pressure-target-pct)
        [[ "$#" -ge 2 ]] || die "--fra-pressure-target-pct requires a percentage"
        FRA_PRESSURE_TARGET_PCT="$2"
        shift 2
        ;;
      --fra-pressure-headroom-mb)
        [[ "$#" -ge 2 ]] || die "--fra-pressure-headroom-mb requires a size in MB"
        FRA_PRESSURE_HEADROOM_MB="$2"
        shift 2
        ;;
      --temp-exhaust-mb)
        [[ "$#" -ge 2 ]] || die "--temp-exhaust-mb requires a size in MB"
        TEMP_EXHAUST_MB="$2"
        shift 2
        ;;
      --audit-retain|--retain-logs)
        [[ "$#" -ge 2 ]] || die "$1 requires yes or no"
        AUDIT_RETAIN="$2"
        shift 2
        ;;
      --no-audit-retain|--no-retain-logs)
        AUDIT_RETAIN=0
        shift
        ;;
      --audit-retention-days|--log-retention-days)
        [[ "$#" -ge 2 ]] || die "$1 requires a number of days"
        AUDIT_RETENTION_DAYS="$2"
        shift 2
        ;;
      --audit-dir)
        [[ "$#" -ge 2 ]] || die "--audit-dir requires a directory"
        AUDIT_DIR="$2"
        shift 2
        ;;
      --auto-scorecard|--auto-resilience-scorecard)
        [[ "$#" -ge 2 ]] || die "$1 requires yes or no"
        AUTO_SCORECARD="$2"
        shift 2
        ;;
      --no-auto-scorecard|--no-auto-resilience-scorecard)
        AUTO_SCORECARD=0
        shift
        ;;
      --maa-app-name)
        [[ "$#" -ge 2 ]] || die "--maa-app-name requires a value"
        MAA_APP_NAME="$2"
        shift 2
        ;;
      --maa-local-rto)
        [[ "$#" -ge 2 ]] || die "--maa-local-rto requires a value"
        MAA_LOCAL_RTO="$2"
        shift 2
        ;;
      --maa-local-rpo)
        [[ "$#" -ge 2 ]] || die "--maa-local-rpo requires a value"
        MAA_LOCAL_RPO="$2"
        shift 2
        ;;
      --maa-dr-rto)
        [[ "$#" -ge 2 ]] || die "--maa-dr-rto requires a value"
        MAA_DR_RTO="$2"
        shift 2
        ;;
      --maa-dr-rpo)
        [[ "$#" -ge 2 ]] || die "--maa-dr-rpo requires a value"
        MAA_DR_RPO="$2"
        shift 2
        ;;
      --maa-planned-rto)
        [[ "$#" -ge 2 ]] || die "--maa-planned-rto requires a value"
        MAA_PLANNED_RTO="$2"
        shift 2
        ;;
      --maa-planned-rpo)
        [[ "$#" -ge 2 ]] || die "--maa-planned-rpo requires a value"
        MAA_PLANNED_RPO="$2"
        shift 2
        ;;
      --maa-criticality)
        [[ "$#" -ge 2 ]] || die "--maa-criticality requires a value"
        MAA_CRITICALITY="$2"
        shift 2
        ;;
      --maa-local-ha-target)
        [[ "$#" -ge 2 ]] || die "--maa-local-ha-target requires a value"
        MAA_LOCAL_HA_TARGET="$2"
        shift 2
        ;;
      --maa-dr-required)
        [[ "$#" -ge 2 ]] || die "--maa-dr-required requires a value"
        MAA_DR_REQUIRED="$2"
        shift 2
        ;;
      --maa-automatic-failover-required)
        [[ "$#" -ge 2 ]] || die "--maa-automatic-failover-required requires a value"
        MAA_AUTOMATIC_FAILOVER_REQUIRED="$2"
        shift 2
        ;;
      --maa-active-active-required)
        [[ "$#" -ge 2 ]] || die "--maa-active-active-required requires a value"
        MAA_ACTIVE_ACTIVE_REQUIRED="$2"
        shift 2
        ;;
      --maa-platform-hint)
        [[ "$#" -ge 2 ]] || die "--maa-platform-hint requires a value"
        MAA_PLATFORM_HINT="$2"
        shift 2
        ;;
      --maa-standby-scope)
        [[ "$#" -ge 2 ]] || die "--maa-standby-scope requires a value"
        MAA_STANDBY_SCOPE="$2"
        shift 2
        ;;
      --dry-run)
        EXECUTE=0
        shift
        ;;
      --execute)
        EXECUTE=1
        shift
        ;;
      --yes)
        ASSUME_YES=1
        shift
        ;;
      --accept-destructive-lab)
        DESTRUCTIVE_LAB_ACK="YES"
        shift
        ;;
      --topology-cache-ttl)
        [[ "$#" -ge 2 ]] || die "--topology-cache-ttl requires seconds"
        TOPOLOGY_CACHE_TTL_SECONDS="$2"
        shift 2
        ;;
      --refresh-topology)
        TOPOLOGY_CACHE_REFRESH=1
        shift
        ;;
      --no-topology-cache)
        TOPOLOGY_CACHE_DISABLED=1
        shift
        ;;
      --log-dir)
        [[ "$#" -ge 2 ]] || die "--log-dir requires a directory"
        LOG_DIR="$2"
        shift 2
        ;;
      --sqlplus-logon)
        [[ "$#" -ge 2 ]] || die "--sqlplus-logon requires a logon string"
        SQLPLUS_LOGON="$2"
        shift 2
        ;;
      --verbose)
        VERBOSE=1
        shift
        ;;
      --help|-h)
        usage
        exit "$SUCCESS"
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

menu_pause() {
  local answer
  echo
  echo "Press Enter to continue..."
  read -r answer || true
}

menu_selected_scenario_label() {
  if [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]; then
    printf "%s - %s" "$SCENARIO_ID" "${SCENARIO_TITLE[$SCENARIO_ID]}"
  else
    printf "none"
  fi
}

menu_discover_environment_optional() {
  if load_topology_cache; then
    return "$SUCCESS"
  fi

  if [[ "$ORACLE_USER_REQUIRED" -eq 1 && "$(id -un)" != "oracle" ]]; then
    warn "Database topology discovery skipped: this run requires OS user oracle, current user is $(id -un)."
    warn "ADB scenarios, ADB readiness reports, review, and configuration menus remain available."
    return "$SUCCESS"
  fi

  if ! find_sqlplus_if_available; then
    warn "Database topology discovery skipped: sqlplus was not found. Set ORACLE_HOME or SQLPLUS for database-host scenarios."
    warn "ADB scenarios, ADB readiness reports, review, and configuration menus remain available."
    return "$SUCCESS"
  fi

  discover_environment || warn "Database topology discovery did not complete. The guided menu will open with currently available context."
}

menu_print_header() {
  echo
  echo "CrashSimulator V2 ${VERSION}"
  echo "Database: ${DB_UNIQUE_NAME:-not discovered}  Role: ${DB_ROLE:-unknown}  Open: ${DB_OPEN_MODE:-unknown}  CDB: ${DB_CDB:-unknown}"
  echo "Instance: ${INSTANCE_NAME:-unknown}  Storage: ${STORAGE_TYPE:-unknown}  Cluster: ${CLUSTER_TYPE:-unknown}"
  echo
  echo "Selected scenario: $(menu_selected_scenario_label)"
  if [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]; then
    echo "Lifecycle: validation=$(scenario_validation_capability) | protection=$(scenario_protection_capability "$SCENARIO_ID") | recovery=$(scenario_recovery_capability "$SCENARIO_ID")"
  fi
  echo "PDB: ${TARGET_PDB:-not set}  Schema: ${TARGET_SCHEMA:-not set}  FILE#: ${TARGET_FILE_NO:-not set}"
  echo "Manifest: ${MANIFEST_FILE:-not set}"
  echo "Log dir: ${LOG_DIR}"
  echo "Report deep validation: ${REPORT_DEEP_VALIDATE}"
  echo "Baseline backup tag prefix: ${BASELINE_TAG_PREFIX}"
  echo "Config file: ${CONFIG_SOURCE:-not loaded}"
  echo "Audit retain: ${AUDIT_RETAIN}  Retention days: ${AUDIT_RETENTION_DAYS}  Audit dir: ${AUDIT_DIR}"
  echo "Scenario 25 guards: local-only=${LOCAL_ONLY}  max-targets=${MAX_TARGETS:-not set}  piece-handle=$([[ -n "$PIECE_HANDLE" ]] && echo set || echo not-set)"
  echo "RMAN catalog: $([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo configured || echo not configured)"
  echo "Password-file recovery: SYS password=$([[ -n "$SYS_PASSWORD" ]] && echo set || echo not-set)  service=${SERVICE_NAME:-not set}"
  echo "Scenario 61/63 knobs: FRA target=${FRA_PRESSURE_TARGET_PCT}%  FRA headroom=${FRA_PRESSURE_HEADROOM_MB}MB  TEMP workload=${TEMP_EXHAUST_MB}MB"
  echo "ADB scenario: ${ADB_SCENARIO_ID:-not set}"
}

menu_select_scenario() {
  local answer

  echo
  list_scenarios
  echo
  echo "Enter scenario id to select, or blank to keep current:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"

  if scenario_exists "$answer"; then
    SCENARIO_ID="$answer"
    MENU_SCHEMA_PROMPTED_SCENARIO=""
    echo "Selected scenario ${SCENARIO_ID}: ${SCENARIO_TITLE[$SCENARIO_ID]}"
    menu_ensure_scenario_context "select" "dry-run" || menu_show_selected_scenario_readiness
    echo "Use menu option 17 to generate the full topology-versus-scenario readiness report."
  else
    warn "Unknown scenario id: $answer"
    return "$FAIL"
  fi
}

menu_require_scenario() {
  if [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]; then
    return "$SUCCESS"
  fi
  menu_select_scenario
  [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]]
}

menu_select_pdb() {
  local answer idx row name con_id open_mode

  discover_environment || true
  echo
  if [[ "$DB_CDB" != "YES" ]]; then
    warn "The discovered database is not a CDB. Leave PDB unset for non-CDB scenarios."
  elif [[ "${#PDB_ROWS[@]}" -gt 0 ]]; then
    echo "Available PDBs:"
    idx=1
    for row in "${PDB_ROWS[@]}"; do
      IFS='|' read -r name con_id open_mode <<<"$row"
      printf "  %2d. %-30s CON_ID=%-5s OPEN_MODE=%s\n" "$idx" "$name" "$con_id" "$open_mode"
      idx=$((idx + 1))
    done
  fi

  echo
  echo "Enter PDB name or number, c to clear, or blank to keep [${TARGET_PDB:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      TARGET_PDB=""
      echo "PDB target cleared."
      return "$SUCCESS"
      ;;
  esac

  if [[ "$answer" =~ ^[0-9]+$ && "${#PDB_ROWS[@]}" -gt 0 && "$answer" -ge 1 && "$answer" -le "${#PDB_ROWS[@]}" ]]; then
    IFS='|' read -r TARGET_PDB con_id open_mode <<<"${PDB_ROWS[$((answer - 1))]}"
  else
    TARGET_PDB="$(normalize_name "$answer")"
  fi
  validate_oracle_name "$TARGET_PDB" || {
    warn "Invalid PDB name: $TARGET_PDB"
    TARGET_PDB=""
    return "$FAIL"
  }
  echo "PDB target set to ${TARGET_PDB}."
}

scenario_requires_pdb_context() {
  local id="$1"
  [[ ",${SCENARIO_REQUIRES[$id]:-}," == *,pdb,* ]]
}

scenario_uses_schema_context() {
  local id="$1"
  case "$id" in
    11|36|43|44) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

scenario_schema_prompt_default_yes() {
  local id="$1"
  case "$id" in
    44) return "$SUCCESS" ;;
    *) return "$FAIL" ;;
  esac
}

scenario_file_no_context_useful() {
  local id="$1"
  supports_file_recovery_automation "$id"
}

menu_auto_select_single_pdb() {
  local row con_id open_mode

  discover_environment || true
  [[ "$DB_CDB" == "YES" && -z "$TARGET_PDB" && "${#PDB_ROWS[@]}" -eq 1 ]] || return "$FAIL"
  IFS='|' read -r TARGET_PDB con_id open_mode <<<"${PDB_ROWS[0]}"
  echo "Using only available PDB: ${TARGET_PDB} (OPEN_MODE=${open_mode})"
}

menu_select_schema() {
  local answer idx row owner table_count index_count candidate_filter confirm_token schema_safe
  local target_file="$WORK_DIR/menu_schema_candidates.lst"

  echo
  echo "Schema selection"
  candidate_filter=""
  case "${SCENARIO_ID:-}" in
    11|36)
      candidate_filter="and exists (select 1 from dba_indexes i where i.owner = u.username and i.uniqueness = 'NONUNIQUE')"
      ;;
    43)
      candidate_filter="and exists (select 1 from dba_tables t where t.owner = u.username and t.nested = 'NO' and t.temporary = 'N' and t.secondary = 'N')"
      ;;
  esac
  # A configured CRASHSIM_PDB from another environment (e.g. the conf example's
  # CRASHPDB on a database whose PDB is named differently) used to flow straight
  # into 'alter session set container' here and die with a raw ORA-65011.
  # Validate it against the discovered PDB list first and fall back sensibly.
  if [[ -n "$TARGET_PDB" && "$DB_CDB" == "YES" ]] && ! pdb_exists "$TARGET_PDB"; then
    warn "Configured PDB ${TARGET_PDB} does not exist on this database (available: $(pdb_list_for_message))."
    warn "Check CRASHSIM_PDB in crashsimulator.conf (or the --pdb value)."
    if [[ "${#PDB_ROWS[@]}" -eq 1 ]]; then
      IFS='|' read -r TARGET_PDB _ _ <<<"${PDB_ROWS[0]}"
      echo "Falling back to the only available PDB: ${TARGET_PDB}"
    else
      TARGET_PDB=""
      return "$FAIL"
    fi
  fi
  if [[ -n "$TARGET_PDB" ]]; then
    sql_query "$target_file" "
alter session set container = ${TARGET_PDB};
select username || '|' ||
       (select count(*) from dba_tables t where t.owner = u.username and t.nested = 'NO' and t.temporary = 'N') || '|' ||
       (select count(*) from dba_indexes i where i.owner = u.username and i.uniqueness = 'NONUNIQUE')
from dba_users u
where u.oracle_maintained = 'N'
  and u.username not in ('SYS','SYSTEM')
  and u.username like 'CRASHSIM%'
  ${candidate_filter}
order by case when u.username like 'CRASHSIM%' then 0 else 1 end, u.username;
alter session set container = CDB\$ROOT;
"
  else
    sql_query "$target_file" "
select username || '|' ||
       (select count(*) from dba_tables t where t.owner = u.username and t.nested = 'NO' and t.temporary = 'N') || '|' ||
       (select count(*) from dba_indexes i where i.owner = u.username and i.uniqueness = 'NONUNIQUE')
from dba_users u
where u.oracle_maintained = 'N'
  and u.username not in ('SYS','SYSTEM')
  and (u.username like 'CRASHSIM%' or u.username like 'C##CRASHSIM%')
  ${candidate_filter}
order by case when u.username like 'CRASHSIM%' then 0 else 1 end, u.username;
"
  fi
  load_rows "$target_file" || true

  if [[ "${#TARGET_ROWS[@]}" -gt 0 ]]; then
    echo "Available disposable CrashSimulator lab schemas:"
    idx=1
    for row in "${TARGET_ROWS[@]}"; do
      IFS='|' read -r owner table_count index_count <<<"$row"
      printf "  %2d. %-30s tables=%-6s nonunique_indexes=%s\n" "$idx" "$owner" "${table_count:-0}" "${index_count:-0}"
      idx=$((idx + 1))
      [[ "$idx" -le 30 ]] || break
    done
  else
    echo "No disposable CrashSimulator lab schemas were discovered in the current container context."
    echo "Re-run seed_crashsim_lab.sql in the relevant container or type a known disposable schema name manually."
  fi

  echo
  echo "Enter schema name or number, c to clear, or blank to keep/skip [${TARGET_SCHEMA:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      TARGET_SCHEMA=""
      echo "Schema target cleared."
      return "$SUCCESS"
      ;;
  esac

  if [[ "$answer" =~ ^[0-9]+$ && "${#TARGET_ROWS[@]}" -gt 0 && "$answer" -ge 1 && "$answer" -le "${#TARGET_ROWS[@]}" ]]; then
    IFS='|' read -r TARGET_SCHEMA table_count index_count <<<"${TARGET_ROWS[$((answer - 1))]}"
  else
    TARGET_SCHEMA="$(normalize_name "$answer")"
  fi
  validate_oracle_name "$TARGET_SCHEMA" || {
    warn "Invalid schema name: $TARGET_SCHEMA"
    TARGET_SCHEMA=""
    return "$FAIL"
  }
  schema_safe=0
  if [[ -n "$TARGET_PDB" ]]; then
    [[ "$TARGET_SCHEMA" == CRASHSIM* ]] && schema_safe=1
  else
    [[ "$TARGET_SCHEMA" == CRASHSIM* || "$TARGET_SCHEMA" == C##CRASHSIM* ]] && schema_safe=1
  fi
  if scenario_uses_schema_context "${SCENARIO_ID:-}" && [[ "$schema_safe" -ne 1 ]]; then
    echo
    warn "Schema ${TARGET_SCHEMA} does not look like a CrashSimulator lab schema."
    echo "Only use disposable lab schemas for destructive logical drills."
    confirm_token="USE-SCHEMA-${TARGET_SCHEMA}"
    echo "Type ${confirm_token} to accept this schema, or anything else to cancel:"
    read -r answer || return "$FAIL"
    if [[ "$answer" != "$confirm_token" ]]; then
      TARGET_SCHEMA=""
      warn "Schema selection cancelled."
      return "$FAIL"
    fi
  fi
  echo "Schema target set to ${TARGET_SCHEMA}."
}

menu_prompt_schema_if_useful() {
  local answer default_label

  scenario_uses_schema_context "$SCENARIO_ID" || return "$SUCCESS"
  [[ -z "$TARGET_SCHEMA" ]] || return "$SUCCESS"
  [[ "$MENU_SCHEMA_PROMPTED_SCENARIO" != "$SCENARIO_ID" ]] || return "$SUCCESS"
  MENU_SCHEMA_PROMPTED_SCENARIO="$SCENARIO_ID"

  echo
  echo "Scenario ${SCENARIO_ID} can use an optional schema filter."
  echo "Leaving schema unset lets CrashSimulator choose a disposable candidate during dry-run/execution."
  if scenario_schema_prompt_default_yes "$SCENARIO_ID"; then
    default_label="Y/n"
    echo "Select a schema now? [${default_label}]"
  else
    default_label="y/N"
    echo "Select a schema now? [${default_label}]"
  fi
  read -r answer || return "$FAIL"
  if scenario_schema_prompt_default_yes "$SCENARIO_ID"; then
    case "$answer" in
      n|N|no|NO) return "$SUCCESS" ;;
      *)
        menu_select_schema || {
          MENU_SCHEMA_PROMPTED_SCENARIO=""
          return "$FAIL"
        }
        ;;
    esac
  else
    case "$answer" in
      y|Y|yes|YES)
        menu_select_schema || {
          MENU_SCHEMA_PROMPTED_SCENARIO=""
          return "$FAIL"
        }
        ;;
      *) return "$SUCCESS" ;;
    esac
  fi
}

menu_apply_manifest_context_if_available() {
  local value

  [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]] || return "$SUCCESS"

  if [[ -z "$TARGET_PDB" ]]; then
    value="$(manifest_first_value "target_pdb" "target_1_pdb_name" "action_1_pdb_name" "apex_runtime_target_container" || true)"
    if [[ -n "$value" ]]; then
      value="$(normalize_name "$value")"
      if validate_oracle_name "$value"; then
        TARGET_PDB="$value"
        echo "PDB target loaded from manifest: ${TARGET_PDB}"
      fi
    fi
  fi

  if [[ -z "$TARGET_SCHEMA" ]]; then
    value="$(manifest_first_value "target_schema" "action_1_owner" || true)"
    if [[ -n "$value" ]]; then
      value="$(normalize_name "$value")"
      if validate_oracle_name "$value"; then
        TARGET_SCHEMA="$value"
        echo "Schema target loaded from manifest: ${TARGET_SCHEMA}"
      fi
    fi
  fi

  if [[ -z "$TARGET_FILE_NO" ]]; then
    value="$(manifest_first_value "recover_file_no" "target_1_file_no" "action_1_file_no" || true)"
    if [[ "$value" =~ ^[0-9]+$ ]]; then
      TARGET_FILE_NO="$value"
      echo "FILE# loaded from manifest: ${TARGET_FILE_NO}"
    fi
  fi
}

menu_prompt_oracle_name() {
  local label="$1"
  local var_name="$2"
  local current="$3"
  local answer normalized

  echo "Enter ${label}, c to clear, or blank to keep [${current:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      printf -v "$var_name" ""
      echo "${label} cleared."
      return "$SUCCESS"
      ;;
  esac
  normalized="$(normalize_name "$answer")"
  validate_oracle_name "$normalized" || {
    warn "Invalid ${label}: $normalized"
    return "$FAIL"
  }
  printf -v "$var_name" "%s" "$normalized"
  echo "${label} set to ${normalized}."
}

menu_prompt_path() {
  local label="$1"
  local var_name="$2"
  local current="$3"
  local answer

  echo "Enter ${label}, c to clear, or blank to keep [${current:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      printf -v "$var_name" ""
      echo "${label} cleared."
      return "$SUCCESS"
      ;;
  esac
  printf -v "$var_name" "%s" "$answer"
  echo "${label} set to ${answer}."
}

menu_prompt_audit_retain() {
  local answer

  echo "Retain per-run audit logs? [y/N, blank keeps current ${AUDIT_RETAIN}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    y|Y|yes|YES|1|true|TRUE|on|ON)
      AUDIT_RETAIN=1
      ;;
    n|N|no|NO|0|false|FALSE|off|OFF)
      AUDIT_RETAIN=0
      ;;
    *)
      warn "Invalid audit retain value: $answer"
      return "$FAIL"
      ;;
  esac
  echo "Audit retain set to ${AUDIT_RETAIN}."
}

menu_prompt_audit_retention_days() {
  local answer

  echo "Enter audit retention days, or blank to keep [${AUDIT_RETENTION_DAYS}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  [[ "$answer" =~ ^[0-9]+$ ]] || {
    warn "Invalid retention days: $answer"
    return "$FAIL"
  }
  AUDIT_RETENTION_DAYS="$answer"
  echo "Audit retention days set to ${AUDIT_RETENTION_DAYS}."
}

menu_prompt_integer_range() {
  local label="$1"
  local var_name="$2"
  local current="$3"
  local min_value="$4"
  local max_value="${5:-}"
  local answer

  echo "Enter ${label}, or blank to keep [${current}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  [[ "$answer" =~ ^[0-9]+$ ]] || {
    warn "Invalid ${label}: $answer"
    return "$FAIL"
  }
  if [[ -n "$min_value" && "$answer" -lt "$min_value" ]]; then
    warn "${label} must be >= ${min_value}."
    return "$FAIL"
  fi
  if [[ -n "$max_value" && "$answer" -gt "$max_value" ]]; then
    warn "${label} must be <= ${max_value}."
    return "$FAIL"
  fi
  printf -v "$var_name" "%s" "$answer"
  echo "${label} set to ${answer}."
}

menu_prompt_rman_catalog() {
  local answer

  echo "Enter RMAN recovery catalog connect string, c to clear, or blank to keep [$([[ -n "$RMAN_CATALOG_CONNECT" ]] && echo configured || echo not-set)]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      RMAN_CATALOG_CONNECT=""
      echo "RMAN recovery catalog connect string cleared."
      return "$SUCCESS"
      ;;
  esac

  RMAN_CATALOG_CONNECT="$answer"
  echo "RMAN recovery catalog connect string configured: $(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"
}

menu_prompt_file_no() {
  local answer target_file idx row file_no pdb_name tablespace size_mb file_name where_clause

  discover_environment || true
  target_file="$WORK_DIR/menu_datafiles.lst"
  if [[ "$DB_CDB" == "YES" ]]; then
    where_clause="where c.name <> 'PDB\$SEED'"
    if [[ -n "$TARGET_PDB" ]]; then
      where_clause="${where_clause} and c.name = $(sql_quote "$TARGET_PDB")"
    fi
    sql_query "$target_file" "
select vf.file# || '|' ||
       c.name || '|' ||
       nvl(ts.name, 'UNKNOWN') || '|' ||
       round(vf.bytes/1024/1024) || '|' ||
       vf.name
from v\$datafile vf
join v\$containers c
  on c.con_id = vf.con_id
left join v\$tablespace ts
  on ts.con_id = vf.con_id
 and ts.ts# = vf.ts#
${where_clause}
order by vf.con_id, vf.file#;
"
  else
    sql_query "$target_file" "
select vf.file# || '|NONCDB|' ||
       nvl(ts.name, 'UNKNOWN') || '|' ||
       round(vf.bytes/1024/1024) || '|' ||
       vf.name
from v\$datafile vf
left join v\$tablespace ts
  on ts.ts# = vf.ts#
order by vf.file#;
"
  fi
  load_rows "$target_file" || true

  echo
  echo "Datafile FILE# selection"
  if [[ "${#TARGET_ROWS[@]}" -gt 0 ]]; then
    echo "Available datafiles$([[ -n "$TARGET_PDB" ]] && printf " for PDB %s" "$TARGET_PDB"):"
    idx=1
    for row in "${TARGET_ROWS[@]}"; do
      IFS='|' read -r file_no pdb_name tablespace size_mb file_name <<<"$row"
      printf "  %2d. FILE#=%-5s PDB=%-20s TBS=%-24s SIZE_MB=%-8s %s\n" \
        "$idx" "$file_no" "$pdb_name" "$tablespace" "${size_mb:-unknown}" "$file_name"
      idx=$((idx + 1))
      [[ "$idx" -le 40 ]] || break
    done
  else
    echo "No datafiles were discovered for the current target context."
  fi

  echo
  echo "Enter list number or FILE#, c to clear, or blank to keep [${TARGET_FILE_NO:-not set}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  case "$answer" in
    c|C|clear|CLEAR)
      TARGET_FILE_NO=""
      echo "FILE# cleared."
      return "$SUCCESS"
      ;;
  esac
  [[ "$answer" =~ ^[0-9]+$ ]] || {
    warn "Invalid FILE#: $answer"
    return "$FAIL"
  }
  if [[ "${#TARGET_ROWS[@]}" -gt 0 && "$answer" -ge 1 && "$answer" -le "${#TARGET_ROWS[@]}" ]]; then
    IFS='|' read -r TARGET_FILE_NO pdb_name tablespace size_mb file_name <<<"${TARGET_ROWS[$((answer - 1))]}"
  else
    TARGET_FILE_NO="$answer"
  fi
  echo "FILE# set to ${TARGET_FILE_NO}."
}

menu_show_selected_scenario_readiness() {
  [[ -n "$SCENARIO_ID" && -n "${SCENARIO_TITLE[$SCENARIO_ID]:-}" ]] || return "$SUCCESS"

  if validate_scenario_can_run "$SCENARIO_ID"; then
    echo "Readiness: RUNNABLE - ${SCENARIO_VALIDATION_REASON}"
  elif [[ "$SCENARIO_VALIDATION_STATUS" == "PLAN_ONLY" ]]; then
    echo "Readiness: PLAN-ONLY - ${SCENARIO_VALIDATION_REASON}"
    echo "Execution remains blocked until the guardrail is resolved."
  else
    echo "Readiness: NOT RUNNABLE - ${SCENARIO_VALIDATION_REASON}"
    echo "This scenario cannot be executed in the current topology or target context."
  fi
}

menu_prompt_file_no_for_recovery_if_useful() {
  local answer

  scenario_file_no_context_useful "$SCENARIO_ID" || return "$SUCCESS"
  [[ -z "$TARGET_FILE_NO" ]] || return "$SUCCESS"
  [[ -z "$MANIFEST_FILE" ]] || return "$SUCCESS"

  echo
  echo "Recovery helper note"
  echo "No recovery manifest is selected. A manifest is preferred because it carries the exact target metadata."
  echo "You can optionally select a FILE# now for recovery override/live discovery fallback."
  echo "Select FILE# now? [y/N]"
  read -r answer || return "$FAIL"
  case "$answer" in
    y|Y|yes|YES) menu_prompt_file_no ;;
    *) return "$SUCCESS" ;;
  esac
}

menu_ensure_scenario_context() {
  local action="${1:-scenario}"
  local run_mode="${2:-dry-run}"

  [[ -n "$run_mode" ]] || run_mode="dry-run"
  menu_require_scenario || return "$FAIL"
  discover_environment || true

  if scenario_requires_pdb_context "$SCENARIO_ID" && [[ -z "$TARGET_PDB" ]]; then
    echo
    echo "Scenario ${SCENARIO_ID} requires a PDB target."
    if ! menu_auto_select_single_pdb; then
      menu_select_pdb || return "$FAIL"
    fi
    if [[ -z "$TARGET_PDB" ]]; then
      warn "PDB target is still not set. Select a PDB before continuing with scenario ${SCENARIO_ID}."
      return "$FAIL"
    fi
  fi

  menu_prompt_schema_if_useful || return "$FAIL"

  if [[ "$action" == "recover" ]]; then
    menu_apply_manifest_context_if_available
    menu_prompt_file_no_for_recovery_if_useful || return "$FAIL"
  fi

  echo
  menu_show_selected_scenario_readiness
}

menu_configure_scenario25() {
  local answer

  echo
  echo "Scenario 25 backup-piece guardrails"
  echo "Current local-only: ${LOCAL_ONLY}"
  echo "Set local-only? [y/N, blank keeps current]:"
  read -r answer || return "$FAIL"
  case "$answer" in
    y|Y|yes|YES) LOCAL_ONLY=1 ;;
    n|N|no|NO) LOCAL_ONLY=0 ;;
  esac

  echo "Enter max targets, c to clear, or blank to keep [${MAX_TARGETS:-not set}]:"
  read -r answer || return "$FAIL"
  if [[ -n "$answer" ]]; then
    case "$answer" in
      c|C|clear|CLEAR)
        MAX_TARGETS=""
        ;;
      *)
        [[ "$answer" =~ ^[1-9][0-9]*$ ]] || {
          warn "Invalid max targets: $answer"
          return "$FAIL"
        }
        MAX_TARGETS="$answer"
        ;;
    esac
  fi

  menu_prompt_path "backup-piece handle" PIECE_HANDLE "$PIECE_HANDLE"
}

menu_configure_resilience_drills() {
  echo
  echo "FRA / TEMP / RTO-RPO drill options"
  menu_prompt_integer_range "scenario 61 FRA target used percentage" FRA_PRESSURE_TARGET_PCT "$FRA_PRESSURE_TARGET_PCT" 50 100
  menu_prompt_integer_range "scenario 61 FRA free headroom MB" FRA_PRESSURE_HEADROOM_MB "$FRA_PRESSURE_HEADROOM_MB" 1
  menu_prompt_integer_range "scenario 63 TEMP workload MB" TEMP_EXHAUST_MB "$TEMP_EXHAUST_MB" 1
  echo
  echo "Use the MAA/SLA context menu to set RTO/RPO objectives consumed by scenarios 64 and 65."
}

menu_load_config_file() {
  local answer

  echo
  echo "Load CrashSimulator configuration file"
  echo "Enter path, or blank to keep current [${CONFIG_SOURCE:-${CONFIG_FILE:-not set}}]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="${CONFIG_SOURCE:-${CONFIG_FILE:-}}"
  [[ -n "$answer" ]] || {
    warn "No configuration file path provided."
    return "$FAIL"
  }

  CONFIG_FILE="$answer"
  CONFIG_EXPLICIT=1
  load_config_file "$CONFIG_FILE"
  normalize_targets
  [[ -n "$LOG_DIR" ]] || LOG_DIR="$(pwd)/crashsimulator_logs"
  mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
  audit_effective_dir
  echo "Configuration loaded: ${CONFIG_SOURCE}"
  echo "Existing shell environment values were preserved."
}

menu_write_config_template() {
  local answer old_yes

  echo
  echo "Write configuration template"
  echo "Enter output path [./crashsimulator.conf]:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="./crashsimulator.conf"
  if [[ -e "$answer" ]]; then
    echo "File exists. Type OVERWRITE-CONFIG to replace it:"
    read -r old_yes || return "$FAIL"
    [[ "$old_yes" == "OVERWRITE-CONFIG" ]] || {
      warn "Configuration template write cancelled."
      return "$FAIL"
    }
    old_yes="$ASSUME_YES"
    ASSUME_YES=1
    write_config_template "$answer"
    ASSUME_YES="$old_yes"
  else
    write_config_template "$answer"
  fi
}

menu_config_file_options() {
  local answer

  while true; do
    echo
    echo "Configuration File Options"
    echo "  1. Load configuration file"
    echo "  2. Show active configuration"
    echo "  3. Validate active configuration"
    echo "  4. Write configuration template"
    echo "  5. Show lookup order and precedence"
    echo "  b. Back"
    echo
    echo "Loaded config: ${CONFIG_SOURCE:-not loaded}"
    echo "Precedence: CLI arguments > existing environment > config file > built-in defaults"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        menu_load_config_file
        menu_pause
        ;;
      2)
        show_active_config
        menu_pause
        ;;
      3)
        validate_config_runtime || true
        menu_pause
        ;;
      4)
        menu_write_config_template
        menu_pause
        ;;
      5)
        echo
        echo "Lookup order:"
        echo "  1. --config <file>"
        echo "  2. CRASHSIM_CONFIG"
        echo "  3. ./crashsimulator.conf"
        echo "  4. \$HOME/.crashsimulator/crashsimulator.conf"
        echo "  5. /etc/crashsimulator/crashsimulator.conf"
        echo
        echo "The file is parsed as allowlisted KEY=value entries, not sourced as shell code."
        echo "Do not store passwords or wallet secrets in the configuration file."
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown configuration-file menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_set_password_file_options() {
  local answer

  echo
  echo "Password-file recovery options"
  echo "Enter SYS password for this menu session, c to clear, or blank to keep current:"
  read -rs answer || return "$FAIL"
  echo
  if [[ -n "$answer" ]]; then
    case "$answer" in
      c|C|clear|CLEAR)
        SYS_PASSWORD=""
        echo "SYS password cleared from this process."
        ;;
      *)
        SYS_PASSWORD="$answer"
        echo "SYS password stored only in this running process."
        ;;
    esac
  fi

  menu_prompt_path "listener service name" SERVICE_NAME "$SERVICE_NAME"
  menu_prompt_oracle_name "SYSBACKUP user" SYSBACKUP_USER "$SYSBACKUP_USER"
}

menu_configure_options() {
  local answer

  while true; do
    echo
    echo "Configure Menu Context"
    echo "  1. Select PDB"
    echo "  2. Set schema"
    echo "  3. Set FILE#"
    echo "  4. Set recovery manifest"
    echo "  5. Set PFILE path"
    echo "  6. Scenario 25 backup-piece guardrails"
    echo "  7. Password-file recovery options"
    echo "  8. Set log directory"
    echo "  9. Set RMAN recovery catalog"
    echo " 10. Set baseline backup tag prefix"
    echo " 11. FRA/TEMP/RTO-RPO drill options"
    echo " 12. Configuration file options"
    echo " 13. Clear selected scenario and targets"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1) menu_select_pdb; menu_pause ;;
      2) menu_select_schema; menu_pause ;;
      3) menu_prompt_file_no; menu_pause ;;
      4)
        menu_prompt_path "manifest path" MANIFEST_FILE "$MANIFEST_FILE"
        [[ -n "$MANIFEST_FILE" ]] && MANIFEST_FROM_ARG=1
        menu_pause
        ;;
      5) menu_prompt_path "PFILE path" PFILE_PATH "$PFILE_PATH"; menu_pause ;;
      6) menu_configure_scenario25; menu_pause ;;
      7) menu_set_password_file_options; menu_pause ;;
      8)
        menu_prompt_path "log directory" LOG_DIR "$LOG_DIR"
        [[ -n "$LOG_DIR" ]] || LOG_DIR="$(pwd)/crashsimulator_logs"
        mkdir -p "$LOG_DIR" || die "Unable to create log directory: $LOG_DIR"
        menu_pause
        ;;
      9)
        menu_prompt_rman_catalog
        menu_pause
        ;;
      10)
        menu_prompt_path "baseline backup tag prefix" BASELINE_TAG_PREFIX "$BASELINE_TAG_PREFIX"
        menu_pause
        ;;
      11)
        menu_configure_resilience_drills
        menu_pause
        ;;
      12)
        menu_config_file_options
        ;;
      13)
        SCENARIO_ID=""
        MENU_SCHEMA_PROMPTED_SCENARIO=""
        TARGET_PDB=""
        TARGET_SCHEMA=""
        TARGET_FILE_NO=""
        MANIFEST_FILE=""
        MANIFEST_FROM_ARG=0
        PFILE_PATH=""
        LOCAL_ONLY=0
        MAX_TARGETS=""
        PIECE_HANDLE=""
        RMAN_CATALOG_CONNECT=""
        BASELINE_TAG_PREFIX="${CRASHSIM_BASELINE_TAG_PREFIX:-CSIM_BASE}"
        FRA_PRESSURE_TARGET_PCT="${CRASHSIM_FRA_PRESSURE_TARGET_PCT:-98}"
        FRA_PRESSURE_HEADROOM_MB="${CRASHSIM_FRA_PRESSURE_HEADROOM_MB:-64}"
        TEMP_EXHAUST_MB="${CRASHSIM_TEMP_EXHAUST_MB:-512}"
        echo "Scenario and target context cleared."
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_latest_manifest() {
  find "$LOG_DIR" -maxdepth 1 -type f -name '*.manifest' 2>/dev/null | sort | tail -n 1
}

menu_latest_manifest_for_mode() {
  local mode_name="$1"
  local id="$2"
  find "$LOG_DIR" -maxdepth 1 -type f -name "crashsim_${mode_name}_s${id}_*.manifest" 2>/dev/null | sort | tail -n 1
}

menu_choose_recovery_manifest() {
  local latest answer

  if [[ -n "$MANIFEST_FILE" ]]; then
    return "$SUCCESS"
  fi

  if [[ -n "$SCENARIO_ID" ]]; then
    latest="$(menu_latest_manifest_for_mode "scenario" "$SCENARIO_ID")"
  else
    latest=""
  fi
  [[ -n "$latest" ]] || latest="$(menu_latest_manifest)"

  if [[ -n "$latest" ]]; then
    echo "Latest manifest: ${latest}"
    echo "Use this manifest for recovery? [Y/n]"
    read -r answer || return "$FAIL"
    case "$answer" in
      n|N|no|NO)
        ;;
      *)
        MANIFEST_FILE="$latest"
        MANIFEST_FROM_ARG=1
        return "$SUCCESS"
        ;;
    esac
  fi

  echo "Enter recovery manifest path, or blank to let the recovery helper decide when supported:"
  read -r answer || return "$FAIL"
  if [[ -n "$answer" ]]; then
    MANIFEST_FILE="$answer"
    MANIFEST_FROM_ARG=1
  fi
}

# A scenario manifest records restore points (rename_N_original/rename_N_backup)
# only when the scenario actually ran: a dry-run scenario (option 5) prints the
# plan and renames/backs up nothing. Recovery replays those restore points, so a
# dry-run scenario manifest can never recover - load_manifest_restore_pairs finds
# no pair and the helper stops with "Manifest is missing ... restore paths", which
# the guided menu surfaced only as a bare "Command exited with status 1". Detect
# it up front and say what to do instead. Scoped to fs_rename plans (the mechanism
# recovery replays) so scenarios that recover by other means are never blocked.
menu_recovery_manifest_is_recoverable() {
  local idx kind planned_rename run_id title

  [[ -n "$MANIFEST_FILE" && -f "$MANIFEST_FILE" ]] || return "$SUCCESS"
  [[ "$(manifest_get "mode" || true)" == "scenario" ]] || return "$SUCCESS"

  planned_rename=0
  idx=1
  while :; do
    kind="$(manifest_get "action_${idx}_kind" || true)"
    [[ -n "$kind" ]] || break
    if [[ "$kind" == "fs_rename" ]]; then
      planned_rename=1
      break
    fi
    idx=$((idx + 1))
  done
  [[ "$planned_rename" -eq 1 ]] || return "$SUCCESS"

  # Mirror load_manifest_restore_pairs: it starts at rename_1 and reports no
  # pairs only when both sides are empty.
  [[ -z "$(manifest_get "rename_1_original" || true)" ]] || return "$SUCCESS"
  [[ -z "$(manifest_get "rename_1_backup" || true)" ]] || return "$SUCCESS"

  run_id="$(manifest_get "run_id" || true)"
  title="$(manifest_get "scenario_title" || true)"
  warn "This manifest is from a dry-run scenario preview - there is nothing to recover."
  echo "  Manifest: ${MANIFEST_FILE}"
  echo "  Scenario: ${SCENARIO_ID}${title:+ - ${title}}${run_id:+ (run ${run_id})}"
  echo
  echo "  A dry-run scenario prints the plan but renames and backs up no file, so this"
  echo "  manifest holds no restore point. Recovery replays those restore points, so it"
  echo "  would stop with \"Manifest is missing ... restore paths\"."
  echo
  echo "  Run menu option 8 (Execute selected scenario) first, then retry recovery:"
  echo "  the executed run writes its own manifest and the menu will offer that one."
  return "$FAIL"
}

# Scenario 16 (Loss of password file) recovers by RECREATING the file with
# orapwd, which embeds the SYS password - so execute-mode recovery cannot run
# without it. Mirrors the id -> recover_password_file_scenario mapping in the
# recovery dispatch.
menu_scenario_recovery_needs_sys_password() {
  case "${1:-}" in
    16) return "$SUCCESS" ;;
  esac
  return "$FAIL"
}

# Surface the SYS-password prerequisite at the right moments (field-tested
# 2026-07-18: the operator learned about it only AFTER typing RECOVER-16 and
# LAB-APPROVED):
#   - action=scenario (menu options 5 and 8): non-blocking heads-up BEFORE
#     breaking a password file the operator cannot yet recover; the scenario
#     itself runs fine without the password.
#   - action=recover in execute mode (menu option 10): fail early with the
#     fix, instead of letting the child die after the confirmation gates.
menu_warn_sys_password_for_scenario() {
  local action="$1" run_mode="$2"
  [[ -n "$SCENARIO_ID" ]] || return "$SUCCESS"
  menu_scenario_recovery_needs_sys_password "$SCENARIO_ID" || return "$SUCCESS"
  [[ -z "$SYS_PASSWORD" ]] || return "$SUCCESS"

  case "$action" in
    scenario)
      warn "Recovering scenario ${SCENARIO_ID} later will need the SYS password, which is not set."
      echo "  Recovery recreates the password file with orapwd, and execute-mode recovery"
      echo "  (option 10) refuses to run without the SYS password. Set it via option 12"
      echo "  (Configure targets and options -> Password-file recovery options) now or"
      echo "  before you recover. Continuing with the scenario itself is safe."
      echo
      ;;
    recover)
      if [[ "$run_mode" == "execute" ]]; then
        warn "Execute-mode recovery for scenario ${SCENARIO_ID} requires the SYS password, which is not set."
        echo "  Recovery recreates the password file with orapwd file=... password=<SYS>, so"
        echo "  the run would stop with \"Password-file recovery execution requires"
        echo "  --sys-password or CRASHSIM_SYS_PASSWORD\". Set the SYS password via option 12"
        echo "  (Configure targets and options -> Password-file recovery options), then retry."
        return "$FAIL"
      fi
      ;;
  esac
  return "$SUCCESS"
}

menu_append_common_child_args() {
  [[ -n "$CONFIG_SOURCE" ]] && MENU_CMD+=("--config" "$CONFIG_SOURCE")
  [[ -n "$TARGET_PDB" ]] && MENU_CMD+=("--pdb" "$TARGET_PDB")
  [[ -n "$TARGET_SCHEMA" ]] && MENU_CMD+=("--schema" "$TARGET_SCHEMA")
  [[ -n "$TARGET_FILE_NO" ]] && MENU_CMD+=("--file-no" "$TARGET_FILE_NO")
  [[ -n "$PFILE_PATH" ]] && MENU_CMD+=("--pfile" "$PFILE_PATH")
  [[ -n "$SERVICE_NAME" ]] && MENU_CMD+=("--service-name" "$SERVICE_NAME")
  [[ -n "$ORDS_SERVICE_NAME" ]] && MENU_CMD+=("--ords-service" "$ORDS_SERVICE_NAME")
  [[ -n "$ORDS_CONFIG_DIR" ]] && MENU_CMD+=("--ords-config-dir" "$ORDS_CONFIG_DIR")
  [[ -n "$ORDS_URL" ]] && MENU_CMD+=("--ords-url" "$ORDS_URL")
  [[ -n "$ORDS_LB_URL" ]] && MENU_CMD+=("--ords-lb-url" "$ORDS_LB_URL")
  [[ -n "$ORDS_PRIV_HELPER" ]] && MENU_CMD+=("--ords-priv-helper" "$ORDS_PRIV_HELPER")
  [[ -n "$APEX_IMAGES_DIR" ]] && MENU_CMD+=("--apex-images-dir" "$APEX_IMAGES_DIR")
  [[ -n "$APEX_SESSION_DRIVER" ]] && MENU_CMD+=("--apex-session-driver" "$APEX_SESSION_DRIVER")
  [[ -n "$APEX_SESSION_URL" ]] && MENU_CMD+=("--apex-session-url" "$APEX_SESSION_URL")
  [[ -n "$APEX_SESSION_USERNAME" ]] && MENU_CMD+=("--apex-session-username" "$APEX_SESSION_USERNAME")
  [[ -n "$APEX_SESSION_SUCCESS_SELECTOR" ]] && MENU_CMD+=("--apex-session-success-selector" "$APEX_SESSION_SUCCESS_SELECTOR")
  [[ -n "$APEX_SESSION_USERNAME_SELECTOR" ]] && MENU_CMD+=("--apex-session-username-selector" "$APEX_SESSION_USERNAME_SELECTOR")
  [[ -n "$APEX_SESSION_PASSWORD_SELECTOR" ]] && MENU_CMD+=("--apex-session-password-selector" "$APEX_SESSION_PASSWORD_SELECTOR")
  [[ -n "$APEX_SESSION_SUBMIT_SELECTOR" ]] && MENU_CMD+=("--apex-session-submit-selector" "$APEX_SESSION_SUBMIT_SELECTOR")
  MENU_CMD+=("--apex-session-duration" "$APEX_SESSION_DURATION")
  MENU_CMD+=("--apex-session-interval" "$APEX_SESSION_INTERVAL")
  MENU_CMD+=("--apex-session-headless" "$APEX_SESSION_HEADLESS")
  [[ -n "$ADB_WALLET_DIR" ]] && MENU_CMD+=("--adb-wallet-dir" "$ADB_WALLET_DIR")
  [[ -n "$ADB_CONNECT_ALIAS" ]] && MENU_CMD+=("--adb-connect-alias" "$ADB_CONNECT_ALIAS")
  [[ -n "$ADB_CONNECT_DESCRIPTOR" ]] && MENU_CMD+=("--adb-connect-descriptor" "$ADB_CONNECT_DESCRIPTOR")
  [[ -n "$ADB_SERVICE_LEVEL" ]] && MENU_CMD+=("--adb-service-level" "$ADB_SERVICE_LEVEL")
  [[ -n "$ADB_USER" ]] && MENU_CMD+=("--adb-user" "$ADB_USER")
  [[ -n "$ADB_PASSWORD_ENV" ]] && MENU_CMD+=("--adb-password-env" "$ADB_PASSWORD_ENV")
  [[ -n "$ADB_WALLET_PASSWORD_ENV" ]] && MENU_CMD+=("--adb-wallet-password-env" "$ADB_WALLET_PASSWORD_ENV")
  [[ -n "$ADB_PYTHON" ]] && MENU_CMD+=("--adb-python" "$ADB_PYTHON")
  [[ -n "$ADB_TLS_MODE" ]] && MENU_CMD+=("--adb-tls-mode" "$ADB_TLS_MODE")
  [[ -n "$ADB_OCID" ]] && MENU_CMD+=("--adb-ocid" "$ADB_OCID")
  [[ -n "$ADB_COMPARTMENT_OCID" ]] && MENU_CMD+=("--adb-compartment-ocid" "$ADB_COMPARTMENT_OCID")
  [[ -n "$ADB_REGION" ]] && MENU_CMD+=("--adb-region" "$ADB_REGION")
  [[ -n "$ADB_OCI_PROFILE" ]] && MENU_CMD+=("--adb-oci-profile" "$ADB_OCI_PROFILE")
  [[ -n "$ADB_OCI_CONFIG_FILE" ]] && MENU_CMD+=("--adb-oci-config-file" "$ADB_OCI_CONFIG_FILE")
  [[ -n "$ADB_OCI_AUTH" ]] && MENU_CMD+=("--adb-oci-auth" "$ADB_OCI_AUTH")
  [[ -n "$ADB_APEX_URL" ]] && MENU_CMD+=("--adb-apex-url" "$ADB_APEX_URL")
  [[ -n "$ADB_DATABASE_ACTIONS_URL" ]] && MENU_CMD+=("--adb-database-actions-url" "$ADB_DATABASE_ACTIONS_URL")
  [[ -n "$ADB_PRIVATE_ENDPOINT" ]] && MENU_CMD+=("--adb-private-endpoint" "$ADB_PRIVATE_ENDPOINT")
  [[ -n "$SYSBACKUP_USER" ]] && MENU_CMD+=("--sysbackup-user" "$SYSBACKUP_USER")
  [[ "$LOCAL_ONLY" == "1" ]] && MENU_CMD+=("--local-only")
  [[ -n "$MAX_TARGETS" ]] && MENU_CMD+=("--max-targets" "$MAX_TARGETS")
  [[ -n "$PIECE_HANDLE" ]] && MENU_CMD+=("--piece-handle" "$PIECE_HANDLE")
  MENU_CMD+=("--fra-pressure-target-pct" "$FRA_PRESSURE_TARGET_PCT")
  MENU_CMD+=("--fra-pressure-headroom-mb" "$FRA_PRESSURE_HEADROOM_MB")
  MENU_CMD+=("--temp-exhaust-mb" "$TEMP_EXHAUST_MB")
  [[ -n "$MAA_APP_NAME" ]] && MENU_CMD+=("--maa-app-name" "$MAA_APP_NAME")
  [[ -n "$MAA_LOCAL_RTO" ]] && MENU_CMD+=("--maa-local-rto" "$MAA_LOCAL_RTO")
  [[ -n "$MAA_LOCAL_RPO" ]] && MENU_CMD+=("--maa-local-rpo" "$MAA_LOCAL_RPO")
  [[ -n "$MAA_DR_RTO" ]] && MENU_CMD+=("--maa-dr-rto" "$MAA_DR_RTO")
  [[ -n "$MAA_DR_RPO" ]] && MENU_CMD+=("--maa-dr-rpo" "$MAA_DR_RPO")
  [[ -n "$MAA_PLANNED_RTO" ]] && MENU_CMD+=("--maa-planned-rto" "$MAA_PLANNED_RTO")
  [[ -n "$MAA_PLANNED_RPO" ]] && MENU_CMD+=("--maa-planned-rpo" "$MAA_PLANNED_RPO")
  [[ -n "$MAA_CRITICALITY" ]] && MENU_CMD+=("--maa-criticality" "$MAA_CRITICALITY")
  [[ -n "$MAA_LOCAL_HA_TARGET" ]] && MENU_CMD+=("--maa-local-ha-target" "$MAA_LOCAL_HA_TARGET")
  [[ -n "$MAA_DR_REQUIRED" ]] && MENU_CMD+=("--maa-dr-required" "$MAA_DR_REQUIRED")
  [[ -n "$MAA_AUTOMATIC_FAILOVER_REQUIRED" ]] && MENU_CMD+=("--maa-automatic-failover-required" "$MAA_AUTOMATIC_FAILOVER_REQUIRED")
  [[ -n "$MAA_ACTIVE_ACTIVE_REQUIRED" ]] && MENU_CMD+=("--maa-active-active-required" "$MAA_ACTIVE_ACTIVE_REQUIRED")
  [[ -n "$MAA_PLATFORM_HINT" ]] && MENU_CMD+=("--maa-platform-hint" "$MAA_PLATFORM_HINT")
  [[ -n "$MAA_STANDBY_SCOPE" ]] && MENU_CMD+=("--maa-standby-scope" "$MAA_STANDBY_SCOPE")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
}

menu_print_child_command() {
  local arg i
  printf "Running:"
  [[ -n "$SYS_PASSWORD" ]] && printf " CRASHSIM_SYS_PASSWORD=%q" "<redacted>"
  [[ -n "$RMAN_CATALOG_CONNECT" ]] && printf " CRASHSIM_RMAN_CATALOG=%q" "$(redact_rman_catalog_connect "$RMAN_CATALOG_CONNECT")"
  printf " CRASHSIM_AUDIT_RETAIN=%q" "$AUDIT_RETAIN"
  printf " CRASHSIM_AUDIT_RETENTION_DAYS=%q" "$AUDIT_RETENTION_DAYS"
  printf " CRASHSIM_AUDIT_DIR=%q" "$AUDIT_DIR"
  for ((i = 0; i < ${#MENU_CMD[@]}; i++)); do
    arg="${MENU_CMD[$i]}"
    printf " %q" "$arg"
    case "$arg" in
      --rman-catalog|--sys-password)
        if (( i + 1 < ${#MENU_CMD[@]} )); then
          i=$((i + 1))
          printf " %q" "<redacted>"
        fi
        ;;
    esac
  done
  printf "\n"
}

menu_run_child_command() {
  local status child_stream_capture
  # Guided-menu children have an operator at the terminal: audit stream capture
  # would wrap the child's stdout in the redaction pipe and its interactive
  # confirmation prompts (Type PREPARE-ENVIRONMENT / EXECUTE-<id> / ...) can
  # arrive late while `read` already blocks - the operator answers a safety
  # gate blind. Default capture OFF for children (same policy the audit module
  # applies to the menu itself; generated artifacts are still collected at
  # finalization). An explicit CRASHSIM_AUDIT_STREAM_CAPTURE=0/1 is respected.
  child_stream_capture="${AUDIT_STREAM_CAPTURE:-auto}"
  [[ "$child_stream_capture" == "auto" ]] && child_stream_capture=0
  menu_print_child_command
  echo
  env \
    CRASHSIM_SYS_PASSWORD="$SYS_PASSWORD" \
    CRASHSIM_RMAN_CATALOG="$RMAN_CATALOG_CONNECT" \
    CRASHSIM_AUDIT_RETAIN="$AUDIT_RETAIN" \
    CRASHSIM_AUDIT_RETENTION_DAYS="$AUDIT_RETENTION_DAYS" \
    CRASHSIM_AUDIT_DIR="$AUDIT_DIR" \
    CRASHSIM_AUDIT_STREAM_CAPTURE="$child_stream_capture" \
    "${MENU_CMD[@]}"
  status=$?
  echo
  if [[ "$status" -eq 0 ]]; then
    echo "Command completed successfully."
  else
    warn "Command exited with status ${status}."
  fi
  return "$status"
}

menu_run_child_action() {
  local action="$1"
  local run_mode="$2"
  local latest status capability

  menu_require_scenario || {
    warn "No scenario selected."
    return "$FAIL"
  }

  case "$action" in
    scenario)
      menu_warn_sys_password_for_scenario "scenario" "$run_mode"
      ;;
    protect)
      if ! supports_file_recovery_automation "$SCENARIO_ID"; then
        capability="$(scenario_protection_capability "$SCENARIO_ID")"
        warn "Automated protection is not available for scenario ${SCENARIO_ID}: ${capability}. Use menu option 4 for the runbook and refresh the backup baseline where appropriate."
        return "$FAIL"
      fi
      ;;
    recover)
      if ! supports_recovery_automation "$SCENARIO_ID"; then
        capability="$(scenario_recovery_capability "$SCENARIO_ID")"
        warn "Automated recovery is not available for scenario ${SCENARIO_ID}: ${capability}. Use menu option 4 for the recovery runbook and evidence guidance."
        return "$FAIL"
      fi
      menu_warn_sys_password_for_scenario "recover" "$run_mode" || return "$FAIL"
      menu_choose_recovery_manifest
      menu_apply_manifest_context_if_available
      menu_recovery_manifest_is_recoverable || return "$FAIL"
      ;;
    *)
      warn "Unknown action: $action"
      return "$FAIL"
      ;;
  esac

  menu_ensure_scenario_context "$action" "$run_mode" || return "$FAIL"

  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH")
  case "$action" in
    scenario) MENU_CMD+=("--scenario" "$SCENARIO_ID") ;;
    protect) MENU_CMD+=("--protect" "$SCENARIO_ID") ;;
    recover)
      MENU_CMD+=("--recover" "$SCENARIO_ID")
      [[ -n "$MANIFEST_FILE" ]] && MENU_CMD+=("--manifest" "$MANIFEST_FILE")
      ;;
  esac

  menu_append_common_child_args
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown run mode: $run_mode"; return "$FAIL" ;;
  esac

  menu_run_child_command
  status=$?

  if [[ "$action" == "scenario" && "$status" -eq 0 ]]; then
    latest="$(menu_latest_manifest_for_mode "scenario" "$SCENARIO_ID")"
    if [[ -n "$latest" ]]; then
      MANIFEST_FILE="$latest"
      MANIFEST_FROM_ARG=1
      echo "Current recovery manifest set to: ${MANIFEST_FILE}"
      echo "For destructive recovery, make sure this is the executed scenario manifest, not only a dry-run manifest."
    fi
  fi

  return "$status"
}

menu_run_validate_scenario() {
  menu_require_scenario || {
    warn "No scenario selected."
    return "$FAIL"
  }
  menu_ensure_scenario_context "validate" "dry-run" || return "$FAIL"

  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--validate-scenario" "$SCENARIO_ID")
  menu_append_common_child_args
  menu_run_child_command
}

menu_run_validate_all_scenarios() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--validate-all-scenarios")
  menu_append_common_child_args
  menu_run_child_command
}

menu_run_scenario_readiness_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--scenario-readiness-report")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_scenario_lifecycle_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--scenario-lifecycle-report")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_random_scenario() {
  local run_mode="$1"
  select_random_scenario || return "$FAIL"
  menu_run_child_action "scenario" "$run_mode"
}

menu_run_health_check() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--health-check")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_configuration_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--config-report")
  [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && MENU_CMD+=("--deep-validate")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_backup_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--backup-report")
  [[ "$REPORT_DEEP_VALIDATE" -eq 1 ]] && MENU_CMD+=("--deep-validate")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_baseline_backup() {
  local run_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--baseline-backup")
  [[ -n "$BASELINE_TAG_PREFIX" ]] && MENU_CMD+=("--tag-prefix" "$BASELINE_TAG_PREFIX")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown baseline backup mode: $run_mode"; return "$FAIL" ;;
  esac
  menu_run_child_command
}

menu_run_maa_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--maa-report")
  [[ -n "$MAA_APP_NAME" ]] && MENU_CMD+=("--maa-app-name" "$MAA_APP_NAME")
  [[ -n "$MAA_LOCAL_RTO" ]] && MENU_CMD+=("--maa-local-rto" "$MAA_LOCAL_RTO")
  [[ -n "$MAA_LOCAL_RPO" ]] && MENU_CMD+=("--maa-local-rpo" "$MAA_LOCAL_RPO")
  [[ -n "$MAA_DR_RTO" ]] && MENU_CMD+=("--maa-dr-rto" "$MAA_DR_RTO")
  [[ -n "$MAA_DR_RPO" ]] && MENU_CMD+=("--maa-dr-rpo" "$MAA_DR_RPO")
  [[ -n "$MAA_PLANNED_RTO" ]] && MENU_CMD+=("--maa-planned-rto" "$MAA_PLANNED_RTO")
  [[ -n "$MAA_PLANNED_RPO" ]] && MENU_CMD+=("--maa-planned-rpo" "$MAA_PLANNED_RPO")
  [[ -n "$MAA_CRITICALITY" ]] && MENU_CMD+=("--maa-criticality" "$MAA_CRITICALITY")
  [[ -n "$MAA_LOCAL_HA_TARGET" ]] && MENU_CMD+=("--maa-local-ha-target" "$MAA_LOCAL_HA_TARGET")
  [[ -n "$MAA_DR_REQUIRED" ]] && MENU_CMD+=("--maa-dr-required" "$MAA_DR_REQUIRED")
  [[ -n "$MAA_AUTOMATIC_FAILOVER_REQUIRED" ]] && MENU_CMD+=("--maa-automatic-failover-required" "$MAA_AUTOMATIC_FAILOVER_REQUIRED")
  [[ -n "$MAA_ACTIVE_ACTIVE_REQUIRED" ]] && MENU_CMD+=("--maa-active-active-required" "$MAA_ACTIVE_ACTIVE_REQUIRED")
  [[ -n "$MAA_PLATFORM_HINT" ]] && MENU_CMD+=("--maa-platform-hint" "$MAA_PLATFORM_HINT")
  [[ -n "$MAA_STANDBY_SCOPE" ]] && MENU_CMD+=("--maa-standby-scope" "$MAA_STANDBY_SCOPE")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_resilience_scorecard() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--resilience-scorecard")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_service_review() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--service-review")
  MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ -n "$SQLPLUS_LOGON" ]] && MENU_CMD+=("--sqlplus-logon" "$SQLPLUS_LOGON")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_apex_ords_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--apex-ords-report")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_prepare_environment() {
  local run_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--prepare-environment")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown prepare mode: $run_mode"; return "$FAIL" ;;
  esac
  menu_run_child_command
}

menu_run_show_latest_prepare_report() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--show-artifact" "latest:prepare")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_prepare_environment() {
  local answer

  while true; do
    echo
    echo "Seed / Prepare Scenario Lab"
    echo "  1. Analyze missing preparations for current topology"
    echo "  2. Execute eligible missing preparations"
    echo "  3. Generate scenario readiness report after preparation"
    echo "  4. Show latest preparation report"
    echo "  5. Show latest preparation report and generate HTML"
    echo "  6. Run fresh RMAN baseline backup dry-run"
    echo "  7. Run fresh RMAN baseline backup after preparation"
    echo "  b. Back"
    echo
    echo "The prepare planner is topology-aware. It skips non-applicable seeds and does not auto-enable FSFO, provision disks, or install APEX/ORDS without required credentials/media."
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1|a|A)
        menu_run_prepare_environment "dry-run"
        menu_pause
        ;;
      2|e|E)
        menu_run_prepare_environment "execute"
        menu_pause
        ;;
      3)
        menu_run_scenario_readiness_report
        menu_pause
        ;;
      4)
        menu_run_show_latest_prepare_report "text"
        menu_pause
        ;;
      5)
        menu_run_show_latest_prepare_report "html"
        menu_pause
        ;;
      6)
        menu_run_baseline_backup "dry-run"
        menu_pause
        ;;
      7)
        menu_run_baseline_backup "execute"
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown prepare menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_run_simple_mode() {
  local mode_arg="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "$mode_arg")
  menu_append_common_child_args
  case "$mode_arg" in
    --doctor|--first-run|--public-limitations|--scenario-lifecycle-check) MENU_CMD+=("--html") ;;
  esac
  menu_run_child_command
}

menu_public_readiness() {
  local answer

  while true; do
    echo
    echo "Public Readiness And Safety"
    echo "  1. Run doctor / preflight"
    echo "  2. Generate first-run guide"
    echo "  3. Check scenario lifecycle consistency"
    echo "  4. Scan repository/artifacts for secrets"
    echo "  5. Create sanitized public artifact copies"
    echo "  6. Run multi-node sync check"
    echo "  7. Run full release check"
    echo "  8. Generate public limitations page"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1) menu_run_simple_mode "--doctor"; menu_pause ;;
      2) menu_run_simple_mode "--first-run"; menu_pause ;;
      3) menu_run_simple_mode "--scenario-lifecycle-check"; menu_pause ;;
      4) menu_run_simple_mode "--secret-scan"; menu_pause ;;
      5) menu_run_simple_mode "--sanitize-artifacts"; menu_pause ;;
      6) menu_run_simple_mode "--node-sync-check"; menu_pause ;;
      7) menu_run_simple_mode "--release-check"; menu_pause ;;
      8) menu_run_simple_mode "--public-limitations"; menu_pause ;;
      b|B|q|Q) return "$SUCCESS" ;;
      *) warn "Unknown public readiness choice: $answer"; menu_pause ;;
    esac
  done
}

menu_run_adb_readiness_report() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--adb-readiness-report")
  menu_append_common_child_args
  MENU_CMD+=("--html")
  menu_run_child_command
}

menu_run_show_latest_adb_report() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--show-artifact" "latest:adb")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_configure_maa_context() {
  echo
  echo "MAA / SLA planning context"
  menu_prompt_path "application name" MAA_APP_NAME "$MAA_APP_NAME"
  menu_prompt_path "local unplanned-outage RTO" MAA_LOCAL_RTO "$MAA_LOCAL_RTO"
  menu_prompt_path "local unplanned-outage RPO" MAA_LOCAL_RPO "$MAA_LOCAL_RPO"
  menu_prompt_path "disaster/site-outage RTO" MAA_DR_RTO "$MAA_DR_RTO"
  menu_prompt_path "disaster/site-outage RPO" MAA_DR_RPO "$MAA_DR_RPO"
  menu_prompt_path "planned-maintenance RTO" MAA_PLANNED_RTO "$MAA_PLANNED_RTO"
  menu_prompt_path "planned-maintenance RPO" MAA_PLANNED_RPO "$MAA_PLANNED_RPO"
  menu_prompt_path "criticality (dev/production/mission-critical/ultra-critical)" MAA_CRITICALITY "$MAA_CRITICALITY"
  menu_prompt_path "local HA target (yes/no)" MAA_LOCAL_HA_TARGET "$MAA_LOCAL_HA_TARGET"
  menu_prompt_path "DR required (yes/no)" MAA_DR_REQUIRED "$MAA_DR_REQUIRED"
  menu_prompt_path "automatic failover required (yes/no)" MAA_AUTOMATIC_FAILOVER_REQUIRED "$MAA_AUTOMATIC_FAILOVER_REQUIRED"
  menu_prompt_path "active-active required (yes/no)" MAA_ACTIVE_ACTIVE_REQUIRED "$MAA_ACTIVE_ACTIVE_REQUIRED"
  menu_prompt_path "platform hint (generic/Exadata/ODA/BaseDB/etc.)" MAA_PLATFORM_HINT "$MAA_PLATFORM_HINT"
  menu_prompt_path "standby scope (local/remote/unknown)" MAA_STANDBY_SCOPE "$MAA_STANDBY_SCOPE"
}

menu_configure_adb_context() {
  echo
  echo "Autonomous Database report context"
  menu_prompt_path "ADB wallet directory" ADB_WALLET_DIR "$ADB_WALLET_DIR"
  menu_prompt_path "ADB connect alias" ADB_CONNECT_ALIAS "$ADB_CONNECT_ALIAS"
  menu_prompt_path "ADB connect descriptor or Easy Connect string" ADB_CONNECT_DESCRIPTOR "$ADB_CONNECT_DESCRIPTOR"
  menu_prompt_path "ADB service-level hint" ADB_SERVICE_LEVEL "$ADB_SERVICE_LEVEL"
  menu_prompt_oracle_name "ADB user" ADB_USER "$ADB_USER"
  menu_prompt_path "ADB password environment variable name" ADB_PASSWORD_ENV "$ADB_PASSWORD_ENV"
  menu_prompt_path "ADB wallet password environment variable name" ADB_WALLET_PASSWORD_ENV "$ADB_WALLET_PASSWORD_ENV"
  menu_prompt_path "Python executable with python-oracledb" ADB_PYTHON "$ADB_PYTHON"
  menu_prompt_path "ADB TLS mode (mTLS or TLS)" ADB_TLS_MODE "$ADB_TLS_MODE"
  menu_prompt_path "ADB OCID" ADB_OCID "$ADB_OCID"
  menu_prompt_path "ADB compartment OCID" ADB_COMPARTMENT_OCID "$ADB_COMPARTMENT_OCID"
  menu_prompt_path "OCI region" ADB_REGION "$ADB_REGION"
  menu_prompt_path "OCI CLI profile" ADB_OCI_PROFILE "$ADB_OCI_PROFILE"
  menu_prompt_path "OCI CLI config file" ADB_OCI_CONFIG_FILE "$ADB_OCI_CONFIG_FILE"
  menu_prompt_path "OCI CLI auth mode" ADB_OCI_AUTH "$ADB_OCI_AUTH"
  menu_prompt_path "Autonomous APEX URL" ADB_APEX_URL "$ADB_APEX_URL"
  menu_prompt_path "Autonomous Database Actions URL" ADB_DATABASE_ACTIONS_URL "$ADB_DATABASE_ACTIONS_URL"
  menu_prompt_path "Private endpoint/DNS label" ADB_PRIVATE_ENDPOINT "$ADB_PRIVATE_ENDPOINT"
  echo
  echo "Passwords are not prompted here. Set the environment variables named above before running the report."
}

menu_selected_adb_scenario_label() {
  if [[ -n "$ADB_SCENARIO_ID" && -n "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]:-}" ]]; then
    printf "%s - %s" "$ADB_SCENARIO_ID" "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]}"
  else
    printf "none"
  fi
}

menu_select_adb_scenario() {
  local answer

  echo
  print_adb_scenario_catalog
  echo
  echo "Enter ADB scenario id to select, or blank to keep current:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || return "$SUCCESS"
  answer="$(printf "%s" "$answer" | tr '[:lower:]' '[:upper:]')"
  if adb_scenario_exists "$answer"; then
    ADB_SCENARIO_ID="$answer"
    echo "Selected ADB scenario ${ADB_SCENARIO_ID}: ${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]}"
  else
    warn "Unknown ADB scenario id: $answer"
    return "$FAIL"
  fi
}

menu_require_adb_scenario() {
  if [[ -n "$ADB_SCENARIO_ID" && -n "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]:-}" ]]; then
    return "$SUCCESS"
  fi
  menu_select_adb_scenario
  [[ -n "$ADB_SCENARIO_ID" && -n "${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]:-}" ]]
}

menu_show_selected_adb_scenario() {
  menu_require_adb_scenario || return "$FAIL"
  print_adb_scenario_detail "$ADB_SCENARIO_ID"
}

menu_adb_helper_placeholder() {
  menu_require_adb_scenario || return "$FAIL"
  echo
  echo "ADB helper execution placeholder"
  echo "Scenario: ${ADB_SCENARIO_ID} - ${ADB_SCENARIO_TITLE[$ADB_SCENARIO_ID]}"
  echo "Current helper posture: ${ADB_SCENARIO_HELPER[$ADB_SCENARIO_ID]}"
  echo
  echo "No ADB destructive/logical execution helper is enabled yet."
  echo "Use the readiness report and scenario detail now; when seeded logical and OCI helpers are implemented, this menu path can call them without changing the workflow."
}

menu_adb_scenarios() {
  local answer

  while true; do
    echo
    echo "Autonomous Database Scenarios"
    echo "Selected ADB scenario: $(menu_selected_adb_scenario_label)"
    echo "  1. List ADB01-ADB20 with readiness status"
    echo "  2. Select ADB scenario"
    echo "  3. Show selected ADB scenario detail and validation status"
    echo "  4. Configure Autonomous Database report context"
    echo "  5. Run fresh Autonomous Database readiness report"
    echo "  6. Show latest Autonomous Database readiness report"
    echo "  7. Show latest Autonomous Database readiness report and generate HTML"
    echo "  8. Future ADB helper placeholder for selected scenario"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1|l|L)
        print_adb_scenario_catalog
        menu_pause
        ;;
      2|s|S)
        menu_select_adb_scenario
        menu_pause
        ;;
      3|d|D)
        menu_show_selected_adb_scenario
        menu_pause
        ;;
      4|c|C)
        menu_configure_adb_context
        menu_pause
        ;;
      5|r|R)
        menu_run_adb_readiness_report
        menu_pause
        ;;
      6)
        menu_run_show_latest_adb_report "text"
        menu_pause
        ;;
      7)
        menu_run_show_latest_adb_report "html"
        menu_pause
        ;;
      8|e|E)
        menu_adb_helper_placeholder
        menu_pause
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown Autonomous Database menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_run_audit_status() {
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--audit-status")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_audit_purge() {
  local run_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--purge-audit-logs")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  case "$run_mode" in
    execute) MENU_CMD+=("--execute") ;;
    dry-run) MENU_CMD+=("--dry-run") ;;
    *) warn "Unknown audit purge mode: $run_mode"; return "$FAIL" ;;
  esac
  menu_run_child_command
}

menu_run_review_index() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--review")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_review_topology() {
  local html_mode="$1"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--review-topology")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_prompt_artifact_reference() {
  local var_name="$1"
  local answer

  echo "Enter artifact path or latest:<kind> reference."
  echo "Kinds: topology, config, backup, service, apex-ords, adb, scenario-readiness, lifecycle, lifecycle-check, maa, health, doctor, first-run, public-limitations, scenario, protect, recover, runbook, baseline, review, audit, any"
  echo "Blank uses latest:any:"
  read -r answer || return "$FAIL"
  [[ -n "$answer" ]] || answer="latest:any"
  printf -v "$var_name" "%s" "$answer"
}

menu_run_show_artifact() {
  local html_mode="$1"
  local ref
  menu_prompt_artifact_reference ref || return "$FAIL"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--show-artifact" "$ref")
  [[ "$html_mode" == "html" ]] && MENU_CMD+=("--html")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

menu_run_render_html() {
  local ref
  menu_prompt_artifact_reference ref || return "$FAIL"
  MENU_CMD=("$BASH_EXECUTABLE" "$SCRIPT_PATH" "--render-html" "$ref")
  [[ -n "$LOG_DIR" ]] && MENU_CMD+=("--log-dir" "$LOG_DIR")
  [[ "$VERBOSE" -eq 1 ]] && MENU_CMD+=("--verbose")
  menu_run_child_command
}

file_mtime_epoch() {
  local file="$1"
  local epoch

  epoch="$(stat -c %Y "$file" 2>/dev/null || true)"
  if [[ -z "$epoch" ]]; then
    epoch="$(stat -f %m "$file" 2>/dev/null || true)"
  fi
  [[ "$epoch" =~ ^[0-9]+$ ]] || epoch=0
  printf "%s" "$epoch"
}

format_epoch_local() {
  local epoch="$1"

  if date -d "@${epoch}" "+%Y-%m-%d %H:%M:%S %Z" >/dev/null 2>&1; then
    date -d "@${epoch}" "+%Y-%m-%d %H:%M:%S %Z"
  else
    date -r "$epoch" "+%Y-%m-%d %H:%M:%S %Z" 2>/dev/null || printf "unknown"
  fi
}

file_size_human() {
  local file="$1"
  du -h "$file" 2>/dev/null | awk '{print $1}' || printf "?"
}

artifact_kind_from_path() {
  local file="$1"
  local base

  base="$(basename "$file")"
  case "$base" in
    *.manifest) printf "manifest" ;;
    *.rman) printf "rman" ;;
    *.sql) printf "sql" ;;
    *.md) printf "report" ;;
    *.html) printf "html" ;;
    *.log) printf "log" ;;
    *.txt) printf "text" ;;
    *.evidence) printf "evidence" ;;
    *.out) printf "output" ;;
    metadata.env) printf "audit-meta" ;;
    command.redacted) printf "audit-cmd" ;;
    exit_status) printf "audit-exit" ;;
    artifact_index) printf "audit-index" ;;
    *) printf "file" ;;
  esac
}

menu_collect_artifacts() {
  local category="$1"
  local limit="${2:-60}"
  local file epoch record
  local -a records=()

  MENU_ARTIFACT_FILES=()
  case "$category" in
    recent)
      [[ -d "$LOG_DIR" ]] || return "$SUCCESS"
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        epoch="$(file_mtime_epoch "$file")"
        records+=("${epoch}|${file}")
      done < <(find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.manifest' -o -name '*.log' -o -name '*.rman' -o -name '*.sql' -o -name '*.md' -o -name '*.txt' -o -name '*.html' -o -name '*.out' -o -name '*.evidence' \) 2>/dev/null)
      ;;
    reports)
      [[ -d "$LOG_DIR" ]] || return "$SUCCESS"
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        epoch="$(file_mtime_epoch "$file")"
        records+=("${epoch}|${file}")
      done < <(find "$LOG_DIR" -maxdepth 1 -type f \( -name '*.md' -o -name '*.html' \) 2>/dev/null)
      ;;
    audit)
      audit_effective_dir
      [[ -d "$AUDIT_DIR" ]] || return "$SUCCESS"
      while IFS= read -r file; do
        [[ -n "$file" ]] || continue
        epoch="$(file_mtime_epoch "$file")"
        records+=("${epoch}|${file}")
      done < <(find "$AUDIT_DIR" -mindepth 1 -maxdepth 4 -type f \( -name '*.log' -o -name '*.env' -o -name '*.redacted' -o -name '*.manifest' -o -name '*.md' -o -name '*.txt' -o -name '*.rman' -o -name '*.sql' -o -name '*.out' -o -name '*.evidence' -o -name 'exit_status' -o -name 'artifact_index' \) 2>/dev/null)
      ;;
    *)
      warn "Unknown artifact category: $category"
      return "$FAIL"
      ;;
  esac

  while IFS= read -r record; do
    [[ -n "$record" ]] || continue
    MENU_ARTIFACT_FILES+=("${record#*|}")
  done < <(printf "%s\n" "${records[@]}" | sort -t'|' -k1,1rn | head -n "$limit")
}

menu_print_artifact_list() {
  local idx file epoch when kind size

  if [[ "${#MENU_ARTIFACT_FILES[@]}" -eq 0 ]]; then
    echo "No files found."
    return "$SUCCESS"
  fi

  printf "  %3s  %-22s %-12s %-8s %s\n" "No." "Generated" "Type" "Size" "File"
  printf "  %3s  %-22s %-12s %-8s %s\n" "---" "----------------------" "------------" "--------" "----"
  idx=1
  for file in "${MENU_ARTIFACT_FILES[@]}"; do
    epoch="$(file_mtime_epoch "$file")"
    when="$(format_epoch_local "$epoch")"
    kind="$(artifact_kind_from_path "$file")"
    size="$(file_size_human "$file")"
    printf "  %3d. %-22s %-12s %-8s %s\n" "$idx" "$when" "$kind" "$size" "$file"
    idx=$((idx + 1))
  done
}

menu_inspect_artifact_file() {
  local file="$1"

  [[ -f "$file" ]] || {
    warn "Selected file no longer exists: $file"
    return "$FAIL"
  }
  echo
  echo "Inspecting artifact"
  echo "Path: ${file}"
  echo "Generated: $(format_epoch_local "$(file_mtime_epoch "$file")")"
  echo "Type: $(artifact_kind_from_path "$file")"
  echo "Size: $(file_size_human "$file")"
  echo
  show_artifact "$file"
}

menu_browse_artifacts() {
  local title="$1"
  local category="$2"
  local limit="${3:-60}"
  local answer idx

  while true; do
    menu_collect_artifacts "$category" "$limit" || return "$FAIL"
    echo
    echo "$title"
    menu_print_artifact_list
    if [[ "${#MENU_ARTIFACT_FILES[@]}" -eq 0 ]]; then
      menu_pause
      return "$SUCCESS"
    fi
    echo
    echo "Enter a number to inspect, r to refresh, or b/blank to go back:"
    read -r answer || return "$FAIL"
    [[ -n "$answer" ]] || return "$SUCCESS"
    case "$answer" in
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      r|R)
        continue
        ;;
    esac
    if [[ "$answer" =~ ^[0-9]+$ && "$answer" -ge 1 && "$answer" -le "${#MENU_ARTIFACT_FILES[@]}" ]]; then
      idx=$((answer - 1))
      menu_inspect_artifact_file "${MENU_ARTIFACT_FILES[$idx]}"
      menu_pause
    else
      warn "Invalid selection: $answer"
      menu_pause
    fi
  done
}

menu_review_center() {
  local answer

  while true; do
    echo
    echo "Review Center"
    echo "  1. Show latest collected topology"
    echo "  2. Generate HTML for latest collected topology"
    echo "  3. Generate collected activity review index"
    echo "  4. Generate collected activity review index with HTML"
    echo "  5. Show artifact as text"
    echo "  6. Show artifact as text and generate HTML"
    echo "  7. Generate HTML for artifact"
    echo "  8. Show recent manifests, logs, reports, and HTML files"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        menu_run_review_topology "text"
        menu_pause
        ;;
      2)
        menu_run_review_topology "html"
        menu_pause
        ;;
      3)
        menu_run_review_index "text"
        menu_pause
        ;;
      4)
        menu_run_review_index "html"
        menu_pause
        ;;
      5)
        menu_run_show_artifact "text"
        menu_pause
        ;;
      6)
        menu_run_show_artifact "html"
        menu_pause
        ;;
      7)
        menu_run_render_html
        menu_pause
        ;;
      8)
        menu_browse_artifacts "Recent Manifests, Logs, Reports, And Helper Files" "recent" 60
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown review menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_audit_settings() {
  local answer

  while true; do
    echo
    echo "Audit / Retention Settings"
    echo "  1. Enable/disable audit log retention"
    echo "  2. Set audit retention days"
    echo "  3. Set audit directory"
    echo "  4. Show audit status"
    echo "  5. Dry-run audit purge"
    echo "  6. Execute audit purge"
    echo "  7. Browse audit logs and inspect contents"
    echo "  b. Back"
    echo
    echo "Current retain=${AUDIT_RETAIN} retention_days=${AUDIT_RETENTION_DAYS} audit_dir=${AUDIT_DIR}"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        menu_prompt_audit_retain
        menu_pause
        ;;
      2)
        menu_prompt_audit_retention_days
        menu_pause
        ;;
      3)
        menu_prompt_path "audit directory" AUDIT_DIR "$AUDIT_DIR"
        [[ -n "$AUDIT_DIR" ]] || audit_effective_dir
        mkdir -p "$AUDIT_DIR" || die "Unable to create audit directory: $AUDIT_DIR"
        menu_pause
        ;;
      4)
        menu_run_audit_status
        menu_pause
        ;;
      5)
        menu_run_audit_purge "dry-run"
        menu_pause
        ;;
      6)
        menu_run_audit_purge "execute"
        menu_pause
        ;;
      7)
        menu_browse_artifacts "Audit Logs And Retained Run Artifacts" "audit" 80
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown audit menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_reports() {
  local answer

  while true; do
    echo
    echo "Reports"
    echo "  1. Generate target configuration report"
    echo "  2. Generate target configuration report with deep RMAN validation (read-only, heavier)"
    echo "  3. Generate Oracle MAA readiness report"
    echo "  4. Set MAA / SLA planning context"
    echo "  5. Generate resilience scorecard"
    echo "  6. Generate Oracle service HA best-practice review"
    echo "  7. Generate backup strategy and recoverability report"
    echo "  8. Generate backup report with deep RMAN validation (read-only, heavier)"
    echo "  9. Dry-run fresh RMAN baseline backup"
    echo " 10. Run fresh RMAN baseline backup (requires BASELINE-BACKUP confirmation)"
    echo " 11. Generate scenario lifecycle coverage report"
    echo " 12. Generate APEX / ORDS readiness report"
    echo " 13. Set Autonomous Database report context"
    echo " 14. Generate Autonomous Database readiness report"
    echo " 15. Browse generated reports and inspect contents"
    echo " 16. List Autonomous Database scenarios with readiness status"
    echo " 17. Select Autonomous Database scenario"
    echo " 18. Show selected Autonomous Database scenario detail"
    echo " 19. Open Autonomous Database scenarios submenu"
    echo "  b. Back"
    echo
    echo "Choice:"
    read -r answer || return "$FAIL"
    case "$answer" in
      1)
        REPORT_DEEP_VALIDATE=0
        menu_run_configuration_report
        menu_pause
        ;;
      2)
        REPORT_DEEP_VALIDATE=1
        menu_run_configuration_report
        menu_pause
        ;;
      3)
        menu_run_maa_report
        menu_pause
        ;;
      4)
        menu_configure_maa_context
        menu_pause
        ;;
      5)
        menu_run_resilience_scorecard
        menu_pause
        ;;
      6)
        menu_run_service_review
        menu_pause
        ;;
      7)
        REPORT_DEEP_VALIDATE=0
        menu_run_backup_report
        menu_pause
        ;;
      8)
        REPORT_DEEP_VALIDATE=1
        menu_run_backup_report
        menu_pause
        ;;
      9)
        menu_run_baseline_backup "dry-run"
        menu_pause
        ;;
      10)
        menu_run_baseline_backup "execute"
        menu_pause
        ;;
      11)
        menu_run_scenario_lifecycle_report
        menu_pause
        ;;
      12)
        menu_run_apex_ords_report
        menu_pause
        ;;
      13)
        menu_configure_adb_context
        menu_pause
        ;;
      14)
        menu_run_adb_readiness_report
        menu_pause
        ;;
      15)
        menu_browse_artifacts "Generated Reports And HTML Artifacts" "reports" 80
        ;;
      16)
        print_adb_scenario_catalog
        menu_pause
        ;;
      17)
        menu_select_adb_scenario
        menu_pause
        ;;
      18)
        menu_show_selected_adb_scenario
        menu_pause
        ;;
      19)
        menu_adb_scenarios
        ;;
      b|B|q|Q)
        return "$SUCCESS"
        ;;
      *)
        warn "Unknown reports choice: $answer"
        menu_pause
        ;;
    esac
  done
}

menu_show_recent_artifacts() {
  menu_browse_artifacts "Recent Manifests, Logs, Reports, And Helper Files" "recent" 60
}

interactive_menu() {
  local answer

  while true; do
    menu_print_header
    echo
    echo "Guided Workflow"
    echo
    echo "Safe discovery and planning"
    echo "  1. Discover or refresh database topology"
    echo "  2. Select scenario"
    echo "  3. List all scenarios"
    echo "  4. Show recovery runbook for selected scenario"
    echo "  v. Validate selected scenario readiness"
    echo "  5. Dry-run selected scenario"
    echo "  6. Dry-run protection for selected scenario"
    echo "  9. Dry-run recovery for selected scenario"
    echo " 11. Run health check / validation"
    echo " 12. Configure targets and options"
    echo " 13. Browse recent manifests, logs, reports, and inspect contents"
    echo " 14. Dry-run random/aleatory scenario for this topology"
    echo " 16. Reports"
    echo " 17. Generate scenario readiness report for this topology"
    echo " 18. Audit / retention settings"
    echo " 19. Review collected topology, logs, reports, and history"
    echo " 20. Autonomous Database scenarios"
    echo " 21. Seed / prepare scenario lab for this topology"
    echo " 22. Public readiness and safety checks"
    echo
    echo "Execution actions - typed confirmation required"
    echo "  7. Execute protection for selected scenario"
    echo "  8. Execute selected scenario"
    echo " 10. Execute recovery for selected scenario"
    echo " 15. Execute random/aleatory scenario for this topology"
    echo "  q. Quit"
    echo
    echo "Choice:"
    read -r answer || break

    case "$answer" in
      1|d|D)
        discover_environment || true
        print_discovery
        menu_pause
        ;;
      2|s|S)
        menu_select_scenario
        menu_pause
        ;;
      3|l|L)
        list_scenarios
        menu_pause
        ;;
      4|r|R)
        if menu_require_scenario; then
          print_runbook_only "$SCENARIO_ID"
        fi
        menu_pause
        ;;
      v|V)
        menu_run_validate_scenario
        menu_pause
        ;;
      5)
        menu_run_child_action "scenario" "dry-run"
        menu_pause
        ;;
      6)
        menu_run_child_action "protect" "dry-run"
        menu_pause
        ;;
      7)
        menu_run_child_action "protect" "execute"
        menu_pause
        ;;
      8)
        menu_run_child_action "scenario" "execute"
        menu_pause
        ;;
      9)
        menu_run_child_action "recover" "dry-run"
        menu_pause
        ;;
      10)
        menu_run_child_action "recover" "execute"
        menu_pause
        ;;
      11|h|H)
        menu_run_health_check
        menu_pause
        ;;
      12|c|C)
        menu_configure_options
        ;;
      13|a|A)
        menu_show_recent_artifacts
        ;;
      14)
        menu_run_random_scenario "dry-run"
        menu_pause
        ;;
      15)
        menu_run_random_scenario "execute"
        menu_pause
        ;;
      16|p|P)
        menu_reports
        ;;
      17)
        menu_run_scenario_readiness_report
        menu_pause
        ;;
      18)
        menu_audit_settings
        ;;
      19)
        menu_review_center
        ;;
      20)
        menu_adb_scenarios
        ;;
      21)
        menu_prepare_environment
        ;;
      22)
        menu_public_readiness
        ;;
      q|Q|0)
        break
        ;;
      *)
        warn "Unknown menu choice: $answer"
        menu_pause
        ;;
    esac
  done
}

main() {
  register_scenarios
  register_adb_scenarios
  load_startup_config "$@"
  parse_args "$@"
  normalize_targets
  init_runtime
  audit_start

  case "$MODE" in
    discover)
      print_discovery
      ;;
    list)
      list_scenarios
      ;;
    doctor)
      run_doctor
      ;;
    first_run)
      run_first_run_guide
      ;;
    public_limitations)
      run_public_limitations_page
      ;;
    health)
      run_health_check
      ;;
    report)
      run_configuration_report
      ;;
    backup_report)
      run_backup_report
      ;;
    service_review)
      run_service_review
      ;;
    apex_ords_report)
      run_apex_ords_report
      ;;
    prepare_environment)
      run_prepare_environment
      ;;
    adb_readiness_report)
      run_adb_readiness_report
      ;;
    adb_scenarios)
      print_adb_scenario_catalog
      ;;
    adb_scenario_detail)
      [[ -n "$ADB_SCENARIO_ID" ]] || die "No ADB scenario id provided."
      print_adb_scenario_detail "$ADB_SCENARIO_ID"
      ;;
    baseline_backup)
      run_baseline_backup
      ;;
    audit_status)
      audit_status
      ;;
    audit_purge)
      purge_audit_logs
      ;;
    show_config)
      show_active_config
      ;;
    validate_config)
      validate_config_runtime || exit "$FAIL"
      ;;
    write_config_template)
      write_config_template "$CONFIG_TEMPLATE_FILE"
      ;;
    review)
      generate_review_index
      ;;
    review_topology)
      review_topology
      ;;
    show_artifact)
      [[ -n "$REVIEW_TARGET" ]] || die "No artifact reference provided."
      show_artifact "$REVIEW_TARGET"
      ;;
    render_html)
      [[ -n "$HTML_TARGET" ]] || die "No artifact reference provided."
      render_html_target "$HTML_TARGET"
      ;;
    maa_report)
      run_maa_report
      ;;
    resilience_scorecard)
      run_resilience_scorecard
      ;;
    validate)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_scenario_validation "$SCENARIO_ID"
      ;;
    validate_all)
      validate_all_scenarios
      ;;
    scenario_readiness_report)
      generate_scenario_readiness_report
      ;;
    scenario_lifecycle_report)
      generate_scenario_lifecycle_report
      ;;
    scenario_lifecycle_check)
      scenario_lifecycle_check
      ;;
    secret_scan)
      run_secret_scan
      ;;
    sanitize_artifacts)
      run_sanitize_artifacts
      ;;
    node_sync_check)
      run_node_sync_check
      ;;
    release_check)
      run_release_check
      ;;
    runbook)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      print_runbook_only "$SCENARIO_ID"
      ;;
    scenario)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      run_scenario "$SCENARIO_ID"
      ;;
    random)
      run_random_scenario
      ;;
    protect)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      protect_scenario "$SCENARIO_ID"
      ;;
    recover)
      [[ -n "$SCENARIO_ID" ]] || die "No scenario id provided."
      recover_scenario "$SCENARIO_ID"
      ;;
    menu)
      echo "Starting CrashSimulator Guided Workflow menu..."
      echo "Trying target topology discovery for the menu header. This normally takes a few seconds on database hosts."
      echo "If SQL*Plus is unavailable, the menu still opens for ADB reports, ADB scenarios, review, and configuration."
      menu_discover_environment_optional
      interactive_menu
      ;;
    *)
      die "Unknown mode: $MODE"
      ;;
  esac

  maybe_refresh_resilience_scorecard "$MODE" "$SCENARIO_ID"
}

main "$@"
