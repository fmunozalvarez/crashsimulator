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
- Ran a fresh RMAN baseline backup with tag `C26AI_260607031353`.
- Installed and validated APEX 26.1.0 in PDB `CRASHDB_PDB1`.
- Installed ORDS 26.1.2 on both RAC nodes, configured the default pool against
  the RAC SCAN/PDB service, and configured APEX static image serving.

## Validation Results

- Scenario readiness: `44` runnable, `27` plan-only, `11` not runnable.
- All `44` runnable scenarios completed readiness validation successfully.
- APEX/ORDS readiness checks passed for APEX registry status, runtime accounts,
  invalid object count, ORDS service posture, ORDS pool validation, and local
  smoke URL.
- APEX/ORDS read-only scenarios `78`, `81`, and `82` executed successfully.
  Scenarios `76` and `77` are runnable pending approved destructive execution;
  `73`, `74`, `75`, and `80` are plan-only in the current OS/application
  posture; `79` requires an ORDS load-balancer URL.
- MAA readiness: Silver posture, baseline checks passed.
- Backup report: Level 0/full backup strategy with archived redo backups.
- Post-validation health: CDB/PDB open read write, no recover-file rows, no
  database block corruption rows.

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

## Notes

CrashSimulator is designed for Oracle Database 12c and later. The project now
has validation evidence from live Oracle Database 19c and Oracle AI Database
26ai labs, including RAC/ASM and APEX/ORDS application access-path coverage.
This is CrashSimulator project validation evidence, not an official Oracle
product certification.
