#!/bin/ksh
# check_alert.sh
# Script to see if oracle instance is up
# Script to check Oracle errors in alert log file
# Author    : Biju Thomas
# Created   : 08/05/1997
# Modified  : 12/03/1997
#
# Read /etc/oratab file to get the instance names on this machine and 
# Oracle Home directory
#
#
cat /etc/oratab | while read LINE
do
  case $LINE in
  \#*)            ;;      #comment-line in oratab
  *)
  #       Proceed only if third field is 'Y'.
  if [ "`echo $LINE | awk -F: '{print $3}' -`" = "Y" ] ; then
    ORACLE_SID=`echo $LINE | awk -F: '{print $1}' -`
    if [ "$ORACLE_SID" = '*' ] ; then
      ORACLE_SID=""
    fi
    export ORACLE_SID
    ORACLE_HOME=`echo $LINE | awk -F: '{print $2}' -`
    export ORACLE_HOME
#
#
# Perform the test using the ORACLE_SID
#
#
  werr=0
  wdate=`date '+%m%d'`
  wlogfile=/tmp/calertlog.$ORACLE_SID
  werrfile=/tmp/calerterr.$ORACLE_SID
#
# Initialize message files
#
  echo "**********************************************************************" >  $wlogfile
  echo "**********************************************************************" >  $werrfile
#
# Verfiy if required Oracle Environment Variables are Available
#
  if test `env | grep ORACLE_SID | wc -l` -ne 1
  then
     werr=1
     echo "Environment Variable ORACLE_SID Not Available \n" >> $werrfile
     echo "**********************************************************************" >>  $werrfile
  fi
  if test `env | grep ORACLE_HOME | wc -l` -ne 1
  then
     werr=1
     echo "Environment Variable ORACLE_HOME Not Available \n" >> $werrfile
     echo "**********************************************************************" >>  $werrfile
  fi
#
# If Environment variables not available discontinue process and inform DBAOC
#
  if test $werr -eq 1
  then
     echo "Date        : "`date '+%m/%d/%y %X %A '` >> $werrfile
     echo "Database    : "$ORACLE_SID >> $werrfile
     echo "Server      : "`uname -n` >> $werrfile
     echo "**********************************************************************" >>  $werrfile
     mailx -s "Errors found in routine alert file checkup" "tbiju@hotmail.com" > /dev/null < $werrfile
     continue
  fi
#
#  Check for instance availability
#
  if test -f ${ORACLE_HOME}/dbs/sgadef${ORACLE_SID}.dbf
  then
     echo "Oracle up and running" >> $wlogfile
  else
     echo "Oracle Not Available $ORACLE_SID" >> $werrfile
     echo "**********************************************************************" >>  $werrfile
  fi
#
#
# Check the alert log file for any errors 
#
walertfile=/ora_dump/${ORACLE_SID}/bdump/alert_${ORACLE_SID}
  if test -f ${walertfile}.log
  then
    if test `grep "ORA-" ${walertfile}.log | wc -l` -ne 0
    then
       echo "Following errors written to the Alert log file. Please verify" >> $werrfile
       grep "ORA-" ${walertfile}.log >> $werrfile
       echo "**********************************************************************" >>  $werrfile
       cat ${walertfile}.log >> ${walertfile}.${wdate}
       rm ${walertfile}.log
       touch ${walertfile}.log
    else
       echo "No Errors in the Alert log file" >> $wlogfile
    fi
#
#
#
# Check if errors encountered, if yes send mail to DBA
#
    if test `cat $werrfile | wc -l` -ne 1
    then
       echo "**********************************************************************" >>  $werrfile
       echo "Date        : "`date '+%m/%d/%y %X %A '` >> $werrfile
       echo "Database    : "$ORACLE_SID >> $werrfile
       echo "Server      : "`uname -n` >> $werrfile
       echo "**********************************************************************" >>  $werrfile
       mailx -s "Errors found in routine alert file checkup - $ORACLE_SID" "tbiju@hotmail.com" > /dev/null < $werrfile
       continue
    else
       echo "Successful completion of routine checkup" >> $wlogfile
       echo "No Errors / Alerts Encountered" >> $wlogfile
       echo "**********************************************************************" >>  $wlogfile
       continue
    fi
  fi
  fi
  esac
done
#
# End of Script
