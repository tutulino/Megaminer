param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'ZERG'
$WalletMode = 'WALLET'
$ApiUrl = 'http://api.zergpool.com:8080/api'
$MineUrl = 'mine.zergpool.com'
$Location = 'Europe'
$RewardType = "PPS"
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to config.txt wallet, no registration required"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $True
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if ($Querymode -eq "speed") {
    try {
        $http = $ApiUrl + "/walletEx?address=" + $Info.user
        $Request = Invoke-WebRequest -UserAgent $UserAgent $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    $Result = @()

    if (![string]::IsNullOrEmpty($Request)) {
        $Request.Miners |ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Version    = $_.version
                Algorithm  = get_algo_unified_name $_.Algo
                Workername = ($_.password -split ",")[2]
                Diff       = $_.difficulty
                Rejected   = $_.rejected
                Hashrate   = $_.accepted
            }
        }
        remove-variable Request
    }
}


if ($Querymode -eq "wallet") {
    try {
        $http = $ApiUrl + "/wallet?address=" + $Info.user
        $Request = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    if (![string]::IsNullOrEmpty($Request)) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Request.currency
            balance  = $Request.balance
        }
        remove-variable Request
    }
    Start-Sleep -Seconds 1 # Prevent API Saturation
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $retries = 1
    do {
        try {
            $http = $ApiUrl + "/currencies"
            $Request = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
        } catch {start-sleep 2}
        $retries++
        if ([string]::IsNullOrEmpty($Request)) {start-sleep 3}
    } while ($Request -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }
    $retries = 1
    do {
        try {
            $http = $ApiUrl + "/status"
            $Request2 = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
        } catch {start-sleep 2}
        $retries++
        if ([string]::IsNullOrEmpty($Request2)) {start-sleep 3}
    } while ($Request2 -eq $null -and $retries -le 3)
    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
    }

    $Request | Get-Member -MemberType Properties | ForEach-Object {

        $coin = $Request | Select-Object -ExpandProperty $_.name
        $Pool_Algo = get_algo_unified_name $coin.algo

        $Pool_coin = get_coin_unified_name $coin.name
        $Pool_symbol = $_.name

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "blake2s" {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "equihash" {$Divisor /= 1000}
            "scrypt" {$Divisor *= 1000}
            "sha256" {$Divisor *= 1000}
        }

        $Currency = if ([string]::IsNullOrEmpty($(get_config_variable "CURRENCY_$Name"))) { get_config_variable "CURRENCY" } else { get_config_variable "CURRENCY_$Name" }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_coin
            Price                 = $coin.estimate / $Divisor
            Price24h              = $coin.'24h_btc' / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $MineUrl
            Port                  = $coin.port
            User                  = $CoinsWallets.get_item($Currency)
            Pass                  = "c=$Currency,mc=$Pool_Symbol,ID=#WorkerName#"
            Location              = $Location
            SSL                   = $false
            Symbol                = $Pool_Symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $coin.Workers
            PoolHashRate          = $coin.hashrate
            Blocks_24h            = $coin.'24h_blocks'
            WalletMode            = $WalletMode
            Walletsymbol          = $Currency
            PoolName              = $Name
            Fee                   = $Request2.($coin.algo).Fees / 100
            RewardType            = $RewardType
        }
    }
    remove-variable Request
    remove-variable Request2
}


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
