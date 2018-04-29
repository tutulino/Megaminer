Add-Type -Path .\Includes\OpenCL\*.cs



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function set_Nvidia_Clocks ([int]$PowerLimitPercent, [string]$Devices) {

    $device = $Devices -split ','
    $device | ForEach-Object {

        $xpr = ".\includes\nvidia-smi.exe -i " + $_ + " --query-gpu=power.default_limit --format=csv,noheader"
        $PowerDefaultLimit = [int]((Invoke-Expression $xpr) -replace 'W', '')

        #powerlimit change must run in admin mode
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo ".\includes\nvidia-smi.exe"
        $newProcess.Verb = "runas"
        #$newProcess.UseShellExecute = $false
        $newProcess.Arguments = "-i " + $_ + " -pl " + [Math]::Floor([int]($PowerDefaultLimit -replace ' W', '') * ($PowerLimitPercent / 100))
        [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    }
    Remove-Variable newprocess
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function set_Nvidia_Powerlimit ([int]$PowerLimitPercent, [string]$Devices) {

    $device = $Devices -split ','
    $device | ForEach-Object {

        $xpr = ".\includes\nvidia-smi.exe -i " + $_ + " --query-gpu=power.default_limit --format=csv,noheader"
        $PowerDefaultLimit = [int]((Invoke-Expression $xpr) -replace 'W', '')


        #powerlimit change must run in admin mode
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo ".\includes\nvidia-smi.exe"
        $newProcess.Verb = "runas"
        #$newProcess.UseShellExecute = $false
        $newProcess.Arguments = "-i " + $_ + " -pl " + [Math]::Floor([int]($PowerDefaultLimit -replace ' W', '') * ($PowerLimitPercent / 100))
        [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    }
    Remove-Variable newprocess
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_ComputerStats {
    [cmdletbinding()]
    $avg = Get-CimInstance win32_processor | Measure-Object -property LoadPercentage -Average | ForEach-Object {$_.Average}
    $mem = Get-CimInstance win32_operatingsystem | ForEach-Object {"{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory) * 100) / $_.TotalVisibleMemorySize)}
    $memV = Get-CimInstance win32_operatingsystem | ForEach-Object {"{0:N2}" -f ((($_.TotalVirtualMemorySize - $_.FreeVirtualMemory) * 100) / $_.TotalVirtualMemorySize)}
    $free = Get-CimInstance Win32_Volume -Filter "DriveLetter = 'C:'" | ForEach-Object {"{0:N2}" -f (($_.FreeSpace / $_.Capacity) * 100)}
    $nprocs = (Get-Process).count
    if (Get-Command "Get-NetTCPConnection" -ErrorAction SilentlyContinue) {
        $Conns = (Get-NetTCPConnection).count
    } else {
        $Error.Remove($Error[$Error.Count - 1])
    }

    "AverageCpu = $avg % | MemoryUsage = $mem % | VirtualMemoryUsage = $memV % | PercentCFree = $free % | Processes = $nprocs | Connections = $Conns"
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
function ErrorsTolog ($LogFile) {

    for ($i = 0; $i -lt $error.count; $i++) {
        if ($error[$i].InnerException.Paramname -ne "scopeId") {
            # errors in debug
            $Msg = "###### ERROR ##### " + [string]($error[$i]) + ' ' + $error[$i].ScriptStackTrace
            WriteLog $msg $LogFile
        }

    }
    $error.clear()
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function replace_foreach_device {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFileArguments,
        [Parameter(Mandatory = $false)]
        [string]$Devices
    )



    #search string to replace

    $ConfigFileArguments = $ConfigFileArguments -replace [Environment]::NewLine, "#NL#" #replace carriage return for Select-string search (only search in each line)

    $Match = $ConfigFileArguments | Select-String -Pattern "#FOR_EACH_GPU#.*?#END_FOR_EACH_GPU#"
    if ($Match -ne $null) {

        $Match.Matches | ForEach-Object {
            $Base = $_.value -replace "#FOR_EACH_GPU#", "" -replace "#END_FOR_EACH_GPU#", ""
            $Final = ""
            $Devices -split ',' | ForEach-Object {$Final += ($base -replace "#GPUID#", $_)}
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index) + $final + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }


    $Match = $ConfigFileArguments | Select-String -Pattern "#REMOVE_LAST_CHARACTER#"
    if ($Match -ne $null) {
        $Match.Matches | ForEach-Object {
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index - 1) + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }

    $ConfigFileArguments = $ConfigFileArguments -replace "#NL#", [Environment]::NewLine #replace carriage return for Select-string search (only search in each line)
    $ConfigFileArguments
}
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_next_free_port {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LastUsedPort
    )


    if ($LastUsedPort -lt 2000) {$FreePort = 2001} else {$FreePort = $LastUsedPort + 1} #not allow use of <2000 ports
    while (Query_TCPPort -Server 127.0.0.1 -Port $FreePort -timeout 100) {$FreePort = $LastUsedPort + 1}
    $FreePort
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Query_TCPPort {
    param([string]$Server, [int]$Port, [int]$Timeout)

    $Connection = New-Object System.Net.Sockets.TCPClient

    try {
        $Connection.SendTimeout = $Timeout
        $Connection.ReceiveTimeout = $Timeout
        $Connection.Connect($Server, $Port) | out-Null
        $Connection.Close
        $Connection.Dispose
        return $true #port is occupied
    } catch {
        $Error.Remove($error[$Error.Count - 1])
        return $false  #port is free
    }
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Kill_Process {
    param(
        [Parameter(Mandatory = $true)]
        $Process
    )

    $sw = [Diagnostics.Stopwatch]::new()
    try {
        $Process.CloseMainWindow() | Out-Null
        $sw.Start()
        do {
            if ($sw.Elapsed.TotalSeconds -gt 1) {
                Stop-Process -InputObject $Process -Force
            }
            if (!$Process.HasExited) {
                Start-Sleep -Milliseconds 1
            }
        } while (!$Process.HasExited)
    } finally {
        $sw.Stop()
        if (!$Process.HasExited) {
            Stop-Process -InputObject $Process -Force
        }
    }
    Remove-Variable sw
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_devices_information ($Types) {
    [cmdletbinding()]

    $Devices = @()

    #NVIDIA
    if ($Types | Where-Object Type -eq 'NVIDIA') {
        $DeviceId = 0
        Invoke-Expression ".\includes\nvidia-smi.exe --query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit --format=csv,noheader" | ForEach-Object {
            $SMIresultSplit = $_ -split (",")
            if ($SMIresultSplit.count -gt 10) {
                #less is error or no NVIDIA gpu present

                $Group = ($Types | Where-Object type -eq 'NVIDIA' | Where-Object DeviceArray -contains $DeviceId).groupname

                $Card = [pscustomObject]@{
                    Type               = 'NVIDIA'
                    Id                 = $DeviceId
                    Group              = $Group
                    Name               = $SMIresultSplit[0]
                    Utilization        = if ($SMIresultSplit[1] -like "*Supported*") {100} else {[int]($SMIresultSplit[1] -replace '%', '')} #If we dont have real Utilization, at least make the watchdog happy
                    Utilization_Memory = if ($SMIresultSplit[2] -like "*Supported*") {$null} else {[int]($SMIresultSplit[2] -replace '%', '')}
                    Temperature        = if ($SMIresultSplit[3] -like "*Supported*") {$null} else {[int]($SMIresultSplit[3] -replace '%', '')}
                    Power_Draw         = if ($SMIresultSplit[4] -like "*Supported*") {$null} else {[int]($SMIresultSplit[4] -replace 'W', '')}
                    Power_Limit        = if ($SMIresultSplit[5] -like "*Supported*" -or $SMIresultSplit[5] -like "*error*") {$null} else {[int]($SMIresultSplit[5] -replace 'W', '')}
                    Pstate             = $SMIresultSplit[7]
                    FanSpeed           = if ($SMIresultSplit[6] -like "*Supported*" -or $SMIresultSplit[6] -like "*error*") {$null} else {[int]($SMIresultSplit[6] -replace '%', '')}
                    Clock              = if ($SMIresultSplit[8] -like "*Supported*") {$null} else {[int]($SMIresultSplit[8] -replace 'Mhz', '')}
                    ClockMem           = if ($SMIresultSplit[9] -like "*Supported*") {$null} else {[int]($SMIresultSplit[9] -replace 'Mhz', '')}
                    Power_MaxLimit     = if ($SMIresultSplit[10] -like "*Supported*") {$null} else { [int]($SMIresultSplit[10] -replace 'W', '')}
                    Power_DefaultLimit = if ($SMIresultSplit[11] -like "*Supported*") {$null} else {[int]($SMIresultSplit[11] -replace 'W', '')}
                }
                if ($Card.Power_DefaultLimit -gt 0) { $Card | Add-Member Power_limit_percent ([math]::Floor(($Card.power_limit * 100) / $Card.Power_DefaultLimit))}
                $Devices += $Card
                $DeviceId++
            }
        }
    }


    #AMD
    if ($Types | Where-Object Type -eq 'AMD') {
        #ADL
        $DeviceId = 0

        if ((get_config_variable "Afterburner") -eq "Enabled") {

            $abMonitor.ReloadAll()
            $abControl.ReloadAll()

            $Cards = @($abMonitor.GpuEntries | Where-Object Device -like "*Radeon*")

            $Cards | ForEach-Object {
                $CardData = $abMonitor.Entries | Where-Object GPU -eq $_.Index
                $Group = ($Types | Where-Object type -eq 'AMD' | Where-Object DeviceArray -contains $DeviceId).groupname
                $Card = [pscustomObject]@{
                    Type                = 'AMD'
                    Id                  = $DeviceId
                    Group               = $Group
                    AdapterId           = [int]$_.Index
                    Utilization_Memory  = [int]($($CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage").Data / $($CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage").MaxLimit * 100)
                    FanSpeed            = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed").Data
                    Clock               = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock").Data
                    ClockMem            = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock").Data
                    Utilization         = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage").Data
                    Temperature         = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature").Data
                    Power_Limit_Percent = [int]$abControl.GpuEntries[$_.Index].PowerLimitCur + 100
                    Power_Draw          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?power").Data
                    Name                = $_.Device
                }
                $Devices += $Card
                $DeviceId++
            }
        } else {
            $AdlResult = invoke-expression ".\includes\OverdriveN.exe" | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed"}
        $AmdCardsTDP = Get-Content .\Includes\amd-cards-tdp.json | ConvertFrom-Json

        if ($AdlResult -ne $null) {
            $AdlResult | ForEach-Object {

                $AdlResultSplit = $_ -split (",")
                $Group = ($Types | Where-Object type -eq 'AMD' | Where-Object DeviceArray -contains $DeviceId).groupname

                    $Card = [pscustomObject]@{
                    Type                = 'AMD'
                    Id                  = $DeviceId
                    Group               = $Group
                    AdapterId           = [int]$AdlResultSplit[0]
                    FanSpeed            = [int][int]([int]$AdlResultSplit[1] / [int]$AdlResultSplit[2] * 100)
                    Clock               = [int]([int]($AdlResultSplit[3] / 100))
                    ClockMem            = [int]([int]($AdlResultSplit[4] / 100))
                    Utilization         = [int]$AdlResultSplit[5]
                    Temperature         = [int]$AdlResultSplit[6] / 1000
                    Power_Limit_Percent = 100 + [int]$AdlResultSplit[7]
                    Power_Draw          = $AmdCardsTDP.$($AdlResultSplit[8].Trim()) * ((100 + [double]$AdlResultSplit[7]) / 100) * ([double]$AdlResultSplit[5] / 100)
                    Name                = $AdlResultSplit[8].Trim()
                    UDID                = $AdlResultSplit[9].Trim()
                }
                    $Devices += $Card
                $DeviceId++
            }
                }
        Clear-Variable AmdCardsTDP
    }
    }

    # CPU
    if ($Types | Where-Object Type -eq 'CPU') {

        $CpuResult = @(Get-CimInstance Win32_Processor)

        ### Not sure how Afterburner results look with more than 1 CPU
        if ((get_config_variable "Afterburner") -eq "Enabled" -and $CpuResult.count -eq 1) {
            $abMonitor.ReloadAll()
            $CPUData = $abMonitor.Entries | Where-Object SrcName -like "CPU*"

            $CpuResult | ForEach-Object {
                $Devices += [PSCustomObject]@{
                    Type        = 'CPU'
                    Id          = $_.DeviceID
                    Group       = 'CPU'
                    Clock       = [int]$($CPUData | Where-Object SrcName -eq 'CPU clock').Data
                    Utilization = [int]$($CPUData | Where-Object SrcName -eq 'CPU usage').Data
                    CacheL3     = $_.L3CacheSize
                    Cores       = $_.NumberOfCores
                    Threads     = $_.NumberOfLogicalProcessors
                    Power_Draw  = [int]$($CPUData | Where-Object SrcName -eq 'CPU power').Data
                    Temperature = [int]$($CPUData | Where-Object SrcName -eq 'CPU temperature').Data
                    Name        = $_.Name
                }
            }

        } else {
        $CpuTDP = Get-Content ".\Includes\cpu-tdp.json" | ConvertFrom-Json
        # Get-Counter is more accurate and is preferable, but currently not available in Poweshell 6
        if (Get-Command "Get-Counter" -Type Cmdlet -errorAction SilentlyContinue) {
            # Language independent version of Get-Counter '\Processor(_Total)\% Processor Time'
            $CpuLoad = (Get-Counter -Counter '\238(_Total)\6').CounterSamples.CookedValue / 100
        } else {
            $Error.Remove($Error[$Error.Count - 1])
            $CpuLoad = (Get-CimInstance -ClassName win32_processor | Measure-Object -Property LoadPercentage -Average | Select-Object -ExpandProperty Average) / 100
        }

        $CpuResult | ForEach-Object {
                $Devices += [PSCustomObject]@{
                Type        = 'CPU'
                Id          = $_.DeviceID
                    Group       = 'CPU'
                Clock       = $_.MaxClockSpeed
                Utilization = $_.LoadPercentage
                CacheL3     = $_.L3CacheSize
                Cores       = $_.NumberOfCores
                Threads     = $_.NumberOfLogicalProcessors
                Power_Draw  = [int]($CpuTDP.($_.Name) * $CpuLoad)
                Name        = $_.Name
            }
        }
        Clear-Variable CpuTDP
    }
    }
    $Devices
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function print_devices_information ($Devices) {

    foreach ($T in @('NVIDIA', 'AMD', 'Intel')) {
        $Devices | Where-Object Type -eq $T | Format-Table -Wrap  (
            @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
            @{Label = "Group"; Expression = {$_.Group}; Align = 'right'},
            @{Label = "Name"; Expression = {$_.Name}},
            @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
            @{Label = "Mem"; Expression = {[string]$_.Utilization_Memory + "%"}; Align = 'right'},
            @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
            @{Label = "Fan"; Expression = {[string]$_.FanSpeed + "%"}; Align = 'right'},
            @{Label = "Power"; Expression = {[string]$_.Power_Draw + "W"}; Align = 'right'},
            @{Label = "PowLmt"; Expression = {[string]$_.Power_Limit_Percent + '%'}; Align = 'right'},
            @{Label = "Pstate"; Expression = {$_.pstate}; Align = 'right'},
            @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
            @{Label = "ClkMem"; Expression = {[string]$_.ClockMem + "Mhz"}; Align = 'right'}
        ) -groupby Type | Out-Host
    }

    $Devices | Where-Object Type -eq 'CPU' | Format-Table -Wrap  (
        @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
        @{Label = "Group"; Expression = {$_.Group}; Align = 'right'},
        @{Label = "Name"; Expression = {$_.Name}},
        @{Label = "Cores"; Expression = {$_.Cores}},
        @{Label = "Threads"; Expression = {$_.Threads}},
        @{Label = "CacheL3"; Expression = {[string]$_.CacheL3 + "kb"}; Align = 'right'},
        @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
        @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
        @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
        @{Label = "Power*"; Expression = {[string]$_.Power_Draw + "W"}; Align = 'right'}
    )  -groupby Type | Out-Host
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_comma_separated_string {
    param(
        [Parameter(Mandatory = $true)]
        [int]$start,
        [Parameter(Mandatory = $true)]
        [int]$lenght
    )

    $result = $null


    for ($i = $start; $i - $start -lt $lenght; $i++) {
        if ($result -ne $null) {$result += ","}
        $result = $result + [string]$i
    }
    $result
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

Function Get_Mining_Types () {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Filter = $null
    )


    if ($Filter -eq $null) {$Filter = @()} # to allow comparation after

    $Types = @()
    $OCLDevices = @()

    $Types0 = get_config_variable "GpuGroups"
    if ($Types0) {$Types0 = $Types0 | ConvertFrom-Json}

    $OCLPlatforms = [OpenCl.Platform]::GetPlatformIDs()
    for ($i = 0; $i -lt $OCLPlatforms.length; $i++) {$OCLDevices += ([OpenCl.Device]::GetDeviceIDs($OCLPlatforms[$i], "ALL"))}

    if ($Types0 -eq $null) {
        #Autodetection on, must add types manually
        $Types0 = @()

        $NumberNvidiaDevices = ($OCLDevices | Where-Object Vendor -like '*NVIDIA*' | Measure-Object).count
        if ($NumberNvidiaDevices -gt 0) {
            $Types0 += [pscustomobject] @{
                GroupName   = "NVIDIA"
                Type        = "NVIDIA"
                Devices     = (get_comma_separated_string 0 $NumberNvidiaDevices)
                Powerlimits = "0"
                OCLDevices  = $OCLDevices | Where-Object Vendor -like '*NVIDIA*'
            }
        }

        $NumberAmdDevices = ($OCLDevices | Where-Object Vendor -like '*Advanced Micro Devices*' | Measure-Object).count
        if ($NumberAmdDevices -gt 0) {
            $Types0 += [pscustomobject] @{
                GroupName   = "AMD"
                Type        = "AMD"
                Devices     = (get_comma_separated_string 0 $NumberAmdDevices)
                Powerlimits = "0"
                OCLDevices  = $OCLDevices | Where-Object Vendor -like '*Advanced Micro Devices*'
            }
        }

        # $NumberIntelDevices = ($OCLDevices | Where-Object Vendor -like '*Intel*' | Measure-Object).count
        # if ($NumberIntelDevices -gt 0) {
        #     $Types0 += [pscustomobject] @{
        #         GroupName   = "Intel"
        #         Type        = "Intel"
        #         Devices        = (get_comma_separated_string 0 $NumberIntelDevices)
        #         Powerlimits = "0"
        #     }
        # }
    }

    #if cpu mining is enabled add a new group
    if (
        ((get_config_variable "CPUMINING") -eq 'ENABLED' -and !$Filter) -or
        "CPU" -in $Filter
    ) {
        $Types0 += [pscustomobject]@{
            GroupName   = "CPU"
            Type        = "CPU"
            Devices     = $null
            PowerLimits = "0"
        }
    }


    $c = 0
    $Types0 | ForEach-Object {
        if (
            ((compare-object $_.Groupname $Filter -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) -or
            (($Filter | Measure-Object).count -eq 0)
        ) {
            $_ | Add-Member Id $c
            $c = $c + 1

            $_ | Add-Member DevicesClayMode ($_.Devices -replace '10', 'A' -replace '11', 'B' -replace '12', 'C' -replace '13', 'D' -replace '14', 'E' -replace '15', 'F' -replace '16', 'G' -replace ',', '')
            $_ | Add-Member DevicesETHMode ($_.Devices -replace ',', ' ')
            $_ | Add-Member DevicesNsgMode ("-d " + $_.Devices -replace ',', ' -d ')
            $_ | Add-Member Platform (Get_Gpu_Platform $_.Type)
            $_ | Add-Member DeviceArray ($_.Devices -split ",")
            $_ | Add-Member DeviceCount ($_.Devices -split ",").count
            $Pl = @()
            ($_.PowerLimits -split ',') | ForEach-Object {$Pl += [int]$_}
            $_.PowerLimits = $Pl | Sort-Object -Descending

            if (
                $_.PowerLimits.Count -eq 0 -or
                $_.Type -in @('Intel') -or
                ($_.Type -in @('AMD') -and (get_config_variable "Afterburner") -ne 'Enabled')
            ) {$_.PowerLimits = [array](0) }

            $_ | Add-Member Algorithms ((get_config_variable ("Algorithms_" + $_.Type)) -split ',')
            $_ | Add-Member MinMemory (($_.OCLDevices | Measure-Object -Property GlobalMemSize -Minimum | Select-Object -ExpandProperty Minimum) / 1024 / 1024)
            $Types += $_
        }
    }
    $Types #return
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function WriteLog ($Message, $LogFile, $SendToScreen) {

    if (![string]::IsNullOrWhitespace($message)) {

        $M = [string](get-date) + "...... " + $Message
        $LogFile.WriteLine($M)

        if ($SendToScreen) { $Message | Write-Host -ForegroundColor Green }
    }
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function Timed_ReadKb {
    param(
        [Parameter(Mandatory = $true)]
        [int]$SecondsToWait,
        [Parameter(Mandatory = $true)]
        [array]$ValidKeys

    )

    $LoopStart = Get-Date
    $KeyPressed = $null

    while ((New-TimeSpan $LoopStart (Get-Date)).Seconds -le $SecondsToWait -and $ValidKeys -notcontains $KeyPressed) {
        if ($host.UI.RawUI.KeyAvailable) {
            $Key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
            $KeyPressed = $Key.character
            while ($Host.UI.RawUI.KeyAvailable) {$host.UI.RawUI.FlushInputBuffer()} #keyb buffer flush
        }
        Start-Sleep -Milliseconds 30
    }
    $KeyPressed
}





#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Gpu_Platform {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Type
    )
    switch ($Type) {
        "AMD" { $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.')) }
        "Intel" { $([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Intel')) }
        Default { 0 }
    }

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Clear_Screen_Zone {
    param(
        [Parameter(Mandatory = $true)]
        [int]$startY,
        [Parameter(Mandatory = $true)]
        [int]$endY
    )

    $BlankLine = " " * $Host.UI.RawUI.WindowSize.Width

    Set_ConsolePosition 0 $start

    for ($i = $startY; $i -le $endY; $i++) {
        $BlankLine | write-host
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Invoke_TcpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $true)]
        [String]$Request,
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        $Response = $Reader.ReadLine()
    } catch { $Error.Remove($error[$Error.Count - 1])}
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }
    $response
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Invoke_httpRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Request,
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $response = Invoke-WebRequest "http://$($Server):$Port$Request" -UseBasicParsing -TimeoutSec $timeout
    } catch {$Error.Remove($error[$Error.Count - 1])}

    $response
}

function Invoke_APIRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Url = "http://localhost/",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 5, #seconds
        [Parameter(Mandatory = $false)]
        [Int]$Retry = 3,
        [Parameter(Mandatory = $false)]
        [Int]$MaxAge = 10
    )
    $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
    $CachePath = '.\Cache\'
    $CacheFile = $CachePath + [System.Web.HttpUtility]::UrlEncode($Url) + '.json'

    if (Test-Path -LiteralPath $CacheFile -NewerThan (Get-Date).AddMinutes(-3)) {
        $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
    } else {
        if (!(Test-Path -Path $CachePath)) { New-Item -Path $CachePath -ItemType directory}

        while ($Retry -gt 0) {
            try {
                $Retry--
                $Response = Invoke-WebRequest $Url -UserAgent $UserAgent -UseBasicParsing -TimeoutSec $Timeout | ConvertFrom-Json
                if ($Response) {$Retry = 0}
            } catch {
                Start-Sleep -Seconds 2
                $Error.Remove($error[$Error.Count - 1])
            }
        }
        if ($Response) {
            if ($CacheFile.Length -lt 260) {$Response | ConvertTo-Json -Depth 100 | Set-Content -Path $CacheFile}
        } elseif (Test-Path -LiteralPath $CacheFile -NewerThan (Get-Date).AddMinutes( - $MaxAge)) {
            $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
        }
    }
    $Response
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Live_HashRate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$API,
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [Object]$Parameters = @{}

    )

    $Server = "localhost"

    try {
        switch ($API) {

            "Dtsm" {
                $Request = Invoke_TcpRequest $server $port "empty" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json | Select-Object  -ExpandProperty result
                    $HashRate = [double](($Data.sol_ps) | Measure-Object -Sum).Sum
                }
            }

            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
                $Request = Invoke_TcpRequest $server $port $Message 5

                if ($Request) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

                    $HashRate = if ($Data.SUMMARY.HS_5s) {[double]$Data.SUMMARY.HS_5s}
                    elseif ($Data.SUMMARY.KHS_5s) {[double]$Data.SUMMARY.KHS_5s * [math]::Pow(1000, 1)}
                    elseif ($Data.SUMMARY.MHS_5s) {[double]$Data.SUMMARY.MHS_5s * [math]::Pow(1000, 2)}
                    elseif ($Data.SUMMARY.GHS_5s) {[double]$Data.SUMMARY.GHS_5s * [math]::Pow(1000, 3)}
                    elseif ($Data.SUMMARY.THS_5s) {[double]$Data.SUMMARY.THS_5s * [math]::Pow(1000, 4)}
                    elseif ($Data.SUMMARY.PHS_5s) {[double]$Data.SUMMARY.PHS_5s * [math]::Pow(1000, 5)}

                    if ($HashRate -eq $null) {
                        $HashRate = if ($Data.SUMMARY.HS_av) {[double]$Data.SUMMARY.HS_av}
                        elseif ($Data.SUMMARY.KHS_av) {[double]$Data.SUMMARY.KHS_av * [math]::Pow(1000, 1)}
                        elseif ($Data.SUMMARY.MHS_av) {[double]$Data.SUMMARY.MHS_av * [math]::Pow(1000, 2)}
                        elseif ($Data.SUMMARY.GHS_av) {[double]$Data.SUMMARY.GHS_av * [math]::Pow(1000, 3)}
                        elseif ($Data.SUMMARY.THS_av) {[double]$Data.SUMMARY.THS_av * [math]::Pow(1000, 4)}
                        elseif ($Data.SUMMARY.PHS_av) {[double]$Data.SUMMARY.PHS_av * [math]::Pow(1000, 5)}
                    }
                }
            }

            "palgin" {
                $Request = Invoke_TcpRequest $server $port "summary" 5
                if ($Request) {
                    $Data = $Request -split ";"
                    $HashRate = [double]($Data[5] -split '=')[1] * 1000
                }
            }

            "ccminer" {
                $Request = Invoke_TcpRequest $server $port "summary" 5
                if ($Request) {
                    $Data = $Request -split ";" | ConvertFrom-StringData
                    $HashRate = if ($Data.HS) {[double]$Data.HS}
                    elseif ($Data.KHS) {[double]$Data.KHS * [math]::Pow(1000, 1)}
                    elseif ($Data.MHS) {[double]$Data.MHS * [math]::Pow(1000, 2)}
                    elseif ($Data.GHS) {[double]$Data.GHS * [math]::Pow(1000, 3)}
                    elseif ($Data.THS) {[double]$Data.THS * [math]::Pow(1000, 4)}
                    elseif ($Data.PHS) {[double]$Data.PHS * [math]::Pow(1000, 5)}
                }
            }

            "nicehashequihash" {
                $Request = Invoke_TcpRequest $server $port "status" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.result.speed_hps
                    if ($HashRate -eq $null) {$HashRate = $Data.result.speed_sps}
                }
            }

            "excavator" {
                $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
                $Request = Invoke_TcpRequest $server $port $message 5
                if ($Request) {
                    $Data = ($Request | ConvertFrom-Json).Algorithms
                    $HashRate = [double](($Data.workers.speed) | Measure-Object -Sum).Sum
                }
            }

            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
                $Request = Invoke_TcpRequest $server $port $message 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                }
            }

            "Claymore" {
                $Message = '{"id":0,"jsonrpc":"2.0","method":"miner_getstat1"}'
                $Request = Invoke_TcpRequest -Server $Server -Port $Port -Request $Message -Timeout 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $Miner = $Data.result[0]
                    switch -wildcard ($Miner) {
                        "* - ETH" {$Multiplier = 1000} #Ethash
                        "* - NS" {$Multiplier = 1000} #NeoScrypt
                        "PM*" {$Multiplier = 1000} #PhoenixMiner
                        "* - AEO" {$Multiplier = 1} #CryptoLight
                        "* - XMR" {$Multiplier = 1} #CryptoNight
                        "* - CN" {$Multiplier = 1} #CryptoNight
                        "* - ZEC" {$Multiplier = 1} #Equihash
                        Default {$Multiplier = 1000}
                    }
                    $HashRate = [double]$Data.result[2].Split(";")[0] * $Multiplier
                    $HashRate_Dual = [double]$Data.result[4].Split(";")[0] * $Multiplier
                }
            }

            "prospector" {
                $Request = Invoke_httpRequest $Server 42000 "/api/v0/hashrates" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.rate | Measure-Object -Sum).sum
                }
            }

            "wrapper" {
                $HashRate = ""
                $wrpath = ".\Wrapper_$Port.txt"
                $HashRate = if (test-path -path $wrpath ) {
                    Get-Content  $wrpath
                    $HashRate = ($HashRate -split ',')[0]
                    $HashRate = ($HashRate -split '.')[0]
                } else {$hashrate = 0}
            }

            "castXMR" {
                $Request = Invoke_httpRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000
                }
            }

            "XMrig" {
                $Request = Invoke_httpRequest $Server $Port "/api.json" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.hashrate.total[0]
                }
            }

            "Bminer" {
                $Request = Invoke_httpRequest $Server $Port "/api/status" 5
                if ($Request) {
                    $Data = $Request.content | ConvertFrom-Json
                    $HashRate = 0
                    $Data.miners | Get-Member -MemberType NoteProperty | ForEach-Object {
                        $HashRate += $Data.miners.($_.name).solver.solution_rate
                    }
                }
            }

            "optiminer" {
                $Request = Invoke_httpRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.solution_rate.Total."60s" | Measure-Object -Sum).sum
                    if ($HashRate -eq 0) { $HashRate = [double]($Data.solution_rate.Total."5s" | Measure-Object -Sum).sum }
                }
            }

            "Xrig" {
                $Request = Invoke_httpRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    if ([double]$Data.hashrate_15m -gt 0) {$HashRate = [double]$Data.hashrate_15m}
                    elseif ([double]$Data.hashrate_60s -gt 0) {$HashRate = [double]$Data.hashrate_60s}
                    elseif ([double]$Data.hashrate_10s -gt 0) {$HashRate = [double]$Data.hashrate_10s}
                }
            }
        } #end switch

        $HashRates = @()
        $HashRates += [double]$HashRate
        $HashRates += [double]$HashRate_Dual

        $HashRates
    } catch {}
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function ConvertTo_Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
    )


    $Return = switch ([math]::truncate([math]::log($Hash, [math]::Pow(1000, 1)))) {

        "-Infinity" {"0 h"}
        0 {"{0:g4}  h" -f ($Hash / [math]::Pow(1000, 0))}
        1 {"{0:g4} kh" -f ($Hash / [math]::Pow(1000, 1))}
        2 {"{0:g4} mh" -f ($Hash / [math]::Pow(1000, 2))}
        3 {"{0:g4} gh" -f ($Hash / [math]::Pow(1000, 3))}
        4 {"{0:g4} th" -f ($Hash / [math]::Pow(1000, 4))}
        Default {"{0:g4} ph" -f ($Hash / [math]::Pow(1000, 5))}
    }
    $Return
}




