# Docker Compose EmPorium House API di Rider

Tanggal: 2026-10-03. Status: selesai; UI Rider dan attach debugger belum diuji.

Permintaan: saat membuka solution API di Rider, Docker Compose sudah tersedia.

- Tambahkan Dockerfile Alpine .NET 10 mengikuti host engine.
- Sertakan engine melalui named build context; pertahankan ProjectReference EmSystemPath.
- Tambahkan Compose, dcproj, profil dan shared run configuration Rider.
- Pakai port 5232, konfigurasi .env diabaikan Git, volume data persisten.
- Dokumentasikan penggunaan lalu verifikasi build solution, image dan startup HTTP.
- Catat batas verifikasi UI Rider/debugger.

## Hasil

- Dockerfile Alpine 3.23 / ASP.NET Core 10, non-root UID 1654.
- Named context engine `em-system`, default repo sibling; override `EM_SYSTEM_BUILD_CONTEXT`.
- Compose, dcproj (Regular mode), profil launch dan shared `.run` tersedia dalam solution.
- Port default 5232, hostname stabil, named volume `/app/data`, konfigurasi `.env`.
- `.env` lokal dibuat dari konfigurasi container engine yang sudah tersedia, nilai tidak ditampilkan atau dikomit.
- README backend dan tautan README root ditambahkan; perubahan multi-feed sebelumnya dipertahankan.

## Verifikasi

- `dotnet build EmPoriumHouse.Api.slnx --configuration Release`: 0 warning/error.
- `docker compose config --quiet`: lulus.
- `docker compose build`: image Release lulus; semua library juga dipublish Release di Linux.
- `docker compose up -d`: startup database dan NuPak schema marker 2 lulus.
- HTTP `/cdn/` 200; `/v2/` 401 (registry membutuhkan autentikasi); `/nuget/unknown/v3/index.json` 404.
- UID 1654, `/app/data` writable; local/production JSON tidak ada dalam image; runtime ASP.NET Core 10.0.10.
- XML shared Run/dcproj valid; `.env` diabaikan Git; `git diff --check` lulus.
- Container uji dihentikan lewat `docker compose down`, volume dipertahankan agar port bebas untuk Run Rider.

## Batas

Run/F5 lewat UI Rider dan attach debugger belum diuji. Buka
`src/backend/EmPoriumHouse.Api.slnx`, pilih `EmPoriumHouse.Api Compose`, lalu Run
dengan Docker Desktop Linux aktif. Jika koneksi Docker belum terdeteksi, konfigurasi
di Settings | Build, Execution, Deployment | Docker. Untuk simbol debug set
`BUILD_CONFIGURATION=Debug`; ini bukan bukti attach debugger berhasil.
