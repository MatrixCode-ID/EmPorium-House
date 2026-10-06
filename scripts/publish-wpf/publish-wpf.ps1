<#
Tujuan   : publish klien WPF EmPoriumHouse.Ui.Wpf menjadi satu aplikasi (single file, self-contained,
           win-x64), mengemasnya menjadi EmPorium-House.<versi>.zip (isi: EmPoriumHouse.exe), lalu
           bertanya (y/N) apakah zip diunggah ke GitHub Release v<versi> sebagai asset. GitHub Packages tidak
           menyimpan exe/zip biasa (hanya NuGet, npm, Maven, RubyGems, container); Release adalah tempatnya.
Versi    : cara kerjanya sama dengan skrip container (scripts\upload-api-ghcr): skrip memakai ulang
           upload-api-ghcr\channel.ps1 dan versioning.ps1, menanyakan channel (release, beta, alpha, prealpha) dan
           versi target, lalu menghitung nomor build berikutnya dari riwayat di GitHub (Release dan tag v*).
           Hasil: <MAJOR.MINOR.PATCH>-<channel>.<N>, mis. 0.1.0-alpha.1; build yang belum diunggah tidak memakai nomor.
Prasyarat: Windows, .NET SDK 10, akses ke nuget.org (restore paket engine dan runtime pack win-x64),
           GitHub CLI (gh) sudah login (gh auth login) untuk membaca riwayat versi dan mengunggah.
Parameter: -Version        lewati pertanyaan dan pakai versi lengkap ini, mis. 0.1.0-alpha.2 (tetap dicek ke GitHub).
           -Repo           repo GitHub untuk Release (default MatrixCode-ID/EmPorium-House).
           -FrameworkDependent  tanpa runtime .NET di dalam exe (kecil, tapi pemakai butuh .NET 10 Desktop Runtime).
           -Runtime        RID target (default win-x64).
           -DryRun         build dan zip tetap jalan, tetapi upload hanya dicetak, tidak dijalankan.
           -NoExplorer     jangan membuka Explorer ke folder hasil (default: dibuka dengan zip terpilih setelah
                           pertanyaan upload dijawab tidak, atau setelah upload ke GitHub selesai).
Dampak   : semua keluaran, termasuk data sementara, ditulis di luar repo pada ..\.artefacts\EmPorium\release\
           (folder artefak repo ini; ganti dengan environment variable ArtefactsPath, sama seperti
           Directory.Build.props): EmPorium-House.<versi>.zip langsung di folder itu dan hasil publish sementara di
           temp\<versi>, yang dikosongkan dulu bila sudah ada. Hanya ada satu zip rilis dan satu folder temp:
           EmPorium-House.*.zip dan temp\<versi lain> dari build sebelumnya dihapus setelah zip baru berhasil dibuat.
           Upload hanya setelah jawaban y/yes dan tidak pernah menimpa: tag/release yang sudah ada ditolak
           (naikkan N atau PATCH). Channel release dibuat sebagai Release biasa (latest); channel lain ditandai
           prerelease.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)-(prealpha|alpha|beta|release)\.[1-9][0-9]*$')]
    [string]$Version,

    [string]$Repo = 'MatrixCode-ID/EmPorium-House',

    [switch]$FrameworkDependent,

    [ValidatePattern('^win-(x64|x86|arm64)$')]
    [string]$Runtime = 'win-x64',

    [switch]$DryRun,

    [switch]$NoExplorer
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$appProject = Join-Path $repoRoot 'src' 'frontend' 'EmPoriumHouse.Ui.Wpf' 'EmPoriumHouse.Ui.Wpf.csproj'
# Artefak lokal tidak masuk repo: ..\.artefacts\EmPorium (atau ArtefactsPath), subfolder release\.
$artefactsRoot = if ($env:ArtefactsPath) { $env:ArtefactsPath } else { Join-Path $repoRoot '..' '.artefacts' 'EmPorium' }
$outDir = [IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetFullPath($artefactsRoot, $repoRoot)) 'release'))
$tempRoot = Join-Path $outDir 'temp'
$exeName = 'EmPoriumHouse.exe'

# Logika channel dan versi dipakai bersama dengan skrip container.
$sharedDir = Join-Path $repoRoot 'scripts' 'upload-api-ghcr'
foreach ($shared in 'versioning.ps1', 'channel.ps1') {
    $sharedPath = Join-Path $sharedDir $shared
    if (-not (Test-Path -LiteralPath $sharedPath -PathType Leaf)) { throw "Berkas bersama tidak ditemukan: $sharedPath" }
    . $sharedPath
}

if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') { throw 'Klien WPF hanya bisa dibangun di Windows.' }
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue)) { throw 'dotnet tidak ditemukan di PATH. Pasang .NET SDK 10.' }
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'gh (GitHub CLI) tidak ditemukan di PATH. Pasang dari https://cli.github.com lalu jalankan: gh auth login' }
if (-not (Test-Path -LiteralPath $appProject -PathType Leaf)) { throw "Berkas tidak ditemukan: $appProject" }
& gh auth status *> $null
if ($LASTEXITCODE -ne 0) { throw 'gh belum login. Jalankan: gh auth login' }

