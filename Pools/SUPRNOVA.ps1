param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode=$false
$AbbName='SNV'
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




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    if ($Querymode -eq "APIKEY")    {
        
                        
                            try {
                                $http="http://"+$Info.Symbol+".suprnova.cc/index.php?page=api&action=getuserbalance&api_key="+$Info.ApiKey+"&id="
                                #$http |write-host  
                                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12                              
                                $Request =  Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5
                                $Request = $Request | ConvertFrom-Json | Select-Object -ExpandProperty getuserbalance | Select-Object -ExpandProperty data
                                }
                            catch {
                                  }
        
        
                        
                                $Result=[PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Info.OriginalCoin
                                                        balance = $Request.confirmed+$Request.unconfirmed
                                                    }
                         
                         
                                                
                        }

            
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    if ($Querymode -eq "SPEED")    {
        
                        
        try {
            $http="http://"+$Info.Symbol+".suprnova.cc/index.php?page=api&action=getuserbalance&api_key="+$Info.ApiKey+"&id="
            #$http |write-host  
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12                              
            $Request =  Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5
            $Request = $Request | ConvertFrom-Json | Select-Object -ExpandProperty getuserbalance | Select-Object -ExpandProperty data
            }
        catch {
              }


    
            $Result=[PSCustomObject]@{
                                    Pool =$name
                                    currency = $Info.OriginalCoin
                                    balance = $Request.confirmed+$Request.unconfirmed
                                }
                            
    }



