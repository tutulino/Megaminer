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
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Based on Whattomine statistics, you must have acount on Suprnova a wallets for each coin on config.txt "
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = 'WTM'
        WalletMode               = $WalletMode
    }
}


if (($Querymode -eq "wallet") -or ($Querymode -eq "APIKEY")) {
    if ($PoolRealName -ne $null) {
        $Info.poolname = $PoolRealName
        $result = Get-Pools -Querymode $info.WalletMode -PoolsFilterList $Info.PoolName -Info $Info   | select-object Pool, currency, balance
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $Pools = @()

    #Manual Pools zone (you cand add your pools here - wallet for that coins must exists on config.txt)
    #$Pools +=[pscustomobject]@{"coin" = "PIRL";"algo"="Ethash"; "symbol"= "PIRL";"server"="pirl.minerpool.net"; "port"= "8004";"location"="US";"User"="XXX";"Pass" = "YYY";"fee"="0";"Abbname"="MinerP";"WalletMode"="NONE"}

    #Data from WTM
    $retries = 1
    do {
        try {
            $http = "https://whattomine.com/coins.json"
            $Response = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5
            If ($Response.StatusCode -eq 200) {
                $Response.Content | Set-Content .\Cache\wtm-coins.json
                $WTMResponse = $Response.Content | ConvertFrom-Json | Select-Object -ExpandProperty coins
            }
        } catch {start-sleep 2}
        $retries++
        if ($WTMResponse -eq $null -or $WTMResponse -eq "") {start-sleep 3}
    } while ($WTMResponse -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...USING CACHE'
        try { $WTMResponse = (Get-Content -Path ".\Cache\wtm-coins.json") | ConvertFrom-Json | Select-Object -ExpandProperty coins } catch { Write-Host "No Cache. Exiting"; Exit}
    }

    $WTMResponse.psobject.properties.name | ForEach-Object {

        $WTMResponse.($_).Algorithm = get-algo-unified-name ($WTMResponse.($_).Algorithm)

        #not necessary delete bad names/algo, only necessary add correct name/algo
        $NewCoinName = get-coin-unified-name $_
        if ($NewCoinName -ne $_) {
            $TempCoin = $WTMResponse.($_)
            $WTMResponse |add-member $NewCoinName $TempCoin
        }
    }

    try {$CustomCoins = (Get-Content config.txt | Where-Object {$_ -like '@@CUSTOM_WTM_COINS=*'}) -replace '@@CUSTOM_WTM_COINS=', '' -split ','} catch {$CustomCoins = @()}
    foreach ($c in $CustomCoins) {
        $retries = 1
        do {
            try {
                $http = "http://whattomine.com/coins/$c.json"
                $Response = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5
                If ($Response.StatusCode -eq 200) {
                    $Response.Content | Set-Content ".\Cache\wtm-$c.json"
                    $WTMCoinResponse = $Response.Content | ConvertFrom-Json
                }
            } catch {start-sleep 2}
            $retries++
            if ($WTMCoinResponse -eq $null -or $WTMCoinResponse -eq "") {start-sleep 3}
        } while ($WTMCoinResponse -eq $null -and $retries -le 3)
        if ($retries -gt 3) {
            Write-Host $Name 'COIN API NOT RESPONDING...USING CACHE'
            try { $WTMCoinResponse = (Get-Content -Path ".\Cache\wtm-$c.json") | ConvertFrom-Json } catch { Write-Host "No Cache. Skipping" }
        }

        $WTMCoinResponse.algorithm = get-algo-unified-name ($WTMCoinResponse.algorithm)
        #not necessary delete bad names/algo, only necessary add correct name/algo
        $NewCoinName = get-coin-unified-name $WTMCoinResponse.name
        if ($NewCoinName -ne $WTMCoinResponse.name) {
            $TempCoin = $WTMCoinResponse
            $WTMCoinResponse | add-member $NewCoinName $TempCoin
        }
        try { $WTMResponse | Add-Member $NewCoinName $WTMCoinResponse } catch {}
        remove-variable WTMCoinResponse

    }

    #search on pools where to mine coins, switch sentence determines order to look, if one pool has one coin, no more pools for that coin are searched after.

    $PoolsList = @(
        'Mining_Pool_Hub_Coins'
        'Suprnova'
        'FairPool'
        'MyPools'
        'YIIMP'
    )
    foreach ($Pool in $PoolsList) {

        $HPools = Get-Pools -Querymode "core" -PoolsFilterList $Pool -location $Info.Location

        $HPools | ForEach-Object {

            $WTMcoin = $WTMResponse.($_.Info)

            if (($WTMcoin.Algorithm -eq $_.Algorithm) -and (($Pools | where-object coin -eq $_.info |where-object Algo -eq $_.Algorithm) -eq $null)) {
                $Pools += [pscustomobject]@{
                    coin              = $_.Info
                    algo              = $_.Algorithm
                    symbol            = $WTMResponse.($_.Info).tag
                    server            = $_.host
                    port              = $_.port
                    location          = $_.location
                    Fee               = $_.Fee
                    User              = $_.User
                    Pass              = $_.Pass
                    protocol          = $_.Protocol
                    Abbname           = $_.Abbname
                    WalletMode        = $_.WalletMode
                    WalletSymbol      = $_.WalletSymbol
                    PoolName          = $_.PoolName
                    OriginalAlgorithm = $_.OriginalAlgorithm
                    OriginalCoin      = $_.OriginalCoin
                }
            }
        }
    }

    #add estimation data to selected pools

    $Pools |ForEach-Object {
        $WTMFactor = get-WhattomineFactor ($_.Algo)
        if ($WTMFactor -ne $null) {
            $Estimate = [Double]($WTMResponse.($_.coin).btc_revenue / $WTMFactor)
            $Estimate24h = [Double]($WTMResponse.($_.coin).btc_revenue24 / $WTMFactor)
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Price                 = $Estimate * 0.95
            Price24h              = $Estimate24h * 0.95
            Protocol              = $_.Protocol
            Host                  = $_.Server
            Port                  = $_.Port
            User                  = $_.User
            Pass                  = $_.Pass
            Location              = $_.Location
            SSL                   = $false
            Symbol                = $_.symbol
            AbbName               = "WTM-" + $_.Abbname
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $_.PoolName
            WalletMode            = $_.WalletMode
            OriginalAlgorithm     = $_.OriginalAlgorithm
            OriginalCoin          = $_.OriginalCoin
            Fee                   = $_.Fee
        }
    }
    remove-variable WTMResponse
    remove-variable Response
    remove-variable Pools
    remove-variable PoolsList
    remove-variable WTMcoin
    remove-variable HPools
}

$Result |ConvertTo-Json | Set-Content ("$name.tmp")
remove-variable Result
