# Shared rules for the noninteractive product release workflow.
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '..' 'upload-api-ghcr' 'versioning.ps1')

function Invoke-Checked {
    param([string]$Command, [string[]]$Arguments)
    $result = & $Command @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "$Command failed (exit $LASTEXITCODE): $result" }
    return $result
}

function Get-ReleaseSettings([string]$RepoRoot) {
    $settings = Get-Content (Join-Path $RepoRoot 'scripts/release-product/settings.json') -Raw | ConvertFrom-Json
    if ($settings.image -cnotmatch '^ghcr\.io/[a-z0-9][a-z0-9-]*/[a-z0-9][a-z0-9-]*$') { throw 'Invalid GHCR image name.' }
    if ($settings.automaticChannel -notin @('prealpha', 'alpha', 'beta', 'release')) { throw 'Invalid automatic channel.' }
    Get-NextVersionTag -Tags @() -Channel $settings.automaticChannel -Version $settings.automaticTargetVersion | Out-Null
    return $settings
}

function Assert-ProductVersion([string]$Version) {
    $parsed = @(Get-VersionTags @($Version))
    if ($parsed.Count -ne 1 -or $parsed[0].Build -lt 1 -or $parsed[0].Version -eq [version]'0.0.0') {
        throw 'Product version must be MAJOR.MINOR.PATCH-<prealpha|alpha|beta|release>.N, with N >= 1.'
    }
    return $parsed[0]
}

function ConvertTo-EngineVersion([string]$Version) {
    if ($Version -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$') {
        throw 'Engine version must be a NuGet semantic version without build metadata.'
    }
    $core = [long[]]@($Matches[1], $Matches[2], $Matches[3])
    $pre = [string[]]@(if ($Matches[4]) { $Matches[4].Split('.') })
    foreach ($part in $pre) {
        if ($part -match '^\d+$' -and $part.Length -gt 1 -and $part.StartsWith('0')) {
            throw 'Numeric prerelease identifiers cannot contain leading zeros.'
        }
    }
    return [pscustomobject]@{ Core = $core; Pre = $pre }
}

function Compare-EngineVersion([string]$Left, [string]$Right) {
    $a = ConvertTo-EngineVersion $Left
    $b = ConvertTo-EngineVersion $Right
    for ($i = 0; $i -lt 3; $i++) {
        if ($a.Core[$i] -ne $b.Core[$i]) { return $a.Core[$i].CompareTo($b.Core[$i]) }
    }
    if (-not $a.Pre.Count -or -not $b.Pre.Count) { return [Math]::Sign($b.Pre.Count - $a.Pre.Count) }
    for ($i = 0; $i -lt [Math]::Min($a.Pre.Count, $b.Pre.Count); $i++) {
        $leftNumeric = $a.Pre[$i] -match '^\d+$'
        $rightNumeric = $b.Pre[$i] -match '^\d+$'
        if ($leftNumeric -and $rightNumeric) { $result = ([bigint]$a.Pre[$i]).CompareTo([bigint]$b.Pre[$i]) }
        elseif ($leftNumeric) { $result = -1 }
        elseif ($rightNumeric) { $result = 1 }
        else { $result = [string]::CompareOrdinal($a.Pre[$i], $b.Pre[$i]) }
        if ($result -ne 0) { return [Math]::Sign($result) }
    }
    return [Math]::Sign($a.Pre.Count - $b.Pre.Count)
}

function Get-EngineVersion([string]$RepoRoot) {
    [xml]$props = Get-Content (Join-Path $RepoRoot 'Directory.Build.props') -Raw
    $nodes = @($props.SelectNodes('/Project/PropertyGroup/EmSysVersion'))
    if ($nodes.Count -ne 1) { throw 'Directory.Build.props must define EmSysVersion exactly once.' }
    $version = $nodes[0].InnerText.Trim()
    ConvertTo-EngineVersion $version | Out-Null
    return $version
}

