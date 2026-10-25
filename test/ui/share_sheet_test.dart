import 'package:ai_game/data/share_text.dart';
import 'package:ai_game/data/skins.dart';
import 'package:ai_game/logic/match_scoring.dart';
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

/// A walk-in at the table with the bouquet built: the exact request, or one
/// stem of a flower they did not ask for.
ShopSession _table({required bool exact}) {
  final s = newSession(seed: 3);
  s.state.shopName = 'Tiệm Mây';
  stockAndOpen(s);
  final c = waitForCustomer(s);
  s.state.pendingArrivals.clear();
  s.openTable();
  final r = c.request;
  if (exact) {
    for (final e in r.stems.entries) {
      for (var i = 0; i < e.value; i++) {
        s.addStem(e.key);
      }
    }
    for (var i = 0; i < r.fillerCount; i++) {
      s.addStem(r.fillerId!);
    }
    s.selectPaper(r.paperId);
    s.selectRibbon(r.ribbonId);
  } else {
    // Only flowers the customer did not ask for.
    final other = s.unlockedFlowers.firstWhere(
      (f) => !r.requestedSpecies.contains(f.id),
    );
    expect(s.addStem(other.id), isTrue);
    s.selectPaper('kraft');
  }
  return s;
}

int _stars(ShopSession s) =>
    s.e.reviewStars[scoreBouquet(
      s.e,
      s.tableCustomer!.request,
      s.draft,
    ).tier.name] ??
    0;

Future<void> _wrap(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('deliver-button')));
  await tester.pump();
  final hold = await tester.startGesture(
    tester.getCenter(find.byKey(const Key('wrap-hold'))),
  );
  await tester.pump(const Duration(milliseconds: 40));
  await hold.up();
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
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

  testWidgets('bouquet: Khoe bó hoa after the wrap of a 4★+ bouquet', (
    tester,
  ) async {
    final s = _table(exact: true);
    expect(_stars(s), greaterThanOrEqualTo(4));
    await _host(tester, BouquetTableScreen(session: s));
    expect(find.byKey(const Key('share-bouquet')), findsNothing);
    await _wrap(tester);
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

  testWidgets('bouquet under 4★: no Khoe bó hoa', (tester) async {
    final s = _table(exact: false);
    expect(_stars(s), lessThan(4));
    await _host(tester, BouquetTableScreen(session: s));
    await _wrap(tester);
    expect(find.byKey(const Key('admire-deliver')), findsOneWidget);
    expect(find.byKey(const Key('share-bouquet')), findsNothing);
  });

  testWidgets('format toggle: 4:5 by default, Story 9:16 exports 1080×1920', (
    tester,
  ) async {
    final s = newSession();
    s.state.shopName = 'Tiệm Mây';
    s.openDecorate(skinGroupShop);
    await _host(tester, DecorateScreen(session: s));
    await tester.tap(find.byKey(const Key('share-shop')));
    await tester.pump();
    expect(find.text(shareFeedLabel), findsOneWidget);
    expect(find.text(shareStoryLabel), findsOneWidget);
    await _settleRender(tester);
    await tester.tap(find.byKey(const Key('share-go')));
    await tester.pump();
    var b = ByteData.sublistView(pngs.last);
    expect((b.getUint32(16), b.getUint32(20)), (1080, 1350));

    await tester.tap(find.byKey(const Key('share-format-story')));
    await tester.pump();
    await _settleRender(tester);
    await tester.tap(find.byKey(const Key('share-go')));
    await tester.pump();
    b = ByteData.sublistView(pngs.last);
    expect((b.getUint32(16), b.getUint32(20)), (1080, 1920));

    await tester.tap(find.byKey(const Key('share-format-feed')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('share-go')));
    await tester.pump();
    b = ByteData.sublistView(pngs.last);
    expect(b.getUint32(20), 1350);
  });
}
