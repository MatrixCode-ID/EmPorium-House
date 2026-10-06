# Rider masih menunjuk project Compose lama

Tanggal: 2026-10-03. Permintaan: log tetap tidak terlihat di Rider.

Temuan: API `emporium-server` berjalan dan stdout berisi startup. Workspace Rider memilih `compose.yml: Compose Deployment`, yang mengesampingkan project name menjadi `emporium-house-api` (nama sebelum rename), bukan profil shared terbaru. Perbaikan: selaraskan project name di profil shared dan konfigurasi lokal terpilih, serta pilih profil shared. Simpan backup workspace sebelum perubahan. Verifikasi log dari project Compose yang benar; UI tetap belum diverifikasi.

Hasil: profil shared punya composeProjectName eksplisit emporium-server. Konfigurasi lokal lama diperbaiki ke project baru, forceBuild=true dan upDetach=false; pilihan RunManager diarahkan ke shared profile. Backup `.idea/.idea.EmPoriumHouse.Api/.idea/workspace.xml.before-log-project-fix.bak` (diabaikan Git). `docker compose -p emporium-server logs --tail 6` menampilkan log startup API. XML tersimpan valid dan diff check lulus. Container milik pengguna tetap berjalan. Reopen solution diperlukan agar workspace baru terbaca; UI/log tab belum diverifikasi. Salah project adalah temuan konkret, tetapi belum membuktikan seluruh penyebab log tidak terlihat di UI.
