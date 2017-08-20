param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $true
$AbbName= 'H.RFRY'
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
                                $http="http://pool.hashrefinery.com/api/wallet?address="+$wallet
                                $HR_Request = Invoke-WebRequest $http -UseBasicParsing -timeoutsec 10 | ConvertFrom-Json 
                            }
                            catch {}
        
        
                            if ($HR_Request -ne $null -and $HR_Request -ne ""){
                                        [PSCustomObject]@{
                                                        Pool =$name
                                                        currency = $HR_Request.currency
                                                        balance = $HR_Request.balance
                                                    }
                                    }
                        }



if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        try
        {
            $HR_Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UseBasicParsing | ConvertFrom-Json
        }
        catch
        {
            EXIT
        }



        $HR_Request | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {

                        $Divisor = (Get-Algo-Divisor $_) / 1000
                    

                
                            [PSCustomObject]@{
                                Algorithm =  get-algo-unified-name $_
                                Info = $null
                                Price = [Double]$HR_Request.$_.estimate_current/$Divisor
                                Price24h =[Double]$HR_Request.$_.estimate_last24h/$Divisor
                                Protocol = "stratum+tcp"
                                Host = $_+".us.hashrefinery.com"
                                Port = $HR_Request.$_.port
                                User = $CoinsWallets.get_item($Currency)
                                Pass = "c=$Currency,$WorkerName,stats"
                                Location = "US"
                                SSL = $false
                                AbbName = $AbbName
                                ActiveOnManualMode    = $ActiveOnManualMode
                                ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                PoolWorkers = $HR_Request.$_.workers
                                WalletMode=$WalletMode
                                PoolName = $Name
                    
                }
            
        }
}