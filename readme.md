
I'm user of NemosMiner and Multipoolminer also I'm user of diferents pools, manteinance of diferent software updates are painfull,  I have merged this softwares and added some features. I hope you enjoy it.


Based 75% on aaronsace, 5% on Nemos software, 20% is mine (aprox.)

Donations to

Aaronsace - 1MsrCoAt8qM53HUMsUxvy9gMj3QVbHLazH

Nemos - 1QGADhdMRpp9Pk5u5zG1TrHKRrdK5R81TE

Me - 1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TMN



----- DISCLAIMER ---- ------------------------------------------

Only tested on nvidia pascal (10X0) , sorry I haven't AMD card for testing purposes.

Only for Windows (at this moment)

Miners for AMD are included but not tested , ¡¡¡ AMD TESTERS NEEDED !!!

Core for auto change pools is forked from AaronSace MultipoolMiner, you can read info at https://github.com/aaronsace/MultiPoolMiner


-------NEW FEATURES OVER NEMO AND AARONSACE SOFTWARE -----------

In this software you can get same features than Nemosminer (Zpool) and Multipoolminer (MiningPoolHub), and also:


-Can mine on any of this pools (or all at same time): Zpool, HashRefinery, MPH or Yiimp with auto coin change based on pool profit for each algorithm with dual mining between diferent pools (ex. Eth on MPH and lbry on Zpool)

-Can mine on Suprnova,YIIMP or BlocksFactory pool without autochange or profit calculation, manual coin selection

-One file config

-Fastest miner for each algo/coin preselected for Nvidia Pascal (08/01/2017) on all pools.

-Enabled yescript algo

-Multiple drci test for eth/sia dual mining on MPH

-Dual Mining between different pools (ex. Eth on MPH and lbry on Zpool)

-Basic info from Bittrex and Cryptopia for no automatic coin selection pools

-Unified software repository for all pools

-Start to mine without commands or downloads only select pool and coin




---- INSTRUCTIONS ----------------------------------------------

0. Download latest Release from github

1. Edit CONFIG.TXT file before mining

2. Firt time, software will be donwloaded from miners github repositories.

3. Exec start.bat for manual selection or edit AutoStartExample.bat for automatic boot without user prompt


Default donation is 5 minutes each day on automatic pools, manual pools has no donation percent, you can change it at config.txt or donate manually ;-)


---- UPGRADE PROCEDURE ------------------------------------

Safest way is download new software and copy from old version "stats" folders and "config.txt" file.
If new verson haven´t miners update you can copy "bin" folder
If there is a new version on some miner is recomended delete hasrate.txt files of that miner on miners folder to force benchmark again.


---- POOLS SUPORTED ---------------------------------------

ZPOOL -- Anonymous, autoexchange to selected coin in config.txt

HASHREFINERY -- Anonymous, autoexchange to selected coin in config.txt

MININGPOOLHUB -- registration required, autoexchange to selected coin on pool´s web.

SPRNOVA -- registration required, one registration for all pools except bitcoin cash, no autoexchange

BLOCKSFACTORY -- registration required, one registration for all pools, no autoexchange

YIIMP -- Anonymous, no autoexchange, must set a wallet for each coin



---- ALGOS/COINS SUPORTED -------------------------------

**MPH, ZPOOL and HASHREFINERY (must be suported by pool)--
	skunk, jha, Blakecoin, c11, Groestl, yescrypt, veltor, blake, equihash, skein, scrypt, sib, neoscrypt, lbry, MyriadGroestl, Lyra2RE2, 
	Keccak, blake2s,x11evos,sia, vanilla, timetravel, tribus, Qubit, decred ,X11, x17, lyra2z, hmq1725, pascal, bitcore, ethash, 
	cryptonight, Nist5

**SPRNOVA
	DECRED(DCR), DIGIBYTE-SKEIN(DGB), HUSH(HUSH), LIBRARY(LBRY), MONACOIN (MONA), SIGNATUM(SIGT), VELTOR(VLT), ZCASH(ZEC),
	ZENCASH (ZEN), ZCOIN(XZC), DASHCOIN(DASH), ZCLASSIC(ZCL), KOMODO(KMD), MONERO(XMR), CHAINCOIN(CHC), ETHEREUM+DECRED(ETH+DCR),
	ETHEREUM+LIBRARY(ETH+LBRY),BITCORE(BTX)


**BLOCKSFACTORY
	DIGIBYTE-SKEIN(DGB), FEATHERCOIN(FTC), PHOENIXCOIN(PXC), ORBITCOIN(ORB), GUNCOIN(GUN)
	

**YIIMP
	DENARIUS(DNR), DECRED(DCR), SIGNATUM(SIGT), BITCORE(BTX), VERGE(VRG), SIBCOIN(SIB), VERTCOIN(VRC) 

**CROSSED POOLS
	ETHEREUM+DECRED(ETH+DCR),ETHEREUM+LIBRARY(ETH+LBRY),ETHEREUM+PASCAL(ETH+PSC),ETHEREUM+SIA(ETH+SC),



---- NO SCAM WARRANTY --------------------------------------------

You can see .ps1 files, are source code, miners are downloaded from github, can see address on miners folder files (except no github available, included)








