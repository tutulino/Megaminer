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

    


    if ($Querymode -eq "APIKEY")    {

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

                            
                            try {
                                    $http="http://"+$Info.Coin+".miningpoolhub.com/index.php?page=api&action=getdashboarddata&api_key="+$Info.ApiKey+"&id="
                                    #$http |write-host                                
                                    $MiningPoolHub_Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json | Select-Object -ExpandProperty getdashboarddata | Select-Object -ExpandProperty data
                            }
                            catch {}
        
        
                            if ($MiningPoolHub_Request -ne $null -and $MiningPoolHub_Request -ne ""){
                                $Result = [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Info.OriginalCoin
                                                        balance = $MiningPoolHub_Request.balance.confirmed+$MiningPoolHub_Request.balance.unconfirmed+$MiningPoolHub_Request.balance_for_auto_exchange.confirmed+$MiningPoolHub_Request.balance_for_auto_exchange.unconfirmed
                                                    }
                                Remove-variable MiningPoolHub_Request                                    
                                }

                        
                        }

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){


            try {
                $MiningPoolHub_Request = Invoke-WebRequest "http://miningpoolhub.com/index.php?page=api&action=getminingandprofitsstatistics" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json
            }
            catch {
                    WRITE-HOST 'MINING POOL HUB API NOT RESPONDING...ABORTING'
                    EXIT
            }
            
            if (-not $MiningPoolHub_Request.success) { WRITE-HOST 'MINING POOL HUB API NOT RESPONDING...ABORTING'; EXIT}


            $Locations = "Europe", "US", "Asia"

            $MiningPoolHub_Request.return | ForEach-Object {

                $MiningPoolHub_Algorithm= get_algo_unified_name $_.algo
                $MiningPoolHub_Coin =   get_coin_unified_name $_.coin_name

                $MiningPoolHub_OriginalAlgorithm=  $_.algo
                $MiningPoolHub_OriginalCoin=  $_.coin_name


                $MiningPoolHub_Hosts = $_.host_list.split(";")
                $MiningPoolHub_Port = $_.port

                $Divisor = [double]1000000000
    
                $MiningPoolHub_Price=[Double]($_.profit / $Divisor)

                $Locations | ForEach-Object {
                        $enableSSL = ( $NH_Algorithm -eq "Cryptonight" -or  $NH_Algorithm -eq "Equihash" )
                        $Location = $_

                                $Result+=[PSCustomObject]@{
                                            Algorithm     = $MiningPoolHub_Algorithm
                                            Info          = $MiningPoolHub_Coin
                                            Price         = $MiningPoolHub_Price
                                            Price24h      = $null #MPH not send this on api
                                            Protocol      = If ($enableSSL) {"stratum+ssl"} else {"stratum+tcp"}
                                            Host          = $MiningPoolHub_Hosts | Sort-Object -Descending {$_ -ilike "$Location*"} | Select-Object -First 1
                                            Port          = $_.port
                                            User          = "$UserName.#WorkerName#"
                                            Pass          = "x"
                                            Location      = $Location
                                            SSL           = $enableSSL
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


Remove-variable MiningPoolHub_Request
}

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
