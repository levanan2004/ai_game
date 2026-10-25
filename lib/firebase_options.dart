import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Hand-written from the public [firebase_config.json]. No FlutterFire CLI.
class DefaultFirebaseOptions {
  /// Options to pass to `Firebase.initializeApp`, or null when the native
  /// config file must be used instead: `android/app/google-services.json`
  /// on Android (read by the google-services Gradle plugin) and
  /// `GoogleService-Info.plist` on iOS. Null with no such file means Firebase
  /// does not start and the game plays offline.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidConfigured ? android : null;
      default:
        return null;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD8YMB2SUHY9bNVjLU-Fj8hvG51yYeQRx0',
    appId: '1:109365200950:web:f8214a14462e87a998f097',
    messagingSenderId: '109365200950',
    projectId: 'tiem-hoa-som-mai',
    authDomain: 'tiem-hoa-som-mai.firebaseapp.com',
    storageBucket: 'tiem-hoa-som-mai.firebasestorage.app',
    measurementId: 'G-86HPJBJYQQ',
  );

  /// Android app `com.tiemhoasommai.game`.
  ///
  /// apiKey and appId do not exist until the Android app is added in the
  /// Firebase console (docs/ANDROID_FIREBASE.md). Until then they stay as the
  /// PASTE_ placeholders below and [androidConfigured] is false, so Android
  /// reads google-services.json instead. Pasting the two real values from the
  /// downloaded google-services.json (`current_key` and `mobilesdk_app_id`)
  /// is optional; the file alone is enough.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'PASTE_ANDROID_API_KEY',
    appId: 'PASTE_ANDROID_APP_ID',
    messagingSenderId: '109365200950',
    projectId: 'tiem-hoa-som-mai',
    storageBucket: 'tiem-hoa-som-mai.firebasestorage.app',
  );

  /// True once the PASTE_ placeholders in [android] were replaced.
  static bool get androidConfigured =>
      !android.apiKey.startsWith('PASTE_') &&
      !android.appId.startsWith('PASTE_');
}
