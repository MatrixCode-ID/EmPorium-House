# Rename container image

Tanggal: 2026-10-03

Permintaan: ubah nama image container EmPorium House menjadi `emporium-server`.

- Ubah image Compose ke `emporium-server:local`.
- Tag ulang image lokal yang sudah dibangun tanpa rebuild.
- Verifikasi Compose dan identitas image, lalu hapus tag lama.
- Pertahankan service, hostname, volume, dan container berjalan.

## Hasil

Selesai: Compose dan README memakai `emporium-server:local`. Image lokal ditag ulang (ID `743457b7f3f0`); tag lama dihapus. `docker compose config --images` menghasilkan `emporium-server:local` dan inspect membuktikan ID image sama. Container yang sedang berjalan tidak direstart; referensi image pada container lama dapat tetap menampilkan nama lama hingga recreate berikutnya.
