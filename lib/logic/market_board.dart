// Bảng giá chợ hôm nay (Phú's spec 25/10): which holiday the market card
// names, the sheet's banner and row order. Prices come from ShopSession.

import '../data/economy.dart';
import 'shop_session.dart';

enum MarketBannerKind { soon, holiday, after }

class MarketBanner {
  const MarketBanner(this.kind, this.holiday);

  final MarketBannerKind kind;
  final HolidayDef holiday;
}

/// Sheet banner on [day]: the holiday itself, a ramp day before it, or the
/// first day after its prices came back down; null on a normal day.
MarketBanner? marketBannerOf(Economy e, int day) {
  final today = e.holidayOn(day);
  if (today != null) return MarketBanner(MarketBannerKind.holiday, today);
  final ramp = e.holidayOffset(day);
  if (ramp != null) {
    if (ramp.$2 < 0) return MarketBanner(MarketBannerKind.soon, ramp.$1);
    return MarketBanner(MarketBannerKind.holiday, ramp.$1);
  }
  if (day > 1 && e.priceRiseHoliday(day) == null) {
    final y = e.priceRiseHoliday(day - 1);
    if (y != null) return MarketBanner(MarketBannerKind.after, y);
  }
  return null;
}

/// The holiday the market card names: today's, or the one whose prices are
/// rising.
HolidayDef? marketCardHoliday(Economy e, int day) =>
    e.holidayOn(day) ?? e.priceRiseHoliday(day);

/// "Lễ" tag: the flower costs more today because of a holiday.
bool holidayPriced(Economy e, FlowerDef f, int day) =>
    e.holidayPriceFactor(f, day) > 1;

/// Sheet rows: the flowers the shop can buy, holiday-priced first.
List<FlowerDef> marketBoardFlowers(ShopSession s) {
  final e = s.e;
  final owned = [
    for (final f in e.flowers)
      if (s.owned.contains(f.id)) f,
  ];
  return [
    for (final f in owned)
      if (holidayPriced(e, f, s.state.day)) f,
    for (final f in owned)
      if (!holidayPriced(e, f, s.state.day)) f,
  ];
}
