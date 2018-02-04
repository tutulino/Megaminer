@echo off
setx GPU_FORCE_64BIT_PTR 0
setx GPU_MAX_HEAP_SIZE 100
setx GPU_USE_SYNC_OBJECTS 1
setx GPU_MAX_ALLOC_PERCENT 100
setx GPU_SINGLE_ALLOC_PERCENT 100

cd /d %~dp0

:LOOP

powershell -version 5.0 -noexit -executionpolicy bypass -command ^
    "&.\Core.ps1 -MiningMode AUTOMATIC -PoolsName WhatToMine

GOTO LOOP
