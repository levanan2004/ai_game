import 'package:ai_game/data/pot_rules.dart';
import 'package:ai_game/logic/mailbox.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/ui/gacha_text.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Stands in for functions/wallet.js: keeps a balance and answers like the
/// callables (the result always carries the wallet view).
class _FakeWallet implements WalletApi {
  _FakeWallet({this.phaLe = 0});

  int phaLe;
  final calls = <(String, Map<String, Object?>)>[];
  String? refuse;
  int xuCardsToday = 0;

  Map<String, Object?> _view([Map<String, Object?> extra = const {}]) => {
    'phaLe': phaLe,
    'cards': {'chau_cuu_vi_ho': 2},
    'week': {'potId': 'chau_cuu_vi_ho', 'daysLeft': 3},
    'pity': {
      'chau_cuu_vi_ho': {'n': 0, 'resetFrom': 7},
    },
    'pityAt': 90,
    'xuCardsToday': {
      'bought': xuCardsToday,
      'max': 10,
      'left': 10 - xuCardsToday,
    },
    'price': {'phaLe': 20},
    ...extra,
  };

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    calls.add((name, data));
    if (refuse != null && name != 'walletSync') {
      throw WalletException(refuse!);
    }
    switch (name) {
      case 'phaleBuy':
        phaLe -= 500;
      case 'walletEarn':
        phaLe += 50;
        return _view({
          'credited': {'phaLe': 50},
        });
      case 'walletClaimMail':
        phaLe += 120;
        return _view({'status': 'claimed'});
      case 'gachaBuyCards':
        final count = data['count'] as int;
        if (data['currency'] == 'coins') {
          xuCardsToday += count;
          return _view({
            'paid': {'coins': 1000000 * count},
          });
        }
        phaLe -= 20 * count;
        return _view({
          'paid': {'phaLe': 20 * count},
        });
    }
    return _view();
  }
}

ShopSession _signedIn(_FakeWallet api, {int localPhaLe = 0}) {
  final s = newSession()
    ..accountUid = 'me'
    ..walletApi = api;
  s.state.phaLe = localPhaLe;
  s.state.money = 50000000;
  return s;
}

