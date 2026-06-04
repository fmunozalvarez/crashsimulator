# CrashSimulator RAC/GI/ASM Prep Report

Report timestamp: 2026-06-04

## Environment

- Host: `crashserver2`
- Oracle version family: 19c, database home `/u01/app/oracle/product/19.0.0.0/dbhome_1`
- Grid home: `/u01/app/19.0.0.0/grid`
- Database: `CRASHDB`
- DB unique name: `crashdb_test2`
- Instance/SID: `crashdb`
- Role/open mode: `PRIMARY`, `READ WRITE`
- CDB: `YES`
- PDB: `CRASHPDB`, `READ WRITE`
- Clusterware managed: yes
- CrashSimulator detected cluster type: `GI_SINGLE`
- Storage: ASM
- ASM disk groups observed: `DATA`, `RECO`
- SPFILE: `+DATA/CRASHDB_TEST2/PARAMETERFILE/spfile.261.1234929739`
- FRA: `+RECO`
- Redo log posture after validation: three groups, each multiplexed with one
  member in `+RECO` and one member in `+DATA`
- OCR/voting posture: OCR in `+DATA`; one voting disk in `DATA`; `DATA` uses
  `EXTERN` redundancy

## Preparation Completed

- Copied current CrashSimulator framework and helper scripts to `/tmp/crashsimulator`.
- Changed the staging directory owner to `oracle:oinstall` so logs/manifests can be written.
- Ran `bash -n CrashSimulatorV2.sh` successfully on the server.
- Ran `--list` successfully.
- Ran `--discover` successfully after patching detection.
- Ran `--health-check` successfully.
- Ran dry-runs for:
  - Scenario `30`: PDB non-system datafile target selection
  - Scenario `46`: ASM disk-group planning helper
  - Scenario `47`: OCR planning helper
  - Scenario `55`: GI-managed instance abort target selection
- Re-ran scenario `55` after patching GI-managed single-database behavior:
  - Initial `srvctl stop instance -d crashdb_test2 -i crashdb -o abort` failed
    safely with `PRCD-1035` because the resource is not a cluster database.
  - Patched scenario `55` on `GI_SINGLE` to use
    `srvctl stop database -d crashdb_test2 -o abort`.
  - Executed the corrected scenario; database and service stopped under
    Clusterware control.
  - Recovered manually with `srvctl start database -d crashdb_test2`.
  - Validated the `--recover 55 --execute` helper against the recovered state.
- Ran ASM datafile scenarios `30`, `7`, `32`, and `41` in dry-run/protect-only
  mode. No ASM datafile crash injection was executed.
- Ran scenario-helper dry-runs for `46`, `47`, `48`, and `49`.
- Added a second redo member in `+DATA` to redo groups `1`, `2`, and `3`.
- Executed scenario `18` by removing an inactive multiplexed `+DATA` redo
  member as `grid`, then recovered with the framework ASM redo helper.
- Attempted scenario `3` current-member injection safely:
  - `asmcmd rm` refused the current member with ORA-15028 because it was in use.
  - `alter database drop logfile member` refused it with ORA-01609 because the
    group was current.
  - No forced lower-level disk failure was attempted in this single-node lab.
- Executed ASM datafile scenarios:
  - `30`: protected FILE# `12`, removed the PDB USERS datafile, recovered and
    reopened `CRASHPDB`.
  - `32`: protected FILE# `8`, removed the PDB SYSTEM datafile, recovered with
    direct RMAN FILE# recovery, and reopened `CRASHPDB`.
  - `41`: protected FILE# `8,9,10,12`, removed all `CRASHPDB` datafiles,
    recovered the FILE# list, reopened `CRASHPDB`, and restarted the PDB service.
  - `7`: protected FILE# `1`, stopped the GI-managed database, removed the root
    SYSTEM datafile, recovered in mount mode, and validated Clusterware/service
    state.
- Ran safe GI/ASM validations:
  - Created an OCR manual backup with `ocrconfig -manualbackup`.
  - Created an ASM SPFILE backup in `+RECO/CRASHSIM_BACKUP`.
  - Re-ran helpers `46`, `47`, `48`, and `49` in dry-run evidence mode.
