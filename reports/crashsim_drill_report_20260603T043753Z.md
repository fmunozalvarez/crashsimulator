# CrashSimulator Drill Report

Report timestamp: 2026-06-03T04:37:53Z

## Environment

- Host: `crashserver`
- Database: `CRASHDB`
- DB unique name: `crashdb_test`
- Oracle version: `19.31.0.0.0`
- Role: `PRIMARY`
- CDB: `YES`
- PDB tested: `CRASHPDB`
- RAC: `NO`
- Storage: filesystem/LVM, no ASM
- Backup destination: Oracle Database Backup Service / Object Storage via `SBT_TAPE`

## Completed Drill

The following destructive CrashSimulator V2 scenarios were executed and recovered:

- Scenario 30: PDB loss of one non-system datafile
  - Target before failure: datafile `12`, PDB `CRASHPDB`, tablespace `USERS`
  - Original path renamed by simulator:
    `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST/50A9DC5BA2EB1FD8E0637207F40AF404/datafile/o1_mf_users_o1z3vqpn_.dbf`
  - Recovered path after RMAN restore:
    `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST/50A9DC5BA2EB1FD8E0637207F40AF404/datafile/o1_mf_users_o1zbmrmn_.dbf`

- Scenario 5: Loss of one non-system datafile
  - Target before failure: datafile `7`, CDB root, tablespace `USERS`
  - Original path renamed by simulator:
    `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST/datafile/o1_mf_users_o1z3pq8v_.dbf`
  - Recovered path after RMAN restore:
    `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST/datafile/o1_mf_users_o1zbrjv3_.dbf`

## Protection Before Failure Injection

Before executing scenario 30 and scenario 5, targeted RMAN backups were created:

- `CRASHSIM_S30_PROTECT`: datafile `12`
- `CRASHSIM_S05_PROTECT`: datafile `7`
- `CRASHSIM_CONTROL_PROTECT`: current control file

After scenario 30 was recovered and before scenario 5 was executed, a fresh targeted backup was created:

- `CRASHSIM_S05_POST30_PROTECT`: datafile `7`
- `CRASHSIM_POST30_CONTROL_PROTECT`: current control file

## Recovery Results

- Scenario 30:
  - RMAN restored datafile `12`.
  - RMAN media recovery completed.
  - Database opened successfully.
  - `CRASHPDB` was already open when the recovery script attempted to open it, causing `ORA-65019`; follow-up checks confirmed successful recovery.

- Scenario 5:
  - RMAN restored datafile `7`.
  - RMAN media recovery completed.
  - Database and PDBs opened successfully.
  - RMAN `LIST FAILURE` reported no failures.

## Post-Drill Stabilization

A fresh full backup was taken after both recoveries:

- Backup tag: `CRASHSIM_POSTDRILL_FULL`
  - Backup set `26`, handle `0s4pn45q_28_1_1`
  - Backup set `27`, handle `0t4pn46u_29_1_1`
  - Backup set `28`, handle `0u4pn47n_30_1_1`

Archived redo was backed up:

- Backup tag: `CRASHSIM_POSTDRILL_ARCH`
  - Backup set `30`, handle `104pn48m_32_1_1`
  - Archived redo sequences backed up: thread `1`, sequences `8` through `14`

Current control file was backed up:

- Backup tag: `CRASHSIM_POSTDRILL_CONTROL`
  - Backup set `31`, handle `114pn48v_33_1_1`
  - Control file checkpoint SCN: `3110980`

Control file/SPFILE autobackups were also created during RMAN backup processing:

- `c-1274767557-20260603-07`
- `c-1274767557-20260603-08`

## Backup Validation

RMAN validation completed successfully:

- `RESTORE DATABASE VALIDATE` read and validated the post-drill full backup pieces:
  - `0s4pn45q_28_1_1`
  - `0t4pn46u_29_1_1`
  - `0u4pn47n_30_1_1`
- `VALIDATE DATAFILE 7`: `OK`, marked corrupt `0`
- `VALIDATE DATAFILE 12`: `OK`, marked corrupt `0`
- `LIST FAILURE`: no failures found

## Final Health Check

Final SQL health check showed:

- Database `CRASHDB`: `READ WRITE`, `PRIMARY`, CDB `YES`
- PDB `CRASHPDB`: `READ WRITE`
- `V$RECOVER_FILE`: no rows
- `V$DATABASE_BLOCK_CORRUPTION`: no rows
- Drill target datafiles:
  - File `7`: `AVAILABLE`, `ONLINE`
  - File `12`: `AVAILABLE`, `ONLINE`

## Cleanup

After the fresh full backup and validation completed, the two old renamed drill artifacts were removed:

- `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST/datafile/o1_mf_users_o1z3pq8v_.dbf.20260603_041743.crashsim.bak`
- `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST/50A9DC5BA2EB1FD8E0637207F40AF404/datafile/o1_mf_users_o1z3vqpn_.dbf.20260603_041454.crashsim.bak`

A follow-up search under `/u02/app/oracle/oradata/crashdb_test/CRASHDB_TEST` found no remaining `*.crashsim.bak` artifacts.

## Evidence Files

- `reports/crashsim_postdrill_full_backup_20260603T043753Z.log`
- `reports/crashsim_postdrill_validate_20260603T043753Z.log`
