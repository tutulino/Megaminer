Add-Type -Path .\Includes\OpenCL\*.cs

function Set-NvidiaPowerLimit ([int]$PowerLimitPercent, [string]$Devices) {

    foreach ($Device in @($Devices -split ',')) {

        $Command = '.\includes\nvidia-smi.exe'
        $Arguments = @(
            '-i ' + $Device
            '--query-gpu=power.default_limit'
            '--format=csv,noheader'
        )
        $PowerDefaultLimit = [int]((& $Command $Arguments) -replace 'W', '')

        #powerlimit change must run in admin mode
        $newProcess = New-Object System.Diagnostics.ProcessStartInfo ".\includes\nvidia-smi.exe"
        $newProcess.Verb = "runas"
        #$newProcess.UseShellExecute = $false
        $newProcess.Arguments = "-i " + $Device + " -pl " + [Math]::Floor([int]($PowerDefaultLimit -replace ' W', '') * ($PowerLimitPercent / 100))
        [System.Diagnostics.Process]::Start($newProcess) | Out-Null
    }
    Remove-Variable newprocess
}

function Get-ComputerStats {
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

function Send-ErrorsToLog ($LogFile) {

    for ($i = 0; $i -lt $error.count; $i++) {
        if ($error[$i].InnerException.Paramname -ne "scopeId") {
            # errors in debug
            $Msg = "###### ERROR ##### " + [string]($error[$i]) + ' ' + $error[$i].ScriptStackTrace
            Log-Message $msg -Severity Error -NoEcho
        }
    }
    $error.clear()
}

function Replace-ForEachDevice {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigFileArguments,
        [Parameter(Mandatory = $false)]
        [string]$Devices
    )

    #search string to replace
    $ConfigFileArguments = $ConfigFileArguments -replace [Environment]::NewLine, "#NL#" #replace carriage return for Select-string search (only search in each line)

    $Match = $ConfigFileArguments | Select-String -Pattern "#ForEachDevice#.*?#EndForEachDevice#"
    if ($null -ne $Match) {

        $Match.Matches | ForEach-Object {
            $Base = $_.value -replace "#ForEachDevice#" -replace "#EndForEachDevice#"
            $Final = ""
            $Devices -split ',' | ForEach-Object {$Final += ($base -replace "#DeviceID#", $_)}
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index) + $Final + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }

    $Match = $ConfigFileArguments | Select-String -Pattern "#RemoveLastCharacter#"
    if ($null -ne $Match) {
        $Match.Matches | ForEach-Object {
            $ConfigFileArguments = $ConfigFileArguments.Substring(0, $_.index - 1) + $ConfigFileArguments.Substring($_.index + $_.Length, $ConfigFileArguments.Length - ($_.index + $_.Length))
        }
    }

    $ConfigFileArguments = $ConfigFileArguments -replace "#NL#", [Environment]::NewLine #replace carriage return for Select-string search (only search in each line)
    $ConfigFileArguments
}

function Get-NextFreePort {
    param(
        [Parameter(Mandatory = $true)]
        [int]$LastUsedPort
    )

    if ($LastUsedPort -lt 2000) {$FreePort = 2001} else {$FreePort = $LastUsedPort + 1} #not allow use of <2000 ports
    while (Test-TCPPort -Server 127.0.0.1 -Port $FreePort -timeout 100) {$FreePort = $LastUsedPort + 1}
    $FreePort
}

function Test-TCPPort {
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
        return $false #port is free
    }
}

