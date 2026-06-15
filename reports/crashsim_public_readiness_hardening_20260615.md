# CrashSimulator Public Readiness Hardening

- Date: 2026-06-15
- Scope: Public beta safety, release checks, scenario lifecycle enforcement, and first-run usability
- Validation command: `./CrashSimulatorV2.sh --release-check`
- Validation evidence: clean reports are written as `reports/crashsim_release_check_*.md`

## Implemented Improvements

| Area | Improvement |
| --- | --- |
| Preflight | Added `--doctor` / `--preflight` to check local tooling, config posture, logging, Oracle client tools, GI/Data Guard/APEX/ORDS/OCI helpers, Node/Playwright readiness, and multi-node sync inputs. |
| First-run UX | Added `--first-run` to generate a read-only first-run guide and safe starter command sequence. |
| Safety gate | Added `CRASHSIM_ACCEPT_DESTRUCTIVE_LAB=YES` / `--accept-destructive-lab` acknowledgement for non-interactive destructive `--execute --yes` flows. Interactive runs now also require a lab approval token after the scenario/protect/recover confirmation token. |
| Topology efficiency | Added guided-menu topology cache support with `CRASHSIM_TOPOLOGY_CACHE_TTL_SECONDS`, `--refresh-topology`, and `--no-topology-cache`. |
| Lifecycle enforcement | Added `--scenario-lifecycle-check` to fail public checks when registered scenarios are missing metadata, handlers, or lifecycle capability text. |
| Secret hygiene | Added `--secret-scan` and `tools/crashsim_secret_scan.sh` for fast release-scope scanning of keys, wallets, and obvious inline secrets. |
| Public artifacts | Added `--sanitize-artifacts` and `tools/crashsim_sanitize_artifacts.sh` to create redacted public copies of text evidence. |
| Multi-node consistency | Added `--node-sync-check` and `tools/crashsim_node_sync_check.sh` for RAC/ORDS helper-version drift checks when `CRASHSIM_REMOTE_NODES` is configured. |
| Release packaging | Added `tools/crashsim_build_runtime_zip.sh` to rebuild the curated runtime ZIP and checksum from the current tree while excluding local logs, wallets/keys, compressed evidence bundles, and large tutorial media. |
| Release validation | Added `--release-check` and `tools/crashsim_release_check.sh` to combine syntax, whitespace, lifecycle, secret scan, required ZIP contents, ZIP freshness, checksum, and certification-wording checks. |
| Guided Workflow | Added `22. Public readiness and safety checks` submenu. |

## Validation Results

| Check | Result |
| --- | --- |
| `bash -n CrashSimulatorV2.sh` and helper scripts | PASS |
| `git diff --check` | PASS |
| `--scenario-lifecycle-check` | PASS, 0 failures, 0 warnings |
| `--secret-scan --scan-path .` | PASS, 0 high findings, 0 warnings |
| `--release-check` | PASS, 0 failures, 0 warnings |
| Runtime ZIP rebuild | PASS, regenerated `dist/crashsimulator-v2.0.1-beta-runtime.zip` and `.sha256` |
| Runtime ZIP required contents/freshness | PASS |
| ADB report artifact sanitization | PASS, live OCIDs redacted from public report examples |
| Guided Workflow option 22 smoke test | PASS |
| Blocked `--scenario 28 --execute --yes` exit code | PASS, exits with status 1 when lab acknowledgement/readiness is absent |

## Public Guidance

Use project-validation language rather than formal certification language unless
a separate certification process exists. Treat installed/configured components
as candidates until timed drills, client failover behavior, backup/restore
validation, or role-transition evidence proves the claim.
