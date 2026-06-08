# CrashSimulator Reference Examples

This directory contains sanitized reference output generated from live CrashSimulator lab runs. The examples are intended for documentation, demos, reviews, and comparison with customer or lab output.

## Backup Strategy And Recoverability Reports

- `backup_strategy_recoverability_report_target_control_file_example.md`
  - Generated with `./CrashSimulatorV2.sh --backup-report`
  - Shows the default report using the target control file as the RMAN repository source.
  - HTML copy: `backup_strategy_recoverability_report_target_control_file_example.md.html`
- `backup_strategy_recoverability_report_recovery_catalog_example.md`
  - Generated with `CRASHSIM_RMAN_CATALOG='rcat/<password>@//host:1521/service' ./CrashSimulatorV2.sh --backup-report`
  - Shows report behavior when a recovery catalog is supplied and connected.
  - HTML copy: `backup_strategy_recoverability_report_recovery_catalog_example.md.html`
- `backup_strategy_recoverability_report_deep_validate_example.md`
  - Generated with `./CrashSimulatorV2.sh --backup-report --deep-validate`
  - Shows the expanded report including RMAN validation output.
  - HTML copy: `backup_strategy_recoverability_report_deep_validate_example.md.html`

The examples are anonymized: hostnames, DBID, ASM disk group names, temporary paths, PDB GUIDs, and provider-specific backup library paths have been replaced with representative values.

## Scenario Registry And Readiness References

- `scenario_registry_82_reference.md`
  - Generated from `./CrashSimulatorV2.sh --list --audit-retain no`
  - Summarizes the current 82-scenario registry, group counts, newly added
    resilience/DG/RAC/ASM/APEX/ORDS scenarios, and current protection/recovery
    helper coverage.
  - HTML copy: `scenario_registry_82_reference.md.html`
- `scenario_lifecycle_coverage_reference.md`
  - Generated with `./CrashSimulatorV2.sh --scenario-lifecycle-report --html`
  - Shows validation, protection, execution, recovery, and runbook/evidence
    coverage for every registered scenario.
  - HTML copy: `scenario_lifecycle_coverage_reference.md.html`

## APEX / ORDS Scenario 80 Evidence Examples

- `apex_session_driver_example.md`
  - Sanitized local Playwright smoke evidence for the optional scenario `80`
    browser-session driver.
  - Shows the Markdown evidence shape, screenshots, status checks, and how the
    success selector proves a seeded APEX page is still available.
  - HTML copy: `apex_session_driver_example.md.html`
- `apex_session_driver_result_example.json`
  - Sanitized JSON result file produced by
    `tools/crashsim_apex_session_driver.cjs`.
- `../../assets/screenshots/crashsim_apex_session_driver_baseline.png`
  - Baseline browser screenshot from the seeded-session evidence example.
- `../../assets/screenshots/crashsim_apex_session_driver_final.png`
  - Final browser screenshot from the seeded-session evidence example.

## Oracle AI Database 26ai Validation References

The `26ai/` subdirectory contains reference artifacts from a live two-node RAC
Oracle AI Database 26ai lab (`23.26.2.0.0`) using ASM diskgroups `DATA` and
`RECO`, CDB `CRASHDB`, and PDB `CRASHDB_PDB1`.

- `26ai/26ai_scenario_readiness_reference.md`
  - Generated with `./CrashSimulatorV2.sh --scenario-readiness-report --pdb CRASHDB_PDB1 --html`
  - Shows 49 runnable scenarios, 23 plan-only scenarios, and 10 not-runnable
    scenarios for the RAC/ASM/APEX/ORDS/no-Data-Guard topology.
- `26ai/26ai_backup_strategy_recoverability_reference.md`
  - Generated after the post-APEX/ORDS baseline backup tagged
    `C26AIAPEX_260607073734`.
  - Shows Level 0/full backup detection, archived redo backup evidence, and
    RTO/RPO planning estimates from 26ai RMAN metadata.
- `26ai/26ai_config_report_reference.md`
  - Captures the target configuration after redo and control file
    multiplexing.
- `26ai/26ai_maa_readiness_reference.md`
  - Shows the MAA readiness review for the prepared 26ai RAC/ASM lab.
- `26ai/26ai_service_ha_review_reference.md`
  - Shows Oracle service HA, AC/TAC, FSFO, DML redirection, and role-based
    service awareness evidence for the lab.
- `26ai/26ai_scenario_lifecycle_reference.md`
  - Shows lifecycle coverage for the 82-scenario registry from the 26ai run.
- `26ai/26ai_apex_ords_readiness_reference.md`
  - Shows the APEX/ORDS readiness report after installing APEX 26.1.0 and ORDS
    26.1.2 on the 26ai RAC lab.
- `26ai/26ai_apex_availability_s78_reference.md`
  - Shows scenario 78 read-only ORDS/APEX availability smoke evidence.
- `26ai/26ai_apex_session_continuity_s80_reference.md`
  - Shows fresh scenario 80 ORDS/APEX continuity evidence with local and peer
    ORDS URLs in the 26ai RAC lab.
- `../../captures/26ai/26ai_apex_ords_s76_s77_execution.txt`
  - Shows compact execution and recovery evidence for APEX/ORDS scenarios `76`
    and `77`, including the PDB-aware recovery helper validation.
- `../../captures/26ai/26ai_apex_ords_blockers_fixed_s73_s75_s79_s80.txt`
  - Shows compact evidence for the fixed APEX/ORDS blockers: restricted ORDS
    helper validation, scenarios `73`, `74`, `75`, and `79` execution/recovery,
    scenario `80` read-only evidence, and post-drill stabilization.
- `../APEX_SESSION_DRIVER_DESIGN.md`
  - Documents the optional seeded APEX browser-session driver for scenario `80`,
    including the seeded app contract, example command, and evidence artifacts.
- `../../captures/26ai/26ai_apex_session_driver_s80_design_validation.txt`
  - Shows scenario `80` default readiness in the 26ai lab, driver self-check
    guardrail behavior, and local Playwright smoke-test evidence.

## Autonomous Database Readiness References

- `../../reports/crashsim_adb_readonly_discovery_20260608.md`
  - Read-only discovery evidence from the first live Autonomous Database target
    using a bastion-host Python client and wallet.
- `../../reports/crashsim_adb_readiness_20260608.md`
  - Generated with `./CrashSimulatorV2.sh --adb-readiness-report --html`
    from the bastion-host ADB client path.
  - Shows wallet/TNS alias evidence, `python-oracledb` connectivity, APEX
    registry evidence, Flashback Archive retention, ADB scenario coverage, and
    OCI control-plane gaps for clone/PITR/ADG/IAM/Object Storage checks.
  - HTML copy: `../../reports/crashsim_adb_readiness_20260608.md.html`

## HTML Reference Files

The `.html` files were generated from the sanitized Markdown reference reports
with the CrashSimulator HTML artifact renderer:

```bash
./CrashSimulatorV2.sh --render-html docs/reference/backup_strategy_recoverability_report_target_control_file_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/backup_strategy_recoverability_report_recovery_catalog_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/backup_strategy_recoverability_report_deep_validate_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/scenario_registry_82_reference.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/scenario_lifecycle_coverage_reference.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/26ai/26ai_scenario_readiness_reference.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/apex_session_driver_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
```

They are intended for demos and visual review. The original Markdown examples
remain the canonical text form.
