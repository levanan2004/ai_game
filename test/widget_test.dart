import 'package:ai_game/game/shop_game.dart';
import 'package:ai_game/main.dart';
import 'package:ai_game/save/progress_store.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first
        .reset();
  });

  testWidgets('market -> main shop -> open, at phone size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    final backing = <String, String>{};
    await tester.pumpWidget(
      ShopApp(data: loadTestData(), store: ProgressStore.memory(backing)),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.text('Chợ hoa buổi sáng'), findsOneWidget);
    expect(find.text('Mở cửa luôn'), findsOneWidget);
    await tester.tap(find.byKey(const Key('plus-rose')));
    await tester.pump();
    expect(find.text('Mua & mở cửa'), findsOneWidget);
    await tester.tap(find.byKey(const Key('market-buy')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Mở cửa'), findsOneWidget);
    expect(find.text('Mục tiêu hôm nay'), findsOneWidget);
    await tester.tap(find.byKey(const Key('main-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đang chờ khách...'), findsOneWidget);

    final game = tester
        .widget<GameWidget<ShopGame>>(find.byType(GameWidget<ShopGame>))
        .game!;
    expect(game.camera.viewport.virtualSize.x, ShopGame.logicalWidth);

    // Star pill opens the Reviews screen.
    await tester.tap(find.byKey(const Key('nav-3')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Đánh giá của khách'), findsOneWidget);
    expect(find.text('Chưa có nhận xét nào'), findsOneWidget);
    await tester.tap(find.byKey(const Key('reviews-back')));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
