
#--------------optional parameters...to allow direct launch without prompt to user
param(
    [Parameter(Mandatory = $false)]
    [String]$PoolName #= "SUPRNOVA"
    ,
    [Parameter(Mandatory = $false)]
    [String]$CoinName  #= "KOMODO"
    ,
    [Parameter(Mandatory = $false)]
    [String]$Dcri  #= "KOMODO"


)


#Parameter backup
$ParameterPoolName=$PoolName
$ParameterCoinName=$CoinName
$ParameterDcri=$Dcri


#--------------Load config.txt file
$ConfigLocation=(Get-Content config.txt | Where-Object {$_ -like '*@@LOCATION=*'} )-replace '@@LOCATION=',''
$ConfigDonate=(Get-Content config.txt | Where-Object {$_ -like '*@@DONATE=*'} )-replace '@@DONATE=',''
$ConfigWalletDonate=(Get-Content config.txt | Where-Object {$_ -like '*@@WALLETDONATE=*'} )-replace '@@WALLETDONATE=',''
$ConfigWallet=(Get-Content config.txt | Where-Object {$_ -like '*@@WALLET=*'} ) -replace '@@WALLET=',''
$ConfigUsername=(Get-Content config.txt | Where-Object {$_ -like '*@@USERNAME=*'} )-replace '@@USERNAME=',''
$ConfigType=(Get-Content config.txt | Where-Object {$_ -like '*@@TYPE=*'}) -replace '@@TYPE=',''
$ConfigInterval=(Get-Content config.txt | Where-Object {$_ -like '*@@INTERVAL=*'}) -replace '@@INTERVAL=',''
$ConfigWorkerName=(Get-Content config.txt | Where-Object {$_ -like '*@@WORKERNAME=*'} )-replace '@@WORKERNAME=',''
$ConfigCurrency=(Get-Content config.txt | Where-Object {$_ -like '*@@CURRENCY=*'} )-replace '@@CURRENCY=',''


$pools= if(Test-Path 'Pools'){Get-ChildItem 'Pools' | Sort-Object}

#|Foreach-Object {$_.basename -replace '_',' '}

#-----------------Ask user for pool to use, if a pool is indicated in parameters no prompt

Clear-Host
$Position=0
$SelectedPoolIndex=-1
$AutomaticPoolsString='#'
write-host ...............................................
write-host ..........SELECT POOL/S  TO MINE...............
write-host ...............................................
 
Foreach ($pool in $pools)
{
    $PoolName=$pool.basename -replace '_',' '
    if ($pool.extension -eq ".ps1") {
            $PoolType='(Automatic Coin Selection)'
            #Also Use loop for generation of All automatic pools string
            $AutomaticPoolsString=$AutomaticPoolsString+','+$Pool.basename
        }
         else {$PoolType=''}
    write-host   $Position - $PoolName $PoolType
    #Search for pool selected in parameter
    If ($ParameterPoolName -eq $pool.basename) {$SelectedPoolIndex=$Position}
    $Position++
}

If ($ParameterPoolName -eq "All") {$SelectedPoolIndex=99}
write-host 99. All "automatic coin" pools
write-host ...............................................
write-host ...............................................

If ($SelectedPoolIndex -eq -1)  
    {$SelectedPoolIndex = Read-Host -Prompt 'Input pool number and press Enter:'}
    else 
    {write-host Selected option $SelectedPoolIndex on parameters}
        

##Ejecutamos el pool seleccionado

If ($SelectedPoolIndex -eq 99)   #All Automatic pools
{
 $SelectedPoolName=$AutomaticPoolsString -replace '#,',''
 $SelectedPoolExtension='.ps1'

}
else 
{
   $SelectedPoolName=$Pools[$SelectedPoolIndex].BaseName
   $SelectedPoolExtension=$Pools[$SelectedPoolIndex].Extension
}

$PoolFilePath=".\pools\"+$SelectedPoolName+$SelectedPoolExtension

