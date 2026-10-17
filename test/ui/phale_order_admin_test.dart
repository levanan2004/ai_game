import 'package:ai_game/data/firestore_phale_orders.dart';
import 'package:ai_game/logic/phale_order_admin.dart';
import 'package:ai_game/ui/phale_order_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MemoryPhaleOrderAdmin _orders({int? vipAfter}) => MemoryPhaleOrderAdmin(
  vipAfterRefund: vipAfter,
  orders: [
    PhaleOrderRow(
      code: 'THSMAAA111',
      uid: 'alice',
      shopName: 'Tiệm Hoa Mai',
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
      refundNote: 'đã chuyển trả',
      clawback: 'wallet',
      phaleTaken: 40000,
      phaleDebt: 30000,
    ),
    PhaleOrderRow(
      code: 'THSMCCC333',
      uid: 'carol',
      shopName: 'Tiệm Lan',
      status: 'pending',
      amount: 200000,
      crystals: 26000,
      createdAt: DateTime(2026, 10, 17, 10),
    ),
  ],
);

/// Marks the order, then answers as if someone else had marked it first.
class _RacyAdmin extends MemoryPhaleOrderAdmin {
  _RacyAdmin(List<PhaleOrderRow> orders) : super(orders: orders);

  @override
  Future<void> markRefunded(String code, {String note = ''}) async {
    await super.markRefunded(code, note: note);
    throw StateError('permission-denied');
  }
}

