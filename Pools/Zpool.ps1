param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null

    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName ='ZPOOL'
$WalletMode='WALLET'




if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Autoexchange to config.txt wallet, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }



if ($Querymode -like "wallet_*")    {

                    $Wallet=($Querymode -split '_')[1]
                    try {
                        $http="http://www.zpool.ca/api/wallet?address="+$wallet
                        $Zpool_Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                    }
                    catch {}


                    if ($Zpool_Request -ne $null -and $Zpool_Request -ne ""){
                                [PSCustomObject]@{
                                                Pool =$name
                                                currency = $Zpool_Request.currency
                                                balance = $Zpool_Request.balance
                                            }
                            }
                }

    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

                $retries=1
                do {
                        try {
                            $Zpool_Request = Invoke-WebRequest "http://www.zpool.ca/api/status" -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
                            #$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json
                        }
                        catch {start-sleep 2}
                        $retries++
                        if ($Zpool_Request -eq $null -or $Zpool_Request -eq "") {start-sleep 3}
                    } while ($Zpool_Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'ZPOOL API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }
            

                $Zpool_Request | Get-Member -MemberType properties| ForEach-Object {
                                
                                $coin=$Zpool_Request | select -ExpandProperty $_.name

                                $Zpool_Algo =  get-algo-unified-name ($_.name)

                            
                                $Divisor = (Get-Algo-Divisor $Zpool_Algo) / 1000

                                switch ($Zpool_Algo){
                                    "X11"{$Divisor *= 1000}
                                    "qubit"{$Divisor *= 1000}
                                    "quark"{$Divisor *= 1000}
                                    }

                                
                                
                                        [PSCustomObject]@{
                                            Algorithm     = $Zpool_Algo
                                            Info          = $null
                                            Price         = $coin.estimate_current / $Divisor
                                            Price24h      = $coin.estimate_last24h / $Divisor
                                            Protocol      = "stratum+tcp"
                                            Host          = "mine.zpool.ca"
                                            Port          = $coin.port
                                            User          = $CoinsWallets.get_item($Currency)
                                            Pass          = "c=$Currency,$WorkerName,stats"
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
    }

