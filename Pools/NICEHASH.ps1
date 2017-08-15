param(
    [Parameter(Mandatory = $true)]
    #[String]$Querymode = "core"
    [String]$Querymode = $null 
    )

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode    = $true
$ActiveOnAutomaticMode = $true
$AbbName = 'NH'


if ($Querymode -eq "info"){
        [PSCustomObject]@{
                    Disclaimer = "No registration, Autoexchange to BTC always"
                    ActiveOnManualMode=$ActiveOnManualMode  
                    ActiveOnAutomaticMode=$ActiveOnAutomaticMode
                    ApiData = $True
                    AbbName=$AbbName
                         }
    }


    
if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")){

        try {
            $NH_Request = Invoke-WebRequest "https://api.nicehash.com/api?method=simplemultialgo.info" -UseBasicParsing | ConvertFrom-Json |Select-Object -expand result |Select-Object -expand simplemultialgo
            
        }
        catch {
                    WRITE-HOST 'Nicehash API NOT RESPONDING...ABORTING'
                    EXIT
                }

        

        $Locations=@()
        $Locations += [PSCustomObject]@{NhLocation ='USA';MMlocation='US'}
        $Locations += [PSCustomObject]@{NhLocation ='EU';MMlocation='EUROPE'}

        $NH_Request | ForEach-Object {


                    $NH_Algorithm = get-algo-unified-name ($_.name)
                    
                    $Divisor = 1000000000

                    switch ($NH_Algorithm) {
                            "Ethash" {$NH_coin="Ethereum"} #must force to allow dualmining Ethereum+?
                            "Lbry" {$NH_coin="Lbry"}
                            "Pascal" {$NH_coin="Pascal"}
                            "Blake2b" {$NH_coin="Siacoin"}
                            "Blake14r" {$NH_coin="Decred"}
                            default {$NH_coin=$NH_Algorithm}
                            }
                 
                
                    if ((Get-Stat -Name "NH_$($NH_Coin)_Profit") -eq $null) {$Stat = Set-Stat -Name "NH_$($NH_Coin)_Profit" -Value ([Double]$_.paying / $Divisor * (1 - 0.05))}
                    else {$Stat = Set-Stat -Name "$($Name)_$($NH_Coin)_Profit" -Value ([Double]$_.paying / $Divisor)}




                    foreach ($location in $Locations) {

            

                                    [PSCustomObject]@{
                                        Algorithm     = $NH_Algorithm
                                        Info          = $NH_coin
                                        Price         = $Stat.Live
                                        StablePrice   = $Stat.Week
                                        MarginOfError = $Stat.Week_Fluctuation
                                        Protocol      = "stratum+tcp"
                                        Host          = ($_.name)+"."+$location.NhLocation+".nicehash.com"
                                        Port          = $_.port
                                        User          = $CoinsWallets.get_item('BTC')
                                        Pass          = "x"
                                        Location      = $location.MMLocation
                                        SSL           = $false
                                        Symbol        = $null
                                        AbbName       = $AbbName
                                        ActiveOnManualMode    = $ActiveOnManualMode
                                        ActiveOnAutomaticMode = $ActiveOnAutomaticMode
                                        }
                        }
                }
    }