#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start_SubProcess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath,
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "",
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = "",
        [ValidateRange(-2, 3)]
        [Parameter(Mandatory = $false)]
        [Int]$Priority = 0,
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$MinerWindowStyle = "Minimized", <# UselessGuru #>
        [Parameter(Mandatory = $false)] <# UselessGuru #>
        [String]$UseAlternateMinerLauncher = $true <# UselessGuru #>
    )

    $PriorityNames = [PSCustomObject]@{-2 = "Idle"; -1 = "BelowNormal"; 0 = "Normal"; 1 = "AboveNormal"; 2 = "High"; 3 = "RealTime"}

    if ($UseAlternateMinerLauncher) {

        $ShowWindow = [PSCustomObject]@{"Normal" = "SW_SHOW"; "Maximized" = "SW_SHOWMAXIMIZE"; "Minimized" = "SW_SHOWMINNOACTIVE"}

        $Job = Start-Job `
            -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)');. .\Includes\CreateProcess.ps1")) `
            -ArgumentList $PID, $FilePath, $ArgumentList, $ShowWindow.$MinerWindowStyle, $PriorityNames.$Priority, $WorkingDirectory {
            param($ControllerProcessID, $FilePath, $ArgumentList, $ShowWindow, $Priority, $WorkingDirectory)

            . .\Includes\CreateProcess.ps1
            $ControllerProcess = Get-Process -Id $ControllerProcessID
            if ($ControllerProcess -eq $null) {return}

            $Process = Invoke-CreateProcess `
                -Binary $FilePath `
                -Arguments $ArgumentList `
                -CreationFlags CREATE_NEW_CONSOLE `
                -ShowWindow $ShowWindow `
                -StartF STARTF_USESHOWWINDOW `
                -Priority $Priority `
                -WorkingDirectory $WorkingDirectory
            if ($Process -eq $null) {
                [PSCustomObject]@{ProcessId = $null}
                return
            }

            [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

            $ControllerProcess.Handle | Out-Null
            $Process.Handle | Out-Null

            do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
            while ($Process.HasExited -eq $false)
        }
    } else {
        $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle {
            param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory, $MinerWindowStyle)

            $ControllerProcess = Get-Process -Id $ControllerProcessID
            if ($ControllerProcess -eq $null) {return}

            $ProcessParam = @{}
            $ProcessParam.Add("FilePath", $FilePath)
            $ProcessParam.Add("WindowStyle", $MinerWindowStyle)
            if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
            if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
            $Process = Start-Process @ProcessParam -PassThru
            if ($Process -eq $null) {
                [PSCustomObject]@{ProcessId = $null}
                return
            }

            [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}

            $ControllerProcess.Handle | Out-Null
            $Process.Handle | Out-Null

            do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
            while ($Process.HasExited -eq $false)

        }
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process

    if ($Process) {$Process.PriorityClass = $PriorityNames.$Priority}
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Expand_WebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )


    $DestinationFolder = $PSScriptRoot + $Path.Substring(1)
    $FileName = ([IO.FileInfo](Split-Path $Uri -Leaf)).name
    $FilePath = $PSScriptRoot + '\' + $Filename

    if (Test-Path $FileName) {Remove-Item $FileName}
    try {
        (New-Object System.Net.WebClient).DownloadFile($Uri, $FileName)
        if (Test-Path $FileName) {
            if ($SHA256 -and (Get-FileHash -Path $FileName -Algorithm SHA256).Hash -ne $SHA256) {
                "File hash doesn't match. Skipping miner." | Write-Host -ForegroundColor Red
            } else {
                $Command = 'x "' + $FilePath + '" -o"' + $DestinationFolder + '" -y -spe'
                Start-Process ".\includes\7z.exe" $Command -Wait
            }
        }
    } finally {
        if (Test-Path $FileName) {Remove-Item $FileName}
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get_Pools {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Querymode = 'core',
        [Parameter(Mandatory = $false)]
        [array]$PoolsFilterList = $null,
        #[array]$PoolsFilterList='Mining_pool_hub',
        [Parameter(Mandatory = $false)]
        [array]$CoinFilterList,
        #[array]$CoinFilterList = ('GroestlCoin','Feathercoin','zclassic'),
        [Parameter(Mandatory = $false)]
        [string]$Location = $null,
        #[string]$Location='EU'
        [Parameter(Mandatory = $false)]
        [array]$AlgoFilterList,
        [Parameter(Mandatory = $false)]
        [pscustomobject]$Info
    )
    #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool

    if ($location -eq 'GB') {$location = 'EU'}

    $PoolsFolderContent = Get-ChildItem ($PSScriptRoot + '\pools') -File | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare-Object $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}

    $ChildItems = @()

    if ($info -eq $null) { $Info = [pscustomobject]@{}
    }

    if (($info | Get-Member -MemberType NoteProperty | Where-Object name -eq location) -eq $null) {$info | Add-Member Location $Location}

    $info | Add-Member SharedFile [string]$null

    $PoolsFolderContent | ForEach-Object {

        $Basename = $_.BaseName
        $SharedFile = $PSScriptRoot + "\" + $Basename + [string](Get-Random -minimum 0 -maximum 9999999) + ".tmp"
        $info.SharedFile = $SharedFile

        if (Test-Path $SharedFile) {Remove-Item $SharedFile}
        &$_.FullName -Querymode $Querymode -Info $Info
        if (Test-Path $SharedFile) {
            $Content = Get-Content $SharedFile | ConvertFrom-Json
            Remove-Item $SharedFile
        } else { $Content = $null }
        $Content | ForEach-Object {$ChildItems += [PSCustomObject]@{Name = $Basename; Content = $_}}
    }

    $AllPools = $ChildItems | ForEach-Object {if ($_.Content) {$_.Content | Add-Member @{Name = $_.Name} -PassThru}}


    $AllPools | Add-Member LocationPriority 9999

    #Apply filters
    $AllPools2 = @()
    if ($Querymode -eq "core" -or $Querymode -eq "menu" ) {
        foreach ($Pool in $AllPools) {
            #must have wallet
            if (!$Pool.User) {continue}

            #must be in algo filter list or no list
            if ($AlgoFilterList) {$Algofilter = Compare-Object $AlgoFilterList $Pool.Algorithm -IncludeEqual -ExcludeDifferent}
            if ($AlgoFilterList.count -eq 0 -or $Algofilter) {

                #must be in coin filter list or no list
                if ($CoinFilterList) {$CoinFilter = Compare-Object $CoinFilterList $Pool.info -IncludeEqual -ExcludeDifferent}
                if ($CoinFilterList.count -eq 0 -or $CoinFilter) {
                    if ($Pool.Location -eq $Location) {$Pool.LocationPriority = 1}
                    elseif ($Pool.Location -eq 'EU' -and $Location -eq 'US') {$Pool.LocationPriority = 2}
                    elseif ($Pool.Location -eq 'US' -and $Location -eq 'EU') {$Pool.LocationPriority = 2}

                    ## Apply pool fees and pool factors
                    if ($Pool.Price) {
                        $Pool.Price *= 1 - [double]$Pool.Fee
                        $Pool.Price *= $(if ($Config."PoolProfitFactor_$($Pool.Name)") {[double]$Config."PoolProfitFactor_$($Pool.Name)"} else {1})
                    }
                    if ($Pool.Price24h) {
                        $Pool.Price24h *= 1 - [double]$Pool.Fee
                        $Pool.Price24h *= $(if ($Config."PoolProfitFactor_$($Pool.Name)") {[double]$Config."PoolProfitFactor_$($Pool.Name)"} else {1})
                    }
                    $AllPools2 += $Pool
                }
            }
        }
        $Return = $AllPools2
    } else { $Return = $AllPools }


    Remove-variable AllPools
    Remove-variable AllPools2

    $Return
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_config {

    $Result = @{}
    switch -regex -file config.ini {
        "^\s*(\w+)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            $Result[$name] = $value.Trim()
        }
    }
    $Result  # Return Value
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function get_config_variable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VarName
    )

    $Result = (get_config).$VarName
    $Result  # Return Value
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Best_Hashrate_Algo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )


    $Pattern = "*_" + $Algorithm + "_*_HashRate.csv"

    $Besthashrate = 0

    Get-ChildItem ($PSScriptRoot + "\Stats") -Filter $Pattern -File | ForEach-Object {
        $Content = ($_ | Get-Content | ConvertFrom-Csv )
        $Hrs = 0
        if ($Content -ne $null) {$Hrs = $($Content | Where-Object TimeSinceStartInterval -gt 60 | Measure-Object -property Speed -average).Average}

        if ($Hrs -gt $Besthashrate) {
            $Besthashrate = $Hrs
            $Miner = ($_.pschildname -split '_')[0]
        }
        $Return = [pscustomobject]@{
            Hashrate = $Besthashrate
            Miner    = $Miner
        }
    }
    $Return
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Algo_Divisor {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algo
    )

    $Divisor = 1000000000

    switch (get_algo_unified_name $Algo) {
        "blake2s" {$Divisor *= 1000}
        "blakecoin" {$Divisor *= 1000}
        "decred" {$Divisor *= 1000}
        "equihash" {$Divisor /= 1000}
        "keccakc" {$Divisor *= 1000}
        "skein" {$Divisor *= 1000}
        "yescrypt" {$Divisor /= 1000}
    }
    $Divisor
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set_ConsolePosition ([int]$x, [int]$y) {
    # Get current cursor position and store away
    $position = $host.ui.rawui.cursorposition
    # Store new X Co-ordinate away
    $position.x = $x
    $position.y = $y
    # Place modified location back to $HOST
    $host.ui.rawui.cursorposition = $position
    remove-variable position
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_ConsolePosition ([ref]$x, [ref]$y) {

    $position = $host.UI.RawUI.CursorPosition
    $x.value = $position.x
    $y.value = $position.y
    remove-variable position
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
function Print_Horizontal_line ([string]$Title) {

    $Width = $Host.UI.RawUI.WindowSize.Width
    if ([string]::IsNullOrEmpty($Title)) {$str = "-" * $Width}
    else {
        $str = ("-" * ($Width / 2 - ($Title.Length / 2) - 4)) + "  " + $Title + "  "
        $str += "-" * ($Width - $str.Length)
    }
    $str | Out-Host
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set_WindowSize ([int]$Width, [int]$Height) {
    #zero not change this axis


    $pshost = Get-Host
    $RawUI = $pshost.UI.RawUI

    #Buffer must be always greater than windows size

    $BSize = $Host.UI.RawUI.BufferSize
    if ($Width -ne 0 -and $Width -gt $BSize.Width) {$BSize.Width = $Width}
    if ($Height -ne 0 -and $Height -gt $BSize.Height) {$BSize.Width = $Height}

    $Host.UI.RawUI.BufferSize = $BSize


    $WSize = $Host.UI.RawUI.WindowSize
    if ($Width -ne 0) {$WSize.Width = $Width}
    if ($Height -ne 0) {$WSize.Height = $Height}

    $Host.UI.RawUI.WindowSize = $WSize
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_algo_unified_name ([string]$Algo) {

    if (![string]::IsNullOrEmpty($Algo)) {
        $Algos = Get-Content -Path ".\Includes\algorithms.json" | ConvertFrom-Json
        if ($Algos.($Algo.Trim()) -ne $null) { $Algos.($Algo.Trim()) }
        else { $Algo.Trim() }
    }
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function  get_coin_unified_name ([string]$Coin) {

    if ($Coin) {
        switch -wildcard ($Coin.Trim()) {
            "Auroracoin-*" { "Aurora" }
            "Dgb-*" { "Digibyte" }
            "Digibyte-*" { "Digibyte" }
            "Ethereum-Classic" { "EthereumClassic" }
            "Myriad-*" { "Myriad" }
            "Myriadcoin-*" { "Myriad" }
            "Verge-*" { "Verge" }
            "Bitcoin-Gold" { "BitcoinGold" }
            "Bitcoin-Cash" { "BitcoinCash" }
            "Bitcoin-Private" { "BitcoinPrivate" }
            Default { $Coin.Trim() }
        }
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Get_Hashrates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel
    )


    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}
    $Pattern = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate"

    if (!(Test-Path -path "$Pattern.csv")) {
        if (Test-Path -path "$Pattern.txt") {
            $Content = (Get-Content -path "$Pattern.txt")
            try {$Content = $Content | ConvertFrom-Json} catch {
            } finally {
                if ($Content) {$Content | ConvertTo-Csv | Set-Content -Path "$Pattern.csv"}
                Remove-Item -path "$Pattern.txt"
            }
        }
    } else {
        $Content = (Get-Content -path "$Pattern.csv")
        try {$Content = $Content | ConvertFrom-Csv} catch {
            #if error from convert from json delete file
            WriteLog ("Corrupted file $Pattern.csv, deleting") $LogFile $true
            Remove-Item -path "$Pattern.csv"
        }
    }

    if ($Content -eq $null) {$Content = @()}
    $Content
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set_Hashrates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )


    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate.csv"

    $Value | ConvertTo-Csv | Set-Content  -Path $Path
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Stats {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}
    $Pattern = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats"

    if (!(Test-Path -path "$Pattern.json")) {
        if (Test-Path -path "$Pattern.txt") {Rename-Item -Path "$Pattern.txt" -NewName "$Pattern.json"}
    } else {
        $Content = (Get-Content -path "$Pattern.json")
        try {$Content = $Content | ConvertFrom-Json} catch {
            #if error from convert from json delete file
            writelog ("Corrupted file $Pattern.json, deleting") $LogFile $true
            Remove-Item -path "$Pattern.json"
        }
    }
    $Content
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set_Stats {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )


    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats.json"

    $Value | ConvertTo-Json | Set-Content -Path $Path
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start_Downloader {
    param(
        [Parameter(Mandatory = $true)]
        [String]$URI,
        [Parameter(Mandatory = $true)]
        [String]$ExtractionPath,
        [Parameter(Mandatory = $true)]
        [String]$Path,
        [Parameter(Mandatory = $false)]
        [String]$SHA256
    )

    if (-not (Test-Path $Path)) {
        try {
            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                New-Item (Split-Path $Path) -ItemType "Directory" | Out-Null
                (New-Object System.Net.WebClient).DownloadFile($URI, $Path)
                if ($SHA256 -and (Get-FileHash -Path $Path -Algorithm SHA256).Hash -ne $SHA256) {
                    Remove-Item $Path
                    "File hash doesn't match. Skipping miner." | write-host -ForegroundColor Red
                }
            } else {
                $Message = "Downloading....$($URI)"
                Write-Host -BackgroundColor green -ForegroundColor Black  $Message
                WriteLog $Message $LogFile
                Expand_WebRequest $URI $ExtractionPath -ErrorAction Stop -SHA256 $SHA256
            }
        } catch {
            $Message = "Cannot download $URI"
            Write-Host -BackgroundColor Yellow -ForegroundColor Black $Message
            WriteLog $Message $LogFile

            if ($Path_Old) {
                if (Test-Path (Split-Path $Path_New)) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
            } else {
                $Message = "Cannot find $($Path) distributed at $($URI). "
                Write-Host -BackgroundColor Yellow -ForegroundColor Black $Message
                WriteLog $Message $LogFile
            }
        }
    }
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Clear_Files {

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.txt"
    $LastWrite = $Now.AddDays( - $Days)
    $Files = Get-Childitem $TargetFolder -Include $Extension -Exclude "empty.txt" -File -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}
    $Files | ForEach-Object {Remove-Item $_.fullname}

    $TargetFolder = "."
    $Extension = "wrapper_*.txt"
    $Files = Get-Childitem $TargetFolder -Include $Extension -File -Recurse
    $Files | ForEach-Object {Remove-Item $_.fullname}

    $TargetFolder = "."
    $Extension = "*.tmp"
    $Files = Get-Childitem $TargetFolder -Include $Extension -File -Recurse
    $Files | ForEach-Object {Remove-Item $_.fullname}

    $TargetFolder = ".\Cache"
    $Extension = "*.json"
    $LastWrite = $Now.AddDays( - $Days)
    $Files = Get-Childitem $TargetFolder -Include $Extension -Exclude "empty.txt" -File -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}
    $Files | ForEach-Object {Remove-Item $_.fullname}
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_coin_symbol ([string]$Coin) {

    switch -wildcard  ($Coin) {
        "adzcoin" { "ADZ" }
        "auroracoin" { "AUR" }
        "bitcoincash" { "BCH" }
        "bitcoingold" { "BTG" }
        "bitcoin" { "BTC" }
        "dash" { "DASH" }
        "decred" { "DCR" }
        "digibyte" { "DGB" }
        "electroneum" { "ETN" }
        "ethereumclassic" { "ETC" }
        "ethereum" { "ETH" }
        "expanse" { "EXP" }
        "feathercoin" { "FTC" }
        "gamecredits" { "GAME" }
        "geocoin" { "GEO" }
        "globalboosty" { "BSTY" }
        "groestlcoin" { "GRS" }
        "litecoin" { "LTC" }
        "maxcoin" { "MAX" }
        "monacoin" { "MONA" }
        "monero" { "XMR" }
        "musicoin" { "MUSIC" }
        "myriad" { "XMY" }
        "pascal" { "PASC" }
        "polytimos" { "POLY" }
        "sexcoin" { "SXC" }
        "siacoin" { "SC" }
        "startcoin" { "START" }
        "verge" { "XVG" }
        "vertcoin" { "VTC" }
        "zcash" { "ZEC" }
        "zclassic" { "ZCL" }
        "zcoin" { "XZC" }
        "zencash" { "ZEN" }
        Default { $Coin }
    }
}

function Check_DeviceGroups_Config ($types) {
    $Devices = get_devices_information $types
    $types | ForEach-Object {
        $DetectedDevices = @()
        $DetectedDevices += $Devices | Where-Object group -eq $_.GroupName
        if ($DetectedDevices.count -eq 0) {
            WriteLog ("No Devices for group " + $_.GroupName + " was detected, activity based watchdog will be disabled for that group, this can happens if AMD beta blockchain drivers are installed or incorrect gpugroups config") $LogFile $false
            write-warning ("No Devices for group " + $_.GroupName + " was detected, activity based watchdog will be disabled for that group, this can happens if AMD beta blockchain drivers are installed or incorrect gpugroups config")
            start-sleep 5
        } elseif ($DetectedDevices.count -ne $_.DeviceCount) {
            WriteLog ("Mismatching Devices for group " + $_.GroupName + " was detected, check gpugroups config and gpulist.bat") $LogFile $false
            write-warning ("Mismatching Devices for group " + $_.GroupName + " was detected, check gpugroups config and gpulist.bat")
            start-sleep 5
        }
    }
}
