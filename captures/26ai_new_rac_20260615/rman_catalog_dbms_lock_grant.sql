whenever sqlerror exit sql.sqlcode
set pages 100 lines 200 feedback on
alter session set container=CRASHPDB;
grant execute on sys.dbms_lock to RMAN_CATALOG;
column owner format a10
column table_name format a20
column privilege format a12
column grantee format a20
select owner, table_name, privilege, grantee
from dba_tab_privs
where owner = 'SYS'
  and table_name = 'DBMS_LOCK'
  and grantee = 'RMAN_CATALOG';
exit
