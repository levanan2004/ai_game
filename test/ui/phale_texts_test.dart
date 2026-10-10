import 'package:ai_game/data/phale_shop.dart';
import 'package:ai_game/logic/phale_shop_controller.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/phale_popups.dart';
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:ai_game/ui/phale_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

/// The seven texts Nhất approved (each at most 90 characters).
const _approved = {
  'phale.confirm.qr':
      'Chuyển khoản qua mã QR. Pha lê vào ví khi tiệm nhận được tiền.',
  'phale.expired.title': 'Mã này đã hết hạn, đừng chuyển thêm.',
  'phale.expired.hint':
      'Đã chuyển đúng rồi? Pha lê vẫn vào ví khi tiền về. Chờ lâu thì gửi mã đơn cho hỗ trợ:',
  'phale.cancelled.body':
      'Mã QR cũ đã hết hiệu lực. Đừng chuyển tiền vào mã cũ.',
  'phale.cancelled.hint':
      'Đã chuyển rồi? Pha lê vẫn vào ví khi tiền về. Chờ lâu thì gửi mã đơn cho hỗ trợ.',
  'phale.mismatch.body':
      'Tiệm thấy tiền về nhưng số tiền hoặc nội dung chưa khớp đơn, nên chưa cộng Pha lê.',
  'phale.mismatch.foot': 'Gửi mã đơn cho hỗ trợ, tiệm sẽ kiểm tra rồi báo bạn.',
};

