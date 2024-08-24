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

RUN apt-get update --fix-missing  && \
apt update  && \
apt upgrade -y && \
apt install -y unattended-upgrades \
ca-certificates \
wget

# install and update phpldapadmin
RUN DEBIAN_FRONTEND=nointeractive apt-get install -y phpldapadmin && \
    wget http://archive.ubuntu.com/ubuntu/pool/universe/p/phpldapadmin/phpldapadmin_1.2.6.3-0.3_all.deb && \
    dpkg -i phpldapadmin_1.2.6.3-0.3_all.deb && \
    rm phpldapadmin_1.2.6.3-0.3_all.deb && \
    cp /etc/phpldapadmin/config.php /etc/phpldapadmin/config.php.orig && \
    cp /etc/phpldapadmin/apache.conf /etc/phpldapadmin/apache.conf.orig

# copy bin files
WORKDIR /usr/local/bin
COPY ./bin .
RUN chmod -R +x .

# Expose LDAP ports
EXPOSE 80 443

# entrypoint to start the slapd service
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
