---- POOLS SUPORTED ---------------------------------------

AHASHPOOL -- Anonymous, autoexchange to selected coin in config.txt
ALTMINER -- Anonymous, no autoexchange, must set a wallet for each coin
BLAZEPOOL -- Anonymous, autoexchange to selected coin in config.txt
BLOCKSFACTORY -- Registration required, one registration for all pools, no autoexchange
FLYPOOL -- Anonymous, manual mode only
HASHREFINERY -- Anonymous, autoexchange to selected coin in config.txt
ITALYIIMP -- Anonymous, autoexchange to selected coin in config.txt
MININGPOOLHUB -- registration required, autoexchange to selected coin on pool´s web.
NANOPOOL -- Anonymous, no autoexchange, must set a wallet for each coin
NICEHASH-- Anonymous, autoexchange to BTC
SUPRNOVA -- Registration required, one registration for all pools except bitcoin cash, no autoexchange
UNIMINING -- No registration, No autoexchange, need wallet for each coin on config.txt
WHATTOMINE (virtual) - Based on statistics of whattomine, it use MPH and Suprnova servers to mine most profitable coin, you must configure wallets on config.cfg and also have an account on Suprnova to us
YIIMP -- Anonymous, no autoexchange, must set a wallet for each coin
ZERGPOOL -- Anonymous, autoexchange to selected coin in config.txt
ZPOOL -- Anonymous, autoexchange to selected coin in config.txt


---- INSTRUCTIONS ----------------------------------------------

0. Download and decompress source code from latest Release from github (you dont need executable file)

1. For AMD, Install Microsoft Visual C++ 2015 Redistributable https://www.microsoft.com/en-us/download/details.aspx?id=52685

2. For AMD, beta blockchain drivers are not recommended (gpus will not show in current screen and activity based watchdog will be disabled)

3. Edit CONFIG.TXT file before mining

4. Exec start.bat for manual selection or edit AutoStartExample.bat for automatic boot without user prompt, you can use this parameters on your batch
    - PoolsName = separated comma string of pools to run 
	- MiningMode = Mode to check profit, note not all pools suport all modes (Automatic/Automatic24h/Manual). If manual mode is selected one coin must be passed on Coinsname parameter
	- Algorithm = separated comma string of algorithms to run (optional)
    - CoinsName = separated comma string of Coins to run (optional)
    - Groupnames = Groups of gpu/cpu to run (based on your defined groups in config.txt @@Gpugroups section) (optional)
	- PercentToSwitch = Overrides config.txt config, percent to switch miner/algo, new miner/algo only will be launched if new profit is greater than actual profit in specified percent (optional)
 

5. First time, software will be donwloaded from miners github repositories
	- As usual, some miners are detected as virus by your Antivirus, to avoid this you must set your instalation directory as excluded. For Windows Defender MM path is excluded automatic

6. Your system will be benchmarked (long process)
 
7. Make profit
	- Except Nicehash (where you sell your power to indicated price), pools always overstimated profit, you must understand profit column as a way to get best algoritmh. Your real profit will be lower.

8. Tuning (optional)
	- you can edit miners folders content to delete miners or to assign/unassign algos to miners. 
	- you can edit pools folders content to delete pools
	- for advanced users, you can create miners or pools if are based on existing one.

9. Monitorize all your rigs from one machine using Farm Monitor	


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

-GPU Info (AMD/Nvidia) (Power, fan, temperatures, eficency...)

-Pools Wallets actual and evolution info
 
-Option to autochange based on 24h statistics (on supported pools)

-Option for asociate command to launch before run to each miner (nvidia inspector for example to set overclock)

-Miners and Pools fees are included in profit calculation

-For mixed rigs (or for testing purpose on same cards rigs) you can group your cards allowing each group work at its best algo and difficulty

-Option to switch miner only if profit is a percent upper than actual (defined by you)

-Automatic NVIDIA Gpu Power limit, you can define any power limit values (90%, 80%, etc) for each winner miner/algo MM checks what of that power limit point is more profitable at each interval based in power cost, hashrate and reward.

-Delayed miners closing, while new miner is starting, old one continue mining

-Api rest for other software integration

-Utility for Farm rigs monitoring/alert (see config.txt)

----- DISCLAIMER ---- ------------------------------------------

Tested on nvidia pascal 10X0 and AMD RX580

Only for Windows

Core for auto change pools is forked from AaronSace MultipoolMiner, you can read info at https://github.com/aaronsace/MultiPoolMiner

Profit calculations are estimates based on info provided by Pools/Whattomine for your bechmarked hashrate extrapolated to 24h. No real profit warranty except nicehash, where you are selling your power at indicated price.

Pools or Whattomine statistics are based on past (luck, difficulty, exchange-rate, pool hashrte, network hashrate, etc), it can be not very accurate, usually expected profit is near 50% pool indicates.

Local Currency exchange rate to BTC is taken from Coindesk, Local currency profit can vary from whattomine revenue (instant), BTC revenue must be exact.


Based 20% on aaronsace, 80% is new at latest release (aprox.) Donations to

BTC: 1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TM
LTC: LVwuYbAvbMDVapheQBA7o2qQ2mKTEXVDbX
BCH: 1N7wsg4JmWJLP6BuHUP5rwsAXnQjTWPBjr
ETH: 0x9b7A01Bf5bD29c66d228d372B5bD1C43cDb78AcC




---- NO SCAM WARRANTY --------------------------------------------

You can audit .ps1 files, they are source code and running script (no compilation needed), miners are downloaded from github except not available that are downloaded from developer source and uploaded to my repository


