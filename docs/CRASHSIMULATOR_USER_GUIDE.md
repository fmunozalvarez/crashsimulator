# CrashSimulator End-User Guide

CrashSimulator is an open-source resilience validation platform for Oracle
Database environments. It helps teams practice controlled failures and recovery
procedures before a real outage happens.

Use it to answer practical questions:

- Can we restore and recover the database, PDB, or file we think we can recover?
- Do our backups, archived logs, wallet files, password files, and configuration
  backups really support our RTO and RPO objectives?
- Does RAC, Grid Infrastructure, ASM, Data Guard, Active Data Guard, or the
  listener behave the way our HA/DR runbooks expect?
- Are DBAs, SREs, operations teams, and application owners familiar with the
  recovery steps and validation evidence?

CrashSimulator is a lab and validation tool. Run destructive scenarios only in
approved non-production or dedicated resilience-test environments.

## Who Should Use This Guide

This guide is for DBAs, infrastructure engineers, SREs, application owners, and
auditors who need a simple explanation of what CrashSimulator does and how to use
it safely.

The tool is designed for Oracle Database 12c and later, including non-CDB and
CDB/PDB environments. Current validation has focused on Oracle Database 19c, with
work covering standalone, OCI Base Database Service, RAC One Node or
GI-managed single-database, filesystem/LVM, ASM, and early Data Guard/Active Data
Guard scenario registration.

## Safety Model

CrashSimulator is intentionally conservative:

- `--dry-run` is the default. It plans and prints actions without changing the
  database or files.
- Destructive actions require `--execute`.
- Most destructive actions also require a typed confirmation token such as
  `EXECUTE-30`, `PROTECT-30`, or `RECOVER-30`.
- The tool records manifests, command files, and logs under
  `./crashsimulator_logs` unless another log directory is provided.
- Recovery runbook hints are printed before destructive scenario execution.
- Filesystem actions refuse ASM paths such as `+DATA/...` unless the scenario has
  an ASM-aware helper.

Recommended safety rule: every scenario should follow this sequence:

1. Discover the environment.
2. List and understand the scenario.
3. Show the recovery runbook.
4. Validate whether the scenario can run in the current topology.
5. Dry-run the scenario.
6. Run `--protect` when available.
7. Execute the scenario only after backups and recovery steps are confirmed.
8. Recover using the manifest from the executed scenario.
9. Validate the database, PDB, services, corruption views, RMAN restore/validate
   evidence, and application checks.
10. Take a fresh post-drill backup after meaningful recovery work.

## Important Terms

`CDB`: A container database. It contains the root container, seed, and one or
more pluggable databases.

`PDB`: A pluggable database inside a CDB. Many application schemas live inside a
PDB.

`non-CDB`: An older-style database that is not a container database.

`SYSDBA`: A privileged administrative database connection. CrashSimulator usually
connects locally as `/ as sysdba`.

`RMAN`: Oracle Recovery Manager. It is used for backup, restore, recovery,
validation, restore preview, and recovery catalog operations.

`recovery catalog`: A separate RMAN metadata repository. CrashSimulator can test
catalog availability and the fallback to control-file metadata.

`control file`: A critical database file that records database structure, redo
history, checkpoint information, and backup metadata.

`redo log`: Online redo log files record database changes. Redo is essential for
crash recovery and media recovery.

`archived redo log`: A saved copy of redo generated after a log switch. Archived
logs are critical for point-in-time recovery and Data Guard.

`datafile`: A physical file that stores table, index, undo, dictionary, and other
database segment data.

`SYSTEM tablespace`: The core dictionary tablespace. Losing it is high impact
and normally requires mount-mode recovery.

`UNDO tablespace`: Stores undo records used for transaction rollback and read
consistency.

`temporary tablespace`: Stores temporary sort/hash/work files. Tempfiles can
usually be recreated rather than media recovered.

`tablespace`: A logical storage container made of one or more datafiles or
tempfiles.

`SPFILE`: Server parameter file. It stores database initialization parameters.

`password file`: File used for remote privileged authentication such as remote
SYSDBA and SYSBACKUP.

`SQL*Net files`: Network configuration files such as `listener.ora`,
`tnsnames.ora`, and `sqlnet.ora`.

`listener`: Oracle Net process that accepts client connections and registers
database services.

`FRA`: Fast Recovery Area. A managed location for archived logs, backups,
flashback logs, and recovery-related files.

`ASM`: Automatic Storage Management. Oracle storage layer that uses disk groups
such as `+DATA` and `+RECO`.

`Grid Infrastructure`: Oracle cluster and ASM infrastructure. It includes CRS,
OCR, voting disks, ASM, and resource management.

`OCR`: Oracle Cluster Registry. It stores cluster configuration metadata.

`voting disk`: Grid Infrastructure file used for cluster membership decisions.

`RAC`: Real Application Clusters. Multiple instances open the same database for
local HA and scale-out.

`RAC One Node`: A single active RAC-style instance that can relocate between
cluster nodes.

