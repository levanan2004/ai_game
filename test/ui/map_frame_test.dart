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

Future<ShopSession> _pump(WidgetTester tester, Size size, int extra) async {
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
            MapPopup(session: s, onClose: () {}, extraRows: _more(extra)),
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

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    final tag = '${size.width.round()}';

    testWidgets('six rows: 312x516 frame, centred, nothing clipped ($tag)', (
      tester,
    ) async {
      await _pump(tester, size, 0);
      final frame = tester.getRect(find.byKey(const Key('map-popup')));
      expect(frame.size, const Size(312, 516));
      expect(frame.center.dx, closeTo(size.width / 2, 0.5));
      expect(frame.bottom, lessThanOrEqualTo(size.height));
      final last = tester.getRect(find.byKey(const Key('map-garden')));
      // Inside the safe area, clear of the two bottom ornaments.
      expect(last.bottom, lessThanOrEqualTo(frame.bottom - 30.5));
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
          lessThanOrEqualTo(frame.bottom - 30.5 + 0.5),
        );
        await _save(tester, 'map_7_rows_scrolled_$tag');
      },
    );
  }
}
