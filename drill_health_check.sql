whenever sqlerror exit sql.sqlcode
set lines 32767 pages 100 trimspool on tab off feedback on
col name format a80
col file_name format a160
col tablespace_name format a30

prompt === Database state ===
select name, db_unique_name, open_mode, database_role, cdb
from v$database;

prompt === PDB state ===
select name, open_mode
from v$pdbs
order by con_id;

prompt === Files needing media recovery ===
select * from v$recover_file order by file#;

prompt === Datafile status for drill targets ===
select p.name pdb_name,
       df.con_id,
       vf.file# file_no,
       df.tablespace_name,
       df.status,
       df.online_status,
       df.file_name
from cdb_data_files df
join v$datafile vf
  on vf.con_id = df.con_id
 and vf.name = df.file_name
left join v$pdbs p
  on p.con_id = df.con_id
where (p.name = 'CRASHPDB' or df.con_id = 1)
  and df.tablespace_name = 'USERS'
order by df.con_id, vf.file#;

prompt === Block corruption view ===
select * from v$database_block_corruption order by file#, block#;

exit
