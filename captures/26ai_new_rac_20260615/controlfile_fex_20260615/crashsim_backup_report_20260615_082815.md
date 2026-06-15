# CrashSimulator Backup Strategy And Recoverability Report

- Generated UTC: `2026-06-15T08:28:18Z`
- Host: `crashrac1-mlprn`
- OS user: `oracle`
- Database: `CRASHDB`
- DB unique name: `crashrac`
- DBID: `1275818439`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Storage: `FEX`
- Cluster type: `RAC`
- Deep RMAN validation: `disabled`
- RMAN repository source requested: `target control file`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_20260615_082815.evidence`

This report estimates recoverability from current database/RMAN metadata and optional RMAN validation output. RTO/RPO values are planning estimates, not guarantees; prove them with timed restore, recovery, and application validation drills.

## Executive Summary

| Field | Value |
| --- | --- |
| Strategy detected | Level 0/full datafile backup strategy observed with archived redo backups |
| Level 0/full cadence | roughly hourly or better; last backup `2026-06-15 08:27:55`, age `0` hours |
| Level 1 incremental cadence | not enough history; last backup `NONE`, age `UNKNOWN` hours |
| Archived redo backup cadence | roughly hourly or better; last backup `2026-06-15 08:27:44`, age `0` hours |
| Visible database size | `13.48` GB across `17` datafiles |
| Backup device types | `DISK` |
| Backup piece device types | `DISK` |
| Backup-only RPO estimate | Backup-only RPO is approximately the age of the latest archived redo backup, currently about 0 hours; actual data loss can be lower if required archived logs and online redo survive locally. |
| Backup/recovery RTO estimate | Potential RTO may be lower if image copies are current and switch-to-copy/roll-forward is practiced. Visible database size is 13.48 GB. Latest Level 0/full backup age is 0 hours. Recent successful backup job duration averages 2.5 minutes and maxes at 2.7 minutes; restore time can differ and must be measured. |

## Backup Health Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Coverage | Every datafile has backup metadata | missing_datafiles=0 | Keep validating restore paths and catalog/control-file metadata retention. |
| `OK` | Baseline | Recent Level 0/full backup | age_hours=0 | Keep Level 0/full backups aligned with restore-time objectives. |
| `OK` | Recoverability | ARCHIVELOG mode | log_mode=ARCHIVELOG | Continue backing archived redo frequently enough to meet RPO. |
| `OK` | RPO | Recent archived redo backup | age_hours=0 | Back up archived redo more frequently than the required backup-only RPO. |
| `OK` | Reliability | No failed RMAN jobs in last 7 days | failed_7d=0, failed_30d=0 | Keep alerting on failed backup jobs. |
| `OK` | Repository | Backup piece status | available=17, expired=0, unavailable=0, deleted=0 | Schedule periodic CROSSCHECK and cleanup obsolete/expired records. |
| `WARN` | Control file | Control file autobackup | DEFAULT/OFF | Enable CONFIGURE CONTROLFILE AUTOBACKUP ON unless an equivalent control-file/SPFILE backup process exists. |
| `OK` | Validation | Recovery/corruption views | recover_files=0, corruption_rows=0 | Continue scheduled validation and corruption monitoring. |
| `OK` | FRA | FRA utilization | fra_used_pct=4.34 | Keep FRA capacity monitored against archive generation and retention. |

## Strategy Interpretation And Recommendations

- Observed strategy: Level 0/full datafile backup strategy observed with archived redo backups.
- RMAN retention policy: `DEFAULT`.
- Control file record keep time: `7` days. If no catalog is used, keep this long enough to preserve restore history for your retention window.
- Backup repository source: `Target control file only for this report run.`.
- RTO guidance: Potential RTO may be lower if image copies are current and switch-to-copy/roll-forward is practiced. Visible database size is 13.48 GB. Latest Level 0/full backup age is 0 hours. Recent successful backup job duration averages 2.5 minutes and maxes at 2.7 minutes; restore time can differ and must be measured.
- RPO guidance: Backup-only RPO is approximately the age of the latest archived redo backup, currently about 0 hours; actual data loss can be lower if required archived logs and online redo survive locally.
- Best-practice direction: run periodic RMAN restore validation, validate selected backups when pieces are suspected missing, keep repository metadata accurate with crosschecks, protect control file/SPFILE backups, and run timed CrashSimulator restore drills to prove actual RTO/RPO.

## SQL Backup Repository Details


## Control-File SQL Backup Evidence

Command: /u02/app/oracle/product/23.0.0.0/dbhome_1/bin/sqlplus -s /\ as\ sysdba @/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_20260615_082815_detail.sql

```text
# Backup SQL Evidence

