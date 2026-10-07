# NuGet Server — multi-feed

Tanggal: 2026-10-03.
Status: kode dan migrasi lokal selesai; 162 pemeriksaan otomatis dan render terang/gelap lulus. Pembaruan panduan developer tertunda manual akibat policy, bersama verifikasi interaksi nyata/HTTPS/IDE yang dicatat di laporan.
Pelaksana: Codex. Repo pemilik: `<EmPorium>` (EmPorium House).

## Tujuan

Ubah NuPak dari satu feed global menjadi sistem multi-feed sejak awal dalam satu instance API. Setiap feed mempunyai URL, prefix, paket, pengaturan aktif/anonymous read, recycle bin, statistik, dan audit sendiri. ID paket dan versi yang sama boleh berisi artefak berbeda pada feed berbeda. Instalasi awal mempunyai nol feed; pengguna membuat semua feed secara eksplisit. Tidak ada feed bawaan atau feed khusus.

Permintaan saat penyusunan hanya membuat plan ini. Jangan menganggap penyusunan plan sebagai eksekusi migrasi atau perubahan kode.

## Keputusan final pengguna

1. Cakupan implementasi lengkap: migrasi database, backend/protokol, WPF/Home/User Manager, dokumentasi, dan pengujian.
2. URL utama: `/nuget/{slug}/v3/index.json`. Semua resource protokol berada dalam feed yang sama.
3. Keunikan paket adalah per feed: nama paket + versi sama boleh ada pada beberapa feed. Prefix juga unik per feed, bukan global.
4. Setiap feed mempunyai toggle aktif dan anonymous read sendiri, berlaku langsung tanpa restart.
5. Robot tetap satu identitas engine; hak `R`/`W` diberikan per prefix **dalam feed**. Tidak ada hak robot otomatis untuk seluruh feed atau pewarisan dari owner.
6. Keputusan terbaru menggantikan rancangan sebelumnya: hapus konsep feed `default`, seed feed otomatis, dan perlakuan istimewa untuk feed tertentu. Semua feed mengikuti aturan yang sama dan dapat dihapus ketika kosong.
7. Semua endpoint protokol wajib menyertakan slug feed. URL single-feed lama `/nuget/v3/...` dan `/nuget/v2/...` menjawab 404; tidak ada alias, redirect, atau fallback ke feed tertentu.
8. Folder tiap feed dikelola server di bawah root NuPak. Home menampilkan ringkasan semua feed dan toggle server utama.
9. Feed hanya boleh dihapus saat kosong, termasuk tidak mempunyai versi di recycle bin. Slug tidak dapat diubah setelah dibuat.
10. Claim administrator yang ada tetap berlaku untuk semua feed: `NuGet Manager Access` dan `NuGet Settings Manage`. Tidak menambah claim user per feed.
11. Pengguna mengonfirmasi data saat ini masih kosong. Eksekusi lokal berfokus pada pembaruan skema tanpa membuat feed. Konfirmasi ini tidak mengizinkan drop/reset tabel; periksa kondisi aktual saat eksekusi. Migrasi data single-feed berisi paket/prefix/grant di luar cakupan; jika ditemukan, hentikan update sebelum perubahan dan laporkan agar tujuan feed dapat ditentukan secara eksplisit, tanpa membuang atau menempatkan data secara otomatis.

## Ketentuan teknis pelaksanaan

