# Ký bản release Android (An tự làm trên máy mình)

Không bao giờ commit keystore (`.jks`) hoặc `key.properties`. Cả hai đã nằm
trong `.gitignore`. **Mất keystore = không cập nhật được app trên Google Play
(hoặc người dùng phải cài lại). Hãy sao lưu keystore và mật khẩu ở 2 nơi an
toàn (không để trong repo).**

## 1. Tạo keystore (chỉ làm một lần)

Dùng `keytool` đi kèm JDK của Android Studio (xem đường dẫn bằng
`flutter doctor -v`, mục "Java binary at"). Trên PowerShell:

```powershell
& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkey -v `
  -keystore C:\Users\cunuo\keys\tiemhoasommai-upload.jks `
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

(Tạo thư mục `C:\Users\cunuo\keys` trước, nằm NGOÀI repo. Nếu `keytool` đã có
trong PATH thì chỉ cần gõ `keytool -genkey -v ...`.) keytool sẽ hỏi mật khẩu
keystore và mật khẩu key; hãy ghi lại.

## 2. Tạo `android/key.properties`

Tạo file `android/key.properties` (gitignored) với nội dung:

```properties
storePassword=<mật khẩu keystore>
keyPassword=<mật khẩu key>
keyAlias=upload
storeFile=C:/Users/cunuo/keys/tiemhoasommai-upload.jks
```

Dùng dấu `/` (không dùng `\`) trong `storeFile`. Đường dẫn tương đối được tính
từ thư mục `android/app/`.

Nếu thiếu `key.properties`, Gradle in cảnh báo và ký bằng khóa debug (chỉ để
chạy thử, KHÔNG phát hành bản đó). Nếu file có nhưng thiếu một trong 4 dòng
trên, build dừng với thông báo rõ ràng.

## 3. Build

```powershell
flutter build apk --release
```

Kết quả: `build\app\outputs\flutter-apk\app-release.apk`.
(Google Play nên dùng `flutter build appbundle --release`.)

## 4. Lấy dấu vân tay SHA-1 / SHA-256 cho Firebase

```powershell
keytool -list -v -keystore C:\Users\cunuo\keys\tiemhoasommai-upload.jks -alias upload
```

Lấy dòng `SHA1:` và `SHA256:`. Nếu chạy debug trên máy, thêm cả dấu vân tay của
khóa debug:

```powershell
keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Nếu sau này đưa app lên Google Play với "Play App Signing", thêm cả SHA-1 /
SHA-256 của *app signing key* (Play Console > Setup > App signing) vào Firebase.

Các bước còn lại trên Firebase console: xem `docs/ANDROID_FIREBASE.md`.
