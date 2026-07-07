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