## Database Backup Context

NAME                                   DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            CDB LOG_MODE     FORCE_LOGGING                           FLASHBACK_ON
-------------------------------------- ------------------------------ ---------------- -------------------- --- ------------ --------------------------------------- ------------------
CRASHDB                                crashrac                       PRIMARY          READ WRITE           YES ARCHIVELOG   YES                                     YES

1 row selected.

## RMAN Configuration

NAME                                   VALUE
-------------------------------------- ------------------------------------------------------------------------------------------------------------------------
SNAPSHOT CONTROLFILE NAME              TO '@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/snapcf_crashdb.f'

1 row selected.

## RMAN Job History - Last 60 Jobs

         SESSION_KEY INPUT_TYPE               STATUS                   START_TIME           END_TIME                  ELAPSED_MINUTES OUTPUT_DEVICE_TYP
-------------------- ------------------------ ------------------------ -------------------- -------------------- -------------------- -----------------
INPUT_BYTES_DISPLAY
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
OUTPUT_BYTES_DISPLAY
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                  40 DB FULL                  COMPLETED                2026-06-15 08:25:30  2026-06-15 08:27:55                   2.4 DISK
    4.99G
    1.33G

                  11 DB FULL                  COMPLETED                2026-06-15 07:38:23  2026-06-15 07:41:02                   2.7 DISK
    5.26G
    1.46G


2 rows selected.

## Observed Job Cadence By Type, Day, And Hour

INPUT_TYPE               START_DAY  ST            JOB_COUNT FIRST_OBSERVED      LAST_OBSERVED
------------------------ ---------- -- -------------------- ------------------- -------------------
DB FULL                  MON        07                    1 2026-06-15 07:38:23 2026-06-15 07:38:23
DB FULL                  MON        08                    1 2026-06-15 08:25:30 2026-06-15 08:25:30

2 rows selected.

## Datafile Backup Coverage

               FILE# FILE_NAME                                                                                                                                              LAST_BACKUP_TIME    LAST_INCREMENTAL_LEVEL BACKUP_STATUS
-------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------ ------------------- ---------------------- ----------------------------------
                   1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/SYSTEM.OMF.40B42F44                                                              2026-06-15 08:26:11                        BACKUP METADATA FOUND
                   2 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/SYSTEM.OMF.512BC355                             2026-06-15 08:27:17                        BACKUP METADATA FOUND
                   3 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/SYSAUX.OMF.628851FE                                                              2026-06-15 08:25:53                        BACKUP METADATA FOUND
                   4 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/SYSAUX.OMF.45305DF7                             2026-06-15 08:27:17                        BACKUP METADATA FOUND
                   5 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/UNDOTBS1.OMF.419C384E                                                            2026-06-15 08:25:38                        BACKUP METADATA FOUND
                   6 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/UNDOTBS1.OMF.78FB1D9F                           2026-06-15 08:27:10                        BACKUP METADATA FOUND
                   7 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/USERS.OMF.3F743F45                                                               2026-06-15 08:25:32                        BACKUP METADATA FOUND
                   8 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/UNDOTBS2.OMF.693AF748                                                            2026-06-15 08:25:31                        BACKUP METADATA FOUND
                   9 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/SYSTEM.OMF.315F7318                             2026-06-15 08:26:44                        BACKUP METADATA FOUND
                  10 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/SYSAUX.OMF.109389C0                             2026-06-15 08:26:44                        BACKUP METADATA FOUND
                  11 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/UNDOTBS1.OMF.33769FD1                           2026-06-15 08:26:34                        BACKUP METADATA FOUND
                  12 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/UNDO_4.OMF.52C0C459                             2026-06-15 08:26:18                        BACKUP METADATA FOUND
                  13 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/USERS.OMF.7F5C6497                              2026-06-15 08:26:21                        BACKUP METADATA FOUND
                  14 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/CRASHSIM_ROOT_RO_TBS.OMF.3E81B6EF                                                2026-06-15 08:25:31                        BACKUP METADATA FOUND
                  15 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/CRASHSIM_ROOT_INDEX_TBS.OMF.7FCFE216                                             2026-06-15 08:25:31                        BACKUP METADATA FOUND
                  16 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/CRASHSIM_RO_TBS.OMF.62D35026                    2026-06-15 08:26:17                        BACKUP METADATA FOUND
                  17 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/CRASHSIM_INDEX_TBS.OMF.3C2C1FD2                 2026-06-15 08:26:17                        BACKUP METADATA FOUND

