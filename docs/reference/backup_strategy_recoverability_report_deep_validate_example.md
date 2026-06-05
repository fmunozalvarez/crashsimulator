> Reference example: sanitized output generated from a CrashSimulator RAC/ASM lab report. Values such as hostnames, DBID, ASM disk groups, temp paths, and provider-specific backup configuration have been anonymized.
>
# CrashSimulator Backup Strategy And Recoverability Report

- Generated UTC: `2026-06-05T03:35:35Z`
- Host: `rac-node1.example.com`
- OS user: `oracle`
- Database: `CRASHDB`
- DB unique name: `crashdb`
- DBID: `1234567890`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Storage: `ASM`
- Cluster type: `RAC`
- Deep RMAN validation: `enabled`
- RMAN repository source requested: `target control file`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLE.evidence`

This report estimates recoverability from current database/RMAN metadata and optional RMAN validation output. RTO/RPO values are planning estimates, not guarantees; prove them with timed restore, recovery, and application validation drills.

## Executive Summary

| Field | Value |
| --- | --- |
| Strategy detected | Level 0/full datafile backup strategy observed with archived redo backups |
| Level 0/full cadence | roughly hourly or better; last backup `2026-06-05 01:55:57`, age `1.7` hours |
| Level 1 incremental cadence | not enough history; last backup `NONE`, age `UNKNOWN` hours |
| Archived redo backup cadence | roughly hourly or better; last backup `2026-06-05 03:27:15`, age `0.1` hours |
| Visible database size | `14.41` GB across `14` datafiles |
| Backup device types | `SBT_TAPE,UNKNOWN` |
| Backup piece device types | `DISK,SBT_TAPE` |
| Backup-only RPO estimate | Backup-only RPO is approximately the age of the latest archived redo backup, currently about 0.1 hours; actual data loss can be lower if required archived logs and online redo survive locally. |
| Backup/recovery RTO estimate | Potential RTO may be lower if image copies are current and switch-to-copy/roll-forward is practiced. Visible database size is 14.41 GB. Latest Level 0/full backup age is 1.7 hours. Recent successful backup job duration averages 0.5 minutes and maxes at 1.3 minutes; restore time can differ and must be measured. |

## Backup Health Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Coverage | Every datafile has backup metadata | missing_datafiles=0 | Keep validating restore paths and catalog/control-file metadata retention. |
| `OK` | Baseline | Recent Level 0/full backup | age_hours=1.7 | Keep Level 0/full backups aligned with restore-time objectives. |
| `OK` | Recoverability | ARCHIVELOG mode | log_mode=ARCHIVELOG | Continue backing archived redo frequently enough to meet RPO. |
| `OK` | RPO | Recent archived redo backup | age_hours=0.1 | Back up archived redo more frequently than the required backup-only RPO. |
| `WARN` | Reliability | Failed RMAN jobs | failed_7d=1, failed_30d=1 | Investigate failed backup jobs and confirm they did not break required backup windows. |
| `OK` | Repository | Backup piece status | available=56, expired=0, unavailable=0, deleted=0 | Schedule periodic CROSSCHECK and cleanup obsolete/expired records. |
| `OK` | Control file | Control file autobackup | ON | Keep autobackup enabled and test restore controlfile from autobackup. |
| `OK` | Validation | Recovery/corruption views | recover_files=0, corruption_rows=0 | Continue scheduled validation and corruption monitoring. |
| `OK` | FRA | FRA utilization | fra_used_pct=37.14 | Keep FRA capacity monitored against archive generation and retention. |

## Strategy Interpretation And Recommendations

- Observed strategy: Level 0/full datafile backup strategy observed with archived redo backups.
- RMAN retention policy: `TO RECOVERY WINDOW OF 30 DAYS`.
- Control file record keep time: `38` days. If no catalog is used, keep this long enough to preserve restore history for your retention window.
- Backup repository source: `Target control file only for this report run.`.
- RTO guidance: Potential RTO may be lower if image copies are current and switch-to-copy/roll-forward is practiced. Visible database size is 14.41 GB. Latest Level 0/full backup age is 1.7 hours. Recent successful backup job duration averages 0.5 minutes and maxes at 1.3 minutes; restore time can differ and must be measured.
- RPO guidance: Backup-only RPO is approximately the age of the latest archived redo backup, currently about 0.1 hours; actual data loss can be lower if required archived logs and online redo survive locally.
- Best-practice direction: run periodic RMAN restore validation, validate selected backups when pieces are suspected missing, keep repository metadata accurate with crosschecks, protect control file/SPFILE backups, and run timed CrashSimulator restore drills to prove actual RTO/RPO.

## SQL Backup Repository Details


## Control-File SQL Backup Evidence

Command: /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /\ as\ sysdba @/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLE_detail.sql

```text
# Backup SQL Evidence

## Database Backup Context

NAME                                   DB_UNIQUE_NAME                 DATABASE_ROLE    OPEN_MODE            CDB LOG_MODE     FORCE_LOGGING                           FLASHBACK_ON
-------------------------------------- ------------------------------ ---------------- -------------------- --- ------------ --------------------------------------- ------------------
CRASHDB                                crashdb                        PRIMARY          READ WRITE           YES ARCHIVELOG   YES                                     YES

1 row selected.

## RMAN Configuration

NAME                                   VALUE
-------------------------------------- ------------------------------------------------------------------------------------------------------------------------
BACKUP OPTIMIZATION                    ON
CHANNEL                                DEVICE TYPE 'SBT_TAPE' PARMS  'SBT_LIBRARY=/opt/oracle/backup/libopc.so ENV=(OPC_PFILE=/opt/oracle/backup/opcdb.ora)'

COMPRESSION ALGORITHM                  'low' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE
CONTROLFILE AUTOBACKUP                 ON
DEFAULT DEVICE TYPE TO                 'SBT_TAPE'
DEVICE TYPE                            'SBT_TAPE' BACKUP TYPE TO COMPRESSED BACKUPSET PARALLELISM 4
ENCRYPTION ALGORITHM                   'AES256'
ENCRYPTION FOR DATABASE                ON
RETENTION POLICY                       TO RECOVERY WINDOW OF 30 DAYS
SNAPSHOT CONTROLFILE NAME              TO '+RECO/crashdb/controlfile/snapcf_crashdb.f'

10 rows selected.

## RMAN Job History - Last 60 Jobs

         SESSION_KEY INPUT_TYPE               STATUS                   START_TIME           END_TIME                  ELAPSED_MINUTES OUTPUT_DEVICE_TYP
