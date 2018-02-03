
@echo off
setlocal
:PROMPT
SET /P AREYOUSURE=Are you sure, this delete all benchmarks (Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO END


del "Stats\*_HashRate.txt"

echo DELETED HASHRATE FILES FROM STATS FOLDER
pause


:END
endlocal


