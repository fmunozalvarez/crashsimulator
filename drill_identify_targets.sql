whenever sqlerror exit sql.sqlcode
set lines 32767 pages 100 trimspool on tab off feedback on
col scenario format a12
col pdb_name format a20
col tablespace_name format a30
col file_name format a160

prompt === Scenario target datafiles ===
with candidates as (
  select '30_PDB' scenario,
         p.name pdb_name,
         df.con_id,
         vf.file# file_no,
         df.tablespace_name,
         df.file_name,
         row_number() over (partition by '30_PDB' order by df.file_id) rn
  from cdb_data_files df
  join cdb_tablespaces ts
    on ts.con_id = df.con_id
   and ts.tablespace_name = df.tablespace_name
  join v$pdbs p on p.con_id = df.con_id
  join v$datafile vf
    on vf.con_id = df.con_id
   and vf.name = df.file_name
  where p.name = 'CRASHPDB'
    and ts.contents = 'PERMANENT'
    and df.tablespace_name not in ('SYSTEM','SYSAUX')
  union all
  select '05_CDB' scenario,
         'CDB$ROOT' pdb_name,
         df.con_id,
         vf.file# file_no,
         df.tablespace_name,
         df.file_name,
         row_number() over (partition by '05_CDB' order by df.file_id) rn
  from cdb_data_files df
  join cdb_tablespaces ts
    on ts.con_id = df.con_id
   and ts.tablespace_name = df.tablespace_name
  join v$datafile vf
    on vf.con_id = df.con_id
   and vf.name = df.file_name
  where df.con_id = 1
    and ts.contents = 'PERMANENT'
    and df.tablespace_name not in ('SYSTEM','SYSAUX')
)
select scenario, pdb_name, con_id, file_no, tablespace_name, file_name
from candidates
where rn = 1
order by scenario;

prompt === Recovery file view ===
select * from v$recover_file order by file#;

prompt === Database/PDB state ===
select name, open_mode, database_role, cdb from v$database;
select name, open_mode from v$pdbs order by con_id;
