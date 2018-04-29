. .\Include.ps1
if ((get_config_variable "Afterburner") -eq "Enabled") {
    . .\Includes\Afterburner.ps1
}
print_devices_information (get_devices_information (Get_Mining_Types))
