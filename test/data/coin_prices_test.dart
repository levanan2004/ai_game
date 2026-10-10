// The xu prices An approved on 10/10/2026 (Hà Phương's table), read from
// economy.json, and the labels built from them.
import 'package:ai_game/logic/price_format.dart';
import 'package:ai_game/ui/pot_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = newSession().e;

  test('12 Chòm sao pots: 3 to 30 million xu, 159.5M in all', () {
    const ids = [
      'chau_bach_duong',
      'chau_kim_nguu',
      'chau_song_tu',
      'chau_cu_giai',
      'chau_su_tu',
      'chau_xu_nu',
      'chau_thien_binh',
      'chau_ho_cap',
      'chau_nhan_ma',
      'chau_ma_ket',
      'chau_bao_binh',
      'chau_song_ngu',
    ];
    const millions = [3, 4, 5, 6.5, 8, 10, 12, 15, 18, 22, 26, 30];
    var total = 0;
    for (var i = 0; i < ids.length; i++) {
      final pot = e.pot(ids[i]);
      expect(pot.currency, 'coins', reason: ids[i]);
      expect(pot.price, (millions[i] * 1000000).round(), reason: ids[i]);
      total += pot.price;
      // howVi is "Mua {coinLabel} xu", at most 25 characters.
      expect(pot.howVi, 'Mua ${coinLabel(pot.price)} xu', reason: ids[i]);
      expect(pot.howVi!.length, lessThanOrEqualTo(25), reason: ids[i]);
      expect(potHowText(pot), pot.howVi, reason: ids[i]);
    }
    expect(total, 159500000);
    expect(e.pot('chau_cu_giai').howVi, 'Mua 6,5 tr xu');
  });

  test('potHowText follows the live price, whatever howVi says', () {
    final pot = e.pot('chau_song_ngu');
    expect(potHowText(pot), 'Mua 30 tr xu');
  });

  test('Sơn Hải and Linh vật stay in Pha lê', () {
    for (final id in e.pots.where((p) => p.set == 'sonHai').map((p) => p.id)) {
      final pot = e.pot(id);
      expect(pot.paysPhaLe, isTrue, reason: id);
      expect(pot.price, 0, reason: id);
      expect(pot.phaLePrice, greaterThan(0), reason: id);
    }
    expect(e.pot('phoenix').paysPhaLe, isTrue);
    expect(e.pot('phoenix').phaLePrice, 300);
  });

  test('pets: Mèo 1 tr, Cá chép 2,5 tr, Hạc 5 tr; the rest in Pha lê', () {
    expect(e.pet('meo')!.price, 1000000);
    expect(e.pet('ca_chep')!.price, 2500000);
    expect(e.pet('hac')!.price, 5000000);
    for (final p in e.pets.where((p) => p.paysPhaLe)) {
      expect(p.price, greaterThanOrEqualTo(300), reason: p.id);
    }
  });

  test('pet items: thường 2 tr, hiếm 20 tr, resale 30% of the price', () {
    for (final d in e.petItems) {
      switch (d.tier.key) {
        case 'thuong':
          expect(d.price, 2000000, reason: d.id);
          expect(d.currency, 'coins');
        case 'hiem':
          expect(d.price, 20000000, reason: d.id);
          expect(d.currency, 'coins');
        case 'suThi':
          expect(d.price, 120, reason: d.id);
          expect(d.currency, 'phaLe');
        default:
          expect(d.price, 300, reason: d.id);
          expect(d.currency, 'phaLe');
      }
      // The file's resaleValue is only a check: 30% of the current price.
      expect(d.resaleValue, (d.price * e.petItemResaleRate).floor());
    }
  });
}
