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
#$MiningMode='Manual'

#$PoolsName=('ahashpool','mining_pool_hub','hash_refinery')
#$PoolsName='whattomine'
#$PoolsName='zergpool'
#$PoolsName='yiimp'
#$PoolsName='ahashpool'
#$PoolsName=('hash_refinery','zpool')
#$PoolsName='mining_pool_hub'
#$PoolsName='zpool'
#$PoolsName='hash_refinery'
#$PoolsName='altminer'

#$PoolsName="Nicehash"
#$PoolsName="Nanopool"

#$Coinsname =('bitcore','Signatum','Zcash')
#$Coinsname ='zcash'
#$Algorithm =('phi','x17')

#$Groupnames=('rx580')




$ErrorActionPreference = "Continue"
if ($Groupnames -eq $null) {$Host.UI.RawUI.WindowTitle = "MegaMiner"} else {$Host.UI.RawUI.WindowTitle = "MM-" + ($Groupnames -join "/")}
$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' #This align cuda id with nvidia-smi order

$progressPreference = 'silentlyContinue' #No progress message on web requests
#$progressPreference = 'Stop'

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

Get-ChildItem . -Recurse | Unblock-File


#add MM path to windows defender exclusions
    $DefenderExclusions = (Get-MpPreference).CimInstanceProperties |Where-Object name -eq 'ExclusionPath'
    if ($DefenderExclusions.value -notcontains (Convert-Path .)) {Start-Process powershell -Verb runAs -ArgumentList "Add-MpPreference -ExclusionPath '$(Convert-Path .)'"}




#Start log file
    Clear_log
    $LogFile=".\Logs\$(Get-Date -Format "yyyy-MM-dd_HH-mm-ss").txt"
    Start-Transcript $LogFile #for start log msg
    Stop-Transcript
    $Types=Get_Mining_Types -filter $Groupnames
    
    writelog ( get_gpu_information $Types |ConvertTo-Json) $logfile $false
    Writelog ( $Types |ConvertTo-Json) $logfile $false    

 
    


$ActiveMiners = @()
$Activeminers=@()
$ShowBestMinersOnly=$true
$FirstTotalExecution =$true
$StartTime=get-date


