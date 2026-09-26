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

/// Letters (including Vietnamese), digits, spaces, and `&'-.`.
final shopNamePattern = RegExp(r"^[\p{L}\p{N} &'\-.]+$", unicode: true);

/// Trim, collapse spaces, then require 2–20 allowed characters.
/// Returns null when the name cannot be saved.
String? normalizeShopName(String raw) {
  final name = raw.trim().replaceAll(RegExp(r' +'), ' ');
  if (name.length < 2 || name.length > 20) return null;
  if (!shopNamePattern.hasMatch(name)) return null;
  return name;
}

String rollShopName(String current, Random rng) {
  final pool = [
    for (final name in suggestedShopNames)
      if (name != current) name,
  ];
  final choices = pool.isEmpty ? suggestedShopNames : pool;
  return choices[rng.nextInt(choices.length)];
}
