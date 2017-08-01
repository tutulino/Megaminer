. .\Include.ps1

$Path = ".\Bin\NVIDIA-TPruvot\ccminer-x64.exe"
$Uri = "https://github.com/tpruvot/ccminer/releases/download/v2.0-tpruvot/ccminer-2.0-release-x64-cuda-8.0.7z"

$Commands = [PSCustomObject]@{
    "jha" = "" # -i 20 
    "scrypt" = "" 
    "blakecoin" = "" #Blakecoin
    "decred" = ""
    "tribus" = "" # -i 20
    "hmq1725" = "" #hmq1725
    "X15" =""
    "yescrypt" = ""
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "Ccminer"
        Port = 4068
        Wrap = $false
        URI = $Uri
    }
}
