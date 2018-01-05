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
$AbbName = 'NH'
$WalletMode = "WALLET"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "No registration, Autoexchange to BTC always"
        ActiveOnManualMode    = $ActiveOnManualMode
        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
        ApiData               = $True
        AbbName               = $AbbName
        WalletMode            = $WalletMode
    }
}


if ($Querymode -eq "wallet") {
    $Info.user = ($Info.user -split '\.')[0]
    try {
        $http = "https://api.nicehash.com/api?method=stats.provider&addr=" + $Info.user
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json |Select-Object -ExpandProperty result  |Select-Object -ExpandProperty stats
    } catch {}

    if ($Request -ne $null -and $Request -ne "") {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = "BTC"
            balance  = ($Request | Measure-Object -Sum balance).sum
        }
    }
    Remove-variable Request
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $retries = 1
    do {
        try {
            $http = "https://api.nicehash.com/api?method=simplemultialgo.info"
            $Request = Invoke-WebRequest $http -UseBasicParsing -TimeoutSec 5 | ConvertFrom-Json |Select-Object -expand result |Select-Object -expand simplemultialgo
        } catch {start-sleep 2}
        $retries++
        if ($Request -eq $null -or $Request -eq "") {start-sleep 3}
    } while ($Request -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = @()
    $Locations += [PSCustomObject]@{NhLocation = 'USA'; MMlocation = 'US'}
    $Locations += [PSCustomObject]@{NhLocation = 'EU'; MMlocation = 'Europe'}

    $Request | Where-Object {$_.paying -gt 0 } | ForEach-Object {

        $Algo = get_algo_unified_name ($_.name)
        $AlgoOriginal = $_.name

        $Divisor = 1000000000

        foreach ($location in $Locations) {

            $Result += [PSCustomObject]@{
                Algorithm             = $Algo
                Info                  = $coin
                Price                 = [double]($_.paying / $Divisor)
                Price24h              = $null
                Protocol              = "stratum+tcp"
                Host                  = $AlgoOriginal + "." + $location.NhLocation + ".nicehash.com"
                Port                  = $_.port
                User                  = $(if ($CoinsWallets.get_item('BTC_NICE') -ne $null) {$CoinsWallets.get_item('BTC_NICE')} else {$CoinsWallets.get_item('BTC')}) + '.' + "#Workername#"
                Pass                  = "x"
                Location              = $location.MMLocation
                SSL                   = $false
                Symbol                = $null
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                PoolName              = $Name
                WalletMode            = $WalletMode
                WalletSymbol          = "BTC"
                OriginalAlgorithm     = $AlgoOriginal
                OriginalCoin          = $coin
                EthStMode             = 3

            }
        }
    }
    Remove-variable Request
}


$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-variable Result
