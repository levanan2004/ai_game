import 'package:ai_game/data/phale_shop.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/common.dart';
import 'package:ai_game/ui/pet_item_shop.dart';
import 'package:ai_game/ui/phale_popups.dart';
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:ai_game/ui/settings_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

ShopSession _session({
  bool open = true,
  bool signedIn = true,
  PhaleGateway? gateway,
}) {
  final s = newSession(
    data: loadTestData(economy: phaleEconomy(open: open)),
  );
  if (signedIn) s.accountUid = 'me';
  s.state.phaLe = 250;
  s.phaleAutoPoll = false;
  if (gateway != null) s.phaleGateway = gateway;
  return s;
}

/// The game root's two overlays, in the order game_root stacks them.
Future<void> _pump(WidgetTester tester, ShopSession s, {Widget? under}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Stack(
        children: [
          ?under,
          ListenableBuilder(
            listenable: s,
            builder: (context, _) => Stack(
              children: [
                if (s.phaleShopOpen)
                  Positioned.fill(child: PhaleShopHost(session: s)),
                if (s.phaleShort != null)
                  Positioned.fill(child: PhaleShortPopup(session: s)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
  addTearDown(s.phaleShop.leave);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
}

Future<void> _toastGone(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 3));

void main() {
  setUpAll(loadTestFonts);

  testWidgets('S1: six packs, the best one tagged, 100 has no bonus chip', (
    tester,
  ) async {
    final s = _session()..openPhaleShop();
    await _pump(tester, s);
    for (final id in [
      'pack_10k',
      'pack_20k',
      'pack_50k',
      'pack_100k',
      'pack_200k',
      'pack_500k',
    ]) {
      expect(find.byKey(Key('phale-pack-$id')), findsOneWidget, reason: id);
    }
    expect(find.byKey(const Key('phale-best')), findsOneWidget);
    expect(find.text('+5%'), findsOneWidget);
    expect(find.text('+25%'), findsOneWidget);
    expect(find.text('6.250 Pha lê', findRichText: true), findsOneWidget);
    expect(find.text('500.000đ'), findsOneWidget);
    expect(find.byKey(const Key('phale-soon')), findsNothing);
    expect(find.byKey(const Key('phale-guest')), findsNothing);
    // No coin-to-Pha lê exchange anywhere.
    expect(find.textContaining('đổi'), findsNothing);
    // The shop's own pill has no plus.
    expect(find.byKey(const Key('topbar-pha-le-plus')), findsNothing);
  });

  testWidgets('S5c: closed shop says Sắp mở and makes no order', (
    tester,
  ) async {
    final s = _session(open: false)..openPhaleShop();
    await _pump(tester, s);
    expect(find.byKey(const Key('phale-soon')), findsOneWidget);
    expect(find.text('Sắp mở'), findsNWidgets(6));
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    expect(find.text('Chưa mở nạp. Bạn quay lại sau nhé.'), findsOneWidget);
    expect(find.byKey(const Key('phale-confirm')), findsNothing);
    expect(s.phaleShop.order, isNull);
    await _toastGone(tester);
  });

  testWidgets('S3: a guest sees the strip and cannot buy', (tester) async {
    final s = _session(signedIn: false)..openPhaleShop();
    await _pump(tester, s);
    expect(find.byKey(const Key('phale-guest')), findsOneWidget);
    expect(find.text('Cần đăng nhập để mua Pha lê'), findsOneWidget);
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    expect(find.text('Đăng nhập để mua Pha lê'), findsOneWidget);
    expect(find.byKey(const Key('phale-confirm')), findsNothing);
    await _toastGone(tester);
  });

  testWidgets('S2a → S2b → S6a, then Tôi đã chuyển never credits', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_50k'));
    await tester.pump();
    expect(find.text('Mua 550 Pha lê?'), findsOneWidget);
    expect(find.byKey(const Key('phale-confirm-price')), findsOneWidget);
    expect(find.text('50.000đ'), findsWidgets);
    expect(find.text('+10%'), findsWidgets);
    expect(
      find.textContaining('Dưới 16 tuổi, hãy nhờ bố mẹ đồng ý.'),
      findsOneWidget,
    );
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    // The transfer screen.
    expect(find.byKey(const Key('phale-order')), findsOneWidget);
    final order = s.phaleShop.order!;
    expect(find.text(order.transferContent), findsOneWidget);
    expect(find.byKey(const Key('phale-qr')), findsOneWidget);
    expect(find.byKey(const Key('phale-qr-fake')), findsOneWidget);
    expect(find.text('Đang chờ tiền về'), findsOneWidget);
    expect(find.byKey(const Key('phale-timer')), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-paid')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Chưa thấy tiền về. Chờ thêm chút nhé.'), findsOneWidget);
    expect(s.state.phaLe, 250);
    await _toastGone(tester);
  });

  testWidgets('S6a at 360x640: the buttons are pinned, the rest scrolls', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    final paid = tester.getRect(find.byKey(const Key('phale-paid')));
    expect(paid.bottom, lessThanOrEqualTo(640));
    expect(paid.height, 48);
    final cancel = tester.getRect(find.byKey(const Key('phale-second')));
    expect(cancel.height, greaterThanOrEqualTo(44));
    expect(cancel.bottom, lessThanOrEqualTo(640));
    // Pinned means it does not move when the content scrolls.
    await tester.drag(
      find.byKey(const Key('phale-order-scroll')),
      const Offset(0, -400),
    );
    await tester.pump();
    expect(tester.getRect(find.byKey(const Key('phale-paid'))), paid);
    expect(find.byKey(const Key('phale-memo-copy')), findsOneWidget);
  });

  testWidgets('the paid popup shows the server numbers, balance untouched', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_50k'));
    await tester.pump();
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    gw.force(
      s.phaleShop.order!.orderId,
      PhaleOrderStatus.paid,
      granted: 550,
      balance: 800,
    );
    await tester.tap(find.byKey(const Key('phale-paid')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đã nhận tiền!'), findsOneWidget);
    expect(find.text('+550'), findsOneWidget);
    expect(find.text('800'), findsOneWidget);
    // The app never writes the balance; the server's save does.
    expect(s.state.phaLe, 250);
    await tester.tap(find.byKey(const Key('phale-done-ok')));
    await tester.pump();
    expect(find.byKey(const Key('phale-shop')), findsOneWidget);
    await _toastGone(tester);
  });

  testWidgets('S6f and S2e: cancelling asks first, then says it is dead', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('phale-second')));
    await tester.pump();
    expect(find.text('Hủy đơn này?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-cancelask-no')));
    await tester.pump();
    expect(find.byKey(const Key('phale-cancelask')), findsNothing);
    expect(s.phaleShop.order, isNotNull);
    await tester.tap(find.byKey(const Key('phale-second')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('phale-cancelask-yes')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Đơn đã hủy'), findsOneWidget);
    expect(find.byKey(const Key('phale-cancelled-new')), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-cancelled-new')));
    await tester.pump();
    expect(find.text('Mua 100 Pha lê?'), findsOneWidget);
  });

  testWidgets('S6g: leaving keeps the order, S1 offers Xem đơn', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('phale-order-back')));
    await tester.pump();
    expect(find.byKey(const Key('phale-shop')), findsOneWidget);
    expect(find.byKey(const Key('phale-pending')), findsOneWidget);
    expect(find.text('Bạn có đơn đang chờ'), findsOneWidget);
    await tester.tap(find.text('Xem đơn'));
    await tester.pump();
    expect(find.byKey(const Key('phale-order')), findsOneWidget);
  });

  testWidgets('S6c and S6d: expired and mismatch have their own screens', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    gw.force(s.phaleShop.order!.orderId, PhaleOrderStatus.mismatch);
    await s.phaleShop.poll();
    await tester.pump();
    expect(find.byKey(const Key('phale-mismatch')), findsOneWidget);
    expect(find.text('Chưa khớp đơn'), findsWidgets);
    expect(find.text('Liên hệ hỗ trợ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-second')));
    await tester.pump();
    expect(find.byKey(const Key('phale-shop')), findsOneWidget);
  });

  testWidgets('S6e: offline shows the banner and dims the button', (
    tester,
  ) async {
    final gw = DemoPhaleGateway(config: loadTestData().economy.phaLeShop);
    final s = _session(gateway: gw)..openPhaleShop();
    await _pump(tester, s);
    await _tap(tester, const Key('phale-buy-pack_10k'));
    await tester.pump();
    await _tap(tester, const Key('phale-confirm-yes'));
    await tester.pump();
    await tester.pump();
    gw.offline = true;
    await s.phaleShop.poll();
    await tester.pump();
    expect(find.byKey(const Key('phale-offline')), findsOneWidget);
    expect(find.text('Đang thử lại…'), findsOneWidget);
    // The QR and the transfer data stay.
    expect(find.byKey(const Key('phale-qr')), findsOneWidget);
    expect(find.byKey(const Key('phale-memo-code')), findsOneWidget);
  });

  testWidgets('S4b/S4c: short of Pha lê → top-up popup → shop with banner', (
    tester,
  ) async {
    final s = _session();
    await _pump(tester, s);
    s.askPhaleShort('Cánh bình minh', 300);
    await tester.pump();
    expect(find.text('Mua Cánh bình minh?'), findsOneWidget);
    expect(find.text('Thiếu 50 Pha lê'), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-short-cta')));
    await tester.pump();
    expect(s.phaleShort, isNull);
    expect(s.phaleShopOpen, isTrue);
    expect(
      find.text('Cần thêm 50 Pha lê để mua Cánh bình minh'),
      findsOneWidget,
    );
  });

  testWidgets('a short Pha lê item buy opens the popup, not a tooltip', (
    tester,
  ) async {
    final s = _session();
    s.state.day = strayCatDay;
    s.state.hasCat = true;
    s.state.addPet('meo');
    // Chuông ngọc costs 120 Pha lê; the player has 100.
    s.state.phaLe = 100;
    s.openPetItemShop(slot: 'neck');
    await _pump(tester, s, under: PetItemShopScreen(session: s));
    await _tap(tester, const Key('item-shop-buy-chuong_ngoc'));
    await tester.pump();
    expect(s.phaleShort, isNotNull);
    expect(find.byKey(const Key('phale-short')), findsOneWidget);
    expect(find.text('Thiếu 20 Pha lê'), findsOneWidget);
  });

  testWidgets('the Pha lê pill carries a + and opens the shop', (tester) async {
    final s = _session();
    await _pump(
      tester,
      s,
      under: Align(
        alignment: Alignment.topLeft,
        child: TopBar(
          session: s,
          showRating: false,
          showDay: false,
          showPhaLe: true,
        ),
      ),
    );
    expect(find.byKey(const Key('topbar-pha-le-plus')), findsOneWidget);
    await tester.tap(find.byKey(const Key('topbar-pha-le')));
    await tester.pump();
    expect(s.phaleShopOpen, isTrue);
    expect(find.byKey(const Key('phale-shop')), findsOneWidget);
  });

  testWidgets('Cài đặt has one row that opens the shop', (tester) async {
    final s = _session();
    await _pump(tester, s, under: SettingsPopup(session: s));
    expect(find.text('Cửa hàng Pha lê'), findsOneWidget);
    expect(find.text('Nạp Pha lê bằng tiền thật'), findsOneWidget);
    // The row sits in a scrolling card: call its handler (the tap target is
    // a plain GestureDetector, 44dp tall).
    tester
        .widget<GestureDetector>(find.byKey(const Key('settings-phale-open')))
        .onTap!();
    await tester.pump();
    expect(s.phaleShopOpen, isTrue);
  });
}
