<#
Purpose: build EmPoriumHouse.Api in local Docker, then optionally push GHCR.
Prerequisites: PowerShell 5.1+, Docker Linux/BuildKit.
Parameters: -Help. Configuration: GHCR_NAMESPACE, TZ.
Checks Docker API and Linux mode before login or any questions.
Checks saved Docker login; prompts for username and a hidden classic PAT
if missing or expired. PAT needs read:packages and write:packages.
Effects: builds and tags images; pushes only after an explicit yes. Does not
start containers, replace running containers, or save credentials in the repo.
Removes local tags for the unpublished candidate before rebuilding it.
#>
[CmdletBinding()]
param([switch]$Help)
$ErrorActionPreference = 'Stop'
if ($Help) {
    Write-Host 'Usage: scripts\upload-api-ghcr.cmd [-Help]'
    Write-Host 'Flow: Docker API check -> login if needed -> channel -> version -> local build -> push [y/N].'
    Write-Host 'Config: GHCR_NAMESPACE, TZ.'
    Write-Host 'Channel menu stays in CLI: Up/Down arrows or 1-4, Enter confirms, Esc cancels.'
    Write-Host 'Saved Docker GHCR login is reused for version checks and push.'
    Write-Host 'If needed, enter username and a hidden classic PAT (read:packages, write:packages).'
    exit 0
}
. "$PSScriptRoot\versioning.ps1"
. "$PSScriptRoot\auth.ps1"
. "$PSScriptRoot\channel.ps1"
. "$PSScriptRoot\local-image.ps1"

function Invoke-Docker {
    param([string[]]$Arguments)
    & docker @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Docker command failed: $($Arguments[0]) (exit $LASTEXITCODE)." }
}

function Get-RemoteTags {
    param([string]$Namespace)
    $headers = Get-GhcrAuthHeaders $script:GhcrCredential
    try {
        $auth = Invoke-RestMethod -Uri "https://ghcr.io/token?service=ghcr.io&scope=repository:${Namespace}/emporium-server:pull" -Headers $headers
        $uri = "https://ghcr.io/v2/$Namespace/emporium-server/tags/list?n=1000"
        $tags = @()
        while ($uri) {
            $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -Headers @{ Authorization = "Bearer $($auth.token)" }
            $tags += @((ConvertFrom-Json $response.Content).tags | Where-Object { $_ })
            $uri = $null
            if ($response.Headers.Link -match '<([^>]+)>;\s*rel="next"') {
                $uri = ([uri]::new([uri]'https://ghcr.io', $Matches[1])).AbsoluteUri
                if (-not $uri.StartsWith('https://ghcr.io/')) { throw 'Unexpected registry pagination host.' }
            }
        }
        return $tags
    } catch {
        # Only NAME_UNKNOWN means a new package; auth/network failures cannot
        # silently reset the build number.
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 404 -and $_.ErrorDetails.Message -match 'NAME_UNKNOWN') { return @() }
        throw 'Cannot read GHCR history. Check network, package access and PAT read:packages permission.'
    }
}

$originalLocation = Get-Location
try {
    $repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
    Set-Location -LiteralPath $repo
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker CLI is not on PATH.' }
    Write-Host 'Checking Docker API...'
    try {
        $os = Invoke-Docker -Arguments @('info', '--format', '{{.OSType}}')
    } catch {
        throw 'Docker API tidak dapat dihubungi. Jalankan Docker Desktop, tunggu engine siap, dan periksa Docker context/DOCKER_HOST, lalu jalankan script kembali.'
    }
    if ($os -ne 'linux') { throw 'Docker API tersedia, tetapi bukan Linux containers. Pilih Switch to Linux containers di Docker Desktop, lalu jalankan script kembali.' }
    Write-Host 'Docker API ready (Linux containers).'
    $script:GhcrCredential = Ensure-GhcrLogin
    $namespace = $env:GHCR_NAMESPACE
    if (-not $namespace) { $namespace = (Read-Host 'GHCR namespace [matrixcode-id]').Trim(); if (-not $namespace) { $namespace = 'matrixcode-id' } }
    if ($namespace -cnotmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') { throw 'GHCR namespace must be a lowercase account or organization name.' }
    $channel = Select-PublishChannel
    Write-Host 'Checking published tags in GHCR...'
    $remoteTags = @(Get-RemoteTags $namespace)
    $remoteImage = "ghcr.io/$namespace/emporium-server"
    # Unpublished local builds do not consume a version number.
    $tags = @($remoteTags | Select-Object -Unique)
    $versions = @(Get-VersionTags $tags | Sort-Object Version, Build -Descending)
    $previous = $versions | Where-Object Channel -eq $channel | Select-Object -First 1
    $defaultVersion = '0.1.0'
    if ($previous) {
        $defaultVersion = $previous.Version.ToString()
        Write-Host "Previous $channel tag: $($previous.Tag)"
    } elseif ($versions.Count) {
        $defaultVersion = $versions[0].Version.ToString()
        Write-Host "No previous $channel build; latest target version: $defaultVersion"
    } else { Write-Host 'No versioned images found. First target version: 0.1.0' }
    while ($true) {
        $version = (Read-Host "New target version [$defaultVersion]").Trim()
        if (-not $version) { $version = $defaultVersion }
        try { $tag = Get-NextVersionTag $tags $channel $version; break } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
    }
    $image = "emporium-server:$tag"
    $timezone = $env:TZ
    if (-not $timezone) { $timezone = 'Asia/Jakarta' }
    if (@(Get-RemoteTags $namespace) -contains $tag) { throw "Remote tag $tag was published during version selection. Run the script again to choose the next build." }
    Remove-LocalCandidateTags -Tag $tag -RemoteImage $remoteImage
    Write-Host "Building local image $image ..."
    Invoke-Docker -Arguments @('build', '--file', 'src/backend/EmPoriumHouse.Api/Dockerfile', '--target', 'final', '--build-arg', 'BUILD_CONFIGURATION=Release', '--build-arg', "APP_VERSION=$tag", '--build-arg', "TZ=$timezone", '--label', 'org.opencontainers.image.source=https://github.com/MatrixCode-ID/EmPorium-House', '--label', "org.opencontainers.image.version=$tag", '--tag', $image, '.')
    Invoke-Docker -Arguments @('image', 'inspect', $image, '--format', 'Local image: {{.Id}}')
    $answer = (Read-Host "Push $image to $remoteImage ? [y/N]").Trim().ToLowerInvariant()
    if ($answer -notin @('y', 'yes', 'ya')) { Write-Host "Finished locally: $image. GHCR was not changed."; exit 0 }
    if (@(Get-RemoteTags $namespace) -contains $tag) { throw "Remote tag $tag already exists; refusing to overwrite it. Local image is preserved." }
    $pushTags = @($tag, $channel)
    if ($channel -eq 'release') { $v = [version]$version; $pushTags += @('latest', "$($v.Major).$($v.Minor)", "$($v.Major)") }
    foreach ($pushTag in $pushTags) {
        $destination = "${remoteImage}:$pushTag"
        Invoke-Docker -Arguments @('tag', $image, $destination)
        Invoke-Docker -Arguments @('push', $destination)
        Write-Host "Uploaded $destination"
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.InvocationInfo.ScriptName) {
        Write-Host ('Location: {0}, line {1}' -f [IO.Path]::GetFileName($_.InvocationInfo.ScriptName), $_.InvocationInfo.ScriptLineNumber)
    }
    exit 1
} finally {
    $script:GhcrCredential = $null
    Set-Location -LiteralPath $originalLocation.Path
}
