import 'dart:io';

import 'package:ai_game/data/wilting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every hoa sắp héo picture is in assets', () {
    for (final p in WiltingArt.all) {
      expect(File(p).existsSync(), isTrue, reason: p);
    }
  });

  test('no lavender bouquet and no bouquet for sale', () {
    final names = Directory(
      'assets/images/hoa_sap_heo',
    ).listSync().map((f) => f.uri.pathSegments.last).toList();
    expect(names.where((n) => n.contains('lavender')), isEmpty);
    expect(names.where((n) => n.contains('bo_hoa_kho_hong')), isEmpty);
  });
}
