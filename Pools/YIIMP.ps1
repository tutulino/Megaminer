param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null ,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$AbbName = 'YIIMP'
$WalletMode = "NONE"
$Result = @()




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer = "No registration, No autoexchange, need wallet for each coin on config.txt"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    ApiData = $True
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }




               


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $Pools=@()
        $Pools +=[pscustomobject]@{"Symbol"="AUR"; "algo"="skein";"port"=4933;"coin"="AuroraCoin";"location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="BOAT"; "algo"="hmq1725";"port"=3747;"coin"="Doubloon";"location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="BSD";"algo"="xevan"; "port"=3739;"coin"="BitSend"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="BSTY"; "algo"="yescrypt";"port"=6233;"coin"="GlobalBoostY";  "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="BTX";"algo"="bitcore";"port"=3556;"coin"="BitCore";"location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="CHC";"algo"="c11";"port"=3573;"coin"="Chaincoin";"location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="DCR";"algo"="decred";"port"=3252;"coin"="decred"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="DGB";"algo"="skein";"port"=4933;"coin"="Digibyte";"location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="DNR";"algo"="tribus";"port"=8533;"coin"="Denarius"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="FTC";"algo"="neoscrypt";"port"=4233;"coin"="Feathercoin";"location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="GRS";"algo"="groestl";"port"=5339;"coin"="Groestlcoin"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="HUSH";"algo"="equihash";"port"=2142;"coin"="Hush"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="KMD";"algo"="equihash";"port"=2142;"coin"="Komodo"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="MAC";"algo"="timetravel";"port"=3555;"coin"="MachineCoin"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="NEVA";"algo"="blake2s";"port"=4262;"coin"="Neva"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="ORB";"algo"="neoscrypt";"port"=4233;"coin"="OrbitCoin"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="SIB";"algo"="sib";"port"=5033;"coin"="SibCoin";  "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="SIGT";"algo"="skunk";"port"=8433;"coin"="Signatum"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="SWEEP";"algo"="jha";"port"=4633;"coin"="Sweepstake"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="TAJ";"algo"="blake2s";"port"=4262;"coin"="TajCoin"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="TIT";"algo"="sha256";"port"=3333;"coin"="Titcoin"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="VIVO";"algo"="neoscrypt";"port"=4233;"coin"="Vivo"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="VTC";"algo"="lyra2v2";"port"=4533;"coin"="VertCoin"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="XLR";"algo"="nist5";"port"=3833;"coin"="Solaris"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="XRE";"algo"="x11evo";"port"=3553;"coin"="Revolver"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="XVG";"algo"="x17";"port"=3737;"coin"="Verge"; "location"="US";"server"="yiimp.ccminer.org"}
        $Pools +=[pscustomobject]@{"Symbol"="ZEN";"algo"="equihash";"port"=2142;"coin"="ZenCash"; "location"="US";"server"="yiimp.ccminer.org"}


        $Pools |  ForEach-Object {

                    $Yiimp_Algorithm = get-algo-unified-name $_.algo
                    $Yiimp_coin =  get-coin-unified-name $_.coin
                    $Yiimp_symbol = $_.Symbol
                

                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Yiimp_Algorithm
                                Info          = $Yiimp_coin
                                Price         = $null
                                Price24h      = $null
                                Protocol      = "stratum+tcp"
                                Host          = $_.server
                                Port          = $_.port
                                User          = $CoinsWallets.get_item($Yiimp_symbol)
                                Pass          = "c=$Yiimp_symbol,ID=$WorkerName,stats"
                                Location      = $_.location
                                SSL           = $false
                                Symbol        = $Yiimp_Symbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers   = $_.Workers
                                PoolHashRate  = $null
                                Blocks_24h    = $null
                                WalletMode    = $WalletMode
                                PoolName = $Name
                                Fee = 0.02
                                }
                        
                
                }

  
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content ("$name.tmp")
    remove-variable Result
    
