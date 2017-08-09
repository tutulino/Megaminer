#--------------optional parameters...to allow direct launch without prompt to user
param(
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null#= "AUTOMATIC/MANUAL"
    #[String]$MiningMode = "MANUAL"
    ,
    [Parameter(Mandatory = $false)]
    [string]$PoolsName =$null
    #[array]$PoolsName = "SUPRNOVA"
    #[array]$PoolsName = "YIIMP"
    ,
    [Parameter(Mandatory = $false)]
    [string]$CoinsName =$null
)

. .\Include.ps1

#check parameters

if (($MiningMode -eq "MANUAL") -and ($PoolsName.count -gt 1)) { write-host ONLY ONE POOL CAN BE SELECTED ON MANUAL MODE}


#--------------Load config.txt file
$location=@()
$Location=(Get-Content config.txt | Where-Object {$_ -like '@@LOCATION=*'} )-replace '@@LOCATION=',''
$CoinsWallets=@{} #needed for anonymous pools load
     (Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','' | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}


$SelectedOption=""

#-----------------Ask user for mode to mining AUTO/MANUAL to use, if a pool is indicated in parameters no prompt

Clear-Host
write-host ..............................................................................................
write-host ...................SELECT MODE TO MINE.....................................................
write-host ..............................................................................................

$Modes=@()
$Modes += [pscustomobject]@{"Option"=0;"Mode"='AUTOMATIC';"Explanation"='Not necesary choose coin to mine, program choose more profitable coin based on pool´s statistics'}
$Modes += [pscustomobject]@{"Option"=1;"Mode"='MANUAL';"Explanation"='You select coin to mine'}

$Modes | Format-Table Option,Mode,Explanation  | out-host


If ($MiningMode -eq "")  
    {
     $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
     $MiningMode=$Modes[$SelectedOption].Mode
     write-host SELECTED OPTION::$MiningMode
    }
    else 
    {write-host SELECTED BY PARAMETER OPTION::$MiningMode}


    

#-----------------Ask user for pool/s to use, if a pool is indicated in parameters no prompt

if ($MiningMode -eq "automatic"){
        $Pools=Get-Pools -Querymode "Info" | Where-Object ActiveOnAutomaticMode -eq $true | sort name }
    else 
        {$Pools=Get-Pools -Querymode "Info" | Where-Object ActiveOnManualMode -eq $true | sort name  }
 

$Pools | Add-Member Option "0"
$counter=0
$Pools | ForEach-Object {
        $_.Option=$counter
        $counter++}


if ($MiningMode -eq "automatic"){
        $Pools += [pscustomobject]@{"Disclaimer"="";"ActiveOnManualMode"=$false;"ActiveOnAutomaticMode"=$true;"name"='ALL POOLS';"option"=99}}


#Clear-Host
write-host ..............................................................................................
write-host ...................SELECT POOL/S  TO MINE.....................................................
write-host ..............................................................................................

$Pools | Format-Table Option,name,disclaimer | out-host



If (($PoolsName -eq "") -or ($PoolsName -eq $null))
    {
    if ($MiningMode -eq "manual"){
           $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
           while ($SelectedOption -like '*,*') {
                    $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
                    }
           }
    if ($MiningMode -eq "automatic"){
            $SelectedOption = Read-Host -Prompt 'SELECT OPTION/S (separated by comma):'
            if ($SelectedOption -eq "99") {
                  $SelectedOption=""
                  $Pools | Where-Object Option -ne 99 | ForEach-Object {
                        if  ($SelectedOption -eq "") {$comma=''} else {$comma=','}
                        $SelectedOption += $comma+$_.Option
                        }
                         } 
            
            }
    $SelectedOptions = $SelectedOption -split ','        
    $PoolsName=""            
    $SelectedOptions |ForEach-Object {
            if  ($PoolsName -eq "") {$comma=''} else {$comma=','}
            $PoolsName+=$comma+$Pools[$_].name
            } 
    
    $PoolsName=('#'+$PoolsName) -replace '# ,','' -replace ' ','' -replace '#','' #In test mode this is not necesary, in real execution yes...??????

     write-host SELECTED OPTION:: $PoolsName
    }
    else 
        {
            write-host SELECTED BY PARAMETER ::$PoolsName
        }



#-----------------Ask user for coins----------------------------------------------------


if ($MiningMode -eq "manual"){

            If ($CoinsName -eq "")  
                {

                    #Load coins for pool´s file
                    if ($SelectedPool.ApiData -eq $false)  
                        {write-host        POOL API NOT EXISTS, SOME DATA NOT AVAILABLE!!!!!}
                    else 
                        {write-host CALLING POOL API........}

                    $CoinsPool=Get-Pools -Querymode "Menu" -PoolsFilterList $PoolsName |Select-Object info,symbol,algorithm,Workers,PoolHashRate,Blocks_24h -unique | Sort-Object info

                    $CoinsPool | Add-Member Option "0"
                    $CoinsPool | Add-Member BTCPrice 0
                    $CoinsPool | Add-Member BTCChange24h ([Double]0.0)
                    $CoinsPool | Add-Member DifficultyChange ([Double]0.0)
                    $CoinsPool | Add-Member Profitability24h 0
                    
                    $ManualMiningApiUse=(Get-Content config.txt | Where-Object {$_ -like '@@MANUALMININGAPIUSE=*'} )-replace '@@MANUALMININGAPIUSE=',''    


                    if ($ManualMiningApiUse -eq $true){
                                        try {
                                                #$WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing  | ConvertFrom-Json | Select-Object -ExpandProperty coins
                                                #write-host CALLING WHATTOMINE API........
                                                $BTCEuroPrice=(Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-eur" -UseBasicParsing -TimeoutSec 2 | ConvertFrom-Json).ticker.price
                                                write-host CALLING CRYPTONATOR API........BTC_EUR
                                                $BTCDollarPrice=(Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-usd" -UseBasicParsing  -TimeoutSec 2| ConvertFrom-Json).ticker.price
                                                write-host CALLING CRYPTONATOR API........BTC_USD
                                            } catch{}
                                } 

                    $Counter = 0
                    $CoinsPool | ForEach-Object {

                                                if ($ManualMiningApiUse -eq $true){
                                                                "CALLING BITTREX API........"+$_.symbol+"_BTC" | write-host
                                                                try {
                                                                    $Apicall="https://bittrex.com/api/v1.1/public/getmarketsummary?market=btc-"+$_.symbol
                                                                    $ApiResponse=(Invoke-WebRequest $ApiCall -UseBasicParsing  -TimeoutSec 2| ConvertFrom-Json|Select-Object -ExpandProperty result)
                                                                    } 
                                                                catch{}
                                                                if ($ApiResponse -ne $null) {
                                                                                            $_.BTCPrice=$ApiResponse.Last
                                                                                            #$_.BTCChange24h=(1-($ApiResponse.Last/$ApiResponse.prevday))*100
                                                                                            }

                                                                if ($_.BTCPrice -eq 0){
                                                                                        "CALLING CRYPTOPIA API........"+$_.symbol+"_BTC" |Write-Host
                                                                                        try {
                                                                                                $Apicall="https://www.cryptopia.co.nz/api/GetMarket/"+$_.symbol+'_BTC'
                                                                                                $ApiResponse=(Invoke-WebRequest $ApiCall -UseBasicParsing  -TimeoutSec 2| ConvertFrom-Json|Select-Object -ExpandProperty data)
                                                                                            } catch{}
                                                                                        
                                                                                        if ($ApiResponse -ne $null) {
                                                                                                                    $_.BTCPrice=$ApiResponse.LastPrice
                                                                                                                    #$_.BTCChange24h=$ApiResponse.Change
                                                                                                                    }
                                                                                    }
                                                                }
                                                $_.Option=$Counter                                                                
                                                $counter++
                                             }
                    
                    Clear-Host
                    write-host ....................................................................................................
                    write-host ............................SELECT COIN TO MINE.....................................................
                    write-host ....................................................................................................

                    #Only one pool is allowed in manual mode at this point
                    $SelectedPool=$Pools | where name -eq $PoolsName
                    
                    if ($SelectedPool.ApiData -eq $false)  {write-host        ----POOL API NOT EXISTS, SOME DATA NOT AVAILABLE---}

                    if ($Location -eq 'Europe') {$LabelPrice="EurPrice"} else {$LabelPrice="DollarPrice"}

                    $CoinsPool  | Format-Table -Wrap (
                                @{Label = "Option"; Expression = {$_.Option}; Align = 'right'},  
                                @{Label = "Name"; Expression = {$_.info.toupper()}; Align = 'left'} ,
                                @{Label = "Symbol"; Expression = {$_.symbol}; Align = 'left'},   
                                @{Label = "Algorithm"; Expression = {$_.algorithm.tolower()}; Align = 'left'},
                                @{Label = "Workers"; Expression = {$_.Workers}; Align = 'right'},   
                                @{Label = "PoolHashRate"; Expression = {"$($_.PoolHashRate | ConvertTo-Hash)/s"}; Align = 'right'},   
                                @{Label = "Blocks_24h"; Expression = {$_.Blocks_24h}; Align = 'right'},
                                @{Label = "BTCPrice"; Expression = {[math]::Round($_.BTCPrice,6)}; Align = 'right'},
                                #@{Label = "BTCChange24h"; Expression = {([math]::Round($_.BTCChange24h,1)).ToString()+'%'}; Align = 'right'},
                                @{Label = $LabelPrice; Expression = { if ($Location -eq 'Europe') {[math]::Round($_.BTCPrice*$BTCEuroPrice,2)} else {[math]::Round($_.BTCPrice*$BTCDollarPrice,2)}}; Align = 'right'}
                               
                                
                                )  | out-host        
            

                    $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
                    while ($SelectedOption -like '*,*') {
                                                        $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
                                                        }
                    $CoinsName = $CoinsPool[$SelectedOption].Info -replace '_',',' #for dual mining

                    write-host SELECTED OPTION:: $CoinsName 
                }
            else 
                {

                    write-host SELECTED BY PARAMETER :: $CoinsName
                }                    

           
            }

            
#-----------------Launch Command
            $command="./core.ps1 -MiningMode $MiningMode -PoolsName $PoolsName"
            if ($MiningMode -eq "manual"){$command+=" -Coins $CoinsName" } 

            #write-host $command
            Invoke-Expression $command

