#using module .\Include.psm1

param(
    [Parameter(Mandatory = $false)]
    [Array]$Algorithm = $null,

    [Parameter(Mandatory = $false)]
    [Array]$PoolsName = $null,

    [Parameter(Mandatory = $false)]
    [array]$CoinsName= $null,

    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null,

    [Parameter(Mandatory = $false)]
    [array]$Groupnames = $null,

    [Parameter(Mandatory = $false)]
    [string]$PercentToSwitch = $null


)



. .\Include.ps1

##Parameters for testing, must be commented on real use

#$MiningMode='Automatic'
#$MiningMode='Automatic24h'
#$MiningMode='Manual'

#$PoolsName=('ahashpool','mining_pool_hub','hash_refinery')
#$PoolsName='whattomine_virtual'
#$PoolsName='yiimp'
#$PoolsName='nanopool'
#$PoolsName=('hash_refinery','zpool')
#$PoolsName='mining_pool_hub'
#$PoolsName='zpool'
#$PoolsName='hash_refinery'
#$PoolsName='ahashpool'
#$PoolsName='suprnova'

#$PoolsName="Nicehash"

#$Coinsname =('bitcore','Signatum','Zcash')
#$Coinsname ='bitcoingold'
#$Algorithm =('x11')

#$Groupnames=('rx580')



$ErrorActionPreference = "Continue"
if ($Groupnames -eq $null) {$Host.UI.RawUI.WindowTitle = "MegaMiner"} else {$Host.UI.RawUI.WindowTitle = "MM-" + ($Groupnames -join "/")}
$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' #This align cuda id with nvidia-smi order

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File
try {if ((Get-MpPreference).ExclusionPath -notcontains (Convert-Path .)) {Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}}catch {}




#Start log file
    Clear_log
    $LogFile=".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"
    Start-Transcript $LogFile #for start log msg
    Stop-Transcript
    writelog ( get_gpu_information |ConvertTo-Json) $logfile $false
    

 
    


$ActiveMiners = @()
$ActiveMinersIdCounter=0
$Activeminers=@()
$ShowBestMinersOnly=$true
$FirstTotalExecution =$true
$StartTime=get-date




$Screen = get_config_variable "STARTSCREEN"
  


#---Paraneters checking

if ($MiningMode -ne 'Automatic' -and $MiningMode -ne 'Manual' -and $MiningMode -ne 'Automatic24h'){
    "Parameter MiningMode not valid, valid options: Manual, Automatic, Automatic24h" |Out-host
    EXIT
   }


   
$PoolsChecking=Get_Pools -Querymode "info" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $location -AlgoFilterList $Algorithm   

$PoolsErrors=@()
switch ($MiningMode){
    "Automatic"{$PoolsErrors =$PoolsChecking |Where-Object ActiveOnAutomaticMode -eq $false}
    "Automatic24h"{$PoolsErrors =$PoolsChecking |Where-Object ActiveOnAutomatic24hMode -eq $false}
    "Manual"{$PoolsErrors =$PoolsChecking |Where-Object ActiveOnManualMode -eq $false }
    }


$PoolsErrors |ForEach-Object {
    "Selected MiningMode is not valid for pool "+$_.name |Out-host
    EXIT
}



if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -gt 1){
    "On manual mode only one coin must be selected" |Out-host
    EXIT
   }


if ($MiningMode -eq 'Manual' -and ($Coinsname | Measure-Object).count -eq 0){
    "On manual mode must select one coin" |Out-host
    EXIT
   }   
 
if ($MiningMode -eq 'Manual' -and ($Algorithm | measure-object).count -gt 1){
    "On manual mode only one algorithm must be selected" |Out-host
    EXIT
   }
    

#parameters backup

    $ParamAlgorithmBCK=$Algorithm
    $ParamPoolsNameBCK=$PoolsName
    $ParamCoinsNameBCK=$CoinsName
    $ParamMiningModeBCK=$MiningMode


set_WindowSize 120 60 
    
$IntervalStartAt = (Get-Date) #first inicialization, must be outside loop


ErrorsToLog $LogFile


$Msg="Starting Parameters: "   
$Msg+=" //Algorithm: "+[String]($Algorithm -join ",") 
$Msg+=" //PoolsName: "+[String]($PoolsName -join ",") 
$Msg+=" //CoinsName: "+[String]($CoinsName -join ",") 
$Msg+=" //MiningMode: "+$MiningMode
$Msg+=" //Groupnames: "+[String]($Groupnames -join ",") 
$Msg+=" //PercentToSwitch: "+$PercentToSwitch

