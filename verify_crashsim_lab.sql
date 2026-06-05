whenever sqlerror exit sql.sqlcode
set lines 200 pages 100 trimspool on tab off

alter session set container = cdb$root;

prompt === CDB root CRASHSIM user ===
select username, account_status, common
from dba_users
where username = 'C##CRASHSIM_ROOT_LAB'
order by username;

prompt === CDB root CRASHSIM tables ===
select owner, table_name, tablespace_name
from dba_tables
where owner = 'C##CRASHSIM_ROOT_LAB'
order by owner, table_name;

prompt === CDB root CRASHSIM indexes ===
select owner, index_name, uniqueness, tablespace_name
from dba_indexes
where owner = 'C##CRASHSIM_ROOT_LAB'
order by owner, index_name;

prompt === CDB root CRASHSIM tablespaces ===
select tablespace_name, contents, status
from dba_tablespaces
where tablespace_name like 'CRASHSIM_ROOT\_%' escape '\'
order by tablespace_name;

alter session set container = crashpdb;

prompt === PDB CRASHSIM users ===
select username, account_status
from dba_users
where username like 'CRASHSIM\_%' escape '\'
order by username;

prompt === PDB CRASHSIM tables ===
select owner, table_name
from dba_tables
where owner like 'CRASHSIM\_%' escape '\'
order by owner, table_name;

prompt === PDB CRASHSIM indexes ===
select owner, index_name, uniqueness, tablespace_name
from dba_indexes
where owner like 'CRASHSIM\_%' escape '\'
order by owner, index_name;

prompt === PDB CRASHSIM tablespaces ===
select tablespace_name, contents, status
from dba_tablespaces
where tablespace_name like 'CRASHSIM\_%' escape '\'
order by tablespace_name;

alter session set container = cdb$root;

exit
