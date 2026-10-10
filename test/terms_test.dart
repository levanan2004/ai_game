import 'package:ai_game/logic/shop_name.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/main.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/save/terms_consent.dart';
import 'package:ai_game/ui/terms_screen.dart';
import 'dart:io';

import 'package:ai_game/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

Future<void> _boot(
  WidgetTester tester,
  Map<String, String> backing, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ShopApp(data: loadTestData(), store: ProgressStore.memory(backing)),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The real fonts, so line wraps match the game (tests default to a
/// square test font that is much wider).
Future<void> _loadFonts() async {
  const fonts = {
    AppFonts.body: 'assets/fonts/nunito/Nunito-VariableFont_wght.ttf',
    AppFonts.display: 'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
  };
  for (final e in fonts.entries) {
    final bytes = File(e.value).readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

/// A committed day-3 save with a name, as a returning player has.
Map<String, String> _savedProgress() {
  final s = newSession();
  s.state.shopName = 'Hoa Ơi';
  s.state.day = 3;
  return {ProgressStore.storageKey: s.state.encode()};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  group('session', () {
    test('without consent the title buttons open the terms first', () {
      final s = newSession(acceptedTerms: false);
      s.showTitle();
      expect(s.termsMode, TermsMode.accept);
      expect(s.termsOutdated, isFalse);

      s.postponeTerms();
      expect(s.termsMode, isNull);
      expect(s.termsLaterOpen, isTrue);
      expect(s.screen, Screen.title);
      expect(s.terms, isNull);

      s.closeTermsLater();
      s.requestNewGame();
      expect(s.termsMode, TermsMode.accept);
      expect(s.namePrompt, isNull);

      s.acceptTerms();
      expect(s.termsAccepted, isTrue);
      expect(s.termsMode, isNull);
      expect(s.namePrompt, ShopNameMode.start);
    });

    test('accepting stores version, time with offset and age flag', () async {
      final backing = <String, String>{};
      final s = newSession(backing: backing, acceptedTerms: false);
      s.showTitle();
      s.acceptTerms();
      await s.pendingSaves;
      final raw = backing[ProgressStore.termsKey]!;
      expect(
        raw,
        matches(r'"acceptedAt":"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d"'),
      );
      expect(raw, contains('"version":$termsVersion'));
      expect(raw, contains('"age16Confirmed":true'));
      final back = await ProgressStore.memory(backing).loadTerms();
      expect(back!.isCurrent, isTrue);
      expect(back.age16Confirmed, isTrue);
      expect(back.acceptedDate, s.terms!.acceptedDate);
    });

    test('Để sau saves nothing and keeps progress', () async {
      final backing = _savedProgress();
      final before = backing[ProgressStore.storageKey];
      final s = newSession(
        backing: backing,
        saved: GameState.decode(before),
        acceptedTerms: false,
      );
      s.showTitle();
      s.postponeTerms();
      await s.pendingSaves;
      expect(backing.containsKey(ProgressStore.termsKey), isFalse);
      expect(backing[ProgressStore.storageKey], before);
      expect(s.hasSave, isTrue);
      s.continueFromTitle();
      expect(s.termsMode, TermsMode.accept);
      expect(s.screen, Screen.title);
    });

    test('ISO time keeps the offset and shows as dd/MM/yyyy', () {
      final t = DateTime(2026, 9, 29, 15, 47);
      final iso = isoWithOffset(t);
      expect(iso, startsWith('2026-09-29T15:47:00'));
      expect(DateTime.parse(iso).isAtSameMomentAs(t), isTrue);
      final c = TermsConsent(version: 1, acceptedAt: t);
      final back = TermsConsent.decode(c.encode())!;
      expect(back.acceptedAt.isAtSameMomentAs(t), isTrue);
      expect(back.acceptedDate, '29/09/2026');
      expect(TermsConsent.decode(null), isNull);
      expect(TermsConsent.decode('{'), isNull);
      expect(TermsConsent.decode('{"version":"1.0"}'), isNull);
    });
  });

  group('screen', () {
    testWidgets('first launch: terms before naming, checkbox gates the key', (
      tester,
    ) async {
      final backing = <String, String>{};
      await _boot(tester, backing);
      expect(find.byKey(const Key('terms-title')), findsOneWidget);
      expect(find.text(termsTitle), findsOneWidget);
      expect(find.text(termsOpening), findsOneWidget);
      expect(find.text(termsHintOff), findsOneWidget);
      expect(find.byKey(const Key('shop-name-field')), findsNothing);

      // Disabled: nothing happens except the checkbox row shaking.
      final rest = tester.getTopLeft(find.byKey(const Key('terms-checkbox')));
      await tester.tap(find.byKey(const Key('terms-accept-off')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final moved = tester.getTopLeft(find.byKey(const Key('terms-checkbox')));
      expect(moved.dx, isNot(rest.dx));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.getTopLeft(find.byKey(const Key('terms-checkbox'))).dx,
        rest.dx,
      );
      expect(find.byKey(const Key('terms-title')), findsOneWidget);
      expect(backing.containsKey(ProgressStore.termsKey), isFalse);

      await tester.tap(find.byKey(const Key('terms-checkbox')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(termsHintOn), findsOneWidget);
      await tester.tap(find.byKey(const Key('terms-accept')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('terms-title')), findsNothing);
      expect(find.byKey(const Key('shop-name-field')), findsOneWidget);
      expect(backing.containsKey(ProgressStore.termsKey), isTrue);
    });

    testWidgets('Để sau: popup over the title, Đọc lại reopens the terms', (
      tester,
    ) async {
      await _boot(tester, {});
      await tester.tap(find.byKey(const Key('terms-later')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('terms-title')), findsNothing);
      expect(find.text('Tiệm vẫn chờ bạn'), findsOneWidget);
      await tester.tap(find.byKey(const Key('terms-reread')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('terms-title')), findsOneWidget);
      // Ticked state starts over on a new visit.
      expect(find.byKey(const Key('terms-accept-off')), findsOneWidget);

      await tester.tap(find.byKey(const Key('terms-later')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tapAt(const Offset(195, 120));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Tiệm vẫn chờ bạn'), findsNothing);
      await tester.tap(find.byKey(const Key('title-main')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('terms-title')), findsOneWidget);
      expect(find.byKey(const Key('shop-name-field')), findsNothing);
    });

    testWidgets('an older version asks again; the old guest save is ignored', (
      tester,
    ) async {
      final oldGuest = _savedProgress()[ProgressStore.storageKey];
      final backing = _savedProgress()
        ..[ProgressStore.termsKey] = TermsConsent(
          version: termsVersion - 1,
          acceptedAt: DateTime(2026, 1, 2),
        ).encode();
      await _boot(tester, backing);
      expect(find.text(termsUpdatedOpening), findsOneWidget);
      expect(find.byKey(const Key('terms-accept-off')), findsOneWidget);
      await tester.tap(find.byKey(const Key('terms-checkbox')));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const Key('terms-accept')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('terms-title')), findsNothing);
      // Guest play is no longer saved or loaded: the old guest slot is
      // ignored (left as it was), so accepting goes on to naming.
      expect(find.byKey(const Key('shop-name-field')), findsOneWidget);
      expect(backing[ProgressStore.storageKey], oldGuest);
      final terms = TermsConsent.decode(backing[ProgressStore.termsKey])!;
      expect(terms.isCurrent, isTrue);
    });

    testWidgets('current consent skips the terms screen', (tester) async {
      await _boot(tester, withTerms());
      expect(find.byKey(const Key('terms-title')), findsNothing);
      expect(find.byKey(const Key('title-main')), findsOneWidget);
    });

    testWidgets('Cài đặt shows the date and Xem lại is read-only', (
      tester,
    ) async {
      final backing = <String, String>{
        ProgressStore.termsKey: TermsConsent(
          version: termsVersion,
          acceptedAt: DateTime(2026, 9, 29, 15, 47),
        ).encode(),
      };
      await _boot(tester, backing);
      await tester.tap(find.byKey(const Key('topbar-pause')));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(
        find.byKey(const Key('settings-terms-review')),
        80,
      );
      expect(find.text('Điều khoản'), findsOneWidget);
      expect(find.text('Đã đồng ý ngày 29/09/2026'), findsOneWidget);
      await tester.tap(find.byKey(const Key('settings-terms-review')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const Key('terms-title')), findsOneWidget);
      expect(find.text(termsOpening), findsOneWidget);
      expect(find.byKey(const Key('terms-link-terms')), findsOneWidget);
      expect(find.byKey(const Key('terms-link-privacy')), findsOneWidget);
      expect(find.byKey(const Key('terms-checkbox')), findsNothing);
      expect(find.byKey(const Key('terms-later')), findsNothing);
      expect(find.text(termsAcceptLabel), findsNothing);
      await tester.tap(find.byKey(const Key('terms-close')));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byKey(const Key('terms-title')), findsNothing);
      expect(find.byKey(const Key('settings-popup')), findsOneWidget);
      final stored = TermsConsent.decode(backing[ProgressStore.termsKey])!;
      expect(stored.acceptedDate, '29/09/2026');
    });

    testWidgets('fits a 360-wide frame and the summary scrolls', (
      tester,
    ) async {
      await tester.runAsync(_loadFonts);
      await _boot(tester, {}, size: const Size(360, 640));
      expect(tester.takeException(), isNull);
      final box = tester.getRect(find.byKey(const Key('terms-summary')));
      expect(box.height, greaterThan(120));
      expect(
        find.descendant(
          of: find.byKey(const Key('terms-summary')),
          matching: find.byType(SingleChildScrollView),
        ),
        findsOneWidget,
      );
      for (final k in ['terms-checkbox', 'terms-accept-off', 'terms-later']) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(r.height, greaterThanOrEqualTo(44), reason: k);
        expect(r.bottom, lessThanOrEqualTo(640), reason: k);
      }
    });
  });
}
