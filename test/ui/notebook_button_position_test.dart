import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/delivery.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/main_shop_overlay.dart';
import 'package:ai_game/ui/so_tay_screen.dart';
import 'package:ai_game/ui/world_chat_ticker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'so_tay_screen_test.dart' show soTaySession;

OnlineOrder sameDayOffer() => OnlineOrder(
  id: 9001,
  kind: OrderKind.sameday,
  customerName: 'An',
  avatarId: 'lan_anh',
  request: const BouquetRequest(
    occasionId: 'thanks',
    stems: {'rose': 3},
    paperId: 'kraft',
    ribbonId: 'twine',
  ),
  line: '3 hoa hồng',
  speech: 'Giao giúp mình trước giờ đóng cửa nhé!',
  deadline: 120,
  spawnAt: 0,
  acceptLeft: 20,
);

Future<ValueNotifier<int>> _pump(WidgetTester tester, ShopSession s) async {
  await tester.binding.setSurfaceSize(const Size(360, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final bump = ValueNotifier(0);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: Listenable.merge([s, bump]),
          builder: (_, _) => MainShopOverlay(session: s),
        ),
      ),
    ),
  );
  await tester.pump();
  return bump;
}

Rect _button(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('notebook-button')));

void main() {
  testWidgets('no Same-Day card: button at (12,56)', (tester) async {
    final s = soTaySession();
    expect(s.incomingSameDay, isNull);
    expect(notebookButtonTop(s), 56);
    await _pump(tester, s);
    expect(_button(tester).topLeft, const Offset(12, 56));
    expect(_button(tester).size, const Size(44, 44));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Same-Day card: slides 8dp under it in 200ms, badge follows', (
    tester,
  ) async {
    final s = soTaySession();
    expect(s.notebookBadgeCount, greaterThan(0));
    final bump = await _pump(tester, s);
    s.onlineOrders.add(sameDayOffer());
    bump.value++;
    await tester.pump();
    final push = WorldChatTicker.on(s) ? WorldChatTicker.push : 0.0;
    final target = sameDayTop + push + sameDayHeight + 8;
    expect(notebookButtonTop(s), target);
    // Mid-slide, then settled after 200ms.
    await tester.pump(const Duration(milliseconds: 100));
    final mid = _button(tester).top;
    expect(mid, greaterThan(56));
    expect(mid, lessThan(target));
    await tester.pump(const Duration(milliseconds: 120));
    expect(_button(tester).topLeft, Offset(12, target));
    await tester.pump(const Duration(milliseconds: 400));
    final card = tester.getRect(find.byKey(const Key('sameday-card')));
    expect(_button(tester).top, card.bottom + 8);
    // The badge rides on the button's top-right corner.
    final badge = tester.getRect(find.byType(NotebookBadge));
    expect(badge.right, closeTo(_button(tester).right + 4, 0.01));
    expect(badge.top, closeTo(_button(tester).top - 4, 0.01));

    // Card gone: back to (12,56).
    s.onlineOrders.clear();
    bump.value++;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(_button(tester).topLeft, const Offset(12, 56));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpWidget(const SizedBox());
  });
}
