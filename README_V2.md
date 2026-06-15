# CrashSimulator V2.0.2 Beta

CrashSimulator is an open-source resilience validation platform for Oracle
Database environments. By orchestrating controlled failures and recovery
scenarios, it helps organizations continuously verify recoverability, strengthen
operational readiness, validate HA/DR architectures, and demonstrate compliance
with recovery objectives and regulatory requirements.

CrashSimulator V2.0.2 beta is a safer, single-script rewrite of the original
CrashSimulator shell scripts. It keeps destructive database-crash practice
behind explicit gates and adds environment discovery for CDB/non-CDB, PDB,
Data Guard, RAC, ASM/filesystem storage, FRA, SPFILE, and password-file paths.
It also treats APEX/ORDS as an application access-path dependency when ORDS is
installed on the target host, and adds an Autonomous Database readiness report
for client/bastion validation of wallet connectivity, logical recovery posture,
clone/PITR readiness, Autonomous Data Guard/IAM/Object Storage dependencies, and
ADB-specific scenario coverage.

Compatibility target: Oracle Database 12c and later. Project validation
evidence now includes live Oracle Database 19c and Oracle AI Database 26ai
RAC/ASM labs. This is CrashSimulator project validation rather than an official
Oracle product certification.

## Documentation

For end-user guidance, terminology, safety practices, feature descriptions, and
the full scenario catalog, read:

- `README.md` for the short project entry point.
- `docs/CRASHSIMULATOR_V2_0_2_BETA_PRODUCT_OVERVIEW.md` for the product
  overview, intention, capabilities, limitations, and roadmap.
- `docs/RELEASE_NOTES_V2_0_2_BETA.md` for release notes and package details.
- `docs/CRASHSIMULATOR_USER_GUIDE.md` for the complete user guide.
- `docs/AUTONOMOUS_DATABASE_COVERAGE.md` for the ADB coverage model and
  scenario family.
- `SCENARIO_STATUS.md` for current validation status and known gaps.
- `docs/reference/README.md` for sanitized report examples.

## Install From A ZIP File

If you download CrashSimulator as a GitHub release ZIP file, copy the ZIP to
the target Oracle database host and unzip it. For `v2.0.2 beta`, the curated
runtime package is `crashsimulator-v2.0.2-beta-runtime.zip`:

```bash
unzip crashsimulator-v2.0.2-beta-runtime.zip
cd crashsimulator-v2.0.2-beta
chmod +x CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
```

GitHub also creates automatic source-code ZIP files for tags. They are useful
for source review, but the runtime ZIP in `dist/` is the smaller package
intended for database-host installation and excludes local logs, wallets, keys,
scratch HTML output, and large tutorial MP4 files.

Run it as the Oracle software owner, or as an OS user that can connect locally
as SYSDBA. Set the Oracle environment before starting:

```bash
sudo su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0.0/dbhome_1
export ORACLE_SID=orcl
export PATH=$ORACLE_HOME/bin:$PATH
cd /path/to/crashsimulator-v2.0.2-beta
```

If you prefer repeatable startup defaults, copy and edit the sample
configuration file:

```bash
cp config/crashsimulator.conf.example crashsimulator.conf
vi crashsimulator.conf
./CrashSimulatorV2.sh --show-config
./CrashSimulatorV2.sh --validate-config
```

CrashSimulator reads configuration in this order: `--config <file>`,
`CRASHSIM_CONFIG`, `./crashsimulator.conf`,
`$HOME/.crashsimulator/crashsimulator.conf`, then
`/etc/crashsimulator/crashsimulator.conf`. CLI arguments override existing
environment values, existing environment values override the configuration
file, and the configuration file only replaces built-in defaults. The file is
parsed as allowlisted `KEY=value` entries and is not sourced as shell code.
Keep passwords and wallet secrets out of it.

CrashSimulator V2 requires Bash 4 or later, SQL*Plus, RMAN, and the normal
Oracle environment for the target database. Grid Infrastructure commands such as
`srvctl`, `crsctl`, `ocrcheck`, and `asmcmd` are used only for RAC/GI/ASM
scenarios and reports when available.

Validate the downloaded copy with safe commands first:

```bash
./CrashSimulatorV2.sh --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --menu
```

`--dry-run` is the default. Destructive scenarios require `--execute` and an
interactive confirmation token.

## First Run

Run from the database host as an OS user that can connect locally as SYSDBA:

```bash
./CrashSimulatorV2.sh --menu
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --validate-scenario 30 --pdb crashpdb
./CrashSimulatorV2.sh --validate-all-scenarios --pdb crashpdb
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --maa-report
./CrashSimulatorV2.sh --resilience-scorecard --html
./CrashSimulatorV2.sh --apex-ords-report --pdb crashpdb --html
./CrashSimulatorV2.sh --adb-readiness-report --html
./CrashSimulatorV2.sh --list-adb-scenarios
./CrashSimulatorV2.sh --adb-scenario ADB01
./CrashSimulatorV2.sh --baseline-backup --dry-run
./CrashSimulatorV2.sh --audit-status
./CrashSimulatorV2.sh --runbook 30 --pdb crashpdb
./CrashSimulatorV2.sh --protect 30 --pdb crashpdb --dry-run
./CrashSimulatorV2.sh --scenario 30 --pdb crashpdb --dry-run
./CrashSimulatorV2.sh --random-scenario --dry-run
./CrashSimulatorV2.sh --recover 30 --pdb crashpdb --file-no 12 --dry-run
./CrashSimulatorV2.sh --scenario 60 --rman-catalog "$CRASHSIM_RMAN_CATALOG" --dry-run
./CrashSimulatorV2.sh --scenario 43 --pdb crashpdb --schema crashsim_table_lab --dry-run
```

