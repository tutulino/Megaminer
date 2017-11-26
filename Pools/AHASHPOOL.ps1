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
$AbbName = 'AHASH'
$WalletMode ='WALLET'
$Result = @()




#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer = "Anonymous, autoexchange to selected coin in config.txt"
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
                                $http="http://www.ahashpool.com/api/wallet?address="+$Info.user
                                $Aha_Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Aha_Request -ne $null -and $Aha_Request -ne ""){
                                $Result = [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Aha_Request.currency
                                                        balance = $Aha_Request.balance
                                                    }
                                    remove-variable Aha_Request                                                                                                        
                                    }

                        
                        }
                        
                        


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                            $Aha_Request = Invoke-WebRequest "http://www.ahashpool.com/api/status"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 5  | ConvertFrom-Json 
                        }
                        catch {}
                        $retries++
                    if ($Aha_Request -eq $null -or $Aha_Request -eq "") {start-sleep 5}
                    } while ($Aha_Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'AHASHPOOL API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }


        $Aha_Request | Get-Member -MemberType properties| ForEach-Object {

                $coin=$Aha_Request | Select-Object -ExpandProperty $_.name
                

                    $Aha_Algorithm = get-algo-unified-name $_.name
            

                    $Divisor = (Get-Algo-Divisor $Aha_Algorithm) / 1000
                

                    $Result+=[PSCustomObject]@{
                                Algorithm     = $Aha_Algorithm
                                Info          = $null
                                Price         = $coin.estimate_current / $Divisor
                                Price24h      = $coin.estimate_last24h / $Divisor
                                Protocol      = "stratum+tcp"
                                Host          = $_.name + ".mine.ahashpool.com"
                                Port          = $coin.port
                                User          = $CoinsWallets.get_item("BTC")
                                Pass          = "c=BTC,$WorkerName,stats"
                                Location      = 'US'
                                SSL           = $false
                                Symbol        = $null
                                AbbName       = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers       = $coin.Workers
                                PoolHashRate  = $coin.HashRate
                                Blocks_24h    = $coin."24h_blocks"
                                WalletMode    = $WalletMode
                                PoolName = $Name
                                Fee = $Coin.Fees / 100
                                }
                        
                
                }

  remove-variable Aha_Request                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content ("$name.tmp")
    remove-variable Result
    
