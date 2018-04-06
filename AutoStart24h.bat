@echo off

cd /d %~dp0

set "command=& .\core.ps1 -MiningMode Automatic24h -PoolsName Zpool,WhatToMine,NiceHash,MiningPoolHub"

powershell -version 5.0 -noexit -executionpolicy bypass -command "%command%"
::pwsh -noexit -executionpolicy bypass -command "%command%"

pause
