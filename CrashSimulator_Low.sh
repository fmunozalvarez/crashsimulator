#!/bin/bash
# Based on Crashmanager by Marco V, March 27th 2009, Version 1.000.00
# CrashSimulator by Francisco Munoz Alvarez, March 3rd 2018, Version 1.02
#

RANDOM=$$
UPPER_LIMIT=44
SUCCESS=0
FAIL=255

# Invalid user selection
invalid_choice()
{
ERRMSG="Invalid Menu Number... Please Try Again"
}


clear
echo
echo
echo  -e "\e[97mCrashSimulator - Oracle on Linux Crash Scenario Generator V1.04 Terms and Conditions"
echo  -e "\e[97m------------------------------------------------------------------------------------------"
echo  -e "\e[92mBy Francisco Munoz Alvarez - http://oraclenz.com"
echo  -e "\e[92mFollow me on Twitter [FCOMUNOZ] or Linkedin for news about updates, tips and tricks using CrashSimulator"
echo 
echo
echo -e "\e[31m1) This Oracle Crash Simulator Tool could damage your current database environemtn when simulating a Crash."
echo
echo -e "\e[31m2) It is your responsability to have all proper backups on Place before executing this program."
echo
echo -e "\e[31m3) Never run this program in a Production Environment."
echo
echo -e "\e[31m4) You are running this program under your own responsability ."
echo
echo -e "\e[31m4) You will not reverse engineer, decompiled, unwrapped or otherwise tamper this software."
echo
echo -e "\e[97m"
echo $ERRMSG
echo

read -n 1 -p "Do you accept this terms and Conditions and want to Continue? [Y/N]: " ans;

case $ans in
    y|Y)
        continue ;; 
    n|N)
        clear 
        exit ;;
    *)
        clear
        exit;;
esac


show_menu()
{
#clear
clear
echo 
echo 
echo -e "\e[97m\tCrashSimulator - Oracle on Linux Crash Scenario Generator V1.04"
echo -e "\e[97m\t-----------------------------------------------------------------"
echo -e "\e[92m\tBy Francisco Munoz Alvarez - http://oraclenz.com"
echo -e "\e[92m\tFollow me on Twitter [FCOMUNOZ] or Linkedin for news about updates, tips and tricks using CrashSimulator"
echo
echo -e "\e[97m\t\tChoose one of the following scenarios:"
echo 
echo -e "\e[31m\t\tNote: If not using a CDB environment please only execute the CDB and ASM scenarios:"
echo 
echo -e "\e[97m\t\t\tCDB  scenarios:\t\t\t\t\t" 
echo -e "\e[97m\t\t\t---------------\t\t\t\t\t"
echo 
echo -e "\e[92m\t\t\tLoss of a control file:-------------------------------->[ 1]" 
echo -e "\e[93m\t\t\tLoss of all control files:----------------------------->[ 2]"
echo -e "\e[92m\t\t\tLoss of a redo log file group member:------------------>[ 3]"
echo -e "\e[93m\t\t\tLoss of a redo log file group:------------------------->[ 4]"
echo -e "\e[92m\t\t\tLoss of a non-system datafile:------------------------->[ 5]"
echo -e "\e[93m\t\t\tLoss of a temporary tempfile:-------------------------->[ 6]"
echo -e "\e[92m\t\t\tLoss of a SYSTEM datafile:----------------------------->[ 7]"
echo -e "\e[93m\t\t\tLoss of an UNDO datafile:------------------------------>[ 8]"
echo -e "\e[92m\t\t\tLoss of a Read-Only tablespace:------------------------>[ 9]"
echo -e "\e[93m\t\t\tLoss of an Index tablespace:--------------------------->[10]"
echo -e "\e[92m\t\t\tLoss of all Non-unique/primary key indexes in USERS:--->[11]"
echo -e "\e[93m\t\t\tLoss of a non-system tablespace:----------------------->[12]" 
echo -e "\e[92m\t\t\tLoss of a temporary tablespace:------------------------>[13]" 
echo -e "\e[93m\t\t\tLoss of a SYSTEM tablespace:--------------------------->[14]"
echo -e "\e[92m\t\t\tLoss of an UNDO tablespace:---------------------------->[15]"
echo -e "\e[93m\t\t\tLoss of the password file:----------------------------->[16]"
echo -e "\e[92m\t\t\tLoss of all datafiles:--------------------------------->[17]" 
echo -e "\e[93m\t\t\tLoss of redo log member of a multiplexed group:-------->[18]" 
echo -e "\e[92m\t\t\tLoss of all redo log members of INACTIVE groups:------->[19]" 
echo -e "\e[93m\t\t\tLoss of all redo log members of an ACTIVE group:------->[20]" 
echo -e "\e[92m\t\t\tLoss of all redo log members of CURRENT group:--------->[21]" 
echo -e "\e[93m\t\t\tFile Header Corruption:-------------------------------->[22]"  
echo -e "\e[92m\t\t\tControl Files Corruption:------------------------------>[23]"  
echo -e "\e[93m\t\t\tCurrent Log File Corruption:--------------------------->[24]"  
echo -e "\e[92m\t\t\tLoss of all RMAN Backups:------------------------------>[25]"  
echo -e "\e[93m\t\t\tLoss of SPFILE:---------------------------------------->[26]"  
echo -e "\e[92m\t\t\tLoss of TNSNAMES and LISTENER:------------------------->[27]"  
echo -e "\e[93m\t\t\tLoss of ORACLE HOME:----------------------------------->[28]"  
echo -e "\e[92m\t\t\tLoss of FRA:------------------------------------------->[29]"  
echo 
echo -e "\e[97m\t\t\tReview all available PDB and ASM Crash Scenarios:\t[88]"
echo 
echo -e "\e[97m\t\t\tPerform a random CDB, PDB, or ASM Crash Scenario:\t[99]"
echo 
echo -e "\e[97m\t\t\tExit:\t\t\t\t\t\t\t[ 0]"
echo 
echo $ERRMSG
echo 
echo -n "Enter the value number associated with the crash scenario you want to reproduce: "
}

show_menu22()
{
#clear
clear
echo
echo
echo -e "\e[97m\tCrashSimulator - Oracle on Linux Crash Scenario Generator V1.03"
echo -e "\e[97m\t-----------------------------------------------------------------"
echo -e "\e[92m\tBy Francisco Munoz Alvarez - http://oraclenz.com"
echo -e "\e[92m\tFollow me on Twitter [FCOMUNOZ] or Linkedin for news about updates, tips and tricks using CrashSimulator"
echo
echo -e "\e[97m\t\tChoose one of the following scenarios:"
echo
echo -e "\e[97m\t\t\tPDB  scenarios:\t\t\t\t\t" 
echo -e "\e[97m\t\t\t---------------\t\t\t\t\t"
echo
echo -e "\e[92m\t\t\tLoss of a non-system datafile:------------------------->[30]" 
echo -e "\e[93m\t\t\tLoss of a temporary tempfile::------------------------->[31]"
echo -e "\e[92m\t\t\tLoss of a SYSTEM datafile:----------------------------->[32]"
echo -e "\e[93m\t\t\tLoss of an UNDO datafile:------------------------------>[33]"
echo -e "\e[92m\t\t\tLoss of a Read-Only tablespace:------------------------>[34]"
echo -e "\e[93m\t\t\tLoss of an Index tablespace:--------------------------->[35]"
echo -e "\e[92m\t\t\tLoss of all Non-unique/primary key indexes in USERS:--->[36]"
echo -e "\e[93m\t\t\tLoss of a non-system tablespace:----------------------->[37]"
echo -e "\e[92m\t\t\tLoss of a temporary tablespace:------------------------>[38]"
echo -e "\e[93m\t\t\tLoss of a SYSTEM tablespace:--------------------------->[39]"
echo -e "\e[92m\t\t\tLoss of an UNDO tablespace:---------------------------->[40]"
echo -e "\e[93m\t\t\tLoss of all datafiles:--------------------------------->[41]"
echo -e "\e[92m\t\t\tPhysical Block Corruption:----------------------------->[42]"
echo -e "\e[93m\t\t\tLoss of a Table:--------------------------------------->[43]"
echo -e "\e[92m\t\t\tLoss of a Schema:-------------------------------------->[44]"
echo -e "\e[93m\t\t\tLoss of a PDB:----------------------------------------->[45]"
echo
echo -e "\e[97m\t\t\tASM senarios (Coming Soon):"
echo -e "\e[97m\t\t\t---------------------------"
echo
echo -e "\e[97m\t\t\tLoss of a data disk group:\t\t\t\t[46]"
echo -e "\e[97m\t\t\tLoss of OCR:\t\t\t\t\t\t[47]"
echo -e "\e[97m\t\t\tLoss of Voting Disk:\t\t\t\t\t[48]"
echo -e "\e[97m\t\t\taLoss of a ASM Spfile:\t\t\t\t\t[49]"
echo
echo -e "\e[97m\t\t\tPerform a random CDB, PDB, or ASM Crash Scenario:\t[99]"
echo
echo -e "\e[97m\t\t\tBack to CDB scenarios:\t\t\t\t\t[77]"
echo -e "\e[97m\t\t\tExit:\t\t\t\t\t\t\t[ 0]"
echo
echo $ERRMSG
echo
echo -n "Enter the value number associated with the crash scenario you want to reproduce: "
}

