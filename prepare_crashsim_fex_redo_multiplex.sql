whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on lines 240 pages 200 trimspool on tab off
column member format a140

prompt === Before redo multiplexing ===
select group#, thread#, sequence#, bytes/1024/1024 mb, members, archived, status
from v$log
order by thread#, group#;

select l.group#, l.thread#, lf.member
from v$logfile lf
join v$log l on l.group# = lf.group#
order by l.thread#, l.group#, lf.member;

declare
  l_dest   v$parameter.value%type;
  l_member varchar2(600);
  l_sql    varchar2(4000);
  l_exists number;
begin
  select value
  into l_dest
  from v$parameter
  where name = 'db_recovery_file_dest';

  if l_dest is null then
    raise_application_error(
      -20001,
      'db_recovery_file_dest is not configured; refusing to add redo members without an explicit target destination'
    );
  end if;

  dbms_output.put_line('Adding missing redo members in destination: ' || l_dest);
  for rec in (
    select group#, thread#, members
    from v$log
    where members < 2
    order by thread#, group#
  ) loop
    if l_dest like '+%' then
      -- ASM diskgroup: pass the bare diskgroup and let OMF name the member
      l_member := l_dest;
      l_sql := 'alter database add logfile member ''' ||
               replace(l_member, '''', '''''') ||
               ''' to group ' || rec.group#;
    else
      -- Filesystem destination: ADD LOGFILE MEMBER needs a full FILE path -
      -- passing the directory itself fails with ORA-00301/ORA-27038. Build a
      -- deterministic, crashsim-namespaced name per group; REUSE lets a rerun
      -- absorb a leftover from an earlier interrupted attempt.
      l_member := rtrim(l_dest, '/') || '/crashsim_redo_g' || rec.group# || '_m2.log';
      l_sql := 'alter database add logfile member ''' ||
               replace(l_member, '''', '''''') ||
               ''' reuse to group ' || rec.group#;
    end if;

    select count(*)
    into l_exists
    from v$logfile
    where member = l_member;

    if l_exists > 0 then
      dbms_output.put_line('Member already present, skipping: ' || l_member);
    else
      dbms_output.put_line(l_sql);
      execute immediate l_sql;
    end if;
  end loop;
end;
/

-- Rotate so the new members become active. ARCHIVE LOG CURRENT raises
-- ORA-00258 in NOARCHIVELOG labs; SWITCH LOGFILE is valid in both modes.
declare
  l_log_mode v$database.log_mode%type;
begin
  select log_mode into l_log_mode from v$database;
  if l_log_mode = 'ARCHIVELOG' then
    execute immediate 'alter system archive log current';
  else
    execute immediate 'alter system switch logfile';
  end if;
end;
/

prompt === After redo multiplexing ===
select group#, thread#, sequence#, bytes/1024/1024 mb, members, archived, status
from v$log
order by thread#, group#;

select l.group#, l.thread#, lf.member
from v$logfile lf
join v$log l on l.group# = lf.group#
order by l.thread#, l.group#, lf.member;

exit