`Data Guard`: Oracle disaster recovery technology using primary and standby
databases.

`Active Data Guard`: Data Guard with a physical standby open read-only while redo
apply continues.

`FSFO`: Fast-Start Failover. Broker-managed automatic Data Guard failover with an
observer.

`TDE wallet or keystore`: Encryption key store required for Transparent Data
Encryption.

`MAA`: Oracle Maximum Availability Architecture. A reference architecture model
for availability, data protection, backup/recovery, and operational practices.

`RTO`: Recovery Time Objective. How long recovery is allowed to take.

`RPO`: Recovery Point Objective. How much data loss is acceptable.

`manifest`: A CrashSimulator file that links a drill to targets, backups,
renamed files, RMAN command files, logs, and recovery metadata.

`protect`: A pre-drill action that backs up or records the exact target needed
for recovery.

`recover`: A recovery helper that uses the scenario manifest and generated
RMAN/SQL/OS steps where automation is available.

`aleatory scenario`: A random scenario selected from the discovered topology.
The tool still uses dry-run, runbook hints, and confirmation gates.

## Installation From A ZIP File

Download the repository ZIP from GitHub, copy it to the database server, and
unzip it as the Oracle software owner or another OS user allowed to become the
Oracle owner.

Example:

```bash
unzip crashsimulator-main.zip
cd crashsimulator-main
chmod +x CrashSimulatorV2.sh
```

CrashSimulator V2 requires:

- Bash 4 or later.
- Oracle environment variables for the target database session.
- SQL*Plus and RMAN in `PATH`.
- Local OS authentication as SYSDBA, or a working `--sqlplus-logon` string.
- Optional Grid Infrastructure tools such as `srvctl`, `crsctl`, `ocrcheck`, and
  `asmcmd` for RAC, GI, and ASM scenarios.

For a typical Oracle Linux database host:

```bash
sudo su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0.0/dbhome_1
export ORACLE_SID=orcl
export PATH=$ORACLE_HOME/bin:$PATH
cd /path/to/crashsimulator-main
./CrashSimulatorV2.sh --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --menu
```

If the ZIP was renamed by the browser, the directory may be
`crashsimulator-main`, `crashsimulator-master`, or another name. The important
point is to run the commands from the directory containing `CrashSimulatorV2.sh`.

Recommended first checks after unzipping:

```bash
ls CrashSimulatorV2.sh crashsim_run_baseline_backup.sh seed_crashsim_lab.sql verify_crashsim_lab.sql
./CrashSimulatorV2.sh --help
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --discover
```

## Common Commands

```bash
./CrashSimulatorV2.sh --menu
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --config-report --deep-validate
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --backup-report --deep-validate
./CrashSimulatorV2.sh --baseline-backup --dry-run
./CrashSimulatorV2.sh --audit-status
./CrashSimulatorV2.sh --maa-report
./CrashSimulatorV2.sh --runbook 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --protect 30 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --execute
./CrashSimulatorV2.sh --recover 30 --pdb CRASHPDB --manifest ./crashsimulator_logs/<scenario_manifest>.manifest --execute
./CrashSimulatorV2.sh --random-scenario --pdb CRASHPDB --dry-run
```

## Guided Workflow Menu

Run the menu with:

```bash
./CrashSimulatorV2.sh
./CrashSimulatorV2.sh --menu
```

The menu provides options to:

- Discover or refresh database topology.
- Select a scenario.
- List all scenarios.
- Validate whether the selected scenario can run now.
- Show recovery runbook hints.
- Dry-run a scenario.
- Dry-run or execute protection.
- Execute a scenario.
- Dry-run or execute recovery.
- Run health checks.
- Configure PDB, schema, FILE#, manifest, PFILE, log directory, password-file
  recovery, RMAN catalog, and scenario 25 guardrails.
- Show recent manifests and logs.
- Dry-run or execute an aleatory scenario for the detected topology.
- Validate all scenarios for the detected topology.
- Generate configuration, backup strategy/recoverability, and MAA readiness
  reports.
- Configure audit retention, show audit status, and purge old audit records.
- Review previously collected topology, runbooks, reports, scenario manifests,
  health checks, dry-run/execution records, and audit history.
- Create optional HTML copies of reports and logs for easier viewing.

The menu calls the same script in CLI mode, so menu usage and command-line
automation behave consistently.

The menu groups safe planning actions separately from execution actions that
require typed confirmation tokens such as `EXECUTE-30`, `PROTECT-30`, or
`RECOVER-30`. Menu-launched child commands keep sensitive values out of the
printed command line; RMAN catalog connect strings and SYS passwords are shown
only as redacted environment values.

## Functional Capabilities

### Discovery

`--discover` identifies the target database posture: database name, role, open
mode, CDB/PDB status, selected PDB, storage type, ASM/GI/RAC signals, Data Guard
signals, FRA configuration, and other topology evidence.

### Scenario Registry

`--list` prints all registered scenarios with ID, group, scope, impact, and
scenario name. The current registry contains 60 scenarios.

