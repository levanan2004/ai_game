# Ký bản release Android (An tự làm trên máy mình)

Không bao giờ commit keystore (`.jks`) hoặc `key.properties`. Cả hai đã nằm
trong `.gitignore`. **Mất keystore = không cập nhật được app trên Google Play
(hoặc người dùng phải cài lại). Hãy sao lưu keystore và mật khẩu ở 2 nơi an
toàn (không để trong repo).**

## 1. Tạo keystore (chỉ làm một lần)

Tạo thư mục `C:\Users\cunuo\keys` (NGOÀI repo), rồi chạy trong PowerShell
(`keytool` đi kèm JDK của Android Studio; xem đường dẫn bằng `flutter doctor -v`,
mục "Java binary at". Nếu `keytool` chưa có trong PATH, gọi bằng đường dẫn đầy
đủ, ví dụ `& "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" ...`):

```powershell
keytool -genkey -v -keystore C:\Users\cunuo\keys\tiemhoa-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias tiemhoa
```

keytool sẽ hỏi mật khẩu keystore, mật khẩu key và thông tin tên/tổ chức; hãy
ghi lại mật khẩu.

## 2. Tạo `android/key.properties`

Tạo file `android/key.properties` (đã gitignored) với nội dung:

```properties
storePassword=<mật khẩu keystore>
keyPassword=<mật khẩu key>
keyAlias=tiemhoa
storeFile=C:\\Users\\cunuo\\keys\\tiemhoa-release.jks
```

Trong file `.properties`, dấu `\` phải viết đôi (`\\`) như trên; viết
`C:/Users/cunuo/keys/tiemhoa-release.jks` cũng được. Đường dẫn tương đối được
tính từ thư mục `android/app/`.

Nếu thiếu `key.properties`, Gradle in cảnh báo và ký bằng khóa debug (chỉ để
chạy thử, KHÔNG phát hành bản đó). Nếu file có nhưng thiếu một trong 4 dòng
trên, build dừng với thông báo rõ ràng.

## 3. Build

Bản cài từ trang web (đăng nhập Google, nạp Pha lê):

```powershell
flutter build apk --release --flavor open
```

Kết quả: `build\app\outputs\flutter-apk\app-open-release.apk`.

Bản Amazon Appstore: xem `docs/ANDROID_AMAZON.md`.

(Google Play nên dùng `flutter build appbundle --release --flavor open`.)

## 4. Lấy dấu vân tay SHA-1 / SHA-256 cho Firebase

```powershell
keytool -list -v -keystore C:\Users\cunuo\keys\tiemhoa-release.jks -alias tiemhoa
```

Lấy dòng `SHA1:` và `SHA256:`. Nếu chạy debug trên máy, thêm cả dấu vân tay của
khóa debug:

```powershell
keytool -list -v -keystore $env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Nếu sau này đưa app lên Google Play với "Play App Signing", thêm cả SHA-1 /
SHA-256 của *app signing key* (Play Console > Setup > App signing) vào Firebase.

Các bước còn lại trên Firebase console: xem `docs/ANDROID_FIREBASE.md`.
