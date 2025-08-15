# FPLjuara (Flutter, APK-ready)

Aplikasi Android bertema hijau FPL dengan logo raja (mahkota). Fitur:
- Splash screen "Menuju Juara FPL"
- Tema hijau FPL (#00ff87)
- GW info, Top 10 Captain Picks, Top Players
- Caching data (SharedPreferences): app tetap menampilkan data terakhir saat offline sementara

## Jalankan (Dev)
```
flutter pub get
flutter pub run flutter_native_splash:create
flutter pub run flutter_launcher_icons
flutter run
```

## Build APK (Release)
```
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Build via Codemagic (Disarankan)
1. Upload ZIP project ini ke Codemagic.
2. Tambahkan langkah build commands:
   - `flutter pub get`
   - `flutter pub run flutter_native_splash:create`
   - `flutter pub run flutter_launcher_icons`
   - `flutter build apk --release`
3. Download artifact `app-release.apk`.

## Catatan
- Launcher icon & splash dibuat dari `assets/logo.png` (mahkota emas).
- Warna utama: #00ff87 (hijau FPL).
