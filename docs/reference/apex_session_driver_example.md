# CrashSimulator APEX Browser Session Driver Evidence Example

- Generated UTC: `2026-06-07T08:52:47Z`
- Label: `local-driver-smoke`
- Start URL: `seeded APEX application URL`
- Final URL: `seeded APEX application URL`
- Username supplied: `no`
- Success selector: `#CRASHSIM_SESSION_OK`
- Duration seconds: `1`
- Interval seconds: `1`
- Status: `PASS`

This sanitized example shows the evidence shape produced by
`tools/crashsim_apex_session_driver.cjs` for scenario `80`. In a real drill, the
URL should be a disposable seeded APEX application page, and the success
selector should point at a stable page element that proves the user session is
still alive after an ORDS, RAC service, Data Guard, or database recovery event.

## Screenshots

- baseline: `assets/screenshots/crashsim_apex_session_driver_baseline.png`
- final: `assets/screenshots/crashsim_apex_session_driver_final.png`

## Checks

| Check | Status | URL | Title | Messages |
| --- | --- | --- | --- | --- |
| baseline | `OK` | seeded APEX application URL | CrashSimulator APEX Session | `OK` |
| poll-1 | `OK` | seeded APEX application URL | CrashSimulator APEX Session | `OK` |

## Interpretation

The browser driver is intentionally optional. Scenario `80` can still collect
read-only ORDS/APEX continuity evidence without it, but the driver adds the
end-user view: screenshots, page title, final URL, marker validation, warning
messages, and a JSON result file suitable for audit evidence.
