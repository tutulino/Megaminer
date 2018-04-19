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
$AbbName = 'H.RFRY'
$WalletMode = 'WALLET'
$ApiUrl = 'http://pool.hashrefinery.com/api'
$MineUrl = 'us.hashrefinery.com'
$Location = 'US'
$RewardType = "PPS"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to @@currency coin specified in config.ini, no registration required"
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
        $Result = $Request.Miners | ForEach-Object {
            [PSCustomObject]@{
                PoolName   = $Name
                Version    = $_.version
                Algorithm  = get_algo_unified_name $_.Algo
                WorkerName = (($_.password -split 'ID=')[1] -split ',')[0]
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
            Pool     = $Name
            Currency = $Request.currency
            Balance  = $Request.balance
        }
        Remove-Variable Request
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Request = Invoke_APIRequest -Url $($ApiUrl + "/status") -Retry 3
    $RequestCurrencies = Invoke_APIRequest -Url $($ApiUrl + "/currencies") -Retry 3
    if (!$Request -or !$RequestCurrencies) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Currency = if ([string]::IsNullOrEmpty($(get_config_variable "CURRENCY_$Name"))) { get_config_variable "CURRENCY" } else { get_config_variable "CURRENCY_$Name" }

    if (
        $Currency -notin @('BTC', 'LTC') -and
        !($RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object { $_ -eq $Currency })
    ) {
        Write-Host "$Name $Currency not supported for payment"
        Exit
    }

    if (!$CoinsWallets.$Currency) {
        Write-Host "$Name $Currency wallet not defined in config.ini"
        Exit
    }

    $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $Request.$_.actual_last24h -gt 0 -and
        $Request.$_.hashrate -gt 0 -and
        $Request.$_.workers -gt 0
    } | ForEach-Object {

        $Algo = $Request.$_
        $Pool_Algo = get_algo_unified_name $Algo.name

        $Divisor = 1000000


        switch ($Pool_Algo) {
            "blake2s" {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "sha256" {$Divisor *= 1000}
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Algo
            Price                 = [decimal]$Algo.estimate_current / $Divisor
            Price24h              = [decimal]$Algo.estimate_last24h / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $Algo.name + "." + $MineUrl
            Port                  = $Algo.port
            User                  = $CoinsWallets.$Currency
            Pass                  = "c=$Currency,ID=#Workername#"
            Location              = $Location
            SSL                   = $false
            Symbol                = get_coin_symbol -Coin $Pool_Algo
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $Algo.workers
            PoolHashRate          = $Algo.hashrate
            WalletMode            = $WalletMode
            WalletSymbol          = $Currency
            PoolName              = $Name
            Fee                   = $Algo.fees / 100
            RewardType            = $RewardType
        }
    }
    Remove-Variable Request
}


$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
