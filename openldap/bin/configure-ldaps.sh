#!/bin/bash
echo "configuring instance to serve LDAPS"
SSL_CA_CERT_FILE=/etc/ldap/ssl/roots/ca_cert.crt
SSL_CERT_FILE=/etc/ldap/ssl/ldap_cert.pem
SSL_KEY_FILE=/etc/ldap/ssl/ldap_cert_key.pem

# missing_env_vars=false

# if [ -z "$SSL_CA_CERT_FILE" ]; then
#   echo "Error: missing environment variable SSL_CA_CERT_FILE."
#   missing_env_vars=true
# fi

# if [ -z "$SSL_CERT_FILE" ]; then
#   echo "Error: missing environment variable SSL_CERT_FILE."
#   missing_env_vars=true
# fi

# if [ -z "$SSL_KEY_FILE" ]; then
#   echo "Error: missing environment variable SSL_KEY_FILE"
#   missing_env_vars=true
# fi

# if [ "$missing_env_vars" = true ]; then
#   exit 1
# fi

if ls "${SSL_KEY_FILE}" 1> /dev/null 2>&1; then
  echo "updating permissions for $SSL_KEY_FILE"
  chgrp openldap ${SSL_KEY_FILE}
  chmod 0640 ${SSL_KEY_FILE}
else
  echo "$SSL_KEY_FILE not found. Please check if the absolute path of the mounted file is correct."
  exit 1
fi

if ls "${SSL_CA_CERT_FILE}" 1> /dev/null 2>&1; then
  echo "updating CA certificates"
  cp $SSL_CA_CERT_FILE /usr/local/share/ca-certificates/
  update-ca-certificates
else
  echo "$SSL_CA_CERT_FILE not found. Please check if the absolute path of the mounted file is correct."
  exit 1
fi

echo "applying configurations.."
ldapmodify -Y EXTERNAL -H ldapi:/// <<EOF
dn: cn=config
changetype: modify
replace: olcTLSCACertificateFile
olcTLSCACertificateFile: $SSL_CA_CERT_FILE
-
replace: olcTLSCertificateFile
olcTLSCertificateFile: $SSL_CERT_FILE
-
replace: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: $SSL_KEY_FILE
EOF

echo "done."
