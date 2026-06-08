# CrashSimulator 26ai OCI Retirement Final Sync

- Sync UTC: `2026-06-08T16:20Z`
- Environment: OCI 26ai RAC primary, Active Data Guard standby, and bastion/ADB client path
- Purpose: collect final CrashSimulator evidence before terminating the OCI test environment.

## Result

The final useful evidence has been copied from the bastion, RAC primary nodes,
and standby nodes into:

- `captures/26ai_retirement_final_20260608/extracted/`

The extracted evidence was scanned for stored passwords, private keys, wallet
material, and obvious connect-string secrets. No secret values were found in the
retained files. Temporary compressed transfer archives were removed after
extraction so the repository keeps readable evidence only.

It is OK to terminate this OCI test environment from a CrashSimulator artifact
preservation perspective.

## Evidence Collected

| Source | Host observed | Evidence retained |
| --- | --- | --- |
| Bastion | `crashbastian` | Final ADB readiness report, HTML copy, latest pointer, and raw evidence from `2026-06-08T13:44Z`. |
| RAC node 1 | `crashrac1-xnvfw` | Final topology, scenario readiness, lifecycle coverage, MAA/FSFO observer report, DGMGRL FSFO output, srvctl service output, evidence, and scenario 52 manifest. |
| RAC node 2 | `crashrac2-picqh` | Final topology snapshot and latest topology pointer. |
| Standby node 1 | `crashstby1-msjgs` | Final topology, standby scenario readiness, scenario 53 ADG pressure evidence/report/SQL/manifest, and standby redo review SQL. |
| Standby node 2 | `crashstby2-vicdd` | Final topology snapshot and latest topology pointer. |

## Notes

- The deployed server copy still reported `CrashSimulator V2 2.0.0-dev`.
  Current source, docs, package, tag, and GitHub release are now `v2.0.1-beta`
  in the main repository.
- The important code, documentation, screenshots, reference reports, release
  package, and GitHub release have already been synchronized to GitHub.
- No further server-side files are required before terminating this environment.

## Follow-Up After Termination

No database action is required. Keep the retained evidence for historical
validation of the 26ai RAC/ADG/ADB lab work. Future 26ai testing can start from
the `v2.0.1-beta` release package and the current GitHub repository rather than
from the older server-deployed copy.
