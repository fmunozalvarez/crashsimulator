# CrashSimulator Scenario Registry And Artifact Refresh

- Refresh date: `2026-06-07`
- Current catalog refresh: `2026-06-16`
- Local source tree: `/Users/franciscomunozalvarez/Downloads/Crashsimulator/source`
- Scenario source command: `./CrashSimulatorV2.sh --list --audit-retain no`
- Registry count: `123`
- Database-host, infrastructure, application, platform, and provider-planning scenarios: `103`
- Autonomous Database scenarios: `20`

## What Was Refreshed

| Area | Refreshed artifact |
| --- | --- |
| Scenario status | Current documentation summarizes the 123-scenario registry and the expanded resilience/DG/RAC/ASM/APEX/ORDS/services/platform/cloud layer. |
| End-user guide | `docs/CRASHSIMULATOR_USER_GUIDE.md` reports 123 total scenarios and the current protection/recovery helper coverage. |
| V2 notes | `README_V2.md` reflects the 123-scenario registry, helper-script ZIP permissions, and new recovery helper coverage. |
| Captures | `captures/scenarios_available.txt` was regenerated from the current script registry; menu captures were aligned to the current Guided Workflow labels. |
| Screenshots | `tools/render_promo_screenshots.cjs` was updated so the generated scenario catalog is sourced from `CrashSimulatorV2.sh` and includes all current groups. |
| References | `docs/reference/scenario_registry_123_reference.md` is the current sanitized scenario registry reference; 82/97 references are historical snapshots. |
| Reports | This report records the refresh baseline for review and audit. |
| Lifecycle coverage | `--scenario-lifecycle-report` now records validation, protection, execution, recovery, and runbook/evidence coverage for every scenario. |

## New Scenario Layer

| Range | Capability |
| --- | --- |
| `61`-`65` | FRA pressure, required archived-log recovery gap, TEMP exhaustion, RTO validation, and RPO validation. |
| `66`-`69` | FSFO observer, Data Guard apply lag, Data Guard transport partition, and standby redo log review. |
| `70`-`71` | RAC VIP/service placement validation. |
| `72` | ASM single-disk failure planning for redundant disk groups. |
| `73`-`82` | APEX/ORDS application access-path validation, including service, config, runtime-account, static-resource, availability, session, mail, and patch-readiness practice. |
| `83`-`90` | Service continuity, FAN/ONS, Data Guard switchover/failback, role-based services, PDB PITR, guaranteed restore point rollback, and patch rollback readiness. |
| `EXA01`-`EXA04` | Exadata platform readiness planning. |
| `OCI01`-`OCI05` | OCI Base Database Service backup, DR, failover, VCN, and NSG validation planning. |
| `GG01`-`GG04` | GoldenGate process, lag, and trail recovery planning. |
| `ADB01`-`ADB20` | Autonomous Database logical recovery, clone/PITR, wallet/connectivity, ADG, IAM, Object Storage, Database Actions, APEX workspace, and cross-region clone validation. |

## Current Guardrail Position

The framework can list, runbook, and readiness-check the current 123-scenario
catalog. Scenario execution is topology-aware: destructive actions are blocked
when the required PDB, Data Guard, RAC, ASM/FEX/ACFS, redundancy, local
filesystem, backup-piece, APEX, ORDS, OCI, GoldenGate, ADB, or lab object
prerequisites are missing.

Plan-only scenarios remain intentionally guarded when the safe action requires
external infrastructure steps or an unvalidated topology, especially FSFO
observer outage, RAC VIP movement, OCR/voting disk operations, ASM SPFILE loss,
ASM single-disk failure in redundant failgroups, and production load-balancer
validation for ORDS node-outage drills.

## Next Validation Targets

- Validate scenarios `66`, `67`, `68`, and `69` in a Data Guard/FSFO-capable
  lab.
- Validate scenarios `70` and `71` with RAC client connectivity, FAN/ONS, and
  AC/TAC observations.
- Validate scenario `72` only after provisioning a purpose-built NORMAL/HIGH
  redundancy ASM disk group with clear failgroups.
- Re-run APEX/ORDS scenario `79` with a production load-balancer URL when one is
  available; the current 26ai lab evidence uses a peer-continuity endpoint.
- Add a seeded APEX browser-session driver for richer end-user behavior capture
  around scenario `80`; the current implementation generates read-only
  continuity evidence.
- Re-render promotional screenshots after any future scenario registry change.