function Exit-Process {
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

function Get-DevicesInformation ($Types) {
    [cmdletbinding()]

    $Devices = @()
    if ($abMonitor) {$abMonitor.ReloadAll()}
    if ($abControl) {$abControl.ReloadAll()}

    if ($abMonitor) {
        foreach ($Type in @('AMD', 'NVIDIA')) {
            $DeviceId = 0
            $Pattern = @{
                AMD    = '*Radeon*'
                NVIDIA = '*GeForce*'
                Intel  = '*Intel*'
            }
            @($abMonitor.GpuEntries | Where-Object Device -like $Pattern.$Type) | ForEach-Object {
                $CardData = $abMonitor.Entries | Where-Object GPU -eq $_.Index
                $Group = $($Types | Where-Object Type -eq $Type | Where-Object DevicesArray -contains $DeviceId).GroupName
                $Card = @{
                    Type              = $Type
                    Id                = $DeviceId
                    Group             = $Group
                    AdapterId         = [int]$_.Index
                    Name              = $_.Device
                    Utilization       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?usage").Data
                    UtilizationMem    = [int]$($mem = $CardData | Where-Object SrcName -match "^(GPU\d* )?memory usage"; if ($mem.MaxLimit) {$mem.Data / $mem.MaxLimit * 100})
                    Clock             = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?core clock").Data
                    ClockMem          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?memory clock").Data
                    FanSpeed          = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?fan speed").Data
                    Temperature       = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?temperature").Data
                    PowerDraw         = [int]$($CardData | Where-Object SrcName -match "^(GPU\d* )?power").Data
                    PowerLimitPercent = [int]$($abControl.GpuEntries[$_.Index].PowerLimitCur + 100)
                }
                $Devices += [PSCustomObject]$Card
                $DeviceId++
            }
        }
    } else {
        #NVIDIA
        if ($Types | Where-Object Type -eq 'NVIDIA') {
            $DeviceId = 0
            $Command = '.\includes\nvidia-smi.exe'
            $Arguments = @(
                '--query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory,power.max_limit,power.default_limit'
                '--format=csv,noheader'
            )
            & $Command $Arguments  | ForEach-Object {
                $SMIresultSplit = $_ -split (",")
                if ($SMIresultSplit.count -gt 10) {
                    #less is error or no NVIDIA gpu present

                    $Group = ($Types | Where-Object type -eq 'NVIDIA' | Where-Object DevicesArray -contains $DeviceId).groupname

                    $Card = [PSCustomObject]@{
                        Type              = 'NVIDIA'
                        Id                = $DeviceId
                        Group             = $Group
                        Name              = $SMIresultSplit[0]
                        Utilization       = if ($SMIresultSplit[1] -like "*Supported*") {100} else {[int]($SMIresultSplit[1] -replace '%', '')} #If we dont have real Utilization, at least make the watchdog happy
                        UtilizationMem    = if ($SMIresultSplit[2] -like "*Supported*") {$null} else {[int]($SMIresultSplit[2] -replace '%', '')}
                        Temperature       = if ($SMIresultSplit[3] -like "*Supported*") {$null} else {[int]($SMIresultSplit[3] -replace '%', '')}
                        PowerDraw         = if ($SMIresultSplit[4] -like "*Supported*") {$null} else {[int]($SMIresultSplit[4] -replace 'W', '')}
                        PowerLimit        = if ($SMIresultSplit[5] -like "*Supported*" -or $SMIresultSplit[5] -like "*error*") {$null} else {[int]($SMIresultSplit[5] -replace 'W', '')}
                        Pstate            = $SMIresultSplit[7]
                        FanSpeed          = if ($SMIresultSplit[6] -like "*Supported*" -or $SMIresultSplit[6] -like "*error*") {$null} else {[int]($SMIresultSplit[6] -replace '%', '')}
                        Clock             = if ($SMIresultSplit[8] -like "*Supported*") {$null} else {[int]($SMIresultSplit[8] -replace 'Mhz', '')}
                        ClockMem          = if ($SMIresultSplit[9] -like "*Supported*") {$null} else {[int]($SMIresultSplit[9] -replace 'Mhz', '')}
                        PowerMaxLimit     = if ($SMIresultSplit[10] -like "*Supported*") {$null} else { [int]($SMIresultSplit[10] -replace 'W', '')}
                        PowerDefaultLimit = if ($SMIresultSplit[11] -like "*Supported*") {$null} else {[int]($SMIresultSplit[11] -replace 'W', '')}
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

            $Command = ".\Includes\OverdriveN.exe"
            $AdlResult = & $Command | Where-Object {$_ -notlike "*&???" -and $_ -ne "ADL2_OverdriveN_Capabilities_Get is failed"}
            $AmdCardsTDP = Get-Content .\Includes\amd-cards-tdp.json | ConvertFrom-Json

            if ($null -ne $AdlResult) {
                $AdlResult | ForEach-Object {

                    $AdlResultSplit = $_ -split (",")
                    $Group = ($Types | Where-Object type -eq 'AMD' | Where-Object DevicesArray -contains $DeviceId).groupname

                    $CardName = $($AdlResultSplit[8] `
                            -replace 'ASUS' `
                            -replace 'AMD' `
                            -replace '\(?TM\)?' `
                            -replace 'Series' `
                            -replace 'Graphics' `
                            -replace "\s+", ' '
                    ).Trim()

                    $CardName = $CardName -replace '.*Radeon.*([4-5]\d0).*', 'Radeon RX $1'     # RX 400/500 series
                    $CardName = $CardName -replace '.*\s(Vega).*(56|64).*', 'Radeon Vega $2'    # Vega series
                    $CardName = $CardName -replace '.*\s(R\d)\s(\w+).*', 'Radeon $1 $2'         # R3/R5/R7/R9 series
                    $CardName = $CardName -replace '.*\s(HD)\s?(\w+).*', 'Radeon HD $2'         # HD series

                    $Card = [PSCustomObject]@{
                        Type              = 'AMD'
                        Id                = $DeviceId
                        Group             = $Group
                        AdapterId         = [int]$AdlResultSplit[0]
                        FanSpeed          = [int]([int]$AdlResultSplit[1] / [int]$AdlResultSplit[2] * 100)
                        Clock             = [int]([int]($AdlResultSplit[3] / 100))
                        ClockMem          = [int]([int]($AdlResultSplit[4] / 100))
                        Utilization       = [int]$AdlResultSplit[5]
                        Temperature       = [int]$AdlResultSplit[6] / 1000
                        PowerLimitPercent = 100 + [int]$AdlResultSplit[7]
                        PowerDraw         = $AmdCardsTDP.$($AdlResultSplit[8].Trim()) * ((100 + [double]$AdlResultSplit[7]) / 100) * ([double]$AdlResultSplit[5] / 100)
                        Name              = $CardName
                        UDID              = $AdlResultSplit[9].Trim()
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
        if ($abMonitor) {
            $CpuData = @{
                Clock       = $($abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )clock' | Measure-Object -Property Data -Maximum).Maximum
                Utilization = $($abMonitor.Entries | Where-Object SrcName -match '^(CPU\d* )usage'| Measure-Object -Property Data -Average).Average
                PowerDraw   = $($abMonitor.Entries | Where-Object SrcName -eq 'CPU power').Data
                Temperature = $($abMonitor.Entries | Where-Object SrcName -match "^(CPU\d* )temperature" | Measure-Object -Property Data -Maximum).Maximum
            }
        } else {
            $CpuData = @{}
        }

        $CpuResult | ForEach-Object {
            if (-not $CpuData.Utilization) {
                # Get-Counter is more accurate and is preferable, but currently not available in Poweshell 6
                if (Get-Command "Get-Counter" -Type Cmdlet -errorAction SilentlyContinue) {
                    # Language independent version of Get-Counter '\Processor(_Total)\% Processor Time'
                    $CpuData.Utilization = (Get-Counter -Counter '\238(_Total)\6').CounterSamples.CookedValue
                } else {
                    $Error.Remove($Error[$Error.Count - 1])
                    $CpuData.Utilization = $_.LoadPercentage
                }
            }
            if (-not $CpuData.PowerDraw) {
                if (-not $CpuTDP) {$CpuTDP = Get-Content ".\Includes\cpu-tdp.json" | ConvertFrom-Json}
                $CpuData.PowerDraw = $CpuTDP.($_.Name.Trim()) * $CpuData.Utilization / 100
            }
            if (-not $CpuData.Clock) {$CpuData.Clock = $_.MaxClockSpeed}
            $Devices += [PSCustomObject]@{
                Type        = 'CPU'
                Group       = 'CPU'
                Id          = [int]($_.DeviceID -replace "[^0-9]")
                Name        = $_.Name.Trim()
                Cores       = [int]$_.NumberOfCores
                Threads     = [int]$_.NumberOfLogicalProcessors
                CacheL3     = [int]($_.L3CacheSize / 1024)
                Clock       = [int]$CpuData.Clock
                Utilization = [int]$CpuData.Utilization
                PowerDraw   = [int]$CpuData.PowerDraw
                Temperature = [int]$CpuData.Temperature
            }
        }
    }
    $Devices
}

function Print-DevicesInformation ($Devices) {

    $Devices | Where-Object Type -ne 'CPU' | Sort-Object Type | Format-Table -Wrap (
        @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
        @{Label = "Group"; Expression = {$_.Group}; Align = 'right'},
        @{Label = "Name"; Expression = {$_.Name}},
        @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
        @{Label = "Mem"; Expression = {[string]$_.UtilizationMem + "%"}; Align = 'right'},
        @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
        @{Label = "Fan"; Expression = {[string]$_.FanSpeed + "%"}; Align = 'right'},
        @{Label = "Power"; Expression = {[string]$_.PowerDraw + "W"}; Align = 'right'},
        @{Label = "PwLim"; Expression = {[string]$_.PowerLimitPercent + '%'}; Align = 'right'},
        @{Label = "Pstate"; Expression = {$_.pstate}; Align = 'right'},
        @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
        @{Label = "ClkMem"; Expression = {[string]$_.ClockMem + "Mhz"}; Align = 'right'}
    ) -groupby Type | Out-Host

    $Devices | Where-Object Type -eq 'CPU' | Format-Table -Wrap (
        @{Label = "Id"; Expression = {$_.Id}; Align = 'right'},
        @{Label = "Group"; Expression = {$_.Group}; Align = 'right'},
        @{Label = "Name"; Expression = {$_.Name}},
        @{Label = "Cores"; Expression = {$_.Cores}},
        @{Label = "Threads"; Expression = {$_.Threads}},
        @{Label = "CacheL3"; Expression = {[string]$_.CacheL3 + "MB"}; Align = 'right'},
        @{Label = "Clock"; Expression = {[string]$_.Clock + "Mhz"}; Align = 'right'},
        @{Label = "Load"; Expression = {[string]$_.Utilization + "%"}; Align = 'right'},
        @{Label = "Temp"; Expression = {$_.Temperature}; Align = 'right'},
        @{Label = "Power*"; Expression = {[string]$_.PowerDraw + "W"}; Align = 'right'}
    ) -groupby Type | Out-Host
}

Function Get-MiningTypes () {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Filter = $null,
        [Parameter(Mandatory = $false)]
        [switch]$All = $false
    )

    if ($null -eq $Filter) {$Filter = @()} # to allow comparation after

    $OCLPlatforms = [OpenCl.Platform]::GetPlatformIDs()
    $PlatformID = 0
    $OCLDevices = @($OCLPlatforms | ForEach-Object {
            $Devs = [OpenCl.Device]::GetDeviceIDs($_, [OpenCl.DeviceType]::All)
            $Devs | Add-Member PlatformID $PlatformID
            $PlatformID++
            $Devs
        })

    # # start fake
    # $OCLDevices = @()
    # $OCLDevices += [PSCustomObject]@{Name = 'Ellesmere'; Vendor = 'Advanced Micro Devices, Inc.'; GlobalMemSize = 8GB; PlatformID = 0; Type = 'Gpu'}
    # $OCLDevices += [PSCustomObject]@{Name = 'Ellesmere'; Vendor = 'Advanced Micro Devices, Inc.'; GlobalMemSize = 8GB; PlatformID = 0; Type = 'Gpu'}
    # $OCLDevices += [PSCustomObject]@{Name = 'Ellesmere'; Vendor = 'Advanced Micro Devices, Inc.'; GlobalMemSize = 4GB; PlatformID = 0; Type = 'Gpu'}
    # $OCLDevices += [PSCustomObject]@{Name = 'GeForce 1060'; Vendor = 'NVIDIA Corporation'; GlobalMemSize = 3GB; PlatformID = 1; Type = 'Gpu'}
    # $OCLDevices += [PSCustomObject]@{Name = 'GeForce 1060'; Vendor = 'NVIDIA Corporation'; GlobalMemSize = 3GB; PlatformID = 1; Type = 'Gpu'}
    # # end fake

    $Types0 = Get-ConfigVariable "GpuGroups"

    if ($null -eq $Types0 -or $All) {
        # Autodetection on, must add types manually
        $Types0 = @()

        $OCLDevices | Where-Object Type -eq 'Gpu' | Group-Object -Property PlatformID | ForEach-Object {
            $DeviceID = 0
            $_.Group | ForEach-Object {

                Switch ($_.Vendor) {
                    "Advanced Micro Devices, Inc." {$Type = "AMD"}
                    "NVIDIA Corporation" {$Type = "NVIDIA"}
                    # "Intel(R) Corporation" {$Type = "INTEL"} #Nothing to be mined on Intel iGPU
                    default {$Type = $false}
                }

                $MemoryGB = [int]($_.GlobalMemSize / 1GB)
                if ((Get-ConfigVariable "GpuGroupByType") -eq "Enabled") {
                    $Name_Norm = $Type
                } else {
                    $Name_Norm = (Get-Culture).TextInfo.ToTitleCase(($_.Name)) -replace "[^A-Z0-9]"
                    $Name_Norm += $MemoryGB
                }

                $PlatformID = $_.PlatformID

                if ($Type) {
                    if ($null -eq ($Types0 | Where-Object {$_.GroupName -eq $Name_Norm -and $_.Platform -eq $PlatformID})) {
                        $Types0 += [PSCustomObject] @{
                            GroupName   = $Name_Norm
                            Type        = $Type
                            Devices     = [string]$DeviceID
                            Platform    = $PlatformID
                            MemoryGB    = $MemoryGB
                            PowerLimits = "0"
                        }
                    } else {
                        $Types0 | Where-Object {$_.GroupName -eq $Name_Norm -and $_.Platform -eq $PlatformID} | ForEach-Object {
                            $_.Devices += "," + $DeviceID
                        }
                    }
                }
                $DeviceID++
            }
        }
    } elseif ("" -eq $Types0) {
        # Empty GpuGroups - don't autodetect, use cpu only
        [array]$Types0 = $null
    } else {
        # GpuGroups not empty - parse it
        [array]$Types0 = $Types0 | ConvertFrom-Json
    }

    #if cpu mining is enabled add a new group
    if (
        (!$Filter -and (Get-ConfigVariable "CPUMining") -eq 'ENABLED') -or
        $Filter -contains "CPU" -or
        $Types0.Length -eq 0
    ) {
        $SysResult = @(Get-CimInstance Win32_ComputerSystem)
        $Features = $($feat = @{}; switch -regex ((& .\Includes\CHKCPU32.exe /x) -split "</\w+>") {"^\s*<_?(\w+)>(\d+).*" {$feat.($matches[1]) = [int]$matches[2]}}; $feat)
        $RealCores = [int[]](0..($Features.Threads - 1))
        if ($Features.Threads -gt $Features.Cores) {
            $RealCores = $RealCores | Where-Object {-not ($_ % 2)}
        }
        $Types0 += [PSCustomObject]@{
            GroupName   = 'CPU'
            Type        = 'CPU'
            Devices     = $RealCores -join ','
            MemoryGB    = [int]($SysResult.TotalPhysicalMemory / 1GB)
            PowerLimits = "0"
            Features    = $Features
        }
    }

    $Types = @()
    $TypeID = 0
    $Types0 | ForEach-Object {
        if (!$Filter -or (Compare-Object $_.GroupName $Filter -IncludeEqual -ExcludeDifferent)) {

            $_ | Add-Member ID $TypeID
            $TypeID++

            $_ | Add-Member DevicesArray    @([int[]]($_.Devices -split ','))                               # @(0,1,2,10,11,12)
            $_ | Add-Member DevicesClayMode (($_.DevicesArray | ForEach-Object {'{0:X}' -f $_}) -join '')   # 012ABC
            $_ | Add-Member DevicesETHMode  ($_.DevicesArray -join ' ')                                     # 0 1 2 10 11 12
            $_ | Add-Member DevicesNsgMode  (($_.DevicesArray | ForEach-Object { "-d " + $_}) -join ' ')    # -d 0 -d 1 -d 2 -d 10 -d 11 -d 12
            $_ | Add-Member DevicesCount    ($_.DevicesArray.count)                                         # 6

            switch ($_.Type) {
                AMD { $Pattern = 'Advanced Micro Devices, Inc.' }
                NVIDIA { $Pattern = 'NVIDIA Corporation' }
                INTEL { $Pattern = 'Intel(R) Corporation' }
                CPU { $Pattern = '' }
            }
            $_ | Add-Member OCLDevices @($OCLDevices | Where-Object {$_.Vendor -eq $Pattern -and $_.Type -eq 'Gpu'})[$_.DevicesArray]
            if ($null -eq $_.Platform) {$_ | Add-Member Platform ($_.OCLDevices.PlatformID | Select-Object -First 1)}
            if ($null -eq $_.MemoryGB) {$_ | Add-Member MemoryGB ([int](($_.OCLDevices | Measure-Object -Property GlobalMemSize -Minimum | Select-Object -ExpandProperty Minimum) / 1GB ))}

            $_.PowerLimits = @([int[]]($_.PowerLimits -split ',') | Sort-Object -Descending -Unique)

            if (
                $_.PowerLimits.Count -eq 0 -or
                $_.Type -in @('Intel') -or
                ($_.Type -in @('AMD') -and !$abControl)
            ) {$_.PowerLimits = @(0)}

            $_ | Add-Member Algorithms ((Get-ConfigVariable ("Algorithms_" + $_.Type)) -split ',')
            $Types += $_
        }
    }
    $Types #return
}

Function Log-Message {
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$Message,

        [Parameter()]
        [ValidateSet('Info', 'Warn', 'Error', 'Debug')]
        [string]$Severity = 'Info',

        [Parameter()]
        [switch]$NoEcho = $false
    )
    if ($Message) {
        $LogFile.WriteLine("$(Get-Date -f "HH:mm:ss.ff")`t$Severity`t$Message")
        if ($NoEcho -eq $false) {
            switch ($Severity) {
                Info { Write-Host $Message -ForegroundColor Green }
                Warn { Write-Warning $Message }
                Error { Write-Error $Message }
            }
        }
    }
}
Set-Alias Log Log-Message


Function Read-KeyboardTimed {
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

function Clear-ScreenZone {
    param(
        [Parameter(Mandatory = $true)]
        [int]$startY,
        [Parameter(Mandatory = $true)]
        [int]$endY
    )

    $BlankLine = " " * $Host.UI.RawUI.WindowSize.Width

    Set-ConsolePosition 0 $start

    for ($i = $startY; $i -le $endY; $i++) {
        $BlankLine | Out-Host
    }
}

function Invoke-TCPRequest {
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

function Invoke-HTTPRequest {
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

function Invoke-APIRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Url = "http://localhost/",
        [Parameter(Mandatory = $false)]
        [Int]$Timeout = 5, # Request timeout in seconds
        [Parameter(Mandatory = $false)]
        [Int]$Retry = 3, # Amount of retries for request from origin
        [Parameter(Mandatory = $false)]
        [Int]$MaxAge = 10, # Max cache age if request failed, in minutes
        [Parameter(Mandatory = $false)]
        [Int]$Age = 3 # Cache age after which to request from origin, in minutes
    )
    $UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
    $CachePath = '.\Cache\'
    $CacheFile = $CachePath + [System.Web.HttpUtility]::UrlEncode($Url) + '.json'

    if (!(Test-Path -Path $CachePath)) { New-Item -Path $CachePath -ItemType directory -Force | Out-Null }
    if (Test-Path -LiteralPath $CacheFile -NewerThan (Get-Date).AddMinutes( - $Age)) {
        $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
    } else {
        while ($Retry -gt 0) {
            try {
                $Retry--
                $Response = Invoke-RestMethod -Uri $Url -UserAgent $UserAgent -UseBasicParsing -TimeoutSec $Timeout
                if ($Response) {$Retry = 0}
            } catch {
                Start-Sleep -Seconds 2
                $Error.Remove($error[$Error.Count - 1])
            }
        }
        if ($Response) {
            if ($CacheFile.Length -lt 250) {$Response | ConvertTo-Json -Depth 100 | Set-Content -Path $CacheFile}
        } elseif (Test-Path -LiteralPath $CacheFile -NewerThan (Get-Date).AddMinutes( - $MaxAge)) {
            $Response = Get-Content -Path $CacheFile | ConvertFrom-Json
        } else {
            $Response = $null
        }
    }
    $Response
}

function Get-LiveHashRate {
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
                $Request = Invoke-TCPRequest $Server $port "empty" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json | Select-Object -ExpandProperty result
                    $HashRate = [double](($Data.sol_ps) | Measure-Object -Sum).Sum
                }
            }

            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest $Server $port $Message 5

                if ($Request) {
                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

                    $HashRate = [double]$Data.SUMMARY.HS_5s
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.KHS_5s * [math]::Pow(1000, 1)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.MHS_5s * [math]::Pow(1000, 2)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.GHS_5s * [math]::Pow(1000, 3)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.THS_5s * [math]::Pow(1000, 4)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.PHS_5s * [math]::Pow(1000, 5)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.HS_av}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.KHS_av * [math]::Pow(1000, 1)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.MHS_av * [math]::Pow(1000, 2)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.GHS_av * [math]::Pow(1000, 3)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.THS_av * [math]::Pow(1000, 4)}
                    if (-not $HashRate) {$HashRate = [double]$Data.SUMMARY.PHS_av * [math]::Pow(1000, 5)}
                }
            }

            "palgin" {
                $Request = Invoke-TCPRequest $Server $port "summary" 5
                if ($Request) {
                    $Data = $Request -split ";"
                    $HashRate = [double]($Data[5] -split '=')[1] * 1000
                }
            }

            "ccminer" {
                $Request = Invoke-TCPRequest $Server $port "summary" 5
                if ($Request) {
                    $Data = $Request -split ";" | ConvertFrom-StringData
                    $HashRate = [double]$Data.HS
                    if (-not $HashRate) {$HashRate = [double]$Data.KHS * [math]::Pow(1000, 1)}
                    if (-not $HashRate) {$HashRate = [double]$Data.MHS * [math]::Pow(1000, 2)}
                    if (-not $HashRate) {$HashRate = [double]$Data.GHS * [math]::Pow(1000, 3)}
                    if (-not $HashRate) {$HashRate = [double]$Data.THS * [math]::Pow(1000, 4)}
                    if (-not $HashRate) {$HashRate = [double]$Data.PHS * [math]::Pow(1000, 5)}
                }
            }

            "nicehashequihash" {
                $Request = Invoke-TCPRequest $Server $port "status" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.result.speed_hps
                    if (-not $HashRate) {$HashRate = $Data.result.speed_sps}
                }
            }

            "excavator" {
                $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest $Server $port $message 5
                if ($Request) {
                    $Data = ($Request | ConvertFrom-Json).Algorithms
                    $HashRate = [double](($Data.workers.speed) | Measure-Object -Sum).Sum
                    if (-not $HashRate) {$HashRate = [double](($Data.speed) | Measure-Object -Sum).Sum}
                }
            }

            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest $Server $port $message 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                }
            }

            "Claymore" {
                $Message = @{id = 0; jsonrpc = "2.0"; method = "miner_getstat1"} | ConvertTo-Json -Compress
                $Request = Invoke-TCPRequest -Server $Server -Port $Port -Request $Message -Timeout 5
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
                    [double[]]$HashRate = [double]$Data.result[2].Split(";")[0] * $Multiplier
                    $HashRate += [double]$Data.result[4].Split(";")[0] * $Multiplier
                }
            }

            "prospector" {
                $Request = Invoke-HTTPRequest $Server $port "/api/v0/rates" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data | Group-Object device | ForEach-Object { $_.Group | Sort-Object time -Descending | Select-Object -First 1 } | Measure-Object -Sum -Property Rate).Sum
                }
            }

            "wrapper" {
                $HashRate = ""
                $wrpath = ".\Wrapper_$Port.txt"
                $HashRate = [double]$(if (Test-Path -path $wrpath) {Get-Content $wrpath}else {0})
            }

            "castXMR" {
                $Request = Invoke-HTTPRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000
                }
            }

            "XMrig" {
                $Request = Invoke-HTTPRequest $Server $Port "/api.json" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate.total[0]
                }
            }

            "BMiner" {
                $Request = Invoke-HTTPRequest $Server $Port "/api/status" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.miners |
                        Get-Member -MemberType NoteProperty |
                        ForEach-Object {$Data.miners.($_.name).solver.solution_rate} |
                        Measure-Object -Sum |
                        Select-Object -ExpandProperty Sum
                }
            }

            "BMiner8" {
                $Request = Invoke-HTTPRequest $Server $Port "/api/v1/status/solver" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.devices |
                        Get-Member -MemberType NoteProperty |
                        ForEach-Object {$Data.devices.($_.name).solvers} |
                        Group-Object algorithm |
                        ForEach-Object {
                        $_.group.speed_info.hash_rate |
                            Measure-Object -Sum |
                            Select-Object -ExpandProperty Sum
                    }
                }
            }

            "Optiminer" {
                $Request = Invoke-HTTPRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]($Data.solution_rate.Total."60s" | Measure-Object -Sum).sum
                    if (-not $HashRate) { $HashRate = [double]($Data.solution_rate.Total."5s" | Measure-Object -Sum).sum }
                }
            }

            "Xrig" {
                $Request = Invoke-HTTPRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate_15m
                    if (-not $HashRate) {$HashRate = [double]$Data.HashRate_60s}
                    if (-not $HashRate) {$HashRate = [double]$Data.HashRate_10s}
                }
            }

            "SRB" {
                $Request = Invoke-HTTPRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate_total_5min
                    if (-not $HashRate) {$HashRate = [double]$Data.HashRate_total_now}
                }
            }

            "JCE" {
                $Request = Invoke-HTTPRequest $Server $Port "" 5
                if ($Request) {
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [double]$Data.HashRate.total
                }
            }

        } #end switch

        $HashRate
    } catch {}
}

