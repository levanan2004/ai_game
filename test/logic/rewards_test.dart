import 'dart:convert';

import 'package:ai_game/data/account_gateway.dart';
import 'package:ai_game/logic/bouquet.dart';
import 'package:ai_game/logic/pet.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:ai_game/ui/reward_bundle_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Signs in to one cloud morning that has an admin gift waiting.
class _GiftAccount extends OfflineAccount {
  _GiftAccount(this.cloud, this.gift);

  GameState? cloud;
  PetGiftBox? gift;

  @override
  Future<CloudRecord?> pull() async {
    final saved = cloud;
    if (saved == null) return null;
    return CloudRecord(state: saved, updatedAt: DateTime.utc(2026, 1, 2));
  }

  @override
  Future<void> push(GameState state) async {
    cloud = GameState.decode(state.encode());
  }

  @override
  Future<AccountProfile?> signIn() async =>
      const AccountProfile(uid: 'u1', email: 'an@example.com', name: 'An');

  @override
  Future<PetGiftBox?> pullGift() async => gift;
}

GameState _morning({int day = 4}) {
  final state = newSession().state;
  state.day = day;
  return state;
}

final _everyKind = RewardBundle(const [
  RewardItem.coins(50000),
  RewardItem.giotHoa(3),
  RewardItem.phaLe(7),
  RewardItem.pot('dragon', 2),
  RewardItem.treat(4),
  RewardItem.cat(),
  RewardItem.petSkin(giftSeat),
]);

