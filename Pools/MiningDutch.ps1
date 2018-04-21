param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
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


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {

    if (!$UserName) {
        Write-Host "$Name USERNAME not defined in config.ini"
        Exit
    }

    $Pools = @()

    $Pools += [pscustomobject]@{"coin" = "Cerberus"; "algo" = "NeoScrypt"; "symbol" = "CBS"; "port" = 3426};
    $Pools += [pscustomobject]@{"coin" = "Crowdcoin"; "algo" = "NeoScrypt"; "symbol" = "CRC"; "port" = 3315};
    $Pools += [pscustomobject]@{"coin" = "Desire"; "algo" = "NeoScrypt"; "symbol" = "DSR"; "port" = 3635};
    $Pools += [pscustomobject]@{"coin" = "Feathercoin"; "algo" = "NeoScrypt"; "symbol" = "FTC"; "port" = 3347};
    $Pools += [pscustomobject]@{"coin" = "Gobyte"; "algo" = "NeoScrypt"; "symbol" = "GBX"; "port" = 3606};
    $Pools += [pscustomobject]@{"coin" = "Guncoin"; "algo" = "NeoScrypt"; "symbol" = "GUN"; "port" = 3615};
    $Pools += [pscustomobject]@{"coin" = "Innova"; "algo" = "NeoScrypt"; "symbol" = "INN"; "port" = 3389};
    $Pools += [pscustomobject]@{"coin" = "Nyxcoin"; "algo" = "NeoScrypt"; "symbol" = "NYX"; "port" = 3419};
    $Pools += [pscustomobject]@{"coin" = "Onexcash"; "algo" = "NeoScrypt"; "symbol" = "ONEX"; "port" = 3655};
    $Pools += [pscustomobject]@{"coin" = "Orbitcoin"; "algo" = "NeoScrypt"; "symbol" = "ORB"; "port" = 3614};
    $Pools += [pscustomobject]@{"coin" = "Qbic"; "algo" = "NeoScrypt"; "symbol" = "QBIC"; "port" = 3416};
    $Pools += [pscustomobject]@{"coin" = "Sparks"; "algo" = "NeoScrypt"; "symbol" = "SPK"; "port" = 3408};
    $Pools += [pscustomobject]@{"coin" = "Trezarcoin"; "algo" = "NeoScrypt"; "symbol" = "TZC"; "port" = 3616};
    $Pools += [pscustomobject]@{"coin" = "Ufocoin"; "algo" = "NeoScrypt"; "symbol" = "UFO"; "port" = 3351};
    $Pools += [pscustomobject]@{"coin" = "Vivo"; "algo" = "NeoScrypt"; "symbol" = "VIVO"; "port" = 3610};

    $Pools += [pscustomobject]@{"coin" = "Monacoin"; "algo" = "Lyra2rev2"; "symbol" = "MONA"; "port" = 3420};
    $Pools += [pscustomobject]@{"coin" = "Rupee"; "algo" = "Lyra2rev2"; "symbol" = "RUP"; "port" = 3427};
    $Pools += [pscustomobject]@{"coin" = "Shield"; "algo" = "Lyra2rev2"; "symbol" = "XSH"; "port" = 3432};
    $Pools += [pscustomobject]@{"coin" = "Straks"; "algo" = "Lyra2rev2"; "symbol" = "STAK"; "port" = 3433};
    $Pools += [pscustomobject]@{"coin" = "Verge"; "algo" = "Lyra2rev2"; "symbol" = "XVG"; "port" = 3431};
    $Pools += [pscustomobject]@{"coin" = "Vertcoin"; "algo" = "Lyra2rev2"; "symbol" = "VTC"; "port" = 3429};

    $Pools | ForEach-Object {

        $Result += [PSCustomObject]@{
            Algorithm             = get_algo_unified_name $_.Algo
            Info                  = $_.Coin
            Protocol              = "stratum+tcp"
            Host                  = $_.Algo + ".mining-dutch.nl"
            Port                  = $_.Port
            User                  = "$Username.$WorkerName"
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
