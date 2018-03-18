@echo off

cd /d %~dp0

powershell -version 5.0 -noexit -executionpolicy bypass -command ^
    "&.\core.ps1 -MiningMode Manual -PoolsName suprnova -Coinsname Bitcore
