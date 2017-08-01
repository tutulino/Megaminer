@echo off

for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H




ECHO.
ECHO ...............................................
ECHO ............SELECT COIN TO MINE................
ECHO ...............................................
ECHO.
ECHO 1 - DECRED
ECHO 2 - DIGIBYTE (SKEIN)
ECHO 3 - HUSH
ECHO 4 - LBRY
ECHO 5 - MONACOIN
ECHO 6 - SIGNATUM
ECHO 7 - VELTOR
ECHO 8 - ZENCASH
ECHO.

 

:LOOP

SET /P M=Type number, then press ENTER:
IF %M%==1 .\Bin\NVIDIA-skunk\ccminerskunk.exe -a DECRED -o stratum+tcp://dcr.suprnova.cc:3252 -u %USERNAME%.%WORKERNAME% -p x  
IF %M%==2 .\Bin\NVIDIA-skunk\ccminerskunk.exe -a skein -o stratum+tcp://dgbs.suprnova.cc:5226 -u %USERNAME%.%WORKERNAME% -p x 
IF %M%==3 .\Bin\NVIDIA-EWBF\zminer --server zdash.suprnova.cc --user %USERNAME%.%WORKERNAME% --pass x --port 4048 
IF %M%==4 .\Bin\NVIDIA-Alexis78\ccminer.exe -a LBRY -o stratum+tcp://lbry.suprnova.cc:6256 -u %USERNAME%.%WORKERNAME% -p x   
IF %M%==5 .\Bin\NVIDIA-Alexis78\ccminer.exe -a lyra2v2 -o stratum+tcp://mona.suprnova.cc:2995 -u %USERNAME%.%WORKERNAME% -p x   
IF %M%==6 .\Bin\NVIDIA-skunk\ccminerskunk.exe -a skunk -o stratum+tcp://sigt.suprnova.cc:7106 -u %USERNAME%.%WORKERNAME% -p x   
IF %M%==7 .\Bin\NVIDIA-Alexis78\ccminer.exe -a veltor -o stratum+tcp://veltor.suprnova.cc:8897 -u %USERNAME%.%WORKERNAME% -p x   
IF %M%==8 .\Bin\NVIDIA-EWBF\zminer --server zen.suprnova.cc --user %USERNAME%.%WORKERNAME% --pass x --port 4048 

GOTO LOOP



