@echo off

cd /d %~dp0

powershell -version 5.0 -noexit -executionpolicy bypass -command "& .\Miner.ps1"
::pwsh -noexit -executionpolicy bypass -command "& .\Miner.ps1"

pause
