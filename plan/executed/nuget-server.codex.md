# NuGet Server (modul NuPak) untuk EmPorium House

Tanggal: 2026-10-03.
Status: implementasi selesai; verifikasi otomatis lulus, verifikasi interaksi/deployment nyata tercatat di bawah.
Pelaksana: Codex. Jalankan dari `<EmPorium>`; plan ini juga mengubah `<em-system>` (hook engine, Tahap 1).

## Tujuan

EmPorium House menjadi server NuGet (protokol V3) di jalur `/nuget`: robot dapat `dotnet restore`, `dotnet nuget push`, dan `dotnet nuget delete` (masuk recycle bin) terhadap feed `http(s)://<server>/nuget/v3/index.json`; Visual Studio/Rider/`dotnet package search` dapat mencari paket. Fitur dapat dinyalakan/dimatikan **saat runtime** dari NuGet Manager (WPF) dan dari tombol toggle di card NuGet pada Home EmPorium House. Modul berada di repo ini sebagai modul produk, sedangkan hal generik (titik ekstensi engine) ditambahkan di em-system.

## Aturan eksekusi

- Baca `CLAUDE.md` repo ini dan `claude.md` em-system sebelum mulai. Pertahankan perubahan yang sudah ada di working tree kedua repo (em-system punya pekerjaan storage settings yang belum di-commit: `EmApp.cs`, `EmAppBuilder.cs`, `Program.cs`, dst.). Jangan membatalkan atau memformat ulang hunk milik orang lain.
- Urutan kerja: **tulis seluruh kode Tahap 1–7 sampai selesai lebih dulu**. Build penuh, uji HTTP/klien NuGet, uji layar, dan review dilakukan sekali di Tahap 8. Jangan menyelipkan tes atau analisa antar tahap. Bila token menipis, hentikan tes/analisa lebih dulu (bukan penulisan kode) dan catat di laporan apa yang belum sempat diuji.
- Tindakan yang ditolak `blocked by policy` (mis. menjalankan skrip SQL, menjalankan server): catat, jangan diulang lewat cara lain; siapkan skrip `.ps1` di `plan/nuget-server-manual/` sesuai aturan `CLAUDE.md`, lanjutkan pekerjaan lain, dan beri tahu pengguna apa yang harus dijalankan saat menutup eksekusi. Jangan menyatakan verifikasi manual yang tertunda sudah lulus.
- Jangan mengunggah apa pun ke nuget.org dan jangan menyentuh feed publik. Uji push hanya ke server lokal.
- Gunakan nama kode, command, dan error message dalam bahasa aslinya; komentar kode dan dokumen mengikuti bahasa file di sekitarnya. Teks UI dan bantuan untuk pengguna tidak menyebut nama objek database.

## Keputusan final (sudah disetujui pengguna)

1. **Nama modul**: `NuPak`. Project `src/modules/EmPoriumHouse.NuPak/EmPoriumHouse.NuPak.{Models,Api,Models.Ui,Wpf}`, namespace `EmPoriumHouse.NuPak[.*]`. Sengaja bukan `EmPoriumHouse.NuGet` karena namespace `NuGet` akan menimpa referensi ke paket `NuGet.Versioning`. Label UI: **NuGet Manager** / **NuGet Server**. Prefix tabel: `ta_NuPak`.
2. **Aktif/nonaktif**: disimpan di `ta_Meta`, berlaku langsung tanpa restart. Key `NuPakEnable` (`True`/`False`, default bila baris belum ada: `False`) dan `NuPakAnonymousRead` (default `False`). Cache memori singkat (beberapa detik) yang dibatalkan seketika saat nilai diubah lewat service; tiap request ke `/nuget/...` membaca lewat cache. Nonaktif → semua `/nuget/...` menjawab 404 polos; NuGet Manager dan datanya tetap bisa dibuka; tidak ada data dihapus. Tidak memakai pola `ManagedStorageSettings` (restart).
3. **Folder penyimpanan `.nupkg`**: dipasang di `Program.cs` host seperti modul lain: `builder.AddNuPakModule("./data/nuget")` (path relatif dihitung dari ContentRoot; dibuat saat startup). Tidak ikut toggle runtime.
4. **Metadata** di database inti (tabel di bawah); file `.nupkg` di disk. Total storage dihitung dari `SUM` ukuran di database.
5. **Hak robot per prefix id paket**, lewat `IRobotAccessManager` baru dengan `Id = "NuGet"`; kode hak `R` (restore) dan `W` (restore + push + delete ke recycle bin). Hak diberikan di User Manager > Robots (pola engine yang sudah ada); tab Prefixes di NuGet Manager hanya **menampilkan** robot yang punya hak (baca saja) dengan tombol/ petunjuk ke User Manager. Hard delete hanya dari NuGet Manager oleh user ber-claim.
6. **Prefix wajib terdaftar**: push ke id yang tidak cocok dengan prefix mana pun ditolak (403). Prefix dibuat dulu di NuGet Manager. Prefix pemilik paket ditetapkan saat push pertama id itu = prefix terpanjang yang cocok (awalan id, tanpa membedakan huruf besar-kecil) dan disimpan di baris paket; prefix yang dibuat belakangan tidak memindahkan paket lama.
7. **Endpoint protokol (9)**: service index, flatcontainer (daftar versi, `.nupkg`, `.nuspec`), push, delete, search, registration (index dan leaf). Tidak dibangun: autocomplete, symbol package, statistik unduhan.
8. **Delete = recycle bin**: `DELETE` protokol dan tombol Recycle di manager memindahkan versi ke recycle bin (`cNuPakVersionState = -2`, file tetap di disk). Versi di recycle bin tidak muncul di daftar versi, search, registration, dan tidak bisa diunduh (404), tetapi **id+versi itu tetap dipesan**: push ulang versi yang sama → 409 dengan pesan menyebut recycle bin. Bisa Restore, Purge (hapus permanen satu versi: file + baris), atau Empty Recycle Bin (semua). Tidak ada auto-purge. Versi di recycle bin tetap dihitung di total storage dan juga ditampilkan terpisah.
9. **Audit**: tabel `ta_NuPakAudit` dibangun sekarang; tab Audit di manager.
10. **UI**: NuGet Manager WPF dengan tab **Packages**, **Prefixes**, **Audit**, plus card Settings (toggle aktif, anonymous read, storage). Card NuGet di Home EmPorium House menggantikan "Coming soon": dinamis, ada tombol refresh pojok kanan atas, dan **tombol toggle** aktif/nonaktif. MAUI tidak mendapat layar ini.
11. **Claim** (module `Administrative Tools`, pola `ICtnServices`): `NuGet Manager Access` (lihat, prefix, recycle, restore, audit) dan `NuGet Settings Manage` (toggle aktif, anonymous read, Purge, Empty Recycle Bin). Hak lama tidak otomatis memberi hak baru; administrator mengikuti mekanisme claim administrator.
12. **Batas ukuran push**: 250 MB, parameter opsional `AddNuPakModule(path, maxPackageMb: 250)`.
13. **Lain-lain**: satu feed; tanpa mirror/proxy ke nuget.org; HTTP polos boleh (dokumentasikan `allowInsecureConnections` dan sarankan HTTPS + `packageSourceMapping`); tanpa package signing.
14. **Commit**: satu commit per repo, pesan **Bahasa Indonesia** (judul dan deskripsi), hanya berisi file milik task ini. Lihat Tahap 8 untuk kasus em-system yang working tree-nya sudah berisi pekerjaan lain.

