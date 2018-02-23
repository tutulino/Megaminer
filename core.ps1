#using module .\Include.psm1

param(
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = $null,

    [Parameter(Mandatory = $false)]
    [Array]$PoolsName = $null,

    [Parameter(Mandatory = $false)]
    [array]$CoinsName = $null,

    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null,

    [Parameter(Mandatory = $false)]
    [array]$GroupNames = $null,

    [Parameter(Mandatory = $false)]
    [string]$PercentToSwitch = $null
)



. .\Include.ps1

##Parameters for testing, must be commented on real use


#$MiningMode='Automatic'
#$MiningMode='Manual'

#$PoolsName=('ahashpool','miningpoolhub','hashrefinery')
#$PoolsName='whattomine'
#$PoolsName='zergpool'
#$PoolsName='yiimp'
#$PoolsName='ahashpool'
#$PoolsName=('hashrefinery','zpool')
#$PoolsName='miningpoolhub'
#$PoolsName='zpool'
#$PoolsName='hashrefinery'
#$PoolsName='altminer'
#$PoolsName='blazepool'

#$PoolsName="Nicehash"
#$PoolsName="Nanopool"

#$Coinsname =('bitcore','Signatum','Zcash')
#$Coinsname ='zcash'
#$Algorithm =('phi','x17')

#$GroupNames=('rx580')



$ErrorActionPreference = "Continue"
$config = get_config

$Release = "6.04b"

if ($GroupNames -eq $null) {$Host.UI.RawUI.WindowTitle = "MegaMiner"}
else {$Host.UI.RawUI.WindowTitle = "MM-" + ($GroupNames -join "/")}
$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' #This align cuda id with nvidia-smi order

$progressPreference = 'silentlyContinue' #No progress message on web requests
#$progressPreference = 'Stop'

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
#add MM path to windows defender exclusions
$DefenderExclusions = (Get-MpPreference).CimInstanceProperties | Where-Object name -eq 'ExclusionPath'
if ($DefenderExclusions.value -notcontains (Convert-Path .)) {
    Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"
}

#Start log file
Clear_log
$logname = ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"
Start-Transcript $logname #for start log msg
Stop-Transcript
$LogFile = [System.IO.StreamWriter]::new( $logname, $true )
$LogFile.AutoFlush = $true

writelog ("Release $Release") $logfile $false

#get mining types
$Types = Get_Mining_Types -filter $GroupNames
writelog ( get_devices_information $Types | ConvertTo-Json) $logfile $false
Writelog ( $Types |ConvertTo-Json) $logfile $false

$ActiveMiners = @()

$ShowBestMinersOnly = $true
$FirstTotalExecution = $true
$StartTime = Get-Date

if (($config.DEBUGLOG) -eq "ENABLED") {$DetailedLog = $True} else {$DetailedLog = $false}

$Screen = $config.STARTSCREEN


#---Parameters checking

if ($MiningMode -NotIn @('Manual', 'Automatic', 'Automatic24h')) {
    "Parameter MiningMode not valid, valid options: Manual, Automatic, Automatic24h" | Out-Host
    EXIT
}

