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

                                switch($info.AbbName) {
                                                "WTM-SN" {$PoolRealName = 'SUPRNOVA'  }
                                                "WTM-MPH" {$PoolRealName = 'MINING_POOL_HUB'  }
                                                "WTM-YI" {$PoolRealName = 'YIIMP'  }
                                }
                                
                                $Info.poolname = $PoolRealName     
                                $result = Get-Pools -Querymode $info.WalletMode -PoolsFilterList $PoolRealName -Info $Info   | select-object Pool,currency,balance
                             
                        
                                 }
        
            




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************






if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $Pools=@()

        #Manual Pools zone 

                #$Pools +=[pscustomobject]@{"coin" = "ZCLASSIC";"algo"="Equihash"; "symbol"= "ZCL";"server"="us-east.equihash-hub.miningpoolhub.com"; "port"= "20575";"location"="US"}
                #$Pools +=[pscustomobject]@{"coin" = "ORBITCOIN"; "algo"="NEOSCRYPT"; "symbol"= "ORB"; "server"="yiimp.ccminer.org";"port"="4233";"location"="US"}

        #Data from WTM
                try {$WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json | Select-Object -ExpandProperty coins} catch { WRITE-HOST 'WTM API NOT RESPONDING...ABORTING';EXIT}

                $WTMResponse.psobject.properties.name | ForEach-Object { 
                        $A=$WTMResponse.($_).Algorithm
                        $WTMResponse.($_).Algorithm = get-algo-unified-name ($WTMResponse.($_).Algorithm)

                         #not necessary delete bad names/algo, only necessary add correct name/algo
                        $NewCoinName = get-coin-unified-name $_
                        if ($NewCoinName -ne $_) {
                                $TempCoin=$WTMResponse.($_)
                                $WTMResponse |add-member $NewCoinName $TempCoin
                                }

                        }

        #search if MPH has pool for WTM mcoins

                $MPHPools=Get-Pools -Querymode "core" -PoolsFilterList 'MINING_POOL_HUB' -location $Info.Location

                $MPHPools | ForEach-Object {

                        $WTMcoin=$WTMResponse.($_.Info) 

                        if (($WTMcoin.Algorithm -eq $_.Algorithm) -and (($Pools | where-object coin -eq $_.info |where-object Algo -eq $_.Algorithm) -eq $null)) {
                                                $Pools +=[pscustomobject]@{
                                                        "coin" = $_.Info
                                                        "algo"=  $_.Algorithm
                                                        "symbol"= $WTMResponse.($_.Info).tag
                                                        "server"= $_.host
                                                        "port"=  $_.port
                                                        "location"= $_.location
                                                        }
                                }

                        }
      

         #search if suprnova has pool for WTM mcoins

               $SPRPools=Get-Pools -Querymode "core" -PoolsFilterList 'Suprnova' -location $Info.Location

                $SPRPools | ForEach-Object {

                        $WTMcoin=$WTMResponse.($_.Info)   
                        if (($WTMcoin.Algorithm -eq $_.Algorithm) -and (($Pools | where-object coin -eq $_.info |where-object Algo -eq $_.Algorithm) -eq $null)) {
                                                $Pools +=[pscustomobject]@{
                                                        "coin" = $_.Info
                                                        "algo"= $_.Algorithm
                                                        "symbol"= $WTMResponse.($_.Info).tag
                                                        "server"= $_.host
                                                        "port"=  $_.port
                                                        "location"= $_.location
                                                        }
                                }

                        }

         
         #search if Yiimp has pool for WTM mcoins

               $YiimpPools=Get-Pools -Querymode "core" -PoolsFilterList 'YIIMP' -location $Info.Location
               
                               $YiimpPools | ForEach-Object {
               
                                       $WTMcoin=$WTMResponse.($_.Info)   
                                       if (($WTMcoin.Algorithm -eq $_.Algorithm) -and (($Pools | where-object coin -eq $_.info |where-object Algo -eq $_.Algorithm) -eq $null)) {
                                         if ($_.Info -ne 'decred') { #decred on yiimp has "server full" errors
                                                               $Pools +=[pscustomobject]@{
                                                                       "coin" = $_.Info
                                                                       "algo"= $_.Algorithm
                                                                       "symbol"= $WTMResponse.($_.Info).tag
                                                                       "server"= $_.host
                                                                       "port"=  $_.port
                                                                       "location"= $_.location
                                                                       }
                                                               }
                                               }
               
                                       }
           
           
        $Pools |ForEach-Object {
                            #WTM json is for 3xAMD 480 hashrate must adjust, 
                            # to check result with WTM set WTM on "Difficulty for revenue" to "current diff" and "and sort by "current profit" set your algo hashrate from profits screen, WTM "Rev. BTC" and MM BTC/Day must be the same
                            $WTMFactor=$null
                            switch ($_.Algo)
                                        {
                                                "Ethash"{$WTMFactor=79500000}
                                                "Groestl"{$WTMFactor=54000000}
                                                "Myriad-Groestl"{$WTMFactor=79380000}
                                                "X11Gost"{$WTMFactor=20100000}
                                                "Cryptonight"{$WTMFactor=2190}
                                                "equihash"{$WTMFactor=870}
                                                "lyra2v2"{$WTMFactor=14700000}
                                                "Neoscrypt"{$WTMFactor=1950000}
                                                "Lbry"{$WTMFactor=285000000}
                                                "Blake2b"{$WTMFactor=2970000000} 
                                                "Blake14r"{$WTMFactor=4200000000}
                                                "Pascal"{$WTMFactor=2070000000}
                                                "skunk"{$WTMFactor=54000000}
                                        }

                            if ($WTMFactor -ne $null) {
                                                        $Estimate=[Double]($WTMResponse.($_.coin).btc_revenue/$WTMFactor)
                                                        $Estimate24h=[Double]($WTMResponse.($_.coin).btc_revenue24/$WTMFactor)
                                                        }

                            if ($_.Server -like '*suprnova*'){
                                        $VPUser="$Username.$WorkerName" 
                                        $VPPassword="x"  
                                        $VPprotocol="stratum+tcp"
                                        $VpAbbname='SN'
                                        $VpWalletMode='APIKEY'
                                    }

                                    
                            if ($_.Server -like '*yiimp*'){
                                        $VPUser= $CoinsWallets.get_item($_.symbol)
                                        $VPPassword="c=$Yiimp_currency,ID=$WorkerName,stats"
                                        $VPprotocol="stratum+tcp"
                                        $VpAbbname='YI'
                                        $VpWalletMode='WALLET'
                                    }
                        
                             if ($_.Server -like '*miningpoolhub*'){
                                        $VPUser= "$UserName.$WorkerName"
                                        $VPPassword="x"
                                        $VPprotocol="stratum+tcp"
                                        $VpAbbname='MPH'
                                        $VpWalletMode='APIKEY'
                                    }                                    

                $Result+=[PSCustomObject]@{
                                Algorithm     = $_.Algo
                                Info          = $_.Coin
                                Price         = $Estimate
                                Price24h      = $Estimate24h
                                Protocol      = $VPprotocol
                                Host          = $_.Server
                                Port          = $_.Port
                                User          = $VpUser
                                Pass          = $VpPassword
                                Location      = $_.Location
                                SSL           = $false
                                Symbol        = $_.symbol
                                AbbName       = "WTM-"+$VpAbbname
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolName = $Name
                                WalletMode = $VpWalletMode
                                }

                        }


        remove-variable WTMResponse
        remove-variable Pools
        remove-variable WTMcoin
        remove-variable MPHPools
        remove-variable SPRPools                                      

        }

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



$Result |ConvertTo-Json | Set-Content ("$name.tmp")
remove-variable Result
