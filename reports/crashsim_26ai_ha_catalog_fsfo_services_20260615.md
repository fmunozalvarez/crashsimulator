# CrashSimulator 26ai HA Catalog, FSFO, FEX/ACFS, And Service Setup

Generated UTC: 2026-06-15

## Environment

- Primary RAC node used for setup: `crashrac1-mlprn`
- Database unique name: `crashrac`
- Database name: `CRASHDB`
- PDB: `CRASHPDB`
- Oracle Database version family: 26ai / 23.26 home
- Storage posture discovered by CrashSimulator after patch: `FEX_ACFS`

## RMAN Recovery Catalog

Status: configured and validated for the lab.

- Catalog owner: `RMAN_CATALOG`
- Catalog location: `CRASHPDB` in the lab target CDB
- Target DBID: `1275818439`
- Target registration: complete
- Validation: full resync completed and `REPORT SCHEMA` returned the CDB/PDB datafile inventory
- CrashSimulator runtime config: RMAN catalog is configured and redacted by `--show-config`

Important: this is a development lab catalog inside the target CDB/PDB. For production MAA/DR posture, host the recovery catalog in a separate protected database outside the target database failure domain.

## FSFO

Status: not configured in this environment because prerequisites are absent.

Evidence shows:

- `dg_broker_start=FALSE`
- Data Guard Broker reports `ORA-16525`
- `FS_FAILOVER_STATUS=DISABLED`
- No standby archive destination is currently configured

FSFO remains blocked until a Broker-managed Data Guard configuration exists, flashback and standby redo are validated on all members, and an observer host can reach both primary and standby connect identifiers. A bastion observer should be used when the standby topology is available.

## AC/TAC/FAN Services

Status: configured and running.

Dedicated CrashSimulator lab services were created instead of modifying the OCI-created default PDB service:

- `crashsim_ac`
  - Role: `PRIMARY`
  - PDB: `CRASHPDB`
  - FAN/AQ notifications: `TRUE`
  - Commit outcome: `TRUE`
  - Failover type: `TRANSACTION`
  - Failover restore: `LEVEL1`
  - Runtime load balancing goal: `SERVICE_TIME`
  - Drain timeout: `300`
  - Running on: `crashdb1`, `crashdb2`
- `crashsim_tac`
  - Role: `PRIMARY`
  - PDB: `CRASHPDB`
  - FAN/AQ notifications: `TRUE`
  - Commit outcome: `TRUE`
  - Failover type: `AUTO`
  - Failover restore: `AUTO`
  - Runtime load balancing goal: `SERVICE_TIME`
  - Session state consistency: `AUTO`
  - Drain timeout: `300`
  - Running on: `crashdb1`, `crashdb2`

CrashSimulator service review now reports:

- AC services: `1`
- TAC services: `1`
- FAN/AQ notification services: `2`
- Commit outcome services: `2`
- Drain-timeout services: `2`
- srvctl service evidence: `OK`

## Framework Improvements

- FEX/ACFS discovery now includes GI mount paths and CRS ACFS resource metadata.
- Exact ACFS mount path `/var/opt/oracle/dbaas_acfs` is classified as `ACFS`.
- Mixed FEX handles plus visible ACFS mounts are reported as `FEX_ACFS`.
- Service review now uses Grid-home discovery for `srvctl` instead of relying only on `PATH`.
- The srvctl service parser now recognizes 26ai service fields for AC/TAC, FAN/AQ, commit outcome, RLB, drain timeout, session state consistency, and failover restore.
- The scenario-specific srvctl evidence collector was renamed so it no longer overrides the MAA/service-report parser.
- Added reusable lab helper scripts:
  - `tools/crashsim_collect_ha_config.sh`
  - `tools/crashsim_configure_ha_lab.sh`

## Local Evidence

Relevant evidence was saved under:

- `captures/26ai_new_rac_20260615/ha_config_discovery_20260615_100617.txt`
- `captures/26ai_new_rac_20260615/rman_catalog_setup_retry_20260615_101805.txt`
- `captures/26ai_new_rac_20260615/ac_tac_services_setup_retry_20260615_102049.txt`
- `captures/26ai_new_rac_20260615/fsfo_prereq_check_20260615_102119.txt`
- `captures/26ai_new_rac_20260615/crashsim_runtime_redeploy_discover_20260615_102226.txt`
- `captures/26ai_new_rac_20260615/crashsim_service_review_20260615_103446.md`
- `captures/26ai_new_rac_20260615/crashsim_backup_report_20260615_103836.md`
- `captures/26ai_new_rac_20260615/service_scenarios_83_84_87_dryrun_retry_20260615_103619.txt`

## Next Safe Actions

- Run scenario `83` with an approved replay-safe client workload to prove AC/TAC replay behavior.
- Run scenario `84` only after defining the safe ONS/FAN interruption and restoration boundary.
- Configure Data Guard/Broker before attempting FSFO observer setup.
- Once Data Guard exists, add standby role-based services and rerun scenario `87`.
