# CrashSimulator Scenario Status

Snapshot date: 2026-06-05

This status reflects the first OCI Base DB Service validation environment and
the RAC/GI/ASM validation environments, including the current two-node RAC lab.

First OCI Base DB Service validation environment:

- Oracle Database 19.31 Enterprise Edition
- CDB `CRASHDB` with PDB `CRASHPDB`
- Single-instance primary database
- Filesystem/LVM storage, no ASM
- No RAC, no standby, no Active Data Guard
- Backups to Object Storage/SBT, with local filesystem drills constrained where required

The required patched project files on the server and laptop were compared by
SHA-256 and matched for the framework, README, seed/verify scripts, and drill
SQL/RMAN helpers. Generated manifests and logs under `/tmp/crashsim_logs` are
environment-specific evidence and are not source-controlled by default.

## Validated In This Environment

The following scenarios were dry-run checked, executed where a target existed,
recovered, and followed by database/PDB health validation:

- `1`: loss of one control file
- `2`: loss of all control files
- `4`: loss of all members from current redo group
- `5`: loss of one non-system datafile
- `6`: loss of one temporary file
- `7`: loss of one SYSTEM datafile
- `16`: loss of password file
- `17`: loss of all datafiles
- `19`: loss of all inactive redo groups
- `20`: loss of all active redo groups
- `21`: loss of all current redo group members
- `23`: control file corruption
- `24`: redo log corruption
- `25`: loss of local RMAN backup piece, using `--local-only --max-targets 1`
- `26`: loss of SPFILE
- `30`: PDB loss of one non-system datafile
- `31`: PDB loss of one temporary file
- `32`: PDB loss of one SYSTEM datafile
- `41`: PDB loss of all datafiles
- `59`: missing archived redo log

Final validation after the higher-risk batch showed:

- Database open read write
- PDB `CRASHPDB` open read write
- `V$RECOVER_FILE` count `0`
- `V$DATABASE_BLOCK_CORRUPTION` count `0`
- No remaining `.crashsim.bak` artifacts

## No Valid Target In This Environment

- `3`: loss of one member from current redo group
- `18`: loss of one member from multiplexed redo group

The test database did not have the required redo-log member shape for these
single-member drills. They should be validated in an environment with
multiplexed redo logs.

## Implemented But Still Awaiting Validation

These scenarios have handlers registered in the framework but still need
environment-specific dry-run, protection, execution, recovery, and validation:

- `8`: loss of one UNDO datafile
- `9`: loss of a read-only tablespace
- `10`: loss of an index-only tablespace
- `12`: loss of a non-system tablespace
- `13`: loss of a temporary tablespace
- `14`: loss of SYSTEM tablespace
- `15`: loss of UNDO tablespace
- `22`: datafile header corruption
- `28`: loss of ORACLE_HOME
- `29`: loss of FRA destination
- `33`: PDB loss of one UNDO datafile
- `34`: PDB loss of read-only tablespace
- `35`: PDB loss of index-only tablespace
- `37`: PDB loss of non-system tablespace
- `38`: PDB loss of temporary tablespace
- `39`: PDB loss of SYSTEM tablespace
- `40`: PDB loss of UNDO tablespace
- `42`: PDB SYSTEM file header corruption
- `50`: standby managed recovery cancelled
- `51`: primary transport destination deferred

Re-run `seed_crashsim_lab.sql` before table, schema, index-loss, read-only
tablespace, or index-only tablespace scenarios.

## Initial RAC/GI/ASM Validation

The RAC One Node/GI/ASM environment uses Oracle Database 19.31, CDB
`CRASHDB`, PDB `CRASHPDB`, DB unique name `crashdb_test2`, GI-managed
single-database topology detected as `GI_SINGLE`, and ASM disk groups `DATA`
and `RECO`.

- `55`: dry-run, execute, manual `srvctl start database` recovery, automated
  `--recover 55 --execute` validation, and post-drill health check completed.
- Redo groups were multiplexed by adding one `+DATA` member to each group while
  retaining the original `+RECO` members.
- `18`: inactive multiplexed redo member removed from ASM as `grid`, recovered
  with the ASM redo recovery helper, and validated.
- `3`: current redo member target selected and recovery helper dry-run
  validated. Destructive injection was not forced because ASM refused removal of
  the current file with ORA-15028 and Oracle refused logical drop with ORA-01609.
- `30`: protected FILE# `12`, removed the PDB USERS datafile from ASM, restored
  and recovered it, and reopened `CRASHPDB`.