## Tahap 1 — Hook engine di em-system

Titik ekstensi generik; modul produk tidak boleh mengakses internal engine. Registrasi DI tetap builder-only (`EmAppBuilder.Services` internal). Tulis sebagai partial baru (mis. `Api/Shared/EmAppBuilder.Extensibility.cs`) sebanyak mungkin; edit `EmApp.cs` seminimal mungkin karena sudah berisi perubahan pengguna.

- `EmAppBuilder.AddRobotAccessManager<T>() where T : class, IRobotAccessManager` (publik): `Services.AddScoped<IRobotAccessManager, T>()`. Refaktor `AddContainerRegistry` agar boleh memakai jalur yang sama bila murah; jangan mengubah perilakunya.
- `EmAppBuilder.AddPublicEndpoint(string pathPrefix, RequestDelegate handler)` (publik): mendaftarkan jalur di luar dispatcher action (tanpa `HttpRequestTimeout`, tanpa `ActionRateLimit`, seperti `/cdn` dan `/v2`). Dipetakan di `EmApp.Run` dekat `MapCdn`/`MapContainerRegistry`, **sebelum** `UseRouting`/fallback. Tolak prefix kosong, tidak diawali `/`, atau bentrok dengan `/api`, `/cdn`, `/v2`, dan prefix lain yang sudah terdaftar (`InvalidOperationException` saat startup).
- `RobotAuth`: tambahkan overload publik yang mengautentikasi robot dari **token saja** (untuk `X-NuGet-ApiKey`, yang tidak membawa username), dengan aturan sama (robot aktif, token belum kedaluwarsa, `LastUsed` dicatat berselang). Periksa dulu apakah `RobotAuth.AuthenticateAsync(HttpContext, RobotContext)` sudah cukup publik (kelas dan `RobotContext` sudah `public`) dan pakai ulang tanpa menduplikasi.
- Periksa apakah ada throttle kegagalan autentikasi di `RobotAuth`; jika ada, pakai ulang; jika tidak, jangan menambah di plan ini (catat sebagai batas di laporan).
- Tidak ada perubahan skema. Perbarui `claude.md` em-system (bagian pembaruan baru, tanpa menghapus isi lama) dan dokumen engine yang relevan (`doc/engine-robots.md`: modul dapat menambah provider hak lewat `AddRobotAccessManager`).

## Tahap 2 — Skema database (repo ini)

Berkas `doc/sqlscript/mssql/sets/NuPak.sql`, mengikuti gaya `em-system/doc/sqlscript/mssql/sets/Ctn.sql` (header komentar, `SET XACT_ABORT ON`, `IF OBJECT_ID ... IS NULL`, `--region`, aman diulang, `GO`). Prasyarat: skema inti dan `ta_Robot` sudah ada. Id `char(26)` ULID, nama kolom `c` + nama tabel, kolom standar `ustamp`, `datestamp`, `json_object` di setiap tabel. Collation default (case-insensitive) untuk id/versi; kolom hash memakai `SQL_Latin1_General_CP1_CS_AS`. Konvensi: `Doc/Struktur penamaan object database..md` di em-system.

