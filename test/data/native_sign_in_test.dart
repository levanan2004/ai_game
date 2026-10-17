import 'package:ai_game/data/firebase_account.dart';
import 'package:ai_game/data/native_google_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';

class _User implements User {
  _User(this.uid, this.email);

  @override
  final String uid;
  @override
  final String? email;
  @override
  String? get displayName => 'An';
  @override
  String? get photoURL => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Cred implements UserCredential {
  _Cred(this.user);

  @override
  final User? user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth implements FirebaseAuth {
  final credentials = <AuthCredential>[];
  var signOuts = 0;
  User? user;
  var failSignOut = false;

  @override
  User? get currentUser => user;

  @override
  Future<UserCredential> signInWithCredential(AuthCredential credential) async {
    credentials.add(credential);
    user = _User('uid-${credentials.length}', 'an${credentials.length}@x.vn');
    return _Cred(user);
  }

  @override
  Future<void> signOut() async {
    signOuts++;
    user = null;
    if (failSignOut) throw StateError('boom');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Db implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Storage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Native implements NativeGoogleAuth {
  _Native(this.answers);

  final List<Object?> answers;
  var asked = 0;
  var signOuts = 0;

  @override
  Future<String?> idToken() async {
    final a = answers[asked++];
    if (a is Exception) throw a;
    return a as String?;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

FirebaseAccount _account(_Auth auth, _Native native) => FirebaseAccount(
  auth: auth,
  firestore: _Db(),
  storage: _Storage(),
  nativeGoogle: native,
);

void main() {
  test(
    'native sign-in turns the Google ID token into a Firebase login',
    () async {
      final auth = _Auth();
      final native = _Native(['google-id-token']);
      final profile = await _account(auth, native).signIn();
      expect(profile?.uid, 'uid-1');
      expect(profile?.email, 'an1@x.vn');
      expect(
        (auth.credentials.single as OAuthCredential).idToken,
        'google-id-token',
      );
      expect(auth.credentials.single.providerId, 'google.com');
    },
  );

  test('closing the Google chooser is a quiet null, not an error', () async {
    final auth = _Auth();
    final native = _Native([null]);
    expect(await _account(auth, native).signIn(), isNull);
    expect(auth.credentials, isEmpty);
  });

  test(
    'a real failure is thrown so the session shows its retry line',
    () async {
      final auth = _Auth();
      final native = _Native([Exception('config')]);
      await expectLater(_account(auth, native).signIn(), throwsException);
      expect(auth.credentials, isEmpty);
    },
  );

  test(
    'sign-out clears Firebase and the Google account; switching works',
    () async {
      final auth = _Auth();
      final native = _Native(['t1', 't2']);
      final account = _account(auth, native);
      expect((await account.signIn())?.uid, 'uid-1');
      await account.signOut();
      expect(auth.signOuts, 1);
      expect(native.signOuts, 1);
      expect(account.currentProfile(), isNull);
      // Another Google account on the same phone.
      expect((await account.signIn())?.uid, 'uid-2');
      expect(native.asked, 2);
      expect(auth.credentials.map((c) => (c as OAuthCredential).idToken), [
        't1',
        't2',
      ]);
    },
  );

  test(
    'the Google account is forgotten even when Firebase sign-out fails',
    () async {
      final auth = _Auth()..failSignOut = true;
      final native = _Native([]);
      await expectLater(_account(auth, native).signOut(), throwsStateError);
      expect(native.signOuts, 1);
    },
  );

  test('cancel and interrupted are not errors; configuration errors are', () {
    expect(
      googleSignInWasCancelled(GoogleSignInExceptionCode.canceled),
      isTrue,
    );
    expect(
      googleSignInWasCancelled(GoogleSignInExceptionCode.interrupted),
      isTrue,
    );
    expect(
      googleSignInWasCancelled(
        GoogleSignInExceptionCode.clientConfigurationError,
      ),
      isFalse,
    );
    expect(
      googleSignInWasCancelled(GoogleSignInExceptionCode.uiUnavailable),
      isFalse,
    );
  });
}
