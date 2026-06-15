# CrashSimulator Public Readiness Sanity Sweep

- Generated UTC: `2026-06-15T13:37:00Z`
- Tool version: `2.0.1-beta`
- Scope: local repository validation, menu smoke tests, report examples, screenshots, and tutorial media.

## Summary

This sweep validates the public-facing CrashSimulator surfaces that can be tested without a live Oracle target. It does not claim that destructive database scenarios were executed on this laptop. Destructive execution still requires an approved non-production Oracle lab, tested backups, topology-specific readiness checks, and explicit destructive-lab acknowledgement.

## Local Results

| Area | Result | Evidence |
| --- | --- | --- |
| Scenario lifecycle check | PASS | `captures/scenario_lifecycle_check_latest.txt` shows `103` database scenarios, `20` ADB scenarios, `0` failures, and `0` warnings. |
| Scenario lifecycle report | PASS | `docs/reference/scenario_lifecycle_coverage_reference.md` and `.html` refreshed. |
| Public limitations page | PASS | `docs/CRASHSIMULATOR_PUBLIC_LIMITATIONS.md`, `docs/reference/public_limitations_reference.md`, and HTML copies refreshed. |
| Guided Workflow option 21 | PASS | `captures/menu_prepare_environment_option21.txt` confirms the Seed / prepare scenario lab menu path returns promptly. |
| Public readiness menu | PASS | `captures/menu_public_readiness_option22.txt` confirms the public-readiness submenu returns promptly. |
| Reports menu | PASS | `captures/menu_reports_current.txt` confirms reports remain reachable from Guided Workflow. |
| Artifact browser | PASS | `captures/menu_recent_artifacts_current.txt` confirms recent artifact review still opens locally. |
| Promotional screenshots | PASS | `assets/screenshots/crashsim_prepare_environment_option21.png`, `crashsim_first_run_public_readiness.png`, and `crashsim_public_limitations_page.png` generated. |
| Tutorial videos | PASS | Silent/subtitled and narrated MP4s generated for prepare-environment, guided first-run, and public limitations tutorials. |

## Plan-Only / External Action Expectations

The lifecycle report intentionally labels provider-specific or change-window-sensitive scenarios as plan-only or external-action evidence first. This includes GI/OCR/voting disk and FEX/ACFS/ASM storage drills, Data Guard switchover/failback and FSFO observer drills, AC/TAC/FAN client replay validation, PDB PITR/GRP rollback/patch rollback drills, Exadata, OCI Base Database Service, and GoldenGate scenario families.

## Live Lab Follow-Up

Before public destructive demonstrations, run the same workflow on a dedicated Oracle lab:

```bash
./CrashSimulatorV2.sh --show-config
./CrashSimulatorV2.sh --validate-config
./CrashSimulatorV2.sh --doctor --html
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --prepare-environment --dry-run --html
./CrashSimulatorV2.sh --scenario-readiness-report --html
./CrashSimulatorV2.sh --backup-report --html
./CrashSimulatorV2.sh --scenario-lifecycle-check --html
```

Then execute only readiness-passing, low-risk starter drills first, such as tempfile loss, disposable logical objects, and read-only/service-review drills, before moving to destructive datafile, redo, control file, RAC, Data Guard, APEX/ORDS, or provider-specific scenarios.
