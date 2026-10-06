<#
Purpose: test automatic GHCR login with dummy credentials and mocked Docker/HTTP.
Prerequisites: Windows PowerShell 5.1+; no Docker daemon or GitHub access needed.
Parameters: none. Run in a fresh PowerShell process, not by dot-sourcing.
Effects: creates/removes its own temporary dummy config/helper; temporarily
changes environment in this process. Does not access real saved credentials,
contact GitHub, log in to Docker, build images, or push packages.
#>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
. (Join-Path $repo 'scripts\upload-api-ghcr\auth.ps1')
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('emporium-auth-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testDirectory | Out-Null
$previousConfig = $env:DOCKER_CONFIG
$previousPath = $env:PATH
$previousUsername = $env:GHCR_USERNAME
$env:DOCKER_CONFIG = $testDirectory
$env:GHCR_USERNAME = $null
$global:testPrompts = 0
$global:testLogins = 0
function global:Read-Host {
    param($Prompt, [switch]$AsSecureString)
    $global:testPrompts++
    if ($AsSecureString) { return (ConvertTo-SecureString 'dummy-test-secret' -AsPlainText -Force) }
    return 'test-user'
}
function global:docker {
    if ($args[0] -ne 'login' -or $args -notcontains '--password-stdin' -or $args -contains 'dummy-test-secret') { throw 'Unsafe login invocation' }
    $received = @($input)
    if ($received[0] -ne 'dummy-test-secret') { throw 'PAT not delivered through stdin' }
    $global:testLogins++
    $global:LASTEXITCODE = 0
}
function global:Invoke-RestMethod {
    param($Uri, $Headers)
    if (-not $Headers.Authorization.StartsWith('Basic ')) { throw 'Missing authorization' }
    return @{ token = 'mock-token' }
}
try {
    $credential = Ensure-GhcrLogin
    if ($credential.Username -ne 'test-user' -or $global:testLogins -ne 1 -or $global:testPrompts -ne 2) { throw 'Missing login flow failed' }
    Write-Output 'PASS: missing credentials request username and hidden PAT, sent via stdin.'
    $auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('test-user:dummy-test-secret'))
    @{ auths = @{ 'ghcr.io' = @{ auth = $auth } } } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$testDirectory/config.json"
    $credential = Ensure-GhcrLogin
    if ($global:testPrompts -ne 2 -or $global:testLogins -ne 1) { throw 'Cached login prompted again' }
    Write-Output 'PASS: valid cached Docker login is reused without prompting.'
    function Test-GhcrCredential { param($Credential); return ($Credential.Secret -ne 'expired-secret') }
    $auth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('test-user:expired-secret'))
    @{ auths = @{ 'ghcr.io' = @{ auth = $auth } } } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$testDirectory/config.json"
    $credential = Ensure-GhcrLogin
    if ($global:testPrompts -ne 4 -or $global:testLogins -ne 2) { throw 'Expired credential was not replaced' }
    Write-Output 'PASS: expired credentials trigger login again.'
    @'
@echo off
set /p registry=
echo {"Username":"helper-user","Secret":"dummy-test-secret"}
'@ | Set-Content -LiteralPath "$testDirectory/docker-credential-mock.cmd" -Encoding ascii
    $env:PATH = "$testDirectory;$previousPath"
    @{ credHelpers = @{ 'ghcr.io' = 'mock' }; credsStore = 'missing-default' } | ConvertTo-Json | Set-Content -LiteralPath "$testDirectory/config.json"
    $credential = Get-DockerGhcrCredential
    if ($credential.Username -ne 'helper-user') { throw 'Registry helper precedence failed' }
    Write-Output 'PASS: registry credential helper takes precedence over default store.'
    @{ credsStore = 'mock' } | ConvertTo-Json | Set-Content -LiteralPath "$testDirectory/config.json"
    $credential = Get-DockerGhcrCredential
    if ($credential.Username -ne 'helper-user') { throw 'Default credential store failed' }
    Write-Output 'PASS: default credential store.'
    Get-ChildItem (Join-Path $repo 'scripts\upload-api-ghcr\*.ps1') | ForEach-Object {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$parseErrors) | Out-Null
        if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
    }
    Write-Output 'PASS: PowerShell syntax.'
    & (Join-Path $repo 'scripts\upload-api-ghcr.cmd') -Help
    if ($LASTEXITCODE -ne 0) { throw 'CMD help failed' }
    git -C $repo diff --check
    if ($LASTEXITCODE -ne 0) { throw 'Diff check failed' }
} finally {
    $env:DOCKER_CONFIG = $previousConfig
    $env:PATH = $previousPath
    $env:GHCR_USERNAME = $previousUsername
    $resolved = [IO.Path]::GetFullPath($testDirectory)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved) -notlike 'emporium-auth-test-*') { throw 'Unexpected test cleanup path' }
    Remove-Item -LiteralPath $resolved -Recurse -Force
}
