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
$ActiveOnAutomatic24hMode = $true
$AbbName ='ZPOOL'
$WalletMode='WALLET'
$Result=@()
$RewardType='PPS'

           

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if ($Querymode -eq "info"){
    $Result=[PSCustomObject]@{
                    Disclaimer = "Autoexchange to config.txt wallet, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                    RewardType=$RewardType
                         }
    }

           

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if ($Querymode -eq "wallet")    {

               
                    try {
                        $http="http://www.zpool.ca/api/wallet?address="+$Info.user
                        $Request = Invoke-WebRequest $http -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                    }
                    catch {}


                    if ($Request -ne $null -and $Request -ne ""){
                        $Result=[PSCustomObject]@{
                                                Pool =$name
                                                currency = $Request.currency
                                                balance = $Request.balance
                                            }
                            remove-variable  Request                                            
                            }
                
                }


                

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if ($Querymode -eq "speed")    {
        
                            
    try {
        $http="http://www.zpool.ca/api/walletEx?address="+$Info.user
        $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
    }
    catch {}
    
    $Result=@()

    if ($Request -ne $null -and $Request -ne ""){
            $Request.Miners |ForEach-Object {
                            $Result += [PSCustomObject]@{
                                PoolName =$name
                                Version = $_.version
                                Algorithm = get_algo_unified_name $_.Algo
                                Workername =($_.password -split ",")[1]
                                Diff     = $_.difficulty
                                Rejected = $_.rejected
                                Hashrate = $_.accepted
                          }     
                    }
            remove-variable Request                                                                                                        
            }


}

           

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

                $retries=1
                do {
                        try {
                            $Request = Invoke-WebRequest "http://www.zpool.ca/api/status" -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
                            #$Request=get-content "..\Request.json" | ConvertFrom-Json
                        }
                        catch {start-sleep 2}
                        $retries++
                        if ($Request -eq $null -or $Request -eq "") {start-sleep 3}
                    } while ($Request -eq $null -and $retries -le 3)
                
                if ($retries -gt 3) {
                                    WRITE-HOST 'ZPOOL API NOT RESPONDING...ABORTING'
                                    EXIT
                                    }
            
                $Currency= if ((get_config_variable "CURRENCY_ZPOOL") -eq "") {get_config_variable "CURRENCY"} else {get_config_variable "CURRENCY_ZPOOL"}        
               
                $Request | Get-Member -MemberType properties| ForEach-Object {
                                
                                $coin=$Request | Select-Object -ExpandProperty $_.name

                                $Zpool_Algo =  get_algo_unified_name ($_.name)

                            
                                $Divisor = (Get_Algo_Divisor $Zpool_Algo) / 1000

                                switch ($Zpool_Algo){
                                    "X11"{$Divisor *= 1000}
                                    "qubit"{$Divisor *= 1000}
                                    "quark"{$Divisor *= 1000}
                                    "keccak"{$Divisor *= 1000}
                                    }

                
                                    
                                    $Result+=[PSCustomObject]@{
                                            Algorithm     = $Zpool_Algo
                                            Info          = $Zpool_Algo
                                            Price         = $coin.estimate_current / $Divisor
                                            Price24h      = $coin.estimate_last24h / $Divisor
                                            Protocol      = "stratum+tcp"
                                            Host          = $_.name+".mine.zpool.ca"
                                            Port          = $coin.port
                                            User          = $CoinsWallets.get_item($Currency)
                                            Pass          = "c=$Currency,#Workername#"
                                            Location      = "US"
                                            SSL           = $false
                                            Symbol        = $null
                                            AbbName       = $AbbName
                                            ActiveOnManualMode    = $ActiveOnManualMode
                                            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                            PoolWorkers = $coin.workers
                                            WalletMode=$WalletMode
                                            WalletSymbol=$Currency
                                            PoolName = $Name
                                            Fee = $coin.Fees/100
                                            RewardType=$RewardType
                                            }
                           }

    remove-variable Request                           
    }


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable Result
