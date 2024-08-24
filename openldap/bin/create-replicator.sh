#!/bin/bash

echo "Admin dn (e.g. cn=admin,dc=example,dc=com): "
read ADMIN_DN

echo "Enter dn for replicator (e.g. cn=replicator,dc=example,dc=com): "
read REPLICATOR_DN

echo "adding security object $REPLICATOR_DN"
ldapadd -x -ZZ -D $ADMIN_DN -W <<EOF
dn: $REPLICATOR_DN
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: replicator
description: Replication user
userPassword: {CRYPT}x
EOF

echo "Enter new password for $REPLICATOR_DN"
ldappasswd -x -ZZ -D $ADMIN_DN -W -S $REPLICATOR_DN

echo "updating ACL for replicator user.."
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to *
  by dn.exact="$REPLICATOR_DN" read
  by * break
-
add: olcLimits
olcLimits: dn.exact="$REPLICATOR_DN"
  time.soft=unlimited time.hard=unlimited
  size.soft=unlimited size.hard=unlimited
EOF

echo "done."