exec_menu()
{
                # Execute one of the functions based
                # on the number entered by the user.
                case "$1" in
                        "1"  ) menu_id_01 ;;
                        "2"  ) menu_id_02 ;;
                        "3"  ) menu_id_03 ;;
                        "4"  ) menu_id_04 ;;
                        "5"  ) menu_id_05 ;;
                        "6"  ) menu_id_06 ;;
                        "7"  ) menu_id_07 ;;
                        "8"  ) menu_id_08 ;;
                        "9"  ) menu_id_09 ;;
                        "10" ) menu_id_10 ;;
                        "11" ) menu_id_11 ;;
                        "12" ) menu_id_12 ;;
                        "13" ) menu_id_13 ;;
                        "14" ) menu_id_14 ;;
                        "15" ) menu_id_15 ;;
                        "16" ) menu_id_16 ;;
                        "17" ) menu_id_17 ;;
                        "18" ) menu_id_18 ;;
                        "19" ) menu_id_19 ;;
                        "20" ) menu_id_20 ;;
                        "21" ) menu_id_21 ;;
                        "22" ) menu_id_22 ;;
                        "23" ) menu_id_23 ;;
                        "24" ) menu_id_24 ;;
                        "25" ) menu_id_25 ;;
                        "26" ) menu_id_26 ;;
                        "27" ) menu_id_27 ;;
                        "28" ) menu_id_28 ;;
                        "29" ) menu_id_29 ;;
                        "30" ) menu_id_30 ;;
                        "31" ) menu_id_31 ;;
                        "32" ) menu_id_32 ;;
                        "33" ) menu_id_33 ;;
                        "34" ) menu_id_34 ;;
                        "35" ) menu_id_35 ;;
                        "36" ) menu_id_36 ;;
                        "37" ) menu_id_37 ;;
                        "38" ) menu_id_38 ;;
                        "39" ) menu_id_39 ;;
                        "40" ) menu_id_40 ;;
                        "41" ) menu_id_41 ;;
                        "42" ) menu_id_42 ;;
                        "43" ) menu_id_42 ;;
                        "44" ) menu_id_42 ;;
                        "45" ) menu_id_42 ;;
                        "88" ) show_menu2 ;;
                        "99" ) menu_id_99 ;;
                        "0" ) break ;;
                         *  ) invalid_choice ;;
                esac

}

# exec_menu2()
# {
#                # Execute one of the functions based
#                # on the number entered by the user.
#                case "$1" in
#                        "30" ) menu_id_30 ;;
#                        "31" ) menu_id_31 ;;
#                        "32" ) menu_id_32 ;;
#                        "33" ) menu_id_33 ;;
#                        "34" ) menu_id_34 ;;
#                        "35" ) menu_id_35 ;;
#                        "36" ) menu_id_36 ;;
#                        "37" ) menu_id_37 ;;
#                        "38" ) menu_id_38 ;;
#                        "39" ) menu_id_39 ;;
#                        "40" ) menu_id_40 ;;
#                        "41" ) menu_id_41 ;;
#                        "42" ) menu_id_42 ;;
#                        "77" ) show_menu ;;
#                        "99" ) menu_id_99 ;;
#                        "0" ) break ;;
#                         *  ) invalid_choice ;;
#                esac
#
#}

kill_instance()
{
	pmon_pid=$(ps -ef | grep pmon | grep -v grep | awk '{print $2}')
	kill -9 "$pmon_pid"
}

get_random_number()
{
RANDOM_NUMBER=$(( $RANDOM % $UPPER_LIMIT + 1 ))
return "$RANDOM_NUMBER"
}

# Remove files pointed from the array of file location
# starting from 0 to n (argument passed to the function)
remove_files() 
{
	ii=0
	file_renamed=$(date +%Y%m%d_%H%M%S).bck
	while ((ii < "$1"))
	do
		echo "mv ${ARRAY_OF_FILES[ii]} ${ARRAY_OF_FILES[ii]}.$file_renamed"
		mv "${ARRAY_OF_FILES[ii]}" "${ARRAY_OF_FILES[ii]}.$file_renamed"
		((ii = ii + 1))
	done
	return "$SUCCESS"
}

remove_files2()
{
        echo "mv $ORACLE_HOME $ORACLE_BASE"
        mv "$ORACLE_HOME" "$ORACLE_BASE"
        return "$SUCCESS"
}

remove_files3()
{
        ii=0
        while ((ii < "$1"))
        do
                echo "mv ${ARRAY_OF_FILES[ii]} $ORACLE_BASE"
                mv "${ARRAY_OF_FILES[ii]}" "$ORACLE_BASE"
                ((ii = ii + 1))
        done
        return "$SUCCESS"


        echo "mv $ORACLE_HOME $ORACLE_BASE"
        mv "$ORACLE_HOME" "$ORACLE_BASE"
        return "$SUCCESS"
}

exec_files()
{
        chmod u+x /tmp/filehcorruption.tmp
        /bin/bash /tmp/filehcorruption.tmp
        return "$SUCCESS"
}

exec_files2()
{
        chmod u+x /tmp/filecorruption.tmp
        /bin/bash /tmp/filecorruption.tmp
        return "$SUCCESS"
}

exec_files3()
{
        chmod u+x /tmp/logcorruption.tmp
        /bin/bash /tmp/logcorruption.tmp
        return "$SUCCESS"
}

exec_files4()
{
        chmod u+x /tmp/pdbfilehcorruption.tmp
        /bin/bash /tmp/pdbfilehcorruption.tmp
        return "$SUCCESS"
}




# Read content of tmp file
read_files()
{
	ii=0
	file_exist "$1"
	if [ "$?" -eq "$SUCCESS" ]
	then
		# Testing for presence of a second arg (how many lines do you want to read)
		if [ "$#" -eq "2" ]
		then
			# Reading exactly n lines of the file
	 		for filename in `seq $2`
			do
				read filename
				if [[ ! -z "$filename" && "$filename" != '' ]]
				then
					ARRAY_OF_FILES[$ii]=$filename
					((ii = ii + 1))
				fi
			done < "$1"
		else
			# Reading all lines of the file
			while read filename
			do
				if [[ ! -z "$filename" && "$filename" != '' ]]
				then
					ARRAY_OF_FILES[$ii]=$filename
					((ii = ii + 1))
				fi
			done < $1
		fi
	else
		return "$FAIL"
	fi
	return "$SUCCESS"
}

# Checking existence of tmp file
file_exist()
{
	if [[ -e "$1" ]]
	then
		return "$SUCCESS"
	fi
	return "$FAIL"
}

# Counts how many lines are present in the file
count_files()
{
	file_exist "$1"
	if [ "$?" -eq "$SUCCESS" ]
	then
		# Checking for Oracle errors (0 match found, 1 match not found) 
		# ORA-01034: ORACLE not available for example
		grep -q ORA- "$1"
		return_val=$?
		if [ "$return_val" -ne "$SUCCESS" ]
		then
			return $(echo $(wc -l < "$1"))
		fi
	fi
	return "$FAIL"
}



query_controlfiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/controlfile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col name format a150

DECLARE
BEGIN
    FOR rec IN (select name from v\$controlfile where rownum=1)
    LOOP
        dbms_output.put_line(rec.name);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_allcontrolfiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/allcontrolfile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col name format a150

DECLARE
BEGIN
    FOR rec IN (select name from v\$controlfile)
    LOOP
        dbms_output.put_line(rec.name);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_ns_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/non_system_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select FILE_NAME from dba_data_files where TABLESPACE_NAME='USERS' where rownum=1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_ns_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/non_system_datafiles.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select FILE_NAME from dba_data_files where TABLESPACE_NAME='USERS' order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbns_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbnon_system_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from cdb_data_files a, V\$PDBS b  where a.TABLESPACE_NAME='USERS' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') and rownum = 1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit
EOF
}

query_pdbns_datafilealls()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbnon_system_datafileall.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from cdb_data_files a, V\$PDBS b  where a.TABLESPACE_NAME='USERS' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit
EOF
}

query_pdb_table()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbtable.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col OWNER format a150
col NAME format a150
col SEGMENT_NAME format a30

