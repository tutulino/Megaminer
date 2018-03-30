@echo off

cd /d %~dp0

set "command=& .\core.ps1 -MiningMode Automatic -PoolsName MiningPoolHub,Zpool,HashRefinery,AhashPool,WhatToMine,BlockMasters,NiceHash,ZergPool"

powershell -version 5.0 -noexit -executionpolicy bypass -command "%command%"
::pwsh -noexit -executionpolicy bypass -command "%command%"

pause
