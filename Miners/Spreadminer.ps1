. .\Include.ps1

$Path = ".\Bin\NVIDIA-SPREADMINER\\spreadminer.exe"
$Uri = "https://github.com/tsiv/spreadminer/releases/download/v0.1r3/spreadminer_v0.1r3.zip"

$Commands = [PSCustomObject]@{

    "SpreadX11" = ""

}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = ""
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = ""
        Port = 42000
        Wrap = $false
        URI = $Uri
    }
}