// Renders the Pha lê shop states (S1 to S6) to PNGs. Skipped unless SHOT_DIR
// is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/phale_shop_screenshot_test.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/data/phale_shop.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/ui/phale_popups.dart';
import 'package:ai_game/ui/phale_shop_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';
import '../logic/phale_shop_test.dart' show phaleEconomy;

final _dir = Platform.environment['SHOT_DIR'];

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 2; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }
}

Future<void> _save(WidgetTester tester, Key key, String name) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

Widget _frame(Key key, ShopSession s) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: GameFrame(
          child: ListenableBuilder(
            listenable: s,
            builder: (context, _) => Stack(
              children: [
                const ColoredBox(color: Color(0xFFF7F5EF)),
                if (s.phaleShopOpen)
                  Positioned.fill(child: PhaleShopHost(session: s)),
                if (s.phaleShort != null)
                  Positioned.fill(child: PhaleShortPopup(session: s)),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);

ShopSession _session({
  bool open = true,
  bool signedIn = true,
  PhaleGateway? gateway,
}) {
  final s = newSession(
    data: loadTestData(economy: phaleEconomy(open: open)),
  );
  if (signedIn) s.accountUid = 'me';
  s.state.money = 350000;
  s.state.phaLe = 250;
  s.phaleAutoPoll = false;
  if (gateway != null) s.phaleGateway = gateway;
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('pha le shop shots', skip: _dir == null, (tester) async {
    await loadTestFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final cfg = loadTestData().economy.phaLeShop;

    Future<void> shoot(String name, ShopSession s) async {
      await tester.pumpWidget(_frame(ValueKey('shot-$name'), s));
      await _settle(tester);
      await _save(tester, ValueKey('shot-$name'), name);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    }

    await shoot('phale_S1_cua_hang_360x640', _session()..openPhaleShop());
    await shoot(
      'phale_S5c_sap_mo_360x640',
      _session(open: false)..openPhaleShop(),
    );
    await shoot(
      'phale_S3_khach_360x640',
      _session(signedIn: false)..openPhaleShop(),
    );
    await shoot(
      'phale_S4c_thieu_phale_banner_360x640',
      _session()..openPhaleShop(need: 50, name: 'Cánh bình minh'),
    );
    final short = _session()..askPhaleShort('Cánh bình minh', 300);
    await shoot('phale_S4b_thieu_phale_popup_360x640', short);

    final confirm = _session()..openPhaleShop();
    confirm.phaleShop.pick('pack_50k');
    await shoot('phale_S2a_xac_nhan_360x640', confirm);

    final creating = _session()..openPhaleShop();
    creating.phaleShop.pick('pack_50k');
    unawaited(creating.phaleShop.confirmBuy());
    await shoot('phale_S2b_dang_tao_don_360x640', creating);

    final failGw = DemoPhaleGateway(config: cfg)..offline = true;
    final fail = _session(gateway: failGw)..openPhaleShop();
    fail.phaleShop.pick('pack_50k');
    await fail.phaleShop.confirmBuy();
    await shoot('phale_S2d_khong_tao_duoc_360x640', fail);

    Future<(ShopSession, DemoPhaleGateway)> order({
      Duration lifetime = const Duration(minutes: 15),
    }) async {
      final gw = DemoPhaleGateway(config: cfg, lifetime: lifetime);
      final s = _session(gateway: gw)..openPhaleShop();
      s.phaleShop.pick('pack_50k');
      await s.phaleShop.confirmBuy();
      return (s, gw);
    }

    final (wait, _) = await order();
    await shoot('phale_S6a_cho_tien_ve_360x640', wait);

    final (checking, _) = await order();
    checking.phaleShop.checking = true;
    await shoot('phale_S6b_dang_kiem_tra_360x640', checking);

    final (expired, _) = await order(lifetime: const Duration(seconds: -5));
    await shoot('phale_S6c_het_han_360x640', expired);

    final (mismatch, mgw) = await order();
    mgw.force(mismatch.phaleShop.order!.orderId, PhaleOrderStatus.mismatch);
    await mismatch.phaleShop.poll();
    await shoot('phale_S6d_lech_don_360x640', mismatch);

    final (offline, ogw) = await order();
    ogw.offline = true;
    await offline.phaleShop.poll();
    await shoot('phale_S6e_mat_mang_360x640', offline);

    final (ask, _) = await order();
    ask.phaleShop.askCancel();
    await shoot('phale_S6f_hoi_huy_don_360x640', ask);

    final (cancel, _) = await order();
    cancel.phaleShop.askCancel();
    await cancel.phaleShop.confirmCancel();
    await shoot('phale_S2e_da_huy_360x640', cancel);

    final (pending, _) = await order();
    pending.phaleShop.backToShop();
    await shoot('phale_S6g_don_dang_cho_360x640', pending);

    final (done, dgw) = await order();
    dgw.force(
      done.phaleShop.order!.orderId,
      PhaleOrderStatus.paid,
      granted: 550,
      balance: 800,
    );
    await done.phaleShop.poll();
    await shoot('phale_S2c_nhan_tien_360x640', done);
  });
}