function ConvertTo-Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
    )

    $Return = switch ([math]::truncate([math]::log($Hash, 1e3))) {
        1 {"{0:g4} kh" -f ($Hash / 1e3)}
        2 {"{0:g4} mh" -f ($Hash / 1e6)}
        3 {"{0:g4} gh" -f ($Hash / 1e9)}
        4 {"{0:g4} th" -f ($Hash / 1e12)}
        5 {"{0:g4} ph" -f ($Hash / 1e15)}
        default {"{0:g4} h" -f ($Hash)}
    }
    $Return
}

function Start-SubProcess {
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
            if ($null -eq $ControllerProcess) {return}

            $ProcessParams = @{
                Binary           = $FilePath
                Arguments        = $ArgumentList
                CreationFlags    = [CreationFlags]::CREATE_NEW_CONSOLE
                ShowWindow       = $ShowWindow
                StartF           = [STARTF]::STARTF_USESHOWWINDOW
                Priority         = $Priority
                WorkingDirectory = $WorkingDirectory
            }
            $Process = Invoke-CreateProcess @ProcessParams
            if ($null -eq $Process) {
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
            if ($null -eq $ControllerProcess) {return}

            $ProcessParam = @{}
            $ProcessParam.Add("FilePath", $FilePath)
            $ProcessParam.Add("WindowStyle", $MinerWindowStyle)
            if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
            if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
            $Process = Start-Process @ProcessParam -PassThru
            if ($null -eq $Process) {
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
    while ($null -eq $JobOutput)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process

    if ($Process) {$Process.PriorityClass = $PriorityNames.$Priority}
}

function Expand-WebRequest {
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
    $CachePath = $PSScriptRoot + '\Downloads\'
    $FilePath = $CachePath + $Filename

    if (-not (Test-Path -LiteralPath $CachePath)) {$null = New-Item -Path $CachePath -ItemType directory}

    try {
        if (Test-Path -LiteralPath $FilePath) {
            if ($SHA256 -and (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash -ne $SHA256) {
                Log-Message "Existing file hash doesn't match. Will re-download." -Severity Warn
                Remove-Item $FilePath
            }
        }
        if (-not (Test-Path -LiteralPath $FilePath)) {
            (New-Object System.Net.WebClient).DownloadFile($Uri, $FilePath)
        }
        if (Test-Path -LiteralPath $FilePath) {
            if ($SHA256 -and (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash -ne $SHA256) {
                Log-Message "File hash doesn't match. Removing file." -Severity Warn
            } elseif ((Get-Item $FilePath).Extension -in @('.msi', '.exe')) {
                Start-Process $FilePath "-qb" -Wait
            } else {
                $Command = 'x "' + $FilePath + '" -o"' + $DestinationFolder + '" -y -spe'
                Start-Process ".\includes\7z.exe" $Command -Wait
            }
        }
    } finally {
        # if (Test-Path $FilePath) {Remove-Item $FilePath}
    }
}

function Get-Pools {
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
        [PSCustomObject]$Info
    )
    #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool

    if ($location -eq 'GB') {$location = 'EU'}

    $PoolsFolderContent = Get-ChildItem ($PSScriptRoot + '\pools') -File | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare-Object $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0}

    $ChildItems = @()

    if ($null -eq $Info) { $Info = [PSCustomObject]@{}
    }

    if ($null -eq ($Info | Get-Member -MemberType NoteProperty | Where-Object name -eq location)) {$Info | Add-Member Location $Location}

    $Info | Add-Member SharedFile [string]$null

    $PoolsFolderContent | ForEach-Object {

        $Basename = $_.BaseName
        $SharedFile = $PSScriptRoot + "\" + $Basename + [string](Get-Random -minimum 0 -maximum 9999999) + ".tmp"
        $Info.SharedFile = $SharedFile

        if (Test-Path $SharedFile) {Remove-Item $SharedFile}
        & $_.FullName -Querymode $Querymode -Info $Info
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

function Get-Config {

    $Result = @{}
    switch -regex -file config.ini {
        "^\s*(\w+)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            $Result[$name] = $value.Trim()
        }
    }
    $Result # Return Value
}

Function Get-ConfigVariable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VarName
    )

    $Result = (Get-Config).$VarName
    $Result # Return Value
}

function Get-BestHashRateAlgo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )

    $Pattern = "*_" + $Algorithm + "_*_HashRate.csv"

    $BestHashRate = 0

    Get-ChildItem ($PSScriptRoot + "\Stats") -Filter $Pattern -File | ForEach-Object {
        $Content = ($_ | Get-Content | ConvertFrom-Csv )
        $Hrs = 0
        if ($null -ne $Content) {$Hrs = $($Content | Where-Object TimeSinceStartInterval -gt 60 | Measure-Object -property Speed -average).Average}

        if ($Hrs -gt $BestHashRate) {
            $BestHashRate = $Hrs
            $Miner = ($_.pschildname -split '_')[0]
        }
        $Return = [PSCustomObject]@{
            HashRate = $BestHashRate
            Miner    = $Miner
        }
    }
    $Return
}

