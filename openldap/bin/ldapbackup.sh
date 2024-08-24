#!/bin/bash
set -e

if [ -z "$1" ]; then
  echo "Usage: $0 <SEARCHBASE>"
  exit 1
fi

SEARCHBASE="$1"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
BACKUP_PATH=/mnt/backup
BACKUP_FOLDER="$BACKUP_PATH/backup_$TIMESTAMP"

echo "creating backup $BACKUP_FOLDER"
mkdir -p "$BACKUP_FOLDER"
nice slapcat -b cn=config > ${BACKUP_FOLDER}/config.ldif
nice slapcat -b ${SEARCHBASE} > ${BACKUP_FOLDER}/${SEARCHBASE}.ldif
chown root:root ${BACKUP_FOLDER}/*
chmod 600 ${BACKUP_FOLDER}/*.ldif
