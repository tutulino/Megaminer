param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$AbbName = 'BM'
$WalletMode = 'WALLET'
$ApiUrl = 'http://blockmasters.co/api'
$MineUrl = 'blockmasters.co'
$Location = 'US'
$RewardType = "PPS"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin on config.ini"
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

    $RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $RequestCurrencies.$_.'24h_blocks' -gt 0 -and
        $RequestCurrencies.$_.hashrate -gt 0 -and
        $RequestCurrencies.$_.workers -gt 0
    } | ForEach-Object {


        $Coin = $RequestCurrencies.$_
        $Pool_Algo = get_algo_unified_name $Coin.algo
        $Pool_Coin = get_coin_unified_name $Coin.name
        $Pool_Symbol = $_

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "Blake2s" {$Divisor *= 1000}
            "Blakecoin" {$Divisor *= 1000}
            "Decred" {$Divisor *= 1000}
            "Equihash" {$Divisor /= 1000}
            "Quark" {$Divisor *= 1000}
            "Qubit" {$Divisor *= 1000}
            "Scrypt" {$Divisor *= 1000}
            "SHA256" {$Divisor *= 1000}
            "X11" {$Divisor *= 1000}
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Coin
            Price                 = [decimal]$Coin.estimate / $Divisor
            Price24h              = [decimal]$Coin.'24h_btc' / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $MineUrl
            Port                  = [int]$Coin.port
            User                  = $CoinsWallets.$Pool_Symbol
            Pass                  = "c=$Pool_Symbol,ID=#WorkerName#"
            Location              = $Location
            SSL                   = $false
            Symbol                = $Pool_Symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = [int]$Coin.workers
            PoolHashRate          = [decimal]$Coin.hashrate
            WalletMode            = $WalletMode
            Walletsymbol          = $Pool_Symbol
            PoolName              = $Name
            Fee                   = $Request.($Coin.algo).fees / 100
            RewardType            = $RewardType
        }
    }
    Remove-Variable Request
    Remove-Variable RequestCurrencies
}


$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
