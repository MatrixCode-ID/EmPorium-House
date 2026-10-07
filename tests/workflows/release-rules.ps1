# Maintained checks for version allocation and release-note selection. No GitHub writes.
[CmdletBinding()]
param([string]$FixtureDirectory)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..' '..' 'scripts' 'release-product' 'release-common.ps1')
if (-not $FixtureDirectory) {
    $FixtureDirectory = Join-Path $PSScriptRoot '..' '..' '..' '.artefacts' 'EmPorium' 'scripts' 'release-rules-tests' ([guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Path $FixtureDirectory -Force | Out-Null
$checks = 0
function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -cne $Expected) { throw "$Message (expected '$Expected', received '$Actual')" }
    $script:checks++
}
function Assert-Rejected([scriptblock]$Action, [string]$Message) {
    $rejected = $false
    try { & $Action | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw "$Message was not rejected." }
    $script:checks++
}

Assert-Equal (Get-NextVersionTag @('0.1.0-alpha.1', '0.1.0-alpha.4', 'alpha') 'alpha' '0.1.0') '0.1.0-alpha.5' 'Advance product build'
Assert-Equal (Get-NextVersionTag @('0.1.0-alpha.4', '0.1.0-alpha.9') 'alpha' '0.1.0') '0.1.0-alpha.10' 'Reserve existing GHCR build numbers'
Assert-Equal (Get-NextVersionTag @('0.1.0-alpha.9') 'beta' '0.1.0') '0.1.0-beta.1' 'Reset the counter on a new channel'
Assert-Equal (Get-NextVersionTag @('0.1.0-beta.1') 'beta' '0.1.0') '0.1.0-beta.2' 'Advance beta'
Assert-Equal (Get-NextVersionTag @('0.1.0-release.3') 'release' '0.1.0') '0.1.0-release.4' 'Retain the product release suffix'
Assert-Equal (Get-NextVersionTag @('0.1.0-alpha.9') 'alpha' '0.2.0') '0.2.0-alpha.1' 'Reset a new target version'
Assert-Equal (Compare-EngineVersion '0.1.0-alpha.10' '0.1.0-alpha.9') 1 'Compare numeric prerelease identifiers'
Assert-Equal (Compare-EngineVersion '0.1.0-alpha.4' '0.1.0-alpha.4') 0 'Identify duplicate engine events'
Assert-Equal (Compare-EngineVersion '0.1.0-alpha.3' '0.1.0-alpha.4') -1 'Reject stale engine events'
Assert-Equal (Compare-EngineVersion '0.1.0' '0.1.0-rc.1') 1 'Compare stable engine versions'
Assert-Equal (Compare-EngineVersion '0.1.0-0.prealpha.2' '0.1.0-0.prealpha.1') 1 'Accept NuGet prealpha syntax'
Assert-Rejected { ConvertTo-EngineVersion '0.1.0-alpha.01' } 'Leading zero prerelease identifier'
Assert-Rejected { ConvertTo-EngineVersion '0.1.0-alpha.5; echo secret' } 'Unsafe version input'
Assert-Rejected { Assert-ProductVersion '0.1.0' } 'Missing product build suffix'
Assert-Rejected { Assert-ProductVersion '0.1.0-alpha.0' } 'Zero product build'
Assert-Rejected { Assert-ProductVersion '../0.1.0-alpha.1' } 'Release note path traversal'
Assert-ReleaseIncreases '0.1.0-beta.1' @('0.1.0-alpha.4')
$checks++
Assert-Rejected { Assert-ReleaseIncreases '0.1.0-alpha.3' @('0.1.0-alpha.4') } 'Product version downgrade'

$noteDirectory = Join-Path $FixtureDirectory 'doc/ReleaseNote'
New-Item -ItemType Directory -Path $noteDirectory -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $noteDirectory 'README.md'), 'Not a version.')
[IO.File]::WriteAllText((Join-Path $noteDirectory '0.1.0-alpha.5.md'), "# Product`n`n## Summary`n`nNew Home card.`n")
$notes = @(Get-ReleaseNotes $FixtureDirectory)
Assert-Equal $notes.Count 1 'Exclude README from release notes'
Assert-Equal (Get-PendingReleaseNote $notes @('0.1.0-alpha.4')).Version '0.1.0-alpha.5' 'Select the pending note'
Assert-Equal (Get-PendingReleaseNote $notes @('0.1.0-alpha.5')) $null 'Exclude published notes'
[IO.File]::WriteAllText((Join-Path $noteDirectory '0.1.0-alpha.6.md'), "# Product`n`n## Summary`n`nAnother change.`n")
Assert-Rejected { Get-PendingReleaseNote @(Get-ReleaseNotes $FixtureDirectory) @() } 'Two pending releases'
[IO.File]::WriteAllText((Join-Path $noteDirectory '0.1.0-alpha.6.md'), "# Product`n`n## Summary`n`n## Fixes`n`nA fix.`n")
Assert-Rejected { Get-ReleaseNotes $FixtureDirectory } 'Empty summary followed by another section'
Assert-Equal (ConvertFrom-RegistryResponse @{ Content = '{"schemaVersion":2}' }).schemaVersion 2 'Decode a JSON manifest'
Assert-Equal (ConvertFrom-RegistryResponse @{ Content = [Text.Encoding]::UTF8.GetBytes('{"schemaVersion":2}') }).schemaVersion 2 'Decode a binary OCI response'
Write-Host "$checks release-rule checks passed."
