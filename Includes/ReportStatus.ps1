param(
    [Parameter(Mandatory = $true)][String]$MinerStatusKey,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

$Profit = 0
$MinerReport = ConvertTo-Json @($ActiveMiners | Where-Object {$_.Best} | Foreach-Object {
        $Profit += [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual
        [pscustomobject]@{
            Name           = $_.Name
            # Path           = Resolve-Path -Relative $_.Path
            Type           = $_.Groupname
            Active         = "{0:N1} min" -f ($_.ActiveTime.TotalMinutes)
            Algorithm      = $_.Algorithm + $_.AlgoLabel + $(if ($_.AlgorithmDual -ne $null) {'|' + $_.AlgorithmDual}) + $_.BestBySwitch
            Pool           = $_.PoolAbbName
            CurrentSpeed   = (ConvertTo_Hash $_.SpeedLive) + '/s' + $(if ($_.AlgorithmDual -ne $null) {'|' + (ConvertTo_Hash $_.SpeedLiveDual) + '/s'}) -replace ",", "."
            EstimatedSpeed = $_.Hashrates
            PID            = $_.Process.Id
            StatusMiner    = $_.Status
            'BTC/day'      = [decimal]$_.RevenueLive + [decimal]$_.RevenueLiveDual
        }
    })
Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $MinerStatusKey; workername = $WorkerName; miners = $MinerReport; profit = $Profit} | Out-Null
