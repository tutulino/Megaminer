---- POOLS SUPORTED ---------------------------------------

ZPOOL -- Anonymous, autoexchange to selected coin in config.txt

HASHREFINERY -- Anonymous, autoexchange to selected coin in config.txt

MININGPOOLHUB -- registration required, autoexchange to selected coin on pool´s web.

SUPRNOVA -- registration required, one registration for all pools except bitcoin cash, no autoexchange

BLOCKSFACTORY -- registration required, one registration for all pools, no autoexchange

YIIMP -- Anonymous, no autoexchange, must set a wallet for each coin

NICEHASH-- Anonymous, autoexchange to BTC

WHATTOMINE (virtual) - Based on statistics of whattomine, it use MPH,Yiimp and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to us


---- ALGOS/COINS SUPORTED (NVIDIA) -------------------------------

**Mining Pool Hub, Yiimp, ZPOOL, Nicehash and Hash Refinery (must be suported by pool)
   skunk, jha, Blakecoin, c11, Groestl, yescrypt, veltor, blake, equihash, skein, scrypt, sib, neoscrypt, lbry, Myriad-Groestl, Lyra2v2, 
   Keccak, blake2s,x11evo,sia, vanilla, timetravel, tribus, Qubit , X13, x17, lyra2z, hmq1725, pascal, bitcore, ethash, 
   cryptonight, Nist5, quark, blake14r,x11gost, ethash|blake2s, ethash|lbry, ethash|pascal, ethash|blake14r, PHI, HSR

**SUPRNOVA
   DECRED(DCR), DIGIBYTE-SKEIN(DGB), HUSH(HUSH), LIBRARY(LBRY), MONACOIN (MONA), SIGNATUM(SIGT), ZCASH(ZEC),
   ZENCASH (ZEN), ZCLASSIC(ZCL), KOMODO(KMD), MONERO(XMR), DIGIBYTE-GROESTL(DGB), SIBCOIN (SIB) ,UBIQ (UBQ), EXPANSE (EXP),
   BITSEND (BSD)


**BLOCKSFACTORY
   DIGIBYTE-SKEIN(DGB), FEATHERCOIN(FTC), PHOENIXCOIN(PXC), ORBITCOIN(ORB), GUNCOIN(GUN)

**FLYPOOL
   ZCASH


**WHATTOMINE (virtual)
   DECRED(DCR),  HUSH(HUSH), LBRY(LBRY), MONACOIN (MONA), ZCASH(ZEC), ZENCASH (ZEN), ZCOIN(XZC), ZCLASSIC(ZCL), VERTCOIN (VTC)
   KOMODO(KMD), MONERO(XMR), DIGIBYTE-GROESTL(DGB),SIBCOIN (SIB),UBIQ (UBQ), EXPANSE (EXP), ETHEREUM CLASSIC (ETC), MYRIAD-GROESTL (XMY), MUSICOIN (MUSIC),
   ETHEREUM+DECRED(ETH+DCR),ETHEREUM+LBRY(ETH+LBRY)


**CROSSED BETWEEN POOLS
    ETHEREUM+DECRED, ETHEREUM+LBRY, ETHEREUM+PASCAL, ETHEREUM+SIACOIN



-------NEW FEATURES OVER NEMO AND AARONSACE SOFTWARE -----------

In this software you can get same features than Nemosminer (Zpool) and Multipoolminer (MiningPoolHub), and also:

-Menus sytem to choose coin/algo/pool and start mining

-One file config to start mining

-Can mine on "Virtual" Pool Whattomine, based on statistics of whattomine, it use MPH,Yiimp and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to use. 

-Can mine on any of this pools (or all at same time): Nicehash, Zpool, Whattomine (virtual) HashRefinery, MPH with auto coin change based on pool profit for each algorithm with dual mining between diferent pools (ex. Eth on MPH and lbry on Zpool)

-Can mine on Suprnova,Nicehash, MPH, YIIMP, Flypool or BlocksFactory pool without autochange or profit calculation, manual coin selection

-Fastest miner for each algo/coin preselected for Nvidia Pascal (08/01/2017) on all pools.

-Dual Mining between different pools (ex. Eth on MPH and lbry on Zpool)

-Profit info from Whattomine,Bittrex and Cryptopia (based on your real hashrate) for manual coin selection

-Unified software repository for all pools, no need one program for each pool

-On fail no wait for interval ends, instant relaunch.

-Auto Interval time for benchmarks, no need to change interval more.

-Local currency info on main screen

-Lastest version of miners available

-Nvidia SMI Info (Power, temperatures...)

-Pools Wallets actual and evolution info
 
-Option to autochange based on 24h statistics (on supported pools)

-Option for asociate command to launch before run to each miner (nvidia inspector for example to set overclock)





---- INSTRUCTIONS ----------------------------------------------

0. Download latest Release from github

1. Edit CONFIG.TXT file before mining

2. Firt time, software will be donwloaded from miners github repositories.

3. Exec start.bat for manual selection or edit AutoStartExample.bat for automatic boot without user prompt


Default donation is 5 minutes each day on automatic pools, you can change it at config.txt or donate manually ;-)


---- UPGRADE PROCEDURE ------------------------------------

Safest way is download new software and copy from old version "stats" folders and "config.txt" file.
If new verson haven´t miners update you can copy "bin" folder
If there is a new version on some miner is recomended delete hasrate.txt files of that miner on miners folder to force benchmark again.



----- DISCLAIMER ---- ------------------------------------------

Only tested on nvidia pascal (10X0) , sorry I haven't AMD card for testing purposes.

Only for Windows (at this moment)

Miners for AMD are included but not tested , ¡¡¡ AMD TESTERS NEEDED !!!

Core for auto change pools is forked from AaronSace MultipoolMiner, you can read info at https://github.com/aaronsace/MultiPoolMiner

Profit calculations are estimates based on info provided by Pools/Whattomine for your bechmarked hashrate extrapolated to 24h. No real profit warranty.

Pools/Whattomine statistics are based on past (luck, difficulty, exchange-rate, pool hashrte, network hashrate, etc), it can be not very accurate.

Local Currency exchange rate to BTC is taken from Coindesk, Local currency profit can vary from whattomine revenue (instant), BTC revenue must be exact.


Based 70% on aaronsace, 30% is mine (aprox.) Donations to

*Aaronsace - 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH
*Me - 1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TM



---- NO SCAM WARRANTY --------------------------------------------

You can see .ps1 files, are source code, miners are downloaded from github