| Tabel | Kolom (selain standar) | Kunci/indeks |
|---|---|---|
| `ta_NuPakPrefix` | `cNuPakPrefixId`, `cNuPakPrefixName varchar(100)` (huruf, angka, `.`, `_`, `-`), `cNuPakPrefixState int`, `cNuPakPrefixDescription varchar(500) NULL` | PK id; UNIQUE name |
| `ta_NuPakPackage` | `cNuPakPackageId`, `cNuPakPrefixId` FK (tanpa cascade), `cNuPakPackageName varchar(128)` (casing asli dari nuspec), `cNuPakPackageState int` | PK; UNIQUE name (CI); indeks `cNuPakPrefixId` |
| `ta_NuPakVersion` | `cNuPakVersionId`, `cNuPakPackageId` FK ON DELETE CASCADE, `cNuPakVersionNumber varchar(64)` (ternormalisasi, huruf kecil), `cNuPakVersionOriginal varchar(64)`, `cNuPakVersionPrerelease bit`, `cNuPakVersionState int` (1 aktif, -2 recycle bin), `cNuPakVersionRecycledAt datetime NULL`, `cNuPakVersionSize bigint`, `cNuPakVersionHash varchar(128)` (SHA-512 base64, collation CS), `cNuPakVersionNuspec nvarchar(max)`, `cNuPakVersionTitle varchar(255) NULL`, `cNuPakVersionDescription varchar(4000) NULL`, `cNuPakVersionAuthors varchar(500) NULL`, `cNuPakVersionTags varchar(1000) NULL`, `cNuPakVersionPushedBy_cRobotId char(26) NULL` FK ke `ta_Robot` | PK; UNIQUE (`cNuPakPackageId`, `cNuPakVersionNumber`); indeks `cNuPakVersionState` |
| `ta_NuPakPrefixRobot` | `cRobotId` FK `ta_Robot`, `cNuPakPrefixId` FK ON DELETE CASCADE, `cNuPakPrefixRobotAccess varchar(8)` (`R`/`W`) | PK komposit; meniru `ta_CtnRootRobot` |
| `ta_NuPakAudit` | `cNuPakAuditId`, `cNuPakAuditAt datetime`, `cNuPakAuditAction varchar(20)` (`Push`, `Recycle`, `Restore`, `Purge`, `EmptyBin`, `Enable`, `Disable`, `AnonymousRead`, `PrefixCreate`, `PrefixUpdate`, `PrefixDelete`), `cNuPakAuditPackage varchar(128) NULL`, `cNuPakAuditVersion varchar(64) NULL`, `cNuPakAuditActorKind varchar(10)` (`Robot`/`User`), `cNuPakAuditActorId char(26) NULL`, `cNuPakAuditActorName varchar(255)`, `cNuPakAuditResult varchar(10)` (`Success`/`Denied`/`Failed`), `cNuPakAuditDetail varchar(500) NULL`, `cNuPakAuditAddress varchar(64) NULL` | PK; indeks `cNuPakAuditAt DESC`, indeks (`cNuPakAuditPackage`, `cNuPakAuditVersion`) |

Catatan skema:
- Pemakaian ulang `ta_Robot`: saat robot dihapus, provider `PrepareDeleteAsync` mengosongkan `cNuPakVersionPushedBy_cRobotId` dan menghapus baris `ta_NuPakPrefixRobot` miliknya dalam transaksi yang sama (meniru `CtnRobotAccessManager`, termasuk konteks pendek yang berbagi koneksi/transaksi). Nama aktor di audit disalin sebagai teks sehingga tetap terbaca setelah robot/user dihapus; `cNuPakAuditActorId` tanpa FK.
- Path file `.nupkg` **tidak** disimpan; dihitung dari id+versi.
- View `vi_` (nama sama dengan tabel, tanpa kalkulasi berat, pola `Ctn.sql`/skill scaffold): `vi_NuPakPrefix`, `vi_NuPakPackage` (plus nama prefix), `vi_NuPakVersion` (tanpa kolom nuspec), `vi_NuPakAudit`. Agregat (jumlah versi, ukuran per paket/prefix, versi terbaru) dihitung di service lewat query terindeks, bukan di view. Urutan "versi terbaru" memakai urutan semver di aplikasi.
- Tidak ada tabel untuk toggle: `ta_Meta` (`NuPakEnable`, `NuPakAnonymousRead`).
- Jalankan skrip pada database lokal bila tidak diblokir policy; bila diblokir, siapkan `.ps1` manual.

## Tahap 3 — Models, kontrak, dan UI model

`src/modules/EmPoriumHouse.NuPak/EmPoriumHouse.NuPak.Models` (+ `.Models.Ui`): entitas `ta_NuPak*` dan `vi_NuPak*`, DTO, dan `INuPakServices : IServices` (module `Administrative Tools`). Ikuti pola `ICtnServices`/`ITestServices`, `doc/service_pattern.cs` em-system, aturan nama action (`GetMeta_`, `PostGetMeta_`, `PostMeta_`; setiap action wajib atribut `[GetAction]`/`[PostAction]` atau menjawab 404 diam) dan peran project model (Models untuk module, Models.Ui untuk UI). Tidak ada `Task` ke luar tanpa `CancellationToken` bila pola ICtn memintanya; cocokkan dengan pola yang ada.

Action (claim di kurung: M = `NuGet Manager Access`, S = `NuGet Settings Manage`):
- Status/pengaturan: `GetMeta_NuPakStatus` (M; mengembalikan `Enabled`, `AnonymousRead`, alamat service index relatif, hitung prefix/paket/versi/recycle), `PostGetMeta_NuPakSetEnabled(bool)` (S), `PostGetMeta_NuPakSetAnonymousRead(bool)` (S), `GetMeta_NuPakStorageSize` (M; total byte, aktif, recycle bin, jumlah paket/versi; versi recycle ikut total).
- Prefix: `GetMeta_NuPakPrefixes` (M; plus jumlah paket dan ukuran), `PostGetMeta_NuPakPrefixCreate`, `PostGetMeta_NuPakPrefixUpdate` (ganti nama hanya jika belum ada paket), `PostMeta_NuPakPrefixDelete` (409 bila masih ada paket, termasuk yang di recycle bin; hak robot ikut terhapus), `GetMeta_NuPakPrefixAccess(prefixId)` (M; robot beserta kode hak, baca saja).
- Paket: `GetMeta_NuPakPackages(prefixId, search, skip, take)`, `GetMeta_NuPakVersions(packageId)` (aktif saja), `PostMeta_NuPakVersionRecycle(versionId)`, `PostMeta_NuPakVersionRestore(versionId)` (409 bila bentrok tak mungkin; versi unik sehingga cukup validasi state), `GetMeta_NuPakRecycleBin(prefixId?, skip, take)`, `PostMeta_NuPakVersionPurge(versionId)` (S), `PostMeta_NuPakRecycleBinEmpty(prefixId?)` (S; mengembalikan jumlah dan byte yang dibebaskan).
- Audit: `GetMeta_NuPakAudit(filter, skip, take)` (M; filter paket, versi, aktor, aksi, hasil, rentang waktu).
- Semua kegagalan memakai `ActionException` dengan kode HTTP yang sesuai. Saat modul belum dipasang di server, action menjawab 404 (card Home membacanya sebagai "modul tidak dinyalakan"); saat modul terpasang tetapi toggle nonaktif, action manajemen **tetap bekerja** (hanya `/nuget/...` yang 404).

