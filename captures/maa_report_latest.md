# CrashSimulator Oracle MAA Readiness Report

- Generated UTC: `2026-06-05T07:00:39Z`
- Host: `crashrac1-ynkfr`
- OS user: `oracle`
- Application context: `CrashSimulatorLab`
- Database: `CRASHDB`
- DB unique name: `crashdb`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Cluster type: `RAC`
- Storage type: `ASM`
- Detected MAA posture: `Silver`
- Readiness status: `Baseline gaps detected`
- Raw SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260605_070037.evidence`

This report is a best-effort posture assessment, not an Oracle certification. It maps observable database, Grid Infrastructure, backup, Data Guard, and security evidence to the MAA reference architecture model and highlights gaps that should be validated with timed drills.


## Detected MAA Level

| Field | Value |
| --- | --- |
| Detected posture | `Silver` |
| Basis | RAC or RAC One Node style topology was detected. |
| Baseline readiness | `Baseline gaps detected` |
| Detection confidence | Medium: based on target-host SQL/GI evidence; application failover behavior and external schedulers require confirmation. |

## MAA Reference Model Used

| MAA level | Observable capabilities used by this report |
| --- | --- |
| Bronze | Single-instance or Oracle Restart style database with ARCHIVELOG, RMAN backup/recovery evidence, corruption checks, and basic restart/restore readiness. |
| Silver | Bronze plus RAC or RAC One Node style local HA; Application Continuity evidence is checked when dictionary columns are available. |
| Gold | Silver/Bronze plus Data Guard or Active Data Guard evidence for disaster recovery and low/zero data-loss posture. |
| Platinum | Gold plus GoldenGate/advanced replication or sharding-style evidence for near-zero or zero application outage patterns. |
| Diamond | Next-generation 26ai-or-later/Exadata/GoldenGate active-active pattern; this report can only flag partial evidence and requires manual confirmation. |

## Evidence Summary

| Area | Evidence |
| --- | --- |
| Database | Role `PRIMARY`, open mode `READ WRITE`, log mode `ARCHIVELOG`, force logging `YES`, flashback `YES` |
| Local HA | Cluster `RAC`, cluster_database `TRUE`, instance parallel `YES`, GI managed `1`, storage `ASM` |
| Backup | Recent successful jobs 7d `19`, failed jobs 7d `1`, last success `2026-06-05 06:49:17`, datafiles without backup metadata `4`, devices `SBT_TAPE,UNKNOWN` |
| Data Guard | Remote standby destinations `0`, valid destinations `0`, FSFO `DISABLED`, observer `UNKNOWN`, transport lag `UNKNOWN`, apply lag `UNKNOWN` |
| Storage/config | Control files `3`, redo min members `2`, redo groups with <2 members `0`, FRA configured `YES`, FRA used `37.68%` |
| Security | Wallet open rows `3`, wallet not-open rows `0`, encrypted tablespaces `8`, TDE config `keystore_configuration=FILE` |
| Application continuity / replication | AC-style services `0`, capture processes `0`, apply processes `0` |

## Best-Practice Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Recoverability | ARCHIVELOG enabled | LOG_MODE=ARCHIVELOG | Keep validating archived-log backup, restore, and gap handling. |
| `OK` | Data protection | FORCE LOGGING enabled | FORCE_LOGGING=YES | Keep FORCE LOGGING enabled for Data Guard/readiness unless an exception is explicitly approved. |
| `GAP` | Backup | Recent complete RMAN backup coverage | jobs_7d=19, no_backup_files=4 | Fix backup coverage before destructive drills; run RMAN backup, preview, and validate. |
| `WARN` | Backup | No recent failed RMAN jobs | failed_jobs_7d=1 | Review failed RMAN jobs and confirm they do not represent missing required backup windows. |
| `OK` | Health | No media recovery or block corruption rows | recover_file=0, block_corruption=0 | Keep periodic validation and corruption monitoring. |
| `OK` | Recovery | Flashback Database enabled | FLASHBACK_ON=YES | Use guaranteed restore points deliberately for risky changes and validate retention. |
| `GAP` | Disaster recovery | Data Guard topology detected | role=PRIMARY, standby_dests=0 | Gold or higher MAA posture needs Data Guard/Active Data Guard or equivalent DR architecture. |
| `INFO` | Disaster recovery | Fast-Start Failover evidence | FSFO=DISABLED, observer=UNKNOWN | For strict RTO/RPO, evaluate FSFO with appropriate protection mode and observer design. |
| `OK` | Local HA | RAC/RAC One Node evidence | cluster=RAC, cluster_database=TRUE, parallel=YES | Validate service placement, FAN/ONS, Application Continuity, and rolling maintenance drills. |
| `INFO` | Application continuity | AC-style service metadata | services=0 | For Silver/Platinum readiness, review services, drivers, FAN/ONS, TAC/AC, and request boundaries. |
| `OK` | File redundancy | Control file and redo multiplexing | control_files=3, redo_min_members=2 | Keep members separated across failure domains where possible. |
| `OK` | Security | TDE wallet open for encrypted data | wallet_open=3, encrypted_tbs=8 | Keep wallet backups synchronized across RAC/Data Guard sites. |

## SLA / RTO / RPO Planning Context

| Requirement | Supplied value |
| --- | --- |
| Application | `CrashSimulatorLab` |
| Local unplanned RTO | `less than 1 minute` |
| Local unplanned RPO | `zero` |
| Disaster/site RTO | `less than 1 hour` |
| Disaster/site RPO | `zero` |
| Planned maintenance RTO | `near zero` |
| Planned maintenance RPO | `not supplied` |

Preliminary recommendation hint: Supplied objectives appear very aggressive. Expect at least Gold for site protection, and Platinum/Diamond patterns when application-visible downtime must approach zero.

## Suggested CrashSimulator Validation Coverage

| Objective | Suggested drills |
| --- | --- |
| Bronze backup/restart readiness | Health check, config report, scenarios `5`, `6`, `25`, `26`, `59`, `61`, `62`, `63`, `64`, `65`, and timed restore-preview/validate runs. |
| Silver local HA readiness | Service/instance/VIP relocation or restart drills such as `55`, `56`, `70`, and `71`, plus client FAN/ONS/Application Continuity validation. |
| Gold DR readiness | Data Guard transport/apply, switchover/failover, FSFO, archive gap, standby redo log, and standby recovery drills such as `50`, `51`, `52`, `59`, `66`, `67`, `68`, and `69`. |
| Platinum/Diamond application continuity | GoldenGate/active-active or sharding failover, conflict handling, zero-downtime planned maintenance, and application transaction replay tests. |

## References

- Oracle MAA Reference Architectures Overview: https://docs.oracle.com/en/database/oracle/oracle-database/26/haiad/maa_overview.html
- Oracle HA requirements, RTO/RPO, and MAA architecture mapping: https://docs.oracle.com/en/database/oracle/oracle-database/19/haovw/ha-requirements-architecture.html
- User RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery

## Raw MAA Evidence

Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260605_070037.evidence`

