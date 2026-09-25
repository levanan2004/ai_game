import 'dart:math';

import '../data/texts.dart';
import 'delivery.dart';

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

/// Customer sentence for an online order.
/// Preorder cards use `online.preorder`; same-day cards use `online.sameday`.
String pickOnlineLine(
  OrderTexts texts,
  OrderKind kind,
  Random rng,
  List<String> recent,
) {
  final pool = kind == OrderKind.preorder
      ? texts.onlinePreorder
      : texts.onlineSameday;
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

/// Chip label for an `ownerReplies` tone (spec_danh_gia.md §3).
const ownerReplyToneLabel = <String, String>{
  'thanks': 'Cảm ơn',
  'sorry': 'Xin lỗi',
  'improve': 'Hứa làm tốt hơn',
  'invite': 'Mời quay lại',
  'cute': 'Vui vẻ đáng yêu',
};

class OwnerReplyChoice {
  const OwnerReplyChoice({
    required this.tone,
    required this.label,
    required this.text,
  });

  final String tone;
  final String label;

  /// The suggestion that tapping this chip writes into the field.
  final String text;
}

/// Up to `ownerReplyChoices` suggestions, each a different tone.
/// The sentence is chosen once, so a tap fills that line for editing.
/// An outcome with no `ownerReplies` group returns an empty list.
List<OwnerReplyChoice> ownerReplyChoices(
  ReviewTexts texts,
  String outcome,
  Random rng,
) {
  final group = texts.ownerReplies[outcome];
  if (group == null || group.isEmpty) return const [];
  final tones = group.map((line) => line.tone).toSet().toList()..shuffle(rng);
  final n = texts.ownerReplyChoiceCount;
  final choices = <OwnerReplyChoice>[];
  for (final tone in tones) {
    if (choices.length >= n) break;
    final lines = [
      for (final line in group)
        if (line.tone == tone) line.text,
    ];
    if (lines.isEmpty) continue;
    choices.add(
      OwnerReplyChoice(
        tone: tone,
        label: ownerReplyToneLabel[tone] ?? tone,
        text: lines[rng.nextInt(lines.length)],
      ),
    );
  }
  return choices;
}

/// A random prepared sentence of [tone], or null when that tone has none.
String? pickOwnerReply(
  ReviewTexts texts,
  String outcome,
  String tone,
  Random rng,
) {
  final lines = [
    for (final line in texts.ownerReplies[outcome] ?? const <OwnerReplyLine>[])
      if (line.tone == tone) line.text,
  ];
  if (lines.isEmpty) return null;
  return lines[rng.nextInt(lines.length)];
}

/// Player-typed reply, trimmed and clipped to 80 characters.
/// Empty or whitespace-only text cannot be sent.
String? normalizeReply(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  return text.length > 80 ? text.substring(0, 80) : text;
}
