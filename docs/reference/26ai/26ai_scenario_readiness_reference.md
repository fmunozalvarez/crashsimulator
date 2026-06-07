# CrashSimulator Scenario Readiness Report

- Generated UTC: `2026-06-07T07:44:08Z`
- Tool version: `2.0.0-dev`
- Log directory: `/tmp/crashsimulator/crashsimulator_logs`
- Target PDB context: `CRASHDB_PDB1`
- Target schema context: `not set`
- Target FILE# context: `not set`

This report validates the discovered target environment against the CrashSimulator scenario registry. The same requirement checks, topology gates, target selection, and execution guardrails are used by scenario execution, so unavailable scenarios are blocked before destructive code runs.

## Current Topology

| Signal | Value |
| --- | --- |
| Host | crashdb26ai1 |
| OS user | oracle |
| Oracle home | /u01/app/oracle/product/23.0.0.0/dbhome_1 |
| SQL*Plus | /u01/app/oracle/product/23.0.0.0/dbhome_1/bin/sqlplus |
| Database name | CRASHDB |
| DB unique name | crashdb_26ai |
| Database role | PRIMARY |
| Open mode | READ WRITE |
| CDB | YES |
| Instance | crashdb1 |
| Thread | 1 |
| RAC parallel | YES |
| Cluster type | RAC |
| GI managed | 1 |
| Storage type | ASM |
| Protection mode | MAXIMUM PERFORMANCE |
| Switchover status | NOT ALLOWED |
| SPFILE | +DATA/CRASHDB_26AI/PARAMETERFILE/spfile.266.1235269757 |
| Password file | +DATA/CRASHDB_26AI/PASSWORD/pwdcrashdb_26ai.262.1235269335 |
| FRA | +RECO |

## PDBs

| PDB | CON_ID | Open mode |
| --- | --- | --- |
| CRASHDB_PDB1 | 3 | READ WRITE |

## Readiness Summary

| Status | Count | Meaning |
| --- | ---: | --- |
| RUNNABLE | 44 | Scenario can be selected for dry-run and, when requested, execution. |
| PLAN-ONLY | 27 | Scenario can produce useful dry-run/runbook evidence, but execution is blocked by a guardrail or provider-specific limitation. |
| NOT-RUNNABLE | 11 | Scenario is not available in the current topology or target context. |
| TOTAL | 82 | Registered scenarios evaluated. |

## Runnable Scenarios

