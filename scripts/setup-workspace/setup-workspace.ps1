<#
.SYNOPSIS
Configures the EmPorium House workspace after its first clone.
.DESCRIPTION
Uses private/work-bench for development and origin/main for public releases.
An existing clone is configured in place; a standalone copy can clone the private
repository into <ParentDir>/EmPorium. Requires Git and access to both repositories.
Creates tracking branches and changes remotes; never pushes, deletes branches,
resets commits, or discards local changes. Machine-local artifacts are not cloned.
.PARAMETER ParentDir
Existing parent directory for a new clone when the script is outside a repository.
#>
[CmdletBinding()]
param([string]$ParentDir)

$ErrorActionPreference = 'Stop'
$privateUrl = 'https://github.com/MatrixCode-ID/EmPorium-House-work.git'
$publicUrl = 'https://github.com/MatrixCode-ID/EmPorium-House.git'

function Invoke-Git {
    $result = & git @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Git command failed: $result" }
    return $result
}

function Get-RemoteUrl([string]$Name) {
    $result = & git remote get-url $Name 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return "$result".Trim()
}

function Get-RepositoryIdentity([string]$Url) {
    if ($Url -match '^https://github\.com/([^/]+/[^/]+?)(?:\.git)?/?$' -or
        $Url -match '^git@github\.com:([^/]+/[^/]+?)(?:\.git)?/?$' -or
        $Url -match '^ssh://git@github\.com/([^/]+/[^/]+?)(?:\.git)?/?$') {
        return $Matches[1].ToLowerInvariant()
    }
    return ''
}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git was not found on PATH.' }
$candidate = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..' '..'))
& git -C $candidate rev-parse --show-toplevel 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    $repoRoot = (& git -C $candidate rev-parse --show-toplevel).Trim()
} else {
    if ([string]::IsNullOrWhiteSpace($ParentDir)) {
        $defaultParent = (Get-Location).Path
        $ParentDir = Read-Host "Parent folder for the clone [$defaultParent]"
        if ([string]::IsNullOrWhiteSpace($ParentDir)) { $ParentDir = $defaultParent }
    }
    $ParentDir = [IO.Path]::GetFullPath($ParentDir.Trim().Trim('"'))
    if (-not (Test-Path -LiteralPath $ParentDir -PathType Container)) { throw 'The parent directory does not exist.' }
    $repoRoot = Join-Path $ParentDir 'EmPorium'
    if (Test-Path -LiteralPath $repoRoot) { throw 'EmPorium already exists. Run its scripts/setup-workspace.cmd instead.' }
    Invoke-Git clone --origin private $privateUrl $repoRoot | Out-Null
}

Push-Location -LiteralPath $repoRoot
try {
    $originUrl = Get-RemoteUrl origin
    $privateRemoteUrl = Get-RemoteUrl private
    $originIdentity = Get-RepositoryIdentity $originUrl
    $privateIdentity = Get-RepositoryIdentity $privateRemoteUrl
    $expectedPrivate = Get-RepositoryIdentity $privateUrl
    $expectedPublic = Get-RepositoryIdentity $publicUrl

    # Validate every existing remote before changing any configuration.
    if ($privateRemoteUrl -and $privateIdentity -ne $expectedPrivate) {
        throw 'Remote private belongs to another repository. No remotes were changed.'
    }
    if ($originUrl -and $originIdentity -notin @($expectedPublic, $expectedPrivate)) {
        throw 'Remote origin belongs to another repository. No remotes were changed.'
    }
    if (-not $originUrl -and -not $privateRemoteUrl) {
        throw 'This is not a recognized EmPorium House clone. No remotes were changed.'
    }
    foreach ($remote in @('origin', 'private')) {
        $url = Get-RemoteUrl $remote
        if (-not $url) { continue }
        $identity = Get-RepositoryIdentity $url
        $pushUrls = @(Invoke-Git remote get-url --push --all $remote)
        if (@($pushUrls | Where-Object { (Get-RepositoryIdentity "$_") -ne $identity }).Count) {
            throw "Remote $remote has an unexpected push URL. No remotes were changed."
        }
    }
    if ($originIdentity -eq $expectedPrivate) {
        if ($privateRemoteUrl) {
            Invoke-Git remote set-url origin $publicUrl | Out-Null
            & git config --unset-all remote.origin.pushurl
            if ($LASTEXITCODE -notin @(0, 5)) { throw 'Could not clear the old origin push URL.' }
        } else {
            Invoke-Git remote rename origin private | Out-Null
            Invoke-Git remote add origin $publicUrl | Out-Null
        }
    } elseif (-not $originUrl) {
        Invoke-Git remote add origin $publicUrl | Out-Null
    }
    if (-not (Get-RemoteUrl private)) { Invoke-Git remote add private $privateUrl | Out-Null }

    # An explicit push URL must not direct a development push to the public repository.
    foreach ($remote in @('private', 'origin')) {
        $expected = if ($remote -eq 'private') { $expectedPrivate } else { $expectedPublic }
        $pushUrls = @(Invoke-Git remote get-url --push --all $remote)
        if (@($pushUrls | Where-Object { (Get-RepositoryIdentity "$_") -ne $expected }).Count) {
            throw "Remote $remote has an unexpected push URL. Check Git configuration before pushing."
        }
        Invoke-Git config --replace-all "remote.$remote.push" $(if ($remote -eq 'private') {
            'refs/heads/work-bench:refs/heads/work-bench'
        } else { 'refs/heads/main:refs/heads/main' }) | Out-Null
    }

    Invoke-Git fetch --prune private | Out-Null
    Invoke-Git fetch --prune origin | Out-Null
    & git rev-parse --verify refs/remotes/private/work-bench *> $null
    if ($LASTEXITCODE -ne 0) { throw 'private/work-bench is missing. Seed the private repository first.' }

    $tracking = [ordered]@{ 'work-bench' = 'private'; 'main' = 'origin'; 'ci-sandbox' = 'origin' }
    foreach ($branch in $tracking.Keys) {
        $remote = $tracking[$branch]
        & git rev-parse --verify "refs/remotes/$remote/$branch" *> $null
        if ($LASTEXITCODE -ne 0) { continue }
        & git rev-parse --verify "refs/heads/$branch" *> $null
        if ($LASTEXITCODE -eq 0) {
            Invoke-Git branch --set-upstream-to "$remote/$branch" $branch | Out-Null
        } else {
            Invoke-Git branch --track $branch "$remote/$branch" | Out-Null
        }
        Invoke-Git config "branch.$branch.pushRemote" $remote | Out-Null
    }
    Invoke-Git config remote.pushDefault private | Out-Null
    Invoke-Git config push.default simple | Out-Null

    $current = "$(Invoke-Git branch --show-current)".Trim()
    if ($current -ne 'work-bench') {
        if (@(Invoke-Git status --porcelain).Count) {
            Write-Host "Local changes were preserved; the active branch remains '$current'."
        } else {
            Invoke-Git switch work-bench | Out-Null
        }
    }
    Invoke-Git remote -v | ForEach-Object { Write-Host $_ }
    Invoke-Git branch -vv | ForEach-Object { Write-Host $_ }
    Write-Host 'Work on work-bench. Publish main explicitly to origin.'
    Write-Host 'Copy ../.artefacts/EmPorium from the previous machine separately; it is not in Git.'
} finally {
    Pop-Location
}