if ((get_config_variable "DEBUGLOG") -eq "ENABLED"){$DetailedLog=$True} else {$DetailedLog=$false}

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


    
set_WindowSize 185 60 
    
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
    $BenchmarkintervalTime=[int](get_config_variable "BENCHMARKTIME" )
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
    
    $DelayCloseMiners=[int](get_config_variable "DELAYCLOSEMINERS")        
    
    #Donation
    $LastIntervalTime= (get-date) - $IntervalStartAt
    $IntervalStartAt = (Get-Date)
    $DonationPastTime= ((Get-Content Donation.ctr) -split '_')[0]
    $DonatedTime = ((Get-Content Donation.ctr) -split '_')[1]

    If ($DonationPastTime -eq $null -or $DonationPastTime -eq "" ) {$DonationPastTime=0}
    If ($DonatedTime -eq $null -or $DonatedTime -eq "" ) {$DonatedTime=0}

    $ElapsedDonationTime = [int]($DonationPastTime) + $LastIntervalTime.minutes + ($LastIntervalTime.hours *60)
    $ElapsedDonatedTime = [int]($DonatedTime) + $LastIntervalTime.minutes + ($LastIntervalTime.hours *60)

    
    $ConfigDonateTime= [int](get_config_variable "DONATE")
    

    #if ($DonateTime -gt 5) {[int]$DonateTime=5}
    
    #Activate or deactivate donation
    if ($ElapsedDonationTime -gt 1440 -and $ConfigDonateTime -gt 0) { # donation interval

                $DonationInterval = $true
                $UserName = "tutulino"
                #$WorkerName = "Megaminer"
                $CoinsWallets=@{} 
                $CoinsWallets.add("BTC","1AVMHnFgc6SW33cwqrDyy2Fug9CsS8u6TM")

                $NextInterval= ($ConfigDonateTime *60) - ($ElapsedDonatedTime *60)

                $Algorithm=$null
                $PoolsName="DonationPool"
                $CoinsName=$null
                $MiningMode="Automatic"

                if ($ElapsedDonatedTime -ge $ConfigDonateTime) {"0_0" | Set-Content  -Path Donation.ctr} else {[string]$DonationPastTime+"_"+[string]$ElapsedDonatedTime | Set-Content  -Path Donation.ctr}

                WriteLog ("Next interval you will be donating , thanks for your support") $LogFile $True

            }
            else { #NOT donation interval
                    $DonationInterval = $false
                    #get interval time based on pool kind (pps/ppls)
                    $NextInterval=0
                    Get_Pools -Querymode "Info" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $Location -AlgoFilterList $Algorithm | foreach-object {
                        $PItime=get_config_variable ("INTERVAL_"+$_.Rewardtype)
                        if ([int]$PItime -gt $NextInterval) {$NextInterval= [int]$PItime}
                        }

                    $Algorithm=$ParamAlgorithmBCK
                    $PoolsName=$ParamPoolsNameBCK
                    $CoinsName=$ParamCoinsNameBCK
                    $MiningMode=$ParamMiningModeBCK
                    $UserName= get_config_variable "USERNAME"
                    $WorkerName= get_config_variable "WORKERNAME"
                    $CoinsWallets=@{} 
                    ((Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','').TrimEnd() | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}
                
                    [string]$ElapsedDonationTime+"_0" | Set-Content  -Path Donation.ctr

                 }
        

    
    ErrorsToLog $LogFile


    #get actual hour electricity cost
    $ElectricityCostValue= [double]((get_config_variable "ElectricityCost" |ConvertFrom-Json) |where-object  HourStart -le (get-date).Hour |where-object  HourEnd -ge (get-date).Hour).CostKwh



    WriteLog "Loading Pools Information............." $LogFile $True

    #Load information about the Pools, only must read parameter passed files (not all as mph do), level is Pool-Algo-Coin
     do
        {
        $Pools=Get_Pools -Querymode "core" -PoolsFilterList $PoolsName -CoinFilterList $CoinsName -Location $Location -AlgoFilterList $Algorithm

        if  ($Pools.Count -eq 0) {
                $Msg="NO POOLS!....retry in 10 sec --- REMEMBER, IF YOUR ARE MINING ON ANONYMOUS WITHOUT AUTOEXCHANGE POOLS LIKE YIIMP, NANOPOOL, ETC. YOU MUST SET WALLET FOR AT LEAST ONE POOL COIN IN CONFIG.TXT"
                WriteLog $msg $logFile $true
                
                Start-Sleep 10}
        }
    while ($Pools.Count -eq 0) 
    
    $Pools | Select-Object name -unique | foreach-object {Writelog ("Pool "+$_.name+" was responsive....") $logfile $true}

    writelog ("Detected "+[string]$Pools.count+" pools......") $logfile $true

  


    #Filter by minworkes variable
    $Pools = $Pools | Where-Object {$_.Poolworkers -ge (get_config_variable "MINWORKERS") -or $_.Poolworkers -eq $null}
    writelog ([string]$Pools.count+" pools left after min workers filter.....") $logfile $true

    #Call api to local currency conversion
    try {
        $CDKResponse = Invoke-WebRequest "https://api.coindesk.com/v1/bpi/currentprice.json" -UseBasicParsing -TimeoutSec 2 | ConvertFrom-Json | Select-Object -ExpandProperty BPI
        writelog "Coindesk api was responsive.........." $logfile $true
    } 
        
    catch {

        writelog "Coindesk api not responding, not possible/deactuallized local coin conversion.........." $logfile $true
        }
        
        switch ($LocalCurrency) {
            'EURO' {$LocalSymbol=[convert]::ToChar(8364) ; $localBTCvalue = [double]$CDKResponse.eur.rate}
            'DOLLAR'     {$LocalSymbol=+[convert]::ToChar(36)  ; $localBTCvalue = [double]$CDKResponse.usd.rate}
            'GBP'     {$LocalSymbol=[convert]::ToChar(163)  ; $localBTCvalue = [double]$CDKResponse.gbp.rate}
            default {$LocalSymbol=" $" ; $localBTCvalue = [double]$CDKResponse.usd.rate}

        }

   

    
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
                            
                            ForEach ( $TypeGroup in $types) { #generate a line for each gpu group
                                    
                                    if  ((Compare-object $TypeGroup.type $Miner.Types -IncludeEqual -ExcludeDifferent | Measure-Object).count -gt 0) { #check group and miner types are the same
                                        Foreach ($Pool in ($Pools | where-object Algorithm -eq $AlgoName))  {   #Search pools for that algo
                                            
                                            if ((($Pools | Where-Object Algorithm -eq $AlgoNameDual) -ne  $null) -or ($AlgoNameDual -eq $null)){
                                            

                                            if (((Compare-object $Pool.info ($Miner.DualMiningMainCoin -replace $null,"") -IncludeEqual -ExcludeDifferent | Measure-Object).count -gt 0) -or $AlgoNameDual -eq $null) {  #not allow dualmining if main coin not coincide


                                            #Replace wildcards patterns
                                                    if (($Types | Measure-Object).Count -gt 1) {
                                                                if ($Pool.name -eq 'Nicehash') {$WorkerName2=$WorkerName+$TypeGroup.GroupName} else {$WorkerName2=$WorkerName+'_'+$TypeGroup.GroupName}
                                                            }
                                                            else  {$WorkerName2=$WorkerName} 


                                                    $Arguments = $Miner.Arguments  -replace '#PORT#',$Pool.Port -replace '#SERVER#',$Pool.Host -replace '#PROTOCOL#',$Pool.Protocol -replace '#LOGIN#',$Pool.user -replace '#PASSWORD#',$Pool.Pass -replace "#GpuPlatform#",$TypeGroup.GpuPlatform  -replace '#ALGORITHM#',$Algoname -replace '#ALGORITHMPARAMETERS#',$Algo.PSObject.Properties.Value -replace '#WORKERNAME#',$WorkerName2  -replace '#DEVICES#',$TypeGroup.Gpus   -replace '#DEVICESCLAYMODE#',$TypeGroup.GpusClayMode -replace '#DEVICESETHMODE#',$TypeGroup.GpusETHMode -replace '#GROUPNAME#',$TypeGroup.Groupname -replace "#ETHSTMODE#",$Pool.EthStMode -replace "#DEVICESNSGMODE#",$TypeGroup.GpusNsgMode                   
                                                    if ($Miner.PatternConfigFile -ne $null) {
                                                                    $ConfigFileArguments =  replace_foreach_gpu (get-content $Miner.PatternConfigFile -raw)  $TypeGroup.Gpus
                                                                    $ConfigFileArguments = $ConfigFileArguments -replace '#PORT#',$Pool.Port -replace '#SERVER#',$Pool.Host -replace '#PROTOCOL#',$Pool.Protocol -replace '#LOGIN#',$Pool.user -replace '#PASSWORD#',$Pool.Pass -replace "#GpuPlatform#",$TypeGroup.GpuPlatform   -replace '#ALGORITHM#',$Algoname -replace '#ALGORITHMPARAMETERS#',$Algo.PSObject.Properties.Value -replace '#WORKERNAME#',$WorkerName2  -replace '#DEVICES#',$TypeGroup.Gpus -replace '#DEVICESCLAYMODE#',$TypeGroup.GpusClayMode  -replace '#DEVICESETHMODE#',$TypeGroup.GpusETHMode -replace '#GROUPNAME#',$TypeGroup.Groupname -replace "#ETHSTMODE#",$Pool.EthStMode -replace "#DEVICESNSGMODE#",$TypeGroup.GpusNsgMode                   
                                                                }

                                                    $PoolPass=$Pool.Pass -replace '#WORKERNAME#',$WorkerName2
                                                    $PoolUser=$Pool.User -replace '#WORKERNAME#',$WorkerName2
                                            
                                                #Adjust pool price by pool defined factor
                                                    $PoolProfitFactor=[double](get_config_variable ("POOLPROFITFACTOR_"+$Pool.name))
                                                    if ($PoolProfitFactor -eq "") { $PoolProfitFactor=1}

                                                #select correct price by mode        
                                                    if ($MiningMode -eq 'Automatic24h') {$Price = [double]$Pool.Price24h * $PoolProfitFactor}
                                                    else {$Price = [double]$Pool.Price * $PoolProfitFactor}
                                                
                                                #Search for dualmining pool   
                                                    if ($Miner.Dualmining) {
                                                          #Adjust pool dual price by pool defined factor
                                                          $PoolProfitFactorDual=[double](get_config_variable ("POOLPROFITFACTOR_"+$PoolDual.name))
                                                             if ($PoolProfitFactorDual -eq "") { $PoolProfitFactorDual=1}

                                                           #search dual pool and select correct price by mode   
                                                               if ($MiningMode -eq 'Automatic24h')   {
                                                                    $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price24h -Descending| Select-Object -First 1
                                                                    $PriceDual=[double]$PoolDual.Price24h * $PoolProfitFactor
                                                                }   

                                                                else {
                                                                    $PoolDual = $Pools |where-object Algorithm -eq $AlgoNameDual | sort-object price -Descending| Select-Object -First 1
                                                                    $PriceDual=[double]$PoolDual.Price * $PoolProfitFactor
                                                                 }


                                                            #Replace wildcards patterns
                                                                 $WorkerName3=$WorkerName2+'D'
                                                                 $PoolPassDual=$PoolDual.Pass -replace '#WORKERNAME#',$WorkerName3
                                                                 $PoolUserDual=$PoolDual.user -replace '#WORKERNAME#',$WorkerName3

                                                                 $Arguments = $Arguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolUserDual -replace '#PASSWORDDUAL#',$PoolPassDual  -replace '#ALGORITHMDUAL#',$AlgonameDual -replace '#WORKERNAME#',$WorkerName3 
                                                                 if ($Miner.PatternConfigFile -ne $null) {
                                                                                     $ConfigFileArguments = $ConfigFileArguments -replace '#PORTDUAL#',$PoolDual.Port -replace '#SERVERDUAL#',$PoolDual.Host  -replace '#PROTOCOLDUAL#',$PoolDual.Protocol -replace '#LOGINDUAL#',$PoolUserDual -replace '#PASSWORDDUAL#',$PoolPassDual -replace '#ALGORITHMDUAL#' -replace '#WORKERNAME#',$WorkerName3 
                                                                                     }


                                                       }


                                                #Subminer are variations of miner that not need to relaunch
                                                #Creates a "subminer" object for each PL
                                                    $Subminers=@()
                                                    Foreach ($PowerLimit in ($TypeGroup.PowerLimits -split ',')) { #always exists as least a power limit 0 
                                                                $Hrs = Get_Hashrates -algorithm $Algorithms -minername $Minerfile.basename  -GroupName $TypeGroup.GroupName  -PowerLimit $PowerLimit -AlgoLabel  $AlgoLabel | Where-Object {$_.TimeSinceStartInterval -gt ($_.BenchmarkintervalTime * 0.66)}
                                                                $PowerValue=[double]($Hrs | measure-object -property Power -average).average
                                                                $HashrateValue=[double]($Hrs | measure-object -property Speed -average).average
                                                                $HashrateValueDual=[double]($Hrs | measure-object -property SpeedDual -average).average

                                                                
                                                                #calculates revenue
                                                                $SubMinerRevenue =  [double]($HashrateValue * $Price)
                                                                $SubMinerRevenueDual = [Double]([double]$HashrateValueDual * $PriceDual)
                                                                        
                                                                
                                                                #apply fee to revenues
                                                                if ([double]$Miner.Fee -gt 0) { #MinerFee
                                                                        $SubMinerRevenue-=($SubMinerRevenue*[double]$Miner.fee)
                                                                        $SubMinerRevenueDual-=($MinerRevenueDual*[double]$Miner.fee)
                                                                        } 
                                                                if ([double]$Pool.Fee -gt 0) {$SubMinerRevenue-=($SubMinerRevenue*[double]$Pool.fee)} #PoolFee
                                                                if ([double]$PoolDual.Fee -gt 0) {$SubMinerRevenueDual-=($MinerRevenueDual*[double]$PoolDual.fee)}      
                                                                            
                                                                $StatsHistory=Get_Stats -algorithm $Algorithms -minername $Minerfile.basename  -GroupName $TypeGroup.GroupName  -PowerLimit $PowerLimit -AlgoLabel  $AlgoLabel
                                                                $Stats=[pscustomobject]@{
                                                                                    BestTimes             = 0
                                                                                    BenchmarkedTimes      = 0
                                                                                    LastTimeActive        = [TimeSpan]0
                                                                                    ActivatedTimes        = 0
                                                                                    ActiveTime            = [TimeSpan]0
                                                                                    FailedTimes           =0
                                                                                    }
                                                                if ($StatsHistory -eq $null) {$StatsHistory=$stats}

                                                                if ($Subminers.count -eq 0 -or $Subminers[0].StatsHistory.BestTimes -gt 0) { #only add a subminer (distint from first if sometime first was best)
                                                                            $Subminers+=[pscustomObject]@{
                                                                                    Id                    = $Subminers.count
                                                                                    Best                  = $False       
                                                                                    BestBySwitch          = ""
                                                                                    Hashrate              = $HashrateValue
                                                                                    HashrateDual          = $HashrateValueDual
                                                                                    NeedBenchmark         = if ($HashrateValue -eq 0 -or ($AlgorithmDual -ne $null -and $HashrateValueDual -eq 0)) {$true} else {$False}
                                                                                    PowerAvg              = $PowerValue
                                                                                    PowerLimit            = [int]$PowerLimit
                                                                                    PowerLive             = 0
                                                                                    Profits               = (($SubMinerRevenue + $SubMinerRevenueDual)* $localBTCvalue) - ($ElectricityCostValue*($PowerValue*24)/1000) #Profit is revenue less electricity cost, can separate profit in dual and non dual because electricity cost can be divided
                                                                                    ProfitsLive           = 0
                                                                                    Revenue               = $SubMinerRevenue
                                                                                    RevenueDual           = $SubMinerRevenueDual
                                                                                    RevenueLive           = 0
                                                                                    RevenueLiveDual       = 0
                                                                                    SpeedLive             = 0
                                                                                    SpeedLiveDual         = 0
                                                                                    SpeedReads            = if ($Hrs -ne $null) {[array]$Hrs} else {@()}
                                                                                    Status                = 'Idle'
                                                                                    Stats                 = $Stats
                                                                                    StatsHistory          = $StatsHistory
                                                                                    TimeSinceStartInterval= [TimeSpan]0              
                                                                            } 
                                                                        }
                                                          }   



                                                    $Miners += [pscustomobject] @{  
                                                                    AlgoLabel=$AlgoLabel
                                                                    Algorithm = $AlgoName
                                                                    AlgorithmDual = $AlgoNameDual
                                                                    Algorithms=$Algorithms
                                                                    API = $Miner.API
                                                                    Arguments=$Arguments
                                                                    Coin = $Pool.Info.tolower()
                                                                    CoinDual = $PoolDual.Info
                                                                    ConfigFileArguments = $ConfigFileArguments
                                                                    DualMining = $Miner.Dualmining
                                                                    ExtractionPath = $Miner.ExtractionPath
                                                                    GenerateConfigFile = $miner.GenerateConfigFile -replace '#GROUPNAME#',$TypeGroup.Groupname
                                                                    GpuGroup = $TypeGroup
                                                                    Host =$Pool.Host
                                                                    Location = $Pool.location
                                                                    MinerFee= if ($Miner.Fee -eq $null) {$null} else {[double]$Miner.fee}
                                                                    Name = $Minerfile.basename
                                                                    Path = $Miner.Path
                                                                    PoolAbbName = $Pool.AbbName
                                                                    PoolAbbNameDual = $PoolDual.AbbName
                                                                    PoolFee = if ($Pool.Fee -eq $null) {$null} else {[double]$Pool.fee}
                                                                    PoolName = $Pool.name
                                                                    PoolNameDual = $PoolDual.name
                                                                    PoolPass= $PoolPass
                                                                    PoolPrice=if ($MiningMode -eq 'Automatic24h') {[double]$Pool.Price24h} else {[double]$Pool.Price}
                                                                    PoolPriceDual=if ($MiningMode -eq 'Automatic24h') {[double]$PoolDual.Price24h} else {[double]$PoolDual.Price}
                                                                    PoolWorkers = $Pool.PoolWorkers
                                                                    PoolWorkersDual = $PoolDual.PoolWorkers
                                                                    Port = if (($Types |Where-object type -eq $TypeGroup.type).count -le 1 -and $DelayCloseMiners -eq 0) {$miner.ApiPort} else {$null}
                                                                    PrelaunchCommand = $Miner.PrelaunchCommand
                                                                    Subminers = $Subminers
                                                                    Symbol = $Pool.Symbol
                                                                    SymbolDual = $PoolDual.Symbol
                                                                    URI = $Miner.URI
                                                                    Username = $PoolUser
                                                                    UsernameDual = $PoolUserDual
                                                                    UsernameReal = ($PoolUser -split '\.')[0]
                                                                    UsernameRealDual = ($PoolUserDual -split '\.')[0]
                                                                    WalletMode=$Pool.WalletMode
                                                                    WalletSymbol = $Pool.WalletSymbol
                                                                    Workername= $WorkerName2
                                                                    WorkernameDual= $WorkerName3
                                                                    }
                                
                                                }    #dualmining                   
                                            }          
        
                                }  #end foreach pool


                                } #  end if types 

                        } # end Types loop 

                    } #end foreach algo
                } #end foreach miner
             

    Writelog ("Miners/Pools combinations detected: "+ [string]($Miners.count)+".........") $LogFile $true    
     
    #Launch download of miners    
    $Miners | where-object {$_.URI -ne $null -and $_.ExtractionPath -ne $null -and $_.Path -ne $null -and $_.URI -ne "" -and $_.ExtractionPath -ne "" -and $_.Path -ne ""} | Select-Object URI, ExtractionPath,Path -Unique | ForEach-Object {
                Start_Downloader -URI $_.URI  -ExtractionPath $_.ExtractionPath -Path $_.Path
            }
    
    ErrorsToLog $LogFile
    
    #Paint no miners message
    $Miners = $Miners | Where-Object {Test-Path $_.Path}
    if ($Miners.Count -eq 0) {Writelog "NO MINERS!" $LogFile $true ; EXIT}

    
    #Update the active miners list which is alive for  all execution time

    
     ForEach ($ActiveMiner in ($ActiveMiners|Sort-Object [int]id)) {   #Search existant miners to update data
                
                
                     $Miner = $miners | Where-Object {$_.Name -eq $ActiveMiner.Name -and 
                                $_.Coin -eq $ActiveMiner.Coin -and 
                                $_.Algorithm -eq$ActiveMiner.Algorithm -and  
                                $_.CoinDual -eq $ActiveMiner.CoinDual -and 
                                $_.AlgorithmDual -eq $ActiveMiner.AlgorithmDual -and 
                                $_.PoolAbbName -eq $ActiveMiner.PoolAbbName -and 
                                $_.Location -eq $ActiveMiner.Location -and 
                                $_.GpuGroup.Id -eq $ActiveMiner.GpuGroup.Id -and 
                                $_.AlgoLabel -eq $ActiveMiner.AlgoLabel }
                            


                   
                    if (($Miner | Measure-Object).count -gt 1) {Clear-Host; Writelog ("DUPLICATED ALGO "+$MINER.ALGORITHM+" ON "+$MINER.NAME) $LogFile $true ;EXIT}                 
                    
                    if ($Miner) { # we found that miner
                            $ActiveMiner.Arguments= $miner.Arguments
                            $ActiveMiner.PoolPrice = $Miner.PoolPrice
                            $ActiveMiner.PoolPriceDual = $Miner.PoolPriceDual
                            $ActiveMiner.PoolFee= $Miner.PoolFee
                            $ActiveMiner.PoolWorkers = $Miner.PoolWorkers
                            $ActiveMiner.IsValid=$true

                            foreach ($subminer in $miner.Subminers) {
                                if (($ActiveMiner.Subminers | where-object {$_.Id -eq $subminer.Id}).count -eq 0) {
                                    $Subminer | Add-Member IdF $ActiveMiner.Id
                                    $ActiveMiner.Subminers+=$Subminer
                                 }
                                else {
                                    $ActiveMiner.Subminers[$subminer.Id].Hashrate = $Subminer.Hashrate
                                    $ActiveMiner.Subminers[$subminer.Id].HashrateDual=$Subminer.HashrateDual
                                    $ActiveMiner.Subminers[$subminer.Id].NeedBenchmark=$Subminer.NeedBenchmark
                                    $ActiveMiner.Subminers[$subminer.Id].PowerAvg=$Subminer.PowerAvg
                                    $ActiveMiner.Subminers[$subminer.Id].Profits=$Subminer.Profits
                                    $ActiveMiner.Subminers[$subminer.Id].Revenue=$Subminer.Revenue
                                    $ActiveMiner.Subminers[$subminer.Id].RevenueDual=$Subminer.RevenueDual
                                    
                                }
                              }
                            
                            }

                     else {  #An existant miner is not found now
                            $ActiveMiner.IsValid=$false
                         
                            }       
                
                }

 

    ##Add new miners to list
    ForEach ($miner in $miners) {
                
                    $ActiveMiner = $ActiveMiners | Where-Object {$_.Name -eq $Miner.Name -and
                            $_.Coin -eq $Miner.Coin -and
                            $_.Algorithm -eq $Miner.Algorithm -and
                            $_.CoinDual -eq $Miner.CoinDual -and 
                            $_.AlgorithmDual -eq $Miner.AlgorithmDual -and
                            $_.PoolAbbName -eq $Miner.PoolAbbName -and
                            $_.Location -eq $Miner.Location -and
                            $_.GpuGroup.Id -eq $Miner.GpuGroup.Id -and
                            $_.AlgoLabel -eq $Miner.AlgoLabel}

                
                    if ($ActiveMiner -eq $null) {
                        
                        $Miner.SubMiners | Add-Member IdF $ActiveMiners.count

                        $ActiveMiners += [pscustomObject]@{
                            AlgoLabel            = $Miner.AlgoLabel
                            Algorithm            = $Miner.Algorithm
                            AlgorithmDual        = $Miner.AlgorithmDual
                            Algorithms           = $Miner.Algorithms
                            API                  = $Miner.API
                            Arguments            = $Miner.Arguments
                            ConsecutiveZeroSpeed = 0
                            Coin                 = $Miner.coin
                            CoinDual             = $Miner.CoinDual
                            ConfigFileArguments  = $Miner.ConfigFileArguments
                            DualMining           = $Miner.DualMining
                            GenerateConfigFile   = $Miner.GenerateConfigFile
                            GpuGroup             = $Miner.GpuGroup
                            Host                 = $Miner.Host
                            Id                   = $ActiveMiners.count
                            IsValid              = $true
                            Location             = $Miner.Location  
                            MinerFee             = $Miner.MinerFee                                                      
                            Name                 = $Miner.Name
                            Path                 = Convert-Path $Miner.Path
                            PoolAbbName          = $Miner.PoolAbbName
                            PoolFee              = $Miner.PoolFee
                            PoolName             = $Miner.PoolName
                            PoolNameDual         = $Miner.PoolNameDual
                            PoolPrice            = $Miner.PoolPrice
                            PoolPriceDual        = $Miner.PoolPriceDual
                            PoolWorkers          = $Miner.PoolWorkers
                            PoolHashrate         = $null
                            PoolHashrateDual     = $null
                            PoolPass             = $Miner.PoolPass
                            Port                 = $Miner.Port
                            PrelaunchCommand     = $Miner.PrelaunchCommand
                            Process              = $null
                            SubMiners            = $Miner.SubMiners
                            Symbol               = $Miner.Symbol
                            SymbolDual           = $Miner.SymbolDual    
                            Username             = $Miner.Username
                            UsernameDual         = $Miner.UsernameDual
                            UserNameReal         = $Miner.UserNameReal
                            UserNameRealDual     = $Miner.UserNameRealDual
                            WalletMode           = $Miner.WalletMode
                            WalletSymbol         = $Miner.WalletSymbol
                            Workername           = $Miner.Workername
                            WorkernameDual       = $Miner.WorkernameDual                            
                            

                        }
                
                }
            }

    

    Writelog ("Active Miners-pools: "+ [string]($ActiveMiners.count)+".........") $LogFile $true                

    ErrorsToLog $LogFile

    Writelog ("Pending benchmarks: "+ [string](($ActiveMiners.subminers | where-object NeedBenchmark -eq $true).count)+".........") $LogFile $true                

    if ($DetailedLog) {$ActiveMiners.subminers| foreach-object {Writelog ([string] $_.Idf+'-'+[string]$_.Id+','+$ActiveMiners[$_.idf].gpugroup.groupname+','+$ActiveMiners[$_.idf].IsValid+', PL'+[string]$_.PowerLimit+','+$_.Status+','+$ActiveMiners[$_.idf].name+','+$ActiveMiners[$_.idf].algorithms+','+$ActiveMiners[$_.idf].Coin+','+[string]($ActiveMiners[$_.idf].process.id)) $LogFile $false}}

    #For each type, select most profitable miner, not benchmarked has priority, only new miner is lauched if new profit is greater than old by percenttoswitch
    #This section changes subminer 
    foreach ($Type in $Types) {

        

        #look for last roud best
            $Candidates = $ActiveMiners | Where-Object {$_.GpuGroup.Id -eq $Type.Id}
            $BestLast = $Candidates.subminers | Where-Object {$_.Status -eq "Running" -or $_.Status -eq 'PendingCancellation'}
            if ($BestLast -ne $null) {
                $ProfitLast=$BestLast.profits
                $BestLastLogMsg=$ActiveMiners[$BestLast.IdF].name+"/"+$ActiveMiners[$BestLast.IdF].Algorithms+'/'+$ActiveMiners[$BestLast.IdF].Coin+" with Power Limit "+[string]$BestLast.PowerLimit+" (id "+[string]$BestLast.IdF+"-"+[string]$BestLast.Id+") for group "+$Type.groupname
                } 
            else {
                    $ProfitLast=0
                }
            
        #check if must cancell miner/algo/coin combo
            if ($BestLast.Status -eq 'PendingCancellation') {
                $A=($ActiveMiners[$BestLast.IdF].subminers.stats.FailedTimes | Measure-Object -sum ).sum
                if (($ActiveMiners[$BestLast.IdF].subminers.stats.FailedTimes | Measure-Object -sum).sum -ge 2) {
                                    $ActiveMiners[$BestLast.IdF].subminers |foreach-object{$_.Status='Cancelled'}
                                    Writelog ("Detected more than 3 fails,cancelling combination  for $BestNowLogMsg") $LogFile $true           
                                }
                }

        #look for best for next round
            $Candidates = $ActiveMiners | Where-Object {$_.GpuGroup.Id -eq $Type.Id -and $_.IsValid}
            $BestNow = $Candidates.Subminers |where-object Status -ne 'Cancelled' | Sort-Object -Descending {if ($_.NeedBenchmark) {1} else {0}}, Profits,{$Activeminers[$_.IdF].Algorithm},{$Activeminers[$_.IdF].PoolPrice},PowerLimit | Select-Object -First 1 
            $BestNowLogMsg=$ActiveMiners[$BestNow.IdF].name+"/"+$ActiveMiners[$BestNow.IdF].Algorithms+'/'+$ActiveMiners[$BestNow.IdF].Coin+" with Power Limit "+[string]$BestNow.PowerLimit+" (id "+[string]$BestNow.IdF+"-"+[string]$BestNow.Id+") for group "+$Type.groupname
            $ProfitNow=$BestNow.Profits

            if ($BestNow.NeedBenchmark -eq $false) {
                    $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].Stats.BestTimes++
                    $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].StatsHistory.BestTimes++
                    }
            else 
                {$NextInterval=$BenchmarkintervalTime}


        Writelog ("$BestNowLogMsg is the best combination for gpu group, last was id "+[string]$BestLast.Idf+"-"+[string]$BestLast.Id) $LogFile $true            
        
        
        if ($BestLast.IdF -ne $BestNow.IdF -or  $BestLast.Id -ne $BestNow.Id -or $BestLast.Status -eq 'PendingCancellation' -or $BestLast.Status -eq 'Cancelled') { #something changes or some miner error

        if ($BestLast.IdF -eq $BestNow.IdF -and  $BestLast.Id -ne $BestNow.Id) {              #Must launch other subminer
                            if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type='NVIDIA' -and $BestNow.PowerLimit -gt 0) {set_Nvidia_Powerlimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].GpuGroup.gpus}
                            if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type='AMD'-and $BestNow.PowerLimit -gt 0){}
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].best=$true
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].Status= "Running"
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].Stats.LastTimeActive = get-date
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].StatsHistory.LastTimeActive = get-date
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0
                            $ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].best=$false
                            Switch ($BestLast.Status) {
                                    "Running"{$ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].Status="Iddle"}
                                    "PendingCancellation"{$ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].Status="Failed"}
                                    "Cancelled"{$ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].Status="Cancelled"}
                                     }

                            Writelog ("$BestNowLogMsg - Marked as running, changed Power Limit from "+$BestLast.PowerLimit) $LogFile $true           

                        }
                elseif ($ProfitNow -gt ($ProfitLast *(1+($PercentToSwitch2/100))) -or $BestNow.NeedBenchmark -or $BestLast.Status -eq 'PendingCancellation'  -or $BestLast.Status -eq 'Cancelled' -or $BestLast -eq $null) { #Must launch other miner and stop actual
               
                            #Stop old
                            if ($BestLast -ne $null) {
                                    
                                    WriteLog ("Killing in "+[string]$DelayCloseMiners+" seconds $BestLastLogMsg with system process id "+[string]$ActiveMiners[$BestLast.IdF].Process.Id) $LogFile

                                    if ($Bestnow.NeedBenchmark -or $DelayCloseMiners -eq 0 -or $BestLast.Status -eq 'PendingCancellation') { #inmediate kill
                                        Kill_Process $ActiveMiners[$BestLast.IdF].Process
                                        }
                                    else { #delayed kill
                                        
                                        $code={ 
                                                param($ProcessId,$DelaySeconds)
                                                Start-Sleep $DelaySeconds
                                                if ((get-process |Where-Object id -eq 11484) -ne $ProcessId ) {Stop-Process $ProcessId -force -wa SilentlyContinue -ea SilentlyContinue }
                                               }
                                        Start-Job  -ScriptBlock $Code -ArgumentList ($ActiveMiners[$BestLast.IdF].Process.Id),$DelayCloseMiners
                                        

                                        }
    
                                    $ActiveMiners[$BestLast.IdF].Process=$null
                                    $ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].best=$false
                                    Switch ($BestLast.Status) {
                                        "Running" {$ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].Status="Iddle"}
                                        "PendingCancellation" {$ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].Status="Failed"}
                                        "Cancelled" {$ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].Status="Cancelled"}
                                          }
                                 
                                   }
                            #Start New
                            if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type -eq 'NVIDIA' -and $BestNow.PowerLimit -gt 0) {set_Nvidia_Powerlimit $BestNow.PowerLimit $ActiveMiners[$BestNow.IdF].GpuGroup.gpus}
                            if ($ActiveMiners[$BestNow.IdF].GpuGroup.Type -eq 'AMD'-and $BestNow.PowerLimit -gt 0){}
                            
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].best=$true

                            if ($ActiveMiners[$BestNow.IdF].Port -eq $null) { $ActiveMiners[$BestNow.IdF].Port = get_next_free_port (Get-Random -minimum 2000 -maximum 48000)} 
                            $ActiveMiners[$BestNow.IdF].Arguments = $ActiveMiners[$BestNow.IdF].Arguments -replace '#APIPORT#',$ActiveMiners[$BestNow.IdF].Port
                            $ActiveMiners[$BestNow.IdF].ConfigFileArguments = $ActiveMiners[$BestNow.IdF].ConfigFileArguments -replace '#APIPORT#',$ActiveMiners[$BestNow.IdF].Port
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].stats.ActivatedTimes++
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].statsHistory.ActivatedTimes++
                            if ($ActiveMiners[$BestNow.IdF].GenerateConfigFile -ne "") {$ActiveMiners[$BestNow.IdF].ConfigFileArguments | Set-Content ($ActiveMiners[$BestNow.IdF].GenerateConfigFile)}
                            if ($ActiveMiners[$BestNow.IdF].PrelaunchCommand -ne $null -and $ActiveMiners[$BestNow.IdF].PrelaunchCommand -ne "") {Start-Process -FilePath $ActiveMiners[$BestNow.IdF].PrelaunchCommand}                                             #run prelaunch command

                            if ($ActiveMiners[$BestNow.IdF].Api -eq "Wrapper") {$ActiveMiners[$BestNow.IdF].Process = Start-Process -FilePath "PowerShell" -ArgumentList "-executionpolicy bypass -command . '$(Convert-Path ".\Wrapper.ps1")' -ControllerProcessID $PID -Id '$($ActiveMiners[$BestNow.IdF].Port)' -FilePath '$($ActiveMiners[$BestNow.IdF].Path)' -ArgumentList '$($ActiveMiners[$BestNow.IdF].Arguments)' -WorkingDirectory '$(Split-Path $ActiveMiners[$BestNow.IdF].Path)'" -PassThru}
                            else {$ActiveMiners[$BestNow.IdF].Process = Start_SubProcess -FilePath $ActiveMiners[$BestNow.IdF].Path -ArgumentList $ActiveMiners[$BestNow.IdF].Arguments -WorkingDirectory (Split-Path $ActiveMiners[$BestNow.IdF].Path)}
                            
  
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].Status =  "Running"
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].Stats.LastTimeActive = get-date
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].StatsHistory.LastTimeActive = get-date
                            $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].TimeSinceStartInterval = [TimeSpan]0
                            Writelog ("Started System process Id "+[string]($ActiveMiners[$BestNow.IdF].Process.Id)+" for $BestNowLogMsg --> "+$ActiveMiners[$BestNow.IdF].Path+" "+$ActiveMiners[$BestNow.IdF].Arguments) $LogFile $false
                            
        
                        } 
                else {
                            #Must mantain last miner by switch
                            $ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].best=$true
                            if ($Profitlast -lt $ProfitNow) {
                                        $ActiveMiners[$BestLast.IdF].Subminers[$BestLast.Id].BestBySwitch= "*"
                                        Writelog ("$BestNowLogMsg continue mining due to @@percenttoswitch value") $LogFile $true                
                                    }
                        }

            }


        Set_Stats -algorithm $ActiveMiners[$BestNow.IdF].Algorithms -minername $ActiveMiners[$BestNow.IdF].Name -GroupName $ActiveMiners[$BestNow.IdF].GpuGroup.GroupName -AlgoLabel $ActiveMiners[$BestNow.IdF].AlgoLabel -Powerlimit $BestNow.PowerLimit -value  $ActiveMiners[$BestNow.IdF].Subminers[$BestNow.Id].StatsHistory

        }

    ErrorsToLog $LogFile
   

    $FirstLoopExecution=$True   
    $LoopStarttime=Get-Date
 

    ErrorsToLog $LogFile
    $SwitchLoop = 0

    Clear-Host;$repaintScreen=$true

    while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush


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

    #loop to update info and check if miner is running, exit loop is forced inside                        
    While (1 -eq 1) 
        {

        

        if  ($SwitchLoop -gt 10) {$SwitchLoop=0} #reduces 10-1 ratio of execution 
        $SwitchLoop++ 
        

        $ExitLoop = $false
        

        $cards=get_gpu_information $Types

           #############################################################

                            
            #Check Live Speed and record benchmark if necessary
            $ActiveMiners.subminers | Where-Object Best -eq $true | ForEach-Object {
                if ($FirstLoopExecution -and $_.NeedBenchmark) {$_.Stats.BenchmarkedTimes++;$_.StatsHistory.BenchmarkedTimes++}
                
                $_.SpeedLive = 0
                $_.SpeedLiveDual = 0
                $_.ProfitsLive = 0
                $_.RevenueLive = 0
                $_.RevenueLiveDual = 0
                $Miner_HashRates = $null
                
                $_.Stats.ActiveTime += (get-date) - $_.Stats.LastTimeActive 
                $Miner_HashRates = Get_Live_HashRate $ActiveMiners[$_.IdF].API $ActiveMiners[$_.IdF].Port 

                if ($Miner_HashRates -ne $null){
                    
                    $_.SpeedLive = [double]($Miner_HashRates[0])
                    $_.SpeedLiveDual = [double]($Miner_HashRates[1])
                    
                    $_.RevenueLive = $_.SpeedLive * $ActiveMiners[$_.IdF].PoolPrice 
                    $_.RevenueLiveDual = $_.SpeedLiveDual * $ActiveMiners[$_.IdF].PoolPriceDual
             
                    $_.PowerLive = ($Cards | Where-Object gpugroup -eq ($ActiveMiners[$_.IdF].GpuGroup.GroupName) | Measure-Object -property power_draw -sum).sum

                    $_.Profitslive= (($_.RevenueLive + $_.RevenueLiveDual)* $LocalBTCvalue) - ($ElectricityCostValue*($_.PowerLive*24)/1000)


                    $_.TimeSinceStartInterval =(get-date) - $_.Stats.LastTimeActive 
                    $TimeSinceStartInterval= $_.TimeSinceStartInterval.seconds + ($_.TimeSinceStartInterval.minutes*60) + ($_.TimeSinceStartInterval.hours*3600)

                    if ($_.SpeedLive -gt 0) {

                            if ($_.SpeedReads.count -le 10 -or $_.Speedlive -le ((($_.SpeedReads.speed |Measure-Object -average).average)*100)){ #for avoid miners peaks recording
                                                if (($_.SpeedReads).count -eq 0) {$_.SpeedReads=@()}
                                                $_.SpeedReads += [PSCustomObject]@{
                                                                Speed = $_.SpeedLive 
                                                                SpeedDual=  $_.SpeedLiveDual
                                                                GpuActivity = ($Cards | Where-Object gpugroup -eq ($ActiveMiners[$_.IdF].GpuGroup.GroupName) | Measure-Object -property utilization_gpu -average).average
                                                                Power = $_.PowerLive
                                                                Date= (get-date).DateTime
                                                                Benchmarking =$_.NeedBenchmark
                                                                TimeSinceStartInterval = $TimeSinceStartInterval
                                                                BenchmarkintervalTime = $BenchmarkintervalTime
                                                               }
                                                
                                                }

                            

                            if ($_.SpeedReads.count -gt 2000) {$_.SpeedReads = $_.SpeedReads[1..($_.SpeedReads.length-1)]} #if array is greateher than  X delete first element    

                            if ((get_config_variable "LIVESTATSUPDATE") -eq "ENABLED" -or $_.NeedBenchmark) {
                                                    Set_Hashrates -algorithm $ActiveMiners[$_.IdF].Algorithms -minername $ActiveMiners[$_.IdF].Name -GroupName $ActiveMiners[$_.IdF].GpuGroup.GroupName -AlgoLabel $ActiveMiners[$_.IdF].AlgoLabel -Powerlimit $_.PowerLimit -value  $_.SpeedReads
                                                }
                            
                        } 
                    
                    }          

                    #WATCHDOG

                    $GpuActivityAverage = ($Cards | Where-Object gpugroup -eq ($ActiveMiners[$_.IdF].GpuGroup.GroupName) | Measure-Object -property utilization_gpu -average).average

                    if ($ActiveMiners[$_.IdF].Process -eq $null -or $ActiveMiners[$_.IdF].Process.HasExited -or ($GpuActivityAverage -le 40 -and $TimeSinceStartInterval -gt 100) ) {
                            $ExitLoop = $true
                            $_.Status = "PendingCancellation"
                            $_.Stats.FailedTimes++
                            $_.StatsHistory.FailedTimes++
                            writelog ("Detected miner error "+$ActiveMiners[$_.IdF].name+"/"+$ActiveMiners[$_.IdF].Algorithm+" (id "+$_.IdF+'-'+$_.Id+") --> "+$ActiveMiners[$_.IdF].Path+" "+$ActiveMiners[$_.IdF].Arguments) $logfile $false
                        }
                    
          } #End For each
       


        #############################################################

        #display interval
            $TimetoNextInterval= NEW-TIMESPAN (Get-Date) ($LoopStarttime.AddSeconds($NextInterval))
            $TimetoNextIntervalSeconds=($TimetoNextInterval.Hours*3600)+($TimetoNextInterval.Minutes*60)+$TimetoNextInterval.Seconds
            if ($TimetoNextIntervalSeconds -lt 0) {$TimetoNextIntervalSeconds = 0}

            set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width-31) 2
            "|  Next Interval:  $TimetoNextIntervalSeconds secs..." | Out-host
            set_ConsolePosition 0 0

        #display header     
        Print_Horizontal_line  "MegaMiner 6.0"  
        Print_Horizontal_line
        "  (E)nd Interval   (P)rofits    (C)urrent    (H)istory    (W)allets    (S)tats" | Out-host
      
        #display donation message
        
            if ($DonationInterval) {" THIS INTERVAL YOU ARE DONATING, YOU CAN INCREASE OR DECREASE DONATION ON CONFIG.TXT, THANK YOU FOR YOUR SUPPORT !!!!"}

        #display current mining info

        Print_Horizontal_line
        
        if ($SwitchLoop=1) { 

                                writelog ($ActiveMiners | Where-Object Status -eq 'Running'| select-object id,process.Id,groupname,name,poolabbname,Algorithm,AlgorithmDual,SpeedLive,ProfitsLive,location,port,arguments |ConvertTo-Json) $logfile $false
                                
                                #To get pool speed
                                        $PoolsSpeed=@()
                                        
                                        $ActiveMiners | Where-Object Status -eq 'Running' |select-object PoolName,UserNameReal,WalletSymbol,coin,Workername -unique | ForEach-Object { 
                                                            $Info=[PSCustomObject]@{
                                                                                User= $_.UsernameReal
                                                                                PoolName=$_.Poolname
                                                                                ApiKey = get_config_variable ("APIKEY_"+$_.PoolName)
                                                                                Symbol = $_.WalletSymbol
                                                                                Coin= $_.coin
                                                                                Workername= $_.Workername
                                                                                }
                                                            $PoolsSpeed+=Get_Pools -Querymode "speed" -PoolsFilterList $_.Poolname -Info $Info
                                                            }

                                        #Dual miners

                                        $ActiveMiners | Where-Object Status -eq 'Running' |Where-object PoolNameDual -ne $null |select-object PoolnameDual,UserNameRealDual,WalletSymbol,coinDual,Workername -unique | ForEach-Object { 
                                                            $Info=[PSCustomObject]@{
                                                                                User= $_.UsernameRealDual
                                                                                PoolName=$_.PoolnameDual
                                                                                ApiKey = get_config_variable ("APIKEY_"+$_.PoolnameDual)
                                                                                Symbol = $_.WalletSymbol
                                                                                Coin= $_.coinDual
                                                                                Workername= $_.WorkernameDual
                                                                                }
                                                            $PoolsSpeed+=Get_Pools -Querymode "speed" -PoolsFilterList $_.PoolnameDual -Info $Info
                                            }      
                                            
                                            
                                        $ActiveMiners | Where-Object Status -eq 'Running' | ForEach-Object { 
                                                        
                                                        $Me=$PoolsSpeed | where-object PoolName -eq $_.Poolname | where-object Workername -eq $_.Workername |select-object HashRate,PoolName,Workername -first 1

                                                        $_.PoolHashrate=$Me.Hashrate
                                                        

                                                        $MeDual=$PoolsSpeed | where-object PoolName -eq $_.PoolnameDual | where-object Workername -eq $_.WorkernameDual |select-object HashRate,PoolName,Workername -first 1

                                                        $_.PoolHashrateDual=$MeDual.Hashrate
                                                        
                                                        
                                                        }


                            }

    
  
          $ActiveMiners.Subminers | Where-Object Status -eq 'Running'| Sort-Object GroupId -Descending | Format-Table -Wrap  (
             # @{Label = "Id"; Expression = {$_.IdF}; Align = 'right'},   
              @{Label = "GroupName"; Expression ={$ActiveMiners[$_.IdF].GpuGroup.GroupName}}, 
              @{Label = "MMPowLmt"; Expression ={if ($_.PowerLimit -gt 0) {$_.PowerLimit}};align='right'}, 

              @{Label = "LocalSpeed"; Expression = {if  ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null) {(ConvertTo_Hash  ($_.SpeedLive))+'/s'} else {(ConvertTo_Hash  ($_.SpeedLive))+'/s|'+(ConvertTo_Hash ($_.SpeedLiveDual))+'/s'} }; Align = 'right'},     
              @{Label = "Rev./Day"; Expression = {($_.RevenueLive.tostring("n5"))+'btc'}; Align = 'right'}, 
              @{Label = "Rev./Day"; Expression = {((($_.RevenueLive + $_.RevenueLiveDual) *  $localBTCvalue ).tostring("n2"))+$LocalSymbol}; Align = 'right'}, 
              @{Label = "Profit/Day"; Expression = {(($_.ProfitsLive).tostring("n2"))+$LocalSymbol}; Align = 'right'}, 
              @{Label = "Algorithm"; Expression = {if ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null) {$ActiveMiners[$_.IdF].Algorithm+$ActiveMiners[$_.IdF].AlgoLabel+$_.BestBySwitch} else  {$ActiveMiners[$_.IdF].Algorithm+$ActiveMiners[$_.IdF].AlgoLabel+ '|' + $ActiveMiners[$_.IdF].AlgorithmDual+$_.BestBySwitch}}},   
              @{Label = "Coin"; Expression = {if ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null) {$ActiveMiners[$_.IdF].Coin} else  {($ActiveMiners[$_.IdF].Coin)+ '|' + ($ActiveMiners[$_.IdF].CoinDual)}}},   
              @{Label = "Miner"; Expression = {$ActiveMiners[$_.IdF].Name}}, 
              @{Label = "Power"; Expression = {[string]$_.PowerLive+'W'};Align = 'right'}, 
              @{Label = "Efficiency"; Expression = {if ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null -and $_.PowerLive -gt 0) {(ConvertTo_Hash  ($_.SpeedLive/$_.PowerLive))+'/W'} else {$null} }; Align = 'right'},     
              
              @{Label = "PoolSpeed"; Expression = {if ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null) {(ConvertTo_Hash  ($ActiveMiners[$_.IdF].PoolHashrate))+'/s'} else {(ConvertTo_Hash  ($ActiveMiners[$_.IdF].PoolHashrate))+'/s|'+(ConvertTo_Hash ($ActiveMiners[$_.IdF].PoolHashrateDual))+'/s'} }; Align = 'right'},     
              @{Label = "Workers"; Expression = {if ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null)  {$ActiveMiners[$_.IdF].PoolWorkers} else {[string]$ActiveMiners[$_.IdF].PoolWorkers+'|'+[string]$ActiveMiners[$_.IdF].PoolWorkersDual}}; Align = 'right'},
              @{Label = "Loc."; Expression = {$ActiveMiners[$_.IdF].Location}},
              @{Label = "Pool"; Expression = {if ($ActiveMiners[$_.IdF].AlgorithmDual -eq $null)  {$ActiveMiners[$_.IdF].PoolAbbName} else {$ActiveMiners[$_.IdF].PoolAbbName+'|'+$ActiveMiners[$_.IdF].PoolAbbNameDual}}  }

