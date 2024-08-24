#!/bin/bash
# Note:
#   docker entrypoint is watching for slapd process and we need `pkill slapd` before we can restore a backup.
#   this file will create a RESTORE_FLAG before stopping the slapd process
#   as a result, the entrypoint.sh will wait until the RESTORE_FLAG has been removed.
#   ldaprestore.sh is the one in-charge to remove the RESTORE_FLAG after successful execution.

RESTORE_FLAG="/tmp/restoring_db"

# skip process if ldap restore flag already exist, because we also call this file at the top of ldaprestore.sh
if [ -f "${RESTORE_FLAG}" ]; then
    echo "skip $RESTORE_FLAG already exist. Proceed with ldaprestore.sh"
    exit 1
fi

read -p "This operation will stop the slapd.service. Are you sure you want to proceed? [y/N] " response
if [ "$response" != "y" ] && [ "$response" != "Y" ]; then
  echo "cancelled."
  exit 1
fi

touch "$RESTORE_FLAG"
echo "Stopping slapd.."
pkill -SIGTERM slapd
