import 'dart:io';
import 'dart:ui' as ui;

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
    expect(rewardRarity(const RewardItem.treat(3)), RewardRarity.thuong);
    expect(rewardRarity(const RewardItem.giotHoa(10)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.phaLe(100)), RewardRarity.hiem);
    expect(rewardRarity(const RewardItem.phaLe(900)), RewardRarity.suThi);
    expect(rewardRarity(const RewardItem.pot('dragon')), RewardRarity.suThi);
    expect(rewardRarity(const RewardItem.cat()), RewardRarity.huyenThoai);
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
  });
}
