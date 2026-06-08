# CrashSimulator 26ai Active Data Guard Topology Evidence

- Generated UTC: `2026-06-08T09:10:00Z`
- Existing primary setup evidence commit: `d42413b`
- Bastion host: `crashbastian`

## Data Guard Topology

Broker configuration `crashdb_dgconf` is enabled and healthy.

- Configuration status: `SUCCESS`
- Protection mode: `MaxPerformance`
- Primary database: `crashrdb`
- Standby database: `crashdr`
- Fast-Start Failover: `Disabled`
- Primary intended state: `TRANSPORT-ON`
- Standby intended state: `APPLY-ON`
- Standby Real-Time Query: `ON`
- Transport lag at capture time: `0 seconds`
- Apply lag at capture time: `0 seconds`
- Apply instance: `crashdb1`

## Primary RAC

- Host checked: `crashrac1-xnvfw`
- Database name: `CRASHDB`
- DB unique name: `crashrdb`
- Role: `PRIMARY`
- Open mode: `READ WRITE`
- PDB: `CRASHPDB` open `READ WRITE`
- Instances: `crashdb1`, `crashdb2`
- GI managed: `YES`
- Storage detected by CrashSimulator: `FILESYSTEM`
- MAA posture: `Gold`
- MAA readiness: `Baseline checks passed`

Primary scenario readiness for `CRASHPDB`:

- Runnable scenarios: `55`
- Plan-only scenarios: `5`
- Not runnable scenarios: `22`
- Newly relevant primary-side DG scenarios: `51`, `68`, `69`

## Standby RAC / Active Data Guard

CrashSimulator was installed and configured on both standby RAC nodes:

- Standby node 1: `crashstby1-msjgs`
- Standby node 2: `crashstby2-vicdd`
- DB unique name: `crashdr`
- Role: `PHYSICAL STANDBY`
- Open mode: `READ ONLY WITH APPLY`
- PDB: `CRASHPDB` open `READ ONLY`
- Instances: `crashdb1`, `crashdb2`
- GI managed: `YES`
- Storage detected by CrashSimulator: `FILESYSTEM`
- TDE wallet status: `OPEN` for root, seed, and `CRASHPDB`
- Flashback: `YES`
- Force logging: `YES`
- MRP status: `APPLYING_LOG`

Standby services:

- `crashdb_CRASHPDB.paas.oracle.com`: not running on standby, as expected for the PRIMARY role service.
- `crashdb_CRASHPDB_ro.paas.oracle.com`: running on both standby instances, matching the PHYSICAL_STANDBY role service.

Standby scenario readiness for `CRASHPDB`:

- Runnable scenarios: `9`
- Plan-only scenarios: `4`
- Not runnable scenarios: `69`
- Runnable standby/ADG-relevant scenarios: `50`, `67`, `69`

The standby MAA report detected `Gold`, but reported baseline gaps on the standby side. This is expected until standby-local backup/recoverability policy is explicitly validated or defined.

## Current Scenario Target Notes

- `50` Standby managed recovery cancelled: runnable on standby.
- `51` Primary transport destination deferred: runnable on primary.
- `67` Data Guard apply lag exceeds SLA: runnable on standby.
- `68` Data Guard transport network partition: runnable on primary.
- `69` Standby redo log misconfiguration review: runnable as a read-only review.
- `66` FSFO observer unavailable: not runnable because FSFO is disabled and no observer is present.
- `53` Active Data Guard read-only session pressure: ADG topology is now present, but this scenario is still a framework placeholder.
- `54` Snapshot standby conversion practice: standby topology is present, but this scenario is still a framework placeholder and should remain plan-only until a controlled restore-point/flashback procedure is approved.

Existing non-DG blockers remain:

- `3` and `18`: online redo logs are not multiplexed.
- `46`, `49`, and `72`: require conventional ASM storage; this 26ai environment uses Oracle `@...` / ACFS-FEX-style storage naming.
- `70`: VIP relocation still needs an approved privileged Grid/Clusterware path.
- APEX/ORDS scenarios require APEX/ORDS installation and configuration.

## Preserved Evidence

- `captures/26ai_adg/dgmgrl_show_configuration_20260608.txt`
- `captures/26ai_adg/standby_adg_sql_status_20260608.txt`
- `captures/26ai_adg/crashsim_26ai_adg_primary_evidence_20260608.tgz`
- `captures/26ai_adg/crashsim_26ai_adg_standby_evidence_20260608.tgz`

Evidence bundle checksums:

- Primary evidence: `c2e08b01c4a9e8c52e53873abc83be7947a2d1dbeffbfffff4047dd6e5070f85`
- Standby evidence: `6b54368948974e72ede68048bc717edc041172accbed3d956cbfa407803d0f2f`

## Recommended Next Safe Steps

1. Run read-only/low-risk dry-runs first: `69`, `67`, and `50` on the standby; `51` and `68` on the primary.
2. Generate runbooks before execution for each DG scenario.
3. Keep FSFO scenario `66` blocked until FSFO and an observer are intentionally configured.
4. Consider implementing scenario handlers for `53` and `54` now that a valid ADG standby exists.
