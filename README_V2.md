# CrashSimulator V2

CrashSimulator V2 is a safer, single-script rewrite of the original
CrashSimulator shell scripts. It keeps destructive database-crash practice
behind explicit gates and adds environment discovery for CDB/non-CDB, PDB,
Data Guard, RAC, ASM/filesystem storage, FRA, SPFILE, and password-file paths.

## First Run

Run from the database host as an OS user that can connect locally as SYSDBA:

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --runbook 30 --pdb crashpdb
./CrashSimulatorV2.sh --protect 30 --pdb crashpdb --dry-run
./CrashSimulatorV2.sh --scenario 30 --pdb crashpdb --dry-run
./CrashSimulatorV2.sh --recover 30 --pdb crashpdb --file-no 12 --dry-run
./CrashSimulatorV2.sh --scenario 43 --pdb crashpdb --schema crashsim_table_lab --dry-run
```

`--dry-run` is the default. It discovers targets and prints the planned action
without changing files or database state.

Every scenario run prints recovery-runbook hints before any destructive
confirmation. Use `--runbook <id>` to print the same recovery guidance without
planning or executing the crash scenario.

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

Automated RMAN protection is currently enabled for:

- Scenario 5: loss of one non-system datafile in a non-CDB or CDB root.
- Scenario 30: loss of one non-system PDB datafile.

Automated recovery helpers are currently enabled for:

- Scenario 1, 2, and 23: control-file restore from scenario backup copies,
  startup/open validation, RMAN control-file validation, and backup cleanup.
- Scenario 5 and 30: RMAN datafile restore/recover.
- Scenario 6 and 31: tempfile metadata repair/replacement. Recovery queries
  current tempfiles first because OMF may auto-create replacements on startup.
- Scenario 3, 4, 18, 19, 20, 21, and 24: redo member restore from scenario
  backup copies, database open validation, redo metadata checks, forced log
  switch, and backup cleanup.
- Scenario 7, 14, 17, 32, 39, and 41: RMAN restore/recover for SYSTEM and
  all-datafile drills using FILE# metadata captured in the scenario manifest.
- Scenario 16: password-file recreation, optional SYSBACKUP re-grant, and remote
  SYSDBA validation. Use `CRASHSIM_SYS_PASSWORD` or `--sys-password`, and
  optionally `--service-name`.
- Scenario 25: local filesystem RMAN backup-piece restore, backup-set
  crosscheck, backup-set validation, and final scenario backup cleanup.
- Scenario 26: SPFILE recovery from `--pfile` or the scenario backup, followed
  by RMAN `validate spfile`.
- Scenario 59: archived-log crosscheck, restore from the scenario backup,
  validation, and final backup cleanup.

For scenario 30, recovery creates a SQL*Plus post-step that opens the target PDB
only when it is not already open, avoiding the ORA-65019 issue observed during
manual recovery.

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
- RAC, Data Guard, ASM, and Grid Infrastructure scenarios are registered but
  gated by discovered topology.
- Filesystem actions refuse ASM-style `+DATA/...` paths.
- Instance abort targets the discovered/current instance instead of every PMON
  on the host.
- Fixed `/tmp/*.tmp` files are replaced with a private `mktemp` work directory.

## Current Status

The framework has been validated in the first OCI Base DB Service lab for a
subset of control-file, redo, datafile, tempfile, password-file, SPFILE,
backup-piece, PDB, and archived-log scenarios. See `SCENARIO_STATUS.md` for the
current validation matrix, known environment gaps, and the next RAC, ASM, Data
Guard, and Active Data Guard validation targets.

Start each new environment with `--discover`, then dry-run target selection,
run `--protect` where available, execute only after backups and recovery
objectives are confirmed, and keep the GitHub repository as the source of truth.
