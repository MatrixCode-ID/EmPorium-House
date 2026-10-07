# Workspace dan workflow EmPorium House

- Tanggal: 2026-10-07
- Pelaksana: Codex
- Dasar: permintaan langsung pengguna untuk menyiapkan repo, workflow, dan wrapper setup clone pertama.
- Ide: [rilis otomatis](../../doc/ideas/rilis-otomatis-setelah-nuget-engine.md).

## Keputusan

- Repo privat `MatrixCode-ID/EmPorium-House-work`, branch `work-bench`, remote `private`.
- Repo publik `MatrixCode-ID/EmPorium-House`, branch `main`, remote `origin`.
- Folder lokal tetap `EmPorium`; setup clone pertama lewat `scripts/setup-workspace.cmd`.
- Rilis produk dipicu release note versi produk baru, seperti em-system.
- Dispatch engine memperbarui dan mencatat versi engine pada `main`, menaikkan nomor
  rilis produk independen, lalu membangun ZIP dan image GHCR dari commit yang sama.
- Channel otomatis tetap alpha, target 0.1.0 saat ini; konfigurasi eksplisit disediakan.
- `work-bench` mengambil perubahan `main` melalui fetch/merge, mempertahankan pekerjaan pengguna.
- Tahap ini menyiapkan sisi EmPorium House; pemicu dan token lintas repo di em-system belum diubah.
- Tidak membuat release note versi baru pada main atau menerbitkan produk dalam tugas persiapan ini.

## Pekerjaan

1. Buat repo privat memakai gh dan isi work-bench dengan riwayat Git produk yang sama.
2. Siapkan wrapper CMD CRLF dan setup PowerShell yang memvalidasi remote serta mempertahankan perubahan lokal.
3. Tulis workflow CI dan rilis, skrip noninteraktif, dokumentasi, serta aturan CLAUDE.md.
4. Setelah seluruh kode selesai, validasi YAML/PowerShell, skenario Git clone pertama,
   resolusi versi/idempotensi, publish ZIP lokal dan build container bila daemon tersedia.
5. Commit/push persiapan ke repo privat, atur default branch/tracking, pasang workflow
   pada main publik tanpa release note versi baru, lalu laporkan verifikasi serta
   pemicu em-system dan akses GHCR yang masih diperlukan.

## Hasil eksekusi

- Repo privat dibuat lewat gh, diisi riwayat produk, default branch `work-bench`.
- Remote lokal `private`/`origin` dan tracking/push destination sudah dikonfigurasi.
  Branch aktif kembali `work-bench`. GitHub CLI lokal diarahkan ke repo kerja privat;
  perintah workflow/publish menyebut repo publik secara eksplisit.
- Wrapper setup CRLF memakai PowerShell 7; mendukung clone privat/publik, HTTPS/SSH,
  standalone clone, pengulangan, dan menjaga checkout yang punya perubahan lokal.
  Remote dan push URL yang tidak sesuai ditolak sebelum konfigurasi diubah.
- Workflow CI dan release tersedia di `main` publik dan `work-bench` privat.
  Commit implementasi: `7cb5ba6`. Tidak ada release note versi produk baru dalam commit ini.
- Release versi produk independen, konfigurasi otomatis alpha/0.1.0, pemilihan
  nomor memakai riwayat note/tag Git/GHCR. Upgrade engine menunggu NuGet, commit ke
  main, dan build WPF serta Docker memakai satu SHA. Trigger duplikat/tua tidak
  menaikkan nomor. Versi tetap dengan revision berbeda tidak ditimpa; draft rilis
  dapat diteruskan dan alias channel dipromosikan setelah publikasi GitHub Release.
- `README.md`, `CLAUDE.md`, panduan workspace dan format release note diperbarui.

## Verifikasi

- Parser PowerShell dan actionlint 1.7.12: lulus.
- 25 pemeriksaan aturan rilis yang dirawat dan dijalankan CI: lulus.
- 21 pemeriksaan workspace dengan repo Git lokal: lulus (clone privat/publik,
  HTTPS/SSH, standalone, pengulangan, perubahan belum di-commit, remote yang salah,
  push URL yang salah, dua remote awal sama-sama privat).
- 18 pemeriksaan Prepare dengan Git sungguhan dan layanan remote tiruan: lulus.
  Engine alpha.8 menghasilkan produk alpha.5, main dan SHA konsisten; event duplikat
  serta lebih tua aman, paket belum tersedia tidak mengubah main, rilis selanjutnya
  memakai alpha.6. Tidak ada push ke repo produksi dalam harness.
- 13 pemeriksaan Publish dengan Docker/GitHub/GHCR tiruan: lulus. Draft dan ZIP
  disiapkan, alpha tidak mengubah latest, collision tidak menimpa versi tetap,
  pemulihan memakai image yang sudah dipublikasikan dan tidak membuat rilis kedua.
- Build API lokal Release: lulus, 0 warning/error. Build/publish WPF self-contained
  win-x64: lulus; ZIP berisi satu EmPoriumHouse.exe, integritas arsip lulus.
- Setelah pengguna menyalakan Docker, build image, ekspor tar melalui buildx,
  load tar, dan pemeriksaan runtime .NET/UID 1654/TZ Asia/Jakarta: lulus.
- Pembacaan manifest/config image alpha GHCR yang sudah ada, termasuk response
  byte[] OCI, dan respons tag yang tidak ada: lulus. Tidak ada push GHCR baru.
- Clone sungguhan dari repo privat ke folder verifikasi di luar repo lalu setup:
  lulus. Wrapper CMD diuji interaktif dan berhenti pada pause di akhir, baik jalur
  sukses maupun saat PowerShell 7 tidak ditemukan (exit 1 setelah pengguna menekan tombol).
- [CI repo privat](https://github.com/MatrixCode-ID/EmPorium-House-work/actions/runs/37641577766):
  lulus (aturan rilis, API Linux, WPF Windows, container).
- [CI repo publik](https://github.com/MatrixCode-ID/EmPorium-House/actions/runs/37641685411):
  lulus untuk empat job yang sama.
- [Workflow release persiapan](https://github.com/MatrixCode-ID/EmPorium-House/actions/runs/37641685328):
  prepare lulus, build/publish di-skip karena tidak ada note versi baru. Tidak membuat
  versi/tag/GitHub Release/image publik baru.

Harness dan artefak lokal ada di `../.artefacts/EmPorium/scripts/workspace-ci-release-smoke/`:
`test-workspace.ps1`, `test-prepare.ps1`, `test-publish.ps1`, `verify-live.ps1`,
clone uji, ZIP, image tar, serta actionlint. Tidak dimasukkan ke repo.

## Batas dan pekerjaan terpisah

- Trigger di `publish-nuget.yml` em-system beserta token lintas repo belum dipasang;
  itu di luar permintaan persiapan sisi EmPorium House ini.
- Dispatch engine produksi, push GHCR dengan token workflow, dan publikasi GitHub
  Release sungguhan belum dijalankan agar tugas persiapan tidak merilis versi baru.
  Paket GHCR harus memberikan Actions access ke repo publik sebelum rilis pertama.
- Sinkronisasi `main` ke `work-bench` dilakukan lewat fetch/merge sesuai panduan;
  tidak ada bot yang menimpa branch kerja secara otomatis.
