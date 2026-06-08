# CrashSimulator Oracle MAA Readiness Report

- Generated UTC: `2026-06-08T12:40:33Z`
- Host: `crashrac1-xnvfw`
- OS user: `oracle`
- Application context: `not supplied`
- Database: `CRASHDB`
- DB unique name: `crashrdb`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Cluster type: `RAC`
- Storage type: `FEX`
- Detected MAA posture: `Gold`
- Readiness status: `Baseline checks passed`
- Raw SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260608_124030.evidence`
- Data Guard Broker FSFO evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260608_124030_dgmgrl_fsfo.out`

This report is a best-effort posture assessment, not an Oracle certification. It maps observable database, Grid Infrastructure, backup, Data Guard, and security evidence to the MAA reference architecture model and highlights gaps that should be validated with timed drills.


## Detected MAA Level

| Field | Value |
| --- | --- |
| Detected posture | `Gold` |
| Basis | Data Guard standby role or remote standby transport destination was detected. |
| Baseline readiness | `Baseline checks passed` |
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
| Local HA | Cluster `RAC`, cluster_database `TRUE`, instance parallel `YES`, GI managed `1`, storage `FEX` |
| Backup | Recent successful jobs 7d `18`, failed jobs 7d `0`, last success `2026-06-08 12:33:28`, datafiles without backup metadata `0`, devices `SBT_TAPE` |
| Data Guard | Remote standby destinations `1`, valid destinations `1`, FSFO `TARGET UNDER LAG LIMIT`, observer `YES`, transport lag `UNKNOWN`, apply lag `UNKNOWN` |
| Storage/config | Control files `1`, redo min members `2`, redo groups with <2 members `0`, FRA configured `YES`, FRA used `8.07%` |
| Security | Wallet open rows `3`, wallet not-open rows `0`, encrypted tablespaces `8`, TDE config `keystore_configuration=FILE` |
| Application continuity / services | Replay-capable services `0`, AC `0`, TAC `0`, missing AC/TAC `0`, role-based srvctl services `2` |
| ADG DML redirection | adg_redirect_dml `FALSE`, modifiable `IMMEDIATE` |
| Replication dictionary | capture processes `0`, apply processes `0` |

## Best-Practice Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Recoverability | ARCHIVELOG enabled | LOG_MODE=ARCHIVELOG | Keep validating archived-log backup, restore, and gap handling. |
| `OK` | Data protection | FORCE LOGGING enabled | FORCE_LOGGING=YES | Keep FORCE LOGGING enabled for Data Guard/readiness unless an exception is explicitly approved. |
| `OK` | Backup | Recent complete RMAN backup coverage | jobs_7d=18, no_backup_files=0 | Continue scheduled restore preview/validate drills and retain off-host copies. |
| `OK` | Backup | No recent failed RMAN jobs | failed_jobs_7d=0 | Continue monitoring failed backup jobs and alerting. |
| `OK` | Health | No media recovery or block corruption rows | recover_file=0, block_corruption=0 | Keep periodic validation and corruption monitoring. |
| `OK` | Recovery | Flashback Database enabled | FLASHBACK_ON=YES | Use guaranteed restore points deliberately for risky changes and validate retention. |
| `OK` | Disaster recovery | Data Guard topology detected | role=PRIMARY, standby_dests=1, valid=1 | Validate switchover/failover, FSFO, transport/apply lag, and application reconnection. |
| `OK` | Disaster recovery | Fast-Start Failover evidence | FSFO=TARGET UNDER LAG LIMIT, observer=YES | Keep testing observer placement and failover/failback runbooks. |
| `OK` | Local HA | RAC/RAC One Node evidence | cluster=RAC, cluster_database=TRUE, parallel=YES | Validate service placement, FAN/ONS, Application Continuity, and rolling maintenance drills. |
| `INFO` | Application continuity | AC-style service metadata | services=0 | For Silver/Platinum readiness, review services, drivers, FAN/ONS, TAC/AC, and request boundaries. |
| `WARN` | File redundancy | Control file and redo multiplexing | control_files=1, redo_min_members=2, redo_under2=0 | Multiplex control files and redo members across independent storage failure domains. |
| `OK` | Security | TDE wallet open for encrypted data | wallet_open=3, encrypted_tbs=8 | Keep wallet backups synchronized across RAC/Data Guard sites. |