- Baca `AGENTS.md`/`CLAUDE.md` terbaru di kedua repo. Pertahankan perubahan working tree milik tugas lain.
- Tulis seluruh kode Tahap 1–6 dahulu, termasuk harness dan dokumentasi. Penggabungan/integrasi, build, eksekusi migrasi, uji SQL/HTTP/klien/render, dan review dilakukan sekali di Tahap 7. Jangan menyelipkan pengujian atau analisa antar tahap penulisan.
- Utamakan perubahan di modul produk `src/modules/EmPoriumHouse.NuPak` dan host EmPorium House. Hook engine yang ada sudah cukup secara rancangan; ubah em-system hanya jika ada kebutuhan generik yang terbukti, bukan memasukkan model feed NuPak ke engine.
- Tetap satu instance API per store/database NuPak. Multi-feed tidak mencakup beberapa instance berbagi storage, mirror/proxy, symbols, kuota, atau pemindahan paket antar-feed.
- Root dan batas upload tetap parameter `AddNuPakModule(localStorePath, maxPackageMb)`; limit berlaku sama pada semua feed. Jangan menambah path bebas dari UI.
- Feed baru awalnya nonaktif dan anonymous read nonaktif. Tidak ada feed yang dibuat oleh installer, migrasi, startup, atau toggle server. Slug lowercase ASCII, 1–64 karakter, huruf/angka dengan tanda hubung internal; tolak nama `v2`, `v3`, serta nama jalur internal yang dicadangkan. Nama tampilan/deskripsi boleh berubah. Jika pengguna sendiri membuat slug `default`, perlakukan sebagai feed biasa tanpa alias atau perlindungan khusus.
- Toggle server utama tetap `ta_Meta.NuPakEnable`. Efektif aktif = server aktif **dan** feed aktif. Server off tidak mengubah toggle masing-masing feed dan tidak menghapus data; seluruh protokol menjawab 404, manajemen tetap tersedia.
- Klaim M = Manager Access; S = Settings Manage. Baca/list/statistik/feed audit memakai M; create/update/delete feed, pengaturan feed/server, purge dan empty bin memakai S. Pengelolaan prefix/recycle/restore tetap M seperti perilaku lama.
- Jika tindakan ditolak policy, catat tindakan/alasan, jangan coba jalan lain. Siapkan `.ps1` yang dapat ditinjau dan dijalankan manual dalam `plan/nuget-multifeed-manual/`, beserta prasyarat, parameter, dampak, dan urutan eksekusi; lanjutkan pekerjaan independen. Jangan mengklaim verifikasi tertunda lulus.
- Tidak mengunggah ke nuget.org, menghapus data pengguna untuk pengujian, atau membuat commit otomatis dalam task ini.

## Titik perubahan dari implementasi saat ini

- `NuPakDbContext`: unique prefix/name paket masih global.
- `NuPakSettings`/`NuPakServices`: enable dan anonymous read masih satu pasangan global di `ta_Meta`.
- `NuPakEndpoint`: lookup dan URL resource masih di bawah `/nuget` tanpa konteks feed.
- `NuPakOperations`: pencocokan longest prefix dan lookup paket masih global.
- `NuPakStore`: path `{root}/packages/{id}/{version}/...`, gate mutasi tunggal, recovery purge berdasarkan id+versi saja.
- `NuPakRobotAccessManager`: resource robot ditampilkan sebagai nama prefix saja.
- `INuPakServices`, DTO, NuGet Manager, dan Home: status/filter statistik masih satu feed.
- Harness yang dipakai ulang: `../.artefacts/EmPorium/scripts/nuget-smoke`, `../.artefacts/EmPorium/scripts/nuget-host-smoke/nuget-host-smoke.ps1`, `../.artefacts/EmPorium/scripts/module-card-qa-render`.

## Tahap 1 — Skema dan migrasi

