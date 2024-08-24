@echo off
docker ps --format "{{.ID}} | {{.Status}} | {{.Names}}"