-------------------- ------------------------ ------------------------ -------------------- -------------------- -------------------- -----------------
INPUT_BYTES_DISPLAY
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
OUTPUT_BYTES_DISPLAY
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                 154 ARCHIVELOG               COMPLETED                2026-06-05 03:27:12  2026-06-05 03:27:20                    .1 SBT_TAPE
  169.33M
    3.25M

                 137 DB FULL                  COMPLETED                2026-06-05 03:24:46  2026-06-05 03:26:06                   1.3 SBT_TAPE
    6.87G
    1.58G

                 135 DB FULL                  FAILED                   2026-06-05 03:23:34  2026-06-05 03:23:35                     0
    0.00K
    0.00K

                 129 ARCHIVELOG               COMPLETED                2026-06-05 03:19:09  2026-06-05 03:19:18                    .2 SBT_TAPE
  185.86M
   20.00M

                  59 ARCHIVELOG               COMPLETED                2026-06-05 02:57:09  2026-06-05 02:57:20                    .2 SBT_TAPE
  256.75M
   91.50M

                  38 CONTROLFILE              COMPLETED                2026-06-05 02:33:53  2026-06-05 02:34:03                    .2 SBT_TAPE
  334.69M
    2.50M

                  34 ARCHIVELOG               COMPLETED                2026-06-05 02:27:09  2026-06-05 02:27:20                    .2 SBT_TAPE
  221.69M
   56.00M

                  18 DB INCR                  COMPLETED                2026-06-05 01:54:55  2026-06-05 01:56:04                   1.2 SBT_TAPE
    5.91G
    1.56G

                  11 ARCHIVELOG               COMPLETED                2026-06-05 01:49:09  2026-06-05 01:49:37                    .5 SBT_TAPE
  535.53M
  370.00M


9 rows selected.

## Observed Job Cadence By Type, Day, And Hour

INPUT_TYPE               START_DAY  ST            JOB_COUNT FIRST_OBSERVED      LAST_OBSERVED
------------------------ ---------- -- -------------------- ------------------- -------------------
ARCHIVELOG               FRI        02                    2 2026-06-05 02:27:09 2026-06-05 02:57:09
ARCHIVELOG               FRI        03                    2 2026-06-05 03:19:09 2026-06-05 03:27:12
ARCHIVELOG               FRI        01                    1 2026-06-05 01:49:09 2026-06-05 01:49:09
CONTROLFILE              FRI        02                    1 2026-06-05 02:33:53 2026-06-05 02:33:53
DB FULL                  FRI        03                    2 2026-06-05 03:23:34 2026-06-05 03:24:46
DB INCR                  FRI        01                    1 2026-06-05 01:54:55 2026-06-05 01:54:55

6 rows selected.

## Datafile Backup Coverage

               FILE# FILE_NAME                                                                                                                                              LAST_BACKUP_TIME    LAST_INCREMENTAL_LEVEL BACKUP_STATUS
-------------------- ------------------------------------------------------------------------------------------------------------------------------------------------------ ------------------- ---------------------- ----------------------------------
                   1 +DATA/CRASHDB/DATAFILE/system.258.1235092711                                                                                                    2026-06-05 03:25:19                        BACKUP METADATA FOUND
                   2 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.262.1235092459                                                                   2026-06-05 03:25:34                        BACKUP METADATA FOUND
                   3 +DATA/CRASHDB/DATAFILE/sysaux.267.1235092687                                                                                                    2026-06-05 03:25:19                        BACKUP METADATA FOUND
                   4 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.263.1235092459                                                                   2026-06-05 03:25:30                        BACKUP METADATA FOUND
                   5 +DATA/CRASHDB/DATAFILE/undotbs1.257.1235092737                                                                                                  2026-06-05 03:25:11                        BACKUP METADATA FOUND
                   6 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.264.1235092459                                                                 2026-06-05 03:25:29                        BACKUP METADATA FOUND
                   7 +DATA/CRASHDB/DATAFILE/users.259.1235092763                                                                                                     2026-06-05 03:24:53                        BACKUP METADATA FOUND
                   8 +DATA/CRASHDB/DATAFILE/undotbs2.266.1235092685                                                                                                  2026-06-05 03:24:50                        BACKUP METADATA FOUND
                   9 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.274.1235093307                                                                   2026-06-05 03:25:18                        BACKUP METADATA FOUND
                  10 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.268.1235093319                                                                   2026-06-05 03:25:30                        BACKUP METADATA FOUND
                  11 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.269.1235093329                                                                 2026-06-05 03:25:13                        BACKUP METADATA FOUND
                  12 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undo_2.270.1235093341                                                                   2026-06-05 03:25:20                        BACKUP METADATA FOUND
                  13 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/users.273.1235093307                                                                    2026-06-05 03:24:53                        BACKUP METADATA FOUND
                  14 +DATA/CRASHDB/<PDB_GUID>/DATAFILE/rcat_tbs.275.1235096605                                                                 2026-06-05 03:24:54                        BACKUP METADATA FOUND

14 rows selected.

## Datafile Backup Levels - Last 90 Days

BACKUP_CLASS            BACKED_FILE_ENTRIES FIRST_OBSERVED      LAST_OBSERVED
---------------------- -------------------- ------------------- -------------------
FULL/NON-INCREMENTAL                     28 2026-06-05 01:41:50 2026-06-05 03:27:18
LEVEL 0                                  13 2026-06-05 01:55:01 2026-06-05 01:55:57

2 rows selected.

## Backup Piece Status

STATUS                   DEVICE_TYPE                 PIECE_COUNT OLDEST_COMPLETION   LATEST_COMPLETION
------------------------ ------------------ -------------------- ------------------- -------------------
A                        DISK                                  1 2026-06-05 01:41:50 2026-06-05 01:41:50
A                        SBT_TAPE                             55 2026-06-05 01:49:19 2026-06-05 03:27:18

2 rows selected.

## Recent Backup Pieces

               RECID                STAMP STATUS                   DEVICE_TYPE        COMPLETION_TIME                   SIZE_GB COM
-------------------- -------------------- ------------------------ ------------------ -------------------- -------------------- ---
HANDLE
------------------------------------------------------------------------------------------------------------------------------------------------------
                  56           1235100437 A                        SBT_TAPE           2026-06-05 03:27:18                     0 YES
c-1234567890-20260605-0b

                  54           1235100434 A                        SBT_TAPE           2026-06-05 03:27:15                     0 NO
AL_AUTO_05_06_2026_031900_arc_CRASHDB_1234567890_1v4ps8oi_63_1_1_20260605_1235100434_set63

                  55           1235100434 A                        SBT_TAPE           2026-06-05 03:27:15                     0 NO
