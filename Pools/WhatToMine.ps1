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
        $Info.PoolName = $PoolRealName
        $Result = Get_Pools -Querymode "speed" -PoolsFilterList $Info.PoolName -Info $Info
    }
}


if (($Querymode -eq "wallet") -or ($Querymode -eq "APIKEY")) {
    if ($PoolRealName -ne $null) {
        $Info.PoolName = $PoolRealName
        $Result = Get_Pools -Querymode $info.WalletMode -PoolsFilterList $Info.PoolName -Info $Info | select-object Pool, currency, balance
    }
}


if ($Querymode -eq "core" -or $Querymode -eq "Menu") {

    #Look for pools
    $ConfigOrder = (get_config_variable "WHATTOMINEPOOLORDER") -split ','
    $HPools = foreach ($PoolToSearch in $ConfigOrder) {
        $HPoolsTmp = Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location
        #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
        $HPoolsTmp | Where-Object {$_.Poolworkers -ge (get_config_variable "MINWORKERS") -or $_.Poolworkers -eq $null}
    }

    #Common Data from WTM

    #Add main page coins
    $WTMResponse = Invoke_APIRequest -Url 'https://whattomine.com/coins.json' -Retry 3 | Select-Object -ExpandProperty coins
    if (!$WTMResponse) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }
    $WTMCoins = $WTMResponse.PSObject.Properties.Name | ForEach-Object {
        #convert response to collection
        $res = $WTMResponse.($_)
        $res | Add-Member name (get_coin_unified_name $_)
        $res.Algorithm = get_algo_unified_name ($res.Algorithm)
        $res
    }
    Remove-Variable WTMResponse

    #Add secondary page coins
    $WTMResponse = Invoke_APIRequest -Url 'https://whattomine.com/calculators.json' -Retry 3 | Select-Object -ExpandProperty coins
    $WTMSecondaryCoins = $WTMResponse.PSObject.Properties.Name | ForEach-Object {
        #convert response to collection
        $res = $WTMResponse.($_)
        $res | Add-Member name (get_coin_unified_name $_)
        $res.Algorithm = get_algo_unified_name ($res.Algorithm)
        if ($res.Status -eq "Active") {$res}
    }
    Remove-Variable WTMResponse


    #join pools and coins
    ForEach ($HPool in $HPools) {

        $HPool.Algorithm = get_algo_unified_name $HPool.Algorithm
        $HPool.Info = get_coin_unified_name $HPool.Info

        #we must add units for each algo, this value must be filled if we want a coin to be selected
        $WTMFactor = switch ($HPool.Algorithm) {
            #main page
            "Ethash" { 84000000 }
            "Sib" { 20100000 }
            "CryptoNight" { 2190 }
            "Equihash" { 870 }
            "Lyra2v2" { 14700000 }
            "NeoScrypt" { 2460000 }
            "Skunk" { 54000000 }
            "Nist5" { 57000000 }

            #others
            "Bitcore" { 30000000 }
            "Blake2s" { 7500000000 }
            "CryptoLight" { 6600 }
            "Keccak" { 900000000 }
            "KeccakC" { 240000000 }
            "Lyra2z" { 420000 }
            "X17" { 100000 }
            "Xevan" { 4800000 }
            "Yescrypt" { 13080 }
            "Zero" { 18 }
            default {$null}
        }

        if (($Result | Where-Object { $_.Info -eq $HPool.Info -and $_.Algorithm -eq $HPool.Algorithm}).count -eq 0 -and $WTMFactor) {
            #look that this coin is not included in result

            #look for this coin in main page coins
            $WtmCoin = $WTMCoins | Where-Object {
                $_.Name -eq $HPool.Info -and
                $_.Algorithm -eq $HPool.Algorithm
            }

            if (!$WtmCoin) {
                #look in secondary coins page
                $WtmSecCoin = $WTMSecondaryCoins | Where-Object {
                    $_.Name -eq $HPool.Info -and
                    $_.Algorithm -eq $HPool.Algorithm
                }
                if ($WtmSecCoin) {
                    $WtmCoin = Invoke_APIRequest -Url $('https://whattomine.com/coins/' + $WtmSecCoin.Id + '.json') -Retry 3
                    if ($WtmCoin) {$WtmCoin | Add-Member btc_revenue24 $WtmCoin.btc_revenue}
                }
            }
            if ($WtmCoin -ne $null) {
                $Result += [PSCustomObject]@{
                    Info                  = $HPool.Info
                    Algorithm             = $HPool.Algorithm
                    Price                 = [decimal]$WtmCoin.btc_revenue / $WTMFactor
                    Price24h              = [decimal]$WtmCoin.btc_revenue24 / $WTMFactor
                    Symbol                = $WtmCoin.Tag
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
                    PoolWorkers           = $HPool.PoolWorkers
                    PoolHashRate          = $HPool.PoolHashRate
                    RewardType            = $HPool.RewardType
                    ActiveOnManualMode    = $ActiveOnManualMode
                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                }
            }
        }
    } #end foreach pool
    Remove-Variable HPools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
