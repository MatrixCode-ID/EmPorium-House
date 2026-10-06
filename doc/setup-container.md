# Setup container EmPorium House API

Panduan ini menjalankan host `EmPoriumHouse.Api` dari repo ini memakai Docker Compose atau `docker run`. Image dibangun dari [Dockerfile](../src/backend/EmPoriumHouse.Api/Dockerfile). Image berbasis Alpine 3.23: SDK .NET 10 hanya dipakai di stage build, sedangkan image akhir hanya berisi ASP.NET runtime. Build image tidak memerlukan SDK .NET di mesin lokal, dan engine diambil dari paket `EmSys.*` di nuget.org (versi `EmSysVersion` di `Directory.Build.props`), jadi checkout em-system tidak diperlukan.

Kecuali disebutkan lain, semua perintah dijalankan lewat PowerShell dari **root repo**.

## Prasyarat

- Docker dalam mode Linux containers dengan BuildKit. Compose memakai plugin v2.24 atau lebih baru (`docker compose version`).
- Akses internet saat build untuk image Alpine, paket apk, dan paket NuGet.
- Database yang dapat dijangkau dari container. Compose hanya menjalankan API, tidak menyediakan server database.
- Skema sudah terpasang di database tersebut. Skrip SQL Server milik engine ada di repo em-system, folder [`doc/sqlscript/mssql`](https://github.com/MatrixCode-ID/em-system/tree/main/doc/sqlscript/mssql); daftar skrip, urutan, dan contoh `sqlcmd` ada di [README, bagian "Prepare the database"](../README.md#prepare-the-database). Singkatnya: `sets/000-ulid.sql`, `tables/010-core.sql`, `030-registry.sql`, `040-nupak.sql`, lalu view `vi_Address`, `vi_Comm`, `vi_Contact`, `vi_Role`, `vi_User`, `vi_UserCredential` dan lima `vi_NuPak*`. Untuk database NuPak yang sudah ada, ikuti runbook upgrade engine NuPak multifeed di em-system.

## Konfigurasi

Konfigurasi API ada di satu berkas `emapi-config.json` (class engine `EmApiConfig`). Formatnya ada di [emapi-config.example.json](../src/backend/EmPoriumHouse.Api/emapi-config.example.json). Berkas ini disimpan di luar repo, di folder artefak `..\.artefacts\EmPorium\config\`, karena memuat secret:

| Berkas | Dipakai oleh |
| --- | --- |
| `emapi-config.json` | `dotnet run` / IDE. Build menyalinnya ke output, dan berkas ini tidak ikut publish. |
| `emapi-config.docker.json` | Container. Di-mount read-only ke `/run/secrets/emapi-config`. |

```powershell
New-Item -ItemType Directory -Force ..\.artefacts\EmPorium\config
Copy-Item src/backend/EmPoriumHouse.Api/emapi-config.example.json ..\.artefacts\EmPorium\config\emapi-config.docker.json
notepad ..\.artefacts\EmPorium\config\emapi-config.docker.json
```

Isi `database.connectionString` dan `admin.initialPassword`. Berkas untuk container berbeda dari berkas lokal hanya pada bagian yang bergantung pada jaringan:

- Di dalam container, `localhost` adalah container itu sendiri. Untuk SQL Server di mesin host, pakai `Server=host.docker.internal,1433` dengan port TCP yang sebenarnya.
- Login harus memakai SQL authentication. Windows integrated authentication dan named instance tanpa port tidak bisa dipakai dari container Linux. Pastikan TCP SQL Server, firewall, dan izin login mengizinkan koneksi.
- `TrustServerCertificate=True` hanya untuk server yang sertifikatnya memang Anda percayai, misalnya database lokal.
- Path storage relatif (`./data/...`) mengarah ke volume `/app/data`.

Host membaca berkas dari path di `EM_API_CONFIG`. Environment variable `EM_DB_CONNECTION_STRING`, `EM_DB_PROVIDER`, `EM_ADMIN_INITIAL_PASSWORD`, dan `EM_DEBUG_TOKEN`, bila ada, mengesampingkan nilai berkas. Variabel ini berguna untuk secret manager, tetapi sebaiknya tidak ditulis di `.env`, supaya berkas config tetap menjadi satu-satunya sumber.

### File `.env` Compose

`.env` hanya berisi pengaturan Compose. Salin contohnya sekali, dan jangan menimpa file yang sudah terisi:

```powershell
Copy-Item src/backend/.env.example src/backend/.env
```

```dotenv
EM_API_CONFIG_FILE=../../../.artefacts/EmPorium/config/emapi-config.docker.json
EMPORIUM_API_PORT=5232
EMPORIUM_API_BIND_ADDRESS=127.0.0.1
ASPNETCORE_ENVIRONMENT=Development
BUILD_CONFIGURATION=Release
TZ=Asia/Jakarta
```

`.env` dan `emapi-config*.json` diabaikan Git dan build context, jadi tidak ikut masuk image. Opsi CLI `--env-file` menentukan sumber interpolasi, dan variabel shell mengesampingkan nilai interpolasi; lihat [dokumentasi interpolasi Compose](https://docs.docker.com/compose/how-tos/environment-variables/variable-interpolation/).

## Pilihan 1: Docker Compose

### Compose minimal (image jadi)

`compose.yml` mandiri yang menjalankan image yang sudah dibangun atau dipublikasikan: tanpa build context dan tanpa `.env`. Simpan di folder mana pun, sesuaikan path config, lalu jalankan `docker compose up -d`.

```yaml
name: emporium-server
services:
  emporium-server:
    image: ghcr.io/matrixcode-id/emporium-server:alpha
    container_name: emporium-server
    hostname: emporium-house-api
    init: true
    restart: unless-stopped
    environment:
      EM_API_CONFIG: /run/secrets/emapi-config
      ASPNETCORE_ENVIRONMENT: Production
      TZ: Asia/Jakarta
    ports:
      - "127.0.0.1:5232:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - emporium-house-api-data:/app/data
    secrets:
      - emapi-config
volumes:
  emporium-house-api-data:
secrets:
  emapi-config:
    file: ./emapi-config.docker.json
```

Tag `alpha` adalah tag channel yang bergerak; untuk deployment yang dapat diulang, pakai tag versi penuh (lihat [konvensi penamaan container](https://github.com/MatrixCode-ID/em-system/blob/main/doc/convention/container-naming.md)). Jika package GHCR privat, jalankan `docker login ghcr.io` lebih dulu.

### Compose dari source

File [`src/backend/compose.yml`](../src/backend/compose.yml) menambahkan build image, interpolasi `.env`, dan label IDE:

```yaml
name: emporium-server
services:
  emporium-server:
    image: emporium-server:local
    container_name: emporium-server
    hostname: emporium-house-api
    labels:
      com.jetbrains.rider.fast.mode: "false"
      com.microsoft.visual-studio.project-name: EmPoriumHouse.Api
    build:
      context: ../..
      dockerfile: src/backend/EmPoriumHouse.Api/Dockerfile
      args:
        BUILD_CONFIGURATION: ${BUILD_CONFIGURATION:-Release}
        TZ: ${TZ:-Asia/Jakarta}
    env_file:
      - path: .env
        required: false
    environment:
      TZ: ${TZ:-Asia/Jakarta}
      EM_API_CONFIG: /run/secrets/emapi-config
      ASPNETCORE_ENVIRONMENT: ${ASPNETCORE_ENVIRONMENT:-Development}
      ASPNETCORE_URLS: http://+:8080
    ports:
      - "${EMPORIUM_API_BIND_ADDRESS:-127.0.0.1}:${EMPORIUM_API_PORT:-5232}:8080"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    volumes:
      - emporium-house-api-data:/app/data
    secrets:
      - emapi-config
    init: true
volumes:
  emporium-house-api-data:
    name: emporium-house-api_emporium-house-api-data
secrets:
  emapi-config:
    file: ${EM_API_CONFIG_FILE:-../../../.artefacts/EmPorium/config/emapi-config.docker.json}
```

- Build context adalah root repo (`../..`). Kedua label hanya dipakai oleh Rider/Visual Studio.
- Di luar Swarm, [secret Compose](https://docs.docker.com/compose/how-tos/use-secrets/) dengan `file:` adalah bind mount read-only. Berkasnya tidak muncul sebagai environment variable di `docker inspect`.
- Path relatif pada `file:` dihitung dari folder `compose.yml`. Bila berkas tidak ada, `up` gagal dengan pesan bahwa file secret tidak ditemukan.

### Build dan jalankan

Dari folder `src/backend`, Compose otomatis membaca `compose.yml` dan `.env`:

```powershell
Set-Location src/backend
docker compose config --quiet
docker compose up --build -d emporium-server
docker compose ps
docker compose logs --tail 100 -f emporium-server
Set-Location ../..
```

Dari root repo, sebutkan kedua file secara eksplisit:

```powershell
docker compose --env-file src/backend/.env -f src/backend/compose.yml up --build -d
docker compose --env-file src/backend/.env -f src/backend/compose.yml logs --tail 100 -f emporium-server
```

- `config --quiet` memvalidasi konfigurasi Compose tanpa mencetak secret. Perintah ini tidak memeriksa isi `emapi-config` maupun koneksi database.
- `--build` membangun image `emporium-server:local`, dan `-d` menjalankan service di background. Jika image sudah ada, gunakan `up --no-build -d emporium-server`.

API tersedia di `http://localhost:5232` (sesuaikan bila port diubah):

```powershell
Invoke-WebRequest http://localhost:5232/
```

Respons HTTP hanya membuktikan API berjalan. Fitur database dan storage tetap perlu diverifikasi lewat aplikasi.

### Ubah konfigurasi, restart, dan stop

Contoh berikut dijalankan dari `src/backend`.

| Perubahan | Perintah |
| --- | --- |
| Isi `emapi-config.docker.json` | `docker compose restart emporium-server`. Berkas dibaca ulang saat startup. |
| Isi `.env` atau path `EM_API_CONFIG_FILE` | `docker compose up -d --force-recreate`. `restart` tidak membaca ulang `.env`. |
| Kode atau `BUILD_CONFIGURATION` | `docker compose up --build -d` |
| Hentikan service | `docker compose down` |

`down` menghapus container dan network, tetapi volume data tetap ada. **`down --volumes` menghapus volume data**; jangan dipakai untuk restart atau update biasa.

Cara menjalankan Compose dari Visual Studio/Rider ada di [README backend](../src/backend/README.md#run-from-an-ide).

## Pilihan 2: docker build dan docker run

### Build image

Build context harus root repo:

```powershell
docker build --file src/backend/EmPoriumHouse.Api/Dockerfile --build-arg BUILD_CONFIGURATION=Release --build-arg TZ=Asia/Jakarta --tag emporium-server:local .
```

Compose menghasilkan tag yang sama (`emporium-server:local`), jadi image hasil build Compose juga bisa langsung dipakai. Tanpa `--build-arg TZ`, image memakai `UTC`; timezone bisa diganti saat runtime dengan `--env TZ=...`.

### Jalankan container

Pakai image hasil build di atas, atau image terpublikasi seperti `ghcr.io/matrixcode-id/emporium-server:alpha` (jalankan `docker login ghcr.io` bila package privat). Berkas config di-mount read-only dengan bind mount biasa, ke path yang sama seperti pada Compose:

```powershell
$config = (Resolve-Path ..\.artefacts\EmPorium\config\emapi-config.docker.json).Path
docker volume create emporium-house-api-data
docker run --detach --name emporium-server --hostname emporium-house-api --init `
  --env EM_API_CONFIG=/run/secrets/emapi-config `
  --env ASPNETCORE_ENVIRONMENT=Production `
  --env TZ=Asia/Jakarta `
  --mount "type=bind,source=$config,target=/run/secrets/emapi-config,readonly" `
  --mount type=volume,source=emporium-house-api-data,target=/app/data `
  --publish 127.0.0.1:5232:8080 `
  --add-host host.docker.internal:host-gateway `
  emporium-server:local

docker logs --tail 100 -f emporium-server
```

Backtick adalah penyambung baris di PowerShell; jangan beri spasi sesudahnya. Port internal image adalah `8080`. Untuk mengubah alamat atau port host, ubah bagian `127.0.0.1:5232` pada `--publish`. `EMPORIUM_API_PORT` dan `EMPORIUM_API_BIND_ADDRESS` hanya dibaca oleh Compose. Lihat [referensi docker run](https://docs.docker.com/reference/cli/docker/container/run/).

| Parameter | Fungsi |
| --- | --- |
| `--hostname emporium-house-api` | Pertahankan tetap sama; hostname dan content root menjadi bagian identitas pengaturan yang disimpan. |
| `--env EM_API_CONFIG` | Path berkas config di dalam container. Tanpa ini host mencari `emapi-config.json` di `/app`. |
| `--mount ...target=/run/secrets/emapi-config,readonly` | Berkas config dari host, read-only. Di Linux harus bisa dibaca UID `1654`. |
| `--mount ...target=/app/data` | Volume berisi file CDN, registry, dan NuGet. Tanpa ini data hilang saat container dihapus. |
| `--publish 127.0.0.1:5232:8080` | Alamat dan port host yang dipetakan ke port container `8080`. |
| `--add-host host.docker.internal:host-gateway` | Dibutuhkan di Linux untuk menjangkau database di host Docker (Docker Desktop sudah menyediakannya). |

### Restart, update, dan stop

`docker restart emporium-server` membaca ulang isi berkas config, tetapi tetap memakai environment dan mount lama. Untuk mengganti environment, mount, atau image, hapus container lalu jalankan ulang `docker run` dengan volume yang sama. Jika kode berubah, build image lebih dulu:

```powershell
docker stop emporium-server
docker rm emporium-server
```

Menghapus container tidak menghapus named volume.

### Berpindah antara Compose dan docker run

Kedua cara memakai volume yang berbeda: Compose dari source memakai `emporium-house-api_emporium-house-api-data`, sedangkan contoh `docker run` memakai `emporium-house-api-data`. Untuk memakai data Compose dari `docker run`, hentikan service Compose, lalu ganti `source=` dengan nama volume Compose (periksa dengan `docker volume ls`). Pertahankan database, hostname `emporium-house-api`, dan content root `/app` yang sama. Jangan jalankan dua instance dengan port atau storage yang sama.

## Daftar variabel

| Variabel | Dibaca oleh | Default | Fungsi |
| --- | --- | --- | --- |
| `EM_API_CONFIG_FILE` | Compose | `../../../.artefacts/EmPorium/config/emapi-config.docker.json` | Path berkas config di host, relatif terhadap `compose.yml` atau absolut. |
| `EM_API_CONFIG` | Host API | Compose: `/run/secrets/emapi-config` | Path berkas config di dalam container. Tanpa variabel ini, host mencari `emapi-config.json` di folder aplikasi. |
| `EM_DB_CONNECTION_STRING`, `EM_DB_PROVIDER`, `EM_ADMIN_INITIAL_PASSWORD`, `EM_DEBUG_TOKEN` | Host API | Tidak diisi | Opsional. Mengesampingkan nilai berkas yang sesuai, misalnya dari secret manager. |
| `EMPORIUM_API_PORT` | Compose | `5232` | Port host yang dipetakan ke port container `8080`. |
| `EMPORIUM_API_BIND_ADDRESS` | Compose | `127.0.0.1` | Alamat host untuk publish. `0.0.0.0` membuka port pada semua interface IPv4. |
| `ASPNETCORE_ENVIRONMENT` | ASP.NET Core | Compose: `Development`; tanpa override: `Production` | Gunakan `Production` untuk deployment. Dockerfile tidak menetapkan variabel ini. |
| `BUILD_CONFIGURATION` | Build argument | `Release` | Konfigurasi `dotnet publish` (`Release` atau `Debug`). Untuk `docker build`, pakai `--build-arg`. |
| `TZ` | Build argument dan runtime | Compose: `Asia/Jakarta`; Dockerfile: `UTC` | Timezone IANA untuk build dan runtime. Waktu yang disimpan atau dicatat eksplisit sebagai UTC tetap UTC. |
| `ALPINE_VERSION` | Build argument | `3.23` | Versi base image. Ganti lewat `docker build --build-arg ALPINE_VERSION=...` dan pastikan paket .NET 10 tersedia. Compose tidak meneruskan nilai ini. |
| `ASPNETCORE_URLS` | ASP.NET Core | `http://+:8080` | Alamat listen internal. Jika diubah lewat `docker run`, sesuaikan target port `--publish`. |

Timeout HTTP, rate limit, proxy, retensi session token, dan path serta batas storage (CDN, registry, NuGet) diatur di berkas config. Modul yang aktif ditentukan di [Program.cs](../src/backend/EmPoriumHouse.Api/Program.cs).

## Storage

Image berjalan sebagai user `em` (UID/GID `1654`) dengan content root `/app`. Volume `/app/data` berisi:

| Path container | Isi |
| --- | --- |
| `/app/data/tasks` | Cache task. |
| `/app/data/cdn` | Payload CDN (batas upload `cdnMaxFileSizeMb`, contoh 200 MB). |
| `/app/data/container-registry` | Blob/payload container registry. |
| `/app/data/nuget` | Paket NuGet (batas `nuPakMaxPackageMb`, contoh 250 MB). |

- Gunakan directory di bawah `/app/data`, atau mount tambahan yang dapat ditulis UID/GID `1654`. Untuk bind mount, siapkan izin di host sebelum container dijalankan.
- Backup database **dan** volume sebagai satu kesatuan, karena file registry dan paket harus cocok dengan metadata di database.
- File di luar volume, misalnya hasil edit `nano` di filesystem container, hilang saat container dibuat ulang.

## Deployment publik

Contoh di atas ditujukan untuk mesin lokal. Untuk server yang dapat diakses publik:

- Simpan berkas config di luar checkout, misalnya `/etc/emporium/emapi-config.json`, dan arahkan `EM_API_CONFIG_FILE` ke sana. Berkas harus bisa dibaca UID `1654` tetapi tidak oleh semua user, misalnya `chown root:1654` dan `chmod 640`.
- Set `ASPNETCORE_ENVIRONMENT=Production`.
- Kosongkan `debugTokens` kecuali memang diperlukan. Key yang terdaftar dapat menerbitkan token yang valid selama 60 hari.
- Image hanya melayani HTTP. Pasang TLS lewat reverse proxy, dan daftarkan alamat proxy di `http.proxy.trusted` supaya alamat client tercatat benar. Jika proxy berjalan di host yang sama, pertahankan bind `127.0.0.1`; jangan membuka port `8080`/`5232` langsung ke internet.
- Pakai password admin awal yang kuat dan login database khusus aplikasi (bukan `sa`), dengan sertifikat server yang tervalidasi.

## Diagnosis

```powershell
# Compose (dari src/backend)
docker compose exec emporium-server ls -l /run/secrets/emapi-config
docker compose exec emporium-server ping -c 3 host.docker.internal
docker compose exec emporium-server traceroute host.docker.internal

# docker run
docker exec emporium-server id
docker exec emporium-server ping -c 3 host.docker.internal
```

Ping dan traceroute hanya memeriksa jaringan, dan dapat diblokir oleh jaringan host. Keberhasilannya tidak membuktikan login SQL berhasil.

| Gejala | Yang perlu diperiksa |
| --- | --- |
| `up` gagal: file secret tidak ditemukan | `EM_API_CONFIG_FILE` dan keberadaan berkas; path relatif dihitung dari `compose.yml`. |
| Startup gagal: `database.connectionString` / `admin.initialPassword is required` | Isi berkas config, dan apakah `EM_API_CONFIG` menunjuk berkas yang benar. |
| Startup gagal: `... is not a valid emapi-config.json` | Sintaks JSON. Komentar `//` dan koma di akhir diperbolehkan. |
| Permission denied saat membaca config | Izin baca berkas untuk UID `1654` di server Linux. |
| SQL timeout / login failed | Alamat host, port TCP, firewall, kredensial, sertifikat, database tujuan. |
| Nilai config seolah diabaikan | Variabel `EM_DB_*`, `EM_ADMIN_INITIAL_PASSWORD`, atau `EM_DEBUG_TOKEN` yang tersisa di `.env` atau environment mengesampingkan berkas. |
| Tabel registry/NuPak tidak ditemukan | Skema registry dan NuPak versi 2 sudah dijalankan di database tujuan. |
| Permission denied pada storage | Mount yang benar dan izin tulis UID/GID `1654`. |
| Port already allocated | Hentikan instance sebelumnya atau ganti port host. |
