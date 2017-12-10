
Add-Type -Path .\OpenCL\*.cs


$OCLPlatforms = @()
$counter=0

[OpenCl.Platform]::GetPlatformIDs() | ForEach-Object {
    $OCLPlatforms+=[pscustomobject]@{
            PlatformId=$counter
            Name=$_.Name
            Vendor=$_.vendor
            }
            $counter++
       }
       

$OCLPlatforms | out-host

<#


#Get GPUPlatforms
$GpuPlatforms=@()
$counter=0

(Get-WmiObject -class CIM_VideoController | Select-Object -ExpandProperty AdapterCompatibility) | ForEach-Object {

            $GpuPlatforms +=[pscustomObject]@{
                PlatformId     = $counter
                Type           = $_
            }
            $counter+=1
        }

"-------------------GPU PLATFORMS------------------------ "

$GpuPlatforms | Out-Host

 

#Get SMI info for nvidia cards
$NvidiaCards=@()
$counter=0
$env:CUDA_DEVICE_ORDER = 'PCI_BUS_ID' #This align cuda id with nvidia-smi order
invoke-expression "./nvidia-smi.exe --query-gpu=gpu_name  --format=csv,noheader"  | ForEach-Object {

                            $SMIresultSplit = $_ -split (",")

                            $NvidiaCards +=[pscustomObject]@{
                                        GpuId              = $counter
                                        gpu_name           = $SMIresultSplit[0] 
                                    }
                            $counter+=1

                                }

#Show nvidia cards list

"-------------------NVIDIA GPUS------------------------ "
$NvidiaCards | Out-Host

#>



                  
                            
           