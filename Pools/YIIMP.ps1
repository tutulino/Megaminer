param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null 
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $false
$AbbName = 'YIIMP'
$WalletMode ='WALLET'


if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "No registration, No autoexchange, need wallet for each coin on config.txt"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    ApiData = $True
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }








    if ($Querymode -like "wallet_*")    {
        
                            $Wallet=($Querymode -split '_')[1]
                            try {
                                $http="http://yiimp.ccminer.org/api/wallet?address="+$wallet
                                $Yiimp_Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Yiimp_Request -ne $null -and $Yiimp_Request -ne ""){
                                        [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Yiimp_Request.currency
                                                        balance = $Yiimp_Request.balance
                                                    }
                                    }
                        }
                        
                        

    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                             $Yiimp_Request = Invoke-WebRequest "http://yiimp.ccminer.org/api/currencies" -UseBasicParsing -timeout 5 | ConvertFrom-Json 
                             #$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json
                        }
                        catch {}
                        $retries++
                    if ($Yiimp_Request -eq $null -or $Yiimp_Request -eq "") {start-sleep 5}
                    } while ($Yiimp_Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'YIIMP API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }


        $Yiimp_Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Yiimp_Request | select -ExpandProperty $_.name
                

                    $Yiimp_Algorithm = get-algo-unified-name $coin.algo
                    $Yiimp_coin =  get-coin-unified-name $coin.name
                    $Yiimp_Simbol=$_.name
            

                    $Divisor = Get-Algo-Divisor $Yiimp_Algorithm
                    
                

                            [PSCustomObject]@{
                                Algorithm     = $Yiimp_Algorithm
                                Info          = $Yiimp_coin
                                Price         = [Double]$coin.estimate / $Divisor
                                Price24h      = $null
                                Protocol      = "stratum+tcp"
                                Host          = "yiimp.ccminer.org"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item($Yiimp_Simbol)
                                Pass          = "c=$Yiimp_symbol,ID=$WorkerName,stats"
                                Location      = 'US'
                                SSL           = $false
                                Symbol        = $Yiimp_Simbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                PoolName = $Name
                                }
                        
                
                }
    }

