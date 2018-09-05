@echo off

cd /d %~dp0

set Mode=Manual
set Pools=SuprNova
set Coins=Bitcore

powershell -version 5.0 -noexit -executionpolicy bypass -command "& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Coinsname %Coins%"
::pwsh -noexit -executionpolicy bypass -command "& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Coinsname %Coins%"

pause