void main() {
  group('RewardBundle json', () {
    test('every kind survives a round trip', () {
      final raw = jsonEncode(_everyKind.toJson());
      final back = RewardBundle.fromJson(jsonDecode(raw));
      expect(back, _everyKind);
      expect(back.items.length, 7);
      expect(back.amountOf(RewardKind.pot, 'dragon'), 2);
      expect((jsonDecode(raw) as Map)['items'][0], {
        'kind': 'coins',
        'amount': 50000,
      });
    });

    test('unknown kinds and broken items are skipped, not thrown', () {
      final bundle = RewardBundle.fromJson({
        'items': [
          {'kind': 'coins', 'amount': 100},
          {'kind': 'starDust', 'amount': 5},
          {'kind': 'pot', 'amount': 1},
          {'kind': 'phaLe', 'amount': -2},
          {'kind': 'phaLe', 'amount': 1.5},
          {'kind': 'phaLe', 'amount': '3'},
          {'kind': 'giotHoa', 'amount': maxRewardAmount + 1},
          'nope',
          null,
          {'kind': 'treat', 'amount': 2},
          {'kind': 'phaLe', 'amount': 2.0},
        ],
        'future': true,
      });
      expect(bundle.items, const [
        RewardItem.coins(100),
        RewardItem.treat(2),
        RewardItem.phaLe(2),
      ]);
      expect(RewardBundle.fromJson(null).isEmpty, isTrue);
      expect(RewardBundle.fromJson('x').isEmpty, isTrue);
      expect(RewardBundle.fromJson({'items': 3}).isEmpty, isTrue);
      expect(
        RewardBundle.fromJson([
          {'kind': 'coins', 'amount': 5},
        ]),
        RewardBundle.coins(5),
      );
    });

    test('an admin gift map turns into the same bundle every time', () {
      final bundle = RewardBundle.fromGiftItems({
        giftXu: 1000,
        'dragon': 2,
        giftCat: 1,
        giftPhaLe: 5,
        'not-a-gift': 9,
      });
      expect(bundle.items, const [
        RewardItem.cat(),
        RewardItem.pot('dragon', 2),
        RewardItem.coins(1000),
        RewardItem.phaLe(5),
      ]);
      expect(bundle.toGiftItems(), {
        giftCat: 1,
        'dragon': 2,
        giftXu: 1000,
        giftPhaLe: 5,
      });
      expect(bundle.label, 'Mèo, Chậu rồng thiên ×2, Xu 1k, Pha lê ×5');
    });
  });

  group('applyRewards', () {
    test('each kind is added to the save', () {
      final state = newSession().state
        ..hasCat = false
        ..petSeats = []
        ..petSeat = null;
      final money = state.money;
      final drops = state.drops;
      final biscuits = state.biscuits;
      final result = applyRewards(state, _everyKind);
      expect(result.skipped, isEmpty);
      expect(result.granted, _everyKind);
      expect(state.money, money + 50000);
      expect(state.drops, drops + 3);
      expect(state.phaLe, 7);
      expect(state.potCounts['dragon'], 2);
      expect(state.biscuits, biscuits + 4);
      expect(state.hasCat, isTrue);
      expect(state.petStage, 0);
      expect(state.petSeats, [giftSeat]);
      expect(state.petSeat, giftSeat);
    });

    test('an owned pot adds a copy; an owned cat or skin is skipped', () {
      final state = newSession().state
        ..hasCat = true
        ..petStage = 2;
      state.potCounts['koi'] = 1;
      final result = applyRewards(
        state,
        RewardBundle(const [
          RewardItem.pot('koi'),
          RewardItem.pot('sage'),
          RewardItem.pot('nope'),
          RewardItem.cat(),
          RewardItem.petSkin(giftSeat),
          RewardItem.petSkin('crown'),
          RewardItem.treat(1, id: 'cake'),
        ]),
      );
      expect(state.potCounts['koi'], 2);
      expect(state.potCounts.containsKey('sage'), isFalse);
      expect(state.potCounts.containsKey('nope'), isFalse);
      expect(state.petStage, 2);
      expect(state.petSeats, [giftSeat]);
      expect(result.granted, RewardBundle(const [RewardItem.pot('koi')]));
      expect(result.skipped.length, 6);
    });
  });

  group('Pha lê in the save', () {
    test('Pha lê survives save and load', () {
      final state = _morning()..phaLe = 12;
      final raw = state.encode();
      expect(jsonDecode(raw)['phaLe'], 12);
      expect(GameState.decode(raw)!.phaLe, 12);
    });

    test('an old save without Pha lê loads 0', () {
      final raw = _morning().encode();
      expect(raw, isNot(contains('phaLe')));
      final map = jsonDecode(raw) as Map<String, Object?>..remove('phaLe');
      expect(GameState.decode(jsonEncode(map))!.phaLe, 0);
      map['phaLe'] = -4;
      expect(GameState.decode(jsonEncode(map))!.phaLe, 0);
      map['phaLe'] = 'x';
      expect(GameState.decode(jsonEncode(map))!.phaLe, 0);
    });

    test('a persisting grant writes the morning save at once', () async {
      final backing = <String, String>{};
      final s = newSession(backing: backing);
      s.startNewGame();
      await s.pendingSaves;
      final granted = s.grantRewards(
        RewardBundle(const [RewardItem.phaLe(3), RewardItem.pot('crane')]),
        source: RewardSource.mailbox,
      );
      await s.pendingSaves;
      expect(granted.amountOf(RewardKind.phaLe), 3);
      expect(s.state.phaLe, 3);
      final stored = GameState.decode(backing[ProgressStore.storageKey])!;
      expect(stored.phaLe, 3);
      expect(stored.potCounts['crane'], 1);

      final reopened = newSession(backing: backing, saved: stored);
      expect(reopened.state.phaLe, 3);
    });

    test('an in-day grant stays out of the morning save', () async {
      final backing = <String, String>{};
      final s = newSession(backing: backing);
      s.startNewGame();
      await s.pendingSaves;
      final before = backing[ProgressStore.storageKey];
      final money = s.state.money;
      s.grantRewards(RewardBundle.coins(700), source: RewardSource.shopEvent);
      await s.pendingSaves;
      expect(s.state.money, money + 700);
      expect(backing[ProgressStore.storageKey], before);
    });
  });

  group('migrated sources', () {
    test('an admin gift adds the same items once, like before', () async {
      final cloud = _morning()
        ..hasCat = true
        ..petStage = 1;
      cloud.potCounts['dragon'] = 1;
      final money = cloud.money;
      final biscuits = cloud.biscuits;
      final account = _GiftAccount(
        cloud,
        const PetGiftBox(
          id: 'box-pots',
          items: {giftCat: 1, 'dragon': 2, giftXu: 50000, giftBiscuit: 1},
        ),
      );
      final s = newSession(account: account);
      await s.signIn();
      expect(s.shopNotice, 'Nhận quà: Bánh mật, Chậu rồng thiên ×2, Xu 50k.');
      expect(s.state.money, money + 50000);
      expect(s.state.potCounts['dragon'], 3);
      expect(s.state.biscuits, biscuits + 1);
      expect(s.state.petStage, 1);
      expect(s.state.appliedGiftId, 'box-pots');
      await s.pendingSaves;
      expect(account.cloud!.money, money + 50000);
      expect(account.cloud!.potCounts['dragon'], 3);
      expect(account.cloud!.biscuits, biscuits + 1);
      expect(account.cloud!.appliedGiftId, 'box-pots');

      await s.signOut();
      await s.signIn();
      expect(s.state.money, money + 50000);
      expect(s.state.potCounts['dragon'], 3);
    });

    test('an old admin gift doc still applies; Pha lê gifts work', () async {
      final old = giftFromMap({
        'id': 'gift-old-1',
        'note': '',
        'items': {giftBiscuit: 2, 'koi': 1},
      });
      expect(old!.items, {giftBiscuit: 2, 'koi': 1});
      final fresh = giftFromMap({
        'id': 'gift-new-1',
        'items': {giftPhaLe: 5000, giftDrop: 1},
      });
      expect(fresh!.items, {giftDrop: 1, giftPhaLe: maxPhaLeGift});

      final account = _GiftAccount(_morning(), fresh);
      final s = newSession(account: account);
      await s.signIn();
      expect(s.state.phaLe, maxPhaLeGift);
      expect(s.shopNotice, 'Nhận quà: Giọt hoa, Pha lê ×$maxPhaLeGift.');
      await s.pendingSaves;
      expect(account.cloud!.phaLe, maxPhaLeGift);
      expect(
        PetPocket.fromProgress(account.cloud!.toJson()).countOf(giftPhaLe),
        maxPhaLeGift,
      );
    });

    test('a gift of things already owned says so and is not repeated', () {
      final state = newSession().state..hasCat = true;
      final bundle = giftBundle(
        const PetGiftBox(id: 'g', items: {giftCat: 1, giftSeat: 1}),
        appliedId: null,
      )!;
      final result = applyRewards(state, bundle);
      expect(giftGrantedLine(result.granted), 'Quà này tiệm đã có rồi.');
      expect(
        giftBundle(
          const PetGiftBox(id: 'g', items: {giftCat: 1}),
          appliedId: 'g',
        ),
        isNull,
      );
    });

    test('the wholesale bonus still pays 30% mid-day', () async {
      final backing = <String, String>{};
      final s = newSession(backing: backing);
      s.state.tutorialDone = true;
      s.state.day = 5;
      stockAndOpen(s);
      await s.pendingSaves;
      final saved = backing[ProgressStore.storageKey];
      s.presentEvent('wholesale');
      s.chooseEvent('accept');
      final money = s.state.money;
      for (var i = 0; i < 3; i++) {
        noteWholesale(s, Bouquet(paperId: 'basket'), 100000);
      }
      expect(s.state.money, money + 90000);
      expect(s.shopNotice, 'Khách sỉ trả thêm 90k.');
      await s.pendingSaves;
      expect(backing[ProgressStore.storageKey], saved);
    });
  });

  testWidgets('a bundle shows one icon and amount per item', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: RewardBundleView(bundle: _everyKind)),
      ),
    );
    for (final key in [
      'reward-coins',
      'reward-giotHoa',
      'reward-phaLe',
      'reward-pot-dragon',
      'reward-treat-banh_mat',
      'reward-cat',
      'reward-petSkin-dem_xanh',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(find.text('50k'), findsOneWidget);
    expect(find.text('×7'), findsOneWidget);
    expect(find.byType(PhaLeIcon), findsOneWidget);
  });
}
