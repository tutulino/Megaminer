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

    $Pools += [PSCustomObject]@{coin = "Aeon"; symbol = "AEON"; algo = "CnLiteV7"; port = 5541; fee = 0.0; walletSymbol = "Aeon"; server = "aeon.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Alloy"; symbol = "XAO"; algo = "CnAlloy"; port = 5661; fee = 0.0; walletSymbol = "Alloy"; server = "alloy.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Arqma"; symbol = "ARQ"; algo = "CnLiteV7"; port = 3731; fee = 0.0; walletSymbol = "arq"; server = "arq.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Arto"; symbol = "ARTO"; algo = "CnArto"; port = 51201; fee = 0.0; walletSymbol = "Arto"; server = "arto.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "BBS"; symbol = "BBS"; algo = "CnV7"; port = 19931; fee = 0.0; walletSymbol = "BBS"; server = "bbs.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "BitTube"; symbol = "TUBE"; algo = "CnSaber"; port = 4461; fee = 0.0; walletSymbol = "IPBC"; server = "ipbc.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Elya"; symbol = "ELYA"; algo = "CnV7"; port = 50201; fee = 0.0; walletSymbol = "ELYA"; server = "elya.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Graft"; symbol = "GRF"; algo = "CnV7"; port = 9111; fee = 0.0; walletSymbol = "GRAFT"; server = "graft.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Haven"; symbol = "XHV"; algo = "CnHeavy"; port = 5531; fee = 0.0; walletSymbol = "Haven"; server = "haven.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "IntenseCoin"; symbol = "ITNS"; algo = "CnV7"; port = 8881; fee = 0.0; walletSymbol = "ITNS"; server = "intense.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Iridium"; symbol = "IRD"; algo = "CnLiteV7"; port = 50501; fee = 0.0; walletSymbol = "Iridium"; server = "iridium.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Italo"; symbol = "ITA"; algo = "CnHaven"; port = 50701; fee = 0.0; walletSymbol = "Italo"; server = "italo.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Lines"; symbol = "LNS"; algo = "CnV7"; port = 50401; fee = 0.0; walletSymbol = "Lines"; server = "lines.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Loki"; symbol = "LOKI"; algo = "CnHeavy"; port = 7731; fee = 0.0; walletSymbol = "Loki"; server = "loki.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Masari"; symbol = "MSR"; algo = "CnFast"; port = 3333; fee = 0.0; walletSymbol = "MSR"; server = "masari.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "MoneroV"; symbol = "XMV"; algo = "CnV7"; port = 9221; fee = 0.0; walletSymbol = "MoneroV"; server = "monerov.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Niobio"; symbol = "NBR"; algo = "CnHeavy"; port = 50101; fee = 0.0; walletSymbol = "Niobio"; server = "niobio.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Ombre"; symbol = "OMB"; algo = "CnHeavy"; port = 5571; fee = 0.0; walletSymbol = "Ombre"; server = "ombre.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Qwerty"; symbol = "QWC"; algo = "CnHeavy"; port = 8261; fee = 0.0; walletSymbol = "Qwery"; server = "qwerty.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Saronite"; symbol = "XRN"; algo = "CnHeavy"; port = 5531; fee = 0.0; walletSymbol = "Saronite"; server = "saronite.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Solace"; symbol = "SOL"; algo = "CnHeavy"; port = 5001; fee = 0.0; walletSymbol = "Solace"; server = "solace.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Stellite"; symbol = "XTL"; algo = "CnXTL"; port = 16221; fee = 0.0; walletSymbol = "Stellite"; server = "stellite.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "Triton"; symbol = "TRIT"; algo = "CnLiteV7"; port = 6631; fee = 0.0; walletSymbol = "Triton"; server = "triton.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "TurtleCoin"; symbol = "TRTL"; algo = "CnLiteV7"; port = 4901; fee = 0.0; walletSymbol = "Turtle"; server = "turtle.ingest.cryptoknight.cc"}
    $Pools += [PSCustomObject]@{coin = "WowNero"; symbol = "WOW"; algo = "CnV7"; port = 50901; fee = 0.0; walletSymbol = "WowNero"; server = "wownero.ingest.cryptoknight.cc"}

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
