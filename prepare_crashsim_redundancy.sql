whenever sqlerror exit sql.sqlcode
set echo on feedback on serveroutput on pages 200 lines 220

prompt === Add missing online redo members in +DATA ===

declare
  l_sql varchar2(4000);
begin
  for rec in (
    select group#
    from v$logfile
    group by group#
    having count(*) < 2
    order by group#
  ) loop
    l_sql := q'[alter database add logfile member '+DATA' to group ]' || rec.group#;
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
  end loop;
end;
/

alter system archive log current;
alter system switch logfile;

prompt === Redo member layout ===

select l.group#,
       l.thread#,
       l.sequence#,
       l.status,
       l.bytes / 1024 / 1024 as mb,
       count(lf.member) as members
from v$log l
join v$logfile lf on lf.group# = l.group#
group by l.group#, l.thread#, l.sequence#, l.status, l.bytes
order by l.thread#, l.group#;

select group#, member
from v$logfile
order by group#, member;

prompt === Control file layout ===

select name
from v$controlfile
order by name;

exit
