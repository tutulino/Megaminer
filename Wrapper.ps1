param(
    [Parameter(Mandatory = $true)]
    [Int]$ControllerProcessID,
    [Parameter(Mandatory = $true)]
    [String]$Id,
    [Parameter(Mandatory = $true)]
    [String]$FilePath,
    [Parameter(Mandatory = $false)]
    [String]$ArgumentList = "",
    [Parameter(Mandatory = $false)]
    [String]$WorkingDirectory = ""
)

Set-Location (Split-Path $script:MyInvocation.MyCommand.Path)

0 | Set-Content ".\Wrapper_$Id.txt"

$PowerShell = [PowerShell]::Create()
if ($WorkingDirectory -ne "") {$PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null}
$Command = ". '$FilePath'"
if ($ArgumentList -ne "") {$Command += " $ArgumentList"}
$PowerShell.AddScript("$Command 2>&1 | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black

do {
    Start-Sleep -Seconds 1

    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        $Line = $_

        if ($Line -like "*accepted*" -or
            $Line -like "*Mining on #*" -or
            $Line -like "*diff*yes!*" -or
            $Line -like ">*Rej*" -or
            $Line -like "*overall*" -or
            $Line -like "*Average*" -or
            $Line -like "*Total*"
        ) {
            $Line = $Line  `
                -replace "\smh/s", "mh/s" `
                -replace "\skh/s", "kh/s" `
                -replace "\sgh/s", "gh/s" `
                -replace "\sth/s", "th/s" `
                -replace "\sph/s", "ph/s" `
                -replace "\sh/s", "h/s" `
                -replace "\ssol/s", "h/s" `
                -replace "\sHash/s", "h/s"

            $Words = $Line -split " " -like "*/s*" -replace ","

            if ($Command -notlike '*mkxminer.exe*') {
                $Words = $Words | Select-Object -Last 1
            }

            $HashRate = 0
            foreach ($Word in $Words) {
                if ($Word -match "([0-9.]+)([kmgtp]?h)/s") {
                    $HashRate += [decimal]$Matches[1] * $(switch ($Matches[2]) {
                            'kh' { 1e3 }
                            'mh' { 1e6 }
                            'gh' { 1e9 }
                            'th' { 1e12 }
                            'ph' { 1e15 }
                            Default { 1 }
                        })
                }
            }

            $HashRate -replace ',', '.' | Set-Content ".\Wrapper_$Id.txt"
        }
        $Line
    }

    if ((Get-Process | Where-Object Id -EQ $ControllerProcessID) -eq $null) {$PowerShell.Stop() | Out-Null}
}
until($Result.IsCompleted)