DECLARE
l_ddl VARCHAR2(1000);
l_ddl2 VARCHAR2(1000);
l_ddl3 VARCHAR2(1000);
l_ddl4 VARCHAR2(1000);
finx NUMBER(10);
fHandle UTL_FILE.FILE_TYPE; 
vText varchar2(100); 
BEGIN
    FOR rec IN (select a.owner, a.segment_name, b.name
    from cdb_segments a, V\$PDBS b
    where a.CON_ID = b.CON_ID 
    and (b.CON_ID  = 3 or b.NAME='PDB1') 
    and a.SEGMENT_TYPE = 'TABLE'
    and a.OWNER not in ('APEX_050100','SYSTEM','ORDDATA','XDB','SYS','TSMSYS','MDSYS','EXFSYS','WMSYS','ORDSYS','OUTLN','DBSNMP','CTXSYS','ORDS_METADATA','OJVMSYS','DVSYS','AUDSYS','GSMADMIN_INTERNAL','LBACSYS')
    and a.SEGMENT_NAME not like 'BIN$%')
    LOOP
      l_ddl2 := 'ALTER SESSION SET CONTAINER='||rec.name;
      dbms_output.put_line(l_ddl2);
      EXECUTE IMMEDIATE (l_ddl2);
      SELECT count(*) into finx
      FROM cdb_constraints pk
      JOIN cdb_constraints fk
      ON pk.constraint_name = fk.r_constraint_name
      AND fk.constraint_type = 'R'
      JOIN cdb_cons_columns col
      ON fk.constraint_name = col.constraint_name
      WHERE pk.owner = rec.owner AND pk.table_name = rec.segment_name AND pk.constraint_type = 'P';      
      if finx = 0 then
         EXECUTE IMMEDIATE 'DROP TABLE '||rec.owner||'.'||rec.segment_name;
         EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY TMP AS ''' ||'/tmp'||'''';
         EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY TMP TO SYS';
         EXECUTE IMMEDIATE 'GRANT WRITE ON DIRECTORY TMP TO SYS';
         fHandle := UTL_FILE.FOPEN('TMP','pdbtable.tmp','w'); 
         vText := 'DROP TABLE '||rec.owner||'.'||rec.segment_name; 
         UTL_FILE.PUTF(fHandle,vText); 
         UTL_FILE.FCLOSE(fHandle); 
        exit;
      end if;
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdb_schema()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbschema.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col OWNER format a150
col NAME format a150
col SEGMENT_NAME format a30

DECLARE
l_ddl VARCHAR2(1000);
l_ddl2 VARCHAR2(1000);
l_ddl3 VARCHAR2(1000);
l_ddl4 VARCHAR2(1000);
fHandle UTL_FILE.FILE_TYPE;
vText varchar2(100);
BEGIN
    FOR rec IN (select distinct a.owner,b.name
     from cdb_segments a, V\$PDBS b
     where a.CON_ID = b.CON_ID 
     and (b.CON_ID  = 3 or b.NAME='PDB1') 
     and a.OWNER not in ('APEX_050100','SYSTEM','XDB','SYS','TSMSYS','MDSYS','EXFSYS','WMSYS','ORDSYS','OUTLN','DBSNMP','CTXSYS','ORDS_METADATA','OJVMSYS','DVSYS','AUDSYS','GSMADMIN_INTERNAL','LBACSYS','ORDDATA')
     and rownum=1)
    LOOP
         EXECUTE IMMEDIATE 'ALTER SESSION SET CONTAINER='||rec.name;
         EXECUTE IMMEDIATE 'DROP USER '||rec.owner||' CASCADE';
         EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY TMP AS ''' ||'/tmp'||'''';
         EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY TMP TO SYS';
         EXECUTE IMMEDIATE 'GRANT WRITE ON DIRECTORY TMP TO SYS';
         fHandle := UTL_FILE.FOPEN('TMP','pdbschema.tmp','w'); 
         vText := 'DROP USER '||rec.owner||' CASCADE';
         UTL_FILE.PUTF(fHandle,vText); 
         UTL_FILE.FCLOSE(fHandle); 
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdb()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdb.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col OWNER format a150
col NAME format a150
col SEGMENT_NAME format a30

DECLARE
l_ddl VARCHAR2(1000);
l_ddl2 VARCHAR2(1000);
fHandle UTL_FILE.FILE_TYPE;
vText varchar2(100);
BEGIN
    FOR rec IN (select name
from V\$PDBS 
where  (CON_ID  = 3 or NAME='PDB1')
and rownum=1)
    LOOP
         EXECUTE IMMEDIATE 'ALTER PLUGGABLE DATABASE '||rec.name||' CLOSE';
         EXECUTE IMMEDIATE 'DROP PLUGGABLE DATABASE '||rec.name||' INCLUDING DATAFILES';
         EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY TMP AS ''' ||'/tmp'||'''';
         EXECUTE IMMEDIATE 'GRANT READ ON DIRECTORY TMP TO SYS';
         EXECUTE IMMEDIATE 'GRANT WRITE ON DIRECTORY TMP TO SYS';
         fHandle := UTL_FILE.FOPEN('TMP','pdb.tmp','w');
         vText := 'DROP PLUGGABLE DATABASE '||rec.name||' INCLUDING DATAFILES';
         UTL_FILE.PUTF(fHandle,vText);
         UTL_FILE.FCLOSE(fHandle);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbsys_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbsystem_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from CDB_DATA_FILES a, V\$PDBS b  where a.TABLESPACE_NAME='SYSTEM' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') and rownum= 1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbsys_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbsystem_datafileall.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from CDB_DATA_FILES a, V\$PDBS b  where a.TABLESPACE_NAME='SYSTEM' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbundo_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbundo_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from CDB_DATA_FILES a, V\$PDBS b  where a.TABLESPACE_NAME like 'UND%' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') and rownum = 1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbundo_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbundo_datafileall.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from CDB_DATA_FILES a, V\$PDBS b  where a.TABLESPACE_NAME like 'UND%' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbfile_h_corruption()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbfilehcorruption.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off

DECLARE
   line1 VARCHAR2(150);
   line2 VARCHAR2(150);
   line3 VARCHAR2(150);
BEGIN
    select 'dd if=/dev/zero of='||a.file_name||' bs=8k conv=notrunc seek=1 count=1' into line1 from CDB_DATA_FILES a, V\$PDBS b  where a.TABLESPACE_NAME = 'SYSTEM' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') and rownum = 1;
    dbms_output.put_line(line1);
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbreadonly_tablespace()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbreadonly_tablespace.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select file_name from cdb_data_files a , V\$PDBS b where b.STATUS = 'READ ONLY' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') order by FILE_ID))
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbindexusers()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbindexusers.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col INDEX_NAME format a150
col OWNER format a150
col NAME format a150

