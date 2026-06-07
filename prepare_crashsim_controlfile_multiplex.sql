whenever sqlerror exit sql.sqlcode
set echo on feedback on serveroutput on pages 200 lines 220

prompt === Prepare CONTROL_FILES spfile value for +DATA multiplexing ===

declare
  l_existing_control_files varchar2(4000);
  l_new_control_file varchar2(512);
  l_sql varchar2(5000);
begin
  select listagg('''' || name || '''', ',') within group (order by name)
    into l_existing_control_files
    from v$controlfile;

  select '+DATA/' || upper(db_unique_name) || '/CONTROLFILE/current01.ctl'
    into l_new_control_file
    from v$database;

  if instr(l_existing_control_files, '''' || l_new_control_file || '''') = 0 then
    l_sql := 'alter system set control_files=' ||
             l_existing_control_files || ',''' || l_new_control_file ||
             ''' scope=spfile sid=''*''';
    dbms_output.put_line(l_sql);
    execute immediate l_sql;
  else
    dbms_output.put_line('CONTROL_FILES already includes ' || l_new_control_file);
  end if;
end;
/

prompt Restart the database, copy the surviving control file to the new +DATA location while stopped, then start the database.

select name
from v$controlfile
order by name;

exit
