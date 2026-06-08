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
CDB/PDB environments. Current project validation evidence includes Oracle
Database 19c and Oracle AI Database 26ai RAC/ASM labs, with work covering
standalone, OCI Base Database Service, RAC One Node, two-node RAC,
GI-managed single-database, filesystem/LVM, ASM, and early Data Guard/Active
Data Guard scenario registration. This is CrashSimulator project validation,
not an official Oracle product certification.

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

`APEX`: Oracle APEX, a low-code application platform that runs inside an Oracle
Database schema and is commonly exposed to users through ORDS.

`ORDS`: Oracle REST Data Services. It is the HTTP access layer for APEX,
Database Actions, REST-enabled SQL, and REST APIs. ORDS can be installed on one
or more mid-tier/database hosts.

`Autonomous Database` or `ADB`: Oracle-managed database service in OCI. The
customer manages schemas, users, application connectivity, wallets, IAM,
network access, clones, and service configuration, while Oracle manages the OS,
storage, ASM, Grid Infrastructure, patching, backups, and infrastructure.

`APEX static resources`: JavaScript, CSS, images, and other files normally
served under a path such as `/i/`. If these files are missing, the database may
be open but APEX pages can still be unusable.

`ORDS pool`: The ORDS database connection configuration that points to a
service, user, password, wallet, and pool settings.

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
chmod +x crashsimulator CrashSimulatorV2.sh
chmod +x crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
```

CrashSimulator V2 requires:

- Bash 4 or later.
- Oracle environment variables for the target database session.
- SQL*Plus and RMAN in `PATH`.
- Local OS authentication as SYSDBA, or a working `--sqlplus-logon` string.
- Optional Grid Infrastructure tools such as `srvctl`, `crsctl`, `ocrcheck`, and
  `asmcmd` for RAC, GI, and ASM scenarios.

The Autonomous Database readiness report is different: it can run from a client
or bastion host without local SQL*Plus, RMAN, Oracle OS ownership, ASM, or Grid
Infrastructure access when Python and `python-oracledb` are available.

For a typical Oracle Linux database host:

```bash
sudo su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0.0/dbhome_1
export ORACLE_SID=orcl
export PATH=$ORACLE_HOME/bin:$PATH
cd /path/to/crashsimulator-main
./CrashSimulatorV2.sh --help
./crashsimulator --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --menu
./crashsimulator --menu
```

You can also use a CrashSimulator startup configuration file to fill missing
Oracle and CrashSimulator defaults automatically. This is useful on RAC, ASM,
Data Guard, APEX/ORDS, Autonomous Database client hosts, and repeatable lab
hosts where the same `ORACLE_SID`, `ORACLE_HOME`, PDB, log directory, Grid
home, ORDS settings, ADB wallet path, or ADB service alias are reused.

```bash
cp config/crashsimulator.conf.example crashsimulator.conf
vi crashsimulator.conf
./CrashSimulatorV2.sh --show-config
./CrashSimulatorV2.sh --validate-config
./CrashSimulatorV2.sh --config ./crashsimulator.conf --discover
```

Lookup order:

1. `--config <file>`
2. `CRASHSIM_CONFIG`
3. `./crashsimulator.conf`
4. `$HOME/.crashsimulator/crashsimulator.conf`
5. `/etc/crashsimulator/crashsimulator.conf`

Precedence is conservative: CLI arguments override existing shell environment,
existing shell environment overrides the configuration file, and the
configuration file overrides only built-in defaults. The file is parsed as
allowlisted `KEY=value` entries and is not sourced as shell code. Do not store
SYS passwords, RMAN catalog passwords, APEX passwords, wallet secrets, tokens,
or similar sensitive values in it.

If the ZIP was renamed by the browser, the directory may be
`crashsimulator-main`, `crashsimulator-master`, or another name. The important
point is to run the commands from the directory containing `CrashSimulatorV2.sh`.

Recommended first checks after unzipping:

```bash
ls CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs seed_crashsim_lab.sql verify_crashsim_lab.sql
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
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --config-report --deep-validate
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --backup-report --deep-validate
./CrashSimulatorV2.sh --apex-ords-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --adb-readiness-report --html
./CrashSimulatorV2.sh --list-adb-scenarios
./CrashSimulatorV2.sh --adb-scenario ADB01
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
./crashsimulator --menu
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
- Configure or be guided through PDB, schema, FILE#, manifest, PFILE, log
  directory, configuration file, password-file recovery, RMAN catalog, and
  scenario 25 guardrails.