- `32`: protected FILE# `8`, removed the PDB SYSTEM datafile from ASM, restored
  and recovered it, and reopened `CRASHPDB`.
- `41`: protected FILE# list `8,9,10,12`, removed all `CRASHPDB` datafiles from
  ASM, restored and recovered the list, reopened `CRASHPDB`, and restarted the
  PDB service.
- `7`: protected FILE# `1`, stopped the GI-managed database, removed the root
  SYSTEM datafile from ASM, restored and recovered in mount mode, and validated
  Clusterware/service state.
- `46`: ASM disk-group planning helper implemented and dry-run validated.
- `47`: OCR planning helper implemented and dry-run validated with `ocrcheck`
  and OCR backup listing evidence. A manual OCR backup was also created.
- `48`: voting-disk planning helper implemented and dry-run validated.
- `49`: ASM SPFILE planning helper implemented and dry-run validated, with
  `srvctl config asm` evidence. An ASM SPFILE backup was created in `+RECO`.
- `60`: RMAN recovery catalog lab created in `CRASHPDB`, target database
  registered, scenario dry-run and execute completed, catalog resync validated,
  and `NOCATALOG` fallback restore-preview checks completed.
- Logical lab reseeding was expanded to include controlled PDB read-only and
  index-only tablespaces: `CRASHSIM_RO_TBS` and `CRASHSIM_INDEX_TBS`.
- `11`: executed safely against `CRASHPDB` by using
  `ORACLE_PDB_SID=CRASHPDB` plus `--schema CRASHSIM_INDEX_LAB`; non-unique
  index loss was validated and the lab objects were reseeded.
- `36`: executed against `CRASHPDB` with `--schema CRASHSIM_INDEX_LAB`;
  non-unique index loss was validated and reseeded.
- `43`: executed against `CRASHPDB` with `--schema CRASHSIM_TABLE_LAB`; table
  loss was validated and reseeded.
- `44`: executed against `CRASHPDB` with `--schema CRASHSIM_SCHEMA_LAB`; schema
  loss was validated and reseeded.
- `27` and `57`: executed against Oracle Home `network/admin` SQL*Net files,
  restored from `.crashsim.bak` copies, and validated with listener status plus
  local SQL*Plus verification. The active listener parameter file is in the Grid
  home, so these scenarios exercised the Oracle Home client/network config path.
- `45`: executed against disposable PDB `CRASHSIM_DROP_PDB` only; the PDB was
  dropped including datafiles and validated absent while `CRASHPDB` remained
  open read write.
- `33`, `34`, `35`, `37`, `38`, `39`, `40`, and `42`: dry-run target selection
  validated in `CRASHPDB`. Destructive execution remains blocked until the
  framework has ASM-aware injection and scenario-specific recovery helpers for
  these PDB datafile/tablespace variants.
- `8`, `12`, `13`, `14`, `15`, `22`, `28`, and `29`: dry-run target
  selection validated. ASM datafile/FRA targets remained provider-specific, and
  ORACLE_HOME execution was intentionally not performed without an external
  restore/reinstall plan.
- `9` and `10`: no valid CDB-root read-only or index-only tablespace target was
  present in this RAC/GI/ASM lab.
- A post-drill targeted RMAN backup captured `CRASHPDB` datafiles `31` and `32`
  for the new logical lab tablespaces, plus the current control file and SPFILE,
  and resynced the recovery catalog.
- `--maa-report`: Oracle MAA readiness reporting implemented and validated on
  the RAC/GI/ASM lab. The report detected a Bronze MAA posture for the current
  GI-managed single-database environment, with baseline backup/recoverability
  checks passing and expected gaps for Gold-or-higher posture because no Data
  Guard, FSFO, or standby topology is configured.

## Two-Node RAC/GI/ASM Follow-Up Validation

The current two-node RAC lab uses Oracle Database 19.31, CDB `CRASHDB`, PDB
`CRASHPDB`, DB unique name `crashdb`, ASM storage, and a RAC service
`crashdb_CRASHPDB.paas.oracle.com` running on instances `crashdb1` and
`crashdb2`.

Additional framework improvements and validations completed:

- `56`: implemented as a RAC service drill. If a singleton service has a
  running source and idle target, the scenario plans a `srvctl relocate service`
  action. If the service is already running on all preferred instances, as in
  this lab, it performs a controlled `srvctl stop service ... -i <instance>` and
  `srvctl start service ... -i <instance>` cycle. The scenario was dry-run
  validated, executed against `crashdb_CRASHPDB.paas.oracle.com`, recovered with
  `--recover 56`, and followed by health validation.
