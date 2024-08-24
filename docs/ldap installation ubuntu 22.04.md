## LDAP installation Ubuntu 22.04

### Install LDAP

```sh
sudo apt update
sudo apt upgrade -y
sudo apt install unattended-upgrades
sudo apt-get install slapd ldap-utils
```

Reconfigure slapd

```sh
sudo dpkg-reconfigure slapd
```

- dns domain name: example.com
- organization name: example
- enter the administrator password
- choose database MDB if possible

Modify LDAP configuration

```sh
sudo vi /etc/ldap/ldap.conf
```

- uncomment and set, `BASE dc=example,dc=com`
- uncomment and set, `URI ldap://192.168.1.111` (can be an IP address also, SHOULD match the DNS in SSL)

Retart the `slapd` and verify installation

```sh
sudo systemctl restart slapd
sudo systemctl status slapd
ldapsearch -x
```

### Install PHP LDAP Admin

the last phpldapadmin release for Ubuntu 22.04 is old version `1.2.6.3-0.2`, we need to manually install the debian package `1.2.6.3-0.3`

```sh
wget http://archive.ubuntu.com/ubuntu/pool/universe/p/phpldapadmin/phpldapadmin_1.2.6.3-0.3_all.deb
sudo dpkg -i phpldapadmin_1.2.6.3-0.3_all.deb
```

modify phpldapadmin configuration

- search for pattern `$servers->`
- modify the server name: `LDAP Server`
- server base: `array('dc=example,dc=com')`
- search for pattern `hide_template_warning`, uncomment the line and set the value `true`.
- search for pattern `anon_bind`, uncomment the line and set the value to `false`.

```sh
sudo vi /etc/phpldapadmin/config.php
```

### PHP LDAP Admin : Directory structure

- create Organization Units: `groups`, `people`
- select `ou: groups` add a generic POSIX group `Users`, `Admin`
  - a Portable Operating System Interface (POSIX) standard is for Linux and Unix, in context of LDAP we use them for user directory access permissions.
- select `ou: people` add a generic User Account, this account requires a default group. always select `Users`.
- to include a cn in people in a POSIX group, we use the `memberUid` attribute.
  - select `cn: Admin, ou: groups` add new attribute `memberUid` set the value to the username (uid) of the target user.

```
root: example.com
'-- ou: groups
|   '-- cn: Admin
|   '-- cn: Dev
|   '-- cn: DevOps
|   '-- cn: Management
|   '-- cn: QA
|   '-- cn: Users
'-- ou: people
    '-- cn: Same Employee
    '-- ...
```

### LDAP

list all POSIX account

```sh
ldapsearch -x -LLL -H ldap:/// -D "cn=admin,dc=example,dc=com" -W -b "dc=example,dc=com" "objectClass=posixAccount" uid cn
```

test credentials

```sh
ldapwhoami -vvv -H ldap:/// -D 'cn=Erric Rapsing,ou=people,dc=example,dc=com' -x -W
```

show slapd config DIT.

```sh
sudo ldapsearch -Q -LLL -Y EXTERNAL -H ldapi:/// -b cn=config dn
```

Where the entries mean the following:

- cn=config: Global settings
- cn=module{0},cn=config: A dynamically loaded module
- cn=schema,cn=config: Contains hard-coded system-level schema
- cn={0}core,cn=schema,cn=config: The hard-coded core schema
- cn={1}cosine,cn=schema,cn=config: The Cosine schema
- cn={2}nis,cn=schema,cn=config: The Network Information Services (NIS) schema
- cn={3}inetorgperson,cn=schema,cn=config: The InetOrgPerson schema
- olcDatabase={-1}frontend,cn=config: Frontend database, default settings for other databases
- olcDatabase={0}config,cn=config: slapd configuration database (cn=config)
- olcDatabase={1}mdb,cn=config: Your database instance (dc=example,dc=com)

using `ldapsearch` to query DN and object attributes

```sh
ldapsearch -x -LLL -H ldap:/// -b SEARCH_BASE [specific_attributes...]
```

show DIT from base `dc=example,dc=com`

```sh
ldapsearch -x -LLL -H ldap:/// -b dc=example,dc=com dn
```

list all users, include uid in result

```sh
ldapsearch -x -LLL -H ldap:/// -b ou=people,dc=example,dc=com dn uid
```

list all group and members

```sh
ldapsearch -x -LLL -H ldap:/// -b ou=groups,dc=example,dc=com dn memberUid
```

## Server Hardening

