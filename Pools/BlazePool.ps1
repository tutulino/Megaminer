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
$AbbName = 'BLAZ'
$WalletMode = 'WALLET'
$ApiUrl = 'http://api.blazepool.com/'
$MineUrl = 'mine.blazepool.com'
$Location = 'US'
$RewardType = "PPS"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Autoexchange to BTC wallet, no registration required"
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
    # $Request = Invoke_APIRequest -Url $($ApiUrl + "/walletEx?address=" + $Info.user) -Retry 1

    # if ($Request) {
    #     $Result = $Request.Miners | ForEach-Object {
    #         [PSCustomObject]@{
    #             PoolName   = $Name
    #             Version    = $_.version
    #             Algorithm  = get_algo_unified_name $_.Algo
    #             WorkerName = (($_.password -split 'ID=')[1] -split ',')[0]
    #             Diff       = $_.difficulty
    #             Rejected   = $_.rejected
    #             Hashrate   = $_.accepted
    #         }
    #     }
    #     Remove-Variable Request
    # }
}


if ($Querymode -eq "wallet") {
    $Request = Invoke_APIRequest -Url $($ApiUrl + "/wallet/" + $Info.user) -Retry 3

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

    if (!$CoinsWallets.BTC) {
        Write-Host "$Name BTC wallet not defined in config.ini"
        Exit
    }

    $Request = Invoke_APIRequest -Url $($ApiUrl + "/status") -Retry 3
    if (!$Request) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }


    $Currency = if ([string]::IsNullOrEmpty($(get_config_variable "CURRENCY_$Name"))) { get_config_variable "CURRENCY" } else { get_config_variable "CURRENCY_$Name" }

    $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $Request.$_.actual_last24h -gt 0 -and
        $Request.$_.hashrate -gt 0 -and
        $Request.$_.workers -gt 0
    } | ForEach-Object {

        $Algo = $Request.$_
        $Pool_Algo = get_algo_unified_name $Algo.name

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "Blake2s" {$Divisor *= 1000}
            "Blakecoin" {$Divisor *= 1000}
            "Decred" {$Divisor *= 1000}
            "Keccak" {$Divisor *= 1000}
            "Quark" {$Divisor *= 1000}
            "Qubit" {$Divisor *= 1000}
            "Scrypt" {$Divisor *= 1000}
            "SHA256" {$Divisor *= 1000000}
            "X11" {$Divisor *= 1000}
            "Yescrypt" {$Divisor /= 1000}
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Algo
            Price                 = [decimal]$Algo.estimate_current / $Divisor
            Price24h              = [decimal]$Algo.estimate_last24h / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $Algo.name + "." + $MineUrl
            Port                  = $Algo.port
            User                  = $CoinsWallets.BTC
            Pass                  = "c=BTC,ID=#WorkerName#"
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