## Tahap 4 — Api: modul, penyimpanan, hak, dan layanan

`EmPoriumHouse.NuPak.Api`: `NuPakDbContext`, `NuPakServices` (partial per area, seperti `TestServices.*.cs`), `NuPakStore` (layout file + operasi atomic), `NuPakSettings` (cache toggle dari `ta_Meta`, dibatalkan saat diubah), `NuPakRobotAccessManager : IRobotAccessManager` (`Id = "NuGet"`, `Options` R/W, `Resources` = prefix; pola `CtnRobotAccessManager`), `NuPakModuleExtensions.AddNuPakModule(this EmAppBuilder, string localStorePath, int maxPackageMb = 250)`: `AddDbContext<NuPakDbContext>()`, `AddService<INuPakServices, NuPakServices>()`, `AddClaims(...)` untuk dua claim, `AddRobotAccessManager<NuPakRobotAccessManager>()`, `AddPublicEndpoint("/nuget", NuPakEndpoint.HandleAsync)`, folder dibuat saat startup, panggilan kedua ditolak. Startup memeriksa keberadaan seluruh tabel `ta_NuPak*` dan gagal dengan pesan yang menyebut `NuPak.sql` (pola `CtnStartupChecks`). Sisa file di folder `temp/` dihapus saat startup.

Penyimpanan: `{root}/packages/{id-lower}/{version-lower}/{id-lower}.{version-lower}.nupkg`; unggahan ditulis ke `{root}/temp/<ulid>.tmp` sambil menghitung SHA-512 dan ukuran (tolak bila melebihi `maxPackageMb` sambil streaming), divalidasi, lalu dipindah (`File.Move`) dan baris dicatat; bila `SaveChanges` gagal, file dihapus. Validasi id/versi dengan regex ketat sebelum jadi bagian path (cegah path traversal); jangan pernah membentuk path dari input mentah. Purge menghapus file lalu baris (atau sebaliknya dengan urutan yang aman terhadap kegagalan, dicatat di komentar) dan menghapus folder kosong; baris paket tanpa versi sama sekali ikut dihapus. Empty Recycle Bin memproses per versi dan melaporkan sebagian-berhasil bila ada kegagalan file (dengan tetap konsisten DB/disk).

## Tahap 5 — Endpoint protokol `/nuget`

`NuPakEndpoint` (di luar dispatcher action). Alamat absolut di service index dibangun dari scheme/host/PathBase request (engine sudah memakai `UseForwardedHeaders`). Kesalahan tak terduga: 500 polos dan log; `OperationCanceledException` karena klien pergi diabaikan. Semua jawaban selain 2xx/401 tanpa body sensitif.

Pintu masuk, berurutan: (1) toggle (cache) mati → 404 polos; (2) autentikasi; (3) otorisasi per prefix; (4) operasi.

- **Autentikasi**: header Basic = nama robot + token (`RobotAuth`). Push juga menerima `X-NuGet-ApiKey` berisi token robot. Tanpa kredensial: bila `NuPakAnonymousRead` aktif dan metodenya baca, lanjut sebagai anonim; selain itu 401 + `WWW-Authenticate: Basic realm="EmPorium House NuGet"`. Kredensial ada tetapi salah → 401 (juga pada mode anonim). Metode tulis (PUT, DELETE) tidak pernah anonim.
- **Otorisasi**: baca butuh `R` atau `W` pada prefix pemilik paket; robot tanpa hak apa pun pada prefix itu menerima 404 (tidak membocorkan keberadaan). Mode anonim: semua paket aktif terbaca. Search/registration hanya menampilkan paket yang boleh dibaca pemanggil. Push dan delete butuh `W` pada prefix (push: prefix hasil pencocokan id; tidak cocok → 403 dengan pesan jelas; tidak punya `W` → 403).

Endpoint (semua di bawah `/nuget`):

| # | Method | Path | Perilaku |
|---|---|---|---|
| 1 | GET | `/v3/index.json` | Service index `{"version":"3.0.0","resources":[...]}` dengan resource: `PackageBaseAddress/3.0.0` (`/v3/flatcontainer/`), `PackagePublish/2.0.0` (`/v2/package`), `SearchQueryService`, `SearchQueryService/3.0.0-rc`, `SearchQueryService/3.5.0` (`/v3/search`), `RegistrationsBaseUrl`, `RegistrationsBaseUrl/3.6.0` (`/v3/registration/`). Semua `@id` absolut. |
| 2 | GET | `/v3/flatcontainer/{id}/index.json` | `{"versions":[...]}` versi aktif ternormalisasi huruf kecil, urut semver naik; 404 bila tidak ada versi aktif. `{id}` diperlakukan tanpa membedakan huruf. |
| 3 | GET | `/v3/flatcontainer/{id}/{version}/{id}.{version}.nupkg` | Streaming file (mendukung Range/HEAD seperti file statis; `application/octet-stream`); versi di recycle bin → 404. |
| 4 | GET | `/v3/flatcontainer/{id}/{version}/{id}.nuspec` | Isi `cNuPakVersionNuspec` (`application/xml`). |
| 5 | PUT | `/v2/package` | `multipart/form-data` dengan satu bagian file (`.nupkg`). 201 Created; 400 paket tidak valid; 401/403; 409 id+versi sudah ada (aktif atau di recycle bin); 413 melebihi batas. |
| 6 | DELETE | `/v2/package/{id}/{version}` | Memindahkan versi ke recycle bin; 204; 404 bila tidak ada/sudah di recycle bin; 401/403. |
| 7 | GET | `/v3/search` | Parameter `q`, `skip`, `take`, `prerelease`, `semVerLevel`; respons `totalHits` dan `data[]` (`@id`, `id`, `version` terbaru yang cocok, `description`, `title`, `authors`, `tags`, `versions[]` (`version`, `@id`, `downloads`), `totalDownloads` = 0, `verified` = false). Pencarian pada id, judul, tag, deskripsi; hanya versi aktif; `take` dibatasi (mis. maks 100). |
| 8 | GET | `/v3/registration/{id}/index.json` | RegistrationIndex dengan satu halaman inline berisi semua versi aktif (leaf berisi `catalogEntry` dengan `id`, `version`, `authors`, `description`, `dependencyGroups` hasil parse nuspec, `listed: true`, `packageContent`, `tags`, `title`). |
| 9 | GET | `/v3/registration/{id}/{version}.json` | Satu leaf registration. |