<#
              @{Label = "PoolPrice"; Expression = {$ActiveMiners[$_.IdF].PoolPrice}}

              @{Label = "BmkT"; Expression = {$_.BenchmarkedTimes}},
              @{Label = "FailT"; Expression = {$_.FailedTimes}},
              @{Label = "Nbmk"; Expression = {$_.NeedBenchmark}},
              
              @{Label = "Port"; Expression = {$ActiveMiners[$_.IdF].Port}}
 #>             


          ) | Out-Host


         


        $XToWrite=[ref]0
        $YToWrite=[ref]0      
        Get_ConsolePosition ([ref]$XToWrite) ([ref]$YToWrite)  
        $YToWriteMessages=$YToWrite+1
        $YToWriteData=$YToWrite+2
        Remove-Variable XToWrite
        Remove-Variable YToWrite                          


        #############################################################
        Print_Horizontal_line $Screen.ToUpper()


        #display profits screen
        if ($Screen -eq "Profits" -and $repaintScreen) {
        
                   set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width-37) $YToWriteMessages
                    
                    
                    "(B)est Miners/All       (T)op "+[string]$InitialProfitsScreenLimit+"/All" | Out-Host

                    
                    set_ConsolePosition 0 $YToWriteData

                    $ProfitMiners=@()
                    if ($ShowBestMinersOnly) {
                        foreach ($subminer in ($ActiveMiners.Subminers|Where-Object Status -ne "Cancelled")) {
                                    $Candidates = $ActiveMiners | Where-Object {$_.IsValid -and $_.GpuGroup.Id -eq $ActiveMiners[$Subminer.Idf].GpuGroup.Id -and $_.Algorithm -eq $ActiveMiners[$Subminer.Idf].Algorithm -and $_.AlgorithmDual -eq $ActiveMiners[$Subminer.Idf].AlgorithmDual }
                                    $ExistsBest = $Candidates.Subminers | Where-Object {$_.Profits -gt $subminer.Profits}
                                    if ($ExistsBest -eq $null -and $Subminer.Profits -eq 0) { 
                                            $ExistsBest = $Candidates | Where-Object {$_.hashrate -gt $Subminer.hashrate}
                                            }
                                    if ($ExistsBest -eq $null -or $Subminer.NeedBenchmark -eq $true) {
                                                $ProfitMiner = $ActiveMiners[$Subminer.Idf] |Select-Object * -ExcludeProperty Subminers
                                                $ProfitMiner| add-member Subminer $Subminer
                                                $ProfitMiner| add-member GroupName $ProfitMiner.GpuGroup.Groupname #needed for groupby 
                                                $ProfitMiner| add-member NeedBenchmark $ProfitMiner.subminer.NeedBenchmark #needed for sort 
                                                $ProfitMiner| add-member Profits $ProfitMiner.subminer.Profits #needed for sort 
                                                $ProfitMiners +=  $ProfitMiner
                                            }
                                    }
                           }
                    else 
                           { $ActiveMiners.Subminers | Where-Object {$_.IsValid} | ForEach-Object {
                                        $ProfitMiner = $ActiveMiners[$_.Idf] |Select-Object * -ExcludeProperty Subminers
                                        $ProfitMiner| add-member Subminer $_
                                        $ProfitMiner| add-member GroupName $ProfitMiner.GpuGroup.Groupname #needed for groupby 
                                        $ProfitMiner| add-member NeedBenchmark $ProfitMiner.subminer.NeedBenchmark #needed for sort 
                                        $ProfitMiner| add-member Profits $ProfitMiner.subminer.Profits #needed for sort 
                                        $ProfitMiners +=  $ProfitMiner
                                }
                            }
 
                    $ProfitMiners2=@()
                    ForEach ($TypeId in $types.Id) {
                            $inserted=1
                            $ProfitMiners  | Where-Object {$_.GpuGroup.Id -eq $TypeId} | Sort-Object -Descending GroupName,NeedBenchmark,Profits | ForEach-Object {
                                if ($inserted -le $ProfitsScreenLimit) {$ProfitMiners2+=$_ ; $inserted++} #this can be done with select-object -first but then memory leak happens, ¿why?
                                    }
                        }
 
    
                        



                    #Display profits  information
                    $ProfitMiners2 | Sort-Object @{expression="GroupName";Ascending=$true}, @{expression="NeedBenchmark";Descending=$true}, @{expression="Profits";Descending=$true} | Format-Table (
                        #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},   
                        @{Label = "Algorithm"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Algorithm+$_.AlgoLabel} else  {$_.Algorithm+$_.AlgoLabel+ '|' + $_.AlgorithmDual}}},   
                        @{Label = "Coin"; Expression = {if ($_.AlgorithmDual -eq $null) {$_.Coin} else  {($_.Symbol)+ '|' + ($_.SymbolDual)}}},   
                        @{Label = "Miner"; Expression = {$_.Name}}, 
                        @{Label = "PowLmt"; Expression ={if ($_.Subminer.PowerLimit -gt 0) {$_.Subminer.PowerLimit}};align='right'}, 
                        @{Label = "StatsSpeed"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo_Hash  ($_.Subminer.hashrate))+'/s'} else {(ConvertTo_Hash  ($_.Subminer.hashrate))+'/s|'+(ConvertTo_Hash ($_.Subminer.hashratedual))+'/s'}}; Align = 'right'}, 
                        @{Label = "PowerAvg"; Expression = {if ($_.Subminer.NeedBenchmark) {"Benchmarking"} else {$_.Subminer.PowerAvg.tostring("n0")}}; Align = 'right'}, 
                        @{Label = "Efficiency"; Expression = {if  ($_.AlgorithmDual -eq $null) {(ConvertTo_Hash  ($_.Subminer.hashrate/$_.Subminer.PowerAvg))+'/W'} else {$null} }; Align = 'right'},    
                        @{Label = "Rev./Day"; Expression = {(($_.Subminer.Revenue+$_.Subminer.RenevueDual).tostring("n5"))+"btc" } ; Align = 'right'},
                        @{Label = "Rev./Day"; Expression = {((($_.Subminer.Revenue+$_.Subminer.RenevueDual) * [double]$localBTCvalue ).tostring("n2"))+$LocalSymbol } ; Align = 'right'},
                        @{Label = "Profit/Day"; Expression = {if ($_.Subminer.NeedBenchmark) {"Benchmarking"} else {($_.Subminer.Profits).tostring("n2")+$LocalSymbol}}; Align = 'right'}, 
                        @{Label = "PoolFee"; Expression = {if ($_.PoolFee -ne $null) {"{0:P2}" -f $_.PoolFee}}; Align = 'right'},
                        @{Label = "MinerFee"; Expression = {if ($_.MinerFee -ne $null) {"{0:P2}" -f $_.MinerFee}}; Align = 'right'},
                        @{Label = "Pool"; Expression = {$_.PoolAbbName}},
                        @{Label = "Location"; Expression = {$_.Location}}

                      

                    )  -GroupBy GroupName |  Out-Host

                       
                    Remove-Variable ProfitMiners
                    Remove-Variable ProfitMiners2
                    
                   
                }
  

                
                          
        if ($Screen -eq "Current") {
                    

                    set_ConsolePosition 0 $YToWriteData

                    # Display devices info
                    print_gpu_information $Cards
                }
                                    
        
        #############################################################        
                    
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
                                    

                                    
                                    $ApiKey = get_config_variable ("APIKEY_"+$_.PoolName)
                                
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
                            
                            set_ConsolePosition 0 $YToWriteMessages
                            "Start Time: $StartTime                                                                                                                                (U)pdate" | Out-Host
                            set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width-10) $YToWriteMessages
                            "(U)pdate" | Out-Host
                            "" | Out-Host 
                                                    

                            $WalletStatus | where-object Balance -gt 0 | Sort-Object  @{expression="poolname";Ascending=$true},@{expression="balance";Descending=$true} | Format-Table -Wrap -groupby poolname (
                                @{Label = "Coin"; Expression = {if ($_.WalletSymbol -ne $null) {$_.WalletSymbol} else {$_.wallet}}}, 
                                @{Label = "Balance"; Expression = {$_.balance.tostring("n5")}; Align = 'right'},
                                @{Label = "IncFromStart"; Expression = {($_.balance - $_.BalanceAtStart).tostring("n5")}; Align = 'right'}
                                
                            ) | Out-Host
                        

                            $Pools  | where-object WalletMode -eq 'NONE' | Select-Object PoolName -unique | ForEach-Object {
                                "NO EXISTS API FOR POOL "+$_.PoolName+" - NO WALLETS CHECK" | Out-host 
                                }  

                            $repaintScreen=$false
                            }
                        
                
            }

            
        #############################################################    
        if ($Screen -eq "History" -and $repaintScreen) {                        

                    set_ConsolePosition 0 $YToWriteMessages
                    "Running Mode: $MiningMode" |out-host

                    set_ConsolePosition 0 $YToWriteData

                    #Display activated miners list
                    $ActiveMiners.Subminers | Where-Object {$_.Stats.ActivatedTimes -GT 0} | Sort-Object -Descending {$_.Stats.LastTimeActive}  | Format-Table -Wrap  (
                        #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},   
                        @{Label = "LastTime"; Expression = {$_.Stats.LastTimeActive}}, 
                        @{Label = "GroupName"; Expression = {$Activeminers[$_.Idf].GpuGroup.GroupName}}, 
                        @{Label = "PowLmt";Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}}, 
                        @{Label = "Command"; Expression = {$($Activeminers[$_.Idf].Path.TrimStart((Convert-Path ".\"))) +" "+$($Activeminers[$_.Idf].Arguments)}}
                    )  | Out-Host


                    $repaintScreen=$false
                }

        #############################################################
  
        if ($Screen -eq "Stats" -and $repaintScreen) {                        

                    set_ConsolePosition 0 $YToWriteMessages
                    "Start Time: $StartTime"
                    
                    set_ConsolePosition ($Host.UI.RawUI.WindowSize.Width-30) $YToWriteMessages

                    "Running Mode: $MiningMode" | Out-Host


                    set_ConsolePosition 0 $YToWriteData

                    #Display activated miners list
                    $ActiveMiners.subminers | Where-Object {$_.stats.ActivatedTimes -GT 0} | Sort-Object -Descending {$_.stats.ActivatedTimes} |  Format-Table -Wrap (
                        #@{Label = "Id"; Expression = {$_.Id}; Align = 'right'},   
                        @{Label = "GpuGroup"; Expression = {$ActiveMiners[$_.Idf].GpuGroup.GroupName}},
                        @{Label = "Algorithm"; Expression = {if ($ActiveMiners[$_.Idf].AlgorithmDual -eq $null) {$ActiveMiners[$_.Idf].Algorithm} else  {$ActiveMiners[$_.Idf].Algorithm+ '|' + $ActiveMiners[$_.Idf].AlgorithmDual}}},       
                        @{Label = "Pool"; Expression = {$ActiveMiners[$_.Idf].PoolAbbName}},
                        @{Label = "Miner"; Expression = {$ActiveMiners[$_.Idf].Name}}, 
                        @{Label = "PwLmt"; Expression = {if ($_.PowerLimit -gt 0) {$_.PowerLimit}}}, 
                        @{Label = "Launch"; Expression = {$_.stats.ActivatedTimes}},
                        @{Label = "Time"; Expression = {[string][int](($_.stats.Activetime.days*60*24)+($_.stats.Activetime.Hours *60)+$_.stats.Activetime.minutes)+" min"}},
                        @{Label = "Best"; Expression = {$_.stats.Besttimes}},
                        @{Label = "Last"; Expression = {$_.stats.LastTimeActive}} 
                    ) | Out-Host


                    $repaintScreen=$false
                }
                
                $FirstLoopExecution=$False

                #Loop for reading key and wait
             
                $KeyPressed=Timed_ReadKb 3 ('P','C','H','E','W','U','T','B','S','X')
            
                switch ($KeyPressed){
                    'P' {$Screen='PROFITS'}
                    'C' {$Screen='CURRENT'}
                    'H' {$Screen='HISTORY'}
                    'S' {$Screen='STATS'}
                    'E' {$ExitLoop=$true}
                    'W' {$Screen='WALLETS'}
                    'U' {if ($Screen -eq "WALLETS") {$WalletsUpdate=$null}}
                    'T' {if ($Screen -eq "PROFITS") {if ($ProfitsScreenLimit -eq $InitialProfitsScreenLimit) {$ProfitsScreenLimit=1000} else {$ProfitsScreenLimit=$InitialProfitsScreenLimit}}}
                    'B' {if ($Screen -eq "PROFITS") {if ($ShowBestMinersOnly -eq $true) {$ShowBestMinersOnly=$false} else {$ShowBestMinersOnly=$true}}}
                    'X' {set_WindowSize 185 60}
                    }

                if ($KeyPressed) {Clear-host;$repaintScreen=$true}
           
                if (((Get-Date) -ge ($LoopStarttime.AddSeconds($NextInterval)))  ) { #If time of interval has over, exit of main loop
                                #If last interval was benchmark and no speed detected mark as failed
                                $ActiveMiners.subminers | Where-Object Best -eq $true | ForEach-Object {
                                    if ($_.NeedBenchmark -and $_.Speedreads.count -eq 0) {
                                        $_.Status='PendingCancellation'
                                        writelog ("No speed detected while benchmark "+$ActiveMiners[$_.IdF].name+"/"+$ActiveMiners[$_.IdF].Algorithm+" (id "+$ActiveMiners[$_.IdF].Id+")") $logfile $false
                                        }
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
