param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$AbbName = 'CRKN'
$WalletMode = "NONE"
$Location = 'US'
$RewardType = 'PPLS'
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin on config.txt"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $false
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Pools = @()

    $Pools += [PSCustomObject]@{coin = "Alloy"; symbol = "XAO"; algo = "CryptoNightAlloy"; port = 5661; fee = 0.0; walletSymbol = "Alloy"; server = "alloy.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "B2B"; symbol = "B2B"; algo = "CryptoNight"; port = 4491; fee = 0.0; walletSymbol = "B2B"; server = "b2b.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "BBS"; symbol = "BBS"; algo = "CryptoNightV7"; port = 19931; fee = 0.0; walletSymbol = "BBS"; server = "bbs.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "BitcoiNote"; symbol = "BTCN"; algo = "CryptoNight"; port = 9732; fee = 0.0; walletSymbol = "BTCN"; server = "btcn.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CryptoLightIPBC"; port = 4461; fee = 0.0; walletSymbol = "IPBC"; server = "ipbc.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Crep"; symbol = "CREP"; algo = "CryptoNight"; port = 4201; fee = 0.0; walletSymbol = "CREP"; server = "crep.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "eDollar"; symbol = "EDL"; algo = "CryptoNight"; port = 50301; fee = 0.0; walletSymbol = "EDL"; server = "edl.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Elya"; symbol = "ELYA"; algo = "CryptoNight"; port = 50201; fee = 0.0; walletSymbol = "ELYA"; server = "elya.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Graft"; symbol = "GRF"; algo = "CryptoNightV7"; port = 9111; fee = 0.0; walletSymbol = "GRAFT"; server = "graft.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CryptoNightHeavy"; port = 5531; fee = 0.0; walletSymbol = "Haven"; server = "haven.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "IntenseCoin"; symbol = "ITNS"; algo = "CryptoNightV7"; port = 8881; fee = 0.0; walletSymbol = "ITNS"; server = "intense.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Iridium"; symbol = "IRD"; algo = "CryptoLightV7"; port = 50501; fee = 0.0; walletSymbol = "Iridium"; server = "iridium.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Italo"; symbol = "ITA"; algo = "CryptoNightHeavy"; port = 50701; fee = 0.0; walletSymbol = "Italo"; server = "italo.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Karbo"; symbol = "KRB"; algo = "CryptoNight"; port = 29991; fee = 0.0; walletSymbol = "Karbo"; server = "karbo.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Lines"; symbol = "LNS"; algo = "CryptoNightV7"; port = 50401; fee = 0.0; walletSymbol = "Lines"; server = "lines.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CryptoNightHeavy"; port = 7731; fee = 0.0; walletSymbol = "Loki"; server = "loki.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CryptoNightV7"; port = 3333; fee = 0.0; walletSymbol = "MSR"; server = "masari.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "MoneroV"; symbol = "XMV"; algo = "CryptoNightV7"; port = 9221; fee = 0.0; walletSymbol = "MoneroV"; server = "monerov.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Niobio"; symbol = "NBR"; algo = "CryptoNight"; port = 50101; fee = 0.0; walletSymbol = "Niobio"; server = "niobio.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Ombre"; symbol = "OMB"; algo = "CryptoNightHeavy"; port = 5571; fee = 0.0; walletSymbol = "Ombre"; server = "ombre.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Qwerty"; symbol = "QWC"; algo = "CryptoNight"; port = 8261; fee = 0.0; walletSymbol = "Qwery"; server = "qwerty.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Solace"; symbol = "SOL"; algo = "CryptoNightHeavy"; port = 5001; fee = 0.0; walletSymbol = "Solace"; server = "solace.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CryptoNightV7"; port = 16221; fee = 0.0; walletSymbol = "Stellite"; server = "stellite.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Sumo"; symbol = "SUMO"; algo = "CryptoNightHeavy"; port = 50801; fee = 0.0; walletSymbol = "Sumo"; server = "sumo.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Triton"; symbol = "TRIT"; algo = "CryptoLightV7"; port = 6631; fee = 0.0; walletSymbol = "Triton"; server = "triton.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "TurtleCoin"; symbol = "TRTL"; algo = "CryptoLightV7"; port = 4901; fee = 0.0; walletSymbol = "Turtle"; server = "turtle.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "UltraNode"; symbol = "XUN"; algo = "CryptoNight"; port = 4444; fee = 0.0; walletSymbol = "XUN"; server = "xun.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "WowNero"; symbol = "WOW"; algo = "CryptoNightV7"; port = 50901; fee = 0.0; walletSymbol = "WowNero"; server = "wownero.ingest.cryptoknight.cc"}

    $Pools | ForEach-Object {

        $Wallet = $CoinsWallets.get_item($_.symbol)
        if ($Wallet) {

            $Result += [PSCustomObject]@{
                Algorithm                = $_.algo
                Info                     = $_.coin
                Protocol                 = "stratum+tcp"
                Host                     = $_.server
                Port                     = $_.port
                User                     = $Wallet
                Pass                     = "#WorkerName#"
                Location                 = $Location
                SSL                      = $false
                Symbol                   = $_.symbol
                AbbName                  = $AbbName
                ActiveOnManualMode       = $ActiveOnManualMode
                ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
                ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
                WalletMode               = $WalletMode
                WalletSymbol             = $_.walletSymbol
                PoolName                 = $Name
                Fee                      = $_.fee
                RewardType               = $RewardType
            }
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result
