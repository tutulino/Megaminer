---- POOLS SUPORTED ---------------------------------------

ZPOOL -- Anonymous, autoexchange to selected coin in config.txt

AHASHPOOL -- Anonymous, autoexchange to selected coin in config.txt

HASHREFINERY -- Anonymous, autoexchange to selected coin in config.txt

MININGPOOLHUB -- registration required, autoexchange to selected coin on pool´s web.

SUPRNOVA -- registration required, one registration for all pools except bitcoin cash, no autoexchange

BLOCKSFACTORY -- registration required, one registration for all pools, no autoexchange

YIIMP -- Anonymous, no autoexchange, must set a wallet for each coin

NICEHASH-- Anonymous, autoexchange to BTC

NANOPOOL -- Anonymous, no autoexchange, must set a wallet for each coin

FLYPOOL -- Anonymous, manual mode only

UNIMINING -- No registration, No autoexchange, need wallet for each coin on config.txt

ITALYIIMP -- Anonymous, autoexchange to selected coin in config.txt

WHATTOMINE (virtual) - Based on statistics of whattomine, it use MPH and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to us



---- INSTRUCTIONS ----------------------------------------------

0. Download latest Release from github

1. Edit CONFIG.TXT file before mining

2. Exec start.bat for manual selection or edit AutoStartExample.bat for automatic boot without user prompt, you can use this parameters on your batch
    *PoolsName = separated comma string of pools to run 
	*MiningMode = Mode to check profit, note not all pools suport all modes (Automatic/Automatic24h/Manual). If manual mode is selected one coin must be passed on Coinsname parameter
	*Algorithm = separated comma string of algorithms to run (optional)
    *CoinsName = separated comma string of Coins to run (optional)
    *Groupnames = Groups of gpu/cpu to run (based on your defined groups in config.txt @@Gpugroups section) (optional)

3. Firt time, software will be donwloaded from miners github repositories and your system will be benchmarked (long process)
	- As usual, some miners are detected as virus by Windows Defender, to avoid this you must set your instalation directory as excluded on Windows Defender 

4. Tuning (optional)
	- you can edit miners folders content to delete miners or to assign/unassign algos to miners. 
	- you can edit pools folders content to delete pools
	- for advanced users, you can create miners or pools if are based on existing one.



Default donation is 5 minutes each day on automatic pools, you can change it at config.txt or donate manually ;-)


---- UPGRADE PROCEDURE ------------------------------------

Safest way is download new software and copy from old version "stats" folders and "config.txt" file.
If new verson has no miners update you can copy "bin" folder
If there is a new miner version is recomended delete miner_algo_hashrate.txt files on miners folder to force benchmark again.


-------NEW FEATURES OVER BASE SOFTWARE -----------

-Menus sytem to choose coin/algo/pool and start mining

-One file config to start mining

-Can mine on "Virtual" Pool Whattomine, based on statistics of whattomine, it use MPH,Yiimp and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to use. 

-Can mine on any of this pools (or all at same time): Ahashpool, Nanopool, YIIMP, Nicehash, Zpool, Unimining, Whattomine (virtual) HashRefinery, MPH with auto coin change based on pool profit for each algorithm with dual mining between diferent pools (ex. Eth on MPH and lbry on Zpool)

-Can mine on Suprnova,Nicehash, MPH, Flypool or BlocksFactory pool without autochange or profit calculation, manual coin selection

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

-Miners and Pools fees are included in profit calculation

-For mixed rigs (or for testing purpose on same cards rigs) you can group your cards allowing each group work at its best algo and difficulty



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
*Tutulino (Me)  - 1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TM



---- NO SCAM WARRANTY --------------------------------------------

You can see .ps1 files, are source code, miners are downloaded from github