- Tambah `ta_NuPakFeed` dan `vi_NuPakFeed`: ULID `cNuPakFeedId char(26)` PK; slug unik case-insensitive `varchar(64)`; nama tampilan `varchar(100)`; deskripsi `varchar(500) NULL`; enabled/anonymous `bit`; kolom standar `ustamp`, `datestamp`, `json_object`. Nama kolom mengikuti konvensi tabel NuPak. Tidak ada kolom default/legacy storage atau seed feed.
- Tambah FK feed non-null pada Prefix dan Package. UNIQUE prefix = `(feedId, prefixName)`; UNIQUE package = `(feedId, packageName)`. UNIQUE versi tetap `(packageId, normalizedVersion)`.
- Cegah paket menunjuk prefix milik feed lain dengan FK komposit `(feedId, prefixId)` ke key komposit Prefix. Grant tetap menunjuk prefix ULID yang unik global; tidak perlu mengganti primary key atau resource ID robot.
- Audit mempunyai feed ID nullable untuk peristiwa server global, serta snapshot slug/nama untuk menjaga sejarah setelah feed kosong dihapus. Gunakan FK tanpa cascade; saat penghapusan feed, lepaskan relasi audit secara transaksional tanpa menghapus audit. Jika hanya ada audit lama tanpa paket/prefix/grant, pertahankan sebagai histori single-feed sebelum migrasi dengan feed ID null dan keterangan legacy yang jelas; jangan membuat feed untuk menampungnya. Audit feed terhapus tetap dapat dilihat dari tampilan audit seluruh server.
- Tambah indeks query per feed dan per state/waktu yang sesuai; perbarui view, model EF, panjang varchar, collation, dan relasi.
- Perbarui `doc/sqlscript/mssql/sets/NuPak.sql` untuk instalasi baru dan buat `doc/sqlscript/mssql/updates/20261003-NuPakMultiFeed.sql` untuk instalasi lama. Keduanya idempotent dan menghasilkan skema akhir yang sama. Instalasi lama harus menjalankan update sebelum set terbaru; jangan hanya mengandalkan `IF TABLE IS NULL`.
- Migrasi transaksional dari skema single-feed kosong: preflight memastikan Prefix, Package, Version dan PrefixRobot kosong sebelum perubahan skema. Bila tidak kosong, gagal dengan pesan jelas sebelum mutasi, tanpa reset atau backfill otomatis. Tambah kolom feed wajib dan ganti unique/FK pada tabel kosong; pertahankan audit dan pengaturan server. Run ulang pada skema multi-feed yang sudah terpasang harus aman meskipun kini berisi data; preflight kosong hanya berlaku pada transisi dari skema single-feed.
- Server toggle mempertahankan nilai lama `NuPakEnable`; instalasi baru server off dan nol feed. Key `NuPakAnonymousRead` lama tidak lagi menjadi sumber runtime dan tidak diwariskan ke feed baru; dokumentasikan status legacy-nya tanpa menghapus metadata inti lain.
- Simpan marker versi migrasi sehingga startup baru menolak skema lama/incomplete dengan petunjuk update yang jelas. Startup multi-feed dengan nol feed harus berhasil.

## Tahap 2 — Model, kontrak, dan layanan manajemen

- Tambah model Feed, DTO ringkasan server dan status/storage per feed, serta create/update DTO. DTO membawa feed ID, slug, alamat index, toggle tersimpan, dan status efektif.
- `GetMeta_NuPakStatus` menjadi ringkasan server; toggle server tetap pada action global. Tambah list/detail/create/update/delete feed dengan pola nama `GetMeta_`, `PostGetMeta_`, `PostMeta_` dan atribut action yang dipakai engine.
- Buat konteks feed eksplisit pada semua action prefix, packages, versions, recycle bin, purge/empty, audit dan storage. Jika menerima feed ID bersama prefix/package/version ID, validasi relasi di server dan tolak ID feed lain (404); jangan percaya filter UI.
- Tidak ada parameter feed kosong yang berarti seluruh feed pada operasi mutasi. Empty bin wajib feed tertentu; audit global dan statistik global hanya action baca terpisah yang jelas.
- Update Models.Ui dan seluruh pemanggil secara serentak. Semua operasi feed memerlukan konteks eksplisit, tanpa wrapper yang diam-diam memilih feed pertama atau feed bernama tertentu.
- Feed delete: pakai gate/transaction yang sama dengan mutasi paket. Tolak feed berisi paket/versi aktif/recycle (409). Feed kosong boleh mempunyai prefix kosong: hapus prefix dan grant-nya secara transaksional, simpan audit, hapus metadata feed. UI konfirmasi menyebut prefix/grant yang ikut dihapus. Feed terakhir boleh dihapus sehingga sistem kembali mempunyai nol feed. Tidak ada cascade yang menghapus paket/file.
- Cache pengaturan server dan feed terpisah berdasarkan immutable feed ID; invalidasi sesudah commit dan cegah slow read mengisi ulang nilai usang. Perubahan aktif/anon segera berlaku pada request baru; pembacaan status UI berasal dari server.

## Tahap 3 — Storage dan operasi paket

