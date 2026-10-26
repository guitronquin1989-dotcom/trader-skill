@echo off
REM trader-skill - instalador Windows (dois cliques, ou rode no cmd)
REM Chama o install.ps1 com bypass de ExecutionPolicy so para este processo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
