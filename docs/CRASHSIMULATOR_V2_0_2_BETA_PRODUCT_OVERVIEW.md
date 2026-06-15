# CrashSimulator v2.0.2 Beta Product Overview

Status date: 2026-06-15

## Executive Summary

CrashSimulator is an open-source resilience validation platform for Oracle
Database environments. By orchestrating controlled failures and recovery
scenarios, it helps organizations continuously verify recoverability, strengthen
operational readiness, validate HA/DR architectures, and demonstrate compliance
with recovery objectives and regulatory requirements.

Version `v2.0.2 beta` is the current V2 framework release. It is a
single-script, guardrail-driven platform that can discover an Oracle database
topology, explain which scenarios are possible in that topology, generate
runbooks and evidence, execute supported drills, assist recovery, and produce
reports for operators, architects, auditors, and resilience teams.

CrashSimulator is not intended to replace Oracle documentation, DBA judgment,
backup strategy design, Data Guard design, MAA architecture work, or operational
change control. Its purpose is to make resilience practice safer, repeatable,
measurable, and easier to evidence.

## What The Product Is

CrashSimulator is a practical training, validation, and evidence platform for
Oracle recoverability. It helps teams answer questions that are often assumed
but not regularly proven:

- Can this database, PDB, service, or application access path really recover?
- Do our backups, RMAN catalog, archived logs, and recovery procedures work?
- Are our Data Guard, RAC, ASM, APEX/ORDS, and Autonomous Database dependencies
  ready for realistic failures?
- Can operators follow a repeatable runbook during pressure?
- Can we produce evidence for internal audit, compliance, and resilience
  programs?
- Are our RTO and RPO objectives realistic for the current topology?

The project is built around controlled drills, not uncontrolled breakage. The
default mode is dry-run. Destructive actions require explicit `--execute`
intent and typed confirmation tokens. Non-interactive destructive lab runs also
require an explicit lab acknowledgement through
`CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` or `--accept-destructive-lab`. Where a
scenario is not safe or not supported by the discovered topology,
CrashSimulator reports the reason instead of forcing execution.

Public beta hardening includes a doctor/preflight report, a first-run guide,
scenario lifecycle consistency checks, secret scanning, sanitized public
artifact generation, optional multi-node sync checks for RAC/ORDS labs, and a
combined release-check command.

## Why The Project Was Created

CrashSimulator was created to close the gap between theoretical recoverability
and proven recoverability.

Many Oracle environments have backups, Data Guard, RAC, ASM, APEX/ORDS, or OCI
cloud services configured, but teams often do not practice real failure and
recovery paths frequently enough. When an incident happens, the hard part is not
only knowing the Oracle command. It is also knowing the target, validating the
backup, choosing the recovery path, coordinating application access, collecting
evidence, and confirming the service is healthy again.

The intention of CrashSimulator is to give DBAs, MAA practitioners, platform
teams, auditors, and application owners a safer lab-oriented way to practice
those decisions. It turns recovery drills into a lifecycle:

1. Discover the environment.
2. Validate whether a scenario is possible now.
3. Generate a runbook and dry-run plan.
4. Protect the target where supported.
5. Execute only after explicit approval.
6. Recover with helper guidance where available.
7. Validate database, PDB, service, and application state.
8. Preserve evidence and lessons learned.
9. Refresh the backup baseline after higher-risk drills.

## Open-Source Status

CrashSimulator is now an open-source project. The repository includes an
Apache License 2.0 license file, so users can inspect, use, modify, and
contribute to the framework under those license terms.

The open-source intention is important: resilience validation improves when the
community can review scenarios, add topology-specific helpers, contribute
runbooks, share lessons learned, and challenge unsafe assumptions.

CrashSimulator is not an official Oracle product and does not provide official
Oracle certification. When this project says a topology is validated, it means
the CrashSimulator project has collected lab evidence for that capability. It
does not replace Oracle support guidance or customer-specific architecture
review.

## Current Version

Current product version: `v2.0.2 beta`

