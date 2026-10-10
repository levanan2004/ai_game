import 'dart:math';

/// [start] is "Mở tiệm" with no cancel. [rename] is "Lưu tên" plus "Hủy".
enum ShopNameMode { start, rename }

/// Nhất's eight suggestions (nhat_dat_ten_tiem.md). The dice must not
/// repeat the name currently shown.
const suggestedShopNames = <String>[
  'Tiệm Hoa Nhà Mây',
  'Hoa Nắng Sớm',
  'Góc Hoa Nhỏ',
  'Tiệm Hoa Cúc Họa Mi',
  'Hoa Ơi',
  'Tiệm Hoa Gió Chiều',
  'Vườn Hoa Nhà Bé',
  'Hoa Ngõ Nhỏ',
];

/// Longest suggested name plus a space and [maxShopNameNumber].
const maxShopNameLength = 26;

/// Number painted after a suggested name, from 1 through this.
const maxShopNameNumber = 100000;

/// Letters (including Vietnamese), digits, spaces, and `&'-.`.
final shopNamePattern = RegExp(r"^[\p{L}\p{N} &'\-.]+$", unicode: true);

/// Trim, collapse spaces, then require 2–[maxShopNameLength] allowed characters.
/// Returns null when the name cannot be saved.
String? normalizeShopName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r' +'), ' ');
  if (name.length < 2 || name.length > maxShopNameLength) return null;
  if (name == '..') return null;
  if (!shopNamePattern.hasMatch(name)) return null;
  return name;
}

/// Same shop, whether or not the letters are capitalized.
/// Dart's lowercase, including Ơ → ơ. Firestore rules `lower()` only folds
/// A–Z, so the document id is this string and the rules do not re-fold it.
String shopNameKey(String name) => name.toLowerCase();

/// Result of reserving a shop name for one account.
enum ShopNameClaim { claimed, taken, failed }

String rollShopName(String current, Random rng) {
  final pool = [
    for (final name in suggestedShopNames)
      if (name != current) name,
  ];
  final choices = pool.isEmpty ? suggestedShopNames : pool;
  return choices[rng.nextInt(choices.length)];
}

/// [base] plus a number. The base is kept whole, so a name that cannot
/// fit the suffix is skipped.
String? shopNameWithNumber(String base, int n) {
  if (n < 1 || n > maxShopNameNumber) return null;
  return normalizeShopName('${base.trim()} $n');
}

/// One of the eight names with a random number from 1 to [maxShopNameNumber].
String? rollNumberedShopName(Random rng, {String? avoid}) {
  final bases = [...suggestedShopNames]..shuffle(rng);
  final skip = avoid == null ? null : shopNameKey(avoid);
  for (final base in bases) {
    final name = shopNameWithNumber(base, 1 + rng.nextInt(maxShopNameNumber));
    if (name == null) continue;
    if (skip != null && shopNameKey(name) == skip) continue;
    return name;
  }
  return null;
}

/// Unused-looking names based on [base], for a shop whose name is taken.
List<String> spareShopNames(String base, Random rng, {int limit = 12}) {
  final out = <String>[];
  final seen = <String>{shopNameKey(base)};
  void add(String? raw) {
    if (raw == null || out.length >= limit) return;
    final name = normalizeShopName(raw);
    if (name == null) return;
    if (!seen.add(shopNameKey(name))) return;
    out.add(name);
  }

  final nums = <int>{};
  while (nums.length < limit) {
    nums.add(1 + rng.nextInt(maxShopNameNumber));
  }
  for (final n in nums) {
    add(shopNameWithNumber(base, n));
  }
  for (var n = 1; out.length < limit && n <= maxShopNameNumber; n++) {
    add(shopNameWithNumber(base, n));
  }
  return out;
}
