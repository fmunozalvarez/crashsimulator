# CrashSimulator v2.0.3 Release Notes

Release: `v2.0.3` (General Availability)

## Summary

CrashSimulator `v2.0.3` is the first **General Availability** release of the
open-source edition. It supersedes `v2.0.3-rc1` through `v2.0.3-rc4`.

The scenario catalog is unchanged at 104 scenarios. What changed is what
happens *around* a drill: the engine now refuses to start drills it cannot
finish, says so before the fault rather than after, and knows the difference
between "recovered" and "never injected". Most of this release is the result
of running the destructive catalog end to end against a two-node RAC + Data
Guard lab and fixing everything the runs exposed.

This release is intended for controlled lab, development, training, and
resilience-test environments. **Do not run destructive scenarios in
production.**

## The theme: never claim more than the evidence supports

Every item below came from the same failure mode — the tool knowing something
and reporting something else.

- **"No automated recovery" is announced *before* the fault.** Nine scenarios
  inject a real fault that `--recover` cannot undo. Previously you found that
  out after the injection, when recovery refused. `--validate-scenario` now
  warns at validation time, names the manual path, and the guided menu shows
  it before you commit.

- **Validation-only drills no longer ask to be recovered.** Scenarios that
  inject nothing (read-only checks, plan-only reviews, external-evidence
  drills) said "recovery is not implemented" when asked to recover — alarming
  and wrong. They now state plainly that there is nothing to undo and that the
  drill output *is* the evidence.

- **A destructive plan is refused when its files are not backed up.** Backup
  coverage is now asserted across the whole plan *before* the first removal,
  not discovered halfway through. An unprotected file stops the run.

- **Total redo loss decides from live redo state.** The recovery path reads
  `v$log` at mount time and distinguishes archived from unarchived groups,
  instead of assuming. It records the chain state it actually found, and names
  any group it could not reach.

- **Un-recovered drills block new destructive ones.** Stacking a fresh fault
  on an un-recovered one is how a recoverable lab becomes an unrecoverable
  one. The gate can be closed honestly with the new `--reconcile-drills`,
  which checks manifests against the live database and closes the ones the
  database shows are already recovered — or were never injected.

- **Manifests are strict.** A dry-run manifest, or one from a different
  scenario, is refused for recovery rather than silently accepted.

## ASM-aware injection and recovery

Datafile, control file, redo, archive log, SPFILE, and password file drills
are now ASM-aware end to end:

- ASM write capability is probed **before** anything is offlined, so a missing
  OSASM/`sudo` privilege becomes a clean refusal that changed nothing, instead
  of a half-executed drill with the datafile already offline.
- Files an instance holds open (control files, online redo) are handled by the
  open-file rules ASM actually enforces (`ORA-15028`), including the whole-
  database abort those removals require.
- Recovery re-creates through RMAN rather than copying files into place.

## Also in this release

- **Preparation checklist** — `--prep-list` shows what a scenario needs on this
  target, `--prep <items|all>` prepares them, `--prep-remove <items>` removes
  them.
- **`--online-datafile-drill`** takes the datafile offline first, for a safer
  datafile drill on a database you care about.
- **MAA readiness** understands Distributed topology as a *class*
  (`--maa-distributed-scope`, `--maa-globally-distributed`), separate from the
  tier ladder.
- **Security** — no credential ever appears on a `sqlplus` command line;
  connect strings are supplied on stdin, so they cannot be read from `ps`.
- **Discovery fails closed** when `v$database` cannot be read, instead of
  parsing an Oracle error as topology (carried from RC4).
- **Documentation now matches the tool.** The user guide previously showed
  copy-paste commands for an evidence repository, badges, and calendar export
  — none of which exist in the open-source edition. Those sections now say
  what the open-source edition does and name CrashSimulator Enterprise for the
  rest. Every flag in the documentation is accepted by this build; that is
  checked mechanically at release time.

## Upgrading

Replace `CrashSimulatorV2.sh` with the `v2.0.3` artifact. No configuration
file changes are required, and no state is carried between versions.

Manifests written by earlier builds remain readable. If an older run left a
drill un-recovered, either recover it or run `--reconcile-drills` to close it
against the live database state.

## Known limitations

- Nine scenarios have no automated recovery. This release makes that visible
  up front and documents the manual path; it does not automate it.
- Destructive scenarios require an explicit acknowledgement and a lab-approved
  target. That is deliberate and is not going away.
- Single database, single operator, from the command line. Fleet governance, a
  central evidence repository, and console-driven drills are CrashSimulator
  Enterprise capabilities.