17 rows selected.

## Datafile Backup Levels - Last 90 Days

BACKUP_CLASS            BACKED_FILE_ENTRIES FIRST_OBSERVED      LAST_OBSERVED
---------------------- -------------------- ------------------- -------------------
FULL/NON-INCREMENTAL                     41 2026-06-15 06:37:13 2026-06-15 08:27:55

1 row selected.

## Backup Piece Status

STATUS                   DEVICE_TYPE                 PIECE_COUNT OLDEST_COMPLETION   LATEST_COMPLETION
------------------------ ------------------ -------------------- ------------------- -------------------
A                        DISK                                 17 2026-06-15 06:37:13 2026-06-15 08:27:55

1 row selected.

## Recent Backup Pieces

               RECID                STAMP STATUS                   DEVICE_TYPE        COMPLETION_TIME                   SIZE_GB COM
-------------------- -------------------- ------------------------ ------------------ -------------------- -------------------- ---
HANDLE
------------------------------------------------------------------------------------------------------------------------------------------------------
                  17           1235982473 A                        DISK               2026-06-15 08:27:55                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235982472.OMF.2FECFC65

                  16           1235982471 A                        DISK               2026-06-15 08:27:51                     0 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnsnf0_CSIM_BASE_260615082525_SPFILE_0.OMF.2EF16019

                  15           1235982468 A                        DISK               2026-06-15 08:27:49                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/ncnnf0_CSIM_BASE_260615082525_CTL_0.OMF.21B58463

                  14           1235982459 A                        DISK               2026-06-15 08:27:44                   .05 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/annnf0_CSIM_BASE_260615082525_ARCH_0.OMF.6AC6F156

                  13           1235982447 A                        DISK               2026-06-15 08:27:32                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235982446.OMF.0D3AA8DC

                  12           1235982411 A                        DISK               2026-06-15 08:27:18                   .22 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445B43E3238B3BCE0630500000A274A/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615082525_0.OMF
.21848FFE

                  11           1235982376 A                        DISK               2026-06-15 08:26:44                   .23 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615082525_0.OMF
.46789514

                  10           1235982331 A                        DISK               2026-06-15 08:26:11                   .34 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615082525_0.OMF.2F34BEEF

                   9           1235979659 A                        DISK               2026-06-15 07:41:01                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235979659.OMF.4B00A687

                   7           1235979656 A                        DISK               2026-06-15 07:40:57                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/ncnnf0_CSIM_BASE_260615073817_CTL_0.OMF.3C244ED6

                   8           1235979657 A                        DISK               2026-06-15 07:40:57                     0 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnsnf0_CSIM_BASE_260615073817_SPFILE_0.OMF.475DF89E

                   6           1235979629 A                        DISK               2026-06-15 07:40:50                   .17 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/annnf0_CSIM_BASE_260615073817_ARCH_0.OMF.15026A01

                   5           1235979620 A                        DISK               2026-06-15 07:40:21                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235979619.OMF.2F36F593

                   4           1235979584 A                        DISK               2026-06-15 07:40:10                   .22 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445B43E3238B3BCE0630500000A274A/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615073817_0.OMF