Validasi push (urutan: batas ukuran → zip valid → tepat satu `.nuspec` di akar zip → nuspec ≤ 1 MB, dibaca langsung dari entri tanpa mengekstrak ke disk → `id`/`version` sah → versi lolos `NuGet.Versioning` (tambahkan paket **NuGet.Versioning** ke project Api) → prefix cocok dan hak `W` → versi belum ada). Versi disimpan ternormalisasi (`ToNormalizedString()`, huruf kecil; build metadata `+...` dibuang untuk keunikan) dan versi asli disimpan terpisah. Id harus sesuai `^[A-Za-z0-9]([A-Za-z0-9._-]*[A-Za-z0-9])?$` maks 100. Nuspec tak boleh berisi DTD/entitas eksternal (`XmlReaderSettings.DtdProcessing = Prohibit`, `XmlResolver = null`).

Pustaka acuan perilaku: dokumentasi NuGet Server API (`learn.microsoft.com/nuget/api/overview`). Verifikasi bentuk JSON terhadap klien nyata (`dotnet restore`, `dotnet nuget push`, `dotnet package search`) di Tahap 8, bukan hanya terhadap dokumen.

Audit: setiap Push/Recycle/Restore/Purge/EmptyBin/Enable/Disable/AnonymousRead/Prefix* berhasil dicatat dengan aktor (robot atau user) dan alamat klien. Push/Delete yang ditolak (401 dikecualikan karena aktornya belum dikenal; 403/409/400 untuk aktor terautentikasi) dicatat `Denied`/`Failed`. Audit ditulis di transaksi yang sama dengan perubahannya bila memungkinkan; kegagalan menulis audit untuk aksi baca tidak ada (baca tidak diaudit).

## Tahap 6 — WPF: NuGet Manager

`EmPoriumHouse.NuPak.Wpf`: `NuPakService : INuPakServices` (proxy client, pola `CtnService`), `AddNuPakModule(this EmAppBuilder)` (daftarkan service dan navigasi `admin.nupak`, claim `NuGet Manager Access`, ikon FontAwesome 6, grup Tools/Administrative seperti Container Manager), dan layar **NuGet Manager** (`NuPakManager.xaml[.cs]` + ViewModel partial per tab). Pola visual dan perilaku mengikuti `Em.Ui.Wpf.Core/Navigations/ContainerManager*` dan `RobotManager.xaml`.

- **Card Settings** di bagian atas (selalu tampil, juga ketika nonaktif): toggle Enabled (langsung berlaku; menonaktifkan meminta konfirmasi bahwa klien akan menerima 404), toggle Anonymous read, alamat service index yang bisa disalin (`http(s)://<server>/nuget/v3/index.json`) beserta contoh `nuget.config` (termasuk `allowInsecureConnections`), total storage (aktif + recycle bin, rincian jumlah paket/versi). Tombol refresh kecil di pojok kanan atas card: memuat ulang seluruh informasi card, tetap bisa dicoba ulang setelah gagal, mencegah request ganda. Toggle dan tombol milik card hanya aktif untuk pemegang `NuGet Settings Manage`; tanpa itu tampil nonaktif tanpa mengubah warna tema.
- **Tab Packages**: kiri daftar prefix (jumlah paket, ukuran), tengah daftar paket prefix terpilih (pencarian), kanan detail paket dan daftar versi (ukuran, hash, pengirim, waktu push, prerelease) dengan tindakan Recycle; sub-tampilan **Recycle Bin** (daftar versi di recycle bin, Restore, Purge, Empty Recycle Bin dengan konfirmasi yang menyebut jumlah dan ukuran). Tombol salin `PackageReference` dan perintah `dotnet add package` per versi.
- **Tab Prefixes**: CRUD prefix; panel hak robot (baca saja: robot, kode hak R/W) dengan petunjuk bahwa hak diatur di User Manager > Robots. Hapus prefix menampilkan 409 dengan penjelasan bila masih ada paket.
- **Tab Audit**: daftar log bergulir dengan filter paket, versi, aktor, aksi, hasil, dan rentang waktu.
- Setiap card/panel yang menampilkan informasi dinamis punya tombol refresh kecil di pojok kanan atas (aturan permanen repo).
- **Aturan UI WPF anti kilatan putih**: seluruh kondisi enabled/disabled/busy harus mempertahankan warna tema terang/gelap. Gunakan `surfaceListBoxStyle`/`surfaceTreeViewStyle` dari `Em.Ui.Wpf.Core/Styles/Collections.xaml` (digabung lewat `MaterialDesign.xaml`) untuk ListBox/TreeView di panel bertema; jangan mengandalkan `Background="Transparent"`; jangan menyalin palette per file; jangan menaruh layar di `Controls/` (layar di `Navigations/`-nya modul). Pertahankan seleksi, scroll, virtualisasi, dan pemblokiran interaksi saat busy.

## Tahap 7 — Host EmPorium House, Home, dan dokumentasi

