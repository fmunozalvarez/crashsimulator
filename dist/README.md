# CrashSimulator Release Packages

This directory contains installable release archives generated from the
repository.

## v2.0.1 Beta

Package:

- `crashsimulator-v2.0.1-beta-runtime.zip`
- `crashsimulator-v2.0.1-beta-runtime.zip.sha256`

Purpose:

- Install and test CrashSimulator on Oracle database hosts, RAC nodes, bastion
  hosts, or Autonomous Database client hosts.

Included:

- Main executables and helper scripts.
- SQL and RMAN helper files.
- Configuration template.
- Documentation and manuals.
- Reference reports and examples.
- Screenshots and lightweight tutorial metadata.
- Tool scripts required by optional workflows.

Excluded:

- `.git` repository metadata.
- Local `crashsimulator_logs` and scratch output.
- Wallets, keys, keystores, and other secret-like files.
- Local capture scratch HTML.
- Compressed lab-evidence bundles such as `*.tgz`.
- Large tutorial/promotional MP4 files.
- The `dist/` directory itself, so the package does not recursively include
  release archives.

Install:

```bash
unzip crashsimulator-v2.0.1-beta-runtime.zip
cd crashsimulator-v2.0.1-beta
chmod +x crashsimulator CrashSimulatorV2.sh crashsim_run_baseline_backup.sh crashsim_prepare_redundant_gi_lab.sh crashsim_ords_priv_helper.sh tools/crashsim_apex_session_driver.cjs
./CrashSimulatorV2.sh --help
```

See `README.md`, `README_V2.md`, and
`docs/CRASHSIMULATOR_V2_0_1_BETA_PRODUCT_OVERVIEW.md` for full guidance.
