# CrashSimulator Scenario Status

Snapshot date: 2026-06-03

This status reflects the first OCI Base DB Service validation environment:

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
- `11`: drop non-unique indexes outside Oracle schemas
- `12`: loss of a non-system tablespace
- `13`: loss of a temporary tablespace
- `14`: loss of SYSTEM tablespace
- `15`: loss of UNDO tablespace
- `22`: datafile header corruption
- `27`: loss of SQL*Net config files
- `28`: loss of ORACLE_HOME
- `29`: loss of FRA destination
- `33`: PDB loss of one UNDO datafile
- `34`: PDB loss of read-only tablespace
- `35`: PDB loss of index-only tablespace
- `36`: PDB drop non-unique indexes
- `37`: PDB loss of non-system tablespace
- `38`: PDB loss of temporary tablespace
- `39`: PDB loss of SYSTEM tablespace
- `40`: PDB loss of UNDO tablespace
- `42`: PDB SYSTEM file header corruption
- `43`: PDB loss of one user table
- `44`: PDB loss of one user schema
- `45`: drop selected PDB including datafiles
- `50`: standby managed recovery cancelled
- `51`: primary transport destination deferred
- `55`: RAC abort one instance
- `57`: listener config unavailable
- `58`: TDE wallet or keystore unavailable

Re-run `seed_crashsim_lab.sql` before table, schema, or index-loss scenarios.

## Registered Placeholders Needing Implementation

These scenarios are registered and gated, but still use the placeholder handler:

- `46`: ASM data disk group unavailable
- `47`: OCR loss or restore drill
- `48`: voting disk loss or restore drill
- `49`: ASM SPFILE loss
- `52`: Data Guard broker configuration unavailable
- `53`: Active Data Guard read-only session pressure
- `54`: snapshot standby conversion practice
- `56`: RAC service relocation failure practice
- `60`: recovery catalog unavailable

## Next Validation Environments

Use GitHub `fmunozalvarez/crashsimulator` as the main repository. Laptop and
server copies should be treated as working copies that pull from, test against,
and push back to GitHub.

Recommended next validation coverage:

- Multiplexed redo logs for scenarios `3` and `18`
- ASM/Grid Infrastructure for scenarios `46`, `47`, `48`, and `49`
- RAC for scenarios `55` and `56`
- Data Guard and Active Data Guard for scenarios `50`, `51`, `52`, `53`, and `54`
- Logical recovery scenarios after re-seeding lab objects: `11`, `36`, `43`, and `44`
