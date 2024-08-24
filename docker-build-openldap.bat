@echo off
pushd openldap
docker build -t openldap -f Dockerfile .
docker image prune
popd
