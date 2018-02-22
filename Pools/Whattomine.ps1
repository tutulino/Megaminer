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
                    WalletMode =$WalletMode
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

      
   #Data from WTM
                $WTMResponse2=@()

                #Add main page coins
                try {$WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins} catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING';EXIT}
                $WTMResponse.psobject.properties.name  | ForEach-Object {

                $res=$WTMResponse.($_) 
                $res |add-member name $_
                $WTMResponse2 += $res
                }




                try {$WTMResponse = Invoke-WebRequest "http://whattomine.com/calculators.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins } catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING';EXIT}


                #Add secondary page coins

                $WTMResponse.psobject.properties.name | ForEach-Object {

                        if ($WTMResponse.($_).Status -eq "Active") {
                        $Id = $WTMResponse.($_).Id
                        $exists= $WTMResponse2 | Where-Object id -eq $Id
                        if ($exists.count -eq 0) {
                                $page="https://whattomine.com/coins/"+$WTMResponse.($_).Id+".json"
                                try {$WTMResponse2 += Invoke-WebRequest $page -UseBasicParsing -timeoutsec 2 | ConvertFrom-Json  } catch {}
                                }
                        }
                }
                


                        
        #search on pools where to mine coins, order is determined by config.txt @@WHATTOMINEPOOLORDER variable
                $ConfigOrder = (get_config_variable "WHATTOMINEPOOLORDER") -split ','
                foreach ($PoolToSearch in $ConfigOrder)  {

                                $HPools=Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location

                                #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
                                $HPools = $HPools | Where-Object {$_.Poolworkers -ge (get_config_variable "MINWORKERS") -or $_.Poolworkers -eq $null}
        
                                ForEach ($WtmCoinName in $WTMResponse2)  {

                                        $Algorithm=get_algo_unified_name ($WtmCoinName.Algorithm)
                                        $Coin= get_coin_unified_name ($WtmCoinName.name)

                                        #search if this coin was added before
                                        if (($Result | where-object { $_.Info -eq $coin -and  $_.Algorithm -eq $Algorithm}).count -eq 0)  {
                                            $Hpool = $HPools | where-object { $_.Info -eq $coin -and  $_.Algorithm -eq $Algorithm}
                                            if ($Hpool -ne $null) { #Search if each pool has coin correspondence in WTM        

                                                $WTMFactor = get_WhattomineFactor $Algorithm

                                                if ($WTMFactor -ne $null) {
                                                                $Result +=[pscustomobject]@{
                                                                        Info            = $Coin
                                                                        Algorithm       = $Algorithm
                                                                        Price           = [Double]($WtmCoinName.btc_revenue/$WTMFactor)
                                                                        Price24h        = [Double]($WtmCoinName.btc_revenue24/$WTMFactor)
                                                                        symbol          = $WtmCoinName.tag
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

                                            }


                                        }

                                

                                        } #end foreach coin

                    
                }  #end for each PoolToSearch     

     


        remove-variable WTMResponse
        remove-variable HPools
      

        }

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
