param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null ,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'YIIMP'
$WalletMode ='WALLET'
$Result = @()




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer = "No registration, No autoexchange, need wallet for each coin on config.txt"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    ApiData = $True
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }






#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



    if ($Querymode -eq "wallet")    {
        
                            
                            try {
                                $http="http://api.yiimp.eu/api/wallet?address="+$Info.user
                                $Yiimp_Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Yiimp_Request -ne $null -and $Yiimp_Request -ne ""){
                                $Result = [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Yiimp_Request.currency
                                                        balance = $Yiimp_Request.balance
                                                    }
                                    remove-variable Yiimp_Request                                                                                                        
                                    }

                        
                        }
                        
                        


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                            $Yiimp_Request = Invoke-WebRequest "http://api.yiimp.eu/api/currencies"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 5 
                            $Yiimp_Request = $Yiimp_Request | ConvertFrom-Json 
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

                $coin=$Yiimp_Request | Select-Object -ExpandProperty $_.name
                

                    $Yiimp_Algorithm = get-algo-unified-name $coin.algo
                    $Yiimp_coin =  get-coin-unified-name $coin.name
                    $Yiimp_Simbol=$_.name
            

                    $Divisor = Get-Algo-Divisor $Yiimp_Algorithm
                    
                

                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Yiimp_Algorithm
                                Info          = $Yiimp_coin
                                Price         = [Double]$coin.estimate / $Divisor
                                Price24h      = [Double]$coin.actual_last24h / $Divisor
                                Protocol      = "stratum+tcp"
                                Host          = "yiimp.eu"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item($Yiimp_Simbol)
                                Pass          = "c=$Yiimp_symbol,ID=$WorkerName"
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
                                Fee = $coin.fees/100
                                }
                        
                
                }

  remove-variable Yiimp_Request                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content ("$name.tmp")
    remove-variable Result
  
