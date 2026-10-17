// Fix round 17/10 (Phú's review) at phone size 390x844: one PNG per task.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/fix_round_1017_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/rewards.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/gacha_screen.dart';
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:ai_game/ui/vip_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../load_fonts.dart';
import '../logic/gacha_test.dart';
import '../logic/vip_test.dart' show FakeVipWallet, vipSession;
import '../ui/gacha_ui_test.dart' show ready;

final _dir = Platform.environment['SHOT_DIR'];
const _frame = Key('shot-frame');
const _size = Size(390, 844);

Future<void> _save(WidgetTester tester, String name) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_frame),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Future<void> _host(
  WidgetTester tester,
  Widget Function() child,
  Listenable listen,
) async {
  tester.view.physicalSize = _size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _frame,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Material(
          color: const Color(0xFFB9D7A8),
          child: ListenableBuilder(
            listenable: listen,
            builder: (_, _) => child(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _gacha(WidgetTester tester, ShopSession s) => _host(
  tester,
  () => Stack(
    children: [
      if (s.gacha.open) Positioned.fill(child: GachaScreen(session: s)),
      if (s.phaleShopOpen) Positioned.fill(child: PhaleShopHost(session: s)),
    ],
  ),
  Listenable.merge([s, s.gacha]),
);

void main() {
  setUpAll(loadTestFonts);
  if (_dir == null) {
    test('screenshots skipped (SHOT_DIR not set)', () {}, skip: true);
    return;
  }

  testWidgets('01 thiếu Pha lê', (tester) async {
    final s = await ready(tester, FakeGachaWallet(phaLe: 5));
    s.gacha.openScreen();
    await _gacha(tester, s);
    s.gacha.openBuy(10);
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-buy-pl')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-pl-ok')));
    await tester.pump();
    await _save(tester, '01_thieu_pha_le');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('02 wheel spin', (tester) async {
    final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 12});
    final s = await ready(tester, api);
    s.gacha.openScreen();
    await _gacha(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-1')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await _save(tester, '02a_quay1_dang_quay');
    await tester.pump(const Duration(milliseconds: 1700));
    await _save(tester, '02b_quay1_dung_o_o');
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, '02c_quay1_ket_qua');
    await tester.tap(find.byKey(const Key('gacha-result-claim')));
    await tester.pump();
    await tester.pump();
    api.nextResults = [
      {
        'featured': true,
        'items': RewardBundle([
          const RewardItem.pot('chau_cuu_vi_ho'),
        ]).toJson(),
      },
    ];
    await tester.tap(find.byKey(const Key('gacha-spin-1')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2650));
    await _save(tester, '02d_chau_tuan_vang');
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const Key('gacha-result-claim')));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('gacha-spin-10')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    await _save(tester, '02e_quay10_dang_quay');
    await tester.pump(const Duration(seconds: 3));
    await _save(tester, '02f_quay10_ket_qua');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('03 mua thẻ', (tester) async {
    final s = await ready(
      tester,
      FakeGachaWallet(cards: {'chau_cuu_vi_ho': 2}, xuLeft: 7),
    );
    s.gacha.openScreen();
    await _gacha(tester, s);
    s.gacha.openBuy(1);
    await tester.pump();
    await _save(tester, '03a_mua_the');
    await tester.tap(find.byKey(const Key('gacha-buy-info')));
    await tester.pump();
    await _save(tester, '03b_mua_the_info');
    await tester.pumpWidget(const SizedBox());
    final s2 = await ready(tester, FakeGachaWallet(xuLeft: 0));
    s2.gacha.openScreen();
    await _gacha(tester, s2);
    s2.gacha.openBuy(1);
    await tester.pump();
    await _save(tester, '03c_mua_the_het_xu');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('04 VIP chip', (tester) async {
    final s = vipSession(FakeVipWallet(level: 3, vnd: 500000));
    await tester.runAsync(() async {
      await s.syncWallet();
      await Future<void>.delayed(const Duration(milliseconds: 10));
    });
    await _host(
      tester,
      () => Stack(
        children: [
          Positioned.fill(child: PhaleShopScreen(session: s)),
          if (s.vip.open) Positioned.fill(child: VipScreen(session: s)),
        ],
      ),
      Listenable.merge([s, s.vip]),
    );
    await _save(tester, '04_vip_chip_cua_hang');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('05 wheel screen', (tester) async {
    final s = await ready(
      tester,
      FakeGachaWallet(
        cards: {'chau_cuu_vi_ho': 3},
        pity: {
          'chau_cuu_vi_ho': {'n': 23},
        },
      ),
    );
    s.gacha.openScreen();
    await _gacha(tester, s);
    await _save(tester, '05_vong_quay_tuan');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('06 quay 10 names', (tester) async {
    final api = FakeGachaWallet(cards: {'chau_cuu_vi_ho': 10});
    api.nextResults = [
      for (final i in [
        const RewardItem.coins(2000000),
        const RewardItem.petItem('canh_buom'),
        const RewardItem.pot('chau_su_tu'),
        const RewardItem.petItem('mu_rom'),
        const RewardItem.giotHoa(10),
        const RewardItem.coins(500000),
        const RewardItem.treat(3),
        const RewardItem.giotHoa(3),
        const RewardItem.coins(200000),
        const RewardItem.petItem('vong_hoa_nho'),
      ])
        {
          'items': RewardBundle([i]).toJson(),
        },
    ];
    final s = await ready(tester, api);
    s.gacha.openScreen();
    await _gacha(tester, s);
    await tester.tap(find.byKey(const Key('gacha-spin-10')));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await _save(tester, '06_quay10_ten_qua');
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpWidget(const SizedBox());
  });
}
