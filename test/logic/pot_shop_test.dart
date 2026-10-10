import 'package:ai_game/data/pot_book.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// `shortVi` of the 32 pots (SPEC_tiem_chau_hoa.md §8.1).
const _shortVi = <String, String>{
  'chau_bach_duong': 'Bạch Dương',
  'chau_kim_nguu': 'Kim Ngưu',
  'chau_song_tu': 'Song Tử',
  'chau_cu_giai': 'Cự Giải',
  'chau_su_tu': 'Sư Tử',
  'chau_xu_nu': 'Xử Nữ',
  'chau_thien_binh': 'Thiên Bình',
  'chau_ho_cap': 'Thiên Yết',
  'chau_nhan_ma': 'Nhân Mã',
  'chau_ma_ket': 'Ma Kết',
  'chau_bao_binh': 'Bảo Bình',
  'chau_song_ngu': 'Song Ngư',
  'chau_thao_thiet': 'Thao Thiết',
  'chau_cung_ky': 'Cùng Kỳ',
  'chau_hon_don': 'Hỗn Độn',
  'chau_dao_ngot': 'Đào Ngột',
  'chau_cuu_vi_ho': 'Cửu Vĩ Hồ',
  'chau_tat_phuong': 'Tất Phương',
  'chau_ky_lan': 'Kỳ lân xanh',
  'chau_chuc_long': 'Chúc Long',
  'chau_con_bang': 'Côn Bằng',
  'chau_bach_trach': 'Bạch Trạch',
  'chau_tinh_ve': 'Tinh Vệ',
  'chau_de_giang': 'Đế Giang',
  'koi': 'Cá chép',
  'crane': 'Hạc',
  'nghe': 'Nghê',
  'tortoise': 'Huyền vũ',
  'tiger': 'Bạch hổ',
  'qilin': 'Kỳ lân vàng',
  'phoenix': 'Phượng hoàng',
  'dragon': 'Rồng thiên',
};

ShopSession _day(int day, {int money = 50000000, int phaLe = 2000}) {
  final s = newSession();
  s.state.day = day;
  s.state.money = money;
  s.state.phaLe = phaLe;
  s.buyAndGoToShop(); // preparing
  return s;
}

