@echo off
call config.bat
call select-container.bat %1
docker exec -it %containerId% ldapbackup.sh %CFG_DOMAIN_BASE%