DECLARE
l_ddl VARCHAR2(1000);
l_ddl2 VARCHAR2(1000);
l_ddl3 VARCHAR2(1000);
BEGIN
    FOR rec IN ( select a.owner,a.index_name, b.name  from cdb_indexes ai, V\$PDBS b  where  a.tablespace_name = 'USERS' and a.UNIQUENESS = 'NONUNIQUE' and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1'))
    LOOP
      l_ddl2 := 'ALTER SESSION SET container = '|||rec.name; 
      dbms_output.put_line(l_ddl2);
      EXECUTE IMMEDIATE (l_ddl2);
      l_ddl := 'drop index '|| rec.owner||'.'||rec.index_name;
      dbms_output.put_line(l_ddl);
      EXECUTE IMMEDIATE (l_ddl);
     l_ddl3 := 'ALTER SESSION SET container = cdb$root;
      dbms_output.put_line(l_ddl3);
      EXECUTE IMMEDIATE (l_ddl3);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbindexonly_tablespace()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbindexonly_tablespace.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a150

DECLARE
totalx number(6);
BEGIN
    FOR rec IN ( select distinct a.tablespace_name from cdb_indexes a, V\$PDBS b where a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') order by a.tablespace_name)
    LOOP
    SELECT COUNT(*) into totalx from cdb_tables a, V\$PDBS b where t.ablespace_name = rec.tablespace_name and a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1');
    IF totalx = 0 then
       FOR rec2 IN (select a.file_name from dba_data_files a, \$PDBS b where a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1')  order by a.FILE_ID)
           LOOP
           dbms_output.put_line(rec2.FILE_NAME);
           END LOOP;
    END IF;
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdball_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdball_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select a.FILE_NAME from cdb_data_files a, v\$PDBS b where a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1')  order by a.FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbtemp_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbtemporary_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
FOR rec IN (select a.FILE_NAME from CDB_TEMP_FILES a, V\$PDBS b  where a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') and rownum = 1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pdbtemp_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pdbtemporary_datafileall.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
FOR rec IN (select a.FILE_NAME from CDB_TEMP_FILES a, V\$PDBS b  where a.CON_ID = b.CON_ID  and (b.CON_ID  = 3 or b.NAME='PDB1') order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_temp_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/temporary_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select file_name 
		from dba_users, dba_temp_files 
		where tablespace_name = temporary_tablespace 
		and username = 'SYS'
                and rownum = 1)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_temp_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/temporary_datafiles.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select file_name 
		from dba_users, dba_temp_files 
		where tablespace_name = temporary_tablespace 
		and username = 'SYS')
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_sys_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/system_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select FILE_NAME from dba_data_files where TABLESPACE_NAME='SYSTEM' and rownum = 1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_sys_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/system_datafiles.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select FILE_NAME from dba_data_files where TABLESPACE_NAME='SYSTEM' order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_rman_loss()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/rmanloss.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col HANDLE format a150

DECLARE
BEGIN
    FOR rec IN (select HANDLE from v\$backup_piece)
    LOOP
        dbms_output.put_line(rec.HANDLE);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_undo_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/undo_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    --FOR rec IN (select FILE_NAME from dba_data_files where TABLESPACE_NAME='UNDOTBS1' order by FILE_ID)
    FOR rec IN (select FILE_NAME from dba_data_files a, dba_tablespaces b where b.STATUS = 'ONLINE' and b.CONTENTS = 'UNDO' and a.TABLESPACE_NAME = b.TABLESPACE_NAME and rownum = 1 order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_undo_datafilesall()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/undo_datafiles.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    --FOR rec IN (select FILE_NAME from dba_data_files where TABLESPACE_NAME='UNDOTBS1' order by FILE_ID)
    FOR rec IN (select FILE_NAME from dba_data_files a, dba_tablespaces b where b.STATUS = 'ONLINE' and b.CONTENTS = 'UNDO' and a.TABLESPACE_NAME = b.TABLESPACE_NAME order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_readonly_tablespace()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/readonly_tablespace.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150

DECLARE
BEGIN
    FOR rec IN (select file_name from dba_data_files a, dba_tablespaces b where b.STATUS = 'READ ONLY' and b.TABLESPACE_NAME = a.TABLESPACE_NAME order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_indexonly_tablespace()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/indexonly_tablespace.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a150

DECLARE
totalx number(6);
BEGIN
    FOR rec IN ( select distinct tablespace_name from all_indexes order by tablespace_name)
    LOOP
    SELECT COUNT(*) into totalx from dba_tables where tablespace_name = rec.tablespace_name;
    IF totalx = 0 then
       FOR rec2 IN (select file_name from dba_data_files a, dba_tablespaces b where a.TABLESPACE_NAME = rec.TABLESPACE_NAME and  b.TABLESPACE_NAME = a.TABLESPACE_NAME order by FILE_ID)
           LOOP
           dbms_output.put_line(rec2.FILE_NAME);
           END LOOP;
    END IF;
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_indexusers()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/indexusers.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col INDEX_NAME format a150
col OWNER format a150

DECLARE
l_ddl VARCHAR2(1000);
BEGIN
    FOR rec IN ( select owner,index_name from dba_indexes where  tablespace_name = 'USERS' and UNIQUENESS = 'NONUNIQUE')
    LOOP
      
      l_ddl := 'drop index '|| rec.owner||'.'||rec.index_name;
      dbms_output.put_line(l_ddl);
      EXECUTE IMMEDIATE (l_ddl); 
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_spfile()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/spfile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col VALUE format a150

DECLARE
BEGIN
    FOR rec IN (select VALUE from v\$parameter WHERE name = 'spfile')
    LOOP
        dbms_output.put_line(rec.VALUE);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_all_datafiles()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/all_datafile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col FILE_NAME format a150
col TABLESPACE_NAME format a30

DECLARE
BEGIN
    FOR rec IN (select FILE_NAME from dba_data_files order by FILE_ID)
    LOOP
        dbms_output.put_line(rec.FILE_NAME);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_pfile()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/pfile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col VALUE format a150

DECLARE
BEGIN
    FOR rec IN (select VALUE from v\$parameter WHERE name = 'pfile')
    LOOP
        dbms_output.put_line(rec.VALUE);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}


query_log_member()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/logfile.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col member format a150

DECLARE
BEGIN
    FOR rec IN (select member 
		    from  v\$log a, v\$logfile b
		    where a.group# = b.group#
		    and a.status = 'CURRENT')
    LOOP
        dbms_output.put_line(rec.member);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_redo_member()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/redo_group.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col member format a150

DECLARE
BEGIN
    FOR rec IN (select member 
		    from  v\$log a, v\$logfile b
		    where a.group# = b.group#
		    and a.status = 'CURRENT')
    LOOP
        dbms_output.put_line(rec.member);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}
query_inactive_group()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/inactive_group.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col member format a150

DECLARE
BEGIN
    FOR rec IN (select member 
		    from  v\$log a, v\$logfile b
		    where a.group# = b.group#
		    and a.status = 'INACTIVE'
		    order by b.group#, member)
    LOOP
        dbms_output.put_line(rec.member);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_active_group()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/active_group.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col member format a150

DECLARE
BEGIN
    execute immediate 'alter system switch logfile';
    FOR rec IN (select member 
		    from  v\$log a, v\$logfile b
		    where a.group# = b.group#
		    and a.status = 'ACTIVE'
		    order by b.group#, member)
    LOOP
        dbms_output.put_line(rec.member);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_log_group()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/log_groupfiles.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col member format a150

DECLARE
BEGIN
    FOR rec IN (select member
                    from  v\$log a, v\$logfile b
                    where a.group# = b.group#
                    and a.status = 'CURRENT'
                    order by b.group#, member)
    LOOP
        dbms_output.put_line(rec.member);
    END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_current_group()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/current_group.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col member format a150

DECLARE
BEGIN
    FOR rec IN (select member
                    from  v\$log a, v\$logfile b
                    where a.group# = b.group#
                    and a.status = 'CURRENT'
                    order by b.group#, member)
    LOOP
        dbms_output.put_line(rec.member);
   END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_fra()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/fra.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off
col value format a150

DECLARE
BEGIN
    FOR rec IN (select value from v\$parameter where name = 'db_recovery_file_dest')
    LOOP
        dbms_output.put_line(rec.value);
   END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_sqlnet()
{
ls $ORACLE_HOME/network/admin/listener.ora > /tmp/sqlnet.tmp
ls $ORACLE_HOME/network/admin/tnsnames.ora >> /tmp/sqlnet.tmp
}

query_oraclehome()
{
ls $ORACLE_HOME > /tmp/oraclehome.tmp
}

query_file_h_corruption()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/filehcorruption.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off

DECLARE
   line1 VARCHAR2(150);
   line2 VARCHAR2(150);
   line3 VARCHAR2(150);
BEGIN
    select 'dd if=/dev/zero of='||b.name||' bs=8k conv=notrunc seek=1 count=1' into line1 from v\$tablespace a, v\$datafile b  where a.TS# = b.TS# and a.name = 'SYSTEM' and rownum = 1;  
    dbms_output.put_line(line1);
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_file_corruption()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/filecorruption.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off

DECLARE
   line1 VARCHAR2(150);
   line2 VARCHAR2(150);
   line3 VARCHAR2(150);
BEGIN
    FOR rec IN (select name from v\$controlfile)
    LOOP
        line1 := 'dd if=\$ORACLE_HOME/bin/oracle of='||rec.name||' bs=8192 seek=1 count=30 conv=notrunc';
        dbms_output.put_line(line1);
   END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

query_log_corruption()
{
$ORACLE_HOME/bin/sqlplus -s / as sysdba << EOF > /tmp/logcorruption.tmp
set serveroutput on
set lines 180
set pages 1000
set feedback off
set echo off
set ver off

DECLARE
   line1 VARCHAR2(150);
   line2 VARCHAR2(150);
   line3 VARCHAR2(150);
BEGIN
    execute immediate 'alter system switch logfile';
    FOR rec IN (select member
                    from  v\$log a, v\$logfile b
                    where a.group# = b.group#
                    and a.status = 'ACTIVE'
                    order by b.group#, member)
    LOOP
        line1 := 'dd if=\$ORACLE_HOME/bin/oracle of='||rec.member||' bs=8192 seek=1 count=30 conv=notrunc';
        dbms_output.put_line(line1);
   END LOOP;
END;
/

set echo on
set feed on
set ver on
exit;
EOF
}

files_to_tmp()
{
	case "$1" in
		"CONTROLFILES"     ) query_controlfiles ;;
		"ALLCONTROLFILES"  ) query_allcontrolfiles ;;
		"LOGFILES"         ) query_log_member ;;
		"LOGGROUP"         ) query_log_group ;;
		"NONSYSTEMDATA"    ) query_ns_datafiles ;;
		"PDBNONSYSTEMDATA" ) query_pdbns_datafiles ;;
		"TEMPORARYDATA"    ) query_temp_datafiles ;;
		"PDBTEMPORARYDATA" ) query_pdbtemp_datafiles ;;
		"RMANLOSS"         ) query_rman_loss ;;
		"SYSTEMDATA"       ) query_sys_datafiles ;;
		"PDBSYSTEMDATA"    ) query_pdbsys_datafiles ;;
		"UNDODATA"         ) query_undo_datafiles ;;
		"PDBUNDODATA"      ) query_pdbundo_datafiles ;;
		"READONLYTBS"      ) query_readonly_tablespace ;;
		"PDBREADONLYTBS"   ) query_pdbreadonly_tablespace ;;
		"INDEXONLYTBS"     ) query_indexonly_tablespace ;;
		"PDBINDEXONLYTBS"  ) query_pdbindexonly_tablespace ;;
		"INDEXUSERS"       ) query_indexusers ;;
		"PDBINDEXUSERS"    ) query_pdbindexusers ;;
		"NONSYSTEMTBS"     ) query_ns_datafilesall ;;
		"PDBNONSYSTEMTBS"  ) query_pdbns_datafilesall ;;
		"TEMPORARYTBS"     ) query_temp_datafilesall ;;
		"PDBTEMPORARYTBS"  ) query_pdbtemp_datafilesall ;;
		"SYSTEMTBS"        ) query_sys_datafilesall ;;
		"PDBSYSTEMTBS"     ) query_pdbsys_datafilesall ;;
		"UNDOTBS"          ) query_undo_datafilesall ;;
		"PDBUNDOTBS"       ) query_pdbundo_datafilesall ;;
		"SPFILE"           ) query_spfile ;;
		"PFILE"            ) query_pfile ;;
		"ALLDATA"          ) query_all_datafiles ;;
		"PDBALLDATA"       ) query_pdball_datafiles ;;
		"REDOMEMBER"       ) query_redo_member ;;
		"INACTIVEGROUP"    ) query_inactive_group ;;
		"ACTIVEGROUP"      ) query_active_group ;;
  		"CURRENTGROUP"     ) query_current_group ;;
  		"FILEHCORRUPTION"  ) query_file_h_corruption ;;
  		"PDBFILEHCORRUPTION"  ) query_pdbfile_h_corruption ;;
  		"FILECORRUPTION"   ) query_file_corruption ;;
  		"LOGCORRUPTION"    ) query_log_corruption ;;
  		"PDBTABLE"         ) query_pdb_table ;;
  		"PDBSCHEMA"        ) query_pdb_schema ;;
  		"PDB"              ) query_pdb ;;
  		"SQLNET"           ) query_sqlnet ;;
  		"ORACLEHOME"       ) query_oraclehome ;;
  		"FRA"              ) query_fra ;;
	esac
}

