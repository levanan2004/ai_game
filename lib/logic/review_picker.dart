import 'dart:math';

import '../data/texts.dart';

/// Picks a review sentence following reviews.json `selection._rule`.
///
/// [recent] is the list of recently used sentences (newest last); the last
/// `noRepeatLast` of them are never repeated while an alternative exists.
String pickReviewComment(
  ReviewTexts texts, {
  required String outcome,
  required String occasionId,
  required Random rng,
  required List<String> recent,
  String? holidayId,
  String? mismatchReason,
}) {
  final o = texts.outcomes[outcome];
  if (o == null) return '';
  final blocked = recent.length > texts.noRepeatLast
      ? recent.sublist(recent.length - texts.noRepeatLast).toSet()
      : recent.toSet();

  List<String> pool = const [];
  final reasonPool = mismatchReason == null
      ? const <String>[]
      : (o.byReason[mismatchReason] ?? const <String>[]);
  final holidayPool = holidayId == null
      ? const <String>[]
      : (o.byHoliday[holidayId] ?? const <String>[]);
  final occasionPool = o.byOccasion[occasionId] ?? const <String>[];

  if ((outcome == 'unhappy' || outcome == 'okay') &&
      reasonPool.isNotEmpty &&
      rng.nextDouble() < texts.reasonChance) {
    pool = reasonPool;
  } else if (holidayPool.isNotEmpty && rng.nextDouble() < texts.holidayChance) {
    pool = holidayPool;
  } else if (occasionPool.isNotEmpty &&
      rng.nextDouble() < texts.occasionChance) {
    pool = occasionPool;
  } else {
    pool = o.generic;
  }

  var options = pool.where((s) => !blocked.contains(s)).toList();
  if (options.isEmpty) {
    // "hết câu thì lấy generic"
    options = o.generic.where((s) => !blocked.contains(s)).toList();
  }
  if (options.isEmpty) options = o.generic;
  if (options.isEmpty) return '';
  return options[rng.nextInt(options.length)];
}

/// Picks a customer request line following orders.json `selection` and
/// `speakerRule`: lines listed in `speakerOnly` only go to matching
/// customers; every other line is for anyone.
String pickOrderLine(
  OrderTexts texts, {
  required String occasionId,
  required Random rng,
  required List<String> recent,
  String? holidayId,
  CustomerProfile? speaker,
}) {
  final blocked = recent.length > texts.noRepeatLast
      ? recent.sublist(recent.length - texts.noRepeatLast).toSet()
      : recent.toSet();
  List<String> allowed(List<String>? pool) => [
    for (final s in pool ?? const <String>[])
      if (texts.canSay(s, speaker)) s,
  ];
  final holidayPool = holidayId == null
      ? const <String>[]
      : allowed(texts.byHoliday[holidayId]);
  final occasionPool = allowed(texts.byOccasion[occasionId]);
  var pool = occasionPool;
  if (holidayPool.isNotEmpty &&
      (occasionPool.isEmpty || rng.nextDouble() < texts.holidayChance)) {
    pool = holidayPool;
  }
  var options = pool.where((s) => !blocked.contains(s)).toList();
  if (options.isEmpty) options = pool;
  if (options.isEmpty) return '';
  return options[rng.nextInt(options.length)];
}

/// Customer sentence for an online order (`orders.json` `online`).
String pickOnlineLine(OrderTexts texts, Random rng, List<String> recent) {
  final pool = texts.online;
  if (pool.isEmpty) return '';
  final blocked = recent.length > texts.noRepeatLast
      ? recent.sublist(recent.length - texts.noRepeatLast).toSet()
      : recent.toSet();
  var options = [
    for (final s in pool)
      if (!blocked.contains(s)) s,
  ];
  if (options.isEmpty) options = [...pool];
  return options[rng.nextInt(options.length)];
}
