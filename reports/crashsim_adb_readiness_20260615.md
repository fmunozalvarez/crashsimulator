# CrashSimulator Autonomous Database Readiness Report

- Generated UTC: `2026-06-15T05:47:38Z`
- Tool version: `2.0.1-beta`
- Host: `Franciscos-MacBook-Pro.local`
- OS user: `franciscomunozalvarez`
- ADB user: `ADMIN`
- TLS mode: `mTLS`
- Evidence file: `/private/tmp/crashsim_adb_oci_ready/crashsim_adb_readiness_20260615_154738.evidence`

Autonomous Database hides OS, storage, ASM, Grid Infrastructure, control files, redo files, SPFILE, password file, and managed-backup internals from customers. This report therefore separates traditional CrashSimulator database-host scenarios from cloud-service scenarios that are realistic for ADB: logical/user-error recovery, clone/PITR, wallet/connectivity, service limits, Autonomous Data Guard, IAM, and Object Storage dependencies.

## Connection And Configuration

| Signal | Value |
| --- | --- |
| Wallet directory | `/private/tmp/crashsim_adb_wallet_20260615` |
| Wallet state | `present` |
| tnsnames.ora | `present` |
| Wallet aliases | `crashautonomous_high, crashautonomous_low, crashautonomous_medium, crashautonomous_tp, crashautonomous_tpurgent` |
| Connect alias / descriptor | `crashautonomous_low` |
| Service-level hint | `low` |
| Password env var | `CRASHSIM_ADB_PASSWORD` |
| Wallet password env var | `CRASHSIM_ADB_WALLET_PASSWORD` |
| Python executable | `/private/tmp/crashsim_adb_venv/bin/python` |
| python-oracledb | `4.0.1` |
| SQL connection | `OK` |
| OCI CLI | `found` |
| OCI control-plane posture | `metadata collected` |
| OCI auth mode | `security_token` |
| OCI metadata status | `OK` |
| OCI ADB lifecycle | `AVAILABLE` |
| OCI backup retention days | `60` |
| APEX URL | `https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/apex` |
| Database Actions URL | `https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/sql-developer` |
| Private endpoint expectation | `not configured` |

## Live SQL Evidence Summary

| Signal | Value |
| --- | --- |
| DB identity | `FCEYFTL6\|READ WRITE\|PRIMARY\|YES\|ARCHIVELOG\|YES\|` |
| Version | `Oracle AI Database 26ai Enterprise Edition Release <ip-redacted>.0 - Production Version <ip-redacted>.0` |
| Version number | `<ip-redacted>.0` |
| Services | `KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_high.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_low.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_medium.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_tp.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_tpurgent.adb.oraclecloud.com, kemeja2k9zf9hpa_crashautonomous` |
| APEX registry | `24.2.17:VALID` |
| Tablespaces | `7` |
| Encrypted tablespaces | `6` |
| Segment size GB | `165.34` |
| Flashback archive count | `1` |
| Flashback archive retention days | `60` |
| Open application users | `2` |
| Application users | `ADBSNMP:LOCKED, ADB_APP_STORE:LOCKED, ADMIN:OPEN, DCAT_ADMIN:LOCKED, GGADMIN:LOCKED, RMAN$CATALOG:OPEN` |
| Invalid objects | `3` |
| Recycle bin rows | `0` |
| Resource plan | `OLTP_PLAN` |

## OCI Control-Plane Evidence Summary

| Signal | Value |
| --- | --- |
| Metadata status | `OK` |
| Metadata file | `/private/tmp/crashsim_adb_oci_ready/crashsim_adb_readiness_20260615_154738_oci_adb.json` |
| Display name / DB name | `crashai` / `crashautonomous` |
| Lifecycle state | `AVAILABLE` |
| Compartment OCID | `ocid1.<redacted>` |
| Backup retention days | `60` |
| Total backup storage GB | `6.0` |
| Manual backup type / bucket | `NONE` / `NONE` |
| Data Guard enabled | `false` |
| Local / remote Data Guard | `false` / `false` |
| Data Guard region type | `NONE` |
| Peer DB IDs | `NONE` |
| Private endpoint / label / IP | `NONE` / `NONE` / `NONE` |
| NSGs | `NONE` |
| Data Safe / Operations Insights | `NOT_REGISTERED` / `NOT_ENABLED` |
| Permission level | `UNRESTRICTED` |
| APEX / ORDS version | `24.2.17` / `<ip-redacted>.1916` |
| Supported clone regions | `KIX, ICN, SIN, BOM, HYD, IAD, PHX, FRA, CWL, ORD, SJC, MEL, AMS, LHR, YUL, YYZ, SYD` |

