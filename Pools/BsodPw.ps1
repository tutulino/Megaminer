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
$ActiveOnAutomatic24hMode = $false
$AbbName = 'BSOD'
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
                                $http="http://api.bsod.pw/api/wallet?address="+$Info.user
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
        $http="http://api.bsod.pw/api/walletEx?address="+$Info.user
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
                            $Request = Invoke-WebRequest "http://api.bsod.pw/api/currencies"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 8  | ConvertFrom-Json 
                            start-sleep 5
                            $Request2 = Invoke-WebRequest "http://api.bsod.pw/api/status"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 8 | ConvertFrom-Json  

                        }
                        catch {}
                        $retries++
                    if ($Request -eq $null -or $Request -eq "" -or $Request2 -eq $null -or $Request2 -eq "") {start-sleep 5}
                    } while (($Request -eq $null -or $Request2 -eq $null ) -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'BSOD API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }


        $Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Request | Select-Object -ExpandProperty $_.name
                

                    $Bsod_Algorithm = get_algo_unified_name $coin.algo
                    $Bsod_coin =   get_coin_unified_name $coin.name
                    $Bsod_Symbol=$_.name
            

                    $Divisor = Get_Algo_Divisor $Bsod_Algorithm
                    
                
                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Bsod_Algorithm
                                Info          = $Bsod_coin
                                Price         = [Double]$coin.estimate / $Divisor
                                Price24h      = [Double]$coin.estimate  / $Divisor # not available 
                                Protocol      = "stratum+tcp"
                                Host          = "pool.bsod.pw"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item($Bsod_Symbol)
                                Pass          = "c=$Bsod_symbol,ID=#WorkerName#"
                                Location      = 'EU'
                                SSL           = $false
                                Symbol        = $Bsod_Symbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                Walletsymbol = $Bsod_Symbol
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
  
