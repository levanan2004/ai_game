import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Google sign-in on Android and iOS (the web uses the Firebase popup).
///
/// Only hands back a Google ID token; [FirebaseAccount] turns it into a
/// Firebase login. Kept behind this small interface so tests need no plugin.
abstract class NativeGoogleAuth {
  /// Shows the Google account chooser. Returns the ID token, or null when the
  /// player closed the chooser. Throws for any other failure (no network,
  /// wrong SHA / package in the Firebase console, no Google account).
  Future<String?> idToken();

  /// Forgets the Google account so the next [idToken] shows the chooser
  /// again (switching account). Never throws.
  Future<void> signOut();
}

/// Optional OAuth *web* client id, only needed when the app is built without
/// google-services.json: `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`.
const _serverClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

/// True when [code] means the player backed out (not an error to show).
bool googleSignInWasCancelled(GoogleSignInExceptionCode code) =>
    code == GoogleSignInExceptionCode.canceled ||
    code == GoogleSignInExceptionCode.interrupted;

/// The native sign-in for the platform this app runs on, or null on the web
/// and on desktop.
NativeGoogleAuth? platformGoogleAuth() {
  if (kIsWeb) return null;
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return GoogleSignInNative();
    default:
      return null;
  }
}

/// `google_sign_in` 7.x. On Android the web client id comes from
/// google-services.json (needs the release SHA-1 in the Firebase console);
/// on iOS from GoogleService-Info.plist.
class GoogleSignInNative implements NativeGoogleAuth {
  Future<void>? _ready;

  Future<void> _init() async {
    try {
      await (_ready ??= GoogleSignIn.instance.initialize(
        serverClientId: _serverClientId.isEmpty ? null : _serverClientId,
      ));
    } catch (_) {
      _ready = null;
      rethrow;
    }
  }

  @override
  Future<String?> idToken() async {
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null || token.isEmpty) {
        throw StateError('Google returned no ID token');
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (googleSignInWasCancelled(e.code)) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _init();
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
