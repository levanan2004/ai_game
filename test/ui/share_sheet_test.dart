import 'package:ai_game/data/share_text.dart';
import 'package:ai_game/data/skins.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/bouquet_table_screen.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:ai_game/ui/share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

Future<void> _host(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(child: SizedBox(width: 360, height: 640, child: child)),
    ),
  );
}

/// Lets the off-screen render finish (real image decode, then frames).
Future<void> _settleRender(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    if (find.byKey(const Key('share-preview')).evaluate().isNotEmpty) return;
  }
}

ShopSession _admiring(WidgetTester tester) {
  final s = newSession(seed: 3);
  s.state.shopName = 'Tiệm Mây';
  stockAndOpen(s);
  final c = waitForCustomer(s);
  s.state.pendingArrivals.clear();
  s.openTable();
  expect(s.addStem(c.request.stems.keys.first), isTrue);
  s.selectPaper('kraft');
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  late List<String> shared;
  late List<Uint8List> pngs;
  setUp(() {
    shared = [];
    pngs = [];
    ShareSheet.share = (png, text) async {
      pngs.add(png);
      shared.add(text);
      return true;
    };
  });

  testWidgets('decorate shop: Khoe tiệm hoa opens the sheet and shares', (
    tester,
  ) async {
    final s = newSession();
    s.state.shopName = 'Tiệm Mây';
    s.openDecorate(skinGroupShop);
    await _host(tester, DecorateScreen(session: s));
    final t = s.data.share;
    final btn = find.byKey(const Key('share-shop'));
    expect(btn, findsOneWidget);
    expect(find.text(t.ui('button.share_shop')), findsOneWidget);
    // Inside the preview, above the tabs.
    final preview = tester.getRect(find.byKey(const Key('decorate-preview')));
    expect(preview.contains(tester.getRect(btn).center), isTrue);

    await tester.tap(btn);
    await tester.pump();
    expect(find.text(t.ui('sheet.title_shop')), findsOneWidget);
    await _settleRender(tester);
    expect(find.byKey(const Key('share-preview')), findsOneWidget);
    // Only messages without an invite code, tokens filled.
    final captions = t.captions(ShareKind.shop, tenTiem: 'Tiệm Mây');
    expect(find.text(captions[1]), findsOneWidget);
    expect(find.textContaining('Mã mời'), findsNothing);

    await tester.tap(find.byKey(const Key('share-caption-1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('share-go')));
    await tester.pump();
    expect(shared, hasLength(1));
    expect(shared.single, startsWith(captions[1]));
    expect(shared.single, contains('#TiemHoaSomMai'));
    final b = ByteData.sublistView(pngs.single);
    expect(b.getUint32(16), 1080);
    expect(b.getUint32(20), 1350);

    await tester.tap(find.byKey(const Key('share-close')));
    await tester.pump();
    expect(find.byKey(const Key('share-sheet')), findsNothing);
  });

  testWidgets('pet room decorate has no share button', (tester) async {
    final s = newSession();
    s.openDecorate(skinGroupRoom);
    await _host(tester, DecorateScreen(session: s));
    expect(find.byKey(const Key('share-shop')), findsNothing);
  });

  testWidgets('copy link puts the /tai-game link on the clipboard', (
    tester,
  ) async {
    String? clip;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clip = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    final s = newSession();
    s.state.shopName = 'Tiệm Mây';
    s.openDecorate(skinGroupShop);
    await _host(tester, DecorateScreen(session: s));
    await tester.tap(find.byKey(const Key('share-shop')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('share-copy-link')));
    await tester.pump();
    expect(clip, shareLink);
    expect(find.text(s.data.share.ui('toast.link_copied')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('share failure shows the toast', (tester) async {
    ShareSheet.share = (png, text) async => false;
    final s = newSession();
    s.state.shopName = 'Tiệm Mây';
    s.openDecorate(skinGroupShop);
    await _host(tester, DecorateScreen(session: s));
    await tester.tap(find.byKey(const Key('share-shop')));
    await tester.pump();
    await _settleRender(tester);
    await tester.tap(find.byKey(const Key('share-go')));
    await tester.pump();
    await tester.pump();
    expect(find.text(s.data.share.ui('toast.share_failed')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('bouquet: Khoe bó hoa only after the wrap', (tester) async {
    final s = _admiring(tester);
    await _host(tester, BouquetTableScreen(session: s));
    expect(find.byKey(const Key('share-bouquet')), findsNothing);
    await tester.tap(find.byKey(const Key('deliver-button')));
    await tester.pump();
    final hold = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wrap-hold'))),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final btn = find.byKey(const Key('share-bouquet'));
    expect(btn, findsOneWidget);
    final r = tester.getRect(btn);
    expect(r.bottom, lessThanOrEqualTo(422));
    expect(r.right, lessThanOrEqualTo(348));
    await tester.tap(btn);
    await tester.pump();
    expect(find.text(s.data.share.ui('sheet.title_bouquet')), findsOneWidget);
    await _settleRender(tester);
    await tester.tap(find.byKey(const Key('share-go')));
    await tester.pump();
    expect(shared, hasLength(1));
    expect(shared.single, isNot(contains('{')));
    await tester.tap(find.byKey(const Key('share-close')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('admire-deliver')));
    await tester.pump();
    expect(find.byKey(const Key('share-bouquet')), findsNothing);
  });
}
