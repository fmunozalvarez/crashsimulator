# FEX Control-File Multiplexing Runbook

Generated UTC: 2026-06-15T08:24:39Z

## Current Evidence

- Database unique name: `crashrac`
- Existing control file: `@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/Current.OMF.70545531`
- Proposed second control file: `@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_082438.ctl`
- Grid command: `/u01/app/23.0.0.0/gridhome_1/bin/srvctl`

## Required Method

FEX exposes Oracle database files as managed `@...` handles. On this host,
the database-file namespace is not exposed through `cp`, `asmcmd`, or the
visible DBaaS ACFS mount. A valid multiplexed control file must be a
byte-for-byte current control file copied while the database is stopped, or must
be recreated through an approved CREATE CONTROLFILE procedure.

Do not use:

```sql
alter database backup controlfile to '@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_082438.ctl';
```

That command creates a backup control file. It can be older than the current
control-file version at the next startup and can raise ORA-00214.

## Provider-Aware Offline Copy Pattern

1. Confirm a recent baseline backup and control-file autobackup.
2. Set the SPFILE target after the byte-copy method is approved:

```sql
alter system set control_files='@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/Current.OMF.70545531','@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_082438.ctl' scope=spfile sid='*';
```

3. Stop the RAC database:

```bash
/u01/app/23.0.0.0/gridhome_1/bin/srvctl stop database -d crashrac -o immediate
```

4. Use the OCI/FEX/provider-approved byte-copy method to copy:

```text
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/Current.OMF.70545531
to
@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_082438.ctl
```

5. Start and validate:

```bash
/u01/app/23.0.0.0/gridhome_1/bin/srvctl start database -d crashrac
```

```sql
select name from v\$controlfile order by name;
select inst_id, instance_name, status from gv\$instance order by inst_id;
select count(*) from v\$recover_file;
```

## Rollback

If startup fails, start one instance NOMOUNT if needed, restore the original
SPFILE value, shut down, and start with srvctl:

```sql
startup nomount;
alter system set control_files='@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/Current.OMF.70545531' scope=spfile sid='*';
shutdown abort;
```

```bash
/u01/app/23.0.0.0/gridhome_1/bin/srvctl start database -d crashrac
```