function Get-ReleaseNotes([string]$RepoRoot) {
    $directory = Join-Path $RepoRoot 'doc/ReleaseNote'
    if (-not (Test-Path -LiteralPath $directory)) { return @() }
    return @(Get-ChildItem -LiteralPath $directory -Filter '*.md' -File |
        Where-Object BaseName -ne 'README' | ForEach-Object {
            Assert-ProductVersion $_.BaseName | Out-Null
            $content = Get-Content -LiteralPath $_.FullName -Raw
            $summary = [regex]::Match($content, '(?ms)^## Summary[ \t]*\r?\n(?<body>.*?)(?=^##[ \t]|\z)')
            if (-not $summary.Success -or -not $summary.Groups['body'].Value.Trim()) { throw "Missing Summary: $($_.Name)" }
            [pscustomobject]@{ Version = $_.BaseName; Path = $_.FullName; Content = $content }
        })
}

function Get-PendingReleaseNote([object[]]$Notes, [string[]]$PublishedVersions) {
    $pending = @($Notes | Where-Object Version -notin $PublishedVersions)
    if ($pending.Count -gt 1) { throw 'More than one pending product release note. Release one version per merge.' }
    if ($pending.Count) { return $pending[0] }
    return $null
}

function Assert-ReleaseIncreases([string]$Version, [string[]]$PublishedVersions) {
    $parsed = Assert-ProductVersion $Version
    $prior = @(Get-VersionTags $PublishedVersions | Where-Object { $_.Channel -eq $parsed.Channel } | Sort-Object Version, Build -Descending)
    if ($prior.Count -and ($parsed.Version -lt $prior[0].Version -or
        ($parsed.Version -eq $prior[0].Version -and $parsed.Build -le $prior[0].Build))) {
        throw 'The product version must increase within its channel.'
    }
}

function Get-RegistryContext([string]$Image) {
    $name = $Image.Substring('ghcr.io/'.Length)
    $auth = Invoke-RestMethod -Uri "https://ghcr.io/token?service=ghcr.io&scope=repository:${name}:pull"
    return @{ Base = "https://ghcr.io/v2/$name"; Headers = @{ Authorization = "Bearer $($auth.token)" } }
}

function Get-RegistryVersionTags([string]$Image) {
    $registry = Get-RegistryContext $Image
    $uri = "$($registry.Base)/tags/list?n=1000"
    $tags = [Collections.Generic.List[string]]::new()
    do {
        $response = Invoke-WebRequest -Uri $uri -Headers $registry.Headers
        $body = $response.Content | ConvertFrom-Json
        foreach ($tag in $body.tags) { $tags.Add($tag) }
        $uri = $null
        if ($response.Headers.ContainsKey('Link') -and "$($response.Headers.Link)" -match '<([^>]+)>;\s*rel="?next"?') {
            $uri = ([uri]::new([uri]'https://ghcr.io', $Matches[1])).AbsoluteUri
            if (([uri]$uri).Host -ne 'ghcr.io') { throw 'Unexpected registry pagination host.' }
        }
    } while ($uri)
    return $tags.ToArray()
}

function ConvertFrom-RegistryResponse($Response) {
    $json = if ($Response.Content -is [byte[]]) {
        [Text.Encoding]::UTF8.GetString($Response.Content)
    } else { [string]$Response.Content }
    return ($json | ConvertFrom-Json -AsHashtable)
}

