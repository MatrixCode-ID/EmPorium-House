# Rilis otomatis setelah NuGet engine naik

- Tanggal: 2026-10-07
- Status: jadi plan
- Plan turunan: [workspace dan workflow](../../plan/unexecuted/workspace-ci-release.codex.md).

## Latar belakang

Pengguna menanyakan apakah publikasi versi baru paket NuGet em-system dapat
memicu build EmPorium House, menghasilkan ZIP aplikasi desktop pada GitHub
Release, serta menerbitkan image API ke GHCR. Kedua proyek berada di repo berbeda.

## Keputusan yang sudah jelas

- Permintaan terbaru hanya diskusi; belum ada izin implementasi workflow atau publikasi.
- Repo sumber adalah `MatrixCode-ID/em-system`, repo produk adalah
  `MatrixCode-ID/EmPorium-House`.
- Fokus diskusi terbaru adalah publikasi NuGet, menggantikan pembahasan awal
  mengenai pemicu setelah CI sukses saja.
- Engine produk berasal dari paket `EmSys.*`; `EmSysVersion` berada di
  `Directory.Build.props`.

## Alur yang dipertimbangkan

1. Workflow `Publish NuGet` em-system berhasil memublikasikan seluruh paket versi tertentu.
2. em-system mengirim `workflow_dispatch` ke repo produk, membawa versi engine tersebut.
3. Workflow produk menunggu paket yang dibutuhkan tersedia untuk restore, dengan retry
   terbatas, lalu memakai versi persis yang diterima untuk build WPF dan Docker.
4. Build WPF pada runner Windows menghasilkan aplikasi single file dan
   `EmPorium-House.<versi-produk>.zip`.
5. Build API pada runner Linux menghasilkan image
   `ghcr.io/matrixcode-id/emporium-server:<versi-produk>`.
6. Setelah kedua build lolos, workflow menerbitkan image dan GitHub Release
   dengan ZIP. Alias channel diperbarui sesuai kebijakan versi yang disepakati.

Pemicu lintas repo membutuhkan GitHub App token atau fine-grained PAT dengan
izin Actions write di repo produk. Token bawaan repo em-system terbatas pada repo
tersebut. Workflow produk dapat memakai token repo sendiri untuk GitHub Release
dan GHCR, dengan izin yang sesuai dan akses package GHCR yang sudah ada.

Fondasi lokal sudah tersedia: `scripts/publish-wpf/publish-wpf.ps1`,
`scripts/upload-api-ghcr/publish.ps1`, dan Dockerfile API. Skrip saat ini
interaktif sehingga belum langsung cocok untuk workflow tanpa input pengguna.
Dockerfile membaca `Directory.Build.props`; versi engine baru harus diterapkan
juga pada konteks Docker, bukan hanya build WPF.

## Pertanyaan yang masih terbuka

- Apakah versi produk mengikuti versi engine atau memakai nomor rilis produk sendiri?
- Apakah pembaruan `EmSysVersion` dicatat otomatis sebagai commit, melalui PR,
  atau hanya diterapkan pada checkout build? Tag produk harus tetap memungkinkan
  build ulang dengan versi engine yang sama.
- Branch/commit produk mana yang dipakai untuk rilis otomatis?
- Channel engine mana yang memicu rilis produk, dan alias image apa yang diperbarui?
- Bagaimana menjalankan ulang publikasi parsial tanpa membuat rilis ganda?

## Pembahasan update produk sendiri (2026-10-07)

Pengguna menambahkan skenario perubahan Home default di repo EmPorium House
dan menanyakan rancangan dari sisi produk. Skenario ini masih diskusi.

Workflow produk dapat menerima dua pemicu: `push`/merge perubahan produk ke
`main`, serta `workflow_dispatch` dari rilis engine. Pada pemicu produk, versi
engine dibaca dari `EmSysVersion` yang tercatat; pada dispatch engine, versi
input perlu diterapkan dan dicatat agar build produk berikutnya tidak kembali
memakai engine lama. Cara mencatatnya (commit atau PR) belum diputuskan.

Versi produk yang independen dari versi engine direkomendasikan supaya update
Home dapat menghasilkan ZIP dan image baru tanpa merilis ulang paket engine.
Misalnya dua rilis produk berturut-turut sama-sama memakai satu versi engine,
lalu rilis produk berikutnya memakai engine yang lebih baru. Nomor rilis produk
yang sama dipakai untuk tag GitHub Release, nama ZIP, dan tag image versi tetap.

Kebijakan publikasi perubahan produk belum diputuskan: setiap merge ke `main`
langsung merilis produk, atau setiap merge hanya build/CI dan publikasi menunggu
versi/release note/tag produk baru. Pemilihan nomor versi dilakukan sekali dan
dibagikan ke build WPF serta Docker. Rancangan juga perlu mengatur concurrency
dan deduplikasi ketika perubahan produk dan dispatch engine datang berdekatan.

## Pembahasan branch work-bench (2026-10-07)

Pengguna menanyakan apakah produk dapat memakai pola `work-bench` seperti
em-system. Checkout lokal saat diperiksa berada di `main`, melacak `origin/main`,
dengan satu remote `origin` ke repo publik `MatrixCode-ID/EmPorium-House`.
Belum ada branch lokal `work-bench` atau remote `private`; keadaan remote terkini
belum diperiksa melalui fetch/API.

