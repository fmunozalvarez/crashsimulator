# CrashSimulator

CrashSimulator is an open-source resilience validation platform for Oracle
Database environments. By orchestrating controlled failures and recovery
scenarios, it helps organizations continuously verify recoverability, strengthen
operational readiness, validate HA/DR architectures, and demonstrate compliance
with recovery objectives and regulatory requirements.

CrashSimulator V2 is the current single-script framework. It supports dry-run
planning, guided menu execution, recovery runbook hints, protection and recovery
helpers, topology-aware random scenario selection, configuration reports, and
Oracle MAA readiness reporting.

For the full end-user documentation, read:

- [CrashSimulator End-User Guide](docs/CRASHSIMULATOR_USER_GUIDE.md)
- [Scenario validation status](SCENARIO_STATUS.md)
- [Detailed V2 notes](README_V2.md)

## Install From A ZIP File

Download the repository ZIP from GitHub, copy it to the Oracle database host,
and unzip it.

```bash
unzip crashsimulator-main.zip
cd crashsimulator-main
chmod +x CrashSimulatorV2.sh
```

Run as the Oracle software owner, or as an OS user that can connect locally as
SYSDBA. Set the target Oracle environment first:

```bash
sudo su - oracle
export ORACLE_HOME=/u01/app/oracle/product/19.0.0.0/dbhome_1
export ORACLE_SID=orcl
export PATH=$ORACLE_HOME/bin:$PATH
cd /path/to/crashsimulator-main
```

Validate the download and start safely:

```bash
./CrashSimulatorV2.sh --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --menu
```

`--dry-run` is the default. Destructive scenarios require `--execute` and an
interactive confirmation token.

The Guided Workflow menu separates safe planning actions from execution actions
and redacts RMAN catalog/SYS password values from command echoes.

## First Safe Commands

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --maa-report
./CrashSimulatorV2.sh --runbook 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run
```

## Important Safety Note

Run destructive scenarios only in approved non-production or dedicated
resilience-test environments. Always confirm backups, dry-run target selection,
review the recovery runbook, and keep the generated manifest for recovery.
