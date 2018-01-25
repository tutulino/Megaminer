param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)


$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$AbbName = 'DEMO'
$WalletMode = "NONE"
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


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Pools = @()

    $Pools += [pscustomobject]@{"coin" = "Bikercoin"; "algo" = "CryptoNight"; "symbol" = "BIC"; "server" = "pool2.democats.org"; "port" = "45560"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Bipcoin"; "algo" = "CryptoNight"; "symbol" = "BIP"; "server" = "pool.democats.org"; "port" = "45590"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Bitcoal"; "algo" = "CryptoNight"; "symbol" = "COAL"; "server" = "pool.democats.org"; "port" = "45600"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Bytecoin"; "algo" = "CryptoNight"; "symbol" = "BCN"; "server" = "pool.democats.org"; "port" = "45500"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Dashcoin"; "algo" = "CryptoNight"; "symbol" = "DSH"; "server" = "pool.democats.org"; "port" = "45510"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Dinastycoin"; "algo" = "CryptoNight"; "symbol" = "DCY"; "server" = "pool.democats.org"; "port" = "45550"; "fee" = "0.03"}
    $Pools += [pscustomobject]@{"coin" = "Karbowanec"; "algo" = "CryptoNight"; "symbol" = "KRB"; "server" = "pool2.democats.org"; "port" = "45570"; "fee" = "0"}

    $Pools |ForEach-Object {
        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Price                 = $Null
            Price24h              = $Null
            Protocol              = "stratum+tcp"
            Host                  = $_.Server
            Port                  = $_.Port
            User                  = $CoinsWallets.get_item($_.symbol)
            Pass                  = "x"
            Location              = "Europe"
            SSL                   = $false
            Symbol                = $_.symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            Fee                   = $_.Fee
        }
    }
    remove-variable Pools
}


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable result
