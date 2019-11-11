#!/bin/bash
#################################
#################################
### Script for backup configs ###
#################################
#################################
#
## Backup Targets: /root/.my.cnf /etc/mysql/ /etc/my.cnf /var/lib/pgsql/*/data/*.conf /etc/postgresql/ /etc/mongod.conf /etc/sysconfig/memcached /etc/memcached.conf /etc/redis.conf /etc/redis* /etc/sysconfig/elasticsearch /etc/default/elasticsearch /etc/elasticsearch/ /etc/sphinx /etc/clickhouse-server/ /etc/clickhouse-client/ /etc/supervisor/ /etc/rabbit_definitions.json /etc/fstab /etc/crontab /var/spool/cron /etc/ssh/ /etc/sudoers /etc/sudoers.d/ /usr/local/etc/ /etc/pkg_list /tmp/iptables_output.txt /etc/iptables/ /etc/sysconfig/iptables /etc/ps_output.txt /etc/lvm* /etc/ldap /etc/consul* /etc/openvpn/ /root/.ssh/ /etc/smartmontools/ /etc/sysconfig/network-scripts /tmp/ip_output.txt /etc/lsyncd.conf /etc/docker/ /etc/libvirt/ /etc/xen/ /etc/vz/ /etc/nginx/ /etc/httpd/ /etc/apache2/ /etc/php* /etc/ssl/ /etc/letsencrypt/ /root/.acme.sh/ /etc/kafka/ /etc/postfix/ /home/bitrix/.msmtprc /var/spool/mail /usr/share/roundcubemail/ /etc/exim* /etc/opendkim.conf /etc/opendkim/ /etc/nagios/ /etc/zabbix/ /etc/named* /var/named/ /etc/haproxy/ /etc/3proxy.cfg /etc/pure-ftpd/ /etc/GeoIP.conf /etc/geoip* /etc/rabbitmq/ /root/scripts/ /root/bin/  ##  
#
export TZ=Europe/Moscow
DT=$(date +"%Y-%m-%d-%H%M%S")
LOG=/var/log/backup/confs.log
ERROR_LOG=/var/log/backup/confs_error.log
PROJECT="some_project"
SERVER="server_name"
FN=confs_${DT}.tgz
DIR=/backup/confs
RPATH=/backup/${SERVER}/confs
SSH="${PROJECT}@backup_server"
CONNECT="/usr/bin/ssh -i /root/.ssh/backup_rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3 ${SSH}"
lockdir=/var/tmp/confs_backup
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
        die confs_default_uploading
      fi
    }
  done
}

if ( /bin/mkdir ${lockdir} ) 2> /dev/null; then
  /bin/echo $$ > $pidfile
  trap '/bin/rm -rf "$lockdir"; exit $?' INT TERM EXIT

  ###################################################################
  ####################### Delete old backups ########################
  /root/scripts/backups/delete_old_backup.sh $DIR ".*confs_[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}.*tgz" 1 >> ${LOG}
  ###################################################################
  /bin/mkdir -p $DIR
  cd $DIR

  ########################## Create backup ##########################
  /bin/echo "[`date`] backup confs started" >>$LOG

  dpkg -l > /etc/pkg_list 2>>$LOG

  ip a > /tmp/ip_output.txt 2>>$LOG
  iptables-save > /tmp/iptables_output.txt 2>>$LOG
  ps auxwwf > /etc/ps_output.txt 2>>$LOG
  /bin/mount -l > /etc/mount_output.txt 2>>$LOG
  if [ "$(netstat -tlpn | grep ':15672' | wc -l)" -ne "0" ] && [ "$(ps aux | grep -c rabbitm[q])" -ne "0" ]; then
         if [ -f ~/.rabbitpass ]; then
             RABBITPASS="$(/bin/cat ~/.rabbitpass)"
            /usr/bin/curl -u ${RABBITPASS} -X GET http://127.0.0.1:15672/api/definitions > /etc/rabbit_definitions.json 2>>$LOG
        else
             /usr/bin/curl -u guest:guest -X GET http://127.0.0.1:15672/api/definitions > /etc/rabbit_definitions.json 2>>$LOG
        fi
        if [ "$(grep -c 'not_authorised' /etc/rabbit_definitions.json)" -ne "0" ]; then
            /bin/echo "[`date`] confs_rabbitmq_backup_failed" >> ${ERROR_LOG}
        fi
  fi 2>>$LOG

  TARGETS=(/root/.my.cnf /etc/mysql/ /etc/my.cnf /var/lib/pgsql/*/data/*.conf /etc/postgresql/ /etc/mongod.conf /etc/sysconfig/memcached /etc/memcached.conf /etc/redis.conf /etc/redis* /etc/sysconfig/elasticsearch /etc/default/elasticsearch /etc/elasticsearch/ /etc/sphinx /etc/clickhouse-server/ /etc/clickhouse-client/ /etc/supervisor/ /etc/rabbit_definitions.json /etc/fstab /etc/crontab /var/spool/cron /etc/ssh/ /etc/sudoers /etc/sudoers.d/ /usr/local/etc/ /etc/pkg_list /tmp/iptables_output.txt /etc/iptables/ /etc/sysconfig/iptables /etc/ps_output.txt /etc/lvm* /etc/ldap /etc/consul* /etc/openvpn/ /root/.ssh/ /etc/smartmontools/ /etc/sysconfig/network-scripts /tmp/ip_output.txt /etc/lsyncd.conf /etc/docker/ /etc/libvirt/ /etc/xen/ /etc/vz/ /etc/nginx/ /etc/httpd/ /etc/apache2/ /etc/php* /etc/ssl/ /etc/letsencrypt/ /root/.acme.sh/ /etc/kafka/ /etc/postfix/ /home/bitrix/.msmtprc /var/spool/mail /usr/share/roundcubemail/ /etc/exim* /etc/opendkim.conf /etc/opendkim/ /etc/nagios/ /etc/zabbix/ /etc/named* /var/named/ /etc/haproxy/ /etc/3proxy.cfg /etc/pure-ftpd/ /etc/GeoIP.conf /etc/geoip* /etc/rabbitmq/ /root/scripts/ /root/bin/ )
  for I in "${TARGETS[@]}";do
        if [[ $(ls ${I} 2>/dev/null) ]]; then
          REAL_TARGETS+=("${I}")
        fi
  done

  /bin/tar czhpf - --exclude='/etc/httpd/logs' "${REAL_TARGETS[@]}" > ${DIR}/${FN} 2>>$LOG || die_if_tar_failed  confs_tarring

  ###################################################################
  #################### Upload backup to storage #####################
  /bin/echo "[`date`] uploading to rsync confs started" >>$LOG
  ${CONNECT} "/bin/mkdir -p ${RPATH}" >> /dev/null 2>&1
    retry /usr/bin/rsync -a -e 'ssh -i /root/.ssh/backup_rsa -o StrictHostKeyChecking=no -o ConnectionAttempts=3' ${DIR}/${FN} ${SSH}:${RPATH} >>$LOG 2>&1

  /bin/echo "[`date`] uploading to rsync confs finished" >>$LOG
  ###################################################################

  /bin/rm -rf "$lockdir"
  trap - INT TERM EXIT
else
  /bin/echo "Lock Exists: $lockdir owned by $(/bin/cat $pidfile)" >>$LOG && die confs_default_lock
fi
