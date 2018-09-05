@echo off

cd /d %~dp0

set Mode=Automatic
set Pools=Zpool
set Algos=Lyra2z

powershell -version 5.0 -noexit -executionpolicy bypass -command "& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Algorithm %Algos%"
::pwsh -noexit -executionpolicy bypass -command "& .\Core.ps1 -MiningMode %Mode% -PoolsName %Pools% -Algorithm %Algos%"

pause