void main() {
  group('catalog of the shop', () {
    test('32 pots in 3 groups, in the book order, all with a shortVi', () {
      final s = newSession();
      expect(potGroupIds, ['chomSao', 'sonHai', 'linhVat']);
      expect(s.groupTotal('chomSao'), 12);
      expect(s.groupTotal('sonHai'), 12);
      expect(s.groupTotal('linhVat'), 8);
      final seen = <String>{};
      for (final g in potGroupIds) {
        for (final p in s.potGroupPots(g)) {
          expect(seen.add(p.id), isTrue, reason: 'one group per pot: ${p.id}');
          expect(s.potGroupOf(p), g);
          expect(p.shortVi, _shortVi[p.id], reason: p.id);
          expect(s.potShortName(p), _shortVi[p.id]);
          expect(s.potNumber(p), greaterThan(0));
        }
      }
      expect(seen.length, 32);
      expect(_shortVi.length, 32);
    });

    test('the shop lists cheapest first and keeps the book order on ties', () {
      final s = newSession();
      final sonHai = s.potShopList('sonHai').map((p) => p.id).toList();
      expect(sonHai, [
        'chau_thao_thiet',
        'chau_cung_ky',
        'chau_hon_don',
        'chau_dao_ngot',
        'chau_cuu_vi_ho',
        'chau_tat_phuong',
        'chau_tinh_ve',
        'chau_de_giang',
        'chau_ky_lan',
        'chau_chuc_long',
        'chau_con_bang',
        'chau_bach_trach',
      ]);
      final hd = s.potShopList('chomSao').map((p) => p.id).toList();
      expect(hd.first, 'chau_bach_duong');
      expect(hd.last, 'chau_song_ngu');
      expect(s.potShopList('linhVat').first.id, 'koi');
    });
  });

  group('buying', () {
    test('any number of copies, each at the listed price (10/10)', () {
      final s = _day(2);
      final xu = s.state.money;
      expect(s.potCanBuy(s.e.pot('chau_su_tu')), isTrue);
      expect(s.buyPot('chau_su_tu'), isTrue);
      expect(s.state.money, xu - 8000000);
      expect(s.potHas('chau_su_tu'), isTrue);
      // Owned or not, it can be bought; the price does not grow with copies.
      expect(s.potCanBuy(s.e.pot('chau_su_tu')), isTrue);
      expect(s.buyPot('chau_su_tu'), isTrue);
      expect(s.state.money, xu - 16000000);
      expect(s.buyPot('chau_su_tu'), isTrue);
      expect(s.state.money, xu - 24000000);
      expect(s.potOwned('chau_su_tu'), 3);
      // Same for a Pha lê pot.
      final pl = s.state.phaLe;
      expect(s.buyPot('chau_ky_lan'), isTrue);
      expect(s.buyPot('chau_ky_lan'), isTrue);
      expect(s.state.phaLe, pl - 700);
      expect(s.potOwned('chau_ky_lan'), 2);
      // The set counts kinds, not copies.
      expect(s.potsOwnedCount, 2);
    });

    test('xu pots spend xu, Pha lê pots spend Pha lê, and short is short', () {
      final s = _day(2, money: 3500000, phaLe: 100);
      final bd = s.e.pot('chau_bach_duong');
      final tt = s.e.pot('chau_thao_thiet');
      expect(s.potShortfall(bd), 0);
      expect(s.potShortfall(s.e.pot('chau_kim_nguu')), 500000);
      expect(s.potShortfall(tt), 150);
      expect(s.buyPot('chau_thao_thiet'), isFalse);
      expect(s.state.phaLe, 100);
      expect(s.buyPot('chau_bach_duong'), isTrue);
      expect(s.state.money, 500000);
      expect(s.state.phaLe, 100);
    });

    test('buying is allowed while the shop serves, placing is not', () async {
      final s = _day(2);
      s.openShop();
      expect(s.state.phase, DayPhase.open);
      expect(s.buyPot('chau_song_tu'), isTrue);
      expect(s.potPlaceAllowed, isFalse);
      expect(s.potPlaceable('chau_song_tu'), isFalse);
      expect(s.startPlaceMode('chau_song_tu'), isFalse);
      expect(s.pendingPlacePotId, isNull);
      expect(s.placeModeActive, isFalse);
    });

    test('a buy is in the morning save', () async {
      final born = newSession().state
        ..money = 10000000
        ..phaLe = 400;
      final raw = born.encode();
      final backing = <String, String>{};
      await ProgressStore.memory(backing).save(GameState.decode(raw)!);
      final s = newSession(backing: backing, saved: GameState.decode(raw));
      expect(s.buyPot('chau_cu_giai'), isTrue);
      expect(s.buyPot('chau_tinh_ve'), isTrue);
      s.openPotShop();
      s.claimCollection('linhVat'); // not complete: nothing
      await s.pendingSaves;
      final back = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(back.potCounts['chau_cu_giai'], 1);
      expect(back.potCounts['chau_tinh_ve'], 1);
      expect(back.phaLe, 100);
      expect(back.money, 3500000);
      expect(back.potShopHintShown, isTrue);
      expect(back.potShopSeenIds, isNotEmpty);
    });
  });

  group('red dot and the one reminder', () {
    test('the dot is on until the shop is visited, back on for a new pot', () {
      final s = _day(2);
      expect(s.potShopRedDot, isTrue);
      s.openPotShop();
      expect(s.screen, Screen.potShop);
      expect(s.potShopRedDot, isFalse);
      expect(s.state.potShopSeenIds.length, s.potShopOnSale.length);
      expect(s.state.potShopHintShown, isTrue); // found it by themselves
      // A pot that was not on sale at the last visit appears.
      s.state.potShopSeenIds.remove('chau_song_ngu');
      expect(s.potShopRedDot, isTrue);
      s.closePotShop();
      s.openPotShop();
      expect(s.potShopRedDot, isFalse);
    });

    test('the seen list and the flag are saved', () {
      final s = _day(2);
      s.openPotShop();
      final back = GameState.decode(s.state.encode())!;
      expect(back.potShopSeenIds, containsAll(s.potShopOnSale));
      expect(back.potShopHintShown, isTrue);
      expect(back.claimedSets, isEmpty);
    });

    test('hint box A: day 2+, preparing, a pot they can pay, only once', () {
      final s = _day(2);
      expect(s.potHintBoxDue, isTrue);
      s.markPotHintShown();
      expect(s.potHintBoxDue, isFalse);
      expect(s.state.potShopHintShown, isTrue);

      expect(_day(1).potHintBoxDue, isFalse, reason: 'day 1');
      expect(_day(2, money: 2999999, phaLe: 0).potHintBoxDue, isFalse);
      // Pha lê alone is enough for form A.
      expect(_day(2, money: 0, phaLe: 250).potHintBoxDue, isTrue);
      final open = _day(2)..openShop();
      expect(open.potHintBoxDue, isFalse, reason: 'never while open');
    });

    test('card B: only an xu pot, the cheapest they can pay', () {
      final s = _day(2, money: 4200000, phaLe: 5000);
      s.state.phase = DayPhase.summary;
      expect(s.potNudgeCardPot?.id, 'chau_bach_duong');
      s.state.potCounts['chau_bach_duong'] = 1;
      expect(s.potNudgeCardPot?.id, 'chau_kim_nguu');
      s.state.money = 1000000;
      expect(s.potNudgeCardPot, isNull, reason: 'Pha lê pots get no card');
      s.state.money = 5000000;
      s.markPotHintShown();
      expect(s.potNudgeCardPot, isNull, reason: 'one flag for both forms');
    });
  });

  group('placing mode', () {
    test('place a new pot on a chosen slot; the old one goes back', () {
      final s = _day(2);
      s.state.potCounts['chau_song_tu'] = 1;
      s.state.potCounts['chau_su_tu'] = 1;
      s.state.barPots[2] = 'chau_su_tu';
      expect(s.startPlaceMode('chau_song_tu'), isTrue);
      expect(s.placeModeActive, isTrue);
      expect(s.screen, Screen.shop);
      // Nothing is chosen yet.
      expect(s.confirmPlace(), isFalse);
      s.previewPlaceSlot(bar: true, index: 2);
      expect(
        s.state.barPots[2],
        'chau_su_tu',
        reason: 'a preview moves nothing',
      );
      s.clearPlacePreview();
      expect(s.pendingPlaceBar, isNull);
      s.previewPlaceSlot(bar: true, index: 2);
      expect(s.confirmPlace(), isTrue);
      expect(s.state.barPots[2], 'chau_song_tu');
      expect(s.potPlaced('chau_su_tu'), 0, reason: 'old pot is back in stock');
      expect(s.potOwned('chau_su_tu'), 1);
      expect(s.placeModeActive, isFalse);
      expect(s.pendingPlacePotId, isNull);
    });

    test('the stand slots work too, and Thôi leaves everything', () {
      final s = _day(2);
      s.state.potCounts['koi'] = 1;
      expect(s.startPlaceMode('koi'), isTrue);
      s.previewPlaceSlot(bar: false, index: 5);
      s.cancelPlaceMode();
      expect(s.state.displayPots[5], defaultPotId);
      expect(s.placeModeActive, isFalse);
      expect(s.startPlaceMode('koi'), isTrue);
      s.previewPlaceSlot(bar: false, index: 5);
      expect(s.confirmPlace(), isTrue);
      expect(s.state.displayPots[5], 'koi');
    });

    test('a pot with no spare copy cannot be placed again', () {
      final s = _day(2);
      s.state.potCounts['koi'] = 1;
      s.state.barPots[0] = 'koi';
      expect(s.potHasSpare('koi'), isFalse);
      expect(s.startPlaceMode('koi'), isFalse);
      expect(s.startPlaceMode('chau_su_tu'), isFalse, reason: 'not owned');
    });

    test('opening the shop ends the mode', () {
      final s = _day(2);
      s.state.potCounts['koi'] = 1;
      s.startPlaceMode('koi');
      s.openShop();
      expect(s.pendingPlacePotId, isNull);
      expect(s.placeModeActive, isFalse);
    });

    test('11 slots: 5 on the bar and 6 on the stand', () {
      expect(barPotSlots, 5);
      expect(displayPotSlots, 6);
    });
  });

  group('screens and Back', () {
    test('shop, then the book, back to the shop, back to the main screen', () {
      final s = _day(2);
      s.openPotShop();
      s.openPotBook(group: 'sonHai');
      expect(s.screen, Screen.potBook);
      expect(s.potBookTab, 'sonHai');
      s.closePotBook();
      expect(s.screen, Screen.potShop);
      s.closePotShop();
      expect(s.screen, Screen.shop);
    });

    test('Mua ở Tiệm from the book replaces the shop on the stack', () {
      final s = _day(2);
      s.openPotShop();
      s.openPotBook(detail: 'chau_ky_lan');
      expect(s.potBookDetailId, 'chau_ky_lan');
      expect(s.potBookTab, 'sonHai');
      s.openPotShop(group: 'sonHai', focus: 'chau_ky_lan');
      expect(s.screen, Screen.potShop);
      expect(s.potShopTab, 'sonHai');
      expect(s.potShopFocusId, 'chau_ky_lan');
      s.closePotShop();
      expect(s.screen, Screen.shop, reason: 'no loop back to the book');
    });

    test('a detail page closes before the book does', () {
      final s = _day(2);
      s.openPotBook(detail: 'koi');
      s.closePotBook();
      expect(s.screen, Screen.potBook);
      expect(s.potBookDetailId, isNull);
      s.closePotBook();
      expect(s.screen, Screen.shop);
    });

    test('from Tổng kết Back returns to Tổng kết', () {
      final s = _day(2);
      s.state.phase = DayPhase.summary;
      s.screen = Screen.summary;
      s.openPotShop(group: 'chomSao', focus: 'chau_bach_duong');
      s.closePotShop();
      expect(s.screen, Screen.summary);
    });
  });

  group('collection rewards', () {
    test('a full set is claimed once, with a saved flag', () {
      final s = _day(2, phaLe: 10);
      expect(s.collectionReward('linhVat'), 100);
      expect(s.collectionReward('chomSao'), 300);
      expect(s.collectionReward('sonHai'), 300);
      for (final p in s.potGroupPots('linhVat').skip(1)) {
        s.state.potCounts[p.id] = 1;
      }
      expect(s.collectionComplete('linhVat'), isFalse);
      expect(s.claimCollection('linhVat'), isFalse);
      s.state.potCounts['koi'] = 1;
      expect(s.collectionClaimable('linhVat'), isTrue);
      expect(s.claimCollection('linhVat'), isTrue);
      expect(s.state.phaLe, 110);
      expect(s.collectionClaimed('linhVat'), isTrue);
      expect(s.claimCollection('linhVat'), isFalse);
      expect(s.state.phaLe, 110);
      final back = GameState.decode(s.state.encode())!;
      expect(back.claimedSets, ['tanThu']);
    });

    test('a player who finished a set before can still claim it', () {
      final old = _day(30, phaLe: 0);
      for (final p in old.potGroupPots('chomSao')) {
        old.state.potCounts[p.id] = 1;
      }
      final reloaded = newSession(saved: GameState.decode(old.state.encode()));
      expect(reloaded.collectionComplete('chomSao'), isTrue);
      expect(reloaded.claimCollection('chomSao'), isTrue);
      expect(reloaded.state.phaLe, 300);
    });

    test('the last purchase of a set completes it', () {
      final s = _day(2, phaLe: 5000);
      for (final p in s.potGroupPots('sonHai').skip(1)) {
        s.state.potCounts[p.id] = 1;
      }
      expect(s.collectionComplete('sonHai'), isFalse);
      expect(s.buyPot('chau_thao_thiet'), isTrue);
      expect(s.collectionComplete('sonHai'), isTrue);
      expect(s.claimCollection('sonHai'), isTrue);
    });
  });
}
