@echo off

cd /d %~dp0

powershell -version 5.0 -noexit -executionpolicy bypass -command ^
    "&.\Core.ps1 -MiningMode AUTOMATIC -PoolsName MiningPoolHub,Zpool,HashRefinery,AhashPool,WhatToMine,BlockMunch,NiceHash