## ADB Readiness Scorecard

This scorecard summarizes Autonomous Database resilience domains separately from host-based Oracle Database scenarios. PASS means CrashSimulator found direct evidence in the current report. PARTIAL means the control path or prerequisite exists, but a drill or deeper OCI metadata check is still needed. GAP means the report cannot currently prove the domain.

| Domain | Status | Evidence | Next action |
| --- | --- | --- | --- |
| Backup Readiness | `PASS` | OCI backup retention is 60 days; total backup storage is 6.0 GB. | Run ADB07 clone/restore validation to convert configured backup posture into measured recoverability evidence. |
| PITR Validation | `PARTIAL` | Backup retention is 60 days and supported clone regions are visible. | Run ADB06 with a selected timestamp and record elapsed clone, validation, and data-merge evidence before marking PASS. |
| Autonomous Data Guard Protection | `GAP` | OCI reports Autonomous Data Guard disabled; local=false, remote=false. | Enable/configure Autonomous Data Guard when DR requirements require managed standby protection. |
| Cross-Region DR | `GAP` | No remote Autonomous Data Guard peer is visible in OCI metadata. | Configure cross-region ADG or document accepted risk when regional DR is not required. |
| IAM / Administrator Access | `PARTIAL` | OCI metadata is available; Data Safe status=NOT_REGISTERED, permission level=UNRESTRICTED. | Review policies, groups, break-glass access, automation principal, and least-privilege boundaries before marking PASS. |
| Wallet Management | `PASS` | mTLS wallet and tnsnames.ora are present, aliases are visible, and SQL probe connects. | Keep wallet rotation owner, distribution inventory, expiry review, and reconnect test evidence current. |
| Private Endpoint Validation | `INFO` | No private endpoint expectation was configured. | Set CRASHSIM_ADB_PRIVATE_ENDPOINT when the ADB uses private endpoints. |
| Resource Manager | `PASS` | Resource plan evidence: OLTP_PLAN. | Add workload threshold evidence for ADB10/ADB11 when validating saturation or concurrency pressure. |
| Logical / Object Recovery | `PASS` | Flashback Archive rows exist with retention_days=60. | Run seeded ADB01/ADB03/ADB04 drills to prove object-level recovery, not only configuration. |
| Application Access Path | `PASS` | SQL probe connects and user-facing URL context is recorded. | Add URL smoke checks and application login/session validation after wallet, clone/PITR, or ADG drills. |

| Metric | Value |
| --- | ---: |
| ADB Readiness Score | 68% |
| Scored domains | 9 |

## Readiness Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | Client connectivity | mTLS wallet available | wallet=/private/tmp/crashsim_adb_wallet_20260615, aliases=crashautonomous_high, crashautonomous_low, crashautonomous_medium, crashautonomous_tp, crashautonomous_tpurgent | Keep wallet rotation, expiry review, and application redeploy steps in the runbook. |
| `OK` | Client connectivity | python-oracledb available | python=/private/tmp/crashsim_adb_venv/bin/python, version=4.0.1 | Pin driver/runtime versions in automation hosts used for readiness reporting. |
| `OK` | Database access | Live SQL probe connects | user=ADMIN, db=FCEYFTL6, open=READ WRITE, role=PRIMARY | Use this same client path for logical recovery drills and application smoke tests. |
| `OK` | Application access | APEX component visible | APEX=24.2.17:VALID | Add APEX smoke/session checks for user-facing ADB applications. |
| `OK` | Logical recovery | Flashback Archive evidence | archives=1, retention_days=60 | Use flashback query/table and clone/PITR drills for logical user-error recovery validation. |
| `WARN` | OCI control plane | ADB OCID and OCI CLI configured | state=metadata collected | Configure CRASHSIM_ADB_OCID plus OCI CLI/profile when backup/PITR/ADG/IAM readiness must be proven. |
| `OK` | Application access | User-facing URLs recorded | apex=https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/apex, database_actions=https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/sql-developer | Use URL smoke checks and application-specific login validation after clone/PITR or wallet rotation. |
| `INFO` | Network | Private endpoint expectation documented | not configured | Set CRASHSIM_ADB_PRIVATE_ENDPOINT when ADB uses private endpoints. |

