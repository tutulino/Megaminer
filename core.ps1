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


# $MiningMode='Automatic'
# $MiningMode='Manual'

# $PoolsName=('ahashpool','miningpoolhub','hashrefinery')
# $PoolsName='whattomine'
# $PoolsName='zergpool'
# $PoolsName='yiimp'
# $PoolsName='ahashpool'
# $PoolsName=('hashrefinery','zpool')
# $PoolsName='miningpoolhub'
# $PoolsName='zpool'
# $PoolsName='hashrefinery'
# $PoolsName='altminer'
# $PoolsName='blazepool'

# $PoolsName="Nicehash"
# $PoolsName="Nanopool"

# $CoinsName =('bitcore','Signatum','Zcash')
# $CoinsName ='zcash'
# $Algorithm =('phi','x17')

# $GroupNames=('rx580')

$error.clear()
$currentDir = Split-Path -Parent $MyInvocation.MyCommand.Path

#Start log file

$logname = ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"
Start-Transcript $logname   #for start log msg
Stop-Transcript
$LogFile = [System.IO.StreamWriter]::new( $logname, $true )
$LogFile.AutoFlush = $true

clear_files

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

$ErrorActionPreference = "Continue"
$Config = get_config

$Release = "6.1"
WriteLog ("Release $Release") $LogFile $false

if ($GroupNames -eq $null) {$Host.UI.RawUI.WindowTitle = "MegaMiner"}
else {$Host.UI.RawUI.WindowTitle = "MM-" + ($GroupNames -join "/")}
$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' #This align cuda id with nvidia-smi order

$progressPreference = 'silentlyContinue' #No progress message on web requests
#$progressPreference = 'Stop'

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
#add MM path to windows defender exclusions
$DefenderExclusions = (Get-MpPreference).CimInstanceProperties | Where-Object name -eq 'ExclusionPath'
if ($DefenderExclusions.Value -notcontains (Convert-Path .)) {
    Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"
}

$ActiveMiners = @()
$ShowBestMinersOnly = $true
$FirstTotalExecution = $true
$StartTime = Get-Date

if (($Config.DEBUGLOG) -eq "ENABLED") {$DetailedLog = $true} else {$DetailedLog = $false}

$Screen = $Config.STARTSCREEN


#---Parameters checking

if ($MiningMode -NotIn @('Manual', 'Automatic', 'Automatic24h')) {
    "Parameter MiningMode not valid, valid options: Manual, Automatic, Automatic24h" | Out-Host
    EXIT
}

