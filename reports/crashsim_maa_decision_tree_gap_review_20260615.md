# CrashSimulator MAA Decision-Tree Gap Review

- Review date: 2026-06-15
- Scope: CrashSimulator `main` working tree, with emphasis on `CrashSimulatorV2.sh`, MAA readiness reporting, scenario `64`/`65`, user guide content, and reference reports.
- Baseline documents reviewed:
  - `Maa-decision-tree-rto-rpo-planned-unplanned.pdf`
  - `Oracle_Database_Engine_Environment_Assessment_Framework.pdf`
  - `Oracle_Database_Engine_12c_to_26ai_Best_Practices_Report.pdf`
- External public reference checked: Oracle Database 26ai MAA reference architecture overview and Oracle Database HA requirements/RTO/RPO guidance.
- Implementation status: Addressed in the same change set by adding target/candidate/evidenced MAA tiering, evidence maturity scoring, local-standby-aware Silver candidate logic, and expanded MAA context inputs.

## Executive Summary

CrashSimulator has strong building blocks for MAA validation: topology discovery, RAC/Data Guard/FSFO/service evidence, AC/TAC awareness, backup/recovery reporting, RTO/RPO drills, scenario readiness, lifecycle coverage, and evidence capture.

At review time, the main gap was that the MAA readiness report still reported a single `Detected MAA posture` based mostly on installed/configured topology. The supplied MAA validation documents require a stricter distinction between:

- business-required target MAA level from RTO/RPO and outage class;
- architecture or product-set candidate level;
- current evidenced MAA level, capped by integration, test, and operational evidence;
- fit-gap between target and evidenced levels.

The implementation now moves the report toward that model by reporting target, candidate, and current evidenced MAA levels separately.

## Key Findings

| Severity | Area | Finding | Current evidence | Required correction |
| --- | --- | --- | --- | --- |
| High | MAA level detection | The report promotes RAC/cluster evidence directly to `Silver` and Data Guard evidence directly to `Gold`. This overstates the evidenced MAA level when service/client failover, measured drills, and operational runbooks are absent. | `CrashSimulatorV2.sh` sets `has_silver` from RAC/cluster flags and `has_gold` from standby role or remote standby destination. | Split output into `Target MAA level`, `Candidate MAA level`, and `Evidenced MAA level`. Cap evidenced level based on measured evidence. |
| High | Silver model | The late-2025 decision tree says Silver can be RAC or local Data Guard standby for strong local HA. Current code describes Silver as RAC/RAC One Node only and treats any Data Guard evidence as Gold. | MAA reference model text says Silver is RAC/RAC One Node; Gold is Data Guard/ADG. | Add local-standby-aware Silver candidate logic. Distinguish local HA standby from remote/site DR standby using explicit context or site metadata. |
| High | Gold validation | Gold is inferred from Data Guard existence, but the assessment framework requires Broker, lag, FSFO/observer where applicable, role transition evidence, RPO evidence, and application behavior validation before claiming tested DR. | Report captures many of these fields but does not cap the MAA level when they are missing. | Treat DG-only as `Gold candidate`; require transition drill evidence and application validation for `Gold evidenced`. |
| Medium | Target tier from RTO/RPO | `maa_sla_hint` uses simple keyword matching. It does not implement the supplied decision tree across mission criticality, local outage, DR outage, planned maintenance, active-active, Exadata, and data-loss tolerance. | CLI/menu collects local, DR, and planned RTO/RPO values, but the report emits only a preliminary hint. | Add a deterministic target-tier evaluator and include blocker questions when required inputs are missing. |
| Medium | Evidence maturity scoring | The supplied assessment framework uses maturity levels 0-5 and domain scoring. CrashSimulator currently has baseline pass/gap checks but no domain scorecard or cap rules. | `Readiness status` is `Baseline checks passed` or `Baseline gaps detected`. | Add domain scores for business SLA, local HA, DR, backup/recovery, application continuity, operations, and validation evidence. |
| Medium | Platinum/Diamond detection | Platinum is inferred from Data Guard plus `DBA_CAPTURE`/`DBA_APPLY` counts, and Diamond from 26ai plus that evidence. This can misclassify non-GoldenGate dictionary artifacts as Platinum/Diamond readiness. | Current logic uses capture/apply process counts and version major. | Keep Platinum/Diamond as manual/candidate only unless explicit supported architecture, Exadata/optimized platform, active replication/global routing, and measured evidence are present. |
| Medium | RTO/RPO evidence integration | Scenarios `64` and `65` produce useful RTO/RPO evidence, but the MAA report does not yet consume those outputs to confirm or cap evidenced tier. | RTO validation reads latest completed recovery manifest; RPO validation estimates archived-redo/backed-redo window. | Link latest RTO/RPO drill results into MAA report and use them in fit-gap scoring. |
| Low | Documentation/reference drift | README/reference reports still describe Silver as RAC/RAC One Node only and example reports say `Detected posture` where they should distinguish candidate versus evidenced level. | README and generated 26ai reference report preserve old model wording. | Refresh documentation and reference reports after code changes. |

## Alignment Notes From Supplied Documents

- The decision tree starts from business requirements: planned maintenance, unplanned local HA, unplanned DR, RTO, and RPO.
- Silver now includes strong local HA where RAC or local Data Guard standby may be appropriate.
- Gold is for mainstream business-critical DR using Active Data Guard and automatic failover where appropriate.
- The assessment framework separates installed, configured, integrated, tested, and operationalized capability to prevent overclaiming from product presence alone.
- RAC without services/client failover validation is infrastructure HA, not application-visible HA.
- Data Guard without Broker, lag, and transition evidence is a configured candidate, not tested DR.
- Backups without restore validation are unproven recovery.

## Recommended Implementation Plan

1. Add a small MAA decision engine inside `CrashSimulatorV2.sh`:
   - parse supplied business context;
   - compute target tier from the decision tree;
   - compute candidate tier from topology;
   - compute evidenced tier from domain score caps.

2. Extend MAA context inputs:
   - `--maa-criticality`;
   - `--maa-local-ha-target`;
   - `--maa-dr-required`;
   - `--maa-automatic-failover-required`;
   - `--maa-active-active-required`;
   - `--maa-platform-hint`;
   - `--maa-standby-scope local|remote|unknown`.

3. Add domain score functions:
   - business requirements;
   - backup/recovery;
   - local HA;
   - Data Guard/ADG/FSFO;
   - services/client HA/AC/TAC;
   - operations/evidence recency.

4. Change MAA report headings:
   - `Target MAA level`;
   - `Candidate MAA level`;
   - `Current evidenced MAA level`;
   - `Fit-gap summary`;
   - `Evidence maturity scorecard`;
   - `Evidence required to promote to next tier`.

5. Update generated examples, README, user guide, tutorials, and reference reports after implementation.

## Review Conclusion

CrashSimulator is now aligned with the main structural requirement from the supplied decision trees: it no longer needs to rely on a single topology-based posture label. Future improvements should refine score thresholds with more live-environment evidence, add explicit evidence recency windows, and refresh generated reference examples after running `--maa-report` on a live target.
