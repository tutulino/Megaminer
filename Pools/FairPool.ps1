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

    $Pools += [pscustomobject]@{"coin" = "Sumokoin"; "algo" = "Cryptonight"; "symbol" = "SUMO"; "server" = "mine.sumo.fairpool.xyz"; "port" = "5555"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "PascalLite"; "algo" = "Pascal"; "symbol" = "PASL"; "server" = "mine.pasl.fairpool.xyz"; "port" = "4009"; "fee" = "0.02"}
    $Pools += [pscustomobject]@{"coin" = "Metaverse"; "algo" = "Ethash"; "symbol" = "ETP"; "server" = "mine.etp.fairpool.xyz"; "port" = "6666"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "Electroneum"; "algo" = "Cryptonight"; "symbol" = "ETN"; "server" = "mine.etn.fairpool.xyz"; "port" = "8888"; "fee" = "0.01"}
    $Pools += [pscustomobject]@{"coin" = "EthereumClassic"; "algo" = "Ethash"; "symbol" = "ETC"; "server" = "mine.etc.fairpool.xyz"; "port" = "4444"; "fee" = "0.01"}

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
            Location              = "US"
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


$Result |ConvertTo-Json | Set-Content ("$name.tmp")
remove-variable result
