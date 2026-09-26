import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// A plain bot plays ten whole days through the public session API:
/// market, serve every walk-in with the requested stems, summary, next day,
/// and spends spare money on upgrades and unlocks in the evening.
void main() {
  test('ten days play through without errors', () async {
    final backing = <String, String>{};
    final s = newSession(backing: backing, seed: 7);
    var openSeconds = 0.0;
    final lines = <String>[];

    for (var day = 1; day <= 10; day++) {
      expect(s.state.day, day);
      while (s.popups.isNotEmpty) {
        s.closePopup();
      }
      if (s.screen == Screen.preorders) s.closePopupAndGoToMarket();

      // Morning shopping (the only time upgrades are sold): keep 600k
      // for flowers and rent, spend the rest.
      final startMoney = s.state.money;
      for (final id in s.e.flowers.map((f) => f.id)) {
        if (s.canUnlock(id) && s.state.money > 600000) s.unlockItem(id);
      }
      for (final u in s.e.upgrades) {
        final st = s.statusOf(u.id);
        if (st.canBuy && s.state.money - st.next!.cost > 600000) {
          s.buyUpgrade(u.id);
        }
      }

      // Market: two bundles of each unlocked flower while cash allows.
      for (var round = 0; round < 2; round++) {
        for (final f in s.unlockedFlowers) {
          if (s.canAddBundle(f.id)) s.addBundle(f.id);
        }
      }
      s.buyAndGoToShop();
      expect(s.state.phase, DayPhase.preparing);
      s.openShop();
      expect(s.state.phase, DayPhase.open);

      var served = 0;
      var t = 0.0;
      final seen = <Object>{};
      while (s.state.phase == DayPhase.open && t < 2000) {
        s.tick(0.1);
        t += 0.1;
        seen.addAll(s.queue);
        while (s.popups.isNotEmpty) {
          s.closePopup();
        }
        if (s.paused) continue;
        if (s.screen == Screen.shop && s.nextForPlayer != null) s.openTable();
        final c = s.tableCustomer;
        if (s.screen == Screen.table && c != null && !s.wrapping) {
          s.resetDraft();
          c.request.stems.forEach((id, n) {
            for (var i = 0; i < n; i++) {
              s.addStem(id);
            }
          });
          final filler = c.request.fillerId;
          for (var i = 0; filler != null && i < c.request.fillerCount; i++) {
            s.addStem(filler);
          }
          if (s.draft.stems.isEmpty) {
            // Out of the wanted flowers: use whatever is left.
            for (final f in s.unlockedFlowers) {
              if (s.addStem(f.id)) break;
            }
          }
          s.selectPaper(
            s.owned.contains(c.request.paperId) ? c.request.paperId : 'kraft',
          );
          if (s.owned.contains(c.request.ribbonId)) {
            s.selectRibbon(c.request.ribbonId);
          }
          if (s.beginWrap() == null) {
            s.resetDraft();
            continue;
          }
          final r = s.finishWrap(hit: true);
          expect(r, isNotNull);
          served++;
          s.closeDeliveryPopup();
        }
      }
      openSeconds += t;
      expect(s.state.phase, DayPhase.summary, reason: 'day $day never closed');

      final m = s.state.metrics;
      lines.add(
        'Ngày $day${s.holidayToday == null ? '' : ' (${s.holidayToday!.nameVi})'}: '
        'khách ${seen.length}, bot bán $served, tổng bán ${m.bouquetsSold}, '
        'bỏ về ${m.customersLeft}, nhập ${m.marketSpend ~/ 1000}k, '
        'thu ${m.income ~/ 1000}k, héo ${m.stemsWilted}, '
        'nâng cấp ${s.state.upgradeLevels}, '
        'lãi ${m.profit ~/ 1000}k, '
        'tiền ${startMoney ~/ 1000}k -> ${s.state.money ~/ 1000}k, '
        'sao ${s.rating.average.toStringAsFixed(1)}, hạng ${s.rank.nameVi}, '
        'mở cửa ${t.toStringAsFixed(0)}s',
      );

      s.startNextDay();
      expect(s.state.phase, DayPhase.market);
      expect(s.state.stock.every((b) => b.count > 0), isTrue);
    }

    // The morning save of day 11 reloads into an identical session.
    await s.pendingSaves;
    final saved = GameState.decode(backing.values.first);
    expect(saved, isNotNull);
    expect(saved!.day, 11);
    expect(saved.money, s.state.money);

    // ignore: avoid_print
    print(
      '${lines.join('\n')}\nTổng thời gian mở cửa: '
      '${(openSeconds / 60).toStringAsFixed(1)} phút',
    );
  });
}
