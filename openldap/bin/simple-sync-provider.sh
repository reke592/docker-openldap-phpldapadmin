#!/bin/bash
echo "Configure this instance as LDAP provider for replicas."
read -p "Are you sure the old primary LDAP service is not running? [y/N] " response
if [ "$response" != "y" && "$response" != "Y" ]; then
  echo "Please ensure the old primary LDAP service is stopped before proceeding."
  exit 1
fi

echo "removing replica related configs to this instance to avoid conflicts.."
echo "remove olcSyncrepl"
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
delete: olcSyncrepl
EOF

echo "remove olcUpdateRef"
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
delete: olcUpdateRef
EOF

echo "Promoting this instance to be the new provider.."
echo "Describe how often the master writes out the context CSN to the database for replicas, whichever comes first."
read -p "olcSpCheckpoint writes (e.g. 100): " olcSpCheckpointWrites
read -p "olcSpCheckpoint minutes (e.g. 10): " olcSpCheckpointMinutes

echo "Describe how many recent operations are stored in session log of the provider. \
This is useful when a replica reconnects to the provider after a temporary disconnection. \
Instead of performing a full resync, the replica can use the session log to quickly catch up on any changes that occured during the disconnection."
read -p "olcSpSessionLog (e.g. 100): " olcSpSessionLog

ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=config
changetype: modify
replace: olcServerID
olcServerID: 1
EOF

echo "clear olcDBIndex"
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
delete: olcDbIndex
EOF

# echo "re-calculate index"
# ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
# dn: olcDatabase={1}mdb,cn=config
# changetype: modify
# add: olcDbIndex
# olcDbIndex: objectClass eq
# olcDbIndex: cn,sn,uid eq,pres,sub
# olcDbIndex: entryUUID eq
# olcDbIndex: entryCSN eq
# EOF

ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
# Add indexes to the frontend db.
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryCSN eq
-
add: olcDbIndex
olcDbIndex: entryUUID eq
EOF

# Load the syncprov module
echo "applying syncprov configurations.."
if ! ldapsearch -Q -Y EXTERNAL -LLL -H ldapi:/// -b "cn=module{0},cn=config" "(olcModuleLoad=syncprov)" | grep -q "syncprov"; then
    ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov
EOF
fi

# syncrepl Provider for primary db
if ! ldapsearch -Q -Y EXTERNAL -LLL -H ldapi:/// -b "olcDatabase={1}mdb,cn=config" "(olcOverlay=syncprov)" | grep -q "syncprov"; then
  echo "adding olcOverlay.."
  ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpCheckpoint: $olcSpCheckpointWrites $olcSpCheckpointMinutes
olcSpSessionLog: $olcSpSessionLog
EOF
else
  echo "updating olcSpCheckpoint and olcSpSessionLog"
  ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcOverlay={0}syncprov,olcDatabase={1}mdb,cn=config
changetype: modify
replace: olcSpCheckpoint
olcSpCheckpoint: $olcSpCheckpointWrites $olcSpCheckpointMinutes
-
replace: olcSpSessionLog
olcSpSessionLog: $olcSpSessionLog
EOF
fi


echo "done."
