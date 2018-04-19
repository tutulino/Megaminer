param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$AbbName = 'SNV'
$WalletMode = "APIKEY"
$RewardType = "PPLS"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Must register and set wallet for each coin on web"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if ($Querymode -eq "APIKEY") {
    $Request = Invoke_APIRequest -Url $("https://" + $Info.Symbol + ".suprnova.cc/index.php?page=api&action=getuserbalance&api_key=" + $Info.ApiKey + "&id=") -Retry 3 |
        Select-Object -ExpandProperty getuserbalance | Select-Object -ExpandProperty data

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = $Request.confirmed + $Request.unconfirmed
        }
    }
}


if ($Querymode -eq "speed") {
    $Request = Invoke_APIRequest -Url $("https://" + $Info.Symbol + ".suprnova.cc/index.php?page=api&action=getuserworkers&api_key=" + $Info.ApiKey) -Retry 1 |
        Select-Object -ExpandProperty getuserworkers | Select-Object -ExpandProperty data

    if ($Request) {
        $Request | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Diff       = $_.difficulty
                Workername = ($_.username -split "\.")[1]
                Hashrate   = $_.hashrate
            }
        }
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    if (!$UserName) {
        Write-Host "$Name USERNAME not defined in config.ini"
        Exit
    }

    $Pools = @()
    $Pools += [pscustomobject]@{"coin" = "AchieveCoin"; "algo" = "Equihash"; "symbol" = "ACH"; "server" = "ach.suprnova.cc"; "port" = 4242; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitcoinGold"; "algo" = "Equihash"; "symbol" = "BTG"; "server" = "btg.suprnova.cc"; "port" = 8816; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitcoinPrivate"; "algo" = "Equihash"; "symbol" = "BTCP"; "server" = "btcp.suprnova.cc"; "port" = 6822; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitcoinZ"; "algo" = "Equihash"; "symbol" = "BTCZ"; "server" = "btcz.suprnova.cc"; "port" = 5586; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitCore"; "algo" = "Bitcore"; "symbol" = "BTX"; "server" = "btx.suprnova.cc"; "port" = 3629; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitSend"; "algo" = "Xevan"; "symbol" = "BSD"; "server" = "bsd.suprnova.cc"; "port" = 8686; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Credits"; "algo" = "Argon2d250"; "symbol" = "CRDS"; "server" = "crds.suprnova.cc"; "port" = 2771; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Criptoreal"; "algo" = "Lyra2Z"; "symbol" = "CRS"; "server" = "crs.suprnova.cc"; "port" = 4155; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Dynamic"; "algo" = "Argon2d500"; "symbol" = "DYN"; "server" = "dyn.suprnova.cc"; "port" = 5960; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Electroneum"; "algo" = "CryptoNight"; "symbol" = "ETN"; "server" = "etn-stratum.suprnova.cc"; "port" = 8875; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Ethereum"; "algo" = "Ethash"; "symbol" = "ETH"; "server" = "eth.suprnova.cc"; "port" = 5000; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "EuropeCoin"; "algo" = "HOdl"; "symbol" = "ERC"; "server" = "erc.suprnova.cc"; "port" = 7674; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Garlicoin"; "algo" = "Allium"; "symbol" = "GRLC"; "server" = "grlc.suprnova.cc"; "port" = 8600; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "HODLcoin"; "algo" = "HOdl"; "symbol" = "HODL"; "server" = "hodl.suprnova.cc"; "port" = 4693; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Hush"; "algo" = "Equihash"; "symbol" = "HUSH"; "server" = "hush.suprnova.cc"; "port" = 4048; "location" = "US"; "portSSL" = 4050; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "Komodo"; "algo" = "Equihash"; "symbol" = "KMD"; "server" = "kmd.suprnova.cc"; "port" = 6250; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Kreds"; "algo" = "Lyra2v2"; "symbol" = "KREDS"; "server" = "kreds.suprnova.cc"; "port" = 7196; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "MinexCoin"; "algo" = "Mars"; "symbol" = "MNX"; "server" = "mnx.suprnova.cc"; "port" = 7076; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "MonaCoin"; "algo" = "Lyra2v2"; "symbol" = "MONA"; "server" = "mona.suprnova.cc"; "port" = 2995; "location" = "US"; "portSSL" = 3001; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "MUNCoin"; "algo" = "Skunk"; "symbol" = "MUN"; "server" = "mun.suprnova.cc"; "port" = 8963; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Polytimos"; "algo" = "Polytimos"; "symbol" = "POLY"; "server" = "poly.suprnova.cc"; "port" = 7935; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Race"; "algo" = "Lyra2v2"; "symbol" = "RACE"; "server" = "race.suprnova.cc"; "port" = 5650; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Raven"; "algo" = "X16r"; "symbol" = "RVN"; "server" = "rvn.suprnova.cc"; "port" = 6666; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Pigeon"; "algo" = "X16s"; "symbol" = "PGN"; "server" = "pign.suprnova.cc"; "port" = 4096; "location" = "US"; "WalletSymbol" = "PIGN"};
    $Pools += [pscustomobject]@{"coin" = "ROIcoin"; "algo" = "HOdl"; "symbol" = "ROI"; "server" = "roi.suprnova.cc"; "port" = 4699; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Straks"; "algo" = "Lyra2v2"; "symbol" = "STAK"; "server" = "stak.suprnova.cc"; "port" = 7706; "location" = "US"; "portSSL" = 7710; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "UBIQ"; "algo" = "Ethash"; "symbol" = "UBQ"; "server" = "ubiq.suprnova.cc"; "port" = 3030; "location" = "US"; "WalletSymbol" = "UBIQ"};
    $Pools += [pscustomobject]@{"coin" = "Vertcoin"; "algo" = "Lyra2v2"; "symbol" = "VTC"; "server" = "vtc.suprnova.cc"; "port" = 5678; "location" = "US"; "portSSL" = 5676; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "WaviCoin"; "algo" = "YescryptR32"; "symbol" = "WAVI"; "server" = "wavi.suprnova.cc"; "port" = 6762; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-apac.suprnova.cc"; "port" = 2142; "location" = "Asia"};
    $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-eu.suprnova.cc"; "port" = 2142; "location" = "EU"; "portSSL" = 2242; "serverSSL" = "zec.suprnova.cc"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-us.suprnova.cc"; "port" = 2142; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "ZClassic"; "algo" = "Equihash"; "symbol" = "ZCL"; "server" = "zcl.suprnova.cc"; "port" = 4042; "location" = "US"; "portSSL" = 4142; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc.suprnova.cc"; "port" = 1569; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "ZENCash"; "algo" = "Equihash"; "symbol" = "ZEN"; "server" = "zen.suprnova.cc"; "port" = 3618; "location" = "US"; "portSSL" = 3621; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "Zero"; "algo" = "Zero"; "symbol" = "ZER"; "server" = "zero.suprnova.cc"; "port" = 6568; "location" = "US"; "WalletSymbol" = "ZERO"};

    $Pools | ForEach-Object {

        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            ProtocolSSL           = $(if ($_.Algo -eq "Lyra2v2") {"stratum+tls"} else {"ssl"})
            Host                  = $_.Server
            HostSSL               = $(if (!$_.serverSSL) {$_.serverSSL} else {$_.server})
            Port                  = $_.Port
            PortSSL               = $_.PortSSL
            User                  = "$Username.#Workername#"
            Pass                  = "x"
            Location              = $_.Location
            SSL                   = [bool]$_.SSL
            Symbol                = $_.symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            WalletSymbol          = if ($_.WalletSymbol) {$_.WalletSymbol} else {$_.Symbol}
            Fee                   = 0.01
            EthStMode             = 3
            RewardType            = $RewardType
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result