- Browse recent manifests, logs, reports, and helper files with generated
  date/time, type, size, and a numbered inspection selector.
- Dry-run or execute an aleatory scenario for the detected topology.
- Generate a scenario readiness report for the detected topology.
- Generate configuration, backup strategy/recoverability, Oracle service HA,
  APEX/ORDS readiness, Autonomous Database readiness, MAA readiness, and
  scenario lifecycle coverage reports.
- Browse the dedicated Autonomous Database scenario catalog, select `ADB01`
  through `ADB15`, review validation status, configure ADB context, and refresh
  ADB readiness evidence from the main ADB submenu or the Reports menu ADB
  options.
- Configure audit retention, show audit status, browse retained audit logs, and
  purge old audit records.
- Review previously collected topology, runbooks, reports, scenario manifests,
  health checks, dry-run/execution records, and audit history.
- Create optional HTML copies of reports and logs for easier viewing.

The menu calls the same script in CLI mode, so menu usage and command-line
automation behave consistently.

When a selected scenario needs additional target context, the menu now guides
the operator before validation, dry-run, protection, execution, or recovery.
For example, PDB-scoped scenarios prompt for a PDB target and auto-select the
only available user PDB when that is unambiguous. Logical object-loss scenarios
such as `11`, `36`, `43`, and `44` offer an optional disposable lab-schema
selector. In PDB context the selector lists local `CRASHSIM%` lab schemas; in
root/non-PDB context it can also list common `C##CRASHSIM%` lab schemas. Typed
non-lab schemas require explicit confirmation.
FILE# selection shows datafile context including PDB, tablespace, size, and file
location; `PDB$SEED` files are hidden from this guided selector.

When a scenario is selected, the menu header shows lifecycle coverage for that
scenario: validation, protection, and recovery. If an operator chooses
protection or recovery for a scenario where the lifecycle report says the step
is not automated or not required, the menu now stops before launching a child
command and explains which runbook or baseline action should be used instead.

The menu groups safe planning actions separately from execution actions that
require typed confirmation tokens such as `EXECUTE-30`, `PROTECT-30`, or
`RECOVER-30`. Menu-launched child commands keep sensitive values out of the
printed command line; RMAN catalog connect strings and SYS passwords are shown
only as redacted environment values.

Reports launched from the Guided Workflow Reports menu generate the normal
Markdown/log artifacts and an additional `.html` copy where the report type
supports HTML rendering. Fresh baseline backup execution still requires the
`BASELINE-BACKUP` confirmation token.

The Recent Files, Reports, and Audit browsers show generated local time,
artifact type, size, and full path. Select the displayed number to print the
artifact contents directly in the terminal.

## Functional Capabilities

### Discovery

`--discover` identifies the target database posture: database name, role, open
mode, CDB/PDB status, selected PDB, storage type, ASM/GI/RAC signals, Data Guard
signals, FRA configuration, and other topology evidence.

### Scenario Registry

`--list` prints the database-host and application access-path scenarios with
ID, group, scope, impact, and scenario name. The full CrashSimulator catalog
contains 97 entries: 82 database-host/application scenarios plus 15
Autonomous Database cloud-service scenarios listed with `--list-adb-scenarios`.

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

When target selection fails, CrashSimulator tries to return a scenario-specific
prerequisite instead of a generic error. Examples include missing multiplexed
redo members, missing read-only or index-only lab tablespaces, missing
`seed_crashsim_lab.sql` objects, missing PDB table/schema targets, or missing
Data Guard/Active Data Guard standby, transport, broker, and apply evidence.

Use `--validate-all-scenarios` to produce a full runnable/not-runnable matrix:

```bash
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
```

Use `--scenario-readiness-report` when you want a saved report for planning,
evidence, or team review:

```bash
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --show-artifact latest:scenario-readiness --html
```

