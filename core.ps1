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
#$MiningMode='Manual'

#$PoolsName=('zpool','mining_pool_hub')
#$PoolsName='nicehash'
#$PoolsName='yiimp'
#$PoolsName=('hash_refinery','yiimp')
#$PoolsName='mining_pool_hub'
#$PoolsName='zpool'
#$PoolsName='Suprnova'

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

#Update stats with missing data and set to today's date/time
if (Test-Path "Stats") {Get-ChildItemContent "Stats" | ForEach-Object {Set-Stat $_.Name $_.Content.Live | Out-Null}}

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
$BechmarkintervalTime=200

Clear-Host


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

    #Load the Stats
    $Stats = [PSCustomObject]@{}
    if (Test-Path "Stats") {Get-ChildItemContent "Stats" | ForEach-Object {$Stats | Add-Member $_.Name $_.Content}}



    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin

     do
        {
        $Pools=Get-Pools -Querymode "core" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm
        if  ($Pools.Count -eq 0) {"NO POOLS!....retry in 10 sec" | Out-Host;Start-Sleep 10}
        }
    while ($Pools.Count -eq 0) 
    
    


    #Load information about the Miner asociated to each Coin-Algo-Miner

    $Miners= @()
    $Hashrates= @()
   


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



                            if (($Stats | Get-Member |Where-Object  name -eq ($Minerfile.basename+'_'+ $AlgoName +'_Hashrate')) -ne $null)
                                {$HashrateValue=[double]($Stats | Select-Object -Expand ($Minerfile.basename+'_'+ $AlgoName +'_Hashrate')  | Select-Object  -Expand  Live)}
                            else 
                                {$HashrateValue = $null}



                             ##for dual mining add second hashrate
                            if ($Miner.Dualmining -eq $true) 
                                {
                                    if (($Stats | Get-Member |Where-Object  name -eq ($Minerfile.basename+'_'+ $AlgoNameDual +'_Hashrate')) -ne $null)
                                        {$HashrateValueDual=[double]($Stats | Select-Object -Expand ($Minerfile.basename+'_'+ $AlgoNameDual +'_Hashrate')  | Select-Object  -Expand  Live)}
                                    else 
                                        {$HashrateValuedual = $null}
                                    
                                }

                            #Only want algos pools has  

                                $Pools | where-object Algorithm -eq $AlgoName | ForEach-Object {
                                    
                                        if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne  $null) -or ($Miner.Dualmining -eq $false)){

                                           if ($_.info -eq $Miner.DualMiningMainCoin -or $Miner.Dualmining -eq $false) {  #not allow dualmining if main coin not coincide
                                           
                                                $Arguments = $Miner.Arguments  -replace '#PORT#',$_.Port -replace '#SERVER#',$_.Host -replace '#PROTOCOL#',$_.Protocol -replace '#LOGIN#',$_.user -replace '#PASSWORD#',$_.Pass 
                                                $Arguments= $Arguments -replace "#GpuPlatform#",$GpuPlatform
                                                
                                                $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price)

                                                $PoolAbbName=$_.Abbname
                                                $PoolName = $_.name
                                                $PoolWorkers = $_.Poolworkers
                                                $MinerProfitDual = $null
                                                $PoolDual = $null

                                                

                                                if ($Miner.Dualmining) 
                                                    {
                                                    $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price -Descending| Select-Object -First 1
                                                    $Arguments = $Arguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolDual.user -replace '#PASSWORDDUAL#',$PoolDual.Pass
                                                    $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price)
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

                                                                }
                            
                                            }                       
                                         }   #         
     
                            }            
                        }
                }            
        }
             
        

    #Launch download of miners    
    if (-not (Get-Job -State Running)) {
        Start-Job -InitializationScript ([scriptblock]::Create("Set-Location('$(Get-Location)')")) -ArgumentList ($Miners | Select-Object URI, Path, @{name = "Searchable"; expression = {$Miner = $_; ($Miners | Where-Object {(Split-Path $_.Path -Leaf) -eq (Split-Path $Miner.Path -Leaf) -and $_.URI -ne $Miner.URI}).Count -eq 0}} -Unique) -FilePath .\Downloader.ps1 | Out-Null
        while (Get-Job -State Running) {}
        }

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


        
        #Display profits  information
        $ActiveMiners | Where-Object IsValid | Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, {$_.Profits} | Format-Table -AutoSize -GroupBy Type (
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
        
    
    $XToWrite=[ref]0
    $YToWrite=[ref]0      
    $FirstLoopExecution=$True   
    $IntervalStartTime=Get-Date


    #loop to update info and check if miner is running                        
    While (1 -eq 1) 
        {

                    if ($FirstLoopExecution) {
                            Get-ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)
                            
                            if ($_.NeedBenchmark) {$_.BenchmarkedTimes++}
                            } 
                        else{
                            Set-ConsolePosition $XToWrite $YToWrite
                            
                            }                    

                    $ExitLoop = $false
                    $TimetoNextInterval= NEW-TIMESPAN (Get-Date) ($IntervalStartTime.AddSeconds($NextInterval))
                    $TimetoNextIntervalSeconds=($TimetoNextInterval.Hours*3600)+($TimetoNextInterval.Minutes*60)+$TimetoNextInterval.Seconds
                    if ($TimetoNextIntervalSeconds -lt 0) {$TimetoNextIntervalSeconds = 0}

                    write-Host Time to next profit check:  $TimetoNextIntervalSeconds seconds..............................
                            
                    

                    #Display activated miners list
                    $ActiveMiners | Where-Object ActivatedTimes -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
                        @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo-Hash  ($_.SpeedLive))+'s'} else {(ConvertTo-Hash  ($_.SpeedLive))+'/s|'+(ConvertTo-Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'}, 
                        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.ActiveTime}}, 
                        @{Label = "Launched"; Expression = {Switch ($_.ActivatedTimes) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                

  
                 
                   

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

                                            $Miner_HashRates = Get-HashRate $_.API $_.Port 

                                            if ($Miner_HashRates -ne $null){
                                                $_.SpeedLive = $Miner_HashRates[0]
                                                if ($Miner_HashRates[0] -gt $_.Hashrate) {
                                                        $_.Hashrate=[double]([double]$Miner_HashRates[0] * 0.95)
                                                        $File=$_.Name+'_'+$_.Algorithm+'_hashrate'
                                                        $Stat = Set-Stat -Name $File  -Value  $_.Hashrate
                                                        }
                                                
                                                    
                                                if ($_.DualMining){     
                                                    $_.SpeedLiveDual = $Miner_HashRates[1] 
                                                    if ($Miner_HashRates[1] -gt $_.HashrateDual) {
                                                            $_.HashrateDual=[double]([double]$Miner_HashRates[1] * 0.95)
                                                            $File=$_.Name+'_'+$_.AlgorithmDual+'_hashrate'
                                                            $Stat = Set-Stat -Name $File  -Value  $_.HashrateDual
                                                            }
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

                    
                    #If time of interval has over, exit of loop
                  
                    if (((Get-Date) -ge ($IntervalStartTime.AddSeconds($NextInterval))) -or ($ExitLoop) ) {break}
                    
                    #Adjust screen heigh to content     
                    $Xsize=[ref]0
                    $Ysize=[ref]0
                    Get-ConsolePosition ([ref]$Xsize) ([ref]$Ysize)     

                    if ($Ysize -gt ((get-host).UI.RawUI.MaxWindowSize.Height)-5) {$Ysize=(get-host).UI.RawUI.MaxWindowSize.Height-5}
                    set-WindowSize 0 ($Ysize)     
                    #Set-ConsolePosition 0 0
                 
                    $FirstLoopExecution=$False
                    
                    #wait for next iteration
                    Start-Sleep (5)  
        


        }
            
   


}

#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of alwais running loop--------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------



#Stop the log
Stop-Transcript