# CrashSimulator v2.0.3 RC Release Notes

Release: `v2.0.3-rc`

## Summary

CrashSimulator `v2.0.3 RC` is a release-candidate update to the V2 framework. It
keeps the full `v2.0.2 beta` capability set — topology discovery, guarded
scenario execution, recovery runbook hints, evidence collection, reporting,
Guided Workflow menu, APEX/ORDS awareness, Autonomous Database readiness
coverage, and the 123-entry scenario catalog — and adds a maintainability,
robustness, and quality-engineering pass focused on the standalone tool.

This release is intended for controlled lab, development, training, and
resilience-test environments. Do not use destructive scenarios in production.

## Highlights

- Current product version reports as `2.0.3-rc`.
- **Modular source, single-file deployment.** `CrashSimulatorV2.sh` is now a
  generated artifact assembled from 19 domain-scoped `lib/*.sh` modules by
  `build.sh`. Deployment stays a one-file copy; development moves to reviewable
  sources. `build.sh --check` verifies the committed monolith matches the
  sources byte-for-byte and fails on drift.
- **MAA readiness report degrades gracefully** when SQL*Plus is not available:
  it writes a blocked-stub report (every database-derived section reported as a
  blocker with an explicit unblock action) instead of aborting.
- **MAA Gold tier threshold corrected.** A low-minute (<= 15m) DR RTO now maps
  to Gold, so the readiness report no longer understates the required
  architecture for Data Guard-class targets.
- **Hardened disposable lab seed.** `seed_crashsim_lab.sql` no longer embeds a
  hardcoded lab-user credential. The value is now taken from a substitution
  variable (with a fail-fast guard), and `tools/crashsim_seed_lab.sh` supplies it
  via a hidden prompt or the `CRASHSIM_LAB_PASSWORD` environment variable on
  stdin (never argv or a temp file). The `--execute` preparation path generates
  a strong, never-recorded value. The seed also now works with or without
  Oracle-Managed Files: it falls back to an explicit, per-container datafile path
  when `db_create_file_dest` is not set.
- **`crashsimulator.conf` is also discovered next to the script**, in addition
  to the working directory, `~/.crashsimulator/`, and `/etc/crashsimulator/`.
- **Correctness fix:** `duration_to_seconds` mis-parsed multi-digit durations
  (for example "30 min" evaluated to 0); it now captures the full leading
  number, so RTO/RPO seconds in MAA and scenario planning are accurate.
- **Quality engineering:** a hermetic CI workflow runs on every push and pull
  request — shell syntax, `build.sh --check` drift, ShellCheck, a
  secret-and-evidence gate, and a `bats` unit suite over the pure `lib/*.sh`
  helpers — with no Oracle dependency.

## Scenario catalog

- `123` total scenario catalog entries (unchanged from `v2.0.2 beta`):
  - `103` database-host, infrastructure, application access-path, platform, and
    compliance scenarios.
  - `20` Autonomous Database cloud-service scenarios, `ADB01` through `ADB20`.

## Validation

- Verified on Oracle Database 23ai (single-instance CDB) on a Lima VM:
  `build.sh --check`, `--discover`, `--health-check`, `--maa-report`, and
  `--scenario-readiness-report`. The lab seed was validated end-to-end with OMF
  off (explicit per-container datafile paths) and on (Oracle-Managed Files), and
  the hardened password path was confirmed by authenticating as a seeded lab
  user.

## Install

Download `crashsimulator-v2.0.3-rc-runtime.zip` from the release, copy it to the
target Oracle host, and unzip it:

```bash
unzip crashsimulator-v2.0.3-rc-runtime.zip
cd crashsimulator-v2.0.3-rc
chmod +x crashsimulator CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
./CrashSimulatorV2.sh --help
```

See `README.md` and `README_V2.md` for full guidance and the
`docs/CRASHSIMULATOR_USER_GUIDE.md` end-user guide.

## Safety

CrashSimulator project validation is not an official Oracle product
certification. Run destructive scenarios only in approved non-production or
dedicated resilience-test environments; `--dry-run` is the default and
destructive scenarios require `--execute` with an interactive confirmation
token.
