#!/bin/bash
RESTORE_FLAG="/tmp/restoring_db"

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <SEARCHBASE> <BACKUP_PATH>"
  exit 1
fi

missing_files=false
SEARCHBASE="$1"
BACKUP_PATH="$2"
CONFIG_LDIF="${BACKUP_PATH}/config.ldif"
DOMAIN_LDIF="${BACKUP_PATH}/${SEARCHBASE}.ldif"

read -p "This operation will delete the current database to restore the backup in ${BACKUP_PATH}. Are you sure you want to proceed? [y/N] " response
if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
  echo "cancelled."
  exit 1
fi

if [ -f "${CONFIG_LDIF}" ]; then
  echo "found ${CONFIG_LDIF}"
else
  echo "${CONFIG_LDIF} not found."
  missing_files=true
fi

if [ -f "${DOMAIN_LDIF}" ]; then
  echo "found ${DOMAIN_LDIF}"
else
  echo "${DOMAIN_LDIF} not found."
  missing_files=true
fi

if [ "$missing_files" = true ]; then
  exit 1
fi

if pgrep slapd > /dev/null; then
  echo "WARN: slapd is running. This operation requires suspension of ldap process. Please re-run the restore command."
  ldapsuspend.sh
fi

if [ -n "$(ls -l /var/lib/ldap/* 2>/dev/null)" ] || [ -n "$(ls -l /etc/ldap/slapd.d/* 2>/dev/null)" ]; then
  echo "Removing existing db.."
  rm -rf /etc/ldap/slapd.d/* /var/lib/ldap/*
fi

echo "Restoring LDAP database from backup.."
slapadd -F /etc/ldap/slapd.d -b cn=config -l $CONFIG_LDIF
slapadd -F /etc/ldap/slapd.d -b $SEARCHBASE -l $DOMAIN_LDIF
chown -R openldap:openldap /etc/ldap/slapd.d/
chown -R openldap:openldap /var/lib/ldap/
rm -f "$RESTORE_FLAG"