- `EmPoriumHouse.Api`: `ProjectReference` ke `EmPoriumHouse.NuPak.Api` dan `.Models` (lewat `$(...)` yang sudah ada; engine tetap lewat `$(EmSystemPath)`), tambahkan `builder.AddNuPakModule("./data/nuget");` di `Program.cs`, dan perbarui komentar prasyarat database (skrip `NuPak.sql`). `.gitignore` mencakup `data/nuget` bila folder data belum terabaikan.
- `EmPoriumHouse.Ui.Wpf`: `ProjectReference` ke `.Wpf`/`.Models.Ui`, `builder.AddNuPakModule()` di `Program.cs`, dan perbarui **Home**:
  - Card NuGet (`Home/EmPoriumHomeControl.xaml[.cs]`, `HomeModels.cs`) tidak lagi "Coming soon": status (Ready / Off = server tidak memasang modul atau modul nonaktif / Warning = tanpa hak atau server tidak menjawab), angka ringkas Prefixes, Packages, Versions, alamat service index (bisa disalin), total storage dengan keterangan (versi di recycle bin ikut dihitung; kegagalan membaca storage = "unavailable" tanpa menggagalkan sisa card), tombol **Open NuGet Manager**.
  - **Tombol toggle** di card: aktif/nonaktif langsung berlaku (memanggil `PostGetMeta_NuPakSetEnabled`), memperbarui status dan teks card setelah berhasil; disable mencegah request ganda, menampilkan loading bertema, dan konfirmasi saat menonaktifkan. Hanya aktif untuk pemegang `NuGet Settings Manage`; tanpa hak, tombol tampil nonaktif (bukan hilang) dengan tooltip. Kegagalan menampilkan pesan dan mengembalikan keadaan toggle ke nilai server.
  - **Tombol refresh** kecil pojok kanan atas card NuGet seperti card registry/CDN: memuat ulang seluruh informasi card itu secara independen, guard request ganda, retry setelah gagal.
  - Perbarui `../.artefacts/EmPorium/scripts/module-card-qa-render` (harness render) agar mencakup card NuGet: ready, busy, disabled/off, tanpa hak, tema terang dan gelap.
- Dokumentasi: `doc/nuget-server.md` (cara menyalakan modul di `Program.cs`, menjalankan `NuPak.sql`, membuat prefix, memberi hak robot di User Manager, contoh `nuget.config` dengan `packageSourceMapping` dan `allowInsecureConnections`, `dotnet nuget push/delete`, semantik recycle bin, batas yang diketahui); jangan menyebut nama objek database di teks yang ditujukan untuk pengguna akhir. Perbarui `README.md` (bahasa Inggris, satu-dua baris fitur NuGet) dan `CLAUDE.md` repo ini (bagian pembaruan baru, isi lama dipertahankan). Perbarui deskripsi fitur hanya yang sudah jadi.

## Tahap 8 — Integrasi, pengujian, review, commit (dikerjakan sekali, setelah semua kode selesai)

1. Build: `dotnet build src/backend/EmPoriumHouse.Api.slnx`, `dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx`, dan build em-system yang tersentuh hook (`dotnet build src/backend/Em.Api.slnx`, `src/frontend/Em.Ui.Wpf.slnx`; tanpa warning/error baru). Bila exe terkunci oleh aplikasi pengguna yang sedang berjalan, jangan hentikan prosesnya: bangun ke `--artifacts-path` terpisah dan catat.
2. Uji layanan terhadap SQL Server lokal dalam transaksi yang di-rollback (pola `scripts/*-smoke` di em-system): prefix (cocok terpanjang, hapus diblokir), push/duplikat/recycle/restore/purge/empty, agregat storage vs SQL (termasuk recycle bin dan bigint > 4 GB), claim GET, hak R/W lewat `IRobotAccessManager`, penghapusan robot, audit, toggle + cache dibatalkan.
3. Uji protokol terhadap server lokal: bila server dapat dijalankan, uji nyata `dotnet nuget push` (paket kecil dari `dist/nuget-pack` em-system, **ke feed lokal saja**), `dotnet restore` dari feed, `dotnet package search`, `dotnet nuget delete`, 401/403/404/409, mode anonim, toggle mati → 404, service index di belakang prefix path, Range pada unduhan. Jika memerlukan password admin/robot yang tidak tersedia atau tindakan diblokir, jangan mengarang hasil: siapkan skrip `.ps1` manual di `plan/nuget-server-manual/` dan catat sebagai verifikasi tertunda.
4. Uji layar: harness konsol STA tanpa server (render PNG, service palsu) untuk NuGet Manager dan card Home pada tema terang/gelap, kondisi ready/busy/disabled/error, dan transisi busy (termasuk request yang selesai cepat). Periksa visual. Klik dengan mouse dan terhadap server nyata yang tidak dapat dilakukan dicatat sebagai verifikasi tertunda; build saja tidak membuktikan kilatan putih hilang.
5. Review sekali di akhir: path traversal, zip/xml bomb, kebocoran keberadaan paket antar-prefix, konsistensi DB/disk saat gagal di tengah push/purge, race pada push duplikat (andalkan indeks unik → 409), cache toggle, dan kepatuhan semua aturan di bagian "Aturan eksekusi". Perbaiki temuan, bangun ulang, ulangi uji yang terdampak.
6. Tulis **Hasil eksekusi** di bagian bawah berkas plan ini: yang selesai, penyimpangan dari plan beserta alasannya, hasil build/uji, batas yang diketahui (mis. tanpa throttle autentikasi bila belum ada, tanpa statistik unduhan, tanpa auto-purge, satu instance API untuk cache toggle), dan verifikasi tertunda beserta perintah PowerShell lengkap untuk dijalankan manual. Pindahkan berkas ini ke `plan/executed/`.
7. Commit (satu per repo, pesan Bahasa Indonesia, hanya file milik task ini; jangan `git add -A`): di repo ini satu commit untuk modul, host, Home, skrip, dan dokumen. Di em-system satu commit untuk hook engine **hanya jika** file yang diubah tidak berisi hunk pekerjaan lain; periksa `git diff` file yang beririsan (`EmApp.cs`, `EmAppBuilder.cs`, dst.). Jika hunk milik task ini tidak dapat dipisahkan dengan aman (mis. via patch parsial `git apply --cached`), **jangan commit em-system**, biarkan di working tree, dan beri tahu pengguna file mana yang harus di-commit setelah pekerjaan storage settings mereka selesai. Jangan melewati hook, jangan `--no-verify`, dan jangan push.

