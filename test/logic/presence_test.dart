import 'package:ai_game/logic/presence.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('online label is count now over everyone who has played', () {
    expect(onlineCrowdLabel(null, null), 'Đang online …');
    expect(onlineCrowdLabel(3, 12), 'Đang online 3/12');
  });

  testWidgets('settings shows the online crowd line', (tester) async {
    final s = newSession();
    s.presence = _QuietPresence();
    s.onlineNow = 3;
    s.playersEver = 12;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 360,
            height: 640,
            child: SettingsPopup(session: s),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Đang online 3/12'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    s.dispose();
  });
}

class _QuietPresence implements PresenceClient {
  @override
  Future<CrowdCounts> counts() async => const CrowdCounts(online: 0, ever: 0);

  @override
  Future<String> identity(String? uid) async => 'guest-id';

  @override
  Future<void> pulse(String id) async {}
}
