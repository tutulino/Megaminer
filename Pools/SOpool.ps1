param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info

    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName ='SOPOOL'
$WalletMode='WALLET'
$Result=@()



if ($Querymode -eq "info"){
    $Result=[PSCustomObject]@{
                    Disclaimer = "Autoexchange to config.txt wallet, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }



if ($Querymode -eq "wallet")    {

               
                    try {
                        $http="http://sopool.us/api/wallet?address="+$Info.user
                        $SOpool_Request = Invoke-WebRequest $http -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                    }
                    catch {}


                    if ($SOpool_Request -ne $null -and $SOpool_Request -ne ""){
                        $Result=[PSCustomObject]@{
                                                Pool =$name
                                                currency = $SOpool_Request.currency
                                                balance = $SOpool_Request.balance
                                            }
                            remove-variable  SOpool_Request                                            
                            }
                
                }

    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

                $retries=1
                do {
                        try {
                            $SOpool_Request = Invoke-WebRequest "http://sopool.us/api/status" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
                            #$SOpool_Request=get-content "..\SOpool_request.json" | ConvertFrom-Json
                        }
                        catch {start-sleep 2}
                        $retries++
                        if ($SOpool_Request -eq $null -or $SOpool_Request -eq "") {start-sleep 3}
                    } while ($SOpool_Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'SOpool API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }
            

               
                $SOpool_Request | Get-Member -MemberType properties| ForEach-Object {
                                
                                $coin=$SOpool_Request | Select-Object -ExpandProperty $_.name

                                $SOpool_Algo =  get-algo-unified-name ($_.name)

                            
                                $Divisor = (Get-Algo-Divisor $SOpool_Algo) / 1000

                                switch ($SOpool_Algo){
                                    "X11"{$Divisor *= 1000}
                                    "qubit"{$Divisor *= 1000}
                                    "quark"{$Divisor *= 1000}
                                    }

                                
                                
                                    $Result+=[PSCustomObject]@{
                                            Algorithm     = $SOpool_Algo
                                            Info          = $null
                                            Price         = $coin.estimate_current / $Divisor
                                            Price24h      = $coin.estimate_last24h / $Divisor
                                            Protocol      = "stratum+tcp"
                                            Host          = "sopool.us"
                                            Port          = $coin.port
                                            User          = $CoinsWallets.get_item($Currency)
                                            Pass          = "c=$Currency,$WorkerName,Stats"
                                            Location      = "US"
                                            SSL           = $false
                                            Symbol        = $null
                                            AbbName       = $AbbName
                                            ActiveOnManualMode    = $ActiveOnManualMode
                                            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                            PoolWorkers = $coin.workers
                                            WalletMode=$WalletMode
                                            PoolName = $Name
                                            }
                           }

    remove-variable SOpool_Request                           
    }


$Result |ConvertTo-Json | Set-Content ("$name.tmp")
remove-variable Result
