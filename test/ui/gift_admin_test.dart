import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/player_account.dart';
import 'package:ai_game/ui/gift_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter gifts and players, then send several gifts', (
    tester,
  ) async {
    // Tall, so the list builds every gift card, the 24 new pots too.
    tester.view.physicalSize = const Size(800, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Gifts([
      const PlayerAccount(
        uid: 'an',
        email: 'an@x.com',
        shopName: 'Hoa Mai',
        day: 4,
        money: 1000,
      ),
      const PlayerAccount(
        uid: 'lan',
        email: 'lan@x.com',
        shopName: 'Hoa Lan',
        day: 2,
        money: 500,
        pocket: PetPocket(biscuits: 2),
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: GiftAdminPanel(admin: admin, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gift-card-banh_mat')), findsOneWidget);
    expect(find.byKey(const Key('gift-card-giat_hoa')), findsOneWidget);
    expect(find.byKey(const Key('gift-user-lan')), findsNothing);

    await tester.enterText(find.byKey(const Key('gift-user-search')), 'lan');
    await tester.tap(find.byKey(const Key('gift-user-find')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gift-user-lan')), findsOneWidget);
    expect(find.byKey(const Key('gift-user-an')), findsNothing);
    expect(find.text('Đang có 2'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('gift-user-search')), 'an@');
    await tester.tap(find.byKey(const Key('gift-user-find')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('gift-user-an')));
    await tester.pumpAndSettle();
    expect(find.text('Tiệm chưa có quà thú cưng.'), findsOneWidget);

    expect(find.byKey(const Key('gift-card-dragon')), findsOneWidget);
    expect(find.byKey(const Key('gift-xu')), findsOneWidget);
    expect(find.byKey(const Key('gift-card-chau_su_tu')), findsOneWidget);
    expect(find.byKey(const Key('gift-card-chau_con_bang')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('gift-qty-dragon')));
    await tester.enterText(find.byKey(const Key('gift-qty-dragon')), '4');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('gift-xu')));
    await tester.enterText(find.byKey(const Key('gift-xu')), '50000');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('gift-qty-banh_mat')));
    await tester.enterText(find.byKey(const Key('gift-qty-banh_mat')), '2');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('gift-card-meo')));
    await tester.tap(find.byKey(const Key('gift-card-meo')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('gift-card-dem_xanh')));
    await tester.tap(find.byKey(const Key('gift-card-dem_xanh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('gift-qty-meo')), findsNothing);
    expect(find.byKey(const Key('gift-qty-dem_xanh')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('gift-send')));
    await tester.tap(find.byKey(const Key('gift-send')));
    await tester.pumpAndSettle();

    expect(admin.uid, 'an');
    expect(admin.items[giftBiscuit], 2);
    expect(admin.items[giftCat], 1);
    expect(admin.items[giftSeat], 1);
    expect(admin.items['dragon'], 4);
    expect(admin.items[giftXu], 50000);
    expect(find.byKey(const Key('gift-sent')), findsOneWidget);
    expect(find.textContaining('Đang chờ'), findsOneWidget);
  });
}

class _Gifts implements AccountAdmin {
  _Gifts(this.rows);

  List<PlayerAccount> rows;
  String? uid;
  Map<String, int> items = const {};
  String? note;

  @override
  Future<List<PlayerAccount>> loadProfiles() async => rows;

  @override
  Future<List<PlayerAccount>> loadSaves(List<String> uids) async => [
    for (final row in rows)
      if (uids.contains(row.uid)) row,
  ];

  @override
  Future<List<PlayerAccount>> findByEmail(String email) async {
    final q = email.trim().toLowerCase();
    if (q.length < 2) return const [];
    final matched = [
      for (final row in rows)
        if (row.email.toLowerCase().startsWith(q)) row.uid,
    ];
    return loadSaves(matched);
  }

  @override
  Future<List<String>> markEstablished(List<PlayerAccount> rows) async =>
      const [];

  @override
  Future<void> grant({
    required String uid,
    required int money,
    int? day,
    required String note,
  }) async {}

  @override
  Future<PetGiftBox> sendGift({
    required String uid,
    required Map<String, int> items,
    required String note,
  }) async {
    this.uid = uid;
    this.items = sanitizeGiftItems(items);
    this.note = note;
    final box = PetGiftBox(id: 'sent-gift-1', items: this.items, note: note);
    rows = [
      for (final row in rows)
        if (row.uid == uid) row.withGift(box) else row,
    ];
    return box;
  }
}
