. .\Include.ps1

$Path = ".\Bin\Nsgminer\nsgminer.exe"
$Uri = "https://github.com/ghostlander/nsgminer/releases/download/nsgminer-v0.9.2/nsgminer-win64-0.9.2.zip"

$Commands = [PSCustomObject]@{
    "neoscrypt" = "" #NeoScrypt
}

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName

$Commands | Get-Member -MemberType NoteProperty | Select -ExpandProperty Name | ForEach {
    [PSCustomObject]@{
        Type = "NVIDIA"
        Path = $Path
        Arguments = "--api-port 24028 --api-listen --neoscrypt -o stratum+tcp://$($Pools.NeoScrypt.Host):$($Pools.NeoScrypt.Port) -u $($Pools.NeoScrypt.User) -p $($Pools.NeoScrypt.Pass)"
        HashRates = [PSCustomObject]@{(Get-Algorithm($_)) = $Stats."$($Name)_$(Get-Algorithm($_))_HashRate".Week}
        API = "Xgminer"
        Port = 24028
        Wrap = $false
        URI = $Uri
    }
}