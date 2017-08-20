:LOOP
del "Stats\*_Profit.txt"

powershell -version 5.0 -noexit -executionpolicy bypass -command "&.\core.ps1 -MiningMode AUTOMATIC -PoolsName Mining_Pool_Hub,Suprnova -Coinsname Feathercoin,Groestlcoin,Zcash,Zclassic,Ethereum,Ubiq,Hush,DIGIBYTE-GROESTL,Vertcoin,Expanse
GOTO LOOP