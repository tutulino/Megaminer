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
Import-Module NetSecurity -ErrorAction Ignore
Import-Module Defender -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\NetSecurity\NetSecurity.psd1" -ErrorAction Ignore
Import-Module "$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1" -ErrorAction Ignore

#Start log file

$LogPath = '.\Logs\'
if (!(Test-Path -Path $LogPath)) { New-Item -Path $LogPath -ItemType directory | Out-Null }
$LogName = $LogPath + "$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"
Start-Transcript $LogName   #for start log msg
Stop-Transcript
$LogFile = [System.IO.StreamWriter]::new( $LogName, $true )
$LogFile.AutoFlush = $true

Clear-Files

if ([Net.ServicePointManager]::SecurityProtocol -notmatch [Net.SecurityProtocolType]::Tls12) {
    [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
}

# Force Culture to en-US
$culture = [System.Globalization.CultureInfo]::CreateSpecificCulture("en-US")
$culture.NumberFormat.NumberDecimalSeparator = "."
$culture.NumberFormat.NumberGroupSeparator = ","
[System.Threading.Thread]::CurrentThread.CurrentCulture = $culture

$ErrorActionPreference = "Continue"
$Config = Get-Config

$Application = "Forager"
$Release = "1.3"
Write-Log ("$Application v$Release") $LogFile $false

if ($GroupNames -eq $null) {$Host.UI.RawUI.WindowTitle = $Application}
else {$Host.UI.RawUI.WindowTitle = "Forager-" + ($GroupNames -join "/")}

$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' #This align cuda id with nvidia-smi order
$env:GPU_FORCE_64BIT_PTR = 0 #For AMD
$env:GPU_MAX_HEAP_SIZE = 100 #For AMD
$env:GPU_USE_SYNC_OBJECTS = 1 #For AMD
$env:GPU_MAX_ALLOC_PERCENT = 100 #For AMD
$env:GPU_SINGLE_ALLOC_PERCENT = 100 #For AMD

$progressPreference = 'silentlyContinue' #No progress message on web requests
#$progressPreference = 'Stop'

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

#Set process priority to BelowNormal to avoid hash rate drops on systems with weak CPUs
(Get-Process -Id $PID).PriorityClass = "BelowNormal"

if (Get-Command "Unblock-File" -ErrorAction SilentlyContinue) {Get-ChildItem . -Recurse | Unblock-File}
if ((Get-Command "Get-MpPreference" -ErrorAction SilentlyContinue) -and (Get-MpComputerStatus -ErrorAction SilentlyContinue) -and (Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {
    Start-Process (@{desktop = "powershell"; core = "pwsh"}.$PSEdition) "-Command Import-Module '$env:Windir\System32\WindowsPowerShell\v1.0\Modules\Defender\Defender.psd1'; Add-MpPreference -ExclusionPath '$(Convert-Path .)'" -Verb runAs
}

$ActiveMiners = @()
$ShowBestMinersOnly = $true
$FirstTotalExecution = $true
$StartTime = Get-Date

$Screen = $Config.STARTSCREEN

#---Parameters checking

if ($MiningMode -NotIn @('Manual', 'Automatic', 'Automatic24h')) {
    "Parameter MiningMode not valid, valid options: Manual, Automatic, Automatic24h" | Out-Host
    Exit
}
$Params = @{
    Querymode       = "info"
    PoolsFilterList = $PoolsName
    CoinFilterList  = $CoinsName
    Location        = $Location
    AlgoFilterList  = $Algorithm

}
$PoolsChecking = Get-Pools @Params

$PoolsErrors = switch ($MiningMode) {
    "Automatic" {$PoolsChecking | Where-Object ActiveOnAutomaticMode -eq $false}
    "Automatic24h" {$PoolsChecking | Where-Object ActiveOnAutomatic24hMode -eq $false}
    "Manual" {$PoolsChecking | Where-Object ActiveOnManualMode -eq $false }
}

$PoolsErrors | ForEach-Object {
    Write-Error "Selected MiningMode is not valid for pool " + $_.Name
    Exit
}

if ($MiningMode -eq 'Manual' -and ($CoinsName -split ',').Count -ne 1) {
    Write-Error "On manual mode one coin must be selected"
    Exit
}

if ($MiningMode -eq 'Manual' -and ($Algorithm -split ',').Count -ne 1) {
    Write-Error "On manual mode one algorithm must be selected"
    Exit
}

#parameters backup

$ParamAlgorithmBCK = $Algorithm
$ParamPoolsNameBCK = $PoolsName
$ParamCoinsNameBCK = $CoinsName
$ParamMiningModeBCK = $MiningMode

try {Set-WindowSize 180 50} catch {}

$IntervalStartAt = (Get-Date) #first initialization, must be outside loop

Send-ErrorsToLog $LogFile

$Msg = "Starting Parameters: "
$Msg += " //Algorithm: " + [string]($Algorithm -join ",")
$Msg += " //PoolsName: " + [string]($PoolsName -join ",")
$Msg += " //CoinsName: " + [string]($CoinsName -join ",")
$Msg += " //MiningMode: " + $MiningMode
$Msg += " //GroupNames: " + [string]($GroupNames -join ",")
$Msg += " //PercentToSwitch: " + $PercentToSwitch

Write-Log $Msg $LogFile $false

#Enable api
if ($config.ApiPort -gt 0) {

    Write-Log ("Starting API in port " + [string]$config.ApiPort) $LogFile $false

    $ApiSharedFile = $currentDir + "\ApiShared" + [string](Get-Random -minimum 0 -maximum 99999999) + ".tmp"
    $command = "-WindowStyle minimized  -noExit -executionpolicy bypass -file $currentDir\Includes\ApiListener.ps1 -port " + [string]$config.ApiPort + " -SharedFile $ApiSharedFile "
    $APIprocess = Start-Process -FilePath "powershell.exe" -ArgumentList $command -Verb RunAs -PassThru -WindowStyle Minimized

    #open firewall port
    $command = "New-NetFirewallRule -DisplayName '$Application' -Direction Inbound -Action Allow -Protocol TCP -LocalPort $($config.ApiPort)"
    Start-Process -FilePath "powershell.exe" -ArgumentList $command -Verb RunAs -WindowStyle Minimized

    $command = "New-NetFirewallRule -DisplayName '$Application' -Direction Outbound -Action Allow -Protocol TCP -LocalPort $($config.ApiPort)"
    Start-Process -FilePath "powershell.exe" -ArgumentList $command -Verb RunAs -WindowStyle Minimized
}

$Quit = $false

# Initialize MSI Afterburner
if ((Get-ConfigVariable "Afterburner") -eq "Enabled") {
    . .\Includes\afterburner.ps1
}

#enable EthlargementPill

if (($config.EthlargementPill) -like "Rev*") {
    Write-Log "Starting ETHlargementPill " $LogFile $false
    $arg = "-" + $config.EthlargementPill
    $EthPill = Start-Process -FilePath ".\Includes\OhGodAnETHlargementPill-r2.exe" -passthru -Verb RunAs -ArgumentList $arg
}

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

    $Config = Get-Config
    $DetailedLog = ($Config.DebugLog -eq "ENABLED")
    if ($DetailedLog) {Write-Log ($Config | ConvertTo-Json) $LogFile $false}

    Clear-Host; $RepaintScreen = $true

    # Check for updates
    try {
        $Request = Invoke-RestMethod -Uri "https://api.github.com/repos/yuzi-co/$Application/releases/latest" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        $RemoteVersion = ($Request.tag_name -replace '^v')
        $Uri = $Request.assets | Where-Object Name -eq "$($Application)-$($RemoteVersion).7z" | Select-Object -ExpandProperty browser_download_url

        if ($RemoteVersion -gt $Release) {
            Write-Host "$Application is out of date. There is an updated version available at $URI" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Failed to get $Application updates."
    }

    #get mining types
    $DeviceGroups = Get-MiningTypes -filter $GroupNames

    Write-Log (Get-DevicesInformation $DeviceGroups | ConvertTo-Json) $LogFile $false
    Write-Log ($DeviceGroups | ConvertTo-Json) $LogFile $false
    if ($FirstTotalExecution) {Test-DeviceGroupsConfig $DeviceGroups}

    $NumberTypesGroups = ($DeviceGroups | Measure-Object).count
    if ($NumberTypesGroups -gt 0) {$InitialProfitsScreenLimit = [Math]::Floor(30 / $NumberTypesGroups) - 5} #screen adjust to number of groups
    if ($FirstTotalExecution) {$ProfitsScreenLimit = $InitialProfitsScreenLimit}

    Write-Log "New interval starting..." $LogFile $true
    Write-Log (Get-ComputerStats | ConvertTo-Json) $LogFile $false

    $Location = $Config.Location

    if ([string]::IsNullOrWhiteSpace($PercentToSwitch)) {$PercentToSwitch2 = [int]($Config.PercentToSwitch)}
    else {$PercentToSwitch2 = [int]$PercentToSwitch}
    $DelayCloseMiners = $Config.DelayCloseMiners

    $Currency = $Config.Currency
    $BenchmarkIntervalTime = [int]($Config.BenchmarkTime)
    $LocalCurrency = $Config.LocalCurrency
    if ([string]::IsNullOrWhiteSpace($LocalCurrency)) {
        #for old config.ini compatibility
        $LocalCurrency = switch ($Location) {
            'Europe' {"EUR"}
            'EU' {"EUR"}
            'US' {"USD"}
            'ASIA' {"USD"}
            'GB' {"GBP"}
            default {"USD"}
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
        $Config.UserName = "ffwd"
        $Config.WorkerName = "Donate"
        $CoinsWallets = @{
            BTC = "3NoVvkGSNjPX8xBMWbP2HioWYK395wSzGL"
        }

        $DonateInterval = ($ConfigDonateTime - $ElapsedDonatedTime) * 60

        $Algorithm = $null
        $PoolsName = ("MiningPoolHub", "NiceHash")
        $CoinsName = $null
        $MiningMode = "Automatic"

        if ($ElapsedDonatedTime -ge $ConfigDonateTime) {"0_0" | Set-Content -Path 'Donation.ctr'}
        else {[string]$DonationPastTime + "_" + [string]$ElapsedDonatedTime | Set-Content -Path 'Donation.ctr'}

        Write-Log ("Next interval you will be donating for $DonateInterval seconds, thanks for your support") $LogFile $true
    } else {
        #NOT donation interval
        $DonationInterval = $false

        $Algorithm = $ParamAlgorithmBCK
        $PoolsName = $ParamPoolsNameBCK
        $CoinsName = $ParamCoinsNameBCK
        $MiningMode = $ParamMiningModeBCK
        if (!$Config.WorkerName) {$Config.WorkerName = $env:COMPUTERNAME}

        $CoinsWallets = @{}
        switch -regex -file config.ini {
            "^\s*WALLET_(\w+)\s*=\s*(.*)" {
                $name, $value = $matches[1..2]
                $CoinsWallets[$name] = $value.Trim()
            }
        }
        [string]$ElapsedDonationTime + "_0" | Set-Content -Path Donation.ctr
    }
    $UserName = $Config.UserName
    $WorkerName = $Config.WorkerName

    $MinerWindowStyle = $Config.MinerWindowStyle
    if ([string]::IsNullOrEmpty($MinerWindowStyle)) {$MinerWindowStyle = 'Minimized'}

    $MinerStatusUrl = $Config.MinerStatusUrl
    $MinerStatusKey = $Config.MinerStatusKey
    if (!$MinerStatusKey -and $CoinsWallets.BTC) {$MinerStatusKey = $CoinsWallets.BTC}

    Send-ErrorsToLog $LogFile

    #get actual hour electricity cost
    ($Config.ElectricityCost | ConvertFrom-Json) | ForEach-Object {
        if ((
                $_.HourStart -lt $_.HourEnd -and
                (Get-Date).Hour -in @(($_.HourStart)..($_.HourEnd))
            ) -or (
                $_.HourStart -gt $_.HourEnd -and (
                    (Get-Date).Hour -in @(($_.HourStart)..23) -or
                    (Get-Date).Hour -in @(0..($_.HourEnd))
                )
            )
        ) {$ElectricityCostValue = [double]$_.CostKwh}
    }

    Write-Log "Loading Pools Information..." $LogFile $true

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
    do {
        $Params = @{
            Querymode       = "core"
            PoolsFilterList = $PoolsName
            CoinFilterList  = $CoinsName
            Location        = $Location
            AlgoFilterList  = $Algorithm
        }
        $AllPools = Get-Pools @Params
        if ($AllPools.Count -eq 0) {
            $Msg = "NO POOLS!...retry in 10 sec --- REMEMBER, IF YOUR ARE MINING ON ANONYMOUS WITHOUT AUTOEXCHANGE POOLS LIKE YIIMP, NANOPOOL, ETC. YOU MUST SET WALLET FOR AT LEAST ONE POOL COIN IN config.ini"
            Write-Log $Msg $LogFile $true

            Start-Sleep 10
        }
    } while ($AllPools.Count -eq 0)

    $AllPools | Select-Object name -unique | ForEach-Object {Write-Log ("Pool " + $_.Name + " was responsive...") $LogFile $true}

    Write-Log ("Detected $($AllPools.Count) pools...") $LogFile $true

    #Filter by minworkers variable (only if there is any pool greater than minimum)
    $Pools = ($AllPools | Where-Object {$_.PoolWorkers -ge $Config.MinWorkers -or $_.PoolWorkers -eq $null})
    if ($Pools.Count -ge 1) {
        Write-Log ("$($Pools.Count) pools left after min workers filter...") $LogFile $true
    } else {
        $Pools = $AllPools
        Write-Log ("No pools with workers greater than minimum config, filter is discarded...") $LogFile $true
    }

    ## Select highest paying pool for each algo and check if pool is alive.
    Write-Log ("Select top pool for each algo in config") $LogFile $true
    if ($config.PingPools -eq 'Enabled') {Write-Log ("Checking pool availability") $LogFile $true}
    $PoolsFiltered = $Pools | Group-Object -Property Algorithm | ForEach-Object {
        $NeedPool = $false
        foreach ($DeviceGroup in $DeviceGroups) {
            ## Is pool algorithm defined in config?
            $AlgoList = $DeviceGroup.Algorithms | ForEach-Object {$_ -split '_'} | Select-Object -Unique
            if (!$AlgoList -or $_.Name -in $AlgoList) {$NeedPool = $true}
        }
        if ($NeedPool) {
            ## Order by price (profitability)
            $_.Group | Sort-Object -Property `
            @{Expression = {if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"}}; Descending = $true},
            @{Expression = "LocationPriority"; Ascending = $true} | ForEach-Object {
                if ($NeedPool) {
                    ## test tcp connection to pool
                    if ($config.PingPools -ne 'Enabled' -or (Test-TCPPort -Server $_.Host -Port $_.Port -Timeout 100)) {
                        $NeedPool = $false
                        $_  ## return result
                    } else {
                        Write-Log "$($_.PoolName): $($_.Host):$($_.Port) is not responding!" $LogFile $true
                    }
                }
            }
        }
    }
    $Pools = $PoolsFiltered

    Write-Log ([string]$Pools.Count + " pools left") $LogFile $true
    Remove-Variable PoolsFiltered

    #Call api to local currency conversion
    try {
        $CDKResponse = Invoke-APIRequest -Url "https://api.coindesk.com/v1/bpi/currentprice/$LocalCurrency.json" -MaxAge 60 |
            Select-Object -ExpandProperty BPI
        $LocalBTCvalue = $CDKResponse.$LocalCurrency.rate_float
        Write-Log ("CoinDesk API was responsive...") $LogFile $true
    } catch {
        Write-Log "Coindesk API not responding, no local coin conversion..." $LogFile $true
    }

    #Load information about the Miner asociated to each Coin-Algo-Miner
    $Miners = @()

    $MinersFolderContent = (Get-ChildItem "Miners" -Filter "*.json")

    Write-Log ("Files in miner folder: " + [string]($MinersFolderContent.count)) $LogFile $false
    Write-Log ("Number of device groups: " + $DeviceGroups.count) $LogFile $false

    foreach ($MinerFile in $MinersFolderContent) {
        try { $Miner = $MinerFile | Get-Content | ConvertFrom-Json }
        catch {
            Write-Log "-------BAD FORMED JSON: $MinerFile" $LogFile $true
            Exit
        }

        foreach ($DeviceGroup in $DeviceGroups) {
            #generate a line for each device group that has algorithm as valid
            if ($Miner.Type -ne $DeviceGroup.type) {
                if ($DetailedLog) {Write-Log ([string]$MinerFile.pschildname + " is NOT valid for " + $DeviceGroup.GroupName + "...ignoring") $LogFile $false }
                Continue
            } elseif ($Config.("ExcludeMiners_" + $DeviceGroup.GroupName) -and ($Config.("ExcludeMiners_" + $DeviceGroup.GroupName).split(',') | Where-Object {$MinerFile.BaseName -like $_})) {
                if ($DetailedLog) {Write-Log ([string]$MinerFile.pschildname + " is Excluded for " + $DeviceGroup.GroupName + "...ignoring") $LogFile $false }
                Continue
            } else {
                #check group and miner types are the same
                if ($DetailedLog) {Write-Log ([string]$MinerFile.pschildname + " is valid for " + $DeviceGroup.GroupName) $LogFile $false }
            }

            foreach ($Algo in $Miner.Algorithms.PSObject.Properties) {

                ##AlgoName contains real name for dual and no dual miners
                $AlgoTmp = ($Algo.Name -split "\|")[0]
                $AlgoLabel = ($Algo.Name -split ("\|"))[1]
                $AlgoName = Get-AlgoUnifiedName (($AlgoTmp -split ("_"))[0])
                $AlgoNameDual = Get-AlgoUnifiedName (($AlgoTmp -split ("_"))[1])
                $Algorithms = $AlgoName + $(if ($AlgoNameDual) {"_$AlgoNameDual"})

                # Check memory constraints on miners
                if ($DeviceGroup.MemoryGB -gt 0) {
                    $SkipLabel = $false
                    if ($AlgoLabel -match '(?<mem>\d+)gb.*') {
                        if ($DeviceGroup.MemoryGB -lt [int]$Matches.mem) {$SkipLabel = $true}
                    }
                    if ($SkipLabel) {
                        Write-Log ($MinerFile.BaseName + "/" + $Algorithms + "/" + $AlgoLabel + " skipped due to constraints") $LogFile $false
                        Continue
                    }
                }

                if ($DeviceGroup.Algorithms -and $Algorithms -notin $DeviceGroup.Algorithms) {Continue} #check config has this algo as minable

                foreach ($Pool in ($Pools | Where-Object Algorithm -eq $AlgoName)) {
                    #Search pools for that algo

                    # If Miner limited to pools
                    if ($Miner.Pools -and $ExecutionContext.InvokeCommand.ExpandString($Miner.Pools) -eq $false) {Continue}

                    if (!$AlgoNameDual -or ($Pools | Where-Object Algorithm -eq $AlgoNameDual)) {

                        #Set flag if both Miner and Pool support SSL
                        $enableSSL = [bool]($Miner.SSL -and $Pool.SSL)

                        #Replace wildcards patterns
                        if ($Pool.PoolName -eq 'Nicehash') {$Nicehash = $true} else {$Nicehash = $false}
                        if ($Nicehash) {
                            $WorkerName2 = $WorkerName + $DeviceGroup.GroupName #Nicehash requires alphanumeric WorkerNames
                        } else {
                            $WorkerName2 = $WorkerName + '_' + $DeviceGroup.GroupName
                        }
                        $PoolUser = $Pool.User -replace '#WorkerName#', $WorkerName2
                        $PoolPass = $Pool.Pass -replace '#WorkerName#', $WorkerName2

                        $Params = @{
                            '#Protocol#'            = $(if ($enableSSL) {$Pool.ProtocolSSL} else {$Pool.Protocol})
                            '#Server#'              = $(if ($enableSSL) {$Pool.HostSSL} else {$Pool.Host})
                            '#Port#'                = $(if ($enableSSL) {$Pool.PortSSL} else {$Pool.Port})
                            '#Login#'               = $PoolUser
                            '#Password#'            = $PoolPass
                            '#GPUPlatform#'         = $DeviceGroup.Platform
                            '#Algorithm#'           = $AlgoName
                            '#AlgorithmParameters#' = $Algo.Value
                            '#WorkerName#'          = $WorkerName2
                            '#Devices#'             = $DeviceGroup.Devices
                            '#DevicesClayMode#'     = $DeviceGroup.DevicesClayMode
                            '#DevicesETHMode#'      = $DeviceGroup.DevicesETHMode
                            '#DevicesNsgMode#'      = $DeviceGroup.DevicesNsgMode
                            '#EthStMode#'           = $Pool.EthStMode
                            '#GroupName#'           = $DeviceGroup.GroupName
                        }

                        $Arguments = $Miner.Arguments -join " "
                        foreach ($P in $Params.Keys) {$Arguments = $Arguments -replace $P, $Params.$P}
                        $PatternConfigFile = $Miner.PatternConfigFile -replace '#Algorithm#', $AlgoName
                        if ($PatternConfigFile -and (Test-Path -Path $PatternConfigFile)) {
                            $ConfigFileArguments = Replace-ForEachDevice (Get-Content $PatternConfigFile -raw) -Devices $DeviceGroup.Devices
                            foreach ($P in $Params.Keys) {$ConfigFileArguments = $ConfigFileArguments -replace $P, $Params.$P}
                        }

                        #select correct price by mode
                        $Price = $Pool.$(if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"})

                        #Search for dualmining pool
                        if ($AlgoNameDual) {
                            #search dual pool and select correct price by mode
                            $PoolDual = $Pools |
                                Where-Object Algorithm -eq $AlgoNameDual |
                                Sort-Object @{Expression = {if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"}}; Descending = $true} |
                                Select-Object -First 1
                            $PriceDual = [double]$PoolDual.$(if ($MiningMode -eq 'Automatic24h') {"Price24h"} else {"Price"})

                            #Set flag if both Miner and Pool support SSL
                            $enableDualSSL = ($Miner.SSL -and $PoolDual.SSL)

                            #Replace wildcards patterns
                            $WorkerName3 = $WorkerName2 + 'D'
                            $PoolUserDual = $PoolDual.User -replace '#WorkerName#', $WorkerName3
                            $PoolPassDual = $PoolDual.Pass -replace '#WorkerName#', $WorkerName3

                            $Params = @{
                                '#PortDual#'      = $(if ($enableDualSSL) {$PoolDual.PortSSL} else {$PoolDual.Port})
                                '#ServerDual#'    = $(if ($enableDualSSL) {$PoolDual.HostSSL} else {$PoolDual.Host})
                                '#ProtocolDual#'  = $(if ($enableDualSSL) {$PoolDual.ProtocolSSL} else {$PoolDual.Protocol})
                                '#LoginDual#'     = $PoolUserDual
                                '#PasswordDual#'  = $PoolPassDual
                                '#AlgorithmDual#' = $AlgoNameDual
                                '#WorkerName#'    = $WorkerName3
                            }
                            foreach ($P in $Params.Keys) {$Arguments = $Arguments -replace $P, $Params.$P}
                            if ($PatternConfigFile -and (Test-Path -Path $PatternConfigFile)) {
                                foreach ($P in $Params.Keys) {$ConfigFileArguments = $ConfigFileArguments -replace $P, $Params.$P}
                            }
                        } else {
                            $PoolDual = $null
                            $PoolUserDual = $null
                            $PriceDual = 0
                        }

                        ## SubMiner are variations of miner that not need to relaunch
                        ## Creates a "SubMiner" object for each PL
                        $SubMiners = @()
                        foreach ($PowerLimit in ($DeviceGroup.PowerLimits)) {
                            ## always exists as least a power limit 0

                            #Write-Log ("$MinerFile $AlgoName "+$DeviceGroup.GroupName+" "+$Pool.Info+" $PowerLimit") $LogFile $true

                            ## look in ActiveMiners collection if we found that miner to conserve some properties and not read files
                            $FoundMiner = $ActiveMiners | Where-Object {
                                $_.Name -eq $MinerFile.BaseName -and
                                $_.Coin -eq $Pool.Info -and
                                $_.Algorithm -eq $AlgoName -and
                                $_.CoinDual -eq $PoolDual.Info -and
                                $_.AlgorithmDual -eq $AlgoNameDual -and
                                $_.PoolAbbName -eq $Pool.AbbName -and
                                $_.PoolAbbNameDual -eq $PoolDual.AbbName -and
                                $_.DeviceGroup.Id -eq $DeviceGroup.Id -and
                                $_.AlgoLabel -eq $AlgoLabel }

                            $FoundSubMiner = $FoundMiner.SubMiners | Where-Object {$_.PowerLimit -eq $PowerLimit}

                            if (!$FoundSubMiner) {
                                $Params = @{
                                    Algorithm  = $Algorithms
                                    MinerName  = $MinerFile.BaseName
                                    GroupName  = $DeviceGroup.GroupName
                                    PowerLimit = $PowerLimit
                                    AlgoLabel  = $AlgoLabel
                                }
                                [array]$Hrs = Get-HashRates @Params
                            } else {
                                [array]$Hrs = $FoundSubMiner.SpeedReads
                            }

                            if ($Hrs.Count -gt 10) {
                                # Remove 10 percent of lowest and highest rate samples which may skew the average
                                $Hrs = $Hrs | Sort-Object Speed
                                $p5Index = [math]::Ceiling($Hrs.Count * 0.05)
                                $p95Index = [math]::Ceiling($Hrs.Count * 0.95)
                                $Hrs = $Hrs[$p5Index..$p95Index] | Sort-Object SpeedDual, Speed
                                $p5Index = [math]::Ceiling($Hrs.Count * 0.05)
                                $p95Index = [math]::Ceiling($Hrs.Count * 0.95)
                                $Hrs = $Hrs[$p5Index..$p95Index]

                                $PowerValue = [double]($Hrs | Measure-Object -property Power -average).average
                                $HashRateValue = [double]($Hrs | Measure-Object -property Speed -average).average
                                $HashRateValueDual = [double]($Hrs | Measure-Object -property SpeedDual -average).average
                            } else {
                                $PowerValue = 0
                                $HashRateValue = 0
                                $HashRateValueDual = 0
                            }

                            #calculates revenue
                            $SubMinerRevenue = [double]($HashRateValue * $Price)
                            $SubMinerRevenueDual = [double]($HashRateValueDual * $PriceDual)

                            #apply fee to revenues
                            $MinerFee = [decimal]$ExecutionContext.InvokeCommand.ExpandString($Miner.Fee)
                            $SubMinerRevenue *= (1 - $MinerFee)

                            if (!$FoundSubMiner) {
                                $Params = @{
                                    Algorithm  = $Algorithms
                                    MinerName  = $MinerFile.BaseName
                                    GroupName  = $DeviceGroup.GroupName
                                    PowerLimit = $PowerLimit
                                    AlgoLabel  = $AlgoLabel
                                }
                                $StatsHistory = Get-Stats @Params
                            } else {
                                $StatsHistory = $FoundSubMiner.StatsHistory
                            }
                            $Stats = [PSCustomObject]@{
                                BestTimes        = 0
                                BenchmarkedTimes = 0
                                LastTimeActive   = [DateTime]0
                                ActivatedTimes   = 0
                                ActiveTime       = [TimeSpan]0
                                FailedTimes      = 0
                                StatsTime        = [TimeSpan]0
                            }
                            if (!$StatsHistory) {$StatsHistory = $Stats}

                            if ($SubMiners.Count -eq 0 -or $SubMiners[0].StatsHistory.BestTimes -gt 0) {
                                #only add a SubMiner (distinct from first if sometime first was best)
                                $SubMiners += [PSCustomObject]@{
                                    Id                     = $SubMiners.Count
                                    Best                   = $false
                                    BestBySwitch           = ""
                                    HashRate               = $HashRateValue
                                    HashRateDual           = $HashRateValueDual
                                    NeedBenchmark          = [bool]($HashRateValue -eq 0 -or ($AlgorithmDual -and $HashRateValueDual -eq 0))
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
                                    SpeedReads             = if ($null -ne $Hrs) {[array]$Hrs} else {@()}
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
                            Arguments           = $ExecutionContext.InvokeCommand.ExpandString($Arguments)
                            BenchmarkArg        = $Miner.BenchmarkArg
                            Coin                = $Pool.Info
                            CoinDual            = $PoolDual.Info
                            ConfigFileArguments = $ExecutionContext.InvokeCommand.ExpandString($ConfigFileArguments)
                            ExtractionPath      = $(".\Bin\" + $MinerFile.BaseName + "\")
                            GenerateConfigFile  = $(if ($PatternConfigFile) {".\Bin\" + $MinerFile.BaseName + "\" + $Miner.GenerateConfigFile -replace '#GroupName#', $DeviceGroup.GroupName -replace '#Algorithm#', $AlgoName})
                            DeviceGroup         = $DeviceGroup
                            Host                = $Pool.Host
                            Location            = $Pool.Location
                            MinerFee            = $MinerFee
                            Name                = $MinerFile.BaseName
                            Path                = $(".\Bin\" + $MinerFile.BaseName + "\" + $ExecutionContext.InvokeCommand.ExpandString($Miner.Path))
                            PoolAbbName         = $Pool.AbbName
                            PoolAbbNameDual     = $PoolDual.AbbName
                            PoolFee             = [double]$Pool.Fee
                            PoolFeeDual         = [double]$PoolDual.Fee
                            PoolName            = $Pool.PoolName
                            PoolNameDual        = $PoolDual.PoolName
                            PoolPrice           = $(if ($MiningMode -eq 'Automatic24h') {[double]$Pool.Price24h} else {[double]$Pool.Price})
                            PoolPriceDual       = $(if ($MiningMode -eq 'Automatic24h') {[double]$PoolDual.Price24h} else {[double]$PoolDual.Price})
                            PoolRewardType      = $Pool.RewardType
                            PoolWorkers         = $Pool.PoolWorkers
                            PoolWorkersDual     = $PoolDual.PoolWorkers
                            Port                = $(if (($DeviceGroups | Where-Object type -eq $DeviceGroup.type).Count -le 1 -and $DelayCloseMiners -eq 0 -and $config.ForceDynamicPorts -ne "Enabled") { $Miner.ApiPort })
                            PrelaunchCommand    = $Miner.PrelaunchCommand
                            SubMiners           = $SubMiners
                            SHA256              = $Miner.SHA256
                            Symbol              = $Pool.Symbol
                            SymbolDual          = $PoolDual.Symbol
                            URI                 = $Miner.URI
                            UserName            = $PoolUser
                            UserNameDual        = $PoolUserDual
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

    Write-Log ("Miners/Pools combinations detected: " + [string]($Miners.Count) + "...") $LogFile $true

    #Launch download of miners
    $Miners |
        Where-Object {
        -not [string]::IsNullOrEmpty($_.URI) -and
        -not [string]::IsNullOrEmpty($_.ExtractionPath) -and
        -not [string]::IsNullOrEmpty($_.Path)} |
        Select-Object URI, ExtractionPath, Path, SHA256 -Unique |
        ForEach-Object {
        if (!(Test-Path $_.Path)) {Start-Downloader -URI $_.URI -ExtractionPath $_.ExtractionPath -Path $_.Path -SHA256 $_.SHA256}
    }

    Send-ErrorsToLog $LogFile

    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {Write-Log "NO MINERS!" $LogFile $true; Exit}

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
            $_.DeviceGroup.Id -eq $ActiveMiner.DeviceGroup.Id -and
            $_.AlgoLabel -eq $ActiveMiner.AlgoLabel }

        if (($Miner | Measure-Object).count -gt 1) {
            Clear-Host
            Write-Log ("DUPLICATED MINER " + $Miner.Algorithms + " in " + $Miner.Name) $LogFile $true
            Exit
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
            $_.DeviceGroup.Id -eq $Miner.DeviceGroup.Id -and
            $_.AlgoLabel -eq $Miner.AlgoLabel}

        if (!$ActiveMiner) {
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
                DeviceGroup         = $Miner.DeviceGroup
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
                UserName            = $Miner.UserName
                UserNameDual        = $Miner.UserNameDual
                WalletMode          = $Miner.WalletMode
                WalletSymbol        = $Miner.WalletSymbol
                WorkerName          = $Miner.WorkerName
                WorkerNameDual      = $Miner.WorkerNameDual
            }
        }
    }

    ## Reset failed miners after 4 hours
    $ActiveMiners.SubMiners | Where-Object {$_.Status -eq 'Cancelled' -and $_.Stats.LastTimeActive -lt (Get-Date).AddHours(-4)} | ForEach-Object {
        $_.Status = 'Idle'
        Write-Log ("Reset failed miner status: $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithms)") $LogFile $true
    }

    Write-Log ("Active Miners-pools: $($ActiveMiners.Count)...") $LogFile $true
    Send-ErrorsToLog $LogFile
    Write-Log ("Pending benchmarks: $(($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty SubMiners | Where-Object NeedBenchmark | Select-Object -ExpandProperty Id).Count)...") $LogFile $true

    if ($DetailedLog) {
        $Msg = $ActiveMiners.SubMiners | ForEach-Object {
            "$($_.IdF)-$($_.Id), " +
            "$($ActiveMiners[$_.IdF].DeviceGroup.GroupName), " +
            "$(if ($ActiveMiners[$_.IdF].IsValid) {'Valid'} else {'Invalid'}), " +
            "PL $($_.PowerLimit), " +
            "$($_.Status), " +
            "$($ActiveMiners[$_.IdF].Name), " +
            "$($ActiveMiners[$_.IdF].Algorithms), " +
            "$($ActiveMiners[$_.IdF].Coin), " +
            "$($ActiveMiners[$_.IdF].Process.Id)`r`n"
        }
        Write-Log $Msg $LogFile $false
    }

    #For each type, select most profitable miner, not benchmarked has priority, new miner is only lauched if new profit is greater than old by percenttoswitch
    #This section changes SubMiner
    foreach ($DeviceGroup in $DeviceGroups) {

        #look for last round best
        $Candidates = $ActiveMiners | Where-Object {$_.DeviceGroup.Id -eq $DeviceGroup.Id}
        $BestLast = $Candidates.SubMiners | Where-Object {$_.Status -in @("Running", "PendingCancellation")}
        if ($null -ne $BestLast) {
            $ProfitLast = $BestLast.Profits
            $BestLastLogMsg = $(
                "$($ActiveMiners[$BestLast.IdF].Name)/" +
                "$($ActiveMiners[$BestLast.IdF].Algorithms)/" +
                "$($ActiveMiners[$BestLast.IdF].Coin)" +
                "$(if ($ActiveMiners[$BestLast.IdF].CoinDual) { '_' + $ActiveMiners[$BestLast.IdF].CoinDual}) " +
                "with Power Limit $($BestLast.PowerLimit) " +
                "(id $($BestLast.IdF)-$($BestLast.Id)) " +
                "for group $($DeviceGroup.GroupName)")
        } else {
            $ProfitLast = 0
        }

        #check if must cancel miner/algo/coin combo
        if ($BestLast.Status -eq 'PendingCancellation') {
            if (($ActiveMiners[$BestLast.IdF].SubMiners.Stats.FailedTimes | Measure-Object -sum).sum -ge 3) {
                $ActiveMiners[$BestLast.IdF].SubMiners | ForEach-Object {$_.Status = 'Cancelled'}
                Write-Log ("Detected more than 3 fails, cancelling combination for $BestNowLogMsg") $LogFile $true
            }
        }

        #look for best for next round
        $Candidates = $ActiveMiners | Where-Object {$_.DeviceGroup.Id -eq $DeviceGroup.Id -and $_.IsValid -and $_.UserName}

        ## Select top miner that need Benchmark, or if running in Manual mode, or highest Profit above zero.
        $BestNow = $Candidates.SubMiners |
            Where-Object Status -ne 'Cancelled' |
            ForEach-Object {if ($_.NeedBenchmark -or $MiningMode -eq "Manual" -or $_.Profits -gt 0) {$_}} |
            Sort-Object -Descending NeedBenchmark, Profits, @{Expression = {$ActiveMiners[$_.IdF].Algorithm}; Ascending = $true}, {$ActiveMiners[$_.IdF].PoolPrice}, {$ActiveMiners[$_.IdF].PoolPriceDual}, PowerLimit |
            Select-Object -First 1

        if ($null -eq $BestNow) {Write-Log ("No detected any valid candidate for device group " + $DeviceGroup.GroupName) $LogFile $true; Continue}

        $BestNowLogMsg = $(
            "$($ActiveMiners[$BestNow.IdF].Name)/" +
            "$($ActiveMiners[$BestNow.IdF].Algorithms)/" +
            "$($ActiveMiners[$BestNow.IdF].Coin)" +
            "$(if ($ActiveMiners[$BestNow.IdF].CoinDual) { '_' + $ActiveMiners[$BestNow.IdF].CoinDual}) " +
            "with Power Limit $($BestNow.PowerLimit) " +
            "(id $($BestNow.IdF)-$($BestNow.Id))"
            "for group $($DeviceGroup.GroupName)")
        $ProfitNow = $BestNow.Profits

        if ($BestNow.NeedBenchmark -eq $false) {
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.BestTimes++
            $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.BestTimes++
        }

        Write-Log ("$BestNowLogMsg is the best combination for device group, last was $BestLastLogMsg") $LogFile $true

        if (
            $BestLast.IdF -ne $BestNow.IdF -or
            $BestLast.Id -ne $BestNow.Id -or
            $BestLast.Status -in @("PendingCancellation", "Cancelled")
        ) {
            #something changes or some miner error

            if (
                $false -and ### Because not all miners live nicely with powerlimit changes during run
                $BestLast.IdF -eq $BestNow.IdF -and
                $BestLast.Id -ne $BestNow.Id
            ) {
                #Must launch other SubMiner
                if ($BestNow.PowerLimit -gt 0) {
                    if ($abControl) {
                        Set-AfterburnerPowerLimit -PowerLimitPercent $BestNow.PowerLimit -DeviceGroup $ActiveMiners[$BestNow.IdF].DeviceGroup
                    } else {
                        if ($ActiveMiners[$BestNow.IdF].DeviceGroup.Type -eq 'NVIDIA') {Set-NvidiaPowerLimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].DeviceGroup.Devices}
                        if ($ActiveMiners[$BestNow.IdF].DeviceGroup.Type -eq 'AMD') {}
                    }
                }

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Best = $true
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Status = "Running"
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.StatsTime = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0

                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $false
                Switch ($BestLast.Status) {
                    "Running" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Idle"}
                    "PendingCancellation" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Failed"}
                    "Cancelled" {$ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Status = "Cancelled"}
                }

                Write-Log ("$BestNowLogMsg - Marked as best, changed Power Limit from $($BestLast.PowerLimit)") $LogFile $true

            } elseif (
                $ProfitNow -gt ($ProfitLast * (1 + ($PercentToSwitch2 / 100))) -or
                $BestNow.NeedBenchmark -or
                $BestLast.Status -in @("Running", "PendingCancellation", "Cancelled") -or
                $null -eq $BestLast -or
                $DonationInterval
            ) {
                #Must launch other miner and stop actual

                #Stop old
                if ($null -ne $BestLast) {

                    Write-Log ("Killing in $DelayCloseMiners seconds $BestLastLogMsg with system process id $($ActiveMiners[$BestLast.IdF].Process.Id)") $LogFile

                    if ($Bestnow.NeedBenchmark -or $DelayCloseMiners -eq 0 -or $BestLast.Status -eq 'PendingCancellation') {
                        #inmediate kill
                        Exit-Process $ActiveMiners[$BestLast.IdF].Process
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
                if ($BestNow.PowerLimit -gt 0) {
                    if ($abControl) {
                        Set-AfterburnerPowerLimit -PowerLimitPercent $BestNow.PowerLimit -DeviceGroup $ActiveMiners[$BestNow.IdF].DeviceGroup
                    } else {
                        if ($ActiveMiners[$BestNow.IdF].DeviceGroup.Type -eq 'NVIDIA') {Set-NvidiaPowerLimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].DeviceGroup.Devices}
                        if ($ActiveMiners[$BestNow.IdF].DeviceGroup.Type -eq 'AMD') {}
                    }
                }

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Best = $true

                if ($null -eq $ActiveMiners[$BestNow.IdF].Port) { $ActiveMiners[$BestNow.IdF].Port = Get-NextFreePort (Get-Random -minimum 2000 -maximum 48000)}
                $ActiveMiners[$BestNow.IdF].Arguments = $ActiveMiners[$BestNow.IdF].Arguments -replace '#APIPort#', $ActiveMiners[$BestNow.IdF].Port

                if ($ActiveMiners[$BestNow.IdF].GenerateConfigFile) {
                    $ActiveMiners[$BestNow.IdF].ConfigFileArguments = $ActiveMiners[$BestNow.IdF].ConfigFileArguments -replace '#APIPort#', $ActiveMiners[$BestNow.IdF].Port
                    $ActiveMiners[$BestNow.IdF].ConfigFileArguments | Set-Content ($ActiveMiners[$BestNow.IdF].GenerateConfigFile)
                }

                if ($ActiveMiners[$BestNow.IdF].PrelaunchCommand) {Start-Process -FilePath $ActiveMiners[$BestNow.IdF].PrelaunchCommand}            #run prelaunch command

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.ActivatedTimes++
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.ActivatedTimes++

                $Arguments = $ActiveMiners[$BestNow.IdF].Arguments
                if ($ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].NeedBenchmark -and $ActiveMiners[$BestNow.IdF].BenchmarkArg) {$Arguments += " " + $ActiveMiners[$BestNow.IdF].BenchmarkArg }

                if ($ActiveMiners[$BestNow.IdF].Api -eq "Wrapper") {
                    $ProcessParams = @{
                        FilePath     = (Get-Process -Id $Global:PID).Path
                        ArgumentList = "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($ActiveMiners[$BestNow.IdF].Port)' -FilePath '$($ActiveMiners[$BestNow.IdF].Path)' -ArgumentList '$($Arguments)' -WorkingDirectory '$(Split-Path $ActiveMiners[$BestNow.IdF].Path)'"
                    }
                } else {
                    $ProcessParams = @{
                        FilePath     = $ActiveMiners[$BestNow.IdF].Path
                        ArgumentList = $Arguments
                    }
                }
                $CommonParams = @{
                    WorkingDirectory = Split-Path $ActiveMiners[$BestNow.IdF].Path
                    MinerWindowStyle = $MinerWindowStyle
                    Priority         = if ($ActiveMiners[$BestNow.IdF].GroupType -eq "CPU") {-2} else {-1}
                }
                $ActiveMiners[$BestNow.IdF].Process = Start-SubProcess @ProcessParams @CommonParams

                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Status = "Running"
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].BestBySwitch = ""
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].Stats.StatsTime = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory.LastTimeActive = Get-Date
                $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0
                Write-Log ("Started System process Id $($ActiveMiners[$BestNow.IdF].Process.Id) for $BestNowLogMsg --> $($ActiveMiners[$BestNow.IdF].Path) $($ActiveMiners[$BestNow.IdF].Arguments)") $LogFile $false

            } else {
                #Must mantain last miner by switch
                $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].Best = $true
                if ($ProfitLast -lt $ProfitNow) {
                    $ActiveMiners[$BestLast.IdF].SubMiners[$BestLast.Id].BestBySwitch = "*"
                    Write-Log ("$BestNowLogMsg Continue mining due to percenttoswitch value") $LogFile $true
                }
            }
        }

        $Params = @{
            Algorithm  = $ActiveMiners[$BestNow.IdF].Algorithms
            MinerName  = $ActiveMiners[$BestNow.IdF].Name
            GroupName  = $ActiveMiners[$BestNow.IdF].DeviceGroup.GroupName
            AlgoLabel  = $ActiveMiners[$BestNow.IdF].AlgoLabel
            PowerLimit = $BestNow.PowerLimit
            Value      = $ActiveMiners[$BestNow.IdF].SubMiners[$BestNow.Id].StatsHistory
        }
        Set-Stats @Params

    }

    if ($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty Subminers | Where-Object {$_.NeedBenchmark -and $_.Status -ne 'Cancelled'}) {$NeedBenchmark = $true} else {$NeedBenchmark = $false}

    if ($DonationInterval) { $NextInterval = $DonateInterval }
    elseif ($NeedBenchmark) { $NextInterval = $BenchmarkIntervalTime }
    else {
        $NextInterval = $ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | Select-Object -ExpandProperty IdF | ForEach-Object {
            $PoolInterval = $Config.("INTERVAL_" + $ActiveMiners[$_].PoolRewardType)
            Write-Log ("Interval for pool " + [string]$ActiveMiners[$_].PoolName + " is " + $PoolInterval) $LogFile $False
            $PoolInterval  # Return value
        } | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum
    }
    Write-Log ("Next interval: " + $NextInterval) $LogFile $true

    $FirstLoopExecution = $true
    $LoopStartTime = Get-Date

    Send-ErrorsToLog $LogFile
    $SwitchLoop = 0
    $ActivityAverages = @()

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

    #loop to update info and check if miner is running, Exit loop is forced inside
    while ($true) {

        $ExitLoop = $false

        $Devices = Get-DevicesInformation $DeviceGroups

        #############################################################

        #Check Live Speed and record benchmark if necessary
        $ActiveMiners.SubMiners | Where-Object Best | ForEach-Object {
            if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.Stats.BenchmarkedTimes++; $_.StatsHistory.BenchmarkedTimes++}
            $_.SpeedLive = 0
            $_.SpeedLiveDual = 0
            $_.ProfitsLive = 0
            $_.RevenueLive = 0
            $_.RevenueLiveDual = 0

            $Miner_HashRates = $null
            $Miner_HashRates = Get-LiveHashRate $ActiveMiners[$_.IdF].API $ActiveMiners[$_.IdF].Port

            if ($Miner_HashRates) {
                $_.SpeedLive = [double]($Miner_HashRates[0])
                $_.SpeedLiveDual = [double]($Miner_HashRates[1])
                $_.RevenueLive = $_.SpeedLive * $ActiveMiners[$_.IdF].PoolPrice
                $_.RevenueLiveDual = $_.SpeedLiveDual * $ActiveMiners[$_.IdF].PoolPriceDual

                $_.PowerLive = ($Devices | Where-Object group -eq ($ActiveMiners[$_.IdF].DeviceGroup.GroupName) | Measure-Object -property PowerDraw -sum).sum

                $_.ProfitsLive = ($_.RevenueLive * (1 - $ActiveMiners[$_.IdF].MinerFee) + $_.RevenueLiveDual) * $LocalBTCvalue
                $_.ProfitsLive -= ($ElectricityCostValue * ($_.PowerLive * 24) / 1000)

                $_.TimeSinceStartInterval = (Get-Date) - $_.Stats.LastTimeActive
                $TimeSinceStartInterval = [int]$_.TimeSinceStartInterval.TotalSeconds

                if (
                    $_.SpeedLive -and
                    ($_.SpeedLiveDual -or !$ActiveMiners[$_.IdF].AlgorithmDual)
                ) {
                    if ($_.Stats.StatsTime) { $_.Stats.ActiveTime += (Get-Date) - $_.Stats.StatsTime }
                    $_.Stats.StatsTime = Get-Date

                    [array]$_.SpeedReads = $_.SpeedReads

                    if ($_.SpeedReads.Count -le 10 -or $_.SpeedLive -le ((($_.SpeedReads | Measure-Object -Property Speed -Average).average) * 100)) {
                        #for avoid miners peaks recording

                        $_.SpeedReads += [PSCustomObject]@{
                            Speed                  = $_.SpeedLive
                            SpeedDual              = $_.SpeedLiveDual
                            Activity               = ($Devices | Where-Object group -eq ($ActiveMiners[$_.IdF].DeviceGroup.GroupName) | Measure-Object -property Utilization -average).average
                            Power                  = $_.PowerLive
                            Date                   = (Get-Date).DateTime
                            Benchmarking           = $_.NeedBenchmark
                            TimeSinceStartInterval = $TimeSinceStartInterval
                            BenchmarkIntervalTime  = $BenchmarkIntervalTime
                        }
                    }
                    if ($_.SpeedReads.Count -gt 2000) {
                        # Remove 10 percent of lowest and highest rate samples which may skew the average
                        $_.SpeedReads = $_.SpeedReads | Sort-Object Speed
                        $p5Index = [math]::Ceiling($_.SpeedReads.Count * 0.05)
                        $p95Index = [math]::Ceiling($_.SpeedReads.Count * 0.95)
                        $_.SpeedReads = $_.SpeedReads[$p5Index..$p95Index] | Sort-Object SpeedDual, Speed
                        $p5Index = [math]::Ceiling($_.SpeedReads.Count * 0.05)
                        $p95Index = [math]::Ceiling($_.SpeedReads.Count * 0.95)
                        $_.SpeedReads = $_.SpeedReads[$p5Index..$p95Index] | Sort-Object Date
                    }

                    if (($Config.LiveStatsUpdate) -eq "ENABLED" -or $_.NeedBenchmark) {

                        if ($_.SpeedReads.Count -gt 20 -and $_.NeedBenchmark) {
                            ### If average of last 2 periods is within SpeedDelta, we can stop benchmarking
                            $SpeedDelta = 0.01
                            $pIndex = [math]::Ceiling($_.SpeedReads.Count * 0.1)

                            $AvgPrev = $_.SpeedReads[($pIndex * 2)..($pIndex * 6)] | Measure-Object -Property Speed -Average | Select-Object -ExpandProperty Average
                            $AvgCurr = $_.SpeedReads[($pIndex * 6)..($_.SpeedReads.count - 1)] | Measure-Object -Property Speed -Average | Select-Object -ExpandProperty Average

                            $AvgPrevDual = $_.SpeedReads[($pIndex * 2)..($pIndex * 6)] | Measure-Object -Property SpeedDual -Average | Select-Object -ExpandProperty Average
                            $AvgCurrDual = $_.SpeedReads[($pIndex * 6)..($_.SpeedReads.count - 1)] | Measure-Object -Property SpeedDual -Average | Select-Object -ExpandProperty Average

                            if (
                                [math]::Abs($AvgPrev / $AvgCurr - 1) -le $SpeedDelta -and
                                ($AvgPrevDual -eq 0 -or [math]::Abs($AvgPrevDual / $AvgCurrDual - 1) -le $SpeedDelta)
                            ) {
                                $_.SpeedReads = $_.SpeedReads[($pIndex * 2)..($_.SpeedReads.count - 1)]
                                $_.NeedBenchmark = $false
                            }
                        }

                        $Params = @{
                            Algorithm  = $ActiveMiners[$_.IdF].Algorithms
                            MinerName  = $ActiveMiners[$_.IdF].Name
                            GroupName  = $ActiveMiners[$_.IdF].DeviceGroup.GroupName
                            AlgoLabel  = $ActiveMiners[$_.IdF].AlgoLabel
                            PowerLimit = $_.PowerLimit
                            Value      = $_.SpeedReads
                        }
                        Set-HashRates @Params

                    }
                }
            }

            #WATCHDOG
            $GroupDevices = @()
            $GroupDevices += $Devices | Where-Object Group -eq $ActiveMiners[$_.IdF].DeviceGroup.GroupName

            $ActivityAverages += [PSCustomObject]@{
                DeviceGroup     = $ActiveMiners[$_.IdF].DeviceGroup.GroupName
                Average         = ($GroupDevices | Measure-Object -property Utilization -average).average
                NumberOfDevices = $GroupDevices.count
            }

            if ($ActivityAverages.count -gt 20) {
                $ActivityAverages = $ActivityAverages[($ActivityAverages.Count - 20)..($ActivityAverages.Count - 1)]
                $ActivityAverage = ($ActivityAverages | Where-Object DeviceGroup -eq $ActiveMiners[$_.IdF].DeviceGroup.GroupName | Measure-Object -property Average -maximum).maximum
                $ActivityDeviceCount = ($ActivityAverages | Where-Object DeviceGroup -eq $ActiveMiners[$_.IdF].DeviceGroup.GroupName | Measure-Object -property NumberOfDevices -maximum).maximum
                if ($DetailedLog) {Write-Log ("Last 20 reads maximum Device activity is $ActivityAverage for DeviceGroup $($ActiveMiners[$_.IdF].DeviceGroup.GroupName)") $LogFile $false}
            } else { $ActivityAverage = 100 } #only want watchdog works with at least 20 reads

            ## HashRate Watchdog
            $WatchdogHashRateFail = $false
            if (
                $Config.WatchdogHashRate -gt 0 -and
                $ActiveMiners[$_.IdF].Algorithm -notin ($Config.WatchdogExcludeAlgos -split ',') -and
                $_.HashRate -gt 0 -and
                $_.SpeedReads.count -gt 20
            ) {
                $AvgCurr = $_.SpeedReads[-10..-1] | Measure-Object -Average -Property Speed | Select-Object -ExpandProperty Average
                $AvgCurrDual = $_.SpeedReads[-10..-1] | Measure-Object -Average -Property SpeedDual | Select-Object -ExpandProperty Average
                if (
                    ($_.HashRate / $AvgCurr - 1) -ge ($Config.WatchdogHashRate / 100) -and
                    (!$_.HashRateDual -or ($_.HashRateDual / $AvgCurrDual - 1) -ge ($Config.WatchdogHashRate / 100))
                ) {
                    # Remove failing SpeedReads from statistics to prevent average skewing
                    $_.SpeedReads = $_.SpeedReads[0..($_.SpeedReads.count - 10)]
                    $WatchdogHashRateFail = $true
                    Write-Log ("Detected low HashRate $($ActiveMiners[$_.IdF].Name)/$($ActiveMiners[$_.IdF].Algorithm) : $(ConvertTo-Hash $AvgCurr) vs $(ConvertTo-Hash $_.HashRate)") $LogFile $false
                }
            }

            if (
                ($Config.WatchdogHashRate -and $WatchdogHashRateFail) -or
                $ActiveMiners[$_.IdF].Process -eq $null -or
                $ActiveMiners[$_.IdF].Process.HasExited -or
                ($ActivityAverage -le 40 -and $TimeSinceStartInterval -gt 100 -and $ActivityDeviceCount -gt 0)
            ) {
                $ExitLoop = $true
                $_.Status = "PendingCancellation"
                $_.Stats.FailedTimes++
                $_.StatsHistory.FailedTimes++
                Write-Log ("Detected miner error " + $ActiveMiners[$_.IdF].Name + "/" + $ActiveMiners[$_.IdF].Algorithm + " (id " + $_.IdF + '-' + $_.Id + ") --> " + $ActiveMiners[$_.IdF].Path + " " + $ActiveMiners[$_.IdF].Arguments) $LogFile $false
                # Write-Log ([string]$ActiveMiners[$_.IdF].Process + ',' + [string]$ActiveMiners[$_.IdF].Process.HasExited + ',' + $ActivityAverage + ',' + $TimeSinceStartInterval) $LogFile $false
            }
        } #End For each

        #############################################################

        if ($NeedBenchmark -and ($ActiveMiners | Where-Object IsValid | Select-Object -ExpandProperty SubMiners | Where-Object {$_.NeedBenchmark -and $_.Best}).Count -eq 0) {
            Write-Log ("Benchmark completed early") $LogFile $false
            $ExitLoop = $true
        }

        #display interval
        $TimeToNextInterval = New-TimeSpan (Get-Date) ($LoopStartTime.AddSeconds($NextInterval))
        $TimeToNextIntervalSeconds = [int]$TimeToNextInterval.TotalSeconds
        if ($TimeToNextIntervalSeconds -lt 0) {$TimeToNextIntervalSeconds = 0}

        Set-ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 31) 2
        " | Next Interval: $TimeToNextIntervalSeconds secs..." | Out-Host
        Set-ConsolePosition 0 0

        #display header
        Print-HorizontalLine "$Application $Release"
        Print-HorizontalLine
        "  (E)nd Interval  (P)rofits  (C)urrent  (H)istory  (W)allets  (S)tats  (Q)uit" | Out-Host

        #display donation message
        if ($DonationInterval) {" THIS INTERVAL YOU ARE DONATING, YOU CAN INCREASE OR DECREASE DONATION ON config.ini, THANK YOU FOR YOUR SUPPORT !!!!"}

        #write speed
        if ($DetailedLog) {Write-Log ($ActiveMiners | Where-Object Best | Select-Object id, process.Id, GroupName, name, poolabbname, Algorithm, AlgorithmDual, SpeedLive, ProfitsLive, location, port, arguments | ConvertTo-Json) $LogFile $false}

        #get pool reported speed (1 or each 10 executions to not saturate pool)
        if ($SwitchLoop -eq 0) {

            # Report stats
            if ($MinerStatusURL -and $MinerStatusKey) { & .\Includes\ReportStatus.ps1 -Key $MinerStatusKey -WorkerName $WorkerName -ActiveMiners $ActiveMiners -MinerStatusURL $MinerStatusURL }

            #To get pool speed
            $PoolsSpeed = @()

            $Candidates = ($ActiveMiners.SubMiners | Where-Object Best | Select-Object IdF).IdF
            $ActiveMiners | Where-Object {$Candidates -contains $_.Id} | Select-Object PoolName, UserName, WalletSymbol, Coin, WorkerName -unique | ForEach-Object {
                $Info = [PSCustomObject]@{
                    User       = $_.UserName
                    PoolName   = $_.PoolName
                    ApiKey     = $Config.("APIKEY_" + $_.PoolName)
                    Symbol     = $_.WalletSymbol
                    Coin       = $_.Coin
                    WorkerName = $_.WorkerName
                }
                $PoolsSpeed += Get-Pools -Querymode "speed" -PoolsFilterList $_.PoolName -Info $Info
            }

            #Dual miners
            $ActiveMiners | Where-Object {$Candidates -contains $_.Id -and $_.PoolNameDual} | Select-Object PoolNameDual, UserNameDual, WalletSymbol, CoinDual, WorkerName -unique | ForEach-Object {
                $Info = [PSCustomObject]@{
                    User       = $_.UserNameDual
                    PoolName   = $_.PoolNameDual
                    ApiKey     = $Config.("APIKEY_" + $_.PoolNameDual)
                    Symbol     = $_.WalletSymbol
                    Coin       = $_.CoinDual
                    WorkerName = $_.WorkerNameDual
                }
                $PoolsSpeed += Get-Pools -Querymode "speed" -PoolsFilterList $_.PoolNameDual -Info $Info
            }

            foreach ($Candidate in $Candidates) {
                $Me = $PoolsSpeed | Where-Object {$_.PoolName -eq $ActiveMiners[$Candidate].PoolName -and $_.WorkerName -eq $ActiveMiners[$Candidate].WorkerName } | Select-Object HashRate, PoolName, WorkerName -first 1
                $ActiveMiners[$Candidate].PoolHashRate = $Me.HashRate

                $MeDual = $PoolsSpeed | Where-Object {$_.PoolName -eq $ActiveMiners[$Candidate].PoolNameDual -and $_.WorkerName -eq $ActiveMiners[$Candidate].WorkerNameDual} | Select-Object HashRate, PoolName, WorkerName -first 1
                $ActiveMiners[$Candidate].PoolHashRateDual = $MeDual.HashRate
            }
        }

        $SwitchLoop++
        if ($SwitchLoop -gt 5) {$SwitchLoop = 0} #reduces 10-1 ratio of execution

        #display current mining info

        Print-HorizontalLine

        $ScreenOut = $ActiveMiners.Subminers |
            Where-Object Best | Sort-Object `
        @{expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq 'CPU'}; Ascending = $true},
        @{expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName}; Ascending = $true} |
            ForEach-Object {
            [PSCustomObject]@{
                GroupName   = $ActiveMiners[$_.IdF].DeviceGroup.GroupName
                PwLim       = if ($_.PowerLimit -gt 0) {$_.PowerLimit} else {""}
                LocalSpeed  = "$(ConvertTo-Hash $_.SpeedLive)" + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) {"/$(ConvertTo-Hash $_.SpeedLiveDual)"})
                mbtcDay     = ((($_.RevenueLive + $_.RevenueLiveDual) * 1000).tostring("n5"))
                RevDay      = ((($_.RevenueLive + $_.RevenueLiveDual) * $localBTCvalue ).tostring("n2"))
                ProfitDay   = (($_.ProfitsLive).tostring("n2"))
                Algorithm   = $ActiveMiners[$_.IdF].Algorithms + $(if ($ActiveMiners[$_.IdF].AlgoLabel) {'|' + $ActiveMiners[$_.IdF].AlgoLabel}) + $_.BestBySwitch
                Coin        = $ActiveMiners[$_.IdF].Symbol + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) {"_$($ActiveMiners[$_.IdF].SymbolDual)"})
                Miner       = $ActiveMiners[$_.IdF].Name
                Power       = [string]$_.PowerLive + 'W'
                EfficiencyH = if (!($ActiveMiners[$_.IdF].AlgorithmDual) -and $_.PowerLive -gt 0) {ConvertTo-Hash ($_.SpeedLive / $_.PowerLive)} else {$null}
                EfficiencyW = if ($_.PowerLive -gt 0) {($_.ProfitsLive / $_.PowerLive).tostring("n4")} else {$null}
                PoolSpeed   = "$(ConvertTo-Hash $ActiveMiners[$_.IdF].PoolHashRate)" + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) {"/$(ConvertTo-Hash $ActiveMiners[$_.IdF].PoolHashRateDual)"})
                Pool        = $ActiveMiners[$_.IdF].PoolAbbName + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) {"|$($ActiveMiners[$_.IdF].PoolAbbNameDual)"})
                Workers     = $ActiveMiners[$_.IdF].PoolWorkers
                Location    = $ActiveMiners[$_.IdF].Location
            }
        }

        $ScreenOut | Format-Table (
            @{Label = "Group"; Expression = {$_.GroupName}},
            @{Label = "Algorithm"; Expression = {$_.Algorithm}},
            @{Label = "Coin"; Expression = {$_.Coin}},
            @{Label = "Miner"; Expression = {$_.Miner}},
            @{Label = "LocalSpeed"; Expression = {$_.LocalSpeed} ; Align = 'right'},
            @{Label = "PwLim"; Expression = {$_.PwLim} ; Align = 'right'},
            @{Label = "Watt"; Expression = {$_.Power} ; Align = 'right'},
            @{Label = "$LocalCurrency/W"; Expression = {$_.EfficiencyW}  ; Align = 'right'},
            @{Label = "mBTC/Day"; Expression = {$_.mbtcDay} ; Align = 'right'},
            @{Label = "$LocalCurrency/Day"; Expression = {$_.RevDay} ; Align = 'right'},
            @{Label = "Profit/Day"; Expression = {$_.ProfitDay} ; Align = 'right'},
            # @{Label = "Hash/W"; Expression = {$_.EfficiencyH} ; Align = 'right'},
            @{Label = "PoolSpeed"; Expression = {$_.PoolSpeed} ; Align = 'right'},
            @{Label = "Pool"; Expression = {$_.Pool} ; Align = 'right'},
            @{Label = "Workers"; Expression = {$_.Workers} ; Align = 'right'},
            @{Label = "Loc."; Expression = {$_.Location} ; Align = 'right'}
        ) | Out-Host

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
            $ApiResponse.Params | Add-Member GroupNames $GroupNames
            $ApiResponse | Add-Member Release $Release
            $ApiResponse | Add-Member RefreshDate ((Get-Date).tostring("o"))
            $ApiResponse | ConvertTo-Json | Set-Content -path $ApiSharedFile
        }

        $XToWrite = [ref]0
        $YToWrite = [ref]0
        Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)
        $YToWriteMessages = $YToWrite + 1
        $YToWriteData = $YToWrite + 2
        Remove-Variable XToWrite
        Remove-Variable YToWrite

        #############################################################
        Print-HorizontalLine $Screen.ToUpper()

        #display profits screen
        if ($Screen -eq "Profits" -and $RepaintScreen) {

            Set-ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 37) $YToWriteMessages
            "(B)est Miners/All  (T)op " + [string]$InitialProfitsScreenLimit + "/All" | Out-Host
            Set-ConsolePosition 0 $YToWriteData

            $ProfitMiners = @()
            if ($ShowBestMinersOnly) {
                foreach ($SubMiner in ($ActiveMiners.SubMiners | Where-Object {$ActiveMiners[$_.IdF].IsValid -and $_.Status -ne "Cancelled"})) {
                    $Candidates = $ActiveMiners |
                        Where-Object {$_.IsValid -and
                        $_.DeviceGroup.Id -eq $ActiveMiners[$SubMiner.IdF].DeviceGroup.Id -and
                        $_.Algorithm -eq $ActiveMiners[$SubMiner.IdF].Algorithm -and
                        $_.AlgorithmDual -eq $ActiveMiners[$SubMiner.IdF].AlgorithmDual }
                    $ExistsBest = $Candidates.SubMiners | Where-Object {$_.Profits -gt $SubMiner.Profits}
                    if ($null -eq $ExistsBest -and 0 -eq $SubMiner.Profits) {
                        $ExistsBest = $Candidates | Where-Object {$_.HashRate -gt $SubMiner.HashRate}
                    }
                    if ($null -eq $ExistsBest -or $true -eq $SubMiner.NeedBenchmark) {
                        $ProfitMiner = $ActiveMiners[$SubMiner.IdF] | Select-Object * -ExcludeProperty SubMiners
                        $ProfitMiner | Add-Member SubMiner $SubMiner
                        $ProfitMiner | Add-Member GroupName $ProfitMiner.DeviceGroup.GroupName #needed for groupby
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
                    $ProfitMiner | Add-Member GroupName $ProfitMiner.DeviceGroup.GroupName #needed for groupby
                    $ProfitMiner | Add-Member NeedBenchmark $ProfitMiner.SubMiner.NeedBenchmark #needed for sort
                    $ProfitMiner | Add-Member Profits $ProfitMiner.SubMiner.Profits #needed for sort
                    $ProfitMiner | Add-Member Status $ProfitMiner.SubMiner.Status #needed for sort
                    $ProfitMiners += $ProfitMiner
                }
            }

            $ProfitMiners2 = @()
            foreach ($DeviceGroupId in $DeviceGroups.Id) {
                $inserted = 1
                $ProfitMiners | Where-Object {$_.DeviceGroup.Id -eq $DeviceGroupId} | Sort-Object -Descending GroupName, NeedBenchmark, Profits | ForEach-Object {
                    if ($inserted -le $ProfitsScreenLimit) {$ProfitMiners2 += $_; $inserted++} #this can be done with Select-Object -first but then memory leak happens, ¿why?
                }
            }

            #Display profits information
            $ProfitMiners2 | Sort-Object `
            @{expression = {$_.GroupName -eq 'CPU'}; Ascending = $true},
            @{expression = "GroupName"; Ascending = $true},
            @{expression = "Status"; Descending = $true},
            @{expression = "NeedBenchmark"; Descending = $true},
            @{expression = "Profits"; Descending = $true} |
                Format-Table (
                @{Label = "Algorithm"; Expression = {$_.Algorithms + $(if ($_.AlgoLabel) {"|$($_.AlgoLabel)"})}},
                @{Label = "Coin"; Expression = {$_.Symbol + $(if ($_.AlgorithmDual) {"_$($_.SymbolDual)"})}},
                @{Label = "Miner"; Expression = {$_.Name}},
                @{Label = "StatsSpeed"; Expression = {if ($_.SubMiner.NeedBenchmark) {"Benchmarking"} else {"$(ConvertTo-Hash $_.SubMiner.HashRate)" + $(if ($_.AlgorithmDual) {"/$(ConvertTo-Hash $_.SubMiner.HashRateDual)"})}}; Align = 'right'},
                @{Label = "PwLim"; Expression = {if ($_.SubMiner.PowerLimit -gt 0) {$_.SubMiner.PowerLimit}}; align = 'right'},
                @{Label = "Watt"; Expression = {if ($_.SubMiner.PowerAvg -gt 0) {$_.SubMiner.PowerAvg.tostring("n0")} else {$null}}; Align = 'right'},
                @{Label = "$LocalCurrency/W"; Expression = {if ($_.SubMiner.PowerAvg -gt 0) {($_.SubMiner.Profits / $_.SubMiner.PowerAvg).tostring("n4")} else {$null} }; Align = 'right'},
                @{Label = "mBTC/Day"; Expression = {if ($_.SubMiner.Revenue) {((($_.SubMiner.Revenue + $_.SubMiner.RevenueDual) * 1000).tostring("n5"))} else {$null}} ; Align = 'right'},
                @{Label = $LocalCurrency + "/Day"; Expression = {if ($_.SubMiner.Revenue) {((($_.SubMiner.Revenue + $_.SubMiner.RevenueDual) * [double]$localBTCvalue).tostring("n2"))} else {$null}} ; Align = 'right'},
                @{Label = "Profit/Day"; Expression = {if ($_.SubMiner.Profits) {($_.SubMiner.Profits).tostring("n2") + " $LocalCurrency"} else {$null}}; Align = 'right'},
                @{Label = "PoolFee"; Expression = {if ($_.PoolFee -gt 0) {"{0:p2}" -f $_.PoolFee}}; Align = 'right'},
                @{Label = "MinerFee"; Expression = {if ($_.MinerFee -gt 0) {"{0:p2}" -f $_.MinerFee}}; Align = 'right'},
                @{Label = "Pool"; Expression = {$_.PoolAbbName + $(if ($_.AlgorithmDual) {"/$($_.PoolAbbNameDual)"})}},
                @{Label = "Loc."; Expression = {$_.Location}}

            ) -GroupBy GroupName | Out-Host
            Remove-Variable ProfitMiners
            Remove-Variable ProfitMiners2

            $RepaintScreen = $false
        }

        if ($Screen -eq "Current") {
            Set-ConsolePosition 0 $YToWriteData

            # Display devices info
            Print-DevicesInformation $Devices
        }

        #############################################################

        if ($Screen -eq "Wallets" -or $FirstTotalExecution) {

            if ($null -eq $WalletsUpdate) {
                #wallets only refresh for manual request

                $WalletsUpdate = Get-Date

                $WalletsToCheck = @()

                $WalletsToCheck += $AllPools |
                    Where-Object {$_.WalletMode -eq 'WALLET' -and $_.User} |
                    Select-Object PoolName, User, WalletMode, WalletSymbol -unique |
                    ForEach-Object {
                    [PSCustomObject]@{
                        PoolName   = $_.PoolName
                        WalletMode = $_.WalletMode
                        User       = $_.User
                        Coin       = $null
                        Algorithm  = $null
                        Symbol     = $_.WalletSymbol
                    }
                }

                $WalletsToCheck += $AllPools |
                    Where-Object {$_.WalletMode -eq 'APIKEY' -and $Config.("APIKEY_" + $_.PoolName)} |
                    Select-Object PoolName, Algorithm, WalletMode, WalletSymbol, @{Name = "ApiKey"; Expression = {$Config.("APIKEY_" + $_.PoolName)}} -unique |
                    ForEach-Object {
                    [PSCustomObject]@{
                        PoolName   = $_.PoolName
                        WalletMode = $_.WalletMode
                        User       = $null
                        Algorithm  = $_.Algorithm
                        Symbol     = $_.WalletSymbol
                        ApiKey     = $_.ApiKey
                    }
                }

                $WalletStatus = @()
                $WalletsToCheck | ForEach-Object {

                    Set-ConsolePosition 0 $YToWriteMessages
                    " " * 70 | Out-Host
                    Set-ConsolePosition 0 $YToWriteMessages

                    if ($_.WalletMode -eq "WALLET") {Write-Log ("Checking " + $_.PoolName + " - " + $_.Symbol) $LogFile $true}
                    else {Write-Log ("Checking " + $_.PoolName + " - " + $_.Symbol + ' (' + $_.Algorithm + ')') $LogFile $true}

                    $Ws = Get-Pools -Querymode $_.WalletMode -PoolsFilterList $_.PoolName -Info ($_)

                    if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                    else {$Ws | Add-Member Wallet $_.Coin}
                    $Ws | Add-Member PoolName $_.PoolName
                    $Ws | Add-Member WalletSymbol $_.Symbol

                    $WalletStatus += $Ws

                } -End {
                    Set-ConsolePosition 0 $YToWriteMessages
                    "                                                                         " | Out-Host
                }

                if (!$WalletStatusAtStart) {$WalletStatusAtStart = $WalletStatus}

                foreach ($Wallet in $WalletStatus) {
                    if (!$Wallet.BalanceAtStart) {
                        $BalanceAtStart = $WalletStatusAtStart | Where-Object {
                            $_.Wallet -eq $Wallet.Wallet -and
                            $_.PoolName -eq $Wallet.PoolName -and
                            $_.Currency -eq $Wallet.Currency
                        } | Select-Object -ExpandProperty Balance

                        if ($BalanceAtStart) {
                            $Wallet | Add-Member BalanceAtStart $BalanceAtStart
                        } else {
                            $WalletStatusAtStart += $Wallet
                        }
                    }
                }
            }

            if ($Screen -eq "Wallets" -and $RepaintScreen) {

                Set-ConsolePosition 0 $YToWriteMessages
                "Start Time: $StartTime                               "
                Set-ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 10) $YToWriteMessages
                "(U)pdate" | Out-Host
                "" | Out-Host

                $WalletStatus | Where-Object Balance |
                    Sort-Object @{expression = "PoolName"; Ascending = $true}, @{expression = "balance"; Descending = $true} |
                    Format-Table -Wrap -groupby PoolName (
                    @{Label = "Coin"; Expression = {if ($_.WalletSymbol -ne $null) {$_.WalletSymbol} else {$_.wallet}}},
                    @{Label = "Balance"; Expression = {$_.Balance.tostring("n5")}; Align = 'right'},
                    @{Label = "IncFromStart"; Expression = {($_.Balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                ) | Out-Host

                $Pools | Where-Object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                    "NO API FOR POOL " + $_.PoolName + " - NO WALLETS CHECK" | Out-Host
                }
                $RepaintScreen = $false
            }
        }

        #############################################################
        if ($Screen -eq "History" -and $RepaintScreen) {

            Set-ConsolePosition 0 $YToWriteMessages
            "Running Mode: $MiningMode" | Out-Host

            Set-ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners.SubMiners |
                Where-Object {$_.Stats.ActivatedTimes -gt 0} | Sort-Object `
            @{expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq 'CPU'}; Ascending = $true},
            @{expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName}; Ascending = $true},
            @{expression = {$_.Stats.LastTimeActive}; Descending = $true} |
                Format-Table -Wrap -GroupBy @{Label = "Group"; Expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName}} (
                @{Label = "LastTimeActive"; Expression = {$($_.Stats.LastTimeActive).tostring("dd/MM/yy H:mm")}},
                @{Label = "Command"; Expression = {"$($ActiveMiners[$_.IdF].Path.TrimStart((Convert-Path ".\Bin\"))) $($ActiveMiners[$_.IdF].Arguments)"}}
            ) | Out-Host
            $RepaintScreen = $false
        }

        #############################################################

        if ($Screen -eq "Stats" -and $RepaintScreen) {
            Set-ConsolePosition 0 $YToWriteMessages
            "Start Time: $StartTime"

            Set-ConsolePosition ($Host.UI.RawUI.WindowSize.Width - 30) $YToWriteMessages

            "Running Mode: $MiningMode" | Out-Host

            Set-ConsolePosition 0 $YToWriteData

            #Display activated miners list
            $ActiveMiners.SubMiners |
                Where-Object {$_.Stats.ActivatedTimes -gt 0} |
                Sort-Object `
            @{expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName -eq 'CPU'}; Ascending = $true},
            @{expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName}; Ascending = $true},
            @{expression = {$_.Stats.Activetime.TotalMinutes}; Descending = $true} |
                Format-Table -Wrap -GroupBy @{Label = "Group"; Expression = {$ActiveMiners[$_.IdF].DeviceGroup.GroupName}}(
                @{Label = "Algorithm"; Expression = {$ActiveMiners[$_.IdF].Algorithms + $(if ($ActiveMiners[$_.IdF].AlgoLabel) {"|$($ActiveMiners[$_.IdF].AlgoLabel)"})}},
                @{Label = "Coin"; Expression = {$ActiveMiners[$_.IdF].Symbol + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) {"_$($ActiveMiners[$_.IdF].SymbolDual)"})}},
                @{Label = "Pool"; Expression = {$ActiveMiners[$_.IdF].PoolAbbName + $(if ($ActiveMiners[$_.IdF].AlgorithmDual) {"/$($ActiveMiners[$_.IdF].PoolAbbNameDual)"})}},
                @{Label = "Miner"; Expression = {$ActiveMiners[$_.IdF].Name}},
                @{Label = "PwLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}},
                @{Label = "Launch"; Expression = {$_.Stats.ActivatedTimes}},
                @{Label = "Best"; Expression = {$_.Stats.BestTimes}},
                @{Label = "ActiveTime"; Expression = {if ($_.Stats.ActiveTime.TotalMinutes -le 60) {"{0:N1} min" -f ($_.Stats.ActiveTime.TotalMinutes)} else {"{0:N1} hours" -f ($_.Stats.ActiveTime.TotalHours)}}},
                @{Label = "LastTimeActive"; Expression = {$($_.Stats.LastTimeActive).tostring("dd/MM/yy H:mm")}},
                @{Label = "Status"; Expression = {$_.Status}}
            ) | Out-Host
        }

        $FirstLoopExecution = $false

        #Loop for reading key and wait

        $KeyPressed = Read-KeyboardTimed 3 ('P', 'C', 'H', 'E', 'W', 'U', 'T', 'B', 'S', 'X', 'Q')

        switch ($KeyPressed) {
            'P' {$Screen = 'PROFITS'}
            'C' {$Screen = 'CURRENT'}
            'H' {$Screen = 'HISTORY'}
            'S' {$Screen = 'STATS'}
            'E' {$ExitLoop = $true; Write-Log "Forced end of interval by E key" $LogFile $false}
            'W' {$Screen = 'WALLETS'}
            'U' {if ($Screen -eq "WALLETS") {$WalletsUpdate = $null}}
            'T' {if ($Screen -eq "PROFITS") {if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) {$ProfitsScreenLimit = 1000} else {$ProfitsScreenLimit = $InitialProfitsScreenLimit}}}
            'B' {if ($Screen -eq "PROFITS") {$ShowBestMinersOnly = !$ShowBestMinersOnly}}
            'X' {try {Set-WindowSize 180 50} catch {}}
            'Q' {$Quit = $true; $ExitLoop = $true}
        }

        if ($KeyPressed) {Clear-Host; $RepaintScreen = $true}

        if (((Get-Date) -ge ($LoopStartTime.AddSeconds($NextInterval))) ) {
            #If time of interval has over, Exit of main loop
            #If last interval was benchmark and no speed detected mark as failed
            $ActiveMiners.SubMiners | Where-Object Best | ForEach-Object {
                if ($_.NeedBenchmark -and $_.SpeedReads.Count -eq 0) {
                    $_.Status = 'PendingCancellation'
                    Write-Log ("No speed detected while benchmark " + $ActiveMiners[$_.IdF].Name + "/" + $ActiveMiners[$_.IdF].Algorithm + " (id " + $ActiveMiners[$_.IdF].Id + ")") $LogFile $false
                }
            }
            $ExitLoop = $true
            Write-Log "Interval ends by time -- $NextInterval"  $LogFile $false
        }

        if ($ExitLoop) {break} #forced Exit

        Send-ErrorsToLog $LogFile
    }

    Remove-Variable miners
    Remove-Variable pools
    Get-Job -State Completed | Remove-Job
    [GC]::Collect() #force garbage collector for free memory
    $FirstTotalExecution = $false
}

#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of always running loop--------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------

Write-Log "Exiting Forager...." $LogFile $true
$LogFile.close()
Clear-Files
$ActiveMiners | Where-Object Process -ne $null | ForEach-Object {try {Exit-Process $_.Process} catch {}}
try {Invoke-WebRequest ("http://localhost:$($config.ApiPort)/?command=Exit") -timeoutsec 1 -UseDefaultCredentials} catch {}

if ($EthPill -ne $null) {Stop-Process -Id $EthPill.Id}
Stop-Process -Id $PID
