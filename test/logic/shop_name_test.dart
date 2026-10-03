import 'dart:convert';
import 'dart:math';

import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/shop_name.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/supporters.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('dice never repeats the name just shown', () {
    final rng = Random(3);
    var shown = suggestedShopNames.first;
    final seen = <String>{shown};
    for (var i = 0; i < 40; i++) {
      final next = rollShopName(shown, rng);
      expect(next, isNot(shown));
      expect(suggestedShopNames, contains(next));
      seen.add(next);
      shown = next;
    }
    expect(seen.length, greaterThan(1));
  });

  test('shop names allow Vietnamese and reject the rest', () {
    expect(normalizeShopName('  Hoa   Ơi  '), 'Hoa Ơi');
    expect(normalizeShopName('Tiệm Hoa Nhà Mây'), 'Tiệm Hoa Nhà Mây');
    expect(normalizeShopName("Lan & Bé-An's"), "Lan & Bé-An's");
    expect(normalizeShopName('A'), isNull);
    expect(normalizeShopName('  A  '), isNull);
    expect(normalizeShopName('Một cái tên dài hơn hai mươi'), isNull);
    expect(normalizeShopName('Hoa@Nhà'), isNull);
    expect(normalizeShopName(''), isNull);
  });

  test('a version 2 save without a shop name still loads', () {
    final s = newSession();
    final j = jsonDecode(s.state.encode()) as Map<String, dynamic>;
    j['version'] = 2;
    j.remove('shopName');
    final back = GameState.decode(jsonEncode(j))!;
    expect(back.shopName, isNull);
    expect(back.money, s.state.money);
    expect(back.day, s.state.day);
    expect(GameState.decode('{"version":1,"money":1}'), isNull);
  });

  test(
    'an old save asks for a name once, then Chơi tiếp goes straight in',
    () async {
      final saved = newSession().state;
      final s = newSession(saved: saved);
      s.showTitle();
      s.continueFromTitle();
      expect(s.screen, Screen.title);
      expect(s.namePrompt, ShopNameMode.start);
      expect(await s.confirmShopName('A'), isFalse);
      expect(await s.confirmShopName('Hoa Ơi'), isTrue);
      expect(s.namePrompt, isNull);
      expect(s.state.shopName, 'Hoa Ơi');
      expect(s.screen, isNot(Screen.title));
      s.backToTitle();
      s.continueFromTitle();
      expect(s.namePrompt, isNull);
      expect(s.screen, isNot(Screen.title));
    },
  );

  test('Bắt đầu asks for a name before day 1 and keeps it', () async {
    final s = newSession();
    s.showTitle();
    s.requestNewGame();
    expect(s.hasSave, isFalse);
    expect(s.namePrompt, ShopNameMode.start);
    await s.confirmShopName('Góc Hoa Nhỏ');
    await s.pendingSaves;
    expect(s.hasSave, isTrue);
    expect(s.state.shopName, 'Góc Hoa Nhỏ');
    expect(s.state.day, 1);
    expect(s.screen, isNot(Screen.title));
  });

  test('rename from settings saves the name and can be cancelled', () async {
    final s = newSession();
    s.showTitle();
    await s.confirmShopName('Hoa Ơi');
    // confirm without a prompt does nothing
    expect(s.state.shopName, isNull);
    s.requestNewGame();
    await s.confirmShopName('Hoa Ơi');
    s.openRename();
    expect(s.namePrompt, ShopNameMode.rename);
    s.cancelShopName();
    expect(s.namePrompt, isNull);
    expect(s.state.shopName, 'Hoa Ơi');
    s.openRename();
    await s.confirmShopName('Hoa Ngõ Nhỏ');
    expect(s.state.shopName, 'Hoa Ngõ Nhỏ');
    expect(s.namePrompt, isNull);
  });

  test('two accounts cannot keep the same shop name', () async {
    final names = _ShopNames();
    final first = newSession(playerDirectory: names);
    first.applySignedIn(
      const AccountProfile(uid: 'a', email: 'a@example.com', name: 'An'),
    );
    first.requestNewGame();
    expect(await first.confirmShopName('Hoa Ơi'), isTrue);

    final second = newSession(playerDirectory: names);
    second.applySignedIn(
      const AccountProfile(uid: 'b', email: 'b@example.com', name: 'Bình'),
    );
    second.requestNewGame();
    expect(await second.confirmShopName('hoa ơi'), isFalse);
    expect(second.state.shopName, isNull);
    expect(second.nameError, 'Tên này đã có tiệm khác dùng rồi.');
    expect(await second.confirmShopName('Góc Hoa Nhỏ'), isTrue);

    first.openRename();
    expect(await first.confirmShopName('Vườn Hoa Nhà Bé'), isTrue);
    final third = newSession(playerDirectory: names);
    third.applySignedIn(
      const AccountProfile(uid: 'c', email: 'c@example.com', name: 'Chi'),
    );
    third.requestNewGame();
    expect(await third.confirmShopName('Hoa Ơi'), isTrue);
  });

  test('a numbered name keeps the whole shop name', () {
    expect(shopNameWithNumber('Tiệm Hoa Nhà Mây', 232), 'Tiệm Hoa Nhà Mây 232');
    expect(
      shopNameWithNumber('Tiệm Hoa Nhà Mây', 100000),
      'Tiệm Hoa Nhà Mây 100000',
    );
    expect(
      shopNameWithNumber('Tiệm Hoa Cúc Họa Mi', 100000),
      'Tiệm Hoa Cúc Họa Mi 100000',
    );
    expect(shopNameWithNumber('Hoa Ơi', 1), 'Hoa Ơi 1');
    expect(shopNameWithNumber('Hoa Ơi', 100001), isNull);
    final names = spareShopNames('Hoa Ơi', Random(1));
    expect(names, isNotEmpty);
    expect(names.every((name) => name.startsWith('Hoa Ơi ')), isTrue);
    expect(names.every((name) => name.length <= maxShopNameLength), isTrue);
  });

  test('signing in keeps a shop name another tiệm already holds', () async {
    final names = _ShopNames()..hold('Hoa Ơi', 'other');
    final morning = newSession().state..shopName = 'Hoa Ơi';
    final s = newSession(
      playerDirectory: names,
      saved: morning,
      account: _NamedAccount(morning),
    );
    await s.signIn();
    expect(s.namePrompt, isNull);
    expect(s.state.shopName, 'Hoa Ơi');
    expect(s.renamedShopNote, isNull);
    expect(names.owners[shopNameKey('Hoa Ơi')], 'other');
  });

  test('dice skips names another tiệm already holds', () async {
    final names = _ShopNames();
    for (final name in suggestedShopNames) {
      names.hold(name, 'other');
    }
    final s = newSession(playerDirectory: names, seed: 2);
    final next = await s.suggestFreeShopName('Hoa Ơi');
    expect(next, isNotNull);
    expect(suggestedShopNames.contains(next), isFalse);
    expect(RegExp(r' \d+$').hasMatch(next!), isTrue);
  });
}

class _NamedAccount extends OfflineAccount {
  _NamedAccount([this.cloud]);

  final GameState? cloud;

  @override
  Future<CloudRecord?> pull() async {
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(state: GameState.decode(saved.encode())!);
  }

  @override
  Future<AccountProfile?> signIn() async =>
      const AccountProfile(uid: 'b', email: 'b@example.com', name: 'Bình');
}

class _ShopNames extends NoPlayerDirectory {
  final Map<String, String> owners = {};

  void hold(String name, String uid) {
    owners[shopNameKey(name)] = uid;
  }

  @override
  Future<ShopNameClaim> claimShopName({
    String? uid,
    required String shopName,
    String? previousName,
  }) async {
    final name = normalizeShopName(shopName);
    if (name == null) return ShopNameClaim.failed;
    final key = shopNameKey(name);
    final owner = owners[key];
    if (owner != null && owner != uid) return ShopNameClaim.taken;
    if (uid == null) return ShopNameClaim.claimed;
    owners[key] = uid;
    if (previousName != null) {
      final previousKey = shopNameKey(previousName);
      if (previousKey != key && owners[previousKey] == uid) {
        owners.remove(previousKey);
      }
    }
    return ShopNameClaim.claimed;
  }
}
