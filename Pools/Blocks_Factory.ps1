param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)


$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $false
$AbbName = 'B.FTRY'
$WalletMode = "NONE"
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer            = "Must register and set wallet for each coin on web, set login on config.txt file"
        ActiveOnManualMode    = $ActiveOnManualMode
        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
        ApiData               = $true
        AbbName               = $AbbName
        WalletMode            = $WalletMode
    }
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    $Pools = @()
    $Pools += [pscustomobject]@{"coin" = "DIGIBYTE"; "algo" = "Groestl"; "symbol" = "DGB"; "server" = "s1.theblocksfactory.com"; "port" = "9003"; "location" = "US"};
    $Pools += [pscustomobject]@{"coin" = "DIGIBYTE"; "algo" = "Skein"; "symbol" = "DGB"; "server" = "s1.theblocksfactory.com"; "port" = "9002"; "location" = "US"};

    $Pools += [pscustomobject]@{"coin" = "FEATHERCOIN"; "algo" = "NeoScrypt"; "symbol" = "FTC"; "server" = "s1.theblocksfactory.com"; "port" = "3333"; "location" = "US"}
    $Pools += [pscustomobject]@{"coin" = "PHOENIXCOIN"; "algo" = "NeoScrypt"; "symbol" = "PXC"; "server" = "s1.theblocksfactory.com"; "port" = "3332"; "location" = "US"}
    $Pools += [pscustomobject]@{"coin" = "ORBITCOIN"; "algo" = "NeoScrypt"; "symbol" = "ORB"; "server" = "s1.theblocksfactory.com"; "port" = "3334"; "location" = "US"}
    $Pools += [pscustomobject]@{"coin" = "GUNCOIN"; "algo" = "NeoScrypt"; "symbol" = "GUN"; "server" = "s1.theblocksfactory.com"; "port" = "3330"; "location" = "US"}

    $Pools |ForEach-Object {
        $Result += [PSCustomObject]@{
            Algorithm             = $_.Algo
            Info                  = $_.Coin
            Price                 = $Null
            Price24h              = $Null
            Protocol              = "stratum+tcp"
            Host                  = $_.Server
            Port                  = $_.Port
            User                  = "$Username.#WorkerName#"
            Pass                  = "x"
            Location              = $_.Location
            SSL                   = $false
            Symbol                = $_.symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolName              = $Name
            WalletMode            = $WalletMode
        }
    }
    remove-variable Pools
}


$Result |ConvertTo-Json | Set-Content $info.SharedFile
remove-variable result
