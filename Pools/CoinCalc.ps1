<#
THIS IS A ADVANCED POOL, NOT FOR NOOB.

THIS IS A VIRTUAL POOL, STATISTICS ARE TAKEN FROM WHATTOMINE AND RECALCULATED WITH YOUR BENCHMARKS HashRate, YOU CAN SET DESTINATION POOL YOU WANT FOR EACH COIN, BUT REMEMBER YOU MUST HAVE AND ACOUNT IF DESTINATION POOL IS NOT ANONYMOUS POOL
#>

param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

# . .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "MIXED"
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Based on CoinCalculator statistics, you must have accounts and wallets for each coin in config.ini"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = 'CC'
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if (($Querymode -eq "Speed")) {
    if ($PoolRealName -ne $null) {
        $Info.PoolName = $PoolRealName
        $Result = Get-Pools -Querymode "Speed" -PoolsFilterList $Info.PoolName -Info $Info
    }
}

if (($Querymode -eq "Wallet") -or ($Querymode -eq "APIKey")) {
    if ($PoolRealName -ne $null) {
        $Info.PoolName = $PoolRealName
        $Result = Get-Pools -Querymode $info.WalletMode -PoolsFilterList $Info.PoolName -Info $Info | select-object Pool, Currency, Balance
    }
}

if ($Querymode -in @("Core", "Menu")) {

    #Look for pools
    $ConfigOrder = (Get-ConfigVariable "CoinCalcPoolOrder") -split ','
    $Pools = foreach ($PoolToSearch in $ConfigOrder) {
        $PoolsTmp = Get-Pools -Querymode "Core" -PoolsFilterList $PoolToSearch -location $Info.Location
        #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
        $PoolsTmp | Where-Object {[string]::IsNullOrEmpty($_.PoolWorkers) -or $_.PoolWorkers -ge (Get-ConfigVariable "MinWorkers")}
    }

    $Url = "https://www.coincalculators.io/api/allcoins.aspx?hashrate=1000&difficultytime=0"
    # $Response = Get-Content .\WIP\CoinCalculators.json | ConvertFrom-Json
    $Response = Invoke-APIRequest -Url $Url -Age 10     ### Requests limited to 500 per day from a single IP
    if (-not $Response) {
        Write-Warning "$Name API NOT RESPONDING...ABORTING"
        Exit
    }
    foreach ($Coin in $Response) {
        $Coin.Name = Get-CoinUnifiedName $Coin.Name
        $Coin.Algorithm = Get-AlgoUnifiedName $Coin.Algorithm

        # Algo fixes
        switch ($Coin.Name) {
            'Stellite' {$Coin.Algorithm = 'CryptoNightXTL'}
            'BitcoinZ' {$Coin.Algorithm = 'Zhash'}
        }
    }

    #join pools and coins
    ForEach ($Pool in $Pools) {

        $Pool.Algorithm = Get-AlgoUnifiedName $Pool.Algorithm
        $Pool.Info = Get-CoinUnifiedName $Pool.Info

        if (($Result | Where-Object {$_.Info -eq $Pool.Info -and $_.Algorithm -eq $Pool.Algorithm}).count -eq 0) {
            #look that this coin is not included in result

            $Response | Where-Object {$_.Name -eq $Pool.Info -and $_.Algorithm -eq $Pool.Algorithm} | ForEach-Object {
                $Result += [PSCustomObject]@{
                    Info                  = $Pool.Info
                    Algorithm             = $Pool.Algorithm
                    Price                 = [decimal]($_.rewardsInDay * $_.price_btc / $_.yourHashrate)
                    Price24h              = [decimal]($_.rewardsInDay * $_.price_btc / $_.currentDifficulty * $_.difficulty24 / $_.yourHashrate)
                    Symbol                = $_.Symbol
                    Host                  = $Pool.Host
                    HostSSL               = $Pool.HostSSL
                    Port                  = $Pool.Port
                    PortSSL               = $Pool.PortSSL
                    Location              = $Pool.Location
                    SSL                   = $Pool.SSL
                    Fee                   = $Pool.Fee
                    User                  = $Pool.User
                    Pass                  = $Pool.Pass
                    Protocol              = $Pool.Protocol
                    ProtocolSSL           = $Pool.ProtocolSSL
                    AbbName               = "CC-" + $Pool.AbbName
                    WalletMode            = $Pool.WalletMode
                    EthStMode             = $Pool.EthStMode
                    WalletSymbol          = $Pool.WalletSymbol
                    PoolName              = $Pool.PoolName
                    PoolWorkers           = $Pool.PoolWorkers
                    PoolHashRate          = $Pool.PoolHashRate
                    RewardType            = $Pool.RewardType
                    ActiveOnManualMode    = $ActiveOnManualMode
                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                }
            }
        }
    } #end foreach pool
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