- Semua feed memakai layout yang sama: `{root}/feeds/{feedId}/packages/{id-lower}/{version-lower}/{id-lower}.{version-lower}.nupkg`. Path memakai ULID tervalidasi dari metadata feed, bukan slug/nama dari request. Temp dapat tetap global karena nama ULID unik; berkas recovery harus dapat dihubungkan secara pasti ke feed.
- Tidak menggunakan layout single-feed lama `{root}/packages/...`. Preflight runbook memeriksa apakah ada artefak lama, termasuk recovery `.purge`; bila ditemukan, laporkan dan hentikan perpindahan versi sebelum mengubah DB/disk. Jangan menghapus, mengadopsi, atau memindahkan file tersebut otomatis. Folder kosong lama boleh dibiarkan.
- Semua API pembentukan path dan recovery menerima konteks feed; lookup SQL recovery juga memakai feed ID. Recovery satu feed tidak boleh memulihkan/menghapus artefak identik di feed lain.
- Pertahankan proteksi traversal, junction/symlink, Windows reserved name, streaming limit, validasi nuspec, hash, rollback push gagal, `.purge` recovery, dan penolakan overwrite orphan. Cleanup folder berhenti pada batas feed/root yang ditentukan.
- Pertahankan gate mutasi tunggal untuk semua feed pada tahap ini; cakup push/recycle/restore/purge/empty/delete feed dan perubahan prefix yang berpotensi race. Jangan membuat gate per feed tanpa mekanisme koordinasi delete.
- Push mencari paket dan longest matching active prefix hanya dalam feed request. Prefix baru tetap tidak memindahkan paket yang sudah mempunyai owner. Recycle/restore/reservasi id+versi, duplicate 409, ukuran, dan statistik selalu per feed.
- Startup validasi skema sebelum cleanup/recovery. Jangan otomatis memigrasikan database pada startup. Hapus folder feed kosong hanya sesudah transaksi delete berhasil, dengan path absolut tervalidasi; kegagalan cleanup dilaporkan, tidak menghapus data lain.

## Tahap 4 — Routing dan autentikasi protokol

- Tetap satu `AddPublicEndpoint("/nuget", ...)`; parsing hanya menerima `/nuget/{slug}/v2|v3/...` dan melakukan feed lookup eksplisit. Validasi slug/segment encoding; slug tidak dikenal dan jalur single-feed lama menjawab 404 tanpa fallback.
- Resolve feed dahulu; server/feed off atau slug tidak ada => 404 polos. Kredensial salah tetap 401 walaupun feed anonymous. Baca anonymous hanya pada feed tersebut; tulis selalu robot dengan W pada prefix dalam feed.
- Service index, search `@id`, registration index/leaf, packageContent, publish/delete, flatcontainer/nuspec, download/Range/HEAD semuanya membangun URL dari base feed request yang sama, scheme/host/PathBase yang benar. Semua URL resource harus membawa slug feed tersebut.
- Scope query paling awal pada feed, kemudian izin prefix. Search/totalHits/pagination/semver/prerelease tidak boleh membocorkan feed lain. Robot R pada feed A tidak memperoleh akses feed B meskipun prefix/name paket sama.
- Header autentikasi, Basic dan X-NuGet-ApiKey, kode error, cancellation, dan streaming mempertahankan perilaku NuGet yang sudah teruji. Jalur lama tidak menjalankan operasi baca/tulis apa pun.

## Tahap 5 — NuGet Manager, Home, dan hak robot WPF

- NuGet Manager menambahkan daftar/pemilih feed yang selalu terlihat, create/edit/delete feed sesuai claim, alamat canonical feed dengan tombol copy kecil tepat di kanan URL, serta pengaturan enabled/anonymous per feed dan kontrol server utama terpisah.
- Semua tab Packages, Prefixes, Recycle Bin, Audit dan card storage mengikuti feed terpilih. Audit menyediakan tampilan seluruh server untuk peristiwa global/feed terhapus. Detail feed tidak ditampilkan sebelum metadata berhasil diterima.
- Kondisi nol feed: tampilkan petunjuk membuat feed dan tombol Create sesuai claim; statistik global nol dan toggle server tetap tersedia. Nonaktifkan operasi yang membutuhkan feed terpilih, jangan mengarang alamat index atau membuat feed otomatis. Setelah feed terakhir dihapus, bersihkan selection/detail dan kembali ke kondisi ini.
- Saat mengganti feed: kosongkan selection dan paging/filter terkait; batalkan/abaikan hasil request lama dengan identitas feed/request. Tombol mutasi menangkap feed+object yang dikonfirmasi dan tidak mengeksekusi pada selection baru. Empty bin menyebut nama feed dan jumlah/ukuran, termasuk semua prefix feed itu.
- Resource `NuPakRobotAccessManager` tetap `ManagerId = "NuGet"`, ResourceId = prefix ULID; label `Feed / Prefix`, urut feed lalu prefix. Tab Prefixes tetap baca hak dan menuju User Manager. Saat nol feed/prefix, resource kosong tanpa entri bawaan.
- Home menampilkan total feeds, feeds aktif efektif, paket/versi/storage seluruh feed; toggle pojok kanan atas tetap **server utama**, di kanan refresh. Jangan menampilkan satu URL sebagai alamat semua feed; tombol Open menuju manager/pemilih feed.
- Ikuti aturan kedua CLAUDE.md: setiap card dinamis punya refresh independen, copy dekat URL, toggle mengikuti nilai server, cegah request ganda, tooltip/accessibility, tema enabled/disabled/loading/hover/focus. Gunakan style ListBox/TreeView bertema engine bila relevan.

