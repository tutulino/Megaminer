param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )



$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode=$false
$AbbName='SNOVA'
$WalletMode="APIKEY"
$Result=@()

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer = "Must register and set wallet for each coin on web"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomaticMode
                    ApiData = $true
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                          }
    }


    if ($Querymode -eq "APIKEY")    {
        
         

                             
                            Switch($Info.Symbol) {
                                "DGB" {$Info.Symbol=$Info.Symbol+($Info.Algorithm.substring(0,1))}
                               }

                               


                            
                            try {

                                $ApiKeyPattern='@@APIKEY_SUPRNOVA=*'
                                $ApiKey = (Get-Content config.txt | Where-Object {$_ -like $ApiKeyPattern} )-replace $ApiKeyPattern,''

                                $http="http://"+$Info.Symbol+".suprnova.cc/index.php?page=api&action=getuserbalance&api_key="+$ApiKey+"&id="
                                #$http |write-host  
                                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12                              
                                $Suprnova_Request =  Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5
                                $Suprnova_Request = $Suprnova_Request | ConvertFrom-Json | Select-Object -ExpandProperty getuserbalance | Select-Object -ExpandProperty data
                                }
                            catch {
                                  }
        
        
                        
                                $Result=[PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Info.OriginalCoin
                                                        balance = $Suprnova_Request.confirmed+$Suprnova_Request.unconfirmed
                                                    }
                         
                         
                                                
                        }

                        



