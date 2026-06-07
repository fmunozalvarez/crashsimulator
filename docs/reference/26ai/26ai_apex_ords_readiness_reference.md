# CrashSimulator APEX / ORDS Readiness Report

- Generated UTC: `2026-06-07T09:01:09Z`
- Host: `crashdb26ai1`
- OS user: `oracle`
- Database: `CRASHDB`
- DB unique name: `crashdb_26ai`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB: `YES`
- Target PDB detail: `CRASHDB_PDB1`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_apex_ords_report_20260607_090108.evidence`
- ORDS service name: `ords`
- ORDS config directory: `/etc/ords/config`
- ORDS smoke URL: `http://localhost:8080/ords/`

This report treats APEX/ORDS as an application access-path dependency. A database can be technically recovered while users are still down because ORDS, static files, runtime users, wallet/TLS, or PDB/service mapping are not healthy.

## Host-Side ORDS Summary

| Signal | Value |
| --- | --- |
| ORDS binary | `/usr/local/bin/ords` |
| ORDS version | `Oracle REST Data Services 26.1.2.r1401916` |
| systemd service | `ords` |
| service state | `active` |
| config directory | `present` |
| smoke URL | `OK` |
| load balancer URL | `not supplied` |

## Database-Side APEX / ORDS Summary

| Signal | Value |
| --- | --- |
| CDB APEX registry rows | `1` |
| CDB APEX versions/status | `3:26.1.0:VALID` |
| CDB ORDS registry rows | `0` |
| CDB ORDS versions/status | `NONE` |
| Current container | `CRASHDB_PDB1` |
| Local APEX version/status | `26.1.0:VALID` |
| APEX_PUBLIC_USER | `OPEN` |
| ORDS_PUBLIC_USER | `OPEN` |
| ORDS_METADATA | `OPEN` |
| Invalid APEX objects | `0` |
| Invalid ORDS objects | `0` |
| APEX workspaces | `2` |
| APEX applications | `21` |
| APEX SMTP parameters | `5` |
| APEX wallet parameters | `0` |
| Network ACLs | `1` |

## Readiness Checks

| Status | Area | Check | Evidence | Recommendation |
| --- | --- | --- | --- | --- |
| `OK` | ORDS host | ORDS binary available | ords=/usr/local/bin/ords, version=Oracle REST Data Services 26.1.2.r1401916 | Keep ORDS packaged or pinned consistently across all ORDS/RAC nodes. |
| `OK` | ORDS config | Configuration directory present | config=/etc/ords/config | Back up ORDS config, wallets, pool settings, and static-file mappings. |
| `OK` | ORDS service | Service active | systemctl is-active ords=active | Validate restart, service monitoring, and node-outage behavior. |
| `OK` | ORDS access | Smoke URL reachable | url=http://localhost:8080/ords/ | Use application-specific APEX URLs for deeper smoke checks. |
| `OK` | APEX database | APEX installed in target container | APEX=26.1.0:VALID | Keep APEX patch/upgrade validation aligned with database recovery drills. |
| `OK` | Runtime accounts | APEX/ORDS runtime accounts open | APEX_PUBLIC_USER=OPEN, ORDS_PUBLIC_USER=OPEN | Include runtime-account lock/credential rotation drills in quarterly testing. |
| `OK` | Invalid objects | APEX/ORDS objects valid | APEX=0, ORDS=0 | Re-check after PDB recovery, APEX patching, datapatch, and ORDS upgrades. |

## Recommended APEX / ORDS Scenario Family

| ID | Scenario | Lifecycle posture |
| --- | --- | --- |
| `73` | ORDS service unavailable | Automatable when the OS user can control the ORDS systemd unit. |
| `74` | ORDS configuration unavailable | Automatable only when the config directory is writable or explicitly run with approved OS privileges. |
| `75` | ORDS database pool misconfiguration | Reversible db.servicename mutation when ORDS restart privileges are approved; --recover 75 restores the original value. |
| `76` | APEX/ORDS runtime account locked | Automatable when APEX/ORDS runtime users exist in the target container. |
| `77` | APEX static resources unavailable | Automatable when an APEX images/static directory is configured and writable. |
| `78` | APEX application availability validation after recovery | Read-only smoke evidence after PDB/datafile recovery. |
| `79` | One ORDS node unavailable behind load balancer | Automatable when ORDS service control and a load-balancer URL are supplied. |
| `80` | APEX session continuity test | Read-only continuity evidence, with optional seeded Playwright browser-session driver for screenshots and JSON/Markdown evidence. |
| `81` | APEX mail queue/configuration validation | Read-only APEX SMTP/wallet/ACL evidence. |
| `82` | APEX upgrade/patch rollback readiness | Read-only pre/post evidence and runbook. |