The report records the current topology signals, PDB context, and every
registered scenario grouped as `RUNNABLE`, `PLAN-ONLY`, or `NOT-RUNNABLE`.
It writes `crashsim_scenario_readiness_<run_id>.md`, updates
`crashsim_scenario_readiness_latest.md`, and optionally creates HTML. Guided
Workflow option 17 generates the same report. Scenario selection in the Guided
Workflow also performs the single-scenario readiness check immediately, so users
can see whether a selected scenario is executable before dry-run or execution.

Scenario execution runs this readiness validation before confirmation or
destructive code. A blocked `--execute` run stops immediately. Some blocked
scenarios can still continue in `--dry-run` so users can see planning evidence,
for example ASM/GI provider-specific targets or broad scenario 25 backup-piece
selection. Aleatory scenario selection also uses readiness validation, so random
drills choose only scenarios that are runnable in the current topology.

### Scenario Lifecycle Coverage

`--scenario-lifecycle-report` creates a static coverage report for the whole
scenario registry. It does not require a database connection. For every
scenario it records whether validation, protection, execution, recovery, and
runbook/evidence reporting are automated, manual/runbook based, plan-only, or
not applicable.

```bash
./CrashSimulatorV2.sh --scenario-lifecycle-report
./CrashSimulatorV2.sh --scenario-lifecycle-report --html
./CrashSimulatorV2.sh --show-artifact latest:lifecycle
```

Use this report after adding or changing scenarios to keep lifecycle gaps
visible. Then use `--scenario-readiness-report` against a live target to check
whether the current topology can actually run the desired drills.

### Runbook Hints

`--runbook <id>` prints scenario-specific recovery guidance. The same hints are
printed before destructive execution.

### Protection

`--protect <id>` prepares a recovery baseline for supported datafile scenarios.
It records metadata and can generate or run targeted RMAN backups before a
destructive drill.

Automated protection currently supports scenarios `5`, `7`, `8`, `9`, `10`,
`12`, `14`, `15`, `17`, `22`, `30`, `32`, `33`, `34`, `35`, `37`, `39`,
`40`, `41`, and `42`.

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
`35`, `37`, `38`, `39`, `40`, `41`, `42`, `50`, `51`, `55`, `56`, `57`,
`58`, `59`, `61`, `62`, `67`, `68`, `71`, `73`, `74`, `75`, `76`, `77`, and
`79`.

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

### Oracle Service HA Review

`--service-review` generates a focused read-only report for Oracle Database
service high-availability posture.

```bash
./CrashSimulatorV2.sh --service-review
./CrashSimulatorV2.sh --service-review --html
```

The report checks Application Continuity and Transparent Application Continuity
signals, Commit Outcome/Transaction Guard, FAN/AQ notifications, runtime/client
load-balancing goals, drain timeout, session-state consistency, failover restore,
Fast-Start Failover evidence, Active Data Guard DML redirection configuration,
and role-based services. When `srvctl` is available, it parses Clusterware
service metadata so Data Guard and Active Data Guard services can be reviewed
for `PRIMARY` and standby-role placement. The same service review section is
included in `--maa-report`.

### APEX/ORDS Readiness Report

`--apex-ords-report` checks whether APEX and ORDS are ready to be part of a
resilience drill. It treats the application access path as part of recovery,
because users can remain down even when the database and PDB are open.

```bash
./CrashSimulatorV2.sh --apex-ords-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --apex-ords-report \
  --pdb CRASHPDB \
  --ords-service ords \
  --ords-config-dir /etc/ords/config \
  --ords-url http://localhost:8080/ords/ \
  --apex-images-dir /opt/oracle/apex/images \
  --html
```

The report checks:

- APEX version and component status in the selected container.
- `APEX_PUBLIC_USER`, `APEX_PUBLIC_ROUTER`, `ORDS_PUBLIC_USER`, and
  `ORDS_METADATA` status where present.
- Invalid APEX and ORDS objects.
- APEX workspace and application counts.
- APEX mail, wallet, and network ACL signals.
- ORDS binary version, configuration directory, systemd service state, and
  smoke URL status.
- Optional ORDS load-balancer URL status.

