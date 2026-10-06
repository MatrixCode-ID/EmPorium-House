# Build dan push image prealpha 1

Tanggal: 2026-10-03

Permintaan: build source kerja terbaru lalu push `ghcr.io/matrixcode-id/emporium-server:0.1.0-prealpha.1`.

- Gunakan Dockerfile host EmPorium House dan named build context `<em-system>`.
- Build Release untuk linux/amd64; perubahan source yang belum dikomit termasuk dalam build.
- Periksa metadata dan isi image agar konfigurasi lokal tidak masuk.
- Push tag yang diminta lalu verifikasi digest registry.
- Catat hasil dan pindahkan task ke plan/executed setelah selesai.

## Hasil

- Selesai: build Release linux/amd64 dan push GHCR berhasil (exit code 0).
- BuildKit menggunakan cache yang cocok dengan source kerja terkini.
- Image: `ghcr.io/matrixcode-id/emporium-server:0.1.0-prealpha.1`.
- Digest index: `sha256:6b6cebcbcc5b4b91f7826814e8d5541cd53decb87577769fafc1fafa01acecc9`.
- Digest manifest linux/amd64: `sha256:e2554677c50719e118647ff4ca6eb2ce0ef153b5b747cd2c7627ea294ede27da`.
- `docker buildx imagetools inspect` membaca tag dari GHCR dan mengonfirmasi digest index yang sama.
- Pemeriksaan image lulus: assembly host/NuPak tersedia, tidak ada *.local.json/.env/*.production.json di /app, UID/GID 1654, ASP.NET/Core runtime 10.0.10. Ukuran lokal 85.013.527 byte.
- Tidak menjalankan ulang integrasi database/HTTP pada task publikasi ini; container aplikasi yang sedang berjalan tidak diubah.
- Source produk HEAD d24ff1b0ab814fff358ddd2468bf03bf0af3df41 dan engine HEAD 845b76de757705417dc0fe03a8b52018d088b558, dengan perubahan kerja yang belum dikomit turut dibangun.