Future<void> _open(
  WidgetTester tester,
  PhaleOrderAdmin orders, {
  VoidCallback? onClose,
  int pollTries = 3,
}) async {
  await tester.binding.setSurfaceSize(const Size(1400, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: PhaleOrderAdminPanel(
        orders: orders,
        onClose: onClose ?? () {},
        pollEvery: Duration.zero,
        pollTries: pollTries,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _confirm(WidgetTester tester, String code, {String? note}) async {
  await tester.tap(find.byKey(Key('phale-refund-$code')));
  await tester.pumpAndSettle();
  if (note != null) {
    await tester.enterText(find.byKey(const Key('phale-refund-note')), note);
  }
  await tester.tap(find.byKey(const Key('phale-refund-yes')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Nhất\'s columns; newest first; refund only on a paid order', (
    tester,
  ) async {
    var closed = false;
    await _open(tester, _orders(), onClose: () => closed = true);
    expect(find.text(AdminTopupText.title), findsOneWidget);
    for (final col in [
      AdminTopupText.colTime,
      AdminTopupText.colOrder,
      AdminTopupText.colPlayer,
      AdminTopupText.colAmount,
      AdminTopupText.colPhaLe,
      AdminTopupText.colStatus,
    ]) {
      expect(find.text(col), findsOneWidget, reason: col);
    }
    for (final f in PhaleOrderFilter.values) {
      expect(find.byKey(Key('phale-filter-${f.name}')), findsOneWidget);
    }
    expect(find.text('15/10/2026 09:30'), findsOneWidget);
    expect(find.text('Tiệm Hoa Mai'), findsOneWidget);
    expect(find.text('bob'), findsOneWidget, reason: 'no name: the uid');
    expect(find.text('50.000đ'), findsOneWidget);
    expect(find.text('6.250'), findsOneWidget);
    double y(String code) =>
        tester.getTopLeft(find.byKey(Key('phale-order-$code'))).dy;
    expect(y('THSMCCC333'), lessThan(y('THSMBBB222')));
    expect(y('THSMBBB222'), lessThan(y('THSMAAA111')));
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsOneWidget);
    expect(find.byKey(const Key('phale-refund-THSMBBB222')), findsNothing);
    expect(find.byKey(const Key('phale-refund-THSMCCC333')), findsNothing);
    expect(find.text(AdminTopupText.filterPaid), findsNWidgets(2));
    expect(find.text(AdminTopupText.filterPending), findsNWidgets(2));
    expect(find.text('Đã hoàn tiền 17/10/2026 08:00'), findsOneWidget);
    expect(
      find.text('Đã thu hồi 40.000 Pha lê, còn nợ 30.000'),
      findsOneWidget,
    );
    expect(find.text('đã chuyển trả'), findsOneWidget);
    await tester.tap(find.byKey(const Key('phale-admin-back')));
    expect(closed, isTrue);
  });

  testWidgets('filters: paid, pending, refunded, all', (tester) async {
    await _open(tester, _orders());
    Future<void> pick(PhaleOrderFilter f) async {
      await tester.tap(find.byKey(Key('phale-filter-${f.name}')));
      await tester.pump();
    }

    Finder row(String code) => find.byKey(Key('phale-order-$code'));
    await pick(PhaleOrderFilter.paid);
    expect(row('THSMAAA111'), findsOneWidget);
    expect(row('THSMBBB222'), findsNothing);
    expect(row('THSMCCC333'), findsNothing);
    await pick(PhaleOrderFilter.pending);
    expect(row('THSMCCC333'), findsOneWidget);
    expect(row('THSMAAA111'), findsNothing);
    await pick(PhaleOrderFilter.refunded);
    expect(row('THSMBBB222'), findsOneWidget);
    expect(row('THSMCCC333'), findsNothing);
    await pick(PhaleOrderFilter.all);
    expect(row('THSMAAA111'), findsOneWidget);
    expect(row('THSMBBB222'), findsOneWidget);
    expect(row('THSMCCC333'), findsOneWidget);
  });

  testWidgets('Hoàn tiền asks with Nhất\'s text; "Thôi" changes nothing', (
    tester,
  ) async {
    final orders = _orders();
    await _open(tester, orders);
    await tester.tap(find.byKey(const Key('phale-refund-THSMAAA111')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phale-refund-confirm')), findsOneWidget);
    expect(find.text('Đánh dấu đơn THSMAAA111 đã hoàn tiền?'), findsOneWidget);
    expect(
      find.text(AdminTopupText.refundBody('50.000đ', '6.250', 'Tiệm Hoa Mai')),
      findsOneWidget,
    );
    expect(find.text(AdminTopupText.noteLabel), findsOneWidget);
    expect(find.text(AdminTopupText.cancel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('phale-refund-confirm')),
        matching: find.text(AdminTopupText.confirm),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('phale-refund-no')));
    await tester.pumpAndSettle();
    expect(orders.marked, isEmpty);
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsOneWidget);
  });

  testWidgets('Đã hoàn tiền: marked once with the note, then the new tier', (
    tester,
  ) async {
    final orders = _orders(vipAfter: 2);
    await _open(tester, orders);
    await _confirm(tester, 'THSMAAA111', note: 'Vietcombank 15:20');
    expect(orders.marked, ['THSMAAA111']);
    expect(orders.notes['THSMAAA111'], 'Vietcombank 15:20');
    expect(
      find.text('Đã đánh dấu hoàn tiền. Tiệm Hoa Mai giờ là VIP 2.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsNothing);
    expect(find.byKey(const Key('phale-refunded-THSMAAA111')), findsOneWidget);
    expect(find.byKey(const Key('phale-note-THSMAAA111')), findsOneWidget);
  });

  testWidgets('no VIP left: done_no_vip', (tester) async {
    await _open(tester, _orders(vipAfter: 0));
    await _confirm(tester, 'THSMAAA111');
    expect(find.text(AdminTopupText.doneNoVip('Tiệm Hoa Mai')), findsOneWidget);
  });

  testWidgets('a slow server: the row shows the refund, no tier line yet', (
    tester,
  ) async {
    await _open(tester, _orders());
    await _confirm(tester, 'THSMAAA111');
    expect(find.byKey(const Key('phale-admin-notice')), findsNothing);
    expect(find.byKey(const Key('phale-refunded-THSMAAA111')), findsOneWidget);
    expect(find.text('Đang thu hồi Pha lê…'), findsOneWidget);
  });

  testWidgets('a refused mark says fail and keeps the button', (tester) async {
    final orders = _orders();
    await _open(tester, orders);
    await tester.tap(find.byKey(const Key('phale-refund-THSMAAA111')));
    await tester.pumpAndSettle();
    orders.fail = true;
    await tester.tap(find.byKey(const Key('phale-refund-yes')));
    await tester.pumpAndSettle();
    expect(find.text(AdminTopupText.fail), findsOneWidget);
    orders.fail = false;
    await tester.tap(find.byKey(const Key('phale-admin-reload')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('phale-refund-THSMAAA111')), findsOneWidget);
  });

  testWidgets('marked elsewhere first: already', (tester) async {
    await _open(tester, _RacyAdmin(_orders().rows));
    await _confirm(tester, 'THSMAAA111');
    expect(find.text(AdminTopupText.already), findsOneWidget);
  });

  testWidgets('search by order code or shop name', (tester) async {
    await _open(tester, _orders());
    expect(find.text(AdminTopupText.search), findsOneWidget);
    await tester.enterText(find.byKey(const Key('phale-admin-search')), 'mai');
    await tester.pump();
    expect(find.byKey(const Key('phale-order-THSMAAA111')), findsOneWidget);
    expect(find.byKey(const Key('phale-order-THSMBBB222')), findsNothing);
    await tester.enterText(find.byKey(const Key('phale-admin-search')), 'bbb2');
    await tester.pump();
    expect(find.byKey(const Key('phale-order-THSMBBB222')), findsOneWidget);
    expect(find.byKey(const Key('phale-order-THSMAAA111')), findsNothing);
  });

  testWidgets('no orders: Nhất\'s empty line; a load failure says so', (
    tester,
  ) async {
    await _open(tester, MemoryPhaleOrderAdmin());
    expect(find.text(AdminTopupText.empty), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await _open(tester, MemoryPhaleOrderAdmin()..fail = true);
    await tester.pump();
    expect(find.text('Chưa tải được đơn nạp.'), findsOneWidget);
  });

  test('reads an order doc; lists paid and open orders only', () {
    final r = readPhaleOrderRow('C1', {
      'uid': 'u',
      'amount': 50000,
      'crystalsGranted': 6250,
      'status': 'paid',
      'shopName': 'Tiệm U',
      'paidAt': DateTime.utc(2026, 10, 1),
      'refundedAt': DateTime.utc(2026, 10, 2),
      'refundNote': 'ok',
      'clawback': 'mail_voided',
      'vipAfter': 3,
    })!;
    expect(r.refunded, isTrue);
    expect(r.crystals, 6250);
    expect(r.player, 'Tiệm U');
    expect(r.refundNote, 'ok');
    expect(r.vipAfter, 3);
    expect(phaleClawbackLabel(r), 'Thư Pha lê chưa nhận đã bị huỷ');
    expect(readPhaleOrderRow('C2', {'amount': 1}), isNull);
    expect(phaleClawbackLabel(readPhaleOrderRow('C3', {'uid': 'u'})!), '');
    expect(readPhaleOrderRow('C4', {'uid': 'u'})!.vipAfter, isNull);
    final now = DateTime.utc(2026, 10, 17, 12);
    expect(phaleOrderListed({'status': 'paid'}, now), isTrue);
    expect(
      phaleOrderListed({
        'status': 'pending',
        'expiresAt': DateTime.utc(2026, 10, 17, 13),
      }, now),
      isTrue,
    );
    expect(
      phaleOrderListed({
        'status': 'pending',
        'expiresAt': DateTime.utc(2026, 10, 17, 11),
      }, now),
      isFalse,
    );
    expect(phaleOrderListed({'status': 'cancelled'}, now), isFalse);
    expect(phaleOrderListed({'status': 'lech_goi'}, now), isFalse);
  });
}
