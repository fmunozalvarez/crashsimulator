# CrashSimulator Scenario Readiness Report

- Generated UTC: `2026-06-08T14:56:24Z`
- Tool version: `2.0.0-dev`
- Log directory: `/tmp/crashsimulator/crashsimulator_logs`
- Target PDB context: `CRASHPDB`
- Target schema context: `not set`
- Target FILE# context: `not set`

This report validates the discovered target environment against the CrashSimulator scenario registry. The same requirement checks, topology gates, target selection, and execution guardrails are used by scenario execution, so unavailable scenarios are blocked before destructive code runs.

## Current Topology

| Signal | Value |
| --- | --- |
| Host | crashstby1-msjgs |
| OS user | oracle |
| Oracle home | /u02/app/oracle/product/23.0.0.0/dbhome_1 |
| SQL*Plus | /u02/app/oracle/product/23.0.0.0/dbhome_1/bin/sqlplus |
| Database name | CRASHDB |
| DB unique name | crashdr |
| Database role | PHYSICAL STANDBY |
| Open mode | READ ONLY WITH APPLY |
| CDB | YES |
| Instance | crashdb1 |
| Thread | 1 |
| RAC parallel | YES |
| Cluster type | RAC |
| GI managed | 1 |
| Storage type | FEX |
| Protection mode | MAXIMUM PERFORMANCE |
| Switchover status | NOT ALLOWED |
| SPFILE | @rJOnB8bM/CRASHSTBY-9E231D37B918FF9BFFE28F2EE3A2029F/CRASHDR/PARAMETERFILE/spfile.OMF.172E355A |
| Password file | @rJOnB8bM/crashstby-9e231d37b918ff9bffe28f2ee3a2029f/CRASHDR/PASSWORD/pwdCRASHDR |
| FRA | @rJOnB8bM |

## PDBs

| PDB | CON_ID | Open mode |
| --- | --- | --- |
| CRASHPDB | 3 | READ ONLY |

## Readiness Summary

| Status | Count | Meaning |
| --- | ---: | --- |
| RUNNABLE | 13 | Scenario can be selected for dry-run and, when requested, execution. |
| PLAN-ONLY | 10 | Scenario can produce useful dry-run/runbook evidence, but execution is blocked by a guardrail or provider-specific limitation. |
| NOT-RUNNABLE | 59 | Scenario is not available in the current topology or target context. |
| TOTAL | 82 | Registered scenarios evaluated. |

## Runnable Scenarios

| ID | Group | Scope | Impact | Scenario | Reason |
| --- | --- | --- | --- | --- | --- |
| `27` | Config | CDB/non-CDB | destructive | Loss of SQL*Net config files | Requirements passed and target selection produced executable actions. |
| `50` | DataGuard | Standby | logical | Standby managed recovery cancelled | Requirements passed and target selection produced executable actions. |
| `53` | ADG | Standby | logical | Active Data Guard read-only session pressure | Requirements passed and target selection produced executable actions. |
| `55` | RAC | RAC | destructive | RAC abort one instance | Requirements passed and target selection produced executable actions. |
| `57` | Network | CDB/non-CDB | destructive | Listener config unavailable | Requirements passed and target selection produced executable actions. |
| `60` | Backup | External | logical | Recovery catalog unavailable | Requirements passed and target selection produced executable actions. |
| `64` | Compliance | CDB/non-CDB | logical | RTO validation drill | Requirements passed and target selection produced executable actions. |
| `65` | Compliance | CDB/non-CDB | logical | RPO validation drill | Requirements passed and target selection produced executable actions. |
| `67` | DataGuard | Standby | logical | Data Guard apply lag exceeds SLA | Requirements passed and target selection produced executable actions. |
| `69` | DataGuard | DG | logical | Standby redo log misconfiguration review | Requirements passed and target selection produced executable actions. |
| `76` | APEX/ORDS | Application | logical | APEX/ORDS runtime account locked | Requirements passed and target selection produced executable actions. |
| `81` | APEX/ORDS | Application | logical | APEX mail queue and configuration validation | Requirements passed and target selection produced executable actions. |
| `82` | APEX/ORDS | Application | logical | APEX upgrade or patch rollback readiness | Requirements passed and target selection produced executable actions. |

## Dry-Run Planning Only