function Set-ConsolePosition ([int]$x, [int]$y) {
    # Get current cursor position and store away
    $position = $host.ui.rawui.cursorposition
    # Store new X Co-ordinate away
    $position.x = $x
    $position.y = $y
    # Place modified location back to $HOST
    $host.ui.rawui.cursorposition = $position
    remove-variable position
}

function Get-ConsolePosition ([ref]$x, [ref]$y) {

    $position = $host.UI.RawUI.CursorPosition
    $x.value = $position.x
    $y.value = $position.y
    remove-variable position
}

function Print-HorizontalLine ([string]$Title) {

    $Width = $Host.UI.RawUI.WindowSize.Width
    if ([string]::IsNullOrEmpty($Title)) {$str = "-" * $Width}
    else {
        $str = ("-" * ($Width / 2 - ($Title.Length / 2) - 4)) + "  " + $Title + "  "
        $str += "-" * ($Width - $str.Length)
    }
    $str | Out-Host
}

function Set-WindowSize ([int]$Width, [int]$Height) {
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

function Get-AlgoUnifiedName ([string]$Algo) {

    if (![string]::IsNullOrEmpty($Algo)) {
        $Algos = Get-Content -Path ".\Includes\algorithms.json" | ConvertFrom-Json
        if ($null -ne $Algos.($Algo.Trim())) { $Algos.($Algo.Trim()) }
        else { $Algo.Trim() }
    }
}

function Get-CoinUnifiedName ([string]$Coin) {

    if ($Coin) {
        $Coin = $Coin.Trim() -replace '[\s_]', '-'
        switch -wildcard ($Coin) {
            "Aur-*" { "Aurora" }
            "Auroracoin-*" { "Aurora" }
            "Bitcoin-*" { $_ -replace '-' }
            "Dgb-*" { "Digibyte" }
            "Digibyte-*" { "Digibyte" }
            "Ethereum-Classic" { "EthereumClassic" }
            "Haven-Protocol" { "Haven" }
            "Myriad-*" { "Myriad" }
            "Myriadcoin-*" { "Myriad" }
            "Shield-*" { "Verge" }
            "Verge-*" { "Verge" }
            Default { $Coin }
        }
    }
}

function Get-HashRates {
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
            Log-Message "Corrupted file $Pattern.csv, deleting" -Severity Warn
            Remove-Item -path "$Pattern.csv"
        }
    }

    if ($null -eq $Content) {$Content = @()}
    $Content
}

