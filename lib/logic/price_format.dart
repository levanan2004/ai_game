/// Price labels for xu and Pha lê: the one place every shop card, button and
/// dialog gets its price text from (Phú's rule, An approved 10/10).
///
/// Xu on a card, button, chip or list line ([coinLabel]): under 1.000.000 the
/// whole number with dots ("80.000", "500.000"); from 1.000.000 millions with
/// a Vietnamese decimal comma and no ",0" ("1 tr", "6,5 tr", "30 tr"). A
/// confirm dialog, a resale line and a shortfall tooltip never abbreviate:
/// they use [coinFull] ("30.000.000"). Pha lê is always the whole number.
///
/// Where a coin icon sits next to the number the unit word is left out
/// ("Mua 30 tr"); in plain text without an icon the word stays
/// ("Mua 30 tr xu"): [priceLabel] and [priceUnit] differ only there.
library;

/// 1250000 -> "1.250.000". The whole number, dots between thousands.
String coinFull(int v) {
  if (v < 0) return '-${coinFull(-v)}';
  final digits = '$v';
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
    out.write(digits[i]);
  }
  return out.toString();
}

/// The abbreviated xu label: "80.000", "1 tr", "2,5 tr", "30 tr". Exact:
/// 1.250.000 is "1,25 tr", never rounded.
String coinLabel(int v) {
  if (v < 0) return '-${coinLabel(-v)}';
  if (v < 1000000) return coinFull(v);
  final whole = v ~/ 1000000;
  final rest = v % 1000000;
  if (rest == 0) return '$whole tr';
  var frac = rest.toString().padLeft(6, '0');
  while (frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  return '$whole,$frac tr';
}

/// A price next to its currency icon: [coinLabel] for xu, the whole number
/// for Pha lê ("120", "1.200").
String priceLabel(int amount, {bool phaLe = false}) =>
    phaLe ? coinFull(amount) : coinLabel(amount);

/// The whole number with its unit word: "150.000 xu", "36 Pha lê". Confirm
/// dialogs, resale lines and shortfall tooltips.
String priceUnit(int amount, {bool phaLe = false}) =>
    '${coinFull(amount)} ${phaLe ? 'Pha lê' : 'xu'}';

/// The abbreviated label with the unit word, for plain text without an icon:
/// "Mua 30 tr xu" -> "30 tr xu", "36 Pha lê".
String priceLabelUnit(int amount, {bool phaLe = false}) =>
    '${priceLabel(amount, phaLe: phaLe)} ${phaLe ? 'Pha lê' : 'xu'}';