## Readiness Summary

| Metric | Value |
| --- | ---: |
| ADB readiness scorecard | 68% |
| Operational check score | 85% |
| OK checks | 6 |
| Warnings | 1 |
| Gaps | 0 |
| Informational checks | 1 |

## Autonomous Scenario Coverage

| ID | Scenario | Status | Validation process | Recovery/runbook focus |
| --- | --- | --- | --- | --- |
| `ADB01` | Drop critical application table | `RUNNABLE AFTER LAB SEED` | Live SQL connection, disposable lab table, flashback eligibility, clone/export fallback. Live SQL probe is healthy; seed disposable ADB lab objects before enabling execution helpers. | Flashback Table, PITR clone, Data Pump/object merge, application validation. |
| `ADB02` | Drop application schema | `PLAN/RUNBOOK` | Live SQL connection, disposable schema, grants/object inventory, export or clone/PITR path. Live SQL probe is healthy; schema-drop automation remains manual until clone/export workflow helpers are added. | Clone/export recovery, user/grant restoration, application validation. |
| `ADB03` | Mass DELETE without WHERE clause | `RUNNABLE AFTER LAB SEED` | Live SQL connection, disposable lab table, before/after row counts, flashback query window. Live SQL probe is healthy; seed disposable ADB lab objects before enabling execution helpers. | Flashback Query/Table, clone comparison, data merge. |
| `ADB04` | Incorrect UPDATE corrupts business data | `RUNNABLE AFTER LAB SEED` | Live SQL connection, disposable lab table, before image evidence, validation query. Live SQL probe is healthy; seed disposable ADB lab objects before enabling execution helpers. | Flashback Versions Query, object restore, data comparison. |
| `ADB05` | Recover from clone | `OCI VALIDATION READY` | OCI metadata for clone permissions, source database, timestamp, compartment, and restore target. Latest ADB readiness evidence includes OCI metadata; clone, PITR, and backup posture can be validated from control-plane data. | Create clone, validate objects/application, merge recovered data. |
| `ADB06` | Point-in-time recovery drill | `OCI VALIDATION READY` | OCI PITR or clone-to-time window, backup retention, timestamp selection, and validation target. Latest ADB readiness evidence includes OCI metadata; clone, PITR, and backup posture can be validated from control-plane data. | Measure RTO/RPO, validate clone, extract/merge recovered data. |
| `ADB07` | Validate backup recoverability | `OCI VALIDATION READY` | OCI backup retention, latest backup, PITR window, restore/clone capability, and evidence freshness. Latest ADB readiness evidence includes OCI metadata; clone, PITR, and backup posture can be validated from control-plane data. | Evidence-only or clone-based restore validation. |
| `ADB08` | Expired or rotated client wallet | `PLAN/RUNBOOK` | Wallet directory, aliases, rotation owner, application distribution points, and reconnect test path. Wallet/client path evidence exists; use the runbook to test rotation and reconnect. | Download new wallet, update clients, reconnect, smoke-test applications. |
| `ADB09` | Private endpoint connectivity loss | `CONFIG NEEDED` | Private endpoint DNS/label, bastion path, routes, NSGs/security lists, and approved fault boundary. Set CRASHSIM_ADB_PRIVATE_ENDPOINT or use the menu context option to document the expected private endpoint path. | Restore network/DNS/security-list path and validate client reconnect. |
| `ADB10` | Connection pool saturation | `PLAN/RUNBOOK` | Live SQL connection, approved workload limits, service-level target, and application retry/backoff boundaries. Live SQL probe is healthy; approved workload limits and application retry boundaries are still required. | Tune pool limits, retries, service class, and application backoff. |
| `ADB11` | Resource Manager or concurrency pressure | `PLAN/RUNBOOK` | Live SQL connection, approved workload generator, resource plan/service class, and measurable threshold. Live SQL probe is healthy; approved workload limits and application retry boundaries are still required. | Review service class, scaling posture, consumer limits, workload scheduling. |
| `ADB12` | Cross-region DR validation | `ADG DISABLED` | OCI Autonomous Data Guard metadata, peer/standby region, lag, failover eligibility, and app reconnect path. OCI metadata reports Autonomous Data Guard is not enabled for this ADB; enable ADG or document that DR is out of scope before ADB12/ADB13. | Failover validation, reconnect, RTO/RPO measurement, fallback plan. |
| `ADB13` | Autonomous Data Guard role transition | `ADG DISABLED` | OCI ADG role, region, lag, switchover/failover eligibility, URL/service validation. OCI metadata reports Autonomous Data Guard is not enabled for this ADB; enable ADG or document that DR is out of scope before ADB12/ADB13. | Switchover/failover and fallback runbook. |
| `ADB14` | IAM administrator access misconfiguration | `PLAN/RUNBOOK` | Read-only IAM policy/group/compartment evidence, break-glass account, and approved test boundary. Latest ADB readiness evidence includes OCI metadata; keep IAM checks read-only unless an approved IAM test boundary exists. | Restore IAM access and validate admin and automation access. |
| `ADB15` | Object Storage export dependency unavailable | `PLAN/RUNBOOK` | Bucket, credential, DBMS_CLOUD object, network path, IAM policy, and export/import procedure evidence. Latest ADB readiness evidence includes OCI metadata; add bucket, credential, DBMS_CLOUD, and network evidence before execution. | Restore bucket/policy/credential/network access; validate export/import. |