Future<(ShopSession, DemoPhaleGateway)> _order(
  WidgetTester tester, {
  Duration lifetime = const Duration(minutes: 15),
}) async {
  final economy = loadTestData(economy: phaleEconomy()).economy;
  final gw = DemoPhaleGateway(config: economy.phaLeShop, lifetime: lifetime);
  final s = newSession(data: loadTestData(economy: phaleEconomy()))
    ..accountUid = 'me'
    ..phaleAutoPoll = false
    ..phaleGateway = gw;
  s.state.phaLe = 250;
  s.openPhaleShop();
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: s,
        builder: (context, _) => Stack(
          children: [
            if (s.phaleShopOpen)
              Positioned.fill(child: PhaleShopHost(session: s)),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  addTearDown(s.phaleShop.leave);
  await tester.tap(find.byKey(const Key('phale-buy-pack_10k')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('phale-confirm-yes')));
  await tester.pump();
  await tester.pump();
  return (s, gw);
}

double _scrollable(WidgetTester tester) => tester
    .state<ScrollableState>(
      find.descendant(
        of: find.byKey(const Key('phale-order-scroll')),
        matching: find.byType(Scrollable),
      ),
    )
    .position
    .maxScrollExtent;

void main() {
  setUpAll(loadTestFonts);

  test('the seven approved texts are in the code, exactly', () {
    final now = {
      'phale.confirm.qr': PhaleText.confirmQr,
      'phale.expired.title': PhaleText.expiredTitle,
      'phale.expired.hint': PhaleText.expiredHint,
      'phale.cancelled.body': PhaleText.cancelledBody,
      'phale.cancelled.hint': PhaleText.cancelledHint,
      'phale.mismatch.body': PhaleText.mismatchBody,
      'phale.mismatch.foot': PhaleText.mismatchFoot,
    };
    expect(now, _approved);
    for (final e in now.entries) {
      expect(e.value.length, lessThanOrEqualTo(90), reason: e.key);
    }
    // Other keys keep their text.
    expect(PhaleText.note, 'Pha lê chỉ mua bằng tiền thật, không đổi qua xu.');
  });

  test(
    'Liên hệ hỗ trợ is a mail to the Liên hệ address with the order code',
    () {
      expect(PhaleText.supportEmail, 'anxaitech@gmail.com');
      final uri = Uri.parse(PhaleText.supportMailto('THSMK7P2Q9XABC'));
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'anxaitech@gmail.com');
      expect(uri.queryParameters['subject'], contains('THSMK7P2Q9XABC'));
      expect(uri.queryParameters['body'], contains('THSMK7P2Q9XABC'));
    },
  );

  testWidgets('S6c at 360x640: expired text, no overflow, no scrolling', (
    tester,
  ) async {
    final (s, _) = await _order(tester, lifetime: const Duration(seconds: -5));
    await s.phaleShop.poll();
    await tester.pump();
    expect(find.byKey(const Key('phale-expired')), findsOneWidget);
    expect(find.text(PhaleText.expiredTitle), findsOneWidget);
    expect(find.text(PhaleText.expiredHint), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(_scrollable(tester), 0);
    final hint = tester.getRect(find.text(PhaleText.expiredHint));
    expect(hint.height, lessThanOrEqualTo(3 * 16.0));
    expect(
      tester.getRect(find.byKey(const Key('phale-paid'))).bottom,
      lessThanOrEqualTo(640),
    );
  });

  testWidgets('S6d at 360x640: mismatch text, no overflow, no scrolling', (
    tester,
  ) async {
    final (s, gw) = await _order(tester);
    gw.force(s.phaleShop.order!.orderId, PhaleOrderStatus.mismatch);
    await s.phaleShop.poll();
    await tester.pump();
    expect(find.byKey(const Key('phale-mismatch')), findsOneWidget);
    expect(find.text(PhaleText.mismatchBody), findsOneWidget);
    expect(find.text(PhaleText.mismatchFoot), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(_scrollable(tester), 0);
    expect(
      tester.getRect(find.byKey(const Key('phale-paid'))).bottom,
      lessThanOrEqualTo(640),
    );
  });

  testWidgets('S2e at 360x640: the cancelled popup fits with its new lines', (
    tester,
  ) async {
    final (s, _) = await _order(tester);
    s.phaleShop.askCancel();
    await tester.pump();
    await tester.tap(find.byKey(const Key('phale-cancelask-yes')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(PhaleCancelledPopup), findsOneWidget);
    expect(find.text(PhaleText.cancelledBody), findsOneWidget);
    expect(find.text(PhaleText.cancelledHint), findsOneWidget);
    expect(tester.takeException(), isNull);
    final box = tester.getRect(find.byType(PhaleCancelledPopup));
    expect(box.bottom, lessThanOrEqualTo(640));
    expect(box.left, greaterThanOrEqualTo(0));
    expect(box.right, lessThanOrEqualTo(360));
  });

  testWidgets('S2a at 360x640: the confirm popup shows the new QR line', (
    tester,
  ) async {
    final economy = loadTestData(economy: phaleEconomy()).economy;
    final s = newSession(data: loadTestData(economy: phaleEconomy()))
      ..accountUid = 'me'
      ..phaleAutoPoll = false
      ..phaleGateway = DemoPhaleGateway(config: economy.phaLeShop);
    s.openPhaleShop();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [Positioned.fill(child: PhaleShopHost(session: s))],
        ),
      ),
    );
    await tester.pump();
    addTearDown(s.phaleShop.leave);
    await tester.tap(find.byKey(const Key('phale-buy-pack_10k')));
    await tester.pump();
    expect(find.textContaining(PhaleText.confirmQr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('the duplicate-transfer notice text is the approved one', () {
    expect(PhaleText.duplicateTitle, 'Chuyển khoản trùng');
    expect(
      PhaleText.duplicateBody,
      'Tiệm thấy hai lần chuyển cho cùng một đơn. Tiệm sẽ kiểm tra rồi báo bạn.',
    );
    expect(PhaleText.duplicateBody.length, lessThan(90));
    // No promise of a refund, and no word about late or cancelled money.
    expect(PhaleText.duplicateBody, isNot(contains('hoàn')));
  });

  testWidgets(
    'paid popup: a duplicate transfer shows the notice, 360x640 fits',
    (tester) async {
      final (s, gw) = await _order(tester);
      final id = s.phaleShop.order!.orderId;
      gw.force(id, PhaleOrderStatus.paid, granted: 550, balance: 800);
      await s.phaleShop.poll();
      await tester.pump();
      expect(find.byKey(const Key('phale-done')), findsOneWidget);
      expect(find.byKey(const Key('phale-duplicate')), findsNothing);

      // The popup is still open and the screen keeps asking: the notice shows.
      gw.force(
        id,
        PhaleOrderStatus.paid,
        granted: 550,
        balance: 800,
        duplicate: true,
      );
      await s.phaleShop.poll();
      await tester.pump();
      expect(find.byKey(const Key('phale-duplicate')), findsOneWidget);
      expect(find.text(PhaleText.duplicateTitle), findsOneWidget);
      expect(find.text(PhaleText.duplicateBody), findsOneWidget);
      // The numbers of the paid popup stay.
      expect(find.byKey(const Key('phale-done-added')), findsOneWidget);
      expect(find.byKey(const Key('phale-done-balance')), findsOneWidget);
      expect(tester.takeException(), isNull);
      final panel = tester.getRect(find.byKey(const Key('phale-done')));
      expect(panel.top, greaterThanOrEqualTo(0));
      expect(panel.bottom, lessThanOrEqualTo(640));
      expect(panel.left, greaterThanOrEqualTo(0));
      expect(panel.right, lessThanOrEqualTo(360));
      expect(
        tester.getRect(find.byKey(const Key('phale-done-ok'))).bottom,
        lessThanOrEqualTo(640),
      );
    },
  );

  testWidgets('the paid popup keeps its balance when the duplicate arrives', (
    tester,
  ) async {
    final (s, gw) = await _order(tester);
    final id = s.phaleShop.order!.orderId;
    gw.force(id, PhaleOrderStatus.paid, granted: 550, balance: 800);
    await s.phaleShop.poll();
    expect(s.phaleShop.order!.newBalance, 800);
    gw.force(id, PhaleOrderStatus.paid, granted: 550, duplicate: true);
    await s.phaleShop.poll();
    expect(s.phaleShop.step, PhaleStep.done);
    expect(s.phaleShop.order!.duplicatePayment, isTrue);
    expect(s.phaleShop.order!.newBalance, 800);
    expect(s.phaleShop.order!.crystalsGranted, 550);
  });
}
