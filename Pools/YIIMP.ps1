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
$AbbName = 'YIIMP'
$WalletMode = "WALLET"
$ApiUrl = 'http://api.yiimp.eu/api'
$MineUrl = 'yiimp.eu'
$Location = 'Europe'
$UserAgent = '"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"'
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
    }
}


if ($Querymode -eq "wallet") {
    try {
        $http = $ApiUrl + "/wallet?address=" + $Info.user
        $Request = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json
    }
    catch {}

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
            $http = $ApiUrl + "/currencies"
            $Request = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json
        }
        catch {start-sleep 2}
        $retries++
        if ($Request -eq $null -or $Request -eq "") {start-sleep 3}
    } while ($Request -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Request | Get-Member -MemberType Properties | ForEach-Object {

        $coin = $Request | Select-Object -ExpandProperty $_.name
        $Pool_Algo = get-algo-unified-name $coin.algo

        $Pool_coin = get-coin-unified-name $coin.name
        $Pool_symbol = $_.name

        $Divisor = (Get-Algo-Divisor $Pool_Algo) / 1000

        switch ($Pool_Algo) {
            "X11" {$Divisor *= 1000}
            "qubit" {$Divisor *= 1000}
            "quark" {$Divisor *= 1000}
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
            Pass                  = "c=$Pool_symbol,ID=$WorkerName"
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
            PoolName              = $Name
        }
    }
    remove-variable Request
}


$Result |ConvertTo-Json | Set-Content ("$name.tmp")
remove-variable Result