| ID | Group | Scope | Impact | Scenario | Reason |
| --- | --- | --- | --- | --- | --- |
| `25` | Backup | CDB/non-CDB | destructive | Loss of RMAN backup pieces | Scenario 25 can see local and object-storage backup handles; execution requires --piece-handle or --local-only --max-targets <n>. |
| `28` | Config | CDB/non-CDB | destructive | Loss of ORACLE_HOME | Scenario 28 ORACLE_HOME loss requires an external restore/reinstall plan and is intentionally dry-run/manual only in this framework. |
| `46` | ASM | ASM/FEX | destructive | ASM/FEX data storage unavailable | Selected target requires a provider-specific or manual handler before safe execution: @rJOnB8bM (FEX/ACFS managed storage outage requires provider-aware fault injection, service impact validation, and RMAN/GI recovery checks) |
| `47` | GI | Cluster | destructive | OCR loss or restore drill | Selected target requires a provider-specific or manual handler before safe execution: OCR (OCR restore practice must use a root/Grid procedure, verified OCR backups, and CRS validation) |
| `48` | GI | Cluster | destructive | Voting disk loss or restore drill | Selected target requires a provider-specific or manual handler before safe execution: VOTING_DISK (Voting disk replacement practice must use a root/Grid procedure and cluster membership validation) |
| `49` | ASM | ASM/FEX | destructive | ASM/FEX SPFILE loss | Selected target requires a provider-specific or manual handler before safe execution: @rJOnB8bM/CRASHSTBY-9E231D37B918FF9BFFE28F2EE3A2029F/CRASHDR/PARAMETERFILE/spfile.OMF.172E355A (FEX/ACFS managed SPFILE loss requires provider-aware metadata restore, srvctl database validation, and instance restart/recovery checks) |
| `52` | DataGuard | DG | logical | Data Guard broker configuration unavailable | Selected target requires a provider-specific or manual handler before safe execution: DG_BROKER_CONFIG (Approved lab action only: make broker configuration unavailable or stop broker management, then validate DGMGRL/SQL warnings and restore broker configuration. CrashSimulator keeps this plan-only.) |
| `54` | DataGuard | Standby | logical | Snapshot standby conversion practice | Selected target requires a provider-specific or manual handler before safe execution: SNAPSHOT_STANDBY_CONVERSION (Approved standby-only action: convert to snapshot standby, run disposable write tests, convert back to physical standby, restart apply, and validate lag. CrashSimulator keeps conversion execution plan-only.) |
| `66` | DataGuard | DG | logical | FSFO observer unavailable | Selected target requires a provider-specific or manual handler before safe execution: FSFO_OBSERVER (Stop or isolate the observer host/process, then validate broker status, failover expectations, and observer restart. CrashSimulator keeps this plan-only.) |
| `72` | ASM | ASM/FEX | destructive | ASM/FEX storage component failure | Selected target requires a provider-specific or manual handler before safe execution: @rJOnB8bM (FEX/ACFS storage-component failure should be injected through provider-approved storage controls; validate database service continuity, GI resources, RMAN recoverability, and provider redundancy/rebuild evidence) |

## Not Runnable Now

