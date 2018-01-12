param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null ,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'ITY'
$WalletMode = 'WALLET'
$ApiUrl = 'http://italyiimp.com/api'
$MineUrl = 'italyiimp.com'
$Location = 'EU'
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to @@currency coin specified in config.txt, no registration required"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $True
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
    }
}


if ($Querymode -eq "speed") {
    try {
        $http = $ApiUrl + "/walletEx?address=" + $Info.user
        $Request = Invoke-WebRequest -UserAgent $UserAgent $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    $Result = @()

    if ($Request -ne $null -and $Request -ne "") {
        $Request.Miners |ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Version    = $_.version
                Algorithm  = get_algo_unified_name $_.Algo
                Workername = ($_.password -split ",")[1]
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

    if ($Request -ne $null -and $Request -ne "") {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Request.currency
            balance  = $Request.balance
        }
    }
    remove-variable Request
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $retries = 1
    do {
        try {
            $http = $ApiUrl + "/status"
            $Request = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
        } catch {start-sleep 2}
        $retries++
        if ($Request -eq $null -or $Request -eq "") {start-sleep 3}
    } while ($Request -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }


    $Request | Get-Member -MemberType Properties | ForEach-Object {

        $coin = $Request | Select-Object -ExpandProperty $_.name
        $Pool_Algo = get_algo_unified_name $coin.name

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "sha256" {$Divisor *= 1000000000}
            "x11" {$Divisor *= 1000}
            "qubit" {$Divisor *= 1000}
            "quark" {$Divisor *= 1000}
            "blake2s" {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "decred" {$Divisor *= 1000}
            "keccak" {$Divisor *= 1000}
            "equihash" {$Divisor /= 1000}
            "yescrypt" {$Divisor /= 1000}
        }

        if ($coin.actual_last24h -gt 0 -and $coin.hashrate -gt 0 -and $coin.Workers -gt 0 -and $coin.Workers -lt 19999) {
            $Result += [PSCustomObject]@{
                Algorithm             = $Pool_Algo
                Info                  = $null
                Price                 = $coin.estimate_current / $Divisor
                Price24h              = $coin.estimate_last24h / $Divisor
                Protocol              = "stratum+tcp"
                Host                  = $MineUrl
                Port                  = $coin.port
                User                  = $CoinsWallets.get_item($Currency)
                Pass                  = "c=$Currency,#WorkerName#"
                Location              = $Location
                SSL                   = $false
                Symbol                = $null
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolWorkers           = $coin.Workers
                PoolHashRate          = $coin.hashrate
                WalletMode            = $WalletMode
                WalletSymbol          = $Currency
                PoolName              = $Name
                Fee                   = $coin.Fees / 100
            }
        }
    }
    remove-variable Request
}


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
