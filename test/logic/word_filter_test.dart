import 'dart:convert';
import 'dart:io';

import 'package:ai_game/logic/shop_name.dart';
import 'package:ai_game/logic/word_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Nhất's sentences from _kiem_tra_tu_cam.py (shared with
/// functions/word_filter.test.js).
final _cases =
    jsonDecode(File('test/fixtures/tu_cam_cases.json').readAsStringSync())
        as Map<String, dynamic>;

List<String> _list(String key) => (_cases[key] as List).cast<String>();

void main() {
  final filter = WordFilter.parse(File(WordFilter.asset).readAsStringSync());

  test('clean sentences hit nothing', () {
    for (final t in _list('pass')) {
      expect(filter.hits(t).map((r) => r.id), isEmpty, reason: t);
    }
  });

  test('safety reminders only hit mask (che) entries', () {
    for (final t in _list('mask')) {
      final hits = filter.hits(t);
      expect(hits, isNotEmpty, reason: t);
      expect(hits.where((r) => r.block), isEmpty, reason: t);
    }
  });

  test('bad sentences are caught', () {
    for (final t in _list('hit')) {
      expect(filter.hits(t), isNotEmpty, reason: t);
    }
  });

  test('accents matter, and decomposed input is composed first', () {
    expect(filter.hits('đồ ngu'), isNotEmpty);
    expect(filter.hits('đồ ngủ'), isEmpty);
    // "đồ ngu" typed as base letters + combining marks.
    expect(filter.hits('\u0111o\u0302\u0300 ngu'), isNotEmpty);
    // A precomposed ? and a combining grave (how some keyboards type it).
    expect(filter.hits('\u0111\u00f4\u0300 ngu'), isNotEmpty);
    expect(foldText('Đẹp ệ ươ'), 'dep e uo');
  });

  test('shop names: any hit, block or mask, or a staff name is refused', () {
    for (final name in suggestedShopNames) {
      expect(filter.allowsShopName(name), isTrue, reason: name);
      expect(filter.allowsShopName('$name 100000'), isTrue, reason: name);
    }
    for (final name in [
      'Tiệm vcl',
      'Tiệm V.C.L',
      'sexy ghê',
      'zalo',
      'Admin',
      'Hoa Admin',
      'Tiệm Hoa Sớm Mai',
      'tiem hoa som mai',
      'BQT',
      'Đội Tiệm',
      'Quản trị viên',
    ]) {
      expect(filter.allowsShopName(name), isFalse, reason: name);
    }
    // Fine in chat, not as a name.
    expect(filter.hits('admin ơi cho mình hỏi'), isEmpty);
    expect(filter.allowsShopName('Admin ơi'), isFalse);
  });

  test('Python \\b \\w \\W \\d become Unicode classes', () {
    expect(pythonRegexForDart(r'\d'), r'\p{Nd}');
    expect(pythonRegexForDart(r'[\w@]'), r'[\p{L}\p{N}_@]');
    final ab = RegExp(pythonRegexForDart(r'\bab\b'), unicode: true);
    expect(ab.hasMatch('ơ ab'), isTrue);
    expect(ab.hasMatch('ơab'), isFalse);
  });

  test('no list loaded: only staff names are refused', () {
    expect(WordFilter.empty.hits('vcl'), isEmpty);
    expect(WordFilter.empty.allowsShopName('Hoa Lan'), isTrue);
    // Staff names are refused even without the list.
    expect(WordFilter.empty.allowsShopName('Admin'), isFalse);
  });

  test('a refused name is not saved and shows Nhất\'s line', () async {
    final s = newSession();
    s.showTitle();
    s.requestNewGame();
    expect(await s.confirmShopName('Tiệm vcl'), isFalse);
    expect(s.nameError, shopNameRefused);
    expect(s.namePrompt, ShopNameMode.start);
    expect(await s.confirmShopName('Góc Hoa Nhỏ'), isTrue);
    s.openRename();
    expect(await s.confirmShopName('Admin'), isFalse);
    expect(s.nameError, shopNameRefused);
    expect(s.state.shopName, 'Góc Hoa Nhỏ');
  });
}
