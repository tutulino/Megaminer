@echo off

for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H
echo 

:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\MultiPoolMiner.ps1 -interval %INTERVAL% -Wallet %WALLET% -Username %USERNAME% -Workername %WORKERNAME% -Location US -PoolName Mining_Pool_Hub -Type %TYPE%  -Donate %DONATE% -WalletDonate %WALLETDONATE%
GOTO LOOP