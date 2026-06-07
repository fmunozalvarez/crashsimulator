# CrashSimulator APEX Session Continuity Evidence

- Generated UTC: `2026-06-07T09:01:18Z`
- Target PDB: `CRASHDB_PDB1`
- ORDS URL: `http://localhost:8080/ords/`
- Continuity URL: `http://localhost:18080/ords/`
- Continuity URL status: `OK`

| Check | Result |
| --- | --- |
| ORDS/APEX smoke URL | `OK` |
| Continuity or peer URL | `OK` |

No seeded browser-session driver was configured. Use `--apex-session-driver` with a seeded APEX application URL when full end-user behavior capture is needed.

Use this report during a live APEX browser session. Record whether the user sees seamless continuation, retry, relogin, lost page state, or failed transaction after ORDS/RAC/service/database failover.
