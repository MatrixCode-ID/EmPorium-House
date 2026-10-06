# Timezone container EmPorium House API

Tanggal: 2026-10-03

Permintaan: periksa Docker build API, tambahkan konfigurasi timezone di Compose dan bantuan Compose.

- Tambahkan ARG/ENV TZ pada Dockerfile dengan default UTC untuk build langsung; pertahankan tzdata di runtime.
- Compose meneruskan TZ untuk build dan runtime, default Asia/Jakarta; tambahkan contoh konfigurasi dan bantuan update/verifikasi.
- Validasi Compose, build image, dan uji timezone default/override sebagai user non-root; catat hasil lalu arsipkan plan.

## Hasil

- Dockerfile menerima `ARG TZ=UTC`, meneruskannya sebagai `ENV TZ` ke build/final; paket `tzdata` tetap disertakan.
- Compose memakai `${TZ:-Asia/Jakarta}` untuk build argument dan runtime; `.env.example` memuat `TZ=Asia/Jakarta`.
- README backend memuat setup timezone, build langsung dengan named context engine, runtime override, recreate, diagnosis `date`, dan perintah bantuan Compose.
- Lulus: validasi Compose dengan `.env.example` dan konfigurasi lokal (hanya nilai TZ yang dicetak), build image Release `emporium-server:local`, dan pemeriksaan whitespace `git diff --check`.
- Container sementara berjalan sebagai UID/GID 1654: default `Asia/Jakarta` menghasilkan WIB +0700; override UTC +0000, Asia/Makassar WITA +0800, Asia/Jayapura WIT +0900. Container uji otomatis dihapus (`--rm`).
- Service aktif tidak dibuat ulang; masih memakai image/environment lama (UTC). Terapkan dari `src/backend` dengan `docker compose up -d --force-recreate emporium-server`, lalu cek `docker compose exec emporium-server date '+%Y-%m-%d %H:%M:%S %Z %z'`. Tidak ada uji startup API baru/database atau Run Rider pada pekerjaan ini.