# Riwayat versi di GitHub: nama tag dari Release (termasuk draft) dan dari tag git v*, tanpa awalan "v".
# Gagal membaca riwayat menghentikan skrip: nomor build tidak boleh ditebak.
function Get-RemoteVersionTags {
    $releaseTags = @(& gh release list --repo $Repo --limit 1000 --json tagName --jq '.[].tagName')
    if ($LASTEXITCODE -ne 0) { throw "Tidak bisa membaca Release di $Repo. Periksa jaringan, nama repo, dan akses gh." }
    $gitRefs = @(& gh api "repos/$Repo/git/matching-refs/tags/v" --paginate --jq '.[].ref')
    if ($LASTEXITCODE -ne 0) { throw "Tidak bisa membaca tag di $Repo. Periksa jaringan, nama repo, dan akses gh." }
    $gitTags = $gitRefs | ForEach-Object { $_ -replace '^refs/tags/', '' }
    @($releaseTags + $gitTags) | Where-Object { $_ } | ForEach-Object { ($_.Trim()) -replace '^v', '' } | Select-Object -Unique
}

Write-Host "Membaca riwayat versi di GitHub ($Repo) ..."
$remoteTags = @(Get-RemoteVersionTags)

if ($Version) {
    if ($remoteTags -contains $Version) { throw "Versi $Version sudah ada di $Repo (Release atau tag). Pilih versi lain." }
} else {
    $channel = Select-PublishChannel
    $versions = @(Get-VersionTags $remoteTags | Sort-Object Version, Build -Descending)
    $previous = $versions | Where-Object Channel -eq $channel | Select-Object -First 1
    $defaultVersion = '0.1.0'
    if ($previous) {
        $defaultVersion = $previous.Version.ToString()
        Write-Host "Versi $channel sebelumnya: $($previous.Tag)"
    } elseif ($versions.Count) {
        $defaultVersion = $versions[0].Version.ToString()
        Write-Host "Belum ada build $channel; versi target terbaru: $defaultVersion"
    } else {
        Write-Host 'Belum ada versi di GitHub. Versi target pertama: 0.1.0'
    }
    while ($true) {
        $target = (Read-Host "Versi target baru [$defaultVersion]").Trim()
        if (-not $target) { $target = $defaultVersion }
        try { $Version = Get-NextVersionTag $remoteTags $channel $target; break } catch { Write-Host $_.Exception.Message -ForegroundColor Yellow }
    }
}
$channel = [regex]::Match($Version, '-(prealpha|alpha|beta|release)\.').Groups[1].Value
$tag = "v$Version"
Write-Host "Versi build: $Version (tag $tag)"

$publishDir = Join-Path $tempRoot $Version
$archiveName = "EmPorium-House.$Version.zip"

# Validasi path sebelum menghapus: publishDir harus ada di bawah <artefak>\release\temp.
$allowedRoot = [IO.Path]::GetFullPath($tempRoot) + [IO.Path]::DirectorySeparatorChar
$fullPublish = [IO.Path]::GetFullPath($publishDir)
if (-not $fullPublish.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path publish di luar $allowedRoot : $fullPublish"
}
if (Test-Path -LiteralPath $fullPublish) { Remove-Item -LiteralPath $fullPublish -Recurse -Force }
New-Item -ItemType Directory -Force -Path $fullPublish | Out-Null

$mode = if ($FrameworkDependent) { 'framework-dependent' } else { 'self-contained' }
Write-Host "Publish $exeName $Version ($Runtime, single file, $mode) ..."
$publishArgs = @(
    'publish', $appProject,
    '--configuration', 'Release',
    '--runtime', $Runtime,
    '--output', $fullPublish,
    "-p:Version=$Version",
    '-p:PublishSingleFile=true',
    '-p:DebugType=None', '-p:DebugSymbols=false'
)
if ($FrameworkDependent) {
    $publishArgs += '--self-contained', 'false'
} else {
    # WPF memuat native library (PresentationNative, wpfgfx, dll); tanpa ini ia tertinggal sebagai berkas terpisah.
    $publishArgs += '--self-contained', 'true', '-p:IncludeNativeLibrariesForSelfExtract=true', '-p:EnableCompressionInSingleFile=true'
}
& dotnet @publishArgs
if ($LASTEXITCODE -ne 0) { throw "dotnet publish gagal (exit code $LASTEXITCODE)." }

$exePath = Join-Path $fullPublish $exeName
if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw "Hasil publish tidak berisi $exeName." }
$extra = @(Get-ChildItem -LiteralPath $fullPublish -File | Where-Object Name -ne $exeName)
if ($extra.Count -gt 0) {
    Write-Warning ("Publish menghasilkan berkas selain exe (tidak ikut zip): " + (($extra | ForEach-Object Name) -join ', '))
}
Write-Host ("  -> {0} ({1:N1} MB)" -f $exeName, ((Get-Item -LiteralPath $exePath).Length / 1MB))