`--dry-run` is the default. It discovers targets and prints the planned action
without changing files or database state.

Every scenario run prints recovery-runbook hints before any destructive
confirmation. Use `--runbook <id>` to print the same recovery guidance without
planning or executing the crash scenario.

## Guided Menu

Run the script without arguments, or use `--menu`, to open the guided terminal
menu:

```bash
./CrashSimulatorV2.sh
./CrashSimulatorV2.sh --menu
```

The menu keeps the CLI guardrails but makes the normal drill flow easier to
drive from a single screen:

- discover or refresh database topology
- select a scenario
- configure PDB, schema, FILE#, manifest, PFILE, log directory,
  configuration file, and scenario 25 guards
- validate whether the selected scenario is runnable and generate a full
  topology-versus-scenario readiness report with blocker reasons
- show recovery-runbook hints
- dry-run a scenario
- dry-run or execute RMAN protection when supported
- execute a scenario with the existing typed confirmation token
- dry-run or execute an aleatory scenario selected from the discovered topology
- dry-run or execute recovery from a manifest
- run the non-destructive health check
- generate target configuration/recoverability reports
- generate backup strategy and recoverability/RTO/RPO reports
- generate Oracle MAA readiness and SLA planning reports
- generate the executive resilience scorecard from backup, HA, DR, security,
  recoverability, MAA, service, and drill evidence
- browse the dedicated Autonomous Database scenario catalog, select `ADB01`
  through `ADB20`, review validation status, and refresh ADB readiness evidence
  from the main ADB submenu or the Reports menu ADB options
- configure audit retention, inspect audit status, and purge old audit records
- review collected topology, manifests, runbooks, dry-run/execution records,
  reports, health checks, configuration outputs, and audit history
- render reports and logs as optional HTML files for easier viewing
- browse recent manifests, logs, reports, HTML files, and audit logs with
  generated date/time, type, size, and a numbered inspection selector

Menu actions re-run the same script in CLI mode, so automation and manual usage
stay consistent. Destructive actions still require `--execute` behavior and the
same typed confirmation, such as `EXECUTE-30`, `PROTECT-30`, or `RECOVER-30`.
The menu separates safe planning actions from confirmation-required execution
actions. Menu-launched child commands keep sensitive values out of the printed
command line; RMAN catalog connect strings and SYS passwords are shown only as
redacted environment values.

When a scenario is selected, the menu header shows lifecycle coverage for
validation, protection, and recovery. Menu protection/recovery choices are
guarded with the same lifecycle-capability checks used by the coverage report,
so users see a clear runbook/baseline message instead of a failing child
command when a step is not automated or not required. Reports launched from the
Reports menu also request HTML output automatically where supported, while
keeping the normal Markdown/log artifacts.

On ADB client or bastion hosts where SQL*Plus is not installed, the menu skips
local database topology discovery and still opens for ADB readiness reports,
ADB scenario browsing, review, and configuration.

## Review Center And HTML Output

CrashSimulator stores generated evidence in the configured log directory and,
when audit retention is enabled, in the audit archive. The Review Center lets
users inspect this already collected information without reconnecting to the
database or rerunning a scenario.

Common CLI commands:

```bash
./CrashSimulatorV2.sh --review
./CrashSimulatorV2.sh --review --html
./CrashSimulatorV2.sh --review-topology
./CrashSimulatorV2.sh --show-artifact latest:runbook
./CrashSimulatorV2.sh --show-artifact latest:health --html
./CrashSimulatorV2.sh --render-html latest:backup
```

Use `--html` with supported report, health-check, runbook, topology, baseline,
review, and artifact commands to create an additional `.html` file next to the
normal text, Markdown, RMAN, or log output. The original report/log format is
kept unchanged. `--render-html <path|latest:kind>` can convert an existing
artifact later. Supported `latest:<kind>` shortcuts include `topology`,
`config`, `backup`, `scenario-readiness`, `lifecycle`, `maa`, `health`,
`scenario`, `protect`, `recover`, `runbook`, `baseline`, `review`, `audit`,
`apex-ords`, and `latest`.

## Scenario Readiness Validation

Use `--validate-scenario <id>` to check whether a scenario can be run now in the
current database topology:

```bash
./CrashSimulatorV2.sh --validate-scenario 30 --pdb crashpdb
./CrashSimulatorV2.sh --validate 25 --local-only --max-targets 1
```

The validation process runs the same requirement gates and target-selection logic
used by dry-run/execution, but in non-destructive planning mode. If a scenario
cannot run, the tool prints a clear message such as:

- required topology is missing, for example no CDB, PDB, Data Guard, ASM, GI, or RAC
- the requested PDB does not exist
- no suitable target exists, such as no read-only tablespace or no multiplexed
  redo member
- the selected target is an ASM/provider-specific file and the scenario does not
  yet have a safe ASM-aware execution helper
- scenario 25 backup-piece guardrails are missing
- the scenario is registered as a future placeholder but does not yet have a
  runnable handler

Target-selection failures are translated into scenario-specific prerequisites
where possible. For example, redo scenarios explain when redo groups are not
multiplexed, read-only/index-only scenarios identify the missing lab
tablespace, logical scenarios point back to `seed_crashsim_lab.sql`, and Data
Guard/Active Data Guard scenarios name the missing standby, transport, broker,
or apply requirement.

Use `--validate-all-scenarios` to produce a runnable/not-runnable matrix for the
current topology:

