param(
    [Parameter(Mandatory = $true)][String]$MinerStatusKey,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

$Profit = 0
$MinerReport = ConvertTo-Json @($ActiveMiners.SubMiners | Where-Object Status -eq 'Running' | ForEach-Object {
        $Profit += [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual

        $Type = $ActiveMiners[$_.IdF].GpuGroup.GroupName

        [pscustomobject]@{
            Name           = $ActiveMiners[$_.IdF].Name
            # Path           = Resolve-Path -Relative $_.Path
            Type           = $ActiveMiners[$_.IdF].GpuGroup.GroupName
            # Active         = "{0:N1} min" -f ($_.TimeSinceStartInterval.TotalMinutes)
            Active         = "{0:N1} min" -f ($_.Stats.ActiveTime.TotalMinutes)
            Algorithm      = $ActiveMiners[$_.IdF].Algorithm + $ActiveMiners[$_.IdF].AlgoLabel + $(
                if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + $ActiveMiners[$_.IdF].AlgorithmDual}
            ) + $ActiveMiners[$_.IdF].BestBySwitch
            Pool           = $ActiveMiners[$_.IdF].PoolAbbName + $(
                if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + $ActiveMiners[$_.IdF].PoolAbbNameDual}
            )
            CurrentSpeed   = (ConvertTo_Hash $_.SpeedLive) + '/s' + $(
                if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + (ConvertTo_Hash $_.SpeedLiveDual) + '/s'}
            ) -replace ",", "."
            EstimatedSpeed = (ConvertTo_Hash $_.Hashrate) + '/s' + $(
                if (![string]::IsNullOrEmpty($ActiveMiners[$_.IdF].AlgorithmDual)) {'|' + (ConvertTo_Hash $_.HashrateDual) + '/s'}
            ) -replace ",", "."
            PID            = $ActiveMiners[$_.IdF].Process.Id
            StatusMiner    = $(if ($_.NeedBenchmark) {"Benchmarking($([string](($ActiveMiners | Where-Object {$_.GpuGroup.GroupName -eq $Type}).count)))"} else {$_.Status})
            'BTC/day'      = [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual
        }
    })
try {
    Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $MinerStatusKey; workername = $WorkerName; miners = $MinerReport; profit = $Profit} | Out-Null
} catch {}
# $MinerReport | Set-Content report.txt
