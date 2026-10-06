# CLAUDE.md

File ini memberi panduan bagi Claude Code (claude.ai/code) dan Codex saat bekerja di repo ini.

## Tentang EmPorium House

EmPorium House adalah platform infrastruktur untuk developer, dibuat oleh **Matrix Code** (organisasi GitHub `MatrixCode-ID`), dengan target pengguna developer. Produk ini berdiri sendiri dan dibangun di atas engine **em-system** (repo terpisah, namespace `Em.*`).

| Elemen | Nilai |
| --- | --- |
| Produk | EmPorium House (selalu ditulis lengkap dua kata; huruf P besar untuk menonjolkan "Em") |
| Repo GitHub | `MatrixCode-ID/EmPorium-House` |
| CLI dan domain | `emporium-house` (huruf kecil, pakai tanda hubung) |
| Assembly dan namespace | Awalan `EmPoriumHouse` (mis. `EmPoriumHouse.Api`) |
| Subtitle | Developer infrastructure platform |
| Slogan | Self-hosted. Fully stocked. |
| Deskripsi GitHub | Self-hosted developer infrastructure platform: CDN, container registry, and NuGet server. Built with MatrixCode Em-System. |
| Lisensi | MIT |

Keputusan nama (2026-10-02): nama awalnya "EmPorium", tetapi sudah dipakai [Emporium](https://emporium.build/) (platform self-hosted open source untuk developer, dengan CLI `emporium`), dan kata "emporium" sangat padat di GitHub. "Granary" polos juga bentrok dengan developer tool lain (granary.dev), jadi pengguna memilih **EmPorium House**. Pengganti yang dipertimbangkan dan ditinggalkan: EmGranary (kandidat terbersih, belum dicek mendalam), Emporium Palace, Wharf, Depot, Hangar. Karena kata "Emporium" masih dipakai produk lain, selalu tulis nama lengkap "EmPorium House" dan jangan menyingkatnya menjadi "EmPorium" di dokumen, UI, maupun nama paket. Belum dicek: ketersediaan `emporium-house` di NuGet, npm, dan domain, serta merek software terdaftar.

Keputusan cakupan (2026-10-02): EmPorium House dilebarkan menjadi platform infrastruktur developer, bukan hanya hosting artefak. Modul pertama adalah CDN dan container registry, lalu NuGet server; git server dan layanan seperti Seq (log server) mungkin menyusul. Karena cakupannya luas, **setiap modul harus bisa dinyalakan atau dimatikan sendiri** lewat satu baris pendaftaran di host (pola `builder.AddXxx()` seperti di em-system), supaya pengguna yang hanya butuh satu fitur tidak membawa yang lain. Deskripsi GitHub dan subtitle hanya menyebut fitur yang sudah ada; tambahkan fitur baru ke sana saat sudah jadi.

## Hubungan dengan em-system

- Engine dipakai sebagai paket NuGet `EmSys.*` dari nuget.org (keputusan pengguna 2026-10-06, sejak rilis `0.1.0-alpha.1`): `EmPoriumHouse.Api` memakai `EmSys.Api.Core`, `EmPoriumHouse.Ui.Wpf` memakai `EmSys.Libs` dan `EmSys.Ui.Wpf.Core`. Versinya satu properti MSBuild `EmSysVersion` di [Directory.Build.props](Directory.Build.props); tidak ada lagi `ProjectReference` atau checkout em-system yang dibutuhkan untuk build maupun image Docker.
- Jangan menulis versi engine langsung di csproj; selalu `Version="$(EmSysVersion)"`. Naik versi engine cukup mengubah `EmSysVersion`.
- Perubahan engine yang belum dirilis tidak terlihat di sini; tunggu paket versi berikutnya lalu naikkan `EmSysVersion`.
- Engine tetap `Em.*`. Jangan mengganti namespace atau nama paket engine menjadi `EmPoriumHouse.*`; awalan `EmPoriumHouse` hanya untuk host dan modul milik produk ini.
- Kode yang generik (autentikasi, penyimpanan, host, UI inti) milik engine dan diubah di repo em-system, bukan di sini.
- Saat ini CDN (`EnableCdn`) dan container registry (`AddContainerRegistry`) masih ada di engine (`Em.Api.Core`) dan hanya dinyalakan oleh host EmPorium House.
- **Library bersama wajib di em-system** (keputusan pengguna 2026-10-04): fitur/library besar yang dipakai bersama (CDN, container registry, NuGet server/NuPak, publish GUI, dan sejenisnya) dibangun di em-system dan diintegrasikan ke `Em.Api.Core`/`Em.Libs`/`Em.Ui.Wpf.Core` seperti manager lain. Repo ini hanya berisi host, **home screen, dan card pada home screen** (plus branding/konfigurasi host). Modul `src/modules/EmPoriumHouse.NuPak` dipindahkan ke em-system lewat plan `plan/unexecuted/publish-nuget-container-gui.codex.md` di repo em-system (fase pertama); jangan kembangkan modul itu lagi di sini.

## Database

- EmPorium House memakai database inti yang sama dengan em-system (EmDb), sehingga pengguna, kredensial, dan claim dipakai bersama dengan server em-system. Pengguna dan kredensial ada di database inti milik engine, dan modul menambah tabelnya sendiri ke database yang sama.
- Prasyarat: skrip skema inti dan `Ctn.sql` (registry) dari `doc/sqlscript/mssql/` milik em-system sudah dijalankan. Skrip tabel modul EmPorium House disimpan di repo ini dan memakai prefix tabel modul sendiri supaya tidak bentrok dengan engine atau modul lain.
- Versi library engine yang dipakai harus cocok dengan skema inti di database. Perbarui skema inti bersamaan dengan versi engine.
- Belum diperiksa: single sign-on antar-server (token dari satu server diterima server lain) bergantung pada kunci penandatanganan token; periksa `Em.Api.Core` sebelum menjanjikannya. "Akun yang sama tapi login terpisah" sudah cukup dengan database bersama.

## Struktur dan penamaan

| Lokasi | Isi |
| --- | --- |
| `src/backend/EmPoriumHouse.Api` | Host server HTTP (assembly `EmPoriumHouse.Api`) |
| `src/frontend/EmPoriumHouse.Ui.Wpf` | Host aplikasi desktop WPF (assembly dan exe `EmPoriumHouse`, namespace `EmPorium`) |
| `src/modules/` | Modul produk, satu folder per modul |
| `doc/`, `plan/`, `scripts/` | Dokumentasi, task (`plan/unexecuted`, `plan/executed`), dan skrip |

- Penamaan mengikuti em-system: host `EmPoriumHouse.Api` dan `EmPoriumHouse.Ui.Wpf`; modul memakai pola `Em.Test`, yaitu `src/modules/EmPoriumHouse.<Modul>/EmPoriumHouse.<Modul>.{Models,Api,Models.Ui,Wpf}`. Host WPF memakai `<AssemblyName>EmPoriumHouse</AssemblyName>`, jadi exe-nya `EmPoriumHouse.exe` (folder dan project tetap `EmPoriumHouse.Ui.Wpf`). Klien WPF single file dibagikan sebagai arsip `EmPorium-House.<versi>.zip` (isi `EmPoriumHouse.exe`) yang diunggah ke GitHub Release `v<versi>`, dibuat lewat `scripts\publish-wpf.cmd`; semua keluarannya, termasuk data sementara, ada di artefak lokal `..\.artefacts\EmPoriumelease\` (bukan di repo). Versi ditanyakan seperti skrip container. Bukan paket NuGet: GitHub Packages tidak menyimpan exe/zip.
- Setiap host punya solution sendiri: `src/backend/EmPoriumHouse.Api.slnx` dan `src/frontend/EmPoriumHouse.Ui.Wpf.slnx`. Tidak ada solution di root. Engine datang dari paket `EmSys.*`, tidak terdaftar di solution.
- Host MAUI belum ada dan belum direncanakan.

## Build dan menjalankan

```powershell
dotnet build src/backend/EmPoriumHouse.Api.slnx
dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx
```

Persyaratan: .NET SDK 10, Windows untuk host WPF, dan akses ke nuget.org untuk paket `EmSys.*`.

`EmPoriumHouse.Api` membaca `emapi-config.json` (class engine `EmApiConfig`, format sama dengan em-system) dari `$(ArtefactsPath)config\` (bawaan `..\.artefacts\EmPorium\config\`, di luar repo) lewat `Helper.ApplyConfig(builder)`; berkas disalin ke output build dan tidak ikut publish. `EM_API_CONFIG` dapat menunjuk path lain, dan `EM_DB_CONNECTION_STRING`, `EM_DB_PROVIDER`, `EM_ADMIN_INITIAL_PASSWORD`, `EM_DEBUG_TOKEN` mengesampingkan isi berkas. Contoh: [emapi-config.example.json](src/backend/EmPoriumHouse.Api/emapi-config.example.json). Container (Compose) memakai berkas terpisah `emapi-config.docker.json` di folder artefak yang sama (database host ditulis `host.docker.internal,1433`), dipasang sebagai Compose secret (bind mount read-only) ke `/run/secrets/emapi-config` dengan `EM_API_CONFIG`; path di host lewat `EM_API_CONFIG_FILE` di `.env`. `.env` hanya berisi pengaturan Compose, bukan `EM_DB_*`. Port lokal: `http://localhost:5232` dan `https://localhost:7260`, berbeda dari `Em.Api` (5132/7160) supaya keduanya bisa jalan bersamaan.

```powershell
dotnet run --project src/backend/EmPoriumHouse.Api/EmPoriumHouse.Api.csproj
```

## Status repo

Pembaruan 2026-10-02: kerangka awal saja. Belum ada modul sendiri, logo, launcher/updater, skrip tabel, atau CI. Logo memakai bawaan engine sampai ada artwork EmPorium House.

Pembaruan 2026-10-06 (icon): `EmPoriumHouse.Ui.Wpf` memakai `ApplicationIcon` `Assets\Logo.ico`, salinan logo engine dari em-system (`doc/assets/logo/Logo.ico`), sampai ada artwork EmPorium House sendiri. Logo di dalam aplikasi tetap bawaan engine (belum ada `LogoSource`). Mengganti artwork: timpa `Assets\Logo.ico` dan atur `BrandingInfo.LogoSource`.

Pembaruan 2026-10-02 (host bisa dijalankan):
- `EmPoriumHouse.Api` menyalakan CDN (`EnableCdn`, `./data/cdn`, maks 200 MB) dan container registry (`AddContainerRegistry`, `./data/container-registry`). Terbukti jalan: `/v2/` menjawab 401 dengan header registry, `/cdn/` menjawab 200. Konfigurasi ada di `emapi-config.json` di folder artefak (lihat bagian Build dan menjalankan serta Artefak lokal); contohnya `src/backend/EmPoriumHouse.Api/emapi-config.example.json`.
- `EmPoriumHouse.Ui.Wpf` memakai layout SPA (`UseSinglePageLayout`) dengan home sendiri, dipasang lewat `builder.UseEmPoriumHome()` (di `Home/EmPoriumHome.cs`, memanggil `UseHomeNavigation` engine). Home sengaja berada **langsung di project host** (folder `Home/`), bukan library atau module terpisah (keputusan pengguna 2026-10-02). Isinya: hero produk, kartu Container Registry dan CDN dengan angka langsung dari server dan alamat pakai (bisa disalin), kartu NuGet "Coming soon", pintasan administrasi, dan menu module lain yang terpasang. Kartu gagal sendiri-sendiri: 404 berarti modul tidak dinyalakan server, 401/403 berarti tanpa hak akses.
- Teruji: build kedua solution, startup API, startup host WPF, dan render home (terang, gelap, lebar 900, kondisi 404 dan 403) lewat harness konsol sementara dengan service palsu (tidak dikomit; caranya ada di memori proyek em-system, "Uji layar WPF tanpa server").
- Belum teruji: login lalu home terhadap server sungguhan (butuh password admin), klik tombol Open dan angka kartu dari data nyata, klik salin alamat, dan docker push/pull sungguhan.
- Catatan: realm registry masih "Em Container Registry" karena berasal dari engine; ganti di engine bila ingin bermerek EmPorium House.

## Konvensi

- Standar switch pada card default Home EmPorium House (keputusan pengguna 2026-10-03): setiap kontrol on/off pada card memakai toggle button kecil di pojok kanan atas header, di sebelah kanan tombol refresh. Gunakan pola `serverToggleStyle` pada `Home/EmPoriumHomeControl.xaml` sebagai acuan untuk card baru maupun perubahan card yang ada. Status toggle mengikuti nilai yang telah diterima server; pembatalan konfirmasi atau kegagalan request mempertahankan status sebelumnya. Pertahankan pemeriksaan hak akses, cegah request ganda, dan nonaktifkan toggle selama card loading/busy. Warna on/off, disabled, hover, dan fokus keyboard mengikuti tema terang/gelap; sediakan tooltip dan nama aksesibilitas. Tombol pembuka manager tetap berada di bagian bawah card. Referensi implementasi: `plan/executed/nuget-home-toggle.codex.md`.

- Aturan card dinamis (keputusan pengguna 2026-10-03): setiap card yang menampilkan informasi dinamis wajib memiliki tombol refresh kecil di pojok kanan atas. Refresh memperbarui seluruh informasi card tersebut secara independen, bisa mencoba ulang setelah gagal, dan mencegah request ganda selama loading. Kondisi enabled/disabled/loading mempertahankan warna tema terang/gelap. Card statis seperti Coming soon tidak memerlukan refresh.

- `AGENTS.md` menginstruksikan Codex membaca file ini sebelum bekerja, jadi file ini dipakai bersama oleh Claude Code dan Codex. Saat memperbarui file ini, pertahankan isi yang sudah ada; jangan menimpa atau menghapus kecuali diminta jelas oleh pengguna.
- Bahasa percakapan: Bahasa Indonesia. Nama kode, command, dan error message tetap dalam bahasa aslinya. Dokumen yang ditujukan untuk developer di luar tim (README, deskripsi repo) memakai Bahasa Inggris.
- Alur ide → plan → eksekusi (keputusan pengguna 2026-10-04, berlaku untuk Claude Code dan Codex): **semua saran dan ide** dari agent (perbaikan, refactor, fitur, temuan yang belum diminta, usulan lanjutan di akhir laporan) ditulis di `doc/ideas/<topik>.md` di repo yang bersangkutan, bukan langsung dikerjakan atau ditulis sebagai plan. Tahapannya: (1) **ide** di `doc/ideas/` didiskusikan sampai matang (keputusan jelas, tidak ada pertanyaan terbuka yang memblokir); (2) baru dibuat **plan** di `plan/unexecuted/` dan status ide diubah menjadi `jadi plan` dengan tautan ke plan; (3) plan dieksekusi hanya setelah plan matang dan pengguna memintanya, lalu dipindah ke `plan/executed/`. Pengecualian: bila pengguna **langsung meminta perubahan kode**, kerjakan langsung tanpa melewati ide/plan; saran tambahan yang muncul selama pekerjaan itu tetap dicatat di `doc/ideas/`. Ide yang menyangkut repo lain (mis. engine em-system vs produk EmPorium) ditulis di repo pemiliknya.
- Format catatan ide: tanggal, status (`diskusi`, `dipertimbangkan`, `jadi plan`, atau `ditolak`), latar belakang, keputusan yang sudah jelas, pertanyaan yang masih terbuka, dan tautan ke plan turunannya setelah dipromosikan. Isinya bukan perintah kerja, jadi agent tidak mengeksekusinya. Catatan lama tidak dihapus agar alasan keputusannya tetap ada.
- Semua task baru ditulis sebagai berkas Markdown di `plan/unexecuted/`, bukan di root repo; setelah selesai, pindahkan ke `plan/executed/`. Jika task akan dikerjakan Codex, sisipkan `.codex` sebelum `.md` (mis. `plan/unexecuted/layar-cdn.codex.md`). Instruksi yang berlaku terus-menerus disimpan di file ini; rincian satu task disimpan di `plan/`.
- Saat diminta menyiapkan plan, tanyakan semua keputusan yang dibutuhkan sebelum plan ditulis, lalu catat jawabannya sebagai keputusan final supaya eksekusinya tidak berhenti untuk bertanya.
- Plan atau permintaan yang punya beberapa tahap: **tulis seluruh kode semua tahap sampai selesai lebih dulu**; penggabungan, pengujian (build penuh, uji HTTP, uji layar), dan analisa/review dikerjakan sekali di akhir. Bila token menipis, hentikan tes/analisa lebih dulu (bukan penulisan kode) dan catat di laporan apa yang belum sempat diuji.
- Tindakan yang ditolak dengan `blocked by policy`: catat tindakan dan alasannya, jangan mengulang lewat shell, wrapper, atau cara lain. Siapkan tindakan yang masih diperlukan sebagai skrip `.ps1` di `plan/<nama-plan>-manual/` untuk dijalankan **manual oleh pengguna** (tiap skrip menyatakan tujuan, prasyarat, parameter, dan dampaknya), lanjutkan pekerjaan yang tidak bergantung padanya, dan beri tahu pengguna apa yang harus dijalankan saat eksekusi ditutup. Jangan menyatakan verifikasi manual yang tertunda sudah lulus.

## Menjalankan Codex dari Claude Code

Jika pengguna meminta Claude menjalankan Codex, tulis tugasnya di `plan/unexecuted/<nama>.codex.md` terlebih dahulu, gunakan mode **Manual** (Ask permissions) di Claude Code, lalu panggil Codex CLI dari folder proyek tanpa opsi yang menonaktifkan pemeriksaan izin:

```powershell
codex exec --skip-git-repo-check -C "<path repo EmPorium>" "Baca plan/unexecuted/<nama>.codex.md lalu kerjakan tugas di dalamnya."
```

Jika Auto mode menolak pemanggilan Codex, jangan mengulanginya lewat cara lain; minta pengguna memakai Manual atau menjalankan perintah itu sendiri. Periksa kode keluar dan hasilnya sebelum menyatakan tugas selesai.

Pembaruan 2026-10-03 (Home mengikuti layanan robot engine): kartu Container Registry di `Home/EmPoriumHomeControl.xaml.cs` menampilkan Roots dan Containers; statistik Robots dihapus karena identitas robot kini dikelola engine melalui User Manager/IRobotServices. Kartu registry tidak membutuhkan claim User Manager Access. Build solution WPF lulus tanpa warning/error; plan: `plan/executed/fix-home-robot-service.codex.md`. Interaksi Home dengan server belum diuji pada perbaikan ini.

Pembaruan 2026-10-03 (NuPak): modul produk NuGet ada di `src/modules/EmPoriumHouse.NuPak` (Models, Api, Models.Ui, Wpf). Pemasangan API `builder.AddNuPakModule("./data/nuget")`, WPF `builder.AddNuPakModule()`. Prasyarat skema: `doc/sqlscript/mssql/sets/NuPak.sql`. Toggle runtime di metadata inti, default off; robot mendapat hak R/W per prefix melalui User Manager. Panduan: `doc/nuget-server.md`; hasil verifikasi dicatat di plan NuGet server.

Hasil verifikasi NuPak 2026-10-03: build backend/WPF produk dan engine tanpa warning/error; 79 pemeriksaan SQL/HTTP/klien NuGet terisolasi lulus, termasuk push paket engine, restore privat, search, delete, race, kegagalan SQL, dan penghapusan robot. Skema lokal NuPak sudah terpasang; default feed off. Harness `scripts/module-card-qa` merender semua tab, kondisi busy/off/error/tanpa hak pada tema terang/gelap. Host WPF debug kini menuju port produk 5232. Interaksi mouse, akun robot permanen, IDE dan reverse proxy HTTPS tetap verifikasi manual. Plan dan laporan: `plan/executed/nuget-server.codex.md`.

Pembaruan 2026-10-03 (NuPak multi-feed): batas single-feed pada catatan lama digantikan oleh feed eksplisit tanpa feed bawaan. URL wajib /nuget/{slug}/v3/index.json; NuPakEnable tetap toggle server, enabled/anonymous tersimpan per feed. Startup wajib marker NuPakSchemaVersion=2. Instalasi legacy kosong wajib update sebelum set terbaru; populated legacy ditolak tanpa backfill/reset. Runbook: doc/nuget-multifeed-upgrade.md; plan: plan/unexecuted/nuget-multifeed.codex.md; hasil/verifikasi tertunda: doc/report/nuget-multifeed-eksekusi.md. Pembaruan panduan developer tertunda manual: plan/nuget-multifeed-manual/update-guide.ps1.

Hasil multi-feed 2026-10-03: plan dipindahkan ke plan/executed/nuget-multifeed.codex.md. Build backend/WPF 0 warning/error; 162 pemeriksaan SQL/HTTP/klien NuGet terisolasi serta render terang/gelap lulus. Database lokal sudah marker 2 dan nol feed sesudah backup penuh terverifikasi + update; NuPakEnable=True lama dipertahankan. Host API nyata startup dan URL lama/unknown 404 lulus. Detail backup, batas verifikasi dan skrip manual panduan: doc/report/nuget-multifeed-eksekusi.md. Interaksi mouse/clipboard, HTTPS reverse proxy dan IDE belum diuji.

Pembaruan 2026-10-03 (Compose Rider): solution backend memuat `compose.dcproj`, `compose.yml`, Dockerfile Alpine 3.23/.NET 10 dan shared Run `EmPoriumHouse.Api Compose`. Engine dibawa melalui named build context sibling, override `EM_SYSTEM_BUILD_CONTEXT` dalam `src/backend/.env`; konfigurasi MSBuild host tetap `EmSystemPath`. Container non-root UID 1654, port default 5232, volume persisten `/app/data`, `.env` lokal diabaikan Git. Panduan: `src/backend/README.md`; laporan: `plan/executed/rider-compose.codex.md`. Build solution/image Release, startup database/NuPak dan HTTP CDN 200/registry 401/unknown feed 404 lulus. Container uji dihentikan; UI Run/F5 Rider dan attach debugger belum diuji.

Pembaruan 2026-10-03 (log Rider): profil shared Compose diperbaiki ke factory/deployment docker-compose.yml sesuai Rider terpasang, forceBuild=true, upDetach=false dan aktivasi tool window. Run foreground menampilkan log startup API dan HTTP CDN 200. Debug Rider lokal memilih linux-x64/JetBrains.Debugger.Worker yang gagal sebelum API startup di Alpine (exit 127); gunakan Run untuk log melalui Services > container > Log. UI Rider/kompatibilitas debugger masih perlu verifikasi. Laporan: plan/executed/rider-compose-logs.codex.md.

Pembaruan 2026-10-03 (nama image container): image Compose memakai `emporium-server:local`, menggantikan `emporium-house-api:local` sesuai permintaan pengguna. Service, hostname, project Compose dan volume tetap memakai nama sebelumnya. Image lokal ditag ulang tanpa rebuild; detail: `plan/executed/rename-container-image.codex.md`.

Pembaruan 2026-10-03 (nama Docker Desktop): project Compose, service dan container kini `emporium-server`; konfigurasi IDE dan perintah logs ikut diperbarui. Hostname tetap `emporium-house-api` untuk identitas settings. Volume memakai nama eksplisit `emporium-house-api_emporium-house-api-data` agar data lama tetap digunakan saat project berganti. Container lama diganti memakai image yang sama tanpa rebuild. Laporan: `plan/executed/rename-compose-container.codex.md`.

Pembaruan 2026-10-03 (project log Rider): workspace lokal masih memilih Compose Deployment dengan override project name lama emporium-house-api setelah rename. Override diperbaiki ke emporium-server dan profil shared dipilih; shared Run kini mencantumkan composeProjectName eksplisit. Log startup API terbaca lewat Compose project baru; UI belum diverifikasi. Backup workspace tersimpan dalam .idea (ignored); container tetap berjalan. Laporan: plan/executed/rider-log-project.codex.md.

Pembaruan 2026-10-03 (timezone container): Dockerfile menerima build argument `TZ` (default build langsung `UTC`) dan menyimpannya sebagai environment image; Compose memakai `TZ` dari `.env` dengan default `Asia/Jakarta` untuk build/runtime. `tzdata` tetap di image. Panduan setup, recreate, diagnosis dan bantuan Compose: `src/backend/README.md`. Build Release serta pemeriksaan WIB/UTC/WITA/WIT sebagai UID 1654 lulus. Service aktif belum dibuat ulang pada pekerjaan ini; perubahan environment memerlukan `docker compose up -d --force-recreate emporium-server`, bukan hanya restart. Laporan: `plan/executed/container-timezone.codex.md`.

## Artefak lokal

- Repo ini publik. Kebutuhan lokal (key debug, konfigurasi produksi, backup) disimpan di `$(ArtefactsPath)`, bawaan `..\.artefacts\EmPorium\`, per subfolder. Key debug WPF: `debugkey\debug-token.key` (private, disisipkan hanya pada build Debug bila file ada) dan `debugkey\debug-token.pub` (public, untuk `EM_DEBUG_TOKEN` server). Jangan commit path absolut mesin, username, IP internal, atau kredensial.

Pembaruan 2026-10-04 (migrasi NuPak): NuPak kini di engine Em.Api.Core/Em.Libs/Em.Ui.Wpf.Core. API memakai AddNuPak() bersama AddManagedStorageSettings() atau AddNuPak(path, maxPackageMb). Navigasi admin.nupak otomatis dari core. Catatan modul produk lama bersifat historis. Panduan dan SQL berada di em-system: doc/engine/engine-nupak.md dan doc/sqlscript/mssql/tables/040-nupak.sql.