AL_AUTO_05_06_2026_031900_arc_CRASHDB_1234567890_1u4ps8oi_62_1_1_20260605_1235100434_set62

                  53           1235100364 A                        SBT_TAPE           2026-06-05 03:26:05                     0 YES
c-1234567890-20260605-0a

                  52           1235100361 A                        SBT_TAPE           2026-06-05 03:26:02                     0 YES
1s4ps8m9_60_1_1

                  51           1235100359 A                        SBT_TAPE           2026-06-05 03:25:59                     0 YES
c-1234567890-20260605-09

                  50           1235100356 A                        SBT_TAPE           2026-06-05 03:25:57                     0 YES
1q4ps8m1_58_1_1

                  49           1235100350 A                        SBT_TAPE           2026-06-05 03:25:51                     0 YES
c-1234567890-20260605-08

                  45           1235100347 A                        SBT_TAPE           2026-06-05 03:25:48                     0 YES
1l4ps8lr_53_1_1

                  48           1235100348 A                        SBT_TAPE           2026-06-05 03:25:48                     0 YES
1o4ps8lr_56_1_1

                  47           1235100347 A                        SBT_TAPE           2026-06-05 03:25:48                     0 YES
1m4ps8lr_54_1_1

                  46           1235100347 A                        SBT_TAPE           2026-06-05 03:25:48                     0 YES
1n4ps8lr_55_1_1

                  44           1235100339 A                        SBT_TAPE           2026-06-05 03:25:39                     0 YES
c-1234567890-20260605-07

                  43           1235100322 A                        SBT_TAPE           2026-06-05 03:25:36                   .29 YES
1h4ps8l2_49_1_1

                  42           1235100318 A                        SBT_TAPE           2026-06-05 03:25:35                   .09 YES
1g4ps8ku_48_1_1

                  41           1235100322 A                        SBT_TAPE           2026-06-05 03:25:32                   .09 YES
1i4ps8l2_50_1_1

                  40           1235100322 A                        SBT_TAPE           2026-06-05 03:25:30                   .08 YES
1j4ps8l2_51_1_1

                  39           1235100287 A                        SBT_TAPE           2026-06-05 03:25:22                   .19 YES
1c4ps8jv_44_1_1

                  37           1235100304 A                        SBT_TAPE           2026-06-05 03:25:21                   .37 YES
1f4ps8ke_47_1_1

                  38           1235100287 A                        SBT_TAPE           2026-06-05 03:25:21                   .47 YES
1b4ps8jv_43_1_1

                  36           1235100287 A                        SBT_TAPE           2026-06-05 03:25:12                     0 YES
1d4ps8jv_45_1_1

                  35           1235100287 A                        SBT_TAPE           2026-06-05 03:24:55                     0 YES
1e4ps8jv_46_1_1

                  34           1235099956 A                        SBT_TAPE           2026-06-05 03:19:17                     0 YES
c-1234567890-20260605-06

                  32           1235099951 A                        SBT_TAPE           2026-06-05 03:19:13                   .01 NO
AL_AUTO_05_06_2026_031900_arc_CRASHDB_1234567890_194ps89f_41_1_1_20260605_1235099951_set41

                  33           1235099951 A                        SBT_TAPE           2026-06-05 03:19:13                   .01 NO
AL_AUTO_05_06_2026_031900_arc_CRASHDB_1234567890_184ps89f_40_1_1_20260605_1235099951_set40

                  31           1235098637 A                        SBT_TAPE           2026-06-05 02:57:18                     0 YES
c-1234567890-20260605-05

                  29           1235098631 A                        SBT_TAPE           2026-06-05 02:57:14                   .04 NO
AL_AUTO_05_06_2026_024900_arc_CRASHDB_1234567890_0v4ps707_31_1_1_20260605_1235098631_set31

                  30           1235098631 A                        SBT_TAPE           2026-06-05 02:57:14                   .04 NO
AL_AUTO_05_06_2026_024900_arc_CRASHDB_1234567890_0u4ps707_30_1_1_20260605_1235098631_set30

                  28           1235098633 A                        SBT_TAPE           2026-06-05 02:57:13                     0 NO
AL_AUTO_05_06_2026_024900_arc_CRASHDB_1234567890_124ps709_34_1_1_20260605_1235098633_set34

                  26           1235098631 A                        SBT_TAPE           2026-06-05 02:57:12                     0 NO
AL_AUTO_05_06_2026_024900_arc_CRASHDB_1234567890_114ps707_33_1_1_20260605_1235098631_set33

                  27           1235098631 A                        SBT_TAPE           2026-06-05 02:57:12                     0 NO
AL_AUTO_05_06_2026_024900_arc_CRASHDB_1234567890_104ps707_32_1_1_20260605_1235098631_set32

                  25           1235097239 A                        SBT_TAPE           2026-06-05 02:34:00                     0 YES
c-1234567890-20260605-04

                  24           1235097236 A                        SBT_TAPE           2026-06-05 02:33:57                     0 YES
0o4ps5kh_24_1_1

                  23           1235096837 A                        SBT_TAPE           2026-06-05 02:27:18                     0 YES
c-1234567890-20260605-03

                  22           1235096833 A                        SBT_TAPE           2026-06-05 02:27:15                   .04 NO
AL_AUTO_05_06_2026_021900_arc_CRASHDB_1234567890_0l4ps581_21_1_1_20260605_1235096833_set21

                  21           1235096833 A                        SBT_TAPE           2026-06-05 02:27:14                   .01 NO
AL_AUTO_05_06_2026_021900_arc_CRASHDB_1234567890_0m4ps581_22_1_1_20260605_1235096833_set22

                  20           1235094966 A                        SBT_TAPE           2026-06-05 01:56:07                     0 YES
c-1234567890-20260605-02

                  18           1235094963 A                        SBT_TAPE           2026-06-05 01:56:04                     0 YES
DBTRegular-L01780623333947wS6_arc_CRASHDB_1234567890_0j4ps3dj_19_1_1_20260605_1235094963_set19

                  19           1235094963 A                        SBT_TAPE           2026-06-05 01:56:04                     0 YES
