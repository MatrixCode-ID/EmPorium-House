function Select-PublishChannel {
    $channels = @('release', 'beta', 'alpha', 'prealpha')
    $selected = 3
    Write-Host 'Pilih channel: panah atas/bawah atau angka 1-4, Enter untuk lanjut, Esc untuk batal.'
    # Redirected input cannot use ReadKey or cursor positioning.
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        Write-Host '1. release   2. beta   3. alpha   4. prealpha'
        while ($true) {
            $answer = (Read-Host 'Channel [4: prealpha]').Trim().ToLowerInvariant()
            if (-not $answer) { return 'prealpha' }
            if ($answer -match '^[1-4]$') { return $channels[[int]$answer - 1] }
            if ($answer -in $channels) { return $answer }
            Write-Host 'Pilih angka 1-4 atau nama channel.'
        }
    }
    $previousColor = [Console]::ForegroundColor
    try {
        # Reserve four rows first so the menu also works near the buffer bottom.
        foreach ($channel in $channels) { [Console]::WriteLine('') }
        $top = [Console]::CursorTop - $channels.Count
        while ($true) {
            for ($index = 0; $index -lt $channels.Count; $index++) {
                [Console]::SetCursorPosition(0, $top + $index)
                $marker = '  '
                [Console]::ForegroundColor = $previousColor
                if ($index -eq $selected) {
                    $marker = '>'
                    [Console]::ForegroundColor = [ConsoleColor]::Cyan
                }
                [Console]::Write(('{0,-2} {1}. {2,-9}' -f $marker, ($index + 1), $channels[$index]))
            }
            $key = [Console]::ReadKey($true)
            switch ($key.Key) {
                'UpArrow' { $selected = ($selected + $channels.Count - 1) % $channels.Count }
                'DownArrow' { $selected = ($selected + 1) % $channels.Count }
                'Enter' {
                    [Console]::SetCursorPosition(0, $top + $channels.Count)
                    Write-Host "Channel: $($channels[$selected])"
                    return $channels[$selected]
                }
                'Escape' { throw 'Pemilihan channel dibatalkan.' }
                default {
                    if ([string]$key.KeyChar -match '^[1-4]$') { $selected = [int]::Parse([string]$key.KeyChar) - 1 }
                }
            }
        }
    } finally {
        [Console]::ForegroundColor = $previousColor
        [Console]::SetCursorPosition(0, $top + $channels.Count)
    }
}
