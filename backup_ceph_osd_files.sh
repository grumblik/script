#!/bin/bash
###############################
###############################
### Script for backup files ###
###############################
###############################

## Backup Targets: /var/lib/ceph/osd/ ## export TZ=Europe/Moscow

export TZ=Europe/Moscow
DT=$(date +"%Y-%m-%d-%H%M%S")
LOG=/var/log/backup/confs.log
ERROR_LOG=/var/log/backup/confs_error.log
PROJECT="some_project"
SERVER="server_name"
FN=files_${DT}.tgz
DIR=/backup/files
RPATH=/backup/${SERVER}/files
SSH="${PROJECT}@backup_server"
CONNECT="/usr/bin/ssh -i /root/.ssh/backup_rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH}"
lockdir=/var/tmp/files_backup
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

retry () {
  local n=0
  while true; do
    "$@" && break || {
      if [[ $n -lt 3 ]]; then
        ((n++))
        echo "Command failed. Attempt $n/3"
        sleep 1m;
      else
        die files_uploading
      fi
    }
  done
}

if ( /bin/mkdir ${lockdir} ) 2> /dev/null; then
  /bin/echo $$ > $pidfile
  trap '/bin/rm -rf "$lockdir"; exit $?' INT TERM EXIT

  ###################################################################
  ####################### Delete old backups ########################
  ./delete_old_backup.sh $DIR ".*files_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.*tgz" 1 >> ${LOG}
  ###################################################################
  /bin/mkdir -p $DIR
  cd $DIR

  ########################## Create backup ##########################
  /bin/echo "[`date`] backup files started" >>$LOG
  /bin/tar czhpf - /var/lib/ceph/osd/ 2>>$LOG | retry ssh -i /root/.ssh/backup_rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH} "/bin/cat -> ${RPATH}/${FN}" >>$LOG 2>&1 || die_if_tar_failed files_streaming
  /bin/echo "[`date`] stream files finished" >>$LOG  ################################################################### 

  /bin/rm -rf "$lockdir"
  trap - INT TERM EXIT
else
  /bin/echo "Lock Exists: $lockdir owned by $(/bin/cat $pidfile)" >>$LOG && die files_lock
fi