## Traditional CrashSimulator Scenarios Not Applicable To ADB

Autonomous Database customers cannot directly remove/corrupt managed OS files, ASM disks, Grid Infrastructure resources, control files, redo logs, password files, SPFILEs, ORACLE_HOME, or RMAN backup pieces. For ADB, those failure classes should be represented as OCI service/readiness checks, clone/PITR validation, Autonomous Data Guard drills, and application access-path tests rather than destructive host actions.

## Recommended Configuration File Keys

Use non-secret keys in `crashsimulator.conf`, and keep passwords in environment variables named by the config keys.

```text
CRASHSIM_ADB_WALLET_DIR=/path/to/wallet
CRASHSIM_ADB_CONNECT_ALIAS=myadb_low
CRASHSIM_ADB_SERVICE_LEVEL=low
CRASHSIM_ADB_USER=ADMIN
CRASHSIM_ADB_PASSWORD_ENV=<redacted>
CRASHSIM_ADB_WALLET_PASSWORD_ENV=<redacted>
CRASHSIM_ADB_PYTHON=/path/to/python
CRASHSIM_ADB_OCID=ocid1.<redacted>
CRASHSIM_ADB_REGION=us-ashburn-1
CRASHSIM_ADB_OCI_PROFILE=DEFAULT
CRASHSIM_ADB_OCI_AUTH=security_token
CRASHSIM_ADB_APEX_URL=https://example.adb.region.oraclecloudapps.com/ords/apex
```

## Raw ADB Evidence

Evidence file: `/private/tmp/crashsim_adb_oci_ready/crashsim_adb_readiness_20260615_154738.evidence`

