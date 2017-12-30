
Add-Type -Path .\OpenCL\*.cs



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Get_ComputerStats {
       [cmdletbinding()]
          $avg = Get-WmiObject win32_processor | Measure-Object -property LoadPercentage -Average | ForEach-Object {$_.Average}
          $mem = Get-WmiObject win32_operatingsystem | Foreach-Object {"{0:N2}" -f ((($_.TotalVisibleMemorySize - $_.FreePhysicalMemory)*100)/ $_.TotalVisibleMemorySize)}
          $memV = Get-WmiObject win32_operatingsystem | Foreach-Object {"{0:N2}" -f ((($_.TotalVirtualMemorySize - $_.FreeVirtualMemory)*100)/ $_.TotalVirtualMemorySize)}
          $free = Get-WmiObject Win32_Volume -Filter "DriveLetter = 'C:'" | Foreach-Object {"{0:N2}" -f (($_.FreeSpace / $_.Capacity)*100)}
          $nprocs = (Get-Process).count
          $Conns = (Get-NetTCPConnection).count

          "AverageCpu = $avg % | MemoryUsage = $mem % | VirtualMemoryUsage = $memV % |  PercentCFree = $free % | Processes = $nprocs | Connections = $Conns"

    }



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
function ErrorsTolog {

    param(
          [Parameter(Mandatory = $true)]
          [string]$LogFile
          )

    for ($i=0;$i -lt $error.count;$i++) {
        $Msg="###### ERROR ##### "+[string]($error[$i])+' '+$error[$i].ScriptStackTrace
        Writelog $msg $LogFile

    }
    $error.clear()
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function replace_foreach_gpu {

      param(
            [Parameter(Mandatory = $true)]
            [string]$ConfigFileArguments,
            [Parameter(Mandatory = $true)]
            [string]$Gpus
            )



        #search string to replace

        $ConfigFileArguments= $ConfigFileArguments  -replace  [Environment]::NewLine,"#NL#" #replace carriage return for Select-string search (only search in each line)

        $Match=$ConfigFileArguments | Select-String -Pattern "#FOR_EACH_GPU#.*?#END_FOR_EACH_GPU#"
        if ($Match -ne $null){

            $Match.Matches |ForEach-Object {

            $Base=$_.value -replace "#FOR_EACH_GPU#","" -replace "#END_FOR_EACH_GPU#",""
            $Final=""
            $Gpus -split ',' |foreach-object {$Final+=($base -replace "#GPUID#",$_)}
            $ConfigFileArguments=$ConfigFileArguments.Substring(0,$_.index)+$final+$ConfigFileArguments.Substring($_.index+$_.Length,$ConfigFileArguments.Length-($_.index+$_.Length))
            }
        }


        $Match=$ConfigFileArguments | Select-String -Pattern "#REMOVE_LAST_CHARACTER#"
        if ($Match -ne $null){

            $Match.Matches |ForEach-Object {

            $ConfigFileArguments=$ConfigFileArguments.Substring(0,$_.index-1)+$ConfigFileArguments.Substring($_.index+$_.Length,$ConfigFileArguments.Length-($_.index+$_.Length))

            }
        }

        $ConfigFileArguments= $ConfigFileArguments  -replace "#NL#", [Environment]::NewLine #replace carriage return for Select-string search (only search in each line)

        $ConfigFileArguments
}
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_next_free_port {

  param(
        [Parameter(Mandatory = $true)]
        [int]$LastUsedPort
        )


    if ($LastUsedPort -lt 2000) {$FreePort=2001} else {$FreePort=$LastUsedPort+1} #not allow use of <2000 ports

    while (Query_TCPPort -Server 127.0.0.1 -Port $FreePort -timeout 100) {$FreePort=$LastUsedPort+1}

    $FreePort


    }


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Query_TCPPort {
    param([string]$Server, [int]$Port, [int]$Timeout)

        $Connection = New-Object System.Net.Sockets.TCPClient



        try {
            $Connection.SendTimeout = $Timeout
            $Connection.ReceiveTimeout = $Timeout
            $Connection.Connect($Server,$Port)  | out-Null
            $Connection.Close
            $Connection.Dispose
            return $true #port is occupied
            }

        catch  {
            $Error.Remove($error[$Error.Count-1])
            return $false  #port is free
            }
    }

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Kill_ProcessId {

    param(
        [Parameter(Mandatory = $true)]
        [int]$ProcessId
        )

    try {
        #$_.Process.CloseMainWindow() | Out-Null
        Stop-Process $ProcessId -force -wa SilentlyContinue -ea SilentlyContinue
    } catch {}
}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function get_gpu_information {
    [cmdletbinding()]


    $Cards=@()
    $GpuId=0

    #NVIDIA
    invoke-expression "./bin/nvidia-smi.exe --query-gpu=gpu_name,utilization.gpu,utilization.memory,temperature.gpu,power.draw,power.limit,fan.speed,pstate,clocks.current.graphics,clocks.current.memory  --format=csv,noheader"  | ForEach-Object {

                $SMIresultSplit = $_ -split (",")

                $Cards +=[pscustomObject]@{
                            Type               ='NVIDIA'
                            GpuId              = $GpuId
                            gpu_name           = $SMIresultSplit[0]
                            utilization_gpu    = $SMIresultSplit[1]
                            utilization_memory = $SMIresultSplit[2]
                            temperature_gpu    = $SMIresultSplit[3]
                            power_draw         = $SMIresultSplit[4]
                            power_limit        = $SMIresultSplit[5]
                            FanSpeed           = $SMIresultSplit[6]
                            pstate             = $SMIresultSplit[7]
                            ClockGpu           = $SMIresultSplit[8]
                            ClockMem           = $SMIresultSplit[9]
                        }
                $GpuId+=1

        }


    #AMD
        $AMDPlatform=[OpenCl.Platform]::GetPlatformIDs() | Where-Object vendor -like "*Advanced Micro Devices*"
        if ($AMDPlatform -ne $null) {
            $ADLDevices=@()


                  #ADL
                    # invoke-expression "./OverdriveN"  | ForEach-Object {

                    #   $AdlResultSplit = $_ -split (",")

                    #   $AdlDevices +=[pscustomObject]@{
                    #               GpuId              = $AdlResultSplit[0]
                    #               FanSpeed           = [string][int]([int]$AdlResultSplit[1] /[int]$AdlResultSplit[2]*100) + " %"
                    #               ClockGpu           = [string]([int]($AdlResultSplit[3] / 100)) + " MHZ"
                    #               ClockMem           = [string]([int]($AdlResultSplit[4] / 100)) + " MHZ"
                    #               utilization_gpu    = $AdlResultSplit[5]+ " %"
                    #               temperature_gpu    = [int]$AdlResultSplit[6] /1000
                    #               TdpLimit           = $AdlResultSplit[7]+ " %"
                    #           }
                    #   }

                      invoke-expression "./bin/adli.exe --noheader"  | ForEach-Object {
                          $ADLresultSplit = $_ -split (",")
                          $ADLDevices += [PSCustomObject]@{
                            GpuId           = $ADLresultSplit[0]
                            gpu_name        = $ADLresultSplit[1]
                            temperature_gpu = $ADLresultSplit[2]
                            FanSpeed        = $ADLresultSplit[3]
                          }
                      }


                      #Open CL
                          $OCLDevices = [OpenCl.Device]::GetDeviceIDs($AMDPlatform[0],"ALL") | Where-Object vendor -like "*Advanced Micro Devices*"  #exclude integrated INTEL gpu

                          $counter=0
                          $OCLDevices| ForEach-Object {
                                      if ($_.vendor -like "*Advanced Micro Devices*") {$type="AMD"}
                                      if ($_.vendor -like "*NVDIA*") {$type="NVIDIA"}
                                      if ($_.vendor -like "*INTEL*") {$type="INTEL"}


                                      $AdlDevice=$AdlDevices |Where-Object GpuId -eq $Counter| Select-Object -first 1

                                      $cards+=[pscustomobject]@{
                                              Type = $Type
                                              GpuId=$counter
                                              Name=$_.Name
                                              FanSpeed=$AdlDevice.FanSpeed
                                              ClockGpu=$AdlDevice.ClockGpu
                                              ClockMem=$AdlDevice.ClockMem
                                              utilization_gpu=$AdlDevice.utilization_gpu
                                              temperature_gpu=$AdlDevice.temperature_gpu
                                              TdpLimit=$AdlDevice.TdpLimit

                                          }
                                          $counter++
                                  }


             }
    $cards

}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function print_gpu_information {



            $Cards=get_gpu_information

            $Cards |where-object Type -eq 'NVIDIA' | Format-Table -Wrap  (
                @{Label = "GpuId"; Expression = {$_.gpuId}},
                @{Label = "Type"; Expression = {"NVIDIA"}},
                @{Label = "Name"; Expression = {$_.gpu_name}},
                @{Label = "Gpu%"; Expression = {$_.utilization_gpu}},
                @{Label = "Mem%"; Expression = {$_.utilization_memory}},
                @{Label = "Temp"; Expression = {$_.temperature_gpu}},
                @{Label = "FanSpeed"; Expression = {$_.FanSpeed}},
                @{Label = "Power"; Expression = {$_.power_draw+" /"+$_.power_limit}},
                @{Label = "pstate"; Expression = {$_.pstate}},
                @{Label = "ClockGpu"; Expression = {$_.ClockGpu}},
                @{Label = "ClockMem"; Expression = {$_.ClockMem}}

            ) | Out-Host



            $Cards |where-object Type -eq 'AMD' | Format-Table -Wrap  (
                            @{Label = "GpuId"; Expression = {$_.gpuId}},
                            @{Label = "Type"; Expression = {$_.Type}},
                            @{Label = "Name"; Expression = {$_.name}},
                            @{Label = "Gpu%"; Expression = {$_.utilization_gpu}},
                            @{Label = "Temp"; Expression = {$_.temperature_gpu}},
                            @{Label = "FanSpeed"; Expression = {$_.FanSpeed}},
                            @{Label = "ClockGpu"; Expression = {$_.ClockGpu}},
                            @{Label = "ClockMem"; Expression = {$_.ClockMem}}

                        ) | Out-Host

                    }





#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function get_comma_separated_string {
        param(
            [Parameter(Mandatory = $true)]
            [int]$start,
            [Parameter(Mandatory = $true)]
            [int]$lenght
            )

        $result=$null


        for ($i=$start;$i-$start -lt $lenght;$i++) {

            if ($result -ne $null) {$result+=","}

            $result=$result + [string]$i
            }

        $result


}

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function get_config_variable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$VarName
        )

        $Var=[string]$null
        $content=@()


        $SearchPattern="@@"+$VarName+"=*"

        $A=Get-Content config.txt | Where-Object {$_ -like $SearchPattern}
        $A | ForEach-Object {$content += ($_ -split '=')[1]}
        if (($content | Measure-Object).count -gt 1) {$var=$content} else {$var=[string]$content}
        if ($Var -ne $null) {($Var.TrimEnd()).TrimStart()}


}