Version `v2.0.2 beta` includes the V2 single-script framework,
`CrashSimulatorV2.sh`, plus the friendly `crashsimulator` launcher, helper
scripts, seed scripts, reports, documentation, screenshots, reference examples,
and tutorial assets.

The beta label is intentional. The framework has broad current capability, but
some scenario families remain readiness-oriented, plan-only, or dependent on
approved lab privileges. The product is suitable for controlled test,
development, training, and resilience-validation environments. It should not be
used to inject destructive failures into production systems.

## Intended Users

CrashSimulator is designed for:

- Oracle DBAs and backup/recovery specialists.
- MAA, HA, DR, and resilience architects.
- Platform teams responsible for RAC, Data Guard, ASM, APEX/ORDS, and OCI.
- Application owners who need to understand user-facing impact.
- Audit, compliance, and risk teams that need recoverability evidence.
- Training teams building realistic Oracle recovery labs.
- Open-source contributors who want to improve scenario coverage.

## Supported Oracle Environment Scope

CrashSimulator is designed for Oracle Database 12c and later.

Current project validation evidence includes Oracle Database 19c and Oracle AI
Database 26ai lab environments, including RAC/ASM and Autonomous Database
readiness evidence. This is project validation, not official Oracle
certification.

The framework supports or is aware of:

- Non-CDB and CDB databases.
- PDB-specific scenarios and PDB context selection.
- Standalone databases.
- RAC and Grid Infrastructure.
- ASM, filesystem storage, FEX/ACFS-style managed storage awareness, and
  provider-managed storage planning.
- Data Guard and Active Data Guard.
- FSFO awareness and observer placement review.
- Oracle services, role-based services, AC/TAC signals, and DML redirection
  awareness.
- RMAN with target control file metadata.
- RMAN recovery catalog availability and reporting when configured.
- FRA and archived redo posture.
- TDE wallet/keystore posture.
- APEX and ORDS as user-facing application access dependencies.
- Oracle Autonomous Database from a client or bastion host using wallet and
  SQL evidence.

## Product Architecture

CrashSimulator V2 is intentionally simple to deploy:

- Main executable: `CrashSimulatorV2.sh`
- Friendly launcher: `crashsimulator`
- Configuration template: `config/crashsimulator.conf.example`
- Lab seed script: `seed_crashsim_lab.sql`
- Lab verification script: `verify_crashsim_lab.sql`
- Baseline backup helper: `crashsim_run_baseline_backup.sh`
- Redundant GI/ASM lab helper: `crashsim_prepare_redundant_gi_lab.sh`
- Restricted ORDS privilege helper: `crashsim_ords_priv_helper.sh`
- Optional APEX browser-session driver:
  `tools/crashsim_apex_session_driver.cjs`

The framework is primarily shell-based because it is intended to run directly
from Oracle database hosts, RAC nodes, bastion hosts, and lab systems where the
Oracle software owner already has the right environment and tools. It uses
Oracle tools such as SQL*Plus, RMAN, `srvctl`, `crsctl`, `asmcmd`, DGMGRL,
`lsnrctl`, ORDS, `curl`, and optional OCI/Python tooling only when those
capabilities are relevant and available.

## Operating Modes

CrashSimulator can be used in two main ways.

### CLI Mode

