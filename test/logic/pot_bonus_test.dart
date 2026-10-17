import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/economy.dart';
import 'package:ai_game/logic/charm_rewards.dart';
import 'package:ai_game/logic/pot_bonus.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

const _sonHai = [
  'chau_cuu_vi_ho',
  'chau_chuc_long',
  'chau_con_bang',
  'chau_bach_trach',
  'chau_thao_thiet',
  'chau_cung_ky',
  'chau_hon_don',
  'chau_dao_ngot',
  'chau_tat_phuong',
  'chau_tinh_ve',
  'chau_de_giang',
  'chau_ky_lan',
];

/// Adult Kim long with three legendary items in the charm slot: 300 + 300.
ShopSession _fullPet() {
  final s = newSession();
  s.state.addPet('kim_long');
  s.state.petCharm = 'kim_long';
  final pet = s.state.ownedPet('kim_long')!;
  pet.stage = 2;
  pet.worn.addAll({
    'neck': 'day_chuyen_suong_mai',
    'head': 'vuong_mien_som_mai',
    'accessory': 'canh_binh_minh',
  });
  return s;
}

/// A session whose economy gives [potId] the [stats] instead.
ShopSession _withStats(String potId, Map<String, double> stats) {
  final j =
      jsonDecode(File('assets/data/economy.json').readAsStringSync())
          as Map<String, dynamic>;
  for (final p in j['pots'] as List) {
    if ((p as Map)['id'] == potId) p['stats'] = stats;
  }
  return newSession(data: loadTestData(economy: jsonEncode(j)));
}

/// Closes day 1 at once (no customers, no events), then puts [batch] in
/// stock and taps "Sang ngày mới".
void _nightWith(ShopSession s, StockBatch batch) {
  s.buyAndGoToShop();
  s.openShop();
  s.closeEarly();
  s.state.stock
    ..clear()
    ..add(batch);
  s.startNextDay();
}

void _fillShelf(GameState st, String id) {
  for (var i = 0; i < st.barPots.length; i++) {
    st.barPots[i] = id;
  }
  for (var i = 0; i < st.displayPots.length; i++) {
    st.displayPots[i] = id;
  }
}

