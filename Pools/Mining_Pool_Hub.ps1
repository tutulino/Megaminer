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
    }
}


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if ($Querymode -eq "APIKEY") {

    try {
        $ApiKeyPattern = "@@APIKEY_$Name=*"
        $ApiKey = (Get-Content config.txt | Where-Object {$_ -like $ApiKeyPattern} ) -replace $ApiKeyPattern, ''

        $http = "http://" + $Info.OriginalCoin + ".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key=" + $ApiKey + "&id="
        $MiningPoolHub_Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json | Select-Object -ExpandProperty getdashboarddata | Select-Object -ExpandProperty data
    } catch {}


    if ($MiningPoolHub_Request -ne $null -and $MiningPoolHub_Request -ne "") {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Info.Symbol
            balance  = $MiningPoolHub_Request.balance.confirmed + $MiningPoolHub_Request.balance.unconfirmed + $MiningPoolHub_Request.balance_for_auto_exchange.confirmed + $MiningPoolHub_Request.balance_for_auto_exchange.unconfirmed
        }
        Remove-variable MiningPoolHub_Request
    }
}

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    $retries = 1
    do {
        try {
            $MiningPoolHub_Request = Invoke-WebRequest "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
        } catch {start-sleep 2}
        $retries++
        if ($MiningPoolHub_Request -eq $null -or $MiningPoolHub_Request -eq "") {start-sleep 3}
    } while ($MiningPoolHub_Request -eq $null -and $retries -le 3)

    if ($retries -gt 3) {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $Locations = "Europe", "US", "Asia"

    $MiningPoolHub_Request.return | Where-Object {$_.time_since_last_block -gt 0 -and $_.time_since_last_block -lt 86400} | ForEach-Object {

        $MiningPoolHub_Algorithm = get_algo_unified_name $_.algo
        $MiningPoolHub_Coin = get_coin_unified_name $_.coin_name

        $MiningPoolHub_OriginalAlgorithm = $_.algo
        $MiningPoolHub_OriginalCoin = $_.coin_name

        $MiningPoolHub_Hosts = $_.direct_mining_host_list.split(";")
        $MiningPoolHub_Port = $_.direct_mining_algo_port

        $Divisor = [double]1000000000

        $MiningPoolHub_Price = [Double]($_.profit / $Divisor)

        $Locations | ForEach-Object {
            $Location = $_

            $MPH_SSL = $false
            $MPH_Proto = "stratum+tcp"
            if ($MiningPoolHub_Algorithm -in @('Cryptonight', 'Equihash')) {
                $MPH_SSL = $true
                $MPH_Proto = "stratum+tls"
            }

            $Result += [PSCustomObject]@{
                Algorithm             = $MiningPoolHub_Algorithm
                Info                  = $MiningPoolHub_Coin
                Price                 = $MiningPoolHub_Price
                Price24h              = $null #MPH not send this on api
                Protocol              = $MPH_Proto
                Host                  = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                Port                  = $MiningPoolHub_Port
                User                  = "$UserName.#WorkerName#"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $MPH_SSL
                Symbol                = get_coin_symbol -Coin $MiningPoolHub_Coin
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                WalletMode            = $WalletMode
                WalletSymbol          = get_coin_symbol -Coin $MiningPoolHub_Coin
                PoolName              = $Name
                OriginalAlgorithm     = $MiningPoolHub_OriginalAlgorithm
                OriginalCoin          = $MiningPoolHub_OriginalCoin
                Fee                   = 0.009
                EthStMode             = 3
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
