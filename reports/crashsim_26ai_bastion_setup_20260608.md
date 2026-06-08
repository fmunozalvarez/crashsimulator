# CrashSimulator 26ai Bastion RAC Setup Evidence

- Generated UTC: `2026-06-08T08:57:00Z`
- Local repository commit used for deployment: `1e093c1`
- Bastion host: `crashbastian`
- RAC node 1: `crashrac1-xnvfw`
- RAC node 2: `crashrac2-picqh`

## Deployment

CrashSimulator was installed on both RAC nodes under `/tmp/crashsimulator`.
The private key stayed on the laptop; access used SSH through the bastion with
`ProxyCommand`.

Runtime checksums on the database hosts:

- `CrashSimulatorV2.sh`: `c931a9ec01bcc146195354f7a4ebe5fadd7c5ecfaec2a4a41730ef4bb7bab984`
- `config/crashsimulator.conf.example`: `3ff1f993601809e2f1ed878aac813334ea5bf04971d0e34b122c38faaf55cdc2`

Node-local `crashsimulator.conf` files were created with:

- Node 1 `ORACLE_SID`: `crashdb1`
- Node 2 `ORACLE_SID`: `crashdb2`
- `ORACLE_HOME`: `/u02/app/oracle/product/23.0.0.0/dbhome_1`
- `ORACLE_BASE`: `/u02/app/oracle`
- `TNS_ADMIN`: `/u02/app/oracle/product/23.0.0.0/dbhome_1/network/admin`
- `CRASHSIM_GRID_HOME`: `/u01/app/23.0.0.0/gridhome_1`
- `CRASHSIM_PDB`: `CRASHPDB`

The Oracle user PATH did not include `/usr/local/bin`, so root-owned symlinks
were added under `/usr/local/sbin` for `crashsimulator`, `srvctl`, `crsctl`, and
`olsnodes`. After this, CrashSimulator correctly detected the database as
GI-managed and discovered password-file metadata through `srvctl`.

## Discovered Topology

- Database name: `CRASHDB`
- DB unique name: `crashrdb`
- CDB: `YES`
- PDB: `CRASHPDB`
- Role: `PRIMARY`
- Open mode: `READ WRITE`
- RAC: `YES`
- Instances: `crashdb1`, `crashdb2`
- GI managed: `YES`
- FRA: `@rJOnB8bM(RECO_HC_HIGHREDUNDANCY)`
- Storage detected by CrashSimulator: `FILESYSTEM`

This environment uses Oracle `@...` storage naming and an ACFS/FEX-style mount
path rather than normal ASM `+DISKGROUP` paths, so ASM-only scenarios remain
blocked unless a dedicated ASM lab is added.

## Lab Seeding

`seed_crashsim_lab.sql` completed successfully from node 1.

Verified lab targets:

- CDB root user: `C##CRASHSIM_ROOT_LAB`
- Root read-only tablespace: `CRASHSIM_ROOT_RO_TBS`
- Root index tablespace: `CRASHSIM_ROOT_INDEX_TBS`
- PDB users: `CRASHSIM_TABLE_LAB`, `CRASHSIM_SCHEMA_LAB`, `CRASHSIM_INDEX_LAB`
- PDB read-only tablespace: `CRASHSIM_RO_TBS`
- PDB index tablespace: `CRASHSIM_INDEX_TBS`

## Baseline Backup

A fresh RMAN baseline backup completed successfully.

- Backup tag: `CSIM_BASE_260608084223`
- Command file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_baseline_backup_20260608_084223.rman`
- Log file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_baseline_backup_20260608_084223.log`

The backup/recoverability report detected a Level 0/full datafile backup strategy
with archived redo backups. The warning in the report is due to `RMAN-06525`
because the RMAN retention policy is set to `NONE`; the RMAN backup validation
sections completed.

## Readiness Snapshot

After the GI PATH fix, scenario readiness for `CRASHPDB` reported:

- Runnable scenarios: `55`
- Plan-only scenarios: `5`
- Not runnable scenarios: `22`
- Registered scenarios evaluated: `82`

Important current blockers:

- Scenarios `3` and `18`: online redo logs are not multiplexed.
- Scenarios `46`, `49`, and `72`: require conventional ASM storage.
- Scenario `70`: VIP relocation needs a privileged Grid/Clusterware path; `crsctl` works as `grid`, but not cleanly as `oracle`.
- Scenarios `47` and `48`: plan-only OCR/voting disk drills, as expected.
- Data Guard standby/ADG/FSFO scenarios need a standby and broker/observer posture.
- APEX/ORDS scenarios need APEX/ORDS installed and configured.

The MAA readiness report detected current posture as `Gold` with baseline checks
passed.

## Preserved Evidence

Final evidence was copied to:

- `captures/26ai_bastion/26ai_bastion_discover_node1_20260608.txt`
- `captures/26ai_bastion/26ai_bastion_discover_node2_20260608.txt`
- `captures/26ai_bastion/26ai_bastion_show_config_node1_20260608.txt`
- `captures/26ai_bastion/26ai_bastion_show_config_node2_20260608.txt`
- `captures/26ai_bastion/crashsim_26ai_bastion_evidence_20260608.tgz`
- `captures/26ai_bastion/evidence_20260608/`

The evidence directory includes generated topology, configuration, backup,
scenario readiness, scenario lifecycle, service HA, MAA readiness, health check,
seed/verify, baseline backup, and audit artifacts.

## Security Check

The copied evidence was scanned locally for private keys, known admin
credentials, and unredacted catalog/password markers. No matches were found.
