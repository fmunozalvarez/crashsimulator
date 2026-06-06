# CrashSimulator

CrashSimulator is an open-source Oracle Resilience Validation Platform that combines failure 
simulation, recoverability analysis, Oracle MAA assessment, SLA-driven readiness evaluation, 
operational runbooks, compliance evidence collection, and recovery validation to continuously
measure and improve database resilience.

CrashSimulator V2 is the current single-script framework. It supports dry-run
planning, guided menu execution, recovery runbook hints, protection and recovery
helpers, topology-aware random scenario selection, scenario readiness reporting,
configuration reports, and Oracle MAA readiness reporting. It can also review previously collected
topology, runbooks, health checks, reports, manifests, and audit records from
the CLI or Guided Workflow menu, with optional HTML rendering for easier
visualization.

For the full end-user documentation, read:

- [CrashSimulator End-User Guide](docs/CRASHSIMULATOR_USER_GUIDE.md)
- [CLI setup and scenario narrated tutorial video](assets/tutorial/crashsimulator_cli_tutorial_with_audio.mp4)
- [Guided Workflow scenario narrated tutorial video](assets/tutorial/crashsimulator_guided_workflow_tutorial_with_audio.mp4)
- [Audit retention narrated tutorial video](assets/tutorial/crashsimulator_audit_retention_tutorial_with_audio.mp4)
- [Scenario readiness narrated tutorial video](assets/tutorial/crashsimulator_scenario_readiness_tutorial_with_audio.mp4)
- [Purpose-built redundant GI/ASM lab runbook](docs/REDUNDANT_GI_LAB_RUNBOOK.md)
- [Scenario validation status](SCENARIO_STATUS.md)
- [Detailed V2 notes](README_V2.md)
- [Reference report examples](docs/reference/README.md)

## Install From A ZIP File

Download the repository ZIP from GitHub, copy it to the Oracle database host,
and unzip it.

```bash
unzip crashsimulator-main.zip
cd crashsimulator-main
chmod +x CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh
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
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --menu
```

`--dry-run` is the default. Destructive scenarios require `--execute` and an
interactive confirmation token.

The Guided Workflow menu separates safe planning actions from execution actions
and redacts RMAN catalog/SYS password values from command echoes.

## Tutorial Videos

Short setup, full scenario walkthrough, audit-retention, and scenario-readiness
videos are available in [assets/tutorial](assets/tutorial/README.md). Narrated
MP4s, burned-in subtitle MP4s, and WebVTT subtitle sidecars are included for CLI
and Guided Workflow menu modes.

## First Safe Commands

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --baseline-backup --dry-run
./CrashSimulatorV2.sh --audit-status
./CrashSimulatorV2.sh --maa-report
./CrashSimulatorV2.sh --review
./CrashSimulatorV2.sh --show-artifact latest:topology --html
./CrashSimulatorV2.sh --runbook 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run
```

## Important Safety Note

Run destructive scenarios only in approved non-production or dedicated
resilience-test environments. Always confirm backups, dry-run target selection,
review the recovery runbook, and keep the generated manifest for recovery.
