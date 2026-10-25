import 'dart:convert';
import 'dart:io';

import 'package:ai_game/data/economy.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hà Phương's gio_cao_diem_gia_cho_block.json, merged into economy.json.
void main() {
  final e = Economy.fromJson(
    jsonDecode(File('assets/data/economy.json').readAsStringSync())
        as Map<String, dynamic>,
  );
  final block =
      jsonDecode(
            File(
              'assets/data/gio_cao_diem_gia_cho_block.json',
            ).readAsStringSync(),
          )
          as Map<String, dynamic>;

  test('arrival weights come from the block; daily total unchanged', () {
    final want = (block['day']['arrivalWeightsByHour'] as Map).map(
      (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()),
    );
    expect(e.arrivalWeightsByHour, want);
    final total = e.arrivalWeightsByHour.values.fold(0.0, (a, b) => a + b);
    expect(total, closeTo(11.2, 1e-9));
    expect(e.peakLabelsVi[8], block['day']['peakLabelsVi']['8']);
  });

  test('peak windows and warn minutes', () {
    final w = e.peakWindows;
    expect(w.peaks.map((p) => (p.start, p.end, p.labelKey)), [
      (8, 10, 'gioDiLam'),
      (17, 19, 'gioTanTam'),
    ]);
    expect(w.lunchQuiet!.start, 12);
    expect(w.lunchQuiet!.end, 15);
    expect(w.warnBeforeMinutes, block['peakWindows']['warnBeforeMinutes']);
    expect(w.peakAt(9)!.labelKey, 'gioDiLam');
    expect(w.peakAt(10), isNull);
    expect(w.peakAt(18)!.labelKey, 'gioTanTam');
    expect(w.peakAt(19), isNull);
    expect(w.isLunchQuiet(14), isTrue);
    expect(w.isLunchQuiet(15), isFalse);
    expect(PeakWindows.fromJson(null).peaks, isEmpty);
  });

  test('daily fluctuation: flowers only', () {
    final f = e.dailyFluctuation;
    expect(f.enabled, isTrue);
    expect(f.range, block['market']['dailyFluctuation']['range']);
    expect(f.step, block['market']['dailyFluctuation']['step']);
    expect(f.flowers, isTrue);
    expect(f.active, isTrue);
    expect(block['marketFluctuationAppliesTo']['wrappingPaper'], isFalse);
    expect(DailyFluctuation.fromJson(null, null).active, isFalse);
  });

  test('posterDaysBefore, price ramp and early buyers per holiday', () {
    expect(e.posterDaysBefore, block['holidays']['posterDaysBefore']);
    expect(e.holidayPriceWindowDays, 0);
    for (final b in block['holidays']['list'] as List) {
      final h = e.holidays.firstWhere((h) => h.id == b['id']);
      expect(
        h.priceRamp,
        (b['priceRamp'] as Map).map(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()),
        ),
        reason: h.id,
      );
      expect(
        h.preHolidayCustomerMultiplier,
        (b['preHolidayCustomerMultiplier'] as Map).map(
          (k, v) => MapEntry(int.parse(k as String), (v as num).toDouble()),
        ),
        reason: h.id,
      );
      // Ramp day 0 = the old one-day multiplier.
      expect(h.priceRamp[0], h.marketPriceMultiplier, reason: h.id);
    }
  });

  test('holiday offsets and ramp factors', () {
    final v = e.holidays.firstWhere((h) => h.id == 'valentine');
    final day = v.days.first;
    final rose = e.flower('rose');
    expect(e.holidayOffset(day - 2), (v, -2));
    expect(e.holidayPriceFactor(rose, day - 3), v.priceRamp[-3]);
    expect(e.holidayPriceFactor(rose, day - 1), v.priceRamp[-1]);
    expect(e.holidayPriceFactor(rose, day), v.priceRamp[0]);
    expect(e.holidayPriceFactor(rose, day + 1), 1);
    expect(e.holidayPriceFactor(rose, day - 4), 1);
    expect(
      e.preHolidayCustomerFactor(day - 1),
      v.preHolidayCustomerMultiplier[-1],
    );
    expect(e.preHolidayCustomerFactor(day), 1);
    expect(e.preHolidayCustomerFactor(day - 2), 1);
    // Tết is two days; key 1 is the second day. Next year repeats.
    final tet = e.holidays.firstWhere((h) => h.id == 'tet');
    final mai = e.flower('hoa_mai');
    expect(e.holidayOffset(tet.days.last), (tet, 1));
    expect(e.holidayOffset(tet.days.first - 4), (tet, -4));
    expect(e.holidayOffset(v.days.first + 3), isNull);
    expect(e.holidayPriceFactor(mai, tet.days.last), tet.priceRamp[1]);
    expect(e.holidayPriceFactor(mai, tet.days.first - 4), tet.priceRamp[-4]);
    expect(
      e.holidayPriceFactor(mai, tet.days.first - 4 + e.yearLengthDays),
      tet.priceRamp[-4],
    );
    expect(e.preHolidayCustomerFactor(tet.days.first - 2), 1.15);
  });
}
