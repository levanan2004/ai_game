import 'dart:io';
import 'dart:ui' as ui;

import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/map_popup.dart';
import 'package:ai_game/ui/ui_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

/// The map frame (Phú's ban_do_khung, 9-slice): 312x516 dp, rows inside the
/// safe area, the six real rows fit (the Xếp hạng Mị lực row is one of them),
/// seven scroll. With SHOT_DIR set it also writes
/// screenshots.
final _dir = Platform.environment['SHOT_DIR'];
const _shot = Key('map-shot');

List<Widget Function(double)> _more(int n) => [
  for (var i = 0; i < n; i++)
    (h) => MapPlace(
      key: Key('map-extra-$i'),
      height: h,
      icon: 'xep_hang_icon',
      title: 'Xếp hạng Mị lực',
      subtitle: '1.${i + 1}00 Mị lực',
      onTap: () {},
    ),
];

Future<ShopSession> _pump(
  WidgetTester tester,
  Size size,
  int extra, {
  VoidCallback? onClose,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final s = newSession();
  await tester.pumpWidget(
    MaterialApp(
      home: RepaintBoundary(
        key: _shot,
        child: Stack(
          children: [
            const ColoredBox(color: Color(0xFFF7F5EF)),
            MapPopup(
              session: s,
              onClose: onClose ?? () {},
              extraRows: _more(extra),
            ),
          ],
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 600)),
  );
  await tester.pump();
  return s;
}

Future<void> _save(WidgetTester tester, String name) async {
  if (_dir == null) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_shot),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${_dir!}${Platform.pathSeparator}$name.png');
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(loadTestFonts);

  test(
    'the frame numbers are the measured ones (936x1394, 162/158/152/150)',
    () {
      const f = UiSkin.mapFrame;
      expect(
        [f.w, f.h, f.left, f.top, f.right, f.bottom],
        [936, 1394, 162, 158, 152, 150],
      );
      expect(File(f.path).existsSync(), isTrue);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('images/ban_do/'),
      );
    },
  );

  for (final size in const [
    Size(360, 640),
    Size(390, 844),
    Size(390, 680), // a short phone (the live report)
  ]) {
    final tag = '${size.width.round()}x${size.height.round()}';

    testWidgets(
      'close X: top-right of the frame, clear of the compass ($tag)',
      (tester) async {
        var closed = 0;
        await _pump(tester, size, 0, onClose: () => closed++);
        final frame = tester.getRect(find.byKey(const Key('map-popup')));
        final x = tester.getRect(find.byKey(const Key('map-close')));
        final hit = tester.getRect(find.byKey(const Key('map-close-box')));
        // the red round X of the other popups, in the corner above the frame
        expect(x.width, closeTo(28, 0.01));
        expect(x.center.dx, greaterThan(frame.right));
        expect(x.center.dy, lessThan(frame.top));
        expect(hit.width, greaterThanOrEqualTo(44));
        expect(hit.height, greaterThanOrEqualTo(44));
        // inside the screen, whole
        expect(x.top, greaterThanOrEqualTo(0));
        expect(x.right, lessThanOrEqualTo(size.width));
        expect(hit.top, greaterThanOrEqualTo(0));
        // the compass is a circle about 54 dp across in the frame's corner
        final compass = Offset(frame.right - 27, frame.top + 27);
        final nearest = Offset(
          compass.dx.clamp(x.left, x.right),
          compass.dy.clamp(x.top, x.bottom),
        );
        expect((nearest - compass).distance, greaterThan(27));
        // and clear of the first row and the title
        expect(
          x.bottom,
          lessThan(tester.getRect(find.byKey(const Key('map-market'))).top),
        );
        await tester.tap(find.byKey(const Key('map-close')));
        expect(closed, 1);
        // the whole 44 dp box takes the tap
        await tester.tapAt(hit.topLeft + const Offset(2, 2));
        expect(closed, 2);
        // outside the frame still closes; a tap on the frame does not
        await tester.tapAt(const Offset(4, 300));
        expect(closed, 3);
        await tester.tapAt(frame.center);
        expect(closed, 3);
        await _save(tester, 'map_close_$tag');
      },
    );

    testWidgets('six rows: 312x516 frame, centred, nothing clipped ($tag)', (
      tester,
    ) async {
      await _pump(tester, size, 0);
      final frame = tester.getRect(find.byKey(const Key('map-popup')));
      expect(frame.size, const Size(312, 516));
      expect(frame.center.dx, closeTo(size.width / 2, 0.5));
      expect(frame.bottom, lessThanOrEqualTo(size.height));
      final last = tester.getRect(find.byKey(const Key('map-garden')));
      // Clear of the two bottom ornaments (pin left, blossom right), which
      // stand 51 dp above the frame's bottom edge.
      expect(MapPopup.decorationZone, greaterThanOrEqualTo(51));
      expect(
        last.bottom,
        lessThanOrEqualTo(frame.bottom - MapPopup.decorationZone + 0.01),
      );
      final rows = tester.getRect(find.byKey(const Key('map-rows')));
      expect(
        rows.bottom,
        lessThanOrEqualTo(frame.bottom - MapPopup.decorationZone + 0.01),
      );
      expect(frame.top, greaterThanOrEqualTo(0));
      // all six rows are there, one under the other, none cut at the list end
      for (final k in const [
        'map-market',
        'map-pets',
        'map-pet-shop',
        'map-pot-shop',
        'map-garden',
      ]) {
        final r = tester.getRect(find.byKey(Key(k)));
        expect(r.top, greaterThanOrEqualTo(rows.top - 0.01), reason: k);
        expect(r.bottom, lessThanOrEqualTo(rows.bottom + 0.01), reason: k);
      }
      expect(last.left, greaterThanOrEqualTo(frame.left + 19.5));
      expect(last.right, lessThanOrEqualTo(frame.right - 19.8));
      expect(last.height, greaterThanOrEqualTo(60));
      final list = tester.widget<SingleChildScrollView>(
        find.byKey(const Key('map-rows')),
      );
      expect(list.physics, isA<NeverScrollableScrollPhysics>());
      await _save(tester, 'map_6_rows_$tag');
    });

    testWidgets(
      'seven rows (one more) scroll, rows keep their minimum ($tag)',
      (tester) async {
        await _pump(tester, size, 1);
        final list = tester.widget<SingleChildScrollView>(
          find.byKey(const Key('map-rows')),
        );
        expect(list.physics, isA<ClampingScrollPhysics>());
        expect(
          tester.getRect(find.byKey(const Key('map-garden'))).height,
          greaterThanOrEqualTo(60),
        );
        await tester.drag(
          find.byKey(const Key('map-rows')),
          const Offset(0, -300),
        );
        await tester.pump();
        final frame = tester.getRect(find.byKey(const Key('map-popup')));
        expect(
          tester.getRect(find.byKey(const Key('map-extra-0'))).bottom,
          lessThanOrEqualTo(frame.bottom - MapPopup.decorationZone + 0.5),
        );
        // and nothing is drawn in the ornament zone: the list view ends above
        expect(
          tester.getRect(find.byKey(const Key('map-rows'))).bottom,
          lessThanOrEqualTo(frame.bottom - MapPopup.decorationZone + 0.01),
        );
        await _save(tester, 'map_7_rows_scrolled_$tag');
      },
    );
  }
}