DBTRegular-L01780623333947wS6_arc_CRASHDB_1234567890_0i4ps3dj_18_1_1_20260605_1235094963_set18

                  17           1235094942 A                        SBT_TAPE           2026-06-05 01:55:59                   .09 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0g4ps3cu_16_1_1_20260605_1235094942_set16

                  16           1235094945 A                        SBT_TAPE           2026-06-05 01:55:51                   .08 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0h4ps3d1_17_1_1_20260605_1235094945_set17

                  15           1235094935 A                        SBT_TAPE           2026-06-05 01:55:50                   .29 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0f4ps3cm_15_1_1_20260605_1235094934_set15

                  14           1235094924 A                        SBT_TAPE           2026-06-05 01:55:47                   .09 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0d4ps3cc_13_1_1_20260605_1235094924_set13

                  13           1235094900 A                        SBT_TAPE           2026-06-05 01:55:43                   .18 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0a4ps3bj_10_1_1_20260605_1235094899_set10

                  12           1235094900 A                        SBT_TAPE           2026-06-05 01:55:41                     0 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0b4ps3bj_11_1_1_20260605_1235094899_set11

                  11           1235094931 A                        SBT_TAPE           2026-06-05 01:55:34                     0 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0e4ps3cj_14_1_1_20260605_1235094931_set14

                  10           1235094900 A                        SBT_TAPE           2026-06-05 01:55:29                   .47 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_094ps3bj_9_1_1_20260605_1235094899_set9

                   9           1235094900 A                        SBT_TAPE           2026-06-05 01:55:15                   .36 YES
DBTRegular-L01780623333947wS6_CRASHDB_1234567890_0c4ps3bj_12_1_1_20260605_1235094899_set12

                   7           1235094897 A                        SBT_TAPE           2026-06-05 01:54:58                     0 YES
DBTRegular-L01780623333947wS6_arc_CRASHDB_1234567890_074ps3bh_7_1_1_20260605_1235094897_set7

                   8           1235094897 A                        SBT_TAPE           2026-06-05 01:54:58                     0 YES
DBTRegular-L01780623333947wS6_arc_CRASHDB_1234567890_084ps3bh_8_1_1_20260605_1235094897_set8

                   6           1235094575 A                        SBT_TAPE           2026-06-05 01:49:36                     0 YES
c-1234567890-20260605-01

                   5           1235094558 A                        SBT_TAPE           2026-06-05 01:49:26                   .27 NO
AL_AUTO_05_06_2026_014900_arc_CRASHDB_1234567890_024ps30u_2_1_1_20260605_1235094558_set2

                   3           1235094558 A                        SBT_TAPE           2026-06-05 01:49:21                   .04 NO
AL_AUTO_05_06_2026_014900_arc_CRASHDB_1234567890_044ps30u_4_1_1_20260605_1235094558_set4

                   4           1235094558 A                        SBT_TAPE           2026-06-05 01:49:21                   .04 NO
AL_AUTO_05_06_2026_014900_arc_CRASHDB_1234567890_034ps30u_3_1_1_20260605_1235094558_set3

                   2           1235094558 A                        SBT_TAPE           2026-06-05 01:49:19                     0 NO
AL_AUTO_05_06_2026_014900_arc_CRASHDB_1234567890_054ps30u_5_1_1_20260605_1235094558_set5

                   1           1235094110 A                        DISK               2026-06-05 01:41:50                   .16 NO
+RECO/CRASHDB/AUTOBACKUP/2026_06_05/s_1235094108.263.1235094111


56 rows selected.

## Archived Redo Backup Coverage - Last 7 Days

             THREAD#            SEQUENCE# FIRST_TIME          COMPLETION_TIME      DEL         BACKUP_COUNT NAME
-------------------- -------------------- ------------------- -------------------- --- -------------------- --------------------------------------
                   1                    2 2026-06-05 01:17:49 2026-06-05 01:49:17  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_2.265.1235094553

                   1                    3 2026-06-05 01:49:12 2026-06-05 01:54:55  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_3.266.1235094895

                   1                    4 2026-06-05 01:54:55 2026-06-05 01:56:00  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_4.268.1235094961

                   1                    5 2026-06-05 01:56:00 2026-06-05 02:27:12  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_5.271.1235096833

                   1                    6 2026-06-05 02:27:12 2026-06-05 02:28:36  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_6.272.1235096917

                   1                    7 2026-06-05 02:28:36 2026-06-05 02:28:39  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_7.274.1235096919

                   1                    8 2026-06-05 02:28:39 2026-06-05 02:28:45  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_8.276.1235096925

                   1                    9 2026-06-05 02:28:45 2026-06-05 02:28:51  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_9.279.1235096931

                   1                   10 2026-06-05 02:28:51 2026-06-05 02:28:54  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_10.281.1235096935

                   1                   11 2026-06-05 02:28:54 2026-06-05 02:31:08  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_11.284.1235097069

                   1                   12 2026-06-05 02:31:08 2026-06-05 02:31:14  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_12.285.1235097073

                   1                   13 2026-06-05 02:31:08 2026-06-05 02:57:09  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_13.286.1235098629

                   1                   14 2026-06-05 02:57:09 2026-06-05 03:19:11  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_14.289.1235099951

                   1                   15 2026-06-05 03:19:11 2026-06-05 03:23:30  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_15.290.1235100211

                   1                   16 2026-06-05 03:23:30 2026-06-05 03:24:44  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_16.293.1235100285

                   1                   17 2026-06-05 03:24:44 2026-06-05 03:25:41  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_17.294.1235100341

                   1                   18 2026-06-05 03:25:41 2026-06-05 03:25:47  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_18.297.1235100347

                   1                   19 2026-06-05 03:25:47 2026-06-05 03:27:14  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_1_seq_19.299.1235100435

                   2                    1 2026-06-05 01:25:42 2026-06-05 01:25:45  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_1.256.1235093145

                   2                    2 2026-06-05 01:27:22 2026-06-05 01:31:21  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_2.261.1235093481

                   2                    3 2026-06-05 01:32:00 2026-06-05 01:49:12  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_3.264.1235094553

                   2                    4 2026-06-05 01:49:12 2026-06-05 01:54:57  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_4.267.1235094897

                   2                    5 2026-06-05 01:54:57 2026-06-05 01:56:03  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_5.269.1235094963

                   2                    6 2026-06-05 01:56:03 2026-06-05 02:27:12  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_6.270.1235096833

                   2                    7 2026-06-05 02:27:12 2026-06-05 02:28:39  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_7.273.1235096919

                   2                    8 2026-06-05 02:28:39 2026-06-05 02:28:42  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_8.275.1235096923

                   2                    9 2026-06-05 02:28:42 2026-06-05 02:28:48  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_9.277.1235096929

                   2                   10 2026-06-05 02:28:48 2026-06-05 02:28:51  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_10.278.1235096931

                   2                   11 2026-06-05 02:28:51 2026-06-05 02:28:54  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_11.280.1235096935

                   2                   12 2026-06-05 02:28:54 2026-06-05 02:30:24  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_12.282.1235097025

                   2                   13 2026-06-05 02:31:08 2026-06-05 02:57:11  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_13.287.1235098631

                   2                   14 2026-06-05 02:57:10 2026-06-05 03:19:11  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_14.288.1235099951

                   2                   15 2026-06-05 03:19:11 2026-06-05 03:23:32  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_15.291.1235100213

                   2                   16 2026-06-05 03:23:32 2026-06-05 03:24:44  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_16.292.1235100285

                   2                   17 2026-06-05 03:24:44 2026-06-05 03:25:44  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_17.295.1235100345

                   2                   18 2026-06-05 03:25:44 2026-06-05 03:25:47  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_18.296.1235100347

                   2                   19 2026-06-05 03:25:47 2026-06-05 03:27:14  NO                     1 +RECO/CRASHDB/ARCHIVELOG/2026_0
                                                                                                            6_05/thread_2_seq_19.298.1235100435


