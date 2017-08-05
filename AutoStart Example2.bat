REM --This is an example of how launch Megaminer without prompt for NOT automatic coin selection pools
:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\Megaminer.ps1 -PoolName Blocks_Factory -CoinName Feathercoin
GOTO LOOP