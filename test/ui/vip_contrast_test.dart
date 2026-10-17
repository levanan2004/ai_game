import 'dart:convert';
import 'dart:io';

import 'package:ai_game/theme/tokens.dart';
import 'package:ai_game/ui/vip_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG contrast ratio of two opaque colours.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('VIP colours contrast', () {
    test('Phú\'s VIP 3, 4 and 7 name colours', () {
      expect(vipNameColor(3), const Color(0xFFB8527E));
      expect(vipNameColor(4), const Color(0xFFA23E78));
      expect(vipNameColor(7), const Color(0xFF9A6418));
    });

    test('economy.json vip.nameColors matches the drawn colours', () {
      final eco =
          jsonDecode(File('assets/data/economy.json').readAsStringSync())
              as Map;
      final cols = (eco['vip'] as Map)['nameColors'] as Map;
      for (var k = 1; k <= 10; k++) {
        final hex = (cols['$k'] as String).substring(1);
        expect(
          Color(int.parse('FF$hex', radix: 16)),
          vipNameColor(k),
          reason: 'VIP $k',
        );
      }
    });

    test('VIP 3, 4 and 7 names reach 4.5:1 on the white card', () {
      for (final k in [3, 4, 7]) {
        expect(
          contrast(vipNameColor(k)!, AppColors.surfaceCard),
          greaterThanOrEqualTo(4.5),
          reason: 'VIP $k',
        );
      }
    });

    test('VIP 4 reaches 5:1 on the page background', () {
      expect(
        contrast(vipNameColor(4)!, AppColors.bgBase),
        greaterThanOrEqualTo(5.0),
      );
    });

    test('every VIP name colour reaches 3:1 on the card and the page', () {
      for (final bg in [AppColors.surfaceCard, AppColors.bgBase]) {
        for (var k = 1; k <= 10; k++) {
          expect(
            contrast(vipNameColor(k)!, bg),
            greaterThanOrEqualTo(3.0),
            reason: 'VIP $k on $bg',
          );
        }
      }
    });

    test('text on the VIP card gradient reaches 4.5:1 at both ends', () {
      for (final bg in vipCardGradient.colors) {
        expect(contrast(AppColors.onPrimary, bg), greaterThanOrEqualTo(4.5));
        expect(contrast(vipCardText, bg), greaterThanOrEqualTo(4.5));
      }
      expect(vipCardGradient.colors, const [
        Color(0xFF3F7F52),
        Color(0xFF2E5E3D),
      ]);
      expect(vipCardBorder, const Color(0xFFF2C94C));
    });
  });
}
