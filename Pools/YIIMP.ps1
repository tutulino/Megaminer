param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true



if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "No registration, No autoexchange, need wallet for each coin on config.txt"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ApiData = $True
                         }
    }


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        try {
            $Yiimp_Request = Invoke-WebRequest "http://yiimp.ccminer.org/api/currencies" -UseBasicParsing | ConvertFrom-Json 
            #$Yiimp_Request=get-content "..\Yiimp_request.json" | ConvertFrom-Json
        }
        catch {
                    WRITE-HOST 'YIIMP API NOT RESPONDING...ABORTING'
                    EXIT
                }

        $Locations = "US"

        $Yiimp_Request | Get-Member -MemberType properties| ForEach-Object {
            $coin=$Yiimp_Request | select -ExpandProperty $_.name
            $Yiimp_currency=$_.name
            $Yiimp_Hosts = "yiimp.ccminer.org"
            $Yiimp_Port = $coin.port
            $Yiimp_Algorithm = $coin.algo
            $Yiimp_Coin = $coin.name
            $Yiimp_Workers = $coin.Workers
            $Yiimp_PoolHashRate = $coin.HashRate
            $Yiimp_24h_blocks = $coin."24h_blocks"
            

            
            

            $Divisor = 1000000000
            
            switch($Yiimp_Algorithm)
            {
                "equihash"{$Divisor /= 1000}
                "blake2s"{$Divisor *= 1000}
                "blakecoin"{$Divisor *= 1000}
                "decred"{$Divisor *= 1000}
            }
            if ((Get-Stat -Name "Yiimp_$($Yiimp_Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "Yiimp_$($Yiimp_Coin)_Profit" -Value ([Double]$coin.estimate / $Divisor * (1 - 0.05))}
            else {$Stat = Set-Stat -Name "$($Name)_$($Yiimp_Coin)_Profit" -Value ([Double]$coin.estimate / $Divisor)}


            $Locations | ForEach-Object {
            $Location = $_

                    $User=$CoinsWallets.get_item($Yiimp_currency)

                    [PSCustomObject]@{
                        Algorithm     = $Yiimp_Algorithm
                        Info          = $Yiimp_Coin
                        Price         = $Stat.Live
                        StablePrice   = $Stat.Week
                        MarginOfError = $Stat.Week_Fluctuation
                        Protocol      = "stratum+tcp"
                        Host          = $Yiimp_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                        Port          = $Yiimp_Port
                        User          = $User
                        Pass          = "c=$Yiimp_currency,ID=$WorkerName,stats"
                        Location      = $Location
                        SSL           = $false
                        Symbol        = $Yiimp_currency
                        AbbName       = "YI"
                        ActiveOnManualMode    = $ActiveOnManualMode
                        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                        Workers       = $Yiimp_Workers
                        PoolHashRate  = $Yiimp_PoolHashRate
                        Blocks_24h    = $Yiimp_24h_blocks
                        }
                 
            }
        }
    }

