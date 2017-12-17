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

    $MiningPoolHub_Request.return |
        Where-Object {$_.time_since_last_block -gt 0 -and $_.time_since_last_block -lt 86400} |
        Group-Object algo |
        ForEach-Object { $_.Group | Sort-Object -Descending profit | Select-Object -First 1} |
        ForEach-Object {

        $MiningPoolHub_Algorithm = get-algo-unified-name $_.algo

        $MiningPoolHub_Hosts = $_.direct_mining_host_list.split(";")
        $MiningPoolHub_Port = $_.direct_mining_algo_port

        $Divisor = [double]1000000000

        $MiningPoolHub_Price = [Double]($_.profit / $Divisor)

        $Locations | ForEach-Object {
            $Location = $_

            $Result += [PSCustomObject]@{
                Algorithm             = $MiningPoolHub_Algorithm
                Info                  = $null
                Price                 = $MiningPoolHub_Price
                Price24h              = $null #MPH not send this on api
                Protocol              = "stratum+tcp"
                Host                  = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                Port                  = $MiningPoolHub_Port
                User                  = "$UserName.$WorkerName"
                Pass                  = "x"
                Location              = $Location
                SSL                   = $false
                Symbol                = $null
                AbbName               = $AbbName
                ActiveOnManualMode    = $ActiveOnManualMode
                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                WalletMode            = $WalletMode
                PoolName              = $Name
                Fee                   = 0.009
            }
        }
    }
    Remove-variable MiningPoolHub_Request
}

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content ("$name.tmp")
remove-variable Result