## Tahap 6 — Dokumentasi dan harness

- Update `doc/nuget-server.md` (bahasa Inggris): multi-feed tanpa feed bawaan, konsep feed vs prefix, kewajiban slug pada URL, create feed pertama, grant robot, config dua source NuGet, package source mapping, toggle global/per feed, delete kosong/terakhir, layout storage dan batas satu instance. URL single-feed lama tidak lagi didukung.
- Buat runbook untuk **instalasi saat ini yang kosong**: hentikan API lama, periksa tabel prefix/paket/versi/grant dan file paket/recovery lama kosong, lindungi database inti bersama sebelum perubahan skema, jalankan update SQL, deploy backend/WPF serentak, verifikasi nol feed/pengaturan/404 URL lama, lalu buat feed secara eksplisit jika diperlukan. Bila preflight menemukan data lama, hentikan update dan laporkan tanpa tindakan destruktif; migrasi populated memerlukan rancangan tujuan feed terpisah. Rollback setelah ada data feed baru wajib restore pasangan backup DB+store; jangan menjalankan binary lama terhadap skema baru.
- Tambah catatan CLAUDE.md tanpa menimpa sejarah: setelah implementasi jelaskan bahwa batas single-feed pada catatan lama sudah digantikan, link panduan/plan/laporan dan verifikasi tertunda.
- Perluas harness existing dengan fixture nol feed dan dua feed (A/B), prefix dan ID+versi sama tetapi hash berbeda, robot A-only/B-only/R/W, anonymous feed berbeda, versi recycle, serta skema single-feed kosong dan fixture populated untuk membuktikan preflight menolak update tanpa perubahan. Semua harness menerima konfigurasi tanpa mencetak password/token atau mengomit secret.
- Tulis `doc/report/nuget-multifeed-eksekusi.md` saat eksekusi: perubahan, hasil nyata, penyimpangan teknis, dan pemeriksaan tertunda.

## Tahap 7 — Integrasi, pengujian, dan review akhir

Lakukan setelah seluruh kode Tahap 1–6 ditulis. Gunakan database/store sementara untuk uji destruktif. Database lokal pengguna dikonfirmasi kosong dari data NuGet; validasi ulang sebelum pembaruan dan jangan reset database inti yang dipakai bersama engine. Uji penolakan update pada data lama menggunakan fixture terisolasi, bukan mengisi database pengguna dengan artefak uji.

