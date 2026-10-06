# Eksekusi NuGet multi-feed

Tanggal: 2026-10-03. Status: implementasi kode, migrasi lokal, dan pengujian otomatis selesai; pembaruan panduan developer dan verifikasi interaksi nyata tertunda manual.

Plan: `plan/executed/nuget-multifeed.codex.md`.

Perubahan: tabel/view feed tanpa seed, FK dan unique per feed, audit bersnapshot,
marker skema 2, update transaksional legacy kosong, kontrak layanan dengan ID feed
eksplisit, URL slug wajib, storage ULID feed, WPF pemilih/editor feed, ringkasan
Home dan label resource robot Feed / Prefix.

Pengaturan feed dibaca langsung dari database untuk setiap request, tanpa cache
per feed. Ini menghindari isi cache usang sesudah commit. Toggle server tetap
tersimpan pada NuPakEnable; NuPakAnonymousRead lama hanya metadata legacy.

Semua perubahan kode, dokumentasi dan harness ditulis sebelum build/uji/review.
Hasil nyata:

- Build backend dan WPF EmPorium House lulus, 0 warning/error. Engine ikut
  dibangun lewat ProjectReference, tanpa perubahan source engine. Build awal yang
  dijalankan bersamaan berbenturan pada output engine; rebuild dilakukan berurutan.
- 162 pemeriksaan di database SQL Server/store sementara lulus. Meliputi upgrade
  legacy populated ditolak tanpa perubahan, rollback marker gagal, audit legacy,
  fresh/update column schema identik, nol feed, marker startup sebelum cleanup,
  legacy recovery artifact ditolak, claim M/S pada semua action, FK komposit,
  longest prefix, reservasi recycle/duplicate, SQL/disk failure, robot deletion,
  dua feed dengan ID/versi sama dan hash/path berbeda, injeksi ID lintas feed,
  anonymous/auth salah, toggle global/feed, URL lama GET/HEAD/PUT/DELETE 404,
  slug invalid/unknown, PathBase, registration/search/nuspec/download/Range/HEAD,
  gzip, push bersamaan, feed delete vs push, recovery purge B menjaga A,
  delete biasa bernama default, delete terakhir dan histori audit.
- Klien dotnet NuGet nyata: push/search/delete paket engine, restore privat dengan
  source mapping/Basic, serta push/restore ID+versi sama dari A/B dengan cache
  terpisah; SHA-512 hasil download cocok dengan artefak masing-masing feed.
- Harness WPF lulus pada tema terang/gelap: Home, semua tab manager, off/busy/error,
  tanpa hak Settings, duplicate refresh guard, nol feed, detail disembunyikan
  sebelum metadata, respons A lambat tidak menimpa pilihan B. PNG tersedia di
  `scripts/module-card-qa/bin/Debug/net10.0-windows/`. Render ready/zero/loading
  juga diperiksa secara visual. Panel operasi feed dinonaktifkan saat nol feed.
- Host API nyata startup lulus, termasuk 12 kombinasi method/jalur legacy dan
  unknown feed yang semuanya 404. Harness menghentikan hanya proses yang dibuatnya.

Migrasi database lokal:

- Tidak ditemukan proses API EmPorium House lama/listener 5232 atau 7260 saat
  preflight. Prefix/package/version/grant legacy dan store paket/recovery kosong.
- Backup penuh database inti memakai COPY_ONLY + CHECKSUM, RESTORE VERIFYONLY
  lulus. Backup: `C:\Program Files\Microsoft SQL Server\MSSQL17.MSSQLSERVER\MSSQL\Backup\NuPakMultiFeed_20261003_110309.bak`.
- Snapshot store dan manifest pasangan: `%LOCALAPPDATA%\EmPoriumHouse\backups\NuPakMultiFeed_20261003_110309`.
  File backup tidak dimasukkan ke Git.
- Update `20261003-NuPakMultiFeed.sql`, lalu set terbaru berhasil. Verifikasi lokal:
  marker 2, nol feed/prefix/package/version/grant. Nilai server lama
  **NuPakEnable=True** dipertahankan; tidak ada feed atau robot permanen dibuat.
- Tidak ada reset/drop tabel atau data pengguna. DROP dan fixture failure hanya
  terjadi pada database sementara `EmNuPakSmoke_*`, yang dibersihkan setelah uji.

