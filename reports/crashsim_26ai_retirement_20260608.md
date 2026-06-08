# CrashSimulator 26ai Environment Retirement Evidence

- Generated UTC: `2026-06-08T02:16:45Z`
- Repository commit checked before retirement: `cc8298c`
- Environment purpose: Oracle Database 26ai RAC/ASM validation, guided workflow fixes, APEX/ORDS scenario validation, lifecycle/reporting evidence

## Target Environment

- Node 1 host: `crashdb26ai1`
- Node 2 host: `crashdb26ai2`
- Database name: `CRASHDB`
- DB unique name: `crashdb_26ai`
- PDB: `CRASHDB_PDB1`
- Oracle home: `/u01/app/oracle/product/23.0.0.0/dbhome_1`
- Database role: `PRIMARY`
- Open mode: `READ WRITE`
- CDB: `YES`
- RAC: `YES`
- Storage: `ASM`
- FRA: `+RECO`

## Repository / Deployment Alignment

The final remote inventory on both nodes showed the deployed CrashSimulator script and configuration sample matched the laptop repository.

- `CrashSimulatorV2.sh` SHA-256: `c931a9ec01bcc146195354f7a4ebe5fadd7c5ecfaec2a4a41730ef4bb7bab984`
- `config/crashsimulator.conf.example` SHA-256: `3ff1f993601809e2f1ed878aac813334ea5bf04971d0e34b122c38faaf55cdc2`

No additional source code or required project scripts were found on the 26ai environment that needed to be pulled back before termination.

## Preserved Final Evidence

The following final captures were copied into the repository before the OCI environment was terminated:

- `captures/26ai/26ai_final_discover_node1_20260608.txt`
- `captures/26ai/26ai_final_discover_node2_20260608.txt`
- `captures/26ai/26ai_final_show_config_node1_20260608.txt`
- `captures/26ai/26ai_final_show_config_node2_20260608.txt`
- `captures/26ai/26ai_retirement_inventory_node1_20260608.txt`
- `captures/26ai/26ai_retirement_inventory_node2_20260608.txt`
- `captures/26ai/26ai_final_review_index_node1_20260608.txt`

The review index captured on node 1 points to the latest generated topology, configuration, backup/recoverability, service HA, scenario readiness, lifecycle coverage, MAA readiness, health check, scenario manifests, runbooks, and audit records that existed on the test host at retirement time.

## Security Check

The preserved retirement captures were scanned locally for private keys, known passwords, and unredacted catalog/password markers before commit. No matches were found.

## Conclusion

From the CrashSimulator repository perspective, the 26ai OCI environment can be terminated. The source tree, relevant project scripts, final topology/configuration evidence, and final review index have been preserved locally and are ready to be pushed to GitHub.
