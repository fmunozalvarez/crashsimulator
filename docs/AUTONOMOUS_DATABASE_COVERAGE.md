# CrashSimulator Autonomous Database Coverage

CrashSimulator treats Oracle Autonomous Database as a separate cloud-service
coverage family. Traditional CrashSimulator drills assume database-host access:
OS files, ASM, Grid Infrastructure, control files, redo files, password files,
SPFILEs, ORACLE_HOME, and RMAN backup pieces. Autonomous Database customers do
not manage those layers directly, so those drills should not be forced into ADB.

For ADB, the useful practice areas are logical/user error recovery, clone and
point-in-time workflows, wallet/connectivity recovery, private endpoint
diagnostics, workload/resource limits, Autonomous Data Guard, IAM, Object
Storage, and application access paths such as APEX.

## New Report

Run the Autonomous readiness report from any client host or bastion that can
reach the ADB endpoint:

```bash
export CRASHSIM_ADB_PASSWORD='<database password>'
export CRASHSIM_ADB_WALLET_PASSWORD='<wallet password if required>'

./CrashSimulatorV2.sh \
  --adb-readiness-report \
  --adb-wallet-dir /path/to/Wallet_myadb \
  --adb-connect-alias myadb_low \
  --adb-user ADMIN \
  --adb-python /path/to/python \
  --html

./CrashSimulatorV2.sh --list-adb-scenarios
./CrashSimulatorV2.sh --adb-scenario ADB01
```

The report does not require local `sqlplus`, `rman`, ASM, Grid Infrastructure,
or Oracle OS ownership. It uses `python-oracledb` for SQL evidence when
credentials are available, and it falls back to a config-only/readiness report
when the live SQL probe cannot run.

## Configuration Keys

Use `crashsimulator.conf` for non-secret defaults:

```text
CRASHSIM_ADB_WALLET_DIR=/path/to/Wallet_myadb
CRASHSIM_ADB_CONNECT_ALIAS=myadb_low
CRASHSIM_ADB_SERVICE_LEVEL=low
CRASHSIM_ADB_USER=ADMIN
CRASHSIM_ADB_PASSWORD_ENV=CRASHSIM_ADB_PASSWORD
CRASHSIM_ADB_WALLET_PASSWORD_ENV=CRASHSIM_ADB_WALLET_PASSWORD
CRASHSIM_ADB_PYTHON=/path/to/python
CRASHSIM_ADB_TLS_MODE=mTLS
CRASHSIM_ADB_OCID=ocid1.autonomousdatabase...
CRASHSIM_ADB_REGION=us-ashburn-1
CRASHSIM_ADB_APEX_URL=https://example.adb.region.oraclecloudapps.com/ords/apex
CRASHSIM_ADB_DATABASE_ACTIONS_URL=https://example.adb.region.oraclecloudapps.com/ords/sql-developer
CRASHSIM_ADB_PRIVATE_ENDPOINT=myadb-private-endpoint
CRASHSIM_ADB_SCENARIO=ADB01
```

Do not store database passwords, wallet passphrases, API keys, or wallet files
in the repository or config file. The config stores only the environment
variable names that contain secrets.

## Scenario Family

The CLI can list the current catalog with `--list-adb-scenarios` and show a
single entry with `--adb-scenario ADB01`. The Guided Workflow menu also has an
Autonomous Database scenarios submenu where users can browse `ADB01` through
`ADB15`, select a scenario, review validation status, configure ADB context,
refresh the readiness report, and later launch ADB-specific helpers when those
seeded logical/OCI workflows are added. In the Guided Workflow Reports menu,
options `12` through `18` cover ADB context, readiness report generation,
report browsing, ADB scenario list/select/detail, and the full ADB submenu.
The menu can open these ADB options even when local SQL*Plus discovery is not
available on a client or bastion host.

| ID | Scenario | Validation | Recovery focus |
| --- | --- | --- | --- |
| `ADB01` | Drop critical application table | Live SQL connection, disposable lab table, flashback/export/clone path | Flashback Table, PITR clone, Data Pump/object merge |
| `ADB02` | Drop application schema | Disposable schema, grants/object inventory, clone/export path | Clone/export recovery, user/grant restoration |
| `ADB03` | Mass DELETE without WHERE clause | Lab table row-count evidence and flashback window | Flashback Query/Table, clone comparison, data merge |
| `ADB04` | Incorrect UPDATE corrupts data | Lab table before/after checks and validation query | Flashback Versions Query, object restore, data comparison |
| `ADB05` | Recover from clone | OCI metadata and clone permissions | Create clone, validate object/application, merge data |
| `ADB06` | Point-in-time recovery drill | OCI PITR/clone-to-time window | Measure RTO/RPO, validate clone, extract/merge data |
| `ADB07` | Backup recoverability validation | OCI backup retention/latest backup/PITR window | Evidence-only or clone-based restore validation |
| `ADB08` | Expired or rotated client wallet | Wallet path, aliases, expiry/rotation owner | Download wallet, update clients, reconnect |
| `ADB09` | Private endpoint connectivity loss | DNS, route, NSG/security-list, bastion path | Restore network path and validate reconnect |
| `ADB10` | Connection pool saturation | Approved client workload and service target | Tune pools, retries, service class, application backoff |
| `ADB11` | Resource Manager/concurrency pressure | Approved workload generator and thresholds | Review service class, scaling, consumer limits |
| `ADB12` | Cross-region DR validation | OCI Autonomous Data Guard metadata | Failover validation, reconnect, RTO/RPO measurement |
| `ADB13` | Autonomous Data Guard role transition | ADG role, region, lag, switchover eligibility | Switchover/failover and fallback runbook |
| `ADB14` | IAM administrator access misconfiguration | IAM policy/group evidence and approval boundary | Restore IAM access and validate admin automation |
| `ADB15` | Object Storage export dependency unavailable | Bucket, credential, DBMS_CLOUD, network evidence | Restore bucket/policy/credential/network access |

## Implementation Posture

The first implementation layer is report/readiness oriented. It identifies
which ADB drills are runnable, which require lab seeding, and which require OCI
control-plane evidence. The next safe development step is to add ADB-specific
lab seed and logical drill helpers for `ADB01`, `ADB03`, and `ADB04`, followed
by OCI metadata collection for clone/PITR/Autonomous Data Guard scenarios.

## Tested Environment Evidence

The project includes a live Autonomous Database discovery reference:

- `reports/crashsim_adb_readonly_discovery_20260608.md`

Use `--adb-readiness-report --html` to generate a fresh Markdown and HTML
readiness report for any configured Autonomous target.
