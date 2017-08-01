. .\Include.ps1

$Path = ".\Bin\NVIDIA-ccminer-2.2\ccminer-x64.exe"
$Uri = "http://ccminer.org/preview/ccminer-2.2-skunk.7z"

$Commands = [PSCustomObject]@{


    "keccak" = "" #Keccak
    "x13" = "" # -i 19
    "neoscrypt" = "" #NeoScrypt
    "tribus" = "" # -i 20

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
