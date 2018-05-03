@echo off

cd /d %~dp0

set "command=& .\Miner.ps1"

powershell -version 5.0 -noexit -executionpolicy bypass -command "%command%"
::pwsh -noexit -executionpolicy bypass -command "%command%"

pause
