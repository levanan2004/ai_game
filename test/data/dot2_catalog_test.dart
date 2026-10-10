import 'dart:io';
import 'dart:typed_data';

import 'package:ai_game/ui/art.dart';
import 'package:ai_game/ui/pot_popup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Phú's dot 2 art: 24 pots (12 Chòm sao, 12 Sơn Hải) and 12 flowers with
/// wilted versions. How to get them is not decided, so they sit in the
/// catalog data only.
const _chomSao = <String, String>{
  'chau_bach_duong': 'Chậu Bạch Dương',
  'chau_kim_nguu': 'Chậu Kim Ngưu',
  'chau_song_tu': 'Chậu Song Tử',
  'chau_cu_giai': 'Chậu Cự Giải',
  'chau_su_tu': 'Chậu Sư Tử',
  'chau_xu_nu': 'Chậu Xử Nữ',
  'chau_thien_binh': 'Chậu Thiên Bình',
  'chau_ho_cap': 'Chậu Hổ Cáp',
  'chau_nhan_ma': 'Chậu Nhân Mã',
  'chau_ma_ket': 'Chậu Ma Kết',
  'chau_bao_binh': 'Chậu Bảo Bình',
  'chau_song_ngu': 'Chậu Song Ngư',
};

const _sonHai = <String, String>{
  'chau_thao_thiet': 'Chậu Thao Thiết',
  'chau_cung_ky': 'Chậu Cùng Kỳ',
  'chau_hon_don': 'Chậu Hỗn Độn',
  'chau_dao_ngot': 'Chậu Đào Ngột',
  'chau_cuu_vi_ho': 'Chậu Cửu Vĩ Hồ',
  'chau_tat_phuong': 'Chậu Tất Phương',
  'chau_ky_lan': 'Chậu Kỳ Lân Sơn Hải',
  'chau_chuc_long': 'Chậu Chúc Long',
  'chau_con_bang': 'Chậu Côn Bằng',
  'chau_bach_trach': 'Chậu Bạch Trạch',
  'chau_tinh_ve': 'Chậu Tinh Vệ',
  'chau_de_giang': 'Chậu Đế Giang',
};

const _flowers = <String, String>{
  'hoa_tra': 'Hoa trà',
  'bi_ngan': 'Bỉ ngạn',
  'sen': 'Sen',
  'hoa_su': 'Hoa sứ',
  'tu_dang': 'Tử đằng',
  'oai_huong': 'Oải hương',
  'thien_dieu': 'Thiên điểu',
  'hoa_mai': 'Hoa mai',
  'hoa_dao': 'Hoa đào',
  'sao_nhai': 'Sao nhái',
  'luu_ly': 'Lưu ly',
  'moc_lan': 'Mộc lan',
};

/// Width and height from a WebP header (VP8X, VP8L or VP8).
(int, int) _webpSize(String path) {
  final b = File(path).readAsBytesSync();
  final d = ByteData.sublistView(Uint8List.fromList(b));
  expect(String.fromCharCodes(b.sublist(0, 4)), 'RIFF', reason: path);
  expect(String.fromCharCodes(b.sublist(8, 12)), 'WEBP', reason: path);
  final kind = String.fromCharCodes(b.sublist(12, 16));
  switch (kind) {
    case 'VP8X':
      final w = 1 + (b[24] | b[25] << 8 | b[26] << 16);
      final h = 1 + (b[27] | b[28] << 8 | b[29] << 16);
      return (w, h);
    case 'VP8L':
      final bits = d.getUint32(21, Endian.little);
      return (1 + (bits & 0x3fff), 1 + ((bits >> 14) & 0x3fff));
    case 'VP8 ':
      return (
        d.getUint16(26, Endian.little) & 0x3fff,
        d.getUint16(28, Endian.little) & 0x3fff,
      );
  }
  fail('$path: unknown WebP chunk $kind');
}