```bash
./CrashSimulatorV2.sh --validate-all-scenarios --pdb crashpdb
```

Use `--scenario-readiness-report` for the persistent report version. It records
the current topology, evaluates every registered scenario, separates
`RUNNABLE`, `PLAN-ONLY`, and `NOT-RUNNABLE` scenarios, writes
`crashsim_scenario_readiness_<run_id>.md`, updates
`crashsim_scenario_readiness_latest.md`, and can render HTML:

```bash
./CrashSimulatorV2.sh --scenario-readiness-report --pdb crashpdb --html
./CrashSimulatorV2.sh --show-artifact latest:scenario-readiness --html
```

Scenario execution now runs the same validation first. A blocked `--execute`
run stops before confirmation or destructive code and prints why it is not
possible to run at that moment. Some blockers are reported as dry-run planning
only, such as ASM/provider-specific targets or broad scenario 25 backup-piece
selection; those scenarios may still show planning evidence in `--dry-run`, but
execution remains blocked until the reason is resolved. Aleatory scenario
selection also uses this validation so random drills select only runnable
scenarios.

## Scenario Lifecycle Coverage

Use `--scenario-lifecycle-report` to review framework coverage for every
registered scenario without connecting to a database:

```bash
./CrashSimulatorV2.sh --scenario-lifecycle-report
./CrashSimulatorV2.sh --scenario-lifecycle-report --html
./CrashSimulatorV2.sh --show-artifact latest:lifecycle
```

The report shows whether each scenario has automated validation, automated or
manual protection, guarded execution, automated or manual recovery, and
runbook/evidence artifacts. It deliberately distinguishes automated helpers
from manual/runbook and plan-only infrastructure drills so gaps remain visible
without overstating safety.

Use `--scenario-lifecycle-check` before publishing or after adding scenarios.
It fails when scenario metadata, handlers, or lifecycle capability text are
missing:

```bash
./CrashSimulatorV2.sh --scenario-lifecycle-check --html
```

## Public Readiness Checks

Before sharing a public build or giving the tool to new users, run the
read-only public-readiness checks:

```bash
./CrashSimulatorV2.sh --doctor --html
./CrashSimulatorV2.sh --first-run --html
./CrashSimulatorV2.sh --public-limitations --html
./CrashSimulatorV2.sh --secret-scan --scan-path .
./CrashSimulatorV2.sh --sanitize-artifacts --sanitize-source reports
./CrashSimulatorV2.sh --release-check
```

`--execute --yes` destructive lab runs require
`CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` or `--accept-destructive-lab`. Keep that
acknowledgement limited to approved non-production environments.

## Configuration Report

Use `--config-report` to generate a Markdown report under
`./crashsimulator_logs` with the current target database/PDB configuration:

```bash
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --config-report --deep-validate
```

The report includes database and PDB identity, CDB/non-CDB posture, redo groups
and members, control files, datafile/tempfile counts and sizes, SYSTEM/UNDO/temp
file details, tablespaces, FRA location and usage, non-default parameters,
ORACLE_HOME evidence, listener status and network config files, RMAN
configuration/history/backup coverage, restore preview, corruption views, TDE,
Data Guard/FSFO evidence, and GI/ASM/OCR/voting-disk status when those tools are
available. The default report uses RMAN metadata and `restore database preview
summary`; `--deep-validate` adds read-only but I/O-intensive RMAN
`restore database validate` and `validate database check logical` checks.

## Oracle Service HA Review

Use `--service-review` to generate a focused, read-only review of Oracle
Database services and application failover posture:

```bash
./CrashSimulatorV2.sh --service-review
./CrashSimulatorV2.sh --service-review --html
```

The review checks SQL service metadata and, when Grid Infrastructure tooling is
available, `srvctl config service` metadata. It reports Application Continuity
and Transparent Application Continuity indicators, Commit Outcome/Transaction
Guard, FAN/AQ notifications, runtime/client load-balancing goals, drain timeout,
session-state consistency, failover restore, Fast-Start Failover evidence, ADG
DML redirection configuration, and role-based services for Data Guard/Active
Data Guard. The same service-awareness section is also included in
`--maa-report`.

## Backup Strategy And Recoverability Report

Use `--backup-report` to generate a focused backup strategy and recoverability
report:

```bash
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --backup-report --deep-validate
CRASHSIM_RMAN_CATALOG='rcat/password@//host:1521/service' ./CrashSimulatorV2.sh --backup-report
```

The report gathers evidence from the target control-file RMAN repository and,
when `--rman-catalog` or `CRASHSIM_RMAN_CATALOG` is supplied, from the RMAN
recovery catalog session as well. It summarizes datafile coverage, Level 0/Level
1 cadence, archived redo backup cadence, backup piece status, FRA pressure,
failed jobs, corruption views, files needing recovery, restore preview,
need-backup/obsolete reports, and optional deep validation.

The RTO/RPO section is an evidence-based estimate. Backup-only RPO is estimated
mainly from archived redo backup age and unbacked archived redo; RTO is
estimated from visible database size, backup method, backup age, and observed job
durations. Actual RTO/RPO still need timed restore/recovery/application drills.
`--deep-validate` adds read-only but I/O-intensive `RESTORE DATABASE VALIDATE`,
`RESTORE ARCHIVELOG ALL VALIDATE`, and `VALIDATE DATABASE CHECK LOGICAL`.

## Resilience Scorecard

Use `--resilience-scorecard` to generate an executive scorecard that converts
the current evidence into domain scores and an overall `Resilience Score`:

