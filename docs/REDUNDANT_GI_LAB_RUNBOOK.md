# Purpose-Built Redundant GI/ASM Lab Runbook

This runbook describes how to prepare a dedicated Oracle Grid Infrastructure
and ASM lab for destructive CrashSimulator scenarios `3`, `46`, `47`, `48`, and
`49`.

Use this only in a non-production resilience lab.

## Why This Lab Is Needed

The current two-node RAC environment has ASM disk groups with `EXTERN`
redundancy and one ASM disk per disk group. That topology is useful for many
database and RAC-service drills, but it is not safe for destructive GI/OCR,
voting-disk, ASM SPFILE, or ASM disk-group failure scenarios.

Important ASM rules:

- An existing `EXTERN` disk group cannot be changed in place to `NORMAL` or
  `HIGH` redundancy. Create a new disk group and move or place files there.
- `NORMAL` redundancy needs at least two regular failure groups.
- `HIGH` redundancy needs at least three regular failure groups.
- For OCR and voting-file drills, use at least three total failure groups so
  Clusterware metadata has real quorum behavior.
- RAC database files must stay on supported cluster-aware shared storage.

## Target Design

Recommended lab target:

- Create a new ASM disk group named `+CRASHGI` or similar.
- Use `NORMAL` redundancy with either:
  - three regular failure groups, or
  - two regular failure groups plus one quorum failure group.
- For a stronger lab, use `HIGH` redundancy with at least three regular failure
  groups.
- Use equally sized, equally performing shared block devices.
- Attach each candidate shared disk to every RAC node before ASM discovery.
- Keep the current database disk groups intact unless this is a disposable lab.

Example logical layout for `NORMAL` redundancy:

| Failure group | Purpose | Example device |
| --- | --- | --- |
| `FG1` | Regular ASM extents | `/dev/disk/by-id/scsi-...fg1` |
| `FG2` | Regular ASM extents | `/dev/disk/by-id/scsi-...fg2` |
| `FGQ` | Quorum metadata/voting | `/dev/disk/by-id/scsi-...fgq` |

Example logical layout for `HIGH` redundancy:

| Failure group | Purpose | Example device |
| --- | --- | --- |
| `FG1` | Regular ASM extents | `/dev/disk/by-id/scsi-...fg1` |
| `FG2` | Regular ASM extents | `/dev/disk/by-id/scsi-...fg2` |
| `FG3` | Regular ASM extents | `/dev/disk/by-id/scsi-...fg3` |

## OCI Prerequisite

CrashSimulator cannot create OCI shared block volumes from the database host
unless OCI credentials and tooling are explicitly configured. Provision the
extra shared storage through an approved OCI process first:

1. Create the required block volumes or database-service storage resources.
2. Attach/connect each candidate volume to every RAC node as shared
   read/write storage using a supported RAC/GI method.
3. Confirm the same device WWNs are visible on all RAC nodes.
4. Configure persistent permissions with the storage method used by the
   environment, such as ASM Filter Driver, ASMLib, or supported udev rules.
5. Do not reuse existing ASM member disks. Do not use `FORCE`.

## Preflight Scan

Run the helper on a RAC node:

```bash
sudo bash ./crashsim_prepare_redundant_gi_lab.sh --scan
```

The scan captures:

- Cluster status
- ASM disk groups and disks
- OCR status and backups
- Voting disk placement
- ASM SPFILE location

## Dry-Run A New Disk Group

Replace the device paths with shared candidate disks visible on every node.

```bash
sudo bash ./crashsim_prepare_redundant_gi_lab.sh \
  --diskgroup CRASHGI \
  --redundancy NORMAL \
  --failure-group FG1:/dev/disk/by-id/scsi-3600...fg1 \
  --failure-group FG2:/dev/disk/by-id/scsi-3600...fg2 \
  --quorum-failure-group FGQ:/dev/disk/by-id/scsi-3600...fgq \
  --create-diskgroup \
  --dry-run
```

The helper writes a plan and SQL file under `crashsimulator_logs`.

## Create The Disk Group

After reviewing the plan:

```bash
sudo bash ./crashsim_prepare_redundant_gi_lab.sh \
  --diskgroup CRASHGI \
  --redundancy NORMAL \
  --failure-group FG1:/dev/disk/by-id/scsi-3600...fg1 \
  --failure-group FG2:/dev/disk/by-id/scsi-3600...fg2 \
  --quorum-failure-group FGQ:/dev/disk/by-id/scsi-3600...fgq \
  --create-diskgroup \
  --execute
```

The helper requires a typed confirmation token unless `--yes` is supplied.

## Add OCR Mirror

Add `+CRASHGI` as an additional OCR location only after the disk group is
mounted on every RAC node:

```bash
sudo bash ./crashsim_prepare_redundant_gi_lab.sh \
  --diskgroup CRASHGI \
  --add-ocr \
  --execute
```

Validate:

```bash
ocrcheck
ocrconfig -showbackup
```

## Move Voting Disks

Move voting disks only in a disposable or approved GI lab:

```bash
sudo bash ./crashsim_prepare_redundant_gi_lab.sh \
  --diskgroup CRASHGI \
  --replace-votedisk \
  --execute
```

Validate:

```bash
crsctl query css votedisk
crsctl check cluster -all
```

## Back Up ASM SPFILE

Keep a fresh ASM SPFILE backup in the new redundant disk group:

```bash
sudo bash ./crashsim_prepare_redundant_gi_lab.sh \
  --diskgroup CRASHGI \
  --backup-asm-spfile \
  --execute
```

## CrashSimulator Validation Sequence

After the redundant lab is created:

```bash
./CrashSimulatorV2.sh --validate-scenario 46 --dry-run
./CrashSimulatorV2.sh --scenario 46 --dry-run
./CrashSimulatorV2.sh --validate-scenario 47 --dry-run
./CrashSimulatorV2.sh --scenario 47 --dry-run
./CrashSimulatorV2.sh --validate-scenario 48 --dry-run
./CrashSimulatorV2.sh --scenario 48 --dry-run
./CrashSimulatorV2.sh --validate-scenario 49 --dry-run
./CrashSimulatorV2.sh --scenario 49 --dry-run
```

Do not execute destructive GI scenarios until the dry-runs select the intended
lab resources and the recovery runbooks are confirmed.

## References

- Oracle ASM `CREATE DISKGROUP` redundancy and failure-group rules:
  <https://docs.oracle.com/en/database/oracle/oracle-database/18/sqlrf/CREATE-DISKGROUP.html>
- Oracle ASM disk group creation guidance:
  <https://docs.oracle.com/en/database/oracle/oracle-database/12.2/ostmg/create-diskgroups.html>
- Oracle Clusterware OCR and voting-file management:
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/cwadd/managing-oracle-cluster-registry-and-voting-files.html>
- Oracle RAC shared storage requirement:
  <https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/introduction-to-oracle-rac.html>