Write-Host 'Buat arsip zip (kompresi tertinggi) ...'
$zipPath = Join-Path $outDir $archiveName
if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }
# Compress-Archive hanya punya Optimal; SmallestSize (kompresi tertinggi) dipanggil langsung lewat .NET.
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$zipFile = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zipFile, $exePath, $exeName, [IO.Compression.CompressionLevel]::SmallestSize) | Out-Null
} finally {
    $zipFile.Dispose()
}
$zip = Get-Item -LiteralPath $zipPath
Write-Host ("  -> {0} ({1:N1} MB)" -f $zip.FullName, ($zip.Length / 1MB))

# Hanya satu zip rilis di folder release: zip versi sebelumnya dihapus setelah zip baru berhasil dibuat (bila build gagal,
# zip lama tetap ada). Yang dihapus hanya EmPorium-House.*.zip tepat di folder itu, bukan berkas lain atau subfolder.
$fullDist = [IO.Path]::GetFullPath($outDir)
foreach ($old in @(Get-ChildItem -LiteralPath $fullDist -Filter 'EmPorium-House.*.zip' -File | Where-Object FullName -ne $zip.FullName)) {
    if ([IO.Path]::GetFullPath($old.DirectoryName) -ne $fullDist) { throw "Path zip lama di luar ${fullDist}: $($old.FullName)" }
    Remove-Item -LiteralPath $old.FullName -Force
    Write-Host "  zip lama dihapus: $($old.Name)"
}

# Folder publish sementara versi lain ikut dibersihkan (setelah zip baru jadi): hanya subfolder langsung di
# release\temp\ selain folder versi ini, dan path-nya divalidasi berada di bawah folder itu.
foreach ($oldDir in @(Get-ChildItem -LiteralPath $tempRoot -Directory | Where-Object { [IO.Path]::GetFullPath($_.FullName) -ne $fullPublish })) {
    $oldFull = [IO.Path]::GetFullPath($oldDir.FullName)
    if (-not $oldFull.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) { throw "Path publish lama di luar ${allowedRoot}: $oldFull" }
    Remove-Item -LiteralPath $oldFull -Recurse -Force
    Write-Host "  folder publish lama dihapus: $($oldDir.Name)"
}

# Buka Explorer di folder hasil dengan zip terpilih. Dipanggil setelah pertanyaan upload dijawab: bila dijawab
# tidak, langsung; bila upload ke GitHub, setelah upload selesai.
function Open-ResultFolder {
    if (-not $NoExplorer) {
        Start-Process -FilePath 'explorer.exe' -ArgumentList "/select,`"$($zip.FullName)`""
    }
}

Write-Host ''
$reply = (Read-Host "Upload $($zip.Name) ke GitHub Release $tag di $Repo ? [y/N]").Trim().ToLowerInvariant()
if ($reply -notin @('y', 'yes', 'ya')) {
    Write-Host "Selesai secara lokal: $($zip.FullName). GitHub tidak diubah."
    Open-ResultFolder
    exit 0
}

# Cek ulang: versi bisa diambil orang lain selama build berjalan. Tidak ada penimpaan.
if (@(Get-RemoteVersionTags) -contains $Version) {
    throw "Versi $Version sudah ada di $Repo (dibuat saat build berjalan). Jalankan skrip lagi untuk build berikutnya; zip lokal tetap ada."
}

$commit = (& git -C $repoRoot rev-parse HEAD).Trim()
if (& git -C $repoRoot status --porcelain) {
    Write-Warning "Working tree punya perubahan yang belum di-commit: zip dibangun dari kondisi itu, bukan persis dari commit $($commit.Substring(0, 7))."
}
if (-not (& git -C $repoRoot branch -r --contains $commit)) {
    throw "Commit $($commit.Substring(0, 7)) belum ada di remote. Push dulu supaya tag $tag menunjuk commit yang benar."
}

# Menjalankan gh; pada -DryRun hanya mencetak perintahnya.
function Invoke-Gh([string[]]$Arguments) {
    if ($DryRun) {
        Write-Host "[DryRun] gh $($Arguments -join ' ')"
        $global:LASTEXITCODE = 0
        return
    }
    & gh @Arguments
}

$notesMode = if ($FrameworkDependent) { 'framework-dependent, needs the .NET 10 Desktop Runtime' } else { 'self-contained' }
$notes = "EmPorium House desktop client $Version for Windows ($Runtime), single file ($notesMode). Extract the zip and run $exeName."
$createArgs = @('release', 'create', $tag, $zip.FullName, '--repo', $Repo, '--target', $commit, '--title', "EmPorium House $Version", '--notes', $notes)
if ($channel -eq 'release') { $createArgs += '--latest' } else { $createArgs += '--prerelease' }
Invoke-Gh $createArgs
if ($LASTEXITCODE -ne 0) { throw "gh release create gagal (exit code $LASTEXITCODE)." }

Write-Host ''
Write-Host "Selesai. Zip ada di release $tag ($Repo). Versi $Version tidak boleh dipakai ulang; bila ada kesalahan, jalankan lagi untuk nomor build berikutnya."
Open-ResultFolder