## Application Continuity, TAC, FSFO, DML Redirection, And Services Review

| Area | Evidence |
| --- | --- |
| SQL service dictionary | Source `DBA_SERVICES`, services `5`, application services `3`, PDB services `3` |
| Application Continuity / TAC | AC `0`, TAC `0`, Commit Outcome `0`, missing AC/TAC `0` |
| Client HA service attributes | FAN/AQ `0`, RLB goals `3`, drain timeout `0`, session state consistency `0`, failover restore `0` |
| Data Guard / FSFO | DG detected `1`, FSFO status `TARGET UNDER LAG LIMIT`, FSFO target `crashdr`, observer `YES`, threshold `30` |
| FSFO observer best-practice evidence | DGMGRL `YES/OK` from `/u02/app/oracle/product/23.0.0.0/dbhome_1/bin/dgmgrl`, active observer `crashsim_bastion_observer`, observer count `1`, observers `crashsim_bastion_observer`, PreferredObserverHosts `NO` |
| Active Data Guard DML redirection | adg_redirect_dml `FALSE`, ADG standby context `0` |
| srvctl service metadata | srvctl `YES`, status `OK`, services `2`, role-based `2`, primary-role `1`, standby-role `1`, automatic `2` |

## Service Best-Practice Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Services | Application services visible | application_services=3 | Keep services workload-specific so HA, DR, and maintenance policies can differ by application. |
| `INFO` | AC/TAC | Replay-capable services | ac_services=0, tac_services=0 | For user-facing services, evaluate TAC or AC with FAN/ONS and compatible drivers before HA drills. |
| `INFO` | AC/TAC | Commit Outcome / Transaction Guard | commit_outcome_services=0 | Enable Commit Outcome for AC/TAC candidate services where the application is replay-safe. |
| `WARN` | Client HA | FAN/AQ notification services | fan_services=0 | Enable HA notifications for application services and validate client-side failover behavior. |
| `OK` | Client HA | Runtime/client load balancing goals | rlb_services=3 | Validate service-time or throughput goals with connection pools and service relocation. |
| `INFO` | Planned maintenance | Service drain timeout | drain_timeout_services=0 | Set drain timeout for services that need graceful planned maintenance. |
| `INFO` | AC/TAC | Session state consistency | session_state_services=0 | Review session-state consistency before enabling AC/TAC for stateful applications. |
| `INFO` | AC/TAC | Failover restore | failover_restore_services=0 | For TAC/AC candidates, review failover restore behavior with the application team. |
| `OK` | Data Guard services | Role-based services | role_based_services=2, primary=1, standby=1 | Keep primary write services and ADG read-only services role-scoped; validate after switchover and failover. |
| `OK` | FSFO | Fast-Start Failover awareness | fsfo=TARGET UNDER LAG LIMIT, observer=YES, threshold=30 | Validate observer location, failover threshold, target, reinstate/failback runbook, and application service movement. |
| `OK` | FSFO observer | Active observer present | observer_present=YES, active=crashsim_bastion_observer, count=1 | Keep the active observer on an external site when possible; if no external site exists, run it with the primary site and keep a secondary-site observer ready after role transition. |
| `WARN` | FSFO observer | Multiple observers configured | observer_count=1, observers=crashsim_bastion_observer | Configure at least two observers when possible so observer availability does not become a single operational dependency. |
| `WARN` | FSFO observer | PreferredObserverHosts configured | preferred_hosts=EMPTY, dgmgrl=YES/OK | Configure PreferredObserverHosts on Data Guard members so the active observer is not placed with the standby database after role transitions. |
| `WARN` | FSFO observer | Observer site placement | active=crashsim_bastion_observer, preferred_hosts_configured=NO | CrashSimulator cannot prove external/primary/standby site placement without PreferredObserverHosts or site metadata; never intentionally place the active observer with the standby database. |
| `INFO` | ADG DML redirection | DML redirection configuration | role=PRIMARY, open_mode=READ WRITE, adg_redirect_dml=FALSE | Run this review on an ADG standby to confirm DML redirection posture for standby read services. |

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

Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260608_124030.evidence`

```text
CSIM_MAA|db_name|CRASHDB
CSIM_MAA|db_unique_name|crashrdb
CSIM_MAA|db_role|PRIMARY
CSIM_MAA|open_mode|READ WRITE
CSIM_MAA|cdb|YES
CSIM_MAA|log_mode|ARCHIVELOG
CSIM_MAA|force_logging|YES
CSIM_MAA|flashback_on|YES
CSIM_MAA|protection_mode|MAXIMUM PERFORMANCE
CSIM_MAA|protection_level|MAXIMUM PERFORMANCE
CSIM_MAA|switchover_status|TO STANDBY
CSIM_MAA|fsfo_status|TARGET UNDER LAG LIMIT
CSIM_MAA|fsfo_target|crashdr
CSIM_MAA|fsfo_threshold|30
CSIM_MAA|fsfo_observer_present|YES
CSIM_MAA|dbid|1275206961
CSIM_MAA|platform_name|Linux x86 64-bit
CSIM_MAA|instance_name|crashdb1
CSIM_MAA|host_name|crashrac1-xnvfw
CSIM_MAA|version|23.0.0.0.0
CSIM_MAA|version_major|23
CSIM_MAA|instance_status|OPEN
CSIM_MAA|instance_parallel|YES
CSIM_MAA|instance_thread|1
CSIM_MAA|cluster_database|TRUE
CSIM_MAA|remote_login_passwordfile|EXCLUSIVE
CSIM_MAA|db_recovery_file_dest|@rJOnB8bM(RECO_HC_HIGHREDUNDANCY)
CSIM_MAA|db_recovery_file_dest_size|240G
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
CSIM_MAA|fra_used_pct|8.07
CSIM_MAA|fra_reclaimable_pct|1.26
CSIM_MAA|recent_successful_backup_jobs_7d|18
CSIM_MAA|recent_failed_backup_jobs_7d|0
CSIM_MAA|last_successful_backup_time|2026-06-08 12:33:28
CSIM_MAA|last_successful_backup_age_hours|.1
CSIM_MAA|backup_device_types|SBT_TAPE
CSIM_MAA|datafiles_without_backup_metadata|0
CSIM_MAA|remote_standby_dest_count|1
CSIM_MAA|valid_remote_standby_dest_count|1
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
CSIM_MAA|service_total_count|5
CSIM_MAA|service_user_count|3
CSIM_MAA|ac_service_count|0
CSIM_MAA|tac_service_count|0
CSIM_MAA|application_continuity_service_count|0
CSIM_MAA|service_without_ac_tac_count|0
CSIM_MAA|commit_outcome_service_count|0
CSIM_MAA|fan_notification_service_count|0
CSIM_MAA|runtime_load_balancing_service_count|3
CSIM_MAA|drain_timeout_service_count|0
CSIM_MAA|session_state_consistency_service_count|0
CSIM_MAA|failover_restore_service_count|0
CSIM_MAA|pdb_service_count|3
CSIM_MAA|capture_process_count|0
CSIM_MAA|apply_process_count|0
```

## Data Guard Broker Evidence

File: `/tmp/crashsimulator/crashsimulator_logs/crashsim_maa_report_20260608_124030_dgmgrl_fsfo.out`

```text
Connected to "crashrdb"