- TODO: USE sha512 encryption for POSIX account passwords

### enable LDAPS (TLS)

install certutils

```sh
sudo apt install gnutls-bin ssl-cert
```

create private key for Certificate Authority

```sh
sudo certtool --generate-privkey --bits 4096 --outfile /etc/ssl/private/ldap1.pem
```

create template file `/etc/ssl/ca.info` to define the CA:

```
cn = example
ca
cert_signing_key
expiration_days = 3650
```

create the self-signed CA certificate

```sh
sudo certtool --generate-self-signed \
--load-privkey /etc/ssl/private/ldap1.pem \
--template /etc/ssl/ca.info \
--outfile /usr/local/share/ca-certificates/ldap1.crt
```

> Note:
> Yes, the --outfile path is correct. We are writing the CA certificate to /usr/local/share/ca-certificates. This is where update-ca-certificates will pick up trusted local CAs from. To pick up CAs from /usr/share/ca-certificates, a call to dpkg-reconfigure ca-certificates is necessary.

run `update-ca-certificates` to add the new CA certificate to the list of trusted CAs.  
this also creates a /etc/ssl/certs/ldap1.pem symplink pointing to the real file in /usr/local/share/ca-certificates.

```sh
sudo update-ca-certificates
```

make a private key for the server

```sh
sudo certtool --generate-privkey \
--bits 2048
--outfile /etc/ldap/ldap1_slapd_key.pem
```

create `/etc/ssl/ldap1.info` template for the LDAP server certificate.

```
organization = example
cn = 192.168.1.111
tls_www_server
encryption_key
signing_key
expiration_days = 1825
```

create the server's certificate

```sh
sudo certtool --generate-certificate \
--load-privkey /etc/ldap/ldap1_slapd_key.pem \
--load-ca-certificate /etc/ssl/certs/ldap1.pem \
--load-ca-privkey /etc/ssl/private/ldap1.pem \
--template /etc/ssl/ldap1.info \
--outfile /etc/ldap/ldap1_slapd_cert.pem
```

adjust the permission and ownership of the private key

```sh
sudo chgrp openldap /etc/ldap/ldap1_slapd_key.pem
sudo chmod 0640 /etc/ldap/ldap1_slapd_key.pem
```

create the file `/etc/ldap/certinfo.ldif` with the following contents

```
dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/ldap1.pem
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ldap1_slapd_cert.pem
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ldap1_slapd_key.pem
```

use the `ldapmodify` command to tell slapd about the TLS work via slapd-config database:

```sh
sudo ldapmodify -Y EXTERNAL -H ldapi:/// -f certinfo.ldif
```

edit `/etc/default/slapd` to enable LDAPS (LDAP over SSL).

```
SLAPD_SERVICES="ldap:/// ldapi:/// ldaps:///"
```

restart slapd

```sh
sudo systemctl restart slapd
```

Test StartTLS:

```sh
ldapwhoami -x -ZZ -H ldap:///
```

Test LDAPS:

```sh
ldapwhoami -x -H ldaps:///
```

## Disaster Recovery

- TODO: Backup LDAP configs
- TODO: Restoration procedure

### Master-Slave Replication

First we need to create a replication user `replicator.ldif`.

```
dn: cn=replicator,dc=example,dc=com
objectClass: simpleSecurityObject
objectClass: organizationalRole
cn: replicator
description: Replication user
userPassword: {CRYPT}x
```

Then add it with `ldapadd`:

```sh
ldapadd -x -ZZ -D cn=admin,dc=example,dc=com -W -f replicator.ldif
```

Now set a password for it with `ldappasswd`:

```sh
ldappasswd -x -ZZ -D cn=admin,dc=example,dc=com -W -S cn=replicator,dc=example,dc=com
```

The next setp is to give this replication user the correct privileges. i.e.:

- Read access to the content that we want to replicated
- No search limits on this content
  For that we need to update the ACLs on the provider. Since ordering matters, first check what the existing ACLs look like on the dc=example,dc=com tree:

```sh
sudo ldapsearch -Q -Y EXTERNAL -H ldapi:/// -LLL -b cn=config '(olcSuffix=dc=example,dc=com)' olcAccess
```

What we need is to insert a new rule before the first one, and also adjust the limits for the replicator user. Prepare the `replicator-acl-limits.ldif` file with this content:

```
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcAccess
olcAccess: {0}to *
  by dn.exact="cn=replicator,dc=example,dc=com" read
  by * break
-
add: olcLimits
olcLimits: dn.exact="cn=replicator,dc=example,dc=com"
  time.soft=unlimited time.hard=unlimited
  size.soft=unlimited size.hard=unlimited
```

