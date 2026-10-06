function Get-VersionTags {
    param([string[]]$Tags)
    foreach ($tag in $Tags) {
        if ($tag -cmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-(prealpha|alpha|beta|release)\.([1-9][0-9]*))?$') {
            [pscustomobject]@{
                Tag = $tag
                Version = [version](($Matches[1], $Matches[2], $Matches[3]) -join '.')
                Channel = $(if ($Matches[4]) { $Matches[4] } else { 'release' })
                Build = $(if ($Matches[5]) { [long]$Matches[5] } else { 0 })
            }
        }
    }
}

function Get-NextVersionTag {
    param([string[]]$Tags, [string]$Channel, [string]$Version)
    if ($Channel -notin @('release', 'beta', 'alpha', 'prealpha')) { throw 'Invalid channel.' }
    if ($Version -cnotmatch '^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$' -or $Version -eq '0.0.0') {
        throw 'Use MAJOR.MINOR.PATCH, for example 0.1.0; 0.0.0 is not allowed.'
    }
    $parsedVersion = [version]$Version
    $existing = @(Get-VersionTags $Tags | Where-Object { $_.Channel -eq $Channel -and $_.Version -eq $parsedVersion })
    $number = 1L
    if ($existing.Count) { $number = ($existing | Measure-Object Build -Maximum).Maximum + 1L }
    return "$Version-$Channel.$number"
}