### Dry-Run Planning

`--dry-run` prints target selection and planned action without changing files or
database state. It is the default mode.

### Scenario Readiness Validation

`--validate-scenario <id>` checks whether one scenario can run at this moment.
It uses the same topology gates and target-selection logic as execution, but in
non-destructive planning mode.

Example:

```bash
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --validate 25 --local-only --max-targets 1
```

If the scenario is runnable, the result is `RUNNABLE`. If it is not executable
but can still show useful dry-run planning evidence, the result is
`NOT RUNNABLE (dry-run planning only)`. Otherwise the tool prints:

```text
Scenario <id> is not possible to run at this moment.
Reason: <specific blocker>
```

Common blockers include:

- The database is not in the required role, such as primary or standby.
- The target topology is missing, such as CDB/PDB, ASM, GI, RAC, or Data Guard.
- The requested PDB does not exist.
- No suitable target exists, such as no read-only tablespace, no index-only
  tablespace, no non-unique index, no local backup piece, or no archived log.
- The selected file is in ASM or provider-managed storage and that specific
  scenario still needs a safe ASM-aware or provider-aware execution helper.
- Scenario 25 guardrails are missing.
- The scenario is registered as a future placeholder but no runnable handler is
  implemented yet.

Use `--validate-all-scenarios` to produce a full runnable/not-runnable matrix:

```bash
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
```

Scenario execution runs this readiness validation before confirmation or
destructive code. A blocked `--execute` run stops immediately. Some blocked
scenarios can still continue in `--dry-run` so users can see planning evidence,
for example ASM/GI provider-specific targets or broad scenario 25 backup-piece
selection. Aleatory scenario selection also uses readiness validation, so random
drills choose only scenarios that are runnable in the current topology.

### Runbook Hints

`--runbook <id>` prints scenario-specific recovery guidance. The same hints are
printed before destructive execution.

### Protection

`--protect <id>` prepares a recovery baseline for supported datafile scenarios.
It records metadata and can generate or run targeted RMAN backups before a
destructive drill.

Automated protection currently supports scenarios `5`, `7`, `14`, `17`, `30`,
`32`, `39`, and `41`.

### Crash Injection

`--scenario <id>` plans or executes the selected scenario. Filesystem targets are
usually renamed or corrupted only after a backup copy is created. Logical
scenarios run SQL actions such as dropping a controlled table, index, or schema.
ASM/GI targets use ASM/GI-aware planning and execute only where a safe handler is
implemented.

### Recovery Helpers

`--recover <id>` uses the executed scenario manifest to plan or run recovery.

Automated recovery currently covers scenarios `1`, `2`, `3`, `4`, `5`, `6`,
`7`, `8`, `9`, `10`, `12`, `13`, `14`, `15`, `16`, `17`, `18`, `19`, `20`,
`21`, `22`, `23`, `24`, `25`, `26`, `27`, `30`, `31`, `32`, `33`, `34`,
`35`, `37`, `38`, `39`, `40`, `41`, `42`, `55`, `56`, `57`, `58`, and `59`.

For unsupported scenarios, use `--runbook <id>` and the generated target
evidence to perform the recovery manually.

### Health Check

`--health-check` runs non-destructive SQL checks for open state, PDB state,
recovery-needed rows, corruption rows, and related validation evidence.

### Configuration Report

`--config-report` generates a Markdown report with database, PDB, redo, control
file, datafile, tempfile, tablespace, FRA, Oracle Home, listener, RMAN backup,
corruption, TDE, Data Guard, FSFO, GI, ASM, OCR, and voting-disk evidence where
available.

`--deep-validate` adds heavier RMAN validation and should be scheduled when I/O
load is acceptable.

### Backup Strategy And Recoverability Report

`--backup-report` generates a focused backup report using the target control-file
RMAN repository and, when configured, an RMAN recovery catalog. It reports backup
coverage by datafile, Level 0/Level 1 cadence, archived redo backup cadence,
backup piece status, failed jobs, FRA pressure, files needing recovery,
corruption views, restore preview, need-backup/obsolete reports, and
recommendations against backup/recovery best practices.

The report estimates backup-only RPO from archived redo backup age and unbacked
archived redo. It estimates possible RTO from visible database size, backup
method, backup age, and observed backup job durations. These are planning
estimates only; real RTO/RPO must be proven with timed restore, recovery, and
application validation drills.

```bash
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --backup-report --deep-validate
CRASHSIM_RMAN_CATALOG='rcat/password@//host:1521/service' ./CrashSimulatorV2.sh --backup-report
```

`--deep-validate` adds read-only but I/O-intensive RMAN checks:
`RESTORE DATABASE VALIDATE`, `RESTORE ARCHIVELOG ALL VALIDATE`, and
`VALIDATE DATABASE CHECK LOGICAL`.

Sanitized examples are available under `docs/reference/`, including default
target-control-file, recovery-catalog-backed, and deep-validation report output.

### Fresh Baseline Backup

