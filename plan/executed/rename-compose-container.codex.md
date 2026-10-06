# Rename Compose names shown in Docker Desktop

Tanggal: 2026-10-03

Permintaan lanjutan: nama project dan container di Docker Desktop harus emporium-server.

Ubah project/service/container serta konfigurasi IDE. Pakai volume lama secara eksplisit dan pertahankan hostname karena settings menggunakan identitas host. Recreate container tanpa rebuild, lalu verifikasi startup dan HTTP.

## Hasil

Selesai: project, service dan container `emporium-server`. Compose, dcproj, launchSettings, Rider shared Run dan README diperbarui. Container lama sudah dihapus tanpa menghapus volume; container baru berjalan dari `emporium-server:local`. Inspect memastikan volume lama dan hostname tetap. Compose config dan startup lulus. Volume lama dapat memunculkan warning label project saat up; data tetap menggunakan volume eksplisit yang sama.
