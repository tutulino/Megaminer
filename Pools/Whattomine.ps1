<#
THIS IS A ADVANCED POOL, NOT FOR NOOB.

THIS IS A VIRTUAL POOL, STATISTICS ARE TAKEN FROM WHATTOMINE AND RECALCULATED WITH YOUR BENCHMARKS HASHRATE, YOU CAN SET DESTINATION POOL YOU WANT FOR EACH COIN, BUT REMEMBER YOU MUST HAVE AND ACOUNT IF DESTINATION POOL IS NOT ANONYMOUS POOL
#>



param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )


#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$WalletMode = "MIXED"
$RewardType ='PPS'
$Result=@()


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if ($Querymode -eq "info"){
        $Result=[PSCustomObject]@{
                    Disclaimer = "Based on Whattomine statistics, you must have acount on Suprnova a wallets for each coin on config.txt "
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    ApiData = $true
                    AbbName = 'WTM'
                    WalletMode = $WalletMode
                    RewardType = $RewardType
                          }
    }




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if (($Querymode -eq "speed") )    {
                                
        if ($PoolRealName -ne $null){
                $Info.poolname = $PoolRealName     
                $result = Get_Pools -Querymode "speed" -PoolsFilterList $Info.poolname -Info $Info   
                }
     

         }




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


    if (($Querymode -eq "wallet") -or ($Querymode -eq "APIKEY"))    {
                                
                                if ($PoolRealName -ne $null){
                                        $Info.poolname = $PoolRealName     
                                        $result = Get_Pools -Querymode $info.WalletMode -PoolsFilterList $Info.poolname -Info $Info   | select-object Pool,currency,balance
                                        }
                             
                        
                                 }
        
            

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************