## Verifikasi yang diperkirakan tertunda (dicatat, bukan dijanjikan lulus)

Uji klien NuGet nyata terhadap server yang berjalan dengan token robot asli, uji klik mouse dan interaksi window sungguhan, tampilan card/manager terhadap data server nyata, `packageSourceMapping`/IDE (Visual Studio/Rider) terhadap feed, serta pengujian di belakang reverse proxy HTTPS.

## Hasil eksekusi — 2026-10-03

### Implementasi selesai

- Tahap 1: engine menyediakan endpoint publik sebelum dispatcher, validasi prefix/overlap, provider hak robot, autentikasi token saja, serta pendaftaran singleton/hosted service lewat builder. Hook produk tidak mengakses service collection internal.
- Tahap 2–5: empat project NuPak, skrip lima tabel dan empat view, metadata toggle default off/private dengan invalidasi cache, storage streaming SHA-512, validasi ZIP/XML/id/version, prefix terpanjang dan kepemilikan tetap, sembilan endpoint V3, hak robot R/W, recycle/restore/purge/empty, agregat bigint, audit mutasi/penolakan/kegagalan. Startup memeriksa skema, membersihkan upload scratch dan memulihkan quarantine purge berdasarkan SQL.
- Tahap 6: NuGet Manager memiliki Settings, Packages, Recycle Bin, Prefixes dan Audit; refresh tiap panel, paging, editor prefix, hak robot baca saja, copy config/alamat/PackageReference/CLI, konfirmasi operasi permanen, dan guard request ganda. Tema memakai MaterialDesign/Collections engine.
- Tahap 7: API/WPF host memasang modul; Home menampilkan status/angka/alamat/storage/refresh/toggle; storage yang gagal tidak merusak statistik card. Host WPF debug memakai port produk 5232. README, CLAUDE.md, panduan dan harness diperbarui.
- `NuPak.sql` sudah dijalankan pada database lokal. Feed lokal tetap **off**, tanpa anonymous read; tidak ada robot permanen atau paket nyata yang dibuat sebagai data produksi oleh harness. Uji SQL memakai database sementara tanpa menyalin isi identitas pengguna.

### Verifikasi yang lulus

| Pemeriksaan | Hasil |
| --- | --- |
| Build backend EmPorium House | 0 warning, 0 error |
| Build WPF EmPorium House | 0 warning, 0 error |
| Build backend dan WPF em-system | Keduanya 0 warning, 0 error |
| `../.artefacts/EmPorium/scripts/nuget-smoke` | **79 pemeriksaan lulus** pada database SQL terisolasi dan server loopback sementara |
| Klien `dotnet` | Push paket `Em.Libs.0.1.0-pre-alpha.1.nupkg`, search, restore privat dengan Basic + source mapping + cache baru, dan delete lulus |
| Protokol | 400/401/403/404/409/413, audit gagal/ditolak, PathBase `/house`, HEAD, Range 206, nuspec, registration index/leaf dan gzip negotiation lulus |
| Konsistensi | Race push satu pemenang; gagal SQL setelah file move membersihkan file; gagal purge mengembalikan file/baris; empty-bin dengan file terkunci mempertahankan metadata dan melaporkan kegagalan |
| Layanan/hak | Prefix terpanjang, kepemilikan tetap setelah prefix baru, rename/delete diblokir bila berisi paket, restore/recycle, storage >4 GB, toggle cache, provider R/W, rollback/commit cleanup robot dan audit yang tetap terbaca lulus |
| WPF offline | Harness STA membuat **28 PNG**: Home dan seluruh tab Manager; light/dark, busy/off/error, tanpa hak, retry, duplikat request, transisi request cepat, toggle Home, serta panel berisi data. PNG utama dan tab diperiksa secara visual; tidak ada panel/list memutih saat disabled |
| Host asli | `../.artefacts/EmPorium/scripts/nuget-host-smoke/nuget-host-smoke.ps1` menyalakan satu proses milik harness dan memverifikasi `/nuget/v3/index.json` = 404 saat off, lalu menghentikan prosesnya sendiri |
| Skrip manual | Sintaks PowerShell diverifikasi; skrip dengan akun robot permanen belum dijalankan |

Perintah reproduksi (PowerShell, direktori kerja `<EmPorium>`):

```powershell
dotnet build src/backend/EmPoriumHouse.Api.slnx
dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx
dotnet run --project ../.artefacts/EmPorium/scripts/nuget-smoke -- <EmPorium>
dotnet run --project ../.artefacts/EmPorium/scripts/module-card-qa-render
pwsh -NoProfile -File ../.artefacts/EmPorium/scripts/nuget-host-smoke/nuget-host-smoke.ps1
```

Harness SQL memerlukan hak CREATE/DROP DATABASE. Database `EmNuPakSmoke_<guid>` dihapus setelah uji; file fixture berada di direktori temp milik harness dan dibersihkan. Connection string dibaca dari konfigurasi lokal/environment tanpa dicetak. Tidak ada push/delete ke feed publik. Perintah instalasi skema (sudah dilakukan pada mesin ini; hanya diperlukan untuk database lain):

```powershell
dotnet run --project ../.artefacts/EmPorium/scripts/nuget-smoke -- <EmPorium> --install-schema
```

