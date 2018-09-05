@echo off

cd /d %~dp0

set Mode=Automatic
set Pools=Zpool,MiningPoolHub
set Coins=Bitcore,Signatum,Zcash

powershell -version 5.0 -noexit -executionpolicy bypass -command "& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Coinsname %Coins%"
::pwsh -noexit -executionpolicy bypass -command "& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Coinsname %Coins%"

pause
