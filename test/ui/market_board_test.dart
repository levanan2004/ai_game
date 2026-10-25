import 'package:ai_game/data/economy.dart';
import 'package:ai_game/logic/market_board.dart';
import 'package:ai_game/logic/market_prices.dart';
import 'package:ai_game/logic/shop_session.dart';
import 'package:ai_game/ui/gio_cao_diem_text.dart';
import 'package:ai_game/ui/market_board.dart';
import 'package:ai_game/ui/market_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import '../load_fonts.dart';

/// Bảng giá chợ: card, sheet, tile arrows and the holiday look. Days and
/// flowers come from economy.json.
HolidayDef _h(Economy e, String id) => e.holidays.firstWhere((h) => h.id == id);

/// [h]'s first day in the second year, plus [offset].
int _dayOf(Economy e, HolidayDef h, int offset) =>
    e.yearLengthDays + h.days.first + offset;

Future<ShopSession> _pump(WidgetTester tester, {required int day}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final s = newSession(seed: 4);
  s.state.day = day;
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: ListenableBuilder(
          listenable: s,
          builder: (_, _) => MarketScreen(session: s),
        ),
      ),
    ),
  );
  await tester.pump();
  return s;
}

void main() {
  setUpAll(loadTestFonts);

  test('banner: soon, holiday, after, none', () {
    final e = newSession().e;
    final v = _h(e, 'valentine');
    final soon = v.priceRamp.keys.reduce((a, b) => a < b ? a : b);
    expect(marketBannerOf(e, _dayOf(e, v, soon))!.kind, MarketBannerKind.soon);
    expect(marketBannerOf(e, _dayOf(e, v, 0))!.kind, MarketBannerKind.holiday);
    final last = v.priceRamp.keys.reduce((a, b) => a > b ? a : b);
    final after = marketBannerOf(e, _dayOf(e, v, last + 1))!;
    expect(after.kind, MarketBannerKind.after);
    expect(after.holiday.id, 'valentine');
    expect(marketBannerOf(e, _dayOf(e, v, soon - 1)), isNull);
    final tet = _h(e, 'tet');
    expect(
      marketBannerOf(e, _dayOf(e, tet, 0))!.kind,
      MarketBannerKind.holiday,
    );
  });

  test('{tenHoa}: two names, then "và n loại khác", lower case', () {
    expect(GioCaoDiemText.flowerList(['Hồng', 'Tulip']), 'hồng và tulip');
    expect(
      GioCaoDiemText.flowerList(['Mai', 'Đào', 'Lan', 'Ly']),
      'mai, đào và 2 loại khác',
    );
  });

  testWidgets('day 1: card, sheet columns, "Mới mở chợ", no arrows', (
    tester,
  ) async {
    final s = await _pump(tester, day: 1);
    final card = tester.getRect(find.byKey(const Key('market-card')));
    expect(card.height, 56);
    expect(find.text(GioCaoDiemText.day(1)), findsOneWidget);
    expect(find.byType(PriceArrow), findsNothing);
    await tester.tap(find.text(GioCaoDiemText.openSheet));
    await tester.pump();
    final sheet = tester.getRect(find.byKey(const Key('market-sheet')));
    expect(sheet.height, closeTo(640 * 0.6, 0.5));
    for (final t in [
      GioCaoDiemText.colFlower,
      GioCaoDiemText.colPrice,
      GioCaoDiemText.colChange,
      GioCaoDiemText.hint,
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    final owned = s.e.flowers.where((f) => s.owned.contains(f.id));
    expect(find.text(GioCaoDiemText.firstDay), findsNWidgets(owned.length));
    await tester.tap(find.byKey(const Key('market-sheet-close')));
    await tester.pump();
    expect(find.byKey(const Key('market-sheet')), findsNothing);
  });

  testWidgets('a normal later day: tile arrows match the sheet', (
    tester,
  ) async {
    final e = newSession().e;
    var day = 2;
    while (marketCardHoliday(e, day) != null ||
        marketBannerOf(e, day) != null) {
      day++;
    }
    final s = await _pump(tester, day: day);
    for (final f in s.e.flowers.where((f) => s.owned.contains(f.id))) {
      final c = s.priceChange(f)!;
      final key = switch (c.trend) {
        PriceTrend.up => 'price-up',
        PriceTrend.down => 'price-down',
        PriceTrend.same => 'price-same',
      };
      expect(
        find.descendant(
          of: find.byKey(Key('price-arrow-${f.id}')),
          matching: find.byKey(Key(key)),
        ),
        findsOneWidget,
      );
    }
    expect(find.byKey(const Key('market-card-holiday')), findsNothing);
  });

  testWidgets('Valentine -2: holiday flowers first with the Lễ tag', (
    tester,
  ) async {
    final probe = newSession();
    final v = _h(probe.e, 'valentine');
    final s = await _pump(tester, day: _dayOf(probe.e, v, -2));
    s.owned.addAll(v.featuredFlowers);
    await tester.tap(find.byKey(const Key('market-card')));
    await tester.pump();
    expect(find.byKey(const Key('market-sheet-banner-soon')), findsOneWidget);
    final rows = marketBoardFlowers(s);
    final tagged = rows.where((f) => v.featuredFlowers.contains(f.id)).length;
    expect(tagged, greaterThan(0));
    for (var i = 0; i < rows.length; i++) {
      expect(v.featuredFlowers.contains(rows[i].id), i < tagged);
      expect(
        find.byKey(Key('market-sheet-tag-${rows[i].id}')),
        i < tagged ? findsOneWidget : findsNothing,
      );
    }
    expect(
      find.text(GioCaoDiemText.holidayName(v.id, v.nameVi)),
      findsOneWidget,
    );
  });

  testWidgets('Tết day 1: gold border and the holiday picture', (tester) async {
    final probe = newSession();
    final tet = _h(probe.e, 'tet');
    await _pump(tester, day: _dayOf(probe.e, tet, 0));
    expect(find.byKey(const Key('market-card-holiday-icon')), findsOneWidget);
    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('market-card')),
            matching: find.byType(Container),
          )
          .first,
    );
    final border = (box.decoration! as BoxDecoration).border! as Border;
    expect(border.top.color, MarketBoardColors.holiday);
  });
}