#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

Function Get_Mining_Types () {
    param(
        [Parameter(Mandatory = $false)]
        [array]$Filter=$null
        )


        if ($Filter -eq $null) {$Filter=@()} # to allow comparation after


        $Types=@()
        $OCLDevices=@()

        $Types0 = get_config_variable "GPUGROUPS" |ConvertFrom-Json

        $OCLPlatforms = [OpenCl.Platform]::GetPlatformIDs()
        for ($i=0;$i -lt $OCLPlatforms.length;$i++) {$OCLDevices+=([OpenCl.Device]::GetDeviceIDs($OCLPlatforms[$i],"ALL"))}


        $NumberNvidiaGPU=  ($OCLDevices | Where-Object Vendor -like '*NVIDIA*' |Measure-Object).count
        $NumberAmdGPU=  ($OCLDevices | Where-Object Vendor -like '*Advanced Micro Devices*' |Measure-Object).count
        $NumberAmdGPU=  ($OCLDevices | Where-Object Vendor -like '*Advanced Micro Devices*' |Measure-Object).count


        if ($Types0 -eq $null) { #Autodetection on, must add types manually
                    $Types0=@()

                    if ($NumberNvidiaGPU -gt 0) {
                                            $Types0 += [pscustomobject] @{
                                                            GroupName ="NVIDIA"
                                                            Type = "NVIDIA"
                                                            Gpus = (get_comma_separated_string 0 $NumberNvidiaGPU)
                                                            }
                                                }

                    if ($NumberAmdGPU -gt 0) {
                                            $Types0 += [pscustomobject] @{
                                                            GroupName = "AMD"
                                                            Type = "AMD"
                                                            Gpus = (get_comma_separated_string 0 $NumberAmdGPU )
                                                                    }
                                                        }


                    }

        #if cpu mining is enabled add a new group
        if  (
                ((get_config_variable "CPUMINING") -eq 'ENABLED' -and ($Filter |Measure-Object).count -eq 0)   -or  ((compare-object "CPU" $Filter -IncludeEqual -ExcludeDifferent |Measure-Object).count -gt 0)
            )
            {$Types0+=[pscustomobject]@{GroupName="CPU";Type="CPU"}}


        $c=0
        $Types0 | foreach-object {
                            if (((compare-object $_.Groupname $Filter -IncludeEqual -ExcludeDifferent  | Measure-Object).Count -gt 0) -or (($Filter | Measure-Object).count -eq 0)) {
                                        $_ | Add-Member Id $c
                                        $c=$c+1

    $_ | Add-Member GpusClayMode ($_.gpus -replace '10','A' -replace '11','B' -replace '12','C' -replace '13','D' -replace '14','E' -replace '15','F' -replace '16','G'  -replace ',','')
                                                 <#
                                        if ($_.type -eq "NVIDIA" -or $OCLPlatforms[0].Name -like "*NVIDIA*") {  #claymore needs global openclid, when Nvidia platform is first, this not coincide with AMD devices only order, some miners like sgminer needs AMD devices only order, others like claymore needs global position
                                            $_ | Add-Member GpusClayMode ($_.gpus -replace '10','A' -replace '11','B' -replace '12','C' -replace '13','D' -replace '14','E' -replace '15','F' -replace '16','G'  -replace ',','')
                                                }
                                            else {
                                                    $gpust=$_.gpus -split ','
                                                    for ($i=0; $i -lt $gpust.length; $i++) {$gpust[$i]=[int]$gpust[$i]+$NumberNvidiaGPU}
                                                    $A=($gpust -join ',')
                                                    $_ | Add-Member GpusClayMode (($gpust -join ',') -replace '10','A' -replace '11','B' -replace '12','C' -replace '13','D' -replace '14','E' -replace '15','F' -replace '16','G'  -replace ',','')

                                                }
                                                    #>
                                        $_ | Add-Member GpusETHMode ($_.gpus -replace ',',' ')
                                        $_ | Add-Member GpusNsgMode ("-d "+$_.gpus -replace ',',' -d ')
                                        $_ | Add-Member GpuPlatform (Get_Gpu_Platform $_.Type)

                                        $Types+=$_
                                        }
                        }

    $Types #return
    }


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function WriteLog {

    param(
        [Parameter(Mandatory = $false)]
        [string]$Message,
        [Parameter(Mandatory = $true)]
        [string]$LogFile,
        [Parameter(Mandatory = $false)]
        [boolean]$SendToScreen=$false
    )



    [string](get-date)+"...... "+$Message | Add-Content  -Path $LogFile -Force
    if ($SendToScreen) { $Message | out-host}

    #if ($object -ne $null) {$object | convertto-json | Set-Content  -Path $LogFile}

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


Function Timed_ReadKb{
    param(
        [Parameter(Mandatory = $true)]
        [int]$secondsToWait,
        [Parameter(Mandatory = $true)]
        [array]$ValidKeys

    )

    $Loopstart=get-date
    $KeyPressed=$null

    while ((NEW-TIMESPAN $Loopstart (get-date)).Seconds -le $SecondsToWait -and $ValidKeys -notcontains $KeyPressed){
        if ($host.ui.RawUi.KeyAvailable) {
                    $key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp")
                    $KeyPressed=$Key.character
                    while ($Host.UI.RawUI.KeyAvailable)  {$host.ui.RawUi.Flushinputbuffer()} #keyb buffer flush

                    }

         start-sleep -m 30


   }

   $KeyPressed
}





#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Gpu_Platform {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Type
    )
    if ($Type -eq "AMD") {$return=$([array]::IndexOf(([OpenCl.Platform]::GetPlatformIDs() | Select-Object -ExpandProperty Vendor), 'Advanced Micro Devices, Inc.'))}
    else {$return=0}

    $return

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Clear_Screen_Zone {
    param(
        [Parameter(Mandatory = $true)]
        [int]$startY,
        [Parameter(Mandatory = $true)]
        [int]$endY
    )

    $BlankLine="                                                                                                                    "


Set_ConsolePosition 0 $start

for ($i=$startY;$i -le $endY;$i++) {
        $BlankLine | write-host
        }
}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Invoke_TcpRequest {

    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $true)]
        [String]$Request,
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {
        $Client = New-Object System.Net.Sockets.TcpClient $Server, $Port
        $Stream = $Client.GetStream()
        $Writer = New-Object System.IO.StreamWriter $Stream
        $Reader = New-Object System.IO.StreamReader $Stream
        $client.SendTimeout = $Timeout * 1000
        $client.ReceiveTimeout = $Timeout * 1000
        $Writer.AutoFlush = $true

        $Writer.WriteLine($Request)
        $Response = $Reader.ReadLine()
    }
    catch { $Error.Remove($error[$Error.Count-1])}
    finally {
        if ($Reader) {$Reader.Close()}
        if ($Writer) {$Writer.Close()}
        if ($Stream) {$Stream.Close()}
        if ($Client) {$Client.Close()}
    }

    $response

}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Invoke_httpRequest {

    param(
        [Parameter(Mandatory = $true)]
        [String]$Server = "localhost",
        [Parameter(Mandatory = $true)]
        [String]$Port,
        [Parameter(Mandatory = $false)]
        [String]$Request,
        [Parameter(Mandatory = $true)]
        [Int]$Timeout = 10 #seconds
    )

    try {

        $response = Invoke-WebRequest "http://$($Server):$Port$Request" -UseBasicParsing -TimeoutSec $timeout
    }
    catch {$Error.Remove($error[$Error.Count-1])}


    $response

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_Live_HashRate {
    param(
        [Parameter(Mandatory = $true)]
        [String]$API,
        [Parameter(Mandatory = $true)]
        [Int]$Port,
        [Parameter(Mandatory = $false)]
        [Object]$Parameters = @{}

    )

    $Server = "localhost"

    $Multiplier = 1000
    #$Delta = 0.05
    #$Interval = 5
    #$HashRates = @()
    #$HashRates_Dual = @()

    try {
        switch ($API) {

            "Dtsm" {

                    $Request = Invoke_TcpRequest $server $port "empty" 5
                    $Data = $Request | ConvertFrom-Json | Select-Object  -ExpandProperty result
                    $HashRate =  [Double](($Data.sol_ps) | Measure-Object -Sum).Sum

                    }
            "xgminer" {
                    $Message = @{command = "summary"; parameter = ""} | ConvertTo-Json -Compress
                    $Request = Invoke_TcpRequest $server $port $Message 5

                    if ($Request -ne "" -and $request -ne $null) {
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

                      }
            "ccminer" {

                    $Request = Invoke_TcpRequest $server $port  "summary" 5
                    $Data = $Request -split ";" | ConvertFrom-StringData
                    $HashRate = if ([Double]$Data.KHS -ne 0 -or [Double]$Data.ACC -ne 0) {[Double]$Data.KHS * $Multiplier}


                  }
            "nicehashequihash" {


                    $Request = Invoke_TcpRequest $server $port  "status" 5
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = $Data.result.speed_hps
                    if ($HashRate -eq $null) {$HashRate = $Data.result.speed_sps}

                 }
            "excavator" {
                    $Message = @{id = 1; method = "algorithm.list"; params = @()} | ConvertTo-Json -Compress
                    $Request = Invoke_TcpRequest $server $port $message 5
                    $Data = ($Request | ConvertFrom-Json).Algorithms
                    $HashRate = [Double](($Data.workers.speed) | Measure-Object -Sum).Sum

                  }
            "ewbf" {
                    $Message = @{id = 1; method = "getstat"} | ConvertTo-Json -Compress
                    $Request = Invoke_TcpRequest $server $port $message 5
                    $Data = $Request | ConvertFrom-Json
                    $HashRate = [Double](($Data.result.speed_sps) | Measure-Object -Sum).Sum
                    }
            "claymore" {


                    $Request = Invoke_httpRequest $Server $Port "" 5
                    if ($Request -ne "" -and $request -ne $null) {
                                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                                    $HashRate = [double]$Data.result[2].Split(";")[0] * $Multiplier
                                    $HashRate_Dual = [double]$Data.result[4].Split(";")[0] * $Multiplier
                                    }

            }

            "ClaymoreV2" {

                    $Request = Invoke_httpRequest $Server $Port "" 5
                    if ($Request -ne "" -and $request -ne $null) {
                                    $Data = $Request.Content.Substring($Request.Content.IndexOf("{"), $Request.Content.LastIndexOf("}") - $Request.Content.IndexOf("{") + 1) | ConvertFrom-Json
                                    $HashRate = [double]$Data.result[2].Split(";")[0]
                                    }
                         }

            "prospector" {
                    $Request = Invoke_httpRequest $Server $Port "/api/v0/hashrates" 5
                    if ($Request -ne "" -and $request -ne $null) {
                                    $Data = $Request | ConvertFrom-Json
                                    $HashRate =  [Double]($Data.rate | Measure-Object -Sum).sum
                                    }
                  }

            "fireice" {
                    $Request = Invoke_httpRequest $Server $Port "/h" 5
                    if ($Request -ne "" -and $request -ne $null) {
                                $Data = $Request.Content -split "</tr>" -match "total*" -split "<td>" -replace "<[^>]*>", ""
                                $HashRate = $Data[1]
                                if ($HashRate -eq "") {$HashRate = $Data[2]}
                                if ($HashRate -eq "") {$HashRate = $Data[3]}
                                }
                        }
            "wrapper" {
                    $HashRate = ""
                    $HashRate = Get-Content ".\Wrapper_$Port.txt"
                    $HashRate =  $HashRate -replace ',','.'
                        }

             "castXMR" {
                    $Request = Invoke_httpRequest $Server $Port "" 5
                    if ($Request -ne "" -and $request -ne $null) {
                            $Data = $Request | ConvertFrom-Json
                            $HashRate =  [Double]($Data.devices.hash_rate | Measure-Object -Sum).Sum / 1000
                            }
                    }

            "XMrig" {
                        $Request = Invoke_httpRequest $Server $Port "/api.json" 5
                        if ($Request -ne "" -and $request -ne $null) {
                                $Data = $Request | ConvertFrom-Json
                                $HashRate =   [Double]$Data.hashrate.total[0]
                                }
                        }


            "Bminer" {
                        $Request = Invoke_httpRequest $Server $Port "/api/status" 5
                        if ($Request -ne "" -and $request -ne $null) {
                                        $Data = $Request.content | ConvertFrom-Json
                                        $HashRate =   0
                                        $Data.miners | Get-Member -MemberType NoteProperty | ForEach-Object {
                                                        $HashRate +=  $Data.miners.($_.name).solver.solution_rate
                                                    }
                                    }
                    }
            "optiminer" {
                            $Request = Invoke-WebRequest "http://$($Server):$Port/" -UseBasicParsing
                            $Data = $Request | ConvertFrom-Json
                            $HashRate = [Double]($Data.solution_rate.Total."5s" | Measure-Object -Sum).sum
                        }
         } #end switch

        $HashRates=@()
        $HashRates += [double]$HashRate
        $HashRates += [double]$HashRate_Dual

        $HashRates
    }
    catch {}
}













#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function ConvertTo_Hash {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Hash
         )


    $Return=switch ([math]::truncate([math]::log($Hash, [Math]::Pow(1000, 1)))) {
          "-Infinity" {"0 h"}
          0 {"{0:n1} h" -f ($Hash / [Math]::Pow(1000, 0))}
          1 {"{0:n1} kh" -f ($Hash / [Math]::Pow(1000, 1))}
          2 {"{0:n1} mh" -f ($Hash / [Math]::Pow(1000, 2))}
          3 {"{0:n1} gh" -f ($Hash / [Math]::Pow(1000, 3))}
          4 {"{0:n1} th" -f ($Hash / [Math]::Pow(1000, 4))}
          Default {"{0:n1} ph" -f ($Hash / [Math]::Pow(1000, 5))}


        }
    $Return
}