$PoolsChecking = Get_Pools `
    -Querymode "info" `
    -PoolsFilterList $PoolsName `
    -CoinFilterList $CoinsName `
    -Location $Location `
    -AlgoFilterList $Algorithm

$PoolsErrors = switch ($MiningMode) {
    "Automatic" {$PoolsChecking | Where-Object ActiveOnAutomaticMode -eq $false}
    "Automatic24h" {$PoolsChecking | Where-Object ActiveOnAutomatic24hMode -eq $false}
    "Manual" {$PoolsChecking | Where-Object ActiveOnManualMode -eq $false }
}

$PoolsErrors | ForEach-Object {
    "Selected MiningMode is not valid for pool " + $_.Name | Write-Host -ForegroundColor Red
    EXIT
}

if ($MiningMode -eq 'Manual' -and ($CoinsName | Measure-Object).Count -gt 1) {
    "On manual mode only one coin must be selected" | Write-Host -ForegroundColor Red
    EXIT
}

if ($MiningMode -eq 'Manual' -and ($CoinsName | Measure-Object).Count -eq 0) {
    "On manual mode must select one coin" | Write-Host -ForegroundColor Red
    EXIT
}

if ($MiningMode -eq 'Manual' -and ($Algorithm | Measure-Object).Count -gt 1) {
    "On manual mode only one algorithm must be selected" | Write-Host -ForegroundColor Red
    EXIT
}


#parameters backup

$ParamAlgorithmBCK = $Algorithm
$ParamPoolsNameBCK = $PoolsName
$ParamCoinsNameBCK = $CoinsName
$ParamMiningModeBCK = $MiningMode



try {set_WindowSize 180 50} catch {}

$IntervalStartAt = (Get-Date) #first initialization, must be outside loop


ErrorsToLog $LogFile


$Msg = "Starting Parameters: "
$Msg += " //Algorithm: " + [String]($Algorithm -join ",")
$Msg += " //PoolsName: " + [String]($PoolsName -join ",")
$Msg += " //CoinsName: " + [String]($CoinsName -join ",")
$Msg += " //MiningMode: " + $MiningMode
$Msg += " //GroupNames: " + [String]($GroupNames -join ",")
$Msg += " //PercentToSwitch: " + $PercentToSwitch

WriteLog $msg $LogFile $false

#Enable api
if ($config.ApiPort -gt 0) {

    WriteLog ("Starting API in port " + [string]$config.ApiPort) $LogFile $false

    $ApiSharedFile = $currentDir + "\ApiShared" + [string](Get-Random -minimum 0 -maximum 99999999) + ".tmp"
    $command = "-WindowStyle minimized  -noexit -executionpolicy bypass -file $currentDir\Includes\ApiListener.ps1 -port " + [string]$config.ApiPort + " -SharedFile $ApiSharedFile "
    $APIprocess = Start-Process -FilePath "powershell.exe" -ArgumentList $command -Verb RunAs -PassThru -WindowStyle Minimized

    #open firewall port
    $command = 'New-NetFirewallRule -DisplayName "Megaminer" -Direction Inbound -Action Allow -Protocol TCP -LocalPort ' + [string]$config.ApiPort
    Start-Process -FilePath "powershell.exe" -ArgumentList $command -Verb RunAs -WindowStyle Minimized

    $command = 'New-NetFirewallRule -DisplayName "Megaminer" -Direction Outbound -Action Allow -Protocol TCP -LocalPort ' + [string]$config.ApiPort
    Start-Process -FilePath "powershell.exe" -ArgumentList $command -Verb RunAs -WindowStyle Minimized
}

$Quit = $false

#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#This loop will be running forever
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------


while ($Quit -eq $false) {

    $Config = get_config
    Clear-Host; $RepaintScreen = $true

    #get mining types
    $Types = Get_Mining_Types -filter $GroupNames

    WriteLog ( get_devices_information $Types | ConvertTo-Json) $LogFile $false
    WriteLog ( $Types | ConvertTo-Json) $LogFile $false
    if ($FirstTotalExecution) {Check_GpuGroups_Config $types}

    $NumberTypesGroups = ($Types | Measure-Object).count
    if ($NumberTypesGroups -gt 0) {$InitialProfitsScreenLimit = [Math]::Floor(30 / $NumberTypesGroups) - 5} #screen adjust to number of groups
    if ($FirstTotalExecution) {$ProfitsScreenLimit = $InitialProfitsScreenLimit}

    WriteLog "New interval starting..." $LogFile $true
    WriteLog ( Get_ComputerStats | ConvertTo-Json) $LogFile $false

    $Location = $Config.Location

    if ([string]::IsNullOrWhiteSpace($PercentToSwitch)) {$PercentToSwitch2 = [int]($Config.PercentToSwitch)}
    else {$PercentToSwitch2 = [int]$PercentToSwitch}
    $DelayCloseMiners = $Config.DelayCloseMiners

    $Currency = $Config.Currency
    $BenchmarkIntervalTime = [int]($Config.BenchmarkTime)
    $LocalCurrency = $Config.LocalCurrency
    if ([string]::IsNullOrWhiteSpace($LocalCurrency)) {
        #for old config.txt compatibility
        switch ($location) {
            'Europe' {$LocalCurrency = "EUR"}
            'EU' {$LocalCurrency = "EUR"}
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
    $DonatedTime = [int]$DonationStat[1]
    $ElapsedDonationTime = [int]($DonationPastTime + $LastIntervalTime.TotalMinutes)
    $ElapsedDonatedTime = [int]($DonatedTime + $LastIntervalTime.TotalMinutes)

    $ConfigDonateTime = [int]($Config.Donate)

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
        $PoolsName = "DonationPool"
        $CoinsName = $null
        $MiningMode = "Automatic"

        if ($ElapsedDonatedTime -ge $ConfigDonateTime) {"0_0" | Set-Content -Path 'Donation.ctr'}
        else {[string]$DonationPastTime + "_" + [string]$ElapsedDonatedTime | Set-Content -Path 'Donation.ctr'}

        WriteLog ("Next interval you will be donating for $NextInterval seconds, thanks for your support") $LogFile $true
    } else {
        #NOT donation interval
        $DonationInterval = $false

        $Algorithm = $ParamAlgorithmBCK
        $PoolsName = $ParamPoolsNameBCK
        $CoinsName = $ParamCoinsNameBCK
        $MiningMode = $ParamMiningModeBCK
        $UserName = $Config.UserName
        $WorkerName = $Config.WorkerName
        if ([string]::IsNullOrWhiteSpace($WorkerName)) {
            $WorkerName = $env:COMPUTERNAME
            $config | Add-Member 'WorkerName' $WorkerName
        }
        $CoinsWallets = @{}
        ((Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*', '').Trim() |
            ForEach-Object {$CoinsWallets.add(($_ -split "=")[0], ($_ -split "=")[1])}

        [string]$ElapsedDonationTime + "_0" | Set-Content -Path Donation.ctr
    }


    $MinerWindowStyle = $Config.MinerWindowStyle
    if ([string]::IsNullOrEmpty($MinerWindowStyle)) {$MinerWindowStyle = 'Minimized'}

    $MinerStatusUrl = $Config.MinerStatusUrl
    $MinerStatusKey = $Config.MinerStatusKey
    if ([string]::IsNullOrEmpty($MinerStatusKey)) {$MinerStatusKey = $CoinsWallets.get_item("BTC")}

    ErrorsToLog $LogFile


    #get actual hour electricity cost
    $ElectricityCostValue = [double](($Config.ElectricityCost | ConvertFrom-Json) |
            Where-Object HourStart -le (Get-Date).Hour |
            Where-Object HourEnd -ge (Get-Date).Hour).CostKwh
    WriteLog "Loading Pools Information..." $LogFile $true

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
    do {
        $AllPools = Get_Pools `
            -Querymode "core" `
            -PoolsFilterList $PoolsName `
            -CoinFilterList $CoinsName `
            -Location $Location `
            -AlgoFilterList $Algorithm
        if ($AllPools.Count -eq 0) {
            $Msg = "NO POOLS!...retry in 10 sec --- REMEMBER, IF YOUR ARE MINING ON ANONYMOUS WITHOUT AUTOEXCHANGE POOLS LIKE YIIMP, NANOPOOL, ETC. YOU MUST SET WALLET FOR AT LEAST ONE POOL COIN IN CONFIG.TXT"
            WriteLog $msg $LogFile $true

            Start-Sleep 10
        }
    } while ($AllPools.Count -eq 0)

    $AllPools | Select-Object name -unique | ForEach-Object {WriteLog ("Pool " + $_.Name + " was responsive...") $LogFile $true}

    WriteLog ("Detected " + [string]$AllPools.Count + " pools...") $LogFile $true

    #Filter by minworkers variable (only if there is any pool greater than minimum)
    $Pools = ($AllPools | Where-Object {$_.PoolWorkers -ge $Config.MinWorkers -or $_.PoolWorkers -eq $null})
    if ($Pools.Count -ge 1) {
        WriteLog ([string]$Pools.Count + " pools left after min workers filter...") $LogFile $true
    } else {
        $Pools = $AllPools
        WriteLog ("No pools with workers greater than minimum config, filter is discarded...") $LogFile $true
    }

    ## Select highest paying pool for each algo and check if pool is alive.
    WriteLog ("Select top pool for each algo in config and check availability...") $LogFile $true
    $PoolsFiltered = $Pools | Group-Object -Property Algorithm | ForEach-Object {
        $NeedPool = $false
        foreach ($TypeGroup in $Types) {
            ## Is pool algorithm defined in config?
            if ([string]::IsNullOrEmpty($TypeGroup.Algorithms) -or $_.Name -in $TypeGroup.Algorithms) {$NeedPool = $true}
            else {
                foreach ($algo in $TypeGroup.Algorithms) {
                    if ($algo -like "$($_.Name)_*" -or $algo -like "*_$($_.Name)") {$NeedPool = $true}
                }
            }
        }
        ## Order by price (profitability)
        $_.Group | Sort-Object -Property `
        @{Expression = {if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"}}; Descending = $true},
        @{Expression = "LocationPriority"; Ascending = $true} | ForEach-Object {
            if ($NeedPool) {
                ## test tcp connection to pool
                if (Query_TCPPort -Server $_.Host -Port $_.Port -Timeout 100) {
                    $NeedPool = $false
                    $_  ## return result
                } else {
                    WriteLog "$($_.PoolName): $($_.Host):$($_.Port) is not responding!" $LogFile $true
                }
            }
        }
    }
    $Pools = $PoolsFiltered
    WriteLog ([string]$Pools.Count + " pools left") $LogFile $true
    Remove-Variable PoolsFiltered

    #Call api to local currency conversion
    try {
        $CDKResponse = Invoke_APIRequest -Url "https://api.Coindesk.com/v1/bpi/currentprice/$LocalCurrency.json" -MaxAge 60 |
            Select-Object -ExpandProperty BPI
        $LocalBTCvalue = $CDKResponse.$LocalCurrency.rate_float
        WriteLog ("CoinDesk API was responsive...") $LogFile $true
    } catch {
        WriteLog "Coindesk API not responding, no local coin conversion..." $LogFile $true
    }


    #Load information about the Miner asociated to each Coin-Algo-Miner
    $Miners = @()

    $MinersFolderContent = (Get-ChildItem "Miners" -Filter "*.json")

    WriteLog ("Files in miner folder: " + [string]($MinersFolderContent.count)) $LogFile $false
    WriteLog ("Number of gpu groups: " + $types.count) $LogFile $false

    foreach ($MinerFile in $MinersFolderContent) {
        try { $Miner = $MinerFile | Get-Content | ConvertFrom-Json }
        catch {
            WriteLog "-------BAD FORMED JSON: $MinerFile" $LogFile $true
            Exit
        }

        foreach ($TypeGroup in $types) {
            #generate a line for each gpu group that has algorithm as valid
            if ($Miner.Type -ne $TypeGroup.type) {
                if ($DetailedLog) {Writelog ([string]$MinerFile.pschildname + " is NOT valid for " + $TypeGroup.groupname + "...ignoring") $LogFile $false }
                continue
            } #check group and miner types are the same
            else {
                if ($DetailedLog) {Writelog ([string]$MinerFile.pschildname + " is valid for " + $TypeGroup.type) $LogFile $false }
            }


            foreach ($Algo in $Miner.Algorithms.PSObject.Properties) {

                ##AlgoName contains real name for dual and no dual miners
                $AlgoTmp = ($Algo.Name -split "\|")[0]
                $AlgoLabel = ($Algo.Name -split ("\|"))[1]
                $AlgoName = get_algo_unified_name (($AlgoTmp -split ("_"))[0])
                $AlgoNameDual = get_algo_unified_name (($AlgoTmp -split ("_"))[1])
                $Algorithms = $AlgoName
                if (![string]::IsNullOrEmpty($AlgoNameDual)) {$Algorithms += "_$AlgoNameDual"}

                if ($TypeGroup.Algorithms -notcontains $Algorithms -and ![string]::IsNullOrEmpty($TypeGroup.Algorithms)) {continue} #check config has this algo as minable

                foreach ($Pool in ($Pools | Where-Object Algorithm -eq $AlgoName)) {
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
                            -replace "#GPUPLATFORM#", $TypeGroup.GpuPlatform `
                            -replace '#ALGORITHM#', $AlgoName `
                            -replace '#ALGORITHMPARAMETERS#', $Algo.Value `
                            -replace '#WORKERNAME#', $WorkerName2 `
                            -replace '#DEVICES#', $TypeGroup.Gpus `
                            -replace '#DEVICESCLAYMODE#', $TypeGroup.GpusClayMode `
                            -replace '#DEVICESETHMODE#', $TypeGroup.GpusETHMode `
                            -replace '#GROUPNAME#', $TypeGroup.GroupName `
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
                                -replace "#GPUPLATFORM#", $TypeGroup.GpuPlatform `
                                -replace '#ALGORITHM#', $AlgoName `
                                -replace '#ALGORITHMPARAMETERS#', $Algo.Value `
                                -replace '#WORKERNAME#', $WorkerName2 `
                                -replace '#DEVICES#', $TypeGroup.Gpus `
                                -replace '#DEVICESCLAYMODE#', $TypeGroup.GpusClayMode `
                                -replace '#DEVICESETHMODE#', $TypeGroup.GpusETHMode `
                                -replace '#GROUPNAME#', $TypeGroup.GroupName `
                                -replace "#ETHSTMODE#", $Pool.EthStMode `
                                -replace "#DEVICESNSGMODE#", $TypeGroup.GpusNsgMode
                        }

                        #select correct price by mode
                        $Price = $Pool.$(if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"})

                        #Search for dualmining pool
                        if (![string]::IsNullOrEmpty($AlgoNameDual)) {
                            #search dual pool and select correct price by mode
                            $PoolDual = $Pools | Where-Object Algorithm -eq $AlgoNameDual | Sort-Object @{Expression = {if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"}}; Descending = $true} | Select-Object -First 1
                            $PriceDual = [double]$PoolDual.$(if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"})

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
                                -replace '#ALGORITHMDUAL#', $AlgoNameDual `
                                -replace '#WORKERNAME#', $WorkerName3
                            if (![string]::IsNullOrEmpty($Miner.PatternConfigFile)) {
                                $ConfigFileArguments = $ConfigFileArguments `
                                    -replace '#PORTDUAL#', $(if ($enableDualSSL) {$PoolDual.PortSSL} else {$PoolDual.Port}) `
                                    -replace '#SERVERDUAL#', $(if ($enableDualSSL) {$PoolDual.HostSSL} else {$PoolDual.Host}) `
                                    -replace '#PROTOCOLDUAL#', $(if ($enableDualSSL) {$PoolDual.ProtocolSSL} else {$PoolDual.Protocol}) `
                                    -replace '#LOGINDUAL#', $PoolDual.User `
                                    -replace '#PASSWORDDUAL#', $PoolDual.Pass `
                                    -replace '#ALGORITHMDUAL#', $AlgoNameDual `
                                    -replace '#WORKERNAME#', $WorkerName3
                            }
                        }


                        ## SubMiner are variations of miner that not need to relaunch
                        ## Creates a "SubMiner" object for each PL
                        $SubMiners = @()
                        foreach ($PowerLimit in ($TypeGroup.PowerLimits)) {
                            ## always exists as least a power limit 0

                            #WriteLog ("$MinerFile $AlgoName "+$TypeGroup.GroupName+" "+$Pool.Info+" $PowerLimit") $LogFile $true

                            ## look in ActiveMiners collection if we found that miner to conserve some properties and not read files
                            $FoundMiner = $ActiveMiners | Where-Object {
                                $_.Name -eq $MinerFile.BaseName -and
                                $_.Coin -eq $Pool.Info -and
                                $_.Algorithm -eq $AlgoName -and
                                $_.CoinDual -eq $PoolDual.Info -and
                                $_.AlgorithmDual -eq $AlgoNameDual -and
                                $_.PoolAbbName -eq $Pool.AbbName -and
                                $_.PoolAbbNameDual -eq $PoolDual.AbbName -and
                                $_.GpuGroup.Id -eq $TypeGroup.Id -and
                                $_.AlgoLabel -eq $AlgoLabel }

                            $FoundSubMiner = $FoundMiner.SubMiners | Where-Object { $_.PowerLimit -eq $PowerLimit}

                            if ($FoundSubMiner -eq $null) {
                                $Hrs = Get_HashRates `
                                    -Algorithm $Algorithms `
                                    -MinerName $MinerFile.BaseName `
                                    -GroupName $TypeGroup.GroupName `
                                    -PowerLimit $PowerLimit `
                                    -AlgoLabel $AlgoLabel
                            } else {
                                $Hrs = $FoundSubMiner.SpeedReads
                            }

                            # Remove 10 percent of lowest and highest rate samples which may skew the average
                            if ($Hrs.Count -gt 10) {
                                if ([string]::IsNullOrEmpty($_.AlgorithmDual)) {
                                    $Hrs = $Hrs | Sort-Object Speed
                                    $p10Index = [math]::Ceiling(10 / 100 * $Hrs.Count)
                                    $p90Index = [math]::Ceiling(90 / 100 * $Hrs.Count)
                                    $Hrs = $Hrs[$p10Index..$p90Index]
                                } else {
                                    $Hrs = $Hrs | Sort-Object Speed
                                    $p5Index = [math]::Ceiling(5 / 100 * $Hrs.Count)
                                    $p95Index = [math]::Ceiling(95 / 100 * $Hrs.Count)
                                    $Hrs = $Hrs[$p5Index..$p95Index] | Sort-Object SpeedDual
                                    $p5Index = [math]::Ceiling(5 / 100 * $Hrs.Count)
                                    $p95Index = [math]::Ceiling(95 / 100 * $Hrs.Count)
                                    $Hrs = $Hrs[$p5Index..$p95Index]
                                }
                            }

                            $PowerValue = [double]($Hrs | Measure-Object -property Power -average).average
                            $HashRateValue = [double]($Hrs | Measure-Object -property Speed -average).average
                            $HashRateValueDual = [double]($Hrs | Measure-Object -property SpeedDual -average).average

                            #calculates revenue
                            $SubMinerRevenue = [double]($HashRateValue * $Price)
                            $SubMinerRevenueDual = [double]($HashRateValueDual * $PriceDual)

                            #apply fee to revenues
                            if ($enableSSL -and [double]$Miner.FeeSSL -gt 0) {
                                $SubMinerRevenue *= (1 - [double]$Miner.FeeSSL)
                            } elseif ([double]$Miner.Fee -gt 0) {
                                $SubMinerRevenue *= (1 - [double]$Miner.Fee)
                            }

                            if ($enableDualSSL -and [double]$Miner.FeeSSL -gt 0) {
                                $SubMinerRevenueDual *= (1 - [double]$Miner.FeeSSL)
                            } elseif ([double]$Miner.Fee -gt 0) {
                                $SubMinerRevenueDual *= (1 - [double]$Miner.Fee)
                            }

                            if ($FoundSubMiner -eq $null) {
                                $StatsHistory = Get_Stats `
                                    -Algorithm $Algorithms `
                                    -MinerName $MinerFile.BaseName `
                                    -GroupName $TypeGroup.GroupName `
                                    -PowerLimit $PowerLimit `
                                    -AlgoLabel $AlgoLabel
                            } else {
                                $StatsHistory = $FoundSubMiner.StatsHistory
                            }
                            $Stats = [PSCustomObject]@{
                                BestTimes        = 0
                                BenchmarkedTimes = 0
                                LastTimeActive   = [TimeSpan]0
                                ActivatedTimes   = 0
                                ActiveTime       = [TimeSpan]0
                                FailedTimes      = 0
                                StatsTime        = [TimeSpan]0
                            }
                            if ($StatsHistory -eq $null) {$StatsHistory = $Stats}

                            if ($SubMiners.Count -eq 0 -or $SubMiners[0].StatsHistory.BestTimes -gt 0) {
                                #only add a SubMiner (distinct from first if sometime first was best)
                                $SubMiners += [PSCustomObject]@{
                                    Id                     = $SubMiners.Count
                                    Best                   = $false
                                    BestBySwitch           = ""
                                    HashRate               = $HashRateValue
                                    HashRateDual           = $HashRateValueDual
                                    NeedBenchmark          = [bool]($HashRateValue -eq 0 -or (![string]::IsNullOrEmpty($AlgorithmDual) -and $HashRateValueDual -eq 0))
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
                        } #end foreach PowerLimit

                        $Miners += [PSCustomObject] @{
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
                            ExtractionPath      = $(".\Bin\" + $MinerFile.BaseName + "\")
                            GenerateConfigFile  = $(if (![string]::IsNullOrEmpty($Miner.GenerateConfigFile)) {".\Bin\" + $MinerFile.BaseName + "\" + $Miner.GenerateConfigFile -replace '#GroupName#', $TypeGroup.GroupName})
                            GpuGroup            = $TypeGroup
                            Host                = $Pool.Host
                            Location            = $Pool.Location
                            MinerFee            = $(if ($enableSSL -and [double]$Miner.FeeSSL -gt 0) { [double]$Miner.FeeSSL } elseif ([double]$Miner.Fee -gt 0) { [double]$Miner.Fee })
                            Name                = $MinerFile.BaseName
                            Path                = $(".\Bin\" + $MinerFile.BaseName + "\" + $Miner.Path)
                            PoolAbbName         = $Pool.AbbName
                            PoolAbbNameDual     = $PoolDual.AbbName
                            PoolFee             = $(if ($Pool.Fee -ne $null) {[double]$Pool.Fee})
                            PoolFeeDual         = $(if ($PoolDual.Fee -ne $null) {[double]$PoolDual.Fee})
                            PoolName            = $Pool.PoolName
                            PoolNameDual        = $PoolDual.PoolName
                            PoolPrice           = $(if ($MiningMode -eq 'Automatic24h') {[double]$Pool.Price24h} else {[double]$Pool.Price})
                            PoolPriceDual       = $(if ($MiningMode -eq 'Automatic24h') {[double]$PoolDual.Price24h} else {[double]$PoolDual.Price})
                            PoolRewardType      = $Pool.RewardType
                            PoolWorkers         = $Pool.PoolWorkers
                            PoolWorkersDual     = $PoolDual.PoolWorkers
                            Port                = $(if (($Types | Where-Object type -eq $TypeGroup.type).Count -le 1 -and $DelayCloseMiners -eq 0) { $Miner.ApiPort })
                            PrelaunchCommand    = $Miner.PrelaunchCommand
                            SubMiners           = $SubMiners
                            SHA256              = $Miner.SHA256
                            Symbol              = $Pool.Symbol
                            SymbolDual          = $PoolDual.Symbol
                            URI                 = $Miner.URI
                            Username            = $PoolUser
                            UsernameDual        = $PoolUserDual
                            WalletMode          = $Pool.WalletMode
                            WalletModeDual      = $PoolDual.WalletMode
                            WalletSymbol        = $Pool.WalletSymbol
                            WalletSymbolDual    = $PoolDual.WalletSymbol
                            WorkerName          = $WorkerName2
                            WorkerNameDual      = $WorkerName3
                        }
                    } #dualmining
                } #end foreach pool
            } #end foreach algo
        } # end if types
    } #end foreach miner


    WriteLog ("Miners/Pools combinations detected: " + [string]($Miners.Count) + "...") $LogFile $true

    #Launch download of miners
    $Miners |
        Where-Object {
        ![string]::IsNullOrEmpty($_.URI) -and
        ![string]::IsNullOrEmpty($_.ExtractionPath) -and
        ![string]::IsNullOrEmpty($_.Path)} |
        Select-Object URI, ExtractionPath, Path, SHA256 -Unique |
        ForEach-Object {
        if (!(Test-Path $_.Path)) {Start_Downloader -URI $_.URI -ExtractionPath $_.ExtractionPath -Path $_.Path -SHA256 $_.SHA256}
    }

    ErrorsToLog $LogFile

    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {WriteLog "NO MINERS!" $LogFile $true; EXIT}


    #Update the active miners list which is alive for all execution time
    foreach ($ActiveMiner in ($ActiveMiners | Sort-Object [int]id)) {
        #Search existing miners to update data
        $Miner = $Miners | Where-Object {
            $_.Name -eq $ActiveMiner.Name -and
            $_.Coin -eq $ActiveMiner.Coin -and
            $_.Algorithm -eq $ActiveMiner.Algorithm -and
            $_.CoinDual -eq $ActiveMiner.CoinDual -and
            $_.AlgorithmDual -eq $ActiveMiner.AlgorithmDual -and
            $_.PoolAbbName -eq $ActiveMiner.PoolAbbName -and
            $_.PoolAbbNameDual -eq $ActiveMiner.PoolAbbNameDual -and
            $_.GpuGroup.Id -eq $ActiveMiner.GpuGroup.Id -and
            $_.AlgoLabel -eq $ActiveMiner.AlgoLabel }

        if (($Miner | Measure-Object).count -gt 1) {
            Clear-Host; WriteLog ("DUPLICATED MINER " + $Miner.Algorithms + " in " + $Miner.Name) $LogFile $true
            EXIT
        }

        if ($Miner) {
            # we found that miner
            $ActiveMiner.Arguments = $Miner.Arguments
            $ActiveMiner.PoolPrice = $Miner.PoolPrice
            $ActiveMiner.PoolPriceDual = $Miner.PoolPriceDual
            $ActiveMiner.PoolFee = $Miner.PoolFee
            $ActiveMiner.PoolFeeDual = $Miner.PoolFeeDual
            $ActiveMiner.PoolWorkers = $Miner.PoolWorkers
            $ActiveMiner.IsValid = $true

            foreach ($SubMiner in $Miner.SubMiners) {
                if (($ActiveMiner.SubMiners | Where-Object {$_.Id -eq $SubMiner.Id}).Count -eq 0) {
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
    foreach ($Miner in $Miners) {

        $ActiveMiner = $ActiveMiners | Where-Object {
            $_.Name -eq $Miner.Name -and
            $_.Coin -eq $Miner.Coin -and
            $_.Algorithm -eq $Miner.Algorithm -and
            $_.CoinDual -eq $Miner.CoinDual -and
            $_.AlgorithmDual -eq $Miner.AlgorithmDual -and
            $_.PoolAbbName -eq $Miner.PoolAbbName -and
            $_.PoolAbbNameDual -eq $Miner.PoolAbbNameDual -and
            $_.GpuGroup.Id -eq $Miner.GpuGroup.Id -and
            $_.AlgoLabel -eq $Miner.AlgoLabel}


        if ($ActiveMiner -eq $null) {
            $Miner.SubMiners | Add-Member IdF $ActiveMiners.Count
            $ActiveMiners += [PSCustomObject]@{
                AlgoLabel           = $Miner.AlgoLabel
                Algorithm           = $Miner.Algorithm
                AlgorithmDual       = $Miner.AlgorithmDual
                Algorithms          = $Miner.Algorithms
                API                 = $Miner.API
                Arguments           = $Miner.Arguments
                BenchmarkArg        = $Miner.BenchmarkArg
                Coin                = $Miner.Coin
                CoinDual            = $Miner.CoinDual
                ConfigFileArguments = $Miner.ConfigFileArguments
                GenerateConfigFile  = $Miner.GenerateConfigFile
                GpuGroup            = $Miner.GpuGroup
                Host                = $Miner.Host
                Id                  = $ActiveMiners.Count
                IsValid             = $true
                Location            = $Miner.Location
                MinerFee            = $Miner.MinerFee
                Name                = $Miner.Name
                Path                = Convert-Path $Miner.Path
                PoolAbbName         = $Miner.PoolAbbName
                PoolAbbNameDual     = $Miner.PoolAbbNameDual
                PoolFee             = $Miner.PoolFee
                PoolFeeDual         = $Miner.PoolFeeDual
                PoolName            = $Miner.PoolName
                PoolNameDual        = $Miner.PoolNameDual
                PoolPrice           = $Miner.PoolPrice
                PoolPriceDual       = $Miner.PoolPriceDual
                PoolWorkers         = $Miner.PoolWorkers
                PoolHashRate        = $null
                PoolHashRateDual    = $null
                PoolRewardType      = $Miner.PoolRewardType
                Port                = $Miner.Port
                PrelaunchCommand    = $Miner.PrelaunchCommand
                Process             = $null
                SubMiners           = $Miner.SubMiners
                Symbol              = $Miner.Symbol
                SymbolDual          = $Miner.SymbolDual
                Username            = $Miner.Username
                UsernameDual        = $Miner.UsernameDual
                WalletMode          = $Miner.WalletMode
                WalletSymbol        = $Miner.WalletSymbol
                WorkerName          = $Miner.WorkerName
                WorkerNameDual      = $Miner.WorkerNameDual
            }
        }
    }

    WriteLog ("Active Miners-pools: $($ActiveMiners.Count)...") $LogFile $true
    ErrorsToLog $LogFile
    WriteLog ("Pending benchmarks: $(($ActiveMiners.SubMiners | Where-Object NeedBenchmark -eq $true).Count)...") $LogFile $true

    if ($DetailedLog) {
        $msg = $ActiveMiners.SubMiners | ForEach-Object {
            "$($_.IdF)-$($_.Id), " +
            "$($ActiveMiners[$_.IdF].GpuGroup.GroupName)), " +
            "$($ActiveMiners[$_.IdF].IsValid), " +
            "PL $($_.PowerLimit), " +
            "$($_.Status), " +
            "$($ActiveMiners[$_.IdF].Name), " +
            "$($ActiveMiners[$_.IdF].Algorithms), " +
            "$($ActiveMiners[$_.IdF].Coin), " +
            "$($ActiveMiners[$_.IdF].Process.Id)`r`n"
        }
        WriteLog $msg $LogFile $false
    }

    #For each type, select most profitable miner, not benchmarked has priority, new miner is only lauched if new profit is greater than old by percenttoswitch
    #This section changes SubMiner
    foreach ($Type in $Types) {

        #look for last round best
        $Candidates = $ActiveMiners | Where-Object {$_.GpuGroup.Id -eq $Type.Id}
        $BestLast = $Candidates.SubMiners | Where-Object {$_.Status -in @("Running", "PendingCancellation")}
        if ($BestLast -ne $null) {
            $ProfitLast = $BestLast.Profits
            $BestLastLogMsg = $(
                "$($ActiveMiners[$BestLast.IdF].Name)/" +
                "$($ActiveMiners[$BestLast.IdF].Algorithms)/" +
                "$($ActiveMiners[$BestLast.IdF].Coin) " +
                "with Power Limit $($BestLast.PowerLimit) " +
                "(id $($BestLast.IdF)-$($BestLast.Id)) " +
                "for group $($Type.GroupName)")
        } else {
            $ProfitLast = 0
        }

        #check if must cancel miner/algo/coin combo
        if ($BestLast.Status -eq 'PendingCancellation') {
            if (($ActiveMiners[$BestLast.IdF].SubMiners.Stats.FailedTimes | Measure-Object -sum).sum -ge 2) {
                $ActiveMiners[$BestLast.IdF].SubMiners | ForEach-Object {$_.Status = 'Cancelled'}
                WriteLog ("Detected more than 3 fails, cancelling combination for $BestNowLogMsg") $LogFile $true
            }
        }

        #look for best for next round
        $Candidates = $ActiveMiners | Where-Object {$_.GpuGroup.Id -eq $Type.Id -and $_.IsValid}

        ## Select top miner that need Benchmark, or if running in Manual mode, or highest Profit above zero.
        $BestNow = $Candidates.SubMiners |
            Where-Object Status -ne 'Cancelled' |
            ForEach-Object {if ($_.NeedBenchmark -or $MiningMode -eq "Manual" -or $_.Profits -gt 0) {$_}} |
            Sort-Object -Descending NeedBenchmark, Profits, {$ActiveMiners[$_.IdF].Algorithm}, {$ActiveMiners[$_.IdF].PoolPrice}, {$ActiveMiners[$_.IdF].PoolPriceDual}, PowerLimit |
            Select-Object -First 1

        if ($BestNow -eq $null) {WriteLog ("No detected any valid candidate for gpu group " + $Type.GroupName) $LogFile $true ; break }

        $BestNowLogMsg = $(
            "$($ActiveMiners[$BestNow.IdF].Name)/" +
            "$($ActiveMiners[$BestNow.IdF].Algorithms)/" +
            "$($ActiveMiners[$BestNow.IdF].Coin) " +
            "with Power Limit $($BestNow.PowerLimit) " +
            "(id $($BestNow.IdF)-$($BestNow.Id))"
            "for group $($Type.GroupName)")
        $ProfitNow = $BestNow.Profits

        if ($BestNow.NeedBenchmark -eq $false) {
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.BestTimes++
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.BestTimes++
        }

        WriteLog ("$BestNowLogMsg is the best combination for gpu group, last was $BestLastLogMsg") $LogFile $true

        if (
            $BestLast.IdF -ne $BestNow.IdF -or
            $BestLast.Id -ne $BestNow.Id -or
            $BestLast.Status -in @("PendingCancellation", "Cancelled")
        ) {
            #something changes or some miner error

            if (
                $BestLast.IdF -eq $BestNow.IdF -and
                $BestLast.Id -ne $BestNow.Id
            ) {
                #Must launch other SubMiner
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type = 'NVIDIA' -and $BestNow.PowerLimit -gt 0) {set_Nvidia_PowerLimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].GpuGroup.gpus}
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type = 'AMD' -and $BestNow.PowerLimit -gt 0) {}

                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $false
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Best = $true
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Status = "Running"
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.StatsTime = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].stats.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].statsHistory.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0

                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $false
                Switch ($BestLast.Status) {
                    "Running" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Idle"}
                    "PendingCancellation" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Failed"}
                    "Cancelled" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Cancelled"}
                }

                WriteLog ("$BestNowLogMsg - Marked as best, changed Power Limit from $($BestLast.PowerLimit)") $LogFile $true

            } elseif (
                $ProfitNow -gt ($ProfitLast * (1 + ($PercentToSwitch2 / 100))) -or
                $BestNow.NeedBenchmark -or
                $BestLast.Status -in @("Running", "PendingCancellation", "Cancelled") -or
                $BestLast -eq $null -or
                $DonationInterval
            ) {
                #Must launch other miner and stop actual

                #Stop old
                if ($BestLast -ne $null) {

                    WriteLog ("Killing in $DelayCloseMiners seconds $BestLastLogMsg with system process id $($ActiveMiners[$BestLast.IdF].Process.Id)") $LogFile

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
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $false
                    Switch ($BestLast.Status) {
                        "Running" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Idle"}
                        "PendingCancellation" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Failed"}
                        "Cancelled" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Cancelled"}
                    }
                }

                #Start New
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type -eq 'NVIDIA' -and $BestNow.PowerLimit -gt 0) {set_Nvidia_PowerLimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].GpuGroup.gpus}
                if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type -eq 'AMD' -and $BestNow.PowerLimit -gt 0) {}

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Best = $true

                if ($ActiveMiners[$BestNow.IdF].Port -eq $null) { $ActiveMiners[$BestNow.IdF].Port = get_next_free_port (Get-Random -minimum 2000 -maximum 48000)}
                $ActiveMiners[$BestNow.IdF].Arguments = $ActiveMiners[$BestNow.IdF].Arguments -replace '#APIPORT#', $ActiveMiners[$BestNow.IdF].Port
                $ActiveMiners[$BestNow.IdF].ConfigFileArguments = $ActiveMiners[$BestNow.IdF].ConfigFileArguments -replace '#APIPORT#', $ActiveMiners[$BestNow.IdF].Port
                if ($ActiveMiners[$BestNow.IdF].GenerateConfigFile) {$ActiveMiners[$BestNow.IdF].ConfigFileArguments | Set-Content ($ActiveMiners[$BestNow.IdF].GenerateConfigFile)}
                if ($ActiveMiners[$BestNow.IdF].PrelaunchCommand) {Start-Process -FilePath $ActiveMiners[$BestNow.IdF].PrelaunchCommand}            #run prelaunch command

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.ActivatedTimes++

                $Arguments = $ActiveMiners[$BestNow.IdF].Arguments
                if ($ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].NeedBenchmark -and $ActiveMiners[$BestNow.IdF].BenchmarkArg) {$Arguments += " " + $ActiveMiners[$BestNow.IdF].BenchmarkArg }

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
                WriteLog ("Started System process Id $($ActiveMiners[$BestNow.IdF].Process.Id) for $BestNowLogMsg --> $($ActiveMiners[$BestNow.IdF].Path) $($ActiveMiners[$BestNow.IdF].Arguments)") $LogFile $false

            } else {
                #Must mantain last miner by switch
                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $true
                if ($ProfitLast -lt $ProfitNow) {
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].BestBySwitch = "*"
                    WriteLog ("$BestNowLogMsg continue mining due to @@percenttoswitch value") $LogFile $true
                }
            }
        }

        Set_Stats `
            -Algorithm $ActiveMiners[$BestNow.IdF].Algorithms `
            -MinerName $ActiveMiners[$BestNow.IdF].Name `
            -GroupName $ActiveMiners[$BestNow.IdF].GpuGroup.GroupName `
            -AlgoLabel $ActiveMiners[$BestNow.IdF].AlgoLabel `
            -PowerLimit $BestNow.PowerLimit `
            -Value $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory
    }

    if ($DonationInterval) { $NextInterval = $ConfigDonateTime }
    elseif (($ActiveMiners.SubMiners | Where-Object NeedBenchmark | Select-Object -ExpandProperty IdF).Count -gt 0) { $NextInterval = $BenchmarkIntervalTime }
    else {
        $NextInterval = $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Select-Object -ExpandProperty IdF | ForEach-Object {
            $PoolInterval = $Config.("INTERVAL_" + $ActiveMiners[$_].PoolRewardType)
            WriteLog ("Interval for pool " + [string]$ActiveMiners[$_].PoolName + " is " + $PoolInterval) $LogFile $False
            $PoolInterval  # Return value
        } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    }
    WriteLog ("Next interval: " + $NextInterval) $LogFile $true

    $FirstLoopExecution = $true
    $LoopStartTime = Get-Date

    ErrorsToLog $LogFile
    $SwitchLoop = 0
    $GpuActivityAverages = @()

    Clear-Host; $RepaintScreen = $true

    while ($Host.UI.RawUI.KeyAvailable) {$Host.UI.RawUI.FlushInputBuffer()} #keyb buffer flush



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
    while ($true) {

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

                $_.ProfitsLive = (($_.RevenueLive * (1 - [double]$ActiveMiners[$_.IdF].PoolFee) + $_.RevenueLiveDual * (1 - [double]$ActiveMiners[$_.IdF].PoolFeeDual)) * $LocalBTCvalue)
                $_.ProfitsLive -= ($ActiveMiners[$_.IdF].MinerFee * $_.ProfitsLive)
                $_.ProfitsLive -= ($ElectricityCostValue * ($_.PowerLive * 24) / 1000)

                $_.TimeSinceStartInterval = (Get-Date) - $_.Stats.LastTimeActive
                $TimeSinceStartInterval = [int]$_.TimeSinceStartInterval.TotalSeconds

                if ($_.SpeedLive -gt 0 -and ($_.SpeedLiveDual -gt 0 -or [string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual))) {
                    if ($_.Stats.StatsTime -ne 0) { $_.Stats.ActiveTime += (Get-Date) - $_.Stats.StatsTime }
                    $_.Stats.StatsTime = Get-Date

                    if ($_.SpeedReads.Count -le 10 -or $_.SpeedLive -le ((($_.SpeedReads.Speed | Measure-Object -average).average) * 100)) {
                        #for avoid miners peaks recording
                        if (($_.SpeedReads).Count -eq 0 -or $_.SpeedReads -eq $null -or $_.SpeedReads -eq "") {$_.SpeedReads = @()}
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
                                BenchmarkIntervalTime  = $BenchmarkIntervalTime
                            }
                        } catch {}
                    }
                    if ($_.SpeedReads.Count -gt 2000) {$_.SpeedReads = $_.SpeedReads[1..($_.SpeedReads.length - 1)]} #if array is greater than X delete first element

                    if (($Config.LiveStatsUpdate) -eq "ENABLED" -or $_.NeedBenchmark) {
                        Set_HashRates `
                            -Algorithm $ActiveMiners[$_.IdF].Algorithms `
                            -MinerName $ActiveMiners[$_.IdF].Name `
                            -GroupName $ActiveMiners[$_.IdF].GpuGroup.GroupName `
                            -AlgoLabel $ActiveMiners[$_.IdF].AlgoLabel `
                            -PowerLimit $_.PowerLimit `
                            -Value $_.SpeedReads
                    }
                }
            }

            #WATCHDOG
            $groupcards = @()
            $groupcards += $Devices | Where-Object gpugroup -eq $ActiveMiners[$_.IdF].GpuGroup.GroupName

            $GpuActivityAverages += [pscustomobject]@{
                gpugroup     = $ActiveMiners[$_.IdF].GpuGroup.GroupName
                Average      = ($groupcards | Measure-Object -property utilization -average).average
                NumberOfGpus = $groupcards.count
            }


            if ($GpuActivityAverages.Count -gt 20) {
                $GpuActivityAverages = $GpuActivityAverages[($GpuActivityAverages.Count - 20)..($GpuActivityAverages.Count - 1)]
                $GpuActivityAverage = ($GpuActivityAverages | Where-Object gpugroup -eq $ActiveMiners[$_.IdF].GpuGroup.GroupName | Measure-Object -property average -maximum).maximum
                $GpuActivityGpuCount = ($GpuActivityAverages | Where-Object gpugroup -eq $ActiveMiners[$_.IdF].GpuGroup.GroupName | Measure-Object -property NumberOfGpus -maximum).maximum
                if ($DetailedLog) {WriteLog ("Last 20 reads maximum GPU activity is " + [string]$GpuActivityAverage + " for Gpugroup " + $ActiveMiners[$_.IdF].GpuGroup.GroupName) $LogFile $false}
            } else { $GpuActivityAverage = 100 } #only want watchdog works with at least 20 reads


            if ($ActiveMiners[$_.IdF].Process -eq $null -or $ActiveMiners[$_.IdF].Process.HasExited -or ($GpuActivityAverage -le 40 -and $TimeSinceStartInterval -gt 100 -and $GpuActivityGpuCount -gt 0) ) {
                $ActiveMiners[$_.IdF].Stats.StatsTime = [timespan]0
                $ExitLoop = $true
                $_.Status = "PendingCancellation"
                $_.Stats.FailedTimes++
                $_.StatsHistory.FailedTimes++
                WriteLog ("Detected miner error " + $ActiveMiners[$_.IdF].Name + "/" + $ActiveMiners[$_.IdF].Algorithm + " (id " + $_.IdF + '-' + $_.Id + ") --> " + $ActiveMiners[$_.IdF].Path + " " + $ActiveMiners[$_.IdF].Arguments) $LogFile $false
                # WriteLog ([string]$ActiveMiners[$_.IdF].Process + ',' + [string]$ActiveMiners[$_.IdF].Process.HasExited + ',' + $GpuActivityAverage + ',' + $TimeSinceStartInterval) $LogFile $false
            }
        } #End For each

        #############################################################

        #display interval
        $TimeToNextInterval = New-TimeSpan (Get-Date) ($LoopStartTime.AddSeconds($NextInterval))
        $TimeToNextIntervalSeconds = [int]$TimeToNextInterval.TotalSeconds
        if ($TimeToNextIntervalSeconds -lt 0) {$TimeToNextIntervalSeconds = 0}

        set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 31) 2
        " | Next Interval: $TimeToNextIntervalSeconds secs..." | Out-host
        set_ConsolePosition 0 0

        #display header
        Print_Horizontal_line "MegaMiner $Release"
        Print_Horizontal_line
        "  (E)nd Interval  (P)rofits  (C)urrent  (H)istory  (W)allets  (S)tats  (Q)uit" | Out-host

        #display donation message
        if ($DonationInterval) {" THIS INTERVAL YOU ARE DONATING, YOU CAN INCREASE OR DECREASE DONATION ON CONFIG.TXT, THANK YOU FOR YOUR SUPPORT !!!!"}



        #write speed
        if ($DetailedLog) {WriteLog ($ActiveMiners | Where-Object Status -eq 'Running'| Select-Object id, process.Id, GroupName, name, poolabbname, Algorithm, AlgorithmDual, SpeedLive, ProfitsLive, location, port, arguments |ConvertTo-Json) $LogFile $false}


        #get pool reported speed (1 or each 10 executions to not saturate pool)
        if ($SwitchLoop -eq 0) {

            #To get pool speed
            $PoolsSpeed = @()


            $Candidates = ($ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Select-Object Idf).IdF
            $ActiveMiners | Where-Object {$candidates -contains $_.Id} | Select-Object PoolName, UserName, WalletSymbol, Coin, WorkerName -unique | ForEach-Object {
                $Info = [PSCustomObject]@{
                    User       = $_.UserName
                    PoolName   = $_.PoolName
                    ApiKey     = $Config.("APIKEY_" + $_.PoolName)
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
                    ApiKey     = $Config.("APIKEY_" + $_.PoolNameDual)
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

        $ScreenOut = @()

        $ActiveMiners.Subminers | Where-Object Status -eq 'Running'| Sort-Object {$ActiveMiners[$_.idf].GpuGroup.GroupName}  | Foreach-object {
            $ScreenOut += [PSCustomObject]@{
                GroupName   = $ActiveMiners[$_.IdF].GpuGroup.GroupName
                MMPowLmt    = if ($_.PowerLimit -gt 0) {$_.PowerLimit} else {""}
                LocalSpeed  = "$(ConvertTo_Hash $_.SpeedLive)/s" + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {"|$(ConvertTo_Hash $_.SpeedLiveDual)/s"})
                mbtc_Day    = ((($_.RevenueLive + $_.RevenueLiveDual) * 1000).tostring("n5"))
                Rev_Day     = ((($_.RevenueLive + $_.RevenueLiveDual) * $localBTCvalue ).tostring("n2"))
                Profit_Day  = (($_.ProfitsLive).tostring("n2"))
                Algorithm   = $ActiveMiners[$_.IdF].Algorithm + $ActiveMiners[$_.IdF].AlgoLabel + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) { "|$($ActiveMiners[$_.IdF].AlgorithmDual)" }) + $_.BestBySwitch
                Coin        = $ActiveMiners[$_.IdF].Symbol + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {"|$($ActiveMiners[$_.IdF].SymbolDual)"})
                Miner       = $ActiveMiners[$_.IdF].Name
                Power       = [string]$_.PowerLive + 'W'
                EfficiencyH = if ([string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual) -and $_.PowerLive -gt 0) {(ConvertTo_Hash ($_.SpeedLive / $_.PowerLive))} else {$null}
                EfficiencyW = if ($_.PowerLive -gt 0) {($_.ProfitsLive / $_.PowerLive).tostring("n4")} else {$null}
                PoolSpeed   = "$(ConvertTo_Hash $ActiveMiners[$_.IdF].PoolHashRate)/s" + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {("|$(ConvertTo_Hash $ActiveMiners[$_.IdF].PoolHashRateDual)/s")})
                Pool        = $ActiveMiners[$_.IdF].PoolAbbName + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {"|$($ActiveMiners[$_.IdF].PoolAbbNameDual)"})
            }
        }

        $ScreenOut | Format-Table (
            @{Label = "GroupName"; Expression = {$_.GroupName}},
            @{Label = "MMPowLmt"; Expression = {$_.MMPowLmt} ; Align = 'right'},
            @{Label = "LocalSpeed"; Expression = {$_.LocalSpeed} ; Align = 'right'},
            @{Label = "mBTC/Day"; Expression = {$_.mbtc_Day} ; Align = 'right'},
            @{Label = "$LocalCurrency/Day"; Expression = {$_.Rev_Day} ; Align = 'right'},
            @{Label = "Profit/Day"; Expression = {$_.Profit_Day} ; Align = 'right'},
            @{Label = "Algorithm"; Expression = {$_.Algorithm}},
            @{Label = "Coin"; Expression = {$_.Coin}},
            @{Label = "Miner"; Expression = {$_.Miner}},
            @{Label = "Power"; Expression = {$_.Power} ; Align = 'right'},
            @{Label = "Hash/W"; Expression = {$_.EfficiencyH} ; Align = 'right'},
            @{Label = "$LocalCurrency/W"; Expression = {$_.EfficiencyW}  ; Align = 'right'},
            @{Label = "PoolSpeed"; Expression = {$_.PoolSpeed}},
            @{Label = "Pool"; Expression = {$_.Pool}}
        ) | out-host

        if ($config.ApiPort -gt 0) {
            #generate api response
            $ApiResponse = [PSCustomObject]@{}
            $ApiResponse | Add-Member ActiveMiners $ScreenOut
            $ApiResponse | Add-Member Config $config
            $ApiResponse | Add-Member Params ([PSCustomObject]@{})
            $ApiResponse.Params | Add-Member Algorithms $Algorithm
            $ApiResponse.Params | Add-Member Pools $PoolsName
            $ApiResponse.Params | Add-Member Coins $CoinsName
            $ApiResponse.Params | Add-Member MiningMode $MiningMode
            $ApiResponse.Params | Add-Member Groupnames $Groupnames
            $ApiResponse | Add-Member Release $Release
            $ApiResponse | Add-Member RefreshDate ((Get-Date).tostring("o"))
            $ApiResponse | ConvertTo-Json | Set-Content -path $ApiSharedFile
        }

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
        if ($Screen -eq "Profits" -and $RepaintScreen) {

            set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 37) $YToWriteMessages
            "(B)est Miners/All  (T)op " + [string]$InitialProfitsScreenLimit + "/All" | Out-Host
            set_ConsolePosition 0 $YToWriteData


            $ProfitMiners = @()
            if ($ShowBestMinersOnly) {
                foreach ($SubMiner in ($ActiveMiners.SubMiners | Where-Object {$ActiveMiners[$_.IdF].IsValid -and $_.Status -ne "Cancelled"})) {
                    $Candidates = $ActiveMiners |
                        Where-Object {$_.IsValid -and
                        $_.GpuGroup.Id -eq $ActiveMiners[$SubMiner.IdF].GpuGroup.Id -and
                        $_.Algorithm -eq $ActiveMiners[$SubMiner.IdF].Algorithm -and
                        $_.AlgorithmDual -eq $ActiveMiners[$SubMiner.IdF].AlgorithmDual }
                    $ExistsBest = $Candidates.SubMiners | Where-Object {$_.Profits -gt $SubMiner.Profits}
                    if ($ExistsBest -eq $null -and $SubMiner.Profits -eq 0) {
                        $ExistsBest = $Candidates | Where-Object {$_.HashRate -gt $SubMiner.HashRate}
                    }
                    if ($ExistsBest -eq $null -or $SubMiner.NeedBenchmark -eq $true) {
                        $ProfitMiner = $ActiveMiners[$SubMiner.IdF] | Select-Object * -ExcludeProperty SubMiners
                        $ProfitMiner | Add-Member SubMiner $SubMiner
                        $ProfitMiner | Add-Member GroupName $ProfitMiner.GpuGroup.GroupName #needed for groupby
                        $ProfitMiner | Add-Member NeedBenchmark $ProfitMiner.SubMiner.NeedBenchmark #needed for sort
                        $ProfitMiner | Add-Member Profits $ProfitMiner.SubMiner.Profits #needed for sort
                        $ProfitMiner | Add-Member Status $ProfitMiner.SubMiner.Status #needed for sort
                        $ProfitMiners += $ProfitMiner
                    }
                }
            } else {
                $ActiveMiners.SubMiners | Where-Object {$ActiveMiners[$_.IdF].IsValid} | ForEach-Object {
                    $ProfitMiner = $ActiveMiners[$_.IdF] | Select-Object * -ExcludeProperty SubMiners
                    $ProfitMiner | Add-Member SubMiner $_
                    $ProfitMiner | Add-Member GroupName $ProfitMiner.GpuGroup.GroupName #needed for groupby
                    $ProfitMiner | Add-Member NeedBenchmark $ProfitMiner.SubMiner.NeedBenchmark #needed for sort
                    $ProfitMiner | Add-Member Profits $ProfitMiner.SubMiner.Profits #needed for sort
                    $ProfitMiner | Add-Member Status $ProfitMiner.SubMiner.Status #needed for sort
                    $ProfitMiners += $ProfitMiner
                }
            }


            $ProfitMiners2 = @()
            foreach ($TypeId in $types.Id) {
                $inserted = 1
                $ProfitMiners | Where-Object {$_.GpuGroup.Id -eq $TypeId} | Sort-Object -Descending GroupName, NeedBenchmark, Profits | ForEach-Object {
                    if ($inserted -le $ProfitsScreenLimit) {$ProfitMiners2 += $_; $inserted++} #this can be done with Select-Object -first but then memory leak happens, ¿why?
                }
            }

            #Display profits information
            $ProfitMiners2 | Sort-Object @{expression = "GroupName"; Ascending = $true}, @{expression = "Status"; Descending = $true}, @{expression = "NeedBenchmark"; Descending = $true}, @{expression = "Profits"; Descending = $true} | Format-Table (
                #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
                @{Label = "Algorithm"; Expression = {$_.Algorithm + $_.AlgoLabel + $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {"|$($_.AlgorithmDual)"})}},
                @{Label = "Coin"; Expression = {$_.Symbol + $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {"|$($_.SymbolDual)"})}},
                @{Label = "Miner"; Expression = {$_.Name}},
                # @{Label = "PowLmt"; Expression = {if ($_.SubMiner.PowerLimit -gt 0) {$_.SubMiner.PowerLimit}}; align = 'right'},
                @{Label = "StatsSpeed"; Expression = {"$(ConvertTo_Hash $_.SubMiner.HashRate)/s" + $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {"|$(ConvertTo_Hash $_.SubMiner.HashRatedual)/s"})}; Align = 'right'},
                @{Label = "Watt"; Expression = {if ($_.SubMiner.NeedBenchmark) {"Benchmarking"} else {$_.SubMiner.PowerAvg.tostring("n0")}}; Align = 'right'},
                # @{Label = "Efficiency"; Expression = {if ([string]::IsNullOrEmpty($_.AlgorithmDual)) {(ConvertTo_Hash ($_.SubMiner.HashRate / $_.SubMiner.PowerAvg)) + '/W'} else {$null} }; Align = 'right'},
                @{Label = "$LocalCurrency/W"; Expression = {if ($_.SubMiner.PowerAvg -gt 0) {($_.SubMiner.Profits / $_.SubMiner.PowerAvg).tostring("n4")} else {$null} }; Align = 'right'},
                @{Label = "mBTC/Day"; Expression = {((($_.SubMiner.Revenue + $_.SubMiner.RevenueDual) * 1000).tostring("n5"))} ; Align = 'right'},
                @{Label = $LocalCurrency + "/Day"; Expression = {((($_.SubMiner.Revenue + $_.SubMiner.RevenueDual) * [double]$localBTCvalue).tostring("n2"))} ; Align = 'right'},
                @{Label = "Profit/Day"; Expression = {if ($_.SubMiner.NeedBenchmark) {"Benchmarking"} else {($_.SubMiner.Profits).tostring("n2") + " $LocalCurrency"}}; Align = 'right'},
                @{Label = "PoolFee"; Expression = {if ($_.PoolFee -ne $null) {"{0:P2}" -f $_.PoolFee}}; Align = 'right'},
                @{Label = "MinerFee"; Expression = {if ($_.MinerFee -ne $null) {"{0:P2}" -f $_.MinerFee}}; Align = 'right'},
                @{Label = "Loc."; Expression = {$_.Location}} ,
                @{Label = "Pool"; Expression = {$_.PoolAbbName + $(if (![string]::IsNullOrEmpty($_.AlgorithmDual)) {"|$($_.PoolAbbNameDual)"})}}

            ) -GroupBy GroupName | Out-Host
            Remove-Variable ProfitMiners
            Remove-Variable ProfitMiners2

            $RepaintScreen = $false
        }

        if ($Screen -eq "Current") {
            set_ConsolePosition 0 $YToWriteData

            # Display devices info
            print_devices_information $Devices
        }


        #############################################################

        if ($Screen -eq "Wallets" -or $FirstTotalExecution) {

            if ($WalletsUpdate -eq $null) {
                #wallets only refresh for manual request

                $WalletsUpdate = Get-Date

                $WalletsToCheck = @()

                $AllPools | Where-Object WalletMode -eq 'WALLET' | Select-Object PoolName, User, WalletMode, WalletSymbol -unique | ForEach-Object {
                    $WalletsToCheck += [PSCustomObject]@{
                        PoolName   = $_.PoolName
                        WalletMode = $_.WalletMode
                        User       = $_.User
                        Coin       = $null
                        Algorithm  = $null
                        Host       = $null
                        Symbol     = $_.WalletSymbol
                    }
                }

                $AllPools | Where-Object WalletMode -eq 'APIKEY' | Select-Object PoolName, Algorithm, WalletMode, WalletSymbol -unique | ForEach-Object {
                    $ApiKey = $Config.("APIKEY_" + $_.PoolName)

                    if ($Apikey -ne "") {
                        $WalletsToCheck += [PSCustomObject]@{
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
                    "                   " | Out-host
                    set_ConsolePosition 0 $YToWriteMessages

                    if ($_.WalletMode -eq "WALLET") {WriteLog ("Checking " + $_.PoolName + " - " + $_.Symbol) $LogFile $true}
                    else {WriteLog ("Checking " + $_.PoolName + " - " + $_.Symbol + ' (' + $_.Algorithm + ')') $LogFile $true}

                    $Ws = Get_Pools -Querymode $_.WalletMode -PoolsFilterList $_.PoolName -Info ($_)

                    if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                    else {$Ws | Add-Member Wallet $_.Coin}
                    $Ws | Add-Member PoolName $_.PoolName
                    $Ws | Add-Member WalletSymbol $_.Symbol

                    $WalletStatus += $Ws

                    set_ConsolePosition 0 $YToWriteMessages
                    "                                                                         " | Out-host
                }


                if ($FirstTotalExecution) {$WalletStatusAtStart = $WalletStatus}

                $WalletStatus | Add-Member BalanceAtStart [double]$null
                $WalletStatus | ForEach-Object {
                    $_.BalanceAtStart = ($WalletStatusAtStart |
                            Where-Object wallet -eq $_.Wallet |
                            Where-Object PoolName -eq $_.PoolName |
                            Where-Object currency -eq $_.Currency).balance
                }
            }

            if ($Screen -eq "Wallets" -and $RepaintScreen) {

                set_ConsolePosition 0 $YToWriteMessages
                "Start Time: $StartTime                               "
                set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 10) $YToWriteMessages
                "(U)pdate" | Out-Host
                "" | Out-Host

                $WalletStatus | Where-Object Balance -gt 0 |
                    Sort-Object @{expression = "PoolName"; Ascending = $true}, @{expression = "balance"; Descending = $true} |
                    Format-Table -Wrap -groupby PoolName (
                    @{Label = "Coin"; Expression = {if ($_.WalletSymbol -ne $null) {$_.WalletSymbol} else {$_.wallet}}},
                    @{Label = "Balance"; Expression = {$_.Balance.tostring("n5")}; Align = 'right'},
                    @{Label = "IncFromStart"; Expression = {($_.Balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                ) | Out-Host

                $Pools | Where-Object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                    "NO API FOR POOL " + $_.PoolName + " - NO WALLETS CHECK" | Out-host
                }
                $RepaintScreen = $false
            }
        }


        #############################################################
        if ($Screen -eq "History" -and $RepaintScreen) {

            set_ConsolePosition 0 $YToWriteMessages
            "Running Mode: $MiningMode" | Out-Host

            set_ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners.SubMiners |
                Where-Object {$_.Stats.ActivatedTimes -gt 0} |
                Sort-Object -Descending {$ActiveMiners[$_.IdF].GpuGroup.GroupName}, {$_.Stats.LastTimeActive} |
                Format-Table -Wrap -GroupBy @{Label = "Group"; Expression = {$ActiveMiners[$_.IdF].GpuGroup.GroupName}} (
                #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
                @{Label = "LastTimeActive"; Expression = {$($_.Stats.LastTimeActive).tostring("dd/MM/yy H:mm")}},
                # @{Label = "Miner"; Expression = {$ActiveMiners[$_.IdF].Name}},
                # @{Label = "GroupName"; Expression = {$ActiveMiners[$_.IdF].GpuGroup.GroupName}},
                # @{Label = "PowLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}},
                @{Label = "Command"; Expression = {"$($ActiveMiners[$_.IdF].Path.TrimStart((Convert-Path ".\Bin\"))) $($ActiveMiners[$_.IdF].Arguments)"}}
            ) | Out-Host
            $RepaintScreen = $false
        }

        #############################################################

        if ($Screen -eq "Stats" -and $RepaintScreen) {
            set_ConsolePosition 0 $YToWriteMessages
            "Start Time: $StartTime"

            set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 30) $YToWriteMessages

            "Running Mode: $MiningMode" | Out-Host


            set_ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners.SubMiners |
                Where-Object {$_.Stats.ActivatedTimes -gt 0} |
                Sort-Object -Descending {$ActiveMiners[$_.IdF].GpuGroup.GroupName}, {$_.Stats.Activetime.TotalMinutes} |
                Format-Table -Wrap -GroupBy @{Label = "Group"; Expression = {$ActiveMiners[$_.IdF].GpuGroup.GroupName}}(
                #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
                # @{Label = "GpuGroup"; Expression = {$ActiveMiners[$_.IdF].GpuGroup.GroupName}},
                @{Label = "Algorithm"; Expression = {$ActiveMiners[$_.IdF].Algorithm + $ActiveMiners[$_.IdF].AlgoLabel + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {"|$($ActiveMiners[$_.IdF].AlgorithmDual)"})}},
                @{Label = "Coin"; Expression = {$ActiveMiners[$_.IdF].Symbol + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {"|$($ActiveMiners[$_.IdF].SymbolDual)"})}},
                @{Label = "Pool"; Expression = {$ActiveMiners[$_.IdF].PoolAbbName + $(if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {"|$($ActiveMiners[$_.IdF].PoolAbbNameDual)"})}},
                @{Label = "Miner"; Expression = {$ActiveMiners[$_.IdF].Name}},
                # @{Label = "PwLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}},
                @{Label = "Launch"; Expression = {$_.Stats.ActivatedTimes}},
                @{Label = "Best"; Expression = {$_.Stats.BestTimes}},
                @{Label = "ActiveTime"; Expression = {if ($_.Stats.ActiveTime.TotalMinutes -le 60) {"{0:N1} min" -f ($_.Stats.ActiveTime.TotalMinutes)} else {"{0:N1} hours" -f ($_.Stats.ActiveTime.TotalHours)}}},
                @{Label = "LastTimeActive"; Expression = {$($_.Stats.LastTimeActive).tostring("dd/MM/yy H:mm")}}
            ) | Out-Host
        }



        $FirstLoopExecution = $false

        #Loop for reading key and wait

        $KeyPressed = Timed_ReadKb 3 ('P', 'C', 'H', 'E', 'W', 'U', 'T', 'B', 'S', 'X', 'Q')



        switch ($KeyPressed) {
            'P' {$Screen = 'PROFITS'}
            'C' {$Screen = 'CURRENT'}
            'H' {$Screen = 'HISTORY'}
            'S' {$Screen = 'STATS'}
            'E' {$ExitLoop = $true; WriteLog "Forced end of interval by E key" $LogFile $false}
            'W' {$Screen = 'WALLETS'}
            'U' {if ($Screen -eq "WALLETS") {$WalletsUpdate = $null}}
            'T' {if ($Screen -eq "PROFITS") {if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) {$ProfitsScreenLimit = 1000} else {$ProfitsScreenLimit = $InitialProfitsScreenLimit}}}
            'B' {if ($Screen -eq "PROFITS") {$ShowBestMinersOnly = !$ShowBestMinersOnly}}
            'X' {try {set_WindowSize 180 50} catch {}}
            'Q' {$Quit = $true; $ExitLoop = $true}
        }

        if ($KeyPressed) {Clear-host; $RepaintScreen = $true}

        if (((Get-Date) -ge ($LoopStartTime.AddSeconds($NextInterval))) ) {
            #If time of interval has over, exit of main loop
            #If last interval was benchmark and no speed detected mark as failed
            $ActiveMiners.SubMiners | Where-Object Best -eq $true | ForEach-Object {
                if ($_.NeedBenchmark -and $_.Speedreads.Count -eq 0) {
                    $_.Status = 'PendingCancellation'
                    WriteLog ("No speed detected while benchmark " + $ActiveMiners[$_.IdF].Name + "/" + $ActiveMiners[$_.IdF].Algorithm + " (id " + $ActiveMiners[$_.IdF].Id + ")") $LogFile $false
                }
            }
            $ExitLoop = $true
            WriteLog "Interval ends by time -- $NextInterval"  $LogFile $false
        }

        if ($ExitLoop) {break} #forced exit

        ErrorsToLog $LogFile
    }


    Remove-variable miners
    Remove-variable pools
    Get-Job -State Completed | Remove-Job
    [GC]::Collect() #force garbage collector for free memory
    $FirstTotalExecution = $false


}

#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of always running loop--------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------



WriteLog "Exiting MM...." $LogFile $true
$LogFile.close()
Clear_Files
$ActiveMiners | Where-Object Process -ne $null | ForEach-Object {try {Kill_Process $_.Process} catch {}}
try {Invoke-WebRequest ("http://localhost:" + [string]$config.ApiPort + "?command=exit") -timeoutsec 1 -UseDefaultCredentials} catch {}

Stop-Process -Id $PID