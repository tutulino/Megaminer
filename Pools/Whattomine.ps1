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

        $Pools=@()

        #Manual Pools zone (you cand add your pools here - wallet for that coins must exists on config.txt)

                 #$Pools +=[pscustomobject]@{"coin" = "PIRL";"algo"="Ethash"; "symbol"= "PIRL";"server"="pirl.minerpool.net"; "port"= "8004";"location"="US";"User"="XXX";"Pass" = "YYY";"fee"="0";"Abbname"="MinerP";"WalletMode"="NONE"}
                        
        #Data from WTM
                try {$WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins} catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING';EXIT}
         
        #search on pools where to mine coins, order is determined by config.txt @@WHATTOMINEPOOLORDER variable
                $ConfigOrder = (get_config_variable "WHATTOMINEPOOLORDER") -split ','
                foreach ($PoolToSearch in $ConfigOrder)  {

                                $HPools=Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location

                                #Filter by minworkes variable (must be here for not selecting now a pool and after that discarded on core.ps1 filter)
                                $HPools = $HPools | Where-Object {$_.Poolworkers -ge (get_config_variable "MINWORKERS") -or $_.Poolworkers -eq $null}
        
                                ForEach ($WtmCoinName in $WTMResponse.psobject.properties.name)  {

                                        $Algorithm=get_algo_unified_name ($WTMResponse.($WtmCoinName).Algorithm)
                                        $Coin= get_coin_unified_name $WtmCoinName

                                        #search if this coin was added before
                                        if (($Result | where-object { $_.Info -eq $coin -and  $_.Algorithm -eq $Algorithm}).count -eq 0)  {
                                            $Hpool = $HPools | where-object { $_.Info -eq $coin -and  $_.Algorithm -eq $Algorithm}
                                            if ($Hpool -ne $null) { #Search if each pool has coin correspondence in WTM        

                                                $WTMFactor = get_WhattomineFactor ($Hpool.Algorithm)

                                                if ($WTMFactor -ne $null) {
                                                                $Result +=[pscustomobject]@{
                                                                        Info            = $Hpool.Info
                                                                        Algorithm       = $Hpool.Algorithm
                                                                        Price           = [Double]($WTMResponse.($_.coin).btc_revenue/$WTMFactor)
                                                                        Price24h        = [Double]($WTMResponse.($_.coin).btc_revenue24/$WTMFactor)
                                                                        symbol          = $WTMResponse.($Hpool.Info).tag
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
