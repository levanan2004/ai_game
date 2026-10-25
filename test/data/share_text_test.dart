import 'dart:io';

import 'package:ai_game/data/share_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final t = loadTestData().share;

  test('chia_se.json is the copy of Nhất\'s file and loads', () {
    expect(t.ui('button.share_bouquet'), 'Khoe bó hoa');
    expect(t.ui('sheet.title_shop'), 'Mời bạn bè ghé tiệm');
    expect(t.ui('button.nope'), 'button.nope');
    expect(t.hashtags.first, '#TiemHoaSomMai');
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- ${ShareText.asset}'),
    );
  });

  test('captions: tokens filled, no invite code, no bouquet name', () {
    final shop = t.captions(ShareKind.shop, tenTiem: 'Tiệm Mây');
    expect(shop, hasLength(9));
    expect(
      shop.first,
      'Tiệm Tiệm Mây của mình đã mở cửa rồi nè, ghé chơi nhé 🏡🌷',
    );
    expect(shop.where((c) => c.contains(shareLink)), isNotEmpty);
    for (final c in shop) {
      expect(c, isNot(contains('{')));
      expect(c, isNot(contains('Mã mời')));
    }
    final bo = t.captions(ShareKind.bouquet, tenTiem: 'Tiệm Mây');
    expect(bo, hasLength(4));
    for (final c in bo) {
      expect(c, isNot(contains('{')));
    }
    expect(
      t.captions(ShareKind.bouquet, tenTiem: 'A', tenBo: 'Nắng'),
      hasLength(9),
    );
  });
}
