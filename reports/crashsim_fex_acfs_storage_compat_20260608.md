# CrashSimulator FEX/ACFS Storage Compatibility Update

Generated UTC: 2026-06-08

## Summary

CrashSimulator was updated so scenarios that were previously ASM-only can also
produce safe, provider-aware plans for Oracle FEX/ACFS-style managed storage.

The key compatibility issue was that Oracle `@...` storage handles are not local
filesystem paths and are not conventional ASM `+DISKGROUP` paths. The framework
now classifies these separately and prevents destructive filesystem actions from
being planned against opaque `@...` handles.

## Code Changes

- Added storage path classification:
  - `+...`: conventional ASM
  - `@...`: FEX/provider-managed storage handle
  - `/.../dbaas_acfs/...` or `/acfs/...`: visible ACFS filesystem path
  - other `/...`: normal filesystem path
- Updated storage discovery to report FEX-style environments as `FEX`.
- Updated scenario requirement handling so ASM/GI managed-storage scenarios can
  plan against `ASM`, `FEX`, `FEX_ACFS`, `ACFS`, or mixed storage.
- Prevented `@...` datafile, tempfile, redo, control-file, SPFILE, FRA, and
  archived-log targets from being treated as renameable filesystem paths.
- Kept opaque FEX targets plan-only until a provider-approved fault injector is
  explicitly added.
- Preserved ACFS local path behavior: visible ACFS files can still use filesystem
  actions when the OS user can see and modify them.

## Scenario Updates

- `46`: renamed to `ASM/FEX data storage unavailable`.
  - Conventional ASM: plans ASM disk group outage evidence.
  - FEX/ACFS: plans managed-storage outage evidence from database destinations.
- `49`: renamed to `ASM/FEX SPFILE loss`.
  - Conventional ASM: plans ASM SPFILE backup/restore flow.
  - FEX/ACFS: plans provider-managed SPFILE metadata restore and srvctl/database validation.
- `72`: renamed to `ASM/FEX storage component failure`.
  - Conventional redundant ASM: plans single-disk/failgroup/rebalance practice.
  - FEX/ACFS: plans provider-managed storage-component outage/rebuild validation.

## 26ai RAC/ADG Validation

The patched runtime was deployed to all four current lab nodes:

- Primary RAC node 1: `crashrac1-xnvfw`
- Primary RAC node 2: `crashrac2-picqh`
- Standby RAC node 1: `crashstby1-msjgs`
- Standby RAC node 2: `crashstby2-vicdd`

All four nodes validated with the same script checksum:

```text
55fe79ade406ef61cc32c1d01e35579624f00b2ce16634751495d0bbe9845388
```

Discovery now reports:

```text
Storage type: FEX
```

Validated dry-run behavior on the primary:

- Scenario `46`: FEX managed-storage outage plan generated; execution blocked as provider-specific.
- Scenario `49`: FEX managed SPFILE-loss plan generated; execution blocked as provider-specific.
- Scenario `72`: FEX storage-component failure plan generated; execution blocked as provider-specific.
- Scenario `30`: PDB datafile target under `@...` is now plan-only, not falsely executable as a local filesystem rename.

## Safety Position

This patch improves compatibility and correctness, but does not pretend that
opaque FEX `@...` handles are safely destructible through generic shell actions.
Execution remains blocked until a provider-approved storage fault injector and
validated recovery workflow are added for the specific lab topology.
