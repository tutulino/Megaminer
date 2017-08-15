param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null #Info/detail"
    )



$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $false
$AbbName='SNOVA'

if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Must register and set wallet for each coin on web"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ApiData = $true
                    AbbName=$AbbName
                          }
    }


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){
        $Pools=@()
        $Pools +=[pscustomobject]@{"coin" = "DECRED"; "algo"="Blake14r"; "symbol"= "DCR"; "server"="dcr.suprnova.cc";"port"="3252";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "BITCORE"; "algo"="BITCORE"; "symbol"= "BTX"; "server"="btx.suprnova.cc";"port"="3629";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="SKEIN"; "symbol"= "DGB";"server"="dgbs.suprnova.cc"; "port"= "5226";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="myriad-groestl"; "symbol"= "DGB";"server"="dgbg.suprnova.cc"; "port"= "7978";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "HUSH";"algo"="Equihash"; "symbol"= "HUSH";"server"="zdash.suprnova.cc"; "port"= "4048";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "LBRY";"algo"="LBRY"; "symbol"= "LBC";"server"="lbry.suprnova.cc"; "port"= "6256";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "MONACOIN";"algo"="lyra2v2"; "symbol"= "MONA";"server"="mona.suprnova.cc"; "port"= "2995";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "SIGNATUM";"algo"="SKUNK"; "symbol"= "SIGT";"server"="sigt.suprnova.cc"; "port"= "7106";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "VELTOR";"algo"="VELTOR"; "symbol"= "VLT";"server"="veltor.suprnova.cc"; "port"= "8897";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "ZENCASH";"algo"="Equihash"; "symbol"= "ZEN";"server"="zen.suprnova.cc"; "port"= "4048";"location"="US"};
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


        #$Pools +=[pscustomobject]@{"coin"= "SPREADCOIN";"algo"="SPREADX11"; "symbol"= "SPR";"server"="spr.suprnova.cc"; "port"= "6666";"location"="US"}


        $ManualMiningApiUse=(Get-Content config.txt | Where-Object {$_ -like '@@MANUALMININGAPIUSE=*'} )-replace '@@MANUALMININGAPIUSE=',''

        

        $Pools |ForEach-Object {

                                
                                if ((Get-Stat -Name "$Name_$($_.Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "$Name_$($_.Coin)_Profit" -Value (0.0001)}
                                else {$Stat = Set-Stat -Name "$($Name)_$($_.Coin)_Profit" -Value (0.0001)}




                                if (($ManualMiningApiUse -eq $true) -and  ($Querymode -eq "Menu")) {
                                        $ApiResponse=$null
                                        try {
                                                $Apicall="https://"+$_.Server+"/index.php?page=api&action=public"
                                                $ApiResponse=(Invoke-WebRequest $ApiCall -UseBasicParsing  -TimeoutSec 5| ConvertFrom-Json)
                                            } catch{}
                                        }
                                

                                [PSCustomObject]@{
                                    Algorithm     = $_.Algo
                                    Info          = $_.Coin
                                    Price         = $null
                                    StablePrice   = $null
                                    MarginOfError = $null
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
                                    PoolWorkers       = $ApiResponse.Workers
                                    PoolHashRate  = [double]$ApiResponse.hashrate

                                }

                        }

        }
                  
