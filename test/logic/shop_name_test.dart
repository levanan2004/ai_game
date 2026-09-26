import 'dart:convert';
import 'dart:math';

import 'package:ai_game/logic/shop_name.dart';
import 'package:ai_game/logic/shop_session.dart';
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

  test('an old save asks for a name once, then Chơi tiếp goes straight in', () {
    final saved = newSession().state;
    final s = newSession(saved: saved);
    s.showTitle();
    s.continueFromTitle();
    expect(s.screen, Screen.title);
    expect(s.namePrompt, ShopNameMode.start);
    expect(s.confirmShopName('A'), isFalse);
    expect(s.confirmShopName('Hoa Ơi'), isTrue);
    expect(s.namePrompt, isNull);
    expect(s.state.shopName, 'Hoa Ơi');
    expect(s.screen, isNot(Screen.title));
    s.backToTitle();
    s.continueFromTitle();
    expect(s.namePrompt, isNull);
    expect(s.screen, isNot(Screen.title));
  });

  test('Bắt đầu asks for a name before day 1 and keeps it', () async {
    final s = newSession();
    s.showTitle();
    s.requestNewGame();
    expect(s.hasSave, isFalse);
    expect(s.namePrompt, ShopNameMode.start);
    s.confirmShopName('Góc Hoa Nhỏ');
    await s.pendingSaves;
    expect(s.hasSave, isTrue);
    expect(s.state.shopName, 'Góc Hoa Nhỏ');
    expect(s.state.day, 1);
    expect(s.screen, isNot(Screen.title));
  });

  test('rename from settings saves the name and can be cancelled', () {
    final s = newSession();
    s.showTitle();
    s.confirmShopName('Hoa Ơi');
    // confirm without a prompt does nothing
    expect(s.state.shopName, isNull);
    s.requestNewGame();
    s.confirmShopName('Hoa Ơi');
    s.openRename();
    expect(s.namePrompt, ShopNameMode.rename);
    s.cancelShopName();
    expect(s.namePrompt, isNull);
    expect(s.state.shopName, 'Hoa Ơi');
    s.openRename();
    s.confirmShopName('Hoa Ngõ Nhỏ');
    expect(s.state.shopName, 'Hoa Ngõ Nhỏ');
    expect(s.namePrompt, isNull);
  });
}
