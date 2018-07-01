param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName= 'H.RFRY'
$WalletMode='WALLET'
$Result=@()
$RewardType='PPS'



#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if ($Querymode -eq "info"){
    $Result= [PSCustomObject]@{
                    Disclaimer = "Autoexchange to @@currency coin specified in config.txt, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
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
                                $http="http://pool.hashrefinery.com/api/wallet?address="+$Info.user
                                $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Request -ne $null -and $Request -ne ""){
                                $Result=  [PSCustomObject]@{
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
                                $http="http://pool.hashrefinery.com/api/walletEx?address="+$Info.user
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
                    $Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
               
                }
                catch {start-sleep 2}
                $retries++
                if ($Request -eq $null -or $Request -eq "") {start-sleep 3}
            } while ($Request -eq $null -and $retries -le 3)
        
        if ($retries -gt 3) {
                            WRITE-HOST 'HASHREFINERY API NOT RESPONDING...ABORTING'
                            EXIT
                            }








        if ($Request -ne $null) {

                        $Currency= if ((get_config_variable "CURRENCY_HASHREFINERY") -eq "") {get_config_variable "CURRENCY"} else {get_config_variable "CURRENCY_HASHREFINERY"}                                    



                        $Request | Get-Member -MemberType properties| ForEach-Object {
                                
                            $coin=$Request | Select-Object -ExpandProperty $_.name

                            $HR_Algo =  get_algo_unified_name ($_.name)

                        
                            $Divisor = 1000000 * $coin.mbtc_mh_factor



                    
                            
                                $Result += [PSCustomObject]@{
                                                Algorithm =  $HR_Algo
                                                Info = $null
                                                Price = $coin.estimate_current/$Divisor
                                                Price24h =$coin.estimate_last24h/$Divisor
                                                Protocol = "stratum+tcp"
                                                Host = $_.name+".us.hashrefinery.com"
                                                Port = $coin.port
                                                User = $CoinsWallets.get_item($currency)
                                                Pass = "c=$Currency,#WorkerName#"
                                                Location = "US"
                                                SSL = $false
                                                AbbName = $AbbName
                                                ActiveOnManualMode    = $ActiveOnManualMode
                                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                                PoolWorkers = $coin.workers
                                                WalletMode=$WalletMode
                                                WalletSymbol    = $currency
                                                PoolName = $Name
                                                Fee = $coin.Fees/100
                                                RewardType=$RewardType
                                    
                                }
                            
                                
                        }
       }

}


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-variable Result
