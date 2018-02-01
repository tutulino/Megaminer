
param(
    [Parameter(Mandatory = $true)][String]$Key,
    [Parameter(Mandatory = $true)][String]$WorkerName,
    [Parameter(Mandatory = $true)]$ActiveMiners,
    [Parameter(Mandatory = $true)]$Miners,
    [Parameter(Mandatory = $true)]$MinerStatusURL
)

$ActiveMiners | Where-Object Best | ForEach-Object {
    $WorkerName2 = $_.Workername
    if ($_.NeedBenchmark) {$WorkerStatus = "Benchmarking"}
    else {$WorkerStatus = "Running"}

    $Profit = ([double]$_.RevenueLive + [double]$_.RevenueLiveDual).tostring("n8") -replace ",", "."
    $ProfitCur = (($_.RevenueLive + $_.RevenueLiveDual) * $LocalBTCvalue ).tostring("n2") -replace ",", "."

    $minerreport = ConvertTo-Json @(
        [pscustomobject]@{
            Name           = $_.Name
            Path           = " " #Resolve-Path -Relative $_.Path
            Type           = $_.Groupname
            Active         = "{0:N1} min" -f ($_.ActiveTime.TotalMinutes)
            Algorithm      = $_.Algorithm + $_.AlgoLabel + $(if ($_.AlgorithmDual -ne $null) {'|' + $_.AlgorithmDual}) + $_.BestBySwitch
            Pool           = $_.PoolAbbName
            CurrentSpeed   = (ConvertTo_Hash $_.SpeedLive) + '/s' + $(if ($_.AlgorithmDual -ne $null) {'|' + (ConvertTo_Hash $_.SpeedLiveDual) + '/s'}) -replace ",", "."
            EstimatedSpeed = $_.Hashrates
            PID            = $_.Process.Id
            statusminer    = $_.Status
            'BTC/day'      = $Profit
        }
    )
    Invoke-RestMethod -Uri $MinerStatusURL -Method Post -Body @{address = $Key; workername = $WorkerName2; miners = $minerreport; profit = $profit; profitcur = $profitcur; status = $WorkerStatus; currency = $LocalCurrency } | Out-Null
}