The Guided Workflow Reports menu includes the same APEX/ORDS readiness option.

### Autonomous Database Readiness Report

`--adb-readiness-report` reviews an Oracle Autonomous Database target from a
client or bastion perspective. It does not try to run host-level scenarios that
customers cannot perform in ADB, such as removing datafiles, control files,
redo logs, ASM disks, SPFILEs, password files, or ORACLE_HOME. Instead it
focuses on realistic ADB resilience practice: logical/user-error recovery,
clone and point-in-time recovery readiness, wallet rotation, private endpoint
diagnostics, connection/resource pressure, Autonomous Data Guard, IAM, Object
Storage dependencies, and APEX/Database Actions URLs.

```bash
export CRASHSIM_ADB_PASSWORD='<database password>'
export CRASHSIM_ADB_WALLET_PASSWORD='<wallet password if required>'

./CrashSimulatorV2.sh \
  --adb-readiness-report \
  --adb-wallet-dir /path/to/Wallet_myadb \
  --adb-connect-alias myadb_low \
  --adb-user ADMIN \
  --adb-python /path/to/python \
  --html
```

For repeatable use, put non-secret ADB defaults in `crashsimulator.conf`, such
as wallet directory, alias, service level, user, Python path, ADB OCID, OCI
region/profile, APEX URL, Database Actions URL, and private endpoint label.
Keep passwords, wallet passphrases, API keys, and wallet files outside the
repository and outside the config file.

The report works in two levels:

- Config-only mode shows what is configured, what is missing, and which ADB
  scenario groups are blocked.
- Live SQL mode uses `python-oracledb` plus the wallet/descriptor/password
  environment variables to collect database identity, service, APEX, encrypted
  tablespace, Flashback Archive, object, and application-user evidence.

OCI control-plane checks for backups, PITR window, clones, Autonomous Data
Guard, IAM, and Object Storage need OCI CLI/profile/OCID context. SQL evidence
alone cannot prove those managed-service dependencies.

The Guided Workflow menu also includes a dedicated Autonomous Database
scenarios submenu. From that submenu users can list `ADB01` through `ADB15`
with current readiness status, select a scenario, inspect the validation and
recovery focus for that scenario, set ADB report context, regenerate the ADB
readiness report, and open the latest ADB report as text or HTML. The helper
execution option is intentionally a placeholder until seeded logical drills and
OCI control-plane helpers are implemented.

The same ADB workflow is also reachable from the Guided Workflow Reports menu:
`12` sets ADB report context, `13` generates the ADB readiness report with HTML,
`14` browses generated reports and HTML artifacts, `15` lists ADB scenarios,
`16` selects an ADB scenario, `17` shows selected ADB scenario detail, and `18`
opens the full ADB scenarios submenu. On ADB client or bastion hosts where
SQL*Plus is not installed, the Guided Workflow menu skips local database
topology discovery and still opens these ADB, review, and configuration
options.

### APEX/ORDS Scenarios

Scenarios `73` through `82` cover APEX and ORDS failures and validations:

- `73`: ORDS service unavailable.
- `74`: ORDS configuration unavailable.
- `75`: ORDS database pool misconfiguration.
- `76`: APEX/ORDS runtime account locked.
- `77`: APEX static resources unavailable.
- `78`: APEX application availability validation after recovery.
- `79`: One ORDS node unavailable behind a load balancer.
- `80`: APEX session continuity test.
- `81`: APEX mail queue and configuration validation.
- `82`: APEX upgrade or patch rollback readiness.

Scenarios `73`, `74`, `75`, `76`, `77`, and `79` have automated recovery
helpers when the target is reversible and the current OS user has safe
permissions. Scenario `75` changes the ORDS pool `db.servicename` to a lab-bad
value and restores the original value during recovery. Scenario `79` can use a
real `--ords-lb-url` or a lab peer-continuity URL, but only a real load balancer
proves production health-check and routing behavior. Scenarios `78`, `80`,
`81`, and `82` are read-only evidence/report drills.