| ID | Group | Scope | Impact | Scenario | Reason |
| --- | --- | --- | --- | --- | --- |
| `5` | Core | CDB/non-CDB | destructive | Loss of one non-system datafile | Requirements passed and target selection produced executable actions. |
| `6` | Core | CDB/non-CDB | destructive | Loss of one temporary file | Requirements passed and target selection produced executable actions. |
| `7` | Core | CDB/non-CDB | destructive | Loss of one SYSTEM datafile | Requirements passed and target selection produced executable actions. |
| `8` | Core | CDB/non-CDB | destructive | Loss of one UNDO datafile | Requirements passed and target selection produced executable actions. |
| `9` | Core | CDB/non-CDB | destructive | Loss of a read-only tablespace | Requirements passed and target selection produced executable actions. |
| `10` | Core | CDB/non-CDB | destructive | Loss of an index-only tablespace | Requirements passed and target selection produced executable actions. |
| `11` | Logical | CDB/non-CDB | logical | Drop non-unique indexes outside Oracle schemas | Requirements passed and target selection produced executable actions. |
| `12` | Core | CDB/non-CDB | destructive | Loss of a non-system tablespace | Requirements passed and target selection produced executable actions. |
| `13` | Core | CDB/non-CDB | destructive | Loss of a temporary tablespace | Requirements passed and target selection produced executable actions. |
| `14` | Core | CDB/non-CDB | destructive | Loss of SYSTEM tablespace | Requirements passed and target selection produced executable actions. |
| `15` | Core | CDB/non-CDB | destructive | Loss of UNDO tablespace | Requirements passed and target selection produced executable actions. |
| `17` | Core | CDB/non-CDB | destructive | Loss of all datafiles | Requirements passed and target selection produced executable actions. |
| `22` | Corrupt | CDB/non-CDB | destructive | Datafile header corruption | Requirements passed and target selection produced executable actions. |
| `27` | Config | CDB/non-CDB | destructive | Loss of SQL*Net config files | Requirements passed and target selection produced executable actions. |
| `30` | PDB | PDB | destructive | PDB loss of one non-system datafile | Requirements passed and target selection produced executable actions. |
| `31` | PDB | PDB | destructive | PDB loss of one temporary file | Requirements passed and target selection produced executable actions. |
| `32` | PDB | PDB | destructive | PDB loss of one SYSTEM datafile | Requirements passed and target selection produced executable actions. |
| `33` | PDB | PDB | destructive | PDB loss of one UNDO datafile | Requirements passed and target selection produced executable actions. |
| `34` | PDB | PDB | destructive | PDB loss of read-only tablespace | Requirements passed and target selection produced executable actions. |
| `35` | PDB | PDB | destructive | PDB loss of index-only tablespace | Requirements passed and target selection produced executable actions. |
| `36` | PDB | PDB | logical | PDB drop non-unique indexes | Requirements passed and target selection produced executable actions. |
| `37` | PDB | PDB | destructive | PDB loss of non-system tablespace | Requirements passed and target selection produced executable actions. |
| `38` | PDB | PDB | destructive | PDB loss of temporary tablespace | Requirements passed and target selection produced executable actions. |
| `39` | PDB | PDB | destructive | PDB loss of SYSTEM tablespace | Requirements passed and target selection produced executable actions. |
| `40` | PDB | PDB | destructive | PDB loss of UNDO tablespace | Requirements passed and target selection produced executable actions. |
| `41` | PDB | PDB | destructive | PDB loss of all datafiles | Requirements passed and target selection produced executable actions. |
| `42` | PDB | PDB | destructive | PDB SYSTEM file header corruption | Requirements passed and target selection produced executable actions. |
| `43` | PDB | PDB | logical | PDB loss of one user table | Requirements passed and target selection produced executable actions. |
| `44` | PDB | PDB | logical | PDB loss of one user schema | Requirements passed and target selection produced executable actions. |
| `55` | RAC | RAC | destructive | RAC abort one instance | Requirements passed and target selection produced executable actions. |
| `56` | RAC | RAC | logical | RAC service relocation failure practice | Requirements passed and target selection produced executable actions. |
| `57` | Network | CDB/non-CDB | destructive | Listener config unavailable | Requirements passed and target selection produced executable actions. |
| `58` | Security | CDB/non-CDB | destructive | TDE wallet or keystore unavailable | Requirements passed and target selection produced executable actions. |
| `60` | Backup | External | logical | Recovery catalog unavailable | Requirements passed and target selection produced executable actions. |
| `61` | Backup | CDB/non-CDB | destructive | FRA reaches critical utilization | Requirements passed and target selection produced executable actions. |
| `63` | Core | CDB/non-CDB | logical | TEMP tablespace exhaustion | Requirements passed and target selection produced executable actions. |
| `64` | Compliance | CDB/non-CDB | logical | RTO validation drill | Requirements passed and target selection produced executable actions. |
| `65` | Compliance | CDB/non-CDB | logical | RPO validation drill | Requirements passed and target selection produced executable actions. |
| `71` | RAC | RAC | logical | RAC service placement failure | Requirements passed and target selection produced executable actions. |
| `76` | APEX/ORDS | Application | logical | APEX/ORDS runtime account locked | Requirements passed and target selection produced executable actions. |
| `77` | APEX/ORDS | Application | destructive | APEX static resources unavailable | Requirements passed and target selection produced executable actions. |
| `78` | APEX/ORDS | Application | logical | APEX application availability validation after recovery | Requirements passed and target selection produced executable actions. |
| `81` | APEX/ORDS | Application | logical | APEX mail queue and configuration validation | Requirements passed and target selection produced executable actions. |
| `82` | APEX/ORDS | Application | logical | APEX upgrade or patch rollback readiness | Requirements passed and target selection produced executable actions. |

## Dry-Run Planning Only

