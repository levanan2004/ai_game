import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  test('early buyers: preHolidayCustomerMultiplier before a holiday', () {
    final s = newSession(seed: 2);
    final e = s.e;
    double perBase(int day) {
      s.state.day = day;
      return s.expectedCustomers / e.baseCustomers(day);
    }

    final normal = perBase(3);
    for (final h in e.holidays) {
      final first = h.days.first;
      for (final entry in h.preHolidayCustomerMultiplier.entries) {
        expect(
          perBase(first + entry.key),
          closeTo(normal * entry.value, 1e-9),
          reason: '${h.id} ${entry.key}',
        );
      }
      // The holiday itself keeps only its customerMultiplier.
      expect(
        perBase(first),
        closeTo(normal * h.customerMultiplier, 1e-9),
        reason: h.id,
      );
    }
    // Valentine -2 is a normal crowd.
    final v = e.holidays.firstWhere((h) => h.id == 'valentine');
    expect(perBase(v.days.first - 2), closeTo(normal, 1e-9));
  });
}
