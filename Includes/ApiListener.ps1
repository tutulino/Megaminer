Param (

    [Parameter()]
    [String] $SharedFile, #complete path
    #[String] $SharedFile='C:\Users\admin\Desktop\Forager\ApiShared34474029.tmp',

    [Parameter()]
    [Int] $Port = 9999,

    [Parameter()]
    [String] $Url = "",
    
    [Parameter()]
    [System.Net.AuthenticationSchemes] $Auth = [System.Net.AuthenticationSchemes]::IntegratedWindowsAuthentication
    )

    $ErrorActionPreference = "Stop"

    if ($Url.Length -gt 0 -and -not $Url.EndsWith('/')) {
        $Url += "/"
    }

    
    $Host.UI.RawUI.WindowTitle = "Forager API Listener"

    $listener = New-Object System.Net.HttpListener
    $prefix = "http://*:$Port/$Url"
    $listener.Prefixes.Add($prefix)
    $listener.AuthenticationSchemes = $Auth 
 
    $listener.Start()

    Write-Warning "Forager Api Listening on port $port......."
    Write-Warning "Don´t close this window while you want to use API."

    while ($true) {
        $statusCode = 200
        $context = $listener.GetContext()
        
        Write-Warning "Received request $(get-date)"
        
       
        $request = $context.Request
        $command = $request.QueryString.Item("command")
        if ($command -eq "exit") {
            Write-Warning  "Received command to exit listener"
            break
        }
       
        
        try{$commandOutput = get-content -path $SharedFile -raw } catch{$commandOutput=""}

        if ($commandOutput -ne $null -and $commandOutput -ne "") {    
            $A=(get-date) 
            $B=([datetime]($commandOutput |convertfrom-json).RefreshDate)
            $Ago = $A - $B
            if ($Ago.TotalSeconds -gt 20) {$commandOutput=""}  #check info refresh date

            if ($Ago.TotalSeconds -gt 300) {break}  #check info refresh date
        }

        $response = $context.Response
        $response.StatusCode = $statusCode

        $Response.ContentEncoding = [System.Text.Encoding]::utf8
        $Response.ContentType = "text/plain; charset=utf-8"

        if (!$commandOutput) {$commandOutput = [string]::Empty}
        $buffer = [System.Text.Encoding]::utf8.GetBytes($commandOutput)

        
        $response.ContentLength64 = $buffer.Length
        $output = $response.OutputStream
        
        try {
            $output.Write($buffer,0,$buffer.Length)
            $output.Close()
        } catch{}
     
    }

$listener.Stop()
stop-process -Id $PID