### Penyimpangan dan temuan review

1. Menambah hook `AddSingleton<T>(factory)` dan `AddHostedService<T>()`: diperlukan agar store/cache/startup modul didaftarkan tanpa membuka `Services` internal atau service locator statis. Tetap builder-only dan generik.
2. Menambah alias `SearchQueryService/3.0.0-beta`: klien nyata mengabaikan alias search yang semula ditulis di plan. Dibuktikan oleh kegagalan awal search, dikonfirmasi pada [kode resmi NuGet ServiceTypes](https://github.com/NuGet/NuGet.Client/blob/dev/src/NuGet.Core/NuGet.Protocol/ServiceTypes.cs), lalu diuji ulang. `packageType` filtering juga dilayani untuk alias 3.5.0.
3. Leaf standalone tidak membawa objek inline `catalogEntry`; metadata lengkap tetap di page inline. Ini mengikuti [bentuk leaf resmi](https://learn.microsoft.com/en-us/nuget/api/registration-base-url-resource#registration-leaf); gzip dilayani melalui negotiation. Daftar versi/download/search tidak memuat seluruh nuspec bila tidak diperlukan.
4. UI Manager memakai partial code-behind per tab, alih-alih ViewModel partial terpisah. State/guard tetap terpusat, service tetap melalui kontrak/proxy; pendekatan mengikuti card pengaturan engine dan dapat dirender dengan service palsu. Recycle Bin menjadi tab tambahan agar mudah dibuka.
5. Seluruh layanan diuji di database disposable, alih-alih membungkus semua action dalam satu transaksi luar: action produksi memiliki transaksi sendiri. Jalur penghapusan robot secara khusus diuji dalam transaksi yang di-rollback dan transaksi commit; uji kegagalan SQL menguji rollback mutasi lainnya.
6. Refresh dan tombol salin tetap tersedia bagi pembaca Manager, sementara toggle/purge/empty mensyaratkan Settings Manage. Pembaca dapat retry dan menyalin konfigurasi tanpa diberi hak mengubah server.
7. Uji normal awal menemukan terjemahan LINQ DTO yang tidak didukung, pemetaan exception 413 ke 400, style WPF yang tidak tersedia, dan alias search klien. Semuanya diperbaiki sebelum verifikasi akhir. Delete CLI pada SDK ini tidak menerima `--allow-insecure-connections`; izin HTTP berasal dari config.
8. Validasi path juga menolak junction/symlink dan nama device Windows. Purge memakai rename quarantine + rollback/recovery startup. Race mengandalkan gate satu instance serta indeks unik; exception DB non-unik tidak disamarkan sebagai konflik 409.

### Batas dan verifikasi tertunda

- Satu instance API per store/cache; tanpa throttle kegagalan autentikasi, mirror, symbols, autocomplete, statistik download, signing enforcement, atau auto-purge.
- Crash proses setelah file push ditempatkan tetapi sebelum commit SQL dapat menyisakan file yatim. Push yang bertabrakan ditolak; administrator harus merekonsiliasi file/metadata. Purge quarantine dipulihkan otomatis saat startup.
- Registration satu halaman inline dapat besar untuk paket dengan sangat banyak versi. Search mengurutkan kandidat semver di aplikasi; belum diuji pada katalog besar. Legacy registration memakai hive yang sama dengan SemVer2 sesuai plan; kompatibilitas klien lama belum diuji.
- Dukungan skema dan conflict mapping diverifikasi pada SQL Server. MySQL/PostgreSQL belum disediakan skrip atau diuji.
- Claim setiap action diperiksa pada atribut/registrasi; penolakan dispatcher terhadap user non-admin yang login dengan hak terbatas belum diuji end-to-end. Hak protokol robot R/W dan ketiadaan kebocoran read/search antar-prefix sudah diuji HTTP.
- Klik mouse/clipboard/dialog konfirmasi, perubahan sesi/claim dalam window nyata, login lalu Manager/Home terhadap server/data pengguna nyata, Visual Studio/Rider, dan reverse proxy HTTPS masih belum diuji. Render offline dan build tidak dianggap membuktikan seluruh interaksi nyata.
- Tidak ada tindakan `blocked by policy` dalam eksekusi ini. Skrip manual berikut disiapkan untuk verifikasi yang membutuhkan akun robot permanen, bukan untuk menghindari blokir.

Verifikasi akun nyata: nyalakan API, buat prefix `MatrixCode.` dan robot dengan W melalui UI, lalu jalankan dari PowerShell:

```powershell
Set-Location <EmPorium>
$token = Read-Host 'Robot token' -AsSecureString
& .\plan\nuget-server-manual\Verify-LiveFeed.ps1 -Source 'http://localhost:5232/nuget/v3/index.json' -RobotName 'build-robot' -RobotToken $token -Prefix 'MatrixCode.'
```

Skrip hanya menerima feed loopback, membuat ID paket unik, melakukan push/search/restore/delete, dan meninggalkannya di recycle bin. Periksa hasil CLI serta audit/Recycle Bin dalam Manager, lalu Purge paket uji. Untuk uji interaksi UI: `dotnet run --project src/frontend/EmPoriumHouse.Ui.Wpf` dan periksa seluruh tab, toggle, refresh/retry, dialog recycle/purge/empty, clipboard dan tema terang/gelap dengan akun administrator serta akun terbatas.

### Commit

- em-system: **69e28fd** — `Tambah ekstensi endpoint publik dan autentikasi token robot`. `EmApp.cs` dan `claude.md` di-stage melalui patch parsial; diff staged diperiksa, hanya hook/dokumen task yang masuk. Seluruh hunk storage settings pengguna tetap di working tree.
- EmPorium House: satu commit modul, host, Home, skema, harness, panduan, skrip manual dan plan ini; pesan commit Bahasa Indonesia. Hash dilaporkan pada jawaban akhir.
- Tidak melakukan push dan tidak melewati hook.
