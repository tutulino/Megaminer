param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)


$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$AbbName = 'FAIR'
$WalletMode = "WALLET"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "Must set wallet for each coin on web, set login on config.txt file"
        ActiveOnManualMode    = $ActiveOnManualMode
        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
        ApiData               = $true
        AbbName               = $AbbName
        WalletMode            = $WalletMode
    }
}


if ($Querymode -eq "speed") {
    try {
        $http = "https://" + $Info.Symbol + ".fairpool.cloud/api/stats?login=" + ($Info.user -split "\+")[0]
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}
    $Result = @()
    if ($Request -ne $null -and $Request -ne "") {
        $Request.Workers | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Workername = $_[0]
                Hashrate   = $_[1]
            }
        }
        remove-variable Request
    }
}


if ($Querymode -eq "wallet") {
    try {
        $http = "https://" + $Info.Symbol + ".fairpool.cloud/api/stats?login=" + ($Info.User -split "\+")[0]
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}
    if ($Request -ne $null -and $Request -ne "") {
        switch ($Info.Symbol) {
            'pasl' { $Divisor = 10000 }
            'sumo' { $Divisor = 1000000000}
            Default { $Divisor = 10000 }
        }
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = ($Request.balance + $Request.unconfirmed ) / $Divisor
        }
        remove-variable Request
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Pools = @()

    $Pools += [pscustomobject]@{"coin" = "Sumokoin"; "algo" = "CryptoNight"; "symbol" = "SUMO"; "server" = "mine.sumo.fairpool.cloud"; "port" = "5555"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "PascalLite"; "algo" = "Pascal"; "symbol" = "PASL"; "server" = "mine.pasl.fairpool.cloud"; "port" = "4009"; "fee" = "0.02"}
    $Pools += [pscustomobject]@{"coin" = "Metaverse"; "algo" = "Ethash"; "symbol" = "ETP"; "server" = "mine.etp.fairpool.cloud"; "port" = "6666"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Electroneum"; "algo" = "CryptoNight"; "symbol" = "ETN"; "server" = "mine.etn.fairpool.cloud"; "port" = "8888"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "EthereumClassic"; "algo" = "Ethash"; "symbol" = "ETC"; "server" = "mine.etc.fairpool.cloud"; "port" = "4444"; "fee" = "0.01"}

    $Pools | ForEach-Object {
        if ($CoinsWallets.get_item($_.symbol) -ne $null) {
            $Result += [PSCustomObject]@{
                Algorithm             = $_.Algo
                Info                  = $_.Coin
                Price                 = $Null
                Price24h              = $Null
                Protocol              = "stratum+tcp"
                Host                  = $_.Server
                Port                  = $_.Port
                User                  = $CoinsWallets.get_item($_.symbol) + "+#WORKERNAME#"
                Pass                  = "x"
                Location              = "US"
                SSL                   = $false
                Symbol                = $_.symbol
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = $_.Symbol
                Fee                   = $_.Fee
            }
        }
    }
    remove-variable Pools
}


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable result
