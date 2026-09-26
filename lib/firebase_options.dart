import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Hand-written from the public [firebase_config.json]. No FlutterFire CLI.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Firebase is only configured for web.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyD8YMB2SUHY9bNVjLU-Fj8hvG51yYeQRx0',
    appId: '1:109365200950:web:f8214a14462e87a998f097',
    messagingSenderId: '109365200950',
    projectId: 'tiem-hoa-som-mai',
    authDomain: 'tiem-hoa-som-mai.firebaseapp.com',
    storageBucket: 'tiem-hoa-som-mai.firebasestorage.app',
  );
}
