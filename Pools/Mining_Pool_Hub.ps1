param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $false
$AbbName="MPH"
$WalletMode="APIKEY"
$Result=@()

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if ($Querymode -eq "info"){
    $Result = [PSCustomObject]@{
                    Disclaimer = "Registration required, set username/workername in config.txt file"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                         }
    }



          

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    


    if ($Querymode -eq "APIKEY" -or $Querymode -eq "SPEED")    {

                            Switch($Info.coin) {
                                "DigiByte" {
                                    switch($Info.Algorithm){
                                                        "qubit"{$Info.Coin="digibyte-qubit"}
                                                        "myriad-groestl"{$Info.Coin="digibyte-groestl"}
                                                        "skein"{$Info.Coin="digibyte-skein"}
                                                        }               

                                            }       
                                "Myriad" {
                                    switch($Info.Algorithm){
                                                            "Skein"{$Info.Coin="myriadcoin-skein"}
                                                            "myriad-groestl"{$Info.Coin="myriadcoin-groestl"}
                                                            "yescrypt"{$Info.Coin="myriadcoin-yescrypt"}
                                                            }                
                                        }
                                "Verge" {$Info.Coin=$Info.coin+'-'+$Info.Algorithm}
                                }


                            #***************************
                            if ($Querymode -eq "APIKEY" ) {

                                        try {
                                                $http="http://"+$Info.Coin+".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key="+$Info.ApiKey+"&id="
                                                $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json | Select-Object -ExpandProperty getdashboarddata | Select-Object -ExpandProperty data
                                        }
                                        catch {}
                    
                    
                                        if ($Request -ne $null -and $Request -ne ""){
                                            $Result = [PSCustomObject]@{
                                                                    Pool =$name
                                                                    currency = $Info.OriginalCoin
                                                                    balance = $Request.balance.confirmed+$Request.balance.unconfirmed+$Request.balance_for_auto_exchange.confirmed+$Request.balance_for_auto_exchange.unconfirmed
                                                                }
                                            Remove-variable Request                                    
                                            }
                                        }
                            #***************************


                            if ($Querymode -eq "SPEED")    {
        
                        
                                try {
                                    $http="http://"+$Info.Coin+".miningpoolhub.com/index.php?page=api&action=getuserworkers&api_key="+$Info.ApiKey
                                    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12                              
                                    $Request =  Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5  | ConvertFrom-Json
                                    }
                                catch {
                                      }
                            
                                if ($Request -ne $null -and $Request -ne ""){
                                $Request.getuserworkers.data | ForEach-Object {
                                                $Result += [PSCustomObject]@{
                                                        PoolName =$name
                                                        Diff     = $_.difficulty
                                                        Workername =($_.username -split "\.")[1]
                                                        Hashrate = $_.hashrate
                                                        }
                                                }
                                                    
                                          }
                            
                                }
                        
                        }

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){


            try {
                $Request = Invoke-WebRequest "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json
            }
            catch {
                    WRITE-HOST 'MINING POOL HUB API NOT RESPONDING...ABORTING'
                    EXIT
            }
            
            if (-not $Request.success) { WRITE-HOST 'MINING POOL HUB API NOT RESPONDING...ABORTING'; EXIT}


            $Locations = "Europe", "US", "Asia"

            $Request.return | ForEach-Object {

                $MiningPoolHub_Algorithm= get_algo_unified_name $_.algo
                $MiningPoolHub_Coin =   get_coin_unified_name $_.coin_name

                $MiningPoolHub_OriginalAlgorithm=  $_.algo
                $MiningPoolHub_OriginalCoin=  $_.coin_name


                $MiningPoolHub_Hosts = $_.host_list.split(";")
                $MiningPoolHub_Port = $_.port

                $Divisor = [double]1000000000
    
                $MiningPoolHub_Price=[Double]($_.profit / $Divisor)

                $Locations | ForEach-Object {
                        $Location = $_

                                $Result+=[PSCustomObject]@{
                                            Algorithm     = $MiningPoolHub_Algorithm
                                            Info          = $MiningPoolHub_Coin
                                            Price         = $MiningPoolHub_Price
                                            Price24h      = $null #MPH not send this on api
                                            Protocol      = "stratum+tcp"
                                            Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                                            Port          = $MiningPoolHub_Port
                                            User          = "$UserName.#WorkerName#"
                                            Pass          = "x"
                                            Location      = $Location
                                            SSL           = $false
                                            Symbol        = ""
                                            AbbName       = $AbbName
                                            ActiveOnManualMode    = $ActiveOnManualMode
                                            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                            WalletMode     = $WalletMode
                                            WalletSymbol= $_.coin_name
                                            PoolName = $Name
                                            OriginalAlgorithm = $MiningPoolHub_OriginalAlgorithm
                                            OriginalCoin = $MiningPoolHub_OriginalCoin
                                            Fee = 0.009
                                            EthStMode = 3
                                            }
                        }

            }


Remove-variable Request
}

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
