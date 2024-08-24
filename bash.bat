@echo off
call select-container.bat %1
docker exec -it %containerId% /bin/bash