#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Start_SubProcess {
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


function Expand_WebRequest {
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
    Start-Process "./bin/7z.exe" $Command -Wait

    if (Test-Path $FileName) {Remove-Item $FileName}

}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get_Pools {
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

        if ($location -eq 'GB') {$location='EUROPE'}

        $PoolsFolderContent= Get-ChildItem ($PSScriptRoot+'\pools') | Where-Object {$PoolsFilterList.Count -eq 0 -or (Compare $PoolsFilterList $_.BaseName -IncludeEqual -ExcludeDifferent | Measure).Count -gt 0}

            $ChildItems=@()

            if ($info -eq $null) {$Info=[pscustomobject]@{}}

            if (($info |  Get-Member -MemberType NoteProperty | where-object name -eq location) -eq $null) {$info | Add-Member Location $Location}

            $info | Add-Member SharedFile [string]$null

            $PoolsFolderContent | ForEach-Object {

                                    $Basename=$_.BaseName
                                    $SharedFile=$PSScriptRoot+"\"+$Basename+[string](Get-Random -minimum 0 -maximum 9999999)+".tmp"
                                    $info.SharedFile=$SharedFile

                                    if (Test-Path $SharedFile) {Remove-Item $SharedFile}
                                    &$_.FullName -Querymode $Querymode -Info $Info
                                    if (Test-Path $SharedFile) {
                                            $Content=Get-Content $SharedFile | ConvertFrom-Json
                                            Remove-Item $SharedFile
                                        }
                                    else
                                        {$Content=$null}
                                    $Content | ForEach-Object {$ChildItems +=[PSCustomObject]@{Name = $Basename; Content = $_}}
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
                                    $Ex = $Return | Where-Object Info -eq $_.Info | Where-Object Algorithm -eq $_.Algorithm | Where-Object PoolName -eq $_.PoolName
                                    if ($Ex.count -eq 0) {$Return += $_}
                                    }
                            }
                        else {
                             $Return=$AllPools2
                            }
                }
            else
             { $Return= $AllPools }




    Remove-variable AllPools
    Remove-variable AllPools2

    $Return


 }


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Get_Algo_Divisor {
      param(
        [Parameter(Mandatory = $true)]
        [String]$Algo
            )

                    $Divisor = 1000000000

                    switch($Algo)
                    {
                        "skein"{$Divisor *= 100}
                        "equihash"{$Divisor /= 1000}
                        "blake2s"{$Divisor *= 1000}
                        "blakecoin"{$Divisor *= 1000}
                        "decred"{$Divisor *= 1000}
                        "blake14r"{$Divisor *= 1000}
                        "keccakc"{$Divisor *= 1000}
                    }

    $Divisor
     }


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set_ConsolePosition ([int]$x,[int]$y) {
        # Get current cursor position and store away
        $position=$host.ui.rawui.cursorposition
        # Store new X Co-ordinate away
        $position.x=$x
        $position.y=$y
        # Place modified location back to $HOST
        $host.ui.rawui.cursorposition=$position
        remove-variable position
        }