if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){
        $Pools=@()
        $Pools +=[pscustomobject]@{"coin" = "DECRED"; "algo"="Blake14r"; "symbol"= "DCR"; "server"="dcr.suprnova.cc";"port"="3252";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "BITCORE"; "algo"="BITCORE"; "symbol"= "BTX"; "server"="btx.suprnova.cc";"port"="3629";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="SKEIN"; "symbol"= "DGB";"server"="dgbs.suprnova.cc"; "port"= "5226";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="myriad-groestl"; "symbol"= "DGB";"server"="dgbg.suprnova.cc"; "port"= "7978";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "HUSH";"algo"="Equihash"; "symbol"= "HUSH";"server"="hush.suprnova.cc"; "port"= "4048";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "LBRY";"algo"="LBRY"; "symbol"= "LBC";"server"="lbry.suprnova.cc"; "port"= "6256";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "MONACOIN";"algo"="lyra2v2"; "symbol"= "MONA";"server"="mona.suprnova.cc"; "port"= "2995";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "SIGNATUM";"algo"="SKUNK"; "symbol"= "SIGT";"server"="sigt.suprnova.cc"; "port"= "7106";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "VELTOR";"algo"="VELTOR"; "symbol"= "VLT";"server"="veltor.suprnova.cc"; "port"= "8897";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZENCASH";"algo"="Equihash"; "symbol"= "ZEN";"server"="zen.suprnova.cc"; "port"= "3618";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZCASH";"algo"="Equihash"; "symbol"= "ZEC";"server"="zec-us.suprnova.cc"; "port"= "2142";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZCASH";"algo"="Equihash"; "symbol"= "ZEC";"server"="zec-eu.suprnova.cc"; "port"= "2142";"location"="EUROPE"};
        $Pools +=[pscustomobject]@{"coin" = "ZCASH";"algo"="Equihash"; "symbol"= "ZEC";"server"="zec-apac.suprnova.cc"; "port"= "2142";"location"="ASIA"};
        $Pools +=[pscustomobject]@{"coin" = "ZCOIN";"algo"="LYRA2Z"; "symbol"= "XZC";"server"="xzc.suprnova.cc"; "port"= "1569";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZCOIN";"algo"="LYRA2Z"; "symbol"= "XZC";"server"="xzc.suprnova.cc"; "port"= "1569";"location"="EUROPE"};
        $Pools +=[pscustomobject]@{"coin" = "ZCOIN";"algo"="LYRA2Z"; "symbol"= "XZC";"server"="xzc-apac.suprnova.cc"; "port"= "1569";"location"="ASIA"};
        $Pools +=[pscustomobject]@{"coin" = "DASHCOIN";"algo"="X11"; "symbol"= "DASH";"server"="dash.suprnova.cc"; "port"= "9995";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZCLASSIC";"algo"="Equihash"; "symbol"= "ZCL";"server"="zcl.suprnova.cc"; "port"= "4042";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZCLASSIC";"algo"="Equihash"; "symbol"= "ZCL";"server"="zcl-apac.suprnova.cc"; "port"= "4042";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "KOMODO";"algo"="Equihash"; "symbol"= "KMD";"server"="kmd.suprnova.cc"; "port"= "6250";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "MONERO";"algo"="CRYPTONIGHT"; "symbol"= "XMR";"server"="xmr-eu.suprnova.cc"; "port"= "5222";"location"="EU"};
        $Pools +=[pscustomobject]@{"coin" = "CHAINCOIN";"algo"="C11"; "symbol"= "CHC";"server"="chc.suprnova.cc"; "port"= "5888";"location"="EU"};
        $Pools +=[pscustomobject]@{"coin" = "ETHEREUM";"algo"="ETHASH"; "symbol"= "ETH";"server"="eth.suprnova.cc"; "port"= "5000";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "SIBCOIN";"algo"="X11gost"; "symbol"= "ETH";"server"="sib.suprnova.cc"; "port"= "3458";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "UBIQ";"algo"="Ethash"; "symbol"= "UBQ";"server"="ubiq.suprnova.cc"; "port"= "3030";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "EXPANSE";"algo"="Ethash"; "symbol"= "UBQ";"server"="exp.suprnova.cc"; "port"= "3333";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ELECTRONEUM";"algo"="CRYPTONIGHT"; "symbol"= "ETN";"server"="etn.suprnova.cc"; "port"= "8875";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "SMARTCASH";"algo"="keccak"; "symbol"= "SMART";"server"="smart.suprnova.cc"; "port"= "4192";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "BITCOINZ";"algo"="equihash"; "symbol"= "BTCZ";"server"="btcz.suprnova.cc"; "port"= "5586";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "BITCOINGOLD";"algo"="equihash"; "symbol"= "BTG";"server"="btg.suprnova.cc"; "port"= "8816";"location"="US"};


        #$Pools +=[pscustomobject]@{"coin"= "SPREADCOIN";"algo"="SPREADX11"; "symbol"= "SPR";"server"="spr.suprnova.cc"; "port"= "6666";"location"="US"}


        $ManualMiningApiUse=(Get-Content config.txt | Where-Object {$_ -like '@@MANUALMININGAPIUSE=*'} )-replace '@@MANUALMININGAPIUSE=',''

        

        $Pools |ForEach-Object {


                                if (($ManualMiningApiUse -eq $true) -and  ($Querymode -eq "Menu")) {
                                        $ApiResponse=$null
                                        try {
                                                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12   
                                                $Apicall="https://"+$_.Server+"/index.php?page=api&action=public"
                                                $ApiResponse=(Invoke-WebRequest $ApiCall -UseBasicParsing  -TimeoutSec 3| ConvertFrom-Json)
                                            } catch{}
                                        }
                                

                            $Result+=[PSCustomObject]@{
                                    Algorithm     = $_.Algo
                                    Info          = $_.Coin
                                    Price         = $null
                                    Price24h      = $null
                                    Protocol      = "stratum+tcp"
                                    Host          = $_.Server
                                    Port          = $_.Port
                                    User          = "$Username.$WorkerName"
                                    Pass          = "x"
                                    Location      = $_.Location
                                    SSL           = $false
                                    Symbol        = $_.symbol
                                    AbbName       = $AbbName
                                    ActiveOnManualMode    = $ActiveOnManualMode
                                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                    PoolWorkers     = $ApiResponse.Workers
                                    PoolHashRate    = [double]$ApiResponse.hashrate
                                    PoolName        = $Name
                                    WalletMode      = $WalletMode
                                    OriginalAlgorithm =  $_.Algo
                                    OriginalCoin = $_.Coin
                                    Fee = 0.01


                                }

                        }
                if (($ManualMiningApiUse -eq $true) -and  ($Querymode -eq "Menu")) {Remove-Variable ApiResponse}
                Remove-Variable Pools
        }
                  
$Result |ConvertTo-Json | Set-Content ("$name.tmp")
Remove-Variable Result