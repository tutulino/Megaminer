@echo off

for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H


:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\MultiPoolMiner.ps1 -interval %INTERVAL% -Wallet %WALLET% -Username %USERNAME% -Workername %WORKERNAME% -Location US -PoolName zpool -Type %TYPE%  -Donate %DONATE% -currency %CURRENCY% -WalletDonate %WALLETDONATE%
GOTO LOOP