void main() {
  group('gacha config (economy.json)', () {
    final cfg = newSession().e.gacha;

    test(
      'rotation starts 0h Monday VN with Cửu Vĩ Hồ and changes each Monday',
      () {
        final start = cfg.rotationStart!;
        expect(start, DateTime.utc(2026, 10, 18, 17)); // 19/10 0h VN
        expect(
          cfg.potOfWeekAt(DateTime.utc(2026, 10, 25, 16, 59, 59)),
          'chau_cuu_vi_ho',
        );
        expect(
          cfg.potOfWeekAt(DateTime.utc(2026, 10, 25, 17)),
          'chau_chuc_long',
        );
        expect(
          cfg.potOfWeekAt(start.add(const Duration(days: 7 * 12))),
          'chau_cuu_vi_ho',
        );
        expect(
          cfg.potOfWeekAt(start.subtract(const Duration(seconds: 1))),
          null,
        );
      },
    );

    test('days left until the pot changes ("Còn X ngày đổi chậu")', () {
      // Saturday 24/10 14:00 VN: the pot changes Monday 26/10 0h VN.
      final now = DateTime.utc(2026, 10, 24, 7);
      expect(cfg.nextChangeAt(now), DateTime.utc(2026, 10, 25, 17));
      expect(cfg.daysUntilChange(now), 2);
      expect(cfg.daysUntilChange(DateTime.utc(2026, 10, 25, 16)), 1);
    });

    test(
      'daily xu cards 10, pity resets weekly, gift cards by mail arrival',
      () {
        expect(cfg.maxCoinTicketsPerDay, 10);
        expect(cfg.pityCarryOver, isFalse);
        expect(cfg.pityAt, 90);
        expect(cfg.ticketPhaLe, 20);
        expect(cfg.giftTicketPotBy, 'mailArrivalWeek');
        expect(
          GachaConfig.vnMidnight('2026-10-19'),
          DateTime.utc(2026, 10, 18, 17),
        );
        expect(GachaConfig.vnMidnight('19/10'), isNull);
      },
    );
  });

  group('wallet view', () {
    test(
      'reads balance, cards, week, pity (with resetFrom) and the xu cap',
      () {
        final v = WalletView.fromJson({
          'phaLe': 40,
          'cards': {'chau_cuu_vi_ho': 3, 'chau_chuc_long': 0},
          'week': {'potId': 'chau_cuu_vi_ho', 'weekEnd': 0, 'daysLeft': 2},
          'pity': {
            'chau_cuu_vi_ho': {'n': 0, 'resetFrom': 12},
          },
          'pityAt': 90,
          'xuCardsToday': {'bought': 4, 'max': 10, 'left': 6},
          'price': {'phaLe': 20, 'coins': 1000000},
        });
        expect(v.phaLe, 40);
        expect(v.cards, {'chau_cuu_vi_ho': 3});
        expect(v.cardsThisWeek, 3);
        expect(v.daysLeft, 2);
        expect(v.pity['chau_cuu_vi_ho']!.resetFrom, 12);
        expect(v.xuCardsLeftToday, 6);
        expect(v.cardCoins, 1000000);
        final unlimited = WalletView.fromJson({
          'phaLe': 0,
          'xuCardsToday': {'bought': 4, 'max': 0, 'left': null},
        });
        expect(unlimited.xuCardsLeftToday, isNull);
      },
    );
    test('a refund debt comes as a balance below 0 and is kept as is', () {
      // functions/wallet.js view: phaLe = balance - phaLeDebt.
      final v = WalletView.fromJson({'phaLe': -1250, 'phaLeDebt': 1250});
      expect(v.phaLe, -1250);
    });
  });

  group('Pha lê spends go to the server', () {
    test(
      'a Pha lê pot is paid by phaleBuy; the save shows the server balance',
      () async {
        final api = _FakeWallet(phaLe: 800);
        final s = _signedIn(api, localPhaLe: 800);
        expect(await s.buyPotPaid('dragon'), isTrue);
        expect(api.calls.single.$1, 'phaleBuy');
        expect(api.calls.single.$2, {'kind': 'pot', 'id': 'dragon'});
        expect(s.state.phaLe, 300);
        expect(s.potOwned('dragon'), 1);
      },
    );

    test('a refused spend adds nothing and resyncs the balance', () async {
      final api = _FakeWallet(phaLe: 100)..refuse = 'balance';
      final s = _signedIn(api, localPhaLe: 9999); // a forged save
      expect(await s.buyPotPaid('dragon'), isFalse);
      expect(s.potOwned('dragon'), 0);
      await Future<void>.delayed(Duration.zero);
      expect(s.state.phaLe, 100, reason: 'the server number replaces the save');
    });

    test('a guest (no wallet) still buys locally', () async {
      final s = newSession()..state.phaLe = 600;
      expect(await s.buyPotPaid('dragon'), isTrue);
      expect(s.state.phaLe, 100);
    });

    test('Pha lê from a login gift is checked by walletEarn', () async {
      final api = _FakeWallet(phaLe: 0);
      final s = _signedIn(api);
      s.grantRewards(RewardBundle.phaLe(50), source: RewardSource.loginReward);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.single.$1, 'walletEarn');
      expect(api.calls.single.$2, {'source': 'login'});
      expect(s.state.phaLe, 50);
      s.grantRewards(RewardBundle.coins(10), source: RewardSource.loginReward);
      await Future<void>.delayed(Duration.zero);
      expect(api.calls.length, 1, reason: 'no Pha lê, no call');
    });

    test('xu cards: the server counts the day, the save pays the xu', () async {
      final api = _FakeWallet();
      final s = _signedIn(api);
      final v = await s.buyGachaCards(count: 3, withPhaLe: false);
      expect(s.state.money, 50000000 - 3000000);
      expect(api.calls.single.$2['gameDay'], s.state.day);
      expect(v.xuCardsLeftToday, 7);
      api.refuse = 'limit';
      await expectLater(
        s.buyGachaCards(count: 8, withPhaLe: false),
        throwsA(isA<WalletException>().having((e) => e.code, 'code', 'limit')),
      );
      expect(s.state.money, 50000000 - 3000000);
      expect(
        GachaText.buyFail('limit'),
        'Hôm nay đã hết lượt mua thẻ bằng xu.',
      );
    });
  });

  group('Hộp thư', () {
    test(
      'a mail with Pha lê is claimed by walletClaimMail, the rest by the app',
      () async {
        final api = _FakeWallet(phaLe: 5);
        final s = _signedIn(api, localPhaLe: 5);
        final feed = MailboxFeed(service: _NoClaim())
          ..walletClaim = s.walletClaimMail;
        final mail = GameMail(
          id: 'phale_1',
          title: 'Nạp Pha lê',
          body: '',
          target: 'me',
          rewards: RewardBundle(const [
            RewardItem.phaLe(120),
            RewardItem.coins(3000),
          ]),
        );
        (feed.service as _NoClaim).mails.add(mail);
        await feed.bindUser('me');
        final money = s.state.money;
        final r = await feed.claim(
          'phale_1',
          allowed: true,
          grant: (m) => s.grantRewards(m.rewards, source: RewardSource.mailbox),
        );
        expect(r, MailClaimResult.claimed);
        expect(api.calls.map((c) => c.$1), ['walletClaimMail']);
        expect(s.state.phaLe, 125, reason: 'once, the server number');
        expect(s.state.money, money + 3000);
        expect(mailToMap(mail)['walletClaim'], isTrue);
      },
    );
  });

  test('Thẻ gacha reward items read and write; nothing enters the save', () {
    final b = RewardBundle.fromJson({
      'items': [
        {'kind': 'ticket', 'amount': 1},
      ],
    });
    expect(b.amountOf(RewardKind.ticket), 1);
    expect(b.toJson(), {
      'items': [
        {'kind': 'ticket', 'amount': 1},
      ],
    });
    final s = newSession();
    final before = s.state.encode();
    final granted = s.grantRewards(b, source: RewardSource.mysteryCustomer);
    expect(granted.amountOf(RewardKind.ticket), 1);
    expect(s.state.encode(), before);
  });
}

class _NoClaim implements MailService {
  final mails = <GameMail>[];

  @override
  Future<List<GameMail>> inbox(String uid) async => mails;

  @override
  Future<Map<String, MailState>> states(String uid) async => {};

  @override
  Future<void> markRead(String uid, String mailId) async {}

  @override
  Future<MailClaimResult> claim(String uid, String mailId) async =>
      throw StateError('a wallet mail must not be claimed by the app');
}
