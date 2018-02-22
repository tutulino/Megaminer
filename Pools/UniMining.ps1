param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null ,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$AbbName = 'UNI'
$WalletMode = 'WALLET'
$ApiUrl = 'http://pool.unimining.net/api'
$MineUrl = 'pool.unimining.net'
$Location = 'US'
$RewardType = "PPS"
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin on config.txt"
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
                Workername = $_.password.Split(",")[1].Split('=')[1]
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
            "sha256" {$Divisor *= 1000}
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_coin
            Price                 = $coin.estimate / $Divisor
            Price24h              = $coin.'24h_btc' / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $MineUrl
            Port                  = $coin.port
            User                  = $CoinsWallets.get_item($Pool_symbol)
            Pass                  = "c=$Pool_symbol,ID=#WorkerName#"
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
            WalletSymbol          = $Pool_Symbol
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
