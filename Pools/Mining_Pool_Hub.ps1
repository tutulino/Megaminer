param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true



if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Registration required, set username/workername in config.txt file"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                         }
    }



    


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){


            try {
                $MiningPoolHub_Request = Invoke-WebRequest "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing | ConvertFrom-Json
            }
            catch {
                    WRITE-HOST 'MINING POOL HUB API NOT RESPONDING...ABORTING'
                    EXIT
            }
            
            if (-not $MiningPoolHub_Request.success) { WRITE-HOST 'MINING POOL HUB API NOT RESPONDING...ABORTING'; EXIT}


            $Locations = "Europe", "US", "Asia"

            $MiningPoolHub_Request.return | ForEach-Object {

                $MiningPoolHub_Algorithm= get-algo-unified-name $_.algo
                $MiningPoolHub_Coin =  get-coin-unified-name $_.coin_name


                $MiningPoolHub_Hosts = $_.host_list.split(";")
                $MiningPoolHub_Port = $_.port
                
                

                $Divisor = 1000000000

                if ((Get-Stat -Name "MiningPoolHub_$($MiningPoolHub_Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "MiningPoolHub_$($MiningPoolHub_Coin)_Profit" -Value ([Double]$_.profit / $Divisor * (1 - 0.05))}
                else {$Stat = Set-Stat -Name "$($Name)_$($MiningPoolHub_Coin)_Profit" -Value ([Double]$_.profit / $Divisor)}


                $Locations | ForEach-Object {
                    $Location = $_
                    
                    [PSCustomObject]@{
                            Algorithm     = $MiningPoolHub_Algorithm
                            Info          = $MiningPoolHub_Coin
                            Price         = $Stat.Live
                            StablePrice   = $Stat.Week
                            MarginOfError = $Stat.Week_Fluctuation
                            Protocol      = "stratum+tcp"
                            Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                            Port          = $MiningPoolHub_Port
                            User          = "$UserName.$WorkerName"
                            Pass          = "x"
                            Location      = $Location
                            SSL           = $false
                            Symbol        = ""
                            AbbName       = "MPH"
                            ActiveOnManualMode    = $ActiveOnManualMode
                            ActiveOnAutomaticMode = $ActiveOnAutomaticMode

                            }
                }

            }
}