.02C4622F

                   3           1235979549 A                        DISK               2026-06-15 07:39:37                   .23 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615073817_0.OMF
.10BE2406

                   2           1235979503 A                        DISK               2026-06-15 07:39:07                   .34 YES
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615073817_0.OMF.5E326159

                   1           1235975832 A                        DISK               2026-06-15 06:37:13                   .16 NO
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235975831.OMF.012BC195


17 rows selected.

## Archived Redo Backup Coverage - Last 7 Days

             THREAD#            SEQUENCE# FIRST_TIME          COMPLETION_TIME      DEL         BACKUP_COUNT NAME
-------------------- -------------------- ------------------- -------------------- --- -------------------- --------------------------------------
                   1                    2 2026-06-15 06:14:41 2026-06-15 06:27:21  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_2.OMF.756BF48B

                   1                    3 2026-06-15 06:27:20 2026-06-15 06:27:23  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_3.OMF.000BB348

                   1                    4 2026-06-15 06:27:21 2026-06-15 07:37:22  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_4.OMF.0A3610AA

                   1                    5 2026-06-15 07:37:21 2026-06-15 07:38:22  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_5.OMF.71551EE2

                   1                    6 2026-06-15 07:38:21 2026-06-15 07:40:25  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_6.OMF.01D58560

                   1                    7 2026-06-15 07:40:24 2026-06-15 07:40:28  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_7.OMF.043FF6D0

                   1                    8 2026-06-15 07:40:27 2026-06-15 08:19:19  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_8.OMF.20BF0827

                   1                    9 2026-06-15 08:19:18 2026-06-15 08:19:20  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_9.OMF.41900063

                   1                   10 2026-06-15 08:19:19 2026-06-15 08:19:20  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_10.OMF.68DC92F1

                   1                   11 2026-06-15 08:19:22 2026-06-15 08:25:28  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_11.OMF.4F1AC189

                   1                   12 2026-06-15 08:25:28 2026-06-15 08:27:35  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_12.OMF.2D7B9B00

                   1                   13 2026-06-15 08:27:35 2026-06-15 08:27:35  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_1_seq_13.OMF.7D3843D3

                   2                    1 2026-06-15 06:19:19 2026-06-15 06:19:21  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_1.OMF.1D82D40F

                   2                    2 2026-06-15 06:21:29 2026-06-15 06:26:47  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_2.OMF.4433030C

                   2                    3 2026-06-15 06:27:20 2026-06-15 07:37:22  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_3.OMF.6B820DC0

                   2                    4 2026-06-15 07:37:21 2026-06-15 07:38:22  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_4.OMF.55A97809

                   2                    5 2026-06-15 07:38:21 2026-06-15 07:40:25  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_5.OMF.41CEE9A7

                   2                    6 2026-06-15 07:40:25 2026-06-15 07:40:28  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_6.OMF.49F68171

                   2                    7 2026-06-15 07:40:28 2026-06-15 08:18:26  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_7.OMF.27B7BB9D

                   2                    8 2026-06-15 08:19:18 2026-06-15 08:19:20  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_8.OMF.6595ED3E

                   2                    9 2026-06-15 08:19:20 2026-06-15 08:25:29  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_9.OMF.71BB1483

                   2                   10 2026-06-15 08:25:29 2026-06-15 08:27:35  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_10.OMF.2939E116

                   2                   11 2026-06-15 08:27:35 2026-06-15 08:27:38  NO                     1 @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8
                                                                                                            F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026
                                                                                                            _06_15/thread_2_seq_11.OMF.56F894B4


23 rows selected.

## Unbacked Archived Redo Logs

no rows selected

## Backup Corruption Views

SOURCE_NAME                            ROW_COUNT
--------------------------- --------------------
V$DATABASE_BLOCK_CORRUPTION                    0
V$COPY_CORRUPTION                              0
V$BACKUP_CORRUPTION                            0