# Menu 1 selected: LOSS OF A CONTROL FILE
menu_id_01()
{
	# Read from database the control file's location
	# redirecting the output to a tmp file
	files_to_tmp "CONTROLFILES"

        # Counting the number of control files found
	count_files "/tmp/controlfile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Control file Available."
		return "$SUCCESS"
	elif [ "$return_val" -le "1" ]
	then
		ERRMSG="Can not proceed. Your database has just one control file. Select menu 2 if you want to perform a loss of all control files."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your control files. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/controlfile.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate Control files."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"

	fi
        echo
        echo -e "Simulation of loss of a control file Successful."
        echo
        kill_instance
        echo
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 2 selected: LOSS OF ALL CONTROL FILES
menu_id_02()
{
	# Read from database the control file's location
	# redirecting the output to a tmp file
	files_to_tmp "ALLCONTROLFILES"

        # Counting the number of control files found
	count_files "/tmp/allcontrolfile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Control files Available."
		return "$SUCCESS"
	elif [ "$return_val" -le "1" ]
	then
		ERRMSG="Not able to find information on your control files. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read all the lines of the file
                read_files "/tmp/allcontrolfile.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate  Control files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of all control files Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 3 selected: LOSS OF A REDO LOG FILE GROUP MEMBER
menu_id_03()
{
	# Read from database the redo log file group member's location
	# redirecting the output to a tmp file
	files_to_tmp "LOGFILES"

        # Counting the number of redo log file group member files found
	count_files "/tmp/logfile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Redo Log file Available."
		return "$SUCCESS"
	elif [ "$return_val" -le "1" ]
	then
		ERRMSG="Can not proceed. Your database has just one redo log file group member file. Select menu 4 if you want to perform a loss of all redo log file group member files."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your redo log file group member files. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/logfile.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate Redo Log files."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"
	fi
        echo
        echo -e "Simulation of loss of a Redo Log File Group Member Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 4 selected: LOSS OF A REDO LOG FILE GROUP
menu_id_04()
{
	# Read from database the redo log file group member's location
	# redirecting the output to a tmp file
	files_to_tmp "LOGGROUP"

        # Counting the number of redo log file group member files found
	count_files "/tmp/log_groupfiles.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Redo Log Group Available."
		return "$SUCCESS"
#	elif [ "$return_val" -le "1" ]
#	then
#		ERRMSG="Not able to find information on your redo log file group member files. Be sure your database is up and running."
#		return "$SUCCESS"
	else
		# Read all the lines of the file
                read_files "/tmp/log_groupfiles.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate Redo Log files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of a Redo Log Group Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 5 selected: LOSS OF A NON-SYSTEM DATAFILE
menu_id_05()
{
	# Read from database the non-system datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "NONSYSTEMDATA"

        # Counting the number of non-system datafile found
	count_files "/tmp/non_system_datafile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed.  No Non-System Datafile is Available."
		return "$SUCCESS"
#	elif [ "$return_val" -le "1" ]
#	then
#		ERRMSG="Can not proceed. Your database has just one non-system datafile. Select menu 12 if you want to perform a loss of all non-system datafiles of USERS tablespace."
#		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your non-system datafile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/non_system_datafile.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate Non-System Datafiles."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"
	fi
        echo
        echo -e "Simulation of loss of a Non-System Datafile Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0

}

# Menu 6 selected: LOSS OF A TEMPORARY DATAFILE
menu_id_06()
{
	# Read from database the temporary datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "TEMPORARYDATA"

        # Counting the number of temporary datafile found
	count_files "/tmp/temporary_datafile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Temporary Datafile Available."
		return "$SUCCESS"
#	elif [ "$return_val" -le "1" ]
#	then
#		ERRMSG="Can not proceed. Your database has just one temporary datafile. Select menu 13 if you want to perform a loss of all temporary datafiles of temporary tablespace."
#		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your temporary datafile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/temporary_datafile.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate temporary files."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"
	fi
        echo
        echo -e "Simulation of loss of a Temporary  Datafile Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 7 selected: LOSS OF A SYSTEM DATAFILE
menu_id_07()
{
	# Read from database the system datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "SYSTEMDATA"

        # Counting the number of system datafile found
	count_files "/tmp/system_datafile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No System Datafile Availabley."
		return "$SUCCESS"
#	elif [ "$return_val" -le "1" ]
#	then
#		ERRMSG="Can not proceed. Your database has just one system datafile. Select menu 14 if you want to perform a loss of all system datafiles of SYSTEM tablespace."
#		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your system datafile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/system_datafile.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate System Datafiles."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"
	fi
        echo
        echo -e "Simulation of loss of a Sydtem Datafile Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 8 selected: LOSS OF A UNDO DATAFILE
menu_id_08()
{
	# Read from database the undo datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "UNDODATA"

        # Counting the number of undo datafile found
	count_files "/tmp/undo_datafile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Undo Datafile Available."
		return "$SUCCESS"
#	elif [ "$return_val" -le "1" ]
#	then
#		ERRMSG="Can not proceed. Your database has just one undo datafile. Select menu 14 if you want to perform a loss of all datafiles of UNDO tablespace."
#		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your undo datafile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/undo_datafile.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate Undo files."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"
	fi
        echo
        echo -e "Simulation of loss of an Undo Datafile Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 9 selected: LOSS OF A READ-ONLY TABLESPACE
menu_id_09()
{
	# Read from database the read-only datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "READONLYTBS"

        # Counting the number of read-only datafile found
	count_files "/tmp/readonly_tablespace.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Read Only Tablespace in the Database."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your read-only datafile. Be sure your database has a Read Only Tablespace or it is up and running."
		return "$SUCCESS"
	else
		# Read all the lines of the file
                read_files "/tmp/readonly_tablespace.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any Read only Tablespace."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of a Read Only Tablespace  Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 10 selected: LOSS OF AN INDEX TABLESPACE
menu_id_10()
{
        # Read from database the Index  datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "INDEXONLYTBS"

        # Counting the number of read-only datafile found
        count_files "/tmp/indexonly_tablespace.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No Index  Only Tablespace in the Database."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your Index-only datafile. Be sure your database has a Read Only Tablespace or it is up and running."
                return "$SUCCESS"
        else
                # Read all the lines of the file
                read_files "/tmp/indexonly_tablespace.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any Index only Tablespace."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of a Index  Only Tablespace  Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 11 selected: LOSS OF ALL Non-unique/primary key INDEXES IN USERS TABLESPACE
menu_id_11()
{
        # Read from database all Non-unique/primary key Indexes in Tabkesoace USERS
        # redirecting the output to a tmp file
        files_to_tmp "INDEXUSERS"

        # Counting the number of read-only datafile found
        count_files "/tmp/indexusers.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No Non-unique/primary key Indexes in Tablespace Users."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your Non-unique/primary key Indexes in Tablespace Users. Be sure your database has a Read Only Tablespace or it is up and running."
                return "$SUCCESS"
        else
                # Read all the lines of the file
                read_files "/tmp/indexusers.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any Non-unique/primary key Indexes in Tablespace Users."
                        return "$SUCCESS"
                fi

                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of all Non-unique/primary key Indexes in Tablespace Users  Successful."
        echo
        # kill_instance
        # echo -e "Instance Terminated!"
        exit 0
}

# Menu 12 selected: LOSS OF A NON-SYSTEM TABLESPACE
menu_id_12()
{
	# Read from database the non-system datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "NONSYSTEMTBS"

        # Counting the number of non-system datafile found
	count_files "/tmp/non_system_datafiles.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No Non-SYSTEM Tablespace Available in the  Database."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your non-system tablespace. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/non_system_datafiles.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate NON-SYSTEM files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of Non-System Tablespace Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 13 selected: LOSS OF A TEMPORARY TABLESPACE
menu_id_13()
{
	# Read from database the temporary datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "TEMPORARYTBS"

        # Counting the number of temporary datafile found
	count_files "/tmp/temporary_datafiles.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. Temporary file is empty."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your temporary tablespace. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/temporary_datafiles.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate temporary files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of Temporary Tablespace Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 14 selected: LOSS OF A SYSTEM TABLESPACE
menu_id_14()
{
	# Read from database the system datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "SYSTEMTBS"

        # Counting the number of system datafile found
	count_files "/tmp/system_datafiles.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No System Files."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your system tablespace. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/system_datafiles.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any System files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of System Tablespace Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 15 selected: LOSS OF AN UNDO TABLESPACE
menu_id_15()
{
	# Read from database the undo datafile's location
	# redirecting the output to a tmp file
	files_to_tmp "UNDOTBS"

        # Counting the number of undo datafile found
	count_files "/tmp/undo_datafiles.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No UNDO Files available."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your undo tablespace. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/undo_datafiles.tmp" "1"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate UNDO files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of UNDO Tablespace Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 16 selected: LOSS OF THE PASSWORD FILE
menu_id_16()
{
	# Read from database the pfile's location
	# redirecting the output to a tmp file
	files_to_tmp "PFILE"

        # Counting the number of spfile found
	count_files "/tmp/pfile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. Can not Locate a PFILE. Please check if your Database is using a SPFILE instead"
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information about your pfile, maybe you are using a spfile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/pfile.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate a PFILE file."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of PFILE Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 17 selected: LOSS OF ALL DATAFILES
menu_id_17()
{
	# Read from database the datafiles's location
	# redirecting the output to a tmp file
	files_to_tmp "ALLDATA"

        # Counting the number of spfile found
	count_files "/tmp/all_datafile.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. Could not find any Datafile."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your datafiles. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/all_datafile.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any datafiles."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of all Datafiles Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 18 selected: LOSS OF REDO LOG MEMBER OF A MULTIPLEXED GROUP
menu_id_18()
{
	# Read from database the redo logfile's location
	# redirecting the output to a tmp file
	files_to_tmp "REDOMEMBER"

        # Counting the number of redo logfile found
	count_files "/tmp/redo_group.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. Could not find any multiplexed Redo Log Group."
		return "$SUCCESS"
	elif [ "$return_val" -le "1" ]
	then
		ERRMSG="Can not proceed. Your database has just one redo logfile member for group. Select menu 19, 20 or 21 if you want to perform a loss of all redo logfiles."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your redo logfiles. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/redo_group.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any multiplexed Redo Log Group."
			return "$SUCCESS"
		fi

		# Remove one file
                remove_files "1"
	fi
        echo
        echo -e "Simulation of loss of a Redolog member of a Multiplexed Groups Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 19 selected: LOSS OF ALL REDO LOG MEMBERS OF ALL INACTIVE GROUP
menu_id_19()
{
	# Read from database the redo logfile's location
	# redirecting the output to a tmp file
	files_to_tmp "INACTIVEGROUP"

        # Counting the number of redo logfile found
	count_files "/tmp/inactive_group.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. No INACTIVE Redo log group found."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your redo log file. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/inactive_group.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any INACTIVE Redo log Group."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of all members of an INACTIVE  Redo log Group Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 20 selected: LOSS OF ALL REDO LOG MEMBERS OF AN ACTIVE GROUP
menu_id_20()
{
	# Read from database the redo logfile's location
	# redirecting the output to a tmp file
	files_to_tmp "ACTIVEGROUP"

        # Counting the number of redo logfile found
	count_files "/tmp/active_group.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. Unable to find any ACTIVE Redo Log Group."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your redo logfile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/active_group.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any ACTIVE Redo Log files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of all members of an ACTIVE  Redo log Group Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 21 selected: LOSS OF ALL REDO LOG MEMBERS OF CURRENT GROUP
menu_id_21()
{
	# Read from database the redo logfile's location
	# redirecting the output to a tmp file
	files_to_tmp "CURRENTGROUP"

        # Counting the number of redo logfile found
	count_files "/tmp/current_group.tmp"
	return_val=$?
	if [ "$return_val" -eq "0" ]
	then
		ERRMSG="Can not proceed. Unable to find any Current Redo Log Group."
		return "$SUCCESS"
	elif [ "$return_val" -eq "$FAIL" ]
	then
		ERRMSG="Not able to find information on your redo logfile. Be sure your database is up and running."
		return "$SUCCESS"
	else
		# Read just the first line of the file
                read_files "/tmp/current_group.tmp"
		return_val=$?
		if [ "$return_val" -eq "$FAIL" ]
		then
			ERRMSG="Can not proceed. Program was not able to locate any Current Redo Log  files."
			return "$SUCCESS"
		fi

		# Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
	fi
        echo
        echo -e "Simulation of loss of all members of a CURRENT Redo log Group Successful."
        echo
	kill_instance
        echo -e "Instance Terminated!"
	exit 0
}

# Menu 22 selected: FILE HEADER CORRUPTION 
menu_id_22()
{
        # Read from database the redo logfile's location
        # redirecting the output to a tmp file
        files_to_tmp "FILEHCORRUPTION"

        # Counting the number of redo logfile found
        count_files "/tmp/filehcorruption.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any File to be Corrupted."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your database files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/filehcorruption.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any Database files."
                        return "$SUCCESS"
                fi
                exec_files
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of a Database File Header Corruption Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

menu_id_23()
{
        # Control file Corruption
        # redirecting the output to a tmp file
        files_to_tmp "FILECORRUPTION"

        # Counting the number of redo logfile found
        count_files "/tmp/filecorruption.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any Control File to be Corrupted."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your database Control files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/filecorruption.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any Database Control files."
                        return "$SUCCESS"
                fi
                exec_files2
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of a Database Control File  Corruption Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

menu_id_24()
{
        # Log file Corruption
        # redirecting the output to a tmp file
        files_to_tmp "LOGCORRUPTION"

        # Counting the number of redo logfile found
        count_files "/tmp/logcorruption.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any Log File to be Corrupted."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your database Log files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/logcorruption.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any log files."
                        return "$SUCCESS"
                fi
                exec_files3
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of a Database Log File Corruption Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Loss of all RMAN backups
menu_id_25()
{
        # Log file Corruption
        # redirecting the output to a tmp file
        files_to_tmp "RMANLOSS"

        # Counting the number of redo logfile found
        count_files "/tmp/rmanloss.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any available RMAN backup."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your RMAN backup files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/rmanloss.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any RMAN files."
                        return "$SUCCESS"
                fi
                # exec_files
                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of Loss of all RMAN backups Successful"
        echo
        #kill_instance
        #echo -e "Instance Terminated!"
        exit 0
}

# Menu 26 selected: LOSS OF THE SPFILE 
menu_id_26()
{
        # Read from database the spfile's location
        # redirecting the output to a tmp file
        files_to_tmp "SPFILE"

        # Counting the number of spfile found
        count_files "/tmp/spfile.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Can not Locate a SPFILE. Please check if your Database is using a PFILE instead"
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about  your spfile, maybe you are using a pfile. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/spfile.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate a SPFILE file."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of SPFILE Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 27 selected: LOSS OF TNSNAMES and LISTENER
menu_id_27()
{
        # Read from database the spfile's location
        # redirecting the output to a tmp file
        files_to_tmp "SQLNET"

        # Counting the number of spfile found
        count_files "/tmp/sqlnet.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Can not Locate a TNSNAMES.ora or LISTENER.ora files. Please check if your Database SQLNET is set and your database is up and running"
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about  your SQLNET files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/sqlnet.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate a TNSNAMES.ora and/or LISTENER.ora file , check if your database is up and running."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of your SQLNET file (LISTENER.ora and TNSNAMES.ora) Successful."
        echo
        # kill_instance
        # echo -e "Instance Terminated!"
        exit 0
}

# Menu 28 selected: LOSS OF ORACLE_HOME
menu_id_28()
{
        # Read from database the spfile's location
        # redirecting the output to a tmp file
        files_to_tmp "ORACLEHOME"

        # Counting the number of spfile found
        count_files "/tmp/oraclehome.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Can not Locate any ORACLE_HOME. Please check if database is installed on this server and your database is up and running"
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your ORACLE_HOME files. Be sure your database is installed on this server and your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/oraclehome.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate an ORACLE_HOME."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files2 "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of your ORACLE_HOME Successful."
        echo
         kill_instance
         echo -e "Instance Terminated!"
        exit 0
}

# Menu 29 selected: LOSS OF FRA
menu_id_29()
{
        # Read from database the spfile's location
        # redirecting the output to a tmp file
        files_to_tmp "FRA"

        # Counting the number of spfile found
        count_files "/tmp/fra.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Can not Locate a FRA. Please check if FRA is Configured on this server and your database is up and running"
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your FRA files. Be sure FRA is configured on this server and your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/fra.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any FRA files."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files3 "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of your FRA files Successful."
        echo
         kill_instance
         echo -e "Instance Terminated!"
        exit 0
}

# Menu 30 selected: LOSS OF A PDB NON-SYSTEM DATAFILE
menu_id_30()
{
        # Read from database the non-system datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBNONSYSTEMDATA"

        # Counting the number of non-system datafile found
        count_files "/tmp/pdbnon_system_datafile.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed.  No PDB Non-System Datafile is Available."
                return "$SUCCESS"
#       elif [ "$return_val" -le "1" ]
#       then
#               ERRMSG="Can not proceed. Your database has just one non-system datafile. Select menu 12 if you want to perform a loss of all non-system datafiles of USERS tablespace."
#               return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB for non-system datafiles. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbnon_system_datafile.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate PDB Non-System Datafiles."
                        return "$SUCCESS"
                fi

                # Remove one file
                remove_files "1"
        fi
        echo
        echo -e "Simulation of loss of a PDB Non-System Datafile Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0

}

# Menu 31 selected: LOSS OF A PDB TEMPORARY DATAFILE
menu_id_31()
{
        # Read from database the temporary datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBTEMPORARYDATA"

        # Counting the number of temporary datafile found
        count_files "/tmp/pdbtemporary_datafile.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB Temporary Datafile Available."
                return "$SUCCESS"
#       elif [ "$return_val" -le "1" ]
#       then
#               ERRMSG="Can not proceed. Your database has just one temporary datafile. Select menu 13 if you want to perform a loss of all temporary datafiles of temporary tablespace."
#               return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB temporary datafile. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbtemporary_datafile.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB temporary files."
                        return "$SUCCESS"
                fi

                # Remove one file
                remove_files "1"
        fi
        echo
        echo -e "Simulation of loss of a PDB Temporary  Datafile Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 32 selected: LOSS OF A PDB SYSTEM DATAFILE
menu_id_32()
{
        # Read from database the system datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBSYSTEMDATA"

        # Counting the number of system datafile found
        count_files "/tmp/pdbsystem_datafile.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB System Datafile Availabley."
                return "$SUCCESS"
#       elif [ "$return_val" -le "1" ]
#       then
#               ERRMSG="Can not proceed. Your database has just one system datafile. Select menu 14 if you want to perform a loss of all system datafiles of SYSTEM tablespace."
#               return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB for a system datafile. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbsystem_datafile.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate a PDB  System Datafile."
                        return "$SUCCESS"
                fi

                # Remove one file
                remove_files "1"
        fi
        echo
        echo -e "Simulation of loss of a PDB System Datafile Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 33 selected: LOSS OF A PDB UNDO DATAFILE
menu_id_33()
{
        # Read from database the undo datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBUNDODATA"

        # Counting the number of undo datafile found
        count_files "/tmp/pdbundo_datafile.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB Undo Datafile Available."
                return "$SUCCESS"
#       elif [ "$return_val" -le "1" ]
#       then
#               ERRMSG="Can not proceed. Your database has just one undo datafile. Select menu 14 if you want to perform a loss of all datafiles of UNDO tablespace."
#               return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB for UNDO datafile. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbundo_datafile.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate Undo files."
                        return "$SUCCESS"
                fi

                # Remove one file
                remove_files "1"
        fi
        echo
        echo -e "Simulation of loss of a PDB Undo Datafile Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 34 selected: LOSS OF A PDB READ-ONLY TABLESPACE
menu_id_34()
{
        # Read from database the read-only datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBREADONLYTBS"

        # Counting the number of read-only datafile found
        count_files "/tmp/pdbreadonly_tablespace.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No Read Only Tablespace in the PDB Database."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB read-only datafile. Be sure your database has a Read Only Tablespace or it is up and running."
                return "$SUCCESS"
        else
                # Read all the lines of the file
                read_files "/tmp/pdbreadonly_tablespace.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB Read only Tablespace."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of a PDB Read Only Tablespace Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 35 selected: LOSS OF A PDB INDEX TABLESPACE
menu_id_35()
{
        # Read from database the Index  datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBINDEXONLYTBS"

        # Counting the number of read-only datafile found
        count_files "/tmp/pdbindexonly_tablespace.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No Index Only Tablespace in the PDB Database."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your Index-only datafile in your PDB. Be sure your PDB database has a Read Only Tablespace or it is up and running."
                return "$SUCCESS"
        else
                # Read all the lines of the file
                read_files "/tmp/pdbindexonly_tablespace.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any Index only Tablespace in your PDB."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of a PDB Index Only Tablespace Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

menu_id_36()
{
        # Read from PDB database all Non-unique/primary key Indexes in Tablesoace USERS
        # redirecting the output to a tmp file
        files_to_tmp "PDBINDEXUSERS"

        # Counting the number of read-only datafile found
        count_files "/tmp/pdbindexusers.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No Non-unique/primary key Indexes in your PDB Tablespace Users."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your Non-unique/primary key Indexes in your PDB Tablespace Users. Be sure your PDB database is up and running."
                return "$SUCCESS"
        else
                # Read all the lines of the file
                read_files "/tmp/pdbindexusers.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any Non-unique/primary key Indexes in the PDB Tablespace Users."
                        return "$SUCCESS"
                fi

                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of all Non-unique/primary key Indexes in the PDB Tablespace Users Successful."
        echo
        # kill_instance
        # echo -e "Instance Terminated!"
        exit 0
}

# Menu 37 selected: LOSS OF A PDB NON-SYSTEM TABLESPACE
menu_id_37()
{
        # Read from database the non-system datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBNONSYSTEMTBS"

        # Counting the number of non-system datafile found
        count_files "/tmp/pdbnon_system_datafileall.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB Non-SYSTEM Tablespace Available in the  Database."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB for non-system tablespace. Be sure your PDB database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbnon_system_datafileall.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB NON-SYSTEM files."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of a PDB Non-System Tablespace Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 38 selected: LOSS OF A PDB TEMPORARY TABLESPACE
menu_id_38()
{
        # Read from database the temporary datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBTEMPORARYTBS"

        # Counting the number of temporary datafile found
        count_files "/tmp/pdbtemporary_datafileall.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB Temporary tablespace available."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on your PDB temporary tablespace. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbtemporary_datafileall.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB temporary files."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of PDB Temporary Tablespace Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 39 selected: LOSS OF A PDB SYSTEM TABLESPACE
menu_id_39()
{
        # Read from database the system datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBSYSTEMTBS"

        # Counting the number of system datafile found
        count_files "/tmp/pdbsystem_datafileall.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB System tablespace available."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information of your PDB system tablespace. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbsystem_datafileall.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB System files."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of the PDB System Tablespace Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 40 selected: LOSS OF A PDB UNDO TABLESPACE
menu_id_40()
{
        # Read from database the undo datafile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBUNDOTBS"

        # Counting the number of undo datafile found
        count_files "/tmp/pdbundo_datafileall.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. No PDB UNDO Files available."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information on about your PDB  undo tablespace. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbundo_datafileall.tmp" "1"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB UNDO files."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of a PDB UNDO Tablespace Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 41 selected: LOSS OF ALL PDB DATAFILES
menu_id_41()
{
        # Read from database the datafiles's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBALLDATA"

        # Counting the number of spfile found
        count_files "/tmp/pdball_datafile.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Could not find any PDB Datafile."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find any information aboout your PDB datafiles. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdball_datafile.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB datafiles."
                        return "$SUCCESS"
                fi

                # Remove all files
                remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of loss of all PDB Datafiles Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 42 selected: PDB BLOCKR CORRUPTION
menu_id_42()
{
        # Read from database the redo logfile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBFILEHCORRUPTION"

        # Counting the number of redo logfile found
        count_files "/tmp/pdbfilehcorruption.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any PDB File to be Corrupted."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your PDB database files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbfilehcorruption.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB Database file."
                        return "$SUCCESS"
                fi
                exec_files4
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of a PDB Database File Corruption Successful."
        echo
        kill_instance
        echo -e "Instance Terminated!"
        exit 0
}

# Menu 43 selected: LOSS OF A PDB TABLE
menu_id_43()
{
        # Read from database the redo logfile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBTABLE"

        # Counting the number of redo logfile found
        count_files "/tmp/pdbtable.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any PDB table."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your PDB database files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbtable.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB table."
                        return "$SUCCESS"
                fi
                # exec_files
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of Loss of a PDB table Successful."
        echo
        #kill_instance
        #echo -e "Instance Terminated!"
        exit 0
}

# Menu 44 selected: LOSS OF A PDB SCHEMA
menu_id_44()
{
        # Read from database the redo logfile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDBSCHEMA"

        # Counting the number of redo logfile found
        count_files "/tmp/pdbschema.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any PDB schema."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your PDB database files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdbschema.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB schema."
                        return "$SUCCESS"
                fi
                # exec_files
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of Loss of a PDB schema Successful."
        echo
        #kill_instance
        #echo -e "Instance Terminated!"
        exit 0
}

# Menu 45 selected: LOSS OF A PDB
menu_id_45()
{
        # Read from database the redo logfile's location
        # redirecting the output to a tmp file
        files_to_tmp "PDB"

        # Counting the number of redo logfile found
        count_files "/tmp/pdb.tmp"
        return_val=$?
        if [ "$return_val" -eq "0" ]
        then
                ERRMSG="Can not proceed. Unable to find any PDB."
                return "$SUCCESS"
        elif [ "$return_val" -eq "$FAIL" ]
        then
                ERRMSG="Not able to find information about your PDB database files. Be sure your database is up and running."
                return "$SUCCESS"
        else
                # Read just the first line of the file
                read_files "/tmp/pdb.tmp"
                return_val=$?
                if [ "$return_val" -eq "$FAIL" ]
                then
                        ERRMSG="Can not proceed. Program was not able to locate any PDB."
                        return "$SUCCESS"
                fi
                # exec_files
                # Remove all files
                # remove_files "${#ARRAY_OF_FILES[*]}"
        fi
        echo
        echo -e "Simulation of a PDB Loss Successful."
        echo
        # kill_instance
        # echo -e "Instance Terminated!"
        exit 0
}


menu_id_77()
{
# Display the menu.
    show_menu

   # Read the number of menu entered by the user.
     read menu_number

   # Clear any error message.
   ERRMSG=""
                case "$menu_number" in
                        "1"  ) menu_id_01 ;;
                        "2"  ) menu_id_02 ;;
                        "3"  ) menu_id_03 ;;
                        "4"  ) menu_id_04 ;;
                        "5"  ) menu_id_05 ;;
                        "6"  ) menu_id_06 ;;
                        "7"  ) menu_id_07 ;;
                        "8"  ) menu_id_08 ;;
                        "9"  ) menu_id_09 ;;
                        "10" ) menu_id_10 ;;
                        "11" ) menu_id_11 ;;
                        "12" ) menu_id_12 ;;
                        "13" ) menu_id_13 ;;
                        "14" ) menu_id_14 ;;
                        "15" ) menu_id_15 ;;
                        "16" ) menu_id_16 ;;
                        "17" ) menu_id_17 ;;
                        "18" ) menu_id_18 ;;
                        "19" ) menu_id_19 ;;
                        "20" ) menu_id_20 ;;
                        "21" ) menu_id_21 ;;
                        "22" ) menu_id_22 ;;
                        "23" ) menu_id_23 ;;
                        "24" ) menu_id_24 ;;
                        "25" ) menu_id_25 ;;
                        "26" ) menu_id_26 ;;
                        "27" ) menu_id_27 ;;
                        "28" ) menu_id_28 ;;
                        "29" ) menu_id_29 ;;
                        "30" ) menu_id_30 ;;
                        "31" ) menu_id_31 ;;
                        "32" ) menu_id_32 ;;
                        "33" ) menu_id_33 ;;
                        "34" ) menu_id_34 ;;
                        "35" ) menu_id_35 ;;
                        "36" ) menu_id_36 ;;
                        "37" ) menu_id_37 ;;
                        "38" ) menu_id_38 ;;
                        "39" ) menu_id_39 ;;
                        "40" ) menu_id_40 ;;
                        "41" ) menu_id_41 ;;
                        "42" ) menu_id_42 ;;
                        "43" ) menu_id_43 ;;
                        "44" ) menu_id_44 ;;
                        "45" ) menu_id_45 ;;
                        "88" ) menu_id_88 ;;
                        "99" ) menu_id_99 ;;
                        "0" ) break ;;
                         *  ) invalid_choice ;;
                esac
}

