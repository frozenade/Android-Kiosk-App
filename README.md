# Exam Browser (Flutter) — kiosk mode tanpa root

Aplikasi *exam browser* untuk **Android** dan **iPhone/iPad**. Halaman ujian (CBT) dibuka di WebView, dan perangkat dikunci ke aplikasi selama ujian berlangsung. **Tidak perlu root maupun jailbreak.**

## Fitur

| | Android | iOS |
|---|---|---|
| Kunci ke aplikasi | Lock Task Mode (Device Owner) atau Sematkan Aplikasi | Mode Asesmen (`AEAssessmentSession`), Single App Mode, atau Akses Terpandu |
| Blokir screenshot/rekam layar | ✅ `FLAG_SECURE` | Hanya deteksi (dicatat sebagai pelanggaran) |
| Sembunyikan aplikasi mengambang | ✅ Android 12+ (`setHideOverlayWindows`) | — (tidak ada di iOS) |
| Deteksi split-screen / PiP | ✅ | — |
| Deteksi keluar aplikasi / kiosk dimatikan | ✅ | ✅ |
| Layar tetap menyala | ✅ | ✅ |

Fitur yang sama di kedua platform:
- Soal ujian baru dibuka setelah mode kiosk aktif.
- Setiap pelanggaran mengunci layar ujian. Hanya pengawas yang bisa membukanya dengan kata sandi.
- WebView hanya boleh membuka domain ujian (ditambah domain yang diizinkan). Alamat lain diblokir.
- User-Agent diberi akhiran `ExamBrowser/1.0`, sehingga server ujian bisa menolak browser biasa.
- Pelanggaran dikirim ke halaman ujian sebagai event JavaScript:
  ```js
  window.addEventListener('examBrowserViolation', e => {
    // e.detail = { type: 'app_left' | 'kiosk_exited' | 'multi_window' | 'screenshot' | ..., count: 1 }
  });
  ```
- Halaman ujian bisa menutup ujian dan mematikan kiosk dengan `ExamBrowser.postMessage('finish')`.

## Struktur

```
lib/
  main.dart
  kiosk/kiosk_service.dart      # MethodChannel `exam_browser/kiosk`
  models/exam_config.dart       # URL, kata sandi pengawas, daftar domain yang diizinkan
  screens/setup_screen.dart     # Layar pengawas: isi URL dan kata sandi
  screens/exam_screen.dart      # WebView, watchdog kiosk, deteksi pelanggaran
  widgets/                      # Layar kunci, gerbang kiosk, dialog kata sandi
android/app/src/main/kotlin/.../
  MainActivity.kt               # Channel, FLAG_SECURE, deteksi multi-window
  KioskManager.kt               # Lock Task / Screen Pinning / kebijakan Device Owner
  KioskAdminReceiver.kt         # Komponen device admin
ios/Runner/
  AppDelegate.swift             # KioskPlugin: AEAssessmentSession, Single App Mode, Akses Terpandu
  Runner.entitlements           # Entitlement asesmen (aktifkan setelah disetujui Apple)
```

## Menjalankan

```bash
flutter pub get
flutter run
```

## Android

### Mode 1 — Sematkan Aplikasi (HP siswa, tanpa persiapan)
Saat ujian dimulai, Android menampilkan dialog "Sematkan aplikasi?". Jika dialog tidak muncul, aktifkan dulu *Setelan > Keamanan > Sematkan aplikasi*. Siswa masih bisa melepas sematan dengan menahan Back + Recent. Jika itu terjadi, aplikasi mencatat pelanggaran, mengunci ujian, lalu menyematkan ulang.

### Mode 2 — Device Owner (tablet/HP milik sekolah, kiosk penuh)
Status bar, notifikasi, Home, Recent, menu power, safe boot, factory reset, dan jendela mengambang diblokir. Siswa tidak bisa keluar dari aplikasi.

Syaratnya, perangkat **tidak boleh memiliki akun** (Google, Samsung, dll.). Lakukan sesudah factory reset dan lewati login:

```bash
adb install app-release.apk
adb shell dpm set-device-owner id.examkiosk.exam_browser/.KioskAdminReceiver
```

Untuk banyak perangkat, gunakan QR provisioning atau MDM (Android Enterprise). Untuk melepas Device Owner, pakai tombol **Lepas Device Owner** di layar awal aplikasi.

## iOS

Aplikasi mencoba tiga cara secara berurutan:

1. **Mode Asesmen** (`AEAssessmentSession`, iOS 13.4+). Cara yang disarankan karena tidak butuh MDM. Syaratnya entitlement khusus dari Apple:
   1. Ajukan *Automatic Assessment Configuration* di <https://developer.apple.com/contact/request/automatic-assessment-configuration>.
   2. Setelah disetujui, aktifkan capability tersebut pada App ID dan perbarui provisioning profile.
   3. Di Xcode, buka *Runner > Build Settings* dan isi **Code Signing Entitlements** = `Runner/Runner.entitlements`.

   Selama entitlement belum ada, mode ini gagal dan aplikasi lanjut ke cara berikutnya.
2. **Autonomous Single App Mode**. Hanya untuk iPad/iPhone yang di-*supervise* (Apple Configurator atau MDM) dengan profil yang mengizinkan aplikasi ini.
3. **Akses Terpandu** secara manual: *Setelan > Aksesibilitas > Akses Terpandu*, lalu klik tiga kali tombol samping. Aplikasi menunggu sampai Akses Terpandu aktif sebelum membuka soal. Pengawas mengakhirinya dengan klik tiga kali + kode sandi.

Screenshot tidak bisa diblokir di iOS, hanya dideteksi.

## Catatan

- HTTP tanpa TLS diizinkan (`usesCleartextTraffic` / `NSAllowsArbitraryLoadsInWebContent`) agar server CBT di LAN sekolah tetap bisa diakses.
- Kata sandi pengawas hanya disimpan di memori untuk satu sesi ujian.
- Pada Sematkan Aplikasi, mematikan layar juga dihitung sebagai "meninggalkan aplikasi". Pada mode kiosk penuh tidak dihitung.