```bash
./CrashSimulatorV2.sh --resilience-scorecard
./CrashSimulatorV2.sh --resilience-scorecard --html
./CrashSimulatorV2.sh --show-artifact latest:resilience
```

The scorecard combines topology discovery, MAA posture, backup posture, scenario
coverage, service/application-continuity signals, recovery manifests, and recent
drill evidence. It currently scores Backup, RAC/local HA, Security, DR/Data
Guard, Recoverability, MAA Alignment, Scenario Coverage, and Application
Continuity. Each domain explains which evidence improved the score and which
gaps are still limiting it.

Scores improve when teams collect stronger evidence: fresh baseline backups,
RMAN validation, successful protection/recovery manifests, scenario lifecycle
coverage, RAC/service failover tests, Data Guard/FSFO evidence, APEX/ORDS or
application access-path validation, and measured RTO/RPO drills. The scorecard
is a management and audit aid, not a formal Oracle certification.

By default, CrashSimulator tries to refresh
`crashsim_resilience_scorecard_latest.md` after scenario, protection, recovery,
validation, health-check, lifecycle/readiness, and baseline-backup actions. The
refresh is best effort and non-blocking; it is skipped with a warning if
SQL*Plus or the target database is not ready at that moment. Use
`--no-auto-scorecard` or `CRASHSIM_AUTO_SCORECARD=0` when automation should only
produce the explicitly requested artifact.

## Fresh Baseline Backup

Use `--baseline-backup` to create a new RMAN baseline backup before or after
destructive drills. Dry-run is the default and prints the RMAN plan without
running a backup:

```bash
./CrashSimulatorV2.sh --baseline-backup --dry-run
./CrashSimulatorV2.sh --baseline-backup --execute
CRASHSIM_RMAN_CATALOG='rcat/password@//host:1521/service' ./CrashSimulatorV2.sh --baseline-backup --execute
```

The helper script `crashsim_run_baseline_backup.sh` can also be run directly.
It creates a forced compressed database backup, backs up archived redo not
already backed up once, backs up the current control file and SPFILE, lists the
generated tags, and writes the RMAN command/log files under
`crashsimulator_logs`. The default RMAN tag prefix is `CSIM_BASE`; override it
with `--backup-tag-prefix` or `CRASHSIM_BASELINE_TAG_PREFIX`.

## Audit Retention And Purge

CrashSimulator can retain a per-run audit archive for compliance, training, and
drill review. Audit retention is enabled by default and writes under
`crashsimulator_logs/audit` unless `--audit-dir` or `CRASHSIM_AUDIT_DIR` is set.

Each audit run folder records redacted command metadata, redacted environment
settings, stdout, stderr, exit status, and redacted copies of generated text
artifacts such as RMAN, SQL, manifest, log, evidence, and Markdown files.

```bash
./CrashSimulatorV2.sh --audit-status
./CrashSimulatorV2.sh --audit-retain yes --audit-retention-days 365 --audit-status
./CrashSimulatorV2.sh --purge-audit-logs --dry-run
./CrashSimulatorV2.sh --purge-audit-logs --execute
```

Use `--audit-retain no` or `CRASHSIM_AUDIT_RETAIN=0` to disable new audit run
folders. Use `--audit-retention-days <days>` or
`CRASHSIM_AUDIT_RETENTION_DAYS` to control purge eligibility. Purge is dry-run
by default and requires `--execute` plus the `PURGE-AUDIT-LOGS` confirmation
token unless `--yes` is supplied by trusted automation.

## MAA Readiness Report

Use `--maa-report` to generate an Oracle MAA posture, decision-tree, and
best-practice report:

```bash
./CrashSimulatorV2.sh --maa-report
./CrashSimulatorV2.sh --maa-report \
  --maa-app-name payroll \
  --maa-criticality mission-critical \
  --maa-local-ha-target yes \
  --maa-local-rto "less than 1 minute" \
  --maa-local-rpo zero \
  --maa-dr-required yes \
  --maa-dr-rto "less than 5 minutes" \
  --maa-dr-rpo zero \
  --maa-automatic-failover-required yes \
  --maa-standby-scope remote
```

The report separates three concepts that should not be mixed:

- `Target MAA level`: what the business requirements imply from RTO/RPO,
  planned-maintenance tolerance, local HA, DR, automatic failover, active-active
  need, and platform context.
- `Candidate MAA level`: what the installed/configured topology appears capable
  of, based on observable RAC/RAC One Node, local standby, Data Guard/Active Data
  Guard, FSFO, service, backup, and replication signals.
- `Current evidenced MAA level`: what CrashSimulator can conservatively support
  from configuration, service/client integration, measured drill evidence,
  backup/recovery validation, and operational evidence.

This implements the decision-tree distinction between product presence and
evidenced readiness. Silver can be a RAC/RAC One Node or explicitly local Data
Guard standby local-HA pattern, but it is only evidenced when service/client
failover and measured local-failure validation exist. Gold is treated as a DR
candidate when Data Guard/Active Data Guard is present, but it requires Broker,
lag/role-service evidence, measured transition/failover behavior, and
application validation before the report promotes it to evidenced Gold.

This is a readiness assessment, not an Oracle certification. It uses Oracle MAA
reference architecture concepts and the RTO/RPO planning model from
`oraclemaa.com` as report references, then points to CrashSimulator drills that
can prove or disprove the expected recovery behavior.

The resilience scorecard reuses these MAA findings as one weighted domain while
also considering backup, recoverability, DR, RAC/local HA, security, scenario
coverage, and application-continuity evidence. This lets technical drill
results roll up into a concise score for managers, auditors, and operational
review meetings.

