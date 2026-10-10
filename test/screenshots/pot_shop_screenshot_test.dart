// Renders Tiệm Chậu Hoa, Sổ sưu tầm and the Tổng kết card to PNGs.
// Skipped unless SHOT_DIR is set:
//   $env:SHOT_DIR="C:\tmp\shots"; flutter test test/screenshots/pot_shop_screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/audio/sounds.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/game_root.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/save/game_state.dart';
import 'package:ai_game/ui/map_popup.dart';
import 'package:ai_game/ui/pot_book_screen.dart';
import 'package:ai_game/ui/pot_shop_screen.dart';
import 'package:ai_game/ui/summary_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

final _dir = Platform.environment['SHOT_DIR'];

Future<void> _loadFonts() async {
  const fonts = {
    AppFonts.body: 'assets/fonts/nunito/Nunito-VariableFont_wght.ttf',
    AppFonts.display: 'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
  };
  for (final e in fonts.entries) {
    final bytes = File(e.value).readAsBytesSync();
    await (FontLoader(
      e.key,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  // Material icons (the day-7 lock) come with the Flutter SDK; tests do not
  // load them by default and would draw empty squares.
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    final icons = File(
      [
        root,
        'bin',
        'cache',
        'artifacts',
        'material_fonts',
        'materialicons-regular.otf',
      ].join(Platform.pathSeparator),
    );
    if (icons.existsSync()) {
      await (FontLoader('MaterialIcons')..addFont(
            Future.value(ByteData.sublistView(icons.readAsBytesSync())),
          ))
          .load();
    }
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var round = 0; round < 3; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
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

Widget _frame(Key key, Widget child) => RepaintBoundary(
  key: key,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SoundScope(
      sounds: Sounds(heard: []),
      child: Material(
        type: MaterialType.transparency,
        child: GameFrame(child: child),
      ),
    ),
  ),
);

ShopSession _s({int money = 420000, int phaLe = 300, int day = 12}) {
  final s = newSession(sounds: Sounds(heard: []));
  s.state.day = day;
  s.state.money = money;
  s.state.phaLe = phaLe;
  s.state.potShopHintShown = true;
  s.buyAndGoToShop();
  return s;
}

Future<void> _shoot(
  WidgetTester tester,
  String name,
  ShopSession s,
  Widget Function(ShopSession) build, {
  Future<void> Function()? after,
}) async {
  await tester.pumpWidget(_frame(ValueKey('shot-$name'), build(s)));
  await _settle(tester);
  if (after != null) {
    await after();
    await _settle(tester);
  }
  await _save(tester, ValueKey('shot-$name'), name);
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('pot shop shots', skip: _dir == null, (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    Widget shop(ShopSession s) => PotShopScreen(session: s);
    Widget book(ShopSession s) => PotBookScreen(session: s);

    final a = _s();
    a.state.potCounts['chau_bach_duong'] = 1;
    a.openPotShop();
    await _shoot(tester, 'tiem_1_hoang_dao_360x640', a, shop);

    final b = _s(phaLe: 280);
    b.state.potCounts['chau_thao_thiet'] = 1;
    b.openPotShop(group: 'sonHai');
    await _shoot(tester, 'tiem_2_son_hai_360x640', b, shop);

    final c = _s(phaLe: 700);
    for (final id in ['dragon', 'tiger', 'koi', 'crane']) {
      c.state.potCounts[id] = 1;
    }
    c.openPotShop(group: 'linhVat');
    await _shoot(tester, 'tiem_3_linh_vat_360x640', c, shop);

    final d = _s();
    d.openPotShop();
    await _shoot(
      tester,
      'tiem_4_hoi_mua_360x640',
      d,
      shop,
      after: () async {
        await tester.tap(find.byKey(const Key('potshop-buy-chau_kim_nguu')));
        await tester.pump();
      },
    );

    final e = _s();
    e.openPotShop();
    await _shoot(
      tester,
      'tiem_5_da_co_360x640',
      e,
      shop,
      after: () async {
        await tester.tap(find.byKey(const Key('potshop-buy-chau_kim_nguu')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
        await tester.pump();
      },
    );

    final f = _s();
    f.openShop();
    f.openPotShop(group: 'sonHai');
    await _shoot(
      tester,
      'tiem_6_dang_ban_360x640',
      f,
      shop,
      after: () async {
        await tester.tap(find.byKey(const Key('potshop-buy-chau_cung_ky')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('potshop-confirm-yes')));
        await tester.pump();
      },
    );

    // Gift-or-buy labels (30-37 chars) wrap to two lines in the card.
    final q = _s(phaLe: 700);
    q.openPotShop(group: 'linhVat');
    await _shoot(tester, 'tiem_7_linh_vat_qua_hoac_mua_360x640', q, shop);

    final q2 = _s(phaLe: 700);
    q2.openPotShop(group: 'linhVat');
    await _shoot(
      tester,
      'tiem_8_linh_vat_cuon_360x640',
      q2,
      shop,
      after: () async {
        await tester.drag(find.byType(GridView), const Offset(0, -420));
        await tester.pump();
      },
    );

    // The book.
    final g = _s();
    for (final id in [
      'chau_bach_duong',
      'chau_song_tu',
      'chau_su_tu',
      'chau_thien_binh',
      'chau_ho_cap',
    ]) {
      g.state.potCounts[id] = 1;
    }
    g.openPotBook();
    await _shoot(tester, 'so_1_hoang_dao_360x640', g, book);

    final h = _s();
    h.state.potCounts['chau_cung_ky'] = 1;
    h.openPotBook(group: 'sonHai');
    await _shoot(tester, 'so_2_son_hai_360x640', h, book);

    final i = _s(phaLe: 50);
    for (final p in i.potGroupPots('linhVat')) {
      i.state.potCounts[p.id] = 1;
    }
    i.openPotBook(group: 'linhVat');
    await _shoot(tester, 'so_3_du_bo_nhan_thuong_360x640', i, book);

    final j = _s();
    j.state.potCounts['chau_su_tu'] = 1;
    j.openPotBook(detail: 'chau_su_tu');
    await _shoot(tester, 'so_4_chi_tiet_da_co_360x640', j, book);

    final k = _s();
    k.openPotBook(detail: 'chau_ky_lan');
    await _shoot(tester, 'so_5_chi_tiet_chua_co_360x640', k, book);

    final w = _s();
    w.openPotBook(detail: 'crane');
    await _shoot(tester, 'so_7_chi_tiet_qua_chuoi_30_360x640', w, book);

    final w2 = _s();
    w2.openPotBook(detail: 'koi');
    await _shoot(tester, 'so_8_chi_tiet_qua_chuoi_14_360x640', w2, book);

    final l = _s();
    l.state.potCounts['koi'] = 1;
    l.openPotBook(detail: 'koi');
    await _shoot(tester, 'so_6_chi_tiet_linh_vat_360x640', l, book);

    // Tổng kết reminder card.
    final m = _s(money: 500000, day: 3);
    m.state.potShopHintShown = false;
    m.state.phase = DayPhase.summary;
    m.screen = Screen.summary;
    await _shoot(
      tester,
      'tong_ket_the_goi_y_360x640',
      m,
      (s) => SummaryScreen(session: s),
      after: () async {
        await tester.pump(const Duration(seconds: 2));
      },
    );

    // Bản đồ with the new row and its red dot.
    final n = _s();
    n.state.potCounts['koi'] = 1;
    n.state.potCounts['chau_su_tu'] = 1;
    await _shoot(
      tester,
      'ban_do_tiem_chau_hoa_360x640',
      n,
      (s) => Stack(
        children: [MapPopup(session: s, onClose: () {})],
      ),
    );
  });
}
