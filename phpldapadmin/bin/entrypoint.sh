#!/bin/bash

# LDAPADMIN="/etc/phpldapadmin"
# ORIG_CONFIG="$LDAPADMIN/config.php"
# BACKUP_CONFIG="$LDAPADMIN/config.php.bak"
# CUSTOM_CONFIG="$LDAPADMIN/custom/config.php"

if [ -d "/usr/local/share/ca-certificates" ]; then
    echo "to register root certificates, mount the directory of your .crt files to /usr/local/share/ca-certificates"
    update-ca-certificates
fi

# if [ -f "$CUSTOM_CONFIG" ]; then
#     echo "using $CUSTOM_CONFIG"
#     if ! [ -f "$BACKUP_CONFIG" ]; then
#         mv $ORIG_CONFIG $BACKUP_CONFIG
#     fi
#     cp "$CUSTOM_CONFIG" "$ORIG_CONFIG"
#     chown root:www-data "$ORIG_CONFIG"
# else
#     echo "to use custom config, mount a file to /etc/phpldapadmin/custom/config.php"
#     if [ -f "$BACKUP_CONFIG" ]; then
#         mv "$BACKUP_CONFIG" "$ORIG_CONFIG"
#     fi
# fi

chown root:www-data "/etc/phpldapadmin/config.php"
apache2ctl -D FOREGROUND