function Set-HashRates {
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
        [PSCustomObject]$Value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_HashRate.csv"

    $Value | ConvertTo-Csv | Set-Content -Path $Path
}

function Get-Stats {
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
            Log-Message "Corrupted file $Pattern.json, deleting" -Severity Warn
            Remove-Item -path "$Pattern.json"
        }
    }
    $Content
}
function Get-AllStats {
    $Stats = @()
    if (-not (Test-Path "Stats")) {New-Item "Stats" -ItemType "directory" | Out-Null}
    Get-ChildItem "Stats" -Filter "*_stats.json" | Foreach-Object {
        $Name = $_.BaseName
        $_ | Get-Content | ConvertFrom-Json | ForEach-Object {
            $Values = $Name -split '_'
            $Stats += @{
                MinerName  = $Values[0]
                Algorithm  = $Values[1]
                GroupName  = $Values[2]
                AlgoLabel  = $Values[3]
                PowerLimit = ($Values[4] -split 'PL')[-1]
                Stats      = $_
            }
        }
    }
    Return $Stats
}


function Set-Stats {
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
        [PSCustomObject]$value,
        [Parameter(Mandatory = $true)]
        [String]$Powerlimit
    )

    if ($AlgoLabel -eq "") {$AlgoLabel = 'X'}

    $Path = $PSScriptRoot + "\Stats\" + $MinerName + "_" + $Algorithm + "_" + $GroupName + "_" + $AlgoLabel + "_PL" + $PowerLimit + "_stats.json"

    $Value | ConvertTo-Json | Set-Content -Path $Path
}

