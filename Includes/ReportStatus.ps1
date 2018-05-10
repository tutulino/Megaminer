param(
    [Parameter(Mandatory = $true)][String]$Key,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

$Profit = 0
$MinerReport = ConvertTo-Json @($ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | ForEach-Object {
        $Profit += [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual

        $M = $ActiveMiners[$_.IdF]

        [PSCustomObject]@{
            Name           = $M.Name
            # Path           = Resolve-Path -Relative $_.Path ## Not the most useful info
            Path           = $M.Symbol + $(if ($M.AlgorithmDual) {'_' + $M.SymbolDual})
            Type           = $M.DeviceGroup.GroupName
            Active         = $(if ($_.Stats.Activetime.TotalMinutes -le 60) {"{0:N1} mins" -f ($_.Stats.ActiveTime.TotalMinutes)} else {"{0:N1} hours" -f ($_.Stats.ActiveTime.TotalHours)})
            Algorithm      = $M.Algorithm + $(if ($M.AlgorithmDual) {'_' + $M.AlgorithmDual}) + $M.BestBySwitch + $(if ($M.AlgoLabel) {"|$($M.AlgoLabel)"})
            Pool           = $M.PoolAbbName + $(if ($M.AlgorithmDual) {"/$($M.PoolAbbNameDual)"})
            CurrentSpeed   = (ConvertTo-Hash $_.SpeedLive) + $(if ($M.AlgorithmDual) {"/$(ConvertTo-Hash $_.SpeedLiveDual)"}) -replace ",", "."
            EstimatedSpeed = (ConvertTo-Hash $_.HashRate) + $(if ($M.AlgorithmDual) {"/$(ConvertTo-Hash $_.HashRateDual)"}) -replace ",", "."
            PID            = $M.Process.Id
            StatusMiner    = $(if ($_.NeedBenchmark) {"Benchmarking($([string](($ActiveMiners | Where-Object {$_.DeviceGroup.GroupName -eq $M.DeviceGroup.GroupName}).count)))"} else {$_.Status})
            'BTC/day'      = [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual
        }
    })
try {
    Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $Key; workername = $WorkerName; miners = $MinerReport; profit = $Profit} | Out-Null
} catch {}
# $MinerReport | Set-Content report.txt
