# CrashSimulator Oracle Service HA Best-Practice Review

- Generated UTC: `2026-06-07T03:46:13Z`
- Host: `crashdb26ai1`
- OS user: `oracle`
- Database: `CRASHDB`
- DB unique name: `crashdb_26ai`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Cluster type: `RAC`
- Storage type: `ASM`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260607_034612.evidence`
- srvctl service evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260607_034612_srvctl_services.out`

This report is read-only. It reviews Oracle Database service metadata, AC/TAC readiness signals, FAN/client HA attributes, Data Guard FSFO posture, Active Data Guard DML redirection configuration, and role-based service evidence when srvctl is available.

## Application Continuity, TAC, FSFO, DML Redirection, And Services Review

| Area | Evidence |
| --- | --- |
| SQL service dictionary | Source `DBA_SERVICES`, services `4`, application services `2`, PDB services `2` |
| Application Continuity / TAC | AC `0`, TAC `0`, Commit Outcome `0`, missing AC/TAC `0` |
| Client HA service attributes | FAN/AQ `0`, RLB goals `2`, drain timeout `0`, session state consistency `0`, failover restore `0` |
| Data Guard / FSFO | DG detected `0`, FSFO status `DISABLED`, FSFO target `NONE`, observer `UNKNOWN`, threshold `0` |
| Active Data Guard DML redirection | adg_redirect_dml `FALSE`, ADG standby context `0` |
| srvctl service metadata | srvctl `YES`, status `OK`, services `2`, role-based `2`, primary-role `2`, standby-role `0`, automatic `2` |

## Service Best-Practice Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Services | Application services visible | application_services=2 | Keep services workload-specific so HA, DR, and maintenance policies can differ by application. |
| `INFO` | AC/TAC | Replay-capable services | ac_services=0, tac_services=0 | For user-facing services, evaluate TAC or AC with FAN/ONS and compatible drivers before HA drills. |
| `INFO` | AC/TAC | Commit Outcome / Transaction Guard | commit_outcome_services=0 | Enable Commit Outcome for AC/TAC candidate services where the application is replay-safe. |
| `WARN` | Client HA | FAN/AQ notification services | fan_services=0 | Enable HA notifications for application services and validate client-side failover behavior. |
| `OK` | Client HA | Runtime/client load balancing goals | rlb_services=2 | Validate service-time or throughput goals with connection pools and service relocation. |
| `INFO` | Planned maintenance | Service drain timeout | drain_timeout_services=0 | Set drain timeout for services that need graceful planned maintenance. |
| `INFO` | AC/TAC | Session state consistency | session_state_services=0 | Review session-state consistency before enabling AC/TAC for stateful applications. |
| `INFO` | AC/TAC | Failover restore | failover_restore_services=0 | For TAC/AC candidates, review failover restore behavior with the application team. |
| `INFO` | Data Guard services | Role-based services | dg_detected=0 | Role-based services become critical once Data Guard or Active Data Guard is configured. |
| `INFO` | FSFO | Fast-Start Failover awareness | dg_detected=0 | FSFO applies after a broker-managed Data Guard configuration is in place. |
| `INFO` | ADG DML redirection | DML redirection configuration | adg_redirect_dml=FALSE | DML redirection is relevant for Active Data Guard standby services. |

## Recommended Validation Drills

| Objective | Suggested validation |
| --- | --- |
| AC/TAC request replay | Run planned service relocation and scenario `55`/`56`; verify client replay, Transaction Guard outcomes, and application smoke tests. |
| FAN and service draining | Stop/start or relocate one service through srvctl; confirm connection pools receive FAN/ONS events and drain gracefully. |
| Data Guard role services | Switchover/failover in a lab; confirm PRIMARY services start only on the new primary and ADG read services start only on the standby role. |
| FSFO | Validate observer placement, failover threshold, failover target, automatic failover, reinstate, and failback runbooks. |
| ADG DML redirection | On an ADG standby, test approved redirected DML paths separately from read-only services and measure primary impact. |

## Raw Service Evidence

SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260607_034612.evidence`

```text
CSIM_MAA|db_name|CRASHDB
CSIM_MAA|db_unique_name|crashdb_26ai
CSIM_MAA|db_role|PRIMARY
CSIM_MAA|open_mode|READ WRITE
CSIM_MAA|cdb|YES
CSIM_MAA|log_mode|ARCHIVELOG
CSIM_MAA|force_logging|YES
CSIM_MAA|flashback_on|NO
CSIM_MAA|protection_mode|MAXIMUM PERFORMANCE
CSIM_MAA|protection_level|MAXIMUM PERFORMANCE
CSIM_MAA|switchover_status|NOT ALLOWED
CSIM_MAA|fsfo_status|DISABLED
CSIM_MAA|fsfo_target|NONE
CSIM_MAA|fsfo_threshold|0
CSIM_MAA|fsfo_observer_present|UNKNOWN
CSIM_MAA|dbid|1275113611
CSIM_MAA|platform_name|Linux x86 64-bit
CSIM_MAA|instance_name|crashdb1
CSIM_MAA|host_name|crashdb26ai1
CSIM_MAA|version|23.0.0.0.0
CSIM_MAA|version_major|23
CSIM_MAA|instance_status|OPEN
CSIM_MAA|instance_parallel|YES
CSIM_MAA|instance_thread|1
CSIM_MAA|cluster_database|TRUE
CSIM_MAA|remote_login_passwordfile|EXCLUSIVE
CSIM_MAA|db_recovery_file_dest|+RECO
CSIM_MAA|db_recovery_file_dest_size|255G
CSIM_MAA|local_undo_enabled|UNKNOWN
CSIM_MAA|wallet_root|/opt/oracle/dcs/commonstore/wallets/crashdb_26ai
CSIM_MAA|tde_configuration|keystore_configuration=FILE
CSIM_MAA|archive_lag_target|0
CSIM_MAA|adg_redirect_dml|FALSE
CSIM_MAA|adg_redirect_dml_modifiable|IMMEDIATE
CSIM_MAA|control_file_count|2
CSIM_MAA|redo_group_count|8
CSIM_MAA|redo_min_members|2
CSIM_MAA|redo_groups_less_than_two_members|0
CSIM_MAA|recover_file_count|0
CSIM_MAA|block_corruption_count|0
CSIM_MAA|copy_corruption_count|0
CSIM_MAA|backup_corruption_count|0
CSIM_MAA|guaranteed_restore_point_count|0
CSIM_MAA|fra_configured|YES
CSIM_MAA|fra_used_pct|.16
CSIM_MAA|fra_reclaimable_pct|.14
CSIM_MAA|recent_successful_backup_jobs_7d|2
CSIM_MAA|recent_failed_backup_jobs_7d|0
CSIM_MAA|last_successful_backup_time|2026-06-07 03:19:51
CSIM_MAA|last_successful_backup_age_hours|.4
CSIM_MAA|backup_device_types|SBT_TAPE
CSIM_MAA|datafiles_without_backup_metadata|0
CSIM_MAA|remote_standby_dest_count|0
CSIM_MAA|valid_remote_standby_dest_count|0
CSIM_MAA|standby_dest_error_count|0
CSIM_MAA|archive_gap_count|0
CSIM_MAA|dataguard_stats_count|0
CSIM_MAA|dataguard_transport_lag|UNKNOWN
CSIM_MAA|dataguard_apply_lag|UNKNOWN
CSIM_MAA|tde_wallet_open_count|3
CSIM_MAA|tde_wallet_not_open_count|0
CSIM_MAA|encrypted_tablespace_count|8
CSIM_MAA|pdb_count|1
CSIM_MAA|pdb_not_open_rw_count|0
CSIM_MAA|service_attribute_source|DBA_SERVICES
CSIM_MAA|service_failover_type_column|YES
CSIM_MAA|service_commit_outcome_column|YES
CSIM_MAA|service_aq_ha_notification_column|YES
CSIM_MAA|service_drain_timeout_column|YES
CSIM_MAA|service_session_state_column|YES
CSIM_MAA|service_total_count|4
CSIM_MAA|service_user_count|2
CSIM_MAA|ac_service_count|0
CSIM_MAA|tac_service_count|0
CSIM_MAA|application_continuity_service_count|0
CSIM_MAA|service_without_ac_tac_count|0
CSIM_MAA|commit_outcome_service_count|0
CSIM_MAA|fan_notification_service_count|0
CSIM_MAA|runtime_load_balancing_service_count|2
CSIM_MAA|drain_timeout_service_count|0
CSIM_MAA|session_state_consistency_service_count|0
CSIM_MAA|failover_restore_service_count|0
CSIM_MAA|pdb_service_count|2
CSIM_MAA|capture_process_count|0
CSIM_MAA|apply_process_count|0
```

srvctl service evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260607_034612_srvctl_services.out`

```text
Service name: crashdb_CRASHDB_PDB1.paas.oracle.com
Cardinality: 2
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: FALSE
AQ HA notifications: FALSE
Global: FALSE
Commit Outcome: FALSE
Commit Outcome Fastpath: FALSE
Reset State: NONE
Failover type: NONE
Failover method: NONE
Failover retries:
Failover delay:
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: NONE
Edition:
Pluggable database name: CRASHDB_PDB1
True Cache service:
Maximum lag time: ANY
SQL Translation Profile:
Retention: 86400 seconds
Failback :  no
Replay Initiation Time: 300 seconds
Drain timeout:
Template timeout: 86400 seconds
Stop option:
Session State Consistency:
Auto Connection Rebalance: DEFAULT
GSM Flags: 0
Service is enabled
Preferred instances: crashdb1,crashdb2
Available instances:
CSS critical: no

Service name: crashdb_crashdb_pdb1
Cardinality: 2
Service role: PRIMARY
Management policy: AUTOMATIC
DTP transaction: FALSE
AQ HA notifications: FALSE
Global: FALSE
Commit Outcome: FALSE
Commit Outcome Fastpath: FALSE
Reset State: NONE
Failover type: NONE
Failover method:
Failover retries:
Failover delay:
Failover restore: NONE
Connection Load Balancing Goal: LONG
Runtime Load Balancing Goal: NONE
TAF policy specification: NONE
Edition:
Pluggable database name: CRASHDB_PDB1
True Cache service:
Maximum lag time: ANY
SQL Translation Profile:
Retention: 86400 seconds
Failback :  no
Replay Initiation Time: 300 seconds
Drain timeout:
Template timeout: 86400 seconds
Stop option:
Session State Consistency:
Auto Connection Rebalance: DEFAULT
GSM Flags: 0
Service is enabled
Preferred instances: crashdb1,crashdb2
Available instances:
CSS critical: no
```

## srvctl Service Status

Command: srvctl status service -d crashdb_26ai

```text
Service crashdb_CRASHDB_PDB1.paas.oracle.com is running on instances crashdb1,crashdb2
Service crashdb_crashdb_pdb1 is running on instances crashdb1,crashdb2
```

## Data Guard Broker FSFO Evidence

Command: bash -lc printf\ \'show\ configuration\ verbose\;\\nshow\ fast_start\ failover\;\\nexit\\n\'\ \|\ dgmgrl\ -silent\ /

```text
Connected to "crashdb_26ai"
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
```