void main() {
  final s = newSession();
  final e = s.e;

  test('the 24 new pots are in the catalog with their names and sets', () {
    final byId = {for (final p in e.pots) p.id: p};
    for (final entry in _chomSao.entries) {
      expect(byId[entry.key]?.nameVi, entry.value, reason: entry.key);
      expect(byId[entry.key]?.set, 'chomSao', reason: entry.key);
    }
    for (final entry in _sonHai.entries) {
      expect(byId[entry.key]?.nameVi, entry.value, reason: entry.key);
      expect(byId[entry.key]?.set, 'sonHai', reason: entry.key);
    }
    expect(e.pots.length, 1 + 8 + 24);
    expect(e.pots.where((p) => p.set != null).length, 24);
    expect({for (final p in e.pots) p.id}.length, e.pots.length);
  });

  test('Kỳ Lân Sơn Hải and the old kỳ lân are two different pots', () {
    final old = e.pot('qilin');
    final novel = e.pot('chau_ky_lan');
    expect(old.nameVi, 'Chậu kỳ lân');
    expect(novel.nameVi, 'Chậu Kỳ Lân Sơn Hải');
    expect(novel.id, isNot(old.id));
    expect(novel.nameVi.toLowerCase(), isNot(old.nameVi.toLowerCase()));
  });

  test('the new pots have art but cannot be bought or listed yet', () {
    for (final id in [..._chomSao.keys, ..._sonHai.keys]) {
      final pot = e.pot(id);
      expect(pot.price, 0, reason: id);
      expect(pot.purchasable, isFalse, reason: id);
      expect(File(Art.pot(id)).existsSync(), isTrue, reason: id);
      final fresh = newSession();
      fresh.state.money = 999999999;
      expect(fresh.buyPot(id), isFalse, reason: id);
      expect(fresh.state.money, 999999999, reason: id);
      expect(fresh.potOwned(id), 0, reason: id);
      expect(fresh.potListed(pot), isFalse, reason: id);
    }
    // The first eight still sell.
    expect(e.pot('dragon').purchasable, isTrue);
    expect(s.potListed(e.pot('dragon')), isTrue);
    expect(s.potListed(e.pot('sage')), isTrue);
  });

  test('a new pot that someone owns is listed and can be placed', () {
    final owner = newSession();
    owner.state.potCounts['chau_su_tu'] = 1;
    expect(owner.potListed(owner.e.pot('chau_su_tu')), isTrue);
    owner.openPotPicker(bar: false, index: 0);
    expect(owner.placePot('chau_su_tu'), isTrue);
    expect(owner.state.displayPots[0], 'chau_su_tu');
  });

  test('the 12 new flowers are catalog-only, with fresh and wilted art', () {
    expect({for (final f in e.newFlowers) f.id: f.nameVi}, _flowers);
    final playable = {for (final f in e.flowers) f.id};
    for (final id in _flowers.keys) {
      expect(playable, isNot(contains(id)), reason: '$id is not playable yet');
      expect(File(Art.flower(id)).existsSync(), isTrue, reason: id);
      expect(File(Art.flowerWilted(id)).existsSync(), isTrue, reason: id);
    }
    expect(Art.flowerWilted('sen'), 'assets/images/flowers/sen_heo.webp');
  });

  test('image sizes: pots 490x490, flowers 256x256, files stay small', () {
    for (final id in [..._chomSao.keys, ..._sonHai.keys]) {
      final path = Art.pot(id);
      expect(_webpSize(path), (490, 490), reason: path);
      expect(File(path).lengthSync(), lessThan(70 * 1024), reason: path);
    }
    for (final id in _flowers.keys) {
      for (final path in [Art.flower(id), Art.flowerWilted(id)]) {
        expect(_webpSize(path), (256, 256), reason: path);
        expect(File(path).lengthSync(), lessThan(60 * 1024), reason: path);
      }
    }
  });

  testWidgets('Kho chậu hides catalog-only pots, shows owned ones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = newSession();
    session.state.potCounts['chau_ky_lan'] = 1;
    session.openPotPicker(bar: true, index: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PotPopup(session: session)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('pot-cell-sage')), findsOneWidget);
    expect(find.byKey(const Key('pot-cell-qilin')), findsOneWidget);
    expect(find.byKey(const Key('pot-cell-chau_ky_lan')), findsOneWidget);
    expect(find.byKey(const Key('pot-cell-chau_su_tu')), findsNothing);
    expect(find.byKey(const Key('pot-cell-chau_thao_thiet')), findsNothing);

    // Detail of the owned pot: full name in a two-line title, no Mua button.
    await tester.ensureVisible(find.byKey(const Key('pot-cell-chau_ky_lan')));
    await tester.tap(find.byKey(const Key('pot-cell-chau_ky_lan')));
    await tester.pump();
    final title = tester.widget<Text>(find.byKey(const Key('pot-detail-name')));
    expect(title.data, 'Chậu Kỳ Lân Sơn Hải');
    expect(title.maxLines, 2);
    expect(find.byKey(const Key('buy-chau_ky_lan')), findsNothing);
    expect(find.byKey(const Key('place-chau_ky_lan')), findsOneWidget);
  });
}
