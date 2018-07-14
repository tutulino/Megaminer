param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'NP'
$WalletMode = "WALLET"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin on config.ini"
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
    $Request = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $Info.symbol.tolower() + "/history/" + $Info.user) -Retry 1
    if ($Request) {
        $Result = [PSCustomObject]@{
            PoolName   = $name
            WorkerName = $Info.WorkerName
            HashRate   = ($Request.data)[0].HashRate
        }
    }
}

if ($Querymode -eq "WALLET") {
    $Request = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $Info.symbol.tolower() + "/balance/" + $Info.user) -Retry 3
    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = $Request.data
        }
    }
}

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $PrePools = @()
    $PrePools += [PSCustomObject]@{coin = "EthereumClassic"; algo = "Ethash"; symbol = "ETC"; port = 19999; fee = 0.01; divisor = 1000000; protocol = "stratum+tcp"};
    $PrePools += [PSCustomObject]@{coin = "Ethereum"; algo = "Ethash"; symbol = "ETH"; port = 9999; fee = 0.01; divisor = 1000000; protocol = "stratum+tcp"};
    $PrePools += [PSCustomObject]@{coin = "Zcash"; algo = "Equihash"; symbol = "ZEC"; port = 6666; fee = 0.01; divisor = 1; protocol = "stratum+ssl"};
    $PrePools += [PSCustomObject]@{coin = "Monero"; algo = "CnV7"; symbol = "XMR"; port = 14444; fee = 0.01; divisor = 1; protocol = "stratum+ssl"};
    $PrePools += [PSCustomObject]@{coin = "Electroneum"; algo = "Cn"; symbol = "ETN"; port = 13333; fee = 0.02; divisor = 1; protocol = "stratum+ssl"};

    $Pools = @() #generate a pool for each location and add API data
    $PrePools | ForEach-Object {
        $RequestW = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $_.symbol.ToLower() + "/pool/activeworkers") -Retry 1
        $RequestP = Invoke-APIRequest -Url $("https://api.nanopool.org/v1/" + $_.symbol.ToLower() + "/approximated_earnings/1000") -Retry 1 |
            Select-Object -ExpandProperty data | Select-Object -ExpandProperty day

        $Locations = @()
        $Locations += [PSCustomObject]@{location = "EU"; server = $_.Symbol + "-eu1.nanopool.org"}
        $Locations += [PSCustomObject]@{location = "US"; server = $_.Symbol + "-us-east1.nanopool.org"}
        $Locations += [PSCustomObject]@{location = "ASIA"; server = $_.Symbol + "-asia1.nanopool.org"}

        ForEach ($loc in $locations) {
            $Result += [PSCustomObject]@{
                Algorithm             = $_.algo
                Info                  = $_.Coin
                Price                 = [decimal]$RequestP.bitcoins / $_.Divisor / 1000
                Price24h              = [decimal]$RequestP.bitcoins / $_.Divisor / 1000
                Protocol              = "stratum+tcp" #$_.Protocol
                Host                  = $loc.server
                Port                  = $_.Port
                User                  = $CoinsWallets.($_.Symbol)
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
                RewardType            = $RewardType
            }
        }
        Start-Sleep -Seconds 1 # Prevent API Saturation
    }
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
