import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/skins.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final skins = loadTestData().skins;
  final block =
      (jsonDecode(File('assets/data/economy.json').readAsStringSync())
              as Map<String, dynamic>)['skins']
          as Map<String, dynamic>;

  test('48 skins: 6 themes in each of the 8 slots of the skins block', () {
    expect(skins.list, hasLength(48));
    final slots = [
      ...(block['slots']['shop'] as List),
      ...(block['slots']['petRoom'] as List),
    ];
    // The block keeps the avatar frames with the shop; the shop draws only
    // [skinShopSlots].
    expect(slots, [
      ...skinShopSlots.take(1),
      skinAvatarFrameSlot,
      ...skinShopSlots.skip(1),
      ...skinRoomSlots,
    ]);
    for (final slot in slots) {
      final list = skins.ofSlot(slot as String);
      expect(list, hasLength(6), reason: slot);
      expect(list.first.id, skins.defaultId(slot));
      expect(list.first.isDefault, isTrue);
    }
  });

  test('names come from ten_skin.json, ids are {slot}_{chu_de}', () {
    final s = skins.byId('bien_hieu_trung_thu')!;
    expect(s.name, 'Biển Đèn Cá Chép');
    expect(s.tier, 'dep');
    expect(s.asset, 'assets/images/skin/tiem/bien_hieu_trung_thu.webp');
    expect(
      skins.byId('nen_phong_tet')!.asset,
      'assets/images/skin/phong_pet/nen_phong_tet.webp',
    );
    expect(skins.ui('skin.buyN', {'n': 2}), 'Mua 2 món');
    expect(skins.ui('skin.save'), 'Lưu');
  });

  test('prices: xu by game day, Pha lê by tier, backgrounds x1.5', () {
    final tiers = block['tiers'] as Map<String, dynamic>;
    final days = tiers['thuong']['priceByGameDay'] as List;
    final he = skins.byId('quay_he_bien')!;
    for (final row in days) {
      final p = skins.priceOf(he, row['fromDay'] as int);
      expect(p.currency, skinCurrencyXu);
      expect(p.amount, row['price']);
    }
    final bg = skins.priceOf(skins.byId('nen_man_hinh_he_bien')!, 1);
    expect(bg.amount, ((days.first['price'] as int) * 1.5).round());
    final tet = skins.priceOf(skins.byId('bat_an_tet')!, 1);
    expect(tet.phaLe, isTrue);
    expect(tet.amount, tiers['dep']['price']);
    final hiem = skins.priceOf(skins.byId('nen_phong_son_hai')!, 1);
    expect(hiem.amount, ((tiers['hiem']['price'] as int) * 1.5).round());
    expect(skins.priceOf(skins.byId('quay_bxh_mua1')!, 1).amount, 0);
    expect(skins.byId('quay_bxh_mua1')!.isEvent, isTrue);
    expect(skins.priceOf(skins.byId('quay_mac_dinh')!, 300).amount, 0);
  });

  test('old cushion and bowl ids map to the default skins', () {
    expect(skins.byId('dem_xanh')!.id, 'cho_ngoi_mac_dinh');
    expect(skins.byId('bat_la')!.id, 'bat_an_mac_dinh');
  });
}
