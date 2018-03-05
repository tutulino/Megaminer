#--------------optional parameters...to allow direct launch without prompt to user
param(
    [Parameter(Mandatory = $false)]
    [String]$MiningMode = $null
    #[String]$MiningMode = "FARM MONITORING"
    ,
    [Parameter(Mandatory = $false)]
    [string]$PoolsName =$null
    #[string]$PoolsName = "YIIMP"
    ,
    [Parameter(Mandatory = $false)]
    [string]$CoinsName =$null
    #[string]$CoinsName ="decred"
)

. .\Include.ps1

#check parameters

if (($MiningMode -eq "MANUAL") -and ($PoolsName.count -gt 1)) { write-host ONLY ONE POOL CAN BE SELECTED ON MANUAL MODE}


#--------------Load config.txt file

$Location= get_config_variable "LOCATION"
$FarmRigs= get_config_variable "FARMRIGS" 



$CoinsWallets=@{} #needed for anonymous pools load
((Get-Content config.txt | Where-Object {$_ -like '@@WALLET_*=*'}) -replace '@@WALLET_*=*','').TrimEnd() | ForEach-Object {$CoinsWallets.add(($_ -split "=")[0],($_ -split "=")[1])}


$SelectedOption=""

#-----------------Ask user for mode to mining AUTO/MANUAL to use, if a pool is indicated in parameters no prompt

Clear-Host

Print_Horizontal_line ""
Print_Horizontal_line "SELECT MODE TO MINE"
Print_Horizontal_line ""


$Modes=@()
$Modes += [pscustomobject]@{"Option"=0;"Mode"='AUTOMATIC';"Explanation"='Not necesary choose coin to mine, program choose more profitable coin based on pool´s current statistics'}
$Modes += [pscustomobject]@{"Option"=1;"Mode"='AUTOMATIC24h';"Explanation"='Same as Automatic mode but based on pools/WTM reported last 24h profit'}
$Modes += [pscustomobject]@{"Option"=2;"Mode"='MANUAL';"Explanation"='You select coin to mine'}

if ($FarmRigs -ne $null -and $FarmRigs -ne "" )  {$Modes += [pscustomobject]@{"Option"=3;"Mode"='FARM MONITORING';"Explanation"='I only want to see my rigs state'}}

$Modes | Format-Table Option,Mode,Explanation  | out-host

If ($MiningMode -eq "")  
    {
     $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
     $MiningMode=$Modes[$SelectedOption].Mode
     write-host SELECTED OPTION::$MiningMode
    }
    else 
    {write-host SELECTED BY PARAMETER OPTION::$MiningMode}


if ($MiningMode -ne "FARM MONITORING") {
                    #-----------------Ask user for pool/s to use, if a pool is indicated in parameters no prompt

                        switch ($MiningMode) {
                                "Automatic" {$Pools=Get_Pools -Querymode "Info" | Where-Object ActiveOnAutomaticMode -eq $true | sort name }
                                "Automatic24h" {$Pools=Get_Pools -Querymode "Info" | Where-Object ActiveOnAutomatic24hMode -eq $true | sort name }
                                "Manual" {$Pools=Get_Pools -Querymode "Info" | Where-Object ActiveOnManualMode -eq $true | sort name }
                                }

                    $Pools | Add-Member Option "0"
                    $counter=0
                    $Pools | ForEach-Object {
                            $_.Option=$counter
                            $counter++}


                    if ($MiningMode -ne "Manual"){
                            $Pools += [pscustomobject]@{"Disclaimer"="";"ActiveOnManualMode"=$false;"ActiveOnAutomaticMode"=$true;"ActiveOnAutomatic24hMode"=$true;"name"='ALL POOLS';"option"=99}}


                    #Clear-Host
                    Print_Horizontal_line ""
                    Print_Horizontal_line "SELECT POOL/S  TO MINE"
                    Print_Horizontal_line ""
                    

                    $Pools | where-object name -ne "Donationpool" | Format-Table Option,name,rewardtype,disclaimer | out-host



                    If (($PoolsName -eq "") -or ($PoolsName -eq $null))
                        {


                        if ($MiningMode -eq "manual"){
                            $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
                            while ($SelectedOption -like '*,*') {
                                        $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
                                        }
                            }
                        if ($MiningMode -ne "Manual"){
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



                                        $CoinsPool=Get_Pools -Querymode "Menu" -PoolsFilterList $PoolsName -location $Location |Select-Object info,symbol,algorithm,Workers,PoolHashRate,Blocks_24h -unique | Sort-Object info

                                        $CoinsPool | Add-Member Option "0"

                                        $Counter = 0
                                        $CoinsPool | ForEach-Object {
                                                                    $_.Option=$Counter                                                                
                                                                    $counter++
                                    
                                                                    }
                                        
                                        Clear-Host
                                        Print_Horizontal_line ""
                                        Print_Horizontal_line "SELECT COIN/ALGO TO MINE"
                                        Print_Horizontal_line ""
                                        

                                        #Only one pool is allowed in manual mode at this point

                                        $CoinsPool  | Format-Table -Wrap (
                                                    @{Label = "Opt."; Expression = {$_.Option}; Align = 'right'} ,
                                                    @{Label = "Name"; Expression = {$_.info.toupper()}; Align = 'left'} ,
                                                    @{Label = "Symbol"; Expression = {$_.symbol}; Align = 'left'},   
                                                    @{Label = "Algorithm"; Expression = {$_.algorithm.tolower()}; Align = 'left'}
                                                    )  | out-host        
                                

                                        $SelectedOption = Read-Host -Prompt 'SELECT ONE OPTION:'
                                        while ($SelectedOption -like '*,*') {
                                                                            $SelectedOption = Read-Host -Prompt 'SELECT ONLY ONE OPTION:'
                                                                            }
                                        $CoinsName = $CoinsPool[$SelectedOption].Info -replace '_',',' #for dual mining
                                        $AlgosName = $CoinsPool[$SelectedOption].Algorithm -replace '_',',' #for dual mining

                                        write-host SELECTED OPTION:: $CoinsName - $AlgosName
                                    }
                                else 
                                    {

                                        write-host SELECTED BY PARAMETER :: $CoinsName
                                    }                    

                            
                                }

                                
                    #-----------------Launch Command
                                $command="./core.ps1 -MiningMode $MiningMode -PoolsName $PoolsName"
                                if ($MiningMode -eq "manual"){$command+=" -Coinsname $CoinsName -Algorithm $AlgosName"} 

                                #write-host $command
                                Invoke-Expression $command

 }


