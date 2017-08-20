param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $false
$AbbName="MPH"
$WalletMode="APIKEY"


if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Registration required, set username/workername in config.txt file"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }



    

    if ($Querymode -like "wallet_*")    {
        
                            $Server=($Querymode -split '_')[1]
                            $Coin=($Querymode -split '_')[2]  
                            $ApiKey=($Querymode -split '_')[3]  
                            $Algo=($Querymode -split '_')[4]  

                            Switch($coin) {
                                "DigiByte" {$Coin=$coin+'-'+$Algo}
                                "Myriad" {$Coin=$coin+'-'+$Algo}
                                "Verge" {$Coin=$coin+'-'+$Algo}
                                }

                            
                            try {
                                $http="http://"+$Coin+".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key="+$ApiKey+"&id="
                                #$http |write-host                                
                                $MiningPoolHub_Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty getdashboarddata | Select-Object -ExpandProperty data

                        
                            }
                            catch {}
        
        
                            if ($MiningPoolHub_Request -ne $null -and $MiningPoolHub_Request -ne ""){
                                        [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $MiningPoolHub_Request.currency
                                                        balance = $MiningPoolHub_Request.balance.confirmed+$MiningPoolHub_Request.balance.unconfirmed+$MiningPoolHub_Request.balance_for_auto_exchange.confirmed+$MiningPoolHub_Request.balance_for_auto_exchange.unconfirmed
                                                    }
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

                $MiningPoolHub_OriginalAlgorithm=  $_.algo
                $MiningPoolHub_OriginalCoin=  $_.coin_name


                $MiningPoolHub_Hosts = $_.host_list.split(";")
                $MiningPoolHub_Port = $_.port

                $Divisor = [double]1000000000
    
                $MiningPoolHub_Price=[Double]($_.profit / $Divisor)

                $Locations | ForEach-Object {
                    $Location = $_
                    
                    [PSCustomObject]@{
                            Algorithm     = $MiningPoolHub_Algorithm
                            Info          = $MiningPoolHub_Coin
                            Price         = $MiningPoolHub_Price
                            Price24h      = $null #MPH not send this on api
                            Protocol      = "stratum+tcp"
                            Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                            Port          = $MiningPoolHub_Port
                            User          = "$UserName.$WorkerName"
                            Pass          = "x"
                            Location      = $Location
                            SSL           = $false
                            Symbol        = ""
                            AbbName       = $AbbName
                            ActiveOnManualMode    = $ActiveOnManualMode
                            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                            WalletMode     = $WalletMode
                            PoolName = $Name
                            OriginalAlgorithm = $MiningPoolHub_OriginalAlgorithm
                            OriginalCoin = $MiningPoolHub_OriginalCoin

                            }
                }

            }
}

