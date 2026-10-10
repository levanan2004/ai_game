import 'dart:math';

import 'package:ai_game/logic/customers.dart';
import 'package:ai_game/logic/format.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  final e = loadTestData().economy;

  group('first-day tutorial (spec_popup_va_mo_dau.md §6)', () {
    test(
      'runs through all 8 steps with an easy, patient first customer',
      () async {
        final backing = <String, String>{};
        final s = newSession(backing: backing);
        s.showTitle();
        expect(s.hasSave, isFalse);
        s.startNewGame();
        expect(s.tutorialStep, 1);

        final rose = e.unlockedFlowers.first;
        s.addBundle(rose);
        expect(s.tutorialStep, 2);
        s.removeBundle(rose);
        expect(s.tutorialStep, 1, reason: 'empty basket goes back to step 1');
        s.addBundle(rose);
        s.buyAndGoToShop();
        expect(s.tutorialStep, 3);
        // The clock stands still from step 3.
        s.openShop();
        expect(s.tutorialStep, 4);
        expect(s.queue.length, 1);
        final c = s.queue.single;
        expect(c.patienceLocked, isTrue);
        expect(c.request.stems.keys.single, rose);
        expect(c.request.total, lessThanOrEqualTo(s.stockCount(rose)));
        expect(e.unlockedPapers, contains(c.request.paperId));
        expect(e.unlockedRibbons, contains(c.request.ribbonId));
        final pending = s.state.pendingArrivals.length;
        for (var i = 0; i < 200; i++) {
          s.tick(0.5);
        }
        expect(s.state.elapsed, 0);
        expect(s.queue.length, 1, reason: 'no second customer before step 8');
        expect(s.state.pendingArrivals.length, pending);
        expect(c.patienceLeft, c.patienceMax);

        s.openTable();
        expect(s.tutorialStep, 5);
        s.tutorialCardTapped();
        expect(s.tutorialStep, 6);
        for (var i = 0; i < c.request.total; i++) {
          s.addStem(rose);
        }
        expect(s.tutorialStep, 6, reason: 'paper not chosen yet');
        s.selectPaper(c.request.paperId);
        expect(s.tutorialStep, 7);
        s.selectRibbon(c.request.ribbonId);
        expect(s.beginWrap(), isNotNull);
        s.tutorialWrapReleased();
        expect(s.tutorialStep, 8);
        s.finishWrap(hit: true);
        s.closeDeliveryPopup();
        expect(s.tutorialStep, 0);
        expect(s.state.tutorialDone, isTrue);
        s.tick(1);
        expect(s.state.elapsed, greaterThan(0));

        // The flag is written to the morning save even though the day isn't.
        await s.pendingSaves;
        final saved = await ProgressStore.memory(backing).load();
        expect(saved!.tutorialDone, isTrue);
        expect(saved.lifetimeBouquetsSold, 0);
      },
    );

    test('"Bỏ qua" ends it for good', () {
      final s = newSession();
      s.startNewGame();
      expect(s.tutorialActive, isTrue);
      s.skipTutorial();
      expect(s.tutorialActive, isFalse);
      s.backToTitle();
      s.continueGame();
      expect(s.tutorialActive, isFalse);
      s.startNewGame();
      expect(s.tutorialActive, isFalse, reason: 'Chơi mới keeps the flag');
    });

    test('view mode from the pause popup steps through the cards', () {
      final s = newSession();
      stockAndOpen(s);
      s.openPause();
      s.openTutorialView();
      expect(s.pauseMenuOpen, isFalse);
      expect(s.tutorialViewStep, 1);
      for (var i = 1; i < ShopSession.tutorialSteps; i++) {
        s.nextTutorialView();
      }
      expect(s.tutorialViewStep, ShopSession.tutorialSteps);
      s.nextTutorialView();
      expect(s.tutorialViewStep, 0);
      expect(s.pauseMenuOpen, isTrue);
      expect(s.paused, isTrue);
    });

    test('easyRequest: start items in stock, one species, fits the stock', () {
      for (var seed = 0; seed < 50; seed++) {
        final r = easyRequest(
          e,
          stock: {'rose': 5, 'baby': 10},
          rng: Random(seed),
        );
        expect(r.stems.keys.single, 'rose');
        expect(r.total, lessThanOrEqualTo(5));
        expect(r.fillerId, isNull);
        expect(r.paperId, e.unlockedPapers.first);
        expect(r.ribbonId, e.unlockedRibbons.first);
      }
    });
  });

  group('popups', () {
    test('rank up shows once on the morning after reaching the rank', () {
      final s = newSession();
      final r2 = e.shopRanks.firstWhere((r) => r.rank == 2);
      s.state.lifetimeBouquetsSold = r2.minBouquetsSold;
      finishDayAndCommit(s);
      expect(s.currentPopup, isA<RankUpPopup>());
      expect((s.currentPopup! as RankUpPopup).rank.rank, 2);
      expect(s.state.rankSeen, 2);
      s.closePopup();
      expect(s.currentPopup, isNull);
      finishDayAndCommit(s);
      expect(s.popups.whereType<RankUpPopup>(), isEmpty);
    });

    test('order: rank up, then unlock, then holiday', () {
      final s = newSession();
      final h = e.holidays.first;
      s.state.day = h.days.first - 1;
      final r2 = e.shopRanks.firstWhere((r) => r.rank == 2);
      s.state.lifetimeBouquetsSold = r2.minBouquetsSold;
      finishDayAndCommit(s);
      expect(s.holidayToday, isNotNull);
      s.state.money = 1 << 30;
      final locked = e.flowers.firstWhere((f) => !s.owned.contains(f.id));
      expect(s.unlockItem(locked.id), isTrue);
      expect(s.popups.map((p) => p.runtimeType).toList(), [
        RankUpPopup,
        UnlockPopup,
        HolidayPopup,
      ]);
      expect((s.popups.last as HolidayPopup).holiday.id, s.holidayToday!.id);
    });

    test('holiday popup shows once per day, poster before it', () {
      final s = newSession();
      final h = e.holidays.first;
      s.state.day = h.days.first - 1 - e.posterDaysBefore;
      expect(s.posterHoliday, isNull);
      finishDayAndCommit(s);
      expect(s.posterHoliday!.$1.id, h.id);
      expect(s.posterHoliday!.$2, e.posterDaysBefore);
      expect(s.popups, isEmpty);
      while (s.holidayToday == null) {
        finishDayAndCommit(s);
      }
      expect(s.popups.whereType<HolidayPopup>().length, 1);
      s.closePopup();
      s.backToTitle();
      s.continueGame();
      expect(s.popups, isEmpty, reason: 'already seen today');
    });

    test('formatMultiplier writes 1,8 and 2', () {
      expect(formatMultiplier(1.8), '1,8');
      expect(formatMultiplier(2.0), '2');
    });
  });
}
