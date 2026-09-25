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

/// Picks a customer request line following orders.json `selection`.
String pickOrderLine(
  OrderTexts texts, {
  required String occasionId,
  required Random rng,
  required List<String> recent,
  String? holidayId,
}) {
  final blocked = recent.length > texts.noRepeatLast
      ? recent.sublist(recent.length - texts.noRepeatLast).toSet()
      : recent.toSet();
  final holidayPool = holidayId == null
      ? const <String>[]
      : (texts.byHoliday[holidayId] ?? const <String>[]);
  final occasionPool = texts.byOccasion[occasionId] ?? const <String>[];
  var pool = occasionPool;
  if (holidayPool.isNotEmpty && rng.nextDouble() < texts.holidayChance) {
    pool = holidayPool;
  }
  var options = pool.where((s) => !blocked.contains(s)).toList();
  if (options.isEmpty) options = pool;
  if (options.isEmpty) return '';
  return options[rng.nextInt(options.length)];
}