$PoolsChecking = Get_Pools `
    -Querymode "info" `
    -PoolsFilterList $PoolsName `
    -CoinFilterList $CoinsName `
    -Location $location `
    -AlgoFilterList $Algorithm

$PoolsErrors = @()
switch ($MiningMode) {
    "Automatic" {$PoolsErrors = $PoolsChecking | Where-Object ActiveOnAutomaticMode -eq $false}
    "Automatic24h" {$PoolsErrors = $PoolsChecking | Where-Object ActiveOnAutomatic24hMode -eq $false}
    "Manual" {$PoolsErrors = $PoolsChecking | Where-Object ActiveOnManualMode -eq $false }
}

$PoolsErrors | ForEach-Object {
    "Selected MiningMode is not valid for pool " + $_.name | Out-Host
    EXIT
}

if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -gt 1) {
    "On manual mode only one coin must be selected" | Out-Host
    EXIT
}

if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -eq 0) {
    "On manual mode must select one coin" | Out-Host
    EXIT
}

if ($MiningMode -eq 'Manual' -and ($Algorithm | Measure-Object).count -gt 1) {
    "On manual mode only one algorithm must be selected" | Out-Host
    EXIT
}


#parameters backup

$ParamAlgorithmBCK = $Algorithm
$ParamPoolsNameBCK = $PoolsName
$ParamCoinsNameBCK = $CoinsName
$ParamMiningModeBCK = $MiningMode



set_WindowSize 185 60

$IntervalStartAt = (Get-Date) #first initialization, must be outside loop


ErrorsToLog $LogFile


$Msg = "Starting Parameters: "
$Msg += " //Algorithm: " + [String]($Algorithm -join ",")
$Msg += " //PoolsName: " + [String]($PoolsName -join ",")
$Msg += " //CoinsName: " + [String]($CoinsName -join ",")
$Msg += " //MiningMode: " + $MiningMode
$Msg += " //GroupNames: " + [String]($GroupNames -join ",")
$Msg += " //PercentToSwitch: " + $PercentToSwitch

WriteLog $msg $LogFile $False




#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#This loop will be running forever
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------


while ($true) {

    $config = get_config
    Clear-Host; $repaintScreen = $true

    WriteLog "New interval starting............." $LogFile $True
    Writelog ( Get_ComputerStats | ConvertTo-Json) $logfile $false

    $Location = $config.Location

    if ([string]::IsNullOrWhiteSpace($PercentToSwitch)) {$PercentToSwitch2 = [int]($config.PercentToSwitch)}
    else {$PercentToSwitch2 = [int]$PercentToSwitch}
    $DelayCloseMiners = $config.DelayCloseMiners

    $Types = Get_Mining_Types -filter $GroupNames

    $NumberTypesGroups = ($Types | Measure-Object).count
    if ($NumberTypesGroups -gt 0) {$InitialProfitsScreenLimit = [int](40 / $NumberTypesGroups) - 5 } #screen adjust to number of groups
    if ($FirstTotalExecution) {$ProfitsScreenLimit = $InitialProfitsScreenLimit}


    $Currency = $config.Currency
    $BenchmarkintervalTime = [int]($config.BenchmarkTime)
    $LocalCurrency = $config.LocalCurrency
    if ([string]::IsNullOrWhiteSpace($LocalCurrency)) {
        #for old config.txt compatibility
        switch ($location) {
            'Europe' {$LocalCurrency = "EUR"}
            'US' {$LocalCurrency = "USD"}
            'ASIA' {$LocalCurrency = "USD"}
            'GB' {$LocalCurrency = "GBP"}
            default {$LocalCurrency = "USD"}
        }
    }

    #Donation
    $LastIntervalTime = (Get-Date) - $IntervalStartAt
    $IntervalStartAt = (Get-Date)
    $DonationStat = if (Test-Path -Path 'Donation.ctr') { (Get-Content -Path 'Donation.ctr') -split '_' } else { 0, 0 }
    $DonationPastTime = [int]$DonationStat[0]
    $DonatedTime = [int]$DonationStat[0]
    $ElapsedDonationTime = [int]($DonationPastTime + $LastIntervalTime.TotalMinutes)
    $ElapsedDonatedTime = [int]($DonatedTime + $LastIntervalTime.TotalMinutes)

    $ConfigDonateTime = [int]($config.Donate)

    #Activate or deactivate donation
    if ($ElapsedDonationTime -gt 1440 -and $ConfigDonateTime -gt 0) {
        # donation interval

        $DonationInterval = $true
        $UserName = "ffwd"
        $WorkerName = "Donate"
        $CoinsWallets = @{}
        $CoinsWallets.add("BTC", "3NoVvkGSNjPX8xBMWbP2HioWYK395wSzGL")

        $NextInterval = ($ConfigDonateTime - $ElapsedDonatedTime) * 60

        $Algorithm = $null
        $PoolsName = "NiceHash"
        $CoinsName = $null
        $MiningMode = "Automatic"

        if ($ElapsedDonatedTime -ge $ConfigDonateTime) {"0_0" | Set-Content -Path 'Donation.ctr'}
        else {[string]$DonationPastTime + "_" + [string]$ElapsedDonatedTime | Set-Content -Path 'Donation.ctr'}

        WriteLog ("Next interval you will be donating, thanks for your support") $LogFile $True
    } else {
        #NOT donation interval
        $DonationInterval = $false
        #get interval time based on pool kind (pps/ppls)
        $NextInterval = 0
        Get_Pools `
            -Querymode "Info" `
            -PoolsFilterList $PoolsName `
            -CoinFilterList $CoinsName `
            -Location $Location `
            -AlgoFilterList $Algorithm | ForEach-Object {
            $PItime = $config.("INTERVAL_" + $_.Rewardtype)
            if ([int]$PItime -gt $NextInterval) {$NextInterval = [int]$PItime}
        }

        $Algorithm = $ParamAlgorithmBCK
        $PoolsName = $ParamPoolsNameBCK
        $CoinsName = $ParamCoinsNameBCK
        $MiningMode = $ParamMiningModeBCK
        $UserName = $config.UserName
        $WorkerName = $config.WorkerName
        if ([string]::IsNullOrWhiteSpace($WorkerName)) {$WorkerName = $env:COMPUTERNAME}
        $CoinsWallets = @{}
        ((Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*', '').Trim() |
            ForEach-Object {$CoinsWallets.add(($_ -split "=")[0], ($_ -split "=")[1])}

        [string]$ElapsedDonationTime + "_0" | Set-Content  -Path Donation.ctr
    }


    $MinerWindowStyle = $config.MinerWindowStyle
    if ([string]::IsNullOrEmpty($MinerWindowStyle)) {$MinerWindowStyle = 'Minimized'}

    $MinerStatusUrl = $config.MinerStatusUrl
    $MinerStatusKey = $config.MinerStatusKey
    if ([string]::IsNullOrEmpty($MinerStatusKey)) {$MinerStatusKey = $CoinsWallets.get_item("BTC")}

    ErrorsToLog $LogFile


    #get actual hour electricity cost
    $ElectricityCostValue = [double](($config.ElectricityCost | ConvertFrom-Json) |
            Where-Object HourStart -le (Get-Date).Hour |
            Where-Object HourEnd -ge (Get-Date).Hour).CostKwh
    WriteLog "Loading Pools Information............." $LogFile $True

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
    do {
        $Pools = Get_Pools `
            -Querymode "core" `
            -PoolsFilterList $PoolsName `
            -CoinFilterList $CoinsName `
            -Location $Location `
            -AlgoFilterList $Algorithm
        if ($Pools.Count -eq 0) {
            $Msg = "NO POOLS!....retry in 10 sec --- REMEMBER, IF YOUR ARE MINING ON ANONYMOUS WITHOUT AUTOEXCHANGE POOLS LIKE YIIMP, NANOPOOL, ETC. YOU MUST SET WALLET FOR AT LEAST ONE POOL COIN IN CONFIG.TXT"
            WriteLog $msg $LogFile $True

            Start-Sleep 10
        }
    }
    while ($Pools.Count -eq 0)

    $Pools | Select-Object name -unique | ForEach-Object {Writelog ("Pool " + $_.name + " was responsive....") $LogFile $True}

    writelog ("Detected " + [string]$Pools.count + " pools......") $logfile $true

    #Filter by minworkers variable (only if there is any pool greater than minimum)
    $PoolsFiltered = ($Pools | Where-Object {$_.PoolWorkers -ge $config.MinWorkers -or $_.PoolWorkers -eq $null})
    if ($PoolsFiltered.count -ge 1) {
        $Pools = $PoolsFiltered
        writelog ([string]$Pools.Count + " pools left after min workers filter.....") $logfile $true
    } else {
        writelog ("No pools with workers greater than minimum config, filter is discarded.....") $logfile $true
    }
    Remove-Variable PoolsFiltered

    ### Check if pools are alive
    $PoolsFiltered = @()
    foreach ($Pool in $Pools) {
        if (Query_TCPPort -Server $Pool.Host -Port $Pool.Port -Timeout 100) {
            $PoolsFiltered += $Pool
        } else {
            WriteLog "$($Pool.PoolName): $($Pool.Host):$($Pool.Port) is not responding!" $LogFile $true
        }
    }
    $Pools = $PoolsFiltered
    Remove-Variable PoolsFiltered

    #Call api to local currency conversion
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice/$LocalCurrency.json" -UseBasicParsing -TimeoutSec 5 |
            ConvertFrom-Json |
            Select-Object -ExpandProperty BPI
        $LocalBTCvalue = $CDKResponse.$LocalCurrency.rate_float
        Writelog ("CoinDesk API was responsive..........") $LogFile $True
    } catch {
        WriteLog "Coindesk api not responding, not possible/deactuallized local coin conversion.........." $logfile $true
    }


    #Load information about the Miner asociated to each Coin-Algo-Miner
    $Miners = @()

    foreach ($MinerFile in (Get-ChildItem "Miners" -Filter "*.json")) {
        try { $Miner = $MinerFile | Get-Content | ConvertFrom-Json }
        catch {
            Writelog "-------BAD FORMED JSON: $MinerFile" $LogFile $True
            Exit
        }

        ForEach ($TypeGroup in $types) {
            #generate a line for each gpu group that has algorithm as valid
            if ($Miner.Type -ne $TypeGroup.type) {continue} #check group and miner types are the same

            foreach ($Algo in $Miner.Algorithms.PSObject.Properties) {

                ##Algoname contains real name for dual and no dual miners
                $AlgoName = get_algo_unified_name (($Algo.Name -split ("_"))[0])
                $AlgoNameDual = get_algo_unified_name (($Algo.Name -split ("_"))[1])
                $AlgoLabel = ($Algo.Name -split ("_"))[2]
                $Algorithms = $AlgoName
                if (![string]::IsNullOrEmpty($AlgoNameDual)) {$Algorithms += "_" + $AlgoNameDual}

                if ($Typegroup.Algorithms -notcontains $Algorithms -and ![string]::IsNullOrEmpty($Typegroup.Algorithms)) {continue} #check config has this algo as minable

                Foreach ($Pool in ($Pools | Where-Object Algorithm -eq $AlgoName)) {
                    #Search pools for that algo

                    if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne $null) -or [string]::IsNullOrEmpty($AlgoNameDual)) {

                        #Set flag if both Miner and Pool support SSL
                        $enableSSL = ($Miner.SSL -and $Pool.SSL)

                        #Replace wildcards patterns
                        if ($Pool.PoolName -eq 'Nicehash') {
                            $WorkerName2 = $WorkerName + $TypeGroup.GroupName #Nicehash requires alphanumeric WorkerNames
                        } else {
                            $WorkerName2 = $WorkerName + '_' + $TypeGroup.GroupName
                        }
                        $PoolUser = $Pool.User -replace '#WorkerName#', $WorkerName2

                        $Arguments = $Miner.Arguments `
                            -replace '#PORT#', $(if ($enableSSL) {$Pool.PortSSL} else {$Pool.Port}) `
                            -replace '#SERVER#', $(if ($enableSSL) {$Pool.HostSSL} else {$Pool.Host}) `
                            -replace '#PROTOCOL#', $(if ($enableSSL) {$Pool.ProtocolSSL} else {$Pool.Protocol}) `
                            -replace '#LOGIN#', $Pool.User `
                            -replace '#PASSWORD#', $Pool.Pass `
                            -replace "#GpuPlatform#", $TypeGroup.GpuPlatform  `
                            -replace '#ALGORITHM#', $Algoname `
                            -replace '#ALGORITHMPARAMETERS#', $Algo.Value `
                            -replace '#WorkerName#', $WorkerName2 `
                            -replace '#DEVICES#', $TypeGroup.Gpus `
                            -replace '#DEVICESCLAYMODE#', $TypeGroup.GpusClayMode `
                            -replace '#DEVICESETHMODE#', $TypeGroup.GpusETHMode `
                            -replace '#GroupName#', $TypeGroup.GroupName `
                            -replace "#ETHSTMODE#", $Pool.EthStMode `
                            -replace "#DEVICESNSGMODE#", $TypeGroup.GpusNsgMode
                        if (![string]::IsNullOrEmpty($Miner.PatternConfigFile)) {
                            $ConfigFileArguments = replace_foreach_gpu (Get-Content $Miner.PatternConfigFile -raw) $TypeGroup.Gpus
                            $ConfigFileArguments = $ConfigFileArguments `
                                -replace '#PORT#', $(if ($enableSSL) {$Pool.PortSSL} else {$Pool.Port}) `
                                -replace '#SERVER#', $(if ($enableSSL) {$Pool.HostSSL} else {$Pool.Host}) `
                                -replace '#PROTOCOL#', $(if ($enableSSL) {$Pool.ProtocolSSL} else {$Pool.Protocol}) `
                                -replace '#LOGIN#', $Pool.User `
                                -replace '#PASSWORD#', $Pool.Pass `
                                -replace "#GpuPlatform#", $TypeGroup.GpuPlatform `
                                -replace '#ALGORITHM#', $Algoname `
                                -replace '#ALGORITHMPARAMETERS#', $Algo.Value `
                                -replace '#WorkerName#', $WorkerName2 `
                                -replace '#DEVICES#', $TypeGroup.Gpus `
                                -replace '#DEVICESCLAYMODE#', $TypeGroup.GpusClayMode `
                                -replace '#DEVICESETHMODE#', $TypeGroup.GpusETHMode `
                                -replace '#GroupName#', $TypeGroup.GroupName `
                                -replace "#ETHSTMODE#", $Pool.EthStMode `
                                -replace "#DEVICESNSGMODE#", $TypeGroup.GpusNsgMode
                        }

                        #Adjust pool price by pool defined factor
                        $PoolProfitFactor = [double]($config.("PoolProfitFactor_" + $Pool.name))
                        if ($PoolProfitFactor -eq 0) { $PoolProfitFactor = 1}

                        #select correct price by mode
                        if ($MiningMode -eq 'Automatic24h') {$Price = [double]$Pool.Price24h * $PoolProfitFactor}
                        else {$Price = [double]$Pool.Price * $PoolProfitFactor}

                        #Search for dualmining pool
                        if (![string]::IsNullOrEmpty($AlgoNameDual)) {
                            #Adjust pool dual price by pool defined factor
                            $PoolProfitFactorDual = [double]($config.("PoolProfitFactor_" + $PoolDual.name))
                            if ($PoolProfitFactorDual -eq 0) { $PoolProfitFactorDual = 1}

                            #search dual pool and select correct price by mode
                            if ($MiningMode -eq 'Automatic24h') {
                                $PoolDual = $Pools | Where-Object Algorithm -eq $AlgoNameDual | Sort-Object Price24h -Descending | Select-Object -First 1
                                $PriceDual = [double]$PoolDual.Price24h * $PoolProfitFactor
                            } else {
                                $PoolDual = $Pools | Where-Object Algorithm -eq $AlgoNameDual | Sort-Object Price -Descending | Select-Object -First 1
                                $PriceDual = [double]$PoolDual.Price * $PoolProfitFactor
                            }

                            #Set flag if both Miner and Pool support SSL
                            $enableDualSSL = ($Miner.SSL -and $PoolDual.SSL)

                            #Replace wildcards patterns
                            $WorkerName3 = $WorkerName2 + 'D'
                            $PoolUserDual = $PoolDual.User -replace '#WorkerName#', $WorkerName3

                            $Arguments = $Arguments `
                                -replace '#PORTDUAL#', $(if ($enableDualSSL) {$PoolDual.PortSSL} else {$PoolDual.Port}) `
                                -replace '#SERVERDUAL#', $(if ($enableDualSSL) {$PoolDual.HostSSL} else {$PoolDual.Host}) `
                                -replace '#PROTOCOLDUAL#', $(if ($enableDualSSL) {$PoolDual.ProtocolSSL} else {$PoolDual.Protocol}) `
                                -replace '#LOGINDUAL#', $PoolDual.User `
                                -replace '#PASSWORDDUAL#', $PoolDual.Pass `
                                -replace '#ALGORITHMDUAL#', $AlgonameDual `
                                -replace '#WorkerName#', $WorkerName3
                            if (![string]::IsNullOrEmpty($Miner.PatternConfigFile)) {
                                $ConfigFileArguments = $ConfigFileArguments `
                                    -replace '#PORTDUAL#', $(if ($enableDualSSL) {$PoolDual.PortSSL} else {$PoolDual.Port}) `
                                    -replace '#SERVERDUAL#', $(if ($enableDualSSL) {$PoolDual.HostSSL} else {$PoolDual.Host}) `
                                    -replace '#PROTOCOLDUAL#', $(if ($enableDualSSL) {$PoolDual.ProtocolSSL} else {$PoolDual.Protocol}) `
                                    -replace '#LOGINDUAL#', $PoolDual.User `
                                    -replace '#PASSWORDDUAL#', $PoolDual.Pass `
                                    -replace '#ALGORITHMDUAL#', $AlgoNameDual `
                                    -replace '#WorkerName#', $WorkerName3
                            }
                        }


                        #SubMiner are variations of miner that not need to relaunch
                        #Creates a "SubMiner" object for each PL
                        $SubMiners = @()
                        Foreach ($PowerLimit in ($TypeGroup.PowerLimits)) {
                            #always exists as least a power limit 0

                            #writelog ("$MinerFile $AlgoName "+$TypeGroup.GroupName+" "+$Pool.Info+" $PowerLimit") $logfile $true

                            #look in Activeminers collection if we found that miner to conserve some properties and not read files
                            $FoundMiner = $ActiveMiners | Where-Object {
                                $_.Name -eq $Minerfile.basename -and
                                $_.Coin -eq $Pool.Info -and
                                $_.Algorithm -eq $AlgoName -and
                                $_.CoinDual -eq $PoolDual.Info -and
                                $_.AlgorithmDual -eq $AlgoNameDual -and
                                $_.PoolAbbName -eq $Pool.AbbName -and
                                $_.PoolAbbNameDual -eq $PoolDual.AbbName -and
                                $_.GpuGroup.Id -eq $TypeGroup.Id -and
                                $_.AlgoLabel -eq $AlgoLabel }

                            $FoundSubminer = $FoundMiner.SubMiners | Where-Object { $_.powerlimit -eq $PowerLimit}

                            if ($FoundSubminer -eq $null) {
                                $Hrs = Get_HashRates `
                                    -Algorithm $Algorithms `
                                    -MinerName $Minerfile.Basename `
                                    -GroupName $TypeGroup.GroupName `
                                    -PowerLimit $PowerLimit `
                                    -AlgoLabel  $AlgoLabel |
                                    Where-Object {$_.TimeSinceStartInterval -gt ($_.BenchmarkintervalTime * 0.66)}
                            } else {
                                $Hrs = $FoundSubminer.SpeedReads
                            }

                            $PowerValue = [double]($Hrs | Measure-Object -property Power -average).average
                            $HashRateValue = [double]($Hrs | Measure-Object -property Speed -average).average
                            $HashRateValueDual = [double]($Hrs | Measure-Object -property SpeedDual -average).average


                            #calculates revenue
                            $SubMinerRevenue = [double]($HashRateValue * $Price)
                            $SubMinerRevenueDual = [Double]([double]$HashRateValueDual * $PriceDual)

                            #apply fee to revenues
                            if ($enableSSL -and [double]$Miner.FeeSSL -gt 0) {
                                $SubMinerRevenue -= ($SubMinerRevenue * [double]$Miner.feeSSL)
                            } elseif ([double]$Miner.Fee -gt 0) {
                                $SubMinerRevenue -= ($SubMinerRevenue * [double]$Miner.fee)
                            }

                            if ($enableDualSSL -and [double]$Miner.FeeSSL -gt 0) {
                                $SubMinerRevenueDual -= ($SubMinerRevenueDual * [double]$Miner.feeSSL)
                            } elseif ([double]$Miner.Fee -gt 0) {
                                $SubMinerRevenueDual -= ($SubMinerRevenueDual * [double]$Miner.fee)
                            }

                            if ([double]$Pool.Fee -gt 0) {$SubMinerRevenue -= ($SubMinerRevenue * [double]$Pool.fee)} #PoolFee
                            if ([double]$PoolDual.Fee -gt 0) {$SubMinerRevenueDual -= ($SubMinerRevenueDual * [double]$PoolDual.fee)}

                            if ($FoundSubminer -eq $null) {
                                $StatsHistory = Get_Stats `
                                    -Algorithm $Algorithms `
                                    -MinerName $Minerfile.BaseName `
                                    -GroupName $TypeGroup.GroupName `
                                    -PowerLimit $PowerLimit `
                                    -AlgoLabel $AlgoLabel
                            } else {
                                $StatsHistory = $FoundSubminer.StatsHistory
                            }
                            $Stats = [pscustomobject]@{
                                BestTimes        = 0
                                BenchmarkedTimes = 0
                                LastTimeActive   = [TimeSpan]0
                                ActivatedTimes   = 0
                                ActiveTime       = [TimeSpan]0
                                FailedTimes      = 0
                                StatsTime        = [TimeSpan]0
                            }
                            if ($StatsHistory -eq $null) {$StatsHistory = $stats}

                            if ($SubMiners.count -eq 0 -or $SubMiners[0].StatsHistory.BestTimes -gt 0) {
                                #only add a SubMiner (distint from first if sometime first was best)
                                $SubMiners += [pscustomObject]@{
                                    Id                     = $SubMiners.count
                                    Best                   = $False
                                    BestBySwitch           = ""
                                    HashRate               = $HashRateValue
                                    HashRateDual           = $HashRateValueDual
                                    NeedBenchmark          = [bool]($HashRateValue -eq 0 -or ($AlgorithmDual -ne $null -and $HashRateValueDual -eq 0))
                                    PowerAvg               = $PowerValue
                                    PowerLimit             = [int]$PowerLimit
                                    PowerLive              = 0
                                    Profits                = (($SubMinerRevenue + $SubMinerRevenueDual) * $localBTCvalue) - ($ElectricityCostValue * ($PowerValue * 24) / 1000) #Profit is revenue less electricity cost
                                    ProfitsLive            = 0
                                    Revenue                = $SubMinerRevenue
                                    RevenueDual            = $SubMinerRevenueDual
                                    RevenueLive            = 0
                                    RevenueLiveDual        = 0
                                    SpeedLive              = 0
                                    SpeedLiveDual          = 0
                                    SpeedReads             = if ($Hrs -ne $null) {[array]$Hrs} else {@()}
                                    Status                 = 'Idle'
                                    Stats                  = $Stats
                                    StatsHistory           = $StatsHistory
                                    TimeSinceStartInterval = [TimeSpan]0
                                }
                            }
                        }

                        $Miners += [pscustomobject] @{
                            AlgoLabel           = $AlgoLabel
                            Algorithm           = $AlgoName
                            AlgorithmDual       = $AlgoNameDual
                            Algorithms          = $Algorithms
                            API                 = $Miner.API
                            Arguments           = $Arguments
                            BenchmarkArg        = $Miner.BenchmarkArg
                            Coin                = $Pool.Info
                            CoinDual            = $PoolDual.Info
                            ConfigFileArguments = $ConfigFileArguments
                            ExtractionPath      = ".\Bin\" + $Minerfile.basename + "\"
                            GenerateConfigFile  = $(if (![string]::IsNullOrEmpty($Miner.GenerateConfigFile)) {
                                    ".\Bin\" + $Minerfile.basename + "\" + $Miner.GenerateConfigFile `
                                        -Replace [RegEx]::Escape($Miner.ExtractionPath), "" `
                                        -Replace '#GroupName#', $TypeGroup.GroupName
                                })
                            GpuGroup            = $TypeGroup
                            Host                = $Pool.Host
                            Location            = $Pool.location
                            MinerFee            = $(if ($enableSSL -and [double]$Miner.FeeSSL -gt 0) { [double]$Miner.feeSSL } elseif ([double]$Miner.Fee -gt 0) { [double]$Miner.Fee })
                            Name                = $Minerfile.basename
                            Path                = $(".\Bin\" + $Minerfile.basename + "\" + $Miner.Path -Replace [RegEx]::Escape($Miner.ExtractionPath), "")
                            PoolAbbName         = $Pool.AbbName
                            PoolAbbNameDual     = $PoolDual.AbbName
                            PoolFee             = $(if ($Pool.Fee -ne $null) {[double]$Pool.fee})
                            PoolName            = $Pool.PoolName
                            PoolNameDual        = $PoolDual.PoolName
                            PoolPrice           = $(if ($MiningMode -eq 'Automatic24h') {[double]$Pool.Price24h} else {[double]$Pool.Price})
                            PoolPriceDual       = $(if ($MiningMode -eq 'Automatic24h') {[double]$PoolDual.Price24h} else {[double]$PoolDual.Price})
                            PoolRewardType      = $Pool.RewardType
                            PoolWorkers         = $Pool.PoolWorkers
                            PoolWorkersDual     = $PoolDual.PoolWorkers
                            Port                = $(if (($Types | Where-Object type -eq $TypeGroup.type).count -le 1 -and $DelayCloseMiners -eq 0) { $miner.ApiPort })
                            PrelaunchCommand    = $Miner.PrelaunchCommand
                            SubMiners           = $SubMiners
                            SHA256              = $Miner.SHA256
                            Symbol              = $Pool.Symbol
                            SymbolDual          = $PoolDual.Symbol
                            URI                 = $Miner.URI
                            Username            = $PoolUser
                            UsernameDual        = $PoolUserDual
                            WalletMode          = $Pool.WalletMode
                            WalletSymbol        = $Pool.WalletSymbol
                            WorkerName          = $WorkerName2
                            WorkerNameDual      = $WorkerName3
                        }
                    }    #dualmining
                }  #end foreach pool
            } #end foreach algo
        } #  end if types
    } #end foreach miner


    Writelog ("Miners/Pools combinations detected: " + [string]($Miners.count) + ".........") $LogFile $true

    #Launch download of miners
    $Miners |
        Where-Object { `
            ![string]::IsNullOrEmpty($_.URI) -and `
            ![string]::IsNullOrEmpty($_.ExtractionPath) -and `
            ![string]::IsNullOrEmpty($_.Path)} |
        Select-Object URI, ExtractionPath, Path, SHA256 -Unique |
        ForEach-Object {
        Start_Downloader -URI $_.URI -ExtractionPath $_.ExtractionPath -Path $_.Path -SHA256 $_.SHA256
    }

    ErrorsToLog $LogFile

    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {Writelog "NO MINERS!" $LogFile $True; EXIT}


    #Update the active miners list which is alive for  all execution time
    ForEach ($ActiveMiner in ($ActiveMiners | Sort-Object [int]id)) {
        #Search existant miners to update data


        $Miner = $miners | Where-Object {$_.Name -eq $ActiveMiner.Name -and
            $_.Coin -eq $ActiveMiner.Coin -and
            $_.Algorithm -eq $ActiveMiner.Algorithm -and
            $_.CoinDual -eq $ActiveMiner.CoinDual -and
            $_.AlgorithmDual -eq $ActiveMiner.AlgorithmDual -and
            $_.PoolAbbName -eq $ActiveMiner.PoolAbbName -and
            $_.PoolAbbNameDual -eq $ActiveMiner.PoolAbbNameDual -and
            $_.GpuGroup.Id -eq $ActiveMiner.GpuGroup.Id -and
            $_.AlgoLabel -eq $ActiveMiner.AlgoLabel }

        if (($Miner | Measure-Object).count -gt 1) {Clear-Host; Writelog ("DUPLICATED ALGO " + $MINER.ALGORITHM + " ON " + $MINER.NAME) $LogFile $true ; EXIT}

        if ($Miner) {
            # we found that miner
            $ActiveMiner.Arguments = $miner.Arguments
            $ActiveMiner.PoolPrice = $Miner.PoolPrice
            $ActiveMiner.PoolPriceDual = $Miner.PoolPriceDual
            $ActiveMiner.PoolFee = $Miner.PoolFee
            $ActiveMiner.PoolWorkers = $Miner.PoolWorkers
            $ActiveMiner.IsValid = $true

            foreach ($SubMiner in $miner.SubMiners) {
                if (($ActiveMiner.SubMiners | Where-Object {$_.Id -eq $SubMiner.Id}).count -eq 0) {
                    $SubMiner | Add-Member IdF $ActiveMiner.Id
                    $ActiveMiner.SubMiners += $SubMiner
                } else {
                    $ActiveMiner.SubMiners[$SubMiner.Id].HashRate = $SubMiner.HashRate
                    $ActiveMiner.SubMiners[$SubMiner.Id].HashRateDual = $SubMiner.HashRateDual
                    $ActiveMiner.SubMiners[$SubMiner.Id].NeedBenchmark = $SubMiner.NeedBenchmark
                    $ActiveMiner.SubMiners[$SubMiner.Id].PowerAvg = $SubMiner.PowerAvg
                    $ActiveMiner.SubMiners[$SubMiner.Id].Profits = $SubMiner.Profits
                    $ActiveMiner.SubMiners[$SubMiner.Id].Revenue = $SubMiner.Revenue
                    $ActiveMiner.SubMiners[$SubMiner.Id].RevenueDual = $SubMiner.RevenueDual
                }
            }
        } else {
            #An existant miner is not found now
            $ActiveMiner.IsValid = $false
        }
    }


    ##Add new miners to list
    ForEach ($miner in $miners) {

        $ActiveMiner = $ActiveMiners | Where-Object {$_.Name -eq $Miner.Name -and
            $_.Coin -eq $Miner.Coin -and
            $_.Algorithm -eq $Miner.Algorithm -and
            $_.CoinDual -eq $Miner.CoinDual -and
            $_.AlgorithmDual -eq $Miner.AlgorithmDual -and
            $_.PoolAbbName -eq $Miner.PoolAbbName -and
            $_.PoolAbbNameDual -eq $Miner.PoolAbbNameDual -and
            $_.GpuGroup.Id -eq $Miner.GpuGroup.Id -and
            $_.AlgoLabel -eq $Miner.AlgoLabel}


        if ($ActiveMiner -eq $null) {
            $Miner.SubMiners | Add-Member IdF $ActiveMiners.count
            $ActiveMiners += [pscustomObject]@{
                AlgoLabel            = $Miner.AlgoLabel
                Algorithm            = $Miner.Algorithm
                AlgorithmDual        = $Miner.AlgorithmDual
                Algorithms           = $Miner.Algorithms
                API                  = $Miner.API
                Arguments            = $Miner.Arguments
                BenchmarkArg         = $Miner.BenchmarkArg
                ConsecutiveZeroSpeed = 0
                Coin                 = $Miner.coin
                CoinDual             = $Miner.CoinDual
                ConfigFileArguments  = $Miner.ConfigFileArguments
                GenerateConfigFile   = $Miner.GenerateConfigFile
                GpuGroup             = $Miner.GpuGroup
                Host                 = $Miner.Host
                Id                   = $ActiveMiners.count
                IsValid              = $true
                Location             = $Miner.Location
                MinerFee             = $Miner.MinerFee
                Name                 = $Miner.Name
                Path                 = Convert-Path $Miner.Path
                PoolAbbName          = $Miner.PoolAbbName
                PoolAbbNameDual      = $Miner.PoolAbbNameDual
                PoolFee              = $Miner.PoolFee
                PoolName             = $Miner.PoolName
                PoolNameDual         = $Miner.PoolNameDual
                PoolPrice            = $Miner.PoolPrice
                PoolPriceDual        = $Miner.PoolPriceDual
                PoolWorkers          = $Miner.PoolWorkers
                PoolHashRate         = $null
                PoolHashRateDual     = $null
                PoolRewardType       = $Miner.PoolRewardType
                Port                 = $Miner.Port
                PrelaunchCommand     = $Miner.PrelaunchCommand
                Process              = $null
                SubMiners            = $Miner.SubMiners
                Symbol               = $Miner.Symbol
                SymbolDual           = $Miner.SymbolDual
                Username             = $Miner.Username
                UsernameDual         = $Miner.UsernameDual
                WalletMode           = $Miner.WalletMode
                WalletSymbol         = $Miner.WalletSymbol
                WorkerName           = $Miner.WorkerName
                WorkerNameDual       = $Miner.WorkerNameDual
            }
        }
    }

    Writelog ("Active Miners-pools: " + [string]($ActiveMiners.count) + ".........") $LogFile $True
    ErrorsToLog $LogFile
    Writelog ("Pending benchmarks: " + [string](($ActiveMiners.SubMiners | Where-Object NeedBenchmark -eq $true).count) + ".........") $LogFile $true

    if ($DetailedLog) {
        $msg = $ActiveMiners.SubMiners | ForEach-Object { [string] $_.Idf + '-' + [string]$_.Id + ',' + $ActiveMiners[$_.idf].gpugroup.GroupName + ',' + $ActiveMiners[$_.idf].IsValid + ', PL' + [string]$_.PowerLimit + ',' + $_.Status + ',' + $ActiveMiners[$_.idf].name + ',' + $ActiveMiners[$_.idf].algorithms + ',' + $ActiveMiners[$_.idf].Coin + ',' + [string]($ActiveMiners[$_.idf].process.id) + "`r`n"}
        Writelog $msg $LogFile $false
    }

    #For each type, select most profitable miner, not benchmarked has priority, only new miner is lauched if new profit is greater than old by percenttoswitch
    #This section changes SubMiner
    foreach ($Type in $Types) {

        #look for last round best
        $Candidates = $ActiveMiners | Where-Object {$_.GpuGroup.Id -eq $Type.Id}
        $BestLast = $Candidates.SubMiners | Where-Object {$_.Status -eq "Running" -or $_.Status -eq 'PendingCancellation'}
        if ($BestLast -ne $null) {
            $ProfitLast = $BestLast.profits
            $BestLastLogMsg = $ActiveMiners[$BestLast.IdF].name + "/" + $ActiveMiners[$BestLast.IdF].Algorithms + '/' + $ActiveMiners[$BestLast.IdF].Coin + " with Power Limit " + [string]$BestLast.PowerLimit + " (id " + [string]$BestLast.IdF + "-" + [string]$BestLast.Id + ") for group " + $Type.GroupName
        } else {
            $ProfitLast = 0
        }

        #check if must cancell miner/algo/coin combo
        if ($BestLast.Status -eq 'PendingCancellation') {
            if (($ActiveMiners[$BestLast.IdF].SubMiners.stats.FailedTimes | Measure-Object -sum).sum -ge 2) {
                $ActiveMiners[$BestLast.IdF].SubMiners | ForEach-Object {$_.Status = 'Cancelled'}
                Writelog ("Detected more than 3 fails, cancelling combination for $BestNowLogMsg") $LogFile $true
            }
        }

        #look for best for next round
        $Candidates = $ActiveMiners | Where-Object {$_.GpuGroup.Id -eq $Type.Id -and $_.IsValid -and $_.Status -ne 'Cancelled'}

        # First try to select a miner that needs benchmark with the highest pool price
        $BestNow = $Candidates.SubMiners |
            Where-Object NeedBenchmark |
            Sort-Object -Descending {$Activeminers[$_.IdF].PoolPrice}, {$Activeminers[$_.IdF].PoolPriceDual} |
            Select-Object -First 1

        # If no miners need benchmark, select a miner with the highest Profits, and making sure they are above zero, to not mine with loss
        if ($BestNow -eq $null) {
            $BestNow = $Candidates.SubMiners |
                Where-Object Profits -gt 0 |
                Sort-Object -Descending Profits, {$Activeminers[$_.IdF].Algorithm}, {$Activeminers[$_.IdF].PoolPrice}, PowerLimit |
                Select-Object -First 1
        }
        if ($BestNow -eq $null) {Writelog ("No detected any valid candidate for gpu group " + $Type.GroupName) $LogFile $true  ; break  }
        $BestNowLogMsg = $ActiveMiners[$BestNow.IdF].name + "/" + $ActiveMiners[$BestNow.IdF].Algorithms + '/' + $ActiveMiners[$BestNow.IdF].Coin + " with Power Limit " + [string]$BestNow.PowerLimit + " (id " + [string]$BestNow.IdF + "-" + [string]$BestNow.Id + ") for group " + $Type.GroupName
        $ProfitNow = $BestNow.Profits

        if ($BestNow.NeedBenchmark -eq $false) {
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.BestTimes++
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.BestTimes++
        } else { $NextInterval = $BenchmarkintervalTime }

        Writelog ("$BestNowLogMsg is the best combination for gpu group, last was id " + [string]$BestLast.Idf + "-" + [string]$BestLast.Id) $LogFile $true

        if ($BestLast.IdF -ne $BestNow.IdF -or $BestLast.Id -ne $BestNow.Id -or $BestLast.Status -eq 'PendingCancellation' -or $BestLast.Status -eq 'Cancelled') {
            #something changes or some miner error

            if ($BestLast.IdF -eq $BestNow.IdF -and $BestLast.Id -ne $BestNow.Id) {
                #Must launch other SubMiner
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type = 'NVIDIA' -and $BestNow.PowerLimit -gt 0) {set_Nvidia_Powerlimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].GpuGroup.gpus}
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type = 'AMD' -and $BestNow.PowerLimit -gt 0) {}

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].best = $true
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Status = "Running"
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0
                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].best = $false
                Switch ($BestLast.Status) {
                    "Running" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Idle"}
                    "PendingCancellation" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Failed"}
                    "Cancelled" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Cancelled"}
                }

                Writelog ("$BestNowLogMsg - Marked as running, changed Power Limit from " + $BestLast.PowerLimit) $LogFile $true

            } elseif ($ProfitNow -gt ($ProfitLast * (1 + ($PercentToSwitch2 / 100))) -or $BestNow.NeedBenchmark -or $BestLast.Status -eq 'PendingCancellation' -or $BestLast.Status -eq 'Cancelled' -or $BestLast -eq $null) {
                #Must launch other miner and stop actual

                #Stop old
                if ($BestLast -ne $null) {

                    WriteLog ("Killing in " + [string]$DelayCloseMiners + " seconds $BestLastLogMsg with system process id " + [string]$ActiveMiners[$BestLast.IdF].Process.Id) $LogFile

                    if ($Bestnow.NeedBenchmark -or $DelayCloseMiners -eq 0 -or $BestLast.Status -eq 'PendingCancellation') {
                        #inmediate kill
                        Kill_Process $ActiveMiners[$BestLast.IdF].Process
                    } else {
                        #delayed kill
                        $Code = {
                            param($Process, $DelaySeconds)
                            Start-Sleep -Seconds $DelaySeconds
                            $Process.CloseMainWindow() | Out-Null
                            Stop-Process $Process.Id -force -wa SilentlyContinue -ea SilentlyContinue
                        }
                        Start-Job -ScriptBlock $Code -ArgumentList ($ActiveMiners[$BestLast.IdF].Process), $DelayCloseMiners
                    }

                    $ActiveMiners[$BestLast.IdF].Process = $null
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].best = $false
                    Switch ($BestLast.Status) {
                        "Running" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Idle"}
                        "PendingCancellation" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Failed"}
                        "Cancelled" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Cancelled"}
                    }
                }

                #Start New
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type -eq 'NVIDIA' -and $BestNow.PowerLimit -gt 0) {set_Nvidia_Powerlimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].GpuGroup.gpus}
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type -eq 'AMD' -and $BestNow.PowerLimit -gt 0) {}

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].best = $true

                if ($ActiveMiners[$BestNow.IdF].Port -eq $null) { $ActiveMiners[$BestNow.IdF].Port = get_next_free_port (Get-Random -minimum 2000 -maximum 48000)}
                $ActiveMiners[$BestNow.IdF].Arguments = $ActiveMiners[$BestNow.IdF].Arguments -replace '#APIPORT#', $ActiveMiners[$BestNow.IdF].Port
                $ActiveMiners[$BestNow.IdF].ConfigFileArguments = $ActiveMiners[$BestNow.IdF].ConfigFileArguments -replace '#APIPORT#', $ActiveMiners[$BestNow.IdF].Port
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].stats.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].statsHistory.ActivatedTimes++
                if (![string]::IsNullOrEmpty($ActiveMiners[$BestNow.IdF].GenerateConfigFile)) {$ActiveMiners[$BestNow.IdF].ConfigFileArguments | Set-Content ($ActiveMiners[$BestNow.IdF].GenerateConfigFile)}
                if (![string]::IsNullOrEmpty($ActiveMiners[$BestNow.IdF].PrelaunchCommand)) {Start-Process -FilePath $ActiveMiners[$BestNow.IdF].PrelaunchCommand}                                             #run prelaunch command

                $Arguments = $ActiveMiners[$BestNow.IdF].Arguments
                if ($ActiveMiners[$BestNow.IdF].NeedBenchmark -and ![string]::IsNullOrWhiteSpace($ActiveMiners[$BestNow.IdF].BenchmarkArg)) {$Arguments += " " + $ActiveMiners[$BestNow.IdF].BenchmarkArg }

                if ($ActiveMiners[$BestNow.IdF].Api -eq "Wrapper") {
                    $ActiveMiners[$BestNow.IdF].Process = Start_SubProcess `
                        -FilePath ((Get-Process -Id $Global:PID).path) `
                        -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($ActiveMiners[$BestNow.IdF].Port)' -FilePath '$($ActiveMiners[$BestNow.IdF].Path)' -ArgumentList '$($Arguments)' -WorkingDirectory '$(Split-Path $ActiveMiners[$BestNow.IdF].Path)'" `
                        -WorkingDirectory (Split-Path $ActiveMiners[$BestNow.IdF].Path) `
                        -MinerWindowStyle $MinerWindowStyle `
                        -Priority $(if ($ActiveMiners[$BestNow.IdF].GroupType -eq "CPU") {-2} else {-1})
                } else {
                    $ActiveMiners[$BestNow.IdF].Process = Start_SubProcess `
                        -FilePath $ActiveMiners[$BestNow.IdF].Path `
                        -ArgumentList $Arguments `
                        -WorkingDirectory (Split-Path $ActiveMiners[$BestNow.IdF].Path) `
                        -MinerWindowStyle $MinerWindowStyle `
                        -Priority $(if ($ActiveMiners[$BestNow.IdF].GroupType -eq "CPU") {-2} else {-1})
                }

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Status = "Running"
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.StatsTime = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0
                Writelog ("Started System process Id " + [string]($ActiveMiners[$BestNow.IdF].Process.Id) + " for $BestNowLogMsg --> " + $ActiveMiners[$BestNow.IdF].Path + " " + $ActiveMiners[$BestNow.IdF].Arguments) $LogFile $false

            } else {
                #Must mantain last miner by switch
                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].best = $true
                if ($Profitlast -lt $ProfitNow) {
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].BestBySwitch = "*"
                    Writelog ("$BestNowLogMsg continue mining due to @@percenttoswitch value") $LogFile $true
                }
            }
        }


        Set_Stats `
            -Algorithm $ActiveMiners[$BestNow.IdF].Algorithms `
            -MinerName $ActiveMiners[$BestNow.IdF].Name `
            -GroupName $ActiveMiners[$BestNow.IdF].GpuGroup.GroupName `
            -AlgoLabel $ActiveMiners[$BestNow.IdF].AlgoLabel `
            -Powerlimit $BestNow.PowerLimit `
            -Value $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory
    }

    ErrorsToLog $LogFile

    $RunningSubminers = ($ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Select-Object Idf).Idf
    foreach ($RunningSubMiner in $RunningSubMiners) {
        $PItime = $config.("Interval_" + $ActiveMiners[$RunningSubMiner].PoolRewardType)
        WriteLog ("Interval for pool " + [string]$ActiveMiners[$RunningSubMiner].PoolName + " is " + $PItime) $LogFile $False
        if ([int]$PItime -lt $NextInterval) {$NextInterval = [int]$PItime}
    }

    $FirstLoopExecution = $True
    $LoopStarttime = Get-Date

    ErrorsToLog $LogFile
    $SwitchLoop = 0
    $GpuActivityAverages = @()

    Clear-Host; $repaintScreen = $true

    while ($Host.UI.RawUI.KeyAvailable) {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush



    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------

    #loop to update info and check if miner is running, exit loop is forced inside
    While ($true) {

        $SwitchLoop++
        if ($SwitchLoop -gt 10) {$SwitchLoop = 0} #reduces 10-1 ratio of execution

        $ExitLoop = $false

        $Devices = get_devices_information $Types

        #############################################################

        #Check Live Speed and record benchmark if necessary
        $ActiveMiners.SubMiners | Where-Object Best -eq $true | ForEach-Object {
            if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.Stats.BenchmarkedTimes++; $_.StatsHistory.BenchmarkedTimes++}
            $_.SpeedLive = 0
            $_.SpeedLiveDual = 0
            $_.ProfitsLive = 0
            $_.RevenueLive = 0
            $_.RevenueLiveDual = 0

            $Miner_HashRates = $null
            $Miner_HashRates = Get_Live_HashRate $ActiveMiners[$_.IdF].API $ActiveMiners[$_.IdF].Port

            if ($Miner_HashRates -ne $null) {
                $_.SpeedLive = [double]($Miner_HashRates[0])
                $_.SpeedLiveDual = [double]($Miner_HashRates[1])
                $_.RevenueLive = $_.SpeedLive * $ActiveMiners[$_.IdF].PoolPrice
                $_.RevenueLiveDual = $_.SpeedLiveDual * $ActiveMiners[$_.IdF].PoolPriceDual

                $_.PowerLive = ($Devices | Where-Object group -eq ($ActiveMiners[$_.IdF].GpuGroup.GroupName) | Measure-Object -property power_draw -sum).sum

                $_.Profitslive = (($_.RevenueLive + $_.RevenueLiveDual) * $LocalBTCvalue)
                $_.Profitslive -= ($ActiveMiners[$_.IdF].MinerFee * $_.Profitslive)
                $_.Profitslive -= ($ActiveMiners[$_.IdF].PoolFee * $_.Profitslive)
                $_.Profitslive -= ($ElectricityCostValue * ($_.PowerLive * 24) / 1000)


                $_.TimeSinceStartInterval = (Get-Date) - $_.Stats.LastTimeActive
                $TimeSinceStartInterval = [int]$_.TimeSinceStartInterval.TotalSeconds

                if ($_.SpeedLive -gt 0) {
                    if ($_.Stats.StatsTime -ne 0) { $_.Stats.ActiveTime += (Get-Date) - $_.Stats.StatsTime }
                    $_.Stats.StatsTime = Get-Date

                    if ($_.SpeedReads.count -le 10 -or $_.Speedlive -le ((($_.SpeedReads.speed | Measure-Object -average).average) * 100)) {
                        #for avoid miners peaks recording
                        if (($_.SpeedReads).count -eq 0 -or $_.SpeedReads -eq $null -or $_.SpeedReads -eq "") {$_.SpeedReads = @()}
                        try {
                            #this command fails sometimes, why?

                            $_.SpeedReads += [PSCustomObject]@{
                                Speed                  = $_.SpeedLive
                                SpeedDual              = $_.SpeedLiveDual
                                GpuActivity            = ($Devices | Where-Object group -eq ($ActiveMiners[$_.IdF].GpuGroup.GroupName) | Measure-Object -property utilization -average).average
                                Power                  = $_.PowerLive
                                Date                   = (Get-Date).DateTime
                                Benchmarking           = $_.NeedBenchmark
                                TimeSinceStartInterval = $TimeSinceStartInterval
                                BenchmarkintervalTime  = $BenchmarkintervalTime
                            }
                        } catch {}
                    }
                    if ($_.SpeedReads.count -gt 2000) {$_.SpeedReads = $_.SpeedReads[1..($_.SpeedReads.length - 1)]} #if array is greater than X delete first element

                    if (($config.LiveStatsUpdate) -eq "ENABLED" -or $_.NeedBenchmark) {
                        Set_HashRates `
                            -Algorithm $ActiveMiners[$_.IdF].Algorithms `
                            -MinerName $ActiveMiners[$_.IdF].Name `
                            -GroupName $ActiveMiners[$_.IdF].GpuGroup.GroupName `
                            -AlgoLabel $ActiveMiners[$_.IdF].AlgoLabel `
                            -Powerlimit $_.PowerLimit -value  $_.SpeedReads
                    }
                }
            }

            #WATCHDOG

            $GpuActivityAverages += [pscustomobject]@{Average = ($Devices | Where-Object group -eq ($ActiveMiners[$_.IdF].GpuGroup.GroupName) | Measure-Object -property utilization -average).average}

            if ($GpuActivityAverages.count -gt 20) {
                $GpuActivityAverages = $GpuActivityAverages[($GpuActivityAverages.count - 20)..($GpuActivityAverages.count - 1)]
                $GpuActivityAverage = ($GpuActivityAverages | Measure-Object -property average -maximum).maximum
                if ($DetailedLog) {writelog ("Last 20 reads maximum GPU activity is " + [string]$GpuActivityAverage + " for Gpugroup " + $ActiveMiners[$_.IdF].GpuGroup.GroupName)  $logfile $false}
            } else { $GpuActivityAverage = 100 } #only want watchdog works with at least 5 reads


            if ($ActiveMiners[$_.IdF].Process -eq $null -or $ActiveMiners[$_.IdF].Process.HasExited -or ($GpuActivityAverage -le 40 -and $TimeSinceStartInterval -gt 100) ) {
                $ActiveMiners[$_.IdF].Stats.StatsTime = [timespan]0
                $ExitLoop = $true
                $_.Status = "PendingCancellation"
                $_.Stats.FailedTimes++
                $_.StatsHistory.FailedTimes++
                writelog ("Detected miner error " + $ActiveMiners[$_.IdF].name + "/" + $ActiveMiners[$_.IdF].Algorithm + " (id " + $_.IdF + '-' + $_.Id + ") --> " + $ActiveMiners[$_.IdF].Path + " " + $ActiveMiners[$_.IdF].Arguments) $logfile $false
                writelog ([string]$ActiveMiners[$_.IdF].Process + ',' + [string]$ActiveMiners[$_.IdF].Process.HasExited + ',' + $GpuActivityAverage + ',' + $TimeSinceStartInterval) $logfile $false
            }
        } #End For each

        #############################################################

        #display interval
        $TimeToNextInterval = New-TimeSpan (Get-Date) ($LoopStarttime.AddSeconds($NextInterval))
        $TimeToNextIntervalSeconds = [int]$TimeToNextInterval.TotalSeconds
        if ($TimeToNextIntervalSeconds -lt 0) {$TimeToNextIntervalSeconds = 0}

        set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 31) 2
        " | Next Interval:  $TimeToNextIntervalSeconds secs..." | Out-host
        set_ConsolePosition 0 0

        #display header
        Print_Horizontal_line "MegaMiner $Release"
        Print_Horizontal_line
        "  (E)nd Interval   (P)rofits    (C)urrent    (H)istory    (W)allets    (S)tats" | Out-host

        #display donation message
        if ($DonationInterval) {" THIS INTERVAL YOU ARE DONATING, YOU CAN INCREASE OR DECREASE DONATION ON CONFIG.TXT, THANK YOU FOR YOUR SUPPORT !!!!"}



        #write speed
        if ($DetailedLog) {writelog ($ActiveMiners | Where-Object Status -eq 'Running'| Select-Object id, process.Id, GroupName, name, poolabbname, Algorithm, AlgorithmDual, SpeedLive, ProfitsLive, location, port, arguments |ConvertTo-Json) $logfile $false}


        #get pool reported speed (1 or each 10 executions to not saturate pool)
        if ($SwitchLoop -eq 0) {

            #To get pool speed
            $PoolsSpeed = @()


            $Candidates = ($ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Select-Object Idf).Idf
            $ActiveMiners | Where-Object {$candidates -contains $_.Id} | Select-Object PoolName, UserName, WalletSymbol, Coin, WorkerName -unique | ForEach-Object {
                $Info = [PSCustomObject]@{
                    User       = $_.UserName
                    PoolName   = $_.PoolName
                    ApiKey     = $config.("APIKEY_" + $_.PoolName)
                    Symbol     = $_.WalletSymbol
                    Coin       = $_.Coin
                    WorkerName = $_.WorkerName
                }
                $PoolsSpeed += Get_Pools -Querymode "speed" -PoolsFilterList $_.PoolName -Info $Info
            }

            #Dual miners
            $ActiveMiners | Where-Object {$candidates -contains $_.Id -and $_.PoolNameDual -ne $null} | Select-Object PoolNameDual, UserNameDual, WalletSymbol, CoinDual, WorkerName -unique | ForEach-Object {
                $Info = [PSCustomObject]@{
                    User       = $_.UserNameDual
                    PoolName   = $_.PoolNameDual
                    ApiKey     = $config.("APIKEY_" + $_.PoolNameDual)
                    Symbol     = $_.WalletSymbol
                    Coin       = $_.CoinDual
                    WorkerName = $_.WorkerNameDual
                }
                $PoolsSpeed += Get_Pools -Querymode "speed" -PoolsFilterList $_.PoolNameDual -Info $Info
            }


            foreach ($Candidate in $Candidates) {
                $Me = $PoolsSpeed | Where-Object {$_.PoolName -eq $ActiveMiners[$Candidate].PoolName -and $_.WorkerName -eq $ActiveMiners[$Candidate].WorkerName } | Select-Object HashRate, PoolName, WorkerName -first 1
                $ActiveMiners[$Candidate].PoolHashRate = $Me.HashRate

                $MeDual = $PoolsSpeed | Where-Object {$_.PoolName -eq $ActiveMiners[$Candidate].PoolNameDual -and $_.WorkerName -eq $ActiveMiners[$Candidate].WorkerNameDual} | Select-Object HashRate, PoolName, WorkerName -first 1
                $ActiveMiners[$Candidate].PoolHashRateDual = $MeDual.HashRate
            }
        }

        #display current mining info

        Print_Horizontal_line

        $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Sort-Object {$ActiveMiners[$_.idf].GpuGroup.GroupName} | Format-Table -Wrap (
            # @{Label = "Id"; Expression = {$_.IdF}; Align = 'right'},
            @{Label = "GroupName"; Expression = {$ActiveMiners[$_.IdF].GpuGroup.GroupName}},
            # @{Label = "MMPowLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}; align = 'right'},
            @{Label = "LocalSpeed"; Expression = { (ConvertTo_Hash ($_.SpeedLive)) + '/s' + $(
                        if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) { '|' + (ConvertTo_Hash ($_.SpeedLiveDual)) + '/s' }
                    ) }; Align = 'right'
            },
            @{Label = "mBTC/Day"; Expression = {((($_.RevenueLive + $_.RevenueLiveDual) * 1000).tostring("n5"))}; Align = 'right'},
            @{Label = $LocalCurrency + "/Day"; Expression = {((($_.RevenueLive + $_.RevenueLiveDual) * $localBTCvalue ).tostring("n2"))}; Align = 'right'},
            @{Label = "Profit/Day"; Expression = {(($_.ProfitsLive).tostring("n2")) + " " + $LocalCurrency}; Align = 'right'},
            @{Label = "Algorithm"; Expression = { $ActiveMiners[$_.IdF].Algorithm + $ActiveMiners[$_.IdF].AlgoLabel + $(
                        if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) { '|' + $ActiveMiners[$_.IdF].AlgorithmDual }
                    ) + $_.BestBySwitch}
            },
            @{Label = "Coin"; Expression = { $ActiveMiners[$_.IdF].Symbol + $(
                        if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + ($ActiveMiners[$_.IdF].SymbolDual)}
                    )}
            },
            @{Label = "Miner"; Expression = {$ActiveMiners[$_.IdF].Name}},
            @{Label = "Power"; Expression = {[string]$_.PowerLive + 'W'}; Align = 'right'},
            # @{Label = "Efficiency"; Expression = { if ([string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual) -and $_.PowerLive -gt 0) { (ConvertTo_Hash  ($_.SpeedLive / $_.PowerLive)) + '/W' } else { $null } }; Align = 'right' },
            @{Label = "$LocalCurrency/W"; Expression = {if ($_.PowerLive -gt 0) {($_.ProfitsLive / $_.PowerLive).tostring("n4")} else {$null} }; Align = 'right'},
            @{Label = "PoolSpeed"; Expression = {(ConvertTo_Hash ($ActiveMiners[$_.IdF].PoolHashRate)) + '/s' + $(
                        if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {('|' + (ConvertTo_Hash ($ActiveMiners[$_.IdF].PoolHashRateDual)) + '/s')}
                    )}; Align = 'right'
            },
            @{Label = "Workers"; Expression = {$ActiveMiners[$_.IdF].PoolWorkers + $(
                        if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) { '|' + [string]$ActiveMiners[$_.IdF].PoolWorkersDual }
                    )}; Align = 'right'
            },
            @{Label = "Loc."; Expression = {$ActiveMiners[$_.IdF].Location}},
            @{Label = "Pool"; Expression = { $ActiveMiners[$_.IdF].PoolAbbName + $(
                        if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + $ActiveMiners[$_.IdF].PoolAbbNameDual}
                    )}
            }

            <#
              @{Label = "PoolPrice"; Expression = {$ActiveMiners[$_.IdF].PoolPrice}}

              @{Label = "BmkT"; Expression = {$_.BenchmarkedTimes}},
              @{Label = "FailT"; Expression = {$_.FailedTimes}},
              @{Label = "Nbmk"; Expression = {$_.NeedBenchmark}},

              @{Label = "Port"; Expression = {$ActiveMiners[$_.IdF].Port}}
 #>

        ) | Out-Host

        # Report stats
        if ($MinerStatusURL -and $MinerStatusKey) { & .\Includes\ReportStatus.ps1 -MinerStatusKey $MinerStatusKey -WorkerName $WorkerName -ActiveMiners $ActiveMiners -MinerStatusURL $MinerStatusURL }

        $XToWrite = [ref]0
        $YToWrite = [ref]0
        Get_ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)
        $YToWriteMessages = $YToWrite + 1
        $YToWriteData = $YToWrite + 2
        Remove-Variable XToWrite
        Remove-Variable YToWrite


        #############################################################
        Print_Horizontal_line $Screen.ToUpper()


        #display profits screen
        if ($Screen -eq "Profits" -and $repaintScreen) {

            set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 37) $YToWriteMessages
            "(B)est Miners/All       (T)op " + [string]$InitialProfitsScreenLimit + "/All" | Out-Host
            set_ConsolePosition 0 $YToWriteData


            $ProfitMiners = @()
            if ($ShowBestMinersOnly) {
                foreach ($SubMiner in ($ActiveMiners.SubMiners | Where-Object {$ActiveMiners[$_.Idf].IsValid -and $_.Status -ne "Cancelled"})) {
                    $Candidates = $ActiveMiners |
                        Where-Object {$_.IsValid -and
                        $_.GpuGroup.Id -eq $ActiveMiners[$SubMiner.Idf].GpuGroup.Id -and
                        $_.Algorithm -eq $ActiveMiners[$SubMiner.Idf].Algorithm -and
                        $_.AlgorithmDual -eq $ActiveMiners[$SubMiner.Idf].AlgorithmDual }
                    $ExistsBest = $Candidates.SubMiners | Where-Object {$_.Profits -gt $SubMiner.Profits}
                    if ($ExistsBest -eq $null -and $SubMiner.Profits -eq 0) {
                        $ExistsBest = $Candidates | Where-Object {$_.HashRate -gt $SubMiner.HashRate}
                    }
                    if ($ExistsBest -eq $null -or $SubMiner.NeedBenchmark -eq $true) {
                        $ProfitMiner = $ActiveMiners[$SubMiner.Idf] | Select-Object * -ExcludeProperty SubMiners
                        $ProfitMiner | Add-Member SubMiner $SubMiner
                        $ProfitMiner | Add-Member GroupName $ProfitMiner.GpuGroup.GroupName #needed for groupby
                        $ProfitMiner | Add-Member NeedBenchmark $ProfitMiner.SubMiner.NeedBenchmark #needed for sort
                        $ProfitMiner | Add-Member Profits $ProfitMiner.SubMiner.Profits #needed for sort
                        $ProfitMiner | Add-Member Status $ProfitMiner.SubMiner.Status #needed for sort
                        $ProfitMiners += $ProfitMiner
                    }
                }
            } else {
                $ActiveMiners.SubMiners | Where-Object {$ActiveMiners[$_.Idf].IsValid} | ForEach-Object {
                    $ProfitMiner = $ActiveMiners[$_.Idf] | Select-Object * -ExcludeProperty SubMiners
                    $ProfitMiner | Add-Member SubMiner $_
                    $ProfitMiner | Add-Member GroupName $ProfitMiner.GpuGroup.GroupName #needed for groupby
                    $ProfitMiner | Add-Member NeedBenchmark $ProfitMiner.SubMiner.NeedBenchmark #needed for sort
                    $ProfitMiner | Add-Member Profits $ProfitMiner.SubMiner.Profits #needed for sort
                    $ProfitMiner | Add-Member Status $ProfitMiner.SubMiner.Status #needed for sort
                    $ProfitMiners += $ProfitMiner
                }
            }


            $ProfitMiners2 = @()
            ForEach ($TypeId in $types.Id) {
                $inserted = 1
                $ProfitMiners  | Where-Object {$_.GpuGroup.Id -eq $TypeId} | Sort-Object -Descending GroupName, NeedBenchmark, Profits | ForEach-Object {
                    if ($inserted -le $ProfitsScreenLimit) {$ProfitMiners2 += $_; $inserted++} #this can be done with Select-Object -first but then memory leak happens, ¿why?
                }
            }

            #Display profits  information
            $ProfitMiners2 | Sort-Object @{expression = "GroupName"; Ascending = $true}, @{expression = "Status"; Descending = $true}, @{expression = "NeedBenchmark"; Descending = $true}, @{expression = "Profits"; Descending = $true} | Format-Table (
                #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
                @{Label = "Algorithm"; Expression = {$_.Algorithm + $_.AlgoLabel +
                        $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {'|' + $_.AlgorithmDual})}
                },
                @{Label = "Coin"; Expression = {$_.Symbol +
                        $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {'|' + $_.SymbolDual})}
                },
                @{Label = "Miner"; Expression = {$_.Name}},
                @{Label = "PowLmt"; Expression = {if ($_.SubMiner.PowerLimit -gt 0) {$_.SubMiner.PowerLimit}}; align = 'right'},
                @{Label = "StatsSpeed"; Expression = {(ConvertTo_Hash ($_.SubMiner.HashRate)) + '/s' +
                        $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {'|' + (ConvertTo_Hash ($_.SubMiner.HashRatedual)) + '/s'})}; Align = 'right'
                },
                @{Label = "PowerAvg"; Expression = {if ($_.SubMiner.NeedBenchmark) {"Benchmarking"} else {$_.SubMiner.PowerAvg.tostring("n0")}}; Align = 'right'},
                # @{Label = "Efficiency"; Expression = {if ([string]::IsNullOrEmpty($_.AlgorithmDual)) {(ConvertTo_Hash  ($_.SubMiner.HashRate / $_.SubMiner.PowerAvg)) + '/W'} else {$null} }; Align = 'right'},
                @{Label = "$LocalCurrency/W"; Expression = {if ($_.SubMiner.PowerAvg -gt 0) {($_.SubMiner.Profits / $_.SubMiner.PowerAvg).tostring("n4")} else {$null} }; Align = 'right'},
                @{Label = "mBTC/Day"; Expression = {((($_.SubMiner.Revenue + $_.SubMiner.RevenueDual) * 1000).tostring("n5"))} ; Align = 'right'},
                @{Label = $LocalCurrency + "/Day"; Expression = {((($_.SubMiner.Revenue + $_.SubMiner.RevenueDual) * [double]$localBTCvalue).tostring("n2"))} ; Align = 'right'},
                @{Label = "Profit/Day"; Expression = {if ($_.SubMiner.NeedBenchmark) {"Benchmarking"} else {($_.SubMiner.Profits).tostring("n2") + " " + $LocalCurrency}}; Align = 'right'},
                @{Label = "PoolFee"; Expression = {if ($_.PoolFee -ne $null) {"{0:P2}" -f $_.PoolFee}}; Align = 'right'},
                @{Label = "MinerFee"; Expression = {if ($_.MinerFee -ne $null) {"{0:P2}" -f $_.MinerFee}}; Align = 'right'},
                @{Label = "Loc."; Expression = {$_.Location}} ,
                @{Label = "Pool"; Expression = {$_.PoolAbbName +
                        $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {'|' + $_.PoolAbbNameDual})}
                }

            )  -GroupBy GroupName | Out-Host
            Remove-Variable ProfitMiners
            Remove-Variable ProfitMiners2

            $repaintScreen = $false
        }

        if ($Screen -eq "Current") {
            set_ConsolePosition 0 $YToWriteData

            # Display devices info
            print_devices_information $Devices
        }


        #############################################################

        if ($Screen -eq "Wallets" -or $FirstTotalExecution -eq $true) {

            if ($WalletsUpdate -eq $null) {
                #wallets only refresh for manual request

                $WalletsUpdate = Get-Date

                $WalletsToCheck = @()

                $Pools | Where-Object WalletMode -eq 'WALLET' | Select-Object PoolName, User, WalletMode, WalletSymbol -unique | ForEach-Object {
                    $WalletsToCheck += [pscustomObject]@{
                        PoolName   = $_.PoolName
                        WalletMode = $_.WalletMode
                        User       = ($_.User -split '\.')[0] #to allow payment id after wallet
                        Coin       = $null
                        Algorithm  = $null
                        Host       = $null
                        Symbol     = $_.WalletSymbol
                    }
                }

                $Pools | Where-Object WalletMode -eq 'APIKEY' | Select-Object PoolName, Algorithm, WalletMode, WalletSymbol -unique | ForEach-Object {
                    $ApiKey = $config.("APIKEY_" + $_.PoolName)

                    if ($Apikey -ne "") {
                        $WalletsToCheck += [pscustomObject]@{
                            PoolName   = $_.PoolName
                            WalletMode = $_.WalletMode
                            User       = $null
                            Algorithm  = $_.Algorithm
                            Symbol     = $_.WalletSymbol
                            ApiKey     = $ApiKey
                        }
                    }
                }

                $WalletStatus = @()
                $WalletsToCheck | ForEach-Object {

                    set_ConsolePosition 0 $YToWriteMessages
                    "                                                                         " | Out-host
                    set_ConsolePosition 0 $YToWriteMessages

                    if ($_.WalletMode -eq "WALLET") {writelog ("Checking " + $_.PoolName + " - " + $_.Symbol) $LogFile $True}
                    else {writelog ("Checking " + $_.PoolName + " - " + $_.Symbol + ' (' + $_.Algorithm + ')') $LogFile $True}

                    $Ws = Get_Pools -Querymode $_.WalletMode -PoolsFilterList $_.PoolName -Info ($_)

                    if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                    else {$Ws | Add-Member Wallet $_.Coin}
                    $Ws | Add-Member PoolName $_.PoolName
                    $Ws | Add-Member WalletSymbol $_.Symbol

                    $WalletStatus += $Ws

                    set_ConsolePosition 0 $YToWriteMessages
                    "                                                                         " | Out-host
                }


                if ($FirstTotalExecution -eq $true) {$WalletStatusAtStart = $WalletStatus}

                $WalletStatus | Add-Member BalanceAtStart [double]$null
                $WalletStatus | ForEach-Object {
                    $_.BalanceAtStart = ($WalletStatusAtStart |
                            Where-Object wallet -eq $_.Wallet |
                            Where-Object PoolName -eq $_.PoolName |
                            Where-Object currency -eq $_.Currency).balance
                }
            }

            if ($Screen -eq "Wallets" -and $repaintScreen) {

                set_ConsolePosition 0 $YToWriteMessages
                "Start Time: $StartTime                                                                                                                          "
                set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 10)  $YToWriteMessages
                "(U)pdate" | Out-Host
                "" | Out-Host

                $WalletStatus | Where-Object Balance -gt 0 |
                    Sort-Object  @{expression = "PoolName"; Ascending = $true}, @{expression = "balance"; Descending = $true} |
                    Format-Table -Wrap -groupby PoolName (
                    @{Label = "Coin"; Expression = {if ($_.WalletSymbol -ne $null) {$_.WalletSymbol} else {$_.wallet}}},
                    @{Label = "Balance"; Expression = {$_.Balance.tostring("n5")}; Align = 'right'},
                    @{Label = "IncFromStart"; Expression = {($_.Balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                ) | Out-Host

                $Pools | Where-Object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                    "NO API FOR POOL " + $_.PoolName + " - NO WALLETS CHECK" | Out-host
                }
                $repaintScreen = $false
            }
        }


        #############################################################
        if ($Screen -eq "History" -and $repaintScreen) {

            set_ConsolePosition 0 $YToWriteMessages
            "Running Mode: $MiningMode" | Out-Host

            set_ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners.SubMiners | Where-Object {$_.Stats.ActivatedTimes -GT 0} | Sort-Object -Descending {$_.Stats.LastTimeActive}  | Format-Table -Wrap  (
                #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
                @{Label = "LastTime"; Expression = {$_.Stats.LastTimeActive}},
                @{Label = "GroupName"; Expression = {$Activeminers[$_.Idf].GpuGroup.GroupName}},
                @{Label = "PowLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}},
                @{Label = "Command"; Expression = {$($Activeminers[$_.Idf].Path.TrimStart((Convert-Path ".\"))) + " " + $($Activeminers[$_.Idf].Arguments)}}
            ) | Out-Host
            $repaintScreen = $false
        }

        #############################################################

        if ($Screen -eq "Stats" -and $repaintScreen) {
            set_ConsolePosition 0 $YToWriteMessages
            "Start Time: $StartTime"

            set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 30) $YToWriteMessages

            "Running Mode: $MiningMode" | Out-Host


            set_ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners.SubMiners | Where-Object {$_.stats.ActivatedTimes -GT 0} | Sort-Object -Descending {$_.stats.ActivatedTimes} |  Format-Table -Wrap (
                #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
                @{Label = "GpuGroup"; Expression = {$ActiveMiners[$_.Idf].GpuGroup.GroupName}},
                @{Label = "Algorithm"; Expression = {$ActiveMiners[$_.Idf].Algorithm + $ActiveMiners[$_.Idf].AlgoLabel +
                        $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + $ActiveMiners[$_.Idf].AlgorithmDual})}
                },
                @{Label = "Pool"; Expression = {$ActiveMiners[$_.Idf].PoolAbbName}},
                @{Label = "Miner"; Expression = {$ActiveMiners[$_.Idf].Name}},
                @{Label = "PwLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}},
                @{Label = "Launch"; Expression = {$_.Stats.ActivatedTimes}},
                @{Label = "Time"; Expression = {if ($_.Stats.Activetime.TotalMinutes -le 60) {"{0:N1} min" -f ($_.Stats.ActiveTime.TotalMinutes)} else {"{0:N1} hours" -f ($_.Stats.ActiveTime.TotalHours)}}},
                @{Label = "Best"; Expression = {$_.Stats.Besttimes}},
                @{Label = "Last"; Expression = {$_.Stats.LastTimeActive}}
            ) | Out-Host
            $repaintScreen = $false
        }



        $FirstLoopExecution = $False

        #Loop for reading key and wait

        $KeyPressed = Timed_ReadKb 3 ('P', 'C', 'H', 'E', 'W', 'U', 'T', 'B', 'S', 'X')



        switch ($KeyPressed) {
            'P' {$Screen = 'PROFITS'}
            'C' {$Screen = 'CURRENT'}
            'H' {$Screen = 'HISTORY'}
            'S' {$Screen = 'STATS'}
            'E' {$ExitLoop = $true}
            'W' {$Screen = 'WALLETS'}
            'U' {if ($Screen -eq "WALLETS") {$WalletsUpdate = $null}}
            'T' {if ($Screen -eq "PROFITS") {if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) {$ProfitsScreenLimit = 1000} else {$ProfitsScreenLimit = $InitialProfitsScreenLimit}}}
            'B' {if ($Screen -eq "PROFITS") {$ShowBestMinersOnly = !$ShowBestMinersOnly}}
            'X' {set_WindowSize 185 60}
        }

        if ($KeyPressed) {Clear-host; $repaintScreen = $true}

        if (((Get-Date) -ge ($LoopStarttime.AddSeconds($NextInterval)))  ) {
            #If time of interval has over, exit of main loop
            #If last interval was benchmark and no speed detected mark as failed
            $ActiveMiners.SubMiners | Where-Object Best -eq $true | ForEach-Object {
                if ($_.NeedBenchmark -and $_.Speedreads.count -eq 0) {
                    $_.Status = 'PendingCancellation'
                    writelog ("No speed detected while benchmark " + $ActiveMiners[$_.IdF].name + "/" + $ActiveMiners[$_.IdF].Algorithm + " (id " + $ActiveMiners[$_.IdF].Id + ")") $logfile $false
                }
            }
            break
        }

        if ($ExitLoop) {break} #forced exit

        ErrorsToLog $logfile
    }


    Remove-variable miners
    Remove-variable pools
    Get-Job -State Completed | Remove-Job
    [GC]::Collect() #force garbage collector for free memory
    $FirstTotalExecution = $False


}

#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of always running loop--------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------



Writelog "Program end" $logfile

$ActiveMiners | ForEach-Object { Kill_Process $_.Process}

$LogFile.close()

#Stop-Transcript
