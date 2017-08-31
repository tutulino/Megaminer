param(
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = $null,

    [Parameter(Mandatory = $false)]
    [Array]$PoolsName = $null,

    [Parameter(Mandatory = $false)]
    [array]$CoinsName= $null,

    [Parameter(Mandatory = $false)]
    [String]$Proxy = "", #i.e http://192.0.0.1:8080 

    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null

)

. .\Include.ps1


#Parameters for testing, must be commented on real use

#$MiningMode='Automatic'
#$MiningMode='Automatic24h'
#$MiningMode='Manual'

#$PoolsName=('zpool','mining_pool_hub')
#$PoolsName='whattomine_virtual'
#$PoolsName='yiimp'
#$PoolsName=('hash_refinery','zpool','mining_pool_hub')
#$PoolsName='mining_pool_hub'
#$PoolsName='zpool'
#$PoolsName=('BLOCKS_FACTORY','nicehash')
#$PoolsName=('Suprnova')
#$PoolsName=

#$Coinsname =('bitcore','Signatum','Zcash')
#$Algorithm =('bitcore')


#--------------Load config.txt file
$location=@()
$Types=@()
$Currency=@()


$Location=(Get-Content config.txt | Where-Object {$_ -like '@@LOCATION=*'} )-replace '@@LOCATION=',''
$Donate=(Get-Content config.txt | Where-Object {$_ -like '@@DONATE=*'} )-replace '@@DONATE=',''
$UserName=(Get-Content config.txt | Where-Object {$_ -like '@@USERNAME=*'} )-replace '@@USERNAME=',''
$Types=(Get-Content config.txt | Where-Object {$_ -like '@@TYPE=*'}) -replace '@@TYPE=','' -split ','
$Interval=(Get-Content config.txt | Where-Object {$_ -like '@@INTERVAL=*'}) -replace '@@INTERVAL=',''
$WorkerName=(Get-Content config.txt | Where-Object {$_ -like '@@WORKERNAME=*'} )-replace '@@WORKERNAME=',''
$Currency=(Get-Content config.txt | Where-Object {$_ -like '@@CURRENCY=*'} )-replace '@@CURRENCY=',''
$CoinsWallets=@{} 
     (Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','' | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}



Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
try {if ((Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}}catch {}

if ($Proxy -eq "") {$PSDefaultParameterValues.Remove("*:Proxy")}
else {$PSDefaultParameterValues["*:Proxy"] = $Proxy}


$ActiveMiners = @()

#Start the log
Start-Transcript ".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"


#Set donation parameters
$LastDonated = (Get-Date).AddDays(-1).AddHours(1)
$UserNameDonate = "tutulino"
$WorkerNameDonate = "Megaminer"
$CoinsWalletsDonate=@{}  
    (Get-Content config.txt | Where-Object {$_ -like '@@WALLETDONATE_*=*'}) -replace '@@WALLETDONATE_*=*','' | ForEach-Object {$CoinsWalletsDonate.add(($_ -split "=")[0],($_ -split "=")[1])}

$UserNameBackup = $UserName
$WorkerNameBackup = $WorkerName
$CoinsWalletsBackup=$CoinsWallets


$ActiveMinersIdCounter=0
$Activeminers=@()
$BechmarkintervalTime=(Get-Content config.txt | Where-Object {$_ -like '@@BENCHMARKTIME=*'} )-replace '@@BENCHMARKTIME=',''
$Screen=(Get-Content config.txt | Where-Object {$_ -like '@@STARTSCREEN=*'} )-replace '@@STARTSCREEN=',''
$ProfitsScreenLimit=40

Clear-Host
set-WindowSize 120 60 


 $GpuPlatform= $([array]::IndexOf((Get-WmiObject -class CIM_VideoController | Select-Object -ExpandProperty AdapterCompatibility), 'Advanced Micro Devices, Inc.')) 
    if ($GpuPlatform -eq -1) {$GpuPlatform=1} #For testing amd miners on nvidia


#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#This loop will be runnig forever
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------
#----------------------------------------------------------------------------------------------------------------------------

while ($true) {
    
    $NextInterval=$Interval

    #Activate or deactivate donation
    if ((Get-Date).AddDays(-1).AddMinutes($Donate) -ge $LastDonated) {
        $UserName = $UserNameDonate
        $WorkerName = $WorkerNameDonate
        $CoinsWallets= $CoinsWalletsDonate
        }
    if ((Get-Date).AddDays(-1) -ge $LastDonated) {
        $UserName = $UserNameBackup
        $WorkerName = $WorkerNameBackup
        $LastDonated = Get-Date
        $CoinsWallets = $CoinsWalletsBackup
       }
        

    $Rates = [PSCustomObject]@{}
    $Currency | ForEach-Object {$Rates | Add-Member $_ (Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-$_" -UseBasicParsing | ConvertFrom-Json).ticker.price}

 

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin

     do
        {
        $Pools=Get-Pools -Querymode "core" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm
        if  ($Pools.Count -eq 0) {"NO POOLS!....retry in 10 sec" | Out-Host;Start-Sleep 10}
        }
    while ($Pools.Count -eq 0) 
    
    


    #Load information about the Miner asociated to each Coin-Algo-Miner

    $Miners= @()
    
   


    foreach ($MinerFile in (Get-ChildItem "Miners" | Where-Object extension -eq '.json'))  
        {
            try { $Miner =$MinerFile | Get-Content | ConvertFrom-Json } 
            catch 
                {   Write-host -------BAD FORMED JSON: $MinerFile 
                Exit}
 
            #Only want algos selected types
            If ($Types.Count -ne 0 -and (Compare-Object $Types $Miner.types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0)
                {

                    foreach ($Algo in ($Miner.Algorithms))
                        {
                            ##Algoname contains real name for dual and no dual miners
                            $Split=$Algo.PSObject.Properties.Name -split ("_")
                            $AlgoName =  $Split[0]
                            $AlgoNameDual = $Split[1]

                            $HashrateValue=Get-Hashrate -minername $Minerfile.basename -algorithm $AlgoName

                             ##for dual mining add second hashrate
                            if ($Miner.Dualmining -eq $true) 
                                {
                                   $HashrateValueDual=Get-Hashrate -minername $Minerfile.basename -algorithm $AlgoNameDual
                                }

                            #Only want algos pools has  

                                $Pools | where-object Algorithm -eq $AlgoName | ForEach-Object {
                                    
                                        if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne  $null) -or ($Miner.Dualmining -eq $false)){

                                           if ($_.info -eq $Miner.DualMiningMainCoin -or $Miner.Dualmining -eq $false) {  #not allow dualmining if main coin not coincide
                                           
                                                $Arguments = $Miner.Arguments  -replace '#PORT#',$_.Port -replace '#SERVER#',$_.Host -replace '#PROTOCOL#',$_.Protocol -replace '#LOGIN#',$_.user -replace '#PASSWORD#',$_.Pass 
                                                $Arguments= $Arguments -replace "#GpuPlatform#",$GpuPlatform
                                                
                                                if ($MiningMode -eq 'Automatic24h') {
                                                        $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price24h)}
                                                    else {
                                                        $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price)}

                                                $PoolAbbName=$_.Abbname
                                                $PoolName = $_.name
                                                $PoolWorkers = $_.Poolworkers
                                                $MinerProfitDual = $null
                                                $PoolDual = $null
                                                

                                                if ($Miner.Dualmining) 
                                                    {
                                                    if ($MiningMode -eq 'Automatic24h')   {
                                                        $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price24h -Descending| Select-Object -First 1
                                                        $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price24h)
                                                         }   

                                                         else {
                                                                $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price24h -Descending| Select-Object -First 1
                                                                $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price24h)
                                                                }

                                                    $Arguments = $Arguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolDual.user -replace '#PASSWORDDUAL#',$PoolDual.Pass
                                                    $PoolAbbName += '|' + $PoolDual.Abbname
                                                    $PoolName += '|' + $PoolDual.name
                                                    if ($PoolDual.workers -ne $null) {$PoolWorkers += '|' + $PoolDual.workers}

                                                    $AlgoNameDual=$AlgoNameDual.toupper()
                                                    $PoolDual.Info=$PoolDual.Info.tolower()
                                                    }
                                                
                                                
                                                $Miners += [pscustomobject] @{  
                                                                    Algorithm = $AlgoName.toupper()
                                                                    AlgorithmDual = $AlgoNameDual
                                                                    Coin = $_.Info.tolower()
                                                                    CoinDual = $PoolDual.Info
                                                                    Name = $Minerfile.basename
                                                                    Types = $Miner.Types
                                                                    Path = $Miner.Path
                                                                    HashRate = $HashRateValue
                                                                    HashRateDual = $HashrateValueDual
                                                                    API = $Miner.API
                                                                    Port =$Miner.APIPort
                                                                    Wrap =$Miner.Wrap
                                                                    URI = $Miner.URI
                                                                    Arguments=$Arguments+' '+$Algo.PSObject.Properties.Value
                                                                    Profit=$MinerProfit
                                                                    ProfitDual=$MinerProfitDual
                                                                    PoolPrice=$_.Price
                                                                    PoolPriceDual=$PoolDual.Price
                                                                    PoolName = $PoolName
                                                                    PoolAbbName = $PoolAbbName
                                                                    PoolWorkers = $PoolWorkers
                                                                    DualMining = $Miner.Dualmining
                                                                    Username = $_.user
                                                                    WalletMode=$_.WalletMode
                                                                    Host =$_.Host
                                                                    ExtractionPath = $Miner.ExtractionPath

                                                                }
                            
                                            }                       
                                         }   #         
     
                            }            
                        }
                }            
        }
             

        

    #Launch download of miners    
    $Miners |
        where-object URI -ne $null | 
        where-object ExtractionPath -ne $null | 
        where-object Path -ne $null | 
        where-object URI -ne "" | 
        where-object ExtractionPath -ne "" | 
        where-object Path -ne "" | 
        Select-Object URI, ExtractionPath,Path -Unique | ForEach-Object {Start-Downloader -URI $_.URI  -ExtractionPath $_.ExtractionPath -Path $_.Path}
    

    
    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {"NO MINERS!" | Out-Host ; EXIT}


    #Update the active miners list which is alive for  all execution time
    $ActiveMiners | ForEach-Object {
                    #Search miner to update data
                
                     $Miner = $miners | Where-Object Name -eq $_.Name | 
                            Where-Object Coin -eq $_.Coin | 
                            Where-Object Algorithm -eq $_.Algorithm | 
                            Where-Object CoinDual -eq $_.CoinDual | 
                            Where-Object AlgorithmDual -eq $_.AlgorithmDual | 
                            Where-Object PoolAbbName -eq $_.PoolAbbName 

                    $_.Best = $false
                    $_.NeedBenchmark = $false
                    #Mark as cancelled if more than 3 fails and running less than 180 secs, if no other alternative option, try forerever

                    $TimeActive=($_.ActiveTime.Hours*3600)+($_.ActiveTime.Minutes*60)+$_.ActiveTime.Seconds
                    if (($_.FailedTimes -gt 3) -and ($TimeActive -lt 180) -and (($ActiveMiners | Measure-Object).count -gt 1)){
                            $_.IsValid=$False 
                            $_.Status='Cancelled'
                        }
                   
                    if (($Miner | Measure-Object).count -gt 1) {WRITE-HOST DUPLICATED ALGO $MINER.ALGORITHM ON $MINER.NAME;EXIT}                 

                    if ($Miner) {
                        $_.Types  = $Miner.Types
                        $_.Profit  = $Miner.Profit
                        $_.ProfitDual  = $Miner.ProfitDual
                        $_.Profits = if ($Miner.AlgorithmDual -ne $null) {$Miner.ProfitDual+$Miner.Profit} else {$Miner.Profit}
                        $_.HashRate  = [double]$Miner.HashRate
                        $_.HashRateDual  = [double]$Miner.HashRateDual
                        $_.Hashrates   = if ($Miner.AlgorithmDual -ne $null) {(ConvertTo-Hash ($Miner.HashRate)) + "/s|"+(ConvertTo-Hash $Miner.HashRateDual) + "/s"} else {(ConvertTo-Hash $Miner.HashRate) +"/s"}
                        $_.PoolWorkers = $Miner.PoolWorkers
                        if ($_.Status -ne 'Cancelled') {$_.IsValid=$true} 
                    
                            }
                    else {
                            $_.IsValid=$false #simulates a delete
                            }
                
                }


    ##Add new miners to list
    $Miners | ForEach-Object {
                
                    $ActiveMiner = $ActiveMiners | Where-Object Name -eq $_.Name | 
                            Where-Object Coin -eq $_.Coin | 
                            Where-Object Algorithm -eq $_.Algorithm | 
                            Where-Object CoinDual -eq $_.CoinDual | 
                            Where-Object AlgorithmDual -eq $_.AlgorithmDual | 
                            Where-Object PoolAbbName -eq $_.PoolAbbName 

                
                    if ($ActiveMiner -eq $null) {
                        $ActiveMiners += [PSCustomObject]@{
                            Id                   = $ActiveMinersIdCounter
                            Algorithm            = $_.Algorithm
                            AlgorithmDual        = $_.AlgorithmDual
                            Name                 = $_.Name
                            Coin                 = $_.coin
                            CoinDual             = $_.CoinDual
                            Path                 = Convert-Path $_.Path
                            Arguments            = $_.Arguments
                            Wrap                 = $_.Wrap
                            API                  = $_.API
                            Port                 = $_.Port
                            Types                = $_.Types
                            Profit               = $_.Profit
                            ProfitDual           = $_.ProfitDual
                            Profits              = if ($_.AlgorithmDual -ne $null) {$_.ProfitDual+$_.Profit} else {$_.Profit}
                            HashRate             = [double]$_.HashRate
                            HashRateDual         = [double]$_.HashRateDual
                            Hashrates            = if ($_.AlgorithmDual -ne $null) {(ConvertTo-Hash ($_.HashRate)) + "/s|"+(ConvertTo-Hash $_.HashRateDual) + "/s"} else {(ConvertTo-Hash ($_.HashRate)) +"/s"}
                            PoolAbbName          = $_.PoolAbbName
                            SpeedLive            = 0
                            SpeedLiveDual        = 0
                            HashrateTotal        = 0
                            HashrateTicks        = 0
                            HashrateDualTotal    = 0
                            HashrateDualTicks    = 0
                            Best                 = $false
                            Process              = $null
                            NewThisRoud          = $True
                            ActiveTime           = [TimeSpan]0
                            LastActiveCheck      = [TimeSpan]0
                            ActivatedTimes       = 0
                            FailedTimes          = 0
                            Status               = ""
                            BenchmarkedTimes     = 0
                            NeedBenchmark        = $false
                            IsValid              = $true
                            PoolWorkers          = $_.PoolWorkers
                            DualMining           = $_.DualMining
                            PoolName             = $_.PoolName
                            Username             = $_.Username
                            WalletMode           = $_.WalletMode
                            Host                 = $_.Host

                        }
                        $ActiveMinersIdCounter++
                }
            }

    #update miners that need benchmarks
                                                
    $ActiveMiners | ForEach-Object {

        if ($_.BenchmarkedTimes -lt 4 -and $_.isvalid -and ($_.Hashrate -eq 0 -or ($_.AlgorithmDual -ne $null -and $_.HashrateDual -eq 0)))
            {$_.NeedBenchmark=$true} 
        }

    #For each type, select most profitable miner, not benchmarked has priority
    foreach ($Type in $Types) {

        $BestId=($ActiveMiners |Where-Object IsValid | select-object NeedBenchmark,Profits,Id,Types,Algorithm | where-object {(Compare-Object $Type $_.Types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0} | Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, {$_.Profits},Algorithm | Select-Object -First 1 | Select-Object id)
        $ActiveMiners[$BestId.PSObject.Properties.value].best=$true
        }



    #Stop miners running if they arent best now
    $ActiveMiners | Where-Object Best -EQ $false | ForEach-Object {
        if ($_.Process -eq $null) {
            $_.Status = "Failed"
        }
        elseif ($_.Process.HasExited -eq $false) {
            $_.Process.CloseMainWindow() | Out-Null
            $_.Status = "Idle"
        }
        
        try {$_.Process.CloseMainWindow() | Out-Null} catch {} #security closing
    }
   
    Start-Sleep 1 #Wait to prevent BSOD

    #Start all Miners marked as Best

    $ActiveMiners | Where-Object Best -EQ $true | ForEach-Object {
        if ($_.Process -eq $null -or $_.Process.HasExited -ne $false) {

            $_.ActivatedTimes++

            if ($_.Wrap) {$_.Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)'" -PassThru}
              else {$_.Process = Start-SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path)}
          
            if ($_.NeedBenchmark) {$NextInterval=$BechmarkintervalTime} #if one need benchmark next interval will be short

            if ($_.Process -eq $null) {
                    $_.Status = "Failed"
                    $_.FailedTimes++
                } 
            else {
                   $_.Status = "Running"
                   $_.LastActiveCheck=get-date
                   $_.HashrateTotal = 0
                   $_.HashrateTicks = 0
                   $_.HashrateDualTotal = 0
                   $_.HashrateDualTicks = 0
                }

            }
      
    }


      

         #Call api to local currency conversion
        try {
                $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing -TimeoutSec 2 | ConvertFrom-Json | Select-Object -ExpandProperty BPI
                Clear-Host
            } 
                
            catch {
                Clear-Host
                Write-Host COINDESK API NOT RESPONDING, NOT POSSIBLE LOCAL COIN CONVERSION
                }
     
                if ($Location -eq 'Europe') {$LabelProfit="EUR/Day"} else {$LabelProfit="USD/Day"}




    $FirstLoopExecution=$True   
    $IntervalStartTime=Get-Date
    $key=$null
    
    while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush

    #loop to update info and check if miner is running                        
    While (1 -eq 1) 
        {

        $ExitLoop = $false
        if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.BenchmarkedTimes++}
        Clear-host

        #display interval
        
        $TimetoNextInterval= NEW-TIMESPAN (Get-Date) ($IntervalStartTime.AddSeconds($NextInterval))
        $TimetoNextIntervalSeconds=($TimetoNextInterval.Hours*3600)+($TimetoNextInterval.Minutes*60)+$TimetoNextInterval.Seconds
        if ($TimetoNextIntervalSeconds -lt 0) {$TimetoNextIntervalSeconds = 0}

        Set-ConsolePosition 93 1
        write-Host Next Interval:  $TimetoNextIntervalSeconds secs
        Set-ConsolePosition 0 0

        #display header        
        "-----------------------------------------------------------------------------------------------------------------------"| write-host
        "  (E)nd Interval   (P)rofits    (C)urrent    (H)istory    (W)allets                       |" | write-host
        "-----------------------------------------------------------------------------------------------------------------------"| write-host
        "" | write-host
      

        
        #display current mining info

      

        "------------------------------------------------ACTIVE MINERS----------------------------------------------------------"| write-host
  
          $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
              @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive))+'s'} else {(ConvertTo-Hash  ($_.SpeedLive))+'/s|'+(ConvertTo-Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'},     
              @{Label = "BTC/Day"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Profits.tostring("n5")}}; Align = 'right'}, 
              @{Label = $LabelProfit; Expression = { if ($Location -eq 'Europe') {([double]$_.Profits * [double]$CDKResponse.eur.rate).tostring("n2") } else {(([double]$_.Profit + [double]$_.ProfitDual) * [double]$CDKResponse.usd.rate).tostring("n3")}}; Align = 'right'},
              @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
              @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.coin)+ '|' + ($_.CoinDual)}}},   
              @{Label = "Miner"; Expression = {$_.Name}}, 
              @{Label = "Pool"; Expression = {$_.PoolAbbName}},
              #@{Label = "Host"; Expression = {$_.Host}},
              #@{Label = "Port"; Expression = {$_.Port}},
              @{Label = "PoolWorkers"; Expression = {$_.PoolWorkers}}
          ) | Out-Host
          


        #display profits screen
        if ($Screen -eq "Profits") {

                    "--------------------------------------------------PROFITS------------------------------------------------------------"| write-host            


                    $XToWrite=[ref]0
                    $YToWrite=[ref]0      
                    Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)  
                    Set-ConsolePosition 95 $YToWrite
                    
                    "(T)oggle All / Top 40" | Write-host 

                    
                    
                    #Display profits  information
                    $ActiveMiners | Where-Object IsValid | Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, {$_.Profits} | select-object -first $ProfitsScreenLimit | Format-Table -AutoSize -GroupBy Type (
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.coin)+ '|' + ($_.CoinDual)}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "Speed"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Hashrates}}}, 
                        @{Label = "BTC/Day"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Profits.tostring("n5")}}; Align = 'right'}, 
                        @{Label = $LabelProfit; Expression = { if ($Location -eq 'Europe') {([double]$_.Profits * [double]$CDKResponse.eur.rate).tostring("n2") } else {(([double]$_.Profit + [double]$_.ProfitDual) * [double]$CDKResponse.usd.rate).tostring("n3")}}; Align = 'right'},
                        #@{Label = "BTC/GH/Day"; Expression = {$_.Pools.PSObject.Properties.Value.Price | ForEach-Object {($_ * 1000000000).ToString("N5")}}; Align = 'right'}
                        @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                        @{Label = "PoolWorkers"; Expression = {$_.PoolWorkers}}
                    ) | Out-Host
                }
    
                          
        if ($Screen -eq "Current") {
                    
                    "----------------------------------------------------CURRENT------------------------------------------------------------"| write-host            
            
                    #Display profits  information
                    $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
                        @{Label = "Pool"; Expression = {$_.PoolAbb}},
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                    
                    #Nvidia SMI-info
                    if ((Compare-Object "NVIDIA" $types -IncludeEqual -ExcludeDifferent | Measure-Object).Count -gt 0) {
                                $NvidiaCards=@()
                                invoke-expression "./nvidia-smi.exe --query-gpu=gpu_name,driver_version,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit --format=csv,noheader"  | foreach {
                            
                                        $SMIresultSplit = $_ -split (",")
                                            $NvidiaCards +=[PSCustomObject]@{
                                                        gpu_name           = $SMIresultSplit[0]
                                                        driver_version     = $SMIresultSplit[1]
                                                        utilization_gpu    = $SMIresultSplit[2]
                                                        utilization_memory = $SMIresultSplit[3]
                                                        temperature_gpu    = $SMIresultSplit[4]
                                                        power_draw         = $SMIresultSplit[5]
                                                        power_limit        = $SMIresultSplit[6]
                                                    }
                                    }               


                                    $NvidiaCards | Format-Table -Wrap  (
                                        @{Label = "GPU"; Expression = {$_.gpu_name}},
                                        @{Label = "GPU%"; Expression = {$_.utilization_gpu}},   
                                        @{Label = "Mem%"; Expression = {$_.utilization_memory}}, 
                                        @{Label = "Temp"; Expression = {$_.temperature_gpu}}, 
                                        @{Label = "Power"; Expression = {$_.power_draw+" /"+$_.power_limit}}
                                    ) | Out-Host


                                }
                }
                                    
                
                    
        if ($Screen -eq "Wallets") {         
            "----------------------------------------------------WALLETS (slow)-----------------------------------------------------"| write-host   

                    $XToWrite=[ref]0
                    $YToWrite=[ref]0      
                    Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)  
                    Set-ConsolePosition 85 $YToWrite
                    
                    "(U)pdate  - $WalletsUpdate  " | Write-host 



                    if (($WalletStatus | Measure-Object).count -eq 0) { #wallets only refresh one time each interval, not each loop iteration

                            $WalletsUpdate=get-date

                            $WalletsToCheck=@()
                            
                            $WalletsToCheck += $Pools  | where-object WalletMode -eq 'WALLET' | Select-Object PoolName,User,WalletMode -unique | Sort-Object Poolname
                            $WalletsToCheck += $Pools  | where-object WalletMode -eq 'APIKEY' | Select-Object PoolName,Algorithm,info,OriginalAlgorithm,OriginalCoin,Host,Symbol,WalletMode  -unique  | Sort-Object Poolname,info,Algorithm


                            $WalletStatus=@()
                            $WalletsToCheck |ForEach-Object {
                                        
                                        if ($_.WalletMode -eq "APIKEY") {
                                            $ApiKeyPattern='@@APIKEY_'+$_.PoolName+'=*'
                                            $ApiKey=(Get-Content config.txt | Where-Object {$_ -like $ApiKeyPattern} )-replace $ApiKeyPattern,''
                                            if (($ApiKey |Measure-Object).count -eq 0) {"NOT API KEY AVAILABLE ON CONFIG.TXT FOR POOL "+$_.PoolName|Write-Output;break}
                                            $Querymode = 'WALLET_'+$_.Host+'_'+$_.OriginalCoin+'_'+$ApiKey+'_'+$_.OriginalAlgorithm+'_'+$_.symbol
                                            Set-ConsolePosition $XToWrite $YToWrite
                                            "                                                                         "| Write-host 
                                            Set-ConsolePosition $XToWrite $YToWrite
                                            "Checking "+$_.PoolName+" - "+$_.info+' ('+$_.Algorithm+')' | Write-host 
                                            } 

                                        if ($_.WalletMode -eq "WALLET") {
                                            $Querymode="Wallet_"+$_.User
                                            Set-ConsolePosition $XToWrite $YToWrite
                                            "                                                                         "| Write-host 
                                            Set-ConsolePosition $XToWrite $YToWrite
                                             "Checking "+$_.PoolName+" - "+$_.User | Write-host
                                            }
                                        

                                        $Ws = Get-Pools -Querymode $Querymode -PoolsFilterList $_.Poolname
                                        
                                        if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                                        else  {$Ws | Add-Member Wallet $_.Info}

                                        $Ws | Add-Member PoolName $_.Poolname
                                        
                                        $WalletStatus += $Ws

                                        start-sleep 1 #no saturation of pool api
                                        "                                                                         "| Write-host     
                                     }


                                }



                        $WalletStatus | where-object Balance -gt 0 | Format-Table -Wrap -groupby poolname (
                            @{Label = "Wallet"; Expression = {$_.wallet}}, 
                            @{Label = "Currency"; Expression = {$_.currency}}, 
                            @{Label = "Balance"; Expression = {$_.balance}}
                        ) | Out-Host
                

                        $Pools  | where-object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                            "NO EXISTS API FOR POOL "+$_.PoolName+" - NO WALLETS CHECK" | Write-host 
                            }                        
                            
                        }

                
        if ($Screen -eq "History") {                        

                    "--------------------------------------------------HISTORY------------------------------------------------------------"| write-host            

                    #Display activated miners list
                    $ActiveMiners | Where-Object ActivatedTimes -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
                        @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive))+'s'} else {(ConvertTo-Hash  ($_.SpeedLive))+'/s|'+(ConvertTo-Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'}, 
                        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.ActiveTime}}, 
                        @{Label = "Launched"; Expression = {Switch ($_.ActivatedTimes) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                }

  
                 
                   

                $ActiveMiners | Where-Object Best -eq $true | ForEach-Object {
                                $_.SpeedLive = 0
                                $_.SpeedLiveDual = 0
                                $Miner_HashRates = $null

                                


                                if ($_.Process -eq $null -or $_.Process.HasExited) {
                                        if ($_.Status -eq "Running") {
                                                    $_.Status = "Failed"
                                                    $_.FailedTimes++
                                                    $ExitLoop = $true
                                                    }
                                        else
                                            { $ExitLoop = $true}         
                                        }

                                else {
                                        $_.ActiveTime += (get-date) - $_.LastActiveCheck 
                                        $_.LastActiveCheck=get-date

                                        $Miner_HashRates = Get-Live-HashRate $_.API $_.Port 

                                        if ($Miner_HashRates -ne $null){
											$_.SpeedLive = [double]($Miner_HashRates[0])
                                            $Hashrate = [double]($Miner_HashRates[0] * 0.95)

                                            if ($Hashrate -gt 0) {
												$ConsecutiveZeroSpeed = 0
											
												$_.HashrateTotal += $Hashrate;
												$_.HashrateTicks++
												
												
												if ($_.DualMining) {     
													$_.SpeedLiveDual = [double]($Miner_HashRates[1])
													$HashrateDual = [double]($Miner_HashRates[1] * 0.95)
													
													if ($HashrateDual -gt 0) {
														$_.HashrateDualTotal += $HashrateDual;
														$_.HashrateDualTicks++
														
														if ($_.NeedBenchmark) {
															$_.Hashrate = $Hashrate
															$HashrateAvg = $_.HashrateTotal / $_.HashrateTicks
															Set-Hashrate -algorithm $_.Algorithm -minername $_.Name -value  $HashrateAvg
															
															$_.HashrateDual = $HashrateDual
															$HashrateDualAvg  = $_.HashrateDualTotal / $_.HashrateDualTicks
															Set-Hashrate -algorithm $_.AlgorithmDual -minername $_.Name -value $HashrateDualAvg
														}
													}
												} else {
													if ($_.NeedBenchmark) {
														$_.Hashrate= $Hashrate
														$HashrateAvg = $_.HashrateTotal / $_.HashrateTicks
														Set-Hashrate -algorithm $_.Algorithm -minername $_.Name -value  $_.HashrateAvg
													}
												}												
											} else {
												$ConsecutiveZeroSpeed++
											}
                                        }        
                                    }
                                
                                        
                                #Benchmark timeout
                                if ($_.BenchmarketTimes -ge 3) {
                                    for ($i = $Miner_HashRates.Count; $i -lt $_.Algorithm.Count; $i++) {
                                        if ((Get-Stat "$($_.Name)_$($_.Algorithm | Select-Object -Index $i)_HashRate") -eq $null) {
                                            $Stat = Set-Stat -Name "$($_.Name)_$($_.Algorithm | Select-Object -Index $i)_HashRate" -Value 0
                                        }
                                    }
                                $ExitLoop = $true
                                }

                        }

                    
            
           


                $FirstLoopExecution=$False
                

                #Loop for reading key and wait
                $Loopstart=get-date 
                $KeyPressed=$null    

             
                while ((NEW-TIMESPAN $Loopstart (get-date)).Seconds -lt 4 -and $KeyPressed -ne 'P'-and $KeyPressed -ne 'C'-and $KeyPressed -ne 'H'-and $KeyPressedkey -ne 'E' -and $KeyPressedkey -ne 'W'  -and $KeyPressedkey -ne 'U'  -and $KeyPressedkey -ne 'T'){
                            
                            if ($host.ui.RawUi.KeyAvailable) {
                                        $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
                                        $KeyPressed=$Key.character
                                        while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush
                                        
                                        }
                       }  
                
                switch ($KeyPressed){
                    'P' {$Screen='profits'}
                    'C' {$Screen='current'}
                    'H' {$Screen='history'}
                    'E' {$ExitLoop=$true}
                    'W' {$Screen='Wallets'}
                    'U' {if ($Screen -eq "Wallets") {$WalletStatus=$null}}
                    'T' {if ($Screen -eq "Profits") {if ($ProfitsScreenLimit -eq 40) {$ProfitsScreenLimit=1000} else {$ProfitsScreenLimit=40}}}
                    
                }


                if ($ConsecutiveZeroSpeed -gt 10) { #to prevent miner hangs
                        $ExitLoop='true'
                        $_.FailedTimes++
                        $_.Status='Failed'
                        }

                if (((Get-Date) -ge ($IntervalStartTime.AddSeconds($NextInterval))) -or ($ExitLoop)  ) {break} #If time of interval has over, exit of main loop
                
    
        }
     
    [GC]::Collect() #force garbage recollector for free memory
   


}

#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of alwais running loop--------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------



#Stop the log
Stop-Transcript
