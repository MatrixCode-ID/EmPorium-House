# Toggle NuGet Server di Home

Permintaan: ganti tombol Switch off/on dengan toggle di pojok kanan atas card NuGet Server.

- Letakkan toggle di header di sebelah kanan refresh; pertahankan refresh independen.
- Status toggle mengikuti hasil server, termasuk saat konfirmasi dibatalkan atau request gagal; pertahankan command, claim, dan busy guard.
- Gunakan template bertema dengan fokus keyboard dan kondisi disabled tanpa background sistem.
- Hapus tombol lama dan rapikan jarak tombol Open NuGet Manager.
- Verifikasi build serta render on/off/busy pada tema terang dan gelap dengan harness offline.

## Hasil

- Selesai: toggle header di kanan refresh, tombol Switch off/on lama dihapus, jarak Open dirapikan.
- Binding satu arah dikembalikan ke status server sebelum command berjalan; confirmation, claim, dan busy guard tetap memakai handler yang sudah ada.
- Build `dotnet build src/frontend/EmPoriumHouse.Ui.Wpf.slnx -c Release --nologo`: lulus, 0 warning/error.
- Harness `dotnet run --project ../.artefacts/EmPorium/scripts/module-card-qa-render/ModuleCardQa.csproj -c Release --artifacts-path <temp>/nuget-home-toggle-qa`: lulus tema terang/gelap, status on/off, disabled saat refresh, hak akses, serta klik toggle off menuju on dengan service palsu.
- Render diperiksa: dark-on, light-off, dark-busy. Output PNG: `<temp>/nuget-home-toggle-qa/bin/ModuleCardQa/release/`. `git diff --check` lulus.
- Belum diuji: mouse/keyboard dan dialog konfirmasi terhadap host/server live. Proses aplikasi pengguna tidak dimulai ulang.
