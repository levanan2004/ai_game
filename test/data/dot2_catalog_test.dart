import 'dart:io';
import 'dart:typed_data';

import 'package:ai_game/data/economy.dart';
import 'package:ai_game/save/game_state.dart';
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
  'chau_ho_cap': 'Chậu Thiên Yết',
  'chau_nhan_ma': 'Chậu Nhân Mã',
  'chau_ma_ket': 'Chậu Ma Kết',
  'chau_bao_binh': 'Chậu Bảo Bình',
  'chau_song_ngu': 'Chậu Song Ngư',
};

/// Hà Phương's approved xu prices, in the order above.
const _chomSaoPrice = <int>[
  3000000, 4000000, 5000000, 6500000, 8000000, 10000000, //
  12000000, 15000000, 18000000, 22000000, 26000000, 30000000,
];

const _sonHai = <String, String>{
  'chau_thao_thiet': 'Chậu Thao Thiết',
  'chau_cung_ky': 'Chậu Cùng Kỳ',
  'chau_hon_don': 'Chậu Hỗn Độn',
  'chau_dao_ngot': 'Chậu Đào Ngột',
  'chau_cuu_vi_ho': 'Chậu Cửu Vĩ Hồ',
  'chau_tat_phuong': 'Chậu Tất Phương',
  'chau_tinh_ve': 'Chậu Tinh Vệ',
  'chau_de_giang': 'Chậu Đế Giang',
  'chau_ky_lan': 'Chậu kỳ lân xanh',
  'chau_bach_trach': 'Chậu Bạch Trạch',
  'chau_chuc_long': 'Chậu Chúc Long',
  'chau_con_bang': 'Chậu Côn Bằng',
};

