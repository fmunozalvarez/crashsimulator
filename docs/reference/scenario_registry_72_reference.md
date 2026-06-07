# CrashSimulator Scenario Registry Reference

- Generated UTC: `2026-06-07T10:45:00Z`
- Source command: `./CrashSimulatorV2.sh --list --audit-retain no`
- Registry size: `72` scenarios
- Logical drills: `20`
- Destructive drills: `52`

This sanitized reference shows the current scenario coverage after adding the
high-value resilience drills and the Data Guard/RAC/ASM-specific layer.

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

## Newly Added Resilience Scenarios

| ID | Scenario | Status |
| ---: | --- | --- |
| 61 | FRA reaches critical utilization | Runnable where FRA is configured; recovery helper restores the original FRA size. |
| 62 | Missing required archived log during recovery | Runnable for local archived-log targets; ASM targets remain plan-only unless explicitly approved. |
| 63 | TEMP tablespace exhaustion | Controlled logical workload; tune with `--temp-exhaust-mb`. |
| 64 | RTO validation drill | Read-only compliance report using completed recovery manifests and supplied SLA context. |
| 65 | RPO validation drill | Read-only recoverable-window estimate using archived redo, backup, and Data Guard evidence. |
| 66 | FSFO observer unavailable | Data Guard plan-only observer drill with broker/FSFO evidence capture. |
| 67 | Data Guard apply lag exceeds SLA | Standby-side reversible apply pause; recovery helper restarts managed recovery. |
| 68 | Data Guard transport network partition | Primary-side destination defer drill; recovery helper re-enables transport and forces log generation. |
| 69 | Standby redo log misconfiguration review | Read-only SRL count/size/thread review against online redo. |
| 70 | RAC VIP relocation drill | Plan-only VIP movement/client-survivability workflow. |
| 71 | RAC service placement failure | Reversible service stop/start or placement validation with recovery helper. |
| 72 | ASM single disk failure | Plan-only redundant ASM/failgroup drill; EXTERN redundancy is rejected. |

## Automation Snapshot

Automated protection currently covers datafile/tablespace scenarios `5`, `7`,
`8`, `9`, `10`, `12`, `14`, `15`, `17`, `22`, `30`, `32`, `33`, `34`, `35`,
`37`, `39`, `40`, `41`, and `42`.

Automated recovery currently covers scenarios `1`, `2`, `3`, `4`, `5`, `6`,
`7`, `8`, `9`, `10`, `12`, `13`, `14`, `15`, `16`, `17`, `18`, `19`, `20`,
`21`, `22`, `23`, `24`, `25`, `26`, `27`, `30`, `31`, `32`, `33`, `34`,
`35`, `37`, `38`, `39`, `40`, `41`, `42`, `50`, `51`, `55`, `56`, `57`,
`58`, `59`, `61`, `62`, `67`, `68`, and `71`.

Use `--validate-scenario <id>` or `--scenario-readiness-report` before running
any destructive drill. CrashSimulator now blocks execution when the current
topology cannot safely support the selected scenario.
