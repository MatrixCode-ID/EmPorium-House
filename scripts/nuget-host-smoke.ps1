<#
Purpose: verify the real EmPorium House host starts with multi-feed NuPak and rejects old/unknown feed URLs.
Prerequisites: backend built, local configuration present, schema marker 2 installed.
Parameters: RepoPath points at this checkout.
Impact: starts one local API process, runs normal engine startup, then stops only that process.
#>
param([string]$RepoPath = (Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference = 'Stop'
$hostRoot = Join-Path (Resolve-Path -LiteralPath $RepoPath).Path 'src\backend\EmPoriumHouse.Api'
$assembly = Join-Path $hostRoot 'bin\Debug\net10.0\EmPoriumHouse.Api.dll'
if (-not (Test-Path -LiteralPath $assembly)) { throw 'Build the backend first.' }
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = $listener.LocalEndpoint.Port
$listener.Stop()
$logRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('nupak-host-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $logRoot | Out-Null
$outputLog = Join-Path $logRoot 'stdout.log'
$errorLog = Join-Path $logRoot 'stderr.log'
$process = $null
try {
    $process = Start-Process -FilePath 'dotnet' -ArgumentList @('exec', ('"' + $assembly + '"'), '--urls', "http://127.0.0.1:$port") -WorkingDirectory $hostRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $outputLog -RedirectStandardError $errorLog
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        if ($process.HasExited) { throw "API exited before readiness. Inspect logs in $logRoot locally." }
        try { $reply = Invoke-WebRequest -Uri "http://127.0.0.1:$port/nuget/v3/index.json" -SkipHttpErrorCheck -TimeoutSec 2 }
        catch { Start-Sleep -Milliseconds 250; continue }
        if ([int]$reply.StatusCode -ne 404) { throw "Expected legacy URL 404, received $($reply.StatusCode)." }
        $ready = $true
        break
    }
    if (-not $ready) { throw "API readiness timed out. Inspect logs in $logRoot locally." }
    foreach ($method in @('GET','HEAD','PUT','DELETE')) {
        foreach ($route in @('/nuget/v3/index.json','/nuget/v2/package','/nuget/unknown/v3/index.json')) {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port$route" -Method $method -SkipHttpErrorCheck -TimeoutSec 5
            if ([int]$response.StatusCode -ne 404) { throw "Expected 404 on $method $route." }
        }
    }
    Write-Output 'PASS real host startup; legacy and unknown-feed URLs return 404 for GET/HEAD/PUT/DELETE.'
} finally {
    if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id }
}
