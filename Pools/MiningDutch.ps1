param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [PSCustomObject]$Info
)

#. .\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$ActiveOnAutomatic24hMode = $false
$AbbName = 'DMN'
$WalletMode = "NONE"
$RewardType = "PPS"
$Result = @()

if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "Must register and set wallet for each coin on web"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $true
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    if (!$UserName) {
        Write-Warning "$Name UserName not defined in config.ini"
        Exit
    }

    $Pools = @()

    $Pools += [PSCustomObject]@{coin = "Cerberus"; algo = "NeoScrypt"; symbol = "CBS"; port = 3426};
    $Pools += [PSCustomObject]@{coin = "Crowdcoin"; algo = "NeoScrypt"; symbol = "CRC"; port = 3315};
    $Pools += [PSCustomObject]@{coin = "Desire"; algo = "NeoScrypt"; symbol = "DSR"; port = 3635};
    $Pools += [PSCustomObject]@{coin = "Feathercoin"; algo = "NeoScrypt"; symbol = "FTC"; port = 3347};
    $Pools += [PSCustomObject]@{coin = "Gobyte"; algo = "NeoScrypt"; symbol = "GBX"; port = 3606};
    $Pools += [PSCustomObject]@{coin = "Guncoin"; algo = "NeoScrypt"; symbol = "GUN"; port = 3615};
    $Pools += [PSCustomObject]@{coin = "Innova"; algo = "NeoScrypt"; symbol = "INN"; port = 3389};
    $Pools += [PSCustomObject]@{coin = "Nyxcoin"; algo = "NeoScrypt"; symbol = "NYX"; port = 3419};
    $Pools += [PSCustomObject]@{coin = "Onexcash"; algo = "NeoScrypt"; symbol = "ONEX"; port = 3655};
    $Pools += [PSCustomObject]@{coin = "Orbitcoin"; algo = "NeoScrypt"; symbol = "ORB"; port = 3614};
    $Pools += [PSCustomObject]@{coin = "Qbic"; algo = "NeoScrypt"; symbol = "QBIC"; port = 3416};
    $Pools += [PSCustomObject]@{coin = "Sparks"; algo = "NeoScrypt"; symbol = "SPK"; port = 3408};
    $Pools += [PSCustomObject]@{coin = "Trezarcoin"; algo = "NeoScrypt"; symbol = "TZC"; port = 3616};
    $Pools += [PSCustomObject]@{coin = "Ufocoin"; algo = "NeoScrypt"; symbol = "UFO"; port = 3351};
    $Pools += [PSCustomObject]@{coin = "Vivo"; algo = "NeoScrypt"; symbol = "VIVO"; port = 3610};

    $Pools += [PSCustomObject]@{coin = "Monacoin"; algo = "Lyra2rev2"; symbol = "MONA"; port = 3420};
    $Pools += [PSCustomObject]@{coin = "Rupee"; algo = "Lyra2rev2"; symbol = "RUP"; port = 3427};
    $Pools += [PSCustomObject]@{coin = "Shield"; algo = "Lyra2rev2"; symbol = "XSH"; port = 3432};
    $Pools += [PSCustomObject]@{coin = "Straks"; algo = "Lyra2rev2"; symbol = "STAK"; port = 3433};
    $Pools += [PSCustomObject]@{coin = "Verge"; algo = "Lyra2rev2"; symbol = "XVG"; port = 3431};
    $Pools += [PSCustomObject]@{coin = "Vertcoin"; algo = "Lyra2rev2"; symbol = "VTC"; port = 3429};

    $Pools | ForEach-Object {

        $Result += [PSCustomObject]@{
            Algorithm             = Get-AlgoUnifiedName $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            Host                  = $_.Algo + ".mining-dutch.nl"
            Port                  = $_.Port
            User                  = "$UserName.$WorkerName"
            Pass                  = "x"
            Location              = "EU"
            SSL                   = $false
            Symbol                = $_.Symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
            WalletSymbol          = $_.Symbol
            Fee                   = 0.02
            EthStMode             = 3
            RewardType            = $RewardType
        }
    }
    Remove-Variable Pools
}

$Result | ConvertTo-Json | Set-Content $Info.SharedFile
Remove-Variable Result