```text
CSIM_ADB|generated_utc|2026-06-15T05:47:38Z
CSIM_ADB|host|Franciscos-MacBook-Pro.local
CSIM_ADB|os_user|franciscomunozalvarez
CSIM_ADB|python_executable|/private/tmp/crashsim_adb_venv/bin/python
CSIM_ADB|dsn_source|alias
CSIM_ADB|dsn_label|crashautonomous_low
CSIM_ADB|python_status|OK
CSIM_ADB|python_oracledb_version|4.0.1
CSIM_ADB|connect_status|OK
CSIM_ADB|current_user|ADMIN
CSIM_ADB|db_identity|FCEYFTL6|READ WRITE|PRIMARY|YES|ARCHIVELOG|YES|
CSIM_ADB|db_name|FCEYFTL6
CSIM_ADB|open_mode|READ WRITE
CSIM_ADB|database_role|PRIMARY
CSIM_ADB|cdb|YES
CSIM_ADB|log_mode|ARCHIVELOG
CSIM_ADB|flashback_on|YES
CSIM_ADB|protection_mode|UNKNOWN
CSIM_ADB|version|Oracle AI Database 26ai Enterprise Edition Release <ip-redacted>.0 - Production Version <ip-redacted>.0
CSIM_ADB|version_number|<ip-redacted>.0
CSIM_ADB|service_count|6
CSIM_ADB|services|KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_high.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_low.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_medium.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_tp.adb.oraclecloud.com, KEMEJA2K9ZF9HPA_CRASHAUTONOMOUS_tpurgent.adb.oraclecloud.com, kemeja2k9zf9hpa_crashautonomous
CSIM_ADB|apex_registry_count|1
CSIM_ADB|apex_version_status|24.2.17:VALID
CSIM_ADB|invalid_object_count|3
CSIM_ADB|admin_object_count|2
CSIM_ADB|user_table_count|0
CSIM_ADB|recyclebin_count|0
CSIM_ADB|tablespace_count|7
CSIM_ADB|encrypted_tablespace_count|6
CSIM_ADB|segment_size_gb|165.34
CSIM_ADB|flashback_archive_count|1
CSIM_ADB|flashback_archive_retention_days|60
CSIM_ADB|open_application_user_count|2
CSIM_ADB|application_users|ADBSNMP:LOCKED, ADB_APP_STORE:LOCKED, ADMIN:OPEN, DCAT_ADMIN:LOCKED, GGADMIN:LOCKED, RMAN$CATALOG:OPEN
CSIM_ADB|resource_plan|OLTP_PLAN
CSIM_ADB|oci_metadata_status|OK
CSIM_ADB|oci_metadata_file|/private/tmp/crashsim_adb_oci_ready/crashsim_adb_readiness_20260615_154738_oci_adb.json
CSIM_ADB|oci_metadata_parse_status|OK
CSIM_ADB|oci_display_name|crashai
CSIM_ADB|oci_db_name|crashautonomous
CSIM_ADB|oci_lifecycle_state|AVAILABLE
CSIM_ADB|oci_compartment_id|ocid1.<redacted>
CSIM_ADB|oci_time_created|2026-06-08T03:25:39.875000+00:00
CSIM_ADB|oci_backup_retention_days|60
CSIM_ADB|oci_total_backup_storage_gb|6.0
CSIM_ADB|oci_manual_backup_type|NONE
CSIM_ADB|oci_manual_backup_bucket_name|NONE
CSIM_ADB|oci_is_backup_retention_locked|false
CSIM_ADB|oci_is_data_guard_enabled|false
CSIM_ADB|oci_is_local_data_guard_enabled|false
CSIM_ADB|oci_is_remote_data_guard_enabled|false
CSIM_ADB|oci_dataguard_region_type|NONE
CSIM_ADB|oci_standby_db|NONE
CSIM_ADB|oci_peer_db_ids|NONE
CSIM_ADB|oci_private_endpoint|NONE
CSIM_ADB|oci_private_endpoint_label|NONE
CSIM_ADB|oci_private_endpoint_ip|NONE
CSIM_ADB|oci_nsg_ids|NONE
CSIM_ADB|oci_data_safe_status|NOT_REGISTERED
CSIM_ADB|oci_operations_insights_status|NOT_ENABLED
CSIM_ADB|oci_permission_level|UNRESTRICTED
CSIM_ADB|oci_license_model|LICENSE_INCLUDED
CSIM_ADB|oci_compute_model|ECPU
CSIM_ADB|oci_compute_count|1.0
CSIM_ADB|oci_data_storage_size_gb|20
CSIM_ADB|oci_actual_used_data_storage_tb|0.005127668380737305
CSIM_ADB|oci_apex_version|24.2.17
CSIM_ADB|oci_ords_version|<ip-redacted>.1916
CSIM_ADB|oci_supported_clone_regions|KIX, ICN, SIN, BOM, HYD, IAD, PHX, FRA, CWL, ORD, SJC, MEL, AMS, LHR, YUL, YYZ, SYD
```

## OCI Autonomous Database Metadata

