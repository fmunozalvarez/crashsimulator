# CrashSimulator Active Data Guard Read-Only Pressure Readiness

- Generated UTC: `2026-06-08T14:54:28Z`
- Database: `crashdr`
- Role/open mode: `PHYSICAL STANDBY` / `READ ONLY WITH APPLY`
- Evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_s53_20260608_145421_adg_pressure.evidence`

This read-only scenario validates that the target is an Active Data Guard standby and captures baseline evidence before any approved reporting/query-pressure workload is introduced. It does not generate load by itself; use the evidence to size a controlled workload and monitor apply lag, user sessions, services, and Resource Manager behavior.


## Evidence

```text
CSIM_ADG|database|db_unique_name=crashdr|role=PHYSICAL STANDBY|open_mode=READ ONLY WITH APPLY|flashback=YES|protection=MAXIMUM PERFORMANCE
CSIM_ADG|managed_standby|MRP0|APPLYING_LOG|N/A|36
CSIM_ADG|managed_standby|RFS|IDLE|Archival|0
CSIM_ADG|lag|apply finish time|+00 00:00:00.001|day(2) to second(3) interval
CSIM_ADG|lag|apply lag|+00 00:00:04|day(2) to second(0) interval
CSIM_ADG|lag|transport lag|+00 00:00:00|day(2) to second(0) interval
CSIM_ADG|user_session_count|16
CSIM_ADG|session_by_user|SYSRAC|5
CSIM_ADG|session_by_user|UNKNOWN|5
CSIM_ADG|session_by_user|PUBLIC|4
CSIM_ADG|session_by_user|SYS|2
```

## Guardrails

- Run only on a standby opened `READ ONLY WITH APPLY`.
- Keep workload read-only and disposable; do not use production reporting spikes as an unbounded stress test.
- Monitor `V$DATAGUARD_STATS`, standby alert logs, service placement, query response time, and application retry behavior.
- If apply lag breaches the SLA, stop the pressure workload first, then validate apply catch-up before continuing.