And add it to the server

```sh
sudo ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f replicator-acl-limits.ldif
```

### Provider configuration - standard replication

The remaining configuration for the provider using standard replication is to add the `syncprov` overlay on top of the `dc=example,dc=com` database.  
Create a file called `provider_simple_sync.ldif` with this content:

```
# Add indexes to the frontend db.
dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryCSN eq
-
add: olcDbIndex
olcDbIndex: entryUUID eq

# Load the syncprov module
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov

# syncrepl Provider for primary db
dn: olcOverlay=syncprov,olcDatabase={1}mdb,cn=config
changetype: add
objectClass: olcOverlayConfig
objectClass: olcSyncProvConfig
olcOverlay: syncprov
olcSpCheckpoint: 100 10
olcSpSessionLog: 100
```

> Customisation warning:
> The LDIF above has some parameters that you should review before deploying in production on your directory.  
> In particular – olcSpCheckpoint and olcSpSessionLog.
> Please see the [slapo-syncprov(5) man page](http://manpages.ubuntu.com/manpages/man5/slapo-syncprov.5.html?_ga=2.104481344.1583623178.1723530125-468803355.1713626168&_gl=1*1d8hqx3*_gcl_au*MjA4MzUzODE5MC4xNzIyNDEwMDI3). In general, olcSpSessionLog should be equal to (or preferably larger than) the number of entries in your directory.  
> Also see [ITS #8125](https://www.openldap.org/its/index.cgi/?findid=8125) for details on an existing bug.

Add the new content:

```sh
sudo ldapadd -Q -Y EXTERNAL -H ldapi:/// -f provider_simple_sync.ldif
```

The Provider is now configured.

### Consumer configuration - standard replication

Install the software by going through the installation steps _(see ref links)_.  
Make sure schemas and the database suffix are the same, and enable TLS _(see ref links)_.  
When using self-signed SSL

- create directory in ldap1 server, e.g.: ~/ldap2
- generate private key for ldap2
- create certificate for ldap2 under ldap1 root CA
- use `scp` to transfer the generated certificate, private key and ldap1 root CA to consumer server

Create an LDIF file with the followin contents and name it `consumer_simple_sync.ldif`

```
dn: cn=module{0},cn=config
changetype: modify
add: olcModuleLoad
olcModuleLoad: syncprov

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: entryUUID eq
-
add: olcSyncrepl
olcSyncrepl: rid=0
  provider=ldap://192.168.1.111
  bindmethod=simple
  binddn="cn=replicator,dc=example,dc=com" credentials=<secret>
  searchbase="dc=example,dc=com"
  schemachecking=on
  type=refreshAndPersist retry="60 +"
  starttls=critical tls_reqcert=demand
-
add: olcUpdateRef
olcUpdateRef: ldap://192.168.1.111
```

Ensure the following attributes have the correct values:

- `provider`: Provider server's hostname - `192.168.1.111` in this example. It must match what is presented in the provider's SSL certificate.
- `binddn`: the bind DN for the replicator user.
- `credentials`: The password you selected for the replicator user
- `searchbase`: The database suffix you're using, i.e., content that is to be replicated
- `olcUpdateRef`: Provider server's hostname or IP address, given to clients if they try to write to this consumer.
- `rid`: Replica ID, a unique 3-digit ID that identifies the replica. Each consumer SHOULD have at least one `rid`.
  > Note:
  > A successful encrypted connection via `START_TLS` is being enforced in this configuration, to avoid sending the credentials in the clear across the network.
  > See LDAP with TLS _(ref links)_ on how to setup OpenLDAP with trusted SSL certificates.
  > Add the new configuration:

```sh
sudo ldapadd -Q -Y EXTERNAL -H ldapi:/// -f consumer_simple_sync.ldif
```

The dc=example,dc=com tree should now be synchronising.

### Ref Links

- [Ubuntu LDAP Installation](https://ubuntu.com/server/docs/install-and-configure-ldap)
- [Ubuntu LDAPS (TLS)](https://ubuntu.com/server/docs/ldap-and-transport-layer-security-tls)
- [Ubuntu LDAP Replication](https://ubuntu.com/server/docs/openldap-replication)
- [PHP LDAP Admin old version problem](https://stackoverflow.com/questions/74384236/unrecognized-error-number-8192-trim-passing-null-to-parameter-1-string)
