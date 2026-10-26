import 'package:ai_game/logic/platform_flags.dart';
import 'package:ai_game/logic/welfare_slides.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Pha le top-up is closed on every platform (An, 26/10/2026), and the
/// supporters board (Dai thien nhan) is back. See platform_flags.dart.
void main() {
  tearDown(() {
    phaLeTopUpOverride = null;
    distributionOverride = null;
    iosAppOverride = null;
    androidAppOverride = null;
    supportersEnabledOverride = null;
  });

  test('no top-up on web, Android open, Android amazon or iOS', () {
    for (final ios in [false, true]) {
      for (final dist in ['open', 'amazon']) {
        iosAppOverride = ios;
        androidAppOverride = !ios;
        distributionOverride = dist;
        expect(phaLeTopUpOffered, isFalse, reason: 'ios=$ios $dist');
      }
    }
    iosAppOverride = false;
    androidAppOverride = false;
    distributionOverride = 'open';
    expect(phaLeTopUpOffered, isFalse, reason: 'web');
  });

  test('the supporters board is on for web and Android, off on iOS', () {
    iosAppOverride = false;
    expect(supportersEnabled, isTrue);
    expect(welfareRoutes.containsKey('donors'), isTrue);
    iosAppOverride = true;
    expect(supportersEnabled, isFalse);
    expect(welfareRoutes.containsKey('donors'), isFalse);
    final s = newSession();
    final before = s.screen;
    s.openDonors();
    expect(s.screen, before);
  });

  testWidgets('iOS Cai dat: no Ung ho row', (tester) async {
    iosAppOverride = true;
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = newSession()..showTitle();
    await tester.pumpWidget(MaterialApp(home: SettingsPopup(session: s)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('settings-donate')), findsNothing);
  });

  test('openPhaleShop and the VIP top-up do nothing', () {
    final s = newSession();
    s.state.phaLe = 300;
    s.openPhaleShop();
    expect(s.phaleShopOpen, isFalse);
    s.openPhaleShop(need: 50, name: 'x');
    expect(s.phaleShopOpen, isFalse);
    s.vip.topUp();
    expect(s.phaleShopOpen, isFalse);
    expect(s.state.phaLe, 300); // the Pha le a player has stays
  });

  test('iOS never starts an App Store purchase', () async {
    iosAppOverride = true;
    final s = newSession();
    await s.buyPhaleWithApple();
    expect(s.phaleShopOpen, isFalse);
  });

  testWidgets('Cai dat: no shop row, the Ung ho row is back', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = newSession()..showTitle();
    await tester.pumpWidget(MaterialApp(home: SettingsPopup(session: s)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('settings-phale-open')), findsNothing);
    expect(find.byKey(const Key('settings-donate')), findsOneWidget);
  });
}
