function Remove-LocalCandidateTags {
    param([string]$Tag, [string]$RemoteImage)
    $references = @("emporium-server:$Tag", "${RemoteImage}:$Tag")
    $existing = @(Invoke-Docker -Arguments @('image', 'ls', '--format', '{{.Repository}}:{{.Tag}}'))
    foreach ($reference in $references) {
        if ($existing -contains $reference) {
            Write-Host "Removing previous local candidate $reference ..."
            # Remove only this candidate tag. No force, container deletion or
            # broad prune; Docker preserves images used by running containers.
            Invoke-Docker -Arguments @('image', 'rm', $reference)
        }
    }
}
