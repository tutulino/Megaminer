param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null ,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName = 'UNI'
$WalletMode ='WALLET'
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



    if ($Querymode -eq "wallet")    {
        
                            
                            try {
                                $http="http://pool.unimining.net/api/wallet?address="+$Info.user
                                $Uni_Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Uni_Request -ne $null -and $Uni_Request -ne ""){
                                $Result = [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Uni_Request.currency
                                                        balance = $Uni_Request.balance
                                                    }
                                    remove-variable Uni_Request                                                                                                        
                                    }

                        
                        }
                        
                        


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                            $Uni_Request = Invoke-WebRequest "http://pool.unimining.net/api/currencies"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 5 
                            $Uni_Request = $Uni_Request | ConvertFrom-Json 
                             #$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json

                        }
                        catch {}
                        $retries++
                    if ($Uni_Request -eq $null -or $Uni_Request -eq "") {start-sleep 5}
                    } while ($Uni_Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'UNIMINING API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }


        $Uni_Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Uni_Request | Select-Object -ExpandProperty $_.name
                

                    $Uni_Algorithm = get-algo-unified-name $coin.algo
                    $Uni_coin =  get-coin-unified-name $coin.name
                    $Uni_Simbol=$_.name
            

                    $Divisor = Get-Algo-Divisor $Uni_Algorithm
                    
                

                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Uni_Algorithm
                                Info          = $Uni_coin
                                Price         = [Double]$coin.estimate / $Divisor
                                Price24h      = [Double]$coin.actual_last24h / $Divisor
                                Protocol      = "stratum+tcp"
                                Host          = "pool.unimining.net"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item($Uni_Simbol)
                                Pass          = "c=$Uni_symbol,ID=#WorkerName#"
                                Location      = 'US'
                                SSL           = $false
                                Symbol        = $Uni_Simbol
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                WalletSymbol = $Uni_Simbol
                                PoolName = $Name
                                Fee = $coin.Fees/100
                                }
                        
                
                }

  remove-variable Uni_Request                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content ("$name.tmp")
    remove-variable Result
    