function Start-Downloader {
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

    if (-not (Test-Path -LiteralPath $Path)) {
        try {
            if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                # downloading a single file
                $null = New-Item (Split-Path $Path) -ItemType "Directory"
                (New-Object System.Net.WebClient).DownloadFile($URI, $Path)
                if ($SHA256 -and (Get-FileHash -Path $Path -Algorithm SHA256).Hash -ne $SHA256) {
                    Log-Message "File hash doesn't match. Removing file." -Severity Warn
                    Remove-Item $Path
                }
            } else {
                # downloading an archive or installer
                Log-Message "Downloading $URI" -Severity Info
                Expand-WebRequest -URI $URI -Path $ExtractionPath -SHA256 $SHA256 -ErrorAction Stop
            }
        } catch {
            $Message = "Cannot download $URI"
            Log-Message $Message -Severity Warn
        }
    }
}

function Clear-Files {

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.log"
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

function Get-CoinSymbol ([string]$Coin) {

    switch -wildcard ($Coin) {
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

function Test-DeviceGroupsConfig ($Types) {
    $Devices = Get-DevicesInformation $Types
    $Types | Where-Object Type -ne 'CPU' | ForEach-Object {
        $DetectedDevices = @()
        $DetectedDevices += $Devices | Where-Object Group -eq $_.GroupName
        if ($DetectedDevices.count -eq 0) {
            Log-Message "No Devices for group " + $_.GroupName + " was detected, activity based watchdog will be disabled for that group, this can happens if AMD beta blockchain drivers are installed or incorrect gpugroups config" -Severity Warn
            Start-Sleep -Seconds 5
        } elseif ($DetectedDevices.count -ne $_.DevicesCount) {
            Log-Message "Mismatching Devices for group " + $_.GroupName + " was detected, check gpugroups config and gpulist.bat" -Severity Warn
            Start-Sleep -Seconds 5
        }
    }
    $TotalMem = (($Types | Where-Object Type -ne 'CPU').OCLDevices.GlobalMemSize | Measure-Object -Sum).Sum / 1GB
    $TotalSwap = (Get-WmiObject Win32_PageFile | Select-Object -ExpandProperty FileSize | Measure-Object -Sum).Sum / 1GB
    if ($TotalMem -gt $TotalSwap) {
        Log-Message "Make sure you have at least $TotalMem GB swap configured" -Severity Warn
        Start-Sleep -Seconds 5
    }
}