#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function Get_ConsolePosition ([ref]$x,[ref]$y) {

    $position=$host.ui.rawui.cursorposition
    $x.value=$position.x
    $y.value=$position.y
    remove-variable position

}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************

function set_WindowSize ([int]$Width,[int]$Height) {
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

function get_algo_unified_name ([string]$Algo) {

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
            "skunkhash" {$Result="skunk"}
            "TimeTravel10" {$Result = "bitcore"}
            "phi1612" {$Result = "phi"}
            "keccak-c" {$Result = "keccakc"}
            }
     $Result

}

 #************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function  get_coin_unified_name ([string]$Coin) {

    $Result = $Coin
    switch -wildcard  ($Coin) {
            "Myriadcoin-*" {$Result="Myriad"}
            "Myriad-*" {$Result="Myriad"}
            "Dgb-*" {$Result="Digibyte"}
            "Digibyte-*" {$Result="Digibyte"}
            "Verge-*" {$Result="Verge"}
            "Auroracoin-*" {$Result = "Auroracoin"}
            "EthereumClassic" {$Result="Ethereum-Classic"}
            }

     $Result

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Get_Hashrates  {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel


    )

    $Hrs=$null

    $Pattern=$MinerName+"_"+$Algorithm+"_"+$GroupName
    if ($AlgoLabel -ne "") {$Pattern+="_"+$AlgoLabel}
    $Pattern+="_HashRate.txt"

    try {$Content=(Get-ChildItem ($PSScriptRoot+"\Stats")  | Where-Object pschildname -eq $Pattern | Get-Content | ConvertFrom-Json)} catch {$Content=$null}

    if ($content -ne $null) {$Hrs = $Content[0].tostring() + "_" + $Content[1].tostring()}

    $Hrs

}
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************


