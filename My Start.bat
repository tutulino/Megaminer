setx GPU_FORCE_64BIT_PTR 1
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

:LOOP

nvidiaInspector.exe -setBaseClockOffset:0,0,200 -setMemoryClockOffset:0,0,600 -setPowerTarget:0,112 -setTempTarget:0,0,75 -setFanSpeed:0,70 -forcepstate:0,0

del "Stats\*_Profit.txt"

powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\core.ps1 -MiningMode AUTOMATIC -PoolsName Mining_Pool_Hub
GOTO LOOP