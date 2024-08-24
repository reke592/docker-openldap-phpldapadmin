@echo off
call config.bat
call select-container.bat %1
call docker exec -it %containerId% ldapsuspend.sh
if %errorlevel%==0 (
    call docker exec -it %containerId% ldaprestore.sh "%CFG_DOMAIN_BASE%" "%CFG_BACKUP%"
)
:eof
