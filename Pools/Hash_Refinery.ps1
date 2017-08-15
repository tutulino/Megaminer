param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null #Info/detail"
    )

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $false
$ActiveOnAutomaticMode = $true
$AbbName= 'H.RFRY'



if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Autoexchange to config.txt wallet, no registration required"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    AbbName=$AbbName
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



        $HR_Request | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach-Object {

                        $Divisor = (Get-Algo-Divisor $_) / 1000
                    

                        if((Get-Stat -Name "$($Name)_$($HR_Algorithm)_Profit") -eq $null){$Stat = Set-Stat -Name "$($Name)_$($HR_Algorithm)_Profit" -Value ([Double]$HR_Request.$_.estimate_last24h/$Divisor)}
                        else{$Stat = Set-Stat -Name "$($Name)_$($HR_Algorithm)_Profit" -Value ([Double]$HR_Request.$_.estimate_current/$Divisor)}
                        
                
                            [PSCustomObject]@{
                                Algorithm =  get-algo-unified-name $_
                                Info = $null
                                Price = $Stat.Live
                                StablePrice = $Stat.Week
                                MarginOfError = $Stat.Fluctuation
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
                    
                }
            
        }
}