37 rows selected.

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
+RECO                                             44                16.34                  .55                   42

1 row selected.

## FRA Usage By File Type

FILE_TYPE                 PERCENT_SPACE_USED PERCENT_SPACE_RECLAIMABLE      NUMBER_OF_FILES
----------------------- -------------------- ------------------------- --------------------
ARCHIVED LOG                            1.25                      1.25                   37
AUXILIARY DATAFILE COPY                    0                         0                    0
BACKUP PIECE                             .37                         0                    1
CONTROL FILE                               0                         0                    0
FLASHBACK LOG                          35.52                         0                    4
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
crashdb                        YES

                  10 ALTERNATE                PRIMARY
+DATA
crashdb                        UNKNOWN


2 rows selected.


no rows selected

```

## RMAN Repository, Restore Preview, Need-Backup, And Obsolete Report

Repository source requested: `target control file`

Command: `rman target / cmdfile=/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLE_repository.rman log=/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLE_repository.log`

```text

Recovery Manager: Release 19.0.0.0.0 - Production on Fri Jun 5 03:35:36 2026
Version 19.31.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: CRASHDB (DBID=1234567890)

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
RMAN configuration parameters for database with db_unique_name CRASHDB are:
CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 30 DAYS;
CONFIGURE BACKUP OPTIMIZATION ON;
CONFIGURE DEFAULT DEVICE TYPE TO 'SBT_TAPE';
CONFIGURE CONTROLFILE AUTOBACKUP ON;
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE SBT_TAPE TO '%F'; # default
CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '%F'; # default
CONFIGURE DEVICE TYPE 'SBT_TAPE' BACKUP TYPE TO COMPRESSED BACKUPSET PARALLELISM 4;
CONFIGURE DEVICE TYPE DISK PARALLELISM 1 BACKUP TYPE TO BACKUPSET; # default
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE SBT_TAPE TO 1; # default
CONFIGURE DATAFILE BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE SBT_TAPE TO 1; # default
CONFIGURE ARCHIVELOG BACKUP COPIES FOR DEVICE TYPE DISK TO 1; # default
CONFIGURE CHANNEL DEVICE TYPE 'SBT_TAPE' PARMS  'SBT_LIBRARY=/opt/oracle/backup/libopc.so ENV=(OPC_PFILE=/opt/oracle/backup/opcdb.ora)';
CONFIGURE MAXSETSIZE TO UNLIMITED; # default
CONFIGURE ENCRYPTION FOR DATABASE ON;
CONFIGURE ENCRYPTION ALGORITHM 'AES256';
CONFIGURE COMPRESSION ALGORITHM 'low' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE;
CONFIGURE RMAN OUTPUT TO KEEP FOR 7 DAYS; # default
CONFIGURE ARCHIVELOG DELETION POLICY TO NONE; # default
CONFIGURE SNAPSHOT CONTROLFILE NAME TO '+RECO/crashdb/controlfile/snapcf_crashdb.f';


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
1       B  F  A DISK        05-JUN-26       1       1       NO         TAG20260605T014148
2       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
3       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
4       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
5       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
6       B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T014933
7       B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
8       B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
9       B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
10      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
11      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
12      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
13      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
14      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
15      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
16      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
17      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
18      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
19      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
20      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T015604
21      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_021900
22      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_021900
23      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T022716
24      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CRASHSIM_POST_MUX_CONTROLFILE
25      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T023358
26      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
27      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
28      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
29      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
30      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
31      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T025716
32      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
33      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
34      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T031914
35      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
36      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
37      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
38      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
39      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
40      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
41      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
42      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
43      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
44      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T032537
45      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
46      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
47      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
48      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
49      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T032549
50      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_CTL
51      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T032557
52      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_SPFILE
53      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T032602
54      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
55      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
56      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        TAG20260605T032716


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
9       B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
10      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
11      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
12      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
13      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
14      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
15      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
16      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
17      B  0  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
35      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
36      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
37      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
38      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
39      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
40      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
41      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
42      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
43      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
2       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
3       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
4       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
5       B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_014900
7       B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
8       B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
18      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
19      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        DBTREGULAR-L01780623333947WS6
21      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_021900
22      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_021900
26      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
27      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
28      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
29      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
30      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_024900
32      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
33      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
45      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
46      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
47      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
48      B  A  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441_ARCH
54      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900
55      B  A  A SBT_TAPE    05-JUN-26       1       1       NO         AL_AUTO_05_06_2026_031900

specification does not match any backup in the repository

specification does not match any archived log in the repository

Report of database schema for database with db_unique_name CRASHDB

List of Permanent Datafiles
===========================
File Size(MB) Tablespace           RB segs Datafile Name
---- -------- -------------------- ------- ------------------------
1    2000     SYSTEM               YES     +DATA/CRASHDB/DATAFILE/system.258.1235092711
2    600      PDB$SEED:SYSTEM      NO      +DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.262.1235092459
3    2000     SYSAUX               NO      +DATA/CRASHDB/DATAFILE/sysaux.267.1235092687
4    600      PDB$SEED:SYSAUX      NO      +DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.263.1235092459
5    2000     UNDOTBS1             YES     +DATA/CRASHDB/DATAFILE/undotbs1.257.1235092737
6    600      PDB$SEED:UNDOTBS1    NO      +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.264.1235092459
7    1024     USERS                NO      +DATA/CRASHDB/DATAFILE/users.259.1235092763
8    2000     UNDOTBS2             YES     +DATA/CRASHDB/DATAFILE/undotbs2.266.1235092685
9    600      CRASHPDB:SYSTEM      YES     +DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.274.1235093307
10   600      CRASHPDB:SYSAUX      NO      +DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.268.1235093319
11   600      CRASHPDB:UNDOTBS1    YES     +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.269.1235093329
12   600      CRASHPDB:UNDO_2      YES     +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undo_2.270.1235093341
13   1024     CRASHPDB:USERS       NO      +DATA/CRASHDB/<PDB_GUID>/DATAFILE/users.273.1235093307
14   512      CRASHPDB:RCAT_TBS    NO      +DATA/CRASHDB/<PDB_GUID>/DATAFILE/rcat_tbs.275.1235096605