WriteLog $msg $LogFile $False

 


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

    Clear-Host;$repaintScreen=$true

    WriteLog "New interval starting............." $LogFile $True
    Writelog ( Get_ComputerStats |ConvertTo-Json) $logfile $false

    $Location=get_config_variable "LOCATION"


    if ($PercentToSwitch -eq "") {$PercentToSwitch2 = [int](get_config_variable "PERCENTTOSWITCH")} else {$PercentToSwitch2=[int]$PercentToSwitch}
    $DelayCloseMiners=get_config_variable "DELAYCLOSEMINERS"
    
    $Types=Get_Mining_Types -filter $Groupnames
    
    $NumberTypesGroups=($Types | Measure-Object).count
    if ($NumberTypesGroups -gt 0) {$InitialProfitsScreenLimit=[Math]::Floor( 25 /$NumberTypesGroups)} #screen adjust to number of groups
    if ($FirstTotalExecution) {$ProfitsScreenLimit=$InitialProfitsScreenLimit}
                         

    $Currency= get_config_variable "CURRENCY"
    $BechmarkintervalTime=[int](get_config_variable "BENCHMARKTIME" )
    $LocalCurrency= get_config_variable "LOCALCURRENCY"
    if ($LocalCurrency.length -eq 0) { #for old config.txt compatibility
        switch ($location) {
            'Europe' {$LocalCurrency="EURO"}
            'US'     {$LocalCurrency="DOLLAR"}
            'ASIA'   {$LocalCurrency="DOLLAR"}
            'GB'     {$LocalCurrency="GBP"}
            default {$LocalCurrency="DOLLAR"}
            }
        }
    

    #Donation
    $LastIntervalTime= (get-date) - $IntervalStartAt
    $IntervalStartAt = (Get-Date)
    $DonationPastTime= (Get-Content Donation.ctr)
    If ($DonationPastTime -eq $null -or $DonationPastTime -eq "" ) {$DonationPastTime=0}
    $ElapsedDonationTime = [int]($DonationPastTime) + $LastIntervalTime.minutes + ($LastIntervalTime.hours *60)

    
    $Dt= [int](get_config_variable "DONATE")
    $DonateTime=if ($Dt -gt 0) {[int]$Dt} else {0}
    #Activate or deactivate donation
    if ($ElapsedDonationTime -gt 1440 -and $DonateTime -gt 0) { # donation interval

                $DonationInterval = $true
                $UserName = "tutulino"
                $WorkerName = "Megaminer"
                $CoinsWallets=@{} 
                $CoinsWallets.add("BTC","1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TM")

                $NextInterval=$DonateTime *60

                $Algorithm=$null
                $PoolsName="DonationPool"
                $CoinsName=$null
                $MiningMode="Automatic"

                0 | Set-Content  -Path Donation.ctr

                WriteLog "Next "+[string]($DonateTime)+" minutes will be donation" $LogFile $True

            }
            else { #NOT donation interval
                    $DonationInterval = $false
                    $NextInterval=get_config_variable "INTERVAL"

                    $Algorithm=$ParamAlgorithmBCK
                    $PoolsName=$ParamPoolsNameBCK
                    $CoinsName=$ParamCoinsNameBCK
                    $MiningMode=$ParamMiningModeBCK
                    $UserName= get_config_variable "USERNAME"
                    $WorkerName= get_config_variable "WORKERNAME"
                    $CoinsWallets=@{} 
                    ((Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','').TrimEnd() | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}
                
                    $ElapsedDonationTime | Set-Content  -Path Donation.ctr

                 }
        

    $Rates = [pscustomObject]@{}
    try { $Currency | ForEach-Object {$Rates | Add-Member $_ (Invoke-WebRequest "https://api.cryptonator.com/api/ticker/btc-$_" -UseBasicParsing | ConvertFrom-Json).ticker.price}} catch {}

    ErrorsToLog $LogFile


    WriteLog "Loading Pools Information............." $LogFile $True

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
     do
        {
        $Pools=Get_Pools -Querymode "core" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $Location -AlgoFilterList $Algorithm
        if  ($Pools.Count -eq 0) {
                $Msg="NO POOLS!....retry in 10 sec"+'/n'
                $Msg+="REMEMBER, IF YOUR ARE MINING ON ANONYMOUS WITHOUT AUTOEXCHANGE POOLS LIKE YIIMP, NANOPOOL, ETC. YOU MUST SET WALLET FOR AT LEAST ONE POOL COIN IN CONFIG.TXT"
                WriteLog $msg $logFile $true
                
                Start-Sleep 10}
        }
    while ($Pools.Count -eq 0) 
    
    $Pools | Select-Object name -unique | foreach-object {Writelog ("Pool "+$_.name+" was responsive....") $logfile $true}

    #Load information about the Miner asociated to each Coin-Algo-Miner

    $Miners= @()

    foreach ($MinerFile in (Get-ChildItem "Miners" | Where-Object extension -eq '.json'))  
        {
            try { $Miner =$MinerFile | Get-Content | ConvertFrom-Json } 
            catch 
                {  Writelog "-------BAD FORMED JSON: $MinerFile" $LogFile $true
                Exit}
 
   
                    foreach ($Algo in ($Miner.Algorithms))
                        {
                            $HashrateValue= 0
                            $HashrateValueDual=0
                            $Hrs=$null

                            ##Algoname contains real name for dual and no dual miners
                            $AlgoName =  (($Algo.PSObject.Properties.Name -split ("_"))[0]).toupper().trimend()
                            $AlgoNameDual = (($Algo.PSObject.Properties.Name -split ("_"))[1])
                            if ($AlgoNameDual -ne $null) {$AlgoNameDual=$AlgoNameDual.toupper()}
                            $AlgoLabel = ($Algo.PSObject.Properties.Name -split ("_"))[2]
                            if ($AlgoNameDual -eq $null) {$Algorithms=$AlgoName} else {$Algorithms=$AlgoName+"_"+$AlgoNameDual}
                          

                                 
                            #generate pools for each gpu group
                            ForEach ( $TypeGroup in $types) {
                             
                              if  ((Compare-object $TypeGroup.type $Miner.Types -IncludeEqual -ExcludeDifferent | Measure-Object).count -gt 0) { #check group and miner types are the same
                                $Pools | where-object Algorithm -eq $AlgoName | ForEach-Object {   #Search pools for that algo
                                    
                                        if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne  $null) -or ($Miner.Dualmining -eq $false)){
                                           $DualMiningMainCoin=$Miner.DualMiningMainCoin -replace $null,""
                                           if (((Compare-object $_.info $DualMiningMainCoin -IncludeEqual -ExcludeDifferent | Measure-Object).count -gt 0) -or $Miner.Dualmining -eq $false) {  #not allow dualmining if main coin not coincide

                                            $Hrs = Get_Hashrates -minername $Minerfile.basename -algorithm $Algorithms -GroupName $TypeGroup.GroupName -AlgoLabel  $AlgoLabel
                                            
                                            $HashrateValue=[long]($Hrs -split ("_"))[0]
                                            $HashrateValueDual=[long]($Hrs -split ("_"))[1]                                            

                                            

                                            if (($Types | Measure-Object).Count -gt 1) {$WorkerName2=$WorkerName+'_'+$TypeGroup.GroupName} else  {$WorkerName2=$WorkerName} 


                                             $Arguments = $Miner.Arguments  -replace '#PORT#',$_.Port -replace '#SERVER#',$_.Host -replace '#PROTOCOL#',$_.Protocol -replace '#LOGIN#',$_.user -replace '#PASSWORD#',$_.Pass -replace "#GpuPlatform#",$TypeGroup.GpuPlatform  -replace '#ALGORITHM#',$Algoname -replace '#ALGORITHMPARAMETERS#',$Algo.PSObject.Properties.Value -replace '#WORKERNAME#',$WorkerName2  -replace '#DEVICES#',$TypeGroup.Gpus   -replace '#DEVICESCLAYMODE#',$TypeGroup.GpusClayMode -replace '#DEVICESETHMODE#',$TypeGroup.GpusETHMode -replace '#GROUPNAME#',$TypeGroup.Groupname -replace "#ETHSTMODE#",$_.EthStMode -replace "#DEVICESNSGMODE#",$TypeGroup.GpusNsgMode                   
                                             if ($Miner.PatternConfigFile -ne $null) {
                                                            $ConfigFileArguments =  replace_foreach_gpu (get-content $Miner.PatternConfigFile -raw)  $TypeGroup.Gpus
                                                            $ConfigFileArguments = $ConfigFileArguments -replace '#PORT#',$_.Port -replace '#SERVER#',$_.Host -replace '#PROTOCOL#',$_.Protocol -replace '#LOGIN#',$_.user -replace '#PASSWORD#',$_.Pass -replace "#GpuPlatform#",$TypeGroup.GpuPlatform   -replace '#ALGORITHM#',$Algoname -replace '#ALGORITHMPARAMETERS#',$Algo.PSObject.Properties.Value -replace '#WORKERNAME#',$WorkerName2  -replace '#DEVICES#',$TypeGroup.Gpus -replace '#DEVICESCLAYMODE#',$TypeGroup.GpusClayMode  -replace '#DEVICESETHMODE#',$TypeGroup.GpusETHMode -replace '#GROUPNAME#',$TypeGroup.Groupname -replace "#ETHSTMODE#",$_.EthStMode -replace "#DEVICESNSGMODE#",$TypeGroup.GpusNsgMode                   
                                                        }

                                                        
                                                if ($MiningMode -eq 'Automatic24h') {
                                                        $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price24h)
                                                       
                                                        }
                                                    else {
                                                        $MinerProfit=[Double]([double]$HashrateValue * [double]$_.Price)}

                                                #apply fee to profit       
                                                if ([double]$Miner.Fee -gt 0) {$MinerProfit=$MinerProfit -($minerProfit*[double]$Miner.fee)}
                                                if ([double]$_.Fee -gt 0) {$MinerProfit=$MinerProfit -($minerProfit*[double]$_.fee)}

                                                $PoolAbbName=$_.Abbname
                                                $PoolName = $_.name
                                                if ($_.PoolWorkers -eq $null) {$PoolWorkers=""} else {$PoolWorkers=$_.Poolworkers.tostring()}
                                                $MinerProfitDual = $null
                                                $PoolDual = $null
                                                

                                                if ($Miner.Dualmining) 
                                                    {
                                                    if ($MiningMode -eq 'Automatic24h')   {
                                                        $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price24h -Descending| Select-Object -First 1
                                                        $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price24h)
                                                         }   

                                                         else {
                                                                $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price -Descending| Select-Object -First 1
                                                                $MinerProfitDual = [Double]([double]$HashrateValueDual * [double]$PoolDual.Price)
                                                                }

                                                     #apply fee to profit       
                                                     if ($Miner.Fee -gt 0) {$MinerProfitDual=$MinerProfitDual -($MinerProfitDual*[double]$Miner.fee)}             
                                                     if ($PoolDual.Fee -gt 0) {$MinerProfitDual=$MinerProfitDual -($MinerProfitDual*[double]$PoolDual.fee)}             

                                                    $Arguments = $Arguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolDual.user -replace '#PASSWORDDUAL#',$PoolDual.Pass  -replace '#ALGORITHMDUAL#',$AlgonameDual -replace '#WORKERNAME#',$WorkerName2 
                                                    if ($Miner.PatternConfigFile -ne $null) {
                                                                         $ConfigFileArguments = $ConfigFileArguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolDual.user -replace '#PASSWORDDUAL#',$PoolDual.Pass -replace '#ALGORITHMDUAL#' -replace '#WORKERNAME#',$WorkerName2 
                                                                        }

                                                    $PoolAbbName += '|' + $PoolDual.Abbname
                                                    $PoolName += '|' + $PoolDual.name
                                                    if ($PoolDual.Poolworkers -ne $null) {$PoolWorkers += '|' + $PoolDual.Poolworkers.tostring()}

                                                    $AlgoNameDual=$AlgoNameDual.toupper()
                                                    $PoolDual.Info=$PoolDual.Info.tolower()
                                                    }
                                                
                                                
                                                $Miners += [pscustomobject] @{  
                                                                    GroupName = $TypeGroup.GroupName
                                                                    GroupId = $TypeGroup.Id
                                                                    GroupType = $TypeGroup.Type
                                                                    Algorithm = $AlgoName
                                                                    AlgorithmDual = $AlgoNameDual
                                                                    Algorithms=$Algorithms
                                                                    AlgoLabel=$AlgoLabel
                                                                    Coin = $_.Info.tolower()
                                                                    CoinDual = $PoolDual.Info
                                                                    Symbol = $_.Symbol
                                                                    SymbolDual = $PoolDual.Symbol
                                                                    Name = $Minerfile.basename
                                                                    Path = $Miner.Path
                                                                    HashRate = $HashRateValue
                                                                    HashRateDual = $HashrateValueDual
                                                                    Hashrates   = if ($Miner.Dualmining) {(ConvertTo_Hash ($HashRateValue)) + "/s|"+(ConvertTo_Hash $HashrateValueDual) + "/s"} else {(ConvertTo_Hash $HashRateValue) +"/s"}
                                                                    API = $Miner.API
                                                                    Port = $miner.ApiPort
                                                                    Wrap =$Miner.Wrap
                                                                    URI = $Miner.URI
                                                                    Arguments=$Arguments
                                                                    Profit=$MinerProfit
                                                                    ProfitDual=$MinerProfitDual
                                                                    PoolPrice=if ($MiningMode -eq 'Automatic24h') {[double]$_.Price24h} else {[double]$_.Price}
                                                                    PoolPriceDual=if ($MiningMode -eq 'Automatic24h') {[double]$PoolDual.Price24h} else {[double]$PoolDual.Price}
                                                                    Profits  = if ($Miner.Dualmining) {$MinerProfitDual+$MinerProfit} else {$MinerProfit}
                                                                    PoolName = $PoolName
                                                                    PoolAbbName = $PoolAbbName
                                                                    PoolWorkers = $PoolWorkers
                                                                    DualMining = $Miner.Dualmining
                                                                    Username = $_.user
                                                                    WalletMode=$_.WalletMode
                                                                    WalletSymbol = $_.WalletSymbol
                                                                    Host =$_.Host
                                                                    ExtractionPath = $Miner.ExtractionPath
                                                                    GenerateConfigFile = $miner.GenerateConfigFile -replace '#GROUPNAME#',$TypeGroup.Groupname
                                                                    ConfigFileArguments = $ConfigFileArguments
                                                                    Location = $_.location
                                                                    PrelaunchCommand = $Miner.PrelaunchCommand
                                                                    MinerFee= if ($Miner.Fee -eq $null) {$null} else {[double]$Miner.fee}
                                                                    PoolFee = if ($_.Fee -eq $null) {$null} else {[double]$_.fee}
                                                                    

                                                                }
                            
                                            }                       
                                         }          
     
                            }  #end foreach pool
                        } #  end if types 
                            

                        }

                        }
               # }            
        }
             

    Writelog ("Miners detected: "+ [string]($Miners.count)+".........") $LogFile $true    
     
    #Launch download of miners    
    $Miners | where-object {$_.URI -ne $null -and $_.ExtractionPath -ne $null -and $_.Path -ne $null -and $_.URI -ne "" -and $_.ExtractionPath -ne "" -and $_.Path -ne ""} | Select-Object URI, ExtractionPath,Path -Unique | ForEach-Object {
                Start_Downloader -URI $_.URI  -ExtractionPath $_.ExtractionPath -Path $_.Path
            }
    
    ErrorsToLog $LogFile
    
    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {Writelog "NO MINERS!" $LogFile $true ; EXIT}


    #Update the active miners list which is alive for  all execution time
    $ActiveMiners | ForEach-Object {
                    #Search miner to update data
                
                     $Miner = $miners | Where-Object Name -eq $_.Name | 
                            Where-Object Coin -eq $_.Coin | 
                            Where-Object Algorithm -eq $_.Algorithm | 
                            Where-Object CoinDual -eq $_.CoinDual | 
                            Where-Object AlgorithmDual -eq $_.AlgorithmDual | 
                            Where-Object PoolAbbName -eq $_.PoolAbbName |
                            Where-Object Location -eq $_.Location |
                            Where-Object GroupId -eq $_.GroupId |
                            Where-Object AlgoLabel -eq $_.AlgoLabel


                            

                    $_.Best = $false
                    $_.NeedBenchmark = $false
                    $_.ConsecutiveZeroSpeed=0
                    if ($_.BenchmarkedTimes -ge 2 -and $_.AnyNonZeroSpeed -eq $false) {$_.Status='Cancelled'}
                    $_.AnyNonZeroSpeed  = $false

                    $TimeActive=($_.ActiveTime.Hours*3600)+($_.ActiveTime.Minutes*60)+$_.ActiveTime.Seconds
                    if (($_.FailedTimes -gt 3) -and ($TimeActive -lt 180) -and (($ActiveMiners | Measure-Object).count -gt 1)){$_.Status='Cancelled'} #Mark as cancelled if more than 3 fails and running less than 180 secs, if no other alternative option, try forerever

                   
                    if (($Miner | Measure-Object).count -gt 1) {
                            Clear-Host;$repaintScreen=$true
                            "DUPLICATED ALGO "+$MINER.ALGORITHM+" ON "+$MINER.NAME | Out-host 
                            EXIT}                 

                    if ($Miner) {
                            $_.GroupId  = $Miner.GroupId
                            $_.Profit  = $Miner.Profit
                            $_.ProfitDual  = $Miner.ProfitDual
                            $_.Profits = $Miner.Profits
                            $_.PoolPrice = $Miner.PoolPrice
                            $_.PoolPriceDual = $Miner.PoolPriceDual
                            $_.HashRate  = [double]$Miner.HashRate
                            $_.HashRateDual  = [double]$Miner.HashRateDual
                            $_.Hashrates   = $miner.hashrates
                            $_.PoolWorkers = $Miner.PoolWorkers
                            $_.PoolFee= $Miner.PoolFee
                            $_.IsValid = $true #not remove, necessary if pool fail and is operative again
                            $_.BestBySwitch  = ""
                            }
                    else {
                            $_.IsValid = $false #simulates a delete
                           
                            }
                
                }


    ##Add new miners to list
    $Miners | ForEach-Object {
                
                    $ActiveMiner = $ActiveMiners | Where-Object Name -eq $_.Name | 
                            Where-Object Coin -eq $_.Coin | 
                            Where-Object Algorithm -eq $_.Algorithm | 
                            Where-Object CoinDual -eq $_.CoinDual | 
                            Where-Object AlgorithmDual -eq $_.AlgorithmDual | 
                            Where-Object PoolAbbName -eq $_.PoolAbbName |
                            Where-Object Location -eq $_.Location |
                            Where-Object GroupId -eq $_.GroupId |
                            Where-Object AlgoLabel -eq $_.AlgoLabel

                
                    if ($ActiveMiner -eq $null) {
                        $ActiveMiners += [pscustomObject]@{
                            Id                   = $ActiveMinersIdCounter
                            GroupName            = $_.GroupName
                            GroupId              = $_.GroupId
                            Algorithm            = $_.Algorithm
                            AlgorithmDual        = $_.AlgorithmDual
                            Algorithms           = $_.Algorithms
                            Name                 = $_.Name
                            Coin                 = $_.coin
                            CoinDual             = $_.CoinDual
                            Path                 = Convert-Path $_.Path
                            Arguments            = $_.Arguments
                            Wrap                 = $_.Wrap
                            API                  = $_.API
                            Port                 = $_.Port
                            Profit               = $_.Profit
                            ProfitDual           = $_.ProfitDual
                            Profits              = $_.Profits
                            HashRate             = [double]$_.HashRate
                            HashRateDual         = [double]$_.HashRateDual
                            Hashrates            = $_.hashrates
                            PoolAbbName          = $_.PoolAbbName
                            SpeedLive            = 0
                            SpeedLiveDual        = 0
                            ProfitLive           = 0
                            ProfitLiveDual       = 0
                            PoolPrice            = $_.PoolPrice
                            PoolPriceDual        = $_.PoolPriceDual
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
                            WalletSymbol         = $_.WalletSymbol
                            Host                 = $_.Host
                            ConfigFileArguments  = $_.ConfigFileArguments
                            GenerateConfigFile   = $_.GenerateConfigFile
                            ConsecutiveZeroSpeed = 0
                            AnyNonZeroSpeed      = $false
                            Location             = $_.Location
                            PrelaunchCommand     = $_.PrelaunchCommand
                            MinerFee             = $_.MinerFee
                            PoolFee              = $_.PoolFee
                            AlgoLabel            = $_.AlgoLabel
                            Symbol               = $_.Symbol
                            SymbolDual           = $_.SymbolDual
                            BestBySwitch         = ""
                            
                            

                        }
                        $ActiveMinersIdCounter++
                }
            }



    Writelog ("Active Miners-pools: "+ [string]($ActiveMiners.count)+".........") $LogFile $true                

    ErrorsToLog $LogFile


    #update miners that need benchmarks
                                                
    $ActiveMiners | ForEach-Object {

        if ($_.BenchmarkedTimes -le 2 -and $_.isvalid -and ($_.Hashrate -eq 0 -or ($_.AlgorithmDual -ne $null -and $_.HashrateDual -eq 0)))
            {$_.NeedBenchmark=$true} 
        }



    Writelog ("Active Miners-pools selected for benchmark: "+ [string](($ActiveMiners | where-object NeedBenchmark -eq $true).count)+".........") $LogFile $true                

    #For each type, select most profitable miner, not benchmarked has priority, only new miner is lauched if new profit is greater than old by percenttoswitch
    foreach ($Type in $Types) {

        $BestIdNow=($ActiveMiners |Where-Object {$_.IsValid -and $_.status -ne "Canceled" -and  $_.GroupId -eq $Type.Id} | Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, {$_.Profits},Algorithm | Select-Object -First 1 | Select-Object -ExpandProperty  id)
        if ($BestIdNow -ne $null) {
                    $ProfitNow=$ActiveMiners[$BestIdNow].profits 

                    Writelog ($ActiveMiners[$BestIdNow].name+"/"+$ActiveMiners[$BestIdNow].Algorithms+"(id "+[string]$BestIdNow+") is the best combination for gpu group "+$Type.groupname) $LogFile $true                

                    $BestIdLast=($ActiveMiners |Where-Object {$_.IsValid -and $_.status -eq "Running" -and  $_.GroupId -eq $Type.Id} | Select-Object -ExpandProperty  id)
                    
                    if ($BestIdLast -ne $null) {$ProfitLast=$ActiveMiners[$BestIdLast].profits} else {$ProfitLast=0}
 
                    if ($ProfitNow -gt ($ProfitLast *(1+($PercentToSwitch2/100))) -or $ActiveMiners[$BestIdNow].NeedBenchmark) {
                            $ActiveMiners[$BestIdNow].best=$true
                            } 
                        else {
                            $ActiveMiners[$BestIdLast].best=$true 
                            if ($Profitlast -lt $ProfitNow) {
                                    $ActiveMiners[$BestIdLast].BestBySwitch  = "*"
                                    Writelog ($ActiveMiners[$BestIdLast].name+"/"+$ActiveMiners[$BestIdLast].Algorithms+"(id "+[string]$BestIdLast+") continue mining due to @@percenttoswitch value "+$Type.name) $LogFile $true                
                                }
                            }
        
                    }
        }


    ErrorsToLog $LogFile
   
   

    #Start all Miners marked as Best (if they are running does nothing)
    $ActiveMiners | Where-Object Best -eq $true | ForEach-Object {
        
                if ($_.NeedBenchmark) {$NextInterval=$BechmarkintervalTime;$DelayCloseMiners=0} #if one need benchmark next interval will be short and fast change

                #Launch
                if ($_.Process -eq $null -or $_.Process.HasExited -ne $false) {


                    $_.Status = "Running"
                    
                    #assign a free random api port (not if it is forced in miner file or calculated before)
                    if ($_.Port -eq $null) { $_.Port = get_next_free_port (Get-Random -minimum 2000 -maximum 48000)} 

                    $_.Arguments = $_.Arguments -replace '#APIPORT#',$_.Port
                    
                    $_.ConfigFileArguments = $_.ConfigFileArguments -replace '#APIPORT#',$_.Port

                    $_.ActivatedTimes++

                    if ($_.GenerateConfigFile -ne "") {$_.ConfigFileArguments | Set-Content ($_.GenerateConfigFile)}

                    #run prelaunch command
                    if ($_.PrelaunchCommand -ne $null -and $_.PrelaunchCommand -ne "") {Start-Process -FilePath $_.PrelaunchCommand}

                    if ($_.Wrap) {$_.Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($_.Port)' -FilePath '$($_.Path)' -ArgumentList '$($_.Arguments)' -WorkingDirectory '$(Split-Path $_.Path)'" -PassThru}
                    else {$_.Process = Start_SubProcess -FilePath $_.Path -ArgumentList $_.Arguments -WorkingDirectory (Split-Path $_.Path)}
                
                    

                    if ($_.Process -eq $null) {
                            $_.Status = "Failed"
                            $_.FailedTimes++
                            Writelog ("Failed start of "+$_.Name+"/"+$_.Algorithms+"("+$_.Id+") --> "+$_.Path+" "+$_.Arguments) $LogFile $false
                        } 
                    else {
                        $_.Status = "Running"
                        $_.LastActiveCheck=get-date
                        Writelog ("Started Process "+[string]$_.Process.Id+" for "+$_.Name+"/"+$_.Algorithms+"("+$_.Id+") --> "+$_.Path+" "+$_.Arguments) $LogFile $false
                        }

                    }
            
                } #end stating miners


      

         #Call api to local currency conversion
        try {
                $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing -TimeoutSec 2 | ConvertFrom-Json | Select-Object -ExpandProperty BPI
                Clear-Host;$repaintScreen=$true
            } 
                
            catch {
                Clear-Host;$repaintScreen=$true
                writelog "COINDESK API NOT RESPONDING, NOT POSSIBLE LOCAL COIN CONVERSION" $logfile $true
                }
                
                switch ($LocalCurrency) {
                    'EURO' {$LabelProfit="EUR/Day" ; $localBTCvalue = [double]$CDKResponse.eur.rate}
                    'DOLLAR'     {$LabelProfit="USD/Day" ; $localBTCvalue = [double]$CDKResponse.usd.rate}
                    'GBP'     {$LabelProfit="GBP/Day" ; $localBTCvalue = [double]$CDKResponse.gbp.rate}
                    default {$LabelProfit="USD/Day" ; $localBTCvalue = [double]$CDKResponse.usd.rate}

                }





    $FirstLoopExecution=$True   
    $LoopStarttime=Get-Date
    $MustCloseMiners=$true

    ErrorsToLog $LogFile



    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------
    #---------------------------------------------------------------------------

    while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush

    
    #loop to update info and check if miner is running, exit loop is forced inside                        
    While (1 -eq 1) 
        {

        $ExitLoop = $false
        

        $LoopTime=(get-date) - $LoopStarttime
        $LoopSeconds=$LoopTime.seconds + $LoopTime.minutes * 60 +  $LoopTime.hours *3600


        #Stop miners running if they arent best now or failed after 30 seconds into loop
        
        
        if ($LoopSeconds -ge $DelayCloseMiners -and $MustCloseMiners) {
                $AnyProcClosed=$false
                $ActiveMiners | Where-Object {$_.Best -eq $false -and $_.Process -ne $null} | ForEach-Object {
                        
                            try {Kill_ProcessId $_.Process.Id} catch{}
                            try {Kill_ProcessId $_.Process.Id} catch{}
                            $_.process=$null
                            $_.Status = "Idle"
                            $AnyProcClosed=$true
                            WriteLog ("Killing "+$_.name+"/"+$_.Algorithms+"(id "+[string]$_.Id+")") $LogFile
                        }
                        
                   if ($AnyProcClosed) {
                        $MustCloseMiners=$false
                        Clear-host
                        $repaintScreen=$true
                        }
            }
            

        #display interval
            $TimetoNextInterval= NEW-TIMESPAN (Get-Date) ($LoopStarttime.AddSeconds($NextInterval))
            $TimetoNextIntervalSeconds=($TimetoNextInterval.Hours*3600)+($TimetoNextInterval.Minutes*60)+$TimetoNextInterval.Seconds
            if ($TimetoNextIntervalSeconds -lt 0) {$TimetoNextIntervalSeconds = 0}

            set_ConsolePosition 92 2
            "Next Interval:  $TimetoNextIntervalSeconds secs..." | Out-host
            set_ConsolePosition 0 0

        #display header        
        "------------------------------------------------   MegaMiner 5.1  -----------------------------------------------------"| Out-host
        "-----------------------------------------------------------------------------------------------------------------------"| Out-host
        "  (E)nd Interval   (P)rofits    (C)urrent    (H)istory    (W)allets                       |" | Out-host
      
        #display donation message
        
            if ($DonationInterval) {" THIS INTERVAL YOU ARE DONATING, YOU CAN INCREASE OR DECREASE DONATION ON CONFIG.TXT, THANK YOU FOR YOUR SUPPORT !!!!"}

        #display current mining info

        "-----------------------------------------------------------------------------------------------------------------------"| Out-host
  
          $ActiveMiners | Where-Object Status -eq 'Running'| Sort-Object GroupId | Format-Table -Wrap  (
              @{Label = "GroupName"; Expression = {$_.GroupName}}, 
              @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo_Hash  ($_.SpeedLive))+'/s'} else {(ConvertTo_Hash  ($_.SpeedLive))+'/s|'+(ConvertTo_Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'},     
              @{Label = "BTC/Day"; Expression = {$_.ProfitLive.tostring("n5")}; Align = 'right'}, 
              @{Label = $LabelProfit; Expression = {(([double]$_.ProfitLive + [double]$_.ProfitLiveDual) *  [double]$localBTCvalue ).tostring("n2")}; Align = 'right'}, 
              @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm+$_.AlgoLabel+$_.BestBySwitch} else  {$_.Algorithm+$_.AlgoLabel+ '|' + $_.AlgorithmDual+$_.BestBySwitch}}},   
              @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.symbol)+ '|' + ($_.symbolDual)}}},   
              @{Label = "Miner"; Expression = {$_.Name}}, 
              @{Label = "Pool"; Expression = {$_.PoolAbbName}},
              @{Label = "Location"; Expression = {$_.Location}},
              @{Label = "PoolWorkers"; Expression = {$_.PoolWorkers}}
