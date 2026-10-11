import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/account_deletion.dart';
import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/platform_flags.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/save/terms_consent.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/delete_account_dialog.dart';
import 'package:ai_game/ui/delete_account_text.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:ai_game/ui/terms_screen.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';
import 'load_fonts.dart';

const _an = AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');

/// A signed-in account whose `deleteAccount` can be made to fail.
class _Acct extends OfflineAccount {
  _Acct();

  Object? failWith;
  var calls = 0;
  var signedOut = 0;

  @override
  AccountProfile? currentProfile() => _an;

  @override
  Future<AccountProfile?> signIn() async => _an;

  @override
  Future<AccountProfile?> restoreProfile() async => _an;

  @override
  Future<void> signOut() async => signedOut++;

  @override
  Future<void> deleteAccount() async {
    calls++;
    final e = failWith;
    if (e != null) throw e;
  }
}

Future<ShopSession> _signedIn(
  _Acct account,
  Map<String, String> backing,
) async {
  final s = newSession(
    store: ProgressStore.memory(backing),
    account: account,
    guestSaves: false,
  );
  await s.signIn();
  await s.pendingSaves;
  // The slot this device keeps for the account (the deletion must remove it).
  backing[ProgressStore.accountKey('u1')] = s.state.encode();
  return s;
}

Widget _host(Widget child) => MaterialApp(home: Scaffold(body: child));

Widget _dialog(ShopSession s) => _host(
  ListenableBuilder(
    listenable: s,
    builder: (_, _) => DeleteAccountDialog(session: s),
  ),
);

