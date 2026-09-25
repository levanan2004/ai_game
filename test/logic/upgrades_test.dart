import 'dart:math';

import 'package:ai_game/logic/payment.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/upgrades.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;

  /// Session in the preparing phase with plenty of money.
  ShopSession richSession({Map<String, String>? backing}) {
    final s = newSession(backing: backing);
    s.state.money = 50000000;
    return s;
  }

  group('status: requires, affordability, shop open, debt', () {
    test('requires blocks until the other upgrade has the level', () {
      final s = richSession();
      final staff = e.upgrade('staff');
      final lv2 = staff.levels[1];
      expect(lv2.requires, isNotEmpty);
      final (reqId, reqLv) = (lv2.requires.keys.first, lv2.requires.values.first);
      expect(s.buyUpgrade('staff'), isTrue);
      var st = s.statusOf('staff');
      expect(st.block, UpgradeBlock.requires);
      expect(st.requiresId, reqId);
      expect(st.requiresLevel, reqLv);
      expect(s.buyUpgrade('staff'), isFalse);
      for (var i = 0; i < reqLv; i++) {
        expect(s.buyUpgrade(reqId), isTrue);
      }
      st = s.statusOf('staff');
      expect(st.canBuy, isTrue);
      expect(s.buyUpgrade('staff'), isTrue);
      expect(s.state.upgradeLevels['staff'], 2);
      expect(s.statusOf('staff').block, UpgradeBlock.maxed);
    });

    test('price button needs enough money; buying subtracts the cost', () {
      final s = newSession();
      final cost = e.upgrade('bench').levels.first.cost;
      s.state.money = cost - 1;
      expect(s.statusOf('bench').block, UpgradeBlock.poor);
      expect(s.buyUpgrade('bench'), isFalse);
      s.state.money = cost;
      expect(s.statusOf('bench').canBuy, isTrue);
      expect(s.buyUpgrade('bench'), isTrue);
      expect(s.state.money, 0);
      expect(s.state.upgradeLevels['bench'], 1);
    });

    test('negative money disables every price, upgrades and unlocks', () {
      final s = newSession();
      s.state.money = -1000;
      for (final u in e.upgrades) {
        expect(s.statusOf(u.id).canBuy, isFalse, reason: u.id);
      }
      final locked = e.flowers.firstWhere((f) => !s.owned.contains(f.id));
      expect(s.canUnlock(locked.id), isFalse);
    });

    test('only while the shop is closed (market or preparing)', () {
      final s = richSession();
      expect(s.shopClosed, isTrue);
      stockAndOpen(s);
      expect(s.shopClosed, isFalse);
      expect(s.statusOf('bench').block, UpgradeBlock.shopOpen);
      expect(s.buyUpgrade('bench'), isFalse);
      s.openUpgrades();
      expect(s.screen, isNot(Screen.upgrades));
      expect(s.shopNotice, 'Nâng cấp khi tiệm đóng cửa nhé');
    });

    test('online orders are not implemented, so online is not for sale', () {
      final s = richSession();
      expect(s.statusOf('online').block, UpgradeBlock.comingSoon);
      expect(s.buyUpgrade('online'), isFalse);
    });

    test('ads: one purchase runs durationDays, then can be bought again', () {
      final s = richSession();
      final days = e.upgrade('ads').levels.first.durationDays!;
      expect(s.buyUpgrade('ads'), isTrue);
      expect(s.state.adsDaysLeft, days);
      expect(s.statusOf('ads').block, UpgradeBlock.adsRunning);
      expect(s.effects.customerMultiplier, greaterThan(1));
    });
  });

  group('effects apply in the game loop', () {
    test('bench: customers wait longer', () {
      final base = newSession(seed: 4);
      stockAndOpen(base);
      final c0 = waitForCustomer(base);
      final s = richSession();
      s.buyUpgrade('bench');
      stockAndOpen(s);
      final c1 = waitForCustomer(s);
      final mult = e.upgrade('bench').levels.first.effect['patienceMultiplier'] as num;
      expect(c1.patienceMax, closeTo(c0.patienceMax * mult, 1e-9));
    });

    test('display: more expected customers', () {
      final s = richSession();
      final before = s.expectedCustomers;
      s.buyUpgrade('display');
      final m = e.upgrade('display').levels.first.effect['customerMultiplier'] as num;
      expect(s.expectedCustomers, closeTo(before * m, 1e-9));
    });

    test('counter: more room before customers walk past', () {
      final s = richSession();
      final before = s.effects.counterSlots + s.effects.maxQueue;
      s.buyUpgrade('counter');
      final fx = e.upgrade('counter').levels.first.effect;
      expect(s.effects.counterSlots, fx['counterSlots']);
      expect(s.effects.maxQueue, fx['maxQueue']);
      expect(s.effects.counterSlots + s.effects.maxQueue, greaterThan(before));
    });

    test('cold storage: adds days to stock already on the shelf', () {
      final s = richSession();
      s.addBundle('rose');
      s.buyAndGoToShop();
      final before = s.oldestBatch('rose')!.freshnessLeft;
      s.buyUpgrade('cold_storage');
      final bonus = e.upgrade('cold_storage').levels.first.effect['freshnessBonusDays'] as num;
      expect(s.oldestBatch('rose')!.freshnessLeft, before + bonus);
      expect(s.fullFreshness(e.flower('rose')), e.flower('rose').freshnessDays + bonus);
    });

    test('wrapping table: wider green zone and shorter wrap', () {
      final s = richSession();
      final plain = wrapZoneFor(e, shopRank: 1, rng: Random(1), tableBonus: 0);
      final t0 = s.wrapAnimationSeconds;
      s.buyUpgrade('wrapping_table');
      final fx = e.upgrade('wrapping_table').levels.first.effect;
      final wide = wrapZoneFor(
        e,
        shopRank: 1,
        rng: Random(1),
        tableBonus: s.effects.greenZoneBonus,
      );
      expect(wide.width, closeTo(plain.width + (fx['greenZoneBonus'] as num), 1e-9));
      expect(
        s.wrapAnimationSeconds,
        closeTo(t0 * (1 - (fx['wrapTimeReduction'] as num)), 1e-9),
      );
    });

    test('staff: paper and ribbon are picked for you at the table', () async {
      final s = richSession();
      s.buyUpgrade('staff');
      stockAndOpen(s);
      final c = waitForCustomer(s);
      s.openTable();
      expect(s.draft.paperId, c.request.paperId);
      expect(s.draft.ribbonId, c.request.ribbonId);
    });

    test('upkeep and wages are paid at the end of the day', () {
      final s = richSession();
      s.buyUpgrade('cold_storage');
      s.buyUpgrade('staff');
      final upkeep = e.upgrade('cold_storage').levels.first.dailyUpkeep +
          e.upgrade('staff').levels.first.dailyWage;
      expect(s.todayUpkeep, upkeep);
      stockAndOpen(s);
      s.state.pendingArrivals.clear();
      for (var t = 0.0; t < s.e.dayRealSeconds + 1; t += 0.5) {
        s.tick(0.5);
      }
      expect(s.state.metrics.fixedCosts, e.fixedCostsTotal + upkeep);
    });

    test('levels, unlocks and ads survive a reload', () async {
      final backing = <String, String>{};
      final s = richSession(backing: backing);
      s.buyUpgrade('bench');
      s.buyUpgrade('ads');
      final locked = e.flowers.firstWhere((f) => !s.owned.contains(f.id));
      expect(s.unlockItem(locked.id), isTrue);
      await s.pendingSaves;
      final saved = await ProgressStore.memory(backing).load();
      final s2 = newSession(backing: backing, saved: saved);
      expect(s2.state.upgradeLevels['bench'], 1);
      expect(s2.state.adsDaysLeft, s.state.adsDaysLeft);
      expect(s2.owned.contains(locked.id), isTrue);
      expect(s2.unlockedFlowers.map((f) => f.id), contains(locked.id));
      expect(s2.state.phase, isNot(DayPhase.open));
    });
  });

  group('effect sentences (spec_nang_cap.md templates)', () {
    test('every level of every upgrade gets a sentence, no raw keys', () {
      for (final u in e.upgrades) {
        for (final l in u.levels) {
          final text = describeEffect(l.effect);
          expect(text, isNotEmpty, reason: '${u.id} ${l.level}');
          for (final k in l.effect.keys) {
            expect(text.contains(k), isFalse, reason: '${u.id}: $k');
          }
          expect(skippedEffectKeys(l.effect), isEmpty, reason: u.id);
        }
      }
    });

    test('templates', () {
      expect(describeEffect({'freshnessBonusDays': 2}), 'hoa tươi thêm 2 ngày');
      expect(
        describeEffect({'wrapTimeReduction': 0.25, 'greenZoneBonus': 0.03}),
        'gói nhanh hơn 25%, vùng xanh rộng hơn',
      );
      expect(describeEffect({'customerMultiplier': 1.15}), 'thêm 15% khách');
      expect(describeEffect({'patienceMultiplier': 1.2}), 'khách chờ lâu hơn 20%');
      expect(
        describeEffect({'counterSlots': 2, 'maxQueue': 5}),
        '2 chỗ ở quầy, hàng chờ 5 người',
      );
      expect(
        describeEffect({
          'autoPaperRibbon': true,
          'stemTimeReduction': 0.2,
          'autoServeSeconds': 30,
          'autoServeMaxStems': 7,
          'autoServeTier': 'okay',
        }),
        'tự chọn giấy và nơ, nhặt hoa nhanh hơn, '
        'nhân viên tự bó đơn tối đa 7 cành, mỗi đơn 30 giây',
      );
      expect(
        describeEffect({'deliveryFee': 20000, 'ordersPerDay': 2}),
        '2 đơn online mỗi ngày, thu phí giao 20k mỗi đơn',
      );
    });

    test('unknown keys, requires and _ keys are skipped without a crash', () {
      final fx = <String, Object>{
        'freshnessBonusDays': 1,
        'sparkleLevel': 3,
        '_note': 'x',
        'requires': {'counter': 1},
      };
      expect(describeEffect(fx), 'hoa tươi thêm 1 ngày');
      expect(skippedEffectKeys(fx), ['sparkleLevel']);
      expect(describeEffect({'mystery': true}), '');
    });
  });
}