Scenario `80` can optionally call the seeded APEX browser-session driver
`tools/crashsim_apex_session_driver.cjs`. The driver opens a disposable APEX
application URL, logs in when a test user is supplied, verifies a success CSS
selector, refreshes the page during the drill window, and writes screenshots,
Markdown, and JSON evidence.

Recommended seeded APEX marker:

```html
<span id="CRASHSIM_SESSION_OK">CrashSimulator session active</span>
```

Example:

```bash
export CRASHSIM_APEX_SESSION_PASSWORD='<test-user-password>'

./CrashSimulatorV2.sh \
  --scenario 80 \
  --pdb CRASHPDB \
  --apex-session-driver ./tools/crashsim_apex_session_driver.cjs \
  --apex-session-url http://localhost:8080/ords/r/crashsim/session-lab/home \
  --apex-session-username CRASHSIM_APEX_USER \
  --apex-session-success-selector '#CRASHSIM_SESSION_OK' \
  --apex-session-duration 120 \
  --apex-session-interval 10 \
  --execute
```

During the driver window, trigger the ORDS/RAC/Data Guard/database event from
another terminal. A `PASS` proves the seeded page stayed reachable and the
success marker remained visible; `WARN` means only URL continuity was tested;
`FAIL` means the page became unreachable, returned to login, or lost the success
marker. See `docs/APEX_SESSION_DRIVER_DESIGN.md` for the full design.

If ORDS service/config control requires elevated OS privileges, install the
restricted helper `crashsim_ords_priv_helper.sh` as root-owned
`/usr/local/bin/crashsim_ords_priv` and grant only that helper through sudoers.
Use `--ords-priv-helper` or `CRASHSIM_ORDS_PRIV_HELPER` to override the helper
path.

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

Live stdout/stderr capture defaults to `auto`. In normal CLI runs,
CrashSimulator captures redacted terminal output into `stdout.log` and
`stderr.log`. In an interactive guided workflow menu attached to a terminal,
live stream capture is disabled by default to keep the menu responsive; metadata
and generated artifacts are still retained. Set
`CRASHSIM_AUDIT_STREAM_CAPTURE=yes` only when you explicitly need live menu
terminal capture and have validated that the terminal/SSH environment supports
it.

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
export CRASHSIM_AUDIT_STREAM_CAPTURE=auto
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
Supported shortcuts include `topology`, `config`, `backup`,
`scenario-readiness`, `lifecycle`, `maa`, `health`, `scenario`, `protect`,
`recover`, `runbook`, `baseline`, `review`, `audit`, `apex-ords`, and
`latest`.

### MAA Readiness Report

`--maa-report` generates a best-effort Oracle MAA posture report. It maps
observable evidence to Bronze, Silver, Gold, Platinum, or Diamond-style
capability levels, includes AC/TAC, FSFO, ADG DML redirection, and role-based
service awareness, and records RTO/RPO planning context.

For FSFO-enabled Data Guard configurations, the MAA and service review reports
also collect Data Guard Broker evidence and check observer best-practice
posture:

- An active FSFO observer is present.
- Multiple observers are configured where possible.
- `PreferredObserverHosts` is configured to guide observer placement after role
  transitions.
- Observer placement is treated conservatively: prefer an external site; if no
  external site exists, use the primary site and keep a secondary-site observer
  ready after transition; never intentionally place the active observer with the
  standby database.

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

The seed and verify scripts use `CRASHPDB` when it exists; otherwise they use
the first read-write user PDB detected in `V$PDBS`.

### RAC/ASM Redundancy Lab Helpers

For RAC/ASM labs, these optional SQL helpers can prepare safer targets for redo
and control-file scenarios:

```bash
sqlplus / as sysdba @prepare_crashsim_redundancy.sql
sqlplus / as sysdba @prepare_crashsim_controlfile_multiplex.sql
```

`prepare_crashsim_redundancy.sql` adds a missing `+DATA` online redo member to
redo groups with fewer than two members. `prepare_crashsim_controlfile_multiplex.sql`
updates the spfile `CONTROL_FILES` value to include a `+DATA` control file
alias. After running the control-file helper, stop the database, copy the
surviving control file to the new ASM alias, and start the database with
`srvctl`; validate `V$CONTROLFILE` before running control-file scenarios.

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
- FSFO observer status, count, `PreferredObserverHosts`, and placement posture.
- Role-based services for primary write workloads and standby/ADG read-only
  workloads.
