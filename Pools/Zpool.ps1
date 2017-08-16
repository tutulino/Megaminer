param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$AbbName ='ZPOOL'

if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Autoexchange to config.txt wallet, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    AbbName=$AbbName
                         }
    }


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

                $retries=1
                do {
                        try {
                            $Zpool_Request = Invoke-WebRequest "http://www.zpool.ca/api/status" -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
                            #$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json
                        }
                        catch {}
                        $retries++
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

                                
                                
                                if ((Get-Stat -Name "Zpool_$($Zpool_Algo)_Profit") -eq $null) {$Stat = Set-Stat -Name "Zpool_$($Zpool_Algo)_Profit" -Value ([Double]$coin.estimate_current / $Divisor * (1 - 0.05))}
                                else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algo)_Profit" -Value ([Double]$coin.estimate_current / $Divisor)}

                                
                                        [PSCustomObject]@{
                                            Algorithm     = $Zpool_Algo
                                            Info          = $null
                                            Price         = $Stat.Live
                                            StablePrice   = $Stat.Week
                                            MarginOfError = $Stat.Week_Fluctuation
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
                                            }
                           }
    }

