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


    if (($Querymode -eq "wallet") -or ($Querymode -eq "APIKEY"))    {
                                
                                if ($PoolRealName -ne $null){
                                        $Info.poolname = $PoolRealName     
                                        $result = Get_Pools -Querymode $info.WalletMode -PoolsFilterList $Info.poolname -Info $Info   | select-object Pool,currency,balance
                                        }
                             
                        
                                 }
        
            




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************






if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $Pools=@()

        #Manual Pools zone (you cand add your pools here - wallet for that coins must exists on config.txt)

                 #$Pools +=[pscustomobject]@{"coin" = "PIRL";"algo"="Ethash"; "symbol"= "PIRL";"server"="pirl.minerpool.net"; "port"= "8004";"location"="US";"User"="XXX";"Pass" = "YYY";"fee"="0";"Abbname"="MinerP";"WalletMode"="NONE"}
                        

        #Data from WTM
                try {$WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins} catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING';EXIT}

                $WTMResponse.psobject.properties.name | ForEach-Object { 
                        
                        $WTMResponse.($_).Algorithm = get_algo_unified_name ($WTMResponse.($_).Algorithm)

                         #not necessary delete bad names/algo, only necessary add correct name/algo
                        $NewCoinName =  get_coin_unified_name $_
                        if ($NewCoinName -ne $_) {
                                $TempCoin=$WTMResponse.($_)
                                $WTMResponse |add-member $NewCoinName $TempCoin
                                }

                        }

        #search on pools where to mine coins, switch sentence determines order to look, if one pool has one coin, no more pools for that coin are searched after.

                $PoolOrder=1
                while ($PoolOrder -le 3)               
                {

                         switch ($PoolOrder)
                                        {
                                                "1"{$PoolToSearch='MINING_POOL_HUB'}
                                                "2"{$PoolToSearch='Suprnova'}
                                                "3"{$PoolToSearch='YIIMP'}

                                        }

                        $HPools=Get_Pools -Querymode "core" -PoolsFilterList $PoolToSearch -location $Info.Location

                        $HPools | ForEach-Object {

                                $WTMcoin=$WTMResponse.($_.Info) 

                                if (($WTMcoin.Algorithm -eq $_.Algorithm) -and (($Pools | where-object coin -eq $_.info |where-object Algo -eq $_.Algorithm) -eq $null)) {
                                                        $Pools +=[pscustomobject]@{
                                                                coin = $_.Info
                                                                algo=  $_.Algorithm
                                                                symbol= $WTMResponse.($_.Info).tag
                                                                server= $_.host
                                                                port=  $_.port
                                                                location=$_.location
                                                                Fee = $_.Fee
                                                                User= $_.User
                                                                Pass= $_.Pass
                                                                protocol= $_.Protocol
                                                                Abbname= $_.Abbname
                                                                WalletMode = $_.WalletMode
                                                                EthStMode = $_.EthStMode
                                                                WalletSymbol= $_.WalletSymbol
                                                                PoolName =$_.PoolName



                                                                }
                                        }

                                }
                        $PoolOrder++        
                }        

        #add estimation data to selected pools

        $Pools |ForEach-Object {
                            
                $WTMFactor = get_WhattomineFactor ($_.Algo)
                

                if ($WTMFactor -ne $null) {
                                        $Estimate=[Double]($WTMResponse.($_.coin).btc_revenue/$WTMFactor)
                                        $Estimate24h=[Double]($WTMResponse.($_.coin).btc_revenue24/$WTMFactor)
                                        }


                $Result+=[PSCustomObject]@{
                                Algorithm     = $_.Algo
                                Info          = $_.Coin
                                Price         = $Estimate
                                Price24h      = $Estimate24h
                                Protocol      = $_.Protocol
                                Host          = $_.Server
                                Port          = $_.Port
                                User          = $_.User
                                Pass          = $_.Pass
                                Location      = $_.Location
                                SSL           = $false
                                Symbol        = $_.symbol
                                AbbName       = "WTM-"+$_.Abbname
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolName =$_.PoolName
                                WalletMode = $_.WalletMode
                                Fee = $_.Fee
                                EthStMode = $_.EthStMode
                                WalletSymbol= $_.WalletSymbol
                                }

                        }


        remove-variable WTMResponse
        remove-variable Pools
        remove-variable WTMcoin
        remove-variable HPools
      

        }

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
