. .\Include.ps1

$Path = ".\Bin\NVIDIA-skunk\ccminerskunk.exe"
$Uri = "https://github.com/nemosminer/ccminer-skunk-jha/releases/download/ccminerskunk/ccminerskunk.7z"

$Commands = [PSCustomObject]@{
    "skunk" = "" #Skein
    "bitcore" = "" # -i 19 
    "timetravel" = "" # -i 19
    "x15" = "" # -i 19
    "x17" = "" # -i 19

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
