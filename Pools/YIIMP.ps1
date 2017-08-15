param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null 
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$AbbName = 'YIIMP'


if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "No registration, No autoexchange, need wallet for each coin on config.txt"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ApiData = $True
                    AbbName=$AbbName
                         }
    }


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        try {
            $Yiimp_Request = Invoke-WebRequest "http://yiimp.ccminer.org/api/currencies" -UseBasicParsing | ConvertFrom-Json 
            #$Yiimp_Request=get-content "..\Yiimp_request.json" | ConvertFrom-Json
        }
        catch {
                    WRITE-HOST 'YIIMP API NOT RESPONDING...ABORTING'
                    EXIT
                }

        $Locations = "US"

        $Yiimp_Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Yiimp_Request | select -ExpandProperty $_.name
                

                    $Yiimp_Algorithm = get-algo-unified-name $coin.algo
                    $Yiimp_coin =  get-coin-unified-name $coin.name
                    $Yiimp_Simbol=$_.name
            

                    $Divisor = Get-Algo-Divisor $Yiimp_Algorithm
                    
                

                    if ((Get-Stat -Name "Yiimp_$($Yiimp_Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "Yiimp_$($Yiimp_Coin)_Profit" -Value ([Double]$coin.estimate / $Divisor * (1 - 0.05))}
                    else {$Stat = Set-Stat -Name "$($Name)_$($Yiimp_Coin)_Profit" -Value ([Double]$coin.estimate / $Divisor)}

                            
                            [PSCustomObject]@{
                                Algorithm     = $Yiimp_Algorithm
                                Info          = $Yiimp_coin
                                Price         = $Stat.Live
                                StablePrice   = $Stat.Week
                                MarginOfError = $Stat.Week_Fluctuation
                                Protocol      = "stratum+tcp"
                                Host          = "yiimp.ccminer.org"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item($Yiimp_Simbol)
                                Pass          = "c=$Yiimp_symbol,ID=$WorkerName,stats"
                                Location      = $Location
                                SSL           = $false
                                Symbol        = $Yiimp_Simbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                }
                        
                
                }
    }

