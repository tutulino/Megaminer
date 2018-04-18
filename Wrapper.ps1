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

. .\Include.ps1

0 | Set-Content ".\Wrapper_$Id.txt"


$PowerShell = [PowerShell]::Create()
if ($WorkingDirectory -ne "") {$PowerShell.AddScript("Set-Location '$WorkingDirectory'") | Out-Null}
$Command = ". '$FilePath'"
if ($ArgumentList -ne "") {$Command += " $ArgumentList"}
$PowerShell.AddScript("$Command 2>&1 | Write-Verbose -Verbose") | Out-Null
$Result = $PowerShell.BeginInvoke()

Write-Host "Wrapper Started" -BackgroundColor Yellow -ForegroundColor Black



do {
    Start-Sleep 1

    $PowerShell.Streams.Verbose.ReadAll() | ForEach-Object {
        $Line = $_


        if ($Line -like "*total speed:*" -or
            $Line -like "*accepted:*" -or
            $Line -like "*Mining on #*" -or
            $line -like "*diff*yes!*" -or
            $line -like ">*Rej*" -or
            $line -like "*overall*" -or
            $line -like "*Average*" -or
            $line -like "*Total:*" 
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

            $Words = $Line -split " "
            $Word = $words -like "*/s*" | Select-Object -Last 1
            $HashRate = [Decimal]($Word `
                    -replace ",", "" `
                    -replace "mh/s", "" `
                    -replace "kh/s", "" `
                    -replace "gh/s", "" `
                    -replace "th/s", "" `
                    -replace "ph/s", "" `
                    -replace "h/s", "" )

            switch  -wildcard ($Word) {
                "*kh/s*" {$HashRate *= [Math]::Pow(1000, 1)}
                "*mh/s*" {$HashRate *= [Math]::Pow(1000, 2)}
                "*gh/s*" {$HashRate *= [Math]::Pow(1000, 3)}
                "*th/s*" {$HashRate *= [Math]::Pow(1000, 4)}
                "*ph/s*" {$HashRate *= [Math]::Pow(1000, 5)}
            }

            $HashRate | Set-Content ".\Wrapper_$Id.txt"
        }
        $Line
    }

    if ((Get-Process | Where-Object Id -EQ $ControllerProcessID) -eq $null) {$PowerShell.Stop() | Out-Null}
}
until($Result.IsCompleted)
