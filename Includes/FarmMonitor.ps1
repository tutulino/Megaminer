. .\Include.ps1


$config = get_config
$FarmRigs = $config.FarmRigs |ConvertFrom-Json
$smtp = $config.Smtpserver |ConvertFrom-Json

#Look for SMTP Password, propmpt and store if not available

if ($config.NotificationMail -ne $null -and $config.NotificationMail -ne "") {
    #mail notification enabled

    if (Test-Path ".\smtp.ctr") {
        $EncPass = Get-Content -path  ".\smtp.ctr" | ConvertTo-SecureString
    } else {

        $PlainPass = Read-Host -Prompt 'TYPE YOUR SMTP SERVER ACCOUNT PASSWORD:'
        $EncPass = Convertto-SecureString $PlainPass -AsPlainText -Force
        ConvertFrom-SecureString $EncPass | set-content -path ".\smtp.ctr"
        Remove-variable PlainPass #for security pass is not stored unencrypted in memory
    }

}


$Host.UI.RawUI.WindowTitle = "MM Farm Monitor"

$FarmRigs | ForEach-Object {
    $_ | add-member LastContent $null
    $_ | add-member State $null
    $_ | add-member LastState $null
    $_ | add-member LastTime $null
    $_ | add-member ChangeStateTime (get-date)
    $_ | add-member PendingNotify $false
    $_ | add-member Workername ""
}

while ($true) {

    $Requests = @()
    ForEach ($rig in $FarmRigs) {
        $uri = "http://" + $rig.IpOrLanName + ':' + $rig.ApiPort
        $rig.LastTime = get-date
        if ($rig.LastState -ne $rig.State -and $rig.LastState -ne $null) {
            $rig.ChangeStateTime = get-date
            if ($rig.PendingNotify)
            {$rig.PendingNotify = $false} #state changes before last change was notified, must anulate notify
            else
            {$rig.PendingNotify = $true}
        }
        $rig.LastState = $rig.State
        try {
            $Request = Invoke-restmethod $uri -timeoutsec 10 -UseDefaultCredential
            if ($request.ActiveMiners -ne $null) {$rig.State = "OK"} else {$rig.State = "ERROR"}
            $rig.LastContent = $Request
        } catch {
            $rig.State = "ERROR"
        }
    }
    try {set_WindowSize 185 60} catch {}
    Clear-Host

    Print_Horizontal_line ("Forager FARM MONITOR (" + (get-date).tostring("g") + ")")
    "" | out-host

    $FarmRigs | ForEach-Object {

        Print_Horizontal_line ($_.IpOrLanName + " (" + $_.LastContent.config.workername + ")")

        if ($_.ChangeStateTime -ne $null) {$ChangeStateElapsed = ((get-date) - [datetime]$_.ChangeStateTime).minutes} else {$ChangeStateElapsed = 0} #calculates time since state change

        if ($_.State -eq "OK") {

            "Mode: " + $_.LastContent.params.MiningMode + "       Pool/s: " + ($_.LastContent.params.pools -join ",") + "         Release: " + $_.LastContent.Release |out-host


            $_.Workername = $_.LastContent.config.workername


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
        } else {
            "" | out-host
            write-warning "NOT RESPONDING FOR $ChangeStateElapsed MINUTES...."
            "" | out-host
        }

        if ($ChangeStateElapsed -gt 4) {
            #change state 5 minutes ago
            #if ($true) {

            if ($config.NotificationMail -ne $null -and $config.NotificationMail -ne "" -and $_.Notifications -and $_.PendingNotify ) {
                #mail notification enabled

                $_.PendingNotify = $false

                $mailmsg = $_.IpOrLanName + "(" + $_.workername + ") is "

                if ($_.State -eq 'OK') {$mailmsg += "ONLINE"} else {$mailmsg += "OFFLINE"}

                $Creds = New-Object PSCredential $smtp.user, $EncPass

                if ($smtp.ssl) {
                    Send-MailMessage -usessl -To $config.NotificationMail -From $smtp.user -Subject  $mailmsg -smtp ($smtp.url) -Port ($smtp.port) -Credential $Creds
                } else {
                    Send-MailMessage  -To $config.NotificationMail -From $smtp.user  -Subject  $mailmsg -smtp ($smtp.url) -Port ($smtp.port) -Credential $creds
                }


            }

        }

    }

    start-sleep $Config.RefreshInterval

}