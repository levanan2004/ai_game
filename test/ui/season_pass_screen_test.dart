import 'dart:io';

import 'package:ai_game/logic/season_pass.dart';
import 'package:ai_game/logic/season_pass_controller.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/logic/wallet.dart';
import 'package:ai_game/ui/season_pass_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

class FakeSpSource implements SeasonPassSource {
  Map<String, String> themes = {};
  Map<String, Object?>? doc;
  bool fail = false;
  int reads = 0;

  @override
  Future<Map<String, String>> themeByPeriod() async {
    if (fail) throw StateError('offline');
    return themes;
  }

  @override
  Future<Map<String, Object?>?> seasonDoc(String uid, String period) async {
    reads++;
    return doc;
  }
}

class FakeApi implements WalletApi {
  final calls = <(String, Map<String, Object?>)>[];
  Map<String, Object?> Function(String, Map<String, Object?>)? reply;
  String? refuse;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> data,
  ) async {
    calls.add((name, data));
    if (refuse != null) throw WalletException(refuse!);
    return reply!(name, data);
  }
}

/// Season 2 (09/11–06/12/2026), day 4, 10:00 in Vietnam.
final now = DateTime.utc(2026, 11, 12, 3);

({ShopSession s, FakeSpSource src, FakeApi api, String period}) setUp_({
  int xp = 650,
  bool premium = false,
  Map<String, Object?> claimed = const {},
  int phaLe = 200,
  bool theme = true,
}) {
  final src = FakeSpSource();
  final s = newSession(seasonPass: src, now: () => now);
  final period = s.e.charmBoard.clock!.at(now).period;
  if (theme) src.themes = {period: 'tri_an_2011'};
  src.doc = {
    'xp': xp,
    'premium': premium,
    'claimed': claimed,
    'daily': {
      'date': '2026-11-12',
      'c': {'bouquetsSold': 3},
    },
    'weekly': {
      'week': 0,
      'c': {'bouquetsSold': 30},
    },
    'season': {
      'c': {'bouquetsSold': 30},
    },
    'done': {'ngay_dang_nhap@2026-11-12': 1},
  };
  final api = FakeApi();
  s.accountUid = 'u1';
  s.walletApi = api;
  s.wallet = WalletView(phaLe: phaLe);
  return (s: s, src: src, api: api, period: period);
}

Future<void> pumpScreen(WidgetTester t, ShopSession s, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await s.seasonPass.load();
  await t.pumpWidget(
    MaterialApp(
      home: ListenableBuilder(
        listenable: s,
        builder: (_, _) => SeasonPassScreen(session: s),
      ),
    ),
  );
  await t.pump();
}

