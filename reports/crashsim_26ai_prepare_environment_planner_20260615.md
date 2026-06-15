# CrashSimulator 26ai RAC Prepare Environment Planner

- Date: 2026-06-15
- Target: Oracle Database 26ai RAC, CDB `CRASHDB`, PDB `CRASHPDB`
- Storage posture: FEX/ACFS-style storage detected as `FEX_ACFS`
- Generated evidence: `captures/26ai_new_rac_20260615/prepare_environment/crashsim_prepare_environment_20260615_122324.md`

The new topology-aware seed/prepare workflow was deployed to the 26ai RAC test
environment and validated in dry-run mode with HTML output.

## Detected Preparation Status

| Preparation | Status | Notes |
| --- | --- | --- |
| Logical/root/PDB lab objects | PRESENT | Root and PDB disposable lab users/tablespaces are seeded. |
| Online redo multiplexing | PRESENT | All redo groups have at least two members. |
| Control-file multiplexing | PLAN_ONLY | One control file is currently configured; FEX/OCI posture requires an explicit provider-aware runbook and restart window. |
| AC/TAC/FAN lab services | MISSING | `crashsim_ac` and `crashsim_tac` services were not detected and are eligible for guarded preparation. |
| APEX/ORDS | PRESENT | APEX registry, ORDS runtime users, ORDS service, config, and static images were detected. |
| RMAN recovery catalog | PRESENT | Catalog metadata and CrashSimulator RMAN catalog configuration were detected. |
| FSFO observer posture | NOT_REQUIRED | No Data Guard standby transport was detected for this target. |
| ASM/GI redundant storage lab | PLAN_ONLY | FEX/ACFS shared-storage destructive drills still require explicit redundant lab storage approval. |
| Fresh RMAN baseline backup evidence | PRESENT | Baseline backup logs were found. |

## Validation Notes

- CLI entry point: `./CrashSimulatorV2.sh --prepare-environment --dry-run --html`
- Guided Workflow entry point: `21. Seed / prepare scenario lab for this topology`
- The planner deliberately auto-executes only eligible disposable or reversible
  helpers. Control-file multiplexing, FSFO enablement, and redundant shared
  storage preparation remain plan-only by design.
- The initial parser bug that cleared collected evidence before scoring was
  fixed; the report now includes raw `CSIM_PREP` evidence and accurate status.