`--baseline-backup` runs the official `crashsim_run_baseline_backup.sh` helper
from the framework. It is intended for post-drill stabilization and for creating
a known fresh backup baseline before higher-risk scenarios.

Dry-run is the default:

```bash
./CrashSimulatorV2.sh --baseline-backup --dry-run
./CrashSimulatorV2.sh --baseline-backup --execute
CRASHSIM_RMAN_CATALOG='rcat/password@//host:1521/service' ./CrashSimulatorV2.sh --baseline-backup --execute
```

When executed, the helper creates a forced compressed database backup, backs up
archived redo not already backed up once, backs up the current control file and
SPFILE, lists the generated backup tags, and writes RMAN command/log files under
`crashsimulator_logs`. Use `--backup-tag-prefix` or
`CRASHSIM_BASELINE_TAG_PREFIX` to change the default `CSIM_BASE` tag prefix.

### Audit Retention And Purge

CrashSimulator can keep a dedicated per-run audit archive for compliance,
training, and post-drill review. Audit retention is enabled by default.

The default audit directory is `./crashsimulator_logs/audit`. Each run gets a
folder similar to:

```text
crashsimulator_logs/audit/YYYY-MM-DD/crashsim_audit_<run_id>_<pid>/
```

Each audit run folder contains:

- `metadata.env`: run id, mode, user, host, log directory, audit policy, and
  exit status.
- `command.redacted`: the command line with sensitive values redacted.
- `environment.redacted`: selected environment evidence with password, token,
  credential, and key-like variables redacted.
- `stdout.log` and `stderr.log`: redacted terminal output from the run.
- `artifacts.index`: source and copied audit artifact paths.
- `artifacts/`: redacted copies of generated text artifacts such as `.rman`,
  `.sql`, `.manifest`, `.log`, `.evidence`, and `.md` files.

Common commands:

```bash
./CrashSimulatorV2.sh --audit-status
./CrashSimulatorV2.sh --audit-retain yes --audit-retention-days 365 --audit-status
./CrashSimulatorV2.sh --audit-dir /secure/audit/crashsimulator --audit-status
./CrashSimulatorV2.sh --purge-audit-logs --dry-run
./CrashSimulatorV2.sh --purge-audit-logs --execute
```

Environment defaults:

```bash
export CRASHSIM_AUDIT_RETAIN=1
export CRASHSIM_AUDIT_RETENTION_DAYS=365
export CRASHSIM_AUDIT_DIR=/secure/audit/crashsimulator
```

The purge process removes audit run folders older than the configured retention
period. It is dry-run by default. Execution requires `--execute` and the
`PURGE-AUDIT-LOGS` confirmation token unless `--yes` is supplied by trusted
automation.

### Review Center And HTML Output

The Review Center helps users inspect information that CrashSimulator already
collected. It does not run a new crash scenario and does not need to reconnect to
the database for the review index. This is useful for operators, auditors, and
training sessions where users need to revisit topology, scenario plans,
runbooks, dry-runs, recovery attempts, health checks, reports, and audit
records.

Common CLI commands:

```bash
./CrashSimulatorV2.sh --review
./CrashSimulatorV2.sh --review --html
./CrashSimulatorV2.sh --review-topology
./CrashSimulatorV2.sh --show-artifact latest:topology
./CrashSimulatorV2.sh --show-artifact latest:runbook --html
./CrashSimulatorV2.sh --render-html latest:backup
```

The Guided Workflow menu includes a Review Center option with choices to:

- Show the latest collected topology snapshot.
- Generate HTML for the latest topology snapshot.
- Build a review index across collected manifests, runbooks, reports, health
  checks, baseline plans/logs, and audit records.
- Show a stored artifact as text.
- Generate an HTML copy of a stored artifact.
- List recent manifests, logs, reports, and HTML files.

`--html` creates an additional `.html` file next to the normal output. It does
not replace the existing `.log`, `.md`, `.txt`, `.rman`, `.sql`, or `.manifest`
files. Use `--render-html <path>` to convert one known artifact, or
`--render-html latest:<kind>` to convert the latest artifact of a type.
Supported shortcuts include `topology`, `config`, `backup`, `maa`, `health`,
`scenario`, `protect`, `recover`, `runbook`, `baseline`, `review`, `audit`, and
`latest`.

### MAA Readiness Report

`--maa-report` generates a best-effort Oracle MAA posture report. It maps
observable evidence to Bronze, Silver, Gold, Platinum, or Diamond-style
capability levels and records RTO/RPO planning context.

Example:

```bash
./CrashSimulatorV2.sh --maa-report \
  --maa-app-name Payroll \
  --maa-local-rto "less than 1 minute" \
  --maa-local-rpo zero \
  --maa-dr-rto "less than 1 hour" \
  --maa-dr-rpo zero
```

This is not an Oracle certification. It is a readiness assessment that helps
teams identify gaps and choose drills.

### Aleatory Scenario

`--random-scenario` or `--aleatory-scenario` lets the tool choose an implemented
scenario that is compatible with the detected topology. Random execution still
requires normal confirmation gates.