- AC/TAC, FAN/ONS, drain timeout, and client replay behavior.
- ADG DML redirection posture for any standby service that allows redirected
  writes.
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
- `ASM`, `Cluster`, `RAC`, `Standby`, `Primary`, `DG`, `External`, or `ADB`:
  Requires that topology, cloud-service target, or external component.

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
| 46 | ASM/FEX data storage unavailable | ASM | ASM/FEX | destructive | ASM disk group or FEX/ACFS managed-storage outage planning and database impact validation. | Planning helper available. Conventional ASM uses disk group evidence; FEX/ACFS emits provider-aware managed-storage plans. Destructive execution requires approved provider/Grid procedure. |
| 47 | OCR loss or restore drill | GI | Cluster | destructive | OCR backup, restore, and Clusterware validation. | Planning helper available. Requires root/Grid procedure approval. |
| 48 | Voting disk loss or restore drill | GI | Cluster | destructive | Voting disk replacement and cluster membership validation. | Planning helper available. Requires redundant GI lab and approval. |
| 49 | ASM/FEX SPFILE loss | ASM | ASM/FEX | destructive | ASM SPFILE or FEX/ACFS managed SPFILE backup/restore and startup validation. | Planning helper available. Destructive execution requires ASM-aware or provider-aware procedure. |
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
| 61 | FRA reaches critical utilization | Backup | CDB/non-CDB | destructive | FRA pressure, archiver/backups impact, reclaim decisions, and restoring FRA capacity. | Simulates pressure by safely shrinking `DB_RECOVERY_FILE_DEST_SIZE` near current usage. Recovery helper restores the original size. |
| 62 | Missing required archived log during recovery | Backup | CDB/non-CDB | destructive | Required archived-log restore, RMAN preview, and incomplete-recovery decision-making. | Targets one available local archived log and produces RMAN decision evidence. ASM archived logs remain plan-only until ASM removal is explicitly approved. |
| 63 | TEMP tablespace exhaustion | Core | CDB/non-CDB | logical | ORA-01652 diagnosis, workload cleanup, TEMP capacity planning, and resource controls. | Runs a disposable controlled TEMP-consuming workload. Use `--temp-exhaust-mb` to tune pressure. |
| 64 | RTO validation drill | Compliance | CDB/non-CDB | logical | Comparing actual measured recovery timing against supplied RTO objectives. | Read-only report based on completed CrashSimulator recovery manifests. Use MAA/SLA options for objectives. |
| 65 | RPO validation drill | Compliance | CDB/non-CDB | logical | Estimating recoverable data window from archived redo, backups, and Data Guard evidence. | Read-only report comparing current evidence against supplied RPO objectives. |
| 66 | FSFO observer unavailable | DataGuard | DG | logical | Observer outage handling, broker monitoring, and failover expectation validation. | Plan-only external observer action. Requires Data Guard/FSFO observer evidence. |
| 67 | Data Guard apply lag exceeds SLA | DataGuard | Standby | logical | Apply lag monitoring, RPO breach handling, and standby apply restart. | Recovery helper restarts managed standby recovery. Run on a physical standby. |
| 68 | Data Guard transport network partition | DataGuard | Primary | logical | Redo transport interruption, lag/gap monitoring, and destination re-enable. | Defers one remote standby archive destination. Recovery helper enables it and forces a log switch. |
| 69 | Standby redo log misconfiguration review | DataGuard | DG | logical | SRL sizing/count review by thread before real-time apply and low-RPO drills. | Read-only report. Flags missing, undersized, or too-few standby redo logs. |
| 70 | RAC VIP relocation drill | RAC | RAC | logical | VIP movement planning, client retry behavior, SCAN/VIP listener evidence, and FAN/ONS validation. | Plan-only external VIP action because target node and Grid-owner approval are environment-specific. |
| 71 | RAC service placement failure | RAC | RAC | logical | Service placement, instance-level service stop/start, FAN/ONS, AC/TAC behavior, and recovery validation. | Uses `srvctl` against one running service instance. Recovery helper validates/starts the service. |
| 72 | ASM/FEX storage component failure | ASM | ASM/FEX | destructive | Single-disk failure planning for redundant ASM, or provider-managed FEX/ACFS storage-component outage review. | Plan-only external action. Redundant ASM requires NORMAL/HIGH/FLEX/EXTENDED redundancy; FEX/ACFS requires provider-approved storage controls and redundancy/rebuild evidence. |
| 73 | ORDS service unavailable | APEX/ORDS | Application | logical | ORDS outage detection, service restart, HTTP smoke validation, and user-facing recovery timing. | Automatable when the current OS user can control the ORDS systemd service. Recovery helper starts ORDS and writes smoke evidence. |
| 74 | ORDS configuration unavailable | APEX/ORDS | Application | destructive | Restoring ORDS configuration, wallets, pools, static mappings, and connection settings. | Renames the ORDS config directory when writable or through the restricted helper; recovery restores the rename backup. |
| 75 | ORDS database pool misconfiguration | APEX/ORDS | Application | logical | Diagnosing bad service names, wallets, users, passwords, pool settings, and ORDS logs. | Reversible `db.servicename` mutation when ORDS restart privileges are approved. Recovery restores the original service name and restarts ORDS. |
| 76 | APEX/ORDS runtime account locked | APEX/ORDS | Application | logical | Recovering from locked or expired APEX/ORDS runtime users and validating application access. | Locks an available runtime account in the selected container. Recovery helper unlocks it. |
| 77 | APEX static resources unavailable | APEX/ORDS | Application | destructive | Restoring APEX images/static files and validating page CSS, JavaScript, image, and login behavior. | Requires `--apex-images-dir` or a detected static path. Recovery helper restores the rename backup when executed. |
| 78 | APEX application availability validation after recovery | APEX/ORDS | Application | logical | Proving the user-facing APEX/ORDS path after database, PDB, service, or ORDS recovery. | Read-only smoke evidence using `--ords-url` and optional load-balancer URL. |
| 79 | ORDS node unavailable behind load balancer | APEX/ORDS | Application | logical | One-node ORDS outage, load-balancer health, session behavior, and service continuity. | Requires ORDS service control and a continuity URL. `--ords-lb-url` proves a real load balancer; a peer URL is acceptable for lab continuity practice. |
| 80 | APEX session continuity test | APEX/ORDS | Application | logical | Observing an active APEX session during ORDS, RAC service, Data Guard, or database failover. | Read-only continuity evidence, with optional seeded Playwright browser-session driver for screenshots and JSON/Markdown evidence. |
| 81 | APEX mail queue and configuration validation | APEX/ORDS | Application | logical | SMTP, wallet/TLS, network ACL, failed mail queue, and notification recovery checks. | Read-only report/evidence drill. |
| 82 | APEX upgrade or patch rollback readiness | APEX/ORDS | Application | logical | Pre/post APEX version, invalid object, ORDS config, runtime-user, and application smoke evidence. | Read-only readiness/runbook drill for APEX/ORDS patching and rollback decisions. |

