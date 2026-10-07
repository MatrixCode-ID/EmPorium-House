# Verifikasi login GHCR manual

Tanggal: 2026-10-04. Status: kode selesai, verifikasi login belum dijalankan.

Perubahan: publisher mengecek kredensial Docker GHCR (credential helper atau
auths), memvalidasi login ke GHCR, lalu meminta username dan PAT tersembunyi jika
belum ada atau kedaluwarsa. Kredensial yang sama dipakai untuk membaca tag dan
push; keputusan push tetap setelah build lokal.

Automatic approval review menolak eksekusi harness pengujian login PowerShell
dengan `blocked by policy`; tidak ada alasan yang lebih spesifik dalam hasil
penolakan. Tidak dicoba ulang melalui shell/wrapper lain. Sesuai aturan tindakan
terblokir di `claude.md`, pengujian disiapkan manual.

Urutan: jalankan `test-login.ps1` dahulu dalam proses PowerShell baru. Direktori
kerja: root repo EmPorium. Perintah lengkap:

```powershell
pwsh -NoLogo -NoProfile -File ..\.artefacts\EmPorium\scripts\ghcr-login-smoke\test-login.ps1
```

Hasil yang perlu diperiksa: semua baris PASS (missing login, cached login,
expired login, per-registry helper, default store, syntax), tampilan help, tanpa
error dan exit code 0. Pengujian memakai dummy, tidak melakukan login nyata atau
menghubungi GitHub. Setelah itu jalankan `scripts\upload-api-ghcr.cmd` untuk
verifikasi login GHCR nyata; pilih tidak saat prompt push bila hanya ingin build
lokal. Login nyata, build dan push belum diverifikasi pada perubahan ini.