## Raw APEX / ORDS SQL Evidence

Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_apex_ords_report_20260607_090108.evidence`

```text
CSIM_APEX|db_name|CRASHDB
CSIM_APEX|db_unique_name|crashdb_26ai
CSIM_APEX|db_role|PRIMARY
CSIM_APEX|open_mode|READ WRITE
CSIM_APEX|cdb|YES
CSIM_APEX|instance_name|crashdb1
CSIM_APEX|host_name|crashdb26ai1
CSIM_APEX|version|23.0.0.0.0
CSIM_APEX|target_pdb_requested|CRASHDB_PDB1
CSIM_APEX|cdb_registry_apex_count|1
CSIM_APEX|cdb_registry_ords_count|0
CSIM_APEX|cdb_apex_versions|3:26.1.0:VALID
CSIM_APEX|cdb_ords_versions|NONE
CSIM_APEX|apex_public_user_count|1
CSIM_APEX|ords_public_user_count|1
CSIM_APEX|ords_metadata_user_count|1
CSIM_APEX|runtime_locked_expired_count|0
CSIM_APEX|invalid_apex_object_count|0
CSIM_APEX|invalid_ords_object_count|0
CSIM_APEX|network_acl_count|1
CSIM_APEX|current_container|CRASHDB_PDB1
CSIM_APEX|local_apex_registry_count|1
CSIM_APEX|local_apex_version|26.1.0:VALID
CSIM_APEX|local_ords_registry_count|0
CSIM_APEX|local_apex_public_user_status|OPEN
CSIM_APEX|local_ords_public_user_status|OPEN
CSIM_APEX|local_ords_metadata_user_status|OPEN
CSIM_APEX|local_invalid_apex_objects|0
CSIM_APEX|local_invalid_ords_objects|0
CSIM_APEX|apex_workspace_count|2
CSIM_APEX|apex_application_count|21
CSIM_APEX|apex_smtp_parameter_count|5
CSIM_APEX|apex_wallet_parameter_count|0
CSIM_APEX|local_network_acl_count|1
```

## ORDS Version

Command: ords --version

```text
2026-06-07T09:01:11Z INFO   ORDS has not detected the option '--config' and this will be set up to the default directory.

ORDS: Release 26.1 Production on Sun Jun 07 09:01:12 2026

Copyright (c) 2010, 2026, Oracle.

Configuration:
  /etc/ords/config

Oracle REST Data Services 26.1.2.r1401916
```

## ORDS Config List

Command: ords --config /etc/ords/config config list

```text

ORDS: Release 26.1 Production on Sun Jun 07 09:01:14 2026

Copyright (c) 2010, 2026, Oracle.

Configuration:
  /etc/ords/config

Database pool: default

Setting                              Value                                                Source     
----------------------------------   --------------------------------------------------   -----------
database.api.enabled                 true                                                 Global     
db.connectionType                    basic                                                Pool       
db.hostname                          crashdb26ai-scan.sub05260219130.operationsvcn.orac   Pool       
                                     levcn.com                                                       
db.password                          ******                                               Pool Wallet
db.port                              1521                                                 Pool       
db.servicename                       crashdb_CRASHDB_PDB1.paas.oracle.com                 Pool       
db.username                          ORDS_PUBLIC_USER                                     Pool       
feature.sdw                          true                                                 Pool       
plsql.gateway.mode                   proxied                                              Pool       
restEnabledSql.active                true                                                 Pool       
security.requestValidationFunction   ords_util.authorize_plsql_gateway                    Pool       

```

## ORDS Service Status

Command: systemctl status ords

```text
● ords.service - Oracle REST Data Services
   Loaded: loaded (/etc/systemd/system/ords.service; enabled; vendor preset: disabled)
   Active: active (running) since Sun 2026-06-07 08:15:24 UTC; 45min ago
  Process: 81244 ExecStop=/usr/bin/bash -c /etc/init.d/ords stop (code=exited, status=0/SUCCESS)
  Process: 83755 ExecStart=/usr/bin/bash -c /etc/init.d/ords start (code=exited, status=0/SUCCESS)
 Main PID: 83890 (java)
    Tasks: 0 (limit: 79998)
   Memory: 24.0K
   CGroup: /system.slice/ords.service
           ‣ 83890 java -Doracle.dbtools.cmdline.home=/opt/oracle/ords -Duser.language=en -Duser.region=US -Dfile.encoding=UTF-8 -Djava.awt.headless=true -Doracle.dbtools.cmdline.ShellCommand=ords -Duser.timezone=UTC -XX:+IgnoreUnrecognizedVMOptions -jar /opt/oracle/ords/ords.war --config /etc/ords/config serve --apex-images /opt/oracle/apex/images
```

## ORDS Smoke URL

Command: curl -sS -L -o /dev/null -D - --max-time 10 http://localhost:8080/ords/

```text
HTTP/1.1 302 Found
Location: http://localhost:8080/ords/_/landing
Transfer-Encoding: chunked

HTTP/1.1 200 OK
Content-Type: text/html
X-Frame-Options: SAMEORIGIN
Transfer-Encoding: chunked

```
