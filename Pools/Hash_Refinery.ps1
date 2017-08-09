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
            $Zpool_Request = Invoke-WebRequest "http://pool.hashrefinery.com/api/status" -UseBasicParsing | ConvertFrom-Json
        }
        catch
        {
            return
        }

        if(-not $Zpool_Request){return}

       
        $Location = "US"

        $Zpool_Request | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | foreach {
            $Zpool_Host = "$_.us.hashrefinery.com"
            $Zpool_Port = $Zpool_Request.$_.port
            $Zpool_Algorithm = Get-Algorithm $Zpool_Request.$_.name
            $Zpool_Coin = "Unknown"

            $Divisor = 1000000
            
            switch($Zpool_Algorithm)
            {
                "equihash"{$Divisor /= 1000}
                "blake2s"{$Divisor *= 1000}
                "blakecoin"{$Divisor *= 1000}
                "decred"{$Divisor *= 1000}
            }

            if((Get-Stat -Name "$($Name)_$($Zpool_Algorithm)_Profit") -eq $null){$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_last24h/$Divisor)}
            else{$Stat = Set-Stat -Name "$($Name)_$($Zpool_Algorithm)_Profit" -Value ([Double]$Zpool_Request.$_.estimate_current/$Divisor)}
            
            if($Wallet)
            {
                [PSCustomObject]@{
                    Algorithm = $Zpool_Algorithm
                    Info = $Zpool
                    Price = $Stat.Live
                    StablePrice = $Stat.Week
                    MarginOfError = $Stat.Fluctuation
                    Protocol = "stratum+tcp"
                    Host = $Zpool_Host
                    Port = $Zpool_Port
                    User = $Wallet
                    Pass = "c=$Currency"
                    Location = $Location
                    SSL = $false
                    AbbName       = "HF"
                    ActiveOnManualMode    = $ActiveOnManualMode
                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                    
                }
            }
        }
}