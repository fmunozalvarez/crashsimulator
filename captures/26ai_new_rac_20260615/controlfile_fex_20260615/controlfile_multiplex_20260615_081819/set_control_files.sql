set echo on feedback on serveroutput on
whenever sqlerror exit sql.sqlcode
alter system set control_files='@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/Current.OMF.70545531','@gB2Ac2II/CRASHRAC-5FB9415B042BDF9DBF8F840EF0BDF92F/CRASHRAC/CONTROLFILE/crashsim_control02_20260615_081819.ctl' scope=spfile sid='*';
exit
