# Bản Android Amazon Appstore

Bản **amazon** dùng cho Amazon Appstore: không đăng nhập Google, không lưu cloud,
không nạp Pha lê (QR), chỉ quảng cáo thưởng AdMob. Luật và privacy: mục *Bản
Amazon Appstore* trên [tiemhoasommai.com/privacy](https://tiemhoasommai.com/privacy).

## Build release

Cần `android/key.properties` như `android/SIGNING.md`.

```powershell
cd C:\Users\cunuo\MyAppFlutter\ai_game
flutter build apk --release --flavor amazon --dart-define=DISTRIBUTION=amazon
```

APK: `build\app\outputs\flutter-apk\app-amazon-release.apk`.

**Bắt buộc** có `--dart-define=DISTRIBUTION=amazon`. Flavor Gradle chỉ chọn
variant; logic game đọc biến `DISTRIBUTION`.

Hoặc:

```powershell
flutter build apk --release --flavor amazon --dart-define-from-file=tool/dart_defines/amazon.json
```

## Bản sideload (trang web)

```powershell
flutter build apk --release --flavor open
```

APK: `app-open-release.apk` (cùng `applicationId`, đăng nhập Google + nạp Pha lê).

## Kiểm tra nhanh sau cài

1. Cài đặt → Tài khoản: không có nút Google; dòng chữ bản Amazon.
2. Không có dải vàng "Đăng nhập để lưu" dưới thanh xu.
3. Cài đặt → không có "Cửa hàng Pha lê".
4. Vòng quay: thông báo không có trên bản Amazon (không nút đăng nhập).
5. Quảng cáo thưởng vẫn hoạt động (nếu có lượt).

## Amazon Developer Console

* Package name: `com.tiemhoasommai.game`
* Privacy: `https://tiemhoasommai.com/privacy`
* Terms: `https://tiemhoasommai.com/terms`