3 rows selected.

## Files Requiring Media Recovery

no rows selected

## FRA Usage

NAME                                         SPACE_LIMIT_GB        SPACE_USED_GB SPACE_RECLAIMABLE_GB      NUMBER_OF_FILES
-------------------------------------- -------------------- -------------------- -------------------- --------------------
@gB2Ac2II(RECO_HC_HIGHREDUNDANCY)                       440                 19.1                 2.09                   45

1 row selected.

## FRA Usage By File Type

FILE_TYPE                 PERCENT_SPACE_USED PERCENT_SPACE_RECLAIMABLE      NUMBER_OF_FILES
----------------------- -------------------- ------------------------- --------------------
ARCHIVED LOG                             .07                       .07                   23
AUXILIARY DATAFILE COPY                    0                         0                    0
BACKUP PIECE                             .67                        .4                   17
CONTROL FILE                             .04                         0                    1
FLASHBACK LOG                           3.55                         0                    4
FOREIGN ARCHIVED LOG                       0                         0                    0
IMAGE COPY                                 0                         0                    0
REDO LOG                                   0                         0                    0

8 rows selected.

## Data Guard / RPO Adjacent Evidence

             DEST_ID STATUS                   TARGET
-------------------- ------------------------ ----------------
DESTINATION
----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
DB_UNIQUE_NAME                 VALID_NOW        ERROR
------------------------------ ---------------- -----------------------------------------------------------------
                   1 VALID                    PRIMARY
USE_DB_RECOVERY_FILE_DEST
crashrac                       YES

                  10 ALTERNATE                PRIMARY
@gB2Ac2II
crashrac                       UNKNOWN


2 rows selected.


no rows selected

```

## RMAN Repository, Restore Preview, Need-Backup, And Obsolete Report

Repository source requested: `target control file`

Command: `rman target / cmdfile=/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_20260615_082815_repository.rman log=/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_20260615_082815_repository.log`

```text

Recovery Manager: Release 23.26.2.0.0 - Production on Mon Jun 15 08:28:20 2026
Version 23.26.2.0.0

Copyright (c) 1982, 2026, Oracle and/or its affiliates.  All rights reserved.

connected to target database: CRASHDB (DBID=1275818439)

RMAN> show all;
2> list backup summary;
3> list backup of database summary;
4> list backup of archivelog all summary;
5> list expired backup summary;
6> list expired archivelog all;
7> report schema;
8> report need backup;
9> report obsolete;
10> restore database preview summary;
11> exit;
using target database control file instead of recovery catalog
RMAN configuration parameters for database with db_unique_name CRASHRAC are:
CONFIGURE RETENTION POLICY TO REDUNDANCY 1; # default
CONFIGURE BACKUP OPTIMIZATION OFF; # default
CONFIGURE DEFAULT DEVICE TYPE TO DISK; # default
CONFIGURE CONTROLFILE AUTOBACKUP ON; # default
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '%F'; # default
CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET; # default
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE MAXSETSIZE TO UNLIMITED; # default
CONFIGURE ENCRYPTION FOR DATABASE OFF; # default
CONFIGURE ENCRYPTION ALGORITHM 'AES256'; # default
CONFIGURE COMPRESSION ALGORITHM 'BASIC' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE ; # default
CONFIGURE RMAN OUTPUT TO KEEP FOR 7 DAYS; # default
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE; # default
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/snapcf_crashdb.f';


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
1       B  F  A DISK        15-JUN-26       1       1       NO         TAG20260615T063711
2       B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817
3       B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817
4       B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817
5       B  F  A DISK        15-JUN-26       1       1       NO         TAG20260615T074019
6       B  A  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817_ARCH
7       B  F  A DISK        15-JUN-26       1       1       NO         CSIM_BASE_260615073817_CTL
8       B  F  A DISK        15-JUN-26       1       1       NO         CSIM_BASE_260615073817_SPFILE
9       B  F  A DISK        15-JUN-26       1       1       NO         TAG20260615T074059
10      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
11      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
12      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
13      B  F  A DISK        15-JUN-26       1       1       NO         TAG20260615T082726
14      B  A  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525_ARCH
15      B  F  A DISK        15-JUN-26       1       1       NO         CSIM_BASE_260615082525_CTL
16      B  F  A DISK        15-JUN-26       1       1       NO         CSIM_BASE_260615082525_SPFILE
17      B  F  A DISK        15-JUN-26       1       1       NO         TAG20260615T082752


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
2       B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817
3       B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817
4       B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817
10      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
11      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
12      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
6       B  A  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615073817_ARCH
14      B  A  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525_ARCH

