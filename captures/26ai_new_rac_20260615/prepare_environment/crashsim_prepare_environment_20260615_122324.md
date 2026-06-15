# CrashSimulator Seed / Prepare Environment Planner

- Generated UTC: `2026-06-15T12:23:32Z`
- Host: `crashrac1-mlprn`
- OS user: `oracle`
- Database: `CRASHDB`
- DB unique name: `crashrac`
- Role/open mode: `PRIMARY` / `READ WRITE`
- CDB / target PDB: `YES` / `CRASHPDB`
- Cluster/storage: `RAC` / `FEX_ACFS`
- Mode: `DRY-RUN`
- SQL evidence file: `/tmp/crashsimulator/crashsimulator_logs/crashsim_prepare_environment_20260615_122324.evidence`

This planner detects missing lab seeds and environment preparations needed by the scenario catalog. It only recommends actions relevant to the current topology. Execution remains guarded; credentials, storage provisioning, FSFO enablement, and provider-specific copy operations are not guessed.

## Preparation Matrix

| ID | Preparation | Status | Required for | Evidence | Action | Auto-execute |
| --- | --- | --- | --- | --- | --- | --- |
| `logical_lab` | Logical/root/PDB lab objects | `PRESENT` | Required for table/schema/index/read-only/index-only scenarios | root_users=2, root_tbs=2, pdb_users=3, pdb_tbs=2, target_pdb=CRASHPDB | No action needed. | `no` |
| `redo_multiplex` | Multiplex online redo logs | `PRESENT` | Required for redo-loss scenarios 3 and 18 | redo_groups_under2=0, min_members=2 | No action needed. | `no` |
| `controlfile_multiplex` | Multiplex control files | `PLAN_ONLY` | Recommended before control-file scenarios 1, 2, and 23 | control_file_count=1, storage=FEX_ACFS | Generate provider-aware control-file multiplexing runbook. | `no` |
| `services_ac_tac` | AC/TAC/FAN lab services | `MISSING` | Required for service continuity scenarios 56, 83, 84, and 87 | cluster=RAC, services=0, ha_services=0 | Create or repair crashsim_ac and crashsim_tac services with FAN/AC/TAC attributes. | `yes` |
| `apex_ords` | APEX/ORDS application access path | `PRESENT` | Required for APEX/ORDS scenarios 73-82 | apex=1, ords_users=3, ords_service=active, config=present, images=present | No action needed. | `no` |
| `rman_catalog` | RMAN recovery catalog | `PRESENT` | Required for catalog outage and catalog-aware backup evidence | catalog_owners=5, catalog_metadata=1, configured=yes | No action needed. | `no` |
| `fsfo` | Data Guard FSFO observer posture | `NOT_REQUIRED` | Data Guard topology required | dg_dest=0, role=PRIMARY | No standby/transport evidence detected. | `no` |
| `asm_gi_redundant_lab` | ASM/GI redundant storage lab | `PLAN_ONLY` | Required for ASM/FEX/GI destructive storage scenarios 46-49 and 72 | storage=FEX_ACFS, gi=1 | Review or create a purpose-built redundant GI/ASM lab with additional shared disks and failgroups. | `no` |
| `baseline_backup` | Fresh RMAN baseline backup evidence | `PRESENT` | Recommended after environment preparation changes | baseline_logs=4, catalog_configured=yes | Run again after executing any preparation changes. | `no` |

## Suggested Commands

| ID | Command / Helper |
| --- | --- |
| `controlfile_multiplex` | `/tmp/crashsimulator/prepare_crashsim_fex_controlfile_multiplex.sh --dry-run --log-dir /tmp/crashsimulator/crashsimulator_logs` |
| `services_ac_tac` | `/tmp/crashsimulator/tools/crashsim_configure_ha_lab.sh --services` |
| `asm_gi_redundant_lab` | `/tmp/crashsimulator/crashsim_prepare_redundant_gi_lab.sh --dry-run` |

## Notes And Guardrails

- `logical_lab`: Re-run only when logical drills intentionally dropped lab objects.
- `redo_multiplex`: Redo is already multiplexed.
- `controlfile_multiplex`: Requires outage/restart and provider-approved byte-copy or CREATE CONTROLFILE procedure; not auto-executed.
- `services_ac_tac`: Requires srvctl/GI privileges and current DB_UNIQUE_NAME/PDB defaults.
- `apex_ords`: Scenario 79 still needs a load-balancer or peer URL when executed.
- `rman_catalog`: Confirm catalog is outside the target failure domain for production-like DR tests.
- `asm_gi_redundant_lab`: Needs explicit disk/LUN approval; never auto-create storage from the generic prepare menu.
- `baseline_backup`: Use Reports -> Run fresh RMAN baseline backup after changes.

## Raw Evidence

```text
CSIM_PREP|apex_images_state|present
CSIM_PREP|baseline_artifact_count|4
CSIM_PREP|catalog_metadata_count|1
CSIM_PREP|catalog_owner_count|5
CSIM_PREP|cdb|YES
CSIM_PREP|cluster_type|RAC
CSIM_PREP|control_file_count|1
CSIM_PREP|database_role|PRIMARY
CSIM_PREP|db_create_file_dest|@gB2Ac2II(DATA_HC_HIGHREDUNDANCY)
CSIM_PREP|db_name|CRASHDB
CSIM_PREP|db_unique_name_discovered|crashrac
CSIM_PREP|db_unique_name|crashrac
CSIM_PREP|dg_broker_start|FALSE
CSIM_PREP|flashback_on|YES
CSIM_PREP|fra_dest|@gB2Ac2II(RECO_HC_HIGHREDUNDANCY)
CSIM_PREP|fs_failover_observer_present|UNKNOWN
CSIM_PREP|fs_failover_status|DISABLED
CSIM_PREP|gi_managed|1
CSIM_PREP|instance_parallel|YES
CSIM_PREP|log_mode|ARCHIVELOG
CSIM_PREP|open_mode|READ WRITE
CSIM_PREP|ords_binary|/bin/ords
CSIM_PREP|ords_config_state|present
CSIM_PREP|ords_service_state|active
CSIM_PREP|pdb_lab_tablespace_count|2
CSIM_PREP|pdb_lab_user_count|3
CSIM_PREP|redo_groups_under2|0
CSIM_PREP|redo_min_members|2
CSIM_PREP|root_lab_tablespace_count|2
CSIM_PREP|root_lab_user_count|2
CSIM_PREP|service_crashsim_count|0
CSIM_PREP|service_crashsim_ha_count|0
CSIM_PREP|standby_dest_count|0
CSIM_PREP|storage_type|FEX_ACFS
CSIM_PREP|target_apex_registry_count|1
CSIM_PREP|target_con_id|3
CSIM_PREP|target_ords_user_count|3
CSIM_PREP|target_pdb|CRASHPDB
```
