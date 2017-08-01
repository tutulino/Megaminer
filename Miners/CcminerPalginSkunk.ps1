. .\Include.ps1

$Path = ".\Bin\NVIDIA-palginkunk\ccminer.exe"
$Uri = "https://github.com/palginpav/ccminer/releases/download/skunk-1/ccminer-1.0-skunk.zip"

$Commands = [PSCustomObject]@{
    "skunk" = ""
     
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | ForEach-Object {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "-a $_ -o stratum+tcp://$($Pools.(Get-Algorithm($_)).Host):$($Pools.(Get-Algorithm($_)).Port) -u $($Pools.(Get-Algorithm($_)).User) -p $($Pools.(Get-Algorithm($_)).Pass)$($Commands.$_)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "ccminer"
        Port = 4068
        Wrap = $true
        URI = $Uri
    }
}
