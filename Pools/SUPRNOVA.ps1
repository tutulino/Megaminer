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
        $Pools += [pscustomobject]@{"coin" = "BitCore"; "algo" = "BitCore"; "symbol" = "BTX"; "server" = "btx.suprnova.cc"; "port" = "3629"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "BitSend"; "algo" = "Xevan"; "symbol" = "BSD"; "server" = "bsd.suprnova.cc"; "port" = "8686"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "BitcoinCash"; "algo" = "SHA256d"; "symbol" = "BCH"; "server" = "bcc.suprnova.cc"; "port" = "3333"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "BitcoinGold"; "algo" = "Equihash"; "symbol" = "BTG"; "server" = "btg.suprnova.cc"; "port" = "8816"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "BitcoinZ"; "algo" = "Equihash"; "symbol" = "BTCZ"; "server" = "btcz.suprnova.cc"; "port" = "5586"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "ChainCoin"; "algo" = "C11"; "symbol" = "CHC"; "server" = "chc.suprnova.cc"; "port" = "5888"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "DashCoin"; "algo" = "X11"; "symbol" = "Dash"; "server" = "dash.suprnova.cc"; "port" = "9995"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Decred"; "algo" = "Blake14r"; "symbol" = "DCR"; "server" = "dcr.suprnova.cc"; "port" = "3252"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Digibyte"; "algo" = "Myriad-Groestl"; "symbol" = "DGB"; "server" = "dgbg.suprnova.cc"; "port" = "7978"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "Digibyte"; "algo" = "Qubit"; "symbol" = "DGB"; "server" = "dgbq.suprnova.cc"; "port" = "8531"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Digibyte"; "algo" = "Skein"; "symbol" = "DGB"; "server" = "dgbs.suprnova.cc"; "port" = "5226"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "Einsteinium"; "algo" = "Scrypt"; "symbol" = "EMC2"; "server" = "emc2.suprnova.cc"; "port" = "3366"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Electroneum"; "algo" = "Cryptonight"; "symbol" = "ETN"; "server" = "etn.suprnova.cc"; "port" = "8875"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "eMark"; "algo" = "SHA256"; "symbol" = "DEM"; "server" = "dem.suprnova.cc"; "port" = "5555"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Ethereum"; "algo" = "Ethash"; "symbol" = "ETH"; "server" = "eth.suprnova.cc"; "port" = "5000"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "EuropeCoin v3"; "algo" = "HODL"; "symbol" = "ERC"; "server" = "erc.suprnova.cc"; "port" = "7674"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Expanse"; "algo" = "Ethash"; "symbol" = "EXP"; "server" = "exp.suprnova.cc"; "port" = "3333"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "FlorinCoin"; "algo" = "Scrypt"; "symbol" = "FLO"; "server" = "flo.suprnova.cc"; "port" = "3210"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "GameCredits"; "algo" = "Scrypt"; "symbol" = "GAME"; "server" = "gmc.suprnova.cc"; "port" = "7351"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "GeoCoin"; "algo" = "Qubit"; "symbol" = "GEO"; "server" = "geo.suprnova.cc"; "port" = "6009"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "GroestlCoin"; "algo" = "Groestl"; "symbol" = "GRS"; "server" = "grs.suprnova.cc"; "port" = "5544"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "HODLcoin"; "algo" = "HODL"; "symbol" = "HODL"; "server" = "hodl.suprnova.cc"; "port" = "4693"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Hush"; "algo" = "Equihash"; "symbol" = "Hush"; "server" = "hush.suprnova.cc"; "port" = "4048"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Komodo"; "algo" = "Equihash"; "symbol" = "KMD"; "server" = "kmd.suprnova.cc"; "port" = "6250"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Lbry"; "algo" = "LBRY"; "symbol" = "LBC"; "server" = "lbry.suprnova.cc"; "port" = "6256"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "Litecoin"; "algo" = "Scrypt"; "symbol" = "LTC"; "server" = "ltc.suprnova.cc"; "port" = "4444"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "MachineCoin"; "algo" = "TimeTravel"; "symbol" = "MAC"; "server" = "mac.suprnova.cc"; "port" = "4942"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "MagiCoin"; "algo" = "M7M"; "symbol" = "XMG"; "server" = "xmg.suprnova.cc"; "port" = "7128"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "MinexCoin"; "algo" = "Mars"; "symbol" = "MNX"; "server" = "mnx.suprnova.cc"; "port" = "7076"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "MonaCoin"; "algo" = "Lyra2V2"; "symbol" = "MONA"; "server" = "mona.suprnova.cc"; "port" = "2995"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Monero"; "algo" = "Cryptonight"; "symbol" = "XMR"; "server" = "xmr-eu.suprnova.cc"; "port" = "5222"; "location" = "Europe"};
        $Pools += [pscustomobject]@{"coin" = "Monero"; "algo" = "Cryptonight"; "symbol" = "XMR"; "server" = "xmr.suprnova.cc"; "port" = "5222"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Myriad"; "algo" = "Myriad-Groestl"; "symbol" = "XMY"; "server" = "myrgrs.suprnova.cc"; "port" = "2529"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "Pure"; "algo" = "X11"; "symbol" = "PURE"; "server" = "pure.suprnova.cc"; "port" = "5518"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Polytmos"; "algo" = "Polytmos"; "symbol" = "PLYS"; "server" = "poly.suprnova.cc"; "port" = "7935"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "SibCoin"; "algo" = "X11GOST"; "symbol" = "SIB"; "server" = "sib.suprnova.cc"; "port" = "3458"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Straks"; "algo" = "lyra2v2"; "symbol" = "STAK"; "server" = "stak.suprnova.cc"; "port" = "7706"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "SmartCash"; "algo" = "keccak"; "symbol" = "SMART"; "server" = "smart.suprnova.cc"; "port" = "4192"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "SpreadCoin"; "algo" = "SpreadX11"; "symbol" = "SPR"; "server" = "spr.suprnova.cc"; "port" = "6666"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "StartCoin"; "algo" = "X11"; "symbol" = "Start"; "server" = "start.suprnova.cc"; "port" = "2207"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "UBIQ"; "algo" = "Ethash"; "symbol" = "UBQ"; "server" = "ubq.suprnova.cc"; "port" = "3030"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Veltor"; "algo" = "Veltor"; "symbol" = "VLT"; "server" = "veltor.suprnova.cc"; "port" = "8897"; "location" = "US"};
        # $Pools += [pscustomobject]@{"coin" = "XIOS"; "algo" = "Scrypt"; "symbol" = "XIOS"; "server" = "xios.suprnova.cc"; "port" = "8972"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-apac.suprnova.cc"; "port" = "2142"; "location" = "Asia"};
        $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-eu.suprnova.cc"; "port" = "2142"; "location" = "Europe"};
        $Pools += [pscustomobject]@{"coin" = "ZCash"; "algo" = "Equihash"; "symbol" = "ZEC"; "server" = "zec-us.suprnova.cc"; "port" = "2142"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "ZClassic"; "algo" = "Equihash"; "symbol" = "ZCL"; "server" = "zcl.suprnova.cc"; "port" = "4042"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "ZENCash"; "algo" = "Equihash"; "symbol" = "ZEN"; "server" = "zen.suprnova.cc"; "port" = "3618"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "ZEROCoin"; "algo" = "Zero"; "symbol" = "ZER"; "server" = "zero.suprnova.cc"; "port" = "6568"; "location" = "US"};
        $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc-apac.suprnova.cc"; "port" = "1569"; "location" = "Asia"};
        $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc.suprnova.cc"; "port" = "1569"; "location" = "Europe"};
        $Pools += [pscustomobject]@{"coin" = "Zcoin"; "algo" = "Lyra2Z"; "symbol" = "XZC"; "server" = "xzc.suprnova.cc"; "port" = "1569"; "location" = "US"};


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