CLI mode is the best path for automation, repeatable runbooks, lab notebooks,
and CI-like validation. Example commands:

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --runbook 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --protect 30 --pdb CRASHPDB --execute
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --execute
./CrashSimulatorV2.sh --recover 30 --pdb CRASHPDB --manifest ./crashsimulator_logs/<manifest> --execute
```

### Guided Workflow Menu

The Guided Workflow menu provides a terminal-based assisted interface. It can:

- Discover or refresh topology.
- Select scenarios.
- Prompt for PDB, schema, FILE#, manifest, PFILE, and scenario-specific
  context.
- Validate whether a selected scenario can run.
- Show runbook hints.
- Dry-run, protect, execute, and recover where supported.
- Generate reports.
- Browse generated reports, logs, manifests, audit folders, HTML files, and
  previous evidence with timestamps and file sizes.
- Open Autonomous Database scenario and report workflows even from client or
  bastion hosts where SQL*Plus is not installed.

This is not yet a browser-based GUI. It is an assisted terminal workflow that
keeps the same guardrails as CLI execution.

## Current Capability Summary

### Topology Discovery

CrashSimulator discovers and reports database posture, including:

- Database name, DB unique name, instance, host, version, and open mode.
- CDB/non-CDB posture and PDB list.
- Database role and Data Guard signals.
- RAC and Grid Infrastructure signals.
- ASM/filesystem/FEX/ACFS-style storage signals.
- FRA location and usage.
- SPFILE and password-file posture.
- ORACLE_HOME and SQL*Plus/RMAN availability.
- Listener and SQL*Net file posture.
- APEX/ORDS and Autonomous Database context where configured.

### Scenario Catalog

The current catalog contains `123` total entries:

- `103` database-host, infrastructure, application access-path, platform, and
  compliance scenarios.
- `20` Autonomous Database cloud-service scenarios, `ADB01` through `ADB20`.
- Existing destructive host/infrastructure drills remain guarded by typed
  confirmation and topology checks.
- New service-continuity, Data Guard transition, Exadata, OCI DB, GoldenGate,
  and expanded ADB drills are readiness/runbook-first until target-specific
  lab evidence and rollback boundaries are approved.

Coverage groups include Core, PDB, Backup, Config, Corrupt, Logical, ASM, GI,
Data Guard, Active Data Guard, RAC, Network, Security, Compliance, APEX/ORDS,
Services, Recovery, Lifecycle, Exadata, OCI DB, GoldenGate, and ADB.

The reference catalog is available in:

- `docs/reference/scenario_registry_123_reference.md`
- `assets/screenshots/crashsim_scenario_catalog.png`

### Scenario Validation And Guardrails

Every scenario should have a validation path. Validation checks whether the
current topology can support the selected scenario and reports a clear blocker
when it cannot.

Examples:

- PDB scenarios require a selected PDB.
- Schema/table scenarios require valid targets, ideally seeded lab objects.
- RAC scenarios require RAC signals and relevant Grid tools.
- Data Guard scenarios require a matching primary, standby, or broker posture.
- ASM scenarios check ASM storage and refuse unsafe filesystem assumptions.
- ORDS/APEX scenarios require ORDS/APEX configuration, URLs, and privileges.
- ADB scenarios use ADB context and readiness evidence rather than host-level
  destructive actions.

### Protection, Execution, Recovery, And Evidence Lifecycle

Where supported, scenarios include:

- Validation.
- Protection or baseline backup steps.
- Dry-run planning.
- Execution with explicit confirmation.
- Recovery helper guidance.
- Recovery validation.
- Runbook/evidence reporting.
- Manifest files that capture the target and action context.

The lifecycle coverage report shows which steps are available per scenario.

### Recovery-Runbook Hints

CrashSimulator prints scenario-specific recovery guidance before execution and
can generate runbooks without running a scenario. This helps users practice the
decision path before touching a target.

### Reports

Version `v2.0.2 beta` includes report families for:

- Database and PDB configuration.
- Backup strategy, recoverability, RTO/RPO estimate, and RMAN metadata.
- Scenario readiness.
- Scenario lifecycle coverage.
- Oracle MAA readiness and best-practice posture.
- Executive resilience scorecard across backup, HA, DR, security,
  recoverability, MAA alignment, scenario coverage, and application continuity.
- Oracle service HA review, including AC/TAC, role-based services, FSFO, and
  ADG DML redirection awareness.
- APEX/ORDS readiness.
- Autonomous Database readiness.
- Review index across existing logs, reports, manifests, health checks, and
  audit evidence.
- HTML rendering for easier viewing while preserving the original text,
  Markdown, RMAN, SQL, or log artifact.

### Backup And Recovery Capabilities

CrashSimulator can help users validate:

- RMAN backup metadata from the target control file.
- RMAN recovery catalog availability when configured.
- Backup device types and backup-piece posture.
- FRA capacity and archived-log posture.
- Baseline backup generation with dry-run and execute modes.
- Backup validation and recoverability evidence.
- RTO/RPO reasonableness from current backup, archived redo, and Data Guard
  evidence.

### Oracle MAA And SLA Readiness

The MAA readiness report gives a best-effort decision-tree assessment. It
separates the target MAA level implied by business RTO/RPO, the candidate level
suggested by topology, and the current evidenced level supported by
configuration, integration, measured drills, and operational evidence. It
reviews signals across:

- Backup/recovery.
- Data Guard and Active Data Guard.
- RAC and services.
- ASM/storage.
- FRA and archived redo.
- TDE wallet posture.
- FSFO observer awareness and placement.
- AC/TAC and application continuity signals.
- ADG DML redirection awareness.
- Role-based services when Data Guard is in use.
- SLA objective context for future RTO/RPO recommendation work.

This is an assessment and training aid, not an Oracle MAA certification.

### Resilience Scorecard

The resilience scorecard turns collected technical evidence into a concise
management view. It uses topology discovery, backup posture, MAA posture,
scenario lifecycle coverage, protection/recovery manifests, service and
application-continuity signals, and recent validation evidence to produce domain
scores and an overall score out of 100.

The scorecard intentionally separates configured capability from proven
readiness. For example, RAC, Data Guard, FSFO, or APEX/ORDS awareness can raise
candidate posture, but scores improve most when the environment also has recent
backup validation, successful recovery manifests, service failover validation,
role-transition evidence, and measured RTO/RPO drills.

The scorecard is useful for executive reporting, audit evidence, and operational
trend reviews. It is not an Oracle certification and should be interpreted
together with the scenario runbooks and raw evidence artifacts.

### APEX/ORDS Application Access Path

CrashSimulator now treats APEX/ORDS as part of recoverability because many
users experience the database through ORDS, APEX, REST APIs, or Database
Actions.

Capabilities include:

- APEX/ORDS readiness report.
- ORDS service unavailable drill.
- ORDS configuration unavailable drill.
- ORDS database pool misconfiguration drill.
- APEX/ORDS runtime account lockout drill.
- APEX static resources unavailable drill.
- APEX availability validation after database/PDB/service recovery.
- ORDS node unavailable behind a load balancer.
- APEX session continuity evidence, with optional browser-session driver.
- APEX mail queue and configuration validation.
- APEX upgrade or patch rollback readiness.

### Autonomous Database Coverage

Autonomous Database is handled differently because customers do not directly
manage host-level datafiles, control files, redo files, ASM disks, SPFILEs,
ORACLE_HOME, or RMAN backup pieces.

For ADB, CrashSimulator focuses on realistic cloud-service resilience practice:

- Logical/user-error recovery.
- Clone and point-in-time recovery readiness.
- Backup recoverability evidence.
- Wallet and client connectivity.
- Private endpoint and network posture.
- Resource limit and connection pool pressure.
- Autonomous Data Guard readiness.
- IAM administrator access posture.
- Object Storage export/import dependencies.
- APEX and Database Actions URL availability.

The ADB family contains `ADB01` through `ADB20`. Current ADB implementation is
readiness/report driven. The readiness report includes an ADB domain scorecard
for Backup Readiness, PITR Validation, Autonomous Data Guard Protection,
Cross-Region DR, IAM/administrator access, Wallet Management, Private Endpoint
Validation, Resource Manager, Logical/Object Recovery, and Application Access
Path. OCI-only domains remain `PARTIAL` or `GAP` until OCI metadata or measured
drill evidence is available, so SQL connectivity alone does not overstate ADB
recoverability.

Future seeded logical and OCI control-plane helpers are planned.

### Audit, Compliance, And Training Evidence

CrashSimulator can retain durable per-run audit archives. Audit retention can
be enabled or disabled, and a retention period in days can be configured. The
purge process supports dry-run and execute modes.

Audit evidence can include:

- Redacted command metadata.
- Redacted environment context.
- Generated manifests.
- Runbooks.
- SQL, RMAN, and log artifacts.
- Reports and HTML copies.
- Exit status and artifact indexes.

### Configuration File Support

CrashSimulator can read non-secret defaults from a configuration file. This is
useful when users do not want to repeatedly export values such as
`ORACLE_HOME`, `ORACLE_SID`, PDB name, log directory, ORDS URL, ADB wallet
directory, ADB alias, or audit preferences.

Precedence is:

1. CLI arguments.
2. Existing shell environment.
3. Configuration file.
4. Built-in defaults.

The configuration file is parsed as allowlisted `KEY=value` entries and is not
sourced as shell code. Passwords, wallet passwords, tokens, and private keys
should not be stored in it.

### Tutorial And Reference Assets

The repository includes tutorial videos, subtitles, screenshots, sample
reports, and reference outputs for documentation and promotional use.

Current tutorial families include:

- CLI setup and scenario execution.
- Guided Workflow scenario execution.
- Audit retention.
- Scenario readiness.
- Guided Reports menu.
- Configuration and evidence review.
- Autonomous Database readiness.
- Autonomous Database scenario browsing.
- APEX/ORDS session continuity.
- General CrashSimulator best practices.

## Typical End-To-End Workflow

A recommended drill flow is:

1. Confirm the environment is a lab or approved resilience-test system.
2. Run discovery.
3. Generate scenario readiness and lifecycle reports.
4. Choose a scenario that is valid for the current topology.
5. Read the runbook.
6. Run dry-run.
7. Confirm backups and recovery path.
8. Run protection where supported.
9. Execute the drill only with explicit approval.
10. Recover using the manifest and helper guidance.
11. Validate database, PDB, service, application, RMAN, corruption, and
    open-state evidence.
12. Preserve logs, manifests, reports, HTML, and audit evidence.
13. Refresh the backup baseline after higher-risk drills.
14. Record lessons learned and update operational runbooks.

## What CrashSimulator Is Not

CrashSimulator is not:

- A production chaos tool.
- A replacement for Oracle support, Oracle documentation, or official MAA
  certification.
- A substitute for validated backups.
- A substitute for change control.
- A security product.
- A complete web GUI.
- A full OCI control-plane orchestrator yet.
- A guarantee that every recovery path will work in every customer topology.

It is a resilience validation framework that helps teams practice, measure, and
improve.

## Current Limitations

Known limitations for `v2.0.2 beta`:

- Destructive drills should be used only in non-production or explicitly
  approved lab environments.
- Some scenarios are intentionally plan-only or readiness-only until the
  current topology, privileges, and recovery design are confirmed.
- Autonomous Database scenarios are currently focused on readiness/reporting and
  scenario detail. Seeded ADB logical execution helpers and OCI control-plane
  clone/PITR/ADG helpers are roadmap items.
- Provider-managed storage such as FEX/ACFS-style environments requires
  provider-aware procedures. CrashSimulator can plan and validate posture, but
  destructive storage actions must remain controlled and approved.
- GI/OCR/voting-disk and low-level ASM failure drills require purpose-built
  redundant labs and appropriate Grid/root privileges.
- APEX/ORDS destructive drills require ORDS configuration visibility, service
  control, URLs, and sometimes a restricted OS privilege helper.
- RAC, Data Guard, FSFO, AC/TAC, and service-placement scenarios require
  matching topology and operational approvals.
- RTO/RPO calculations are evidence-based estimates unless the organization
  supplies explicit SLA targets and runs measured recovery drills.
- Reports may use best-effort signals where Oracle views, licensed diagnostic
  sources, OCI metadata, or OS privileges are unavailable.
- The Guided Workflow menu is terminal-based, not browser-based.
- CrashSimulator does not store secrets by design; users must supply sensitive
  values through environment variables, secure wallets, or approved external
  mechanisms.

## Safety Model

CrashSimulator's safety posture is based on:

- Dry-run by default.
- Explicit `--execute` for destructive actions.
- Typed confirmation tokens.
- Scenario validation before execution.
- Topology-aware guards.
- PDB/schema/FILE# selection prompts in the Guided Workflow menu.
- Local-only and max-target guards for selected file-oriented scenarios.
- Manifests preserved until recovery validation passes.
- No password storage in configuration files.
- Redaction of sensitive values in command echoes and reports where supported.
- Plan-only posture for scenarios that need external provider, Grid, IAM, or
  network approval.

## Current Roadmap Ideas

Likely roadmap areas include:

- Seeded ADB logical helpers for `ADB01`, `ADB03`, and `ADB04`.
- OCI control-plane helpers for ADB clone, PITR, Autonomous Data Guard, backup,
  IAM, and Object Storage scenarios.
- Richer ADB readiness scoring using OCI metadata when the OCI CLI and OCIDs
  are supplied.
- More automated lifecycle coverage for scenarios that are currently plan-only.
- Expanded ASM/GI/FEX/ACFS lab helpers for redundant disk, failgroup, OCR, and
  voting-disk practice.
- More Data Guard and FSFO execution drills, including observer placement,
  failover/failback, and reinstate workflows.
- Stronger AC/TAC, FAN, ONS, service role, and application-session validation.
- A browser-based or APEX-based UI while retaining CLI parity.
- A more formal SLA recommendation engine that maps application RTO/RPO needs
  to current topology gaps and recommended scenarios.
- More reference reports for 12c, 18c, 19c, 21c, 23ai, 26ai, Exadata,
  Autonomous Database, RAC, Data Guard, and hybrid topologies.
- Contributor-friendly scenario metadata and test harnesses.
- Additional tutorials, quick-start labs, and sample training exercises.
- More structured evidence export for audit and compliance systems.

## Suggested Contribution Areas

Open-source contributors can add value by improving:

- Scenario validations and blocker messages.
- Recovery helper coverage.
- Topology-specific runbooks.
- ADB and OCI helpers.
- APEX/ORDS session validation.
- RAC/Data Guard service behavior tests.
- ASM/GI safety checks.
- Documentation and screenshots.
- Reference lab designs.
- Translation and simplified end-user guidance.
- Test harnesses for shell, SQL, RMAN, and report rendering.

## Getting Started

Recommended first commands:

```bash
./CrashSimulatorV2.sh --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --list-adb-scenarios
./CrashSimulatorV2.sh --scenario-readiness-report --html
./CrashSimulatorV2.sh --scenario-lifecycle-report --html
./CrashSimulatorV2.sh --config-report --html
./CrashSimulatorV2.sh --backup-report --html
./CrashSimulatorV2.sh --maa-report --html
./CrashSimulatorV2.sh --review --html
./CrashSimulatorV2.sh --menu
```

Recommended first drills in a lab:

- Tempfile loss, scenarios `6` and `31`.
- Logical seeded object drills, scenarios `11`, `36`, `43`, and `44`.
- Password file and SPFILE drills, scenarios `16` and `26`.
- Local backup-piece drill, scenario `25` with `--local-only --max-targets 1`.
- Archived-log decision drills, scenarios `59` and `62`.
- Read-only RTO/RPO validation, scenarios `64` and `65`.
- APEX/ORDS readiness and smoke drills when APEX/ORDS are installed.
- ADB readiness report and ADB scenario browsing from a configured ADB client
  or bastion host.

## Related Documentation

- `README.md`: short project entry point.
- `README_V2.md`: detailed V2 usage notes.
- `docs/CRASHSIMULATOR_USER_GUIDE.md`: full end-user guide and scenario
  catalog.
- `docs/AUTONOMOUS_DATABASE_COVERAGE.md`: ADB coverage model.
- `SCENARIO_STATUS.md`: current validation status, tested labs, and gaps.
- `docs/reference/scenario_registry_123_reference.md`: current scenario catalog
  reference.
- `docs/reference/README.md`: sample reports and reference evidence.
- `assets/tutorial/README.md`: tutorial video catalog.

## Final Positioning

CrashSimulator v2.0.2 beta is best understood as an Oracle resilience practice
platform. It brings together controlled failure simulation, topology-aware
scenario validation, recovery runbooks, MAA and backup readiness reporting,
APEX/ORDS and Autonomous Database awareness, audit evidence retention, and
guided workflows.

Its core value is not only breaking something safely. Its core value is helping
teams prove, measure, document, and improve their ability to recover.
