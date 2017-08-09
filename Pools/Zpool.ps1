param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true



if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Autoexchange to config.txt wallet, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                         }
    }




    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

             

                try {
                    $Zpool_Request = Invoke-WebRequest "http://www.zpool.ca/api/currencies" -UseBasicParsing | ConvertFrom-Json 
                    #$Zpool_Request=get-content "..\zpool_request.json" | ConvertFrom-Json
                }
                catch {
                    WRITE-HOST 'ZPOOL API NOT RESPONDING...ABORTING'
                    EXIT
                }


                $Locations = "US"

                $Zpool_Request | Get-Member -MemberType properties| ForEach-Object {
                    $coin=$Zpool_Request | select -ExpandProperty $_.name
                    $Zpool_currency=$_.name
                    $Zpool_Hosts = "mine.zpool.ca"
                    $Zpool_Port = $coin.port
                    $Zpool_Algorithm = $coin.algo
                    $Zpool_Coin = $coin.name
                

                    $Divisor = 1000000000
                    
                    switch($Zpool_Algorithm)
                    {
                        "skein"{$Divisor *= 10}
                        "equihash"{$Divisor /= 1000}
                        "blake2s"{$Divisor *= 1000}
                        "blakecoin"{$Divisor *= 1000}
                        "decred"{$Divisor *= 1000}
                    }
                    if ((Get-Stat -Name "Zpool_$($Zpool_Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "Zpool_$($Zpool_Coin)_Profit" -Value ([Double]$coin.estimate / $Divisor * (1 - 0.05))}
                    else {$Stat = Set-Stat -Name "$($Name)_$($Zpool_Coin)_Profit" -Value ([Double]$coin.estimate / $Divisor)}

                    $Locations | ForEach-Object {
                        $Location = $_
                            [PSCustomObject]@{
                                Algorithm     = $Zpool_Algorithm
                                Info          = $Zpool_Coin
                                Price         = $Stat.Live
                                StablePrice   = $Stat.Week
                                MarginOfError = $Stat.Week_Fluctuation
                                Protocol      = "stratum+tcp"
                                Host          = $Zpool_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                                Port          = $Zpool_Port
                                User          = $Wallet
                                Pass          = "c=$Currency,$WorkerName"
                                Location      = $Location
                                SSL           = $false
                                Symbol        = $Zpool_currency
                                AbbName       = "ZP"
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode

                                }
                    }
                }
}