## Aleatory Scenario

Use `--random-scenario` or its alias `--aleatory-scenario` to let the framework
discover the database topology and choose one implemented, topology-compatible
scenario at random:

```bash
./CrashSimulatorV2.sh --random-scenario --dry-run
./CrashSimulatorV2.sh --aleatory-scenario --execute
```

Random execution still uses the selected scenario's normal typed confirmation
token, recovery-runbook hints, target discovery, and destructive-action gates.
Scenario 25 is included in the random pool only when its local backup-piece
guardrails are set with `--piece-handle` or `--local-only --max-targets <n>`.

## Protect, Drill, Recover

The framework now supports a safer end-to-end flow for the tested datafile
scenarios:

```bash
./CrashSimulatorV2.sh --protect 30 --pdb crashpdb --execute
./CrashSimulatorV2.sh --scenario 30 --pdb crashpdb --execute
./CrashSimulatorV2.sh --recover 30 --pdb crashpdb --manifest ./crashsimulator_logs/crashsim_protect_s30_<run_id>.manifest --execute
```

`--protect` generates or runs an RMAN backup of the exact datafile target plus
the current control file before the crash drill. `--recover` generates or runs
the RMAN restore/recover command file. Both modes write a manifest containing
the scenario id, target PDB/container, file number, tablespace, datafile path,
RMAN tag, command files, and logs.

On ASM storage, supported datafile and tempfile drills use ASM-aware action
kinds such as `asm_rm`, `asm_tempfile_rm`, and `asm_corrupt_header`. The helper
uses `asmcmd rm` through the Grid environment for ASM file-loss practice and
records FILE#/tablespace/container metadata for RMAN recovery. ASM header
corruption uses a documented loss-style surrogate because filesystem `dd`
cannot safely target ASM files directly.

Automated RMAN protection is currently enabled for:

- Scenario 5: loss of one non-system datafile in a non-CDB or CDB root.
- Scenario 7: loss of one SYSTEM datafile.
- Scenario 8: loss of one UNDO datafile.
- Scenario 9: loss of a controlled CDB-root or non-CDB read-only tablespace.
- Scenario 10: loss of a controlled CDB-root or non-CDB index-only tablespace.
- Scenario 12: loss of one non-system tablespace.
- Scenario 14: loss of SYSTEM tablespace.
- Scenario 15: loss of UNDO tablespace.
- Scenario 17: loss of all datafiles.
- Scenario 22: datafile header-corruption recovery practice.
- Scenario 30: loss of one non-system PDB datafile.
- Scenario 32: PDB loss of one SYSTEM datafile.
- Scenario 33: PDB loss of one UNDO datafile.
- Scenario 34: PDB loss of read-only tablespace.
- Scenario 35: PDB loss of index-only tablespace.
- Scenario 37: PDB loss of non-system tablespace.
- Scenario 39: PDB loss of SYSTEM tablespace.
- Scenario 40: PDB loss of UNDO tablespace.
- Scenario 41: PDB loss of all datafiles.
- Scenario 42: PDB SYSTEM file header-corruption recovery practice.

Automated recovery helpers are currently enabled for:

- Scenario 1, 2, and 23: control-file restore from scenario backup copies,
  startup/open validation, RMAN control-file validation, and backup cleanup.
- Scenario 5 and 30: RMAN datafile restore/recover.
- Scenario 6, 13, 31, and 38: tempfile metadata repair/replacement. Recovery
  queries current tempfiles first because OMF may auto-create replacements on
  startup, and tablespace-wide temp drills can repair multiple tempfile
  metadata entries.
- Scenario 3, 4, 18, 19, 20, 21, and 24: redo member restore from scenario
  backup copies, database open validation, redo metadata checks, forced log
  switch, and backup cleanup. ASM redo manifests can also drive drop/add-member
  recovery when the missing member is an ASM file and no filesystem backup pair
  exists.
- Scenario 7, 8, 9, 10, 12, 14, 15, 17, 22, 32, 33, 34, 35, 37, 39, 40, 41,
  and 42: RMAN restore/recover for datafile and tablespace drills using FILE#
  metadata captured in the scenario manifest.
- Scenario 16: password-file recreation, optional SYSBACKUP re-grant, and remote
  SYSDBA validation. Use `CRASHSIM_SYS_PASSWORD` or `--sys-password`, and
  optionally `--service-name`.
- Scenario 25: local filesystem RMAN backup-piece restore, backup-set
  crosscheck, backup-set validation, and final scenario backup cleanup.
- Scenario 26: SPFILE recovery from `--pfile` or the scenario backup, followed
  by RMAN `validate spfile`.
- Scenario 27 and 57: SQL*Net/listener configuration restore from filesystem
  rename backups, followed by database/PDB health validation.
- Scenario 50 and 67: managed standby recovery restart and apply-lag catch-up
  validation.
- Scenario 51 and 68: re-enable deferred redo transport destinations, force log
  generation, and validate transport/apply status.
- Scenario 55: GI/RAC instance or GI-managed single-database restart validation
  with `srvctl`, service status checks, and health validation.
- Scenario 56 and 71: RAC service relocation, placement, or stop/start
  validation. Singleton services can be relocated when an idle target exists;
  all-instances services are stop/start validated on one instance, and recovery
  helpers validate or restart the service as needed.
- Scenario 58: TDE wallet/keystore filesystem or ACFS wallet-root restore from
  rename backup, followed by database/PDB health validation.