void main() {
  setUpAll(loadTestFonts);

  tearDown(() {
    iosAppOverride = null;
    androidAppOverride = null;
  });

  group('typed confirmation', () {
    test('XÓA or XOA, any case, trimmed', () {
      for (final ok in [
        'XÓA',
        'xóa',
        'Xóa',
        'XOA',
        'xoa',
        '  XOA ',
        'XO\u0301A', // o + combining acute, as some keyboards type it
      ]) {
        expect(DeleteText.typedOk(ok), isTrue, reason: ok);
      }
      for (final bad in ['', 'XO', 'XÓ A', 'XÓAA', 'xoá', 'delete', 'XÒA']) {
        expect(DeleteText.typedOk(bad), isFalse, reason: bad);
      }
    });

    test('Pha lê count uses dots', () {
      expect(DeleteText.phale(5), startsWith('Bạn đang có 5 Pha lê.'));
      expect(DeleteText.phale(1234), contains('1.234 Pha lê'));
      expect(DeleteText.phale(1234567), contains('1.234.567 Pha lê'));
    });

    test('kept-records note differs on iOS', () {
      expect(DeleteText.kept, DeleteText.keptNote);
      iosAppOverride = true;
      expect(DeleteText.kept, DeleteText.keptNoteIos);
    });
  });

  group('AccountDeletionClient', () {
    AccountDeletionClient clientFor(http.Client c) =>
        AccountDeletionClient(client: c, baseUrl: 'https://f.test');

    test('posts the callable body with the Bearer token', () async {
      late http.Request seen;
      final c = clientFor(
        MockClient((r) async {
          seen = r;
          return http.Response('{"result":{"ok":true}}', 200);
        }),
      );
      await c.delete('tok');
      expect(seen.url.toString(), 'https://f.test/deleteAccount');
      expect(seen.headers['authorization'], 'Bearer tok');
      expect(jsonDecode(seen.body), {'data': <String, Object?>{}});
    });

    test('maps the answers to failures', () {
      List<int> body(String m) =>
          utf8.encode('{"error":{"status":"X","message":"$m"}}');
      expect(
        AccountDeletionClient.failureOf(400, body('order-pending')),
        DeleteFailure.blocked,
      );
      expect(
        AccountDeletionClient.failureOf(500, body('partial')),
        DeleteFailure.partial,
      );
      expect(
        AccountDeletionClient.failureOf(500, body('server')),
        DeleteFailure.generic,
      );
      expect(
        AccountDeletionClient.failureOf(401, body('sign-in-required')),
        DeleteFailure.generic,
      );
      expect(AccountDeletionClient.failureOf(503, []), DeleteFailure.network);
      expect(AccountDeletionClient.failureOf(500, utf8.encode('x')),
          DeleteFailure.generic);
    });

    test('a dead network is a network failure', () async {
      final c = clientFor(
        MockClient((_) async => throw const SocketException('down')),
      );
      await expectLater(
        c.delete('tok'),
        throwsA(
          isA<DeleteAccountException>().having(
            (e) => e.failure,
            'failure',
            DeleteFailure.network,
          ),
        ),
      );
    });

    test('order-pending is blocked', () async {
      final c = clientFor(
        MockClient(
          (_) async => http.Response(
            '{"error":{"status":"FAILED_PRECONDITION","message":"order-pending"}}',
            400,
          ),
        ),
      );
      await expectLater(
        c.delete('tok'),
        throwsA(
          isA<DeleteAccountException>().having(
            (e) => e.failure,
            'failure',
            DeleteFailure.blocked,
          ),
        ),
      );
    });
  });

  group('session', () {
    test('success: signed out, local save gone, back at the title', () async {
      final backing = <String, String>{};
      final a = _Acct();
      final s = await _signedIn(a, backing);
      expect(backing.containsKey(ProgressStore.accountKey('u1')), isTrue);
      expect(backing.containsKey(ProgressStore.lastAccountKey), isTrue);
      s.openDeleteAccount();
      expect(s.deleteAccountOpen, isTrue);

      final failure = await s.deleteAccount();
      expect(failure, isNull);
      expect(a.calls, 1);
      expect(s.signedIn, isFalse);
      expect(s.accountEmail, isNull);
      expect(s.screen, Screen.title);
      expect(s.deleteAccountOpen, isFalse);
      expect(s.deleteBusy, isFalse);
      expect(s.deleteDone, isTrue);
      expect(backing.containsKey(ProgressStore.accountKey('u1')), isFalse);
      expect(backing.containsKey(ProgressStore.lastAccountKey), isFalse);

      // Nothing writes the deleted account back.
      s.setMusic(false);
      await s.pendingSaves;
      expect(backing.containsKey(ProgressStore.accountKey('u1')), isFalse);

      s.closeDeleteDone();
      expect(s.deleteDone, isFalse);
    });

    test('guest play does not open the dialog or call the server', () async {
      final a = _Acct();
      final s = newSession(account: a, guestSaves: false);
      s.openDeleteAccount();
      expect(s.deleteAccountOpen, isFalse);
      expect(await s.deleteAccount(), DeleteFailure.generic);
      expect(a.calls, 0);
    });

    for (final f in [DeleteFailure.network, DeleteFailure.blocked]) {
      test('$f keeps the account and the local save; retry works', () async {
        final backing = <String, String>{};
        final a = _Acct()..failWith = DeleteAccountException(f);
        final s = await _signedIn(a, backing);
        s.openDeleteAccount();
        expect(await s.deleteAccount(), f);
        expect(s.deleteFailure, f);
        expect(s.deleteBusy, isFalse);
        expect(s.deleteAccountOpen, isTrue);
        expect(s.signedIn, isTrue);
        expect(s.deleteDone, isFalse);
        expect(backing.containsKey(ProgressStore.accountKey('u1')), isTrue);

        a.failWith = null;
        expect(await s.deleteAccount(), isNull);
        expect(a.calls, 2);
        expect(s.signedIn, isFalse);
        expect(s.deleteDone, isTrue);
        expect(backing.containsKey(ProgressStore.accountKey('u1')), isFalse);
      });
    }

    test('an unknown error is a generic failure', () async {
      final a = _Acct()..failWith = StateError('boom');
      final s = await _signedIn(a, {});
      s.openDeleteAccount();
      expect(await s.deleteAccount(), DeleteFailure.generic);
      expect(s.signedIn, isTrue);
    });

    test('a half deletion: closing signs out, retry is still allowed', () async {
      final backing = <String, String>{};
      final a = _Acct()
        ..failWith = const DeleteAccountException(DeleteFailure.partial);
      final s = await _signedIn(a, backing);
      s.openDeleteAccount();
      expect(await s.deleteAccount(), DeleteFailure.partial);
      expect(s.signedIn, isTrue);
      // A second tap while busy does nothing.
      a.failWith = null;
      final first = s.deleteAccount();
      expect(await s.deleteAccount(), DeleteFailure.generic);
      expect(await first, isNull);
      expect(a.calls, 2);
    });
  });

  group('settings button', () {
    Future<void> pumpSettings(WidgetTester tester, ShopSession s) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ListenableBuilder(
            listenable: s,
            builder: (_, _) => SettingsPopup(session: s),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('hidden for a guest', (tester) async {
      final s = newSession(guestSaves: false)..openPause();
      await pumpSettings(tester, s);
      expect(find.byKey(const Key('settings-delete-account')), findsNothing);
      expect(find.text(DeleteText.settingsTitle), findsNothing);
    });

    testWidgets('signed in: the row opens the confirmation', (tester) async {
      final s = (await tester.runAsync(() => _signedIn(_Acct(), {})))!;
      s.openPause();
      await pumpSettings(tester, s);
      final row = find.byKey(const Key('settings-delete-account'));
      await tester.ensureVisible(row);
      await tester.pump();
      expect(find.text(DeleteText.settingsTitle), findsOneWidget);
      expect(find.text(DeleteText.settingsSubtitle), findsOneWidget);
      await tester.tap(row);
      await tester.pump();
      expect(s.deleteAccountOpen, isTrue);
    });
  });

  group('confirmation dialog', () {
    Future<void> pumpDialog(WidgetTester tester, ShopSession s) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_dialog(s));
      await tester.pump();
    }

    bool confirmEnabled(WidgetTester tester) {
      final b = tester.widget<ChunkyButton>(
        find.byKey(const Key('delete-confirm')),
      );
      return b.enabled && b.onPressed != null;
    }

    testWidgets('the button needs XÓA or XOA typed', (tester) async {
      final a = _Acct();
      final s = (await tester.runAsync(() => _signedIn(a, {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      expect(find.text(DeleteText.title), findsOneWidget);
      for (final line in DeleteText.list) {
        expect(find.text(line), findsOneWidget);
      }
      expect(find.byKey(const Key('delete-outro')), findsOneWidget);
      expect(find.text(DeleteText.keptNote), findsOneWidget);
      expect(find.byKey(const Key('delete-more')), findsOneWidget);
      expect(confirmEnabled(tester), isFalse);

      await tester.enterText(find.byKey(const Key('delete-field')), 'XO');
      await tester.pump();
      expect(confirmEnabled(tester), isFalse);
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pump();
      expect(a.calls, 0);

      await tester.enterText(find.byKey(const Key('delete-field')), 'xoa');
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);
      await tester.enterText(find.byKey(const Key('delete-field')), 'XÓA');
      await tester.pump();
      expect(confirmEnabled(tester), isTrue);
    });

    testWidgets('Giữ tài khoản closes without calling the server', (
      tester,
    ) async {
      final a = _Acct();
      final s = (await tester.runAsync(() => _signedIn(a, {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      await tester.tap(find.byKey(const Key('delete-cancel')));
      await tester.pump();
      expect(s.deleteAccountOpen, isFalse);
      expect(a.calls, 0);
      expect(s.signedIn, isTrue);
    });

    testWidgets('shows the Pha lê count only above 0', (tester) async {
      final s = (await tester.runAsync(() => _signedIn(_Acct(), {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      expect(find.byKey(const Key('delete-phale')), findsNothing);

      s.state.phaLe = 1250;
      s.openDeleteAccount();
      await tester.pump();
      expect(find.byKey(const Key('delete-phale')), findsOneWidget);
      expect(find.text(DeleteText.phale(1250)), findsOneWidget);
      expect(find.textContaining('1.250 Pha lê'), findsOneWidget);
    });

    testWidgets('iOS: no Pha lê line and the iOS records note', (tester) async {
      iosAppOverride = true;
      final s = (await tester.runAsync(() => _signedIn(_Acct(), {})))!;
      s.state.phaLe = 99;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      expect(find.byKey(const Key('delete-phale')), findsNothing);
      expect(find.text(DeleteText.keptNoteIos), findsOneWidget);
      expect(find.text(DeleteText.keptNote), findsNothing);
    });

    testWidgets('blocked top-up shows the wait message and no email', (
      tester,
    ) async {
      final a = _Acct()
        ..failWith = const DeleteAccountException(DeleteFailure.blocked);
      final s = (await tester.runAsync(() => _signedIn(a, {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      await tester.enterText(find.byKey(const Key('delete-field')), 'XÓA');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text('Đơn nạp đang xử lý, thử lại sau ít phút.'),
          findsOneWidget);
      expect(find.text(DeleteText.blockedHint), findsOneWidget);
      expect(find.byKey(const Key('delete-email')), findsNothing);
      expect(find.byKey(const Key('delete-retry')), findsOneWidget);
    });

    testWidgets('confirm shows the backup note (180 days)', (tester) async {
      final s = (await tester.runAsync(() => _signedIn(_Acct(), {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      expect(find.byKey(const Key('delete-backup-note')), findsOneWidget);
      expect(find.text(DeleteText.backupNote), findsOneWidget);
      expect(DeleteText.backupNote, contains('180 ngày'));
    });

    testWidgets('iOS: blocked uses delete.fail.blocked, no top-up wording', (
      tester,
    ) async {
      iosAppOverride = true;
      final a = _Acct()
        ..failWith = const DeleteAccountException(DeleteFailure.blocked);
      final s = (await tester.runAsync(() => _signedIn(a, {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      await tester.enterText(find.byKey(const Key('delete-field')), 'XÓA');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text(DeleteText.failBlocked), findsOneWidget);
      expect(
        DeleteText.failBlocked,
        'Tài khoản đang có giao dịch chưa xong. Bạn đợi ít phút rồi thử lại nhé.',
      );
      expect(find.text(DeleteText.blocked), findsNothing);
      expect(find.byKey(const Key('delete-blocked-hint')), findsNothing);
      expect(find.byKey(const Key('delete-retry')), findsOneWidget);
    });

    testWidgets('network and partial failures: retry, partial offers email', (
      tester,
    ) async {
      final a = _Acct()
        ..failWith = const DeleteAccountException(DeleteFailure.network);
      final s = (await tester.runAsync(() => _signedIn(a, {})))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      await tester.enterText(find.byKey(const Key('delete-field')), 'XOA');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text(DeleteText.failNetwork), findsOneWidget);
      expect(find.byKey(const Key('delete-email')), findsNothing);

      a.failWith = const DeleteAccountException(DeleteFailure.partial);
      await tester.tap(find.byKey(const Key('delete-retry')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(find.text(DeleteText.failPartial), findsOneWidget);
      expect(find.byKey(const Key('delete-email')), findsOneWidget);
    });

    testWidgets('success leaves the account and shows Đã xóa xong', (
      tester,
    ) async {
      final backing = <String, String>{};
      final a = _Acct();
      final s = (await tester.runAsync(() => _signedIn(a, backing)))!;
      s.openDeleteAccount();
      await pumpDialog(tester, s);
      await tester.enterText(find.byKey(const Key('delete-field')), 'XÓA');
      await tester.pump();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
      expect(a.calls, 1);
      expect(s.signedIn, isFalse);
      expect(s.deleteDone, isTrue);

      await tester.pumpWidget(
        _host(DeleteDoneDialog(session: s)),
      );
      expect(find.text(DeleteText.doneTitle), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-done-close')));
      await tester.pump();
      expect(s.deleteDone, isFalse);
    });
  });

  group('terms version 3', () {
    test('termsVersion is 3 and version 2 consent is outdated', () {
      expect(termsVersion, 3);
      final old = TermsConsent(version: 2, acceptedAt: DateTime(2026, 9, 29));
      expect(old.isCurrent, isFalse);
      final now = TermsConsent(version: 3, acceptedAt: DateTime(2026, 10, 11));
      expect(now.isCurrent, isTrue);
    });

    test('a saved version-2 consent asks again', () async {
      final backing = <String, String>{
        ProgressStore.termsKey: TermsConsent(
          version: 2,
          acceptedAt: DateTime(2026, 9, 29),
        ).encode(),
      };
      final back = await ProgressStore.memory(backing).loadTerms();
      expect(back!.isCurrent, isFalse);
    });

    test('summary lines: Nhất 8b, web/Android and iOS variants', () {
      expect(termsSummaryFor(ios: false), termsSummary);
      expect(termsSummary, hasLength(5));
      expect(termsSummaryIos, hasLength(5));
      final web = termsSummary.join('\n');
      expect(web, contains('16 tuổi'));
      expect(web, isNot(contains('18 tuổi')));
      expect(web, isNot(contains('giữ tiến trình')));
      expect(web, contains('Nạp Pha lê chỉ có trên bản web'));
      expect(web, contains('Bản web dùng cookie'));

      final ios = termsSummaryFor(ios: true);
      expect(ios, termsSummaryIos);
      final joined = ios.join('\n');
      expect(joined, contains('16 tuổi'));
      for (final banned in ['nạp', 'Nạp', 'mua bằng tiền thật', 'cookie']) {
        expect(joined, isNot(contains(banned)), reason: banned);
      }
      expect(joined, contains('xóa được tài khoản và dữ liệu'));
      // Lines 2 and 4 are the same on every platform.
      expect(ios[1], termsSummary[1]);
      expect(ios[3], termsSummary[3]);
    });

    test('the iOS variant follows the platform, never the web build', () {
      // Flutter tests run as Android by default: not iOS.
      expect(termsSummaryFor(), termsSummary);
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(termsSummaryFor(), termsSummaryIos);
    });
  });
}
