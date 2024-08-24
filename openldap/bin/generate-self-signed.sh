#!/bin/bash
# use wsl when running WindowsOS
# adjust ca.info for the organization name
# adjust ldap_primary.info to align the certificate common name (cn) with the server hostname or IP
DEFAULT_CA_EXPIRE=3650
DEFAULT_CERT_EXPIRE=3649
ORG="Self-Signed Example"
SLAPD_CERT_CN=127.0.0.1
CA_EXPIRE_DAYS=${CA_EXPIRE_DAYS:-"$DEFAULT_CA_EXPIRE"}
CERT_EXPIRE=${CERT_EXPIRE:-"$DEFAULT_CERT_EXPIRE"}
OUT_DIR="/etc/ldap/ssl"
CA_ROOT_DIR="$OUT_DIR/roots"
CA_INFO_FILE="${CA_ROOT_DIR}/ca.info"
CA_CERT_FILE="${CA_ROOT_DIR}/ca_cert.crt"
CA_KEY_FILE="${CA_ROOT_DIR}/ca_key.pem"
SLAPD_CERT_KEY_FILE="${OUT_DIR}/ldap_cert_key.pem"
SLAPD_CERT_INFO="${OUT_DIR}/ldap.info"
SLAPD_CERT_FILE="${OUT_DIR}/ldap_cert.pem"

ssl_found=false
if [ -f "$CA_CERT_FILE" ]; then
  echo "found $CA_CERT_FILE"
  ssl_found=true
fi
if [ -f "$SLAPD_CERT_FILE" ]; then
  echo "found $SLAPD_CERT_FILE"
  ssl_found=true
fi
if [ -f "$SLAPD_CERT_KEY_FILE" ]; then
  echo "found $SLAPD_CERT_KEY_FILE"
  ssl_found=true
fi
if [ "$ssl_found" = true ]; then
  exit 0
fi

mkdir -p "$OUT_DIR" "$CA_ROOT_DIR"

echo ".. updating ${CA_INFO_FILE}"
cat > "${CA_INFO_FILE}" <<EOF
organization = $ORG
cn = $ORG
ou = $ORG
ca
cert_signing_key
clr_signing_key
expiration_days = $CA_EXPIRE_DAYS
EOF

echo ".. updating ${SLAPD_CERT_INFO}"
cat > "${SLAPD_CERT_INFO}" <<EOF
organization = $ORG
cn = $SLAPD_CERT_CN
dns_name = $SLAPD_CERT_CN
expiration_days = $CERT_EXPIRE
tls_www_server
encryption_key
signing_key
EOF

if [ -f "${CA_CERT_FILE}" ] && [ -f "${CA_KEY_FILE}" ]; then
  echo ".. skipping creation of ca_cert and ca_key. any of the file already exist in ${OUT_DIR}"
else
  echo ".. creating ${CA_KEY_FILE}"
  certtool \
    --generate-privkey \
    --bits 4096 \
    --outfile "${CA_KEY_FILE}"
  echo ".. creating ${CA_CERT_FILE}"
  certtool \
    --generate-self-signed \
    --load-privkey "${CA_KEY_FILE}" \
    --template "${CA_INFO_FILE}" \
    --outfile "${CA_CERT_FILE}" 2> /dev/null
fi

if [ -f "${SLAPD_CERT_KEY_FILE}" ]; then
  echo ".. re-using ${SLAPD_CERT_KEY_FILE}"
else
  echo ".. creating ${SLAPD_CERT_KEY_FILE}"
  certtool \
    --generate-privkey \
    --bits 4096 \
    --outfile "${SLAPD_CERT_KEY_FILE}" 2> /dev/null
fi

echo ".. generating ${SLAPD_CERT_FILE}"
certtool \
  --generate-certificate \
  --load-privkey "${SLAPD_CERT_KEY_FILE}" \
  --load-ca-certificate "${CA_CERT_FILE}" \
  --load-ca-privkey "${CA_KEY_FILE}" \
  --template "${SLAPD_CERT_INFO}" \
  --outfile "${SLAPD_CERT_FILE}" 2> /dev/null

echo done.
