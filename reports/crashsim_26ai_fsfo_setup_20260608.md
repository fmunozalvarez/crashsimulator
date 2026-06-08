# CrashSimulator 26ai FSFO Setup

Generated UTC: 2026-06-08

## Environment

- Data Guard broker configuration: `crashdb_dgconf`
- Primary DB unique name: `crashrdb`
- Standby DB unique name: `crashdr`
- Primary role: `PRIMARY`
- Standby role: `PHYSICAL STANDBY`
- Standby open mode: `READ ONLY WITH APPLY`
- Observer host: `crashbastian`
- Observer name: `crashsim_bastion_observer`

## Prerequisite Validation

Primary database validation:

- `ARCHIVELOG`: enabled
- `FORCE LOGGING`: enabled
- `FLASHBACK_ON`: `YES`
- RAC instances: `crashdb1`, `crashdb2`
- Online redo: 4 groups per thread, 4000 MB each
- Standby redo: 4 groups per thread, 4000 MB each

Standby database validation:

- `ARCHIVELOG`: enabled
- `FORCE LOGGING`: enabled
- `FLASHBACK_ON`: `YES`
- Active Data Guard open mode: `READ ONLY WITH APPLY`
- Managed recovery process: running
- Online redo: 4 groups per thread, 4000 MB each
- Standby redo: 4 groups per thread, 4000 MB each

Broker validation before enabling FSFO:

- Configuration status: `SUCCESS`
- Potential FSFO target: `crashdr`
- `FastStartFailoverTarget` was already configured both ways:
  - `crashrdb` target: `crashdr`
  - `crashdr` target: `crashrdb`

## Bastion Observer Setup

The bastion did not initially have Oracle broker tooling. The following observer footprint was configured:

- Installed Oracle Instant Client release repo package: `oracle-instantclient-release-26ai-el9`
- Installed Oracle Instant Client Basic: `oracle-instantclient-basic-23.26.2.0.0-1.el9`
- Staged `dgmgrl` from the database Oracle home to `/home/opc/dgmgrl`
- Configured Oracle Net files under `/home/opc/crashsim_fsfo/network/admin`
- Configured passwordless observer access using an Oracle Secure External Password Store wallet under `/home/opc/crashsim_fsfo/wallet`
- Configured observer logs under `/home/opc/crashsim_fsfo/logs`

No database password is stored in the repository or in the observer command line.

## FSFO Configuration

Fast-Start Failover was enabled successfully:

- FSFO mode: `Enabled in Potential Data Loss Mode`
- Protection mode: `MaxPerformance`
- Active target: `crashdr`
- Lag limit: 30 seconds
- Lag type: `APPLY`
- Threshold: 30 seconds
- Shutdown primary: `TRUE`
- Auto-reinstate: `TRUE`
- Observer override: `FALSE`

Important note: because the Data Guard configuration is currently `MaxPerformance` with asynchronous transport, FSFO is enabled in Potential Data Loss Mode. For a zero-data-loss FSFO posture, move to an appropriate Maximum Availability/SYNC design and revalidate transport, standby redo logs, network latency, and application SLA requirements.

## Observer Service

The observer is managed by systemd on the bastion:

- Service: `crashsim-fsfo-observer.service`
- Service state: `enabled`
- Runtime state: `active`
- Process: `/home/opc/dgmgrl`
- Observer file: `/home/opc/crashsim_fsfo/observer_crashdb.dat`
- Observer log: `/home/opc/crashsim_fsfo/logs/observer_crashdb.log`

The service uses a wrapper script:

- `/home/opc/crashsim_fsfo/start_observer.sh`

## Final Validation

Broker final state:

- Configuration status: `SUCCESS`
- FSFO state: `Enabled in Potential Data Loss Mode`
- Active target: `crashdr`
- Observer: `crashsim_bastion_observer`

Observer log confirmed:

- Observer started on host `crashbastian`
- Primary connect string: `crashrdb`
- Standby connect string: `crashdr`
- Standby `crashdr` ready as FSFO target
- Connection to primary restored

## Useful Validation Commands

From the bastion:

```bash
sudo systemctl status crashsim-fsfo-observer.service
export TNS_ADMIN=/home/opc/crashsim_fsfo/network/admin
export LD_LIBRARY_PATH=/usr/lib/oracle/23/client64/lib
/home/opc/dgmgrl -silent /@CRASHRDB "show configuration"
/home/opc/dgmgrl -silent /@CRASHRDB "show fast_start failover"
```

To stop the observer through broker:

```bash
export TNS_ADMIN=/home/opc/crashsim_fsfo/network/admin
export LD_LIBRARY_PATH=/usr/lib/oracle/23/client64/lib
/home/opc/dgmgrl -silent /@CRASHRDB "stop observer all"
sudo systemctl stop crashsim-fsfo-observer.service
```
