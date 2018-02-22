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


if ($Querymode -eq "core" -or $Querymode -eq "Menu") {

    #Data from WTM
    $WTMResponse2 = @()

    #Add main page coins
    try {$WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins} catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING'; EXIT}
    $WTMResponse.PSObject.properties.name | ForEach-Object {

        $res = $WTMResponse.($_)
        $res | Add-Member name $_
        $WTMResponse2 += $res
    }

    try {$WTMResponse = Invoke-WebRequest "https://whattomine.com/calculators.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins } catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING'; EXIT}

    #Add secondary page coins

    $counter=0
    $WTMResponse.PSObject.properties.name | ForEach-Object {

        if ($WTMResponse.($_).status -eq "Active" -and $WTMResponse.($_).listed -eq $false -and $WTMResponse.($_).lagging -eq $false) {
            $Id = $WTMResponse.($_).Id
            $exists = $WTMResponse2 | Where-Object id -eq $Id
            if ($exists.count -eq 0) {
                $page = "https://whattomine.com/coins/" + $WTMResponse.($_).Id + ".json"
                try {$WTMResponse2 += Invoke-WebRequest $page -UseBasicParsing -timeoutsec 2 | ConvertFrom-Json  } catch {}
            }
            $counter++
            # WTM limits to 80 requests per minute. Sleep to prevent API saturation
            if ($counter -gt 70) {
                Write-Host "WTM must sleep sleep to prevent API saturation"
                Start-Sleep -Seconds 60
                $counter = 0
            }
        }
    }

    #search on pools where to mine coins, order is determined by config.txt @@WhatToMinePoolOrder variable
    $ConfigOrder = (get_config_variable "WhatToMinePoolOrder") -split ','
    $MinWorkers = [int](get_config_variable "MinWorkers")
    foreach ($PoolToSearch in $ConfigOrder) {

        $HPools = Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location
        #Filter by MinWorkers variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
        $HPools = $HPools | Where-Object {$_.PoolWorkers -ge $MinWorkers -or $_.PoolWorkers -eq $null}

        ForEach ($WtmCoinName in $WTMResponse2) {

            $Algorithm = get_algo_unified_name $WtmCoinName.algorithm
            $Coin = get_coin_unified_name $WtmCoinName.name

            #search if this coin was added before
            if (($Result | where-object { $_.Info -eq $Coin -and $_.Algorithm -eq $Algorithm}).count -eq 0) {
                foreach ($HPool in $($HPools | where-object { $_.Info -eq $coin -and $_.Algorithm -eq $Algorithm})) {
                    #Search if each pool has coin correspondence in WTM

                    $WTMFactor = get_WhattomineFactor $Algorithm

                    if ($WTMFactor -ne $null) {
                        $Result += [PSCustomObject]@{
                            Info                  = $Coin
                            Algorithm             = $Algorithm
                            Price                 = [Double]($WtmCoinName.btc_revenue / $WTMFactor)
                            Price24h              = [Double]($WtmCoinName.btc_revenue24 / $WTMFactor)
                            symbol                = $WtmCoinName.tag
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
                        Write-Host "Missing WTF Factor for $WtmCoinName"
                    }
                }
            }
        } #end foreach coin
    }  #end for each PoolToSearch
    remove-variable WTMResponse
    remove-variable HPools
}

$Result | ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
