<#
THIS IS A ADVANCED POOL, NOT FOR NOOB.

THIS IS A VIRTUAL POOL, STATISTICS ARE TAKEN FROM WHATTOMINE AND RECALCULATED WITH YOUR BENCHMARKS HASHRATE, YOU CAN SET DESTINATION POOL YOU WANT FOR EACH COIN, BUT REMEMBER YOU MUST HAVE AND ACOUNT IF DESTINATION POOL IS NOT ANONYMOUS POOL
#>



param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)


# . .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "MIXED"
$RewardType = "PPS"
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Based on WhatToMine statistics, you must have account on Suprnova a wallets for each coin on config.txt "
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = 'WTM'
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if (($Querymode -eq "speed") ) {
    if ($PoolRealName -ne $null) {
        $Info.poolname = $PoolRealName
        $result = Get_Pools -Querymode "speed" -PoolsFilterList $Info.poolname -Info $Info
    }
}


if (($Querymode -eq "wallet") -or ($Querymode -eq "APIKEY")) {
    if ($PoolRealName -ne $null) {
        $Info.poolname = $PoolRealName
        $result = Get_Pools -Querymode $info.WalletMode -PoolsFilterList $Info.PoolName -Info $Info |
            select-object Pool, currency, balance
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    #Data from WTM
    try {
        $http = "https://whattomine.com/coins.json"
        $WTMResponse = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json | Select-Object -ExpandProperty coins
    } catch { Write-Host $Name 'API NOT RESPONDING...' }

    $CustomCoins = (get_config_variable "WhatToMineCustomCoins")
    if (![string]::IsNullOrWhiteSpace($CustomCoins)) {
        WriteLog "Custom WTM Coins: $CustomCoins" $LogFile $True
        foreach ($c in $CustomCoins.Split(',')) {
            try {
                $http = "http://whattomine.com/coins/$($c.Trim()).json"
                $WTMCoinResponse = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
                if (![string]::IsNullOrEmpty($WTMCoinResponse)) {
                    try { $WTMResponse | Add-Member $WTMCoinResponse.Name $WTMCoinResponse }
                    catch { $WTMResponse | Add-Member $($WTMCoinResponse.Name + "-" + $WTMCoinResponse.Algorithm) $WTMCoinResponse }
                    Remove-Variable WTMCoinResponse

                }
            } catch { Write-Host $Name 'COIN API NOT RESPONDING...' }
            Start-Sleep -Seconds 1 # Prevent API Saturation
        }
    }

    #search on pools where to mine coins, order is determined by config.txt @@WhatToMinePoolOrder variable
    $ConfigOrder = (get_config_variable "WhatToMinePoolOrder") -split ','
    $MinWorkers = [int](get_config_variable "MinWorkers")
    foreach ($PoolToSearch in $ConfigOrder) {

        $HPools = Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location
        #Filter by MinWorkers variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
        $HPools = $HPools | Where-Object {$_.PoolWorkers -ge $MinWorkers -or $_.PoolWorkers -eq $null}

        ForEach ($WtmCoinName in $WTMResponse.PSObject.Properties.Name) {

            $Algorithm = get_algo_unified_name ($WTMResponse.($WtmCoinName).Algorithm)
            $Coin = get_coin_unified_name $WtmCoinName

            #search if this coin was added before
            if (($Result | where-object { $_.Info -eq $Coin -and $_.Algorithm -eq $Algorithm}).count -eq 0) {
                foreach ($HPool in $($HPools | where-object { $_.Info -eq $coin -and $_.Algorithm -eq $Algorithm})) {
                    #Search if each pool has coin correspondence in WTM

                    $WTMFactor = get_WhatToMineFactor ($HPool.Algorithm)

                    if ($WTMFactor -ne $null) {
                        $Result += [PSCustomObject]@{
                            Info                  = $HPool.Info
                            Algorithm             = $HPool.Algorithm
                            Price                 = [Double]($WTMResponse.($WtmCoinName).btc_revenue / $WTMFactor)
                            Price24h              = [Double]($WTMResponse.($WtmCoinName).btc_revenue24 / $WTMFactor)
                            Symbol                = $WTMResponse.($WtmCoinName).tag
                            Host                  = $HPool.Host
                            HostSSL               = $HPool.HostSSL
                            Port                  = $HPool.Port
                            PortSSL               = $HPool.PortSSL
                            Location              = $HPool.Location
                            SSL                   = $HPool.SSL
                            Fee                   = $HPool.Fee
                            User                  = $HPool.User
                            Pass                  = $HPool.Pass
                            Protocol              = $HPool.Protocol
                            ProtocolSSL           = $HPool.ProtocolSSL
                            AbbName               = "W-" + $HPool.AbbName
                            WalletMode            = $HPool.WalletMode
                            EthStMode             = $HPool.EthStMode
                            WalletSymbol          = $HPool.WalletSymbol
                            PoolName              = $HPool.PoolName
                            RewardType            = $HPool.RewardType
                            ActiveOnManualMode    = $ActiveOnManualMode
                            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                        }
                    } else {
                        Out-Host "Missing WTF Factor for $WtmCoinName"
                    }
                }
            }
        } #end foreach coin
    }  #end for each PoolToSearch
    remove-variable WTMResponse
    remove-variable HPools
}

$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
