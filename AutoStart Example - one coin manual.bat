REM --This is an example of how launch Megaminer without prompt for automatic coin selection pools
:LOOP
del "Stats\*_Profit.txt"

powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\core.ps1 -MiningMode Manual -PoolsName suprnova -Coinsname Bitcore
GOTO LOOP