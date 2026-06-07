# CrashSimulator 26ai RAC/ASM Validation Summary

- Validation date: 2026-06-07 UTC
- Target: Oracle AI Database 26ai EE Extreme Perf Release `23.26.2.0.0`
- Database: `CRASHDB`, DB unique name `crashdb_26ai`
- Topology: two-node RAC, CDB, PDB `CRASHDB_PDB1`, ASM storage
- ASM diskgroups: `DATA`, `RECO`
- Standby/Data Guard: not configured in this lab

## Preparation Completed

- Deployed CrashSimulator to `/tmp/crashsimulator` on both RAC nodes.
- Seeded root and PDB lab objects with `seed_crashsim_lab.sql`.
- Added a reusable seed/verify improvement so the scripts select `CRASHPDB`
  when present, otherwise the first read-write user PDB.
- Multiplexed online redo logs across `+RECO` and `+DATA`.
- Multiplexed control files across `+RECO` and `+DATA`.
- Ran a fresh RMAN baseline backup with tag `C26AI_260607031353`, then refreshed
  the baseline after APEX/ORDS installation with tag `C26AIAPEX_260607073734`.
- Installed and validated APEX 26.1.0 in PDB `CRASHDB_PDB1`.
- Installed ORDS 26.1.2 on both RAC nodes, configured the default pool against
  the RAC SCAN/PDB service, and configured APEX static image serving.
- Installed the restricted ORDS helper `/usr/local/bin/crashsim_ords_priv` on
  both RAC nodes with a narrow sudoers grant for ORDS service control and
  reversible `/etc/ords/config` rename/restore.
- Added a lab peer-continuity URL at `http://localhost:18080/ords/` on each
  node for scenario `79` continuity practice when a production load-balancer URL
  is not available.

## Validation Results

- Scenario readiness: `49` runnable, `23` plan-only, `10` not runnable.
- All `49` runnable scenarios completed readiness validation successfully.
- APEX/ORDS readiness checks passed for APEX registry status, runtime accounts,
  invalid object count, ORDS service posture, ORDS pool validation, and local
  smoke URL.
- APEX/ORDS scenarios `73`, `74`, `75`, `76`, `77`, and `79` executed and
  recovered successfully.
  - `73` restarted ORDS through the restricted helper.
  - `74` restored `/etc/ords/config` through the restricted helper.
  - `75` restored the original ORDS `db.servicename` and restarted ORDS.
  - `79` stopped local ORDS, validated peer continuity through the lab URL, and
    recovered the local ORDS service.
  Scenario `76` validated PDB-aware runtime-account recovery after patching the
  helper to read `apex_runtime_target_container` from the manifest. Scenario
  `77` restored the APEX static-resource directory with no `.crashsim.bak`
  leftovers. Read-only scenarios `78`, `80`, `81`, and `82` executed
  successfully.
- MAA readiness: Silver posture, baseline checks passed.
- Backup report: Level 0/full backup strategy with archived redo backups.
- Post-validation health: CDB/PDB open read write, no recover-file rows, no
  database block corruption rows.
- Scenario `79` should still be repeated with a real load-balancer URL when
  available; the current evidence validates peer continuity, not production
  load-balancer routing or health-check policy.
- Scenario `80` now has an optional seeded APEX browser-session driver for
  end-user continuity evidence. It was smoke-tested locally with Playwright and
  should be run against a disposable APEX test application when the lab URL,
  test user, and success selector are available.

## Evidence

- Topology and dry-run logs: `captures/26ai/`
- Reference reports and HTML copies: `docs/reference/26ai/`
- Key report examples:
  - `docs/reference/26ai/26ai_scenario_readiness_reference.md`
  - `docs/reference/26ai/26ai_backup_strategy_recoverability_reference.md`
  - `docs/reference/26ai/26ai_config_report_reference.md`
  - `docs/reference/26ai/26ai_maa_readiness_reference.md`
  - `docs/reference/26ai/26ai_service_ha_review_reference.md`
  - `docs/reference/26ai/26ai_apex_ords_readiness_reference.md`
  - `docs/reference/26ai/26ai_apex_availability_s78_reference.md`
  - `captures/26ai/26ai_apex_ords_s76_s77_execution.txt`
  - `captures/26ai/26ai_apex_ords_blockers_fixed_s73_s75_s79_s80.txt`

## Notes

CrashSimulator is designed for Oracle Database 12c and later. The project now
has validation evidence from live Oracle Database 19c and Oracle AI Database
26ai labs, including RAC/ASM and APEX/ORDS application access-path coverage.
This is CrashSimulator project validation evidence, not an official Oracle
product certification.
