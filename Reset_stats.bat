
@echo off
setlocal
:PROMPT
SET /P AREYOUSURE=Are you sure, this delete all stats (not benchmark)(Y/[N])?
IF /I "%AREYOUSURE%" NEQ "Y" GOTO END


del "Stats\*_stats.txt"

echo DELETED STATS FILES FROM STATS FOLDER
pause


:END
endlocal


