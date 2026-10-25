import 'package:ai_game/data/firestore_avatar_frames.dart' show readPlayerLook;
import 'package:ai_game/data/firestore_vip.dart' show readVipHallRow;
import 'package:ai_game/data/firestore_world_chat.dart' show readChatMessage;
import 'package:ai_game/logic/avatar_frames.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/vip.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Answers like functions/wallet.js with a `vip` block (functions/vip.js).
class FakeVipWallet implements WalletApi {
  FakeVipWallet({this.level = 0, this.vnd = 0, this.nextVnd});

  int level;
  int vnd;
  int? nextVnd;
  bool withVip = true;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async => {
    'phaLe': 0,
    'cards': const {},
    'week': const {},
    'pity': const {},
    'pityAt': 90,
    'xuCardsToday': const {'bought': 0, 'max': 10, 'left': 10},
    'price': const {'phaLe': 20},
    if (withVip)
      'vip': {
        'level': level,
        'vnd': vnd,
        'max': level,
        'nextVnd': nextVnd,
        'hallHidden': false,
      },
  };
}

ShopSession vipSession(
  FakeVipWallet api, {
  Map<String, String>? backing,
  VipSource? vip,
  AvatarFrameSource? frames,
}) => newSession(backing: backing, vip: vip, avatarFrames: frames)
  ..accountUid = 'me'
  ..walletApi = api;

