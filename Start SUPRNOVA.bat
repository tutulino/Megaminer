@echo off
@setlocal EnableDelayedExpansion 


for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H


REM ----------------------------------SUPRNOVA START------------------------------------------------------------------------

ECHO.
ECHO ...............................................
ECHO ....SELECT COIN TO MINE ON SUPRNOVA POOLS........
ECHO ...............................................
ECHO.
ECHO  1 - DECRED (DCR)
ECHO  2 - DIGIBYTE-SKEIN (DGB)
ECHO  3 - HUSH (HUSH)
ECHO  4 - LIBRARY (LBRY)
ECHO  5 - MONACOIN (MONA)
ECHO  6 - SIGNATUM (SIGT)
ECHO  7 - VELTOR (VLT)
ECHO  8 - ZENCASH (ZEN)
ECHO  9 - ZCASH (ZEC)
ECHO 10 - ZCOIN (XZC)
ECHO 11 - DASHCOIN (DASH)
ECHO 12 - ZCLASSIC (ZCL)
ECHO 13 - KOMODO (KMD)
ECHO 14 - MONERO (XMR)
ECHO 15 - CHAINCOIN (CHC)
ECHO 16 - ETHEREUM + DECRED (ETH+DCR)
ECHO 17 - ETHEREUM + LIBRARY (ETH+LBRY)
ECHO.


SET /P M=Type number, then press ENTER:

REM --------Ask for DRCI in dual mode, must be outside loop
IF !M!==16 set DUALMODE=TRUE
IF !M!==17 set DUALMODE=TRUE

IF !DUALMODE!==TRUE (
					ECHO.	
					ECHO.	
					ECHO.	
					ECHO -----------------------SELECT INITIAL DCRI --------------------------
					ECHO You can change DCRI intensity in runtime with "+" and "-" keys and check current statistics with "s" key
					ECHO.	
					SET DCRI=NULL
					SET /P DCRI=Type DCRI -default 60-, then press ENTER:
					IF !DCRI!==NULL SET DCRI=60
					)
REM --------End ask DRCI


:LOOPSUPRNOVA

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

REM Bitcoin cash --> IF !M!==13 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a sha256d -o stratum+tcp://bcc.suprnova.cc:3333 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==13 .\Bin\NVIDIA-EWBF\zminer.exe --server kmd.suprnova.cc --user !USERNAME!.!WORKERNAME! --pass x --port 6250
IF !M!==14 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a cryptonight -o stratum+tcp://xmr-eu.suprnova.cc:5222 -u !USERNAME!.!WORKERNAME! -p x 
IF !M!==15 .\Bin\NVIDIA-SP-mod\ccminer.exe -a C11 -o stratum+tcp://chc.suprnova.cc:5888 -u !USERNAME!.!WORKERNAME! -p x
IF !M!==16 .\Bin\Ethash-Claymore\EthDcrMiner64.exe -r -1 -epool eth.suprnova.cc:5000 -ewal !USERNAME!.!WORKERNAME! -epsw x -esm 3 -allpools 1 -dpool dcr.suprnova.cc:3252 -dwal !USERNAME!.!WORKERNAME! -dpsw x -dcoin dcr -dcri !DCRI!
			
IF !M!==17 .\Bin\Ethash-Claymore\EthDcrMiner64.exe -r -1 -epool eth.suprnova.cc:5000 -ewal !USERNAME!.!WORKERNAME! -epsw x -esm 3 -allpools 1 -dpool lbry.suprnova.cc:6256 -dwal !USERNAME!.!WORKERNAME! -dpsw x -dcoin lbry -dcri !DCRI!
	

GOTO LOOPSUPRNOVA
GOTO END
REM ----------------------------------SUPRNOVA END------------------------------------------------------------------------









:END


 