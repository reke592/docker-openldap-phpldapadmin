#!/bin/bash
RESTORE_FLAG="/tmp/restoring_db"

# fix permissions
fix_file_permissions() {
  chown -R openldap:openldap /etc/ldap/slapd.d/
  chown -R openldap:openldap /var/lib/ldap/
  chown -R openldap:openldap "/etc/ldap/ssl"
  chmod 0640 "/etc/ldap/ssl/ldap_cert_key.pem"
  
  # if [ -f "$SSL_KEY_FILE" ]; then
  #   chown -R root:openldap "$SSL_KEY_FILE"
  #   chmod 0640 "$SSL_KEY_FILE"
  # fi
  # if [ -f "$SSL_CERT_FILE" ]; then
  #   chown -R root:openldap "$SSL_CERT_FILE"
  #   chmod 0640 "$SSL_CERT_FILE"
  # fi
}

# Function to start slapd
start_slapd() {
    generate-self-signed.sh
    echo "Starting slapd..."
    fix_file_permissions
    exec /usr/sbin/slapd -h "ldap://0.0.0.0 ldaps://0.0.0.0 ldapi:///" -g openldap -u openldap -F /etc/ldap/slapd.d -d 256
}

# Check if slapd should be restarted
while true; do
    if pgrep slapd > /dev/null; then
        sleep 5
    else
        if [ -f "$RESTORE_FLAG" ]; then
          while [ -f "$RESTORE_FLAG" ]; do
            echo "slapd is not running, waiting for DB restore to finish..."
            sleep 1  # Wait for restoration script to finish
          done
        fi
        start_slapd
        break
    fi
done