#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

    
        $Pools=@()
        $Pools +=[pscustomobject]@{"coin" = "DECRED"; "algo"="Blake14r"; "symbol"= "DCR"; "server"="dcr.suprnova.cc";"port"="3252";"location"="US";"WalletSymbol"="DCR"};
        $Pools +=[pscustomobject]@{"coin" = "BITCORE"; "algo"="BITCORE"; "symbol"= "BTX"; "server"="btx.suprnova.cc";"port"="3629";"location"="US";"WalletSymbol"="BTX"};
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="SKEIN"; "symbol"= "DGB";"server"="dgbs.suprnova.cc"; "port"= "5226";"location"="US";"WalletSymbol"="DGBS"};
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="myriad-groestl"; "symbol"= "DGB";"server"="dgbg.suprnova.cc"; "port"= "7978";"location"="US";"WalletSymbol"="DGBM"};
        $Pools +=[pscustomobject]@{"coin" = "HUSH";"algo"="Equihash"; "symbol"= "HUSH";"server"="hush.suprnova.cc"; "port"= "4048";"location"="US";"WalletSymbol"="HUSH"};
        $Pools +=[pscustomobject]@{"coin" = "LBRY";"algo"="LBRY"; "symbol"= "LBC";"server"="lbry.suprnova.cc"; "port"= "6256";"location"="US";"WalletSymbol"="LBRY"};
        $Pools +=[pscustomobject]@{"coin" = "MONACOIN";"algo"="lyra2v2"; "symbol"= "MONA";"server"="mona.suprnova.cc"; "port"= "2995";"location"="US";"WalletSymbol"="MONA"};
        $Pools +=[pscustomobject]@{"coin" = "SIGNATUM";"algo"="SKUNK"; "symbol"= "SIGT";"server"="sigt.suprnova.cc"; "port"= "7106";"location"="US";"WalletSymbol"="SIGT"};
        $Pools +=[pscustomobject]@{"coin" = "VELTOR";"algo"="VELTOR"; "symbol"= "VLT";"server"="veltor.suprnova.cc"; "port"= "8897";"location"="US";"WalletSymbol"="VLT"};
        $Pools +=[pscustomobject]@{"coin" = "ZENCASH";"algo"="Equihash"; "symbol"= "ZEN";"server"="zen.suprnova.cc"; "port"= "3618";"location"="US";"WalletSymbol"="ZEN"};
        $Pools +=[pscustomobject]@{"coin" = "ZCASH";"algo"="Equihash"; "symbol"= "ZEC";"server"="zec-us.suprnova.cc"; "port"= "2142";"location"="US";"WalletSymbol"="ZEC"};
        $Pools +=[pscustomobject]@{"coin" = "ZCASH";"algo"="Equihash"; "symbol"= "ZEC";"server"="zec-eu.suprnova.cc"; "port"= "2142";"location"="EUROPE";"WalletSymbol"="ZEC"};
        $Pools +=[pscustomobject]@{"coin" = "ZCASH";"algo"="Equihash"; "symbol"= "ZEC";"server"="zec-apac.suprnova.cc"; "port"= "2142";"location"="ASIA";"WalletSymbol"="ZEC"};
        $Pools +=[pscustomobject]@{"coin" = "ZCOIN";"algo"="LYRA2Z"; "symbol"= "XZC";"server"="xzc.suprnova.cc"; "port"= "1569";"location"="US";"WalletSymbol"="XZC"};
        $Pools +=[pscustomobject]@{"coin" = "ZCOIN";"algo"="LYRA2Z"; "symbol"= "XZC";"server"="xzc.suprnova.cc"; "port"= "1569";"location"="EUROPE";"WalletSymbol"="XZC"};
        $Pools +=[pscustomobject]@{"coin" = "ZCOIN";"algo"="LYRA2Z"; "symbol"= "XZC";"server"="xzc-apac.suprnova.cc"; "port"= "1569";"location"="ASIA";"WalletSymbol"="XZC"};
        $Pools +=[pscustomobject]@{"coin" = "DASHCOIN";"algo"="X11"; "symbol"= "DASH";"server"="dash.suprnova.cc"; "port"= "9995";"location"="US";"WalletSymbol"="DASH"};
        $Pools +=[pscustomobject]@{"coin" = "ZCLASSIC";"algo"="Equihash"; "symbol"= "ZCL";"server"="zcl.suprnova.cc"; "port"= "4042";"location"="US";"WalletSymbol"="ZCL"};
        $Pools +=[pscustomobject]@{"coin" = "ZCLASSIC";"algo"="Equihash"; "symbol"= "ZCL";"server"="zcl-apac.suprnova.cc"; "port"= "4042";"location"="US";"WalletSymbol"="ZCL"};
        $Pools +=[pscustomobject]@{"coin" = "KOMODO";"algo"="Equihash"; "symbol"= "KMD";"server"="kmd.suprnova.cc"; "port"= "6250";"location"="US";"WalletSymbol"="KMD"};
        $Pools +=[pscustomobject]@{"coin" = "MONERO";"algo"="CRYPTONIGHT"; "symbol"= "XMR";"server"="xmr-eu.suprnova.cc"; "port"= "5222";"location"="EU";"WalletSymbol"="XMR"};
        $Pools +=[pscustomobject]@{"coin" = "CHAINCOIN";"algo"="C11"; "symbol"= "CHC";"server"="chc.suprnova.cc"; "port"= "5888";"location"="EU";"WalletSymbol"="CHC"};
        $Pools +=[pscustomobject]@{"coin" = "ETHEREUM";"algo"="ETHASH"; "symbol"= "ETH";"server"="eth.suprnova.cc"; "port"= "5000";"location"="US";"WalletSymbol"="ETH"};
        $Pools +=[pscustomobject]@{"coin" = "SIBCOIN";"algo"="X11gost"; "symbol"= "ETH";"server"="sib.suprnova.cc"; "port"= "3458";"location"="US";"WalletSymbol"="ETH"};
        $Pools +=[pscustomobject]@{"coin" = "UBIQ";"algo"="Ethash"; "symbol"= "UBQ";"server"="ubiq.suprnova.cc"; "port"= "3030";"location"="US";"WalletSymbol"="UBIQ"};
        $Pools +=[pscustomobject]@{"coin" = "EXPANSE";"algo"="Ethash"; "symbol"= "EXP";"server"="exp.suprnova.cc"; "port"= "3333";"location"="US";"WalletSymbol"="EXP"};
        $Pools +=[pscustomobject]@{"coin" = "ELECTRONEUM";"algo"="CRYPTONIGHT"; "symbol"= "ETN";"server"="etn.suprnova.cc"; "port"= "8875";"location"="US";"WalletSymbol"="ETN"};
        $Pools +=[pscustomobject]@{"coin" = "SMARTCASH";"algo"="keccak"; "symbol"= "SMART";"server"="smart.suprnova.cc"; "port"= "4192";"location"="US";"WalletSymbol"="SMART"};
        $Pools +=[pscustomobject]@{"coin" = "BITCOINZ";"algo"="equihash"; "symbol"= "BTCZ";"server"="btcz.suprnova.cc"; "port"= "5586";"location"="US";"WalletSymbol"="BTCZ"};
        $Pools +=[pscustomobject]@{"coin" = "BITCOINGOLD";"algo"="equihash"; "symbol"= "BTG";"server"="btg.suprnova.cc"; "port"= "8816";"location"="US";"WalletSymbol"="BTG"};
        $Pools +=[pscustomobject]@{"coin" = "polytimos";"algo"="polytimos"; "symbol"= "POLY";"server"="poly.suprnova.cc"; "port"= "7935";"location"="US";"WalletSymbol"="POLY"};
        $Pools +=[pscustomobject]@{"coin" = "Straks";"algo"="lyra2v2"; "symbol"= "STAK";"server"="stak.suprnova.cc"; "port"= "7706";"location"="US";"WalletSymbol"="STAK"};

        
      
        

        $Pools |ForEach-Object {

 

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
                                    PoolWorkers     = $Null
                                    PoolHashRate    = [double]$ApiResponse.hashrate
                                    PoolName        = $Name
                                    WalletMode      = $WalletMode
                                    WalletSymbol    = $_.WalletSymbol
                                    OriginalAlgorithm =  $_.Algo
                                    OriginalCoin = $_.Coin
                                    Fee = 0.01
                                    EthStMode = 3


                                }

                        }
              
                Remove-Variable Pools
        }
                  
$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result