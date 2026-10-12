# Firebase cho bản Android (An tự làm trên Firebase console)

Dự án Firebase: `tiem-hoa-som-mai`. Hiện chỉ có 1 app: `tiem-hoa-web`
(`1:109365200950:web:f8214a14462e87a998f097`, loại WEB). **Chưa có app Android**
(kiểm tra bằng `firebase apps:list --project tiem-hoa-som-mai`), nên cần tạo.

Mã nguồn đã sẵn sàng:

* `android/app/build.gradle.kts` tự bật plugin `com.google.gms.google-services`
  khi có file `android/app/google-services.json`. Không có file thì build vẫn
  chạy, chỉ in cảnh báo và game chơi offline (không đăng nhập / lưu cloud).
* `lib/main.dart` khởi tạo Firebase trên mọi nền tảng. Android dùng
  `google-services.json`, trừ khi `DefaultFirebaseOptions.android` trong
  `lib/firebase_options.dart` đã được điền giá trị thật (không bắt buộc).

## Các bước

1. Tạo keystore và lấy SHA: xem `android/SIGNING.md`.
2. Firebase console > Project settings (bánh răng) > **Your apps** > **Add app**
   > biểu tượng Android.
   * **Android package name**: `com.tiemhoasommai.game`  (phải khớp
     `applicationId` trong `android/app/build.gradle.kts`, không viết hoa/thêm
     ký tự).
   * App nickname: `tiem-hoa-android` (tùy ý).
   * Debug signing certificate SHA-1: có thể bỏ trống, thêm sau.
   * Bấm **Register app**. Bỏ qua các bước "Add Firebase SDK" của console (đã
     làm trong repo).
3. Vẫn ở Project settings > app Android vừa tạo > **SHA certificate
   fingerprints** > **Add fingerprint**, thêm lần lượt:
   * SHA-1 và SHA-256 của keystore release (lệnh `keytool -list -v ...` trong
     `android/SIGNING.md`).
   * (Nên thêm) SHA-1 và SHA-256 của khóa debug nếu muốn chạy debug trên máy.
   * (Sau này) SHA-1/SHA-256 của "App signing key" nếu dùng Play App Signing.
   Google sign-in trên Android chỉ chạy khi SHA đúng đã được đăng ký.
4. Authentication > Sign-in method: **Google** phải đang Enabled (web đã bật).
   Authentication > Settings > Authorized domains không cần đổi cho Android.
5. Sau khi thêm SHA, bấm **Download google-services.json** (tải lại SAU khi đã
   thêm SHA để file có mục `oauth_client` với `client_type: 3`, đây là Web client
   ID dùng để đăng nhập Google) và đặt vào:

   `ai_game\android\app\google-services.json`

   File này không phải bí mật (chỉ chứa ID và API key công khai của app) nên có
   thể commit, nhưng cũng có thể để ngoài git; build chỉ cần nó có mặt trên
   máy build.
6. (Tùy chọn) Dán vào `lib/firebase_options.dart`, mục `android`:
   * `apiKey`  <- `client[0].api_key[0].current_key` trong google-services.json
   * `appId`   <- `client[0].client_info.mobilesdk_app_id` (dạng
     `1:109365200950:android:xxxxxxxxxxxx`)
   Không dán cũng chạy được.
7. Kiểm tra: `flutter build apk --release`, cài lên máy, bấm "Đăng nhập để lưu".

## Nếu đăng nhập Google báo lỗi

* `DEVELOPER_ERROR` / `[16]`/ "no credentials available": SHA-1 của keystore dùng
  để ký APK chưa được thêm vào Firebase, hoặc `google-services.json` tải trước
  khi thêm SHA. Thêm SHA rồi tải lại file, build lại.
* Bản debug và bản release dùng khóa khác nhau nên SHA khác nhau.

## iOS

App Firebase `tiem-hoa-ios`, bundle `com.tiemhoasommai.game`. Repo đã có
`ios/Runner/GoogleService-Info.plist`, bundle id trong Xcode, và URL scheme
Google (`REVERSED_CLIENT_ID`) trong `Info.plist`. Trên máy build: chọn **Team**
signing trong Xcode (target Runner), rồi `flutter run` trên simulator hoặc máy
thật. Authentication > Google phải Enabled (cùng project với web/Android).