specification does not match any backup in the repository

specification does not match any archived log in the repository

Report of database schema for database with db_unique_name CRASHRAC

List of Permanent Datafiles
===========================
File Size(MB) Tablespace           RB segs Datafile Name
---- -------- -------------------- ------- ------------------------
1    2000     SYSTEM               YES     @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/SYSTEM.OMF.40B42F44
2    600      PDB$SEED:SYSTEM      NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/SYSTEM.OMF.512BC355
3    2000     SYSAUX               NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/SYSAUX.OMF.628851FE
4    600      PDB$SEED:SYSAUX      NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/SYSAUX.OMF.45305DF7
5    2000     UNDOTBS1             YES     @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/UNDOTBS1.OMF.419C384E
6    600      PDB$SEED:UNDOTBS1    NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/UNDOTBS1.OMF.78FB1D9F
7    1024     USERS                NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/USERS.OMF.3F743F45
8    2000     UNDOTBS2             YES     @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/UNDOTBS2.OMF.693AF748
9    600      CRASHPDB:SYSTEM      YES     @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/SYSTEM.OMF.315F7318
10   600      CRASHPDB:SYSAUX      NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/SYSAUX.OMF.109389C0
11   600      CRASHPDB:UNDOTBS1    YES     @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/UNDOTBS1.OMF.33769FD1
12   95       CRASHPDB:UNDO_4      YES     @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/UNDO_4.OMF.52C0C459
13   1024     CRASHPDB:USERS       NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/USERS.OMF.7F5C6497
14   16       CRASHSIM_ROOT_RO_TBS NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/CRASHSIM_ROOT_RO_TBS.OMF.3E81B6EF
15   16       CRASHSIM_ROOT_INDEX_TBS NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/DATAFILE/CRASHSIM_ROOT_INDEX_TBS.OMF.7FCFE216
16   16       CRASHPDB:CRASHSIM_RO_TBS NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/CRASHSIM_RO_TBS.OMF.62D35026
17   16       CRASHPDB:CRASHSIM_INDEX_TBS NO      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/DATAFILE/CRASHSIM_INDEX_TBS.OMF.3C2C1FD2

List of Temporary Files
=======================
File Size(MB) Tablespace           Maxsize(MB) Tempfile Name
---- -------- -------------------- ----------- --------------------
1    17408    TEMP                 524288      @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/TEMPFILE/TEMP.OMF.342C3C00
2    5096     PDB$SEED:TEMP        33554431    @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5096C84B7BB5210CE0636C0DF40A1151/DATAFILE/temp012026-06-15_06-11-58-679-AM.dbf
4    1024     CRASHPDB:TEMP        33554431    @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/TEMPFILE/TEMP.OMF.16334B28

RMAN retention policy will be applied to the command
RMAN retention policy is set to redundancy 1
Report of files with less than 1 redundant backups
File #bkps Name
---- ----- -----------------------------------------------------

RMAN retention policy will be applied to the command
RMAN retention policy is set to redundancy 1
Report of obsolete backups and copies
Type                 Key    Completion Time    Filename/Handle
-------------------- ------ ------------------ --------------------
Backup Set           1      15-JUN-26         
  Backup Piece       1      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235975831.OMF.012BC195
Backup Set           2      15-JUN-26         
  Backup Piece       2      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615073817_0.OMF.5E326159