### Logical Lab Seed Objects

`seed_crashsim_lab.sql` creates controlled lab schemas and objects for logical
object-loss scenarios. Re-run it after scenarios that intentionally drop test
tables, schemas, or indexes.

```bash
sqlplus / as sysdba @seed_crashsim_lab.sql
sqlplus / as sysdba @verify_crashsim_lab.sql
```

## Best Practices For Running Drills

### Start With Reports And Dry-Runs

Run these before the first destructive scenario in any new environment:

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --maa-report
```

Use `--config-report --deep-validate` when the environment can tolerate the RMAN
I/O.

### Confirm Backups Before Destructive Tests

Before destructive drills, confirm:

- Last full backup and incremental backup status.
- Archived log backup status.
- Control file and SPFILE autobackups.
- TDE wallet backup if TDE is enabled.
- Password file backup or recreation procedure.
- Listener and SQL*Net configuration backup.
- Data Guard standby health if testing primary-side scenarios.
- Recovery catalog availability, if used.

### Use The Manifest

Recovery helpers depend on the executed scenario manifest. Do not recover from a
dry-run-only manifest.

Example:

```bash
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --execute
./CrashSimulatorV2.sh --recover 30 --pdb CRASHPDB \
  --manifest ./crashsimulator_logs/crashsim_scenario_s30_<run_id>.manifest \
  --execute
