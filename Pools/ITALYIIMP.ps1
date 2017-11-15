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
$AbbName = 'ITY'
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
                                $http="http://italyiimp.com/api/wallet?address="+$Info.user
                                $Ita_Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Ita_Request -ne $null -and $Ita_Request -ne ""){
                                $Result = [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Ita_Request.currency
                                                        balance = $Ita_Request.balance
                                                    }
                                    remove-variable Ita_Request                                                                                                        
                                    }

                        
                        }
                        
                        


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        $retries=1
                do {
                        try {
                            $Ita_Request = Invoke-WebRequest "http://italyiimp.com/api/status"  -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36" -UseBasicParsing -timeout 5 | ConvertFrom-Json 

                        }
                        catch {}
                        $retries++
                    if ($Ita_Request -eq $null -or $Ita_Request -eq "") {start-sleep 5}
                    } while ($Ita_Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'ITALYIIMP API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }



                  

                $Ita_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
                    
                                            $Divisor = (Get-Algo-Divisor $_) / 1000

                                            switch ($_){
                                                "X11"{$Divisor *= 1000}
                                                "qubit"{$Divisor *= 1000}
                                                "quark"{$Divisor *= 1000}
                                                "blakecoin"{$Divisor *= 1000}
                                                }

                    
                                    
                                    $Result += [PSCustomObject]@{
                                                    Algorithm =  get-algo-unified-name $_
                                                    Info = $null
                                                    Price = [Double]$Ita_Request.$_.estimate_current/$Divisor
                                                    Price24h =[Double]$Ita_Request.$_.estimate_last24h/$Divisor
                                                    Protocol = "stratum+tcp"
                                                    Host = "italyiimp.com"
                                                    Port = $Ita_Request.$_.port
                                                    User = $CoinsWallets.get_item($Currency)
                                                    Pass = "c=$Currency,$WorkerName,stats"
                                                    Location = "US"
                                                    SSL = $false
                                                    AbbName = $AbbName
                                                    ActiveOnManualMode    = $ActiveOnManualMode
                                                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                                    PoolWorkers = $Ita_Request.$_.workers
                                                    WalletMode=$WalletMode
                                                    PoolName = $Name
                                                    Fee = $Ita_Request.$_.Fees/100
                                        
                                    }
                                }
  remove-variable Ita_Request                
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    $Result |ConvertTo-Json | Set-Content ("$name.tmp")
    remove-variable Result
    