### Autonomous Database Scenario Catalog

Autonomous Database scenarios use `ADB01` through `ADB15` because they validate
cloud-service and client/application dependencies rather than database-host
file removal. They are listed with `--list-adb-scenarios`, inspected with
`--adb-scenario <ADB01-ADB15>`, and included in the Guided Workflow Autonomous
Database submenu.

| ID | Scenario | Area | Scope | Impact | What users practice | Key notes |
| --- | --- | --- | --- | --- | --- | --- |
| ADB01 | Drop critical application table | ADB | Logical recovery | logical | Flashback, clone, export, or data-merge recovery for a disposable critical table. | Requires live SQL connection and seeded lab table before execution helpers are added. |
| ADB02 | Drop application schema | ADB | Logical recovery | logical | Schema-level recovery through clone/export, grants/object inventory, and application validation. | Plan/runbook first; destructive logical helper pending. |
| ADB03 | Mass DELETE without WHERE clause | ADB | Logical recovery | logical | Recovering accidentally deleted rows with flashback query/table, clone comparison, or data merge. | Requires row-count evidence and flashback window validation. |
| ADB04 | Incorrect UPDATE corrupts business data | ADB | Logical recovery | logical | Before/after validation, Flashback Versions Query, object restore, and data comparison. | Requires disposable lab rows and validation query. |
| ADB05 | Recover from clone | ADB | Clone/PITR | logical | Creating a recovery clone, validating objects/application state, and merging recovered data. | Requires OCI clone permissions and source/timestamp evidence. |
| ADB06 | Point-in-time recovery drill | ADB | Clone/PITR | logical | Measuring RTO/RPO with clone-to-time or PITR-style ADB recovery. | Requires backup retention and timestamp selection evidence. |
| ADB07 | Validate backup recoverability | ADB | Backup readiness | logical | Proving backup retention, latest backup, PITR window, and clone/restore capability. | Evidence-only until OCI control-plane helper is implemented. |
| ADB08 | Expired or rotated client wallet | ADB | Connectivity | logical | Wallet rotation, client distribution, reconnect, and application smoke validation. | Keep passwords out of config files; use environment variables for credentials. |
| ADB09 | Private endpoint connectivity loss | ADB | Network | logical | DNS, bastion path, routes, NSGs/security lists, and reconnect validation. | Plan/runbook first; use approved network fault boundaries only. |
| ADB10 | Connection pool saturation | ADB | Resource limits | logical | Diagnosing pool pressure, retry/backoff behavior, service class, and application impact. | Requires approved workload limits and monitoring. |
| ADB11 | Resource Manager or concurrency pressure | ADB | Resource limits | logical | Reviewing service classes, scaling posture, consumer limits, and workload scheduling. | Plan/runbook first; workload helper pending. |
| ADB12 | Cross-region DR validation | ADB | Autonomous Data Guard | logical | Autonomous Data Guard lag, failover eligibility, reconnect, and RTO/RPO measurement. | Requires OCI ADG metadata and peer/region evidence. |
| ADB13 | Autonomous Data Guard role transition | ADB | Autonomous Data Guard | logical | Switchover/failover runbook, URL/service validation, and fallback planning. | Requires OCI ADG role and transition eligibility evidence. |
| ADB14 | IAM administrator access misconfiguration | ADB | OCI/IAM | logical | Break-glass access, IAM policy/group evidence, and admin automation recovery. | Read-only evidence first; test only inside an approved IAM boundary. |
| ADB15 | Object Storage export dependency unavailable | ADB | Object Storage | logical | Restoring bucket, policy, credential, network access, and export/import procedures. | Requires bucket/credential/DBMS_CLOUD dependency evidence. |

