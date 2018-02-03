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
$AbbName= 'H.RFRY'
$WalletMode='WALLET'
$Result=@()
$RewardType='PPS'



#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************



if ($Querymode -eq "info"){
    $Result= [PSCustomObject]@{
                    Disclaimer = "Autoexchange to @@currency coin specified in config.txt, no registration required"
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
                                $http="http://pool.hashrefinery.com/api/wallet?address="+$Info.user
                                $Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($Request -ne $null -and $Request -ne ""){
                                $Result=  [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $Request.currency
                                                        balance = $Request.balance
                                                    }
                                    }

                        remove-variable Request                                    
                        }

                   

#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


                if ($Querymode -eq "speed")    {
        
                            
                            try {
                                $http="http://pool.hashrefinery.com/api/walletEx?address="+$Info.user
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

        try
        {
            $Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json
        }
        catch
        {
            EXIT
        }


        if ($Request -ne $null) {
                        $Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

                                        $Divisor = (Get_Algo_Divisor $_) / 1000
                                    

                                
                                $Result += [PSCustomObject]@{
                                                Algorithm = get_algo_unified_name $_
                                                Info = $null
                                                Price = [Double]$Request.$_.estimate_current/$Divisor
                                                Price24h =[Double]$Request.$_.estimate_last24h/$Divisor
                                                Protocol = "stratum+tcp"
                                                Host = $_+".us.hashrefinery.com"
                                                Port = $Request.$_.port
                                                User = $CoinsWallets.get_item($currency)
                                                Pass = "c=$Currency,#WorkerName#"
                                                Location = "US"
                                                SSL = $false
                                                AbbName = $AbbName
                                                ActiveOnManualMode    = $ActiveOnManualMode
                                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                                PoolWorkers = $Request.$_.workers
                                                WalletMode=$WalletMode
                                                WalletSymbol    = $currency
                                                PoolName = $Name
                                                Fee = $Request.$_.Fees/100
                                                RewardType=$RewardType
                                    
                                }
                            
                                
                        }
       }

}


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************


$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-variable Result
