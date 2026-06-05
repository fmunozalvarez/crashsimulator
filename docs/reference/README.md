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

## HTML Reference Files

The `.html` files were generated from the sanitized Markdown reference reports
with the CrashSimulator HTML artifact renderer:

```bash
./CrashSimulatorV2.sh --render-html docs/reference/backup_strategy_recoverability_report_target_control_file_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/backup_strategy_recoverability_report_recovery_catalog_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
./CrashSimulatorV2.sh --render-html docs/reference/backup_strategy_recoverability_report_deep_validate_example.md --audit-retain no --log-dir /tmp/crashsim_html_reference
```

They are intended for demos and visual review. The original Markdown examples
remain the canonical text form.