List of Temporary Files
=======================
File Size(MB) Tablespace           Maxsize(MB) Tempfile Name
---- -------- -------------------- ----------- --------------------
1    1024     TEMP                 524288      +DATA/CRASHDB/TEMPFILE/temp.261.1235092827
2    100      PDB$SEED:TEMP        33554431    +DATA/CRASHDB/<PDB_GUID>/TEMPFILE/temp.265.1235092509
4    1024     CRASHPDB:TEMP        33554431    +DATA/CRASHDB/<PDB_GUID>/TEMPFILE/temp.271.1235093303

RMAN retention policy will be applied to the command
RMAN retention policy is set to recovery window of 30 days
Report of files that must be backed up to satisfy 30 days recovery window
File Days  Name
---- ----- -----------------------------------------------------

RMAN retention policy will be applied to the command
RMAN retention policy is set to recovery window of 30 days
RMAN-07554: warning: CONTROL_FILE_RECORD_KEEP_TIME is too large (38 days)
no obsolete backups found

Starting restore at 05-JUN-26
allocated channel: ORA_SBT_TAPE_1
channel ORA_SBT_TAPE_1: SID=58 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_1: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_SBT_TAPE_2
channel ORA_SBT_TAPE_2: SID=74 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_2: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_SBT_TAPE_3
channel ORA_SBT_TAPE_3: SID=2396 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_3: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_SBT_TAPE_4
channel ORA_SBT_TAPE_4: SID=2357 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_4: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=2379 instance=crashdb1 device type=DISK


List of Backups
===============
Key     TY LV S Device Type Completion Time #Pieces #Copies Compressed Tag
------- -- -- - ----------- --------------- ------- ------- ---------- ---
38      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
43      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
39      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
41      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
36      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
40      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
37      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
42      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
35      B  F  A SBT_TAPE    05-JUN-26       1       1       YES        CSIM_BASE_260605032441
using channel ORA_SBT_TAPE_1
using channel ORA_SBT_TAPE_2
using channel ORA_SBT_TAPE_3
using channel ORA_SBT_TAPE_4
using channel ORA_DISK_1

List of Archived Log Copies for database with db_unique_name CRASHDB
=====================================================================

Key     Thrd Seq     S Low Time 
------- ---- ------- - ---------
32      1    17      A 05-JUN-26
        Name: +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_17.294.1235100341

35      1    18      A 05-JUN-26
        Name: +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_18.297.1235100347

37      1    19      A 05-JUN-26
        Name: +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_19.299.1235100435

33      2    17      A 05-JUN-26
        Name: +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_17.295.1235100345

34      2    18      A 05-JUN-26
        Name: +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_18.296.1235100347

36      2    19      A 05-JUN-26
        Name: +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_19.298.1235100435

recovery will be done up to SCN 1826137
Media recovery start SCN is 1826137
Recovery must be done beyond SCN 1826265 to clear datafile fuzziness
validation succeeded for backup piece
Finished restore at 05-JUN-26

Recovery Manager complete.
```

## RMAN Deep Validation - Restore Database, Archivelogs, And Logical Database Check

Repository source requested: `target control file`

Command: `rman target / cmdfile=/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLEvalidate.rman log=/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLEvalidate.log`

```text

Recovery Manager: Release 19.0.0.0.0 - Production on Fri Jun 5 03:35:44 2026
Version 19.31.0.0.0

Copyright (c) 1982, 2019, Oracle and/or its affiliates.  All rights reserved.

connected to target database: CRASHDB (DBID=1234567890)

RMAN> restore database validate;
2> restore archivelog all validate;
3> validate database check logical;
4> exit;
Starting restore at 05-JUN-26
using target database control file instead of recovery catalog
allocated channel: ORA_SBT_TAPE_1
channel ORA_SBT_TAPE_1: SID=73 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_1: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_SBT_TAPE_2
channel ORA_SBT_TAPE_2: SID=57 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_2: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_SBT_TAPE_3
channel ORA_SBT_TAPE_3: SID=2357 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_3: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_SBT_TAPE_4
channel ORA_SBT_TAPE_4: SID=2396 instance=crashdb1 device type=SBT_TAPE
channel ORA_SBT_TAPE_4: Oracle Database Backup Service Library VER=19.0.0.1
allocated channel: ORA_DISK_1
channel ORA_DISK_1: SID=2379 instance=crashdb1 device type=DISK

channel ORA_SBT_TAPE_1: starting validation of datafile backup set
channel ORA_SBT_TAPE_2: starting validation of datafile backup set
channel ORA_SBT_TAPE_3: starting validation of datafile backup set
channel ORA_SBT_TAPE_4: starting validation of datafile backup set
channel ORA_SBT_TAPE_1: reading from backup piece 1e4ps8jv_46_1_1
channel ORA_SBT_TAPE_2: reading from backup piece 1d4ps8jv_45_1_1
channel ORA_SBT_TAPE_3: reading from backup piece 1b4ps8jv_43_1_1
channel ORA_SBT_TAPE_4: reading from backup piece 1f4ps8ke_47_1_1
channel ORA_SBT_TAPE_1: piece handle=1e4ps8jv_46_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_1: restored backup piece 1
channel ORA_SBT_TAPE_1: validation complete, elapsed time: 00:00:01
channel ORA_SBT_TAPE_1: starting validation of datafile backup set
channel ORA_SBT_TAPE_1: reading from backup piece 1c4ps8jv_44_1_1
channel ORA_SBT_TAPE_2: piece handle=1d4ps8jv_45_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_2: restored backup piece 1
channel ORA_SBT_TAPE_2: validation complete, elapsed time: 00:00:01
channel ORA_SBT_TAPE_2: starting validation of datafile backup set
channel ORA_SBT_TAPE_2: reading from backup piece 1j4ps8l2_51_1_1
channel ORA_SBT_TAPE_1: piece handle=1c4ps8jv_44_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_1: restored backup piece 1
channel ORA_SBT_TAPE_1: validation complete, elapsed time: 00:00:03
channel ORA_SBT_TAPE_1: starting validation of datafile backup set
channel ORA_SBT_TAPE_2: piece handle=1j4ps8l2_51_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_2: restored backup piece 1
channel ORA_SBT_TAPE_2: validation complete, elapsed time: 00:00:03
channel ORA_SBT_TAPE_2: starting validation of datafile backup set
channel ORA_SBT_TAPE_1: reading from backup piece 1i4ps8l2_50_1_1
channel ORA_SBT_TAPE_2: reading from backup piece 1g4ps8ku_48_1_1
channel ORA_SBT_TAPE_4: piece handle=1f4ps8ke_47_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_4: restored backup piece 1
channel ORA_SBT_TAPE_4: validation complete, elapsed time: 00:00:05
channel ORA_SBT_TAPE_4: starting validation of datafile backup set
channel ORA_SBT_TAPE_4: reading from backup piece 1h4ps8l2_49_1_1
channel ORA_SBT_TAPE_1: piece handle=1i4ps8l2_50_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_1: restored backup piece 1
channel ORA_SBT_TAPE_1: validation complete, elapsed time: 00:00:02
channel ORA_SBT_TAPE_2: piece handle=1g4ps8ku_48_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_2: restored backup piece 1
channel ORA_SBT_TAPE_2: validation complete, elapsed time: 00:00:02
channel ORA_SBT_TAPE_3: piece handle=1b4ps8jv_43_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_3: restored backup piece 1
channel ORA_SBT_TAPE_3: validation complete, elapsed time: 00:00:08
channel ORA_SBT_TAPE_4: piece handle=1h4ps8l2_49_1_1 tag=CSIM_BASE_260605032441
channel ORA_SBT_TAPE_4: restored backup piece 1
channel ORA_SBT_TAPE_4: validation complete, elapsed time: 00:00:07
Finished restore at 05-JUN-26