function Set_Hashrates {
    param(
        [Parameter(Mandatory = $true)]
        [String]$Algorithm,
        [Parameter(Mandatory = $true)]
        [String]$MinerName,
        [Parameter(Mandatory = $true)]
        [String]$GroupName,
        [Parameter(Mandatory = $false)]
        [String]$AlgoLabel,
        [Parameter(Mandatory = $true)]
        [long]$Value,
        [Parameter(Mandatory = $true)]
        [long]$ValueDual

    )


    $Path=$PSScriptRoot+"\Stats\"+$MinerName+"_"+$Algorithm+"_"+$GroupName
    if ($AlgoLabel -ne "") {$Path+="_"+$AlgoLabel}
    $Path+="_HashRate.txt"


    $Array=$Value,$valueDual
    $Array | Convertto-Json | Set-Content  -Path $Path
    Remove-Variable Array


}



#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function Start_Downloader {
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
                    Expand_WebRequest $URI $ExtractionPath -ErrorAction Stop
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


function clear_log{

    $Now = Get-Date
    $Days = "3"

    $TargetFolder = ".\Logs"
    $Extension = "*.txt"
    $LastWrite = $Now.AddDays(-$Days)

    $Files = Get-Childitem $TargetFolder -Include $Extension -Exclude "empty.txt" -Recurse | Where-Object {$_.LastWriteTime -le "$LastWrite"}

    $Files |ForEach-Object {Remove-Item $_.fullname}

}


