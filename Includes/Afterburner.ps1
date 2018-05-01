
# Initialize MSI Afterburner interface
$baseFolder = Split-Path -parent $script:MyInvocation.MyCommand.Path

try {
    Add-Type -Path $baseFolder\MSIAfterburner.NET.dll
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    throw "Failed to load Afterburner interface library"
}

try {
    $abMonitor = New-Object MSI.Afterburner.HardwareMonitor
    $abControl = New-Object MSI.Afterburner.ControlMemory
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    throw "Failed to communicate with MSI Afterburner"
}


function set_ab_powerlimit ([int]$PowerLimitPercent, $DeviceGroup) {

    try {
        $abMonitor.ReloadAll()
        $abControl.ReloadAll()
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        throw "Failed to communicate with MSI Afterburner"
    }

    if ($DeviceGroup.DeviceArray) {

        $PowerLimit = $PowerLimitPercent - 100

        $Pattern = @{
            AMD    = '*Radeon*'
            NVIDIA = '*GeForce*'
            Intel  = '*Intel*'
        }

        $Devices = @($abMonitor.GpuEntries | Where-Object Device -like $Pattern | Select-Object -ExpandProperty Index)[$DeviceGroup.DeviceArray]

        foreach ($device in $Devices) {
            if ($abControl.GpuEntries[$device].PowerLimitCur -ne $PowerLimit) {

                # Stay within HW limitations
                if ($PowerLimit -gt $abControl.GpuEntries[$device].PowerLimitMax) {$PowerLimit = $abControl.GpuEntries[$device].PowerLimitMax}
                if ($PowerLimit -lt $abControl.GpuEntries[$device].PowerLimitMin) {$PowerLimit = $abControl.GpuEntries[$device].PowerLimitMin}

                $abControl.GpuEntries[$device].PowerLimitCur = $PowerLimit
            }
        }
        $abControl.CommitChanges()
    }
}

function get_ab_devices ($Type) {
    try {
        $abControl.ReloadAll()
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Yellow
        throw "Failed to communicate with MSI Afterburner"
    }

    if ($Type -in @('AMD', 'NVIDIA', 'Intel')) {
        $Pattern = @{
            AMD    = "*Radeon*"
            NVIDIA = "*GeForce*"
            Intel  = "*Intel*"
        }
        @($abMonitor.GpuEntries) | Where-Object Device -like $Pattern.$Type | ForEach-Object {
            $abIndex = $_.Index
            $abMonitor.Entries | Where-Object {
                $_.GPU -eq $abIndex -and
                $_.SrcName -match "(GPU\d+ )?" -and
                $_.SrcName -notmatch "CPU"
            } | Format-Table
            @($abControl.GpuEntries)[$abIndex]
        }
    } elseif ($Type -eq 'CPU') {
        $abMonitor.Entries | Where-Object {
            $_.GPU -eq [uint32]"0xffffffff" -and
            $_.SrcName -match "CPU"
        } | Format-Table
    }
}
