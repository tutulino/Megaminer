param(
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = $null,

    [Parameter(Mandatory = $false)]
    [Array]$PoolsName = $null,

    [Parameter(Mandatory = $false)]
    [array]$CoinsName = $null,

    [Parameter(Mandatory = $false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080

    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null

)

. .\Include.ps1


##Parameters for testing, must be commented on real use

#$MiningMode='Automatic'
#$MiningMode='Automatic24h'
#$MiningMode='Manual'

#$PoolsName=('zpool','mining_pool_hub')
#$PoolsName='whattomine_virtual'
#$PoolsName='yiimp'
#$PoolsName=('hash_refinery','zpool')
#$PoolsName='mining_pool_hub'
#$PoolsName='zpool'
#$PoolsName='hash_refinery'
#$PoolsName='ahashpool'
#$PoolsName='suprnova'

#$PoolsName="Nicehash"

#$Coinsname =('bitcore','Signatum','Zcash')
#$Coinsname ='bitcoingold'
#$Algorithm =('x11')


#--------------Load config.txt file

$DEBUG = $false


Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
try {if ((Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}}catch {}

if ($Proxy -eq "") {$PSDefaultParameterValues.Remove("*:Proxy")}
else {$PSDefaultParameterValues["*:Proxy"] = $Proxy}


$ActiveMiners = @()

#Start the log
Clear-log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"

$ActiveMinersIdCounter = 0
$Activeminers = @()
$InitialProfitsScreenLimit = [int](45 / ((Get-Content config.txt | Where-Object {$_ -like '@@TYPE=*'}) -replace '@@TYPE=', '' -split ',').count) - 5
$ProfitsScreenLimit = $InitialProfitsScreenLimit
$ShowBestMinersOnly = $true
$FirstTotalExecution = $true
$IntervalStartAt = (Get-Date)

Clear-Host
Set-WindowSize 120 60

<#
$GpuPlatform= $([array]::IndexOf((Get-WmiObject -class CIM_VideoController | Select-Object -ExpandProperty AdapterCompatibility), 'Advanced Micro Devices, Inc.'))
 if ($GpuPlatform -eq -1) {$GpuPlatform= $([array]::IndexOf((Get-WmiObject -class CIM_VideoController | Select-Object -ExpandProperty AdapterCompatibility), 'NVIDIA')) } #For testing amd miners on nvidia
#>

$Screen = (Get-Content config.txt | Where-Object {$_ -like '@@STARTSCREEN=*'} ) -replace '@@STARTSCREEN=', ''



#---Paraneters checking

if ($MiningMode -notin @('Automatic', 'Manual', 'Automatic24h')) {
    "Parameter MiningMode not valid, valid options: Manual, Automatic, Automatic24h" |Out-host
    EXIT
}



$PoolsChecking = Get-Pools -Querymode "info" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm

$PoolsErrors = @()
switch ($MiningMode) {
    "Automatic" {$PoolsErrors = $PoolsChecking |Where-Object ActiveOnAutomaticMode -eq $false}
    "Automatic24h" {$PoolsErrors = $PoolsChecking |Where-Object ActiveOnAutomatic24hMode -eq $false}
    "Manual" {$PoolsErrors = $PoolsChecking |Where-Object ActiveOnManualMode -eq $false }
}


$PoolsErrors |ForEach-Object {
    "Selected MiningMode is not valid for pool " + $_.name |Out-host
    EXIT
}



if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -gt 1) {
    "On manual mode only one coin must be selected" |Out-host
    EXIT
}


# if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -eq 0) {
#     "On manual mode must select one coin" |Out-host
#     EXIT
# }

if ($MiningMode -eq 'Manual' -and ($Algorithm | measure-object).count -gt 1) {
    "On manual mode only one algorithm must be selected" |Out-host
    EXIT
}


#parameters backup


$ParamAlgorithmBCK = $Algorithm
$ParamPoolsNameBCK = $PoolsName
$ParamCoinsNameBCK = $CoinsName
$ParamMiningModeBCK = $MiningMode




#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#This loop will be running forever
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------

while ($true) {

    $location = @()
    $Types = @()
    $Currency = @()


    $Location = (Get-Content config.txt | Where-Object {$_ -like '@@LOCATION=*'} ) -replace '@@LOCATION=', ''
    $Types = (Get-Content config.txt | Where-Object {$_ -like '@@TYPE=*'}) -replace '@@TYPE=', '' -split ','
    $Currency = (Get-Content config.txt | Where-Object {$_ -like '@@CURRENCY=*'} ) -replace '@@CURRENCY=', ''
    $GpuPlatform = (Get-Content config.txt | Where-Object {$_ -like '@@GPUPLATFORM=*'} ) -replace '@@GPUPLATFORM=', ''
    $BechmarkintervalTime = (Get-Content config.txt | Where-Object {$_ -like '@@BENCHMARKTIME=*'} ) -replace '@@BENCHMARKTIME=', ''
    $LocalCurrency = (Get-Content config.txt | Where-Object {$_ -like '@@LOCALCURRENCY=*'} ) -replace '@@LOCALCURRENCY=', ''
    if ($LocalCurrency.length -eq 0) {
        #for old config.txt compatibility
        switch ($location) {
            'Europe' {$LocalCurrency = "EUR"}
            'US' {$LocalCurrency = "USD"}
            'ASIA' {$LocalCurrency = "USD"}
            'GB' {$LocalCurrency = "GBP"}
        }
    }


    #Donation
    $LastIntervalTime = (get-date) - $IntervalStartAt
    $IntervalStartAt = (Get-Date)
    $ElapsedDonationTime = [int](Get-Content Donation.ctr) + $LastIntervalTime.minutes + ($LastIntervalTime.hours * 60)


    $DonateTime = [int]((Get-Content config.txt | Where-Object {$_ -like '@@DONATE=*'} ) -replace '@@DONATE=', '')

    #Activate or deactivate donation
    if ($ElapsedDonationTime -gt 1440 -and $DonateTime -gt 0) {
        # donation interval

        $DonationInterval = $true
        $UserName = "ffwd"
        $WorkerName = "megaminer"

        $NextInterval = $DonateTime * 60

        $Algorithm = $null
        $PoolsName = "Mining_pool_Hub"
        $CoinsName = $null
        $MiningMode = "Automatic"

        0 | Set-Content  -Path Donation.ctr

    } else {
        #NOT donation interval
        $DonationInterval = $false
        $NextInterval = [int]((Get-Content config.txt | Where-Object {$_ -like '@@INTERVAL=*'}) -replace '@@INTERVAL=', '')

        $Algorithm = $ParamAlgorithmBCK
        $PoolsName = $ParamPoolsNameBCK
        $CoinsName = $ParamCoinsNameBCK
        $MiningMode = $ParamMiningModeBCK
        $UserName = (Get-Content config.txt | Where-Object {$_ -like '@@USERNAME=*'} ) -replace '@@USERNAME=', ''
        $WorkerName = (Get-Content config.txt | Where-Object {$_ -like '@@WORKERNAME=*'} ) -replace '@@WORKERNAME=', ''
        $CoinsWallets = @{}
        (Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*', '' | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0], ($_ -split "=")[1])}

        $ElapsedDonationTime | Set-Content  -Path Donation.ctr

    }


    # $Rates = [PSCustomObject]@{}
    # $Currency | ForEach-Object {$Rates | Add-Member $_ (Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-$_" -UseBasicParsing | ConvertFrom-Json).ticker.price}


    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
    do {
        $Pools = Get-Pools -Querymode "core" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm
        if ($Pools.Count -eq 0) {"NO POOLS!....retry in 10 sec" | Out-Host; Start-Sleep 10}
    }
    while ($Pools.Count -eq 0)




    #Load information about the Miner asociated to each Coin-Algo-Miner

    $Miners = @()


    foreach ($MinerFile in (Get-ChildItem "Miners" | Where-Object extension -eq '.json')) {
        try { $Miner = $MinerFile | Get-Content | ConvertFrom-Json }
        catch {
            "-------BAD FORMED JSON: $MinerFile" | Out-host
            Exit
        }

        #Only want algos selected types
        If ($Types.Count -ne 0 -and (Compare-Object $Types $Miner.types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) {

            foreach ($Algo in ($Miner.Algorithms)) {
                $HashrateValue = 0
                $HashrateValueDual = 0
                $Hrs = $null

                ##Algoname contains real name for dual and no dual miners
                $AlgoName = ($Algo.PSObject.Properties.Name -split ("_"))[0]
                $AlgoNameDual = ($Algo.PSObject.Properties.Name -split ("_"))[1]

                $Hrs = Get-Hashrates -minername $Minerfile.basename -algorithm $Algo.PSObject.Properties.Name

                $HashrateValue = [long]($Hrs -split ("_"))[0]
                $HashrateValueDual = [long]($Hrs -split ("_"))[1]



                #Only want algos pools has

                $Pools | where-object Algorithm -eq $AlgoName | ForEach-Object {

                    if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne $null) -or ($Miner.Dualmining -eq $false)) {

                        if ($_.Algorithm -eq $Miner.DualMiningMainAlgo -or $Miner.Dualmining -eq $false) {
                            # if ($_.info -eq $Miner.DualMiningMainCoin -or $Miner.Dualmining -eq $false) {
                            #not allow dualmining if main coin not coincide

                            $Arguments = $Miner.Arguments -replace '#PORT#', $_.Port `
                                -replace '#SERVER#', $_.Host `
                                -replace '#PROTOCOL#', $_.Protocol `
                                -replace '#LOGIN#', $_.user `
                                -replace '#PASSWORD#', $_.Pass `
                                -replace "#GpuPlatform#", $GpuPlatform `
                                -replace '#ALGORITHM#', $Algoname `
                                -replace '#ALGORITHMPARAMETERS#', $Algo.PSObject.Properties.Value `
                                -replace '#WORKERNAME#', $WorkerName
                            if ($Miner.PatternConfigFile -ne $null) {
                                $ConfigFileArguments = (get-content $Miner.PatternConfigFile -raw) `
                                    -replace '#PORT#', $_.Port `
                                    -replace '#SERVER#', $_.Host `
                                    -replace '#PROTOCOL#', $_.Protocol `
                                    -replace '#LOGIN#', $_.user `
                                    -replace '#PASSWORD#', $_.Pass `
                                    -replace "#GpuPlatform#", $GpuPlatform `
                                    -replace '#ALGORITHM#', $Algoname `
                                    -replace '#ALGORITHMPARAMETERS#', $Algo.PSObject.Properties.Value `
                                    -replace '#WORKERNAME#', $WorkerName
                            }


                            if ($MiningMode -eq 'Automatic24h') {
                                $MinerProfit = [Double]([double]$HashrateValue * [double]$_.Price24h)

                            } else {
                                $MinerProfit = [Double]([double]$HashrateValue * [double]$_.Price)
                            }

                            #apply fee to profit
                            if ($Miner.Fee -gt 0) { $MinerProfit *= (1 - [double]$Miner.fee) }
                            if ($_.Fee -gt 0) { $MinerProfit *= (1 - [double]$_.fee) }

                            $PoolAbbName = $_.Abbname
                            $PoolName = $_.name
                            $PoolWorkers = $_.Poolworkers
                            $MinerProfitDual = $null
                            $PoolDual = $null


                            if ($Miner.Dualmining) {
                                if ($MiningMode -eq 'Automatic24h') {
                                    $PoolDual = $Pools |
                                        where-object Algorithm -eq $AlgoNameDual |
                                        sort-object price24h -Descending |
                                        Select-Object -First 1
                                    $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price24h)
                                }

                                else {
                                    $PoolDual = $Pools |
                                        where-object Algorithm -eq $AlgoNameDual |
                                        sort-object price -Descending |
                                        Select-Object -First 1
                                    $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price)
                                }

                                #apply fee to profit
                                if ($Miner.Fee -gt 0) {$MinerProfitDual *= (1 - [double]$Miner.fee)}
                                if ($PoolDual.Fee -gt 0) {$MinerProfitDual *= (1 - [double]$PoolDual.fee)}

                                $Arguments = $Arguments -replace '#PORTDUAL#', $PoolDual.Port `
                                    -replace '#SERVERDUAL#', $PoolDual.Host `
                                    -replace '#PROTOCOLDUAL#', $PoolDual.Protocol `
                                    -replace '#LOGINDUAL#', $PoolDual.user `
                                    -replace '#PASSWORDDUAL#', $PoolDual.Pass `
                                    -replace '#ALGORITHMDUAL#', $AlgonameDual
                                if ($Miner.PatternConfigFile -ne $null) {
                                    $ConfigFileArguments = (get-content $Miner.PatternConfigFile -raw) `
                                        -replace '#PORTDUAL#', $PoolDual.Port `
                                        -replace '#SERVERDUAL#', $PoolDual.Host `
                                        -replace '#PROTOCOLDUAL#', $PoolDual.Protocol `
                                        -replace '#LOGINDUAL#', $PoolDual.user `
                                        -replace '#PASSWORDDUAL#', $PoolDual.Pass `
                                        -replace '#ALGORITHMDUAL#', $AlgonameDual
                                }

                                $PoolAbbName += '|' + $PoolDual.Abbname
                                $PoolName += '|' + $PoolDual.name
                                if ($PoolDual.workers -ne $null) {$PoolWorkers += '|' + $PoolDual.workers}
                            }


                            $Miners += [pscustomobject] @{
                                Algorithm           = $AlgoName
                                AlgorithmDual       = $AlgoNameDual
                                Algorithms          = $Algo.PSObject.Properties.Name
                                Coin                = $_.Symbol
                                CoinDual            = $PoolDual.Symbol
                                Name                = $Minerfile.basename
                                Types               = $Miner.Types
                                Path                = $Miner.Path
                                HashRate            = $HashRateValue
                                HashRateDual        = $HashrateValueDual
                                Hashrates           = if ($Miner.Dualmining) {(ConvertTo-Hash ($HashRateValue)) + "s|" + (ConvertTo-Hash $HashrateValueDual) + "s"} else {(ConvertTo-Hash $HashRateValue) + "s"}
                                API                 = $Miner.API
                                Port                = $Miner.APIPort
                                Wrap                = $Miner.Wrap
                                URI                 = $Miner.URI
                                Arguments           = $Arguments
                                Profit              = $MinerProfit
                                ProfitDual          = $MinerProfitDual
                                PoolPrice           = if ($MiningMode -eq 'Automatic24h') {[double]$_.Price24h} else {[double]$_.Price}
                                PoolPriceDual       = if ($MiningMode -eq 'Automatic24h') {[double]$PoolDual.Price24h} else {[double]$PoolDual.Price}
                                Profits             = if ($Miner.Dualmining) {$MinerProfitDual + $MinerProfit} else {$MinerProfit}
                                PoolName            = $PoolName
                                PoolAbbName         = $PoolAbbName
                                PoolWorkers         = $PoolWorkers
                                DualMining          = $Miner.Dualmining
                                Username            = $_.user
                                WalletMode          = $_.WalletMode
                                Host                = $_.Host
                                ExtractionPath      = $Miner.ExtractionPath
                                GenerateConfigFile  = $miner.GenerateConfigFile
                                ConfigFileArguments = $ConfigFileArguments
                                Location            = $_.location
                                PrelaunchCommand    = $Miner.PrelaunchCommand
                                MinerFee            = if ($Miner.Fee -eq $null) {$null} else {[double]$Miner.fee}
                                PoolFee             = if ($_.Fee -eq $null) {$null} else {[double]$_.fee}
                            }
                        }
                    }
                }
            }
        }
    }




    #Launch download of miners
    $Miners |
        where-object URI -ne $null |
        where-object ExtractionPath -ne $null |
        where-object Path -ne $null |
        where-object URI -ne "" |
        where-object ExtractionPath -ne "" |
        where-object Path -ne "" |
        Select-Object URI, ExtractionPath, Path -Unique | ForEach-Object {Start-Downloader -URI $_.URI  -ExtractionPath $_.ExtractionPath -Path $_.Path}



    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {"NO MINERS!" | Out-Host ; EXIT}


    #Update the active miners list which is alive for  all execution time
    $ActiveMiners | ForEach-Object {
        #Search miner to update data

        $Miner = $miners | Where-Object Name -eq $_.Name |
            Where-Object Coin -eq $_.Coin |
            Where-Object Algorithm -eq $_.Algorithm |
            Where-Object CoinDual -eq $_.CoinDual |
            Where-Object AlgorithmDual -eq $_.AlgorithmDual |
            Where-Object PoolAbbName -eq $_.PoolAbbName |
            Where-Object Arguments -eq $_.Arguments |
            Where-Object Location -eq $_.Location |
            Where-Object ConfigFileArguments -eq $_.ConfigFileArguments

        $_.Best = $false
        $_.NeedBenchmark = $false
        $_.ConsecutiveZeroSpeed = 0
        #Mark as cancelled if more than 3 fails and running less than 180 secs, if no other alternative option, try forerever

        $TimeActive = ($_.ActiveTime.Hours * 3600) + ($_.ActiveTime.Minutes * 60) + $_.ActiveTime.Seconds
        if (($_.FailedTimes -gt 3) -and ($TimeActive -lt 180) -and (($ActiveMiners | Measure-Object).count -gt 1)) {
            $_.IsValid = $False
            $_.Status = 'Cancelled'
        }

        if (($Miner | Measure-Object).count -gt 1) {
            Clear-Host
            "DUPLICATED ALGO " + $MINER.ALGORITHM + " ON " + $MINER.NAME | Out-host
            EXIT
        }

        if ($Miner) {
            $_.Types = $Miner.Types
            $_.Profit = $Miner.Profit
            $_.ProfitDual = $Miner.ProfitDual
            $_.Profits = $Miner.Profits
            $_.PoolPrice = $Miner.PoolPrice
            $_.PoolPriceDual = $Miner.PoolPriceDual
            $_.HashRate = [double]$Miner.HashRate
            $_.HashRateDual = [double]$Miner.HashRateDual
            $_.Hashrates = $miner.hashrates
            $_.PoolWorkers = $Miner.PoolWorkers
            $_.PoolFee = $Miner.PoolFee
            if ($_.Status -ne 'Cancelled') {$_.IsValid = $true}

        } else {
            $_.IsValid = $false #simulates a delete

        }

    }


    ##Add new miners to list
    $Miners | ForEach-Object {

        $ActiveMiner = $ActiveMiners | Where-Object Name -eq $_.Name |
            Where-Object Coin -eq $_.Coin |
            Where-Object Algorithm -eq $_.Algorithm |
            Where-Object CoinDual -eq $_.CoinDual |
            Where-Object AlgorithmDual -eq $_.AlgorithmDual |
            Where-Object PoolAbbName -eq $_.PoolAbbName |
            Where-Object Arguments -eq $_.Arguments|
            Where-Object Arguments -eq $_.Arguments |
            Where-Object Location -eq $_.Location |
            Where-Object ConfigFileArguments -eq $_.ConfigFileArguments


        if ($ActiveMiner -eq $null) {
            $ActiveMiners += [PSCustomObject]@{
                Id                   = $ActiveMinersIdCounter
                Algorithm            = $_.Algorithm
                AlgorithmDual        = $_.AlgorithmDual
                Algorithms           = $_.Algorithms
                Name                 = $_.Name
                Coin                 = $_.coin
                CoinDual             = $_.CoinDual
                Path                 = Convert-Path $_.Path
                Arguments            = $_.Arguments
                Wrap                 = $_.Wrap
                API                  = $_.API
                Port                 = $_.Port
                Types                = $_.Types
                Profit               = $_.Profit
                ProfitDual           = $_.ProfitDual
                Profits              = $_.Profits
                HashRate             = [double]$_.HashRate
                HashRateDual         = [double]$_.HashRateDual
                Hashrates            = $_.hashrates
                PoolAbbName          = $_.PoolAbbName
                SpeedLive            = 0
                SpeedLiveDual        = 0
                ProfitLive           = 0
                ProfitLiveDual       = 0
                PoolPrice            = $_.PoolPrice
                PoolPriceDual        = $_.PoolPriceDual
                Best                 = $false
                Process              = $null
                NewThisRoud          = $True
                ActiveTime           = [TimeSpan]0
                LastActiveCheck      = [TimeSpan]0
                ActivatedTimes       = 0
                FailedTimes          = 0
                Status               = ""
                BenchmarkedTimes     = 0
                NeedBenchmark        = $false
                IsValid              = $true
                PoolWorkers          = $_.PoolWorkers
                DualMining           = $_.DualMining
                PoolName             = $_.PoolName
                Username             = $_.Username
                WalletMode           = $_.WalletMode
                Host                 = $_.Host
                ConfigFileArguments  = $_.ConfigFileArguments
                GenerateConfigFile   = $_.GenerateConfigFile
                ConsecutiveZeroSpeed = 0
                Location             = $_.Location
                PrelaunchCommand     = $_.PrelaunchCommand
                MinerFee             = $_.MinerFee
                PoolFee              = $_.PoolFee
            }
            $ActiveMinersIdCounter++
        }
    }

    #update miners that need benchmarks

    $ActiveMiners | ForEach-Object {

        if ($_.BenchmarkedTimes -lt 4 -and $_.isvalid -and ($_.Hashrate -eq 0 -or ($_.AlgorithmDual -ne $null -and $_.HashrateDual -eq 0)))
        {$_.NeedBenchmark = $true}
    }

    #For each type, select most profitable miner, not benchmarked has priority
    foreach ($Type in $Types) {

        $BestId = ($ActiveMiners |
                Where-Object IsValid |
                Where-Object Types -Contains $Type |
                Select-Object NeedBenchmark, Profits, Id, Types, Algorithm |
                Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, {$_.Profits}, Algorithm |
                Select-Object -First 1 |
                Select-Object id
        )
        if ($ActiveMiners -ne $null) { $ActiveMiners[$BestId.PSObject.Properties.value].best = $true }
    }



    #Stop miners running if they arent best now
    $ActiveMiners | Where-Object Best -EQ $false | ForEach-Object {
        if ($_.Process -eq $null) {
            $_.Status = "Failed"
        } elseif ($_.Process.HasExited -eq $false) {
            $_.Process.CloseMainWindow() | Out-Null
            $_.Status = "Idle"
        }

        try {$_.Process.CloseMainWindow() | Out-Null} catch {} #security closing
    }

    #$ActiveMiners | Where-Object Best -EQ $true  | Out-Host

    Start-Sleep 1 #Wait to prevent BSOD

    #Start all Miners marked as Best

    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        if ($_.Process -eq $null -or $_.Process.HasExited -ne $false) {

            $_.ActivatedTimes++

            if ($_.GenerateConfigFile -ne $null) {$_.ConfigFileArguments | Set-Content ($_.GenerateConfigFile)}

            #run prelaunch command
            if ($_.PrelaunchCommand -ne $null -and $_.PrelaunchCommand -ne "") {Start-Process -FilePath $_.PrelaunchCommand}

            if ($_.Wrap) {$_.Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)'" -PassThru}
            else {$_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path)}

            if ($_.NeedBenchmark) {$NextInterval = $BechmarkintervalTime} #if one need benchmark next interval will be short

            if ($_.Process -eq $null) {
                $_.Status = "Failed"
                $_.FailedTimes++
            } else {
                $_.Status = "Running"
                $_.LastActiveCheck = get-date
            }
        }
    }


    #Call api to local currency conversion
    $retries = 1
    do {
        try {
            $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing -TimeoutSec 5 | ConvertFrom-Json | Select-Object -ExpandProperty BPI
        } catch {start-sleep 3}
        $retries++
        if ($CDKResponse -eq $null) {start-sleep 3}
    } while ($CDKResponse -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host "COINDESK API NOT RESPONDING, NO LOCAL COIN CONVERSION"
    }

    $LabelProfit = "$LocalCurrency" + "/Day"
    $localBTCvalue = $CDKResponse.$LocalCurrency.rate_float

    $FirstLoopExecution = $True
    $IntervalStartTime = Get-Date

    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------

    while ($Host.UI.RawUI.KeyAvailable) {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush

    #loop to update info and check if miner is running
    While (1 -eq 1) {

        $ExitLoop = $false
        if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.BenchmarkedTimes++}
        Clear-host

        #display interval

        $TimetoNextInterval = NEW-TIMESPAN (Get-Date) ($IntervalStartTime.AddSeconds($NextInterval))
        $TimetoNextIntervalSeconds = ($TimetoNextInterval.Hours * 3600) + ($TimetoNextInterval.Minutes * 60) + $TimetoNextInterval.Seconds
        if ($TimetoNextIntervalSeconds -lt 0) {$TimetoNextIntervalSeconds = 0}

        # Set-ConsolePosition 0 0

        #display header
        "-----------------------------------------------------------------------------------------------------------------------"| Out-host
        "  (E)nd Interval   (P)rofits    (C)urrent    (H)istory    (W)allets                       |  Next Interval:  $TimetoNextIntervalSeconds secs" | Out-host
        "-----------------------------------------------------------------------------------------------------------------------"| Out-host

        #display donation message
        if ($DonationInterval) {
            " Donation period Active! You are donating $((Get-Content config.txt | Where-Object {$_ -like '@@DONATE=*'} ) -replace '@@DONATE=', '') minutes per day. Thank You for the support! :)"
            " If You wish, you can change this value in config.txt"
        }

        #display current mining info

        "------------------------------------------------ACTIVE MINERS----------------------------------------------------------"| Out-host

        $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
            @{Label = "Speed"; Expression = {if ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive)) + 's'} else {(ConvertTo-Hash  ($_.SpeedLive)) + 's|' + (ConvertTo-Hash ($_.SpeedLiveDual)) + 's'} }; Align = 'right'},
            @{Label = "mBTC/Day"; Expression = {($_.ProfitLive * 1000).tostring("n5")}; Align = 'right'},
            @{Label = $LabelProfit; Expression = {(([double]$_.ProfitLive + [double]$_.ProfitLiveDual) * [double]$localBTCvalue ).tostring("n2")}; Align = 'right'},
            @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else {$_.Algorithm + '|' + $_.AlgorithmDual}}},
            @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else {($_.coin) + '|' + ($_.CoinDual)}}},
            @{Label = "Miner"; Expression = {$_.Name}},
            @{Label = "Pool"; Expression = {$_.PoolAbbName}},
            @{Label = "Location"; Expression = {$_.Location}},
            @{Label = "PoolWorkers"; Expression = {$_.PoolWorkers}}
        ) | Out-Host


        $XToWrite = [ref]0
        $YToWrite = [ref]0
        Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)
        $YToWriteMessages = $YToWrite + 1
        $YToWriteData = $YToWrite + 2
        Remove-Variable XToWrite
        Remove-Variable YToWrite



        #display profits screen
        $TimeTaken = Measure-Command {
            if ($Screen -eq "Profits") {
                "----------------------------------------------------PROFITS------------------------------------------------------------"| Out-host


                Set-ConsolePosition 80 $YToWriteMessages

                "(B)est Miners/All       (T)op " + [string]$InitialProfitsScreenLimit + "/All" | Out-Host

                Set-ConsolePosition 0 $YToWriteData

                foreach ($Type in $Types) {
                    Write-Output "Type: $Type"

                    if ($ShowBestMinersOnly) {
                        $ProfitMiners = $ActiveMiners |
                            Where-Object IsValid |
                            Where-Object Types -Contains $Type |
                            Group-Object NeedBenchmark, Algorithm, AlgorithmDual, Coin, CoinDual |
                            ForEach-Object { $_.Group | Sort-Object -Descending Profits | Select-Object -First 1}
                    } else {
                        $ProfitMiners = $ActiveMiners |
                            Where-Object IsValid |
                            Where-Object Types -Contains $Type
                    }

                    #Display profits  information
                    $ProfitMiners | Where-Object Types -Contains $Type | Sort-Object -Descending NeedBenchmark, Profits | Select-Object -First $ProfitsScreenLimit | Format-Table -GroupBy Type (
                        @{Label = "Algo"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else {$_.Algorithm + '|' + $_.AlgorithmDual}}},
                        @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else {($_.coin) + '|' + ($_.CoinDual)}}},
                        @{Label = "Miner"; Expression = {$_.Name}},
                        @{Label = "Speed"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Hashrates}}},
                        @{Label = "mBTC/Day"; Expression = {if ($_.NeedBenchmark) {"-------"} else {($_.Profits * 1000).tostring("n5")}}; Align = 'right'},
                        @{Label = $LabelProfit; Expression = {([double]$_.Profits * [double]$localBTCvalue ).tostring("n2") } ; Align = 'right'},
                        @{Label = "Pool"; Expression = {if ($_.PoolFee -ne $null) {"{0:P1}" -f $_.PoolFee}}; Align = 'right'},
                        @{Label = "Miner"; Expression = {if ($_.MinerFee -ne $null) {"{0:P1}" -f $_.MinerFee}}; Align = 'right'},
                        @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                        @{Label = "Location"; Expression = {$_.Location}}
                    ) | Out-Host
                    Remove-Variable ProfitMiners
                }
            }
        }
        If ($DEBUG) {Write-Output "DEBUG: Time Taken: $($TimeTaken.TotalMilliseconds) ms"}




        if ($Screen -eq "Current") {

            "----------------------------------------------------CURRENT------------------------------------------------------------"| Out-host

            Set-ConsolePosition 0 $YToWriteData

            #Display profits  information
            $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
                @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else {$_.Algorithm + '|' + $_.AlgorithmDual}}},
                @{Label = "Coin"; Expression = {if ($_.CoinDual -eq $null) {$_.Coin} else {$_.Coin + '|' + $_.CoinDual}}},
                @{Label = "Miner"; Expression = {$_.Name}},
                @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
            ) | Out-Host

            #Nvidia SMI-info
            if ( $types -Contains "NVIDIA" ) {
                $NvidiaCards = @()
                invoke-expression "./bin/nvidia-smi.exe --query-gpu=gpu_name,driver_version,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed  --format=csv,noheader"  | foreach {

                    $SMIresultSplit = $_ -split (",")
                    $NvidiaCards += [PSCustomObject]@{

                        gpu_name           = $SMIresultSplit[0]
                        driver_version     = $SMIresultSplit[1]
                        utilization_gpu    = $SMIresultSplit[2]
                        utilization_memory = $SMIresultSplit[3]
                        temperature_gpu    = $SMIresultSplit[4]
                        power_draw         = $SMIresultSplit[5]
                        power_limit        = $SMIresultSplit[6]
                        FanSpeed           = $SMIresultSplit[7]
                    }
                }


                $NvidiaCards | Format-Table -Wrap  (
                    @{Label = "GPU"; Expression = {$_.gpu_name}},
                    @{Label = "GPU%"; Expression = {$_.utilization_gpu}},
                    @{Label = "Mem%"; Expression = {$_.utilization_memory}},
                    @{Label = "Temp"; Expression = {$_.temperature_gpu}},
                    @{Label = "FanSpeed"; Expression = {$_.FanSpeed}},
                    @{Label = "Power"; Expression = {$_.power_draw + " /" + $_.power_limit}}

                ) | Out-Host
            }
            if ( $types -Contains "AMD" ) {
                $AMDCards = @()
                invoke-expression "./bin/adli.exe --noheader"  | foreach {
                    $SMIresultSplit = $_ -split (",")
                    $AMDCards += [PSCustomObject]@{
                        gpu_index       = $SMIresultSplit[0]
                        gpu_name        = $SMIresultSplit[1]
                        temperature_gpu = $SMIresultSplit[2]
                        FanSpeed        = $SMIresultSplit[3]
                    }
                }
                $AMDCards | Format-Table -Wrap  (
                    @{Label = "#"; Expression = {$_.gpu_index}},
                    @{Label = "GPU"; Expression = {$_.gpu_name}},
                    @{Label = "Temp"; Expression = {$_.temperature_gpu}},
                    @{Label = "FanSpeed"; Expression = {$_.FanSpeed}}
                ) | Out-Host
            }
        }



        # if ($Screen -eq "Wallets" -or $FirstTotalExecution -eq $true) {
        if ($Screen -eq "Wallets") {
            # if ($Screen -eq "Wallets") {
            "----------------------------------------------------WALLETS (slow)-----------------------------------------------------"| Out-host
            Set-ConsolePosition 85 $YToWriteMessages
            "(U)pdate  - $WalletsUpdate  " | Out-Host
            # }


            if ($WalletsUpdate -eq $null) {
                #wallets only refresh one time each interval, not each loop iteration

                $WalletsUpdate = get-date

                $WalletsToCheck = @()

                $Pools  | where-object WalletMode -eq 'WALLET' | Select-Object PoolName, AbbName, User, WalletMode -unique  | ForEach-Object {
                    $WalletsToCheck += [PSCustomObject]@{
                        PoolName          = $_.PoolName
                        AbbName           = $_.AbbName
                        WalletMode        = $_.WalletMode
                        User              = $_.User
                        Coin              = $null
                        Algorithm         = $null
                        OriginalAlgorithm = $null
                        OriginalCoin      = $null
                        Host              = $null
                        Symbol            = $null
                    }
                }
                $Pools  | where-object WalletMode -eq 'APIKEY' | Select-Object PoolName, AbbName, info, Algorithm, OriginalAlgorithm, OriginalCoin, Symbol, WalletMode  -unique  | ForEach-Object {
                    $WalletsToCheck += [PSCustomObject]@{
                        PoolName          = $_.PoolName
                        AbbName           = $_.AbbName
                        WalletMode        = $_.WalletMode
                        User              = $null
                        Coin              = $_.Info
                        Algorithm         = $_.Algorithm
                        OriginalAlgorithm = $_.OriginalAlgorithm
                        OriginalCoin      = $_.OriginalCoin
                        Symbol            = $_.Symbol
                    }
                }

                $WalletStatus = @()
                $WalletsToCheck |ForEach-Object {

                    Set-ConsolePosition 0 $YToWriteMessages
                    "                                                                         "| Out-host
                    Set-ConsolePosition 0 $YToWriteMessages

                    if ($_.WalletMode -eq "WALLET") {"Checking " + $_.Abbname + " - " + $_.User | Out-host}
                    else {"Checking " + $_.Abbname + " - " + $_.coin + ' (' + $_.Algorithm + ')' | Out-host}

                    $Ws = Get-Pools -Querymode $_.WalletMode -PoolsFilterList $_.Poolname -Info ($_)

                    if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                    else {$Ws | Add-Member Wallet $_.Coin}

                    $Ws | Add-Member PoolName $_.Poolname

                    $WalletStatus += $Ws

                    start-sleep 1 #no saturation of pool api
                    Set-ConsolePosition 0 $YToWriteMessages
                    "                                                                         "| Out-host

                }


                if ($FirstTotalExecution -eq $true) {$WalletStatusAtStart = $WalletStatus; $FirstTotalExecution = $false}

                $WalletStatus | Add-Member BalanceAtStart [double]$null
                $WalletStatus | ForEach-Object {
                    $_.BalanceAtStart = ($WalletStatusAtStart |Where-Object wallet -eq $_.Wallet |Where-Object poolname -eq $_.poolname |Where-Object currency -eq $_.currency).balance
                }

            }


            if ($Screen -eq "Wallets") {

                Set-ConsolePosition 0 $YToWriteData

                $WalletStatus | where-object Balance -gt 0 | Sort-Object poolname | Format-Table -Wrap -groupby poolname (
                    @{Label = "Wallet"; Expression = {$_.wallet}},
                    @{Label = "Currency"; Expression = {$_.currency}},
                    @{Label = "Balance"; Expression = {$_.balance.tostring("n5")}; Align = 'right'},
                    @{Label = "IncFromStart"; Expression = {($_.balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                ) | Out-Host


                $Pools  | where-object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                    "NO API FOR POOL " + $_.PoolName + " - NO WALLETS CHECK" | Out-host
                }
            }
        }


        if ($Screen -eq "History") {

            "--------------------------------------------------HISTORY------------------------------------------------------------"| Out-host

            Set-ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners | Where-Object ActivatedTimes -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
                @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else {$_.Algorithm + '|' + $_.AlgorithmDual}}},
                @{Label = "Coin"; Expression = {if ($_.CoinDual -eq $null) {$_.Coin} else {$_.Coin + '|' + $_.CoinDual}}},
                @{Label = "Speed"; Expression = {if ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive)) + 's'} else {(ConvertTo-Hash  ($_.SpeedLive)) + 's|' + (ConvertTo-Hash ($_.SpeedLiveDual)) + 's'} }; Align = 'right'},
                @{Label = "Active"; Expression = {"{0:dd}:{0:hh}:{0:mm}" -f $_.ActiveTime}},
                @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
            ) | Out-Host
        }


        $ActiveMiners | Where-Object Best -eq $true | ForEach-Object {
            $_.SpeedLive = 0
            $_.SpeedLiveDual = 0
            $_.ProfitLive = 0
            $_.ProfitLiveDual = 0
            $Miner_HashRates = $null


            if ($_.Process -eq $null -or $_.Process.HasExited) {
                if ($_.Status -eq "Running") {
                    $_.Status = "Failed"
                    $_.FailedTimes++
                    $ExitLoop = $true
                } else
                { $ExitLoop = $true}
            }

            else {
                $_.ActiveTime += (get-date) - $_.LastActiveCheck
                $_.LastActiveCheck = get-date

                $Miner_HashRates = Get-Live-HashRate $_.API $_.Port

                if ($Miner_HashRates -ne $null) {
                    $_.SpeedLive = [double]($Miner_HashRates[0])
                    $_.ProfitLive = $_.SpeedLive * $_.PoolPrice


                    if ($Miner_HashRates[0] -gt 0) {$_.ConsecutiveZeroSpeed = 0} else {$_.ConsecutiveZeroSpeed++}


                    if ($_.DualMining) {
                        $_.SpeedLiveDual = [double]($Miner_HashRates[1])
                        $_.ProfitLiveDual = $_.SpeedLiveDual * $_.PoolPriceDual
                    }


                    $Value = [long]($Miner_HashRates[0] * 0.95)
                    $ValueDual = [long]($Miner_HashRates[1] * 0.95)

                    if ($Value -gt $_.Hashrate -and $_.NeedBenchmark -and ($valueDual -gt 0 -or $_.Dualmining -eq $false)) {

                        $_.Hashrate = $Value
                        $_.HashrateDual = $ValueDual
                        Set-Hashrates -algorithm $_.Algorithms -minername $_.Name -value  $Value -valueDual $ValueDual
                    }
                }
            }



            if ($_.ConsecutiveZeroSpeed -gt 30) {
                #to prevent miner hangs
                $ExitLoop = 'true'
                $_.FailedTimes++
                $_.Status = 'Failed'
            }


            #Benchmark timeout
            if ($_.BenchmarkedTimes -ge 3) {
                $_.Status = 'Cancelled'
                $ExitLoop = $true
            }
        }




        $FirstLoopExecution = $False

        #Loop for reading key and wait
        $Loopstart = get-date
        $KeyPressed = $null


        while ((NEW-TIMESPAN $Loopstart (get-date)).Seconds -lt 10 -and $KeyPressed -notin @('P', 'C', 'H', 'E', 'W', 'U', 'T', 'B')) {
            Start-Sleep -Seconds 1
            if ($host.ui.RawUi.KeyAvailable) {
                $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
                $KeyPressed = $Key.character
                while ($Host.UI.RawUI.KeyAvailable) {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush
            }
        }

        switch ($KeyPressed) {
            'P' {$Screen = 'profits'}
            'C' {$Screen = 'current'}
            'H' {$Screen = 'history'}
            'E' {$ExitLoop = $true}
            'W' {$Screen = 'Wallets'}
            'U' {if ($Screen -eq "Wallets") {$WalletsUpdate = $null}}
            'T' {if ($Screen -eq "Profits") {if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) {$ProfitsScreenLimit = 1000} else {$ProfitsScreenLimit = $InitialProfitsScreenLimit}}}
            'B' {if ($Screen -eq "Profits") {if ($ShowBestMinersOnly -eq $true) {$ShowBestMinersOnly = $false} else {$ShowBestMinersOnly = $true}}}

        }



        if (((Get-Date) -ge ($IntervalStartTime.AddSeconds($NextInterval))) -or ($ExitLoop)  ) {break} #If time of interval has over, exit of main loop
    }



    Remove-variable miners
    Remove-variable pools
    [GC]::Collect() #force garbage recollector for free memory
}

#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of always running loop--------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------



#Stop the log
Stop-Transcript
