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

