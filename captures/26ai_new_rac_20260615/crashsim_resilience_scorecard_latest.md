# CrashSimulator Resilience Scorecard

- Generated UTC: `2026-06-15T12:11:06Z`
- Host: `crashrac1-mlprn`
- Database: `CRASHDB`
- DB unique name: `crashrac`
- Role/open mode: `PRIMARY` / `READ WRITE`
- Cluster/storage: `RAC` / `FEX_ACFS`
- Target MAA level: `Unknown`
- Candidate MAA level: `Silver`
- Current evidenced MAA level: `Bronze`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_resilience_scorecard_20260615_120414.evidence`

This scorecard is an evidence-weighted management view. Scores are planning indicators, not Oracle certification or SLA guarantees. Re-run after topology changes, backups, recovery drills, switchover/failover tests, and scenario validations.

## Domain Scores

| Domain | Score | Weight | Evidence | Recommendation |
| --- | ---: | ---: | --- | --- |
| Backup | `70/100 (Good)` | `15%` | ARCHIVELOG=ARCHIVELOG, jobs_7d=3, failed_7d=1, missing_datafiles=0, recovery_manifest=no | Keep backup cadence aligned to RPO and prove restore time with timed recovery drills. |
| RAC / Local HA | `60/100 (Developing)` | `12%` | candidate=1, score=3/5, services=2, FAN=2, local_drill=no | Use services, FAN/ONS, drain, AC/TAC where applicable, and measure local failure drills. |
| Security | `100/100 (Excellent)` | `10%` | force_logging=YES, tde_config=keystore_configuration=FILE, encrypted_tbs=8, wallet_open=3, wallet_not_open=0 | Validate TDE/wallet backup posture and add DBSAT/Data Safe evidence for a fuller security score. |
| DR / Data Guard | `0/100 (Critical Gaps)` | `15%` | dg_detected=0, valid_standby_dests=0, FSFO=DISABLED, observer=UNKNOWN, score=0/5 | Validate Broker, lag, role-based services, FSFO observer placement, switchover/failover, and application reconnect behavior. |
| Recoverability | `75/100 (Good)` | `15%` | recover_files=0, corruption_rows=0, flashback=YES, recovery_manifest=no, rto_rpo_drills=no | Use scenarios 64/65 and timed recoveries to prove actual RTO/RPO, not only configuration readiness. |
| MAA Alignment | `35/100 (Critical Gaps)` | `15%` | target=Unknown, candidate=Silver, evidenced=Bronze, gap=Target MAA level is unknown because business context is incomplete. | Close the largest target-versus-evidence gaps first; avoid claiming candidate tiers without measured evidence. |
| Scenario Coverage | `45/100 (At Risk)` | `10%` | registered=103, automated=56, read_only=8, plan_only=9, placeholders=0 | Run scenario readiness/lifecycle reports and prioritize missing automation for high-value HA/DR drills. |
| Application Continuity | `60/100 (Developing)` | `8%` | score=3/5, AC=1, TAC=1, role_services=3, APEX/session_drill=no | Validate client pools, FAN/ONS, AC/TAC replay safety, role-based services, and APEX/ORDS session behavior where applicable. |

## Overall Score

| Metric | Value |
| --- | --- |
| Resilience Score | `53/100 (At Risk)` |
| Total weight | `100` |
| MAA fit-gap | Target MAA level is unknown because business context is incomplete. |

## How The Score Updates

- New backups, RMAN validation, and recovery manifests improve Backup and Recoverability evidence.
- RAC/service relocation, VIP/service placement, and APEX session manifests improve Local HA and Application Continuity evidence.
- Data Guard apply/transport, FSFO, SRL, switchover/failover, and standby drill manifests improve DR evidence.
- Updated MAA context can raise or lower the target tier; measured evidence determines the evidenced tier.

## Recommended Next Actions

- DR score is low: validate or configure Data Guard/ADG, Broker, SRLs, lag monitoring, role-based services, and FSFO where required.
- Scenario coverage can improve: run `--scenario-lifecycle-report` and prioritize lifecycle helpers for high-risk HA/DR scenarios.
- Save this report as audit evidence before and after major resilience improvements.

## Raw Evidence References

- MAA SQL evidence: `/tmp/crashsimulator/crashsimulator_logs/crashsim_resilience_scorecard_20260615_120414.evidence`
- srvctl service evidence: `/tmp/crashsimulator/crashsimulator_logs/crashsim_resilience_scorecard_20260615_120414_srvctl_services.out`
- DGMGRL/FSFO evidence: `/tmp/crashsimulator/crashsimulator_logs/crashsim_resilience_scorecard_20260615_120414_dgmgrl_fsfo.out`
