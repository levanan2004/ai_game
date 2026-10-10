import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/data/economy.dart';
import 'package:ai_game/logic/login_rewards.dart';
import 'package:ai_game/logic/reward_rarity.dart';
import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/ui/login_tiles.dart';
import 'package:ai_game/ui/phuc_loi_art.dart';
import 'package:ai_game/ui/reward_bundle_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every cut-out exists at the size in Phú\'s README', () async {
    for (final art in PhucLoiArt.all) {
      final file = File(art.path);
      expect(file.existsSync(), isTrue, reason: art.path);
      expect(art.path, endsWith('.webp'));
      final codec = await ui.instantiateImageCodec(file.readAsBytesSync());
      final frame = await codec.getNextFrame();
      expect(
        Size(frame.image.width.toDouble(), frame.image.height.toDouble()),
        art.canvas,
        reason: art.id,
      );
      final bounds = Offset.zero & art.canvas;
      expect(bounds.intersect(art.inner), art.inner, reason: art.id);
      if (art.band != null) {
        expect(bounds.intersect(art.band!), art.band!, reason: art.id);
        // The label band sits above the icon area.
        expect(art.band!.bottom, lessThanOrEqualTo(art.inner.top));
      }
    }
  });

  test('frames and tiles share their canvas, so they line up', () {
    for (final r in RewardRarity.values) {
      expect(PhucLoiArt.frame(r).canvas, const Size(425, 425));
      expect(PhucLoiArt.frame(r).id, r.frame);
    }
    for (final t in [
      PhucLoiArt.oDaNhan,
      PhucLoiArt.oHomNay,
      PhucLoiArt.oKhoa,
    ]) {
      expect(t.canvas, const Size(432, 432));
    }
    // README fractions survive scaling.
    final r = PhucLoiArt.oDaNhan.place(
      PhucLoiArt.oDaNhan.band!,
      const Size(216, 216),
    );
    expect(r, const Rect.fromLTWH(61.5, 40, 93.5, 27.5));
  });

  test('rarity rule', () {
    expect(rewardRarity(const RewardItem.coins(50000)), RewardRarity.thuong);
    expect(rewardRarity(const RewardItem.coins(299999)), RewardRarity.thuong);
    expect(rewardRarity(const RewardItem.coins(300000)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.coins(900000)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.treat(3)), RewardRarity.thuong);
    expect(rewardRarity(const RewardItem.giotHoa(10)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.giotHoa(19)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.giotHoa(20)), RewardRarity.suThi);
    expect(rewardRarity(const RewardItem.phaLe(100)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.phaLe(499)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.phaLe(500)), RewardRarity.suThi);
    expect(rewardRarity(const RewardItem.phaLe(900)), RewardRarity.suThi);
    expect(rewardRarity(const RewardItem.pot('dragon')), RewardRarity.suThi);
    expect(rewardRarity(const RewardItem.cat()), RewardRarity.huyenThoai);
  });

  test('economy.json rewardRarity matches the code defaults', () {
    final json =
        jsonDecode(File('assets/data/economy.json').readAsStringSync())
            as Map<String, dynamic>;
    expect(json, contains('rewardRarity'));
    final fromFile = Economy.fromJson(json).rewardRarity;
    const d = RarityRules.defaults;
    expect(fromFile.byKind.keys.toSet(), d.byKind.keys.toSet());
    for (final kind in d.byKind.keys) {
      final a = fromFile.byKind[kind]!;
      final b = d.byKind[kind]!;
      expect(a.base, b.base, reason: kind);
      expect(
        [for (final t in a.tiers) '${t.from}:${t.rarity.name}'],
        [for (final t in b.tiers) '${t.from}:${t.rarity.name}'],
        reason: kind,
      );
    }
    // Every kind the game can give has a rule.
    for (final kind in RewardKind.values) {
      expect(d.byKind, contains(kind.json));
    }
  });

  test('economy.json: phaLePrices and alphaGift, with code defaults', () {
    final json =
        jsonDecode(File('assets/data/economy.json').readAsStringSync())
            as Map<String, dynamic>;
    final e = Economy.fromJson(json);
    expect(e.phaLePrices.petPot, 300);
    expect(e.alphaGift.phaLe, 50);
    expect(e.alphaGift.giotHoa, 10);
    expect(e.alphaGift.coins, 100000);
    expect((json['alphaGift'] as Map)['_note'], contains('8/10'));
    final bare = Economy.fromJson(
      {...json}
        ..remove('phaLePrices')
        ..remove('alphaGift'),
    );
    expect(bare.phaLePrices.petPot, PhaLePrices.defaults.petPot);
    expect(bare.alphaGift.coins, AlphaGift.defaults.coins);
    expect(AlphaGift.fromJson({'coins': 5}).phaLe, 50);
  });

  test('rewardRarity: missing key keeps defaults, edits take effect', () {
    final json =
        jsonDecode(File('assets/data/economy.json').readAsStringSync())
            as Map<String, dynamic>;
    json.remove('rewardRarity');
    final rules = Economy.fromJson(json).rewardRarity;
    expect(
      rewardRarity(const RewardItem.coins(300000), rules),
      RewardRarity.hiem,
    );
    expect(
      rewardRarity(const RewardItem.giotHoa(20), rules),
      RewardRarity.suThi,
    );

    final edited = RarityRules.fromJson({
      '_note': 'x',
      'coins': {
        'tiers': [
          {'from': 1000000, 'rarity': 'suThi'},
          {'from': 100000, 'rarity': 'hiem'},
        ],
      },
      'cat': {'base': 'suThi'},
    });
    expect(
      rewardRarity(const RewardItem.coins(99999), edited),
      RewardRarity.thuong,
    );
    expect(
      rewardRarity(const RewardItem.coins(100000), edited),
      RewardRarity.hiem,
    );
    expect(
      rewardRarity(const RewardItem.coins(1000000), edited),
      RewardRarity.suThi,
    );
    expect(rewardRarity(const RewardItem.cat(), edited), RewardRarity.suThi);
    // Kinds left out keep the defaults.
    expect(
      rewardRarity(const RewardItem.phaLe(500), edited),
      RewardRarity.suThi,
    );

    expect(
      () => RarityRules.fromJson({
        'coins': {'base': 'rare'},
      }),
      throwsFormatException,
    );
    expect(
      () => RarityRules.fromJson({
        'xu': {'base': 'hiem'},
      }),
      throwsFormatException,
    );
  });

  testWidgets('a bundle draws each icon in its rarity frame', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RewardBundleView(
            bundle: RewardBundle(const [
              RewardItem.coins(5000),
              RewardItem.giotHoa(3),
              RewardItem.pot('koi'),
              RewardItem.cat(),
            ]),
          ),
        ),
      ),
    );
    for (final r in RewardRarity.values) {
      expect(find.byKey(Key('reward-frame-${r.name}')), findsOneWidget);
    }
    final frame = tester.getSize(find.byType(RarityFrame).first);
    expect(frame.width, 28 * RewardBundleView.frameScale);
  });

  testWidgets('7-day board: art per state, label in the band, badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = defaultLoginRewards;
    LoginTile stateOf(int n) => n < 3
        ? LoginTile.claimed
        : n == 3
        ? LoginTile.today
        : LoginTile.locked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(14),
            child: LoginWeekBoard(
              tile: (n) => LoginDayTile(
                day: n,
                state: stateOf(n),
                bundle: config.day(n),
              ),
            ),
          ),
        ),
      ),
    );
    Iterable<String> assets(String key) => tester
        .widgetList<Image>(
          find.descendant(
            of: find.byKey(Key(key)),
            matching: find.byType(Image),
          ),
        )
        .map((i) => (i.image as AssetImage).assetName);
    expect(assets('login-day-1'), contains(PhucLoiArt.oDaNhan.path));
    expect(assets('login-day-1'), contains(PhucLoiArt.huyHieuDaNhan.path));
    expect(assets('login-day-3'), contains(PhucLoiArt.oHomNay.path));
    expect(assets('login-day-5'), contains(PhucLoiArt.oKhoa.path));
    expect(assets('login-day-7'), contains(PhucLoiArt.oNgay7.path));
    expect(find.byType(ClaimedBadge), findsNWidgets(2));
    for (var n = 1; n <= 7; n++) {
      expect(find.text('Ngày $n'), findsOneWidget);
    }

    // "Ngày 1" sits inside the README label band of its tile.
    final tile = tester.getRect(find.byKey(const Key('login-day-1')));
    final band = PhucLoiArt.oDaNhan
        .place(PhucLoiArt.oDaNhan.band!, tile.size)
        .shift(tile.topLeft);
    final label = tester.getRect(find.text('Ngày 1'));
    expect(band.inflate(0.5).contains(label.topLeft), isTrue);
    expect(band.inflate(0.5).contains(label.bottomRight), isTrue);

    // Small tiles are one canvas size; day 7 spans both rows.
    final d1 = tester.getSize(find.byKey(const Key('login-day-1')));
    final d3 = tester.getSize(find.byKey(const Key('login-day-3')));
    final d6 = tester.getRect(find.byKey(const Key('login-day-6')));
    final d7 = tester.getRect(find.byKey(const Key('login-day-7')));
    expect(d3, d1);
    expect(d7.height, greaterThan(d1.height * 1.4));
    expect(d7.left, greaterThan(d6.right - d6.width * 0.2));
    expect(d7.right, lessThanOrEqualTo(306.5));

    // Locked gifts stay recognisable, and amounts keep one font size on
    // every small tile. Day 6 draws its first gift plus "+1".
    final x10 = tester.getRect(find.text('×10'));
    final k50 = tester.getRect(find.text('50k'));
    final x50 = tester.getRect(find.text('×50'));
    expect(k50.height, closeTo(x10.height, 0.01));
    expect(x50.height, closeTo(x10.height, 0.01));
    expect(tester.widget<Text>(find.text('50k')).style!.fontSize, 12);
    expect(find.text('×20'), findsNothing);
    expect(find.byKey(const Key('login-more-6')), findsOneWidget);
    final faded = tester.widgetList<Opacity>(
      find.descendant(
        of: find.byKey(const Key('login-day-6')),
        matching: find.byType(Opacity),
      ),
    );
    expect(faded, isNotEmpty);
    for (final o in faded) {
      expect(o.opacity, lockedGiftOpacity);
    }

    // Locked day 7: the gold lock sits in the bottom-right corner, at the
    // spot and size o_khoa draws its lock (fractions of a small tile's ink
    // width, so it matches the day 4-6 locks).
    final ink7 = PhucLoiArt.oNgay7
        .place(PhucLoiArt.oNgay7.ink!, d7.size)
        .shift(d7.topLeft);
    final lock = tester.getRect(find.byKey(const Key('login-day7-lock')));
    final ref = d7.height * LoginWeekBoard.smallInkPerDay7;
    expect(ref, closeTo(d1.width * 325 / 432, 0.5));
    final glyphH = LoginTileArt.lockHeight * ref;
    expect(lock.height, closeTo(glyphH * 24 / 22, 0.5));
    final glyphRight = lock.left + lock.width * 20 / 24;
    final glyphBottom = lock.top + lock.height * 23 / 24;
    expect(glyphRight, closeTo(ink7.right - LoginTileArt.lockRight * ref, 0.5));
    expect(
      glyphBottom,
      closeTo(ink7.bottom - LoginTileArt.lockBottom * ref, 0.5),
    );
    expect(lock.center.dx, greaterThan(ink7.center.dx));
    expect(lock.center.dy, greaterThan(ink7.center.dy));
    // o_khoa: same fractions measured from Phú's picture.
    const k = PhucLoiArt.oKhoa;
    final kw = k.ink!.width;
    expect((k.ink!.right - 347) / kw, closeTo(LoginTileArt.lockRight, 0.01));
    expect((k.ink!.bottom - 356) / kw, closeTo(LoginTileArt.lockBottom, 0.01));
    expect((356 - 246) / kw, closeTo(LoginTileArt.lockHeight, 0.01));
  });
}
