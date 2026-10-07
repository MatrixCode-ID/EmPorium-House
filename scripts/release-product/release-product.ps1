<#
.SYNOPSIS
Noninteractive helpers for CI and product releases. Running without a mode displays help.
.DESCRIPTION
Prepare resolves release notes, and an engine dispatch commits the engine upgrade to main.
The daily scheduled run does the same when nuget.org has a newer EmSys than main, in case a dispatch was missed.
BuildWpf creates a self-contained ZIP. Publish pushes GHCR tags and publishes a GitHub Release.
Prepare and Publish require gh authentication and access to the public product repository.
These mutating modes are restricted to its GitHub Actions main/tag runs. BuildWpf also works locally.
#>
[CmdletBinding()]
param(
    [ValidateSet('Help', 'Prepare', 'BuildWpf', 'Publish')][string]$Mode = 'Help',
    [string]$EngineVersion,
    [string]$Version,
    [string]$Commit,
    [string]$OutputDirectory,
    [string]$ImageArchive,
    [string]$ZipPath
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release-common.ps1')
$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..'))
$repository = 'MatrixCode-ID/EmPorium-House'

if ($Mode -eq 'Help') {
    Write-Host 'Build locally: scripts\release-product.cmd -Mode BuildWpf -Version 0.1.0-alpha.5 -OutputDirectory <outside-repo-folder>'
    Write-Host 'Prepare and Publish are called by .github/workflows/release.yml; they change the public repository/registry.'
    exit 0
}

Push-Location -LiteralPath $repoRoot
try {
    $settings = Get-ReleaseSettings $repoRoot
    if ($Mode -in @('Prepare', 'Publish')) {
        if ($env:GITHUB_ACTIONS -ne 'true' -or $env:GITHUB_REPOSITORY -cne $repository -or
            ($env:GITHUB_REF -ne 'refs/heads/main' -and $env:GITHUB_REF -notlike 'refs/tags/v*')) {
            throw 'Prepare/Publish must run in the public product repository on main or a release tag.'
        }
    }

    if ($Mode -eq 'Prepare') {
        if (@(Invoke-Checked git @('status', '--porcelain')).Count) { throw 'The release checkout must be clean.' }
        Invoke-Checked git @('fetch', '--no-tags', 'origin', 'main') | Out-Null
        Invoke-Checked git @('fetch', '--tags', 'origin') | Out-Null
        $scheduled = $env:GITHUB_EVENT_NAME -eq 'schedule'
        if ($env:GITHUB_EVENT_NAME -eq 'workflow_dispatch' -or $scheduled) {
            if ($env:GITHUB_REF -ne 'refs/heads/main') { throw 'Dispatch product releases on main.' }
            Invoke-Checked git @('checkout', '--detach', 'origin/main') | Out-Null
        }
        Invoke-Checked git @('merge-base', '--is-ancestor', 'HEAD', 'origin/main') | Out-Null
        $currentEngine = Get-EngineVersion $repoRoot
        # The scheduled run is the fallback for a missed engine dispatch: it only acts on an engine that is
        # newer than main's, and never publishes a pending product note on its own.
        if ($scheduled) {
            if ($EngineVersion -or $Version) { throw 'A scheduled run selects the engine version itself.' }
            $latestEngine = Get-LatestEngineVersion $repoRoot
            if (-not $latestEngine -or (Compare-EngineVersion $latestEngine $currentEngine) -le 0) {
                Write-Host "::notice::EmSys $currentEngine is up to date; nothing to release."
                Set-ReleaseOutputs @{ version = ''; sha = ''; engine = $currentEngine; image = $settings.image }
                exit 0
            }
            Write-Host "::notice::EmSys $latestEngine is on nuget.org; upgrading from $currentEngine."
            $EngineVersion = $latestEngine
        }
        $releaseJson = (Invoke-Checked gh @('release', 'list', '--repo', $repository, '--limit', '1000', '--json', 'tagName,isDraft')) -join "`n"
        $releases = @($releaseJson | ConvertFrom-Json)
        $published = @($releases | Where-Object { -not $_.isDraft } | ForEach-Object { $_.tagName -replace '^v', '' })
        $notes = @(Get-ReleaseNotes $repoRoot)
        $pending = Get-PendingReleaseNote $notes $published
        $gitVersions = @(Invoke-Checked git @('tag', '--list', 'v*') | ForEach-Object { "$_" -replace '^v', '' })
        $registryVersions = @(Get-RegistryVersionTags $settings.image)
        $reserved = @($gitVersions) + @($registryVersions) + @($notes | ForEach-Object Version)

        if ($EngineVersion) {
            if ($env:GITHUB_EVENT_NAME -notin @('workflow_dispatch', 'schedule') -or $env:GITHUB_REF -ne 'refs/heads/main') {
                throw 'Engine updates require workflow_dispatch or the schedule on main.'
            }
            $comparison = Compare-EngineVersion $EngineVersion $currentEngine
            if ($comparison -lt 0) {
                Write-Host '::notice::Ignoring an older engine version.'
                Set-ReleaseOutputs @{ version = ''; sha = ''; engine = $currentEngine; image = $settings.image }
                exit 0
            }
            if ($comparison -gt 0) {
                if ($Version) { throw 'An engine update selects the product version automatically; omit release_version.' }
                if ($pending) {
                    Assert-ReleaseIncreases $pending.Version $published
                    if ($pending.Version -in $gitVersions -or $pending.Version -in $registryVersions) {
                        throw 'An unfinished release already has a tag/image. Resume it before accepting another engine update.'
                    }
                }
                Wait-EnginePackages $repoRoot $EngineVersion
                if (-not $pending) {
                    $next = Get-NextVersionTag -Tags $reserved -Channel $settings.automaticChannel -Version $settings.automaticTargetVersion
                    $notePath = Join-Path $repoRoot "doc/ReleaseNote/$next.md"
                    New-Item -ItemType Directory -Path (Split-Path $notePath) -Force | Out-Null
                    $noteBody = "# EmPorium House $next`n`n## Summary`n`nUpgrade the shared EmSys engine from $currentEngine to $EngineVersion.`n`n## Upgrade notes`n`nThis product release uses EmSys $EngineVersion. Review the [engine release notes](https://github.com/MatrixCode-ID/em-system/releases/tag/v$EngineVersion) for compatibility and database migration requirements.`n"
                    [IO.File]::WriteAllText($notePath, $noteBody)
                } else {
                    $notePath = $pending.Path
                    [IO.File]::AppendAllText($notePath, "`n## Engine update`n`nUpgrade EmSys from $currentEngine to $EngineVersion. See the [engine release notes](https://github.com/MatrixCode-ID/em-system/releases/tag/v$EngineVersion).`n")
                }
                $propsPath = Join-Path $repoRoot 'Directory.Build.props'
                $props = Get-Content -LiteralPath $propsPath -Raw
                $props = [regex]::Replace($props, '(?<=<EmSysVersion>)[^<]+(?=</EmSysVersion>)', $EngineVersion)
                [IO.File]::WriteAllText($propsPath, $props)
                Invoke-Checked git @('config', 'user.name', 'github-actions[bot]') | Out-Null
                Invoke-Checked git @('config', 'user.email', '41898282+github-actions[bot]@users.noreply.github.com') | Out-Null
                $relativeNote = [IO.Path]::GetRelativePath($repoRoot, $notePath).Replace('\', '/')
                Invoke-Checked git @('add', '--', 'Directory.Build.props', $relativeNote) | Out-Null
                Invoke-Checked git @('commit', '-m', "Upgrade EmSys to $EngineVersion") | Out-Null
                Invoke-Checked git @('push', 'origin', 'HEAD:refs/heads/main') | Out-Null
                $currentEngine = $EngineVersion
                $notes = @(Get-ReleaseNotes $repoRoot)
                $pending = Get-PendingReleaseNote $notes $published
            }
        }

        if ($env:GITHUB_REF -like 'refs/tags/v*') { $Version = $env:GITHUB_REF.Substring('refs/tags/v'.Length) }
        if ($Version) {
            Assert-ProductVersion $Version | Out-Null
            $selected = @($notes | Where-Object Version -ceq $Version)
            if ($selected.Count -ne 1) { throw "Release note doc/ReleaseNote/$Version.md is missing." }
            # An explicit version can finish alias promotion after publication has already succeeded.
            $pending = $selected[0]
        }
        if (-not $pending) {
            Write-Host '::notice::No unpublished product release note; nothing to release.'
            Set-ReleaseOutputs @{ version = ''; sha = ''; engine = $currentEngine; image = $settings.image }
            exit 0
        }
        if ($pending.Version -notin $published) { Assert-ReleaseIncreases $pending.Version $published }
        # Resume a draft from its original tag when main has advanced since preparation.
        if ($pending.Version -in $gitVersions -and $env:GITHUB_EVENT_NAME -eq 'workflow_dispatch') {
            Invoke-Checked git @('checkout', '--detach', "v$($pending.Version)") | Out-Null
            Invoke-Checked git @('merge-base', '--is-ancestor', 'HEAD', 'origin/main') | Out-Null
            $currentEngine = Get-EngineVersion $repoRoot
            if ($EngineVersion -and (Compare-EngineVersion $EngineVersion $currentEngine) -ne 0) {
                throw 'The unfinished release uses another engine version. Resume it without emsys_version.'
            }
            $settings = Get-ReleaseSettings $repoRoot
        }
        $sha = "$(Invoke-Checked git @('rev-parse', 'HEAD'))".Trim()
        & git rev-parse --verify "refs/tags/v$($pending.Version)" *> $null
        if ($LASTEXITCODE -eq 0) {
            $tagCommit = "$(Invoke-Checked git @('rev-parse', "v$($pending.Version)^{commit}"))".Trim()
            if ($tagCommit -ne $sha) { throw 'An existing release tag points to another commit.' }
        }
        Set-ReleaseOutputs @{ version = $pending.Version; sha = $sha; engine = $currentEngine; image = $settings.image }
    }

    if ($Mode -eq 'BuildWpf') {
        Assert-ProductVersion $Version | Out-Null
        if (-not $OutputDirectory) { throw 'OutputDirectory is required.' }
        $out = [IO.Path]::GetFullPath($OutputDirectory)
        $publish = Join-Path $out 'publish'
        if (Test-Path -LiteralPath $publish) { throw 'Use a fresh output directory; existing publish files are preserved.' }
        New-Item -ItemType Directory -Path $publish -Force | Out-Null
        $arguments = @('publish', 'src/frontend/EmPoriumHouse.Ui.Wpf/EmPoriumHouse.Ui.Wpf.csproj', '--configuration', 'Release',
            '--runtime', 'win-x64', '--self-contained', 'true', '--output', $publish, "-p:Version=$Version",
            '-p:PublishSingleFile=true', '-p:IncludeNativeLibrariesForSelfExtract=true', '-p:EnableCompressionInSingleFile=true',
            '-p:DebugType=None', '-p:DebugSymbols=false', "-p:ArtefactsPath=$(Join-Path $out 'machine-local')")
        Invoke-Checked dotnet $arguments | ForEach-Object { Write-Host $_ }
        $exe = Join-Path $publish 'EmPoriumHouse.exe'
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'The desktop executable was not produced.' }
        $zip = Join-Path $out "EmPorium-House.$Version.zip"
        $archive = [IO.Compression.ZipFile]::Open($zip, [IO.Compression.ZipArchiveMode]::Create)
        try {
            [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $exe, 'EmPoriumHouse.exe', [IO.Compression.CompressionLevel]::SmallestSize) | Out-Null
        } finally { $archive.Dispose() }
        Write-Host "ZIP created: $zip"
    }

    if ($Mode -eq 'Publish') {
        $parsed = Assert-ProductVersion $Version
        if ($Commit -cnotmatch '^[0-9a-f]{40}$') { throw 'Commit must be a full Git SHA.' }
        if ("$(Invoke-Checked git @('rev-parse', 'HEAD'))".Trim() -ne $Commit) { throw 'The publish checkout does not match the build commit.' }
        $engine = Get-EngineVersion $repoRoot
        if ($engine -cne $EngineVersion) { throw 'The engine version does not match the build inputs.' }
        if (-not (Test-Path -LiteralPath $ImageArchive -PathType Leaf) -or -not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
            throw 'The image archive and ZIP are required.'
        }
        $image = $settings.image
        $fixedTag = "${image}:$Version"
        Invoke-Checked docker @('load', '--input', $ImageArchive) | ForEach-Object { Write-Host $_ }
        $localJson = (Invoke-Checked docker @('image', 'inspect', $fixedTag, '--format', '{{json .Config.Labels}}')) -join "`n"
        $localLabels = $localJson | ConvertFrom-Json -AsHashtable
        foreach ($pair in @(@('org.opencontainers.image.revision', $Commit), @('org.opencontainers.image.version', $Version), @('io.matrixcode.emsys.version', $engine))) {
            if ($localLabels[$pair[0]] -cne $pair[1]) { throw "Image label mismatch: $($pair[0])" }
        }
        $remoteLabels = Get-RemoteImageLabels $image $Version
        if ($null -ne $remoteLabels) {
            foreach ($key in @('org.opencontainers.image.revision', 'org.opencontainers.image.version', 'io.matrixcode.emsys.version')) {
                if ($remoteLabels[$key] -cne $localLabels[$key]) { throw 'The fixed image tag is already used by another build; it will not be overwritten.' }
            }
            # Reuse the exact published image when resuming a partially completed release.
            Invoke-Checked docker @('pull', $fixedTag) | Out-Null
        } else {
            Invoke-Checked docker @('push', $fixedTag) | ForEach-Object { Write-Host $_ }
        }

        $tag = "v$Version"
        $releaseRaw = & gh release view $tag --repo $repository --json isDraft 2>$null
        $exists = $LASTEXITCODE -eq 0
        if ($exists) {
            Invoke-Checked git @('fetch', 'origin', "refs/tags/${tag}:refs/tags/$tag") | Out-Null
            if ("$(Invoke-Checked git @('rev-parse', "$tag^{commit}"))".Trim() -ne $Commit) { throw 'The GitHub Release tag points to another commit.' }
            $draft = ($releaseRaw | ConvertFrom-Json).isDraft
        } else {
            $flags = @('release', 'create', $tag, '--repo', $repository, '--target', $Commit, '--draft', '--title', "EmPorium House $Version",
                '--notes-file', "doc/ReleaseNote/$Version.md")
            if ($parsed.Channel -ne 'release') { $flags += '--prerelease' }
            Invoke-Checked gh $flags | Out-Null
            $draft = $true
        }
        if ($draft) {
            Invoke-Checked gh @('release', 'upload', $tag, $ZipPath, '--repo', $repository, '--clobber') | Out-Null
            $flags = @('release', 'edit', $tag, '--repo', $repository, '--draft=false', '--latest=false')
            if ($parsed.Channel -eq 'release') { $flags[-1] = '--latest=true' }
            Invoke-Checked gh $flags | Out-Null
        }

        $channelLabels = Get-RemoteImageLabels $image $parsed.Channel
        $promote = $true
        if ($null -ne $channelLabels -and $channelLabels.ContainsKey('org.opencontainers.image.version')) {
            $current = @(Get-VersionTags @($channelLabels['org.opencontainers.image.version']))
            if ($current.Count -and ($current[0].Version -gt $parsed.Version -or
                ($current[0].Version -eq $parsed.Version -and $current[0].Build -gt $parsed.Build))) { $promote = $false }
        }
        if ($promote) {
            $aliases = @($parsed.Channel)
            if ($parsed.Channel -eq 'release') { $aliases += @('latest', "$($parsed.Version.Major).$($parsed.Version.Minor)", "$($parsed.Version.Major)") }
            foreach ($alias in $aliases) {
                Invoke-Checked docker @('tag', $fixedTag, "${image}:$alias") | Out-Null
                Invoke-Checked docker @('push', "${image}:$alias") | ForEach-Object { Write-Host $_ }
            }
        }
        Write-Host "Published $repository $tag with EmSys $engine and $fixedTag"
    }
} finally {
    Pop-Location
}
# Probes for something that may not exist yet (a release tag, a GitHub Release) leave a non-zero
# $LASTEXITCODE behind, and the Actions pwsh shell exits with it. Every real failure throws, so reaching
# this line means success.
exit 0
