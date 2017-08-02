@echo off
@setlocal EnableDelayedExpansion 


for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H



ECHO.
ECHO ...............................................
ECHO ....SELECT COIN TO MINE ON SPRNVA POOLS........
ECHO ...............................................
ECHO.
ECHO  1 - DECRED (DCR)
ECHO  2 - DIGIBYTE-SKEIN (DGB)
ECHO  3 - HUSH (HUSH)
ECHO  4 - LIBRARY CREDITS (LBRY)
ECHO  5 - MONACOIN (MONA)
ECHO  6 - SIGNATUM (SIGT)
ECHO  7 - VELTOR (VLT)
ECHO  8 - ZENCASH (ZEN)
ECHO  9 - ZCASH (ZEC)
ECHO 10 - ZCOIN (XZC)
ECHO 11 - DASHCOIN (DASH)
ECHO 12 - ZCLASSIC (ZCL)
ECHO 13 - BITCOIN CASH (BCH)
ECHO.



SET /P M=Type number, then press ENTER:

:LOOP

IF !M!==1 .\Bin\NVIDIA-skunk\ccminerskunk.exe -a DECRED -o stratum+tcp://dcr.suprnova.cc:3252 -u !USERNAME!.!WORKERNAME! -p x  
IF !M!==2 .\Bin\NVIDIA-skunk\ccminerskunk.exe -a skein -o stratum+tcp://dgbs.suprnova.cc:5226 -u !USERNAME!.!WORKERNAME! -p x 
IF !M!==3 .\Bin\NVIDIA-EWBF\zminer.exe --server zdash.suprnova.cc --user !USERNAME!.!WORKERNAME! --pass x --port 4048 
IF !M!==4 .\Bin\NVIDIA-Alexis78\ccminer.exe -a LBRY -o stratum+tcp://lbry.suprnova.cc:6256 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==5 .\Bin\NVIDIA-Alexis78\ccminer.exe -a lyra2v2 -o stratum+tcp://mona.suprnova.cc:2995 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==6 .\Bin\NVIDIA-palginkunk\ccminer.exe -a skunk -o stratum+tcp://sigt.suprnova.cc:7106 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==7 .\Bin\NVIDIA-Alexis78\ccminer.exe -a veltor -o stratum+tcp://veltor.suprnova.cc:8897 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==8 .\Bin\NVIDIA-EWBF\zminer.exe --server zen.suprnova.cc --user !USERNAME!.!WORKERNAME! --pass x --port 4048 
IF !M!==9 (
			IF !LOCATION!==US (SET SERVER=zec-us.suprnova.cc)
			IF !LOCATION!==EUROPE (SET SERVER=zec-eu.suprnova.cc)
			IF !LOCATION!==ASIA (SET SERVER=zec-apac.suprnova.cc)
			.\Bin\NVIDIA-EWBF\zminer.exe --server !SERVER! --user !USERNAME!.!WORKERNAME! --pass x --port 2142
			)

IF !M!==10 (
			IF !LOCATION!==US (SET SERVER=xzc.suprnova.cc)
			IF !LOCATION!==EUROPE (SET SERVER=xzc.suprnova.cc)
			IF !LOCATION!==ASIA (SET SERVER= xzc-apac.suprnova.cc)
			.\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a lyra2z -o stratum+tcp://!SERVER!:1569 -u !USERNAME!.!WORKERNAME! -p x   
			)	

IF !M!==11 .\Bin\NVIDIA-Alexis78\ccminer.exe -a x11 -o stratum+tcp://dash.suprnova.cc:9995 -u !USERNAME!.!WORKERNAME! -p x   
				
IF !M!==12 (
			IF !LOCATION!==US (SET SERVER=zcl.suprnova.cc)
			IF !LOCATION!==EUROPE (SET SERVER=zcl.suprnova.cc)
			IF !LOCATION!==ASIA (SET SERVER=zcl-apac.suprnova.cc)
			.\Bin\NVIDIA-EWBF\zminer.exe --server !SERVER! --user !USERNAME!.!WORKERNAME! --pass x --port 4042
			)

IF !M!==13 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a sha256d -o stratum+tcp://bcc.suprnova.cc:3333 -u !USERNAME!.!WORKERNAME! -p x   

GOTO LOOP



