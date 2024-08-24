@echo off
pushd phpldapadmin
docker build -t phpldapadmin -f Dockerfile .
docker image prune
popd
