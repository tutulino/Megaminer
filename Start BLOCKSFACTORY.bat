@echo off
@setlocal EnableDelayedExpansion 


for /f "delims== tokens=1,2" %%G in (config.txt) do set %%G=%%H



ECHO.
ECHO ...............................................
ECHO ..SELECT COIN TO MINE ON BLOCKSFACTORY POOLS...
ECHO ...............................................
ECHO.
ECHO  1 - DIGIBYTE-SKEIN (DGB)
ECHO  2 - FEATHERCOIN (FTC)
ECHO  3 - PHOENIXCOIN (PXC)
ECHO  4 - ORBITCOIN (ORB)
ECHO  5 - GUNCOIN (GUN)
ECHO.



SET /P M=Type number, then press ENTER:

:LOOP

IF !M!==1 .\Bin\NVIDIA-skunk\ccminerskunk.exe -a skein -o stratum+tcp://s1.theblocksfactory.com:9002 -u !USERNAME!.!WORKERNAME! -p x 
IF !M!==2 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a neoscrypt -o stratum+tcp://s1.theblocksfactory.com:3333 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==3 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a neoscrypt -o stratum+tcp://s1.theblocksfactory.com:3332 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==4 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a neoscrypt -o stratum+tcp://s1.theblocksfactory.com:3334 -u !USERNAME!.!WORKERNAME! -p x   
IF !M!==5 .\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe -a neoscrypt -o stratum+tcp://s1.theblocksfactory.com:3330 -u !USERNAME!.!WORKERNAME! -p x   

		
    

GOTO LOOP



