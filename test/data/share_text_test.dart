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
    expect(t.ui('image_text.link_label'), 'Chơi miễn phí tại');
    expect(t.ui('image_text.story_footer'), '~ Hẹn bạn ở tiệm hoa nhé ~');
    expect(
      File('pubspec.yaml').readAsStringSync(),
      contains('- ${ShareText.asset}'),
    );
  });

  test('captions: tokens filled, no invite code', () {
    final shop = t.captions(ShareKind.shop, tenTiem: 'Tiệm Mây');
    expect(shop, hasLength(9));
    expect(shop.first, 'Tiệm Mây của mình đã mở cửa rồi nè, ghé chơi nhé 🏡🌷');
    expect(shop.where((c) => c.contains(shareLink)), isNotEmpty);
    for (final c in shop) {
      expect(c, isNot(contains('{')));
      expect(c, isNot(contains('Mã mời')));
    }
    final bo = t.captions(ShareKind.bouquet, tenTiem: 'Tiệm Mây');
    // The one {maMoi} line is left out until there are invite codes.
    expect(bo, hasLength(9));
    for (final c in bo) {
      expect(c, isNot(contains('{')));
      expect(c, isNot(contains('Mã mời')));
    }
  });
}
