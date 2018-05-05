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
$RewardType = "PPLS"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "Must set wallet for each coin on web, set login on config.ini file"
        ActiveOnManualMode    = $ActiveOnManualMode
        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
        ApiData               = $true
        AbbName               = $AbbName
        WalletMode            = $WalletMode
        RewardType            = $RewardType
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Pools = @()

    $Pools += [pscustomobject]@{"coin" = "Aeon"; "algo" = "CryptoLight"; "symbol" = "AEON"; "server" = "mine.aeon-pool.com"; "port" = 5555; "fee" = 0.01; "User" = $CoinsWallets.AEON}
    # $Pools += [pscustomobject]@{"coin" = "HPPcoin"; "algo" = "Lyra2h"; "symbol" = "HPP"; "server" = "pool.hppcoin.com"; "port" = 3008; "fee" = 0; "User" = "$Username.#Workername#"}
    $Pools += [pscustomobject]@{"coin" = "HPPcoin"; "algo" = "Lyra2h"; "symbol" = "HPP"; "server" = "sg-mine.idcray.com"; "port" = 10111; "fee" = 0.01; "User" = "$Username.#Workername#"}
    # $Pools += [pscustomobject]@{"coin" = "HPPcoin"; "algo" = "Lyra2h"; "symbol" = "HPP"; "server" = "hpp-mine.idcray.com"; "port" = 10111; "fee" = 0.01; "User" = "$Username.#Workername#"}
    $Pools += [pscustomobject]@{"coin" = "Dallar"; "algo" = "Throestl"; "symbol" = "DAL"; "server" = "pool.dallar.org"; "port" = 3032; "fee" = 0.01; "User" = $CoinsWallets.DAL}

    $Pools += [pscustomobject]@{"coin" = "Cryply"; "algo" = "YescryptR16"; "symbol" = "CRP"; "server" = "cryply.luckypool.org"; "port" = 9997; "fee" = 0; "User" = "$Username.#Workername#"}
    $Pools += [pscustomobject]@{"coin" = "HexxCoin"; "algo" = "Lyra2z330"; "symbol" = "HXX"; "server" = "hxx-pool1.chainsilo.com"; "port" = 3033; "fee" = 0.03; "User" = "$Username.#Workername#"}


    $Pools | ForEach-Object {
        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            Host                  = $_.Server
            Port                  = $_.Port
            User                  = $_.User
            Pass                  = if ([string]::IsNullOrEmpty($_.Pass)) {"x"} else {$_.Pass}
            Location              = "EU"
            SSL                   = $false
            Symbol                = $_.symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            Fee                   = $_.Fee
            RewardType            = $RewardType
        }
    }
    Remove-Variable Pools
}


$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable result
