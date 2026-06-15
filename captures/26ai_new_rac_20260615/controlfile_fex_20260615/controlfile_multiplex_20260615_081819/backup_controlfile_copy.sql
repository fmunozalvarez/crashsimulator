set echo on feedback on serveroutput on
whenever sqlerror exit sql.sqlcode
alter database backup controlfile to '@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_081819.ctl';
exit
