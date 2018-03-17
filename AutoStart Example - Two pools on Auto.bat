REM --This is an example of how launch Megaminer without prompt for automatic coin selection pools

cd %~dp0

:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\core.ps1 -MiningMode AUTOMATIC -PoolsName MiningPoolHub,YIIMP
GOTO LOOP