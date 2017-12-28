param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)


$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$AbbName = 'MY'
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

    $Pools += [pscustomobject]@{"coin" = "Karbowanec"; "algo" = "Cryptonight"; "symbol" = "KRB"; "server" = "pool2.democats.org"; "port" = "45570"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Bytecoin"; "algo" = "Cryptonight"; "symbol" = "BCN"; "server" = "pool.democats.org"; "port" = "45500"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Aeon"; "algo" = "Cryptonight-Lite"; "symbol" = "AEON"; "server" = "mine.aeon-pool.com"; "port" = "5555"; "fee" = "0.01"}

    # $Pools +=[pscustomobject]@{"coin" = "Karbowanec";"algo"="Cryptonight"; "symbol"= "KRB";"server"="krb.sberex.com";"port"= "5555";"fee"="0.02"}


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
