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

## Health Check Result

- Database `CRASHDB`: `READ WRITE`, `PRIMARY`, CDB `YES`
- PDB `CRASHPDB`: `READ WRITE`
- `V$RECOVER_FILE`: no rows
- `V$DATABASE_BLOCK_CORRUPTION`: no rows
- USERS datafiles are ASM files under `+DATA`
- Post-scenario-55 validation: `srvctl status database` and
  `srvctl status service` showed the database instance and PDB service running.

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

## Readiness Notes

- Scenario `55` is validated for this `GI_SINGLE` environment using
  database-level `srvctl` abort/restart behavior.
- Datafile scenarios `30`, `7`, `32`, and `41` correctly identify ASM targets
  and can plan RMAN protection by FILE#. They should not be destructively
  executed until an ASM-aware crash-injection helper is implemented.
- ASM/GI scenarios `46`, `47`, `48`, and `49` now have non-destructive planning
  helpers, but still need explicit root/Grid/ASM recovery procedures before
  destructive execution.
- Continue with dry-run, protect where available, execute, recover, health check,
  and post-drill backup discipline for every scenario.