| ID | Group | Scope | Impact | Scenario | Reason |
| --- | --- | --- | --- | --- | --- |
| `1` | Core | CDB/non-CDB | destructive | Loss of one control file | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/CONTROLFILE/current01.ctl (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `2` | Core | CDB/non-CDB | destructive | Loss of all control files | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/CONTROLFILE/current01.ctl (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `3` | Core | CDB/non-CDB | destructive | Loss of one member from current redo group | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_2.285.1235272233 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `4` | Core | CDB/non-CDB | destructive | Loss of all members from current redo group | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_2.285.1235272233 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `16` | Config | CDB/non-CDB | destructive | Loss of password file | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/PASSWORD/pwdcrashdb_26ai.262.1235269335 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `18` | Core | CDB/non-CDB | destructive | Loss of one member from multiplexed redo group | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_1.284.1235272227 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `19` | Core | CDB/non-CDB | destructive | Loss of all inactive redo groups | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_1.284.1235272227 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `20` | Core | CDB/non-CDB | destructive | Loss of all active redo groups | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_2.285.1235272233 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `21` | Core | CDB/non-CDB | destructive | Loss of all current redo group members | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_2.285.1235272233 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `23` | Corrupt | CDB/non-CDB | destructive | Control file corruption | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/CONTROLFILE/current01.ctl (ASM path requires ASM-aware corruption handling; filesystem dd is not valid) |
| `24` | Corrupt | CDB/non-CDB | destructive | Redo log corruption | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/ONLINELOG/group_2.285.1235272233 (ASM path requires ASM-aware corruption handling; filesystem dd is not valid) |
| `25` | Backup | CDB/non-CDB | destructive | Loss of RMAN backup pieces | Scenario 25 can see local and object-storage backup handles; execution requires --piece-handle or --local-only --max-targets <n>. |
| `26` | Config | CDB/non-CDB | destructive | Loss of SPFILE | Selected target requires a provider-specific or manual handler before safe execution: +DATA/CRASHDB_26AI/PARAMETERFILE/spfile.266.1235269757 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `28` | Config | CDB/non-CDB | destructive | Loss of ORACLE_HOME | Scenario 28 ORACLE_HOME loss requires an external restore/reinstall plan and is intentionally dry-run/manual only in this framework. |
| `29` | Backup | CDB/non-CDB | destructive | Loss of FRA destination | Selected target requires a provider-specific or manual handler before safe execution: +RECO (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `45` | PDB | PDB | destructive | Drop selected PDB including datafiles | Scenario 45 can only execute against a disposable PDB whose name starts with CRASHSIM_. Current PDB: CRASHDB_PDB1. |
| `46` | ASM | ASM | destructive | ASM data disk group unavailable | Selected target requires a provider-specific or manual handler before safe execution: +DATA (ASM disk group outage requires explicit ASM-aware fault injection and restore/rebalance steps) |
| `47` | GI | Cluster | destructive | OCR loss or restore drill | Selected target requires a provider-specific or manual handler before safe execution: OCR (OCR restore practice must use a root/Grid procedure, verified OCR backups, and CRS validation) |
| `48` | GI | Cluster | destructive | Voting disk loss or restore drill | Selected target requires a provider-specific or manual handler before safe execution: VOTING_DISK (Voting disk replacement practice must use a root/Grid procedure and cluster membership validation) |
| `49` | ASM | ASM | destructive | ASM SPFILE loss | Selected target requires a provider-specific or manual handler before safe execution: +ASM_SPFILE (ASM SPFILE loss requires ASM-aware backup/restore flow and Clusterware resource validation) |
| `59` | Backup | CDB/non-CDB | destructive | Missing archived redo log | Selected target requires a provider-specific or manual handler before safe execution: +RECO/CRASHDB_26AI/ARCHIVELOG/2026_06_07/thread_2_seq_16.299.1235288307 (ASM path requires ASM-aware crash injection; filesystem rename is not valid) |
| `62` | Backup | CDB/non-CDB | destructive | Missing required archived log during recovery | Selected target requires a provider-specific or manual handler before safe execution: +RECO/CRASHDB_26AI/ARCHIVELOG/2026_06_07/thread_2_seq_16.299.1235288307 (ASM archived-log removal requires an ASM-aware handler; RMAN decision file: /tmp/crashsimulator/crashsimulator_logs/crashsim_s62_20260607_074355_recovery_decision.rman) |
| `70` | RAC | RAC | logical | RAC VIP relocation drill | Selected target requires a provider-specific or manual handler before safe execution: ora.crashdb26ai1.vip (Relocate VIP with srvctl/crsctl under Grid owner approval, then validate client connect strings, FAN/ONS, and service failover. CrashSimulator keeps VIP movement plan-only.) |
| `73` | APEX/ORDS | Application | logical | ORDS service unavailable | Selected target requires a provider-specific or manual handler before safe execution: ords (ORDS service control requires root or passwordless sudo for the current OS user) |
| `74` | APEX/ORDS | Application | destructive | ORDS configuration unavailable | Selected target requires a provider-specific or manual handler before safe execution: /etc/ords/config (ORDS config directory is not writable by oracle; run with approved OS privileges or restore from config backup) |
| `75` | APEX/ORDS | Application | logical | ORDS database pool misconfiguration | Selected target requires a provider-specific or manual handler before safe execution: /etc/ords/config:default (Plan: back up ORDS config, change one pool setting such as service name/wallet/user to a lab-bad value, restart ORDS, validate outage, then restore config and restart. Automated mutation is intentionally blocked until target ORDS pool layout is confirmed.) |
| `80` | APEX/ORDS | Application | logical | APEX session continuity test | Selected target requires a provider-specific or manual handler before safe execution: APEX_SESSION (Plan: open a seeded APEX application session, inject ORDS/RAC/service/database failover, capture browser/client outcome, then validate whether retry/relogin is required. Automated execution requires a lab APEX application and session script.) |

## Not Runnable Now

| ID | Group | Scope | Impact | Scenario | Reason |
| --- | --- | --- | --- | --- | --- |
| `50` | DataGuard | Standby | logical | Standby managed recovery cancelled | Scenario 50 requires a physical standby database with managed recovery running. Run it on a standby environment, then confirm an MRP process is visible in V$MANAGED_STANDBY. |
| `51` | DataGuard | Primary | logical | Primary transport destination deferred | Scenario 51 requires a primary database with a configured remote standby archive destination. Configure Data Guard transport, confirm a V$ARCHIVE_DEST row with TARGET='STANDBY', then rerun validation. |
| `52` | DataGuard | DG | logical | Data Guard broker configuration unavailable | Scenario 52 requires a Data Guard configuration. Configure a standby and verify SQL/Data Guard Broker evidence before running this scenario. |
| `53` | ADG | Standby | logical | Active Data Guard read-only session pressure | Scenario 53 requires an Active Data Guard standby opened READ ONLY WITH APPLY. Run it on an ADG standby after confirming open mode and apply status. |
| `54` | DataGuard | Standby | logical | Snapshot standby conversion practice | Scenario 54 requires a Data Guard physical standby that is approved for snapshot-standby conversion practice. Run it on the standby after confirming flashback, broker/transport posture, and restore-point policy. |
| `66` | DataGuard | DG | logical | FSFO observer unavailable | Scenario 66 requires a Data Guard configuration. Configure a standby and verify SQL/Data Guard Broker evidence before running this scenario. |
| `67` | DataGuard | Standby | logical | Data Guard apply lag exceeds SLA | Scenario 67 requires a physical standby database with managed recovery running. Run it on a standby environment, then confirm an MRP process is visible in V$MANAGED_STANDBY. |
| `68` | DataGuard | Primary | logical | Data Guard transport network partition | Scenario 68 requires a primary database with a configured remote standby archive destination. Configure Data Guard transport, confirm a V$ARCHIVE_DEST row with TARGET='STANDBY', then rerun validation. |
| `69` | DataGuard | DG | logical | Standby redo log misconfiguration review | Scenario 69 requires a Data Guard configuration. Configure a standby and verify SQL/Data Guard Broker evidence before running this scenario. |
| `72` | ASM | ASM | destructive | ASM single disk failure | No redundant ASM disk candidate was found. Scenario 72 requires a NORMAL/HIGH/FLEX/EXTENDED redundancy ASM disk group with online disks; EXTERN redundancy remains plan-only unsuitable for single-disk failure practice. |
| `79` | APEX/ORDS | Application | logical | ORDS node unavailable behind load balancer | Scenario 79 requires --ords-lb-url or CRASHSIM_ORDS_LB_URL so the drill can validate load-balancer continuity. |

## How CrashSimulator Uses This Result

- `--scenario <id> --execute`, `--protect <id> --execute`, and aleatory scenario execution run readiness validation before confirmation or destructive actions.
- Guided Workflow scenario selection now shows the selected scenario readiness status immediately.
- Use only `RUNNABLE` scenarios for execution drills. Review `PLAN-ONLY` and `NOT-RUNNABLE` reasons before changing topology, targets, or helper coverage.
- Re-run this report after changing database topology, adding PDBs, multiplexing redo/control files, configuring Data Guard, adding ASM/GI lab disks, reseeding logical objects, or taking fresh backups.

## Recommended Next Commands

```bash
./CrashSimulatorV2.sh --validate-scenario <id> --pdb CRASHDB_PDB1
./CrashSimulatorV2.sh --scenario <id> --pdb CRASHDB_PDB1 --dry-run
./CrashSimulatorV2.sh --runbook <id> --pdb CRASHDB_PDB1
./CrashSimulatorV2.sh --health-check --pdb CRASHDB_PDB1
```
