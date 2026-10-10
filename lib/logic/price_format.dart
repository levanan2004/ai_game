/// Price labels for xu and Pha lê, one place for every shop card.
///
/// Xu on a card or button: under 1.000.000 the whole number with dots
/// ("80.000", "500.000"); from 1.000.000 an abbreviation in millions with a
/// Vietnamese decimal comma and no ",0" ("1 tr", "2,5 tr", "30 tr"). Pha lê
/// is always the whole number ("120", "1.200"). A confirm dialog and a
/// resale line never abbreviate: they use [formatPriceFull] or
/// [formatPriceUnit].
library;

/// 1250000 -> "1.250.000". The whole number, dots between thousands.
String formatPriceFull(int n) {
  if (n < 0) return '-${formatPriceFull(-n)}';
  final digits = '$n';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A price on a card or a button, without the unit: "80.000", "2,5 tr",
/// "120". Millions are rounded to the nearest tenth (half up), so 2.540.000
/// reads "2,5 tr"; amounts that matter are shown whole in the dialog.
String formatPrice(int amount, {bool phaLe = false}) {
  if (amount < 0) return '-${formatPrice(-amount, phaLe: phaLe)}';
  if (phaLe || amount < 1000000) return formatPriceFull(amount);
  final tenths = (amount + 50000) ~/ 100000;
  final whole = tenths ~/ 10;
  final frac = tenths % 10;
  return frac == 0 ? '$whole tr' : '$whole,$frac tr';
}

/// The whole number with its unit: "150.000 xu", "36 Pha lê". Confirm
/// dialogs, resale lines and shortfall tooltips use this.
String formatPriceUnit(int amount, {bool phaLe = false}) =>
    '${formatPriceFull(amount)} ${phaLe ? 'Pha lê' : 'xu'}';
