# CrashSimulator v2.0.3 RC4 Release Notes

Release: `v2.0.3-rc4`

## Summary

CrashSimulator `v2.0.3 RC4` is a field-testing point release over
`v2.0.3-rc3`. It fixes four issues found while running execute-mode scenario
cycles on Oracle Database 23ai labs, plus two usability improvements. The
capability set, scenario catalog, and safety model are unchanged. It
supersedes `v2.0.3-rc3`.

This release is intended for controlled lab, development, training, and
resilience-test environments. Do not use destructive scenarios in production.

## Fixes

- **Topology discovery fails closed when the instance is down.** With the
  Oracle instance not running, SQL*Plus echoes the failing statement plus
  `ORA-01034`, and discovery parsed that error text as topology data — the
  database role picked up a stray quote from the echoed SQL, so scenario
  readiness gates refused with the misleading `requires PRIMARY role.
  Current role: '` instead of naming the dead instance. Discovery now honors
  the SQL*Plus exit status and stops with the real error and a
  startup/`--recover` hint, and the parsed topology row is shape-checked
  before use.

- **Tempfile recovery (scenario 6) works without Oracle-Managed Files.** The
  recovery script re-added the replacement tempfile with a nameless
  `add tempfile size ...`, which is only legal when `db_create_file_dest`
  (OMF) is configured; on filesystem labs with manually named datafiles it
  died with `ORA-02236` and left the temporary tablespace with zero
  tempfiles. Both recovery builders now branch on `db_create_file_dest`:
  with OMF the nameless form is kept, otherwise the original path (freed by
  the scenario's rename) is reused explicitly. Note `REUSE` must precede
  `AUTOEXTEND` in the file specification (`ORA-03049` otherwise).

- **Schema selection validates the configured PDB before entering it.** A
  `CRASHSIM_PDB` carried over from another environment (for example the
  configuration example's `CRASHPDB` on a database whose PDB is named
  differently) flowed straight into `alter session set container` when
  selecting scenario 11/36/43 targets and died with a raw `ORA-65011`. The
  PDB is now checked against the discovered PDB list first: a clear warning
  names the available PDBs and the configuration key, the tool falls back
  automatically when the database has exactly one PDB, and otherwise returns
  to the menu.

- **Scenario 16 (password file): SYS-password prerequisite surfaced early,
  and remote SYSDBA validation discovers the listener endpoint.** Recovery
  recreates the password file with `orapwd`, which needs the SYS password —
  previously the operator learned this only after typing the destructive
  confirmations. The prerequisite is now flagged when the scenario is
  selected, and recovery fails early with a pointer to the password-file
  recovery options. Separately, remote SYSDBA validation no longer hardcodes
  `//localhost:1521`: the endpoint comes from `CRASHSIM_LISTENER_ENDPOINT`,
  the database's own `local_listener` address, or the default, so labs with
  non-default listener ports validate correctly.

## Improvements

- The guided menu explains a dry-run scenario manifest instead of reporting a
  bare recovery status.
- The user guide is scoped to the public feature set.

## Upgrade

Replace `CrashSimulatorV2.sh` (or unpack the full runtime ZIP). No
configuration migration is required. Users field-testing `v2.0.3-rc3` on any
release should move to `v2.0.3-rc4`; the discovery and recovery fixes affect
19c, 21c, and 23ai alike.