| ID | Group | Scope | Impact | Scenario | Reason |
| --- | --- | --- | --- | --- | --- |
| `1` | Core | CDB/non-CDB | destructive | Loss of one control file | Scenario 1 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `2` | Core | CDB/non-CDB | destructive | Loss of all control files | Scenario 2 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `3` | Core | CDB/non-CDB | destructive | Loss of one member from current redo group | Scenario 3 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `4` | Core | CDB/non-CDB | destructive | Loss of all members from current redo group | Scenario 4 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `5` | Core | CDB/non-CDB | destructive | Loss of one non-system datafile | Scenario 5 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `6` | Core | CDB/non-CDB | destructive | Loss of one temporary file | Scenario 6 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `7` | Core | CDB/non-CDB | destructive | Loss of one SYSTEM datafile | Scenario 7 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `8` | Core | CDB/non-CDB | destructive | Loss of one UNDO datafile | Scenario 8 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `9` | Core | CDB/non-CDB | destructive | Loss of a read-only tablespace | Scenario 9 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `10` | Core | CDB/non-CDB | destructive | Loss of an index-only tablespace | Scenario 10 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `11` | Logical | CDB/non-CDB | logical | Drop non-unique indexes outside Oracle schemas | Scenario 11 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `12` | Core | CDB/non-CDB | destructive | Loss of a non-system tablespace | Scenario 12 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `13` | Core | CDB/non-CDB | destructive | Loss of a temporary tablespace | Scenario 13 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `14` | Core | CDB/non-CDB | destructive | Loss of SYSTEM tablespace | Scenario 14 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `15` | Core | CDB/non-CDB | destructive | Loss of UNDO tablespace | Scenario 15 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `16` | Config | CDB/non-CDB | destructive | Loss of password file | Scenario 16 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `17` | Core | CDB/non-CDB | destructive | Loss of all datafiles | Scenario 17 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `18` | Core | CDB/non-CDB | destructive | Loss of one member from multiplexed redo group | Scenario 18 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `19` | Core | CDB/non-CDB | destructive | Loss of all inactive redo groups | Scenario 19 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `20` | Core | CDB/non-CDB | destructive | Loss of all active redo groups | Scenario 20 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `21` | Core | CDB/non-CDB | destructive | Loss of all current redo group members | Scenario 21 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `22` | Corrupt | CDB/non-CDB | destructive | Datafile header corruption | Scenario 22 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `23` | Corrupt | CDB/non-CDB | destructive | Control file corruption | Scenario 23 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `24` | Corrupt | CDB/non-CDB | destructive | Redo log corruption | Scenario 24 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `26` | Config | CDB/non-CDB | destructive | Loss of SPFILE | Scenario 26 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `29` | Backup | CDB/non-CDB | destructive | Loss of FRA destination | Scenario 29 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `30` | PDB | PDB | destructive | PDB loss of one non-system datafile | Scenario 30 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `31` | PDB | PDB | destructive | PDB loss of one temporary file | Scenario 31 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `32` | PDB | PDB | destructive | PDB loss of one SYSTEM datafile | Scenario 32 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `33` | PDB | PDB | destructive | PDB loss of one UNDO datafile | Scenario 33 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `34` | PDB | PDB | destructive | PDB loss of read-only tablespace | Scenario 34 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `35` | PDB | PDB | destructive | PDB loss of index-only tablespace | Scenario 35 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `36` | PDB | PDB | logical | PDB drop non-unique indexes | Scenario 36 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `37` | PDB | PDB | destructive | PDB loss of non-system tablespace | Scenario 37 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `38` | PDB | PDB | destructive | PDB loss of temporary tablespace | Scenario 38 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `39` | PDB | PDB | destructive | PDB loss of SYSTEM tablespace | Scenario 39 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `40` | PDB | PDB | destructive | PDB loss of UNDO tablespace | Scenario 40 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `41` | PDB | PDB | destructive | PDB loss of all datafiles | Scenario 41 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `42` | PDB | PDB | destructive | PDB SYSTEM file header corruption | Scenario 42 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `43` | PDB | PDB | logical | PDB loss of one user table | Scenario 43 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `44` | PDB | PDB | logical | PDB loss of one user schema | Scenario 44 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `45` | PDB | PDB | destructive | Drop selected PDB including datafiles | Scenario 45 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `51` | DataGuard | Primary | logical | Primary transport destination deferred | Scenario 51 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `56` | RAC | RAC | logical | RAC service relocation failure practice | Service crashdb_CRASHPDB.paas.oracle.com is not running. Start it before relocation/failure practice. |
| `58` | Security | CDB/non-CDB | destructive | TDE wallet or keystore unavailable | Scenario 58 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `59` | Backup | CDB/non-CDB | destructive | Missing archived redo log | Scenario 59 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `61` | Backup | CDB/non-CDB | destructive | FRA reaches critical utilization | Scenario 61 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `62` | Backup | CDB/non-CDB | destructive | Missing required archived log during recovery | Scenario 62 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `63` | Core | CDB/non-CDB | logical | TEMP tablespace exhaustion | Scenario 63 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `68` | DataGuard | Primary | logical | Data Guard transport network partition | Scenario 68 requires PRIMARY role. Current role: PHYSICAL STANDBY |
| `70` | RAC | RAC | logical | RAC VIP relocation drill | Unable to collect Clusterware resource status with crsctl. |
| `71` | RAC | RAC | logical | RAC service placement failure | No running srvctl-managed database service was available. Create/start a database service, or supply --service-name for scenario 71. |
| `73` | APEX/ORDS | Application | logical | ORDS service unavailable | ORDS is not installed or not in PATH. Install/configure ORDS on this host before running scenario 73. |
| `74` | APEX/ORDS | Application | destructive | ORDS configuration unavailable | ORDS configuration directory was not found at /etc/ords/config. Configure ORDS or pass --ords-config-dir before running scenario 74. |
| `75` | APEX/ORDS | Application | logical | ORDS database pool misconfiguration | ORDS is not installed or not in PATH. Install/configure ORDS before running scenario 75. |
| `77` | APEX/ORDS | Application | destructive | APEX static resources unavailable | No APEX static images directory was found. Install APEX static files and pass --apex-images-dir before running scenario 77. |
| `78` | APEX/ORDS | Application | logical | APEX application availability validation after recovery | The ORDS/APEX smoke URL is not reachable: http://localhost:8080/ords/. Start/configure ORDS and validate network access before running scenario 78. |
| `79` | APEX/ORDS | Application | logical | ORDS node unavailable behind load balancer | ORDS is not installed or not in PATH. Install/configure ORDS on this host before running scenario 79. |
| `80` | APEX/ORDS | Application | logical | APEX session continuity test | The ORDS/APEX smoke URL is not reachable: http://localhost:8080/ords/. Start/configure ORDS and validate network access before running scenario 80. |

## How CrashSimulator Uses This Result

- `--scenario <id> --execute`, `--protect <id> --execute`, and aleatory scenario execution run readiness validation before confirmation or destructive actions.
- Guided Workflow scenario selection now shows the selected scenario readiness status immediately.
- Use only `RUNNABLE` scenarios for execution drills. Review `PLAN-ONLY` and `NOT-RUNNABLE` reasons before changing topology, targets, or helper coverage.
- Re-run this report after changing database topology, adding PDBs, multiplexing redo/control files, configuring Data Guard, adding ASM/GI lab disks, reseeding logical objects, or taking fresh backups.

## Recommended Next Commands

```bash
./CrashSimulatorV2.sh --validate-scenario <id> --pdb CRASHPDB
./CrashSimulatorV2.sh --scenario <id> --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --runbook <id> --pdb CRASHPDB
./CrashSimulatorV2.sh --health-check --pdb CRASHPDB
```
