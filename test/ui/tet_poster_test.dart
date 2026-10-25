import 'package:ai_game/ui/gio_cao_diem_text.dart';
import 'package:ai_game/ui/market_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// Tết poster (Nhất 26/10): the day before "Ngày mai là Tết rồi!", mùng 1
/// "Chúc mừng năm mới!", later Tết days "Xuân sang, tiệm vẫn mở cửa";
/// never "Ngày mai là" on Tết itself.
void main() {
  final e = newSession().e;
  final tet = e.holidays.firstWhere((h) => h.id == 'tet');
  final first = e.yearLengthDays + tet.days.first;

  test('poster days around Tết', () {
    final s = newSession();
    s.state.day = first - 1;
    expect(s.posterHoliday!.$1.id, 'tet');
    expect(s.posterHoliday!.$2, 1);
    s.state.day = first;
    expect(s.posterHoliday!.$2, 0);
    s.state.day = first + 1;
    expect(s.posterHoliday!.$2, -1);
  });

  for (final (offset, line) in [
    (-1, GioCaoDiemText.tetTomorrow),
    (0, GioCaoDiemText.tetDay1),
    (1, GioCaoDiemText.tetLater),
  ]) {
    testWidgets('poster line on Tết ${offset >= 0 ? '+' : ''}$offset', (
      tester,
    ) async {
      final s = newSession();
      s.state.day = first + offset;
      await tester.pumpWidget(
        MaterialApp(
          home: Material(
            child: SizedBox(
              width: 360,
              height: 640,
              child: MarketScreen(session: s),
            ),
          ),
        ),
      );
      final poster = find.byKey(const Key('holiday-poster'));
      expect(
        find.descendant(of: poster, matching: find.text(line)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: poster, matching: find.text('Ngày mai là')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
