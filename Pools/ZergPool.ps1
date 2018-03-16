param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'ZERG'
$WalletMode = 'WALLET'
$ApiUrl = 'http://api.zergpool.com:8080/api'
$RewardType = "PPS"
$Result = @()

$StratumServers = @()
$StratumServers += [PSCustomObject]@{Location = 'US'; MineUrl = 'mine.zergpool.com'}
$StratumServers += [PSCustomObject]@{Location = 'EU'; MineUrl = 'europe.mine.zergpool.com'}

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to @@currency coin specified in config.txt, no registration required"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $True
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if ($Querymode -eq "speed") {
    $Request = Invoke_APIRequest -Url $($ApiUrl + "/walletEx?address=" + $Info.user) -Retry 1

    if ($Request) {
        $Request.Miners |ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Version    = $_.version
                Algorithm  = get_algo_unified_name $_.Algo
                Workername = (($_.password -split 'ID=')[1] -split ',')[0]
                Diff       = $_.difficulty
                Rejected   = $_.rejected
                Hashrate   = $_.accepted
            }
        }
        Remove-Variable Request
    }
}


if ($Querymode -eq "wallet") {
    $Request = Invoke_APIRequest -Url $($ApiUrl + "/wallet?address=" + $Info.user) -Retry 3

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Request.currency
            balance  = $Request.balance
        }
        Remove-Variable Request
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Request = Invoke_APIRequest -Url $($ApiUrl + "/status") -Retry 3
    if (!$Request) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Currency = if ([string]::IsNullOrEmpty($(get_config_variable "CURRENCY_$Name"))) { get_config_variable "CURRENCY" } else { get_config_variable "CURRENCY_$Name" }

    ### Option 1 - Mine in particular algorithm
    $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $Request.$_.actual_last24h -gt 0 -and
        $Request.$_.hashrate -gt 0 -and
        $Request.$_.workers -gt 0
    } | ForEach-Object {
        $Coin = $Request.$_
        $Pool_Algo = get_algo_unified_name $Coin.name

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "Blake2s" {$Divisor *= 1000}
            "Blakecoin" {$Divisor *= 1000}
            "BlakeVanilla" {$Divisor *= 1000}
            "Decred" {$Divisor *= 1000}
            "Equihash" {$Divisor /= 1000}
            "Keccak" {$Divisor *= 1000}
            "KeccakC" {$Divisor *= 1000}
            "Quark" {$Divisor *= 1000}
            "Qubit" {$Divisor *= 1000}
            "Scrypt" {$Divisor *= 1000}
            "SHA256" {$Divisor *= 1000}
            "SHA256t" {$Divisor *= 1000}
            "X11" {$Divisor *= 1000}
            "Yescrypt" {$Divisor /= 1000}
            "YescryptR16" {$Divisor /= 1000}
        }

        foreach ($stratum in $StratumServers) {
            $Result += [PSCustomObject]@{
                Algorithm             = $Pool_Algo
                Info                  = $Pool_Algo
                Price                 = $Coin.estimate_current / $Divisor
                Price24h              = $Coin.estimate_last24h / $Divisor
                Protocol              = "stratum+tcp"
                Host                  = $stratum.MineUrl
                Port                  = $Coin.port
                User                  = $CoinsWallets.get_item($Currency)
                Pass                  = "c=$Currency,ID=#WorkerName#"
                Location              = $stratum.Location
                SSL                   = $false
                Symbol                = get_coin_symbol -Coin $Pool_Algo
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolWorkers           = $Coin.workers
                PoolHashRate          = $Coin.hashrate
                WalletMode            = $WalletMode
                WalletSymbol          = $Currency
                PoolName              = $Name
                Fee                   = $Coin.fees / 100
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Request
}

$Result | ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result
