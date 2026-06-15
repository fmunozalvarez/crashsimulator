# CrashSimulator Oracle MAA Readiness Report

- Generated UTC: `2026-06-15T08:24:52Z`
- Host: `crashrac1-mlprn`
- OS user: `oracle`
- Application context: `not supplied`
- Database: `CRASHDB`
- DB unique name: `crashrac`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Cluster type: `RAC`
- Storage type: `FEX`
- Target MAA level: `Unknown`
- Candidate MAA level: `Silver`
- Current evidenced MAA level: `Bronze`
- Readiness status: `Baseline checks passed`
- Raw SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260615_082449.evidence`
- Data Guard Broker FSFO evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260615_082449_dgmgrl_fsfo.out`

This report is a best-effort posture assessment, not an Oracle certification. It separates business target, topology candidate, and current evidenced MAA level so product presence alone does not overclaim HA/DR maturity.


## MAA Decision-Tree Result

| Field | Value |
| --- | --- |
| Target MAA level | `Unknown` |
| Target basis | Business RTO/RPO and outage-class context is incomplete. |
| Target gaps to verify | criticality; RTO objectives; RPO objectives; local HA target; DR requirement |
| Candidate MAA level | `Silver` |
| Candidate basis | RAC/RAC One Node or explicitly local Data Guard standby evidence indicates a Silver local-HA candidate. |
| Current evidenced MAA level | `Bronze` |
| Evidenced basis | Bronze evidenced: backup/recovery baseline is configured and no immediate recovery/corruption blockers were detected. |
| Fit-gap summary | Target MAA level is unknown because business context is incomplete. |
| Baseline readiness | `Baseline checks passed` |
| Detection confidence | Medium: based on target-host SQL/GI evidence; application failover behavior, external monitoring, and measured business outage need confirmation. |

## Evidence Maturity Scorecard

| Domain | Score | Meaning |
| --- | ---: | --- |
| Business requirements | `0` | RTO/RPO, criticality, outage class, and target context completeness. |
| Backup and recovery | `3` | ARCHIVELOG, RMAN coverage, corruption/recovery blockers, and measured recovery manifest evidence. |
| Local HA | `3` | RAC/RAC One/local standby, service placement, client HA attributes, and measured local-failure drills. |
| Data Guard / ADG / FSFO | `0` | DG configuration, Broker/lag/role services, FSFO observer, and measured role/lag/failover drills. |
| Application continuity | `2` | Dedicated services, FAN/RLB/drain, AC/TAC/replay, and application/session validation evidence. |
| Operations and evidence | `3` | Audit retention, readiness/lifecycle evidence, runbook/report evidence, and repeatability. |

## MAA Reference Model Used

| MAA level | Observable capabilities used by this report |
| --- | --- |
| Bronze | Single-instance or Oracle Restart style database with ARCHIVELOG, RMAN backup/recovery evidence, corruption checks, and basic restart/restore readiness. |
| Silver | Bronze plus strong local HA using RAC/RAC One Node or explicitly local Data Guard standby, with service/client failover and application-aware continuity evidence. |
| Gold | Silver plus Data Guard/Active Data Guard DR evidence, Broker/lag/role-services/FSFO where applicable, and measured role-transition/application behavior. |
| Platinum | Gold plus Exadata/optimized platform and/or supported active replication patterns with seconds-class measured service behavior. |
| Diamond | Extreme-availability active/global architecture such as 26ai/Exadata/GoldenGate or distributed patterns; supportability and measured evidence require manual confirmation. |

## Evidence Summary

| Area | Evidence |
| --- | --- |
| Database | Role `PRIMARY`, open mode `READ WRITE`, log mode `ARCHIVELOG`, force logging `YES`, flashback `YES` |
| Local HA | Cluster `RAC`, cluster_database `TRUE`, instance parallel `YES`, GI managed `1`, storage `FEX` |
| Backup | Recent successful jobs 7d `1`, failed jobs 7d `0`, last success `2026-06-15 07:41:02`, datafiles without backup metadata `0`, devices `DISK` |
| Data Guard | Remote standby destinations `0`, valid destinations `0`, FSFO `DISABLED`, observer `UNKNOWN`, transport lag `UNKNOWN`, apply lag `UNKNOWN` |
| Storage/config | Control files `1`, redo min members `2`, redo groups with <2 members `0`, FRA configured `YES`, FRA used `4.03%` |
| Security | Wallet open rows `3`, wallet not-open rows `0`, encrypted tablespaces `8`, TDE config `keystore_configuration=FILE` |
| Application continuity / services | Replay-capable services `0`, AC `0`, TAC `0`, missing AC/TAC `0`, role-based srvctl services `UNAVAILABLE` |
| ADG DML redirection | adg_redirect_dml `FALSE`, modifiable `IMMEDIATE` |
| Replication dictionary | capture processes `0`, apply processes `0` |

