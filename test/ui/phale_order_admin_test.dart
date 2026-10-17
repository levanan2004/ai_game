import 'package:ai_game/data/firestore_phale_orders.dart';
import 'package:ai_game/logic/phale_order_admin.dart';
import 'package:ai_game/ui/phale_order_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryPhaleOrderAdmin _orders() => MemoryPhaleOrderAdmin(
  orders: [
    PhaleOrderRow(
      code: 'THSMAAA111',
      uid: 'alice',
      packId: 'pack_50k',
      amount: 50000,
      crystals: 6250,
      paidAt: DateTime(2026, 10, 15, 9, 30),
    ),
    PhaleOrderRow(
      code: 'THSMBBB222',
      uid: 'bob',
      amount: 500000,
      crystals: 70000,
      paidAt: DateTime(2026, 10, 16, 20, 5),
      refundedAt: DateTime(2026, 10, 17, 8),
      refundedBy: 'admin',
      clawback: 'wallet',
      phaleTaken: 40000,
      phaleDebt: 30000,
    ),
  ],
);

Future<void> _open(
  WidgetTester tester,
  PhaleOrderAdmin orders, {
  VoidCallback? onClose,
}) async {
  await tester.binding.setSurfaceSize(const Size(480, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PhaleOrderAdminPanel(orders: orders, onClose: onClose ?? () {}),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets(
    'lists paid orders newest first; a refunded one shows what the server took',
    (tester) async {
      var closed = false;
      await _open(tester, _orders(), onClose: () => closed = true);
      expect(find.byKey(const Key('phale-order-THSMAAA111')), findsOneWidget);
      expect(find.text('50.000đ · 6.250 Pha lê · pack_50k'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const Key('phale-order-THSMBBB222'))).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('phale-order-THSMAAA111'))).dy,
        ),
      );
      expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsOneWidget);
      expect(find.byKey(const Key('phale-refund-THSMBBB222')), findsNothing);
      expect(
        find.byKey(const Key('phale-refunded-THSMBBB222')),
        findsOneWidget,
      );
      expect(
        find.text('Đã thu hồi 40.000 Pha lê, còn nợ 30.000'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('phale-admin-back')));
      expect(closed, isTrue);
    },
  );

  testWidgets('Hoàn tiền asks first; "Để xem lại" changes nothing', (
    tester,
  ) async {
    final orders = _orders();
    await _open(tester, orders);
    await tester.tap(find.byKey(const Key('phale-refund-THSMAAA111')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phale-refund-confirm')), findsOneWidget);
    expect(find.textContaining('THSMAAA111: 50.000đ'), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-refund-no')));
    await tester.pumpAndSettle();
    expect(orders.marked, isEmpty);
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsOneWidget);
  });

  testWidgets('Hoàn tiền marks the order once and the row turns refunded', (
    tester,
  ) async {
    final orders = _orders();
    await _open(tester, orders);
    await tester.tap(find.byKey(const Key('phale-refund-THSMAAA111')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('phale-refund-yes')));
    await tester.pumpAndSettle();
    expect(orders.marked, ['THSMAAA111']);
    expect(
      orders.orders.firstWhere((o) => o.code == 'THSMAAA111').refundedBy,
      'admin',
    );
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsNothing);
    expect(find.byKey(const Key('phale-refunded-THSMAAA111')), findsOneWidget);
    expect(find.text('Đang thu hồi Pha lê…'), findsOneWidget);
  });

  testWidgets('a refused mark says so and keeps the button', (tester) async {
    final orders = _orders();
    await _open(tester, orders);
    await tester.tap(find.byKey(const Key('phale-refund-THSMAAA111')));
    await tester.pumpAndSettle();
    orders.fail = true;
    await tester.tap(find.byKey(const Key('phale-refund-yes')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phale-admin-error')), findsOneWidget);
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsOneWidget);
  });

  testWidgets('search by code or uid', (tester) async {
    await _open(tester, _orders());
    await tester.enterText(find.byKey(const Key('phale-admin-search')), 'bob');
    await tester.pump();
    expect(find.byKey(const Key('phale-order-THSMAAA111')), findsNothing);
    expect(find.byKey(const Key('phale-order-THSMBBB222')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('phale-admin-search')), 'aaa1');
    await tester.pump();
    expect(find.byKey(const Key('phale-order-THSMAAA111')), findsOneWidget);
  });

  testWidgets('a load failure says so', (tester) async {
    await _open(tester, MemoryPhaleOrderAdmin()..fail = true);
    await tester.pump();
    expect(find.text('Chưa tải được đơn nạp.'), findsOneWidget);
  });

  test('reads an order doc', () {
    final r = readPhaleOrderRow('C1', {
      'uid': 'u',
      'amount': 50000,
      'crystalsGranted': 6250,
      'status': 'paid',
      'paidAt': DateTime.utc(2026, 10, 1),
      'refundedAt': DateTime.utc(2026, 10, 2),
      'clawback': 'mail_voided',
    })!;
    expect(r.refunded, isTrue);
    expect(r.crystals, 6250);
    expect(phaleClawbackLabel(r), 'Thư Pha lê chưa nhận đã bị huỷ');
    expect(readPhaleOrderRow('C2', {'amount': 1}), isNull);
    expect(phaleClawbackLabel(readPhaleOrderRow('C3', {'uid': 'u'})!), '');
  });
}
