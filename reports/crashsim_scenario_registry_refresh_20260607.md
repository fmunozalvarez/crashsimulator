# CrashSimulator Scenario Registry And Artifact Refresh

- Refresh date: `2026-06-07`
- Local source tree: `/Users/franciscomunozalvarez/Downloads/Crashsimulator/source`
- Scenario source command: `./CrashSimulatorV2.sh --list --audit-retain no`
- Registry count: `72`

## What Was Refreshed

| Area | Refreshed artifact |
| --- | --- |
| Scenario status | `SCENARIO_STATUS.md` now summarizes the 72-scenario registry and the newly added resilience/DG/RAC/ASM layer. |
| End-user guide | `docs/CRASHSIMULATOR_USER_GUIDE.md` now reports 72 scenarios and the current protection/recovery helper coverage. |
| V2 notes | `README_V2.md` now reflects the 72-scenario registry, helper-script ZIP permissions, and new recovery helper coverage. |
| Captures | `captures/scenarios_available.txt` was regenerated from the current script registry; menu captures were aligned to the current Guided Workflow labels. |
| Screenshots | `tools/render_promo_screenshots.cjs` was updated so the generated scenario catalog includes the new Compliance group. |
| References | `docs/reference/scenario_registry_72_reference.md` was added as a sanitized scenario registry reference. |
| Reports | This report records the refresh baseline for review and audit. |
| Lifecycle coverage | `--scenario-lifecycle-report` now records validation, protection, execution, recovery, and runbook/evidence coverage for every scenario. |

## New Scenario Layer

| Range | Capability |
| --- | --- |
| `61`-`65` | FRA pressure, required archived-log recovery gap, TEMP exhaustion, RTO validation, and RPO validation. |
| `66`-`69` | FSFO observer, Data Guard apply lag, Data Guard transport partition, and standby redo log review. |
| `70`-`71` | RAC VIP/service placement validation. |
| `72` | ASM single-disk failure planning for redundant disk groups. |

## Current Guardrail Position

The framework can list, runbook, and readiness-check all 72 scenarios. Scenario
execution is topology-aware: destructive actions are blocked when the required
PDB, Data Guard, RAC, ASM, redundancy, local filesystem, backup-piece, or lab
object prerequisites are missing.

Plan-only scenarios remain intentionally guarded when the safe action requires
external infrastructure steps or an unvalidated topology, especially FSFO
observer outage, RAC VIP movement, OCR/voting disk operations, ASM SPFILE loss,
and ASM single-disk failure in redundant failgroups.

## Next Validation Targets

- Validate scenarios `66`, `67`, `68`, and `69` in a Data Guard/FSFO-capable
  lab.
- Validate scenarios `70` and `71` with RAC client connectivity, FAN/ONS, and
  AC/TAC observations.
- Validate scenario `72` only after provisioning a purpose-built NORMAL/HIGH
  redundancy ASM disk group with clear failgroups.
- Re-render promotional screenshots after any future scenario registry change.