Configuration - crashdb_dgconf

  Protection Mode: MaxPerformance
  Members:
  crashrdb - Primary database
    crashdr  - (*) Physical standby database

  (*) Fast-Start Failover target

  Properties:
    BystandersFollowRoleChange      = 'ALL'
    CommunicationTimeout            = '180'
    ConfigurationSimpleName         = 'crashdb_dgconf'
    ConfigurationWideServiceName    = 'crashdb_CFG'
    DrainTimeout                    = '0'
    ExternalDestination1            = ''
    ExternalDestination2            = ''
    FastStartFailoverAutoReinstate  = 'TRUE'
    FastStartFailoverLagGraceTime   = '0'
    FastStartFailoverLagLimit       = '30'
    FastStartFailoverLagType        = 'APPLY'
    FastStartFailoverPmyShutdown    = 'TRUE'
    FastStartFailoverThreshold      = '30'
    ObserverOverride                = 'FALSE'
    ObserverPingInterval            = '0'
    ObserverPingRetry               = '0'
    ObserverReconnect               = '0'
    OperationTimeout                = '30'
    PrimaryDatabaseCandidates       = ''
    PrimaryLostWriteAction          = 'CONTINUE'
    TraceLevel                      = 'USER'

Fast-Start Failover: Enabled in Potential Data Loss Mode
  Lag Limit:          30 seconds
  Lag Type:           APPLY
  Threshold:          30 seconds
  Ping Interval:      3000 milliseconds
  Ping Retry:         0
  Active Target:      crashdr
  Potential Targets:  "crashdr"
    crashdr    valid
  Observer:           crashsim_bastion_observer
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
  Observer Reconnect: (none)
  Observer Override:  FALSE
  Lag Grace Time:     0 seconds

