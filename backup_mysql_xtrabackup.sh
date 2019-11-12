#!/bin/bash
#############################################
### Script for backup mysql by xtrabackup ###
#############################################

export TZ=Europe/Moscow
DT=$(date +"%Y-%m-%d-%H%M%S")
LOG=/var/log/backup/mysql.log
ERROR_LOG=/var/log/backup/mysql_error.log
PROJECT="some_project"
SERVER="some_server"
FN=mysql_default_${DT}.tgz
DIR=/backup/mysql
RPATH=/backup/${SERVER}/mysql
SSH="${PROJECT}@backup_server"
CONNECT="/bin/ssh -i /root/.ssh/rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH}"
lockdir=/var/tmp/mysql_backup
pidfile=${lockdir}/pid

die_if_tar_failed() {
  exitcode=$?
  #1 is ok
  [ $exitcode -eq 0 -o $exitcode -eq 1 ] && return 0
  /bin/echo `date +"%Y-%m-%d-%H%M%S"` $1 exitcode $exitcode >>${ERROR_LOG}
  exit 1
}

die() {
  exitcode=$?
  /bin/echo `date +"%Y-%m-%d-%H%M%S"` $1 exitcode $exitcode >>${ERROR_LOG}
  exit 1
}

check_in() {
if [ -z "`tail -2 ${LOG} | grep 'completed OK!'`" ]
then
 /bin/echo `date +"%Y-%m-%d-%H%M%S"` $1 >> ${ERROR_LOG}
 exit 1
 fi
}

retry () {
  local n=0
  while true; do
    "$@" && break || {
      if [[ $n -lt 3 ]]; then
        ((n++))
        echo "Command failed. Attempt $n/3"
        sleep 1m;
      else
        die mysql_uploading
      fi
    }
  done
}

if ( /bin/mkdir ${lockdir} ) 2> /dev/null; then
  /bin/echo $$ > $pidfile
  trap '/bin/rm -rf "$lockdir"; exit $?' INT TERM EXIT

  ###################################################################
  ####################### Delete old backups ########################
  delete_old_backup.sh $DIR ".*mysql_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.*tgz" 1 >> ${LOG}
  ###################################################################
  /bin/mkdir -p $DIR
  cd $DIR

    WEEKDAY=$(date +'%w')
  if [ ${WEEKDAY} = "6" ]; then
    echo "[`date`] starting logrotate force" >>$LOG
    /usr/sbin/logrotate -f /backup/mysql_logrotate
  fi

  MYCNF=""
  if [ -f "/root/.my.cnf" ]; then
    MYCNF="--defaults-extra-file=/root/.my.cnf"
  else
    if [ -f "/etc/mysql/debian.cnf" ];then
      MYCNF="--defaults-extra-file=/etc/mysql/debian.cnf"
    fi
  fi
  echo "===================================" >>$LOG
  echo "[`date`] doing databases list default" >>$LOG

# Если в "defaults-file" не задан socket, то он берется из "defaults-extra-file"
  creds="$(echo ${MYCNF} | sed 's/extra\-//') $(echo $(if [ $(mysql $(echo ${MYCNF} | sed 's/extra\-//') --print-defaults | tr ' ' '\n' | grep socket | wc -l) == "0" ]; then echo $(mysql ${MYCNF} --print-defaults | tr " " "\n" | grep socket); fi))"

  echo "SELECT table_schema ,sum(data_length+index_length) FROM information_schema.TABLES GROUP BY table_schema;" | mysql ${creds} -N > ${DIR}/default_databaseslist.txt 2>> /dev/null
    rsync -a -e 'ssh -i /root/.ssh/itsumma_backup_rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3' ${DIR}/default_databaseslist.txt ${SSH}:${RPATH} >>$LOG 2>&1
  # Slave is running check
  if [ "$(mysql ${creds} -e 'show slave status\G'| wc -l | tr -d ' ')" != "0" ] && [ "$(mysql ${creds} -e 'show slave status\G' | grep -i Slave_IO_Running | grep -c Yes)" == "0" ] && [ "$(mysql ${creds} -e 'show slave status\G' | grep -i Slave_SQL_Running | grep -c Yes)" == "0" ]; then
       echo "[`date`] SLAVE IS NOT RUNNING!" >> ${ERROR_LOG}
  fi

  ########################## Create backup ##########################
  ulimit -n 102400

  /bin/echo "[`date`] backup mysql xtrabackup started" >>$LOG

  innobackupex ${MYCNF}  --slave-info --no-timestamp --stream=tar ./ 2>> $LOG | gzip -c | retry ssh -i /root/.ssh/rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH} "/bin/cat -> ${RPATH}/${FN}" >>$LOG 2>&1 || die_if_tar_failed mysql_streaming; check_in innobackupex
  /bin/echo "[`date`] stream mysql xtrabackup finished" >>$LOG
  ###################################################################

  /bin/rm -rf "$lockdir"
  trap - INT TERM EXIT
else
  /bin/echo "Lock Exists: $lockdir owned by $(/bin/cat $pidfile)" >>$LOG && die mysql_lock
fi
