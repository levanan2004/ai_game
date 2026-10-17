import 'dart:convert';
import 'dart:io';

import 'package:ai_game/ui/ui_skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

String _imagePath(WidgetTester tester, Finder within) => tester
    .widget<SkinSliceImage>(
      find.descendant(of: within, matching: find.byType(SkinSliceImage)).first,
    )
    .slice
    .path;

void main() {
  test('slice numbers match ui_9slice.json and every file exists', () {
    final json =
        jsonDecode(
              File('assets/images/ui_dot1/ui_9slice.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final s in UiSkin.all) {
      expect(File(s.path).existsSync(), isTrue, reason: s.path);
      final j = json[s.id] as Map<String, dynamic>?;
      if (j == null) continue; // ribbon pieces and round buttons
      expect(
        [s.w, s.h, s.left, s.top, s.right, s.bottom],
        [j['w'], j['h'], j['left'], j['top'], j['right'], j['bottom']],
        reason: s.id,
      );
    }
    // Pieces Phú grouped share one canvas so states never jump.
    for (final g in [
      [
        UiSkin.primary,
        UiSkin.primaryPressed,
        UiSkin.secondary,
        UiSkin.disabled,
      ],
      [UiSkin.tabOn, UiSkin.tabOff],
      [UiSkin.back, UiSkin.close],
    ]) {
      expect(g.map((s) => Size(s.w, s.h)).toSet(), hasLength(1));
    }
  });

  testWidgets('button: pressed art sinks the label, disabled is nut_tat', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 200,
          child: SkinButton(
            key: const Key('b'),
            label: 'Nhận quà',
            height: 50,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    final b = find.byKey(const Key('b'));
    expect(tester.getSize(b), const Size(200, 50));
    expect(_imagePath(tester, b), UiSkin.primary.path);
    final up = tester.getCenter(find.text('Nhận quà')).dy;
    final g = await tester.startGesture(tester.getCenter(b));
    await tester.pump();
    expect(_imagePath(tester, b), UiSkin.primaryPressed.path);
    // 4 px on the 150 px canvas at 50 dp: 4 / 3.
    expect(
      tester.getCenter(find.text('Nhận quà')).dy - up,
      closeTo(4 / 3, 0.01),
    );
    await g.up();
    await tester.pump();
    expect(taps, 1);

    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 200,
          child: SkinButton(
            key: const Key('b'),
            label: 'Đã nhận',
            height: 50,
            enabled: false,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(_imagePath(tester, b), UiSkin.disabled.path);
    await tester.tap(b);
    expect(taps, 1);
  });

  testWidgets('tabs keep their size when selected', (tester) async {
    Future<Size> size(bool on) async {
      await tester.pumpWidget(
        _host(
          SkinTab(
            key: const Key('t'),
            label: 'Giftcode',
            selected: on,
            onTap: () {},
          ),
        ),
      );
      return tester.getSize(find.byKey(const Key('t')));
    }

    expect(await size(true), await size(false));
  });

  testWidgets('slices paint once loaded, at odd scales, without asserts', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkinButton(label: 'Nhận quà', height: 47, onPressed: () {}),
              SkinTab(label: 'Giftcode', selected: true, onTap: () {}),
              const SkinInput(field: TextField(), height: 43),
              const SkinTray(scale: 4.3, child: SizedBox(height: 30)),
              const SkinPanel(scale: 2.7, child: SizedBox(height: 40)),
              const SkinRibbon(title: 'Phúc lợi', height: 45),
            ],
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('popup height follows its content', (tester) async {
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 344,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: SkinPopup(
              key: const Key('p'),
              title: 'Hộp thư',
              onBack: () {},
              onClose: () {},
              child: const SizedBox(height: 100),
            ),
          ),
        ),
      ),
    );
    final pad = UiSkin.popup.padding / 3;
    expect(
      tester.getSize(find.byKey(const Key('p'))).height,
      closeTo(SkinPopup.lift + pad.vertical + 100, 0.01),
    );
    expect(find.byType(SkinRoundButton), findsNWidgets(2));
    expect(find.text('Hộp thư'), findsOneWidget);
  });
}