Configuration Status:
SUCCESS   (status updated 20 seconds ago)


Fast-Start Failover: Enabled in Potential Data Loss Mode

  Protection Mode:    MaxPerformance
  Lag Limit:          30 seconds
  Lag Type:           APPLY

  Threshold:          30 seconds
  Ping Interval:      3000 milliseconds
  Ping Retry:         0
  Active Target:      crashdr
  Potential Targets:  "crashdr"
    crashdr    valid
  Observer:           crashsim_bastion_observer
  Shutdown Primary:   TRUE
  Auto-reinstate:     TRUE
  Observer Reconnect: (none)
  Observer Override:  FALSE
  Lag Grace Time:     0 seconds

Configurable Failover Conditions
  Health Conditions:
    Corrupted Controlfile          YES
    Corrupted Dictionary           YES
    Inaccessible Logfile            NO
    Stuck Archiver                  NO
    Datafile Write Errors          YES

  Oracle Error Conditions:
    (none)


Database - crashrdb

  Role:                PRIMARY
  Intended State:      TRANSPORT-ON
  Redo Rate:           365 Byte/s  in 15 seconds (computed 9 seconds ago)
  Instance(s):
    crashdb1
    crashdb2

  Properties:
    AlternateLocation               = ''
    ApplyInstanceTimeout            = '0'
    ApplyInstances                  = '0'
    ApplyLagThreshold               = '30'
    ApplyParallel                   = 'AUTO'
    ArchiveLocation                 = ''
    Binding                         = 'OPTIONAL'
    DGConnectIdentifier             = 'crashrdb'
    DelayMins                       = '0'
    FastStartFailoverTarget         = 'crashdr'
    InconsistentLogXptProps         = '(monitor)'
    LogShipping                     = 'ON'
    LogXptMode                      = 'ASYNC'
    LogXptStatus                    = '(monitor)'
    MaxFailure                      = '0'
    NetTimeout                      = '30'
    ObserverConnectIdentifier       = ''
    PreferredApplyInstance          = ''
    PreferredObserverHosts          = ''
    RecvQEntries                    = '(monitor)'
    RedoCompression                 = 'DISABLE'
    RedoRoutes                      = ''
    ReopenSecs                      = '300'
    SendQEntries                    = '(monitor)'
    SidName(*)
    StandbyAlternateLocation        = ''
    StandbyArchiveLocation          = ''
    StaticConnectIdentifier(*)
    TopWaitEvents(*)
    TransportDisconnectedThreshold  = '30'
    TransportLagThreshold           = '30'
    UserManagedParams               = ''
    (*) - Please check specific instance for the property value

  Log file locations(*):
    (*) - Check specific instance for log file locations.

Database Status:
SUCCESS


