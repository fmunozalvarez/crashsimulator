# CrashSimulator 26ai RAC/ADG APEX, ORDS, and Redo Setup

Generated UTC: 2026-06-08

## Environment

- Primary RAC: `crashrdb`, database `CRASHDB`, instances `crashdb1` and `crashdb2`
- Standby RAC / Active Data Guard: `crashdr`, `READ ONLY WITH APPLY`
- PDB: `CRASHPDB`
- Database release observed: Oracle AI Database 26ai EE Extreme Performance, `23.26.2.0.0`
- ORACLE_HOME: `/u02/app/oracle/product/23.0.0.0/dbhome_1`
- Managed storage destinations:
  - DATA: `@rJOnB8bM(DATA_HC_HIGHREDUNDANCY)`
  - RECO/FRA: `@rJOnB8bM(RECO_HC_HIGHREDUNDANCY)`

## Redo Multiplexing

Primary online redo logs were multiplexed successfully after the OCI managed storage increase.

- Groups `1` through `8` now have two online redo members each.
- New members were added in the RECO high-redundancy destination.
- Both RAC threads were cycled after member creation.
- Validation showed `MEMBERS=2` and `MEMBER_STATUS_COUNT=0` for every online redo group.

Primary standby redo logs were also multiplexed.

- Groups `9` through `16` now have two standby redo members each.
- New members were added in the RECO high-redundancy destination.
- Each primary SRL group was cleared after adding the member to initialize the new member.
- Validation showed `MEMBERS=2` and `MEMBER_STATUS_COUNT=0` for every primary SRL group.

Standby-side redo/SRL multiplexing was inspected but not changed during this run.

- The standby remains `READ ONLY WITH APPLY`.
- A non-invasive test to add a redo member on the active standby returned `ORA-01156`, because managed recovery may need access to the files.
- Standby-side online redo/SRL multiplexing should be done in a short apply-maintenance window by cancelling managed recovery, applying the redo member changes, validating member status, and restarting apply.

## Data Guard Health

Broker and SQL validation after primary redo changes:

- Data Guard broker configuration status: `SUCCESS`
- Primary intended state: `TRANSPORT-ON`
- Standby intended state: `APPLY-ON`
- Real-Time Query: `ON`
- Transport lag: `0 seconds`
- Apply lag: `0 seconds`
- SQL view showed standby `READ ONLY WITH APPLY` and MRP `APPLYING_LOG`.

## APEX Installation

Oracle APEX 26.1 was installed in `CRASHPDB`.

- Media: `apex_26.1_en.zip`
- Install location on node1: `/u01/app/oracle/product/crashsim_apex_ords/apex_26.1/apex`
- APEX registry status: `VALID`
- APEX version: `26.1.0`
- APEX schema: `APEX_260100`
- APEX tablespace: `USERS`
- APEX files tablespace: `USERS`
- TEMP tablespace: `TEMP`
- APEX instance administrator created: `APEXLAB`

Notes:

- The first APEX install attempt used `SYSAUX` and failed with `ORA-01653`/`ORA-01658` while storage was constrained.
- The partial install was removed with `apxremov.sql`.
- After storage was increased, APEX completed successfully using `USERS` as the APEX/files tablespace.

## ORDS Installation

Oracle REST Data Services 26.1.2 was installed and configured on primary node1.

- Media: `ords-26.1.2.140.1916.zip`
- ORDS version: `26.1.2.r1401916`
- ORDS base: `/u01/app/oracle/product/crashsim_apex_ords/ords_26.1.2`
- ORDS config: `/u01/app/oracle/product/crashsim_apex_ords/ords_config`
- ORDS log: `/var/log/ords/ords.log`
- ORDS install log folder: `/u01/app/oracle/product/crashsim_apex_ords/logs/ords_install_20260608T105131Z`
- ORDS database pool: `crashpdb`
- ORDS service name: `crashdb_CRASHPDB.paas.oracle.com`
- ORDS DB users: `ORDS_METADATA`, `ORDS_PUBLIC_USER`
- ORDS objects: `ORDS_METADATA` valid object count observed as `352`

The bundled ORDS wrapper initially failed because the service started with Java 8. It was replaced with a direct `systemd` unit that runs ORDS foreground as `oracle` with Java 17:

- Service: `ords.service`
- Java: `/usr/java/jdk-17`
- Port: `8080`
- APEX images: `/u01/app/oracle/product/crashsim_apex_ords/apex_26.1/apex/images`

Validation:

- `systemctl status ords`: active/running
- `http://127.0.0.1:8080/ords/`: HTTP 200
- `http://127.0.0.1:8080/i/apex_version.txt`: HTTP 200, reports Oracle APEX Version 26.1
- `http://127.0.0.1:8080/ords/crashpdb/r/apex`: HTTP 200
- `http://127.0.0.1:8080/ords/crashpdb/r/apex/workspace-sign-in`: HTTP 302 to workspace home

## Follow-Up Items

- Add standby-side redo/SRL multiplexing during an approved ADG apply-maintenance window.
- Decide whether ORDS should also be installed on node2 and fronted by a load balancer for ORDS HA and scenario 79.
- Run a fresh baseline backup after the APEX/ORDS install and redo configuration changes.
- Refresh CrashSimulator topology/readiness reports after the backup.
