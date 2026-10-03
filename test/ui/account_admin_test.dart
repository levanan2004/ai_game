import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/player_account.dart';
import 'package:ai_game/logic/xu_grant.dart';
import 'package:ai_game/ui/account_admin_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filter, sort, and send a compensation', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Fake([
      const PlayerAccount(
        uid: 'an',
        name: 'An',
        email: 'an@x.com',
        shopName: 'Hoa Mai',
        money: 100000,
        day: 2,
        bouquets: 3,
      ),
      const PlayerAccount(
        uid: 'lan',
        name: 'Lan',
        email: 'lan@x.com',
        shopName: 'Hoa Lan',
        money: 5000,
        day: 9,
        bouquets: 1,
      ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAdminPanel(admin: admin, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getTopLeft(find.byKey(const Key('account-row-lan'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('account-row-an'))).dy),
    );

    await tester.tap(find.byKey(const Key('account-sort')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiền').last);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('account-row-an'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('account-row-lan'))).dy),
    );

    await tester.enterText(find.byKey(const Key('account-search')), 'lan@');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-row-lan')), findsOneWidget);
    expect(find.byKey(const Key('account-row-an')), findsNothing);

    await tester.enterText(find.byKey(const Key('account-search')), '');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account-row-an')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('account-money')), '25000');
    await tester.enterText(find.byKey(const Key('account-day')), '2');
    await tester.enterText(find.byKey(const Key('account-note')), 'Đền reset');
    await tester.tap(find.byKey(const Key('account-grant')));
    await tester.pumpAndSettle();

    expect(admin.uid, 'an');
    expect(admin.money, 25000);
    expect(admin.day, isNull);
    expect(admin.note, 'Đền reset');
    expect(find.byKey(const Key('account-sent')), findsOneWidget);
    expect(find.textContaining('Đang chờ'), findsOneWidget);
  });

  testWidgets('twenty accounts show per page', (tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final admin = _Fake([
      for (var i = 0; i < 21; i++)
        PlayerAccount(
          uid: 'u$i',
          name: 'N$i',
          email: 'u$i@x.com',
          shopName: 'Shop $i',
          money: 1000,
          day: i + 1,
        ),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAdminPanel(admin: admin, onClose: () {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('account-row-u20')), findsOneWidget);
    expect(find.byKey(const Key('account-row-u0')), findsNothing);
    expect(find.text('1-20 / 21'), findsOneWidget);

    await tester.tap(find.byKey(const Key('account-page-next')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('account-row-u0')), findsOneWidget);
    expect(find.byKey(const Key('account-row-u20')), findsNothing);
  });

  testWidgets('Tăng puts the lower day first', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: AccountAdminPanel(
          admin: _Fake([
            const PlayerAccount(uid: 'an', name: 'An', day: 2),
            const PlayerAccount(uid: 'lan', name: 'Lan', day: 9),
          ]),
          onClose: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Giảm'), findsOneWidget);
    await tester.tap(find.byKey(const Key('account-sort-dir')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('account-row-an'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('account-row-lan'))).dy),
    );
  });
}

class _Fake implements AccountAdmin {
  _Fake(this.rows);

  List<PlayerAccount> rows;
  String? uid;
  int? money;
  int? day;
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
    return [
      for (final row in rows)
        if (row.email.toLowerCase().startsWith(q)) row,
    ];
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
  }) async {
    this.uid = uid;
    this.money = money;
    this.day = day;
    this.note = note;
    rows = [
      for (final row in rows)
        if (row.uid != uid)
          row
        else
          PlayerAccount(
            uid: row.uid,
            name: row.name,
            email: row.email,
            shopName: row.shopName,
            money: row.money,
            day: row.day,
            bouquets: row.bouquets,
            joinedAt: row.joinedAt,
            updatedAt: row.updatedAt,
            grant: XuGrant(id: 'sent', money: money, day: day, note: note),
          ),
    ];
  }

  @override
  Future<PetGiftBox> sendGift({
    required String uid,
    required Map<String, int> items,
    required String note,
  }) async {
    return PetGiftBox(id: 'gift', items: sanitizeGiftItems(items), note: note);
  }
}