menu_id_88()
{
# Display the menu.
    show_menu22

   # Read the number of menu entered by the user.
     read menu_number

   # Clear any error message.
   ERRMSG=""
                case "$menu_number" in
                        "1"  ) menu_id_01 ;;
                        "2"  ) menu_id_02 ;;
                        "3"  ) menu_id_03 ;;
                        "4"  ) menu_id_04 ;;
                        "5"  ) menu_id_05 ;;
                        "6"  ) menu_id_06 ;;
                        "7"  ) menu_id_07 ;;
                        "8"  ) menu_id_08 ;;
                        "9"  ) menu_id_09 ;;
                        "10" ) menu_id_10 ;;
                        "11" ) menu_id_11 ;;
                        "12" ) menu_id_12 ;;
                        "13" ) menu_id_13 ;;
                        "14" ) menu_id_14 ;;
                        "15" ) menu_id_15 ;;
                        "16" ) menu_id_16 ;;
                        "17" ) menu_id_17 ;;
                        "18" ) menu_id_18 ;;
                        "19" ) menu_id_19 ;;
                        "20" ) menu_id_20 ;;
                        "21" ) menu_id_21 ;;
                        "22" ) menu_id_22 ;;
                        "23" ) menu_id_23 ;;
                        "24" ) menu_id_24 ;;
                        "25" ) menu_id_25 ;;
                        "26" ) menu_id_26 ;;
                        "27" ) menu_id_27 ;;
                        "28" ) menu_id_28 ;;
                        "29" ) menu_id_29 ;;
                        "30" ) menu_id_30 ;;
                        "31" ) menu_id_31 ;;
                        "32" ) menu_id_32 ;;
                        "33" ) menu_id_33 ;;
                        "34" ) menu_id_34 ;;
                        "35" ) menu_id_35 ;;
                        "36" ) menu_id_36 ;;
                        "37" ) menu_id_37 ;;
                        "38" ) menu_id_38 ;;
                        "39" ) menu_id_39 ;;
                        "40" ) menu_id_40 ;;
                        "41" ) menu_id_41 ;;
                        "42" ) menu_id_42 ;;
                        "43" ) menu_id_43 ;;
                        "44" ) menu_id_44 ;;
                        "45" ) menu_id_45 ;;
                        "77" ) menu_id_77 ;;
                        "99" ) menu_id_99 ;;
                        "0" ) break ;;
                         *  ) invalid_choice ;;
                esac

}

