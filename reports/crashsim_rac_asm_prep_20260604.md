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
  - Scenario `46`: ASM placeholder gate
  - Scenario `47`: GI placeholder gate
  - Scenario `55`: GI-managed instance abort target selection

## Health Check Result

- Database `CRASHDB`: `READ WRITE`, `PRIMARY`, CDB `YES`
- PDB `CRASHPDB`: `READ WRITE`
- `V$RECOVER_FILE`: no rows
- `V$DATABASE_BLOCK_CORRUPTION`: no rows
- USERS datafiles are ASM files under `+DATA`

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

## Readiness Notes

- Scenario `55` is the first realistic HA drill candidate in this environment:
  it dry-runs to `srvctl_abort_instance crashdb`.
- Datafile scenarios such as `30` correctly identify ASM targets, but should not
  be executed until an ASM-aware crash-injection helper is implemented.
- ASM/GI scenarios `46`, `47`, `48`, and `49` remain registered placeholders and
  need implementation before destructive execution.
- Continue with dry-run, protect where available, execute, recover, health check,
  and post-drill backup discipline for every scenario.