- Ran a post-drill stabilization backup:
  - Full database backup tag `CSIM_POST_RAC_ASM_20260604`
  - Current control file backup tag `CSIM_POST_RAC_ASM_20260604_CTL`
  - SPFILE backup tag `CSIM_POST_ASM_SPFILE`

## Health Check Result

- Database `CRASHDB`: `READ WRITE`, `PRIMARY`, CDB `YES`
- PDB `CRASHPDB`: `READ WRITE`
- `V$RECOVER_FILE`: no rows
- `V$DATABASE_BLOCK_CORRUPTION`: no rows
- USERS datafiles are ASM files under `+DATA`
- Post-scenario-55 validation: `srvctl status database` and
  `srvctl status service` showed the database instance and PDB service running.
- Final post-batch validation: database `READ WRITE`, `CRASHPDB` `READ WRITE`,
  no rows in `V$RECOVER_FILE`, no rows in `V$DATABASE_BLOCK_CORRUPTION`,
  Clusterware resource `ONLINE/STABLE`, PDB service running, and no
  `.crashsim.bak` leftovers.

## Framework Fixes From Prep

- ASM detection now checks `V$DATAFILE`, `V$TEMPFILE`, control files, SPFILE,
  and FRA parameters, and handles SQL*Plus leading whitespace.
- GI-managed databases with `srvctl Type: SINGLE` are reported as `GI_SINGLE`
  instead of plain `SINGLE`.
- RAC requirement gates now allow RAC, RAC One Node-style, and GI-managed
  database topologies for srvctl instance-abort practice.
- ASM targets are now shown as provider-specific `external` actions instead of
  misleading filesystem rename/corruption actions.
- Manifests now include `cluster_type` and `gi_managed`.
- Scenario `55` now distinguishes RAC parallel instance abort from
  GI-managed single-database abort. `GI_SINGLE` plans
  `srvctl_abort_database crashdb_test2`.
- `--recover 55` now performs `srvctl` database/service status checks, starts
  the database/services when needed, and finishes with framework health
  validation.
- Scenario helpers for `46`, `47`, `48`, and `49` now collect non-destructive
  ASM/GI evidence and emit external plans:
  - `46`: ASM disk groups from `V$ASM_DISKGROUP`
  - `47`: `ocrcheck` and OCR backup listing
  - `48`: `crsctl query css votedisk`
  - `49`: `srvctl config asm` and optional `asmcmd spget`
- RMAN protection planning now collects FILE# metadata from ASM/external
  datafile targets. Example: scenario `41` on `CRASHPDB` planned datafiles
  `8,9,10,12` while still refusing destructive ASM file injection.
- Target harvesting for `--protect` no longer prints the later scenario abort
  step.
- PDB-scoped datafile recovery now restores/recover FILE# targets while the CDB
  remains open and the target PDB is closed, instead of forcing a full CDB mount.
- Datafile-list recovery can now read FILE# metadata from both scenario
  manifests and protection manifests.
- Redo recovery can now use ASM redo metadata from a manifest to drop a missing
  member, add a replacement OMF member to the same disk group, switch logs, and
  validate the database.

## Readiness Notes

- Scenario `55` is validated for this `GI_SINGLE` environment using
  database-level `srvctl` abort/restart behavior.
- Datafile scenarios `30`, `7`, `32`, and `41` were destructively validated on
  ASM using RMAN protection, Grid-owner ASM file removal, RMAN recovery, and
  post-recovery health checks.
- Scenario `18` was destructively validated after redo multiplexing.
- Scenario `3` needs a true storage-level current-redo fault injector; Oracle
  and ASM correctly refused safe logical/ASM removal of a current member.
- ASM/GI scenarios `46`, `47`, `48`, and `49` should remain non-destructive in
  this lab because `DATA` holds OCR and the only voting disk with `EXTERN`
  redundancy. Use a purpose-built GI lab with redundant OCR/voting placement for
  destructive validation.
- Continue with dry-run, protect where available, execute, recover, health check,
  and post-drill backup discipline for every scenario.
