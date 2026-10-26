import 'dart:io';

import 'package:ai_game/components/shop_scene.dart';
import 'package:ai_game/logic/shop_name.dart';
import 'package:ai_game/theme/tokens.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The real sign font, so widths match the phone.
  setUpAll(() async {
    final bytes = File(
      'assets/fonts/baloo2/Baloo2-VariableFont_wght.ttf',
    ).readAsBytesSync();
    await (FontLoader(
      AppFonts.display,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  });

  test('the reported name fits whole, last letter included', () {
    final text = shopSignText('Tiệm Hoa Sớm Maiz');
    expect(text.didExceedMaxLines, isFalse);
    expect(text.width, lessThanOrEqualTo(shopSignTextRoom));
  });

  test('a longest-allowed name fits 60% of the board at 12sp or more', () {
    const name = 'Tiệm Hoa Sớm Mai Bên Hồ 99';
    expect(name.length, maxShopNameLength);
    final text = shopSignText(name);
    // Fix 9: one line in 60% of the board, 12sp at the least, then '…'.
    expect(shopSignTextRoom, closeTo(184 * 0.6, 1e-9));
    expect(text.width, lessThanOrEqualTo(shopSignTextRoom));
    expect(text.text!.style!.fontSize, greaterThanOrEqualTo(12));
  });

  test('a short name keeps the full 14px size', () {
    final text = shopSignText('Tiệm Hoa');
    expect(text.text!.style!.fontSize, 14);
    expect(text.didExceedMaxLines, isFalse);
  });

  test('a name too long at 12sp gets an ellipsis', () {
    final text = shopSignText('Tiệm Hoa ${'Rất ' * 20}Dài');
    expect(text.didExceedMaxLines, isTrue);
    expect(text.width, lessThanOrEqualTo(shopSignTextRoom));
  });
}