void main() {
  test('economy.json vip: the 10 tiers of spec 4.1 / Hà Phương', () {
    final c = newSession().e.vip;
    expect(c.tiers.map((t) => t.minVnd), [
      50000, 200000, 500000, 1500000, 3000000, //
      5000000, 7000000, 10000000, 12500000, 15000000,
    ]);
    expect(c.tiers.map((t) => t.giftTickets), [
      5,
      10,
      20,
      25,
      30,
      50,
      50,
      80,
      100,
      100,
    ]);
    expect(c.levelFor(14999999), 9);
  });

  test(
    'the wallet answer carries VIP; progress and what is left to the next tier',
    () async {
      final api = FakeVipWallet(level: 2, vnd: 350000, nextVnd: 500000);
      final s = vipSession(api);
      await s.syncWallet();
      expect(s.vip.level, 2);
      expect(s.vip.next!.level, 3);
      expect(s.vip.toNext, 150000);
      expect(s.vip.progress, closeTo(0.7, 1e-9)); // 200k → 500k
      // Signed out: nothing.
      s.accountUid = null;
      expect(s.vip.level, 0);
      expect(s.vip.status, isNull);
    },
  );

  test('an answer without vip keeps the last one', () async {
    final api = FakeVipWallet(level: 4, vnd: 1600000);
    final s = vipSession(api);
    await s.syncWallet();
    api.withVip = false;
    await s.syncWallet();
    expect(s.vip.level, 4);
  });

  test(
    'perks by tier: only what exists today (badge, colour, frame, pot, title, hall)',
    () {
      final v = newSession().vip;
      expect(v.perksAt(1), [VipPerk.badge, VipPerk.nameColor, VipPerk.frame]);
      expect(v.perksAt(2), [VipPerk.badge, VipPerk.nameColor]);
      expect(v.perksAt(3), contains(VipPerk.pot));
      expect(v.perksAt(6), contains(VipPerk.pot));
      expect(v.allPerksAt(5), contains(VipPerk.chatBubble));
      expect(v.perksAt(10), [
        VipPerk.badge,
        VipPerk.nameColor,
        VipPerk.title,
        VipPerk.hall,
      ]);
      expect(v.potsAt(3), ['chau_ngoc_bich']);
    },
  );

  test(
    'level-up popup: once per new tier, remembered per account on the device',
    () async {
      final backing = <String, String>{};
      final api = FakeVipWallet(level: 3, vnd: 600000);
      final s = vipSession(api, backing: backing);
      await s.syncWallet();
      await pumpEventQueue();
      expect(s.vip.levelUp, 3);
      expect(s.vip.levelUpFrom, 0);
      expect(s.vip.levelUpTickets, 35); // 5 + 10 + 20
      // VIP 2 opens nothing new (same frame as VIP 1): no row for it.
      expect(s.vip.levelUpPerks.map((e) => e.$1).toSet(), {1, 3});
      s.vip.closeLevelUp();
      await pumpEventQueue();
      expect(backing[ProgressStore.vipSeenKey('me')], '3');
      await s.syncWallet();
      await pumpEventQueue();
      expect(s.vip.levelUp, isNull, reason: 'not again');
      // A new session on the same device: not again either.
      final s2 = vipSession(FakeVipWallet(level: 3), backing: backing);
      await s2.syncWallet();
      await pumpEventQueue();
      expect(s2.vip.levelUp, isNull);
      // Up one: popup for 4 only.
      api.level = 4;
      await s.syncWallet();
      await pumpEventQueue();
      expect(s.vip.levelUp, 4);
      expect(s.vip.levelUpFrom, 3);
      expect(s.vip.levelUpTickets, 25);
      s.vip.closeLevelUp();
      // A refund drop lowers what was seen: climbing back shows it again.
      api.level = 2;
      await s.syncWallet();
      await pumpEventQueue();
      expect(s.vip.levelUp, isNull);
      expect(backing[ProgressStore.vipSeenKey('me')], '2');
    },
  );

  test(
    'hall: pages of 20, earliest first, total pages from the count',
    () async {
      final t0 = DateTime.utc(2026, 10, 20);
      final src = MemoryVipSource(
        hall: [
          for (var i = 0; i < 45; i++)
            VipHallRow(
              uid: 'u${i.toString().padLeft(2, '0')}',
              at: t0.add(Duration(days: 44 - i)),
              name: 'Tiệm $i',
            ),
        ],
      );
      final s = vipSession(FakeVipWallet(level: 10), vip: src);
      s.vip.openScreen();
      s.vip.showTab(1);
      await pumpEventQueue();
      expect(s.vip.hall!.length, 20);
      expect(s.vip.hall!.first.name, 'Tiệm 44', reason: 'earliest first');
      expect(s.vip.hallPages, 3);
      expect(s.vip.hallHasNext, isTrue);
      await s.vip.nextHallPage();
      expect(s.vip.hallPage, 1);
      expect(s.vip.hall!.first.name, 'Tiệm 24');
      await s.vip.nextHallPage();
      expect(s.vip.hall!.length, 5);
      expect(s.vip.hallHasNext, isFalse);
      await s.vip.prevHallPage();
      expect(s.vip.hall!.first.name, 'Tiệm 24');
      src.fail = true;
      await s.vip.loadHall();
      expect(s.vip.hallFailed, isTrue);
    },
  );

  test(
    'hall switch goes through the source and updates the wallet view',
    () async {
      final src = MemoryVipSource()
        ..status = const VipStatus(level: 10, vnd: 15000000);
      final s = vipSession(FakeVipWallet(level: 10, vnd: 15000000), vip: src);
      await s.syncWallet();
      expect(s.vip.hallHidden, isFalse);
      s.vip.openScreen();
      expect(await s.vip.setHallHidden(true), isTrue);
      expect(src.hidden, isTrue);
      expect(s.vip.hallHidden, isTrue);
      src.fail = true;
      expect(await s.vip.setHallHidden(false), isFalse);
      expect(s.vip.hallHidden, isTrue);
    },
  );

  test(
    'other players\' tier: from player_avatars (cached with the frames); own from the wallet',
    () async {
      final e = newSession().e;
      final frames = MemoryAvatarFrames(e.avatarFrames, vips: {'u2': 7});
      final s = vipSession(FakeVipWallet(level: 3), frames: frames);
      await s.syncWallet();
      expect(s.frames.vipOf('u2'), 0, reason: 'not read yet');
      await s.frames.prefetch(['u2', 'u3']);
      expect(s.frames.vipOf('u2'), 7);
      expect(s.frames.vipOf('u3'), 0);
      expect(s.frames.vipOf('me'), 3);
    },
  );

  test(
    'Ẩn huy hiệu VIP: through the source; my row shows no tier, my perks stay',
    () async {
      final src = MemoryVipSource()
        ..status = const VipStatus(
          level: 6,
          vnd: 3000000,
          pots: ['chau_ngoc_bich', 'chau_hoang_kim'],
        );
      final s = vipSession(FakeVipWallet(level: 6, vnd: 3000000), vip: src);
      await s.syncWallet();
      expect(s.vip.badgeHidden, isFalse);
      expect(s.vip.shownLevel, 6);
      expect(s.frames.vipOf('me'), 6);
      s.vip.openScreen();
      expect(await s.vip.setBadgeHidden(true), isTrue);
      expect(src.badgeHidden, isTrue);
      expect(s.vip.badgeHidden, isTrue);
      expect(s.vip.level, 6, reason: 'tier unchanged');
      expect(s.vip.shownLevel, 0);
      expect(s.frames.vipOf('me'), 0, reason: 'what others see');
      expect(s.vip.potUnlocked('chau_hoang_kim'), isTrue, reason: 'perks');
      expect(s.vip.hallHidden, isFalse, reason: 'the hall switch is its own');
      src.fail = true;
      expect(await s.vip.setBadgeHidden(false), isFalse);
      expect(s.vip.badgeHidden, isTrue);
      src.fail = false;
      expect(await s.vip.setBadgeHidden(false), isTrue);
      expect(s.vip.shownLevel, 6);
    },
  );

  test('Ẩn huy hiệu VIP keeps the VIP avatar frame on', () async {
    final e = newSession().e;
    final src = MemoryVipSource()
      ..status = const VipStatus(level: 6, vnd: 5000000);
    final frames = MemoryAvatarFrames(
      e.avatarFrames,
      vipLevel: 6,
      worn: {'me': 'vip_hoa_dao'},
    );
    final s = vipSession(
      FakeVipWallet(level: 6, vnd: 5000000),
      vip: src,
      frames: frames,
    );
    await s.syncWallet();
    await s.frames.refresh();
    expect(s.frames.equipped, 'vip_hoa_dao');
    s.vip.openScreen();
    expect(await s.vip.setBadgeHidden(true), isTrue);
    await s.frames.refresh();
    expect(s.vip.shownLevel, 0);
    expect(s.frames.equipped, 'vip_hoa_dao', reason: 'the frame stays');
    expect(s.frames.frameOf('me'), 'vip_hoa_dao');
    expect(s.frames.owned, contains('vip_hoa_dao'));
  });

  test('VipStatus reads badgeHidden', () {
    expect(
      VipStatus.fromJson({'level': 4, 'badgeHidden': true}).badgeHidden,
      isTrue,
    );
    expect(VipStatus.fromJson({'level': 4}).badgeHidden, isFalse);
  });

  test('readers: player_avatars vip, chat stamp, hall row', () {
    expect(readPlayerLook({'frame': 'la_non', 'vip': 7}).vip, 7);
    expect(readPlayerLook({'vip': 11}).vip, 0);
    expect(readPlayerLook({'vip': '9'}).vip, 0);
    final m = readChatMessage('m0000000001', {
      'uid': 'u',
      'text': 'hi',
      'seq': 1,
      'vip': 10,
    })!;
    expect(m.vip, 10);
    expect(
      readChatMessage('m0000000002', {'uid': 'u', 'text': 'hi', 'seq': 2})!.vip,
      0,
    );
    final at = DateTime.utc(2026, 10, 20);
    final r = readVipHallRow('u1', {'at': at, 'name': 'Tiệm', 'hidden': true})!;
    expect(r.hidden, isTrue);
    expect(r.at, at);
    expect(readVipHallRow('u1', {'name': 'x'}), isNull);
    final w = WalletView.fromJson({
      'phaLe': 1,
      'vip': {'level': 5, 'vnd': 3000000, 'nextVnd': 5000000},
    });
    expect(w.vip!.level, 5);
    expect(w.vip!.nextVnd, 5000000);
    expect(WalletView.fromJson({'phaLe': 1}).vip, isNull);
  });
}
