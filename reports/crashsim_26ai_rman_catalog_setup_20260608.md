# CrashSimulator 26ai RMAN Recovery Catalog Setup

Generated UTC: 2026-06-08

## Environment

- Primary RAC DB unique name: `crashrdb`
- Database name: `CRASHDB`
- Target DBID: `1275206961`
- PDB used for local dev recovery catalog: `CRASHPDB`
- Catalog owner: `RMAN_CATALOG`

## Initial Check

No usable recovery catalog was present before this setup:

- No `RMAN_CATALOG`, `RCAT`, `RMAN_CAT`, or `RCAT_OWNER` schema existed in `CRASHPDB`.
- No recovery catalog metadata views such as `RC_DATABASE`, `RC_BACKUP_SET`, or `RC_RMAN_CONFIGURATION` existed.
- `RMAN target /` reported: `using target database control file instead of recovery catalog`.

## Catalog Creation

Created a local development recovery catalog in `CRASHPDB`.

- User: `RMAN_CATALOG`
- Default tablespace: `USERS`
- Temporary tablespace: `TEMP`
- Quota: unlimited on `USERS`
- Granted role: `RECOVERY_CATALOG_OWNER`
- Account status after setup: `OPEN`

RMAN actions completed:

- Connected to target database `CRASHDB`.
- Connected to catalog database as `RMAN_CATALOG`.
- Executed `CREATE CATALOG`.
- Executed `REGISTER DATABASE`.
- Full resync completed.

## Validation

RMAN validation:

- `REPORT SCHEMA` returned the CDB/PDB datafile inventory.
- `LIST INCARNATION` returned DBID `1275206961` with current incarnation reset SCN `1140537`, reset time `08-JUN-26`.
- `SHOW ALL` returned the target RMAN configuration using the recovery catalog connection.

SQL validation in `CRASHPDB`:

- Catalog views `RC_DATABASE`, `RC_DATABASE_INCARNATION`, `RC_BACKUP_SET`, and `RC_RMAN_CONFIGURATION` are `VALID`.
- `RMAN_CATALOG.RC_DATABASE` contains database `CRASHDB`, DBID `1275206961`.
- `RMAN_CATALOG.RC_DATABASE_INCARNATION` shows `REG_DB_UNIQUE_NAME=CRASHRDB` and current incarnation status `CURRENT`.

## Notes

This is a development lab catalog inside the target CDB/PDB. For production MAA/DR posture, the recovery catalog should normally be hosted in a separate protected database, preferably outside the failure domain of the target database.
