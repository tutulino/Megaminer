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
$AbbName = 'NH'
$WalletMode = "WALLET"
$RewardType = "PPS"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, Autoexchange to BTC always"
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
    $Info.user = ($Info.user -split '\.')[0]
    $Request = Invoke_APIRequest -Url $("https://api.nicehash.com/api?method=stats.provider.workers&addr=" + $Info.user) -Retry 1

    if ($Request.Result.Workers) {
        $Request.Result.Workers | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                WorkerName = $_[0]
                Rejected   = $_[4]
                Hashrate   = [double]$_[1].a * 1000000
            }
        }
        Remove-Variable Request
    }
}


if ($Querymode -eq "wallet") {
    $Info.user = ($Info.user -split '\.')[0]
    $Request = Invoke_APIRequest -Url $("https://api.nicehash.com/api?method=stats.provider&addr=" + $Info.user) -Retry 3

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = "BTC"
            balance  = ($Request.result.stats | Measure-Object -Sum balance).sum
        }
        Remove-Variable Request
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $Request = Invoke_APIRequest -Url "https://api.nicehash.com/api?method=simplemultialgo.info" -Retry 3 |
        Select-Object -expand result | Select-Object -expand simplemultialgo

    if (!$Request) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = @()
    $Locations += [PSCustomObject]@{NhLocation = 'USA'; MMlocation = 'US'}
    $Locations += [PSCustomObject]@{NhLocation = 'EU'; MMlocation = 'EU'}
    $Locations += [PSCustomObject]@{NhLocation = 'HK'; MMlocation = 'Asia'}

    $Request | Where-Object {$_.paying -gt 0} | ForEach-Object {

        $Algo = get_algo_unified_name ($_.name)

        $Divisor = 1000000000

        foreach ($location in $Locations) {

            $enableSSL = ($Algo -in @('Cryptonight', 'Equihash'))

            $Result += [PSCustomObject]@{
                Algorithm             = $Algo
                Info                  = $Algo
                Price                 = [decimal]$_.paying / $Divisor
                Price24h              = [decimal]$_.paying / $Divisor
                Protocol              = "stratum+tcp"
                ProtocolSSL           = if ($enableSSL) {"ssl"} else {$null}
                Host                  = $_.name + "." + $location.NhLocation + ".nicehash.com"
                HostSSL               = $(if ($enableSSL) {$_.name + "." + $location.NhLocation + ".nicehash.com"} else {$null})
                Port                  = $_.port
                PortSSL               = $(if ($enableSSL) {$_.port + 30000} else {$null})
                User                  = $(if ($CoinsWallets.get_item('BTC_NICE') -ne $null) {$CoinsWallets.get_item('BTC_NICE')} else {$CoinsWallets.get_item('BTC')}) + '.' + "#Workername#"
                Pass                  = "x"
                Location              = $location.MMLocation
                SSL                   = $enableSSL
                Symbol                = get_coin_symbol -Coin $Algo
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = "BTC"
                Fee                   = $(if ($CoinsWallets.get_item('BTC_NICE') -ne $null) {0.02} else {0.05})
                EthStMode             = 3
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Request
}


$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
