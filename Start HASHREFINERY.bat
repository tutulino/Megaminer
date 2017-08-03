@echo off

for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H
echo 

:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\MultiPoolMiner.ps1 -interval %INTERVAL% -Wallet %WALLET% -Username %USERNAME% -Workername %WORKERNAME% -Location US -PoolName hash_refinery -Type %TYPE%  -Donate %DONATE% -CURRENCY %CURRENCY% -WalletDonate %WALLETDONATE%
GOTO LOOP