```

### Validate After Every Drill

At minimum, validate:

- Database open mode.
- PDB open mode for PDB scenarios.
- `V$RECOVER_FILE`.
- `V$DATABASE_BLOCK_CORRUPTION`.
- RMAN `restore validate` or `backup validate` where appropriate.
- Listener and service status.
- Application smoke tests.
- Alert log and trace evidence.
- No unwanted `.crashsim.bak` leftovers.

### Take A Stabilization Backup

After recovery changes file names, restores OMF files, recreates SPFILE/password
files, or performs incomplete recovery, take a fresh baseline backup.

### Keep Scope Small

Use one scenario at a time until the team has strong evidence and confidence.
For scenario 25, always limit the target:

```bash
./CrashSimulatorV2.sh --scenario 25 --local-only --max-targets 1 --dry-run
./CrashSimulatorV2.sh --scenario 25 --local-only --max-targets 1 --execute
```

### Use Purpose-Built Labs For GI And Storage Loss

Do not test destructive OCR, voting disk, ASM disk group, ASM SPFILE, or current
redo loss in a lab that cannot tolerate it. Use redundant test clusters and
pre-approved root/Grid procedures.

### Treat Data Guard Separately

For Data Guard and Active Data Guard drills, include:

- Primary and standby roles.
- Broker configuration.
- Transport and apply lag.
- Archive gaps.
- FSFO observer status.
- Application failover and reconnection behavior.

### Document The Human Timeline

For every drill, record:

- Fault injection time.
- Detection time.
- Incident declaration time.
- Recovery decision time.
- Restore start time.
- Database/PDB open time.
- Application validation time.
- Backup baseline refresh time.

This is how a technical recovery becomes a measured RTO/RPO exercise.

## Scenario Catalog

Impact meanings:

- `destructive`: Can remove, rename, corrupt, or make unavailable database or
  infrastructure files. Use only with dry-run, protection, and approvals.
- `logical`: Changes logical state such as indexes, schemas, Data Guard apply
  state, service behavior, or catalog connectivity. It can still affect users.

Scope meanings:

- `CDB/non-CDB`: Applies to either a CDB root or a non-CDB target.
- `PDB`: Requires `--pdb <name>`.
- `ASM`, `Cluster`, `RAC`, `Standby`, `Primary`, `DG`, or `External`: Requires
  that topology or external component.

| ID | Scenario | Area | Scope | Impact | What users practice | Key notes |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | Loss of one control file | Core | CDB/non-CDB | destructive | Control file multiplexing and restoring a missing member from a surviving copy. | Recovery helper available. Best when control files are multiplexed. |
| 2 | Loss of all control files | Core | CDB/non-CDB | destructive | Restoring control file from autobackup or known copy and recovering/opening the database. | Recovery helper available. Expect higher risk and possible RESETLOGS decisions. |
| 3 | Loss of one member from current redo group | Core | CDB/non-CDB | destructive | Current redo member failure handling and redo multiplexing validation. | Recovery helper available where the target can be removed. ASM/current redo may need storage-level fault injection. |
| 4 | Loss of all members from current redo group | Core | CDB/non-CDB | destructive | Current redo loss decision-making, incomplete recovery, and RPO validation. | Recovery helper available. High risk. |
| 5 | Loss of one non-system datafile | Core | CDB/non-CDB | destructive | Online or offline datafile restore and recover. | Protection and recovery helpers available. Good early datafile drill. |
| 6 | Loss of one temporary file | Core | CDB/non-CDB | destructive | Tempfile recreation without media recovery. | Recovery helper available. Usually lower risk. |
| 7 | Loss of one SYSTEM datafile | Core | CDB/non-CDB | destructive | Mount-mode SYSTEM datafile restore/recover. | Protection and recovery helpers available. High impact. |
| 8 | Loss of one UNDO datafile | Core | CDB/non-CDB | destructive | UNDO datafile failure and transaction recovery behavior. | Protection and recovery helpers available. ASM targets use `asmcmd rm` plus FILE# restore/recover. |
| 9 | Loss of a read-only tablespace | Core | CDB/non-CDB | destructive | Restore of read-only tablespace files and backup strategy for read-only data. | Controlled CDB-root target `CRASHSIM_ROOT_RO_TBS` is created by the seed script. Protection and recovery helpers available. |
| 10 | Loss of an index-only tablespace | Core | CDB/non-CDB | destructive | Rebuild or restore of index-only storage. | Controlled CDB-root target `CRASHSIM_ROOT_INDEX_TBS` is created by the seed script. Protection and recovery helpers available. |
| 11 | Drop non-unique indexes outside Oracle schemas | Logical | CDB/non-CDB | logical | Rebuilding dropped non-unique indexes from DDL or deployment source. | Use `--schema` to constrain targets. Re-run seed script after testing. |
| 12 | Loss of a non-system tablespace | Core | CDB/non-CDB | destructive | Tablespace-level restore and recover. | Protection and recovery helpers available for selected FILE# targets. |
| 13 | Loss of a temporary tablespace | Core | CDB/non-CDB | destructive | Temporary tablespace repair and default temp tablespace validation. | Recovery helper available, including ASM tempfile removal and metadata repair. |
| 14 | Loss of SYSTEM tablespace | Core | CDB/non-CDB | destructive | Full SYSTEM tablespace restore/recover in mount mode. | Protection and recovery helpers available. Very high impact. |
| 15 | Loss of UNDO tablespace | Core | CDB/non-CDB | destructive | UNDO tablespace restore/recover and database open behavior. | Protection and recovery helpers available. Requires careful planning and validation. |
| 16 | Loss of password file | Config | CDB/non-CDB | destructive | Password-file recreation and remote SYSDBA/SYSBACKUP validation. | Recovery helper available. Use `--sys-password` or `CRASHSIM_SYS_PASSWORD`. |
| 17 | Loss of all datafiles | Core | CDB/non-CDB | destructive | Whole-database restore/recover. | Protection and recovery helpers available. Very high impact. |
| 18 | Loss of one member from multiplexed redo group | Core | CDB/non-CDB | destructive | Redo multiplexing and restoring/recreating a lost member. | Recovery helper available. Requires a redo group with multiple members. |
| 19 | Loss of all inactive redo groups | Core | CDB/non-CDB | destructive | Clearing/recreating inactive redo groups and validating log switching. | Recovery helper available. |
| 20 | Loss of all active redo groups | Core | CDB/non-CDB | destructive | Active redo loss decisions and RPO exposure. | Recovery helper available. High risk. |
| 21 | Loss of all current redo group members | Core | CDB/non-CDB | destructive | Current redo total loss and incomplete recovery/failover decisions. | Recovery helper available. High risk. |
| 22 | Datafile header corruption | Corrupt | CDB/non-CDB | destructive | Detecting and recovering a corrupted datafile header. | Filesystem targets use header corruption; ASM targets use a documented loss-style surrogate and FILE# recovery. |
| 23 | Control file corruption | Corrupt | CDB/non-CDB | destructive | Control file corruption response and restore from clean copy/autobackup. | Recovery helper available. |
| 24 | Redo log corruption | Corrupt | CDB/non-CDB | destructive | Redo corruption detection and recovery decision-making. | Recovery helper available. High risk for active/current redo. |
| 25 | Loss of RMAN backup pieces | Backup | CDB/non-CDB | destructive | Backup-piece loss, crosscheck, restore from secondary storage, and validate. | Recovery helper available for local filesystem pieces. Use `--local-only --max-targets 1` or `--piece-handle`. |
| 26 | Loss of SPFILE | Config | CDB/non-CDB | destructive | Recreating SPFILE from PFILE, memory, backup, or metadata. | Recovery helper available. RAC/ASM requires srvctl/ASM metadata validation. |
| 27 | Loss of SQL*Net config files | Config | CDB/non-CDB | destructive | Restoring `listener.ora`, `tnsnames.ora`, and `sqlnet.ora`. | Recovery helper available for filesystem rename backups. Also used by scenario 57. Validate local and remote connectivity. |
| 28 | Loss of ORACLE_HOME | Config | CDB/non-CDB | destructive | Oracle Home restore/reinstall and inventory/network/dbs recovery. | Manual-only guardrail. Requires an external restore/reinstall plan. |
| 29 | Loss of FRA destination | Backup | CDB/non-CDB | destructive | Recreating FRA path, permissions, capacity, and backup/archivelog posture. | Validate RMAN metadata and archived log availability after recovery. |
| 30 | PDB loss of one non-system datafile | PDB | PDB | destructive | PDB-scoped datafile restore/recover. | Requires `--pdb`. Protection and recovery helpers available. |
| 31 | PDB loss of one temporary file | PDB | PDB | destructive | PDB tempfile recreation and temp workload validation. | Requires `--pdb`. Recovery helper available. |
| 32 | PDB loss of one SYSTEM datafile | PDB | PDB | destructive | PDB SYSTEM datafile restore/recover. | Requires `--pdb`. Protection and recovery helpers available. |
| 33 | PDB loss of one UNDO datafile | PDB | PDB | destructive | Local undo datafile loss in a PDB. | Requires local undo and `--pdb`. Protection and recovery helpers available. |
| 34 | PDB loss of read-only tablespace | PDB | PDB | destructive | PDB read-only tablespace restore. | Requires `--pdb` and read-only tablespace target. Protection and recovery helpers available. |
| 35 | PDB loss of index-only tablespace | PDB | PDB | destructive | PDB index-only storage loss and rebuild/restore decision. | Requires `--pdb` and index-only tablespace target. Protection and recovery helpers available. |
| 36 | PDB drop non-unique indexes | PDB | PDB | logical | PDB-local index rebuild from DDL/deployment metadata. | Requires `--pdb`. Use `--schema` to target lab schema. |
| 37 | PDB loss of non-system tablespace | PDB | PDB | destructive | PDB tablespace-level restore/recover. | Requires `--pdb`. Protection and recovery helpers available. |
| 38 | PDB loss of temporary tablespace | PDB | PDB | destructive | PDB temporary tablespace repair. | Requires `--pdb`. Recovery helper available; tempfiles usually need recreation, not media recovery. |
| 39 | PDB loss of SYSTEM tablespace | PDB | PDB | destructive | PDB SYSTEM tablespace restore/recover. | Requires `--pdb`. Protection and recovery helpers available. |
| 40 | PDB loss of UNDO tablespace | PDB | PDB | destructive | PDB local undo tablespace recovery. | Requires `--pdb` and local undo design. Protection and recovery helpers available. |
| 41 | PDB loss of all datafiles | PDB | PDB | destructive | Full PDB restore/recover while preserving CDB posture. | Requires `--pdb`. Protection and recovery helpers available. |
| 42 | PDB SYSTEM file header corruption | PDB | PDB | destructive | PDB SYSTEM datafile header corruption response. | Requires `--pdb`. Filesystem targets use header corruption; ASM targets use a documented loss-style surrogate and FILE# recovery. |
| 43 | PDB loss of one user table | PDB | PDB | logical | Table restore through Flashback, Data Pump, table recovery, or application reload. | Requires `--pdb` and preferably a lab schema. Re-run seed after testing. |
| 44 | PDB loss of one user schema | PDB | PDB | logical | Schema-level recovery through Data Pump or PDB PITR/extract. | Requires `--pdb` and a lab schema. Re-run seed after testing. |
| 45 | Drop selected PDB including datafiles | PDB | PDB | destructive | Dropped PDB recovery planning and service recreation. | Guarded to disposable PDB names starting with `CRASHSIM_`. Never target production PDBs. |
| 46 | ASM data disk group unavailable | ASM | ASM | destructive | ASM disk group outage planning and database impact validation. | Planning helper available. Destructive execution requires a redundant purpose-built ASM lab. |
| 47 | OCR loss or restore drill | GI | Cluster | destructive | OCR backup, restore, and Clusterware validation. | Planning helper available. Requires root/Grid procedure approval. |
| 48 | Voting disk loss or restore drill | GI | Cluster | destructive | Voting disk replacement and cluster membership validation. | Planning helper available. Requires redundant GI lab and approval. |
| 49 | ASM SPFILE loss | ASM | ASM | destructive | ASM SPFILE backup/restore and ASM startup validation. | Planning helper available. Destructive execution requires ASM-aware procedure. |
| 50 | Standby managed recovery cancelled | DataGuard | Standby | logical | Restarting standby managed recovery and apply validation. | Requires a physical standby. |
| 51 | Primary transport destination deferred | DataGuard | Primary | logical | Restoring redo transport and validating gap/apply catch-up. | Requires Data Guard transport destination. |
| 52 | Data Guard broker configuration unavailable | DataGuard | DG | logical | Broker outage/fallback procedure and DGMGRL validation. | Registered placeholder; needs broker-enabled DG validation. |
| 53 | Active Data Guard read-only session pressure | ADG | Standby | logical | Separating read-only workload pressure from apply lag. | Registered placeholder for Active Data Guard. |
| 54 | Snapshot standby conversion practice | DataGuard | Standby | logical | Snapshot standby conversion and revert practice. | Registered placeholder for Data Guard lab. |
| 55 | RAC abort one instance | RAC | RAC | destructive | Instance abort, Clusterware restart, services, FAN/TAF/Application Continuity behavior. | Recovery helper available for srvctl-managed database restart validation. |
| 56 | RAC service relocation failure practice | RAC | RAC | logical | Service relocation/failover and client behavior validation. | Helper available. Relocates singleton services when possible, or stop/start validates all-instances services. |
| 57 | Listener config unavailable | Network | CDB/non-CDB | destructive | Listener/network configuration recovery. | Recovery helper available for filesystem rename backups. Alias-style network config drill using SQL*Net file handling. |
| 58 | TDE wallet or keystore unavailable | Security | CDB/non-CDB | destructive | Wallet restore, keystore open, encrypted tablespace and backup validation. | Recovery helper available for filesystem or ACFS wallet-root rename backups. Requires secure wallet backup and careful handling. |
| 59 | Missing archived redo log | Backup | CDB/non-CDB | destructive | Archived log restore, crosscheck, gap handling, and incomplete recovery decision-making. | Recovery helper available. Useful RPO validation drill. |
| 60 | Recovery catalog unavailable | Backup | External | logical | RMAN catalog connectivity, resync, and NOCATALOG fallback. | Uses `--rman-catalog` or `CRASHSIM_RMAN_CATALOG` when a catalog is available. |

## Scenario Selection Guidance

Good first drills:

- `6` and `31`: tempfile loss.
- `11`, `36`, `43`, and `44`: logical lab objects after running
  `seed_crashsim_lab.sql`.
- `16` and `26`: password file and SPFILE recovery, if remote-auth and pfile
  inputs are understood.
- `25` with `--local-only --max-targets 1`: local backup-piece handling.
- `59`: archived log loss and RPO decision practice.

Higher-risk drills:

- Control files: `1`, `2`, `23`.
- Redo: `3`, `4`, `18`, `19`, `20`, `21`, `24`.
- SYSTEM and whole-database or whole-PDB datafiles: `7`, `14`, `17`, `32`,
  `39`, `41`.
- Infrastructure: `28`, `46`, `47`, `48`, `49`, `55`, `58`.

Data Guard, Active Data Guard, and RAC service scenarios should be tested only
in topologies that actually include those capabilities.

## Recommended End-To-End Drill Pattern

Example for a supported PDB datafile scenario:

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --runbook 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --protect 30 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --protect 30 --pdb CRASHPDB --execute
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --execute
./CrashSimulatorV2.sh --recover 30 --pdb CRASHPDB --manifest ./crashsimulator_logs/<manifest>.manifest --execute
./CrashSimulatorV2.sh --health-check
```

