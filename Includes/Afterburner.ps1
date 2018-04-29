
# Initialize MSI Afterburner interface
$baseFolder = Split-Path -parent $script:MyInvocation.MyCommand.Path

try {
    Add-Type -Path $baseFolder\MSIAfterburner.NET.dll
} catch {
    throw "Failed to load Afterburner interface library"
}

try {
    $abMonitor = New-Object MSI.Afterburner.HardwareMonitor
    $abControl = New-Object MSI.Afterburner.ControlMemory
} catch {
    throw "Failed to communicate with MSI Afterburner"
}


function set_ab_powerlimit ([int]$PowerLimitPercent, [string]$Devices) {

    try {
        $abControl = New-Object MSI.Afterburner.ControlMemory
    } catch {
        throw "Failed to communicate with MSI Afterburner"
    }

    foreach ($device in $Devices.Split(',')) {
        $abControl.GpuEntries[$device].PowerLimitCur = $PowerLimitPercent - 100
        $abControl.CommitChanges()
    }
}