#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************
#************************************************************************************************************************************************************************************



function get_WhattomineFactor ([string]$Algo) {

   #WTM json is for 3xAMD 480 hashrate must adjust,
   # to check result with WTM set WTM on "Difficulty for revenue" to "current diff" and "and sort by "current profit" set your algo hashrate from profits screen, WTM "Rev. BTC" and MM BTC/Day must be the same

            switch ($_.Algo)
                        {
                                "Ethash"{$WTMFactor=79500000}
                                "Groestl"{$WTMFactor=54000000}
                                "Myriad-Groestl"{$WTMFactor=79380000}
                                "X11Gost"{$WTMFactor=20100000}
                                "Cryptonight"{$WTMFactor=2190}
                                "equihash"{$WTMFactor=870}
                                "lyra2v2"{$WTMFactor=14700000}
                                "Neoscrypt"{$WTMFactor=1950000}
                                "Lbry"{$WTMFactor=285000000}
                                "Blake2b"{$WTMFactor=2970000000}
                                "Blake14r"{$WTMFactor=4200000000}
                                "Pascal"{$WTMFactor=2070000000}
                                "skunk"{$WTMFactor=54000000}
                                "xevan" {$WTMFactor = 4800000}
                                "bitcore" {$WTMFactor = 30000000}
                                "EquihashZero" {$WTMFactor = 18}
                                "keccak" {$WTMFactor = 900000000}
                                "Keccak-C" {$WTMFactor = 240000000}
                                "CryptoNight-Lite" {$WTMFactor = 6600}
                                "Lyra2z" {$WTMFactor = 420000}
                        }



         $WTMFactor

    }

