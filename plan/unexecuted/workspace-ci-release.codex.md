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