After a successful drill, run a post-drill backup or your normal backup
stabilization procedure.

## Logs, Reports, And Evidence

By default, CrashSimulator writes to `./crashsimulator_logs`.

Typical files include:

- `*.manifest`: drill metadata used for recovery.
- `*.rman`: generated RMAN command files.
- `*.sql`: generated SQL helper files.
- `*.log`: command output.
- `*.md`: Markdown configuration and MAA reports.

Keep these files with the drill record. They are useful for audit evidence,
lessons learned, RTO/RPO timing, and improving operational runbooks.

When audit retention is enabled, CrashSimulator also writes a durable audit
archive under `crashsimulator_logs/audit` by default. Use `--audit-status` to
review audit usage and `--purge-audit-logs --dry-run` to preview cleanup before
executing the retention policy.

## What To Do When A Scenario Is Not Automated Yet

Some scenarios are registered before full destructive/recovery automation is
available in every topology. In that case:

1. Use `--runbook <id>`.
2. Use `--scenario <id> --dry-run` to capture target selection.
3. Confirm the manual recovery procedure.
4. Confirm backups and rollback steps.
5. Execute only in a lab designed for that failure.
6. Feed lessons learned back into the framework.

This approach keeps the scenario catalog forward-looking while preventing unsafe
automation in environments where Oracle, ASM, GI, storage, or cloud-provider
behavior needs a purpose-built helper.

## Quick Troubleshooting

`ERROR: CrashSimulator V2 requires Bash 4 or later`: Run on Oracle Linux with
`/bin/bash`, or install a supported Bash.

`sqlplus: command not found`: Set `ORACLE_HOME` and add `$ORACLE_HOME/bin` to
`PATH`.

`Recovery requires --manifest`: Use the manifest from the executed scenario, not
from a dry-run.

`This scenario requires --pdb`: Add `--pdb <pdb_name>` or set `CRASHSIM_PDB`.

`ASM path detected`: The selected file is in ASM. Use an ASM-aware scenario or
wait for the helper for that scenario.

`No targets were found`: The database does not currently have the required shape
for that scenario, such as multiplexed redo, read-only tablespace, index-only
tablespace, Data Guard, or RAC.

## Final Reminder

CrashSimulator is most valuable when it is used repeatedly:

- Before go-live.
- After patching or architecture changes.
- After backup policy changes.
- After adding RAC, Data Guard, Active Data Guard, TDE, or new storage.
- During periodic operational readiness drills.

The goal is not to break the database. The goal is to prove that recovery works,
measure how long it takes, discover gaps early, and make the recovery process
clear enough that the whole team can execute it under pressure.
