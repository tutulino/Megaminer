function Get-Live-HashRate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$API, 
        [Parameter(Mandatory = $true)]
        [Int]$Port, 
        [Parameter(Mandatory = $false)]
        [Object]$Parameters = @{} 
        #[Parameter(Mandatory = $false)]
        #[Bool]$Safe = $false
    )
    
    $Server = "localhost"
    
    $Multiplier = 1000
    #$Delta = 0.05
    #$Interval = 5
    #$HashRates = @()
    #$HashRates_Dual = @()

    try {
        switch ($API) {
            "xgminer" {
                $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
            
               
                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request.Substring($Request.IndexOf("{"), $Request.LastIndexOf("}") - $Request.IndexOf("{") + 1) -replace " ", "_" | ConvertFrom-Json

                    $HashRate = if ($Data.SUMMARY.HS_5s -ne $null) {[Double]$Data.SUMMARY.HS_5s * [Math]::Pow($Multiplier, 0)}
                    elseif ($Data.SUMMARY.KHS_5s -ne $null) {[Double]$Data.SUMMARY.KHS_5s * [Math]::Pow($Multiplier, 1)}
                    elseif ($Data.SUMMARY.MHS_5s -ne $null) {[Double]$Data.SUMMARY.MHS_5s * [Math]::Pow($Multiplier, 2)}
                    elseif ($Data.SUMMARY.GHS_5s -ne $null) {[Double]$Data.SUMMARY.GHS_5s * [Math]::Pow($Multiplier, 3)}
                    elseif ($Data.SUMMARY.THS_5s -ne $null) {[Double]$Data.SUMMARY.THS_5s * [Math]::Pow($Multiplier, 4)}
                    elseif ($Data.SUMMARY.PHS_5s -ne $null) {[Double]$Data.SUMMARY.PHS_5s * [Math]::Pow($Multiplier, 5)}

                    if ($HashRate -eq $null) {
                            $HashRate = if ($Data.SUMMARY.HS_av -ne $null) {[Double]$Data.SUMMARY.HS_av * [Math]::Pow($Multiplier, 0)}
                            elseif ($Data.SUMMARY.KHS_av -ne $null) {[Double]$Data.SUMMARY.KHS_av * [Math]::Pow($Multiplier, 1)}
                            elseif ($Data.SUMMARY.MHS_av -ne $null) {[Double]$Data.SUMMARY.MHS_av * [Math]::Pow($Multiplier, 2)}
                            elseif ($Data.SUMMARY.GHS_av -ne $null) {[Double]$Data.SUMMARY.GHS_av * [Math]::Pow($Multiplier, 3)}
                            elseif ($Data.SUMMARY.THS_av -ne $null) {[Double]$Data.SUMMARY.THS_av * [Math]::Pow($Multiplier, 4)}
                            elseif ($Data.SUMMARY.PHS_av -ne $null) {[Double]$Data.SUMMARY.PHS_av * [Math]::Pow($Multiplier, 5)}
                            }

            }
            "ccminer" {
                $Message = "summary"


                    $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                    $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                    $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                    $Writer.AutoFlush = $true

                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request -split ";" | ConvertFrom-StringData

                    $HashRate = if ([Double]$Data.KHS -ne 0 -or [Double]$Data.ACC -ne 0) {[Double]$Data.KHS * $Multiplier}

                       



            }
            "nicehashequihash" {
                $Message = "status"

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true


                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.result.speed_hps
                    
                    if ($HashRate -eq $null) {$HashRate = $Data.result.speed_sps}

            }
            "nicehash" {
                $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true


                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate = $Data.algorithms.workers.speed


            }
            "ewbf" {
                $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress

                $Client = New-Object System.Net.Sockets.TcpClient $server, $port
                $Writer = New-Object System.IO.StreamWriter $Client.GetStream()
                $Reader = New-Object System.IO.StreamReader $Client.GetStream()
                $Writer.AutoFlush = $true


                    $Writer.WriteLine($Message)
                    $Request = $Reader.ReadLine()

                    $Data = $Request | ConvertFrom-Json
                
                    $HashRate += [Double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
            }
            "claymore" {

                    $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
                    
                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                    
                    $HashRate = [double]$Data.result[2].Split(";")[0] * $Multiplier
                    $HashRate_Dual = [double]$Data.result[4].Split(";")[0] * $Multiplier




            }

            "claymoreZEC" {

                    $Request = Invoke-WebRequest "http://$($Server):$Port" -UseBasicParsing
					
                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                    
                    $HashRate = [double]$Data.result[2].Split(";")[0]
                    $HashRate_Dual = [double]$Data.result[4].Split(";")[0]

            }
	    
            "prospector" {
                    $Request = Invoke-WebRequest "http://$($Server):$Port/api/v0/hashrates" -UseBasicParsing
                    $Data = $Request | ConvertFrom-Json
                    $HashRate =  [Double]($Data.rate | Measure-Object -Sum).sum
                 }

            "fireice" {
                
                    $Request = Invoke-WebRequest "http://$($Server):$Port/h" -UseBasicParsing
                    
                    $Data = $Request.Content -split "</tr>" -match "total*" -split "<td>" -replace "<[^>]*>", ""
                    
                    $HashRate = $Data[1]
                    if ($HashRate -eq "") {$HashRate = $Data[2]}
                    if ($HashRate -eq "") {$HashRate = $Data[3]}

                    
            }
            "wrapper" {
                    $HashRate = ""
                    $HashRate = Get-Content ".\Wrapper_$Port.txt"
                    $HashRate =  $HashRate -replace ',','.'



                }
        }

        $HashRates = @()
        $HashRates += [double]$HashRate
        $HashRates += [double]$HashRate_Dual

        $HashRates
    }
    catch {
    }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function ConvertTo-Hash { 
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
         )

    
    $Return=switch ([math]::truncate([math]::log($Hash, [Math]::Pow(1000, 1)))) {
                0 {"{0:n2}  H" -f ($Hash / [Math]::Pow(1000, 0))}
                1 {"{0:n2} KH" -f ($Hash / [Math]::Pow(1000, 1))}
                2 {"{0:n2} MH" -f ($Hash / [Math]::Pow(1000, 2))}
                3 {"{0:n2} GH" -f ($Hash / [Math]::Pow(1000, 3))}
                4 {"{0:n2} TH" -f ($Hash / [Math]::Pow(1000, 4))}
                Default {"{0:n2} PH" -f ($Hash / [Math]::Pow(1000, 5))}
        }
    $Return
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get-Combination {
    param(
        [Parameter(Mandatory = $true)]
        [Array]$Value, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMax = $Value.Count, 
        [Parameter(Mandatory = $false)]
        [Int]$SizeMin = 1
    )

    $Combination = [PSCustomObject]@{}

    for ($i = 0; $i -lt $Value.Count; $i++) {
        $Combination | Add-Member @{[Math]::Pow(2, $i) = $Value[$i]}
    }

    $Combination_Keys = $Combination | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

    for ($i = $SizeMin; $i -le $SizeMax; $i++) {
        $x = [Math]::Pow(2, $i) - 1

        while ($x -le [Math]::Pow(2, $Value.Count) - 1) {
            [PSCustomObject]@{Combination = $Combination_Keys | Where-Object {$_ -band $x} | ForEach-Object {$Combination.$_}}
            $smallest = ($x -band - $x)
            $ripple = $x + $smallest
            $new_smallest = ($ripple -band - $ripple)
            $ones = (($new_smallest / $smallest) -shr 1) - 1
            $x = $ripple -bor $ones
        }
    }
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start-SubProcess {
    param(
        [Parameter(Mandatory = $true)]
        [String]$FilePath, 
        [Parameter(Mandatory = $false)]
        [String]$ArgumentList = "", 
        [Parameter(Mandatory = $false)]
        [String]$WorkingDirectory = ""
    )

    $Job = Start-Job -ArgumentList $PID, $FilePath, $ArgumentList, $WorkingDirectory {
        param($ControllerProcessID, $FilePath, $ArgumentList, $WorkingDirectory)

        $ControllerProcess = Get-Process -Id $ControllerProcessID
        if ($ControllerProcess -eq $null) {return}

        $ProcessParam = @{}
        $ProcessParam.Add("FilePath", $FilePath)
        $ProcessParam.Add("WindowStyle", 'Minimized')
        if ($ArgumentList -ne "") {$ProcessParam.Add("ArgumentList", $ArgumentList)}
        if ($WorkingDirectory -ne "") {$ProcessParam.Add("WorkingDirectory", $WorkingDirectory)}
        $Process = Start-Process @ProcessParam -PassThru
        if ($Process -eq $null) {
            [PSCustomObject]@{ProcessId = $null}
            return        
        }

        [PSCustomObject]@{ProcessId = $Process.Id; ProcessHandle = $Process.Handle}
        
        $ControllerProcess.Handle | Out-Null
        $Process.Handle | Out-Null

        do {if ($ControllerProcess.WaitForExit(1000)) {$Process.CloseMainWindow() | Out-Null}}
        while ($Process.HasExited -eq $false)
    }

    do {Start-Sleep 1; $JobOutput = Receive-Job $Job}
    while ($JobOutput -eq $null)

    $Process = Get-Process | Where-Object Id -EQ $JobOutput.ProcessId
    $Process.Handle | Out-Null
    $Process
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Expand-WebRequest {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Uri, 
        [Parameter(Mandatory = $true)]
        [String]$Path
    )

    
    $DestinationFolder = $PSScriptRoot + $Path.Substring(1)
    $FileName = ([IO.FileInfo](Split-Path $Uri -Leaf)).name
    $FilePath = $PSScriptRoot +'\'+$Filename


    if (Test-Path $FileName) {Remove-Item $FileName}


    Invoke-WebRequest $Uri -OutFile $FileName -UseBasicParsing
    
    $Command='x "'+$FilePath+'" -o"'+$DestinationFolder+'" -y -spe'
    Start-Process "7z" $Command -Wait

    if (Test-Path $FileName) {Remove-Item $FileName}
    
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get-Pools {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Querymode = 'core', 
        [Parameter(Mandatory = $false)]
        [array]$PoolsFilterList=$null,
        #[array]$PoolsFilterList='Mining_pool_hub',
        [Parameter(Mandatory = $false)]
        [array]$CoinFilterList,
        #[array]$CoinFilterList = ('GroestlCoin','Feathercoin','zclassic'),
        [Parameter(Mandatory = $false)]
        [string]$Location=$null,
        #[string]$Location='EUROPE'
        [Parameter(Mandatory = $false)]
        [array]$AlgoFilterList,
        [Parameter(Mandatory = $false)]
        [pscustomobject]$Info
        )
        #in detail mode returns a line for each pool/algo/coin combination, in info mode returns a line for pool



        $PoolsFolderContent= Get-ChildItem ($PSScriptRoot+'\pools') | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}
        
            $ChildItems=@()

            $PoolsFolderContent | ForEach-Object {
                                    $Name = $_.BaseName
                                    $SharedFile="$PSScriptRoot\$Name.tmp"
                                    if (Test-Path $SharedFile) {Remove-Item $SharedFile}
                                    &$_.FullName -Querymode $Querymode -Info $Info
                                    if (Test-Path $SharedFile) {
                                            $Content=Get-Content $SharedFile | ConvertFrom-Json 
                                            Remove-Item $SharedFile
                                        }
                                    $Content | ForEach-Object {$ChildItems +=[PSCustomObject]@{Name = $Name; Content = $_}}
                                    }
                                
         

            $AllPools = $ChildItems | ForEach-Object {if ($_.content -ne $null) {$_.Content | Add-Member @{Name = $_.Name} -PassThru}}
               

            $AllPools | Add-Member LocationPriority 9999

            #Apply filters
            $AllPools2=@()
            if ($Querymode -eq "core" -or $Querymode -eq "menu" ){
                        foreach ($Pool in $AllPools){
                                #must have wallet
                                if ($Pool.user -ne $null) {
                                    
                                    #must be in algo filter list or no list
                                    if ($AlgoFilterList -ne $null) {$Algofilter = compare-object $AlgoFilterList $Pool.Algorithm -IncludeEqual -ExcludeDifferent}
                                    if (($AlgoFilterList.count -eq 0) -or ($Algofilter -ne $null)){
                                       
                                            #must be in coin filter list or no list
                                            if ($CoinFilterList -ne $null) {$Coinfilter = compare-object $CoinFilterList $Pool.info -IncludeEqual -ExcludeDifferent}
                                            if (($CoinFilterList.count -eq 0) -or ($Coinfilter -ne $null)){
                                                if ($pool.location -eq $Location) {$Pool.LocationPriority=1}
                                                if (($pool.location -eq 'EU') -and ($location -eq 'US')) {$Pool.LocationPriority=2}
                                                if (($pool.location -eq 'EUROPE') -and ($location -eq 'US')) {$Pool.LocationPriority=2}
                                                if ($pool.location -eq 'US' -and $location -eq 'EUROPE') {$Pool.LocationPriority=2}
                                                if ($pool.location -eq 'US' -and $location -eq 'EU') {$Pool.LocationPriority=2}
                                                if ($Pool.Info -eq $null) {$Pool.info=''}
                                                $AllPools2+=$Pool
                                                }
                                        
                                    }
                        }
                        
                        }
                        #Insert by priority of location
                        if ($Location -ne "") {
                                $Return=@()
                                $AllPools2 | Sort-Object Info,Algorithm,LocationPriority | ForEach-Object {
                                    $Ex = $Return | Where-Object Info -eq $_.Info | Where-Object Algorithm -eq $_.Algorithm
                                    if ($Ex.count -eq 0) {$Return += $_}
                                    }
                            }
                        else {
                             $Return=$AllPools2
                            }
                }
            else 
             { $Return= $AllPools }


    
    Remove-variable ChildItems
    Remove-variable AllPools
    Remove-variable AllPools2
    
    $Return     
    

 }

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

 
function Get-Best-Hashrate-Algo {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm
    )


    $Pattern="*_"+$Algorithm+"_HashRate.txt"

    $Besthashrate=0

    Get-ChildItem ($PSScriptRoot+"\Stats")  | Where-Object pschildname -like $Pattern | foreach {
              $Content= $_ | Get-Content | ConvertFrom-Json
              if ($Content.week -gt $Besthashrate) {
                      $Besthashrate=$Content.week
                      $Miner= ($_.pschildname -split '_')[0]
                      }
            $Return=[pscustomobject]@{
                            Hashrate=$Besthashrate
                            Miner=$Miner
                          }

      }

    $Return
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get-Algo-Divisor {
      param(
        [Parameter(Mandatory = $true)]
        [String]$Algo
            )

                    $Divisor = 1000000000
                    
                    switch($Algo)
                    {
                        "skein"{$Divisor *= 10}
                        "equihash"{$Divisor /= 1000}
                        "blake2s"{$Divisor *= 1000}
                        "blakecoin"{$Divisor *= 1000}
                        "decred"{$Divisor *= 1000}
                        "blake14r"{$Divisor *= 1000}
                    }

    $Divisor
     }


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set-ConsolePosition ([int]$x,[int]$y) { 
        # Get current cursor position and store away 
        $position=$host.ui.rawui.cursorposition 
        # Store new X Co-ordinate away 
        $position.x=$x
        $position.y=$y
        # Place modified location back to $HOST 
        $host.ui.rawui.cursorposition=$position
        remove-variable position
        }


function Get-ConsolePosition ([ref]$x,[ref]$y) { 

    $position=$host.ui.rawui.cursorposition 
    $x.value=$position.x
    $y.value=$position.y
    remove-variable position

}
        

   
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set-WindowSize ([int]$Width,[int]$Height) { 
    #zero not change this axis
    $pshost = Get-Host
    $psWindow = $pshost.UI.RawUI
    $newSize = $psWindow.WindowSize
    if ($Width -ne 0) {$newSize.Width =$Width}
    if ($Height -ne 0) {$newSize.Height =$Height}
    $psWindow.WindowSize= $newSize
}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get-algo-unified-name ([string]$Algo) {

    $Result=$Algo
    switch ($Algo){
            "sib" {$Result="x11gost"}
            "Blake (14r)" {$Result="Blake14r"} 
            "Blake (2b)" {$Result="Blake2b"} 
            "decred" {$Result="Blake14r"}
            "Lyra2RE2" {$Result="lyra2v2"}
            "Lyra2REv2" {$Result="lyra2v2"}
            "sia" {$Result="Blake2b"}
            "myr-gr" {$Result="Myriad-Groestl"}
            "myriadgroestl" {$Result="Myriad-Groestl"}
            "daggerhashimoto" {$Result="Ethash"}
            "dagger" {$Result="Ethash"}
            "hashimoto" {$Result="Ethash"}
            }        
     $Result       

}

 #************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

                    
function get-coin-unified-name ([string]$Coin) {

    $Result = $Coin
    switch –wildcard  ($Coin){
            "Myriadcoin-*" {$Result="Myriad"}
            "Myriad-*" {$Result="Myriad"}
            "Dgb-*" {$Result="Digibyte"}
            "Digibyte-*" {$Result="Digibyte"}
            "Verge-*" {$Result="Verge"}
            "EthereumClassic" {$Result="Ethereum-Classic"}
            }      
          
     $Result       

}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Get-Hashrate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $false)]
        [String]$AlgorithmDual
    )

	$DirPath = $PSScriptRoot + "\Stats"
    $BasenameSplit = $MinerName, $Algorithm, $AlgorithmDual, "HashRate" | Where-Object { $_ } | Select -Unique
    $Basename = $BasenameSplit -join "_"
    $Filename = $Basename + ".txt"
    
    try {
        $Hashrates = Get-ChildItem ($DirPath) | Where-Object pschildname -eq $Filename | Get-Content | ConvertFrom-Json
        ## Backward Compatible
        if ($Hashrates -is [double]) {
            $Hashrate = $Hashrates
            $Hashrates = @()
            $Hashrates += $Hashrate
        }
    } catch {
        $Hashrates = @()
    }
    
	$Hashrates
}
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set-Hashrate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [double]$Value,
        [Parameter(Mandatory = $false)]
        [String]$AlgorithmDual,
        [Parameter(Mandatory = $false)]
        [double]$ValueDual
        
    )

	$DirPath = $PSScriptRoot + "\Stats"
    $BasenameSplit = $MinerName, $Algorithm, $AlgorithmDual, "HashRate" | Where-Object { $_ } | Select -Unique
    $Basename = $BasenameSplit -join "_"
    $Filename = $Basename + ".txt"
    $Path = $DirPath + "\" + $Filename

	$Hashrates = $Value, $ValueDual
    $Hashrates | Convertto-Json | Set-Content -Path $Path
	
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Start-Downloader {
    param(
    [Parameter(Mandatory = $true)]
    [String]$URI,
    [Parameter(Mandatory = $true)]
    [String]$ExtractionPath,
    [Parameter(Mandatory = $true)]
    [String]$Path
     )


        if (-not (Test-Path $Path)) {
            try {


                if ($URI -and (Split-Path $URI -Leaf) -eq (Split-Path $Path -Leaf)) {
                    New-Item (Split-Path $Path) -ItemType "Directory" | Out-Null
                    Invoke-WebRequest $URI -OutFile $Path -UseBasicParsing -ErrorAction Stop
                }
                else {
                    Clear-Host
                    Write-Host -BackgroundColor green -ForegroundColor Black "Downloading....$($URI)"
                    Expand-WebRequest $URI $ExtractionPath -ErrorAction Stop
                }
            }
            catch {
                
                if ($URI) {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot download $($Path) distributed at $($URI). "}
                else {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot download $($Path). "}
                
                
                if ($Path_Old) {
                    if (Test-Path (Split-Path $Path_New)) {(Split-Path $Path_New) | Remove-Item -Recurse -Force}
                    (Split-Path $Path_Old) | Copy-Item -Destination (Split-Path $Path_New) -Recurse -Force
                }
                else {
                    if ($URI) {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot find $($Path) distributed at $($URI). "}
                    else {Write-Host -BackgroundColor Yellow -ForegroundColor Black "Cannot find $($Path). "}
                }
            }
        }
    

    
}




#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function clear-log{

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.txt"
    $LastWrite = $Now.AddDays(-$Days)

    $Files = Get-Childitem $TargetFolder -Include $Extension -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}

    $Files |ForEach-Object {Remove-Item $_.fullname}

}
