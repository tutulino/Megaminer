param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
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
        Disclaimer               = "Registration required, set username/workername in config.ini file"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if ($Querymode -eq "APIKEY") {

    $Request = Invoke_APIRequest -Url $("https://" + $Info.Symbol + ".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key=" + $Info.ApiKey + "&id=") -Retry 3 |
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

    $Request = Invoke_APIRequest -Url $("https://" + $Info.Symbol + ".miningpoolhub.com/index.php?page=api&action=getuserworkers&api_key=" + $Info.ApiKey) -Retry 1 |
        Select-Object -ExpandProperty getuserworkers | Select-Object -ExpandProperty data

    if ($Request) {
        $Result = $Request | ForEach-Object {
            if ($_.hashrate -gt 0) {
                [PSCustomObject]@{
                    PoolName   = $name
                    Diff       = $_.difficulty
                    Workername = $($_.username -split '.')[1]
                    Hashrate   = $_.hashrate
                }
            }
        }
        Remove-Variable Request
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    if (!$UserName) {
        Write-Host $Name 'Requires USERNAME in config.ini'
        Exit
    }

    $MiningPoolHub_Request = Invoke_APIRequest -Url "https://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -Retry 3

    if (!$MiningPoolHub_Request) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = "EU", "US", "Asia"

    $MiningPoolHub_Request.return | Where-Object {$_.time_since_last_block -gt 0} | ForEach-Object {

        $MiningPoolHub_Algorithm = get_algo_unified_name $_.algo
        $MiningPoolHub_Coin = get_coin_unified_name $_.coin_name

        $MiningPoolHub_OriginalCoin = $_.coin_name

        $MiningPoolHub_Hosts = $_.host_list.split(";")
        $MiningPoolHub_Port = $_.port

        $Divisor = [double]1000000000

        $MiningPoolHub_Price = [Double]($_.profit / $Divisor)

        foreach ($Location in $Locations) {

            $Server = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
            $IP =  ([Net.DNS]::Resolve($Server).AddressList.IPAddressToString | Select-Object -First 1)

            $enableSSL = ($MiningPoolHub_Algorithm -in @('CryptoNight', 'Equihash'))

            if ($MiningPoolHub_Coin -eq 'Monero') {$MiningPoolHub_Algorithm = 'CryptoNightV7'}

            $Result += [PSCustomObject]@{
                Algorithm             = $MiningPoolHub_Algorithm
                Info                  = $MiningPoolHub_Coin
                Price                 = [decimal]$MiningPoolHub_Price
                Price24h              = [decimal]$MiningPoolHub_Price #MPH not send this on api
                Protocol              = "stratum+tcp"
                ProtocolSSL           = "ssl"
                Host                  = $IP
                HostSSL               = $IP
                Port                  = $MiningPoolHub_Port
                PortSSL               = $MiningPoolHub_Port
                User                  = "$UserName.#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $enableSSL
                Symbol                = get_coin_symbol -Coin $MiningPoolHub_Coin
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                WalletMode            = $WalletMode
                WalletSymbol          = $MiningPoolHub_OriginalCoin
                PoolName              = $Name
                Fee                   = 0.009
                EthStMode             = 2
                RewardType            = $RewardType
            }
        }
    }
    Remove-Variable MiningPoolHub_Request
}


$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
