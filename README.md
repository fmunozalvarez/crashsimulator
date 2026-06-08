# CrashSimulator

CrashSimulator is an open-source Oracle Resilience Validation Platform that combines failure 
simulation, recoverability analysis, Oracle MAA assessment, SLA-driven readiness evaluation, 
operational runbooks, compliance evidence collection, and recovery validation to continuously
measure and improve database resilience.

CrashSimulator V2 is the current single-script framework. It supports dry-run
planning, guided menu execution, recovery runbook hints, protection and recovery
helpers, topology-aware random scenario selection, scenario readiness reporting,
scenario lifecycle coverage reporting, configuration reports, Oracle MAA
readiness reporting, Autonomous Database readiness reporting, and Oracle service HA best-practice reviews for AC/TAC,
FSFO observer placement, ADG DML redirection, and role-based services. It also includes targeted
FRA pressure, TEMP exhaustion, and RTO/RPO validation drills, plus Data Guard,
RAC, ASM, and APEX/ORDS-specific practice for FSFO, transport/apply lag,
standby redo logs, VIP/service placement, ASM disk failure planning, ORDS
service/config outages, APEX runtime-user lockouts, static-resource loss, and
application access-path validation. For Oracle Autonomous Database, it uses a
separate cloud-service coverage model focused on logical/user-error recovery,
clone/PITR readiness, wallet/connectivity, private endpoint, Autonomous Data
Guard, IAM, Object Storage, and resource-limit drills. It can also review previously collected
topology, runbooks, health checks, reports, manifests, and audit records from
the CLI or Guided Workflow menu, with optional HTML rendering for easier
visualization.

Compatibility statement: CrashSimulator is designed for Oracle Database 12c and
later, and the project validation evidence now includes live Oracle Database
19c and Oracle AI Database 26ai RAC/ASM labs. This is CrashSimulator project
validation, not an official Oracle product certification.

For the full end-user documentation, read:

- [CrashSimulator End-User Guide](docs/CRASHSIMULATOR_USER_GUIDE.md)
- [CLI setup and scenario narrated tutorial video](assets/tutorial/crashsimulator_cli_tutorial_with_audio.mp4)
- [Guided Workflow scenario narrated tutorial video](assets/tutorial/crashsimulator_guided_workflow_tutorial_with_audio.mp4)
- [Audit retention narrated tutorial video](assets/tutorial/crashsimulator_audit_retention_tutorial_with_audio.mp4)
- [Scenario readiness narrated tutorial video](assets/tutorial/crashsimulator_scenario_readiness_tutorial_with_audio.mp4)
- [Guided Reports menu narrated tutorial video](assets/tutorial/crashsimulator_guided_reports_menu_tutorial_with_audio.mp4)
- [APEX/ORDS scenario 80 narrated tutorial video](assets/tutorial/crashsimulator_apex_session_driver_tutorial_with_audio.mp4)
- [Purpose-built redundant GI/ASM lab runbook](docs/REDUNDANT_GI_LAB_RUNBOOK.md)
- [Scenario 80 APEX browser-session driver design](docs/APEX_SESSION_DRIVER_DESIGN.md)
- [Autonomous Database coverage guide](docs/AUTONOMOUS_DATABASE_COVERAGE.md)
- [Scenario validation status](SCENARIO_STATUS.md)
- [26ai RAC/ASM validation summary](reports/crashsim_26ai_validation_20260607.md)
- [Detailed V2 notes](README_V2.md)
- [Reference report examples](docs/reference/README.md)

## Install From A ZIP File

Download the repository ZIP from GitHub, copy it to the Oracle database host,
and unzip it.

```bash
unzip crashsimulator-main.zip
cd crashsimulator-main
chmod +x crashsimulator CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
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

Alternatively, create a local startup configuration file so CrashSimulator can
fill missing Oracle and CrashSimulator defaults automatically:

```bash
cp config/crashsimulator.conf.example crashsimulator.conf
vi crashsimulator.conf
./CrashSimulatorV2.sh --show-config
./CrashSimulatorV2.sh --validate-config
```

Configuration precedence is: CLI arguments, existing shell environment,
configuration file, then built-in defaults. The file is parsed as allowlisted
`KEY=value` entries and is not sourced as shell code. Do not store passwords or
wallet secrets in it.

Validate the download and start safely:

```bash
./CrashSimulatorV2.sh --help
./crashsimulator --help
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --list
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --validate-scenario 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --menu
./crashsimulator --menu
```

`--dry-run` is the default. Destructive scenarios require `--execute` and an
interactive confirmation token.

The Guided Workflow menu separates safe planning actions from execution actions
and redacts RMAN catalog/SYS password values from command echoes. It also
includes a dedicated Autonomous Database scenarios submenu to browse `ADB01`
through `ADB15`, select one, review validation status, configure ADB context,
and refresh ADB readiness evidence.

## Tutorial Videos

Short setup, full scenario walkthrough, audit-retention, scenario-readiness,
Guided Reports menu, and APEX/ORDS session-continuity videos are available in
[assets/tutorial](assets/tutorial/README.md). Narrated MP4s, burned-in subtitle
MP4s, and WebVTT subtitle sidecars are included for CLI and Guided Workflow
menu modes.

## First Safe Commands

```bash
./CrashSimulatorV2.sh --discover
./CrashSimulatorV2.sh --health-check
./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --scenario-lifecycle-report --html
./CrashSimulatorV2.sh --validate-all-scenarios --pdb CRASHPDB
./CrashSimulatorV2.sh --config-report
./CrashSimulatorV2.sh --backup-report
./CrashSimulatorV2.sh --service-review --html
./CrashSimulatorV2.sh --apex-ords-report --pdb CRASHPDB --html
./CrashSimulatorV2.sh --adb-readiness-report --html
./CrashSimulatorV2.sh --list-adb-scenarios
./CrashSimulatorV2.sh --adb-scenario ADB01
./CrashSimulatorV2.sh --baseline-backup --dry-run
./CrashSimulatorV2.sh --audit-status
./CrashSimulatorV2.sh --maa-report
./CrashSimulatorV2.sh --review
./CrashSimulatorV2.sh --show-artifact latest:topology --html
./CrashSimulatorV2.sh --runbook 30 --pdb CRASHPDB
./CrashSimulatorV2.sh --scenario 30 --pdb CRASHPDB --dry-run
```

The Guided Workflow menu can also prompt for required scenario context. PDB
scenarios guide PDB selection, logical drills can offer disposable lab schemas,
and FILE# selection shows datafile/PDB/tablespace context instead of requiring
operators to type an unexplained number.

## Important Safety Note

Run destructive scenarios only in approved non-production or dedicated
resilience-test environments. Always confirm backups, dry-run target selection,
review the recovery runbook, and keep the generated manifest for recovery.
