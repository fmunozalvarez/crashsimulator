# lib/ - CrashSimulatorV2.sh source modules

`CrashSimulatorV2.sh` is a GENERATED single-file artifact assembled from the
modules in this directory so that deployment to a target stays a one-file copy
while development happens in reviewable, domain-scoped files.

- Develop here, then run `./build.sh` to regenerate `CrashSimulatorV2.sh`.
- `./build.sh --check` verifies the committed monolith matches these sources
  byte-for-byte (used by CI / pre-commit); it fails on drift.
- Modules are CONTIGUOUS slices of the script at clean function boundaries -
  assembly is a plain concatenation in the `PART_ORDER` defined in `build.sh`,
  so the generated output is byte-identical to the concatenated sources.
- Never edit `CrashSimulatorV2.sh` directly; the next build would overwrite it.

| Module | Contents |
|---|---|
| 00_header.sh | Shebang, globals, script-path detection, mode defaults |
| 10_core.sh | usage/die/logging and shared shell helpers |
| 12_config.sh | Startup config discovery + config file application |
| 14_audit.sh | Audit capture, purge, manifest helpers |
| 16_topology.sh | Environment/topology discovery, doctor, first-run guide |
| 20_registry.sh | Scenario registration tables |
| 25_adb.sh | ADB scenario support + catalog printing |
| 30_planning.sh | PDB helpers, scenario capability/validation planning, readiness report |
| 40_recovery.sh | recover_* scenario recovery handlers |
| 45_prepare.sh | Project tools, secret scan, prepare_* environment evaluation |
| 50_artifacts.sh | HTML rendering / artifact helpers |
| 55_adb_reports.sh | ADB scorecard and report helpers |
| 60_apex_ords.sh | APEX/ORDS availability checks and helpers |
| 65_maa.sh | MAA readiness report inputs, scoring and hints |
| 70_reports.sh | Report assembly, backup report, recovery runbook |
| 75_scenarios.sh | perform_*/scenario_* failure-scenario handlers |
| 90_argparse.sh | parse_args |
| 80_menu.sh | Interactive menu (assembled after argparse - order preserved from the original file) |
| 99_main.sh | main() entrypoint |
