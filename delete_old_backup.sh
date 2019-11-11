#!/bin/bash
export TZ=Europe/Moscow
PATH_BACKUP=$1
PATTERN=$2
SAVE_DAYS=$3
TIME=$(date +%s)
let "CHECK_OFSET = $SAVE_DAYS * 86400"

BACKUP_FILES=$(find  ${PATH_BACKUP} -maxdepth 1 -mindepth 1 -type f -regextype sed -regex ${PATTERN} 2>/dev/null)

if [ ${#BACKUP_FILES[@]} -eq 0 ];then
    echo "Backups not found"
else
    for FILE in ${BACKUP_FILES[@]}; do
        TIME_STRING=$(echo $FILE | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}-[0-9]\{6\}' | sed -r -e 's/(^.{10})-/\1 /;s/^.{13}/&:/;s/^.{16}/&:/')
        TIME_CREATE=$(date -d "${TIME_STRING}" +%s)
        #echo $FILE
        #echo $TIME_CREATE
        let "OFSET = ${TIME} - ${TIME_CREATE}"
        #echo "Storage time: ${CHECK_OFSET}"
        #echo "Time of creation: ${TIME_CREATE}"
        #echo "Time: ${TIME}"
        #echo "Time ofset: ${OFSET}"
        if [ "${OFSET}" -ge "${CHECK_OFSET}" ]; then
            echo "Delete file: ${FILE}"
            /bin/rm -f ${FILE}
        fi
    done
fi
