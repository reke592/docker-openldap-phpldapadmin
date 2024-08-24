@echo off
call config.bat
call select-container %1
docker exec -it %containerId% ldapsearch -x -LLL -b %CFG_DOMAIN_BASE% (objectClass=simpleSecurityObject)
