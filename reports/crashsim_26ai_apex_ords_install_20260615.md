# CrashSimulator 26ai APEX/ORDS Lab Installation Evidence

- Date: 2026-06-15
- Environment: 26ai RAC primary, node1 `crashrac1-mlprn`
- Database: `CRASHDB`
- DB unique name: `crashrac`
- PDB: `CRASHPDB`
- APEX: `26.1.0`
- ORDS: `26.1.2.r1401916`

## Summary

APEX and ORDS were installed and configured for CrashSimulator APEX/ORDS
scenario validation in the 26ai RAC lab. ORDS is managed by `ords.service` on
node1 and serves the `crashpdb` ORDS pool through the local smoke URL:

```text
http://127.0.0.1:8080/ords/crashpdb/
```

The CrashSimulator runtime configuration on node1 now includes non-secret
APEX/ORDS defaults for:

- ORDS service: `ords`
- ORDS config directory:
  `/u01/app/oracle/product/crashsim_apex_ords/ords_config`
- ORDS pool: `crashpdb`
- APEX static files:
  `/u01/app/oracle/product/crashsim_apex_ords/apex_26.1/apex/images`
- Restricted ORDS helper: `/usr/local/bin/crashsim_ords_priv`

## Framework Improvements

- Added APEX/ORDS install/state/download helper scripts under `tools/`.
- Added a Java-stable ORDS wrapper, `tools/crashsim_ords_wrapper.sh`, for lab
  hosts where the default database shell exposes Java 8 before Java 17.
- Expanded the restricted ORDS helper to allow the standard CrashSimulator lab
  ORDS config path as well as `/etc/ords/config`.
- Added missing APEX/ORDS settings to `config/crashsimulator.conf.example`.
- Hardened report command execution with a bounded timeout so ORDS CLI probes
  cannot block APEX/ORDS readiness report generation.

## Scenario Readiness

Validated as runnable after installation/configuration:

- `73` ORDS service unavailable
- `74` ORDS configuration unavailable
- `75` ORDS database pool misconfiguration
- `76` APEX/ORDS runtime account locked
- `77` APEX static resources unavailable
- `78` APEX application availability validation after recovery
- `80` APEX session continuity test, read-only evidence mode
- `81` APEX mail queue and configuration validation
- `82` APEX upgrade or patch rollback readiness

Still gated:

- `79` ORDS node unavailable behind load balancer. The framework now detects
  ORDS correctly, but this scenario still requires `CRASHSIM_ORDS_LB_URL` or a
  reachable peer ORDS node to prove continuity while the local ORDS node is down.

## Backup Baseline

A fresh post-install RMAN baseline backup completed successfully after granting
the recovery catalog owner `EXECUTE` on `SYS.DBMS_LOCK`.

- Backup tag: `CSIM_BASE_260615120414`
- RMAN log:
  `captures/26ai_new_rac_20260615/crashsim_baseline_backup_20260615_120414.log`
- RMAN command file:
  `captures/26ai_new_rac_20260615/crashsim_baseline_backup_20260615_120414.rman`

## Evidence Files

- APEX/ORDS final state:
  `captures/26ai_new_rac_20260615/apex_ords_state_after_config_20260615_120500.txt`
- APEX/ORDS readiness report:
  `captures/26ai_new_rac_20260615/crashsim_apex_ords_report_20260615_115052.md`
- APEX/ORDS readiness report HTML:
  `captures/26ai_new_rac_20260615/crashsim_apex_ords_report_20260615_115052.md.html`
- Scenario validation and dry-run evidence:
  `captures/26ai_new_rac_20260615/apex_ords_scenarios_73_82_validation_20260615_113420.txt`
  `captures/26ai_new_rac_20260615/apex_ords_service_validations_after_wrapper_20260615_120000.txt`
- RMAN catalog privilege fix:
  `captures/26ai_new_rac_20260615/rman_catalog_dbms_lock_grant_verified_20260615_124200.txt`
- Refreshed resilience scorecard:
  `captures/26ai_new_rac_20260615/crashsim_resilience_scorecard_latest.md`
