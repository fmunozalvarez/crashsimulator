# CrashSimulator Oracle Service HA Best-Practice Review

- Generated UTC: `2026-06-15T10:30:20Z`
- Host: `crashrac1-mlprn`
- OS user: `oracle`
- Database: `CRASHDB`
- DB unique name: `crashrac`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Cluster type: `RAC`
- Storage type: `FEX_ACFS`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016.evidence`
- srvctl service evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016_srvctl_services.out`
- Data Guard Broker FSFO evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016_dgmgrl_fsfo.out`

This report is read-only. It reviews Oracle Database service metadata, AC/TAC readiness signals, FAN/client HA attributes, Data Guard FSFO posture, Active Data Guard DML redirection configuration, and role-based service evidence when srvctl is available.

## Application Continuity, TAC, FSFO, DML Redirection, And Services Review

| Area | Evidence |
| --- | --- |
| SQL service dictionary | Source `DBA_SERVICES`, services `4`, application services `2`, PDB services `2` |
| Application Continuity / TAC | AC `0`, TAC `0`, Commit Outcome `0`, missing AC/TAC `0` |
| Client HA service attributes | FAN/AQ `0`, RLB goals `2`, drain timeout `0`, session state consistency `0`, failover restore `0` |
| Data Guard / FSFO | DG detected `0`, FSFO status `DISABLED`, FSFO target `NONE`, observer `UNKNOWN`, threshold `0` |
| FSFO observer best-practice evidence | DGMGRL `YES/OK` from `/u02/app/oracle/product/23.0.0.0/dbhome_1/bin/dgmgrl`, active observer `UNKNOWN`, observer count `0`, observers `NONE`, PreferredObserverHosts `NO` |
| Active Data Guard DML redirection | adg_redirect_dml `FALSE`, ADG standby context `0` |
| srvctl service metadata | srvctl `NO`, status `UNAVAILABLE`, services `UNKNOWN`, role-based `UNKNOWN`, primary-role `UNKNOWN`, standby-role `UNKNOWN`, automatic `UNKNOWN` |

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
| `INFO` | FSFO observer | Observer best-practice placement | dg_detected=0 | Observer placement checks become applicable after Data Guard Broker and FSFO are configured. |
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

SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016.evidence`

```text
CSIM_MAA|db_name|CRASHDB
CSIM_MAA|db_unique_name|crashrac
CSIM_MAA|db_role|PRIMARY
CSIM_MAA|open_mode|READ WRITE
CSIM_MAA|cdb|YES
CSIM_MAA|log_mode|ARCHIVELOG
CSIM_MAA|force_logging|YES
CSIM_MAA|flashback_on|YES
CSIM_MAA|protection_mode|MAXIMUM PERFORMANCE
CSIM_MAA|protection_level|MAXIMUM PERFORMANCE
CSIM_MAA|switchover_status|NOT ALLOWED
CSIM_MAA|fsfo_status|DISABLED
CSIM_MAA|fsfo_target|NONE
CSIM_MAA|fsfo_threshold|0
CSIM_MAA|fsfo_observer_present|UNKNOWN
CSIM_MAA|dbid|1275818439
CSIM_MAA|platform_name|Linux x86 64-bit
CSIM_MAA|instance_name|crashdb1
CSIM_MAA|host_name|crashrac1-mlprn
CSIM_MAA|version|23.0.0.0.0
CSIM_MAA|version_major|23
CSIM_MAA|instance_status|OPEN
CSIM_MAA|instance_parallel|YES
CSIM_MAA|instance_thread|1
CSIM_MAA|cluster_database|TRUE
CSIM_MAA|remote_login_passwordfile|EXCLUSIVE
CSIM_MAA|db_recovery_file_dest|@gB2Ac2II(RECO_HC_HIGHREDUNDANCY)
CSIM_MAA|db_recovery_file_dest_size|440G
CSIM_MAA|local_undo_enabled|UNKNOWN
CSIM_MAA|wallet_root|/var/opt/oracle/dbaas_acfs/crashdb/wallet_root
CSIM_MAA|tde_configuration|keystore_configuration=FILE
CSIM_MAA|archive_lag_target|0
CSIM_MAA|adg_redirect_dml|FALSE
CSIM_MAA|adg_redirect_dml_modifiable|IMMEDIATE
CSIM_MAA|control_file_count|1
CSIM_MAA|redo_group_count|8
CSIM_MAA|redo_min_members|2
CSIM_MAA|redo_groups_less_than_two_members|0
CSIM_MAA|recover_file_count|0
CSIM_MAA|block_corruption_count|0
CSIM_MAA|copy_corruption_count|0
CSIM_MAA|backup_corruption_count|0
CSIM_MAA|guaranteed_restore_point_count|0
CSIM_MAA|fra_configured|YES
CSIM_MAA|fra_used_pct|4.34
CSIM_MAA|fra_reclaimable_pct|.47
CSIM_MAA|recent_successful_backup_jobs_7d|2
CSIM_MAA|recent_failed_backup_jobs_7d|0
CSIM_MAA|last_successful_backup_time|2026-06-15 08:27:55
CSIM_MAA|last_successful_backup_age_hours|2
CSIM_MAA|backup_device_types|DISK
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

srvctl service evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016_srvctl_services.out`

```text
```

Data Guard Broker FSFO evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016_dgmgrl_fsfo.out`

```text
Connected to "crashrac"
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
```

## Data Guard Broker FSFO Evidence

File: `/tmp/crashsimulator/crashsimulator_logs/crashsim_service_review_20260615_103016_dgmgrl_fsfo.out`

```text
Connected to "crashrac"
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
```