## Scenario Selection Guidance

Good first drills:

- `6` and `31`: tempfile loss.
- `11`, `36`, `43`, and `44`: logical lab objects after running
  `seed_crashsim_lab.sql`.
- `16` and `26`: password file and SPFILE recovery, if remote-auth and pfile
  inputs are understood.
- `25` with `--local-only --max-targets 1`: local backup-piece handling.
- `59` and `62`: archived log loss and required-log recovery decision practice.
- `63`: controlled TEMP exhaustion in a lab-sized workload.
- `64` and `65`: read-only RTO/RPO validation reporting after objectives are
  supplied.
- `69`: read-only standby redo log review in any Data Guard topology.
- `73`, `78`, `80`, `81`, and `82`: APEX/ORDS service, smoke, session
  continuity, mail, and patch readiness checks when ORDS/APEX are installed.

Higher-risk drills:

- Control files: `1`, `2`, `23`.
- Redo: `3`, `4`, `18`, `19`, `20`, `21`, `24`.
- SYSTEM and whole-database or whole-PDB datafiles: `7`, `14`, `17`, `32`,
  `39`, `41`.
- FRA pressure: `61`, because it can affect archiving until recovered.
- Data Guard state changes: `67` and `68`, because they intentionally create
  apply or transport lag until recovered.
- Infrastructure: `28`, `46`, `47`, `48`, `49`, `55`, `58`, `70`, `71`, `72`.
- Application access path: `73`, `74`, `75`, `76`, `77`, and `79`, because they
  can interrupt ORDS/APEX user access until recovered.

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
