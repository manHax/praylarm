# Praylarm (Prayer Alarm App)

Aplikasi alarm dan jadwal sholat dengan deteksi lokasi otomatis, menggunakan API dari AlAdhan.
Aplikasi ini mendukung *Push Notification* dan *Native Android Alarm* untuk membangunkan pengguna saat waktu sholat (atau saat Imsak/Tahajud).

## Download APK
Anda bisa men-download APK versi terbaru yang sudah siap pakai (siap di-install) di folder `releases/` atau melalui tautan berikut:

- [Praylarm v1.1.0 (APK)](releases/app-release.apk)

## Fitur-Fitur
- Deteksi lokasi GPS secara otomatis dan _background check_.
- Tampilan responsif dengan _dark mode_ premium.
- Pengaturan kustomisasi notifikasi / alarm penuh per-waktu sholat.
- Fitur peringatan 10 menit sebelum waktu sholat habis.
- Mendukung berbagai jenis alarm kustom sesuai _ringtone_ bawaan perangkat.

## Cara Build Sendiri
Jika Anda ingin me-_run_ atau mem-_build_ aplikasi ini sendiri:
1. Pastikan Anda sudah menginstal [Flutter](https://docs.flutter.dev/get-started/install).
2. Jalankan `flutter pub get`.
3. Jalankan `flutter build apk` (untuk build APK).
