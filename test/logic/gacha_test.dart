import 'package:ai_game/data/firestore_gacha_history.dart';
import 'package:ai_game/logic/gacha.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/logic/world_chat.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// 0h Monday 12/10/2026 in Việt Nam: week 0 (Cửu Vĩ).
final weekStart0 = DateTime.utc(2026, 10, 11, 17);

/// Wednesday 14/10 10h VN, inside week 0.
final midWeek = DateTime.utc(2026, 10, 14, 3);

/// The server wallet of the weekly wheel (functions/wallet.js view, buyCards,
/// spin) in memory.
class FakeGachaWallet implements WalletApi {
  FakeGachaWallet({
    this.week = 0,
    Map<String, int>? cards,
    Map<String, Map<String, Object?>>? pity,
    this.phaLe = 1000,
    this.xuLeft = 10,
  }) : cards = cards ?? {},
       pity = pity ?? {};

  static const rotation = [
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

  int week;
  final Map<String, int> cards;
  final Map<String, Map<String, Object?>> pity;
  int phaLe;
  int xuLeft;
  String? failWith;
  List<Map<String, Object?>> nextResults = [];
  int seq = 0;
  final calls = <(String, Map<String, Object?>)>[];

  String get potId => rotation[week % rotation.length];

  Map<String, Object?> view() {
    final start = weekStart0.add(Duration(days: 7 * week));
    return {
      'phaLe': phaLe,
      'cards': {...cards},
      'week': {
        'index': week,
        'potId': potId,
        'nextPotId': rotation[(week + 1) % rotation.length],
        'weekStart': start.millisecondsSinceEpoch,
        'weekEnd': start.add(const Duration(days: 7)).millisecondsSinceEpoch,
        'daysLeft': 3,
      },
      'pity': {...pity},
      'pityAt': 90,
      'xuCardsToday': {'bought': 10 - xuLeft, 'max': 10, 'left': xuLeft},
      'price': {'phaLe': 20, 'coins': 1000000},
    };
  }

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    calls.add((name, data));
    final fail = failWith;
    if (fail != null && name != 'walletView') {
      failWith = null;
      throw WalletException(fail);
    }
    switch (name) {
      case 'gachaBuyCards':
        final n = data['count'] as int;
        cards[potId] = (cards[potId] ?? 0) + n;
        final pl = data['currency'] == 'phaLe';
        if (pl) {
          phaLe -= 20 * n;
        } else {
          xuLeft -= n;
        }
        return {
          'potId': potId,
          'count': n,
          'paid': pl ? {'phaLe': 20 * n} : {'coins': 1000000 * n},
          ...view(),
        };
      case 'gachaSpin':
        final n = data['count'] as int;
        cards[potId] = (cards[potId] ?? 0) - n;
        seq++;
        final res = nextResults.isNotEmpty
            ? nextResults
            : [
                for (var i = 0; i < n; i++)
                  {
                    'featured': false,
                    'dup': false,
                    'pity': false,
                    'items': RewardBundle([
                      const RewardItem.coins(200000),
                    ]).toJson(),
                  },
              ];
        return {
          'potId': potId,
          'mailId': 'gacha_me_$seq',
          'results': res,
          ...view(),
        };
    }
    return view();
  }
}

class FakeGachaMailbox implements GachaMailbox {
  final claimedIds = <String>[];
  List<String> pendingIds = [];

  @override
  Future<MailClaimResult> claim(String mailId) async {
    claimedIds.add(mailId);
    return MailClaimResult.claimed;
  }

  @override
  Future<List<String>> pendingSpinMails() async => [...pendingIds];
}

ShopSession gachaSession(
  FakeGachaWallet api, {
  DateTime? now,
  bool signedIn = true,
  GachaHistorySource? history,
  WorldChatSource? worldChat,
}) {
  final t = now ?? midWeek;
  final s = newSession(
    now: () => t,
    gachaHistory: history,
    worldChat: worldChat,
  );
  s.buyAndGoToShop();
  if (signedIn) {
    s.accountUid = 'me';
    s.walletApi = api;
  }
  return s;
}