Pola yang dipertimbangkan adalah satu folder kerja dengan remote `private` ke
repo privat produk (nama usulan `MatrixCode-ID/EmPorium-House-work`, keberadaan
repo belum diverifikasi) untuk `work-bench`, serta `origin` ke repo publik untuk
`main` dan, bila diperlukan, `ci-sandbox`. Branch `work-bench` juga bisa berada
di repo yang sama bila pemisahan privat/publik tidak diperlukan.

Perubahan Home dikerjakan dan diuji di `work-bench`; kode siap rilis beserta
release note produk kemudian digabungkan ke `main`. Sebagai usulan mengikuti
em-system, CI berjalan saat perubahan kode masuk `main`, sedangkan publikasi
ZIP/image hanya ketika ada release note versi produk baru yang belum dirilis.

Dispatch engine otomatis dapat memakai kode produk yang sudah ada di `main`,
tanpa menggabungkan pekerjaan Home yang belum siap di `work-bench`. Bila versi
engine diperbarui dan dicatat pada `main`, perubahan tersebut perlu disinkronkan
kembali ke `work-bench`. Kebijakan commit/PR untuk update otomatis, versi produk,
serta penulisan release note otomatis masih perlu diputuskan.

Belum ada permintaan membuat repo/branch, mengubah remote, atau menjalankan
workflow; pembahasan ini tetap berupa ide.

## Keputusan alur update engine (2026-10-07)

Pengguna menetapkan bahwa workflow dari em-system memperbarui branch `main`
EmPorium House, kemudian `work-bench` mengambil perubahan dari `main`.
Keputusan ini menggantikan pertanyaan sebelumnya mengenai branch tujuan update
engine dan perlunya mencatat versi pada repo produk. Ini masih keputusan desain,
bukan permintaan implementasi.

Pada rancangan dispatch yang sedang dibahas, workflow em-system mengirim versi
setelah publikasi NuGet berhasil; workflow penerima di EmPorium House
memperbarui dan mencatat `EmSysVersion` pada `main`, lalu meneruskan build dan
publikasi produk. Seluruh build harus memakai commit dan versi engine yang sama.
Pekerjaan produk yang belum digabungkan dari `work-bench` tidak ikut rilis ini.

Untuk pola dua remote, sinkronisasi lokal dilakukan dengan fetch `origin`, lalu
merge `origin/main` ke `work-bench`; push hasilnya ke `private/work-bench`.
Pull biasa pada `work-bench` mengikuti upstream `private/work-bench`, sehingga
tidak otomatis mengambil `origin/main`. Sinkronisasi mempertahankan commit
pekerjaan pengguna dan tidak memakai reset/force push. Jika ada konflik, konflik
diselesaikan sebelum hasil merge dipublikasikan. Belum diputuskan apakah
sinkronisasi dilakukan lokal oleh pengguna atau otomatis di repo privat.

Sebagai rincian rancangan, build/rilis dapat diteruskan dalam run penerima yang
sama agar tidak mengandalkan push oleh `GITHUB_TOKEN` untuk memicu workflow lain.
Kebijakan nomor versi produk dan release note masih belum diputuskan.

## Keputusan nama repo kerja (2026-10-07)

Pengguna menyatakan bahwa pola ini berarti membuat repo baru
`MatrixCode-ID/EmPorium-House-work`. Nama tersebut menjadi nama repo kerja yang
disepakati, menggantikan status nama usulan pada pembahasan sebelumnya.

Sesuai pola em-system yang sedang dibahas, repo kerja bersifat privat, dipakai
melalui remote `private` untuk branch `work-bench`; repo publik
`MatrixCode-ID/EmPorium-House` tetap remote `origin` untuk `main` dan opsional
`ci-sandbox`. Folder lokal tetap `EmPorium` dan memakai dua remote.

Repo baru harus membawa riwayat Git produk yang sama agar merge antar-branch
dapat dilakukan normal. Repo/branch/remote belum dibuat atau diubah; pengguna
belum mengganti konteks diskusi menjadi permintaan eksekusi.

## Persiapan disetujui (2026-10-07)

Pengguna meminta menyiapkan workflow produk, membuat repo kerja lewat gh, dan
menambahkan wrapper CMD untuk memperbaiki remote/tracking pada clone pertama.
Kebijakan yang dipilih: seperti em-system, release note versi produk baru memicu
publikasi; update engine otomatis menaikkan nomor rilis produk independen.

Repo privat `MatrixCode-ID/EmPorium-House-work` sudah dibuat. Persiapan workflow
memakai target otomatis 0.1.0 dan channel alpha. Contoh alpha.4 menjadi alpha.5,
sementara versi engine bisa alpha.8. Pindah beta melalui perubahan konfigurasi
channel serta release note beta.1; update engine berikutnya naik beta.2.
Detail pelaksanaan dan verifikasi berada di plan turunan. Catatan pembahasan
sebelumnya tetap dipertahankan sebagai sejarah keputusan.

## Dokumentasi sumber

- [Workflow dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)
- [Batas izin GITHUB_TOKEN](https://docs.github.com/en/actions/concepts/security/github_token)
- [Publikasi image melalui GitHub Actions](https://docs.github.com/en/actions/tutorials/publish-packages/publish-docker-images)
- [Validasi dan pengindeksan paket NuGet](https://learn.microsoft.com/en-us/nuget/nuget-org/publish-a-package#package-validation-and-indexing)
