/// Typed views of the text files from Hà Phương: `assets/data/reviews.json`
/// (review sentences + selection rules) and `assets/data/orders.json`
/// (customer request lines + customer names). The game never hard-codes
/// these sentences.
library;

class OutcomeTexts {
  const OutcomeTexts({
    required this.generic,
    required this.byReason,
    required this.byOccasion,
    required this.byHoliday,
  });

  factory OutcomeTexts.fromJson(Map<String, dynamic> j) => OutcomeTexts(
    generic: _strings(j['generic']),
    byReason: _groups(j['byReason']),
    byOccasion: _groups(j['byOccasion']),
    byHoliday: _groups(j['byHoliday']),
  );

  final List<String> generic;
  final Map<String, List<String>> byReason;
  final Map<String, List<String>> byOccasion;
  final Map<String, List<String>> byHoliday;
}

class ReviewTexts {
  const ReviewTexts({
    required this.maxChars,
    required this.reasonChance,
    required this.holidayChance,
    required this.occasionChance,
    required this.noRepeatLast,
    required this.outcomes,
  });

  factory ReviewTexts.fromJson(Map<String, dynamic> j) {
    final sel = j['selection'] as Map<String, dynamic>;
    final outcomes = j['outcomes'] as Map<String, dynamic>;
    return ReviewTexts(
      maxChars: (j['maxChars'] as num).toInt(),
      reasonChance: (sel['reasonChance'] as num).toDouble(),
      holidayChance: (sel['holidayChance'] as num).toDouble(),
      occasionChance: (sel['occasionChance'] as num).toDouble(),
      noRepeatLast: (sel['noRepeatLast'] as num).toInt(),
      outcomes: {
        for (final e in outcomes.entries)
          if (!e.key.startsWith('_'))
            e.key: OutcomeTexts.fromJson(e.value as Map<String, dynamic>),
      },
    );
  }

  final int maxChars;
  final double reasonChance;
  final double holidayChance;
  final double occasionChance;
  final int noRepeatLast;
  final Map<String, OutcomeTexts> outcomes;
}

class OrderTexts {
  const OrderTexts({
    required this.noRepeatLast,
    required this.holidayChance,
    required this.byOccasion,
    required this.byHoliday,
    required this.customerNames,
  });

  factory OrderTexts.fromJson(Map<String, dynamic> j) => OrderTexts(
    noRepeatLast: (j['noRepeatLast'] as num).toInt(),
    holidayChance: (j['holidayChance'] as num).toDouble(),
    byOccasion: _groups(j['byOccasion']),
    byHoliday: _groups(j['byHoliday']),
    customerNames: _strings(j['customerNames']),
  );

  final int noRepeatLast;
  final double holidayChance;
  final Map<String, List<String>> byOccasion;
  final Map<String, List<String>> byHoliday;
  final List<String> customerNames;
}

List<String> _strings(Object? v) =>
    v == null ? const [] : (v as List).cast<String>();

Map<String, List<String>> _groups(Object? v) {
  if (v == null) return const {};
  return {
    for (final e in (v as Map<String, dynamic>).entries)
      if (!e.key.startsWith('_')) e.key: _strings(e.value),
  };
}