Future<ShopSession> synced(
  FakeGachaWallet api, {
  DateTime? now,
  GachaHistorySource? history,
  WorldChatSource? worldChat,
}) async {
  final s = gachaSession(api, now: now, history: history, worldChat: worldChat);
  await s.syncWallet();
  return s;
}

void main() {
  group('config (block v2)', () {
    test('rotation from Cửu Vĩ on 12/10/2026, 12 weeks, repeats', () {
      final c = newSession().e.gacha;
      expect(c.offered, isTrue);
      expect(c.weeklyRotation, FakeGachaWallet.rotation);
      expect(
        c.potOfWeekAt(weekStart0.subtract(const Duration(minutes: 1))),
        isNull,
      );
      expect(c.potOfWeekAt(weekStart0), 'chau_cuu_vi_ho');
      expect(c.potOfWeekAt(midWeek), 'chau_cuu_vi_ho');
      expect(
        c.potOfWeekAt(weekStart0.add(const Duration(days: 7))),
        'chau_chuc_long',
      );
      expect(
        c.potOfWeekAt(weekStart0.add(const Duration(days: 7 * 12))),
        'chau_cuu_vi_ho',
      );
      expect(c.nextChangeAt(midWeek), weekStart0.add(const Duration(days: 7)));
      expect(c.pityAt, 90);
      expect(c.pityReminderAt, 60);
      expect(c.pityReminderDaysBeforeReset, 2);
    });

    test('nextWeekOf: when a pot comes back; the current one next round', () {
      final c = newSession().e.gacha;
      expect(
        c.nextWeekOf('chau_chuc_long', midWeek),
        weekStart0.add(const Duration(days: 7)),
      );
      expect(
        c.nextWeekOf('chau_cuu_vi_ho', midWeek),
        weekStart0.add(const Duration(days: 7 * 12)),
      );
      expect(c.nextWeekOf('chau_khong_co', midWeek), isNull);
    });

    test('gift card by mail: the pot of the week the mail arrived', () {
      final c = newSession().e.gacha;
      final week2 = weekStart0.add(const Duration(days: 15));
      expect(c.giftTicketPotAt(midWeek, week2), 'chau_cuu_vi_ho');
      expect(c.giftTicketPotAt(null, week2), 'chau_con_bang');
    });
  });

  test('wallet view: week index, start and last week of the counter', () {
    final w = WalletView.fromJson(
      FakeGachaWallet(
        week: 3,
        pity: {
          'chau_con_bang': {'n': 0, 'resetFrom': 41, 'lastWeek': 2},
        },
      ).view(),
    );
    expect(w.weekIndex, 3);
    expect(w.potOfWeek, 'chau_bach_trach');
    expect(w.weekStart, weekStart0.add(const Duration(days: 21)));
    expect(w.pity['chau_con_bang']!.lastWeek, 2);
    expect(w.pity['chau_con_bang']!.resetFrom, 41);
    expect(WalletView.fromJson(const {}).weekIndex, -1);
  });

  test('save: the four one-time flags survive a reload', () {
    final s = newSession();
    s.buyAndGoToShop();
    s.state
      ..gachaIntroShown = true
      ..gachaSeenWeek = 4
      ..gachaReminderWeek = 3
      ..gachaResetNoticeWeek = 2;
    final back = GameState.decode(s.state.encode())!;
    expect(back.gachaIntroShown, isTrue);
    expect(back.gachaSeenWeek, 4);
    expect(back.gachaReminderWeek, 3);
    expect(back.gachaResetNoticeWeek, 2);
    final fresh = GameState.decode(newSession().state.encode());
    if (fresh != null) {
      expect(fresh.gachaIntroShown, isFalse);
      expect(fresh.gachaSeenWeek, -1);
    }
  });

  group('entry', () {
    test(
      'red dot: new week not opened, or a card of this week unused',
      () async {
        final api = FakeGachaWallet();
        final s = await synced(api);
        final g = s.gacha;
        expect(g.potId, 'chau_cuu_vi_ho');
        expect(g.dot, isTrue, reason: 'week 0 not opened yet');
        g.openScreen();
        expect(s.state.gachaSeenWeek, 0);
        expect(g.dot, isFalse);
        g.closeScreen();
        api.cards['chau_cuu_vi_ho'] = 2;
        await s.syncWallet();
        expect(g.dot, isTrue, reason: 'unused card');
        api.cards
          ..clear()
          ..['chau_chuc_long'] = 3;
        await s.syncWallet();
        expect(g.dot, isFalse, reason: 'cards of another week do not count');
      },
    );

    test('no dot for a guest', () {
      final s = gachaSession(FakeGachaWallet(), signedIn: false);
      expect(s.gacha.dot, isFalse);
    });

    test('intro once: "Đóng" makes the icon blink, never again', () {
      final s = gachaSession(FakeGachaWallet());
      final g = s.gacha;
      expect(s.screen, Screen.shop);
      expect(g.introDue, isTrue);
      g.closeIntro(open: false);
      expect(g.glowSeq, 1);
      expect(g.open, isFalse);
      expect(g.introDue, isFalse);
      expect(s.state.gachaIntroShown, isTrue);
    });

    test('intro "Xem ngay" opens the wheel', () {
      final s = gachaSession(FakeGachaWallet());
      s.gacha.closeIntro(open: true);
      expect(s.gacha.open, isTrue);
      expect(s.gacha.glowSeq, 0);
      expect(s.gacha.introDue, isFalse);
    });
  });

  group('notices', () {
    test('reset notice once on the first open of a week', () async {
      final api = FakeGachaWallet(
        week: 1,
        pity: {
          'chau_cuu_vi_ho': {'n': 0, 'resetFrom': 37, 'lastWeek': 0},
        },
      );
      final s = await synced(api, now: weekStart0.add(const Duration(days: 8)));
      final g = s.gacha;
      g.openScreen();
      expect(g.popup, GachaPopup.notice);
      expect(g.notice!.kind, GachaNoteKind.resetNotice);
      g.closeNotice();
      expect(g.popup, GachaPopup.none);
      g.closeScreen();
      g.openScreen();
      expect(g.popup, GachaPopup.none);
      expect(s.state.gachaResetNoticeWeek, 1);
    });

    test('no reset notice when last week counted nothing', () async {
      final api = FakeGachaWallet(week: 1);
      final s = await synced(api, now: weekStart0.add(const Duration(days: 8)));
      s.gacha.openScreen();
      expect(s.gacha.popup, GachaPopup.none);
    });

    test('pity reminder: ≥60 in the last 2 days, once', () async {
      final api = FakeGachaWallet(
        pity: {
          'chau_cuu_vi_ho': {'n': 64},
        },
      );
      // Saturday 17/10 20h VN: 1 day 4 hours left.
      final sat = DateTime.utc(2026, 10, 17, 13);
      final s = await synced(api, now: sat);
      final g = s.gacha;
      g.openScreen();
      expect(g.notice?.kind, GachaNoteKind.reminder);
      expect(g.notice!.a, 64);
      expect(g.notice!.b, 90);
      expect(g.notice!.left, const Duration(days: 1, hours: 4));
      g.closeNotice();
      g.closeScreen();
      g.openScreen();
      expect(g.popup, GachaPopup.none);
    });

    test('no reminder mid-week or under 60', () async {
      final s1 = await synced(
        FakeGachaWallet(
          pity: {
            'chau_cuu_vi_ho': {'n': 70},
          },
        ),
      );
      s1.gacha.openScreen();
      expect(s1.gacha.popup, GachaPopup.none);
      final s2 = await synced(
        FakeGachaWallet(
          pity: {
            'chau_cuu_vi_ho': {'n': 59},
          },
        ),
        now: DateTime.utc(2026, 10, 17, 13),
      );
      s2.gacha.openScreen();
      expect(s2.gacha.popup, GachaPopup.none);
    });

    test('last day: countdown under one day', () async {
      final s = await synced(
        FakeGachaWallet(),
        now: DateTime.utc(2026, 10, 18, 3),
      );
      expect(s.gacha.lastDay, isTrue);
      final s2 = await synced(FakeGachaWallet());
      expect(s2.gacha.lastDay, isFalse);
      expect(s2.gacha.timeLeft, const Duration(days: 4, hours: 14));
    });
  });

  group('spin', () {
    test('missing cards open "Thiếu N thẻ", nothing is called', () async {
      final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 3});
      final s = await synced(api);
      final g = s.gacha;
      g.openScreen();
      final r = await g.spin(10);
      expect(r, isNull);
      expect(g.popup, GachaPopup.short);
      expect(g.missing, 7);
      expect(api.calls.where((c) => c.$1 == 'gachaSpin'), isEmpty);
    });

    test(
      'Quay 10 through gachaSpin; the results; claim-all via the mail',
      () async {
        final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 10});
        api.nextResults = [
          {
            'featured': true,
            'dup': false,
            'pity': true,
            'items': RewardBundle([
              const RewardItem.pot('chau_cuu_vi_ho', 1),
            ]).toJson(),
          },
          for (var i = 0; i < 9; i++)
            {
              'items': RewardBundle([const RewardItem.coins(200000)]).toJson(),
            },
        ];
        final s = await synced(api);
        final box = FakeGachaMailbox();
        final g = s.gacha..mailbox = box;
        g.openScreen();
        final r = await g.spin(10);
        expect(r, hasLength(10));
        expect(r!.first.featured, isTrue);
        expect(r.first.pity, isTrue);
        expect(api.calls.last.$2, {'count': 10});
        expect(g.cards, 0);
        g.showResults();
        expect(g.popup, GachaPopup.result);
        expect(await g.claimResults(), isTrue);
        expect(box.claimedIds, ['gacha_me_1']);
        expect(g.popup, GachaPopup.none);
      },
    );

    test('a refusal becomes a toast code', () async {
      final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 1});
      final s = await synced(api);
      api.failWith = 'not-current';
      expect(await s.gacha.spin(1), isNull);
      expect(s.gacha.toast?.kind, GachaNoteKind.spinFail);
      expect(s.gacha.toast?.code, 'not-current');
      expect(s.gacha.spinning, isFalse);
    });

    test('spin mails left unclaimed show and claim from the wheel', () async {
      final s = await synced(FakeGachaWallet());
      final box = FakeGachaMailbox()..pendingIds = ['gacha_me_7'];
      final g = s.gacha..mailbox = box;
      g.openScreen();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(g.pending, ['gacha_me_7']);
      await g.claimPending();
      expect(box.claimedIds, ['gacha_me_7']);
      expect(g.pending, isEmpty);
    });

    test('guests cannot spin', () async {
      final s = gachaSession(FakeGachaWallet(), signedIn: false);
      expect(await s.gacha.spin(1), isNull);
      expect(s.gacha.popup, GachaPopup.none);
    });
  });

  group('buy', () {
    test('xu: 10 a day; over the cap and out of the cap are toasts', () async {
      final api = FakeGachaWallet(xuLeft: 3);
      final s = await synced(api);
      s.state.money = 100000000;
      final g = s.gacha;
      expect(g.xuLeftToday, 3);
      expect(await g.buy(10, withPhaLe: false), isFalse);
      expect(g.toast?.kind, GachaNoteKind.xuOverLimit);
      expect(g.toast?.a, 3);
      api.xuLeft = 0;
      await s.syncWallet();
      expect(await g.buy(1, withPhaLe: false), isFalse);
      expect(g.toast?.kind, GachaNoteKind.xuDailyOut);
      expect(g.toast?.a, 10);
      expect(api.calls.where((c) => c.$1 == 'gachaBuyCards'), isEmpty);
    });

    test('xu buy goes through gachaBuyCards with the game day', () async {
      final api = FakeGachaWallet();
      final s = await synced(api);
      s.state.money = 5000000;
      final g = s.gacha;
      expect(await g.buy(1, withPhaLe: false), isTrue);
      final call = api.calls.last;
      expect(call.$1, 'gachaBuyCards');
      expect(call.$2['currency'], 'coins');
      expect(call.$2['count'], 1);
      expect(call.$2['gameDay'], s.state.day);
      expect(g.cards, 1);
      expect(g.toast?.kind, GachaNoteKind.buySuccess);
      expect(g.toast?.b, 1);
    });

    test('not enough xu / Pha lê: no call', () async {
      final api = FakeGachaWallet(phaLe: 10);
      final s = await synced(api);
      s.state.money = 0;
      expect(await s.gacha.buy(1, withPhaLe: false), isFalse);
      expect(s.gacha.toast?.kind, GachaNoteKind.notEnoughXu);
      expect(await s.gacha.buy(1, withPhaLe: true), isFalse);
      expect(s.gacha.toast?.kind, GachaNoteKind.notEnoughPl);
      expect(api.calls.where((c) => c.$1 == 'gachaBuyCards'), isEmpty);
    });

    test('Pha lê is unlimited; after "Thiếu" the spin follows', () async {
      final api = FakeGachaWallet(xuLeft: 0, cards: {'chau_cuu_vi_ho': 2});
      final s = await synced(api);
      final g = s.gacha..mailbox = FakeGachaMailbox();
      g.openScreen();
      await g.spin(10);
      expect(g.missing, 8);
      g.askPhaLe(g.missing);
      expect(g.popup, GachaPopup.plConfirm);
      expect(await g.buy(8, withPhaLe: true, thenSpin: true), isTrue);
      expect(
        api.calls.map((c) => c.$1),
        containsAllInOrder(['gachaBuyCards', 'gachaSpin']),
      );
      expect(
        api.calls.firstWhere((c) => c.$1 == 'gachaBuyCards').$2['currency'],
        'phaLe',
      );
      expect(g.results, hasLength(10));
      expect(g.popup, GachaPopup.result);
    });
  });

  test('Kho thẻ: one cell per type, this week first, then by return', () async {
    final api = FakeGachaWallet(
      cards: {'chau_ky_lan': 1, 'chau_con_bang': 4, 'chau_cuu_vi_ho': 2},
    );
    final s = await synced(api);
    expect(s.gacha.inventory.map((e) => e.key), [
      'chau_cuu_vi_ho',
      'chau_con_bang',
      'chau_ky_lan',
    ]);
    expect(s.gacha.inventory.first.value, 2);
    api.cards.remove('chau_cuu_vi_ho');
    await s.syncWallet();
    expect(s.gacha.inventory.first, isA<MapEntry<String, int>>());
    expect(s.gacha.inventory.first.key, 'chau_cuu_vi_ho');
    expect(s.gacha.inventory.first.value, 0);
  });

  group('history (everyone)', () {
    test('ledger rows read as spins, others skipped', () {
      final at = DateTime.utc(2026, 10, 13, 5);
      final r = readSpinRecord({
        'type': 'spin',
        'potId': 'chau_cuu_vi_ho',
        'at': at,
        'results': [
          {
            'items': RewardBundle([const RewardItem.coins(500000)]).toJson(),
          },
        ],
      })!;
      expect(r.potId, 'chau_cuu_vi_ho');
      expect(r.at, at);
      expect(r.results.single.items.items.single.amount, 500000);
      expect(readSpinRecord({'type': 'buyCards', 'at': at}), isNull);
    });

    test('loads newest first for a player with no VIP', () async {
      final hist = MemoryGachaHistory([
        SpinRecord(
          at: DateTime.utc(2026, 10, 12),
          potId: 'chau_cuu_vi_ho',
          results: const [],
        ),
        SpinRecord(
          at: DateTime.utc(2026, 10, 13),
          potId: 'chau_cuu_vi_ho',
          results: const [],
        ),
      ]);
      final s = await synced(FakeGachaWallet(), history: hist);
      s.gacha.showPopup(GachaPopup.history);
      await Future<void>.delayed(Duration.zero);
      expect(s.gacha.historyRows!.first.at, DateTime.utc(2026, 10, 13));
      hist.fail = true;
      await s.gacha.loadHistory();
      expect(s.gacha.historyFailed, isTrue);
    });
  });
}