function Get-RemoteImageLabels([string]$Image, [string]$Tag) {
    $registry = Get-RegistryContext $Image
    $headers = $registry.Headers.Clone()
    $headers.Accept = 'application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json, application/vnd.docker.distribution.manifest.list.v2+json, application/vnd.docker.distribution.manifest.v2+json'
    try {
        $manifest = ConvertFrom-RegistryResponse (Invoke-WebRequest -Uri "$($registry.Base)/manifests/$Tag" -Headers $headers -ErrorAction Stop)
    }
    catch {
        $response = $_.Exception.PSObject.Properties['Response']
        if ($response -and [int]$response.Value.StatusCode -eq 404) { return $null }
        throw
    }
    if ($manifest.ContainsKey('manifests')) {
        $platform = @($manifest.manifests | Where-Object { $_.platform.os -eq 'linux' -and $_.platform.architecture -eq 'amd64' })
        if ($platform.Count -ne 1) { throw 'Expected one linux/amd64 image in the manifest index.' }
        $manifest = ConvertFrom-RegistryResponse (Invoke-WebRequest -Uri "$($registry.Base)/manifests/$($platform[0].digest)" -Headers $headers)
    }
    $config = ConvertFrom-RegistryResponse (Invoke-WebRequest -Uri "$($registry.Base)/blobs/$($manifest.config.digest)" -Headers $registry.Headers)
    if (-not $config.config.ContainsKey('Labels')) { return @{} }
    return $config.config.Labels
}

function Get-EnginePackageIds([string]$RepoRoot) {
    $packageIds = @(Get-ChildItem (Join-Path $RepoRoot 'src') -Filter '*.csproj' -Recurse -File |
        ForEach-Object { [regex]::Matches((Get-Content $_.FullName -Raw), 'PackageReference\s+Include="(EmSys\.[^"]+)"') } |
        ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } | Sort-Object -Unique)
    if (-not $packageIds.Count) { throw 'No EmSys package references found.' }
    return $packageIds
}

# The highest version present for every package. A version still being pushed (only some packages are
# on the feed) is skipped, so a scheduled check never picks a half-published engine. Versions that are not
# valid engine versions are ignored.
function Select-LatestEngineVersion([hashtable]$VersionsByPackage) {
    $common = $null
    foreach ($versions in $VersionsByPackage.Values) {
        $set = @($versions | ForEach-Object { "$_".ToLowerInvariant() })
        $common = if ($null -eq $common) { $set } else { @($common | Where-Object { $_ -in $set }) }
    }
    $latest = $null
    foreach ($version in @($common)) {
        try { ConvertTo-EngineVersion $version | Out-Null } catch { continue }
        if (-not $latest -or (Compare-EngineVersion $version $latest) -gt 0) { $latest = $version }
    }
    return $latest
}

# Reads the published versions of every EmSys package the product references from nuget.org.
function Get-LatestEngineVersion([string]$RepoRoot) {
    $versionsByPackage = @{}
    foreach ($id in Get-EnginePackageIds $RepoRoot) {
        $index = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/$id/index.json" -TimeoutSec 30
        $versionsByPackage[$id] = @($index.versions)
    }
    return Select-LatestEngineVersion $versionsByPackage
}

function Wait-EnginePackages([string]$RepoRoot, [string]$Version, [int]$Attempts = 30) {
    $packageIds = Get-EnginePackageIds $RepoRoot
    $normalizedVersion = $Version.ToLowerInvariant()
    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        $missing = @($packageIds | Where-Object {
            $uri = "https://api.nuget.org/v3-flatcontainer/$_/$normalizedVersion/$_.${normalizedVersion}.nupkg"
            try { Invoke-WebRequest -Uri $uri -Method Head -TimeoutSec 10 | Out-Null; return $false }
            catch { return $true }
        })
        if (-not $missing.Count) { return }
        Write-Host "Waiting for NuGet $Version (attempt $attempt/$Attempts): $($missing -join ', ')"
        if ($attempt -lt $Attempts) { Start-Sleep -Seconds 10 }
    }
    throw "NuGet packages $Version are not ready. Main was not updated."
}

function Set-ReleaseOutputs([hashtable]$Values) {
    if ($env:GITHUB_OUTPUT) {
        foreach ($key in $Values.Keys) { "$key=$($Values[$key])" | Add-Content -LiteralPath $env:GITHUB_OUTPUT -Encoding utf8 }
    }
    Write-Host ($Values | ConvertTo-Json -Compress)
}
