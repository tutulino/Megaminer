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
$ActiveOnAutomatic24hMode = $false
$AbbName = "MPH"
$WalletMode = "APIKEY"
$RewardType = "PPLS"
$Result = @()

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Registration required, set username/workername in config.txt file"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if ($Querymode -eq "APIKEY") {

    try {
        $http = "https://" + $Info.Symbol + ".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key=" + $Info.ApiKey + "&id="
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json | Select-Object -ExpandProperty getdashboarddata | Select-Object -ExpandProperty data
    } catch {}


    if (![string]::IsNullOrEmpty($Request)) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = $Request.balance.confirmed +
            $Request.balance.unconfirmed +
            $Request.balance_for_auto_exchange.confirmed +
            $Request.balance_for_auto_exchange.unconfirmed +
            $Request.balance_on_exchange
        }
        Remove-variable Request
    }
}


if ($Querymode -eq "SPEED") {

    try {
        $http = "https://" + $Info.Symbol + ".miningpoolhub.com/index.php?page=api&action=getuserworkers&api_key=" + $Info.ApiKey
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5  | ConvertFrom-Json
    } catch {
    }

    if (![string]::IsNullOrEmpty($Request)) {
        $Request.getuserworkers.data | ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Diff       = $_.difficulty
                Workername = ($_.username -split "\.")[1]
                Hashrate   = $_.hashrate
            }
        }
        Remove-variable Request
    }
}

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $retries = 1
    do {
        try {
            $MiningPoolHub_Request = Invoke-WebRequest "https://miningpoolhub.com/index.php?page=api&action=getautoswitchingandprofitsstatistics" -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
        } catch {start-sleep 2}
        $retries++
        if ($MiningPoolHub_Request -eq $null -or $MiningPoolHub_Request -eq "") {start-sleep 3}
    } while ($MiningPoolHub_Request -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = "Europe", "US", "Asia"

    $MiningPoolHub_Request.return | ForEach-Object {

        $MiningPoolHub_Algorithm = get_algo_unified_name $_.algo
        # $MiningPoolHub_Coin = get_coin_unified_name $_.current_mining_coin

        $MiningPoolHub_OriginalCoin = $_.current_mining_coin

        $MiningPoolHub_Hosts = $_.all_host_list.split(";")
        $MiningPoolHub_Port = $_.algo_switch_port

        $Divisor = [double]1000000000

        $MiningPoolHub_Price = [Double]($_.profit / $Divisor)

        $Locations | ForEach-Object {
            $Location = $_

            $enableSSL = ($MiningPoolHub_Algorithm -in @('Cryptonight', 'Equihash'))

            $Result += [PSCustomObject]@{
                Algorithm             = $MiningPoolHub_Algorithm
                Info                  = $null #$MiningPoolHub_Coin
                Price                 = $MiningPoolHub_Price
                Price24h              = $null #MPH not send this on api
                Protocol              = "stratum+tcp"
                ProtocolSSL           = if ($enableSSL) {"stratum+tls"} else {$null}
                Host                  = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                Port                  = $MiningPoolHub_Port
                User                  = "$UserName.#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $enableSSL
                Symbol                = $null #get_coin_symbol -Coin $MiningPoolHub_Coin
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
    Remove-variable MiningPoolHub_Request
}

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