Command: oci db autonomous-database get --autonomous-database-id ocid1.<redacted> --profile CRASHSIM_ADB --region ap-tokyo-1 --auth security_token

```text
{
  "data": {
    "actual-used-data-storage-size-in-tbs": 0.005127668380737305,
    "additional-attributes": {},
    "allocated-storage-size-in-tbs": 0.0068359375,
    "apex-details": {
      "apex-version": "24.2.17",
      "ords-version": "<ip-redacted>.1916"
    },
    "are-primary-whitelisted-ips-used": null,
    "auto-refresh-frequency-in-seconds": null,
    "auto-refresh-point-lag-in-seconds": null,
    "autonomous-container-database-id": null,
    "autonomous-database-maintenance-window": null,
    "autonomous-maintenance-schedule-type": "REGULAR",
    "availability-domain": "Bpxv:AP-TOKYO-1-AD-1",
    "available-upgrade-versions": [],
    "backup-config": {
      "manual-backup-bucket-name": null,
      "manual-backup-type": "NONE"
    },
    "backup-retention-period-in-days": 60,
    "byol-compute-count-limit": null,
    "character-set": "AL32UTF8",
    "clone-table-space-list": null,
    "clone-type": null,
    "cluster-placement-group-id": null,
    "compartment-id": "ocid1.<redacted>",
    "compute-count": 1.0,
    "compute-model": "ECPU",
    "connection-strings": {
      "all-connection-strings": {
        "HIGH": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_high.adb.oraclecloud.com",
        "LOW": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_low.adb.oraclecloud.com",
        "MEDIUM": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_medium.adb.oraclecloud.com",
        "TP": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_tp.adb.oraclecloud.com",
        "TPURGENT": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_tpurgent.adb.oraclecloud.com"
      },
      "dedicated": null,
      "high": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_high.adb.oraclecloud.com",
      "low": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_low.adb.oraclecloud.com",
      "medium": "adb.ap-tokyo-1.oraclecloud.com:1522/kemeja2k9zf9hpa_crashautonomous_medium.adb.oraclecloud.com",
      "profiles": [
        {
          "consumer-group": "HIGH",
          "display-name": "crashautonomous_high",
          "host-format": "FQDN",
          "is-regional": null,
          "protocol": "TCPS",
          "session-mode": "DIRECT",
          "syntax-format": "LONG",
          "tls-authentication": "MUTUAL",
          "value": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-tokyo-1.oraclecloud.com))(connect_data=(service_name=kemeja2k9zf9hpa_crashautonomous_high.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
        },
        {
          "consumer-group": "MEDIUM",
          "display-name": "crashautonomous_medium",
          "host-format": "FQDN",
          "is-regional": null,
          "protocol": "TCPS",
          "session-mode": "DIRECT",
          "syntax-format": "LONG",
          "tls-authentication": "MUTUAL",
          "value": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-tokyo-1.oraclecloud.com))(connect_data=(service_name=kemeja2k9zf9hpa_crashautonomous_medium.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
        },
        {
          "consumer-group": "LOW",
          "display-name": "crashautonomous_low",
          "host-format": "FQDN",
          "is-regional": null,
          "protocol": "TCPS",
          "session-mode": "DIRECT",
          "syntax-format": "LONG",
          "tls-authentication": "MUTUAL",
          "value": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-tokyo-1.oraclecloud.com))(connect_data=(service_name=kemeja2k9zf9hpa_crashautonomous_low.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
        },
        {
          "consumer-group": "TP",
          "display-name": "crashautonomous_tp",
          "host-format": "FQDN",
          "is-regional": null,
          "protocol": "TCPS",
          "session-mode": "DIRECT",
          "syntax-format": "LONG",
          "tls-authentication": "MUTUAL",
          "value": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-tokyo-1.oraclecloud.com))(connect_data=(service_name=kemeja2k9zf9hpa_crashautonomous_tp.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
        },
        {
          "consumer-group": "TPURGENT",
          "display-name": "crashautonomous_tpurgent",
          "host-format": "FQDN",
          "is-regional": null,
          "protocol": "TCPS",
          "session-mode": "DIRECT",
          "syntax-format": "LONG",
          "tls-authentication": "MUTUAL",
          "value": "(description= (retry_count=20)(retry_delay=3)(address=(protocol=tcps)(port=1522)(host=adb.ap-tokyo-1.oraclecloud.com))(connect_data=(service_name=kemeja2k9zf9hpa_crashautonomous_tpurgent.adb.oraclecloud.com))(security=(ssl_server_dn_match=yes)))"
        }
      ]
    },
    "connection-urls": {
      "apex-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/apex",
      "database-transforms-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/odi/?sso=true",
      "graph-studio-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/graphstudio/?sso=true",
      "machine-learning-notebook-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/oml/?sso=true",
      "machine-learning-user-management-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/omlusers/",
      "mongo-db-url": null,
      "ords-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/",
      "spatial-studio-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/spatialstudio/",
      "sql-dev-web-url": "https://KEMEJA2K9ZF9HPA-CRASHAUTONOMOUS.adb.ap-tokyo-1.oraclecloudapps.com/ords/sql-developer"
    },
    "cpu-core-count": 0,
    "customer-contacts": [
      {
        "email": "alvarez@clouddb.com.au"
      }
    ],
    "data-safe-status": "NOT_REGISTERED",
    "data-storage-size-in-gbs": 20,
    "data-storage-size-in-tbs": null,
    "database-edition": null,
    "database-management-status": null,
    "dataguard-region-type": null,
    "db-name": "crashautonomous",
    "db-tools-details": [
      {
        "compute-count": null,
        "is-enabled": true,
        "max-idle-time-in-minutes": null,
        "name": "APEX"
      },
      {
        "compute-count": 2.0,
        "is-enabled": true,
        "max-idle-time-in-minutes": 30,
        "name": "DATA_TRANSFORMS"
      },
      {
        "compute-count": null,
        "is-enabled": true,
        "max-idle-time-in-minutes": null,
        "name": "DATABASE_ACTIONS"
      },
      {
        "compute-count": null,
        "is-enabled": false,
        "max-idle-time-in-minutes": null,
        "name": "UNKNOWN_ENUM_VALUE"
      },
      {
        "compute-count": 2.0,
        "is-enabled": true,
        "max-idle-time-in-minutes": 60,
        "name": "GRAPH_STUDIO"
      },
      {
        "compute-count": null,
        "is-enabled": true,
        "max-idle-time-in-minutes": null,
        "name": "MONGODB_API"
      },
      {
        "compute-count": 2.0,
        "is-enabled": true,
        "max-idle-time-in-minutes": 60,
        "name": "OML"
      },
      {
        "compute-count": null,
        "is-enabled": true,
        "max-idle-time-in-minutes": null,
        "name": "ORDS"
      },
      {
        "compute-count": 2.0,
        "is-enabled": true,
        "max-idle-time-in-minutes": 60,
        "name": "SPATIAL_STUDIO"
      }
    ],
    "db-version": "26ai",
    "db-workload": "OLTP",
    "defined-tags": {},
    "disaster-recovery-region-type": null,
    "display-name": "crashai",
    "encryption-key": {
      "provider": "ORACLE_MANAGED"
    },
    "encryption-key-history-entry": [
      {
        "encryption-key": {
          "provider": "ORACLE_MANAGED"
        },
        "time-activated": "2026-06-08T03:27:36.413000+00:00"
      }
    ],
    "encryption-key-location-details": null,
    "failed-data-recovery-in-seconds": null,
    "freeform-tags": {},
    "id": "ocid1.<redacted>",
    "in-memory-area-in-gbs": null,
    "in-memory-percentage": null,
    "infrastructure-type": null,
    "is-access-control-enabled": null,
    "is-auto-scaling-enabled": false,
    "is-auto-scaling-for-storage-enabled": false,
    "is-backup-retention-locked": false,
    "is-data-guard-enabled": false,
    "is-dedicated": false,
    "is-dev-tier": null,
    "is-free-tier": true,
    "is-local-data-guard-enabled": false,
    "is-mtls-connection-required": true,
    "is-preview": false,
    "is-reconnect-clone-enabled": false,
    "is-refreshable-clone": null,
    "is-remote-data-guard-enabled": false,
    "key-history-entry": [
      {
        "id": "ORACLE_MANAGED_KEY",
        "kms-key-version-id": null,
        "time-activated": "2026-06-08T03:27:36.413000+00:00",
        "vault-id": null
      }
    ],
    "key-store-id": null,
    "key-store-wallet-name": null,
    "kms-key-id": "ORACLE_MANAGED_KEY",
    "kms-key-lifecycle-details": null,
    "kms-key-version-id": null,
    "license-model": "LICENSE_INCLUDED",
    "lifecycle-details": null,
    "lifecycle-state": "AVAILABLE",
    "local-adg-auto-failover-max-data-loss-limit": null,
    "local-adg-resource-pool-leader-id": null,
    "local-disaster-recovery-type": null,
    "local-standby-db": null,
    "long-term-backup-schedule": null,
    "maintenance-target-component": "Database",
    "memory-per-compute-unit-in-gbs": null,
    "memory-per-oracle-compute-unit-in-gbs": null,
    "ncharacter-set": "AL16UTF16",
    "net-services-architecture": null,
    "next-long-term-backup-time-stamp": null,
    "nsg-ids": null,
    "ocpu-count": null,
    "open-mode": "READ_WRITE",
    "operations-insights-status": "NOT_ENABLED",
    "peer-db-ids": null,
    "permission-level": "UNRESTRICTED",
    "private-endpoint": null,
    "private-endpoint-ip": null,
    "private-endpoint-label": null,
    "provisionable-cpus": null,
    "public-connection-urls": null,
    "public-endpoint": null,
    "refreshable-mode": null,
    "refreshable-status": null,
    "remote-disaster-recovery-configuration": null,
    "resource-pool-leader-id": null,
    "resource-pool-summary": {
      "available-compute-capacity": null,
      "available-storage-capacity-in-tbs": null,
      "is-disabled": true,
      "pool-size": null,
      "pool-storage-size-in-tbs": null,
      "total-compute-capacity": null
    },
    "role": null,
    "scheduled-operations": null,
    "security-attributes": {},
    "service-console-url": null,
    "source-id": null,
    "standby-db": null,
    "standby-whitelisted-ips": null,
    "subnet-id": null,
    "subscription-id": null,
    "supported-regions-to-clone-to": [
      "KIX",
      "ICN",
      "SIN",
      "BOM",
      "HYD",
      "IAD",
      "PHX",
      "FRA",
      "CWL",
      "ORD",
      "SJC",
      "MEL",
      "AMS",
      "LHR",
      "YUL",
      "YYZ",
      "SYD"
    ],
    "system-tags": {
      "orcl-cloud": {
        "free-tier-retained": "true"
      }
    },
    "time-created": "2026-06-08T03:25:39.875000+00:00",
    "time-data-guard-role-changed": null,
    "time-deletion-of-free-autonomous-database": null,
    "time-disaster-recovery-role-changed": null,
    "time-earliest-available-db-version-upgrade": "2026-06-15T06:20:00+00:00",
    "time-latest-available-db-version-upgrade": "2026-07-15T05:50:00+00:00",
    "time-local-data-guard-enabled": null,
    "time-maintenance-begin": "2026-06-20T03:00:00+00:00",
    "time-maintenance-end": "2026-06-20T05:00:00+00:00",
    "time-maintenance-pause-until": null,
    "time-of-auto-refresh-start": null,
    "time-of-joining-resource-pool": null,
    "time-of-last-failover": null,
    "time-of-last-refresh": null,
    "time-of-last-refresh-point": null,
    "time-of-last-switchover": null,
    "time-of-next-refresh": null,
    "time-reclamation-of-free-autonomous-database": "2026-06-15T15:25:25.102000+00:00",
    "time-scheduled-db-version-upgrade": null,
    "time-undeleted": null,
    "time-until-reconnect-clone-enabled": null,
    "total-backup-storage-size-in-gbs": 6.0,
    "used-data-storage-size-in-gbs": null,
    "used-data-storage-size-in-tbs": null,
    "vanity-connection-urls": null,
    "vanity-url-details": {
      "api-gateway-id": null,
      "is-disabled": true,
      "vanity-url-host-name": null
    },
    "vault-id": null,
    "whitelisted-ips": null
  },
  "etag": "2e487de0--gzip"
}
```