if ($SelectedPoolExtension -eq '.ps1') #Pools from AAronsace Multipool
    {
        
         #Load information about the Pools to check if it has location
        if ($SelectedPoolIndex -ne 99) {$PoolLocations=(Get-Content $PoolFilePath | Where-Object {$_ -like '*$Location*=*'} )}
        If ($PoolLocations -match $ConfigLocation) {$LaunchLocation=$ConfigLocation} else {$LaunchLocation="US"}
        Invoke-Expression "./MultiPoolMiner.ps1 -Interval $ConfigInterval -Wallet $ConfigWallet -Username $ConfigUserName -Workername $ConfigWorkerName -Location $LaunchLocation -PoolName $SelectedPoolName -Type $ConfigType  -Donate $ConfigDonate -WalletDonate $ConfigWalletDonate -currency $ConfigCurrency" 
    }
else #Other Pools no automatics
    {

            try {

                $WTMResponse = Invoke-WebRequest "https://whattomine.com/coins.json" -UseBasicParsing  | ConvertFrom-Json
                $CTPResponse = Invoke-WebRequest "https://www.cryptopia.co.nz/api/GetMarkets/BTC" -UseBasicParsing | ConvertFrom-Json | Select-Object -ExpandProperty Data
                $BTXResponse = Invoke-WebRequest "https://bittrex.com/api/v1.1/public/getmarketsummaries" -UseBasicParsing | ConvertFrom-Json | Select-Object -ExpandProperty result
                $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing  | ConvertFrom-Json | Select-Object -ExpandProperty BPI
               
            } 

            catch {}
            #wait for invoke ends
            Start-Sleep 1

            #Load coins information
            $CoinsColection = (get-content "Coins.json" | ConvertFrom-Json) |sort name
            $CoinsColection | Add-Member option -1
            $CoinsColection | Add-Member BTC ""
            $CoinsColection | Add-Member BtcCh24h ""
            $CoinsColection | Add-Member USD ""
            $CoinsColection | Add-Member DiffOver24 ""
            $CoinsColection | Add-Member EUR ""
            $CoinsColection | Add-Member profitability ""


            #Load pool information
            $PoolInfo = ConvertFrom-Json "$(get-content $PoolFilePath)"

            #Load algo informattion
            $AlgoColection = (get-content "Algorithms.json" | ConvertFrom-Json)  


            If ($ParameterCoinName -eq $null) {Clear-Host}
            write-host .........................................................................................
            write-host ...........................SELECT COIN TO MINE...........................................
            write-host .........................................................................................

            $Position=0
            Foreach ($Coin in $CoinsColection)
                    {
                        #only shows if pool have this coin
                        if (($PoolInfo.pools | where-object coin -eq $Coin.name) -ne $null)
                            {
                                
                                #Add info from cryptopia
                                if ($CTPResponse -ne $null)
                                {
                                    $CTPMarket=$coin.symbol+"/BTC"
                                    $CoinCTPinfo=$CTPResponse | where label -eq $CTPMarket
                                    If ($CoinCTPinfo -ne $null) 
                                        {
                                        $Coin.BTC=$CoinCTPinfo.lastprice
                                        $Coin.BtcCh24h=$CoinCTPinfo.change
                                        $Coin.USD=[math]::Round($CoinCTPinfo.lastprice*$CDKResponse.usd.rate,2)
                                        $Coin.EUR=[math]::Round($CoinCTPinfo.lastprice*$CDKResponse.eur.rate,2)
                                        }
                                }   

                                 #Add info from bittrex if haven´t from cryptopia
                                if (($BTXResponse -ne $null) -and ($CoinCTPinfo -eq $null))
                                {
                                    $BTXMarket="BTC-"+$coin.symbol
                                    $CoinBTXinfo=$BTXResponse | where marketname -eq $BTXMarket
                                    If ($CoinBTXinfo -ne $null) 
                                        {
                                        $Coin.BTC=$CoinBTXinfo.last
                                        if ($CoinBTXinfo.PrevDay -ne 0) {$Coin.BtcCh24h=[math]::Round((($CoinBTXinfo.last/$CoinBTXinfo.PrevDay)-1)*100,2)}
                                        $Coin.USD=[math]::Round($CoinBTXinfo.lastprice*$CDKResponse.usd.rate,2)
                                        $Coin.EUR=[math]::Round($CoinBTXinfo.lastprice*$CDKResponse.eur.rate,2)
                                        }
                                }   

                                #Add info from Whattomine, search by coin symbol
                                if ($WTMResponse -ne $null)
                                    {foreach ($WTMCoin in ($WTMResponse.coins | get-member  -MemberType NoteProperty))
                                        {
                                        $CoinWTMinfo=$WTMResponse |Select-Object -ExpandProperty Coins | Select-Object -ExpandProperty $WTMCoin.name
                                        If ($CoinWTMinfo.tag -eq $coin.symbol) 
                                                {
                                                $Coin.DiffOver24=[math]::Round((($CoinWTMinfo.Difficulty/$CoinWTMinfo.Difficulty24)-1)*100,1)
                                                $Coin.profitability=$CoinWTMinfo.estimated_rewards
                                                
                                                }
                                        }
                                    }
                                #Search for coin selected in parameter
                                If ($ParameterCoinName -eq $Coin.name) {$SelectedCoinIndex=$Position}
                                $coin.option=$Position
                                $Position++
                            }       
                        
                }

                If ($ConfigLocation -eq "EUROPE") {$CoinsColection | where option -ne -1| Sort-Object -Property name | Format-Table Option,name,symbol,algo,BTC,EUR,BtcCh24h,DiffOver24  | out-host}
                    else {$CoinsColection | where option -ne -1| Sort-Object -Property name | Format-Table Option,name,symbol,algo,BTC,USD,BtcCh24h,DiffOver24 | out-host}

        
                
                If ($ParameterCoinName -eq "")  
                    {$SelectedCoinIndex = Read-Host -Prompt 'Input coin number and press Enter:'}
                    else 
                    {write-host Selected option $SelectedCoinIndex on parameters}
                
                $DestinationCoin= $CoinsColection | Where-Object option -eq $SelectedCoinIndex
                
                #Load algo for this coin
                $DestinationAlgo = $AlgoColection  | Where-Object name -eq $DestinationCoin.Algo 
                
                #If dual must recalculate all properties and ask prompt for DCRI
                if ($DestinationAlgo.Dual -eq "TRUE") 
                    {
                        $Split= $DestinationCoin.name -split(" | ")
                        $DestinationCoin= $CoinsColection | Where-Object name -eq $Split[0]
                        $DestinationCoinDual= $CoinsColection | Where-Object name -eq $Split[2]

                        #Search Server for dual coin
                        $DestinationServerDual=$PoolInfo.pools | where-object Location -eq $ConfigLocation  | where-object Coin -eq $DestinationCoinDual.name
                        if ($DestinationServerDual -eq $null) {$DestinationServerDual=$PoolInfo.pools | where-object Location -eq US |where-object Coin -eq $DestinationCoinDual.name}
                        if ($DestinationServerDual -eq $null) {$DestinationServerDual=$PoolInfo.pools | where-object Coin -eq $DestinationCoinDual.name}
                        
                        #Promt user for dcri
                            If ($ParameterDCRI -eq $null) {Clear-Host}
                            write-host ...............................................
                            write-host You can change DCRI intensity in runtime with "+" and "-" keys and check current statistics with "s" key    
                            If ($ParameterDcri -eq "")  
                                {
                                
                                    $SelectedDcri = Read-Host -Prompt 'Input initial DCRI (default 30) and press Enter:'}
                            else 
                                {write-host Selected option $ParameterDcri on parameters}
                        
                    }

                #search servers for location for indicated coin
                $DestinationServer=$PoolInfo.pools | where-object Location -eq $ConfigLocation  | where-object Coin -eq $DestinationCoin.name
                if ($DestinationServer -eq $null) {$DestinationServer=$PoolInfo.pools | where-object Location -eq US |where-object Coin -eq $DestinationCoin.name}
                if ($DestinationServer -eq $null) {$DestinationServer=$PoolInfo.pools | where-object Coin -eq $DestinationCoin.name}
            
                #Launch command

                $Command=$DestinationAlgo.Miner  -replace '!','\' -replace '#server#',$DestinationServer.server -replace '#serverdual#',$DestinationServerDual.server
                $Command=$Command  -replace '#Port#',$DestinationServer.port -replace '#portdual#',$DestinationServerDual.port
                $Command=$Command  -replace '#UserName#',$ConfigUsername -replace '#workername#',$ConfigWorkerName  -replace '#dcri#',$SelectedDcri
                write-host ............LAUNCHED COMMAND...................
                write-host $Command
                write-host ...............................................

                #Call into loop for fail relaunch
                while (1 -eq 1) {Invoke-Expression $Command }

                
            

    }
