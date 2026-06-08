# CrashSimulator Scenario Registry Reference

- Generated UTC: `2026-06-08T15:31:50Z`
- Database-host source command: `./CrashSimulatorV2.sh --list --audit-retain no`
- Autonomous Database source: `CrashSimulatorV2.sh` ADB scenario registry
- Registry size: `97` scenarios
- Database, infrastructure, and application scenarios: `82`
- Autonomous Database cloud-service scenarios: `15`
- Logical/cloud-service drills: `43`
- Destructive host/infrastructure drills: `54`

This sanitized reference shows the current scenario coverage after adding the
high-value resilience drills, the Data Guard/RAC/ASM-specific layer, the
APEX/ORDS application access-path layer, and the Autonomous Database
cloud-service scenario family.

## Coverage By Group

| Group | Count | Coverage intent |
| --- | ---: | --- |
| Core | 20 | Control files, redo, datafiles, tempfiles, tablespaces, TEMP pressure, and root database media recovery practice. |
| PDB | 16 | PDB-scoped datafile, tempfile, tablespace, logical object, and disposable PDB drills. |
| Backup | 6 | RMAN pieces, FRA destination/pressure, archived-log loss, required archived-log recovery gaps, and recovery catalog posture. |
| Config | 4 | Password file, SPFILE, SQL*Net, and ORACLE_HOME practice. |
| Corrupt | 3 | Datafile header, control file, and redo corruption drills. |
| Logical | 1 | Root/non-CDB non-unique index loss. |
| ASM | 3 | ASM disk group, ASM SPFILE, and redundant ASM single-disk failure planning. |
| GI | 2 | OCR and voting-disk restore planning. |
| DataGuard | 8 | Managed recovery, transport, broker, FSFO observer, apply lag, transport partition, SRL review, and snapshot standby coverage. |
| ADG | 1 | Active Data Guard read-only pressure placeholder. |
| RAC | 4 | Instance abort, service relocation, VIP relocation planning, and service placement failure. |
| Network | 1 | Listener/network configuration recovery. |
| Security | 1 | TDE wallet or keystore unavailability. |
| Compliance | 2 | RTO and RPO validation reporting. |
| APEX/ORDS | 10 | ORDS service/config/pool, APEX runtime account, static files, availability, session, mail, and patch-readiness practice. |
| ADB | 15 | Autonomous Database logical recovery, clone/PITR, backup readiness, wallet/connectivity, resource pressure, Autonomous Data Guard, IAM, and Object Storage dependency drills. |

## Autonomous Database Scenarios

| ID | Scenario | Area | Validation focus | Recovery focus |
| --- | --- | --- | --- | --- |
| ADB01 | Drop critical application table | Logical recovery | Live SQL connection, disposable lab table, flashback eligibility, clone/export fallback. | Flashback Table, PITR clone, Data Pump/object merge, application validation. |
| ADB02 | Drop application schema | Logical recovery | Live SQL connection, disposable schema, grants/object inventory, export or clone/PITR path. | Clone/export recovery, user/grant restoration, application validation. |
| ADB03 | Mass DELETE without WHERE clause | Logical recovery | Live SQL connection, disposable lab table, before/after row counts, flashback query window. | Flashback Query/Table, clone comparison, data merge. |
| ADB04 | Incorrect UPDATE corrupts business data | Logical recovery | Live SQL connection, disposable lab table, before image evidence, validation query. | Flashback Versions Query, object restore, data comparison. |
| ADB05 | Recover from clone | Clone/PITR | OCI metadata for clone permissions, source database, timestamp, compartment, and restore target. | Create clone, validate objects/application, merge recovered data. |
| ADB06 | Point-in-time recovery drill | Clone/PITR | OCI PITR or clone-to-time window, backup retention, timestamp selection, and validation target. | Measure RTO/RPO, validate clone, extract/merge recovered data. |
| ADB07 | Validate backup recoverability | Backup readiness | OCI backup retention, latest backup, PITR window, restore/clone capability, and evidence freshness. | Evidence-only or clone-based restore validation. |
| ADB08 | Expired or rotated client wallet | Connectivity | Wallet directory, aliases, rotation owner, application distribution points, and reconnect test path. | Download new wallet, update clients, reconnect, smoke-test applications. |
| ADB09 | Private endpoint connectivity loss | Network | Private endpoint DNS/label, bastion path, routes, NSGs/security lists, and approved fault boundary. | Restore network/DNS/security-list path and validate client reconnect. |
| ADB10 | Connection pool saturation | Resource limits | Live SQL connection, approved workload limits, service-level target, and application retry/backoff boundaries. | Tune pool limits, retries, service class, and application backoff. |
| ADB11 | Resource Manager or concurrency pressure | Resource limits | Live SQL connection, approved workload generator, resource plan/service class, and measurable threshold. | Review service class, scaling posture, consumer limits, workload scheduling. |
| ADB12 | Cross-region DR validation | Autonomous Data Guard | OCI Autonomous Data Guard metadata, peer/standby region, lag, failover eligibility, and app reconnect path. | Failover validation, reconnect, RTO/RPO measurement, fallback plan. |
| ADB13 | Autonomous Data Guard role transition | Autonomous Data Guard | OCI ADG role, region, lag, switchover/failover eligibility, URL/service validation. | Switchover/failover and fallback runbook. |
| ADB14 | IAM administrator access misconfiguration | OCI/IAM | Read-only IAM policy/group/compartment evidence, break-glass account, and approved test boundary. | Restore IAM access and validate admin and automation access. |
| ADB15 | Object Storage export dependency unavailable | Object Storage | Bucket, credential, DBMS_CLOUD object, network path, IAM policy, and export/import procedure evidence. | Restore bucket/policy/credential/network access; validate export/import. |

## Automation Snapshot

Automated protection currently covers datafile/tablespace scenarios `5`, `7`,
`8`, `9`, `10`, `12`, `14`, `15`, `17`, `22`, `30`, `32`, `33`, `34`, `35`,
`37`, `39`, `40`, `41`, and `42`.

Automated recovery currently covers scenarios `1`, `2`, `3`, `4`, `5`, `6`,
`7`, `8`, `9`, `10`, `12`, `13`, `14`, `15`, `16`, `17`, `18`, `19`, `20`,
`21`, `22`, `23`, `24`, `25`, `26`, `27`, `30`, `31`, `32`, `33`, `34`,
`35`, `37`, `38`, `39`, `40`, `41`, `42`, `50`, `51`, `55`, `56`, `57`,
`58`, `59`, `61`, `62`, `67`, `68`, `71`, `73`, `74`, `75`, `76`, `77`, and
`79`.

Autonomous Database scenarios are currently readiness/report driven. Use
`--adb-readiness-report`, `--list-adb-scenarios`, and
`--adb-scenario <ADB01-ADB15>` to validate the target context and inspect
runbook posture before adding seeded logical or OCI control-plane helpers.

Use `--validate-scenario <id>`, `--scenario-readiness-report`, or the Guided
Workflow menu before running any destructive database-host drill.
CrashSimulator blocks execution when the current topology cannot safely support
the selected scenario.
