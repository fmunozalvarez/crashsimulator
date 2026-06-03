whenever sqlerror exit sql.sqlcode
set serveroutput on feedback on
declare
  l_cdb v$database.cdb%type;
begin
  select cdb into l_cdb from v$database;

  if l_cdb = 'YES' then
    for r in (
      select name, open_mode
      from v$pdbs
      where name <> 'PDB$SEED'
      order by con_id
    ) loop
      if r.open_mode not in ('READ WRITE', 'READ ONLY', 'READ ONLY WITH APPLY') then
        execute immediate 'alter pluggable database ' || r.name || ' open';
      else
        dbms_output.put_line('PDB ' || r.name || ' already open: ' || r.open_mode);
      end if;
    end loop;
  end if;
end;
/
exit
