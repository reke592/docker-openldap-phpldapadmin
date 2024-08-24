# Docker: OpenLDAP and PHPLdapAdmin

PS: If you want to use the windows batch files for testing, make sure to adjust the `config.bat` to match your variables.

## TODO:

- phpldapadmin apache2 ssl

## Docker Build

FROM ubuntu:22.04

#### Open LDAP image

- copy `slapd-pressed.txt.sample` to `slapd-preseed.txt` and configure the slapd installation parameters.
- run `docker-build-openldap.bat`

#### PHP LDAP Admin

- run `docker-build-phpldapadmin.bat`

## Docker compose configuration

The `docker-compose.yaml` file contains sample configuration to implement a `primary` and `replica` LDAP services.  
Make sure to adjust the `ldap.conf` URI to match the hostname or IP of the ldap server. The internal LDAP client in container will use this configuration in order to execute ldap commands.

### Enable LDAPS

By default the container will generate a self-signed certificate for 127.0.0.1 testing.  
If you want to generate different self-signed DNS you can use `./ssl/self-signed.sh`. (need WSL for windows)

#### Steps:

1. docker-compose.yaml file mounts for custom SSL
   - ./ssl/roots/your_ca_cert.crt:/etc/ldap/ssl/roots/ca_cert.crt
   - ./ssl/certs/your/\_.dev.mylocal_cert.pem:/etc/ldap/ssl/ldap_cert.pem
   - ./ssl/certs/your/ldap_cert_key.pem:/etc/ldap/ssl/ldap_cert_key.pem
2. make sure to adjust the ldap.conf URI to match your certificate DNS
3. run the containers
4. run `enable-ldaps.bat <containerID>` to run the ldapmodify and update-ca-certificates

#### Testing LDAPS:

You can run test by running ldapwhoami command. The -H option can be omitted if the default URI for ldap client is provided in ldap.conf.

```sh
# expected response: anonymous
docker exec -it containerID ldapwhoami -x -ZZ
docker exec -it containerID ldapwhoami -x
docker exec -it containerID ldapwhoami -x -ZZ -H ldap:///
docker exec -it containerID ldapwhoami -x -H ldaps:///
```

### LDAP Data Snapshot

#### Creating Backup

run `bin/ldapbackup.sh <SEARCHBASE>` (kindly refer to glossary section).  
This will dump the slapcat results to `/mnt/backup`. Make sure to declare a volume bindmount to that directory in your docker-compose.yaml.

#### Restore Backup

This procedure requires temporary suspension of slapd service to delete the old database.  
run `bin/ldapsuspend.sh` then `bin/ldaprestore.sh <SEARCHBASE> <BACKUP_PATH>`. (kindly refer to glossary section)

### Configure Replication:

Given the ldap containers are running.

#### Steps to configure the Primary server:

1. run `stats.bat` to display the running docker process
2. run `create-replicator.bat <containerID>` this will request for LDAP admin account credentials to save the new replicator account.
3. run `as-primary.bat <containerID>` to automate the configuration of primary server

#### Steps to configure the Replica:

1. run `stats.bat` to display the running docker process
2. set the docker-compose.yaml environments
   - `REPLICA_ID` - a unique 3 digits value assigned to each replica server
   - `REPLICATOR_DN` - the replicator account to use
   - `REPLICA_SEARCHBASE` - the dc format of the provided DOMAIN_NAME in slapd-preseed.txt
   - `REPLICA_PROVIDER_HOST` - the primary server hostname or IP address. e.g. _ldap://ldap.primary.test_
3. run `as-replica.bat <containerID>` to automate the configuration of replica server, this will ask for the replicator account password.

### Configuring PHP LDAP Admin

#### Persist PHP Session

To persist PHP LDAP Admin sessions on container restart, bind mount a volume to `/var/lib/php/sessions`.

#### Add more LDAP servers

Create your custom `config.php` file, mount override `/etc/phpldapadmin/config.php` then restart the phpldapadmin container.  
A sample configuration can be found in `./test/phpldapadmin/conf/config.php`.  
To add more ldap servers, just follow the snippets below.

