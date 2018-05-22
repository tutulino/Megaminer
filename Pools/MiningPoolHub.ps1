param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = "MPH"
$WalletMode = "APIKEY"
$RewardType = "PPLS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Registration required, set UserName/WorkerName in config.ini file"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if ($Querymode -eq "APIKEY") {

    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key=" + $Info.ApiKey + "&id=" + "&$(Get-Date -Format "yyyy-MM-dd_HH-mm")") -Retry 3 |
        Select-Object -ExpandProperty getdashboarddata | Select-Object -ExpandProperty data

    if ($Request) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = $Request.balance.confirmed +
            $Request.balance.unconfirmed +
            $Request.balance_for_auto_exchange.confirmed +
            $Request.balance_for_auto_exchange.unconfirmed +
            $Request.balance_on_exchange
        }
        Remove-Variable Request
    }
}

if ($Querymode -eq "SPEED") {

    $Request = Invoke-APIRequest -Url $("https://" + $Info.Symbol + ".miningpoolhub.com/index.php?page=api&action=getuserworkers&api_key=" + $Info.ApiKey + "&$(Get-Date -Format "yyyy-MM-dd_HH-mm")") -Retry 1 |
        Select-Object -ExpandProperty getuserworkers | Select-Object -ExpandProperty data

    if ($Request) {
        $Result = $Request | ForEach-Object {
            if ($_.HashRate -gt 0) {
                [PSCustomObject]@{
                    PoolName   = $name
                    Diff       = $_.difficulty
                    WorkerName = $_.UserName.split('.')[1]
                    HashRate   = $_.HashRate
                }
            }
        }
        Remove-Variable Request
    }
}

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    if (!$UserName) {
        Write-Host "$Name UserName not defined in config.ini"
        Exit
    }

    $MiningPoolHub_Request = Invoke-APIRequest -Url "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics&$(Get-Date -Format "yyyy-MM-dd_HH-mm")" -Retry 3

    if (!$MiningPoolHub_Request) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = "EU", "US", "Asia"

    $MiningPoolHub_Request.return | Where-Object {$_.time_since_last_block -gt 0} | ForEach-Object {

        $MiningPoolHub_Algorithm = Get-AlgoUnifiedName $_.algo
        $MiningPoolHub_Coin = Get-CoinUnifiedName $_.coin_name

        $MiningPoolHub_OriginalCoin = $_.coin_name

        $MiningPoolHub_Hosts = $_.host_list -split ";"
        $MiningPoolHub_Port = $_.port

        $Divisor = [double]1000000000

        $MiningPoolHub_Price = [Double]($_.profit / $Divisor)

        foreach ($Location in $Locations) {

            $Server = $MiningPoolHub_Hosts | Sort-Object {$_ -like "$Location*"} -Descending | Select-Object -First 1

            $enableSSL = ($MiningPoolHub_Algorithm -in @('CryptoNightV7', 'Equihash'))

            if ($MiningPoolHub_Coin -eq 'Electroneum') {$MiningPoolHub_Algorithm = 'CryptoNight'}  # Temporary fix for Cryptonight

            $Result += [PSCustomObject]@{
                Algorithm             = $MiningPoolHub_Algorithm
                Info                  = $MiningPoolHub_Coin
                Price                 = [decimal]$MiningPoolHub_Price
                Price24h              = [decimal]$MiningPoolHub_Price #MPH not send this on api
                Protocol              = "stratum+tcp"
                ProtocolSSL           = "ssl"
                Host                  = $Server
                HostSSL               = $Server
                Port                  = $MiningPoolHub_Port
                PortSSL               = $MiningPoolHub_Port
                User                  = "$UserName.#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $enableSSL
                Symbol                = Get-CoinSymbol -Coin $MiningPoolHub_Coin
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                WalletMode            = $WalletMode
                WalletSymbol          = $MiningPoolHub_OriginalCoin
                PoolName              = $Name
                Fee                   = 0.009 + 0.002 # Pool fee + AutoExchange fee
                EthStMode             = 2
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable MiningPoolHub_Request
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