```text
CSIM_MAA|db_name|CRASHDB
CSIM_MAA|db_unique_name|crashdb
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
CSIM_MAA|dbid|1274936449
CSIM_MAA|platform_name|Linux x86 64-bit
CSIM_MAA|instance_name|crashdb1
CSIM_MAA|host_name|crashrac1-ynkfr
CSIM_MAA|version|19.0.0.0.0
CSIM_MAA|version_major|19
CSIM_MAA|instance_status|OPEN
CSIM_MAA|instance_parallel|YES
CSIM_MAA|instance_thread|1
CSIM_MAA|cluster_database|TRUE
CSIM_MAA|remote_login_passwordfile|EXCLUSIVE
CSIM_MAA|db_recovery_file_dest|+RECOcrashdb
CSIM_MAA|db_recovery_file_dest_size|44G
CSIM_MAA|local_undo_enabled|UNKNOWN
CSIM_MAA|wallet_root|/var/opt/oracle/dbaas_acfs/crashdb/wallet_root
CSIM_MAA|tde_configuration|keystore_configuration=FILE
CSIM_MAA|archive_lag_target|0
CSIM_MAA|control_file_count|3
CSIM_MAA|redo_group_count|8
CSIM_MAA|redo_min_members|2
CSIM_MAA|redo_groups_less_than_two_members|0
CSIM_MAA|recover_file_count|0
CSIM_MAA|block_corruption_count|0
CSIM_MAA|copy_corruption_count|0
CSIM_MAA|backup_corruption_count|0
CSIM_MAA|guaranteed_restore_point_count|0
CSIM_MAA|fra_configured|YES
CSIM_MAA|fra_used_pct|37.68
CSIM_MAA|fra_reclaimable_pct|1.41
CSIM_MAA|recent_successful_backup_jobs_7d|19
CSIM_MAA|recent_failed_backup_jobs_7d|1
CSIM_MAA|last_successful_backup_time|2026-06-05 06:49:17
CSIM_MAA|last_successful_backup_age_hours|.2
CSIM_MAA|backup_device_types|SBT_TAPE,UNKNOWN
CSIM_MAA|datafiles_without_backup_metadata|4
CSIM_MAA|remote_standby_dest_count|0
CSIM_MAA|valid_remote_standby_dest_count|0
CSIM_MAA|standby_dest_error_count|0
CSIM_MAA|archive_gap_count|0
CSIM_MAA|dataguard_stats_count|0
CSIM_MAA|dataguard_transport_lag|UNKNOWN
CSIM_MAA|dataguard_apply_lag|UNKNOWN
CSIM_MAA|tde_wallet_open_count|3
CSIM_MAA|tde_wallet_not_open_count|0
