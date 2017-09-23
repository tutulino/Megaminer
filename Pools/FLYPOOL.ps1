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
$AbbName = 'FLYP'
$WalletMode = "NONE"
$Result = @()




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer = "No registration, No autoexchange"
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
        $Pools +=[pscustomobject]@{"Symbol"="ZEC"; "algo"="equihash";"port"=3333;"coin"="Zcash";"location"="US";"server"="us1-zcash.flypool.org"}
        $Pools +=[pscustomobject]@{"Symbol"="ZEC"; "algo"="equihash";"port"=3333;"coin"="Zcash";"location"="ASIA";"server"="asia1-zcash.flypool.org"}
        $Pools +=[pscustomobject]@{"Symbol"="ZEC"; "algo"="equihash";"port"=3333;"coin"="Zcash";"location"="EUROPE";"server"="eu1-zcash.flypool.org"}

     


        $Pools |  ForEach-Object {

                    $Flypool_Algorithm = get-algo-unified-name $_.algo
                    $Flypool_coin =  get-coin-unified-name $_.coin
                    $Flypool_symbol = $_.Symbol
                

                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Flypool_Algorithm
                                Info          = $Flypool_coin
                                Price         = $null
                                Price24h      = $null
                                Protocol      = "stratum+tcp"
                                Host          = $_.server
                                Port          = $_.port
                                User          = $CoinsWallets.get_item($Flypool_symbol)
                                Pass          = "x"
                                Location      = $_.location
                                SSL           = $false
                                Symbol        = $Flypool_Symbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers   = $_.Workers
                                PoolHashRate  = $null
                                Blocks_24h    = $null
                                WalletMode    = $WalletMode
                                PoolName = $Name
                                }
                        
                
                }

  
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content ("$name.tmp")
    remove-variable Result
    
