param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $false
$AbbName = 'NH'
$WalletMode = "WALLET"
$Result=@()
$RewardType='PPS'


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if ($Querymode -eq "info"){
    $Result =  [PSCustomObject]@{
                    Disclaimer = "No registration, Autoexchange to BTC always"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ActiveOnAutomatic24hMode=$ActiveOnAutomatic24hMode
                    ApiData = $True
                    AbbName=$AbbName
                    WalletMode=$WalletMode
                    RewardType=$RewardType
                         }
    }







#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

    if ($Querymode -eq "speed")    {
       
        $Info.user=($Info.user -split '\.')[0]
                            
        try {
            $http="https://api.nicehash.com/api?method=stats.provider.workers&addr="+$Info.user
            $Request = Invoke-WebRequest -UserAgent "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36"  $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
        }
        catch {}
        
        $Result=@()
    
        if ($Request.Result.Workers -ne $null -and $Request.Result.Workers -ne ""){

                $Request.Result.Workers |ForEach-Object {
                                $Result += [PSCustomObject]@{
                                        PoolName =$name
                                        WorkerName =$_[0]
                                        Rejected = $_[4]
                                        Hashrate = [double]$_[1].a * 1000000
                              }     
                        }
                remove-variable Request                                                                                                        
                }
    
    
    }
    






#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


if ($Querymode -eq "wallet")    {
        
                            $Info.user=($Info.user -split '\.')[0]

                            try {
                                $http="https://api.nicehash.com/api?method=stats.provider&addr="+$Info.user
                                $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                                $Request = $Request |Select-Object -ExpandProperty result  |Select-Object -ExpandProperty stats 
                            }
                            catch {}
        
                            if ($Request -ne $null -and $Request -ne ""){
                                $Result =   [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = "BTC"
                                                        balance = ($Request | Measure-Object -Sum balance).sum
                                                    }
                                    }

                        Remove-variable Request
                        }

                        
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        try {
            $Request = Invoke-WebRequest "https://api.nicehash.com/api?method=simplemultialgo.info" -UseBasicParsing -timeoutsec 3 | ConvertFrom-Json 
            $Request = $Request |Select-Object -expand result |Select-Object -expand simplemultialgo
            
        }
        catch {
                    WRITE-HOST 'Nicehash API NOT RESPONDING...ABORTING'
                    EXIT
                }

        

        $Locations=@()
        $Locations += [PSCustomObject]@{NhLocation ='USA';MMlocation='US'}
        $Locations += [PSCustomObject]@{NhLocation ='EU';MMlocation='EU'}

        $Request | ForEach-Object {


                    $NH_Algorithm = get_algo_unified_name ($_.name)
                    $NH_AlgorithmOriginal =$_.name
                    
                    $Divisor = 1000000000

                    switch ($NH_Algorithm) {
                            "Ethash" {$NH_coin="Ethereum"} #must force to allow dualmining Ethereum+?
                            "Lbry" {$NH_coin="Lbry"}
                            "Pascal" {$NH_coin="Pascal"}
                            "Blake2b" {$NH_coin="Siacoin"}
                            "Blake14r" {$NH_coin="Decred"}
                            default {$NH_coin=$NH_Algorithm}
                            }



                    foreach ($location in $Locations) {
            

                        $Result+= [PSCustomObject]@{
                                        Algorithm     = $NH_Algorithm
                                        Info          = $NH_coin
                                        Price         = [double]($_.paying / $Divisor)
                                        Price24h      = [double]($_.paying / $Divisor)
                                        Protocol      = "stratum+tcp"
                                        Host          = ($_.name)+"."+$location.NhLocation+".nicehash.com"
                                        Port          = $_.port
                                        User          = $(if ($CoinsWallets.get_item('BTC_NICE') -ne $null) {$CoinsWallets.get_item('BTC_NICE')} else {$CoinsWallets.get_item('BTC')})+'.'+"#WorkerName#"
                                        Pass          = "x"
                                        Location      = $location.MMLocation
                                        SSL           = $false
                                        Symbol        = $null
                                        AbbName       = $AbbName
                                        ActiveOnManualMode    = $ActiveOnManualMode
                                        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                        PoolName = $Name
                                        WalletMode      = $WalletMode
                                        WalletSymbol = "BTC"
                                        OriginalAlgorithm =  $SNH_AlgorithmOriginal
                                        OriginalCoin = $NH_coin
                                        Fee = $(if ($CoinsWallets.get_item('BTC_NICE') -ne $null) {0.02} else {0.04})
                                        EthStMode = 3
                                        RewardType=$RewardType
                                            
                                        }
                        }
                }

    Remove-variable Request
    }


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-variable Result


