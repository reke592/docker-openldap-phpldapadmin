@echo off
call config.bat
call select-container.bat %1
docker exec -it %containerId% create-replicator.sh