if ($Querymode -eq "core"  -or $Querymode -eq "Menu"){

      
   #Look for pools
        $HPools=@()
        $ConfigOrder = (get_config_variable "WHATTOMINEPOOLORDER") -split ','
        foreach ($PoolToSearch in $ConfigOrder)  {

                        $HPoolsTmp=Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location

                        #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
                        $HPools += $HPoolsTmp | Where-Object {$_.Poolworkers -ge (get_config_variable "MINWORKERS") -or $_.Poolworkers -eq $null}
                }

   #Common Data from WTM
      
   


                #Add main page coins
                try {
                        $WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json?utf8=%E2%9C%93&eth=true&factor%5Beth_hr%5D=1&factor%5Beth_p%5D=0&grof=true&factor%5Bgro_hr%5D=1&factor%5Bgro_p%5D=0&x11gf=true&factor%5Bx11g_hr%5D=1&factor%5Bx11g_p%5D=0&cn=true&factor%5Bcn_hr%5D=1&factor%5Bcn_p%5D=0&eq=true&factor%5Beq_hr%5D=1&factor%5Beq_p%5D=0&lre=true&factor%5Blrev2_hr%5D=1&factor%5Blrev2_p%5D=0&ns=true&factor%5Bns_hr%5D=1&factor%5Bns_p%5D=0&lbry=true&factor%5Blbry_hr%5D=1&factor%5Blbry_p%5D=0&bk14=true&factor%5Bbk14_hr%5D=1&factor%5Bbk14_p%5D=0&pas=true&factor%5Bpas_hr%5D=1&factor%5Bpas_p%5D=0&skh=true&factor%5Bskh_hr%5D=1&factor%5Bskh_p%5D=0&n5=true&factor%5Bn5_hr%5D=1&factor%5Bn5_p%5D=0&factor%5Bl2z_hr%5D=420.0&factor%5Bl2z_p%5D=300.0&factor%5Bcost%5D=0.1&sort=Profitability24&volume=0&revenue=24h&factor%5Bexchanges%5D%5B%5D=&factor%5Bexchanges%5D%5B%5D=abucoins&factor%5Bexchanges%5D%5B%5D=bitfinex&factor%5Bexchanges%5D%5B%5D=bittrex&factor%5Bexchanges%5D%5B%5D=binance&factor%5Bexchanges%5D%5B%5D=cryptopia&factor%5Bexchanges%5D%5B%5D=hitbtc&factor%5Bexchanges%5D%5B%5D=poloniex&factor%5Bexchanges%5D%5B%5D=yobit&dataset=Main&commit=Calculate" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins
                        } 
                catch { 
                        WRITE-HOST 'WTM API NOT RESPONDING...ABORTING'
                        EXIT
                        }
                $WTMCoins=@()
                $WTMResponse.psobject.properties.name  | ForEach-Object {
                        #convert response to collection                
                        $res=$WTMResponse.($_) 
                        $res |add-member name (get_coin_unified_name $_)

                        $res.Algorithm=get_algo_unified_name ($res.Algorithm)
                
                        $WTMCoins += $res
                    }



                try {
                                $WTMResponse2 = Invoke-WebRequest "https://whattomine.com/calculators.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins 
                        } 
                catch { 
                      }
                $WTMSecondaryCoins=@()

                $WTMResponse2.psobject.properties.name  | ForEach-Object {
                        #convert response to collection                
                        $res=$WTMResponse2.($_) 
                        
                        $res |add-member name (get_coin_unified_name $_)
                        
                        $res.Algorithm=get_algo_unified_name ($res.Algorithm)
                        if ($res.Status -eq "Active") {$WTMSecondaryCoins += $res}
                        }


#join pools and coins
       
      
        ForEach ($Hpool in $Hpools)  {

                #we must add units for each algo, this value must be filled if we want a coin to be selected
                switch ($hpool.Algorithm)
                             {
                                     "Ethash"{$WTMFactor=1000000}
                                     "Groestl"{$WTMFactor=1000000}
                                     "Myriad-Groestl"{$WTMFactor=1000000}
                                     "X11Gost"{$WTMFactor=1000000}
                                     "Cryptonight"{$WTMFactor=1}
                                     "equihash"{$WTMFactor=1}
                                     "lyra2v2"{$WTMFactor=1000}
                                     "Neoscrypt"{$WTMFactor=1000}
                                     "Lbry"{$WTMFactor=1000000}
                                     "Blake2b"{$WTMFactor=1000000} 
                                     "Blake14r"{$WTMFactor=1000000}
                                     "Pascal"{$WTMFactor=1000000}
                                     "skunk"{$WTMFactor=1000000}
                                     "nist5"{$WTMFactor=1000000}
                                     "phi"{$WTMFactor=1000000}
                                     default {$null}
                             }
     
     


                if (($Result | where-object { $_.Info -eq $hpool.info -and  $_.Algorithm -eq $hpool.Algorithm}).count -eq 0 -and $WTMFactor -ne $null)  { #look that this coin is not included in result

                        #look for this coin in main page coins
                        $WtmCoin = $WTMCoins  | where-object { $_.name -eq $hpool.info -and  $_.Algorithm -eq $hpool.Algorithm}
                        
                        if ($WtmCoin -eq $null) { #look in secondary coins page

                                $WtmSecCoin = $WTMSecondaryCoins  | where-object { $_.name -eq $hpool.info -and  $_.Algorithm -eq $hpool.Algorithm}
                                if ($WtmSecCoin -ne $null) {
                                        $page="https://whattomine.com/coins/"+$WtmSecCoin.Id+'.json?utf8=✓&hr=1&p=0&fee=0.0&cost=0.1&hcost=0.0&commit=Calculate'
                                        try {$WTMResponse3 += Invoke-WebRequest $page -UseBasicParsing -timeoutsec 4 
                                                $WtmCoin=$WTMResponse3 | ConvertFrom-Json  
                                                $WtmCoin | add-member btc_revenue24 $WtmCoin.btc_revenue
                                            } 
                                        catch {}
                                        
                                        }

                                }
            
                                        $Result +=[pscustomobject]@{
                                                Info            = $hpool.info
                                                Algorithm       = $hpool.Algorithm
                                                Price           = [Double]($WtmCoin.btc_revenue/$WTMFactor)
                                                Price24h        = [Double]($WtmCoin.btc_revenue24/$WTMFactor)
                                                symbol          = $hpool.symbol
                                                Host            = $Hpool.host
                                                port            = $Hpool.port
                                                location        = $Hpool.location
                                                Fee             = $Hpool.Fee
                                                User            = $Hpool.User
                                                Pass            = $Hpool.Pass
                                                protocol        = $Hpool.Protocol
                                                Abbname         = "WTM-"+$Hpool.Abbname
                                                WalletMode      = $Hpool.WalletMode
                                                EthStMode       = $Hpool.EthStMode
                                                WalletSymbol    = $Hpool.WalletSymbol
                                                PoolName        = $Hpool.PoolName
                                                RewardType      = $Hpool.RewardType
                                                ActiveOnManualMode    = $ActiveOnManualMode
                                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode


                                                }
                                        

                        }



                } #end foreach pool




     
                #Add secondary page coins

             


        remove-variable WTMResponse
        remove-variable WTMResponse2
        
        remove-variable HPool
        remove-variable HPools
      

        }

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