```php
# define new server
$servers->newServer('ldap_pla');
# configure server connection settings
$servers->setValue('server','name','Local Lan Primary');
# if you want to always use LDAPS, make the server host value starts with ldaps://, and disable the STARTTLS for this server connection
$servers->setValue('server','host','ldap1.dev.mylocal');
# default ports: 389 ldap, 636 ldaps
// $servers->setValue('server','port',389);
$servers->setValue('server','base',array('dc=local,dc=lan'));
$servers->setValue('login','auth_type','session');
$servers->setValue('login','bind_id','cn=admin,dc=local,dc=lan');
# enable STARTTLS
$servers->setValue('server','tls',true);
# trusted root CA's, needed by the ldap client in order to connect with LDAPS
# we always set the value to /usr/local/share/ca-certificates because this directory is mounted in docker-compose.yaml
# the container will run `update-ca-certificates` when calling `bin/configure-ldaps.sh` or via docker exec manually.
$servers->setValue('server','tls_cacertdir','/usr/local/share/ca-certificates');
# The configuration below is needed when the target LDAP server demands olcTLSVerifyClient.
/* TLS Client Certificate file (PHP 7.1+) */
// $servers->setValue('server','tls_cert',null);
#  $servers->setValue('server','tls_cert','/etc/pki/tls/certs/ldap_user.crt');
/* TLS Client Certificate Key file (PHP 7.1+) */
// $servers->setValue('server','tls_key',null);
#  $servers->setValue('server','tls_key','/etc/pki/tls/private/ldap_user.key');
```

## Glossary

- `bin/configure-ldaps.sh` - container shell to enable LDAPS
- `bin/create-replicator.sh` - container shell that automates the LDAP commands to add replicator user account.
- `bin/entrypoint.sh` - main entry point of docker container
- `bin/ldapbackup.sh <SEARCHBASE>` - container shell to backup LDAP database and save to `/mnt/backup/<folder_with_timestamp>`. e.g. _`ldapbackup.sh dc=local,dc=lan`_
- `bin/ldaprestore.sh <SEARCHBASE> <BACKUP_PATH>` - container shell to restore LDAP database backup. e.g. _`ldaprestore.sh dc=local,dc=lan /mnt/backup/backup_timestamp`_
- `bin/ldapsuspend.sh` - container shell to stop `slapd` process, this file will create a flag in `/tmp/restoring_db` in order to run database restoration.
- `bin/simple-sync-consumer.sh` - container shell to convert the container to LDAP replica.
- `bin/simple-sync-provider.sh` - container shell to convert the container to LDAP primary server for replicas.
- `conf/ldap.conf` - internal ldap client configuration file used to execute ldap commands. mount this file to `/etc/ldap/ldap.conf`.
- `config.bat` - windows batch file to apply common variables needed in other batch files.
- `docker-compose.yaml` - a docker service configuration file, this file also contains samples for `primary` and `replica` deployments.
- `as-primary.bat` - windows batch file to convert container instance to LDAP primary server.
- `as-replica.bat` - windows batch file to convert container instance to LDAP replica server.
- `backup.bat` - creates LDAP backup files, needs volume bind mount to `/mnt/backup`.
- `bash.bat` - run docker exec `/bin/bash` in container
- `create-replicator.bat` - creates LDAP security object for replicator account.
- `docker-build-openldap.bat` - rebuild openldap image
- `docker-build-phpldapadmin.bat` - rebuild phpldapadmin image
- `down.bat` - down and remove service volumes
- `enable-ldaps.bat` - configure container to use SSL for LDAPS
- `restore.bat` - restore LDAP backup
- `search.bat <containerID> <searchBase> <attribs>` - run ldapsearch in container. e.g. _search containerID "ou=groups,dc=example,dc=com" "cn"_
- `search_ldaps.bat <containerID> <searchBase> <attribs>` - STARTTLS version of `search.bat` to test LDAPS.
- `security-objects.bat` - display all securityObjects in domain. see `config.bat` for CFG_DOMAIN_BASE
- `select-container.bat <containerID>` - set variable containerId, if containerID was not provided it will call `stats.bat` and ask for user input.
- `slapd-preseed.txt.sample` - a required configuration file for slapd installation, we need this in docker build process.
- `stats.bat` - display ID, Status, Names of running docker process
- `up.bat` - start containers in docker-compose.yaml this accepts also accepts the argument. e.g. _up.bat -d_