/// Pha lê price per tier: Tứ hung 250, Kỳ thú 300, Thần thú 350.
const _sonHaiPrice = <int>[
  250,
  250,
  250,
  250,
  300,
  300,
  300,
  300,
  350,
  350,
  350,
  350,
];

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
    expect(e.pots.where((p) => p.set == 'chomSao').length, 12);
    expect(e.pots.where((p) => p.set == 'sonHai').length, 12);
    expect(e.pots.where((p) => p.set == 'linhVat').length, 8);
    expect({for (final p in e.pots) p.id}.length, e.pots.length);
  });

  test('every pot has a different full name and a different short name', () {
    final full = [for (final p in e.pots) p.nameVi.toLowerCase()];
    expect(full.toSet().length, full.length);
    final short = [
      for (final p in e.pots)
        if (!p.unlimited) p.shortVi!.toLowerCase(),
    ];
    expect(short.toSet().length, short.length);
    for (final p in e.pots.where((p) => !p.unlimited)) {
      // shortVi is the name without "Chậu", first letter capital.
      final base = p.nameVi.replaceFirst('Chậu ', '');
      expect(
        p.shortVi,
        base[0].toUpperCase() + base.substring(1),
        reason: p.id,
      );
    }
    expect(e.pot('qilin').shortVi, 'Kỳ lân vàng');
    expect(e.pot('chau_ky_lan').shortVi, 'Kỳ lân xanh');
    expect(e.pot('chau_ho_cap').shortVi, 'Thiên Yết');
    expect(e.pot('chau_cung_ky').shortVi, 'Cùng Kỳ');
  });

  test('the two kỳ lân pots are different and keep their full names', () {
    final old = e.pot('qilin');
    final novel = e.pot('chau_ky_lan');
    expect(old.nameVi, 'Chậu kỳ lân vàng');
    expect(novel.nameVi, 'Chậu kỳ lân xanh');
    expect(novel.id, isNot(old.id));
    // The pet keeps the plain name.
    expect(e.pets.firstWhere((p) => p.id == 'ky_lan').nameVi, 'Kỳ lân');
  });

  test(
    'Chòm sao pots cost xu, Sơn Hải pots cost Pha lê, like Hà Phương said',
    () {
      final ids = _chomSao.keys.toList();
      for (var i = 0; i < ids.length; i++) {
        final pot = e.pot(ids[i]);
        expect(pot.currency, 'coins', reason: ids[i]);
        expect(pot.paysPhaLe, isFalse, reason: ids[i]);
        expect(pot.price, _chomSaoPrice[i], reason: ids[i]);
        expect(pot.phaLePrice, 0, reason: ids[i]);
        expect(pot.cost, _chomSaoPrice[i], reason: ids[i]);
        expect(pot.purchasable, isTrue, reason: ids[i]);
        expect(pot.howVi, startsWith('Mua '), reason: ids[i]);
        expect(pot.howVi, endsWith(' xu'), reason: ids[i]);
        expect(pot.howVi!.length, lessThanOrEqualTo(25), reason: ids[i]);
      }
      expect(_chomSaoPrice.reduce((a, b) => a + b), 159500000);
      final sh = _sonHai.keys.toList();
      for (var i = 0; i < sh.length; i++) {
        final pot = e.pot(sh[i]);
        expect(pot.currency, 'phaLe', reason: sh[i]);
        expect(pot.paysPhaLe, isTrue, reason: sh[i]);
        expect(pot.price, 0, reason: '${sh[i]}: no xu price');
        expect(pot.phaLePrice, _sonHaiPrice[i], reason: sh[i]);
        expect(pot.cost, _sonHaiPrice[i], reason: sh[i]);
        expect(pot.purchasable, isTrue, reason: sh[i]);
        expect(pot.howVi, 'Mua ${_sonHaiPrice[i]} Pha lê', reason: sh[i]);
      }
      expect(_sonHaiPrice.reduce((a, b) => a + b), 3600);
      // The 8 old pots cost 300 Pha lê (was 1.800.000 xu).
      final old = e.pots.where((p) => p.set == 'linhVat').toList();
      expect(old.length, 8);
      for (final p in old) {
        expect(p.currency, 'phaLe', reason: p.id);
        expect(p.price, 0, reason: p.id);
        expect(p.phaLePrice, 300, reason: p.id);
        expect(p.purchasable, isTrue, reason: p.id);
        expect(p.howVi, endsWith('300 Pha lê'), reason: p.id);
        expect(p.howVi!.length, lessThanOrEqualTo(37), reason: p.id);
      }
      const how = {
        'dragon': 'Quà ngày 2 hoặc mua 300 Pha lê',
        'tiger': 'Quà ngày 6 hoặc mua 300 Pha lê',
        'koi': 'Quà mốc 14 ngày hoặc mua 300 Pha lê',
        'crane': 'Quà mốc 30 ngày hoặc mua 300 Pha lê',
        'phoenix': 'Mua 300 Pha lê',
        'tortoise': 'Mua 300 Pha lê',
        'qilin': 'Mua 300 Pha lê',
        'nghe': 'Mua 300 Pha lê',
      };
      how.forEach((id, text) => expect(e.pot(id).howVi, text, reason: id));
      expect(e.pot('nghe').howVi, 'Mua 300 Pha lê');
      for (final id in [..._chomSao.keys, ..._sonHai.keys]) {
        expect(File(Art.pot(id)).existsSync(), isTrue, reason: id);
        expect(newSession().potListed(e.pot(id)), isTrue, reason: id);
      }
    },
  );

  test('old pots: Pha lê price, and owners keep what they have', () {
    // A save from before the price change: 2 dragons, 1 koi, on the bar.
    final before = newSession();
    before.state.potCounts
      ..['dragon'] = 2
      ..['koi'] = 1;
    before.state.barPots[0] = 'dragon';
    final back = newSession(saved: GameState.decode(before.state.encode()));
    expect(back.potOwned('dragon'), 2);
    expect(back.potOwned('koi'), 1);
    expect(back.state.barPots[0], 'dragon');
    expect(back.potListed(back.e.pot('dragon')), isTrue);
    // A pot they own is not sold again (one copy of each pot).
    back.state.money = 9999999;
    back.state.phaLe = 9999;
    expect(back.buyPot('dragon'), isFalse);
    expect(back.potOwned('dragon'), 2);
    // An old pot they lack costs 300 Pha lê, never xu.
    back.state.phaLe = 299;
    expect(back.buyPot('nghe'), isFalse);
    back.state.phaLe = 300;
    expect(back.buyPot('nghe'), isTrue);
    expect(back.state.phaLe, 0);
    expect(back.state.money, 9999999);
    expect(back.potOwned('nghe'), 1);
  });

  test('buying a Chòm sao pot spends xu only', () {
    final b = newSession();
    b.state.money = 10000000;
    b.state.phaLe = 500;
    expect(b.buyPot('chau_su_tu'), isTrue);
    expect(b.state.money, 2000000);
    expect(b.state.phaLe, 500);
    expect(b.potOwned('chau_su_tu'), 1);
    // Not enough xu: nothing changes, even with plenty of Pha lê.
    expect(b.buyPot('chau_song_ngu'), isFalse);
    expect(b.state.money, 2000000);
    expect(b.state.phaLe, 500);
    expect(b.potOwned('chau_song_ngu'), 0);
  });

  test('buying a Sơn Hải pot spends Pha lê only', () {
    final b = newSession();
    b.state.money = 99999999;
    b.state.phaLe = 600;
    expect(b.buyPot('chau_thao_thiet'), isTrue);
    expect(b.state.phaLe, 350);
    expect(b.state.money, 99999999);
    expect(b.potOwned('chau_thao_thiet'), 1);
    expect(b.buyPot('chau_ky_lan'), isTrue); // 350
    expect(b.state.phaLe, 0);
    // Not enough Pha lê: nothing changes, even with plenty of xu.
    expect(b.buyPot('chau_tinh_ve'), isFalse);
    expect(b.state.phaLe, 0);
    expect(b.state.money, 99999999);
    expect(b.potOwned('chau_tinh_ve'), 0);
    // No second copy of a pot, even with the Pha lê for it.
    b.state.phaLe = 250;
    expect(b.buyPot('chau_thao_thiet'), isFalse);
    expect(b.potOwned('chau_thao_thiet'), 1);
    expect(b.state.phaLe, 250);
  });

  test('the free bucket can never be bought', () {
    final b = newSession();
    b.state.money = 99999999;
    expect(b.buyPot('sage'), isFalse);
    expect(b.state.money, 99999999);
  });

  test(
    'potScale: 1.1 for Chòm sao and Sơn Hải, 1.0 for Linh vật and the bucket',
    () {
      expect(potScaleBySet, {'linhVat': 1.0, 'chomSao': 1.1, 'sonHai': 1.1});
      for (final id in [..._chomSao.keys, ..._sonHai.keys]) {
        expect(e.pot(id).potScale, 1.1, reason: id);
      }
      for (final p in e.pots.where((p) => p.set == 'linhVat')) {
        expect(p.potScale, 1.0, reason: p.id);
      }
      expect(e.pot('sage').potScale, 1.0);
    },
  );

  test('pot sets and collections are data from Hà Phương', () {
    expect(
      {for (final s in e.potSets) s.id: s.nameVi},
      {'linhVat': 'Linh vật', 'chomSao': 'Hoàng đạo', 'sonHai': 'Sơn Hải'},
    );
    final byId = {for (final c in e.potCollections) c.id: c};
    expect(byId.keys, containsAll(['tanThu', 'chomSao', 'sonHai1']));
    expect(byId['tanThu']!.nameVi, 'Linh vật');
    expect(byId['chomSao']!.nameVi, 'Hoàng đạo');
    expect(byId['sonHai1']!.nameVi, 'Sơn Hải');
    expect(byId['tanThu']!.rewardPhaLe, 100);
    expect(byId['chomSao']!.rewardPhaLe, 300);
    expect(byId['sonHai1']!.rewardPhaLe, 300);
    List<String> inSet(String set) => [
      for (final p in e.pots)
        if (p.set == set) p.id,
    ];
    expect(byId['tanThu']!.pots.toSet(), inSet('linhVat').toSet());
    expect(byId['chomSao']!.pots.toSet(), inSet('chomSao').toSet());
    expect(byId['sonHai1']!.pots.toSet(), inSet('sonHai').toSet());
    expect(byId['tanThu']!.pots.length, 8);
    expect(byId['chomSao']!.pots.length, 12);
    expect(byId['sonHai1']!.pots.length, 12);
  });

  test('every pot has a description from cosmetics.json that fits', () {
    final cos = loadTestData().cosmetics;
    for (final p in e.pots) {
      final lore = cos.find(p.id);
      expect(lore, isNotNull, reason: p.id);
      expect(lore!.nameVi, p.nameVi, reason: p.id);
      expect(lore.description.length, lessThanOrEqualTo(115), reason: p.id);
      expect(lore.description, isNotEmpty, reason: p.id);
    }
    expect(
      cos.find('chau_su_tu')!.description,
      startsWith('Chậu vàng nắng, bờm sư tử cam xoăn'),
    );
    expect(cos.find('chau_ho_cap')!.nameVi, 'Chậu Thiên Yết');
    expect(cos.find('qilin')!.nameVi, 'Chậu kỳ lân vàng');
  });

  testWidgets('Kho chậu: an xu pot shows Mua 8 tr and buys it', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = newSession();
    session.state.money = 5000000;
    session.openPotPicker(bar: true, index: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PotPopup(session: session)),
      ),
    );
    await tester.pump();
    final cell = find.byKey(const Key('pot-cell-chau_su_tu'));
    await tester.scrollUntilVisible(cell, 80);
    await tester.ensureVisible(cell);
    await tester.pump();
    await tester.tap(cell);
    await tester.pump();
    expect(find.text('Mua 8 tr'), findsOneWidget);
    // Not enough: grey button, "Chưa đủ xu", tapping says how much is missing.
    expect(find.byKey(const Key('buy-short-chau_su_tu')), findsOneWidget);
    expect(find.text('Chưa đủ xu'), findsOneWidget);
    await tester.tap(find.byKey(const Key('buy-chau_su_tu')));
    await tester.pump();
    expect(find.textContaining('Còn thiếu'), findsOneWidget);
    expect(find.textContaining('xu'), findsWidgets);
    expect(session.potOwned('chau_su_tu'), 0);
    await tester.pump(const Duration(seconds: 3));
    session.state.money = 10000000;
    // The popup does not listen; the shop screen rebuilds it.
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PotPopup(session: session)),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('buy-short-chau_su_tu')), findsNothing);
    await tester.tap(find.byKey(const Key('buy-chau_su_tu')));
    await tester.pump();
    expect(session.potOwned('chau_su_tu'), 1);
    expect(session.state.money, 2000000);
  });

  testWidgets('Kho chậu: a Pha lê pot behaves like the pet shop', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = newSession();
    session.state.money = 99999999;
    session.state.phaLe = 100;
    session.openPotPicker(bar: true, index: 0);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PotPopup(session: session)),
      ),
    );
    await tester.pump();
    final cell = find.byKey(const Key('pot-cell-chau_thao_thiet'));
    await tester.scrollUntilVisible(cell, 80);
    await tester.ensureVisible(cell);
    await tester.pump();
    await tester.tap(cell);
    await tester.pump();
    expect(find.text('Mua 250 Pha lê'), findsOneWidget);
    expect(find.text('Chưa đủ Pha lê'), findsOneWidget);
    // Plenty of xu does not help; tapping shows the missing Pha lê.
    await tester.tap(find.byKey(const Key('buy-chau_thao_thiet')));
    await tester.pump();
    expect(find.text('Còn thiếu 150 Pha lê'), findsOneWidget);
    expect(session.potOwned('chau_thao_thiet'), 0);
    expect(session.state.money, 99999999);
    await tester.pump(const Duration(seconds: 3));
    session.state.phaLe = 300;
    // The popup does not listen; the shop screen rebuilds it.
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: PotPopup(session: session)),
      ),
    );
    await tester.pump();
    expect(find.text('Chưa đủ Pha lê'), findsNothing);
    await tester.tap(find.byKey(const Key('buy-chau_thao_thiet')));
    await tester.pump();
    expect(session.potOwned('chau_thao_thiet'), 1);
    expect(session.state.phaLe, 50);
    expect(session.state.money, 99999999);
  });

  test('the 12 new flowers are playable, with fresh and wilted art', () {
    for (final id in _flowers.keys) {
      final f = e.flower(id);
      expect(f.nameVi, _flowers[id], reason: id);
      expect(f.wiltedArt, isTrue, reason: id);
      expect(File(Art.flower(id)).existsSync(), isTrue, reason: id);
      expect(File(Art.flowerWilted(id)).existsSync(), isTrue, reason: id);
    }
    expect(e.flowers.length, 24 + 12);
    expect({for (final f in e.flowers) f.id}.length, e.flowers.length);
    expect(e.newFlowers, isEmpty, reason: 'moved to flowers[]');
    // The old 24 have no wilted picture and keep drooping only.
    expect(e.flower('rose').wiltedArt, isFalse);
    expect(Art.flowerWilted('sen'), 'assets/images/flowers/sen_heo.webp');
  });

  test(
    'new flower prices, freshness, bundles and unlock costs (Hà Phương)',
    () {
      // id: buy, sell, freshnessDays, bundle, unlockCost
      const want = <String, List<int>>{
        'luu_ly': [3000, 5000, 4, 10, 200000],
        'sao_nhai': [3500, 6000, 3, 10, 230000],
        'oai_huong': [6500, 11000, 5, 10, 300000],
        'hoa_su': [8000, 13500, 3, 5, 340000],
        'hoa_tra': [9000, 15500, 4, 5, 380000],
        'hoa_dao': [11000, 19000, 4, 5, 420000],
        'hoa_mai': [12000, 21000, 4, 5, 450000],
        'tu_dang': [12000, 21000, 3, 5, 520000],
        'thien_dieu': [16000, 28000, 5, 5, 600000],
        'sen': [20000, 34000, 2, 3, 650000],
        'moc_lan': [22000, 38000, 4, 3, 750000],
        'bi_ngan': [25000, 45000, 3, 3, 800000],
      };
      expect(want.keys.toSet(), _flowers.keys.toSet());
      for (final en in want.entries) {
        final f = e.flower(en.key);
        expect(
          [
            f.buyPrice,
            f.sellPrice,
            f.freshnessDays,
            f.bundleSize,
            f.unlockCost,
          ],
          en.value,
          reason: en.key,
        );
        expect(f.sellPrice, greaterThan(f.buyPrice), reason: en.key);
        // Locked at the start, unlocked by paying unlockCost like the others.
        expect(e.unlockedFlowers, isNot(contains(en.key)), reason: en.key);
      }
    },
  );

  test('customers ask for the new flowers on the right occasions', () {
    const want = <String, List<String>>{
      'birthday': ['luu_ly', 'sao_nhai', 'oai_huong', 'hoa_dao', 'tu_dang'],
      'thanks': ['luu_ly', 'sao_nhai', 'oai_huong', 'hoa_su', 'hoa_tra', 'sen'],
      'graduation': ['luu_ly', 'sao_nhai', 'hoa_mai', 'thien_dieu', 'bi_ngan'],
      'opening': [
        'hoa_su',
        'hoa_dao',
        'hoa_mai',
        'thien_dieu',
        'sen',
        'moc_lan',
      ],
      'confession': ['hoa_tra', 'hoa_dao', 'tu_dang', 'moc_lan', 'bi_ngan'],
      'wedding': ['tu_dang', 'sen', 'moc_lan'],
    };
    final fresh = _flowers.keys.toSet();
    for (final o in e.occasions) {
      final got = o.species.where(fresh.contains).toSet();
      expect(got, (want[o.id] ?? const <String>[]).toSet(), reason: o.id);
      for (final id in o.species) {
        expect(() => e.flower(id), returnsNormally, reason: '${o.id}: $id');
      }
    }
    // Bỉ ngạn means farewell: confession and graduation, never a wedding.
    final biNgan = [
      for (final o in e.occasions)
        if (o.species.contains('bi_ngan')) o.id,
    ];
    expect(biNgan.toSet(), {'confession', 'graduation'});
  });

  test('Tết features hoa mai and hoa đào at x1.3 market price', () {
    final tet = e.holidays.firstWhere((h) => h.id == 'tet');
    expect(tet.featuredFlowers, containsAll(['hoa_mai', 'hoa_dao']));
    // The poster and popup draw the first 3 icons: Tết's own flowers lead.
    expect(tet.featuredFlowers.take(3), ['hoa_mai', 'hoa_dao', 'orchid']);
    expect(tet.marketPriceMultiplier, 1.3);
    final day = tet.days.first;
    final mai = e.flower('hoa_mai');
    expect(e.bundlePrice(mai, day), (12000 * 5 * 1.3).round());
    expect(e.bundlePrice(mai, 1), 12000 * 5);
    // Not featured: hoa sứ stays at base price on Tết.
    final su = e.flower('hoa_su');
    expect(e.bundlePrice(su, day), 8000 * 5);
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

  testWidgets('Kho chậu lists every pot and wraps the long name', (
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
    final cell = find.byKey(const Key('pot-cell-chau_ky_lan'));
    await tester.scrollUntilVisible(cell, 80);
    await tester.ensureVisible(cell);
    await tester.pump();
    expect(cell, findsOneWidget);
    await tester.tap(cell);
    await tester.pump();
    final title = tester.widget<Text>(find.byKey(const Key('pot-detail-name')));
    expect(title.data, 'Chậu kỳ lân xanh');
    expect(title.maxLines, 2);
    // Owned: no second copy is sold, but it can be placed.
    expect(find.byKey(const Key('buy-chau_ky_lan')), findsNothing);
    expect(find.byKey(const Key('place-chau_ky_lan')), findsOneWidget);
  });
}
