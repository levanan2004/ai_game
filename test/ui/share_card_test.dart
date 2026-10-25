import 'dart:typed_data';

import 'package:ai_game/data/share_text.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/bouquet_table_screen.dart';
import 'package:ai_game/ui/decorate_screen.dart';
import 'package:ai_game/ui/share_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../helpers.dart';
import '../load_fonts.dart';

ShopSession _bouquetSession() {
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

Widget _card(ShopSession s, ShareKind kind, {bool story = false}) => ShareCard(
  kind: kind,
  story: story,
  shopName: s.state.shopName ?? '',
  caption: s.data.share.onImage(kind).first,
  gameTag: s.data.share.ui('image_text.game_tag'),
  linkLabel: s.data.share.ui('image_text.link_label'),
  storyFooter: s.data.share.ui('image_text.story_footer'),
  photo: kind == ShareKind.bouquet
      ? ShareBouquetPhoto(bouquet: BouquetArt(session: s))
      : FittedBox(
          fit: BoxFit.cover,
          child: ShopScenePreview(session: s),
        ),
);

Future<void> _pump(WidgetTester tester, Widget card, double h) async {
  tester.view.physicalSize = Size(360, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Align(alignment: Alignment.topLeft, child: card),
      ),
    ),
  );
}

void main() {
  setUpAll(loadTestFonts);

  for (final story in [false, true]) {
    testWidgets('bouquet card ${story ? '9:16' : '4:5'}', (tester) async {
      final s = _bouquetSession();
      final h = story ? ShareCard.storyHeight : ShareCard.feedHeight;
      await _pump(tester, _card(s, ShareKind.bouquet, story: story), h);
      expect(tester.getSize(find.byType(ShareCard)), Size(360, h));
      expect(find.text('Tiệm Mây'), findsOneWidget);
      expect(find.text(shareLinkLabel), findsOneWidget);
      expect(find.text('Chơi miễn phí tại'), findsOneWidget);
      expect(find.textContaining('Mã mời'), findsNothing);
      expect(
        find.text('“${s.data.share.onImage(ShareKind.bouquet).first}”'),
        findsOneWidget,
      );
      expect(
        find.text('~ Hẹn bạn ở tiệm hoa nhé ~'),
        story ? findsOneWidget : findsNothing,
      );
      final qr = tester.getRect(find.byKey(const Key('share-qr')));
      expect(qr.width, moreOrLessEquals(166 / 3, epsilon: 0.1));
      expect(qr.left, moreOrLessEquals(842 / 3, epsilon: 0.1));
      expect(qr.top, moreOrLessEquals((story ? 1372 : 1132) / 3, epsilon: 0.1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('QR points to the /tai-game page', (tester) async {
    final s = newSession();
    s.state.shopName = 'Tiệm Mây';
    await _pump(tester, _card(s, ShareKind.shop), ShareCard.feedHeight);
    final qr = tester.widget<QrImageView>(find.byKey(const Key('share-qr')));
    expect(qr.errorCorrectionLevel, QrErrorCorrectLevel.M);
    expect(shareLink, 'https://tiemhoasommai.com/tai-game');
    expect(find.byKey(const Key('decorate-shop-name')), findsOneWidget);
    expect(find.byKey(const Key('decorate-set')), findsNothing);
  });

  testWidgets('long shop name is cut at 20 characters', (tester) async {
    final s = newSession();
    s.state.shopName = 'Tiệm Hoa Có Cái Tên Rất Là Dài Luôn';
    await _pump(tester, _card(s, ShareKind.shop), ShareCard.feedHeight);
    final t = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('share-shop-name')),
        matching: find.byType(Text),
      ),
    );
    expect(t.data, 'Tiệm Hoa Có Cái Tên …');
  });

  testWidgets('renders to a 1080×1350 PNG off screen', (tester) async {
    final s = newSession();
    s.state.shopName = 'Tiệm Mây';
    late BuildContext ctx;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    final f = renderSharePng(
      ctx,
      _card(s, ShareKind.shop),
      size: const Size(360, ShareCard.feedHeight),
    );
    Uint8List? png;
    f.then((v) => png = v);
    for (var i = 0; i < 20 && png == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(png, isNotNull);
    final b = ByteData.sublistView(png!);
    expect(b.getUint32(16), 1080);
    expect(b.getUint32(20), 1350);
    expect(find.byType(ShareCard), findsNothing);
  });
}