Review menyeluruh:

Query/lookup mutasi memvalidasi ID feed dan relasi objek; query protokol dibatasi
feed sebelum izin prefix. Seluruh URL resource membawa slug yang sama. Path dan
recovery memakai ULID feed tervalidasi, traversal/reparse-point dicegah. Gate
tunggal mencakup push/recycle/restore/purge/seluruh empty-bin, prefix/feed mutations
dan toggle server. Delete menolak paket/recycle dan artefak orphan, melepas relasi
audit secara transaksional, lalu membersihkan hanya folder feed kosong sesudah
commit. Feed metadata dibaca langsung sehingga tidak ada cache per-feed usang.
UI memakai generation untuk menolak respons lama dan menangkap ID feed/objek
sebelum konfirmasi mutasi. Server settings terpisah dari feed settings.

Penyimpangan teknis:

- Cache per-feed tidak diperlukan: pembacaan langsung committed metadata dipilih
  agar perubahan langsung berlaku tanpa masalah cache stale. Ada biaya query
  per request, sesuai batas satu instance tahap ini.
- Delete juga menolak file orphan dalam folder feed, walaupun metadata SQL kosong,
  agar tidak menghapus/adopsi file tanpa rekonsiliasi administrator.
- Update SQL tidak membuat feed dan tidak memigrasikan isi single-feed legacy.
- Panduan `doc/nuget-server.md` belum berubah karena policy; runbook baru sudah
  tersedia. Skrip manual di bawah menyelesaikan pembaruan panduan.

Tindakan manual akibat policy (urutan 1):

- Tindakan: memperbarui `doc/nuget-server.md` lewat perintah PowerShell yang
  menjalankan editor Python. Review otomatis menolak perintah tersebut dengan
  alasan **blocked by policy**; tidak memberikan alasan yang lebih rinci.
- Tidak dicoba ulang melalui shell/wrapper/cara lain. Skrip siap tinjau:
  `plan/nuget-multifeed-manual/update-guide.ps1`.
- Direktori kerja: `<EmPorium>`. Jalankan sendiri:

  ```powershell
  & '<EmPorium>\plan\nuget-multifeed-manual\update-guide.ps1' -RepoPath '<EmPorium>'
  ```

- Periksa bagian Multi-feed operation, URL sumber A/B, source mapping, langkah
  membuat feed pertama, grant robot, toggle, delete terakhir, storage dan runbook.
  Skrip tidak dijalankan agent; hasilnya belum dinyatakan lulus.

Verifikasi tertunda (bukan hasil otomatis):

- Interaksi mouse/keyboard dan clipboard pada host WPF dengan server sungguhan:
  buat dua feed, atur prefix/grant, copy URL, toggle, ganti feed saat loading,
  recycle/restore/purge, hapus feed terakhir; ulang tema terang/gelap. Jangan
  memakai database pengguna untuk uji destruktif; gunakan lingkungan sementara.
- HTTPS reverse proxy dan IDE: pasang source canonical pada dua feed, periksa
  scheme/host/PathBase pada semua resource dan restore dengan cache terpisah.
  Harness membuktikan PathBase HTTP lokal, bukan reverse proxy HTTPS nyata.
- ACL read-only, junction/symlink nyata, cancellation saat streaming, serta
  kombinasi race prefix edit/delete vs push belum dieksekusi satu per satu.
  Proteksi dan gate ditelusuri lewat review; tidak diklaim sebagai uji OS nyata.
- Claim M/S diuji sebagai batas atribut kontrak dan rendering izin UI, bukan
  login user M-only/S-only lewat dispatcher host sungguhan.
- Paket/recovery single-feed populated sengaja tidak diadopsi. Jika ada data lama
  pada lingkungan lain, hentikan deployment dan tentukan feed tujuan terpisah.

Perintah verifikasi ulang:

```powershell
dotnet build src/backend/EmPoriumHouse.Api.slnx
dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx
dotnet run --project scripts/nuget-smoke -- <EmPorium>
dotnet run --project scripts/module-card-qa
pwsh -File scripts/nuget-host-smoke.ps1
```

Harness membaca konfigurasi lokal atau environment connection string tanpa
mencetak password/token. Tidak ada upload nuget.org atau commit otomatis.
