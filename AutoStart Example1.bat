REM --This is an example of how launch Megaminer without prompt for automatic coin selection pools
:LOOP
powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\Megaminer.ps1 -PoolName Mining_Pool_Hub
GOTO LOOP