Backup Set           3      15-JUN-26         
  Backup Piece       3      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445D83CA62AD33EE0630500000AB777/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615073817_0.OMF.10BE2406
Backup Set           4      15-JUN-26         
  Backup Piece       4      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/5445B43E3238B3BCE0630500000A274A/BACKUPSET/2026_06_15/nnndf0_CSIM_BASE_260615073817_0.OMF.02C4622F
Backup Set           5      15-JUN-26         
  Backup Piece       5      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235979619.OMF.2F36F593
Backup Set           7      15-JUN-26         
  Backup Piece       7      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/ncnnf0_CSIM_BASE_260615073817_CTL_0.OMF.3C244ED6
Backup Set           8      15-JUN-26         
  Backup Piece       8      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnsnf0_CSIM_BASE_260615073817_SPFILE_0.OMF.475DF89E
Control File Copy     4      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_081819.ctl
Backup Set           9      15-JUN-26         
  Backup Piece       9      15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235979659.OMF.4B00A687
Backup Set           13     15-JUN-26         
  Backup Piece       13     15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/AUTOBACKUP/2026_06_15/s_1235982446.OMF.0D3AA8DC
Backup Set           15     15-JUN-26         
  Backup Piece       15     15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/ncnnf0_CSIM_BASE_260615082525_CTL_0.OMF.21B58463
Backup Set           16     15-JUN-26         
  Backup Piece       16     15-JUN-26          @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/BACKUPSET/2026_06_15/nnsnf0_CSIM_BASE_260615082525_SPFILE_0.OMF.2EF16019

Starting restore at 15-JUN-26
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=2355 instance=crashdb1 device type=DISK


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
10      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
12      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
11      B  F  A DISK        15-JUN-26       1       1       YES        CSIM_BASE_260615082525
using channel ORA_DISK_1

List of Archived Log Copies for database with db_unique_name CRASHRAC
=====================================================================

Key     Thrd Seq     S Low Time 
------- ---- ------- - ---------
21      1    12      A 15-JUN-26
        Name: @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026_06_15/thread_1_seq_12.OMF.2D7B9B00

22      1    13      A 15-JUN-26
        Name: @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026_06_15/thread_1_seq_13.OMF.7D3843D3

20      2    10      A 15-JUN-26
        Name: @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026_06_15/thread_2_seq_10.OMF.2939E116

23      2    11      A 15-JUN-26
        Name: @gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/ARCHIVELOG/2026_06_15/thread_2_seq_11.OMF.56F894B4

recovery will be done up to SCN 1269262
Media recovery start SCN is 1269058
Recovery must be done beyond SCN 1269103 to clear datafile fuzziness
Finished restore at 15-JUN-26

Recovery Manager complete.
```

## RMAN Deep Validation

Skipped by default. Re-run with `--deep-validate` or set `CRASHSIM_REPORT_DEEP_VALIDATE=1` to run `RESTORE DATABASE VALIDATE`, `RESTORE ARCHIVELOG ALL VALIDATE`, and `VALIDATE DATABASE CHECK LOGICAL`. Those checks are read-only but can be I/O intensive, especially for SBT/Object Storage.

## References

- Oracle Database 19c backup and recovery administration: https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/performing-backup-and-recovery.html
- Oracle Maximum Availability Architecture overview: https://www.oracle.com/database/technologies/maximum-availability-architecture/
- CrashSimulator RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery

## Raw Backup Evidence

Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_20260615_082815.evidence`

