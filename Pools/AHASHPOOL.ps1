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
$AbbName = 'AHASH'
$WalletMode ='WALLET'
$RewardType = "PPLS"
$Result = @()





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

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer =  "Autoexchange to @@currency coin specified in config.txt, no registration required"
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
                                $http="http://www.ahashpool.com/api/wallet?address="+$Info.user
                                $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
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
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                            $Request = Invoke-WebRequest "http://www.ahashpool.com/api/status"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 10  | ConvertFrom-Json 
                        }
                        catch {}
                        $retries++
                    if ($Request -eq $null -or $Request -eq "") {start-sleep 5}
                    } while ($Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'AHASHPOOL API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }



        $Currency= if ((get_config_variable "CURRENCY_AHASHPOOL") -eq "") {get_config_variable "CURRENCY"} else {get_config_variable "CURRENCY_AHASHPOOL"}      

        $Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Request | Select-Object -ExpandProperty $_.name
                

                    $Aha_Algorithm = get_algo_unified_name $_.name
            

                    $Divisor = (Get_Algo_Divisor $Aha_Algorithm) / 1000

                
                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Aha_Algorithm
                                Info          = $Aha_Algorithm
                                Price         = $coin.estimate_current / $Divisor
                                Price24h      = $coin.estimate_last24h / $Divisor
                                Protocol      = "stratum+tcp"
                                Host          = $_.name + ".mine.ahashpool.com"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item("BTC")
                                Pass          = "c=BTC,#WorkerName#"
                                Location      = 'US'
                                SSL           = $false
                                Symbol        = $null
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                WalletSymbol    = $currency
                                PoolName = $Name
                                Fee = $Coin.Fees / 100
                                RewardType = $RewardType
                                }
                        
                
                }

  remove-variable Request                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content $info.SharedFile
    remove-variable Result
    
