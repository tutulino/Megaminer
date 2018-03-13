. .\Include.ps1


$config=get_config
$FarmRigs=$config.FarmRigs |ConvertFrom-Json
$smtp=$config.Smtpserver |ConvertFrom-Json

#Look for SMTP Password, propmpt and store if not available

if  ($config.NotificationMail -ne $null -and  $config.NotificationMail -ne "") { #mail notification enabled

        if (Test-Path ".\smtp.ctr") {
            $EncPass = Get-Content -path  ".\smtp.ctr" | ConvertTo-SecureString
            } 
        else 
            {
            
            $PlainPass = Read-Host -Prompt 'TYPE YOUR SMTP SERVER ACCOUNT PASSWORD:'
            $EncPass = Convertto-SecureString $PlainPass -AsPlainText -Force
            ConvertFrom-SecureString $EncPass | set-content -path ".\smtp.ctr"
            Remove-variable PlainPass #for security pass is not stored unencrypted in memory
            }
        
    }

 
$Host.UI.RawUI.WindowTitle = "MM Farm Monitor"

$FarmRigs | ForEach-Object {
        $_ | add-member LastContent $null
        $_ | add-member LastState $null
        $_ | add-member PreviousState $null
        $_ | add-member LastTime $null
        $_ | add-member ChangeStateTime $null
        }

  while ($true)  {
           
           $Requests=@()
           ForEach ($rig in $FarmRigs) {
                        $uri="http://"+$rig.IpOrLanName+':'+$rig.ApiPort
                        $rig.LastTime=get-date
                        if ($rig.PreviousState -ne $rig.LastState) {$rig.PreviousState=$rig.LastState;$rig.ChangeStateTime=get-date }
                        try {
                            $Request = Invoke-restmethod $uri -timeoutsec 5 -UseDefaultCredential 
                            if ($request.ActiveMiners -ne $null) {$rig.LastState="OK"} else {$rig.LastState="ERROR"}
                            $rig.LastContent = $Request 
                             } 
                        catch { 
                            $rig.LastState="ERROR"
                            }
                }         
            try {set_WindowSize 185 60} catch {}
            Clear-Host   
            
            Print_Horizontal_line ("MEGAMINER FARM MONITOR ("+(get-date).tostring("g")+")")
            "" | out-host
            
            $FarmRigs | ForEach-Object {
                        
                        Print_Horizontal_line ($_.IpOrLanName+" ("+$_.LastContent.config.workername+")")

                        if ($_.ChangeStateTime -ne $null) {$ChangeStateElapsed=((get-date) - [datetime]$_.ChangeStateTime).minutes} else {$ChangeStateElapsed=0} #calculates time since state change

                        if ($_.LastState -eq "OK") {

                            "Mode: "+$_.LastContent.params.MiningMode+"       Pool/s: " + ($_.LastContent.params.pools -join ",")+"         Release: "+$_.LastContent.Release |out-host

                            $_.LastContent.Activeminers | Format-Table (
                                    @{Label = "GroupName"; Expression = {$_.GroupName}},   
                                    @{Label = "MMPowLmt"; Expression = {$_.MMPowLmt} ; Align = 'right'},   
                                    @{Label = "LocalSpeed"; Expression = {$_.LocalSpeed} ; Align = 'right'},   
                                    @{Label = "mbtc/Day"; Expression = {$_.mbtc_Day} ; Align = 'right'},   
                                    @{Label = "Rev/Day"; Expression = {$_.Rev_Day} ; Align = 'right'},   
                                    @{Label = "Profit/Day"; Expression = {$_.Profit_Day} ; Align = 'right'},   
                                    @{Label = "Algorithm"; Expression = {$_.Algorithm}},   
                                    @{Label = "Coin"; Expression = {$_.Coin}},   
                                    @{Label = "Miner"; Expression = {$_.Miner}},   
                                    @{Label = "Power"; Expression = {$_.Power} ; Align = 'right'},   
                                    @{Label = "Efficiency"; Expression = {$_.EfficiencyH} ; Align = 'right'},   
                                    @{Label = "Efficiency"; Expression = {$_.EfficiencyW}  ; Align = 'right'},
                                    @{Label = "Pool"; Expression = {$_.Pool}}
                                    ) | out-host
                             }    
                    else {   
                        "" | out-host
                        write-warning "NOT RESPONDING FOR $ChangeStateElapsed MINUTES...."
                        "" | out-host
                        }
                     
                    if ($_.PreviousState -ne $_.LastState -and $_.PreviousState -ne $null) { #change state
                    #if ($true) {

                       

                        if  ($config.NotificationMail -ne $null -and  $config.NotificationMail -ne "" -and $_.Notifications -and $ChangeStateElapsed -gt 2 ) { #mail notification enabled
                  
                                    if ($_.LastState -eq 'OK') {  $mailmsg=$_.IpOrLanName+"("+$_.LastContent.config.workername+") is ONLINE "  }
                                    else {$mailmsg=$_.IpOrLanName+" is OFFLINE" }
                                
                                    $Creds  = New-Object PSCredential $smtp.user,$EncPass
                                    

                                    if ($smtp.ssl) {
                                            Send-MailMessage -usessl -To $config.NotificationMail -From $smtp.user -Subject  $mailmsg -smtp ($smtp.url) -Port ($smtp.port) -Credential $Creds
                                    }
                                        else {
                                            Send-MailMessage  -To $config.NotificationMail -From $smtp.user  -Subject  $mailmsg -smtp ($smtp.url) -Port ($smtp.port) -Credential $creds
                                        }

                           
                            }

                        }
                    
                    }

           start-sleep $Config.RefreshInterval

     }