- Scenario 59: archived-log crosscheck, restore from the scenario backup,
  validation, and final backup cleanup.
- Scenario 61: restore the original `DB_RECOVERY_FILE_DEST_SIZE` after FRA
  pressure simulation and validate FRA posture.
- Scenario 62: restore/crosscheck the targeted archived log and generate
  required-log recovery decision evidence.
- Scenario 73 and 79: restart the ORDS service and generate ORDS/APEX smoke
  or continuity evidence.
- Scenario 74 and 77: restore renamed ORDS configuration or APEX static-file
  directories from scenario backups when the target was writable and executed by
  the lab user.
- Scenario 75: restore the original ORDS pool `db.servicename`, restart ORDS,
  and validate the ORDS/APEX smoke URL.
- Scenario 76: unlock the affected APEX/ORDS runtime account in the selected
  PDB and validate account state.

For scenario 30, recovery creates a SQL*Plus post-step that opens the target PDB
only when it is not already open, avoiding the ORA-65019 issue observed during
manual recovery.

For PDB-scoped datafile recoveries on CDB/ASM environments, the recovery helper
restores and recovers FILE# targets while the CDB remains open and the target
PDB is closed, then opens the PDB and runs validation where applicable.

Scenario recovery uses the executed scenario manifest:

```bash
./CrashSimulatorV2.sh --recover 31 --manifest ./crashsimulator_logs/batch_s31.manifest --execute
CRASHSIM_SYS_PASSWORD='...' ./CrashSimulatorV2.sh --recover 16 --manifest ./crashsimulator_logs/batch_s16.manifest --execute
./CrashSimulatorV2.sh --recover 26 --manifest ./crashsimulator_logs/batch_s26.manifest --pfile /tmp/initcrashdb.ora --execute
```

Recovery helpers stop on SQL/RMAN errors and remove `.crashsim.bak` files only
after the relevant validation step succeeds.

## Scenario 25 Guardrails

Scenario 25 can see both local filesystem backup pieces and provider-managed
Object Storage handles. Dry-run broadly first, then execute with a narrow guard:

```bash
./CrashSimulatorV2.sh --scenario 25 --dry-run
./CrashSimulatorV2.sh --scenario 25 --local-only --max-targets 1 --dry-run
./CrashSimulatorV2.sh --scenario 25 --local-only --max-targets 1 --execute
./CrashSimulatorV2.sh --recover 25 --manifest ./crashsimulator_logs/batch_s25.manifest --execute
```

For an exact local FRA piece:

```bash
./CrashSimulatorV2.sh --scenario 25 --piece-handle '/u03/.../piece.bkp' --execute
```

Destructive execution of scenario 25 requires either `--piece-handle` or
`--local-only --max-targets <n>`. If a selected handle is not a local filesystem
path, execution is refused.

## Recovery Catalog Drill

Scenario 60 validates RMAN recovery-catalog connectivity and the operational
fallback to target-control-file metadata when the catalog is unavailable:

```bash
export CRASHSIM_RMAN_CATALOG='rman_catalog_user/password@//host:1521/service'
./CrashSimulatorV2.sh --scenario 60 --dry-run
./CrashSimulatorV2.sh --scenario 60 --execute
./CrashSimulatorV2.sh --scenario 60 --rman-catalog "$CRASHSIM_RMAN_CATALOG" --execute
```

The drill first connects to the target and catalog, runs `resync catalog`, lists
incarnations, and reports schema metadata. It then validates a `NOCATALOG`
fallback with incarnation, schema, backup summary, and restore-preview checks.
Catalog passwords are redacted from printed RMAN logs and Guided Workflow
command echoes.

For lab convenience, a catalog can be created in a PDB on the same target CDB.
For production and production-like DR testing, keep the RMAN recovery catalog in
an independent database so a target loss does not also remove catalog metadata.

## FRA, TEMP, And RTO/RPO Drills

The high-value resilience scenarios `61` through `65` connect operational
failure practice with recoverability reporting:

```bash
./CrashSimulatorV2.sh --scenario 61 --fra-pressure-target-pct 98 --fra-pressure-headroom-mb 64 --dry-run
./CrashSimulatorV2.sh --scenario 61 --execute
./CrashSimulatorV2.sh --recover 61 --manifest ./crashsimulator_logs/<manifest>.manifest --execute

./CrashSimulatorV2.sh --scenario 62 --dry-run
./CrashSimulatorV2.sh --scenario 63 --pdb CRASHPDB --temp-exhaust-mb 512 --execute

./CrashSimulatorV2.sh --scenario 64 --maa-local-rto "15 minutes" --execute
./CrashSimulatorV2.sh --scenario 65 --maa-local-rpo "5 minutes" --execute
```

Scenario `61` simulates FRA pressure by shrinking
`DB_RECOVERY_FILE_DEST_SIZE` near current FRA usage, then the recovery helper
restores the original size. Scenario `62` targets one archived log and produces
RMAN decision evidence for required-log recovery and incomplete-recovery
choices. Scenario `63` uses a disposable TEMP-consuming workload to practice
ORA-01652 response. Scenarios `64` and `65` are read-only compliance drills:
they compare measured recovery timing and current recoverable-data evidence
against supplied RTO/RPO objectives.

## DG, RAC, And ASM-Specific Drills

Scenarios `66` through `72` add topology-specific MAA practice:

```bash
./CrashSimulatorV2.sh --scenario 66 --dry-run
./CrashSimulatorV2.sh --scenario 67 --dry-run
./CrashSimulatorV2.sh --scenario 67 --execute
./CrashSimulatorV2.sh --recover 67 --execute

./CrashSimulatorV2.sh --scenario 68 --dry-run
./CrashSimulatorV2.sh --scenario 68 --execute
./CrashSimulatorV2.sh --recover 68 --manifest ./crashsimulator_logs/<manifest>.manifest --execute

./CrashSimulatorV2.sh --scenario 69 --execute --html
./CrashSimulatorV2.sh --scenario 70 --dry-run
./CrashSimulatorV2.sh --scenario 71 --service-name <service> --dry-run
./CrashSimulatorV2.sh --scenario 72 --dry-run
```

Scenario `66` is plan-only for FSFO observer outage practice. Scenario `67`
pauses standby apply so teams can measure apply lag and alerting, and the
recovery helper restarts managed recovery. Scenario `68` simulates a transport
network partition by deferring a remote standby archive destination, then
re-enables it during recovery. Scenario `69` is a read-only standby redo log
review. Scenario `70` is plan-only VIP relocation evidence. Scenario `71`
exercises RAC service placement with `srvctl`. Scenario `72` plans single ASM
disk failure only when a redundant disk group exists; EXTERN redundancy is
rejected for this drill.

## Service Continuity, Role Transition, And Platform Drills

Scenarios `83` through `90` add validation/runbook coverage for service
continuity, role transitions, and lifecycle rollback:

- `83`: Application Continuity / TAC replay validation. Captures service
  metadata and plans a replay-safe client workload drill.
- `84`: FAN/ONS notification unavailable. Captures service/ONS evidence and
  keeps notification interruption external to the approved lab runbook.
- `85`: planned Data Guard switchover. Requires a configured Data Guard
  topology and remains operator-approved.
- `86`: Data Guard failback rehearsal. Captures failback/reinstate readiness
  and keeps role transition execution external.
- `87`: role-based service validation. Reviews srvctl/SQL service evidence and
  plans validation after switchover/failover.
- `88`: PDB point-in-time recovery drill. Generates PDB/RMAN PITR evidence and
  a preview template; actual PITR remains operator-approved.
- `89`: guaranteed restore point rollback. Validates Flashback/GRP posture and
  emits rollback guidance.
- `90`: database patch rollback readiness. Reviews backups, restore points,
  SQL patch inventory, Data Guard evidence, and service posture.

The platform scenario families are plan/readiness-first:

- `EXA01` through `EXA04`: Exadata cell, storage server, Smart Scan, and Flash
  Cache validation planning.
- `OCI01` through `OCI05`: OCI Base Database Service backup policy,
  cross-region recovery, DB system failover, VCN connectivity, and NSG
  misconfiguration validation planning.
- `GG01` through `GG04`: GoldenGate Extract, Replicat, lag, and trail recovery
  drills.

These scenarios are intentionally conservative: CrashSimulator collects
evidence and runbooks, then blocks execution until the platform-specific lab
target, rollback path, and approval boundary are known.

## APEX/ORDS Application Access Drills

Scenarios `73` through `82` cover APEX and ORDS as user-facing recovery
dependencies. They are useful after database, PDB, RAC, Data Guard, or ORDS
maintenance because a technically recovered database can still be unavailable to
APEX users.

```bash
./CrashSimulatorV2.sh --apex-ords-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-scenario 73 --pdb CRASHPDB
./CrashSimulatorV2.sh --scenario 73 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --recover 73 --manifest ./crashsimulator_logs/<manifest>.manifest --execute
./CrashSimulatorV2.sh --scenario 75 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --recover 75 --manifest ./crashsimulator_logs/<manifest>.manifest --execute
./CrashSimulatorV2.sh --scenario 76 --pdb CRASHPDB --dry-run
./CrashSimulatorV2.sh --scenario 78 --ords-url http://localhost:8080/ords/ --execute
CRASHSIM_APEX_SESSION_PASSWORD='<test-user-password>' \
  ./CrashSimulatorV2.sh --scenario 80 --pdb CRASHPDB \
  --apex-session-driver ./tools/crashsim_apex_session_driver.cjs \
  --apex-session-url http://localhost:8080/ords/r/crashsim/session-lab/home \
  --apex-session-username CRASHSIM_APEX_USER \
  --apex-session-success-selector '#CRASHSIM_SESSION_OK' \
  --apex-session-duration 120 \
  --execute
```

The APEX/ORDS readiness report checks APEX version/status, runtime accounts,
invalid APEX/ORDS objects, workspaces/applications, SMTP and wallet signals,
network ACLs, ORDS version/configuration, systemd service state, and ORDS smoke
URLs. The Guided Workflow Reports menu includes the same report.

Scenarios `73`, `74`, `75`, `76`, `77`, and `79` have automated recovery
helpers where the lab user has safe OS permissions and the target is reversible.
Scenario `75` performs a reversible `db.servicename` mutation and restores the
original value during recovery. Scenario `79` can use `--ords-lb-url` for a real
load balancer or a lab peer-continuity URL for continuity practice. Scenarios
`78`, `80`, `81`, and `82` are read-only evidence drills for application
availability, session continuity, mail configuration, and upgrade/patch rollback
readiness. Scenario `80` can optionally call the seeded browser-session driver
`tools/crashsim_apex_session_driver.cjs` to capture authenticated APEX session
evidence with screenshots, Markdown, and JSON artifacts.

For labs where the Oracle software owner cannot control ORDS directly, install
the restricted helper `crashsim_ords_priv_helper.sh` as root-owned
`/usr/local/bin/crashsim_ords_priv` and grant only that helper through sudoers.
Then pass `--ords-priv-helper /usr/local/bin/crashsim_ords_priv` or set
`CRASHSIM_ORDS_PRIV_HELPER`.