- Build backend dan WPF EmPorium House; build engine terdampak jika diubah. Pastikan warning/error perubahan ini diselesaikan.
- SQL: instalasi baru dan update skema single-feed kosong menghasilkan nol feed; populated legacy ditolak sebelum mutasi; histori audit lama tetap tersedia; run ulang pada multi-feed populated aman; kegagalan/rollback, unique per feed, FK cross-feed, setting server sebelum/sesudah, marker startup. Menjalankan set terbaru setelah update tidak mereset data atau membuat feed.
- HTTP: setiap endpoint pada A/B; URL absolut dan PathBase/reverse proxy; slug unknown/reserved/traversal; header salah dan anonymous; server off/per-feed off; cache invalidation. URL lama tetap 404 pada GET/HEAD/PUT/DELETE meskipun ada feed yang dibuat pengguna dengan slug `default`. Buktikan isolasi flatcontainer, nuspec, registration, search dan totalHits.
- Klien NuGet nyata: push dan restore paket id+versi sama dengan isi berbeda dari source tunggal A lalu B menggunakan cache/packages folder terpisah; search/delete/restore. Catat bahwa cache NuGet lokal berdasarkan ID+versi dapat mengaburkan hasil bila shared; jangan memakai cache yang sama untuk membuktikan isolasi.
- Layanan/izin: cross-feed ID injection pada seluruh action; robot A-only tidak membaca/menulis B; R tidak menulis; W sesuai prefix; robot deletion mempertahankan audit/pushed-by semantics; claim M/S; create/delete feed kosong/nonkosong/terakhir dan feed biasa bernama `default`; stale UI selection.
- Race/kegagalan: push bersamaan dalam feed dan lintas feed, prefix update/delete, feed delete vs push, duplicate recycle reservation, SQL commit gagal, disk gagal, orphan dan purge recovery A/B. Tidak ada operasi di A mengubah file/baris B.
- Render WPF terang/gelap: nol feed, banyak feed, feed kosong, penghapusan feed terakhir, URL panjang, load cepat/lambat, disabled/busy/error/no claim, pergantian feed saat loading; semua tab, Home, robot resource label, copy dan toggle. Render harness tidak menggantikan interaksi mouse; laporkan keduanya terpisah.
- Review sekali menyeluruh: telusuri setiap query/lookup/path/resource URL/audit/gate dan seluruh pemanggil action untuk memastikan feed context tidak hilang. Tinjau perubahan skema dan runbook serta log secret.
- Jika reverse proxy HTTPS/IDE/interaksi nyata atau tindakan policy belum teruji, sebutkan sebagai tertunda dengan langkah manual konkret. Jangan menyatakan seluruh pengujian lulus berdasarkan build saja.

## Kriteria selesai

- Dua feed dengan ID+versi sama dapat beroperasi independen, termasuk hash file, hak robot, search, recycle/purge, audit dan toggle anonymous.
- Instalasi/update kosong, startup, dan toggle server tidak membuat feed. Semua feed dibuat pengguna, mengikuti aturan yang sama, dan feed terakhir boleh dihapus. Tidak ada fallback/alias URL single-feed lama atau layout storage khusus.
- Pengaturan server utama dan pengaturan feed tidak saling menimpa; manager tetap tersedia saat server/feed off.
- UI dan layanan selalu menyebut/memvalidasi feed yang benar; delete feed tidak menghapus paket ataupun audit historis.
- Migrasi/runbook dan pengujian menghasilkan bukti yang dicatat, beserta keterbatasan nyata.
- Setelah eksekusi selesai, pindahkan plan ini ke `plan/executed/`; status harus membedakan implementasi selesai dari verifikasi manual yang masih tertunda.

## Hasil eksekusi 2026-10-03

Kode skema/backend/protokol/storage/WPF/Home/robot dan harness selesai. Build
backend/WPF 0 warning/error; 162 pemeriksaan SQL/HTTP/klien NuGet terisolasi lulus,
termasuk migrasi rollback, isolasi A/B, cross-feed injection, race delete vs push,
URL lama 404, serta penghapusan feed terakhir. Render terang/gelap dan respons
metadata feed usang diuji. Engine source tidak diubah.

Database lokal di-preflight kosong, backup database inti COPY_ONLY/CHECKSUM dan
snapshot store dibuat, update serta set dijalankan. Marker 2 dan nol feed
terverifikasi; NuPakEnable=True lama dipertahankan. Host API nyata startup dan
12 pemeriksaan URL legacy/unknown feed lulus.

Laporan lengkap, backup, batas verifikasi dan instruksi manual:
`doc/report/nuget-multifeed-eksekusi.md`. Runbook:
`doc/nuget-multifeed-upgrade.md`.

Pembaruan `doc/nuget-server.md` ditolak review otomatis dengan **blocked by policy**.
Tidak dicoba ulang; jalankan sendiri skrip berikut dari `<EmPorium>`:

```powershell
& '<EmPorium>\plan\nuget-multifeed-manual\update-guide.ps1' -RepoPath '<EmPorium>'
```

Interaksi mouse/keyboard/clipboard host live, HTTPS reverse proxy, IDE, ACL/symlink
nyata dan claim dispatcher user M/S tetap belum dinyatakan lulus. Tidak ada commit
otomatis, reset database pengguna atau unggah nuget.org.
