# CrashSimulator v2.0.3 RC2 Release Notes

Release: `v2.0.3-rc2`

## Summary

CrashSimulator `v2.0.3 RC2` is a field-test fix release for the `v2.0.3 RC`
release candidate. It contains no new features: every change below was found
by installing and running `v2.0.3-rc1` on a fresh single-instance 23ai
filesystem lab (NOARCHIVELOG, no Grid Infrastructure) and fixing what broke.
The capability set, scenario catalog, and safety model are unchanged.

This release is intended for controlled lab, development, training, and
resilience-test environments. Do not use destructive scenarios in production.

> **Artifact refreshed 2026-07-17.** The `v2.0.3-rc2` runtime ZIP was rebuilt
> to include the 23ai recover-validation fix below (the last bullet under
> Fixes). If you downloaded an earlier `v2.0.3-rc2` ZIP, re-download it.

## Fixes

- **Config validation no longer echoes a mistyped secret.**
  `CRASHSIM_ADB_PASSWORD_ENV` / `CRASHSIM_ADB_WALLET_PASSWORD_ENV` take the
  NAME of an environment variable; pasting a literal password there used to
  print that value back in the error message on every command. The message now
  hides the value and explains the name-plus-export pattern, and
  `config/crashsimulator.conf.example` documents it inline.
- **Safety-gate prompts can no longer be invisible.** Under audit stream
  capture the confirmation prompts (`Type PREPARE-ENVIRONMENT ...`,
  `Type EXECUTE-<id> ...`, `Type PURGE-AUDIT-LOGS ...`) could sit in the
  redaction pipe while `read` already blocked — the operator answered a gate
  they could not see and the run aborted with "Confirmation did not match".
  Prompts are now mirrored to the controlling terminal and the reply is read
  from `/dev/tty` when stdio is redirected; the audit redaction stream is
  line-buffered (`sed -u`); and Guided Workflow menu children now default to
  stream capture OFF (generated artifacts are still collected — set
  `CRASHSIM_AUDIT_STREAM_CAPTURE=1` to force capture).
- **Grid Infrastructure is no longer misdetected on plain single-instance
  hosts.** A runnable `srvctl` (which ships inside every database home) and
  srvctl failure text printed to stdout were both treated as GI evidence, so
  plain labs classified as `GI_SINGLE` and the seed planner attempted srvctl
  service creation that can never work there. Detection now requires real
  evidence: OLR registration (`olr.loc`) or a live HAS stack, and srvctl
  output only counts when srvctl actually succeeded.
- **`prepare` redo-multiplex seed works on filesystem + NOARCHIVELOG labs.**
  The seed now derives a proper member file name per group (previously
  ORA-00301/ORA-27038 adding the destination directory itself as a member)
  and skips the archive-log steps cleanly in NOARCHIVELOG mode.
- **HA lab catalog/services helper is portable.** PDB, service, listener
  endpoint, and tablespace resolution no longer assume the lab hostnames and
  layout of the original development VMs; the helper resolves them from the
  live database and listener.
- **Baseline backup refuses NOARCHIVELOG open-database runs with a clear
  explanation.** An open-database baseline is impossible in NOARCHIVELOG
  (ORA-19602) and used to die opaquely at `RMAN> 2>` with status 1. The
  helper now detects `v$database.log_mode` up front, prints why plus the
  exact enable-ARCHIVELOG steps, and refuses `--execute` (the dry-run still
  shows the plan).
- **Scenario recovery no longer fails its validation step on Oracle Database
  23ai.** Each recover ran a post-recovery RMAN check that ended with
  `list failure;` (Data Recovery Advisor). `LIST FAILURE` is desupported in
  23ai, so RMAN raised a parse error (`RMAN-01009`) that — because RMAN parses
  the whole command file before executing — aborted the entire step. The
  restore itself had already succeeded (the database was open READ WRITE), but
  the run reported `Command exited with status 1`. The desupported command was
  removed from all validation command files; the `validate`/`crosscheck`
  commands that precede it already set the exit status and report any
  corruption on 19c, 21c, and 23ai.

## Documentation

- User guide: new **Seed / Prepare Scenario Lab planner** walkthrough,
  **Troubleshooting FAQ** covering all of the above as encountered on
  `rc1`, and the ASM datafile drill documentation.
- Public limitations and v2.0.2 product overview refreshed.

## Upgrade

Replace `CrashSimulatorV2.sh`, `crashsim_run_baseline_backup.sh`,
`prepare_crashsim_fex_redo_multiplex.sql`,
`tools/crashsim_configure_ha_lab.sh`, and
`config/crashsimulator.conf.example` (or unpack the full runtime ZIP).
No configuration migration is required; existing `crashsimulator.conf`
files keep working — just never put a literal password in the `*_ENV`
fields.
