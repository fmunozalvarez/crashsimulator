# CrashSimulator v2.0.3 RC3 Release Notes

Release: `v2.0.3-rc3`

## Summary

CrashSimulator `v2.0.3 RC3` is a single-fix point release over `v2.0.3-rc2`.
It fixes a scenario-recovery validation error on Oracle Database 23ai that was
found while field-testing `rc2` on a 23ai lab. It supersedes `v2.0.3-rc2`.
Everything else — the capability set, scenario catalog, safety model, and all
of the `rc2` fixes — is unchanged.

This release is intended for controlled lab, development, training, and
resilience-test environments. Do not use destructive scenarios in production.

## Fix

- **Scenario recovery no longer fails its validation step on Oracle Database
  23ai.** Every recover ran a post-recovery RMAN check whose command file
  ended with `list failure;` (Data Recovery Advisor). `LIST FAILURE` /
  `ADVISE FAILURE` / `REPAIR FAILURE` are desupported in 23ai, so RMAN raised
  `RMAN-00558` / `RMAN-01009` (`syntax error: found "failure"`). Because RMAN
  parses the entire command file before executing any of it, that parse error
  aborted the whole step — the real `validate`/`crosscheck` never ran and the
  recover reported `Command exited with status 1`, even though the restore had
  already succeeded and the database was open READ WRITE.

  The desupported command was removed from all six validation command-file
  builders. The `validate`/`crosscheck` commands that precede it already set
  RMAN's exit status and report any corruption, so recovery validation now
  works correctly on 19c, 21c, and 23ai. On the affected `rc2` build the
  recovery itself was never at risk — only the cosmetic post-check reported a
  failure.

## Upgrade

Replace `CrashSimulatorV2.sh` (or unpack the full runtime ZIP). No
configuration migration is required. If you are on `rc2` and only ever run on
19c/21c you are unaffected, but upgrading is still recommended.

Users who downloaded `v2.0.3-rc2` for a 23ai lab should move to `v2.0.3-rc3`.
