# Refresh card Modules

- Tambahkan tombol refresh pojok kanan atas pada card Container Registry dan CDN sesuai gambar.
- Refresh seluruh informasi hanya pada card yang diklik; guard request ganda, loading dan retry.
- Hubungkan total storage dari action engine yang sudah dibuat pada kedua card.
- Simpan aturan permanen: setiap card dengan informasi dinamis wajib mempunyai tombol refresh.
- Setelah kode selesai, build WPF dan verifikasi render terang/gelap serta kondisi busy bila memungkinkan.

## Hasil 2026-10-03

- Lokasi gambar adalah Home EmPorium House, bukan DefaultHomeControl engine. Card registry/CDN
  memakai tombol refresh bersama (pojok kanan atas), command per card, loading, finally reset,
  guard request ganda, serta retry setelah gagal. NuGet Coming soon tetap statis tanpa refresh.
- Refresh memuat ulang seluruh angka, status, alamat, dan storage card tersebut. Total storage memakai
  action engine yang sudah dibuat pada tugas sebelumnya; jika action storage gagal/tidak tersedia
  pada server lama, informasi modul yang berhasil dibaca tetap tampil dan storage diberi status unavailable.
- Aturan permanen card dinamis disimpan secara tambahan pada CLAUDE.md repo ini dan claude.md em-system.
- Build standar dan UseAppHost=false gagal menyalin output karena exe/dll dikunci aplikasi pengguna
  EmPoriumHouse.Ui.Wpf (PID 13944). Aplikasi tidak dihentikan. Ini file lock, bukan blokir policy.
- Build terisolasi lulus 0 warning/error:
  `dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx --artifacts-path <temp>/emporium-card-build -v minimal`.
- QA offline `dotnet run --project ../.artefacts/EmPorium/scripts/module-card-qa-render --artifacts-path <temp>/emporium-card-qa-build`
  lulus pada kedua tema: dua tombol terlihat, disabled/loading bertema, refresh registry/CDN independen,
  request ganda dicegah, angka/storage diperbarui, retry setelah kegagalan registry. QA dibangun ulang
  setelah penanganan kegagalan storage dipisahkan dari kegagalan modul.
- PNG ready/busy kedua tema tersimpan di `<temp>/emporium-card-qa-build/bin/ModuleCardQa/debug/`.
  `light-ready.png` dan `dark-busy.png` diperiksa visual; ikon terletak di pojok kanan atas dan tidak
  menutupi judul. Harness tidak membuka window atau menggunakan server/database nyata.
- Diff check untuk file task lulus. Diff global repo memiliki blank line EOF pada Program.cs backend
  yang sudah berubah sebelum task; tidak disentuh.
- Tertunda: uji klik dengan mouse dan HTTP server nyata. Untuk memakai output standar, tutup aplikasi
  yang mengunci file lalu jalankan dari <EmPorium>:
  `dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx` dan buka kembali aplikasi.
  Total storage memerlukan backend yang sudah memakai action engine terbaru.