void main() {
  group('economy data (Hà Phương, block v2)', () {
    test('Sơn Hải: not for sale, 60 Mị lực and one stat each', () {
      final e = newSession().e;
      for (final id in _sonHai) {
        final p = e.pot(id);
        expect(p.set, 'sonHai', reason: id);
        expect(p.buyable, isFalse, reason: id);
        expect(p.purchasable, isFalse, reason: id);
        expect(p.howVi, 'Vòng quay tuần', reason: id);
        expect(p.charm, 60, reason: id);
        expect(p.stats.length, 1, reason: id);
      }
      expect(e.pot('chau_dao_ngot').stats, {PotStat.wiltSaveChance: 0.05});
      expect(e.pot('chau_hon_don').stats, {PotStat.patienceBonus: 0.05});
      expect(e.pot('chau_cung_ky').stats, {PotStat.mouseCatch: 0.05});
      expect(e.pot('chau_cuu_vi_ho').stats, {PotStat.mysteryChance: 0.01});
    });

    test('Linh vật keep their price and get a small stat, no Mị lực', () {
      final e = newSession().e;
      final old = e.pots.where((p) => p.set == 'linhVat').toList();
      expect(old.length, 8);
      for (final p in old) {
        expect(p.purchasable, isTrue, reason: p.id);
        expect(p.charm, 0, reason: p.id);
        expect(p.stats.length, 1, reason: p.id);
      }
      expect(e.pot('koi').stats, {PotStat.incomeBonus: 0.005});
      for (final p in e.pots.where((p) => p.set == 'chomSao')) {
        expect(p.stats, isEmpty, reason: p.id);
        expect(p.charm, 0, reason: p.id);
      }
      expect(e.pot('sage').stats, isEmpty);
    });

    test('every stat key in the data is one the game knows', () {
      final raw =
          jsonDecode(File('assets/data/economy.json').readAsStringSync())
              as Map<String, dynamic>;
      final keys = <String>{
        for (final p in raw['pots'] as List)
          ...(((p as Map)['stats'] as Map?) ?? const {}).keys.cast<String>(),
      };
      expect(keys.difference(PotStat.all.toSet()), isEmpty);
      final rules = (raw['potStatsRules'] as Map)['keys'] as Map;
      expect(rules.keys.toSet(), PotStat.all.toSet());
      expect(newSession().e.potStatsRules.shelfSlots, 11);
    });

    test('gacha and VIP blocks load', () {
      final e = newSession().e;
      final g = e.gacha;
      expect(g.weeklyRotation, _sonHai);
      expect(g.weeklyRotation.first, 'chau_cuu_vi_ho');
      expect(g.tableWeight, 10000);
      expect(g.pityAt, 90);
      expect(g.ticketPhaLe, 20);
      expect(g.maxCoinTicketsPerDay, 5);
      expect(g.ticketCoinsOnDay(1), 1000000);
      expect(g.ticketCoinsOnDay(49), 1000000);
      expect(g.ticketCoinsOnDay(50), 3000000);
      expect(g.ticketCoinsOnDay(999), 10000000);
      expect(g.assetIdByPot.keys.toSet(), _sonHai.toSet());
      expect(g.assetIdByPot['chau_cuu_vi_ho'], 'cuu_vy');
      final itemIds = e.petItems.map((i) => i.id).toSet();
      for (final line in g.table) {
        for (final id in line.split) {
          expect(itemIds, contains(id));
        }
      }
      expect(g.table.first.ifOwnedCoins, 5000000);
      final v = e.vip;
      expect(v.tiers.length, 10);
      expect(v.tiers.fold(0, (a, t) => a + t.giftTickets), v.giftTicketsTotal);
      expect(v.levelFor(0), 0);
      expect(v.levelFor(50000), 1);
      expect(v.levelFor(15000000), 10);
      expect(v.pots['chau_ngoc_bich']!.level, 3);
    });

    test('missing blocks read as zero', () {
      expect(CharmRules.fromJson(null).total, 0);
      expect(GachaConfig.fromJson(null).table, isEmpty);
      expect(VipConfig.fromJson('x').levelFor(1 << 30), 0);
      expect(potStatsFromJson({'tipBonus': 0.02, 'nope': 1, 'income': 'x'}), {
        PotStat.tipBonus: 0.02,
      });
    });
  });

  group('Mị lực: pet + items + owned pot types', () {
    test('a Sơn Hải type counts once, shelf or cupboard', () {
      final s = _fullPet();
      expect(s.charmScore, 600);
      s.state.potCounts['chau_cuu_vi_ho'] = 3;
      expect(s.charmScore, 660);
      // Placing the copies on the shelf changes nothing.
      s.state.barPots[0] = 'chau_cuu_vi_ho';
      s.state.displayPots[0] = 'chau_cuu_vi_ho';
      expect(s.charmScore, 660);
      s.state.potCounts['chau_ky_lan'] = 1;
      expect(s.charmScore, 720);
      // A pot on the shelf that is not owned, or a Linh vật pot, adds none.
      s.state.barPots[1] = 'chau_tinh_ve';
      s.state.potCounts['koi'] = 2;
      s.state.potCounts['chau_de_giang'] = 0;
      expect(s.charmScore, 720);
      expect(recomputeCharm(s.state, s.e), s.charmScore);
    });

    test('no overall cap: all 12 types reach 1320', () {
      final s = _fullPet();
      for (final id in _sonHai) {
        s.state.potCounts[id] = 1;
      }
      expect(ownedPotsCharm(s.e, s.state), 720);
      expect(s.charmScore, 1320);
      expect(s.charmScore, greaterThan(600));
      expect(s.charmScore, s.e.charmRules.total);
    });

    test('each part is clamped to its own max', () {
      final s = newSession();
      final e = s.e;
      expect(clampCharmPart(900, e.charmRules.potsMax), 720);
      expect(clampCharmPart(-5, 300), 0);
      expect(clampCharmPart(50, 0), 50);
      // A small pet still gets the whole pot part; no pet, nothing.
      s.state.addPet('ca_chep');
      s.state.petCharm = 'ca_chep';
      s.state.potCounts['chau_chuc_long'] = 1;
      expect(s.charmScore, 10 + 60);
      s.state.petCharm = null;
      expect(s.charmScore, 0);
    });
  });

  group('pot stats count only on the shelf', () {
    test('owned in the cupboard adds nothing; on the shelf the values add', () {
      final s = newSession();
      s.state.potCounts['chau_thao_thiet'] = 2;
      s.state.potCounts['dragon'] = 1;
      expect(s.potShelf.tipBonus, 0);
      s.state.barPots[0] = 'chau_thao_thiet';
      expect(s.potShelf.tipBonus, closeTo(0.03, 1e-9));
      s.state.displayPots[0] = 'chau_thao_thiet';
      s.state.displayPots[1] = 'dragon';
      expect(s.potShelf.tipBonus, closeTo(0.07, 1e-9));
      expect(s.potShelf.incomeBonus, 0);
      expect(s.potShelf[PotStat.marketDiscount], 0);
    });

    test('income, tips and online orders are paid at close', () {
      final s = newSession(seed: 7);
      s.state.barPots[0] = 'chau_chuc_long'; // income 1,5%
      s.state.barPots[1] = 'chau_thao_thiet'; // tips 3%
      s.state.barPots[2] = 'chau_con_bang'; // online 3%
      s.buyAndGoToShop();
      s.openShop();
      s.state.metrics
        ..flowerIncome = 100000
        ..tipIncome = 20000
        ..onlineIncome = 50000;
      s.closeEarly();
      expect(s.state.phase, DayPhase.summary);
      // 1,5% of 170.000 + 3% of 20.000 + 3% of 50.000
      expect(s.state.metrics.potBonus, 2550 + 600 + 1500);
    });

    test('market discount and faster wrapping', () {
      final s = newSession();
      final rose = s.e.flower('rose');
      final full = s.bundlePrice(rose);
      final wrap = s.wrapAnimationSeconds;
      s.state.barPots[0] = 'chau_tat_phuong'; // market 2%
      s.state.barPots[1] = 'chau_de_giang'; // wrap 3%
      expect(s.bundlePrice(rose), (full * 0.98).round());
      expect(s.wrapAnimationSeconds, closeTo(wrap * 0.97, 1e-9));
    });

    test('wiltSaveChance: stems may skip the night tick, none lost', () {
      final s = _withStats('chau_dao_ngot', {PotStat.wiltSaveChance: 1.0});
      _nightWith(s, StockBatch(flowerId: 'rose', count: 10, freshnessLeft: 2));
      expect(s.state.stock.single.freshnessLeft, 1, reason: 'no pot yet');

      final p = _withStats('chau_dao_ngot', {PotStat.wiltSaveChance: 1.0});
      p.state.displayPots[0] = 'chau_dao_ngot';
      _nightWith(p, StockBatch(flowerId: 'rose', count: 10, freshnessLeft: 2));
      expect(p.state.stock.fold(0, (a, b) => a + b.count), 10);
      expect(p.state.stock.every((b) => b.freshnessLeft == 2), isTrue);

      // A real chance splits the batch; the stem count is kept.
      final r = newSession(seed: 3);
      _fillShelf(r.state, 'chau_dao_ngot'); // 11 x 5% = 55%
      _nightWith(r, StockBatch(flowerId: 'rose', count: 200, freshnessLeft: 3));
      final roses = r.state.stock.where((b) => b.flowerId == 'rose').toList();
      expect(roses.fold(0, (a, b) => a + b.count), 200);
      final kept = roses
          .where((b) => b.freshnessLeft == 3)
          .fold(0, (a, b) => a + b.count);
      expect(kept, inInclusiveRange(80, 140));
    });
  });

  test('pot card lines are Nhất\'s, numbers from the data', () {
    final e = newSession().e;
    expect(potStatLines(e, e.pot('chau_cuu_vi_ho')), [
      'Mị lực +60 (tính khi sở hữu)',
      'Khách thần bí +1%',
    ]);
    expect(potStatLines(e, e.pot('chau_dao_ngot')), [
      'Mị lực +60 (tính khi sở hữu)',
      'Giữ tươi thêm: 5% mỗi ngày',
    ]);
    expect(potStatLines(e, e.pot('crane')), ['Khách chờ lâu hơn +2%']);
    expect(potStatLines(e, e.pot('phoenix')), ['Gói hoa nhanh hơn 1,5%']);
    expect(
      potStatLines(e, e.pot('chau_tat_phuong')).last,
      'Giá hoa ở chợ rẻ hơn 2%',
    );
    expect(potStatLines(e, e.pot('chau_bach_duong')), isEmpty);
  });
}