function get_coin_symbol ([string]$Coin) {

    $Result = $Coin
    switch -wildcard  ($Coin) {
        "bitcoin" {$Result = "BTC"}
        "bitcoin-cash" {$Result = "BCH"}
        "bitcoin-gold" {$Result = "BTG"}
        "monero" {$Result = "XMR"}
        "feathercoin" {$Result = "FTC"}
        "ethereum-classic" {$Result = "ETC"}
        "expanse" {$Result = "EXP"}
        "musicoin" {$Result = "MUSIC"}
        "ethereum" {$Result = "ETH"}
        "siacoin" {$Result = "SC"}
        "zcoin" {$Result = "XZC"}
        "zcash" {$Result = "ZEC"}
        "zclassic" {$Result = "ZCL"}
        "zencash" {$Result = "ZEN"}
        "globalboosty" {$Result = "BSTY"}
        "groestlcoin" {$Result = "GRS"}
        "vertcoin" {$Result = "VTC"}
        "monacoin" {$Result = "MONA"}
        "litecoin" {$Result = "LTC"}
        "gamecredits" {$Result = "GAME"}
        "geocoin" {$Result = "GEO"}
        "dash" {$Result = "DASH"}
        "maxcoin" {$Result = "MAX"}
        "startcoin" {$Result = "START"}
        "adzcoin" {$Result = "ADZ"}
        "sexcoin" {$Result = "SXC"}
        "myriad" {$Result = "XMY"}
        "verge" {$Result = "XVG"}
        "digibyte" {$Result = "DGB"}
        "auroracoin" {$Result = "AUR"}
    }
    $Result
}