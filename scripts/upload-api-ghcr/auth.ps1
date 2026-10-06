# Docker credential helper protocol: https://docs.docker.com/reference/cli/docker/login/
function Get-DockerGhcrCredential {
    $configDirectory = $env:DOCKER_CONFIG
    if (-not $configDirectory) { $configDirectory = Join-Path $env:USERPROFILE '.docker' }
    $configPath = Join-Path $configDirectory 'config.json'
    if (-not (Test-Path -LiteralPath $configPath)) { return $null }
    try { $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json } catch { throw 'Cannot read Docker config.json.' }
    $helper = $config.credHelpers.'ghcr.io'
    if (-not $helper) { $helper = $config.credsStore }
    if ($helper) {
        if ($helper -notmatch '^[a-zA-Z0-9_.-]+$') { throw 'Invalid Docker credential helper name.' }
        $command = Get-Command "docker-credential-$helper" -CommandType Application -ErrorAction SilentlyContinue
        if (-not $command) { throw 'Docker credential helper is missing from PATH. Check Docker Desktop installation.' }
        # Capture helper stdout privately; never echo JSON containing the secret.
        $previousPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $saved = 'ghcr.io' | & $command.Source get 2>$null
            $helperExitCode = $LASTEXITCODE
        } finally { $ErrorActionPreference = $previousPreference }
        if ($helperExitCode -ne 0) { return $null }
        try { $credential = ($saved -join "`n") | ConvertFrom-Json } catch { throw 'Invalid Docker credential helper response.' }
        if ($credential.Username -and $credential.Secret) {
            return [pscustomobject]@{ Username = $credential.Username; Secret = $credential.Secret }
        }
        return $null
    }
    $encoded = $config.auths.'ghcr.io'.auth
    if (-not $encoded) { return $null }
    try {
        $decoded = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
        $parts = $decoded -split ':', 2
        if ($parts.Count -eq 2 -and $parts[0] -and $parts[1]) {
            return [pscustomobject]@{ Username = $parts[0]; Secret = $parts[1] }
        }
    } catch { throw 'Invalid GHCR credential in Docker config.json.' }
    return $null
}

function Get-GhcrAuthHeaders {
    param($Credential)
    $pair = '{0}:{1}' -f $Credential.Username, $Credential.Secret
    return @{ Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair)) }
}

function Test-GhcrCredential {
    param($Credential)
    try {
        $token = Invoke-RestMethod -Uri 'https://ghcr.io/token?service=ghcr.io' -Headers (Get-GhcrAuthHeaders $Credential)
        return [bool]$token.token
    } catch {
        if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -in @(401, 403)) { return $false }
        throw 'Cannot contact GHCR to validate login. Check the network and try again.'
    }
}

function Ensure-GhcrLogin {
    Write-Host 'Checking saved GHCR login...'
    $credential = Get-DockerGhcrCredential
    if ($credential -and (Test-GhcrCredential $credential)) {
        Write-Host "GHCR login is valid: $($credential.Username)"
        return $credential
    }
    Write-Host 'GHCR login is missing or expired. Enter a GitHub classic PAT with read:packages and write:packages.'
    $username = $env:GHCR_USERNAME
    if ($credential) { $username = $credential.Username }
    $entered = (Read-Host "GitHub username [$username]").Trim()
    if ($entered) { $username = $entered }
    if ($username -notmatch '^[a-zA-Z0-9]+(?:-[a-zA-Z0-9]+)*$') { throw 'A valid GitHub username is required.' }
    $secureToken = Read-Host 'GitHub PAT (hidden)' -AsSecureString
    if (-not $secureToken.Length) { throw 'GitHub PAT cannot be empty.' }
    $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    try {
        $plainToken = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        # stdin keeps the PAT out of command arguments/history. Docker manages
        # persistence using its configured credential store.
        $plainToken | & docker login ghcr.io --username $username --password-stdin
        if ($LASTEXITCODE -ne 0) { throw 'GHCR login failed. Check the PAT and organization authorization.' }
        $credential = [pscustomobject]@{ Username = $username; Secret = $plainToken }
        if (-not (Test-GhcrCredential $credential)) { throw 'GHCR rejected the login credentials.' }
        return $credential
    } finally {
        $plainToken = $null
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        $secureToken.Dispose()
    }
}
