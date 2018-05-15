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
$AbbName = 'UNI'
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
                                $http="http://pool.unimining.net/api/wallet?address="+$Info.user
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
        $http="http://www.ahashpool.com/api/walletEx?address="+$Info.user
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
                            $Request = Invoke-WebRequest "http://pool.unimining.net/api/currencies"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 20
                            $Request = $Request | ConvertFrom-Json 
                             #$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json

                        }
                        catch {}
                        $retries++
                    if ($Request -eq $null -or $Request -eq "") {start-sleep 5}
                    } while ($Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'UNIMINING API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }


        $Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Request | Select-Object -ExpandProperty $_.name
                

                    $Uni_Algorithm = get_algo_unified_name $coin.algo
                    $Uni_coin =  get_coin_unified_name $coin.name
                    $Uni_Simbol=$_.name
            

                    $Divisor = Get_Algo_Divisor $Uni_Algorithm
                    
                

                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Uni_Algorithm
                                Info          = $Uni_coin
                                Price         = [Double]$coin.estimate / $Divisor
                                Price24h      = [Double]$coin."24h_btc" / $Divisor
                                Protocol      = "stratum+tcp"
                                Host          = if ($Uni_Simbol -eq 'XVG' -and $Uni_Algorithm -eq 'Blake2s') 
                                                    {"xvg.eu1.unimining.net"} 
                                                else  
                                                    {"pool.unimining.net"}
                                Port          = switch ($Uni_Simbol) {
                                                        "RVN"{3638}
                                                        "MTN"{3637}
                                                        "SGL"{4241}
                                                        "DSR"{4234}	
                                                        "DIN"{4245}
                                                        "GOA"{4240}	
                                                        "FTC"{4246}	
                                                        "TZC"{4237}	
                                                        "CBS"{4244}	
                                                        "CRC"{4238}	 
                                                        "RAP"{4242}
                                                        "INN"{4235}	
                                                        "GBX"{4236}
                                                        "LBC"{3334}
                                                        default {$coin.port}
                                                        }
                                User          = $CoinsWallets.get_item($Uni_Simbol)
                                Pass          = "c=$Uni_symbol,ID=#WorkerName#"
                                Location      = 'US'
                                SSL           = $false
                                Symbol        = $Uni_Simbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                WalletSymbol = $Uni_Simbol
                                PoolName = $Name
                                Fee = $coin.Fees/100
                                RewardType=$RewardType
                                }
                        
                
                }

  remove-variable Request                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content $info.SharedFile
    remove-variable Result
    
