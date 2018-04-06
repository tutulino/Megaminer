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
	$http="https://api.nicehash.com/api?method=stats.provider&addr="+$Info.user
    $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
    $Request = $Request |Select-Object -ExpandProperty result  |Select-Object -ExpandProperty stats 

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            Currency = "BTC"
            Balance  = ($Request | Measure-Object -Sum -Property balance).Sum
        }
        Remove-Variable Request
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    if (!$CoinsWallets.BTC_NICE -and !$CoinsWallets.BTC) {
        Write-Host $Name 'Requires BTC or BTC_NICE wallet in config.ini'
        Exit
    }

    $Request = Invoke_APIRequest -Url "https://api.nicehash.com/api?method=simplemultialgo.info" -Retry 3 |
        Select-Object -expand result | Select-Object -expand simplemultialgo

    if (!$Request) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = @{
        US   = 'USA'
        EU   = 'EU'
        Asia = 'HK'
    }

    $Request | Where-Object {$_.paying -gt 0} | ForEach-Object {

        $Algo = get_algo_unified_name ($_.name)

        $Divisor = 1000000000

        foreach ($location in $Locations.Keys) {

            $enableSSL = ($Algo -in @('CryptoNight', 'CryptoNightV7', 'Equihash'))

            $Result += [PSCustomObject]@{
                Algorithm             = $Algo
                Info                  = $Algo
                Price                 = [decimal]$_.paying / $Divisor
                Price24h              = [decimal]$_.paying / $Divisor
                Protocol              = "stratum+tcp"
                ProtocolSSL           = "ssl"
                Host                  = $_.name + "." + $Locations.$location + ".nicehash.com"
                HostSSL               = $_.name + "." + $Locations.$location + ".nicehash.com"
                Port                  = $_.port
                PortSSL               = $_.port + 30000
                User                  = $(if ($CoinsWallets.BTC_NICE) {$CoinsWallets.BTC_NICE} else {$CoinsWallets.BTC}) + '.' + "#Workername#"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $enableSSL
                Symbol                = get_coin_symbol -Coin $Algo
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = "BTC"
                Fee                   = $(if ($CoinsWallets.BTC_NICE) {0.02} else {0.05})
                EthStMode             = 3
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable Request
}


$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
