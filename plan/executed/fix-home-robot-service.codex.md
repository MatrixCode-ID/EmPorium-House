# Perbaiki Home setelah pemisahan layanan robot

Permintaan pengguna: perbaiki EmPorium Home Control setelah perubahan robot di
em-system. Home masih memanggil GetMeta_CtnRobots yang sudah dihapus.

Hapus ketergantungan identitas robot dari kartu Container Registry. Statistik
kartu tetap Roots dan Containers; pengelolaan robot lewat User Manager.
Pertahankan perubahan lokal pengguna di project/Program/resources.

Verifikasi: build solution WPF, cari referensi API robot lama, dan diff check.

Selesai: panggilan GetMeta_CtnRobots dan statistik Robots di kartu registry dihapus.
Kartu menampilkan Roots/Containers tanpa memerlukan hak User Manager.
Build WPF --no-restore lulus (0 warning/error); tidak ada referensi API robot lama
pada source EmPorium House. Uji interaksi Home terhadap server belum dilakukan.
