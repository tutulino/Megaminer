@echo off

for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H

:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\MultiPoolMiner.ps1 -interval 100 -Wallet %WALLET% -Username %USERNAME% -Workername %WORKERNAME% -Location US -PoolName zpool,hash,mph -Type %TYPE%  -Donate %DONATE%
GOTO LOOP