void main() {
  test(
    'view: tiers reached, claimables, focus, missions read from the doc',
    () async {
      final r = setUp_(xp: 650, claimed: {'free_1': 1});
      await r.s.seasonPass.load();
      final v = r.s.seasonPass.view!;
      expect(r.s.seasonPass.phase, SeasonPassPhase.ready);
      expect(v.tier, 3); // 200 + 200 + 200 <= 650
      expect(v.claimables, [
        (2, SeasonPassTrack.free),
        (3, SeasonPassTrack.free),
      ]);
      expect(v.focusTier, 2);
      expect(r.s.seasonPass.entryVisible, isTrue);
      expect(r.s.seasonPass.claimableCount, 2);
      final daily = v.config.missions.firstWhere(
        (m) => m.key == 'ngay_ban_bo_hoa',
      );
      expect(v.mission(daily).current, 3);
      final login = v.config.missions.firstWhere(
        (m) => m.key == 'ngay_dang_nhap',
      );
      expect(v.mission(login).done, isTrue);
      expect(v.canBuy, isTrue);
    },
  );

  test(
    'no theme for the season or before 09/11: closed, button hidden',
    () async {
      final r = setUp_(theme: false);
      await r.s.seasonPass.load();
      expect(r.s.seasonPass.phase, SeasonPassPhase.closed);
      expect(r.s.seasonPass.entryVisible, isFalse);
      expect(r.src.reads, 0);
    },
  );

  test('a stale daily counter (another date) reads as 0', () async {
    final r = setUp_();
    r.src.doc = {
      ...r.src.doc!,
      'daily': {
        'date': '2026-11-11',
        'c': {'bouquetsSold': 9},
      },
    };
    await r.s.seasonPass.load();
    final v = r.s.seasonPass.view!;
    final daily = v.config.missions.firstWhere(
      (m) => m.key == 'ngay_ban_bo_hoa',
    );
    expect(v.mission(daily).current, 0);
  });

  test(
    'claim waits for the server; refusal (flagged) = toast, server state',
    () async {
      final r = setUp_();
      await r.s.seasonPass.load();
      r.api.reply = (name, d) => {
        'status': 'claimed',
        'xp': 650,
        'premium': false,
        'claimed': ['free_1'],
      };
      expect(await r.s.seasonPass.claim(1, SeasonPassTrack.free), isTrue);
      expect(r.s.seasonPass.takeToast(), 'sp_claim_sent_to_mail');
      expect(r.api.calls.single.$2, {'tier': 1, 'track': 'free'});
      expect(
        r.s.seasonPass.view!.status.isClaimed(1, SeasonPassTrack.free),
        isTrue,
      );
      // Mission counters survive the answer (it carries none).
      expect(r.s.seasonPass.view!.status.daily['bouquetsSold'], 3);
      r.api.refuse = 'flagged';
      expect(await r.s.seasonPass.claim(2, SeasonPassTrack.free), isFalse);
      expect(r.s.seasonPass.takeToast(), 'sp_claim_flagged');
      expect(r.s.seasonPass.pending, isEmpty);
      r.api.refuse = 'server';
      expect(await r.s.seasonPass.claim(2, SeasonPassTrack.free), isFalse);
      expect(r.s.seasonPass.takeToast(), 'sp_claim_failed');
    },
  );

  test('claim all: one claim per waiting tier, in order', () async {
    final r = setUp_(xp: 650, premium: true);
    await r.s.seasonPass.load();
    final claimed = <String>[];
    r.api.reply = (name, d) {
      claimed.add('${d['track']}_${d['tier']}');
      return {
        'status': 'claimed',
        'xp': 650,
        'premium': true,
        'claimed': [...claimed],
      };
    };
    final done = await r.s.seasonPass.claimAll();
    expect(done.length, 6);
    expect(claimed.first, 'free_1');
    expect(claimed[1], 'premium_1');
    expect(r.s.seasonPass.claimableCount, 0);
  });

  test(
    'buy: balance refusal = not enough; success opens premium claims',
    () async {
      final r = setUp_();
      await r.s.seasonPass.load();
      r.api.refuse = 'balance';
      expect(await r.s.seasonPass.buy(), SeasonPassBuy.notEnough);
      r.api.refuse = null;
      r.api.reply = (name, d) => {
        'status': 'bought',
        'xp': 650,
        'premium': true,
        'claimed': [],
        'phaLe': 50,
      };
      expect(await r.s.seasonPass.buy(), SeasonPassBuy.bought);
      expect(
        r.s.seasonPass.view!.claimable(1, SeasonPassTrack.premium),
        isTrue,
      );
    },
  );

  test(
    'reward labels come from the block keys and Nhất\'s sp_reward_*',
    () async {
      final r = setUp_();
      await r.s.seasonPass.load();
      final v = r.s.seasonPass.view!;
      final t = r.s.data.seasonPassText!;
      final name = t.get('sp_theme_2011_name');
      List<String> labels(int tier, SeasonPassTrack track) => [
        for (final p in spRewardParts(
          v.config.tiers[tier - 1].track(track),
          t: t,
          themeId: v.themeId,
          seasonName: name,
        ))
          p.label,
      ];
      expect(labels(2, SeasonPassTrack.free), ['200.000 xu']);
      expect(labels(10, SeasonPassTrack.free), ['1 vé quay', 'Nơ cổ vải']);
      expect(labels(1, SeasonPassTrack.premium), ['Biển hiệu $name']);
      expect(labels(22, SeasonPassTrack.premium), [
        'Khung avatar $name (hiếm)',
        '1 vé quay',
      ]);
      expect(labels(30, SeasonPassTrack.free), [
        '1 vé quay',
        'Khung avatar $name',
      ]);
      expect(labels(12, SeasonPassTrack.premium), ['30 Pha lê']);
    },
  );

  for (final size in const [Size(360, 640), Size(393, 852)]) {
    testWidgets('screen ${size.width.toInt()}: track, tabs, buy, no overflow', (
      t,
    ) async {
      final r = setUp_(phaLe: 200);
      await pumpScreen(t, r.s, size);
      expect(find.text('Tri ân 20/11'), findsOneWidget);
      expect(find.text('Cấp 3/30'), findsOneWidget);
      expect(find.byKey(const Key('season-pass-claim-free-1')), findsOneWidget);
      expect(find.byKey(const Key('season-pass-claim-all')), findsOneWidget);
      expect(find.text('Mở nhánh Pha lê · 150 Pha lê'), findsOneWidget);
      expect(find.textContaining('Sắp mở'), findsNothing);
      await t.tap(find.byKey(const Key('season-pass-buy')));
      await t.pump();
      expect(find.byKey(const Key('season-pass-dialog-buy')), findsOneWidget);
      await t.tap(find.byKey(const Key('season-pass-buy-cancel')));
      await t.pump();
      await t.tap(find.byKey(const Key('season-pass-tab-1')));
      await t.pump();
      expect(find.text('Bán 8 bó hoa'), findsOneWidget);
      expect(find.textContaining('Cẩm chướng'), findsWidgets);
      expect(t.takeException(), isNull);
    });
  }

  test('mission art: every goal maps to a real asset path', () async {
    final r = setUp_();
    await r.s.seasonPass.load();
    final v = r.s.seasonPass.view!;
    final flowers = v.config.themes[v.themeId]!.flowers;
    final art = {
      for (final m in v.config.missions)
        m.goal: spMissionArt(m.goal, flowers.firstOrNull),
    };
    expect(art['gameDaysPlayed'], 'nav/cho_hoa.webp');
    expect(art['themeFlowerStemsSold'], 'flowers/${flowers.first}.webp');
    expect(art['dailyMissionsDone'], 'ui/ve_season_pass.webp');
    expect(
      spMissionArt('themeFlowerStemsSold', null),
      'ui/ve_season_pass.webp',
    );
    for (final path in art.values) {
      expect(File('assets/images/$path').existsSync(), isTrue, reason: path);
    }
  });

  testWidgets('premium lock is an 18dp corner chip; claim all waits', (
    t,
  ) async {
    final r = setUp_(xp: 650);
    r.api.reply = (name, d) => {
      'status': 'claimed',
      'xp': 650,
      'premium': false,
      'claimed': ['free_${d['tier']}'],
    };
    await pumpScreen(t, r.s, const Size(360, 640));
    final chip = find.byKey(const Key('season-pass-lock-chip')).first;
    expect(t.getSize(chip), const Size(18, 18));
    final cell = find.ancestor(of: chip, matching: find.byType(Stack)).first;
    final cellBox = t.getRect(cell);
    final chipBox = t.getRect(chip);
    expect(chipBox.right, closeTo(cellBox.right - 3, 0.5));
    expect(chipBox.top, closeTo(cellBox.top + 3, 0.5));
    r.s.seasonPass.pending.add('free_1');
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    r.s.seasonPass.notifyListeners();
    await t.pump();
    final ink = t.widget<InkWell>(
      find.byKey(const Key('season-pass-claim-all')),
    );
    expect(ink.onTap, isNull);
    expect(t.takeException(), isNull);
  });

  testWidgets('not enough Pha lê: only "Đã hiểu", no top-up', (t) async {
    final r = setUp_(phaLe: 40);
    await pumpScreen(t, r.s, const Size(393, 852));
    await t.tap(find.byKey(const Key('season-pass-buy')));
    await t.pump();
    expect(
      find.byKey(const Key('season-pass-dialog-notEnough')),
      findsOneWidget,
    );
    expect(find.text('Bạn còn thiếu 110 Pha lê nữa.'), findsOneWidget);
    final dialog = find.byKey(const Key('season-pass-dialog-notEnough'));
    expect(
      find.descendant(of: dialog, matching: find.byType(InkWell)),
      findsOneWidget,
    );
    expect(find.text('Đã hiểu'), findsOneWidget);
    expect(find.textContaining('Nạp'), findsNothing);
    expect(r.api.calls, isEmpty);
  });

  testWidgets('claim shows the result dialog; tier 30 frame falls back', (
    t,
  ) async {
    final r = setUp_(xp: 99999);
    r.api.reply = (name, d) => {
      'status': 'claimed',
      'xp': 99999,
      'premium': false,
      'claimed': ['free_30'],
    };
    await pumpScreen(t, r.s, const Size(393, 852));
    await r.s.seasonPass.claim(30, SeasonPassTrack.free);
    await t.pump();
    expect(find.text('Đã đạt cấp tối đa mùa này!'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('load error: retry card, no cached numbers', (t) async {
    final r = setUp_();
    r.src.fail = true;
    await pumpScreen(t, r.s, const Size(360, 640));
    expect(find.byKey(const Key('season-pass-error')), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
    expect(find.textContaining('Cấp'), findsNothing);
  });
}
