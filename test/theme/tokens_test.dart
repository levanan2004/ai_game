import 'dart:convert';
import 'dart:io';

import 'package:ai_game/theme/tokens.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

Color _parse(String hex) {
  final h = hex.substring(1);
  final rgb = int.parse(h.substring(0, 6), radix: 16);
  final a = h.length == 8 ? int.parse(h.substring(6, 8), radix: 16) : 0xFF;
  return Color((a << 24) | rgb);
}

void main() {
  test('AppColors mirrors design_tokens.json', () {
    final j =
        jsonDecode(
              File('design/tiem-hoa/design_tokens.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final colors = j['color'] as Map<String, dynamic>;
    var checked = 0;
    for (final group in colors.entries) {
      for (final c in (group.value as Map<String, dynamic>).entries) {
        final path = '${group.key}.${c.key}';
        expect(AppColors.byPath[path], _parse(c.value as String), reason: path);
        checked++;
      }
    }
    expect(checked, AppColors.byPath.length);
  });
}