else {  #FARM MONITORING
 
  $Host.UI.RawUI.WindowTitle = "MM Farm Monitor"


  while ($true)  {
           
           $Requests=@()
           $FarmRigs -split ',' | ForEach-Object {
                        $uri="http://"+$_
                        $Request=[pscustomobject]@{}
                        try {
                            $Request=Invoke-restmethod $uri -timeoutsec 5 -UseDefaultCredential
                            #$Request=Invoke-WebRequest $uri -timeoutsec 5 -UseDefaultCredential
                            $Request=$Request | ConvertFrom-Json
                             } catch {}
                        if ( $Request -eq $null) { $Request=[pscustomobject]@{}}
                        $Request |add-member Server $_
                        $Requests+=$Request
                        }         
            try {set_WindowSize 185 60} catch {}
            Clear-Host   
            
            Print_Horizontal_line ("MEGAMINER FARM MONITOR ("+(get-date).tostring("g")+")")
            "" | out-host
            
            $Requests | ForEach-Object {
                        
                        Print_Horizontal_line ($_.Server+"("+$_.config.workername+")")

                        if ($_.config.workername -ne $null) {

                            "Mode: "+$_.params.MiningMode+"       Pool/s: " + ($_.params.pools -join ",")+"         Release: "+$_.Release |out-host

                            $_.Activeminers | Format-Table (
                                    @{Label = "GroupName"; Expression = {$_.GroupName}},   
                                    @{Label = "MMPowLmt"; Expression = {$_.MMPowLmt} ; Align = 'right'},   
                                    @{Label = "LocalSpeed"; Expression = {$_.LocalSpeed} ; Align = 'right'},   
                                    @{Label = "mbtc/Day"; Expression = {$_.mbtc_Day} ; Align = 'right'},   
                                    @{Label = "Rev/Day"; Expression = {$_.Rev_Day} ; Align = 'right'},   
                                    @{Label = "Profit/Day"; Expression = {$_.Profit_Day} ; Align = 'right'},   
                                    @{Label = "Algorithm"; Expression = {$_.Algorithm}},   
                                    @{Label = "Coin"; Expression = {$_.Coin}},   
                                    @{Label = "Miner"; Expression = {$_.Miner}},   
                                    @{Label = "Power"; Expression = {$_.Power} ; Align = 'right'},   
                                    @{Label = "Efficiency"; Expression = {$_.EfficiencyH} ; Align = 'right'},   
                                    @{Label = "Efficiency"; Expression = {$_.EfficiencyW}  ; Align = 'right'},
                                    @{Label = "Pool"; Expression = {$_.Pool}}
                                    ) | out-host
                             }    
                    else {   
                        "" | out-host
                        "NOT RESPONDING...." | out-host}
                        "" | out-host
                     }

           start-sleep 20


     }


}
