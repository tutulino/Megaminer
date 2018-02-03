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
$RewardType='PPS'




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
                    RewardType=$RewardType
                         }
    }






#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



    if ($Querymode -eq "wallet")    {
        
                            
                            try {
                                $http="http://api.yiimp.eu/api/wallet?address="+$Info.user
                                $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Request -ne $null -and $Request -ne ""){
                                $Result = [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Request.currency
                                                        balance = $Request.balance
                                                    }
                                    remove-variable Request                                                                                                        
                                    }

                        
                        }
                        
     
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if ($Querymode -eq "speed")    {
        
                            
    try {
        $http="http://api.yiimp.eu/api/walletEx?address="+$Info.user
        $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
    }
    catch {}
    
    $Result=@()

    if ($Request -ne $null -and $Request -ne ""){
            $Request.Miners |ForEach-Object {
                            $Result += [PSCustomObject]@{
                                PoolName =$name
                                Version = $_.version
                                Algorithm = get_algo_unified_name $_.Algo
                                Workername =($_.password -split ",")[1]
                                Diff     = $_.difficulty
                                Rejected = $_.rejected
                                Hashrate = $_.accepted
                          }     
                    }
            remove-variable Request                                                                                                        
            }


}                   


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                            $Request = Invoke-WebRequest "http://api.yiimp.eu/api/currencies"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 5  | ConvertFrom-Json 
                            $Request2 = Invoke-WebRequest "http://api.yiimp.eu/api/status"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 5 | ConvertFrom-Json  

                        }
                        catch {}
                        $retries++
                    if ($Request -eq $null -or $Request -eq "") {start-sleep 5}
                    } while ($Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'YIIMP API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }


        $Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Request | Select-Object -ExpandProperty $_.name
                

                    $Yiimp_Algorithm = get_algo_unified_name $coin.algo
                    $Yiimp_coin =   get_coin_unified_name $coin.name
                    $Yiimp_Symbol=$_.name
            

                    $Divisor = Get_Algo_Divisor $Yiimp_Algorithm
                    
                
                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Yiimp_Algorithm
                                Info          = $Yiimp_coin
                                Price         = [Double]$coin.estimate / $Divisor
                                Price24h      = [Double]$coin.estimate_last24h  / $Divisor
                                Protocol      = "stratum+tcp"
                                Host          = "yiimp.eu"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item($Yiimp_Symbol)
                                Pass          = "c=$Yiimp_symbol,ID=#WorkerName#"
                                Location      = 'US'
                                SSL           = $false
                                Symbol        = $Yiimp_Symbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                Walletsymbol = $Yiimp_Symbol
                                PoolName = $Name
                                Fee = ($Request2.($coin.algo).Fees)/100
                                RewardType=$RewardType
                                }
                        
                
                }

        remove-variable Request                
        remove-variable Request2                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content $info.SharedFile
    remove-variable Result
  
