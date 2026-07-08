# CrashSimulator Release Packages

This directory contains installable release archives generated from the
repository.

## v2.0.3 RC

Package:

- `crashsimulator-v2.0.3-rc-runtime.zip`
- `crashsimulator-v2.0.3-rc-runtime.zip.sha256`

Purpose:

- Install and test CrashSimulator on Oracle database hosts, RAC nodes, bastion
  hosts, or Autonomous Database client hosts.

Included:

- Main executables and helper scripts (the single-file, generated
  `CrashSimulatorV2.sh`).
- SQL and RMAN helper files.
- Configuration template.
- Documentation and manuals.
- Reference reports and examples.
- Screenshots and lightweight tutorial metadata.
- Tool scripts required by optional workflows.

Excluded:

- `.git` repository metadata.
- The `lib/*.sh` development sources and `build.sh` (the runtime package ships
  the assembled `CrashSimulatorV2.sh`; build from a source checkout to modify).
- Local `crashsimulator_logs` and scratch output.
- Wallets, keys, keystores, and other secret-like files.
- Local capture scratch HTML.
- Compressed lab-evidence bundles such as `*.tgz`.
- Large tutorial/promotional MP4 files.
- The `dist/` directory itself, so the package does not recursively include
  release archives.

Rebuild from the source checkout:

```bash
CRASHSIM_RELEASE_VERSION=2.0.3-rc tools/crashsim_build_runtime_zip.sh
./CrashSimulatorV2.sh --release-check
```

Install:

```bash
unzip crashsimulator-v2.0.3-rc-runtime.zip
cd crashsimulator-v2.0.3-rc
chmod +x crashsimulator CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
./CrashSimulatorV2.sh --help
```

See `README.md`, `README_V2.md`, and `docs/RELEASE_NOTES_V2_0_3_RC.md` for full
guidance. The prior `crashsimulator-v2.0.2-beta-runtime.zip` package remains
available from the v2.0.2 Beta release.