Starting restore at 05-JUN-26
using channel ORA_SBT_TAPE_1
using channel ORA_SBT_TAPE_2
using channel ORA_SBT_TAPE_3
using channel ORA_SBT_TAPE_4
using channel ORA_DISK_1

channel ORA_SBT_TAPE_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_2.265.1235094553
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_3.266.1235094895
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_4.268.1235094961
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_5.271.1235096833
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_6.272.1235096917
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_7.274.1235096919
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_8.276.1235096925
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_9.279.1235096931
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_10.281.1235096935
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_11.284.1235097069
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_12.285.1235097073
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_13.286.1235098629
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_14.289.1235099951
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_15.290.1235100211
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_16.293.1235100285
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_17.294.1235100341
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_18.297.1235100347
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_1_seq_19.299.1235100435
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_1.256.1235093145
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_2.261.1235093481
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_3.264.1235094553
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_4.267.1235094897
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_5.269.1235094963
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_6.270.1235096833
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_7.273.1235096919
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_8.275.1235096923
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_9.277.1235096929
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_10.278.1235096931
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_11.280.1235096935
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_12.282.1235097025
channel ORA_SBT_TAPE_2: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_13.287.1235098631
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_14.288.1235099951
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_15.291.1235100213
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_16.292.1235100285
channel ORA_SBT_TAPE_4: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_17.295.1235100345
channel ORA_DISK_1: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_18.296.1235100347
channel ORA_SBT_TAPE_3: scanning archived log +RECO/CRASHDB/ARCHIVELOG/2026_06_05/thread_2_seq_19.298.1235100435
Finished restore at 05-JUN-26

Starting validate at 05-JUN-26
released channel: ORA_SBT_TAPE_1
released channel: ORA_SBT_TAPE_2
released channel: ORA_SBT_TAPE_3
released channel: ORA_SBT_TAPE_4
using channel ORA_DISK_1
channel ORA_DISK_1: starting validation of datafile
channel ORA_DISK_1: specifying datafile(s) for validation
input datafile file number=00001 name=+DATA/CRASHDB/DATAFILE/system.258.1235092711
input datafile file number=00003 name=+DATA/CRASHDB/DATAFILE/sysaux.267.1235092687
input datafile file number=00005 name=+DATA/CRASHDB/DATAFILE/undotbs1.257.1235092737
input datafile file number=00008 name=+DATA/CRASHDB/DATAFILE/undotbs2.266.1235092685
input datafile file number=00007 name=+DATA/CRASHDB/DATAFILE/users.259.1235092763
channel ORA_DISK_1: validation complete, elapsed time: 00:00:35
List of Datafiles
=================
File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
1    OK     0              16920        256002          1831864   
  File Name: +DATA/CRASHDB/DATAFILE/system.258.1235092711
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              394             
  Index      0              381             
  Other      0              238305          

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
3    OK     0              18807        256033          1831892   
  File Name: +DATA/CRASHDB/DATAFILE/sysaux.267.1235092687
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              484             
  Index      0              495             
  Other      0              236214          

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
5    OK     0              316          256022          1831891   
  File Name: +DATA/CRASHDB/DATAFILE/undotbs1.257.1235092737
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              255684          

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
7    OK     0              122226       131072          736151    
  File Name: +DATA/CRASHDB/DATAFILE/users.259.1235092763
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              8846            

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
8    OK     0              254795       256000          1831491   
  File Name: +DATA/CRASHDB/DATAFILE/undotbs2.266.1235092685
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              1205            

channel ORA_DISK_1: starting validation of datafile
channel ORA_DISK_1: specifying datafile(s) for validation
input datafile file number=00002 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.262.1235092459
input datafile file number=00004 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.263.1235092459
input datafile file number=00006 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.264.1235092459
channel ORA_DISK_1: validation complete, elapsed time: 00:00:15
List of Datafiles
=================
File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
2    OK     0              18229        76800           1709867   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.262.1235092459
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              17471           
  Index      0              9031            
  Other      0              32069           

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
4    OK     0              21600        76800           1709260   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.263.1235092459
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              6575            
  Index      0              3309            
  Other      0              45316           

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
6    OK     0              46868        76800           1709863   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.264.1235092459
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              29932           

channel ORA_DISK_1: starting validation of datafile
channel ORA_DISK_1: specifying datafile(s) for validation
input datafile file number=00013 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/users.273.1235093307
input datafile file number=00009 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.274.1235093307
input datafile file number=00010 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.268.1235093319
input datafile file number=00011 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.269.1235093329
input datafile file number=00012 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/undo_2.270.1235093341
input datafile file number=00014 name=+DATA/CRASHDB/<PDB_GUID>/DATAFILE/rcat_tbs.275.1235096605
channel ORA_DISK_1: validation complete, elapsed time: 00:00:25
List of Datafiles
=================
File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
9    OK     0              16880        76800           1831615   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/system.274.1235093307
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              103             
  Index      0              96              
  Other      0              59721           

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
10   OK     0              21249        76800           1831138   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/sysaux.268.1235093319
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              158             
  Index      0              154             
  Other      0              55239           

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
11   OK     0              46849        76800           1831157   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undotbs1.269.1235093329
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              29951           

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
12   OK     0              73111        76800           1831137   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/undo_2.270.1235093341
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              3689            

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
13   OK     0              122382       131072          1732264   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/users.273.1235093307
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              0               
  Index      0              0               
  Other      0              8690            