- `27` and `57`: recovery helper coverage was added for filesystem rename
  restore pairs. Both scenarios were re-executed against Oracle Home
  `network/admin` SQL*Net files, restored with `--recover 27` / `--recover 57`,
  and followed by database/PDB health validation.
- `58`: recovery helper coverage was added for filesystem or ACFS wallet-root
  restore pairs. The TDE wallet-root scenario was dry-run checked, executed by
  renaming `/var/opt/oracle/dbaas_acfs/crashdb/wallet_root`, recovered with
  `--recover 58`, and followed by database/PDB health validation.
- `11`, `36`, `43`, and `44`: logical lab objects were reseeded, the scenarios
  were validated and executed against scoped lab schemas, and
  `seed_crashsim_lab.sql` was rerun afterward to restore the logical lab
  objects.
- `28`: validation now reports `PLAN-ONLY`; ORACLE_HOME loss requires an
  external restore/reinstall plan and is intentionally manual-only.
- `45`: validation and execution now require a disposable target PDB whose name
  starts with `CRASHSIM_`. The framework refuses to drop application PDBs such
  as `CRASHPDB`.
- `3`, `46`, `47`, `48`, and `49`: two-node preparation completed on
  2026-06-05. Redo groups were confirmed multiplexed across `+DATACRASHDB` and
  `+LOGCRASHDB`; a fresh manual OCR backup was created in `+GRID`; and an ASM
  SPFILE backup was created in `+RECOCRASHDB`. Dry-runs completed and remained
  correctly gated for destructive execution where the current storage topology
  is not safe.

Final two-node RAC validation showed:

- Database `CRASHDB` open read write
- PDB `CRASHPDB` open read write
- `V$RECOVER_FILE` returned no rows
- `V$DATABASE_BLOCK_CORRUPTION` returned no rows
- Service `crashdb_CRASHPDB.paas.oracle.com` running on `crashdb1` and
  `crashdb2`
- Logical lab users, tables, non-unique indexes, read-only tablespace, and
  index-only tablespace present after reseed
- No remaining `.crashsim.bak` artifacts in the exercised SQL*Net or wallet-root
  paths

Destructive GI execution for `46`, `47`, `48`, and `49` remains blocked in this
lab because OCR, the only voting disk, and the ASM SPFILE are backed by `+GRID`,
all ASM disk groups use `EXTERN` redundancy, and the observed layout has one
ASM disk per disk group with no spare shared disks. Use a purpose-built
redundant GI lab before removing OCR/voting/ASM SPFILE resources.

A guarded preparation helper and runbook were added for the required redundant
GI/ASM lab foundation:

- `crashsim_prepare_redundant_gi_lab.sh`
- `docs/REDUNDANT_GI_LAB_RUNBOOK.md`

The helper can scan the current RAC/GI posture and generate or execute a
`NORMAL`/`HIGH` redundancy `CREATE DISKGROUP` plan once additional shared block
devices are provisioned and visible on all RAC nodes. It intentionally cannot
create OCI shared storage from the database host and does not use existing ASM
member disks.

Final RAC/GI/ASM validation showed:

- Database open read write
- PDB `CRASHPDB` open read write
- `V$RECOVER_FILE` count `0`
- `V$DATABASE_BLOCK_CORRUPTION` count `0`
- Online redo groups `1` through `8` each have two ASM members
- Clusterware database resource `ONLINE/STABLE`
- PDB service running
- No remaining `.crashsim.bak` artifacts
- Post-drill database, control-file, SPFILE, and logical-lab datafile backups
  completed

## Registered Placeholders Needing Implementation

These scenarios are registered and gated, but still need purpose-built
implementation before destructive validation:

- `52`: Data Guard broker configuration unavailable
- `53`: Active Data Guard read-only session pressure
- `54`: snapshot standby conversion practice

## Next Validation Environments

Use GitHub `fmunozalvarez/crashsimulator` as the main repository. Laptop and
server copies should be treated as working copies that pull from, test against,
and push back to GitHub.

Recommended next validation coverage:

- True storage-level current-redo fault injection for scenario `3`
- Redundant GI lab coverage for destructive scenarios `46`, `47`, `48`, and `49`
- Data Guard and Active Data Guard for scenarios `50`, `51`, `52`, `53`, and `54`
- ASM-aware destructive/recovery helpers for remaining PDB and root
  datafile/tablespace scenarios: `8`, `12`, `13`, `15`, `22`, `33`, `34`,
  `35`, `37`, `38`, `40`, and `42`
- Controlled CDB-root read-only/index-only targets for scenarios `9` and `10`
