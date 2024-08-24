@echo off
setlocal
call config.bat
call select-container.bat %1

set /P "BASE=basesearch: "
set /P "FILTERS=filters: "
docker exec -it %containerId% ldapsearch -x -ZZ %CFG_SEARCH_FORMAT% -b %BASE% %FILTERS%

:eof
endlocal
