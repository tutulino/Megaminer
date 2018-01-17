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
    }
}


#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************
#****************************************************************************************************************************************************************************************

if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {


    $Pools = @()
    $Pools += [pscustomobject]@{"coin" = "Anarchistprime"; "algo" = "myriad-groestl"; "symbol" = "ACP"; "port" = "3415"};
    $Pools += [pscustomobject]@{"coin" = "Auroracoin"; "algo" = "myriad-groestl"; "symbol" = "AUR"; "port" = "3761"};
    $Pools += [pscustomobject]@{"coin" = "Digibyte"; "algo" = "myriad-groestl"; "symbol" = "DGB"; "port" = "3472"};
    $Pools += [pscustomobject]@{"coin" = "Myriadcoin"; "algo" = "myriad-groestl"; "symbol" = "XMY"; "port" = "3708"};
    $Pools += [pscustomobject]@{"coin" = "Shield"; "algo" = "myriad-groestl"; "symbol" = "XSH"; "port" = "3762"};
    $Pools += [pscustomobject]@{"coin" = "Verge"; "algo" = "myriad-groestl"; "symbol" = "XVG"; "port" = "3426"};

    $Pools += [pscustomobject]@{"coin" = "Bulwark"; "algo" = "nist5"; "symbol" = "BWK"; "port" = "3758"};
    $Pools += [pscustomobject]@{"coin" = "Coimatic2"; "algo" = "nist5"; "symbol" = "CTIC2"; "port" = "3712"};
    $Pools += [pscustomobject]@{"coin" = "Ectam"; "algo" = "nist5"; "symbol" = "ECT"; "port" = "3759"};
    $Pools += [pscustomobject]@{"coin" = "Virtauniquecoin"; "algo" = "nist5"; "symbol" = "VUC"; "port" = "3408"};
    $Pools += [pscustomobject]@{"coin" = "Wyvern"; "algo" = "nist5"; "symbol" = "WYV"; "port" = "3497"};

    $Pools += [pscustomobject]@{"coin" = "desire"; "algo" = "neoscrypt"; "symbol" = "DSR"; "port" = "3635"};
    $Pools += [pscustomobject]@{"coin" = "feathercoin"; "algo" = "neoscrypt"; "symbol" = "FTC"; "port" = "3347"};
    $Pools += [pscustomobject]@{"coin" = "gobyte"; "algo" = "neoscrypt"; "symbol" = "GBX"; "port" = "3606"};
    $Pools += [pscustomobject]@{"coin" = "guncoin"; "algo" = "neoscrypt"; "symbol" = "GUN"; "port" = "3615"};
    $Pools += [pscustomobject]@{"coin" = "innova"; "algo" = "neoscrypt"; "symbol" = "INN"; "port" = "3389"};
    $Pools += [pscustomobject]@{"coin" = "onexcash"; "algo" = "neoscrypt"; "symbol" = "ONEX"; "port" = "3655"};
    $Pools += [pscustomobject]@{"coin" = "orbitcoin"; "algo" = "neoscrypt"; "symbol" = "ORB"; "port" = "3614"};
    $Pools += [pscustomobject]@{"coin" = "trezarcoin"; "algo" = "neoscrypt"; "symbol" = "TZC"; "port" = "3616"};
    $Pools += [pscustomobject]@{"coin" = "ufocoin"; "algo" = "neoscrypt"; "symbol" = "UFO"; "port" = "3351"};
    $Pools += [pscustomobject]@{"coin" = "vivo"; "algo" = "neoscrypt"; "symbol" = "VIVO"; "port" = "3610"};

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
            Location              = "EU"
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
        }
    }
    Remove-Variable Pools
}

$Result |ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result