## Executing A Scenario

Destructive execution requires `--execute` and an interactive confirmation:

```bash
./CrashSimulatorV2.sh --scenario 30 --pdb crashpdb --execute
```

For automated lab runs only:

```bash
./CrashSimulatorV2.sh --scenario 30 --pdb crashpdb --execute --yes
```

## Design Notes

- One codebase replaces the previous black/white and low/high script forks.
- Scenarios are registered as metadata with id, group, scope, impact,
  requirements, handler, and notes.
- PDB scenarios require a selected PDB; there is no `PDB1` or `CON_ID=3`
  assumption.
- Logical object scenarios can be constrained with `--schema` or
  `CRASHSIM_SCHEMA` so lab runs do not target arbitrary application objects.
- `seed_crashsim_lab.sql` reseeds controlled CDB-root read-only/index-only
  targets for scenarios 9 and 10, plus PDB lab users, table/schema/index
  targets, and read-only/index-only PDB tablespaces for safer target selection
  practice. It uses `CRASHPDB` when present; otherwise it selects the first
  read-write user PDB detected in `V$PDBS`.
- `--prepare-environment` and the Guided Workflow seed/prepare option inspect
  the detected topology and report which scenario lab preparations are present,
  missing, not required, or plan-only. The planner covers logical lab objects,
  redo/control-file multiplexing posture, APEX/ORDS, RMAN catalog, FSFO,
  AC/TAC/FAN services, redundant ASM/FEX/ACFS lab posture, and fresh baseline
  backup evidence.
- `prepare_crashsim_redundancy.sql` and
  `prepare_crashsim_controlfile_multiplex.sql` help RAC/ASM labs add redo
  multiplexing and prepare a `+DATA` control-file alias before manual
  stop/copy/start validation.
- SQL*Plus script execution is isolated from parent shell stdin; repository SQL
  helper scripts also end with `exit` so automation wrappers do not continue
  inside SQL*Plus after a script completes.
- Drill manifests connect crash injection to recovery: target path, FILE#,
  container/PDB, tablespace, backup tag, renamed file path, RMAN command file,
  and recovery log locations are recorded.
- `--recover` can use `--file-no` when the database is only mountable and live
  target discovery is unavailable.
- Instance abort uses `V$BGPROCESS`/`V$PROCESS` PMON SPID discovery before
  falling back to OS process matching.
- RAC, Data Guard, ASM, and Grid Infrastructure scenarios are registered and
  gated by discovered topology. GI-managed single-instance/RAC One Node-style
  databases are reported separately from plain standalone databases.
- ASM paths are identified and routed to ASM-aware helpers where implemented;
  scenarios without safe ASM handling remain provider-specific or plan-only.
- ASM/GI scenarios 46, 47, 48, and 49 include non-destructive planning helpers
  for disk groups, OCR, voting disks, and ASM SPFILE evidence collection.
- Destructive OCR/voting/ASM disk-group drills should be refused in labs where
  OCR or the only voting disk lives in an `EXTERN` redundancy disk group.
- Filesystem actions refuse ASM-style `+DATA/...` paths.
- Instance abort targets the discovered/current instance instead of every PMON
  on the host.
- GI-managed single-database abort drills use `srvctl stop database -o abort`
  and recovery checks use `srvctl status/start database` plus service checks.
- Fixed `/tmp/*.tmp` files are replaced with a private `mktemp` work directory.

## Current Status

The framework currently tracks `123` total scenarios: `103` database-host,
application access-path, and platform/readiness scenarios across Core, PDB,
Backup, Config, Corrupt, Logical, ASM, GI, Data Guard, Active Data Guard, RAC,
Network, Security, Compliance, APEX/ORDS, Services, Recovery, Lifecycle,
Exadata, OCI DB, and GoldenGate groups, plus `ADB01` through `ADB20` for
Autonomous Database cloud-service readiness and recovery practice.

The first OCI Base DB Service lab validated representative control-file, redo,
datafile, tempfile, password-file, SPFILE, backup-piece, PDB, and archived-log
scenarios. RAC/GI/ASM labs added RAC service drills, SQL*Net and wallet
recovery, recovery-catalog practice, logical reseeding, controlled
read-only/index-only targets, ASM-aware datafile/tablespace dry-runs and
recoveries, and MAA/service/backup/readiness reporting.

The latest scenario layer adds high-value resilience/compliance drills for FRA
critical utilization, required archived-log recovery gaps, TEMP exhaustion, RTO
validation, and RPO validation, plus DG/RAC/ASM-specific drills for FSFO
observer outage planning, Data Guard apply lag, Data Guard transport
partitioning, standby redo log review, RAC VIP relocation planning, RAC service
placement failure, and redundant ASM single-disk failure planning.

The APEX/ORDS layer adds ORDS service and configuration outage drills, ORDS pool
misconfiguration recovery, APEX runtime account lockout recovery, APEX static
resource loss, application availability smoke evidence after recovery, ORDS
load-balancer node outage practice, optional seeded APEX browser-session
continuity evidence, mail configuration validation, and APEX upgrade/patch
rollback readiness.

See `SCENARIO_STATUS.md` for the current validation matrix, known environment
gaps, and the next RAC, ASM, Data Guard, and Active Data Guard validation
targets.

Start each new environment with `--discover`, then dry-run target selection,
run `--protect` where available, execute only after backups and recovery
objectives are confirmed, and keep the GitHub repository as the source of truth.
