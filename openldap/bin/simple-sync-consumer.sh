#!/bin/bash
echo "configuring instance as LDAP replica."

missing_env_vars=false

if [ -z "$REPLICA_ID" ]; then
  echo "Error: missing environment variable REPLICA_ID. should be 3 digits. e.g. 100"
  missing_env_vars=true
fi

if [ -z "$REPLICATOR_DN" ]; then
  echo "Error: missing environment variable REPLICATOR_DN. e.g. cn=replicator,dc=example,dc=com"
  missing_env_vars=true
fi

if [ -z "$REPLICA_PROVIDER_HOST" ]; then
  echo "Error: missing environment variable REPLICA_PROVIDER_HOST. e.g. ldap://192.168.8.223"
  missing_env_vars=true
fi

if [ -z "$REPLICA_SEARCHBASE" ]; then
  echo "Error: missing environment variable REPLICA_SEARCHBASE. e.g. dc=example,dc=com"
  missing_env_vars=true
fi

if [ "$missing_env_vars" = true ]; then
  exit 1
fi

read -p "Enter password for $REPLICATOR_DN:" -s REPLICATOR_SECRET

echo "removing provider related configs to avoid conflicts."
echo "remove olcMirrorMode"
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=config
changetype: modify
delete: olcMirrorMode
EOF

echo "remove olcOverlay"
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcOverlay={0}syncprov,olcDatabase={1}mdb,cn=config
changetype: delete
EOF

echo "applying replica configurations.."
if ! ldapsearch -Q -Y EXTERNAL -LLL -H ldapi:/// -b "cn=module{0},cn=config" "(olcModuleLoad=syncprov)" | grep -q "syncprov"; then
    ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov
EOF
fi

ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryUUID eq
-
add: olcSyncrepl
olcSyncrepl: rid=$REPLICA_ID
  provider=$REPLICA_PROVIDER_HOST
  bindmethod=simple
  binddn=$REPLICATOR_DN credentials=$REPLICATOR_SECRET
  searchbase=$REPLICA_SEARCHBASE
  schemachecking=on
  type=refreshAndPersist retry="60 +"
  starttls=critical tls_reqcert=demand
-
add: olcUpdateRef
olcUpdateRef: $REPLICA_PROVIDER_HOST
EOF

echo "done."
