set lines 220 pages 200 trimspool on
whenever sqlerror exit sql.sqlcode
column name format a120
select name, open_mode, database_role, controlfile_type from v$database;
select inst_id, instance_name, status from gv$instance order by inst_id;
select name from v$controlfile order by name;
select con_id, name, open_mode from v$pdbs order by con_id;
select count(*) as recover_file_count from v$recover_file;
exit
