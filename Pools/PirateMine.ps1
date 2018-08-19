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
$AbbName = 'PM'
$WalletMode = "WALLET"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin in config.ini"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {


    $Request = Invoke-APIRequest -Url "https://thepiratemine.nl/pools.php"

    if ($Request.pools) {

        foreach ($Coin in $($Request.pools | Get-Member -Type NoteProperty).name) {

            $Pool = $Request.pools.$Coin

            $Result += [PSCustomObject]@{
                Algorithm             = Get-AlgoUnifiedName ($Pool.xmrStakCurrency -replace "_")
                Info                  = $Pool.coin
                Protocol              = "stratum+tcp"
                Host                  = $Pool.poolHost
                Port                  = $Pool.ports[1].port
                User                  = $CoinsWallets.($Pool.symbol)
                Pass                  = "#WorkerName#"
                Location              = "EU"
                SSL                   = $false
                Symbol                = $Pool.symbol
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolWorkers           = $Request.workers
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = $Pool.symbol
                Fee                   = 0.008
                RewardType            = $RewardType
            }
        }
    }
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
