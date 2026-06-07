# CrashSimulator Guided Workflow Menu Validation

- Date: `2026-06-07`
- Target: Oracle AI Database 26ai RAC/ASM lab
- CDB/PDB: `CRASHDB` / `CRASHDB_PDB1`
- Validation log directory on target: `/tmp/crashsimulator/crashsimulator_logs/menuqa_20260607`
- Local evidence captures: `captures/26ai/guided_menu_*_validation_20260607*.txt`

## Scope

This validation exercised the Guided Workflow menu paths that can be safely run
in the current lab. Destructive random execution was not run; scenario `80`
provided a safe read-only execution path for the selected-scenario execute
workflow.

## Validated Menu Areas

| Area | Result | Evidence |
| --- | --- | --- |
| Main menu discovery, scenario selection, runbook, validation, dry-run, scenario `80` execute, health check, recent artifacts, random dry-run, scenario readiness | PASS | `captures/26ai/guided_menu_main_validation_20260607.txt` |
| Lifecycle guards for non-applicable protection/recovery on scenario `80` | PASS | `captures/26ai/guided_menu_lifecycle_guard_validation_20260607.txt` |
| Reports submenu: MAA context/report, config reports, deep config validation, service review, backup report, deep backup validation, baseline dry-run, lifecycle, APEX/ORDS readiness | PASS | `captures/26ai/guided_menu_reports_validation_20260607.txt` |
| Reports submenu: confirmed fresh baseline backup execution | PASS | `captures/26ai/guided_menu_baseline_execute_validation_20260607.txt` |
| Audit/retention submenu: status, dry-run purge, retain toggle, retention days, audit directory | PASS | `captures/26ai/guided_menu_audit_validation_20260607.txt` |
| Review Center: topology, review index, HTML generation, show artifact, render artifact, recent artifacts | PASS | `captures/26ai/guided_menu_review_validation_20260607.txt` |
| Configure submenu: PDB, schema, FILE#, manifest, PFILE, scenario 25 guardrails, password-file prompts, log directory, RMAN catalog, baseline tag, FRA/TEMP knobs, clear context | PASS | `captures/26ai/guided_menu_configure_validation_20260607_clean.txt` |
| Post-QA health check | PASS | `captures/26ai/guided_menu_postqa_health_20260607.txt` |

## Improvements Made

- Added selected-scenario lifecycle coverage to the Guided Workflow header.
- Added menu-side guards that stop protection/recovery choices before launching
  a child command when the selected scenario has no automated helper or does not
  require that lifecycle step.
- Updated Reports menu command builders so configuration, backup, MAA, and
  service-review reports request HTML copies automatically while retaining the
  normal Markdown/log artifacts.
- Clarified that Reports menu baseline backup execution requires the
  `BASELINE-BACKUP` confirmation token.

## Key Evidence

- Scenario `80` readiness: `RUNNABLE`.
- Scenario `80` dry-run and confirmed execution completed successfully.
- Random/aleatory dry-run selected scenario `27` and completed successfully.
- Scenario readiness report generated with `49` runnable, `23` plan-only, and
  `10` not-runnable scenarios for the current RAC/ASM/APEX/ORDS/no-Data-Guard
  topology.
- Fresh baseline backup completed successfully with tag
  `CSIM_BASE_260607112827`.
- Final health check showed `CRASHDB` and `CRASHDB_PDB1` open `READ WRITE`, no
  files needing media recovery, and no block corruption rows.

## Deferred By Design

- Main menu option `15` executes a random scenario and can choose destructive
  drills. It was not run as part of broad menu QA. The safe random dry-run path
  was validated.
- Scenario-specific destructive execute/protect/recover paths should continue
  to be validated scenario by scenario with dry-run, protection, execution,
  recovery, and health-check evidence.