Database - crashdr

  Role:                PHYSICAL STANDBY
  Intended State:      APPLY-ON
  Transport Lag:       0 seconds (computed 1 second ago)
  Apply Lag:           3 seconds (computed 1 second ago)
  Average Apply Rate:  119.00 KByte/s
  Active Apply Rate:   1.19 MByte/s
  Maximum Apply Rate:  9.96 MByte/s
  Real Time Query:     ON
  Instance(s):
    crashdb1 (apply instance)
    crashdb2

  Properties:
    AlternateLocation               = ''
    ApplyInstanceTimeout            = '0'
    ApplyInstances                  = '0'
    ApplyLagThreshold               = '30'
    ApplyParallel                   = 'AUTO'
    ArchiveLocation                 = ''
    Binding                         = 'OPTIONAL'
    DGConnectIdentifier             = 'crashdr'
    DelayMins                       = '0'
    FastStartFailoverTarget         = 'crashrdb'
    InconsistentLogXptProps         = '(monitor)'
    LogShipping                     = 'ON'
    LogXptMode                      = 'ASYNC'
    LogXptStatus                    = '(monitor)'
    MaxFailure                      = '0'
    NetTimeout                      = '30'
    ObserverConnectIdentifier       = ''
    PreferredApplyInstance          = ''
    PreferredObserverHosts          = ''
    RecvQEntries                    = '(monitor)'
    RedoCompression                 = 'DISABLE'
    RedoRoutes                      = ''
    ReopenSecs                      = '300'
    SendQEntries                    = '(monitor)'
    SidName(*)
    StandbyAlternateLocation        = ''
    StandbyArchiveLocation          = ''
    StaticConnectIdentifier(*)
    TopWaitEvents(*)
    TransportDisconnectedThreshold  = '30'
    TransportLagThreshold           = '30'
    UserManagedParams               = ''
    (*) - Please check specific instance for the property value

  Log file locations(*):
    (*) - Check specific instance for log file locations.

Database Status:
SUCCESS

```

## srvctl Database And Service Evidence

Command: bash -lc srvctl\ config\ database\ -d\ \'crashrdb\'\ 2\>\&1\;\ srvctl\ status\ database\ -d\ \'crashrdb\'\ 2\>\&1\;\ srvctl\ config\ service\ -d\ \'crashrdb\'\ 2\>\&1\;\ srvctl\ status\ service\ -d\ \'crashrdb\'\ 2\>\&1

```text
Database unique name: crashrdb
Database name: crashdb
Oracle home: /u02/app/oracle/product/23.0.0.0/dbhome_1
Oracle user: oracle
Spfile: @rJOnB8bM/CREASHRAC-A4FEA717C5C96F3BFFC46A6348A21A9F/CRASHRDB/PARAMETERFILE/spfile.OMF.37A52C57
Password file: @rJOnB8bM/CREASHRAC-A4FEA717C5C96F3BFFC46A6348A21A9F/CRASHRDB/PASSWORD/pwdCRASHRDB.4B81E94C
Domain: clientsubnet.dns.oraclevcn.com
Start options: open
Stop options: immediate
Database role: PRIMARY
Management policy: AUTOMATIC
Server pools:
Disk Groups:
Mount point paths: /var/opt/oracle/dbaas_acfs
Services: crashdb_CRASHPDB.paas.oracle.com,crashdb_CRASHPDB_ro.paas.oracle.com
Type: RAC
Start concurrency:
Stop concurrency:
OSDBA group: dba
OSOPER group: racoper
Database instances: crashdb1,crashdb2
Configured nodes: crashrac1-xnvfw,crashrac2-picqh
CSS critical: no
CPU count: 0
Memory target: 0
Maximum memory: 0
Default network number for database services:
Database is administrator managed
Instance crashdb1 is running on node crashrac1-xnvfw
Instance crashdb2 is running on node crashrac2-picqh
Service name: crashdb_CRASHPDB.paas.oracle.com
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
Pluggable database name: CRASHPDB
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

Service name: crashdb_CRASHPDB_ro.paas.oracle.com
Cardinality: 2
Service role: PHYSICAL_STANDBY
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
Pluggable database name: CRASHPDB
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
Service crashdb_CRASHPDB.paas.oracle.com is running on instances crashdb1,crashdb2
Service crashdb_CRASHPDB_ro.paas.oracle.com is not running.
```
