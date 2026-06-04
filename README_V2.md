# CrashSimulator V2

CrashSimulator is an open-source resilience validation platform for Oracle
Database environments. By orchestrating controlled failures and recovery
scenarios, it helps organizations continuously verify recoverability, strengthen
operational readiness, validate HA/DR architectures, and demonstrate compliance
with recovery objectives and regulatory requirements.

CrashSimulator V2 is a safer, single-script rewrite of the original
CrashSimulator shell scripts. It keeps destructive database-crash practice
behind explicit gates and adds environment discovery for CDB/non-CDB, PDB,
Data Guard, RAC, ASM/filesystem storage, FRA, SPFILE, and password-file paths.

## First Run

Run from the database host as an OS user that can connect locally as SYSDBA:

```bash
./CrashSimulatorV2.sh --menu
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --runbook 30 --pdb crashpdb
./CrashSimulatorV2.sh --protect 30 --pdb crashpdb --dry-run
./CrashSimulatorV2.sh --scenario 30 --pdb crashpdb --dry-run
./CrashSimulatorV2.sh --random-scenario --dry-run
./CrashSimulatorV2.sh --recover 30 --pdb crashpdb --file-no 12 --dry-run
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
- configure PDB, schema, FILE#, manifest, PFILE, log directory, and scenario 25 guards
- show recovery-runbook hints
- dry-run a scenario
- dry-run or execute RMAN protection when supported
- execute a scenario with the existing typed confirmation token
- dry-run or execute an aleatory scenario selected from the discovered topology
- dry-run or execute recovery from a manifest
- run the non-destructive health check
- generate target configuration/recoverability reports
- view recent manifests and logs

Menu actions re-run the same script in CLI mode, so automation and manual usage
stay consistent. Destructive actions still require `--execute` behavior and the
same typed confirmation, such as `EXECUTE-30`, `PROTECT-30`, or `RECOVER-30`.

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

On ASM storage, datafile crash injection is kept as a provider-specific
`external` action until an ASM-aware helper exists, but `--protect` still
resolves FILE# metadata and can plan or run RMAN protection for those targets.

Automated RMAN protection is currently enabled for:

- Scenario 5: loss of one non-system datafile in a non-CDB or CDB root.
- Scenario 7: loss of one SYSTEM datafile.
- Scenario 14: loss of SYSTEM tablespace.
- Scenario 17: loss of all datafiles.
- Scenario 30: loss of one non-system PDB datafile.
- Scenario 32: PDB loss of one SYSTEM datafile.
- Scenario 39: PDB loss of SYSTEM tablespace.
- Scenario 41: PDB loss of all datafiles.

Automated recovery helpers are currently enabled for:

- Scenario 1, 2, and 23: control-file restore from scenario backup copies,
  startup/open validation, RMAN control-file validation, and backup cleanup.
- Scenario 5 and 30: RMAN datafile restore/recover.
- Scenario 6 and 31: tempfile metadata repair/replacement. Recovery queries
  current tempfiles first because OMF may auto-create replacements on startup.
- Scenario 3, 4, 18, 19, 20, 21, and 24: redo member restore from scenario
  backup copies, database open validation, redo metadata checks, forced log
  switch, and backup cleanup. ASM redo manifests can also drive drop/add-member
  recovery when the missing member is an ASM file and no filesystem backup pair
  exists.
- Scenario 7, 14, 17, 32, 39, and 41: RMAN restore/recover for SYSTEM and
  all-datafile drills using FILE# metadata captured in the scenario manifest.
- Scenario 16: password-file recreation, optional SYSBACKUP re-grant, and remote
  SYSDBA validation. Use `CRASHSIM_SYS_PASSWORD` or `--sys-password`, and
  optionally `--service-name`.
- Scenario 25: local filesystem RMAN backup-piece restore, backup-set
  crosscheck, backup-set validation, and final scenario backup cleanup.
- Scenario 26: SPFILE recovery from `--pfile` or the scenario backup, followed
  by RMAN `validate spfile`.
- Scenario 55: GI/RAC instance or GI-managed single-database restart validation
  with `srvctl`, service status checks, and health validation.
- Scenario 59: archived-log crosscheck, restore from the scenario backup,
  validation, and final backup cleanup.

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
- ASM paths are identified as provider-specific targets; filesystem rename or
  corruption actions are refused until an ASM-aware crash-injection handler is
  implemented for that scenario.
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

The framework has been validated in the first OCI Base DB Service lab for a
subset of control-file, redo, datafile, tempfile, password-file, SPFILE,
backup-piece, PDB, and archived-log scenarios, and initial RAC One Node/GI/ASM
validation has started with scenario 55 and ASM dry-run/protection planning.
See `SCENARIO_STATUS.md` for the current validation matrix, known environment
gaps, and the next RAC, ASM, Data Guard, and Active Data Guard validation
targets.

Start each new environment with `--discover`, then dry-run target selection,
run `--protect` where available, execute only after backups and recovery
objectives are confirmed, and keep the GitHub repository as the source of truth.
