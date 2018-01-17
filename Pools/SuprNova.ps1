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
    }
}


if ($Querymode -eq "APIKEY") {
    try {
        $http = "https://" + $Info.Symbol + ".suprnova.cc/index.php?page=api&action=getuserbalance&api_key=" + $Info.ApiKey + "&id="
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5
        $Request = $Request | ConvertFrom-Json | Select-Object -ExpandProperty getuserbalance | Select-Object -ExpandProperty data
    } catch {
    }

    $Result = [PSCustomObject]@{
        Pool     = $name
        currency = $Info.Symbol
        balance  = $Request.confirmed + $Request.unconfirmed
    }
}


if ($Querymode -eq "speed") {
    try {
        $http = "https://" + $Info.Symbol + ".suprnova.cc/index.php?page=api&action=getuserworkers&api_key=" + $Info.ApiKey
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5  | ConvertFrom-Json
    } catch {
    }

    if ($Request -ne $null -and $Request -ne "") {
        $Request.getuserworkers.data | ForEach-Object {
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
    $Pools = @()
    $Pools += [pscustomobject]@{"coin" = "BitCore"; "algo" = "BitCore"; "symbol" = "BTX"; "server" = "btx.suprnova.cc"; "port" = "3629"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitSend"; "algo" = "Xevan"; "symbol" = "BSD"; "server" = "bsd.suprnova.cc"; "port" = "8686"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitcoinGold"; "algo" = "Equihash"; "symbol" = "BTG"; "server" = "btg.suprnova.cc"; "port" = "8816"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "BitcoinZ"; "algo" = "Equihash"; "symbol" = "BTCZ"; "server" = "btcz.suprnova.cc"; "port" = "5586"; "location" = "US"};
    # $Pools += [pscustomobject]@{"coin" = "Decred"; "algo" = "Blake14r"; "symbol" = "DCR"; "server" = "dcr.suprnova.cc"; "port" = "3252"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Digibyte"; "algo" = "Skein"; "symbol" = "DGB"; "server" = "dgbs.suprnova.cc"; "port" = "5226"; "location" = "US"; "WalletSymbol" = "DGBS"};
    $Pools += [pscustomobject]@{"coin" = "Electroneum"; "algo" = "Cryptonight"; "symbol" = "ETN"; "server" = "etn-stratum.suprnova.cc"; "port" = "8875"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Ethereum"; "algo" = "Ethash"; "symbol" = "ETH"; "server" = "eth.suprnova.cc"; "port" = "5000"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "EuropeCoin v3"; "algo" = "HODL"; "symbol" = "ERC"; "server" = "erc.suprnova.cc"; "port" = "7674"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "GroestlCoin"; "algo" = "Groestl"; "symbol" = "GRS"; "server" = "grs.suprnova.cc"; "port" = "5544"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "HODLcoin"; "algo" = "HODL"; "symbol" = "HODL"; "server" = "hodl.suprnova.cc"; "port" = "4693"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Hush"; "algo" = "Equihash"; "symbol" = "Hush"; "server" = "hush.suprnova.cc"; "port" = "4048"; "location" = "US"; "portSSL" = "4050"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "Komodo"; "algo" = "Equihash"; "symbol" = "KMD"; "server" = "kmd.suprnova.cc"; "port" = "6250"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Lbry"; "algo" = "LBRY"; "symbol" = "LBC"; "server" = "lbry.suprnova.cc"; "port" = "6256"; "location" = "US"; "WalletSymbol" = "LBRY"};
    $Pools += [pscustomobject]@{"coin" = "MinexCoin"; "algo" = "Mars"; "symbol" = "MNX"; "server" = "mnx.suprnova.cc"; "port" = "7076"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "MonaCoin"; "algo" = "Lyra2V2"; "symbol" = "MONA"; "server" = "mona.suprnova.cc"; "port" = "2995"; "location" = "US"; "portSSL" = "3001"; "SSL" = $true};
    # $Pools += [pscustomobject]@{"coin" = "Monero"; "algo" = "Cryptonight"; "symbol" = "XMR"; "server" = "xmr-eu.suprnova.cc"; "port" = "5221"; "location" = "Europe"};
    $Pools += [pscustomobject]@{"coin" = "Monero"; "algo" = "Cryptonight"; "symbol" = "XMR"; "server" = "xmr.suprnova.cc"; "port" = "5222"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "MUNCoin"; "algo" = "skunk"; "symbol" = "MUN"; "server" = "mun.suprnova.cc"; "port" = "8963"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Polytimos"; "algo" = "Polytimos"; "symbol" = "POLY"; "server" = "poly.suprnova.cc"; "port" = "7935"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "SibCoin"; "algo" = "X11GOST"; "symbol" = "SIB"; "server" = "sib.suprnova.cc"; "port" = "3458"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "Straks"; "algo" = "lyra2v2"; "symbol" = "STAK"; "server" = "stak.suprnova.cc"; "port" = "7706"; "location" = "US"; "portSSL" = "7710"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "SmartCash"; "algo" = "keccak"; "symbol" = "SMART"; "server" = "smart.suprnova.cc"; "port" = "4192"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "UBIQ"; "algo" = "Ethash"; "symbol" = "UBQ"; "server" = "ubiq.suprnova.cc"; "port" = "3030"; "location" = "US"; "WalletSymbol" = "UBIQ"};
    $Pools += [pscustomobject]@{"coin" = "Vertcoin"; "algo" = "lyra2v2"; "symbol" = "VTC"; "server" = "vtc.suprnova.cc"; "port" = "5678"; "location" = "US"; "portSSL" = "5676"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "Verge"; "algo" = "lyra2v2"; "symbol" = "XVG"; "server" = "xvg-lyra.suprnova.cc"; "port" = "2595"; "location" = "US"; "WalletSymbol" = "XVG-LYRA"};
    $Pools += [pscustomobject]@{"coin" = "Verge"; "algo" = "x17"; "symbol" = "XVG"; "server" = "xvg-x17.suprnova.cc"; "port" = "7477"; "location" = "US"; "WalletSymbol" = "XVG-17"};
    $Pools += [pscustomobject]@{"coin" = "Verge"; "algo" = "Myriad-Groestl"; "symbol" = "XVG"; "server" = "xvg-mg.suprnova.cc"; "port" = "7722"; "location" = "US"; "WalletSymbol" = "XVG-MG"};
    $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-apac.suprnova.cc"; "port" = "2142"; "location" = "Asia"};
    $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-eu.suprnova.cc"; "port" = "2142"; "location" = "Europe"; "portSSL" = "2242"; "serverSSL" = "zec.suprnova.cc"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-us.suprnova.cc"; "port" = "2142"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "ZClassic"; "algo" = "Equihash"; "symbol" = "ZCL"; "server" = "zcl.suprnova.cc"; "port" = "4042"; "location" = "US"; "portSSL" = "4142"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "ZENCash"; "algo" = "Equihash"; "symbol" = "ZEN"; "server" = "zen.suprnova.cc"; "port" = "3618"; "location" = "US"; "portSSL" = "3621"; "SSL" = $true};
    $Pools += [pscustomobject]@{"coin" = "Zero"; "algo" = "EquihashZero"; "symbol" = "ZER"; "server" = "zero.suprnova.cc"; "port" = "6568"; "location" = "US"; "WalletSymbol" = "ZERO"};
    $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc-apac.suprnova.cc"; "port" = "1569"; "location" = "Asia"};
    $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc.suprnova.cc"; "port" = "1569"; "location" = "Europe"};
    $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc.suprnova.cc"; "port" = "1569"; "location" = "US"};

    $Pools |ForEach-Object {

        $enableSSL = ($_.SSL -eq $true)

        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Price                 = $null
            Price24h              = $null
            Protocol              = "stratum+tcp"
            ProtocolSSL           = if ($enableSSL) {"stratum+tls"} else {$null}
            Host                  = $_.Server
            HostSSL               = if ($enableSSL -and $_.serverSSL -ne $null) {$_.serverSSL} else {$_.Server}
            Port                  = $_.Port
            PortSSL               = if ($enableSSL) {$_.PortSSL} else {$null}
            User                  = "$Username.#Workername#"
            Pass                  = "x"
            Location              = $_.Location
            SSL                   = $enableSSL
            Symbol                = $_.symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $null
            PoolHashRate          = $null
            PoolName              = $Name
            WalletMode            = $WalletMode
            WalletSymbol          = if ($_.WalletSymbol -ne $null) {$_.WalletSymbol} else {$_.Symbol}
            Fee                   = 0.01
            EthStMode             = 3
        }
    }
    Remove-Variable Pools
}

$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result