File Status Marked Corrupt Empty Blocks Blocks Examined High SCN
---- ------ -------------- ------------ --------------- ----------
14   OK     0              55777        65536           1828105   
  File Name: +DATA/CRASHDB/<PDB_GUID>/DATAFILE/rcat_tbs.275.1235096605
  Block Type Blocks Failing Blocks Processed
  ---------- -------------- ----------------
  Data       0              1               
  Index      0              0               
  Other      0              9758            

channel ORA_DISK_1: starting validation of datafile
channel ORA_DISK_1: specifying datafile(s) for validation
including current control file for validation
including current SPFILE in backup set
channel ORA_DISK_1: validation complete, elapsed time: 00:00:01
List of Control File and SPFILE
===============================
File Type    Status Blocks Failing Blocks Examined
------------ ------ -------------- ---------------
SPFILE       OK     0              2               
Control File OK     0              10728           
Finished validate at 05-JUN-26

Recovery Manager complete.
```

## References

- Oracle Database 19c backup and recovery administration: https://docs.oracle.com/en/database/oracle/oracle-database/19/admqs/performing-backup-and-recovery.html
- Oracle Maximum Availability Architecture overview: https://www.oracle.com/database/technologies/maximum-availability-architecture/
- CrashSimulator RTO/RPO planning reference: https://oraclemaa.com/from-downtime-to-data-loss-getting-rto-and-rpo-right-for-high-availability-and-disaster-recovery

## Raw Backup Evidence

Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_backup_report_EXAMPLE.evidence`

```text
CSIM_BKP|db_name|CRASHDB
CSIM_BKP|db_unique_name|crashdb
CSIM_BKP|dbid|1234567890
CSIM_BKP|database_role|PRIMARY
CSIM_BKP|open_mode|READ WRITE
CSIM_BKP|cdb|YES
CSIM_BKP|log_mode|ARCHIVELOG
CSIM_BKP|force_logging|YES
CSIM_BKP|flashback_on|YES
CSIM_BKP|platform_name|Linux x86 64-bit
CSIM_BKP|control_file_record_keep_time|38
CSIM_BKP|archive_lag_target|0
CSIM_BKP|db_recovery_file_dest|+RECO
CSIM_BKP|rman_retention_policy|TO RECOVERY WINDOW OF 30 DAYS
CSIM_BKP|rman_controlfile_autobackup|ON
CSIM_BKP|rman_backup_optimization|ON
CSIM_BKP|rman_encryption|ON
CSIM_BKP|rman_compression|'low' AS OF RELEASE 'DEFAULT' OPTIMIZE FOR LOAD TRUE
CSIM_BKP|rman_channel_config_count|1
CSIM_BKP|datafile_count|14
CSIM_BKP|tempfile_count|3
CSIM_BKP|database_size_gb|14.41
CSIM_BKP|datafile_copy_count|3
CSIM_BKP|datafiles_without_backup_metadata|0
CSIM_BKP|oldest_datafile_backup_time|2026-06-05 03:24:50
CSIM_BKP|last_datafile_backup_time|2026-06-05 03:27:18
CSIM_BKP|last_datafile_backup_age_hours|.1
CSIM_BKP|last_level0_backup_time|2026-06-05 01:55:57
CSIM_BKP|last_level0_backup_age_hours|1.7
CSIM_BKP|last_level1_backup_time|NONE
CSIM_BKP|last_level1_backup_age_hours|UNKNOWN
CSIM_BKP|level0_count_30d|9
CSIM_BKP|level1_count_30d|0
CSIM_BKP|level0_avg_gap_hours|0
CSIM_BKP|level1_avg_gap_hours|UNKNOWN
CSIM_BKP|successful_jobs_7d|8
CSIM_BKP|failed_jobs_7d|1
CSIM_BKP|successful_jobs_30d|8
CSIM_BKP|failed_jobs_30d|1
CSIM_BKP|last_successful_job_time|2026-06-05 03:27:20
CSIM_BKP|last_successful_job_age_hours|.1
CSIM_BKP|backup_device_types|SBT_TAPE,UNKNOWN
CSIM_BKP|avg_successful_job_elapsed_minutes_30d|.5
CSIM_BKP|max_successful_job_elapsed_minutes_30d|1.3
CSIM_BKP|archivelog_backup_sets_30d|23
CSIM_BKP|last_archivelog_backup_time|2026-06-05 03:27:15
CSIM_BKP|last_archivelog_backup_age_hours|.1
CSIM_BKP|archivelog_backup_avg_gap_hours|.1
CSIM_BKP|archivelogs_known_7d|37
CSIM_BKP|archivelogs_not_backed_7d|0
CSIM_BKP|oldest_unbacked_archivelog_time|NONE
CSIM_BKP|oldest_unbacked_archivelog_age_hours|UNKNOWN
CSIM_BKP|latest_archivelog_time|2026-06-05 03:27:14
CSIM_BKP|controlfile_backup_count_30d|14
CSIM_BKP|last_controlfile_backup_time|2026-06-05 03:27:18
CSIM_BKP|last_controlfile_backup_age_hours|.1
CSIM_BKP|backup_piece_available_count|56
CSIM_BKP|backup_piece_expired_count|0
CSIM_BKP|backup_piece_deleted_count|0
CSIM_BKP|backup_piece_unavailable_count|0
CSIM_BKP|latest_backup_piece_time|2026-06-05 03:27:18
CSIM_BKP|backup_piece_device_types|DISK,SBT_TAPE
CSIM_BKP|recover_file_count|0
CSIM_BKP|block_corruption_count|0
CSIM_BKP|copy_corruption_count|0
CSIM_BKP|backup_corruption_count|0
CSIM_BKP|fra_configured|YES
CSIM_BKP|fra_used_pct|37.14
CSIM_BKP|fra_reclaimable_pct|1.25
CSIM_BKP|remote_standby_dest_count|0
CSIM_BKP|valid_remote_standby_dest_count|0
CSIM_BKP|standby_dest_error_count|0
CSIM_BKP|archive_gap_count|0
CSIM_BKP|dataguard_transport_lag|UNKNOWN
CSIM_BKP|dataguard_apply_lag|UNKNOWN
```
