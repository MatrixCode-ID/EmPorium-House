# Tombol copy di kanan URL NuGet

Permintaan: letakkan tombol copy langsung di sebelah kanan URL pada card NuGet Server. Gunakan ikon copy kecil dengan tooltip dan nama aksesibilitas, pertahankan handler salin alamat dan wrapping URL. Verifikasi lewat build/render yang tersedia.

## Hasil (2026-10-03)

Tombol teks Copy address diganti ikon copy 28x28 tepat di kanan URL, jarak 6 px, tooltip dan nama aksesibilitas Copy address. Grid rata kiri mengikuti panjang URL dan mempertahankan wrapping. Handler CopyAddress tetap menyalin endpoint.Text penuh.

Verifikasi: `dotnet run --project ../.artefacts/EmPorium/scripts/module-card-qa-render -c Release` lulus pada tema terang/gelap termasuk ready/busy/off/error; sekaligus membangun host WPF dan modul terbaru. Render gelap manager-ready ditinjau: ikon langsung di kanan URL. `git diff --check` lulus. Klik clipboard dan render window live belum diuji pada perubahan layout ini.
