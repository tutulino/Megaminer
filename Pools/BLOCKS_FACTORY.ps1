param(
    [Parameter(Mandatory = $false)]
    [String]$Querymode = $null #Info/detail"
    )



$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $false

if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "Must register and set wallet for each coin on web, set login on config.txt file"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ApiData = $true
                          }
    }



if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){
        $Pools=@()
        $Pools +=[pscustomobject]@{"coin" = "DIGIBYTE";"algo"="SKEIN"; "symbol"= "DGB";"server"="s1.theblocksfactory.com"; "port"= "9002";"location"="US"};
        $Pools +=[pscustomobject]@{"coin" = "FEATHERCOIN"; "algo"="NEOSCRYPT"; "symbol"= "FTC"; "server"="s1.theblocksfactory.com";"port"="3333";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "PHOENIXCOIN"; "algo"="NEOSCRYPT"; "symbol"= "PXC"; "server"="s1.theblocksfactory.com";"port"="3332";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "ORBITCOIN"; "algo"="NEOSCRYPT"; "symbol"= "ORB"; "server"="s1.theblocksfactory.com";"port"="3334";"location"="US"}
        $Pools +=[pscustomobject]@{"coin" = "GUNCOIN"; "algo"="NEOSCRYPT"; "symbol"= "GUN"; "server"="s1.theblocksfactory.com";"port"="3330";"location"="US"}


        

        $Pools |ForEach-Object {

                               
                                if ((Get-Stat -Name "$Name_$($_.Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "$Name_$($_.Coin)_Profit" -Value (0.0001)}
                                else {$Stat = Set-Stat -Name "$($Name)_$($_.Coin)_Profit" -Value (0.0001)}




                                if (($ManualMiningApiUse -eq $true) -and  ($Querymode -eq "Menu")) {
                                        $ApiResponse=$null
                                        try {
                                                $Apicall="https://"+$_.Server+"/index.php?page=api&action=public"
                                                $ApiResponse=(Invoke-WebRequest $ApiCall -UseBasicParsing  -TimeoutSec 5| ConvertFrom-Json)
                                            } catch{}
                                        }
                                

                                [PSCustomObject]@{
                                    Algorithm     = $_.Algo
                                    Info          = $_.Coin
                                    Price         = 0.0001
                                    StablePrice   = 0.0001
                                    MarginOfError = 0.0001
                                    Protocol      = "stratum+tcp"
                                    Host          = $_.Server
                                    Port          = $_.Port
                                    User          = "$Username.$WorkerName"
                                    Pass          = "x"
                                    Location      = $_.Location
                                    SSL           = $false
                                    Symbol        = $_.symbol
                                    AbbName       = "SPV"
                                    ActiveOnManualMode    = $ActiveOnManualMode
                                    ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                    Workers       = 0
                                    PoolHashRate  = 0

                                }

                        }

        }
                  
