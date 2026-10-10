import 'package:ai_game/logic/player_account.dart';
import 'package:ai_game/logic/xu_grant.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

PlayerAccount _row({
  required String uid,
  String name = '',
  String email = '',
  String shop = '',
  int? money,
  int? day,
  int bouquets = 0,
  DateTime? joined,
  DateTime? updated,
}) {
  return PlayerAccount(
    uid: uid,
    name: name,
    email: email,
    shopName: shop,
    money: money,
    day: day,
    bouquets: bouquets,
    joinedAt: joined,
    updatedAt: updated,
  );
}

void main() {
  test('filter matches email, shop, name, and uid', () {
    final rows = [
      _row(uid: 'u1', name: 'An', email: 'an@x.com', shop: 'Hoa Mai'),
      _row(uid: 'u2', name: 'Lan', email: 'lan@x.com', shop: 'Hoa Lan'),
    ];
    expect(rows.where((r) => accountMatches(r, ' LAN@ ')).map((r) => r.uid), [
      'u2',
    ]);
    expect(rows.where((r) => accountMatches(r, 'mai')).single.uid, 'u1');
    expect(rows.where((r) => accountMatches(r, 'u2')).single.name, 'Lan');
    expect(rows.where((r) => accountMatches(r, '')), hasLength(2));
  });

  test('sort puts missing saves last and breaks ties by uid', () {
    final rows = [
      _row(uid: 'b', shop: 'B', day: 2, money: 9, bouquets: 1),
      _row(uid: 'a', shop: 'A', day: 9, money: 3, bouquets: 4),
      _row(uid: 'c', shop: ''),
    ];
    expect(sortAccounts(rows, AccountSort.day).map((r) => r.uid), [
      'a',
      'b',
      'c',
    ]);
    expect(sortAccounts(rows, AccountSort.money).map((r) => r.uid), [
      'b',
      'a',
      'c',
    ]);
    expect(sortAccounts(rows, AccountSort.bouquets).first.uid, 'a');
    expect(sortAccounts(rows, AccountSort.shop).map((r) => r.uid), [
      'b',
      'a',
      'c',
    ]);
    expect(
      sortAccounts(rows, AccountSort.shop, ascending: true).map((r) => r.uid),
      ['a', 'b', 'c'],
    );
    expect(
      sortAccounts(rows, AccountSort.day, ascending: true).map((r) => r.uid),
      ['b', 'a', 'c'],
    );

    final times = [
      _row(uid: 'old', updated: DateTime.utc(2026, 1, 1)),
      _row(uid: 'new', updated: DateTime.utc(2026, 9, 1)),
      _row(uid: 'none'),
    ];
    expect(sortAccounts(times, AccountSort.updated).map((r) => r.uid), [
      'new',
      'old',
      'none',
    ]);
  });

  test('grant applies once, ignores a lower day, and rejects a repeat', () {
    const grant = XuGrant(id: 'g1', money: 5000, day: 3);
    final first = grantEffect(appliedId: null, currentDay: 8, grant: grant);
    expect(first!.money, 5000);
    expect(first.day, isNull);

    final raised = grantEffect(
      appliedId: null,
      currentDay: 1,
      grant: const XuGrant(id: 'g2', money: 0, day: 6),
    );
    expect(raised!.day, 6);
    expect(raised.money, 0);

    expect(
      grantEffect(appliedId: 'g2', currentDay: 6, grant: raisedGrant()),
      isNull,
    );
    expect(
      grantEffect(
        appliedId: null,
        currentDay: 1,
        grant: const XuGrant(id: 'g3', money: 0),
      ),
      isNull,
    );
  });

  test('the form asks for money or a higher day', () {
    expect(grantFormError(money: null, day: null, currentDay: 4), isNotNull);
    expect(grantFormError(money: 1000, day: 2, currentDay: 4), isNull);
    expect(grantFormError(money: null, day: 2, currentDay: 4), isNotNull);
    expect(grantFormError(money: null, day: 10, currentDay: 4), isNull);
    expect(readDigits('50.000'), 50000);
    expect(readDigits(''), isNull);
  });

  test('grant status tells a waiting grant from one already in the save', () {
    final waiting = PlayerAccount(
      uid: 'u',
      grant: const XuGrant(id: 'g', money: 25000, day: 12),
    );
    expect(grantStatus(waiting), contains('Đang chờ'));
    expect(
      grantStatus(
        PlayerAccount(
          uid: 'u',
          grant: const XuGrant(id: 'g', money: 25000),
          appliedGrantId: 'g',
        ),
      ),
      contains('Đã vào save'),
    );
  });

  test(
    'the account list pages twenty rows and keeps a save on its profile',
    () {
      final rows = [for (var i = 0; i < 21; i++) _row(uid: 'u$i', day: i)];
      expect(accountPage(rows, 0), hasLength(20));
      expect(accountPage(rows, 1).single.uid, 'u20');
      expect(accountPageCount(21), 2);
      final merged = mergeAccountSaves(
        [_row(uid: 'u1', name: 'An', email: 'an@x.com', shop: 'Hoa Mai')],
        [_row(uid: 'u1', shop: 'Hoa Mai', money: 40, day: 3, bouquets: 2)],
      );
      expect(merged.single.email, 'an@x.com');
      expect(merged.single.day, 3);
      expect(merged.single.money, 40);
    },
  );

  test('applied grant id round-trips and old saves stay null', () {
    final state = newSession().state..appliedGrantId = 'abc';
    expect(GameState.decode(state.encode())!.appliedGrantId, 'abc');
    final plain = newSession().state;
    expect(GameState.decode(plain.encode())!.appliedGrantId, isNull);
  });
}

XuGrant raisedGrant() => const XuGrant(id: 'g2', money: 0, day: 6);
