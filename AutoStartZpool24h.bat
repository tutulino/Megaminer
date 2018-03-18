@echo off

cd /d %~dp0

set "command=& .\core.ps1 -MiningMode Automatic24h -PoolsName Zpool"

pwsh -noexit -executionpolicy bypass -command "%command%"
powershell -version 5.0 -noexit -executionpolicy bypass -command "%command%"
msiexec -i https://github.com/PowerShell/PowerShell/releases/download/v6.0.2/PowerShell-6.0.2-win-x64.msi -qb!
pwsh -noexit -executionpolicy bypass -command "%command%"

pause