# Menu 99 selected: PERFORM A CDB RANDOM CRASH SCENARIO
menu_id_99()
{
get_random_number
MENU=$?
exec_menu $MENU
#return "$SUCCESS"
}

#------------------------------------------------------
# Main
#------------------------------------------------------
# Up to this point there are variables and functions.
# The program starts running here.

#checks to see if user is root

# if [ "$(whoami)" != "oracle" ]
if [ "$(whoami)" != "oracle" ]
	then
	  echo "Error: You ARE NOT oracle user!!!!!"
	  exit 1
else
	while true
	do
		# Display the menu.
		show_menu

		# Read the number of menu entered by the user.
		read menu_number

		# Clear any error message.
		ERRMSG=""

		# Execute one of the functions based
		# on the number entered by the user.
		case "$menu_number" in
			"1"  ) menu_id_01 ;;
			"2"  ) menu_id_02 ;;
			"3"  ) menu_id_03 ;;
			"4"  ) menu_id_04 ;;
			"5"  ) menu_id_05 ;;
			"6"  ) menu_id_06 ;;
			"7"  ) menu_id_07 ;;
			"8"  ) menu_id_08 ;;
			"9"  ) menu_id_09 ;;
			"10" ) menu_id_10 ;;
			"11" ) menu_id_11 ;;
			"12" ) menu_id_12 ;;
			"13" ) menu_id_13 ;;
			"14" ) menu_id_14 ;;
			"15" ) menu_id_15 ;;
			"16" ) menu_id_16 ;;
			"17" ) menu_id_17 ;;
			"18" ) menu_id_18 ;;
			"19" ) menu_id_19 ;;
			"20" ) menu_id_20 ;;
			"21" ) menu_id_21 ;;
			"22" ) menu_id_22 ;;
			"23" ) menu_id_23 ;;
			"24" ) menu_id_24 ;;
			"25" ) menu_id_25 ;;
			"26" ) menu_id_26 ;;
			"27" ) menu_id_27 ;;
			"28" ) menu_id_28 ;;
			"29" ) menu_id_29 ;;
			"30" ) menu_id_30 ;;
			"31" ) menu_id_31 ;;
			"32" ) menu_id_32 ;;
			"33" ) menu_id_33 ;;
			"34" ) menu_id_34 ;;
			"35" ) menu_id_35 ;;
			"36" ) menu_id_36 ;;
			"37" ) menu_id_37 ;;
			"38" ) menu_id_38 ;;
			"39" ) menu_id_39 ;;
			"40" ) menu_id_40 ;;
			"41" ) menu_id_41 ;;
			"42" ) menu_id_42 ;;
			"88" ) menu_id_88 ;;
			"99" ) menu_id_99 ;;
			"0" ) break ;;
			 *  ) invalid_choice ;;
		esac
	done
fi


