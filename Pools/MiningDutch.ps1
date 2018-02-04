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
$RewardType = "PROP"
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


    $Pools = @()
    $Pools += [pscustomobject]@{"coin" = "Anarchistprime"; "algo" = "MyriadGroestl"; "symbol" = "ACP"; "port" = "3415"};
    $Pools += [pscustomobject]@{"coin" = "Auroracoin"; "algo" = "MyriadGroestl"; "symbol" = "AUR"; "port" = "3761"};
    $Pools += [pscustomobject]@{"coin" = "Digibyte"; "algo" = "MyriadGroestl"; "symbol" = "DGB"; "port" = "3472"};
    $Pools += [pscustomobject]@{"coin" = "Myriadcoin"; "algo" = "MyriadGroestl"; "symbol" = "XMY"; "port" = "3708"};
    $Pools += [pscustomobject]@{"coin" = "Shield"; "algo" = "MyriadGroestl"; "symbol" = "XSH"; "port" = "3762"};
    $Pools += [pscustomobject]@{"coin" = "Verge"; "algo" = "MyriadGroestl"; "symbol" = "XVG"; "port" = "3426"};

    $Pools += [pscustomobject]@{"coin" = "Bulwark"; "algo" = "Nist5"; "symbol" = "BWK"; "port" = "3758"};
    $Pools += [pscustomobject]@{"coin" = "Coimatic2"; "algo" = "Nist5"; "symbol" = "CTIC2"; "port" = "3712"};
    $Pools += [pscustomobject]@{"coin" = "Ectam"; "algo" = "Nist5"; "symbol" = "ECT"; "port" = "3759"};
    $Pools += [pscustomobject]@{"coin" = "Virtauniquecoin"; "algo" = "Nist5"; "symbol" = "VUC"; "port" = "3408"};
    $Pools += [pscustomobject]@{"coin" = "Wyvern"; "algo" = "Nist5"; "symbol" = "WYV"; "port" = "3497"};

    $Pools += [pscustomobject]@{"coin" = "Desire"; "algo" = "NeoScrypt"; "symbol" = "DSR"; "port" = "3635"};
    $Pools += [pscustomobject]@{"coin" = "Feathercoin"; "algo" = "NeoScrypt"; "symbol" = "FTC"; "port" = "3347"};
    $Pools += [pscustomobject]@{"coin" = "Gobyte"; "algo" = "NeoScrypt"; "symbol" = "GBX"; "port" = "3606"};
    $Pools += [pscustomobject]@{"coin" = "Guncoin"; "algo" = "NeoScrypt"; "symbol" = "GUN"; "port" = "3615"};
    $Pools += [pscustomobject]@{"coin" = "Innova"; "algo" = "NeoScrypt"; "symbol" = "INN"; "port" = "3389"};
    $Pools += [pscustomobject]@{"coin" = "Onexcash"; "algo" = "NeoScrypt"; "symbol" = "ONEX"; "port" = "3655"};
    $Pools += [pscustomobject]@{"coin" = "Orbitcoin"; "algo" = "NeoScrypt"; "symbol" = "ORB"; "port" = "3614"};
    $Pools += [pscustomobject]@{"coin" = "Trezarcoin"; "algo" = "NeoScrypt"; "symbol" = "TZC"; "port" = "3616"};
    $Pools += [pscustomobject]@{"coin" = "Ufocoin"; "algo" = "NeoScrypt"; "symbol" = "UFO"; "port" = "3351"};
    $Pools += [pscustomobject]@{"coin" = "Vivo"; "algo" = "NeoScrypt"; "symbol" = "VIVO"; "port" = "3610"};

    $Pools |ForEach-Object {

        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Price                 = $null
            Price24h              = $null
            Protocol              = "stratum+tcp"
            Host                  = "mining-dutch.nl"
            Port                  = $_.Port
            User                  = "$Username.$WorkerName"
            Pass                  = "x"
            Location              = "Europe"
            SSL                   = $false
            Symbol                = $_.Symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $null
            PoolHashRate          = $null
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

$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result