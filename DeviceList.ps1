. .\Include.ps1
if ((Get-ConfigVariable "Afterburner") -eq "Enabled") {
    . .\Includes\Afterburner.ps1
}
Print-DevicesInformation (Get-DevicesInformation (Get-MiningTypes -All))

$Groups = Get-MiningTypes -All | Where-Object Type -ne 'CPU' | Select-Object GroupName,Type,Devices,@{Name = 'PowerLimits'; Expression = {$_.PowerLimits -join ','}} | ConvertTo-Json -Compress

Write-Host "Suggested GpuGroups string:"
Write-Host "GpuGroups = $Groups" -ForegroundColor Yellow