## Best-Practice Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Recoverability | ARCHIVELOG enabled | LOG_MODE=ARCHIVELOG | Keep validating archived-log backup, restore, and gap handling. |
| `OK` | Data protection | FORCE LOGGING enabled | FORCE_LOGGING=YES | Keep FORCE LOGGING enabled for Data Guard/readiness unless an exception is explicitly approved. |
| `OK` | Backup | Recent complete RMAN backup coverage | jobs_7d=1, no_backup_files=0 | Continue scheduled restore preview/validate drills and retain off-host copies. |
| `OK` | Backup | No recent failed RMAN jobs | failed_jobs_7d=0 | Continue monitoring failed backup jobs and alerting. |
| `OK` | Health | No media recovery or block corruption rows | recover_file=0, block_corruption=0 | Keep periodic validation and corruption monitoring. |
| `OK` | Recovery | Flashback Database enabled | FLASHBACK_ON=YES | Use guaranteed restore points deliberately for risky changes and validate retention. |
| `GAP` | Disaster recovery | Data Guard topology detected | role=PRIMARY, standby_dests=0 | Gold or higher MAA posture needs Data Guard/Active Data Guard or equivalent DR architecture. |
| `INFO` | Disaster recovery | Fast-Start Failover evidence | FSFO=DISABLED, observer=UNKNOWN | For strict RTO/RPO, evaluate FSFO with appropriate protection mode and observer design. |
| `OK` | Local HA | RAC/RAC One/local standby candidate | cluster=RAC, cluster_database=TRUE, parallel=YES, standby_scope=unknown | Validate service placement, FAN/ONS, Application Continuity, and measured local-failure drills before claiming Silver evidenced. |
| `INFO` | Application continuity | AC-style service metadata | services=0 | For Silver/Platinum readiness, review services, drivers, FAN/ONS, TAC/AC, and request boundaries. |
| `INFO` | File redundancy | FEX control-file posture | control_files=1, redo_min_members=2, storage=FEX, control_file=UNKNOWN | OCI FEX exposes provider-managed @... file handles and may not expose a host byte-copy path for manual control-file multiplexing. Validate control-file autobackups, fresh baseline backups, provider storage redundancy, and use a provider-approved offline byte-copy or CREATE CONTROLFILE runbook before attempting active multiplexing. |
| `OK` | Security | TDE wallet open for encrypted data | wallet_open=3, encrypted_tbs=8 | Keep wallet backups synchronized across RAC/Data Guard sites. |

## Application Continuity, TAC, FSFO, DML Redirection, And Services Review

| Area | Evidence |
| --- | --- |
| SQL service dictionary | Source `DBA_SERVICES`, services `4`, application services `2`, PDB services `2` |
| Application Continuity / TAC | AC `0`, TAC `0`, Commit Outcome `0`, missing AC/TAC `0` |
| Client HA service attributes | FAN/AQ `0`, RLB goals `2`, drain timeout `0`, session state consistency `0`, failover restore `0` |
| Data Guard / FSFO | DG detected `0`, FSFO status `DISABLED`, FSFO target `NONE`, observer `UNKNOWN`, threshold `0` |
| FSFO observer best-practice evidence | DGMGRL `YES/OK` from `/u02/app/oracle/product/23.0.0.0/dbhome_1/bin/dgmgrl`, active observer `UNKNOWN`, observer count `0`, observers `NONE`, PreferredObserverHosts `NO` |
| Active Data Guard DML redirection | adg_redirect_dml `FALSE`, ADG standby context `0` |
| srvctl service metadata | srvctl `NO`, status `UNAVAILABLE`, services `UNAVAILABLE`, role-based `UNAVAILABLE`, primary-role `UNAVAILABLE`, standby-role `UNAVAILABLE`, automatic `UNAVAILABLE` |

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

## SLA / RTO / RPO Planning Context

| Requirement | Supplied value |
| --- | --- |
| Application | `not supplied` |
| Local unplanned RTO | `not supplied` |
| Local unplanned RPO | `not supplied` |
| Disaster/site RTO | `not supplied` |
| Disaster/site RPO | `not supplied` |
| Planned maintenance RTO | `not supplied` |
| Planned maintenance RPO | `not supplied` |
| Criticality | `not supplied` |
| Local HA target | `not supplied` |
| DR required | `not supplied` |
| Automatic failover required | `not supplied` |
| Active-active required | `not supplied` |
| Platform hint | `not supplied` |
| Standby scope | `unknown` |

Preliminary recommendation hint: No SLA objectives supplied yet. Provide CRASHSIM_MAA_* values or --maa-* options in a future run to compare target objectives against detected posture.

## Suggested CrashSimulator Validation Coverage

| Objective | Suggested drills |
| --- | --- |
| Bronze backup/restart readiness | Health check, config report, scenarios `5`, `6`, `25`, `26`, `59`, and timed restore-preview/validate runs. |
| Silver local HA readiness | Service/instance relocation or restart drills such as `55` and `56`, plus client FAN/ONS/Application Continuity validation. |
| Gold DR readiness | Data Guard transport/apply, switchover/failover, FSFO, archive gap, and standby recovery drills such as `50`, `51`, `52`, `59`. |
| Platinum/Diamond application continuity | GoldenGate/active-active or sharding failover, conflict handling, zero-downtime planned maintenance, and application transaction replay tests. |

## References

- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html
- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html
- User RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery
- FSFO observer placement reference: https://www.ludovicocaldara.net/blog/video-where-should-i-put-the-observer-in-a-fast-start-failover-configuration/

## Raw MAA Evidence

Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260615_082449.evidence`

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
CSIM_MAA|fra_used_pct|4.03
CSIM_MAA|fra_reclaimable_pct|.17
CSIM_MAA|recent_successful_backup_jobs_7d|1
CSIM_MAA|recent_failed_backup_jobs_7d|0
CSIM_MAA|last_successful_backup_time|2026-06-15 07:41:02
CSIM_MAA|last_successful_backup_age_hours|.7
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

## Data Guard Broker Evidence

File: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260615_082449_dgmgrl_fsfo.out`

```text
Connected to "crashrac"
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
ORA-16525: The Oracle Data Guard broker is not yet available.

Configuration details cannot be determined by DGMGRL
```
