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

        try
        {
            $HR_Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UseBasicParsing | ConvertFrom-Json
        }
        catch
        {
            return
        }

        if(-not $HR_Request){return}

       
        $Location = "US"

        $HR_Request | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | foreach {
            $HR_Host = "$_.us.hashrefinery.com"
            $HR_Port = $HR_Request.$_.port
            $HR_Algorithm = Get-Algorithm $HR_Request.$_.name
            $HR_Coin = "Unknown"



            $Divisor = Get-Algo-Divisor $HR_Algorithm
          

            if((Get-Stat -Name "$($Name)_$($HR_Algorithm)_Profit") -eq $null){$Stat = Set-Stat -Name "$($Name)_$($HR_Algorithm)_Profit" -Value ([Double]$HR_Request.$_.estimate_last24h/$Divisor)}
            else{$Stat = Set-Stat -Name "$($Name)_$($HR_Algorithm)_Profit" -Value ([Double]$HR_Request.$_.estimate_current/$Divisor)}
            
            if($Wallet)
            {
                [PSCustomObject]@{
                    Algorithm = $HR_Algorithm
                    Info = $HR
                    Price = $Stat.Live
                    StablePrice = $Stat.Week
                    MarginOfError = $Stat.Fluctuation
                    Protocol = "stratum+tcp"
                    Host = $HR_Host
                    Port = $HR_Port
                    User = $Wallet
                    Pass = "c=$Currency,$WorkerName,stats"
                    Location = $Location
                    SSL = $false
                    AbbName       = "HF"
                    ActiveOnManualMode    = $ActiveOnManualMode
                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                    
                }
            }
        }
}