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
  l_dest v$parameter.value%type;
  l_sql varchar2(4000);
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
    l_sql := 'alter database add logfile member ''' ||
             replace(l_dest, '''', '''''') ||
             ''' to group ' || rec.group#;
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
  end loop;
end;
/

alter system archive log current;

prompt === After redo multiplexing ===
select group#, thread#, sequence#, bytes/1024/1024 mb, members, archived, status
from v$log
order by thread#, group#;

select l.group#, l.thread#, lf.member
from v$logfile lf
join v$log l on l.group# = lf.group#
order by l.thread#, l.group#, lf.member;

exit
