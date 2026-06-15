# CrashSimulator v2.0.2 Beta Release Notes

Release: `v2.0.2-beta`

## Summary

CrashSimulator `v2.0.2 beta` is a public beta update to the V2 framework. It
packages the current open-source Oracle resilience validation platform with
topology discovery, guarded scenario execution, recovery runbook hints,
evidence collection, reporting, Guided Workflow menu support, APEX/ORDS
awareness, Autonomous Database readiness coverage, and a 123-entry scenario
catalog.

This release is intended for controlled lab, development, training, and
resilience-test environments. Do not use destructive scenarios in production.

## Highlights

- Current product version reports as `2.0.2-beta`.
- Apache License 2.0 open-source repository.
- `123` total scenario catalog entries:
  - `103` database-host, infrastructure, application access-path, platform, and
    compliance scenarios.
  - `20` Autonomous Database cloud-service scenarios, `ADB01` through `ADB20`.
  - New readiness/runbook-first families for AC/TAC/FAN services, Data Guard
    switchover/failback, PDB PITR, guaranteed restore points, patch rollback,
    Exadata, OCI Base Database Service, GoldenGate, and expanded ADB access
    path/cloud-control-plane drills.
- CLI and Guided Workflow menu modes.
- Topology-aware scenario validation and blocker messages.
- Recovery runbook hints and lifecycle coverage reporting.
- Public-readiness hardening: `--doctor`, `--first-run`,
  `--scenario-lifecycle-check`, `--secret-scan`, `--sanitize-artifacts`,
  `--node-sync-check`, and `--release-check`.
- Additional destructive-lab acknowledgement guardrail for non-interactive
  `--execute --yes` lab runs.
- Guided Workflow option `22. Public readiness and safety checks`.
- Guided Workflow topology cache with refresh controls for faster menu startup.
- Configuration file support for non-secret defaults.
- Review Center for existing topology snapshots, reports, manifests, logs,
  HTML artifacts, and audit evidence.
- Markdown and optional HTML report generation.
- Audit retention, audit status, and audit purge support.
- Baseline backup helper.
- Oracle MAA readiness and service HA review reports.
- Backup strategy and recoverability/RTO/RPO reporting.
- APEX/ORDS readiness and scenarios `73` through `82`.
- Autonomous Database readiness report and ADB scenario browsing.
- Reference screenshots, reference reports, and tutorial documentation.

## What Changed Since v2.0.1 Beta

- Added public-readiness guidance with `--first-run` and
  `--public-limitations --html`.
- Added clearer lifecycle coverage for validation, protection, execution,
  recovery, runbook, and evidence posture across all registered scenarios.
- Expanded ADB scenario visibility through `ADB20` and refreshed ADB readiness
  documentation.
- Added seed/prepare environment guidance for topology-aware lab preparation.
- Added tutorial media for prepare-environment, guided first-run, and public
  limitations workflows.
- Refreshed public screenshots, reference reports, and release-sanity evidence.
- Rebuilt the curated runtime package as
  `crashsimulator-v2.0.2-beta-runtime.zip`.

## Installable Package

The release package is:

- `dist/crashsimulator-v2.0.2-beta-runtime.zip`

It is a runtime/source archive intended for installation on Oracle database
hosts, RAC nodes, bastion hosts, or ADB client hosts. It includes the scripts,
SQL/RMAN helpers, configuration template, docs, reports, screenshots, and
reference examples needed to evaluate the product.

To keep the database-host install package practical, large promotional/tutorial
MP4 files and local scratch logs are excluded from the zip. Tutorial video
source files remain available in the GitHub repository and can also be attached
separately to GitHub releases in future.

## Basic Installation

```bash
unzip crashsimulator-v2.0.2-beta-runtime.zip
cd crashsimulator-v2.0.2-beta
chmod +x crashsimulator CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
./CrashSimulatorV2.sh --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --menu
```

Run as the Oracle software owner, or as an OS user that can connect locally as
SYSDBA. `--dry-run` is the default. Destructive scenarios require `--execute`
and typed confirmation. Non-interactive destructive lab runs using
`--execute --yes` also require `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` or
`--accept-destructive-lab`.

## Important Documentation

- `README.md`
- `README_V2.md`
- `docs/CRASHSIMULATOR_V2_0_2_BETA_PRODUCT_OVERVIEW.md`
- `docs/CRASHSIMULATOR_USER_GUIDE.md`
- `docs/AUTONOMOUS_DATABASE_COVERAGE.md`
- `SCENARIO_STATUS.md`
- `docs/reference/scenario_registry_123_reference.md`

## Known Limitations

- Beta release: some scenario families remain readiness-oriented or plan-only.
- Destructive drills require approved lab environments and backups.
- ADB scenarios are currently readiness/report driven; seeded logical and OCI
  control-plane helpers are roadmap items.
- GI/OCR/voting/ASM low-level destructive drills require purpose-built labs and
  approved privileges.
- APEX/ORDS destructive drills require ORDS service/config visibility,
  recoverable lab URLs, and sometimes a restricted OS privilege helper.
- Guided Workflow is terminal-based, not a browser GUI.

## Validation Statement

CrashSimulator is designed for Oracle Database 12c and later. Current project
validation evidence includes Oracle Database 19c and Oracle AI Database 26ai
labs, including RAC/ASM and Autonomous Database readiness evidence.

This is CrashSimulator project validation and not an official Oracle product
certification.