```text
CSIM_BKP|db_name|CRASHDB
CSIM_BKP|db_unique_name|crashrac
CSIM_BKP|dbid|1275818439
CSIM_BKP|database_role|PRIMARY
CSIM_BKP|open_mode|READ WRITE
CSIM_BKP|cdb|YES
CSIM_BKP|log_mode|ARCHIVELOG
CSIM_BKP|force_logging|YES
CSIM_BKP|flashback_on|YES
CSIM_BKP|platform_name|Linux x86 64-bit
CSIM_BKP|control_file_record_keep_time|7
CSIM_BKP|archive_lag_target|0
CSIM_BKP|db_recovery_file_dest|@gB2Ac2II(RECO_HC_HIGHREDUNDANCY)
CSIM_BKP|rman_retention_policy|DEFAULT
CSIM_BKP|rman_controlfile_autobackup|DEFAULT/OFF
CSIM_BKP|rman_backup_optimization|DEFAULT/OFF
CSIM_BKP|rman_encryption|DEFAULT
CSIM_BKP|rman_compression|DEFAULT
CSIM_BKP|rman_channel_config_count|0
CSIM_BKP|datafile_count|17
CSIM_BKP|tempfile_count|3
CSIM_BKP|database_size_gb|13.48
CSIM_BKP|datafile_copy_count|4
CSIM_BKP|datafiles_without_backup_metadata|0
CSIM_BKP|oldest_datafile_backup_time|2026-06-15 08:25:31
CSIM_BKP|last_datafile_backup_time|2026-06-15 08:27:55
CSIM_BKP|last_datafile_backup_age_hours|0
CSIM_BKP|last_level0_backup_time|2026-06-15 08:27:55
CSIM_BKP|last_level0_backup_age_hours|0
CSIM_BKP|last_level1_backup_time|NONE
CSIM_BKP|last_level1_backup_age_hours|UNKNOWN
CSIM_BKP|level0_count_30d|13
CSIM_BKP|level1_count_30d|0
CSIM_BKP|level0_avg_gap_hours|.1
CSIM_BKP|level1_avg_gap_hours|UNKNOWN
CSIM_BKP|successful_jobs_7d|2
CSIM_BKP|failed_jobs_7d|0
CSIM_BKP|successful_jobs_30d|2
CSIM_BKP|failed_jobs_30d|0
CSIM_BKP|last_successful_job_time|2026-06-15 08:27:55
CSIM_BKP|last_successful_job_age_hours|0
CSIM_BKP|backup_device_types|DISK
CSIM_BKP|avg_successful_job_elapsed_minutes_30d|2.5
CSIM_BKP|max_successful_job_elapsed_minutes_30d|2.7
CSIM_BKP|archivelog_backup_sets_30d|2
CSIM_BKP|last_archivelog_backup_time|2026-06-15 08:27:44
CSIM_BKP|last_archivelog_backup_age_hours|0
CSIM_BKP|archivelog_backup_avg_gap_hours|.8
CSIM_BKP|archivelogs_known_7d|23
CSIM_BKP|archivelogs_not_backed_7d|0
CSIM_BKP|oldest_unbacked_archivelog_time|NONE
CSIM_BKP|oldest_unbacked_archivelog_age_hours|UNKNOWN
CSIM_BKP|latest_archivelog_time|2026-06-15 08:27:38
CSIM_BKP|controlfile_backup_count_30d|7
CSIM_BKP|last_controlfile_backup_time|2026-06-15 08:27:55
CSIM_BKP|last_controlfile_backup_age_hours|0
CSIM_BKP|backup_piece_available_count|17
CSIM_BKP|backup_piece_expired_count|0
CSIM_BKP|backup_piece_deleted_count|0
CSIM_BKP|backup_piece_unavailable_count|0
CSIM_BKP|latest_backup_piece_time|2026-06-15 08:27:55
CSIM_BKP|backup_piece_device_types|DISK
CSIM_BKP|recover_file_count|0
CSIM_BKP|block_corruption_count|0
CSIM_BKP|copy_corruption_count|0
CSIM_BKP|backup_corruption_count|0
CSIM_BKP|fra_configured|YES
CSIM_BKP|fra_used_pct|4.34
CSIM_BKP|fra_reclaimable_pct|.47
CSIM_BKP|remote_standby_dest_count|0
CSIM_BKP|valid_remote_standby_dest_count|0
CSIM_BKP|standby_dest_error_count|0
CSIM_BKP|archive_gap_count|0
CSIM_BKP|dataguard_transport_lag|UNKNOWN
CSIM_BKP|dataguard_apply_lag|UNKNOWN
```
