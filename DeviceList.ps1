. .\Include.ps1
if ((get_config_variable "Afterburner") -eq "Enabled") {
    . .\Includes\Afterburner.ps1
}
print_devices_information (get_devices_information (Get_Mining_Types -All))

$Groups = Get_Mining_Types -All | Where-Object Type -ne 'CPU' | Select-Object GroupName,Type,Devices,@{Name = 'PowerLimits'; Expression = {$_.PowerLimits -join ','}} | ConvertTo-Json -Compress

Write-Host "Suggested GpuGroups string:"
Write-Host "GpuGroups = $Groups" -ForegroundColor Yellow
