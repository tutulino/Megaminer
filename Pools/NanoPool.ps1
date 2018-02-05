param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $false
$AbbName = 'NP'
$WalletMode = "WALLET"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin on config.txt"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if ($Querymode -eq "SPEED") {
    try {
        $http = "https://api.nanopool.org/v1/" + $Info.symbol.tolower() + "/history/" + $Info.user
        $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    $Result = [PSCustomObject]@{
        PoolName   = $name
        Workername = $Info.WorkerName
        Hashrate   = ($Request.data)[0].hashrate
    }
}


if ($Querymode -eq "WALLET") {
    try {
        $http = "https://api.nanopool.org/v1/" + $Info.symbol.tolower() + "/balance/" + $Info.user
        $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    $Result = [PSCustomObject]@{
        Pool     = $name
        currency = $Info.Symbol
        balance  = $Request.data
    }
    Start-Sleep -Seconds 1 # Prevent API Saturation
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $PrePools = @()
    $PrePools += [pscustomobject]@{"coin" = "EthereumClassic"; "algo" = "Ethash"; "symbol" = "ETC"; "port" = 19999; "Fee" = 0.01; "Divisor" = 1000000; "protocol" = "stratum+tcp"};
    $PrePools += [pscustomobject]@{"coin" = "Ethereum"; "algo" = "Ethash"; "symbol" = "ETH"; "port" = 9999; "Fee" = 0.01; "Divisor" = 1000000; "protocol" = "stratum+tcp"};
    $PrePools += [pscustomobject]@{"coin" = "Sia"; "algo" = "BLAKE2B"; "symbol" = "SIA"; "port" = 7777; "Fee" = 0.02; "Divisor" = 1000000; "protocol" = "stratum+tcp"};
    $PrePools += [pscustomobject]@{"coin" = "Zcash"; "algo" = "Equihash"; "symbol" = "ZEC"; "port" = 6666; "Fee" = 0.01; "Divisor" = 1; "protocol" = "stratum+ssl"};
    $PrePools += [pscustomobject]@{"coin" = "Monero"; "algo" = "CryptoNight"; "symbol" = "XMR"; "port" = 14444; "Fee" = 0.01; "Divisor" = 1; "protocol" = "stratum+ssl"};
    $PrePools += [pscustomobject]@{"coin" = "Electroneum"; "algo" = "CryptoNight"; "symbol" = "ETN"; "port" = 13333; "Fee" = 0.02; "Divisor" = 1; "protocol" = "stratum+ssl"};

    $Pools = @() #generate a pool for each location and add API data
    $PrePools | ForEach-Object {

        try {
            $RequestW = $null
            $http = "https://api.nanopool.org/v1/" + $_.symbol.ToLower() + "/pool/activeworkers"
            $RequestW = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 3 | ConvertFrom-Json
            $RequestP = $null
            $http = "https://api.nanopool.org/v1/" + $_.symbol.ToLower() + "/approximated_earnings/1"
            $RequestP = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 3 | ConvertFrom-Json |
                select-object -ExpandProperty data | select-object -ExpandProperty day
        } catch {}


        $Locations = @()
        $Locations += [PSCustomObject]@{Location = "EUROPE"; server = $_.Symbol + "-eu1.nanopool.org"}
        $Locations += [PSCustomObject]@{Location = "US"; server = $_.Symbol + "-us-east1.nanopool.org"}
        $Locations += [PSCustomObject]@{Location = "ASIA"; server = $_.Symbol + "-asia1.nanopool.org"}

        ForEach ($loc in $locations) {
            $Result += [PSCustomObject]@{
                Algorithm             = $_.algo
                Info                  = $_.Coin
                Price                 = ($RequestP.bitcoins / $_.Divisor)
                Price24h              = $null
                Protocol              = "stratum+tcp" #$_.Protocol
                Host                  = $loc.server
                Port                  = $_.Port
                User                  = $CoinsWallets.get_item($_.symbol)
                Pass                  = "x,#WorkerName#"
                Location              = $loc.location
                SSL                   = $false
                Symbol                = $_.symbol
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolWorkers           = $RequestW.Data
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = $_.symbol
                Fee                   = $_.fee
                EthStMode             = 0
            }
        }
        Start-Sleep -Seconds 1 # Prevent API Saturation
    }
}

$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result