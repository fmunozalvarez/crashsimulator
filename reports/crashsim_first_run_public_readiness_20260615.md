# CrashSimulator First-Run Guide

- Generated UTC: `2026-06-15T13:27:20Z`
- Tool version: `2.0.1-beta`

This guide is intentionally read-only. It gives new users a safe order of operations before they try destructive drills.

## Recommended Flow

1. Configure the Oracle environment or create `crashsimulator.conf`, then run `./CrashSimulatorV2.sh --show-config` and `./CrashSimulatorV2.sh --validate-config`.
2. Run `./CrashSimulatorV2.sh --public-limitations --html` so the team understands plan-only, provider-specific, ADB, licensing-sensitive, and destructive-drill expectations.
3. Run `./CrashSimulatorV2.sh --doctor --html` to check local tooling, config, and public-safety posture.
4. Run `./CrashSimulatorV2.sh --discover` or open the Guided Workflow menu to collect topology evidence.
5. Run `./CrashSimulatorV2.sh --prepare-environment --dry-run --html` to detect missing lab seeds for this topology without changing the database.
6. Run `./CrashSimulatorV2.sh --scenario-readiness-report --html` to see which scenarios are runnable, plan-only, or blocked.
7. Run `./CrashSimulatorV2.sh --scenario-lifecycle-report --html` to review validation/protection/execution/recovery/runbook/evidence coverage.
8. Start with read-only reports, then low-risk logical/tempfile drills, then destructive drills only after backup, runbook, and recovery validation review.
9. Before any non-interactive destructive execution, set `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` only in an approved non-production lab.

## Safe Starter Commands

```bash
./CrashSimulatorV2.sh --show-config
./CrashSimulatorV2.sh --validate-config
./CrashSimulatorV2.sh --public-limitations --html
./CrashSimulatorV2.sh --doctor --html
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --prepare-environment --dry-run --html
./CrashSimulatorV2.sh --scenario-lifecycle-check --html
./CrashSimulatorV2.sh --scenario-readiness-report --html
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --maa-report --html
./CrashSimulatorV2.sh --resilience-scorecard --html
```

## Evidence Interpretation

Treat installed or configured components as candidates until a drill has measured them. Do not claim near-zero downtime without client/service/FAN/AC/TAC evidence, and do not claim zero data loss without synchronous protection and tested transition evidence.

## Safe Starter Scenario Ideas

- Read-only first: health check, configuration report, backup/recoverability report, MAA report, service review, resilience scorecard, APEX/ORDS readiness, and ADB readiness where applicable.
- Low-risk drills after readiness passes: scenarios `6` and `31` for tempfile loss, `11` and `36` for disposable index rebuild practice, `43` for disposable table loss, and `63` for controlled TEMP pressure.
- Defer plan-only/provider-specific drills such as ASM/GI/OCR/voting, OCI control-plane, Exadata, GoldenGate, switchover/failback, PDB PITR, GRP rollback, and AC/TAC replay until the external runbook and approvals are complete.
