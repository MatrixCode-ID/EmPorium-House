# Log Compose Rider

Tanggal: 2026-10-03. Permintaan: log API tidak terlihat di Rider.

Temuan: container dari Debug Rider berhenti exit 127 dengan `exec /opt/JetBrains/RiderDebuggerTools/linux-x64/JetBrains.Debugger.Worker failed: No such file or directory`. API belum berjalan. Profil shared sebelumnya memakai factory/deployment `docker-compose`, sedangkan Rider terpasang menyimpan `docker-compose.yml`.

Perbaiki format profil sesuai konfigurasi Rider lokal, aktifkan attach output dan tool window; dokumentasikan Run serta lokasi log. Uji output Compose foreground. Attach debugger Alpine tetap belum selesai/teruji.

Hasil: profil shared diperbaiki ke factory/deployment `docker-compose.yml`, `forceBuild=true`, `upDetach=false`, aktivasi tool window serta extension fast mode off. Nama field diperiksa terhadap class plugin Docker Rider terpasang. `docker compose up --no-build` foreground menampilkan stdout startup API, CDN HTTP 200. Container uji dihentikan dengan `docker compose stop`; volume dipertahankan. XML valid dan diff check lulus. UI Rider belum bisa diverifikasi langsung; gunakan Run dan Services > container > Log. Debugger Alpine masih gagal pada konfigurasi Debug yang sebelumnya dipakai pengguna.