<#
              @{Label = "BmkT"; Expression = {$_.BenchmarkedTimes}},
              @{Label = "FailT"; Expression = {$_.FailedTimes}},
              @{Label = "Nbmk"; Expression = {$_.NeedBenchmark}},
              @{Label = "CZero"; Expression = {$_.ConsecutiveZeroSpeed}}
              @{Label = "Port"; Expression = {$_.Port}}
 #>             


          ) | Out-Host


        writelog ($ActiveMiners | Where-Object Status -eq 'Running'| select-object id,groupname,name,poolabbname,Algorithm,AlgorithmDual,SpeedLive,ProfitLive,location,port,arguments |ConvertTo-Json) $logfile $false


        $XToWrite=[ref]0
        $YToWrite=[ref]0      
        Get_ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)  
        $YToWriteMessages=$YToWrite+1
        $YToWriteData=$YToWrite+2
        Remove-Variable XToWrite
        Remove-Variable YToWrite                          



        #display profits screen
        if ($Screen -eq "Profits" -and $repaintScreen) {

                    "----------------------------------------------------PROFITS------------------------------------------------------------"| Out-host            

                 
                    set_ConsolePosition 80 $YToWriteMessages
                    
                    "(B)est Miners/All       (T)op "+[string]$InitialProfitsScreenLimit+"/All" | Out-Host

                    
                    set_ConsolePosition 0 $YToWriteData


                    if ($ShowBestMinersOnly) {
                        $ProfitMiners=@()
                        $ActiveMiners | Where-Object IsValid |ForEach-Object {
                            $ExistsBest=$ActiveMiners | Where-Object GroupId -eq $_.GroupId | Where-Object Algorithm -eq $_.Algorithm | Where-Object AlgorithmDual -eq $_.AlgorithmDual | Where-Object IsValid -eq $true | Where-Object Profits -gt $_.Profits
                                           if ($ExistsBest -eq $null -and $_.Profits -eq 0) {$ExistsBest=$ActiveMiners | Where-Object GroupId -eq $_.GroupId | Where-Object Algorithm -eq $_.Algorithm | Where-Object AlgorithmDual -eq $_.AlgorithmDual | Where-Object IsValid -eq $true | Where-Object hashrate -gt $_.hashrate}
                                           if ($ExistsBest -eq $null -or $_.NeedBenchmark -eq $true) {$ProfitMiners += $_}
                                           }
                           }
                    else 
                           {$ProfitMiners=$ActiveMiners}
                    

                    $ProfitMiners2=@()
                    ForEach ( $TypeId in $types.Id) {
                            $inserted=1
                            $ProfitMiners | Where-Object IsValid |Where-Object GroupId -eq $TypeId | Sort-Object -Descending GroupName,NeedBenchmark,Profits | ForEach-Object {
                                if ($inserted -le $ProfitsScreenLimit) {$ProfitMiners2+=$_ ; $inserted++} #this can be done with select-object -first but then memory leak happens, ¿why?
                                    }
                        }

                        

                    #Display profits  information
                    $ProfitMiners2 | Sort-Object -Descending GroupName,NeedBenchmark,Profits | Format-Table (
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm+$_.AlgoLabel} else  {$_.Algorithm+$_.AlgoLabel+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.Symbol)+ '|' + ($_.SymbolDual)}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "Speed"; Expression = {if ($_.NeedBenchmark) {"Benchmarking"} else {$_.Hashrates}}}, 
                        @{Label = "BTC/Day"; Expression = {if ($_.NeedBenchmark) {"-------"} else {$_.Profits.tostring("n5")}}; Align = 'right'}, 
                        @{Label = $LabelProfit; Expression = {([double]$_.Profits * [double]$localBTCvalue ).tostring("n2") } ; Align = 'right'},
                        @{Label = "PoolFee"; Expression = {if ($_.PoolFee -ne $null) {"{0:P2}" -f $_.PoolFee}}; Align = 'right'},
                        @{Label = "MinerFee"; Expression = {if ($_.MinerFee -ne $null) {"{0:P2}" -f $_.MinerFee}}; Align = 'right'},
                        @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                        @{Label = "Location"; Expression = {$_.Location}}
                        

                    )  -GroupBy GroupName  |  Out-Host

                       
                    Remove-Variable ProfitMiners
                    Remove-Variable ProfitMiners2
                    
                   
                }
  

                
                          
        if ($Screen -eq "Current") {
                    
                    "----------------------------------------------------CURRENT------------------------------------------------------------"| Out-host            
                    
                    
                    set_ConsolePosition 0 $YToWriteData

                    #Display lauched commands information
                    $ActiveMiners | Where-Object Status -eq 'Running' | Format-Table -Wrap  (
                        @{Label = "GroupName"; Expression = {$_.GroupName}}, 
                        @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm} else  {$_.Algorithm+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host
                    
                    # Display devices info
                    print_gpu_information

                  

                }
                                    
                
                    
        if ($Screen -eq "Wallets" -or $FirstTotalExecution -eq $true) {         


                    if ($WalletsUpdate -eq $null) { #wallets only refresh for manual request

                            $WalletsUpdate=get-date

                            $WalletsToCheck=@()
                            
                            $Pools  | where-object WalletMode -eq 'WALLET' | Select-Object PoolName,AbbName,User,WalletMode,WalletSymbol -unique  | ForEach-Object {
                                    $WalletsToCheck += [pscustomObject]@{
                                                PoolName   = $_.PoolName
                                                AbbName = $_.AbbName
                                                WalletMode = $_.WalletMode
                                                User       = ($_.User -split '\.')[0] #to allow payment id after wallet
                                                Coin = $null
                                                Algorithm = $null
                                                OriginalAlgorithm =$null
                                                OriginalCoin = $null
                                                Host = $null
                                                Symbol = $_.WalletSymbol
                                                }
                                }
                            $Pools  | where-object WalletMode -eq 'APIKEY' | Select-Object PoolName,AbbName,info,Algorithm,OriginalAlgorithm,OriginalCoin,Symbol,WalletMode,WalletSymbol  -unique  | ForEach-Object {
                                    

                                    $ApiKeyPattern="APIKEY_"+$_.PoolName
                                    $ApiKey = get_config_variable $ApiKeyPattern
                                
                                    if ($Apikey -ne "") {
                                            $WalletsToCheck += [pscustomObject]@{
                                                        PoolName   = $_.PoolName
                                                        AbbName = $_.AbbName
                                                        WalletMode = $_.WalletMode
                                                        User       = $null
                                                        Coin = $_.Info
                                                        Algorithm =$_.Algorithm
                                                        OriginalAlgorithm =$_.OriginalAlgorithm
                                                        OriginalCoin = $_.OriginalCoin
                                                        Symbol = $_.WalletSymbol
                                                        ApiKey = $ApiKey
                                                        }
                                                    }
                                      }

                            $WalletStatus=@()
                            $WalletsToCheck |ForEach-Object {

                                            set_ConsolePosition 0 $YToWriteMessages
                                            "                                                                         "| Out-host 
                                            set_ConsolePosition 0 $YToWriteMessages

                                            if ($_.WalletMode -eq "WALLET") {writelog ("Checking "+$_.Abbname+" - "+$_.symbol) $logfile $true}
                                               else {writelog ("Checking "+$_.Abbname+" - "+$_.coin+' ('+$_.Algorithm+')') $logfile $true}
                                         

                                          
                                            $Ws = Get_Pools -Querymode $_.WalletMode -PoolsFilterList $_.Poolname -Info ($_)
                                            
                                            if ($_.WalletMode -eq "WALLET") {$Ws | Add-Member Wallet $_.User}
                                            else  {$Ws | Add-Member Wallet $_.Coin}

                                            $Ws | Add-Member PoolName $_.Poolname

                                            $Ws | Add-Member WalletSymbol $_.Symbol
                                            
                                            $WalletStatus += $Ws

                                            set_ConsolePosition 0 $YToWriteMessages
                                            "                                                                         "| Out-host 

                                            start-sleep 1 #no saturation of pool api


                                            
                                        } 


                            if ($FirstTotalExecution -eq $true) {$WalletStatusAtStart= $WalletStatus}
 
                            $WalletStatus | Add-Member BalanceAtStart [double]$null
                            $WalletStatus | ForEach-Object{
                                    $_.BalanceAtStart = ($WalletStatusAtStart |Where-Object wallet -eq $_.Wallet |Where-Object poolname -eq $_.poolname |Where-Object currency -eq $_.currency).balance
                                    }

                         }




                         if ($Screen -eq "Wallets" -and $repaintScreen) {
                            "----------------------------------------------------WALLETS (slow)-----------------------------------------------------"| Out-host   
                            
                            set_ConsolePosition 0 $YToWriteMessages
                            "Start Time: $StartTime                                                       (U)pdate  - $WalletsUpdate  " | Out-Host
                            "" | Out-Host 
                                                    

                            $WalletStatus | where-object Balance -gt 0 | Sort-Object poolname | Format-Table -Wrap -groupby poolname (
                                @{Label = "Coin"; Expression = {$_.WalletSymbol}}, 
                                @{Label = "Balance"; Expression = {$_.balance.tostring("n5")}; Align = 'right'},
                                @{Label = "IncFromStart"; Expression = {($_.balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                                
                            ) | Out-Host
                        

                            $Pools  | where-object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                                "NO EXISTS API FOR POOL "+$_.PoolName+" - NO WALLETS CHECK" | Out-host 
                                }  

                            }
                        
                            $repaintScreen=$false
                        }

                
        if ($Screen -eq "History" ) {                        

                    "--------------------------------------------------HISTORY------------------------------------------------------------"| Out-host            
                    
                    set_ConsolePosition 0 $YToWriteMessages
                    "Running Mode: $MiningMode" |out-host

                    set_ConsolePosition 0 $YToWriteData

                    #Display activated miners list
                    $ActiveMiners | Where-Object ActivatedTimes -GT 0 | Sort-Object -Descending Status, {if ($_.Process -eq $null) {[DateTime]0}else {$_.Process.StartTime}} | Select-Object -First (1 + 6 + 6) | Format-Table -Wrap -GroupBy Status (
                        @{Label = "Speed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo_Hash  ($_.SpeedLive))+'s'} else {(ConvertTo_Hash  ($_.SpeedLive))+'/s|'+(ConvertTo_Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'}, 
                        @{Label = "Active"; Expression = {"{0:dd} Days {0:hh} Hours {0:mm} Minutes" -f $_.ActiveTime}}, 
                        @{Label = "Launched"; Expression = {Switch ($_.ActivatedTimes) {0 {"Never"} 1 {"Once"} Default {"$_ Times"}}}}, 
                        @{Label = "Command"; Expression = {"$($_.Path.TrimStart((Convert-Path ".\"))) $($_.Arguments)"}}
                    ) | Out-Host


                    $repaintScreen=$false
                }

  
                 
                   
            #Check Live Speed and record benchmark if necessary
            $ActiveMiners | Where-Object Best -eq $true | ForEach-Object {
                            if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.BenchmarkedTimes++}
                            $_.SpeedLive = 0
                            $_.SpeedLiveDual = 0
                            $_.ProfitLive = 0
                            $_.ProfitLiveDual = 0
                            $Miner_HashRates = $null


                            if ($_.Process -eq $null -or $_.Process.HasExited) {
                                    if ($_.Status -eq "Running") {
                                                $_.Status = "Failed"
                                                $_.FailedTimes++
                                                writelog ("Detected exit for "+$_.name+"/"+$_.Algorithm+" (if"+$_.Id+") --> "+$_.Arguments) $logfile $false
                                                $ExitLoop = $true
                                                }
                                    else
                                        { $ExitLoop = $true}         
                                    }

                            else {
                                    $_.ActiveTime += (get-date) - $_.LastActiveCheck 
                                    $_.LastActiveCheck=get-date

                                    $Miner_HashRates = Get_Live_HashRate $_.API $_.Port 

                                    if ($Miner_HashRates -ne $null){
                                        $_.SpeedLive = [double]($Miner_HashRates[0])
                                        $_.ProfitLive = $_.SpeedLive * $_.PoolPrice 
                                    

                                        if ($Miner_HashRates[0] -gt 0) {$_.ConsecutiveZeroSpeed=0;$_.AnyNonZeroSpeed = $true} else {$_.ConsecutiveZeroSpeed++}
                                        
                                            
                                        if ($_.DualMining){     
                                            $_.SpeedLiveDual = [double]($Miner_HashRates[1])
                                            $_.ProfitLiveDual = $_.SpeedLiveDual * $_.PoolPriceDual
                                            }


                                        $Value=[long]($Miner_HashRates[0] * 0.95)
                                        $ValueDual=[long]($Miner_HashRates[1] * 0.95)

                                        if ($Value -gt $_.Hashrate -and $_.NeedBenchmark -and ($valueDual -gt 0 -or $_.Dualmining -eq $false)) {
                                            
                                            $_.Hashrate= $Value
                                            $_.HashrateDual= $ValueDual
                                            Set_Hashrates -algorithm $_.Algorithms -minername $_.Name -GroupName $_.GroupName -AlgoLabel $_.AlgoLabel -value  $Value -valueDual $ValueDual
                                            }
                                        }          
                                }

                                

                            if ($_.ConsecutiveZeroSpeed -gt 25 -and $_.NeedBenchmark -ne $true ) { #avoid  miner hangs and wait interval ends
                                writelog ($_.name+"/"+$_.Algorithm+" (if"+$_.Id+") had 25 zero hashrates reads, exiting loop") $logfile $false
                                $_.FailedTimes++
                                $_.status="Failed"
                                #$_.Best= $false
                                $ExitLoop='true'
                                }
            
                                    

                    }

                    


                $FirstLoopExecution=$False

                #Loop for reading key and wait
             
                $KeyPressed=Timed_ReadKb 3 ('P','C','H','E','W','U','T','B','S')

                


            
                switch ($KeyPressed){
                    'P' {$Screen='profits'}
                    'C' {$Screen='current'}
                    'H' {$Screen='history'}
                    'E' {$ExitLoop=$true}
                    'W' {$Screen='Wallets'}
                    'U' {if ($Screen -eq "Wallets") {$WalletsUpdate=$null}}
                    'T' {if ($Screen -eq "Profits") {if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) {$ProfitsScreenLimit=1000} else {$ProfitsScreenLimit=$InitialProfitsScreenLimit}}}
                    'B' {if ($Screen -eq "Profits") {if ($ShowBestMinersOnly -eq $true) {$ShowBestMinersOnly=$false} else {$ShowBestMinersOnly=$true}}}
                    'S' {set_WindowSize 120 60}
                    }

                if ($KeyPressed) {Clear-host;$repaintScreen=$true}
           
                if (((Get-Date) -ge ($LoopStarttime.AddSeconds($NextInterval)))  ) { #If time of interval has over, exit of main loop
                                $ActiveMiners | Where-Object Best -eq $true | ForEach-Object { #if a miner ends inteval without speed reading mark as failed
                                       if ($_.AnyNonZeroSpeed -eq $false) {$_.FailedTimes++;$_.status="Failed"}
                                    }
                                 break
                            } 

                if ($ExitLoop) {break} #forced exit

               ErrorsToLog $logfile
           
    
        }
    
    
    Remove-variable miners
    Remove-variable pools
    Get-Job -State Completed | Remove-Job
    [GC]::Collect() #force garbage recollector for free memory
    $FirstTotalExecution =$False

    
}

#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-------------------------------------------end of alwais running loop--------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------------------------------



Writelog "Program end" $logfile

$ActiveMiners | ForEach-Object { Kill_ProcessId $_.Process.Id}
    
#Stop-Transcript
