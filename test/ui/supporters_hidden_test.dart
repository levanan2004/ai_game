import 'package:ai_game/logic/platform_flags.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/welfare_slides.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// "Đại thiện nhân" (supporters board + donation QR) is hidden behind
/// `supportersEnabled` in lib/logic/platform_flags.dart. Code, assets and
/// Firestore data stay; flip the flag to bring it back.
Future<void> _mount(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump(const Duration(seconds: 1));
}

ShopSession _summarySession() {
  final s = newSession();
  s.state.day = 2;
  s.state.money = 5000000;
  s.state.phase = DayPhase.summary;
  s.screen = Screen.summary;
  return s;
}

void main() {
  tearDown(() => supportersEnabledOverride = null);

  test('the supporters board is off in the build', () {
    expect(supportersEnabled, isFalse);
  });

  test('openDonors does nothing while hidden', () {
    final s = newSession();
    stockAndOpen(s);
    final screen = s.screen;
    s.openDonors();
    expect(s.screen, screen);
    expect(s.paused, isFalse);
  });

  test('welfare slides cannot link to the hidden board', () {
    expect(welfareRoutes.containsKey('donors'), isFalse);
    expect(welfareRoutes.containsKey('garden'), isTrue);
    final slide = WelfareSlide.fromMap('s1', {
      'title': 'Ủng hộ',
      'linkType': 'route',
      'link': 'donors',
    });
    expect(slide!.linkType, SlideLinkType.none);
    supportersEnabledOverride = true;
    expect(welfareRoutes.containsKey('donors'), isTrue);
  });

  testWidgets('Cài đặt has no Ủng hộ row', (tester) async {
    final s = newSession()..showTitle();
    await _mount(tester, SettingsPopup(session: s));
    expect(find.byKey(const Key('settings-phale-open')), findsOneWidget);
    expect(find.byKey(const Key('settings-donate')), findsNothing);
  });

  testWidgets('Cài đặt shows the Ủng hộ row again when the flag is on', (
    tester,
  ) async {
    supportersEnabledOverride = true;
    final s = newSession()..showTitle();
    await _mount(tester, SettingsPopup(session: s));
    expect(find.byKey(const Key('settings-donate')), findsOneWidget);
  });

  testWidgets('the day summary has no donate strip', (tester) async {
    final s = _summarySession();
    await _mount(tester, SummaryScreen(session: s));
    expect(find.byKey(const Key('summary-donate')), findsNothing);
    expect(find.byKey(const Key('summary-donate-button')), findsNothing);
  });

  testWidgets('the day summary donate strip returns when the flag is on', (
    tester,
  ) async {
    supportersEnabledOverride = true;
    final s = _summarySession();
    await _mount(tester, SummaryScreen(session: s));
    expect(find.byKey(const Key('summary-donate')), findsOneWidget);
  });
}
