# directory structure
# /
# '--/mnt
#    '--/backup
#    '--/ldifs
#    '--/ssl
# '--/usr
#    '--/local
#       '--/src
#          '--slapd-preseed.txt (temporary for ldap installation)
FROM ubuntu:22.04

WORKDIR /usr/local/src
RUN apt-get update --fix-missing  && \
    apt update  && \
    apt upgrade -y && \
    apt install -y unattended-upgrades \
    ca-certificates \
    gnutls-bin \
    ssl-cert

COPY slapd-preseed.txt .
RUN debconf-set-selections < slapd-preseed.txt && rm slapd-preseed.txt
RUN DEBIAN_FRONTEND=nointeractive apt-get install -y slapd ldap-utils 

RUN mkdir -p /mnt/backup && \
    mkdir -p /mnt/ldifs

# copy bin files
WORKDIR /usr/local/bin
COPY ./bin .
RUN chmod -R +x .

# Expose LDAP ports
EXPOSE 389 636

# Backup dump directory
VOLUME ["/mnt/backup"]

# entrypoint to start the slapd service
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
